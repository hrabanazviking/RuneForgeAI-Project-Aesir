# engine/aesir.mojo
# The central intelligence that unites the components of the Aesir Engine.

from std.math import max, min
from core.mimir_well import MimirWell, KVCache, MimirStore, RuneTensor, DeviceTopology, NPUBackendType, GPURealmType, f16, f32
from core.inference import forward_pass, forward_pass_batched, TransformerBlock, Qwen35Block, Qwen35State, forward_pass_qwen35, forward_pass_qwen35_batched, Gemma4Block, forward_pass_gemma4, forward_pass_gemma4_batched
from core.parallel import _env_int
from core.sampler import RuneRNG, sample_token_from_logits
from core.phase_timing import PhaseTimings, phase_now_ns, disjoint_pure_ns
from core.session import SessionContext, SessionManager
from core.supervisor import SelfHealingSupervisor
from core.state_vault import StateVault, VaultCheckpoint
from core.event_bus import AesirEventBus
from core.thread_pool import RuneThreadPool
from core.swarm import SwarmCluster
from loader.gguf import GGUFModelConfig, GGUFSeer
from loader.mmproj import MmprojFile, find_mmproj_beside
from core.vision_encoder import encode_image_rows
from loader.tokenizer import RuneWeaver
from loader.chat_template import ChatMessage, RuneChatTemplate
from server.api import BifrostGate
from loader.corpus_ingestion import mean_pool_token_embeddings
from core.gemma4_cuda import Gemma4CUDASession
from core.llama3_cuda import Llama3CUDASession
from core.runtime_plan import NativeModelPlan, NativeDeviceSelection, choose_native_cuda, choose_native_cuda_plan, choose_native_hip_plan, explain_host_fit
from core.inference_memory import MemoryFitExplanation, llama3_memory_plan
from qwen35_resident import validate_qwen35_resident
from core.native_hardware import observe_host_memory, observe_cpu_name, bounded_decimal
from core.cuda_gate import CUDAGate
from core.sampling_config import NativeSamplingConfig
from core.generation_control import GenerationControl, NativeGenerationStatus, ControlledTextSession, monotonic_milliseconds


comptime MAX_RUNTIME_CONTEXT: Int = 16000
"""Ceiling on the context length the runtime will actually allocate KV for.

Generation never builds a KV cache longer than this (see _run_generation),
so the pool must not reserve memory for a model's full trained context:
a 128K-context 1B otherwise forces a ~4.3 GB pool on an 8 GB host, and
256K-context models would not fit at all. One named ceiling, used by both
the pool sizing and the generation path, keeps the two in agreement."""


def calculate_runtime_pool_bytes(
    config: GGUFModelConfig,
    vocab_size: Int,
    knowledge_capacity: Int,
) -> Int:
    """Derives the F16 workspace size from validated model dimensions."""
    var hidden = config.embedding_length
    var kv_dim = config.kv_dim()
    # Converted F32 tensors: up to four hidden-width norms per layer
    # (Gemma2's attn/post-attn/ffn/post-ffw set), two head-width q/k
    # norms per layer, plus small F32 vectors (Qwen3.5 SSM scalars).
    var converted_norms = (
        (4 * config.block_count + 1) * hidden
        + 2 * config.block_count * config.head_dim()
        + config.block_count * hidden
    )
    var kv_cache = (
        2
        * config.block_count
        * min(MAX_RUNTIME_CONTEXT, max(4096, config.context_length))
        * kv_dim
    )
    var layer_workspace = (
        16 * hidden
        + 4 * kv_dim
        + 4 * config.feed_forward_length
        + max(32000, vocab_size)
    )
    var knowledge_store = max(1, knowledge_capacity) * hidden
    # The workspace term is a per-call peak estimate; double it and add
    # flat slack so a model whose real temporaries run slightly over the
    # estimate fails nowhere near the KV reservation (the Gemma2 pool
    # originally landed within ~1 MB of total demand and exhausted).
    var elements = (
        converted_norms + kv_cache + 2 * layer_workspace + knowledge_store
    )
    return 2 * elements + 33554432


def validate_runtime_backend_config(
    num_devices: Int,
    enable_npu: Bool,
    enable_gpu_realm: Bool,
) raises:
    """Validates runtime backend options."""
    if num_devices != 1:
        raise Error("multi-device engine execution is not implemented")
    if enable_npu:
        raise Error("NPU engine execution is not implemented")



comptime MAX_PROMPT_BYTES = 1048576
"""Maximum admitted generation prompt size: 1 MiB of UTF-8 bytes."""


def admit_generation_prompt(prompt: String) raises:
    """Fail-closed admission of a generation prompt before any inference work."""
    if prompt.byte_length() > MAX_PROMPT_BYTES:
        raise Error("Prompt exceeds the 1 MiB byte bound")


struct GenerationConfig(Copyable):
    """Validated configuration parameters for text generation."""

    var max_new_tokens: Int
    var stop_tokens: List[Int]
    var stop_strings: List[String]
    var temperature: Float32
    var top_k: Int
    var top_p: Float32
    var repetition_penalty: Float32
    var frequency_penalty: Float32
    var presence_penalty: Float32
    var min_p: Float32
    var suppress_tokens: List[Int]
    var seed: UInt64

    def __init__(
        out self,
        max_new_tokens: Int = 16000,
        stop_tokens: List[Int] = List[Int](),
        stop_strings: List[String] = List[String](),
        temperature: Float32 = 0.7,
        top_k: Int = 40,
        top_p: Float32 = 0.9,
        repetition_penalty: Float32 = 1.1,
        frequency_penalty: Float32 = 0.0,
        presence_penalty: Float32 = 0.0,
        min_p: Float32 = 0.0,
        suppress_tokens: List[Int] = List[Int](),
        seed: UInt64 = 42,
    ):
        self.max_new_tokens = max_new_tokens
        self.stop_tokens = stop_tokens.copy()
        self.stop_strings = stop_strings.copy()
        self.temperature = temperature
        self.top_k = top_k
        self.top_p = top_p
        self.repetition_penalty = repetition_penalty
        self.frequency_penalty = frequency_penalty
        self.presence_penalty = presence_penalty
        self.min_p = min_p
        self.suppress_tokens = suppress_tokens.copy()
        self.seed = seed

    def __copyinit__(out self, existing: Self):
        self.max_new_tokens = existing.max_new_tokens
        self.stop_tokens = existing.stop_tokens.copy()
        self.stop_strings = existing.stop_strings.copy()
        self.temperature = existing.temperature
        self.top_k = existing.top_k
        self.top_p = existing.top_p
        self.repetition_penalty = existing.repetition_penalty
        self.frequency_penalty = existing.frequency_penalty
        self.presence_penalty = existing.presence_penalty
        self.min_p = existing.min_p
        self.suppress_tokens = existing.suppress_tokens.copy()
        self.seed = existing.seed

    @always_inline
    def copy(self) -> Self:
        return Self(
            self.max_new_tokens,
            self.stop_tokens.copy(),
            self.stop_strings.copy(),
            self.temperature,
            self.top_k,
            self.top_p,
            self.repetition_penalty,
            self.frequency_penalty,
            self.presence_penalty,
            self.min_p,
            self.suppress_tokens.copy(),
            self.seed,
        )

    def validate(self, context_length: Int = 4096) raises:
        """Validates generation hyper-parameters against boundaries."""
        if self.max_new_tokens <= 0:
            raise Error("GenerationConfig max_new_tokens must be a positive integer")
        if self.max_new_tokens > context_length:
            raise Error("GenerationConfig max_new_tokens exceeds context_length boundary")
        if self.temperature < 0.0:
            raise Error("GenerationConfig temperature cannot be negative")
        if self.top_k < 0:
            raise Error("GenerationConfig top_k cannot be negative")
        if self.top_p < 0.0 or self.top_p > 1.0:
            raise Error("GenerationConfig top_p must be between 0.0 and 1.0")
        if self.repetition_penalty < 0.0:
            raise Error("GenerationConfig repetition_penalty cannot be negative")
        if self.frequency_penalty < -2.0 or self.frequency_penalty > 2.0:
            raise Error("GenerationConfig frequency_penalty must be between -2.0 and 2.0")
        if self.presence_penalty < -2.0 or self.presence_penalty > 2.0:
            raise Error("GenerationConfig presence_penalty must be between -2.0 and 2.0")
        if self.min_p < 0.0 or self.min_p > 1.0:
            raise Error("GenerationConfig min_p must be between 0.0 and 1.0")


struct GenerationResult(Copyable):
    """Structured output from one deterministic generation request."""

    var token_ids: List[Int]
    var text: String
    var stop_reason: String
    var prompt_token_count: Int
    # A-036: disjoint phase timings for this run (core/phase_timing.mojo).
    var timings: PhaseTimings

    def __init__(
        out self,
        token_ids: List[Int],
        text: String,
        stop_reason: String,
        prompt_token_count: Int,
        timings: PhaseTimings = PhaseTimings(),
    ):
        self.token_ids = token_ids.copy()
        self.text = text
        self.stop_reason = stop_reason
        self.prompt_token_count = prompt_token_count
        self.timings = timings.copy()

    def __copyinit__(out self, existing: Self):
        self.token_ids = existing.token_ids.copy()
        self.text = existing.text
        self.stop_reason = existing.stop_reason
        self.prompt_token_count = existing.prompt_token_count
        self.timings = existing.timings.copy()

    @always_inline
    def copy(self) -> Self:
        return Self(
            self.token_ids.copy(),
            self.text,
            self.stop_reason,
            self.prompt_token_count,
            self.timings.copy(),
        )

    @always_inline
    def generated_token_count(self) -> Int:
        return len(self.token_ids)


def generation_stop_reason(
    generated_token_id: Int,
    eos_token_id: Int,
    generated_token_count: Int,
    config: GenerationConfig,
    next_position: Int,
    context_length: Int,
) -> String:
    """Returns the stable terminal reason, or an empty string to continue."""
    if eos_token_id >= 0 and generated_token_id == eos_token_id:
        return "eos"
    if generated_token_id in config.stop_tokens:
        return "stop_token"
    if generated_token_count >= config.max_new_tokens:
        return "length"
    if next_position >= context_length:
        return "context_exhausted"
    return ""

struct AesirEngine:
    """
    AesirEngine: Sovereign LLM inference coordinator uniting Memory (MimirWell), Weights (GGUFSeer),
    Tokenizer (RuneWeaver), GPU Compute (CUDAGate), REST Transport (BifrostGate), and Swarm Mesh.
    """
    var pool: MimirWell
    var parser: GGUFSeer
    var tokenizer: RuneWeaver
    var knowledge_base: MimirStore
    var topology: DeviceTopology
    var blocks: List[TransformerBlock]
    var qwen35_blocks: List[Qwen35Block]
    var gemma4_blocks: List[Gemma4Block]
    var qwen35_state: Qwen35State
    # Q35-3r: opt-in Q8_0-resident load mode for qwen35 (default off).
    var qwen35_resident: Bool
    var enable_npu: Bool
    var target_backend: NPUBackendType
    var enable_gpu_realm: Bool
    var target_gpu_realm: GPURealmType
    var supervisor: SelfHealingSupervisor
    var event_bus: AesirEventBus
    var thread_pool: RuneThreadPool
    var swarm_cluster: SwarmCluster
    var runtime_offset: Int
    # A-036: construction-start clock + measured load phase (ns).
    var created_ns: Int64
    var load_ns: Int64
    var image_span_start: Int
    var image_span_rows: List[Float32]
    var image_span_width: Int

    def __init__(
        out self,
        model_path: String,
        num_devices: Int = 1,
        enable_npu: Bool = False,
        target_backend: NPUBackendType = NPUBackendType(NPUBackendType.ARM_NEON),
        enable_gpu_realm: Bool = False,
        target_gpu_realm: GPURealmType = GPURealmType(GPURealmType.NVIDIA_CUDA),
        knowledge_capacity: Int = 100,
        qwen35_resident: Bool = False,
    ) raises:
        var _construct_t0 = phase_now_ns()
        validate_runtime_backend_config(
            num_devices,
            enable_npu,
            enable_gpu_realm,
        )
        var probe_tokenizer = RuneWeaver()
        var probe = GGUFSeer(model_path)
        probe.inspect_metadata(probe_tokenizer)
        var mimir_depth_bytes = calculate_runtime_pool_bytes(
            probe.config,
            probe_tokenizer.vocab_size,
            knowledge_capacity,
        )
        self.created_ns = _construct_t0
        self.load_ns = 0
        self.pool = MimirWell(mimir_depth_bytes)
        print("MimirWell initialized with", mimir_depth_bytes, "derived bytes.")

        self.supervisor = SelfHealingSupervisor()
        self.event_bus = AesirEventBus()
        self.thread_pool = RuneThreadPool(8)
        self.swarm_cluster = SwarmCluster()
        self.supervisor.pulse_heartbeat()

        self.enable_npu = enable_npu
        self.target_backend = target_backend

        self.enable_gpu_realm = enable_gpu_realm
        self.target_gpu_realm = target_gpu_realm

        self.topology = DeviceTopology(num_devices)

        self.parser = GGUFSeer(model_path)
        self.tokenizer = RuneWeaver()
        self.parser.mmap_and_load(self.pool, self.tokenizer)
        self.qwen35_resident = qwen35_resident
        if self.qwen35_resident and self.parser.config.architecture != "qwen35":
            raise Error("AesirEngine: qwen35_resident Q8_0 load mode requires a qwen35 model")
        self.knowledge_base = MimirStore(
            max(1, knowledge_capacity),
            self.parser.config.embedding_length,
            self.pool,
        )
        self.runtime_offset = self.pool.offset
        self.image_span_start = -1
        self.image_span_rows = List[Float32]()
        self.image_span_width = 0

        self.blocks = List[TransformerBlock]()
        if self.parser.config.architecture != "qwen35" and self.parser.config.architecture != "gemma4":
            for layer_idx in range(self.parser.config.block_count):
                self.blocks.append(
                    TransformerBlock(
                        layer_idx,
                        self.parser.config.head_dim(),
                        self.parser.config.head_count,
                        self.parser,
                    )
                )

        # Qwen3.5 hybrid arch: dedicated blocks plus persistent SSM state.
        self.qwen35_blocks = List[Qwen35Block]()
        var qwen35_ssm_layers = 0
        if self.parser.config.architecture == "qwen35":
            for layer_idx in range(self.parser.config.block_count):
                self.qwen35_blocks.append(
                    Qwen35Block(
                        layer_idx,
                        self.parser.config.head_dim(),
                        self.parser.config.head_count,
                        self.parser,
                        self.qwen35_resident,
                    )
                )
            var fai = self.parser.config.full_attention_interval
            if fai <= 0:
                fai = 4
            qwen35_ssm_layers = (
                self.parser.config.block_count
                - self.parser.config.block_count // fai
            )
        # Gemma 4 (S-039): dedicated CPU blocks (shared-KV, dual head
        # dims, PLE); the generic TransformerBlock list stays empty.
        self.gemma4_blocks = List[Gemma4Block]()
        if self.parser.config.architecture == "gemma4":
            for layer_idx in range(self.parser.config.block_count):
                self.gemma4_blocks.append(
                    Gemma4Block(layer_idx, self.parser)
                )
        # Q35-3: state geometry follows the real layout -- head_count
        # is the v-head count (ssm_time_step_rank) and the conv ring
        # width is qkv_width = 2*groups*state + inner, not 3*inner.
        var qwen35_qkv_width = 2 * self.parser.config.ssm_group_count * self.parser.config.ssm_state_size + self.parser.config.ssm_inner_size
        self.qwen35_state = Qwen35State(
            qwen35_ssm_layers,
            self.parser.config.ssm_time_step_rank,
            self.parser.config.ssm_state_size,
            qwen35_qkv_width,
            self.parser.config.ssm_conv_kernel,
        )
        if self.qwen35_resident:
            # Q35-3r: the block constructors already refused any
            # non-Q8_0 large layer weight by name; this whole-model
            # pass covers the globals (token_embd / output) and
            # prices the admitted set both ways for the record.
            var resident_report = validate_qwen35_resident(self.parser)
            print("Qwen35 resident load: mode=" + resident_report.load_mode() + " large_tensors=" + String(resident_report.large_count) + " q8_0_bytes=" + String(resident_report.q8_bytes) + " f16_materialized_bytes_avoided=" + String(resident_report.f16_bytes))
        self.load_ns = phase_now_ns() - _construct_t0

    def _forward_position(
        mut self,
        tokens: List[Int],
        mut kv_cache: KVCache,
        pos: Int,
        gen_config: GenerationConfig,
        is_prefill: Bool = False,
    ) raises -> Int:
        """One position of generation, dispatched by architecture: the
        Qwen3.5 hybrid path carries SSM state and its own blocks; every
        other arch uses the standard transformer forward pass."""
        if self.image_span_start >= 0 and self.parser.config.architecture == "qwen35":
            raise Error("image span override is not supported on the qwen35 path")
        if self.parser.config.architecture == "gemma4":
            return forward_pass_gemma4(
                tokens,
                self.parser,
                self.pool,
                kv_cache,
                self.gemma4_blocks,
                pos,
                gen_config.temperature,
                gen_config.top_k,
                gen_config.top_p,
                gen_config.repetition_penalty,
                is_prefill,
                gen_config.seed,
            )
        if self.parser.config.architecture == "qwen35":
            return forward_pass_qwen35(
                tokens,
                self.parser,
                self.pool,
                kv_cache,
                self.qwen35_blocks,
                self.qwen35_state,
                pos,
                gen_config.temperature,
                gen_config.top_k,
                gen_config.top_p,
                gen_config.repetition_penalty,
                gen_config.seed,
            )
        return forward_pass(
            tokens,
            self.parser,
            self.pool,
            kv_cache,
            pos,
            self.parser.config.block_count,
            self.parser.config.head_dim(),
            self.parser.config.head_count,
            self.topology,
            self.blocks,
            self.enable_npu,
            self.target_backend,
            self.enable_gpu_realm,
            self.target_gpu_realm,
            gen_config.temperature,
            gen_config.top_k,
            gen_config.top_p,
            gen_config.repetition_penalty,
            is_prefill,
            self.image_span_start,
            self.image_span_rows,
            gen_config.seed,
        )

    # Placement options (Janas road J-036): the per-pass placement
    # surface -- --prompt-on / --drafts-on / --reply-on, their
    # AESIR_*_ON env equivalents, the device kill switches, and the
    # quality-tier fields (J-014 gate A2) -- is parsed, validated
    # and reported by core/placement_options.mojo (scan_placement_args
    # + placement_env_inputs + resolve_placement_options). This
    # engine does NOT consume a placement choice yet: passes still
    # run where they have always run, and no surface may claim
    # otherwise. Consumption is roaded to J-038+ (measurement and
    # auto choice); the draft-check pass the drafts option names
    # does not exist yet (J-035 gap G1, Part V J-071/J-072), and
    # placement_options.require_draft_check_use fails closed until
    # it does. See docs/janas/J036_PLACEMENT_OPTIONS.md.
    #
    # Device inventory (Janas road J-037): the machine truth the
    # placement surface deliberately does not carry lives in
    # core/device_inventory.mojo -- observe_device_inventory()
    # probes CPU topology from /proc/cpuinfo, the GPU through the
    # nvidia-smi-class probe with its failure as the reason, and
    # reports the NPU strictly from Aesir's ledgers (the Hailo is
    # parked by campaign law: reported, never probed, never run).
    # Its device_line() is the bench-style line a surface prints at
    # open beside the placement report above; require_device_present
    # is the feed point J-047's generalised refusal consumes. No
    # surface consumes the inventory yet; claiming otherwise would
    # fake an integration that does not exist. See
    # docs/janas/J037_DEVICE_INVENTORY.md.
    #
    # Placement measurement harness (Janas road J-038): the step
    # between the options above and the inventory is
    # core/placement_harness.mojo -- run_placement_measurement()
    # enumerates the candidates a resolved option names for one
    # pass kind, filters them through the inventory (excluded
    # candidates are recorded with the inventory's own reason,
    # never silently dropped), and runs bounded micro-runs per
    # surviving candidate: at least one settle round whose timing
    # is discarded, then measured rounds summarized by median,
    # under hard per-candidate and per-sweep time bounds. It is
    # callable at model open OR on demand -- the same entry point
    # either way -- and this slice wires it into NO live session
    # path: no session consumes a measurement yet, and auto choice
    # is J-040--J-042. Draft-check candidates record as
    # unmeasurable-with-reason (gap G1 above; no pass exists to
    # measure) and co-work candidates likewise (J-043 owns the
    # split pass). See docs/janas/J038_PLACEMENT_MEASUREMENT_HARNESS.md.
    #
    # Thread topology trials (Janas road J-039): the thread-count
    # axis of the same measurement step lives in
    # core/thread_topology.mojo -- derive_thread_ladder() derives
    # the candidate counts from the inventory's CPU facts alone
    # (serial / half / all-physical / all-logical, and a
    # performance-only rung only when the machine itself states a
    # hybrid split; otherwise NOT APPLICABLE-WITH-REASON, never
    # invented), and run_thread_trials() measures every rung per
    # pass kind under the J-038 discipline (settle discarded,
    # median of measured rounds, hard bounds) through the engine's
    # own thread layer (AESIR_THREADS + par_for, checksums asserted
    # bit-identical to the serial workload at every count). The
    # i9 lesson (more threads can be slower) is graded per kind by
    # a pre-registered rule, not assumed. Draft-check rungs record
    # as unmeasurable-with-reason (gap G1 above). This slice wires
    # the trials into NO live session path: no session consumes a
    # thread verdict yet; auto choice is J-040--J-042. See
    # docs/janas/J039_THREAD_TOPOLOGY.md.
    #
    # Bench that measures configurations (Janas road J-100): the
    # user-facing sweep lives in core/bench_configurations.mojo --
    # run_bench_sweep() composes the J-038 device sweep and the
    # J-039 thread trials per pass kind (prompt / draft-check /
    # reply) into the cross product the placement engine may
    # choose (threads x devices x pass kinds), every cell
    # enumerated with its classification and reason, the CPU cells
    # measured through the threaded executor, and machine_report()
    # renders the whole as one stable, sendable text. The `bench`
    # command (cli/bench.mojo, dispatched from cli/commands.mojo)
    # is its one surface in this slice. No session consumes a
    # bench report yet: choice remains J-040--J-042's and the
    # learned file J-044's; `bench --report` is J-101's surface.
    # See docs/janas/J100_BENCH_CONFIGURATIONS.md.
    #
    # The machine report artefact (Janas road J-101): the
    # sendable form of the bench lives in
    # core/machine_report.mojo -- report_artefact() opens with
    # J-100's machine_report() verbatim (hardware inventory,
    # sweeps, cell table) and appends the per-model read/write
    # table of filed evidence (each cell carrying its source and
    # honesty class, or NOT PROVEN with its reason -- nothing in
    # the table is invented) and the device refusal summary
    # (J-037's device line verbatim, then each entry's own line
    # with its refusal reason). The `bench --report` flag
    # (cli/bench.mojo) is its one surface in this slice; it
    # refuses --pass, because the artefact is the whole machine.
    # See docs/janas/J101_MACHINE_REPORT.md.
    #
    # Auto choice for prompt passes (Janas road J-040): the
    # prompt kind's chooser lives in core/prompt_placement.mojo --
    # choose_prompt_placement() runs the J-038 device sweep (the
    # field and its exclusions; its CPU timing is a cross-check
    # only, never ranked -- a different executor from the
    # threaded one) and the J-039 thread trials (the rankable
    # CPU rungs), then applies the pre-registered decision rule:
    # a measured winner must beat the runner-up by more than 10%
    # of its median AND its slowest counted round must beat the
    # runner-up's median, otherwise the session default (cpu,
    # 1 thread) is kept with the failed hurdle stated; a sole
    # measured candidate is chosen as sole-measured; no measured
    # candidate falls back to the default while the cpu is
    # present, else the record is a refusal. An explicit
    # single/co-work prompt option fixes the choice and is never
    # ranked against. The record is kept for the session in a
    # PromptPlacementSession (decided once; a second decision is
    # refused) and rendered by its report(). Present GPU/NPU and
    # co-work candidates ride on the record as excluded /
    # unmeasurable-with-reason -- no device executor exists yet
    # and no GPU or split number is faked. This slice wires the
    # chooser into NO live session path: no session consumes a
    # prompt placement yet. Reply choice is J-041, draft-check
    # J-042, co-work execution J-043, re-trials J-045. See
    # docs/janas/J040_AUTO_PROMPT_PLACEMENT.md.
    #
    # Auto choice for reply passes (Janas road J-041): the reply
    # kind's chooser lives in core/reply_placement.mojo --
    # choose_reply_placement() runs the J-038 device sweep for
    # the reply kind (the field and its exclusions; its CPU
    # timing is a cross-check only, never ranked -- a different
    # executor from the threaded one) and the J-039 thread
    # trials for the reply kind (the rankable CPU rungs), then
    # applies the pre-registered decision rule adopted unchanged
    # from J-040: a measured winner must beat the runner-up by
    # more than 10% of its median AND its slowest counted round
    # must beat the runner-up's median, otherwise the session
    # default (cpu, 1 thread) is kept with the failed hurdle
    # stated; a sole measured candidate is chosen as
    # sole-measured; no measured candidate falls back to the
    # default while the cpu is present, else the record is a
    # refusal. An explicit single/co-work reply option fixes
    # the choice and is never ranked against. The record is
    # kept for the session in a ReplyPlacementSession (decided
    # once; a second decision is refused) and rendered by its
    # report(). The integrated-GPU question is answered
    # honestly on every record: no GPU reply executor exists
    # in the harness yet, so GPU candidates ride as excluded /
    # unmeasurable-with-reason and are never ranked -- single
    # tokens go to the GPU only when a measured GPU reply
    # executor exists and clears the same hurdles (NOT PROVEN
    # today). The NPU never takes a reply pass (J-036 refuses
    # it at parse; in the auto field the inventory excludes it,
    # parked). This slice wires the chooser into NO live
    # session path: no session consumes a reply placement yet.
    # Draft-check choice is J-042, co-work execution J-043,
    # re-trials J-045. See docs/janas/J041_AUTO_REPLY_PLACEMENT.md.
    #
    # Auto choice for draft-check passes (Janas road J-042):
    # the draft-check kind's chooser lives in
    # core/draft_placement.mojo -- choose_draft_placement()
    # enumerates the J-038 device sweep and the J-039 thread
    # ladder for the drafts kind, then applies the
    # pre-registered decision rule adopted unchanged from
    # J-040/J-041. Its honest state today: Aesir has no
    # draft-check pass (J-035 gap G1), so the harness
    # classifies every candidate on both axes
    # UNMEASURABLE-WITH-REASON, nothing is timed or ranked,
    # and the live outcome is the rule's NO-MEASURED-FALLBACK
    # (the session default kept as a label) while the cpu is
    # present, else a refusal. An explicit single/co-work
    # drafts option fixes the choice (MANUAL-FIXED) with its
    # unmeasurable state on the record; choosing is not
    # using -- any actual use of a drafts placement still
    # fails closed through require_draft_check_use() (J-036)
    # until Part V (J-071/J-072) builds the pass and a real
    # verify-pass executor for the harness. The record is
    # kept for the session in a DraftPlacementSession
    # (decided once; a second decision is refused). This
    # slice wires the chooser into NO live session path: no
    # session consumes a drafts placement yet. Co-work
    # execution J-043, re-trials J-045. See
    # docs/janas/J042_AUTO_DRAFT_PLACEMENT.md.
    #
    # Verification-first speculative design (Janas road
    # J-071): the verify pass is a draft-check pass in
    # J-035's taxonomy, and its account lives in
    # core/speculative_verify.mojo -- plan_verify() derives
    # each greedy round from a proposer's draft list and the
    # TARGET's own greedy list (k+1 choices from one pass of
    # width k+1, inside the 2..16 band), emitting the accepted
    # prefix plus exactly one further target choice, built
    # from the target list only, with exact KV/context
    # rollback and zero RNG draws; plan_proposer() states the
    # shapes for J-072's three proposer slots (head --
    # MTP head or assistant model; cross-model; conversation).
    # The invariant is by construction: speculative greedy
    # output is token-identical to non-speculative greedy
    # because nothing but target choices is ever emitted.
    # This slice builds the account only: no loop runs, no
    # session consumes it, and require_draft_check_use()
    # (J-036) still fails closed -- J-072 builds the draft
    # loop and replaces the refusal with real consumption
    # then, and only then. See
    # docs/janas/J071_VERIFICATION_FIRST_DESIGN.md.
    #
    # The draft loop (Janas road J-072): the loop machinery
    # lives in core/speculative_loop.mojo -- dispatch over
    # J-071's three proposer slots, plan_round_k() (band,
    # proposer caps, and explicit KV-capacity shortening),
    # run_loop_round() (snapshot, one plan_verify round,
    # exact rollback of KV / context / proposer KV asserted
    # against the snapshot, RNG word unchanged), and
    # run_loop() (multi-round driving, emission asserted
    # token-identical to plain greedy). The legacy draft
    # bound in core/speculative.mojo is reconciled there:
    # hard limit 15 (the band), default 4 retained as the
    # loop's initial k. The adaptation rule's shape is
    # stated (suggest_next_k); measured tuning is J-079.
    # Honest wiring state: NO session consumes the loop --
    # no proposer implementation or verify-pass executor
    # exists for a session to call, so
    # require_draft_check_use() still fails closed and this
    # facade's speculative_generate still raises
    # not-implemented. Claiming consumption would fake an
    # integration that cannot run. See
    # docs/janas/J072_DRAFT_LOOP.md.
    #
    # Co-work passes for the prompt kind (Janas road J-043):
    # the split machinery lives in core/cowork_passes.mojo --
    # plan_cowork_prompt() plans the pairs a resolved prompt
    # option names (row-split fractions with exact per-side
    # work and crossing/join byte accounting), classifies
    # each pair (any NPU pair refused -- the parked Hailo
    # ledger, J-037; an absent member excluded with the
    # inventory's reason; a present non-CPU member
    # unmeasurable-with-reason -- the harness has CPU prompt
    # executors only and no GPU prompt executor exists), and
    # applies the pre-registered survival rule inherited
    # from J-040: a split survives as an option only when
    # its measured joined time beats BOTH single-device
    # parents by more than 10% of its median AND passes
    # round separation against each parent; failures are
    # measured-and-rejected, never kept. True two-device
    # co-work is NOT PROVEN on today's tree (no device
    # executor; the NPU is parked and refused) and no GPU/NPU
    # timing is stated. The one measurable split,
    # run_thread_partition_analogue(), divides the batch
    # across two thread partitions of the SAME cpu through
    # J-039's threaded executor with a timed List gather as
    # the join, and is labelled an analogue on its face --
    # it is not device co-work and creates no device option;
    # its live verdicts on the VM were measured-and-rejected
    # for all three fractions. An explicit co-work option is
    # evaluated as written and never substituted (manual
    # supremacy untouched). This slice wires the planner
    # into NO live session path: no session consumes a
    # co-work placement yet. The learned file is J-044,
    # re-trials J-045. See docs/janas/J043_COWORK_PASSES.md.
    #
    # The learned file (Janas road J-044): placement + thread
    # choices persisted between sessions live in
    # core/learned_file.mojo -- load_learned_file() loads the
    # file at open from learned_file_path() (AESIR_LEARNED_FILE,
    # else AESIR_CACHE_HOME, else $HOME/.cache/aesir, in Aesir's
    # own versioned text format), keyed exactly by machine
    # (derived from J-037's CPU/GPU facts) + model shape (the
    # GGUF config's shape fields, mapped by the host). A missing
    # file is the clean MISSING state and a corrupt/truncated
    # file a clean REFUSED state with its reason -- neither
    # raises through open and neither partially applies; a key
    # mismatch (lookup_learned) names which half of the key
    # failed. Learned values are DEFAULTS ONLY: an explicit
    # --*-on option overrides them always (manual supremacy;
    # J-047 owns the refusal surface). A kind whose chooser
    # refused is stored absent; no expert map is stored (J-027
    # measured rejection -- the format has no line for one).
    # store_learned_entry() learns a fresh measured choice with
    # its measured-at stamp (J-045's re-trial provenance);
    # erase_learned_file() / erase_learned_entry() erase;
    # LearnedLoad.report() is the show-on-request dump. This
    # slice wires the module into NO live session path: no
    # session consumes a learned choice yet. Re-trials are
    # J-045. See docs/janas/J044_LEARNED_FILE.md.
    #
    # Re-trials of learned choices (Janas road J-045): the
    # re-measurement of a learned choice lives in
    # core/retrial.mojo -- plan_retrial() applies the bounded
    # cadence to one J-044 entry (due on age >= 30 days, or on
    # >= 25 host-counted opens past an absolute 7-day floor;
    # never per-open, never under clock skew; a drifted key is
    # named KEY-DRIFT and is a fresh-measure road, not a
    # re-trial). Only a DUE plan may re-measure: run_retrial()
    # re-runs each due kind's own chooser (J-040/J-041/J-042)
    # under the kind's stored option, and apply_retrial()
    # adopts the verdict through J-044's store path -- a
    # changed kind replaces the learned choice, a reproduced
    # kind keeps it with the measured-at stamp refreshed to
    # the re-trial instant, a fresh refusal makes the kind
    # absent (an all-absent re-trial erases the entry) -- and
    # appends the change record (old -> new, trigger, outcome)
    # to the retrial log beside the learned file
    # (<learned path>.retrials.log). MANUAL-FIXED kinds are
    # never re-trialled and an all-manual entry is never due
    # (manual supremacy). A skipped re-trial writes nothing.
    # This slice wires the module into NO live session path:
    # no session re-trials a learned choice yet. See
    # docs/janas/J045_RETRIALS.md.
    #
    # Within-tolerance proof (Janas road J-046): the grading
    # of the auto choice against the full configuration sweep
    # lives in core/within_tolerance.mojo --
    # run_within_tolerance_proof() runs the real J-040/J-041
    # choosers for REPETITIONS (3) independent repetitions per
    # model shape (keyed the J-044 way) per kind (prompt,
    # then reply) and grades each repetition under the
    # pre-registered rule: best is the lowest median of the
    # thread-ladder sweep the chooser ranks, auto is the
    # median -- in the SAME sweep -- of the configuration the
    # chooser actually chose, gap % = (auto - best) / best *
    # 100 against the targets prompt <= 1.50% / reply <=
    # 2.60% (Janas's published claim, adopted as a target to
    # test); per-repetition verdicts BEATEN / MET / MISSED /
    # NOT PROVEN aggregate per shape per kind (any MISSED
    # with no NOT PROVEN makes the aggregate MISSED; any NOT
    # PROVEN makes it NOT PROVEN). Both options must be auto
    # -- a manual option has no auto choice to grade and the
    # builder refuses it. Device-axis candidates are named on
    # the chooser records and never ranked (no device
    # executor exists; the device sweep's cpu timing is a
    # cross-check from a different executor). Draft-check is
    # NOT PROVEN by construction (no draft-check pass
    # exists, J-035 gap G1) and no proxy is graded. The shape
    # enters as the J-044 key only: the harness workloads are
    # fixed shapes, the choosers take no model argument, and
    # no model inference runs. This slice wires the proof
    # into NO live session path: no session consumes a
    # tolerance proof yet. See
    # docs/janas/J046_WITHIN_TOLERANCE.md.
    #
    # Manual override supremacy (Janas road J-047): the layer
    # that decides whose choice governs lives in
    # core/manual_override.mojo. It carries the --mode preset
    # surface the census names (scan_mode_args +
    # mode_env_inputs + resolve_mode: --mode auto|eco|max,
    # env AESIR_MODE, cli > env > default, sources recorded;
    # eco is a fixed cpu threads=1 intent -- the census's eco
    # rule, gpu never in its field, the serial rung minimal by
    # construction, no speed claimed; max is a measure intent
    # over the full auto field with the learned default
    # bypassed; auto governs nothing). resolve_precedence()
    # applies the stack per pass kind -- hand > preset >
    # learned > auto: a set hand option governs as
    # MANUAL-FIXED (single/co-work, never measured against,
    # never ranked, never re-trialled), MANUAL-RACE (the field
    # is exactly the hand's list), or MANUAL-AUTO (an explicit
    # auto is a hand statement directing fresh measurement;
    # an unset auto is silence and falls through); only under
    # silence may a preset govern (PRESET-FIXED /
    # PRESET-MEASURE), only under silence with no preset may
    # a learned default apply (a learned MANUAL-FIXED keeps
    # its persisted-hand provenance and is never re-trialled),
    # and AUTO is the remainder. validate_open_choices() is
    # the generalised invalid-device refusal at open: every
    # device a governing hand, preset, or learned choice
    # names -- single, both co-work members, every race
    # member -- is checked against the J-037 inventory, and
    # an absent device (or the parked NPU as an execution
    # device) refuses the whole choice with the device, the
    # kind, and the inventory fact in the reason; nothing is
    # dropped, substituted, or trimmed. This slice wires the
    # layer into NO live session path: no session consumes a
    # precedence resolution or a mode preset yet. See
    # docs/janas/J047_MANUAL_OVERRIDE.md.

    # Placement under memory pressure (Janas road J-048): the
    # contention rule where the expert cache and a device
    # placement compete for one memory pool lives in
    # core/placement_pressure.mojo -- plan_placement_pressure().
    # Fixed placement bytes (resident + KV + activation + the
    # pool reserve, J-031's / J-028's charging order) are charged
    # first in full and are never cannibalised by the cache; the
    # expert cache is the only elastic consumer (capped at its
    # open-time budget and at the expert body, shed first, floor
    # = one token's full routed demand as in J-028); a duplicate
    # device copy (the census's NPU-copy shape) is cache-class --
    # admitted only where the cache keeps the floor after it,
    # otherwise it stays closed -- unless a hand choice names
    # it, when it charges as fixed (J-047 supremacy: a governing
    # hand choice is never shrunk, migrated, substituted, or
    # trimmed; an impossible contention refuses the whole
    # session at open with the numbers stated, it never
    # overrides the choice). Below the floor an optional device
    # cache degrades to zero and the placement stands (J-031's
    # resident-only division); a required host cache refuses
    # cleanly (J-028). Placement never migrates mid-run: a
    # token-boundary re-plan moves only the cache and copies.
    # This slice wires the planner into NO live session path:
    # no session consumes a contention plan yet. See
    # docs/janas/J048_PLACEMENT_MEMORY_PRESSURE.md.
    #
    # Server placement parity (Janas road J-049): the parity
    # layer between the placement surface above and Aesir's
    # server surface lives in core/server_placement.mojo.
    # The live service (cli/native_serve.mojo serve_loaded)
    # is one resident CUDA session, concurrency 1, its
    # backend/device/profile/context fixed at startup; per
    # request it reconfigures only cheap state (sampling,
    # control, output, tool) -- there is no configure-placement
    # on any session and no placement field in any request
    # parser today. Placement is allocation-bound state, like
    # the context (server/local_protocol.mojo's
    # require_loaded_context refuses a per-request value that
    # differs from the loaded one), not cheap state like
    # sampling. The parity rule: session defaults govern --
    # resolve_server_defaults() resolves the J-036 options +
    # J-047 mode once at serve open (open refusal + quality
    # gate + one precedence resolution) and
    # require_server_defaults_conformance() checks every
    # fixed outcome against the resident placement the host
    # states (for the CUDA service, single gpu for prompt and
    # reply -- the backend its own banner states); the three
    # generation request shapes may carry prompt_on /
    # drafts_on / reply_on / mode as flat fields (claimed via
    # apply_server_placement_field(); never inside Ollama's
    # numbers-only options object, and never on non-generation
    # routes), resolved per request by
    # resolve_server_request_placement() (request hand >
    # request preset > session resolution, per kind, J-036 /
    # J-047 refusals inherited whole) and checked by
    # require_server_request_conformance(): a request-governed
    # fixed placement must equal the resident session's
    # executed placement, and a request-governed measurement
    # demand is refused (measurement is an open-time act).
    # A request states nothing -> the session default governs
    # the kind; request outcomes never mutate the defaults.
    # This slice wires the layer into NO live server path:
    # serve_loaded consumes no placement resolution yet, and
    # dispatch_native_serve still refuses the placement flags
    # as unsupported service options -- the wiring is the host
    # contract in the module, named, not faked. See
    # docs/janas/J049_SERVER_PLACEMENT_PARITY.md.
    #
    # Placement explainability (Janas road J-050): the
    # `--explain-placement` report lives in
    # core/placement_explain.mojo --
    # assemble_placement_explanation() assembles ONE report
    # from the Part III pieces a surface kept at open (the
    # J-036 options + J-047 precedence, the J-037 inventory,
    # the J-040--J-042 chooser records with every candidate
    # and its numbers or its exclusion reason, the J-043
    # co-work record, the J-044 learned load + lookup with
    # the stored choice per kind, the J-045 re-trial plan,
    # the J-046 tolerance grades, the J-048 pressure plan,
    # and J-049's per-request outcomes where a request
    # governed). Per pass kind the report states the
    # candidates, the choice, the governing layer and its
    # provenance, and the learned-file state; a piece that
    # was not supplied renders as its stated absence (a kind
    # with no chooser record was never measured and says
    # so). The flag itself (scan_explain_placement_args) is
    # a bare boolean that changes no placement and takes no
    # value. This slice wires the report into NO live
    # session or server path: no session consumes a
    # placement plan yet, so none consumes an explanation
    # yet either -- the wiring is the host contract in the
    # module, named, not faked, and roaded to the J-052
    # gate. See docs/janas/J050_PLACEMENT_EXPLAINABILITY.md.
    #
    # Long-prompt watching (Janas road J-059): the progress
    # account for a prompt read lives in
    # core/prompt_progress.mojo -- plan_prompt_progress()
    # states the read's shape under the pre-registered
    # discipline (watched iff >= 1024 prompt tokens AND
    # >= 4 chunks; boundary-only records; a 10% step
    # throttle, so at most 10 records per read at any
    # width; the final 100% record exactly once; never a
    # token not yet read), progress_record() states one
    # chunk boundary (with the caller's monotonic elapsed
    # ms riding as the O2 timestamp), and
    # render_progress_line() / render_progress_event()
    # render it for the CLI and the server stream. The
    # host wiring for THIS loop: build the plan once from
    # len(tokens) and batch_cap before the prefill loop in
    # _run_generation, take one record per completed chunk
    # (width batch_cap, or width 1 in the per-token
    # fallback), and print the line only when record.emit.
    # This slice wires the account into NO live loop yet:
    # _run_generation consumes no progress plan today, so
    # no loop prints one -- the wiring is the host contract
    # in the module, named, not faked, and roaded to the
    # deferred live leg in docs/janas/J059_LONG_PROMPT_
    # WATCHING.md (progress must stay text-invisible: a
    # watched read produces the same ids as a silent one).

    def _prefill_batch_cap(self) -> Int:
        """Chunk size for batched prefill: AESIR_PREFILL_BATCH sets it
        (default 256; 1 disables batching and restores the per-token
        loop). The 256 default is S-033 evidence (Oprius-i1 1.1B,
        purplelongship): on a 213-token prompt, chunk 32 -> 256 cut
        t1 walls 9-14% on every rung with bit-identical token ids
        (each chunk re-decodes the weight blocks, so at small-model
        sizes fewer chunks means far less repeated decode work).
        Also clamped by arena workspace — one batch row needs
        roughly 3*hidden + q_width + 2*kv_width + 2*ffn_dim f16
        elements of per-layer scratch, and at most half the arena's
        free space may be committed to a single chunk."""
        var cap = _env_int("AESIR_PREFILL_BATCH", 256)
        if cap <= 1:
            return 1
        var hidden = self.parser.config.embedding_length
        var q_width = self.parser.config.head_count * self.parser.config.head_dim()
        var kv_width = self.parser.config.kv_dim()
        var ffn_dim = self.parser.config.feed_forward_length
        var per_row = 3 * hidden + q_width + 2 * kv_width + 2 * ffn_dim
        if per_row <= 0:
            return 1
        var free_elems = self.pool.capacity - self.pool.offset
        var by_workspace = (free_elems // 2) // per_row
        if by_workspace < 1:
            by_workspace = 1
        return min(cap, by_workspace)

    def _forward_batch(
        mut self,
        tokens: List[Int],
        mut kv_cache: KVCache,
        start_pos: Int,
        batch_len: Int,
        gen_config: GenerationConfig,
        is_prefill: Bool = False,
    ) raises -> Int:
        """One batched chunk of batch_len consecutive positions — the
        batched twin of _forward_position, dispatched by architecture
        the same way. Pure-prefill chunks (is_prefill) only fill the
        KV cache (and, for Qwen3.5, the SSM state); a non-prefill
        chunk's pass also yields the sampled token at its last
        position."""
        if self.image_span_start >= 0 and self.parser.config.architecture == "qwen35":
            raise Error("image span override is not supported on the qwen35 path")
        if self.parser.config.architecture == "gemma4":
            # Batched Gemma 4 prefill (S-041): Gemma4Block.forward_batched
            # + forward_pass_gemma4_batched; AESIR_PREFILL_BATCH=1 keeps
            # the per-token loop (batch_cap 1 never reaches this method
            # from generate(), which falls back to _forward_position).
            return forward_pass_gemma4_batched(
                tokens,
                self.parser,
                self.pool,
                kv_cache,
                self.gemma4_blocks,
                start_pos,
                batch_len,
                is_prefill,
                gen_config.temperature,
                gen_config.top_k,
                gen_config.top_p,
                gen_config.repetition_penalty,
                gen_config.seed,
            )
        if self.parser.config.architecture == "qwen35":
            return forward_pass_qwen35_batched(
                tokens,
                self.parser,
                self.pool,
                kv_cache,
                self.qwen35_blocks,
                self.qwen35_state,
                start_pos,
                batch_len,
                is_prefill,
                gen_config.temperature,
                gen_config.top_k,
                gen_config.top_p,
                gen_config.repetition_penalty,
                gen_config.seed,
            )
        return forward_pass_batched(
            tokens,
            self.parser,
            self.pool,
            kv_cache,
            start_pos,
            batch_len,
            self.parser.config.block_count,
            self.parser.config.head_dim(),
            self.parser.config.head_count,
            self.topology,
            self.blocks,
            self.enable_npu,
            self.target_backend,
            self.enable_gpu_realm,
            self.target_gpu_realm,
            gen_config.temperature,
            gen_config.top_k,
            gen_config.top_p,
            gen_config.repetition_penalty,
            is_prefill,
            self.image_span_start,
            self.image_span_rows,
            gen_config.seed,
        )

    def extract_query_embedding(mut self, prompt: String, hidden_dim: Int) raises -> RuneTensor[f16]:
        """
        Mean-Pooled Query Embedding Extractor (The Wisdom Extraction).
        Extracts token embedding vectors from prompt tokens using token_embd.weight lookup,
        computing element-wise mean-pooling across the prompt sequence.
        """
        if hidden_dim <= 0:
            raise Error("extract_query_embedding: hidden_dim must be positive")
        if "token_embd.weight" not in self.parser.tensors:
            raise Error("extract_query_embedding: loaded token embeddings are required")
        var embd_tensor = self.parser.tensors["token_embd.weight"].copy()
        if hidden_dim != embd_tensor.cols:
            raise Error("extract_query_embedding: hidden dimension does not match token embeddings")
        var tokens = self.tokenizer.encode(prompt, False)
        return mean_pool_token_embeddings(tokens, embd_tensor, self.pool)

    def ingest_document(mut self, text: String) raises -> Int:
        """
        Reserved document-ingestion entry point.

        The engine has no independently validated embedding model or durable
        citation index yet, so it refuses to fabricate vectors from text.
        """
        _ = text
        raise Error("document ingestion requires caller-computed embeddings and is not implemented by AesirEngine")

    def save_checkpoint(mut self, file_path: String, token_pos: Int, prompt_count: Int) raises -> VaultCheckpoint:
        """
        Persists a corruption-checked position marker using StateVault.

        This does not capture the engine's model, tensors, KV cache, sampler,
        session, process, or transport state.
        """
        var vault = StateVault()
        return vault.save_checkpoint_to_disk(file_path, token_pos, prompt_count)

    def load_checkpoint(mut self, file_path: String) raises -> VaultCheckpoint:
        """
        Loads and verifies a restart-safe position marker from disk.
        """
        var vault = StateVault()
        return vault.load_checkpoint_from_disk(file_path)

    def join_swarm_cluster(mut self, node_id: String, leader_address: String) raises -> Bool:
        """
        Reserved distributed-mesh facade entry point.
        """
        _ = node_id
        _ = leader_address
        raise Error("AesirEngine swarm join is unavailable; no secure network transport is implemented")

    def dispatch_swarm_inference(mut self, prompt: String, max_tokens: Int = 32) raises -> String:
        """
        Reserved distributed-inference facade entry point.
        """
        _ = prompt
        _ = max_tokens
        raise Error("AesirEngine swarm inference is unavailable; no remote execution transport is implemented")

    def speculative_generate(
        mut self, mut draft_engine: AesirEngine, prompt: String, max_new_tokens: Int = 32
    ) raises -> GenerationResult:
        """
        Reserved speculative-generation entry point.
        """
        _ = draft_engine
        _ = prompt
        _ = max_new_tokens
        raise Error("speculative model generation and KV reconciliation are not implemented")

    def generate_tokens_with_grammar(
        mut self, prompt: String, schema_type: String = "json", max_new_tokens: Int = 32
    ) raises -> GenerationResult:
        """
        Reserved grammar-generation entry point.
        """
        _ = prompt
        _ = schema_type
        _ = max_new_tokens
        raise Error("grammar-constrained model generation is not implemented")

    def _prepare_prompt(mut self, prompt: String) raises -> String:
        """
        Applies end-to-end RAG grounded context augmentation with budget enforcement and citations.
        """
        var active_prompt = prompt
        if self.knowledge_base.count > 0:
            var hidden_dim = self.parser.config.embedding_length
            if "token_embd.weight" in self.parser.tensors:
                hidden_dim = self.parser.tensors["token_embd.weight"].cols
            if hidden_dim <= 0:
                return prompt
            var query_vector = self.extract_query_embedding(prompt, hidden_dim)
            var docs = self.knowledge_base.search_knn(query_vector, 3)
            
            if len(docs) > 0:
                var max_context_bytes = 1024
                var context_str = String("[GROUNDED CONTEXT]:\n")
                var curr_bytes = len(context_str.as_bytes())
                var added_count = 0
                
                for i in range(len(docs)):
                    var doc_item = docs[i]
                    var citation = String("[CITATION ") + String(i + 1) + String("]: ") + doc_item + String("\n")
                    var cit_bytes = len(citation.as_bytes())
                    if curr_bytes + cit_bytes > max_context_bytes:
                        break
                    context_str += citation
                    curr_bytes += cit_bytes
                    added_count += 1
                
                if added_count > 0:
                    active_prompt = context_str + String("\n[PROMPT]: ") + prompt
                    print("RAG Grounded Context Augmented:", context_str)
                else:
                    print("RAG Notice: Knowledge context exceeded budget, skipping augmentation.")
            else:
                print("RAG Notice: No relevant knowledge context found.")
            
            self.pool.reset_kv_cache(self.runtime_offset)
        return active_prompt

    def _run_generation(
        mut self,
        prompt: String,
        config: GenerationConfig,
        client_fd: Int32,
        stream_chunks: Bool,
        is_cancelled: Bool = False,
    ) raises -> GenerationResult:
        """Owns prompt prefill and every autoregressive token transition."""
        admit_generation_prompt(prompt)
        if not self.parser.is_loaded:
            raise Error("AesirEngine cannot generate without a validated GGUF model")
        config.validate(self.parser.config.context_length)

        print("Starting deterministic generation loop (The Weaving of Fate)...")

        try:
            var gen_config = config.copy()
            self.pool.offset = self.runtime_offset
            var _prefill_t0 = phase_now_ns()
            var active_prompt = self._prepare_prompt(prompt)

            # Raw generation preserves caller text. Chat formatting belongs to
            # generate_chat; model-specific control IDs must not leak here.
            var tokens = self.tokenizer.encode(active_prompt, True)
            if len(tokens) == 0:
                raise Error("RuneWeaver produced no prompt tokens")
            if len(tokens) > self.parser.config.context_length:
                raise Error("Prompt token count exceeds the model context length")

            # One request owns one KV cache. forward_pass() reclaims only its
            # temporary workspace, leaving these cached positions intact.
            var target_context_len = min(MAX_RUNTIME_CONTEXT, self.parser.config.context_length)
            var kv_cache = KVCache(
                target_context_len,
                self.parser.config.kv_dim(),
                self.pool,
                self.parser.config.block_count,
            )
            print("Prompt tokens:", len(tokens), "context_length:", self.parser.config.context_length)
            # Full Prompt Prefill (Weaving the Context): prompt
            # tokens are processed in batches through the batched
            # forward path (bit-identical to per-token passes; see
            # core/inference.mojo). Every chunk but the last is pure
            # prefill; the final chunk also covers the last prompt
            # token and its pass yields the first sampled token. With
            # batching disabled (cap 1) the per-token loop runs.
            var next_token = -1
            var batch_cap = self._prefill_batch_cap()
            if batch_cap > 1 and len(tokens) > 1:
                var pos = 0
                while len(tokens) - 1 - pos >= batch_cap:
                    _ = self._forward_batch(
                        tokens, kv_cache, pos, batch_cap, gen_config, True
                    )
                    pos += batch_cap
                next_token = self._forward_batch(
                    tokens, kv_cache, pos, len(tokens) - pos, gen_config, False
                )
            else:
                for p in range(len(tokens) - 1):
                    _ = self._forward_position(tokens, kv_cache, p, gen_config, True)
                next_token = self._forward_position(
                    tokens, kv_cache, len(tokens) - 1, gen_config
                )

            var _prefill_span_ns = phase_now_ns() - _prefill_t0
            var _sample_after_prefill = kv_cache.sample_ns_total
            var _decode_t0 = phase_now_ns()
            var current_tokens = tokens.copy()
            var generated_token_ids = List[Int]()
            var response_text = String("")
            var stop_reason = String("")

            var effective_limit = gen_config.max_new_tokens
            if effective_limit <= 0:
                effective_limit = max(1, target_context_len - len(tokens))

            for _ in range(effective_limit):
                if is_cancelled:
                    stop_reason = "cancelled"
                    break
                generated_token_ids.append(next_token)
                current_tokens.append(next_token)

                # EOS is part of the model output contract but never visible text.
                if next_token == self.tokenizer.eos_token_id:
                    stop_reason = "eos"
                    break
                if next_token in gen_config.stop_tokens:
                    stop_reason = "stop_token"
                    break

                var token_text = self.tokenizer.decode(next_token)
                print(" Token generated:", next_token, "'" + token_text + "'")
                response_text += token_text
                if stream_chunks:
                    var chunk_payload = String("{\"model\":\"aesir\",\"response\":\"") + token_text + String("\",\"done\":false}\n")
                    BifrostGate.send_chunk_static(client_fd, chunk_payload)

                var matched_stop_string = False
                for s_idx in range(len(gen_config.stop_strings)):
                    var stop_str = gen_config.stop_strings[s_idx]
                    if stop_str.byte_length() > 0 and stop_str in response_text:
                        stop_reason = "stop_string"
                        var match_pos = response_text.find(stop_str)
                        if match_pos > 0:
                            var sliced_str = String(response_text[codepoint=0:match_pos])
                            response_text = sliced_str
                        else:
                            response_text = String("")
                        matched_stop_string = True
                        break
                if matched_stop_string:
                    break

                var next_position = len(current_tokens) - 1
                stop_reason = generation_stop_reason(
                    next_token,
                    self.tokenizer.eos_token_id,
                    len(generated_token_ids),
                    gen_config,
                    next_position,
                    self.parser.config.context_length,
                )
                if stop_reason != "":
                    break

                # Evaluate exactly the newly generated token at its absolute
                # position to obtain the following greedy token.
                next_token = self._forward_position(
                    current_tokens, kv_cache, next_position, gen_config
                )

            var _decode_span_ns = phase_now_ns() - _decode_t0
            if stop_reason == "":
                stop_reason = "length"

            var _timings = PhaseTimings(
                load_ns=self.load_ns,
                prefill_ns=disjoint_pure_ns(_prefill_span_ns, _sample_after_prefill),
                decode_ns=disjoint_pure_ns(
                    _decode_span_ns, kv_cache.sample_ns_total - _sample_after_prefill
                ),
                sample_ns=kv_cache.sample_ns_total,
                wall_ns=phase_now_ns() - self.created_ns,
                prompt_tokens=len(tokens),
                generated_tokens=len(generated_token_ids),
            )
            var result = GenerationResult(
                generated_token_ids,
                response_text,
                stop_reason,
                len(tokens),
                _timings,
            )
            print("AESIR_TIMING_JSON: " + _timings.to_json())
            print("Generated", result.generated_token_count(), "token(s); stop reason:", stop_reason)
            print("Inference complete. Fate is sealed.")
            self.pool.offset = self.runtime_offset
            return result^
        except e:
            self.pool.offset = self.runtime_offset
            raise e

    def generate_tokens_config(
        mut self, prompt: String, config: GenerationConfig
    ) raises -> GenerationResult:
        """Returns token IDs, decoded text, counts, and a stable stop reason for a given GenerationConfig."""
        return self._run_generation(prompt, config, Int32(-1), False)

    def generate_tokens(
        mut self, prompt: String, max_new_tokens: Int
    ) raises -> GenerationResult:
        """Returns token IDs, decoded text, counts, and a stable stop reason."""
        var config = GenerationConfig(max_new_tokens=max_new_tokens, temperature=0.0, repetition_penalty=1.0)
        return self._run_generation(prompt, config, Int32(-1), False)

    def teacher_forcing_logit_rows(
        mut self, tokens: List[Int]
    ) raises -> List[List[Float32]]:
        """A-045: teacher-forcing logit rows for the CPU parity battery.
        Feeds the GIVEN token sequence position by position through the
        per-token forward path (never the batched prefill, never a chat
        template) with the KVCache logit-row sink on, and returns one
        captured logit row per position: row p is the exact scaled /
        softcapped pre-sampling distribution that predicts tokens[p+1].
        Greedy configuration, repetition penalty 1.0 -- grading only,
        the sampled return values are discarded. Reusable by every
        later backend battery. Standard (llama-family) forward path
        only: the sink lives in core/inference.forward_pass."""
        if len(tokens) == 0:
            raise Error("teacher_forcing_logit_rows: empty token sequence")
        if not self.parser.is_loaded:
            raise Error("teacher_forcing_logit_rows: model not loaded")
        self.pool.offset = self.runtime_offset
        var target_context_len = min(MAX_RUNTIME_CONTEXT, self.parser.config.context_length)
        var kv_cache = KVCache(
            target_context_len,
            self.parser.config.kv_dim(),
            self.pool,
            self.parser.config.block_count,
        )
        kv_cache.capture_logit_row = True
        var config = GenerationConfig(max_new_tokens=1, temperature=0.0, repetition_penalty=1.0)
        var rows = List[List[Float32]]()
        try:
            for pos in range(len(tokens)):
                _ = self._forward_position(tokens, kv_cache, pos, config, False)
                if len(kv_cache.last_logit_row) == 0:
                    raise Error("teacher_forcing_logit_rows: no logit row captured at position " + String(pos))
                rows.append(kv_cache.last_logit_row.copy())
            self.pool.offset = self.runtime_offset
            return rows^
        except e:
            self.pool.offset = self.runtime_offset
            raise e

    def _clear_image_span(mut self):
        self.image_span_start = -1
        self.image_span_rows = List[Float32]()
        self.image_span_width = 0

    def generate_image_chat(
        mut self,
        prompt: String,
        image_path: String,
        config: GenerationConfig,
    ) raises -> GenerationResult:
        """Runs one image + text prompt through the vision tower and
        the language model (design doc section 4, slice 4).

        The prompt carries exactly one <|image|> marker — the gemma4
        canonical template's image spelling, whose id is read from
        this model's own tokenizer. The marker position expands to
        the encoder's soft-token count of sequence positions whose
        embedding rows are the projected encoder output, installed
        through the span override in core.inference; the language
        forward is otherwise unchanged. Fail-closed throughout: a
        missing or repeated marker, a missing mmproj, a tower vs
        language width mismatch, or a token stream whose marker run
        does not equal the encoder row count all raise before any
        forward pass runs."""
        if self.parser.config.architecture == "qwen35":
            raise Error(
                "generate_image_chat: image spans are not supported on the qwen35 path"
            )
        var marker = String("<|image|>")
        var marker_id = self.tokenizer.special_token_id(marker)
        var first = prompt.find(marker)
        if first < 0:
            raise Error("generate_image_chat: prompt carries no <|image|> marker")
        var mlen = marker.byte_length()
        var tail = String(prompt[codepoint=first + mlen:])
        if tail.find(marker) >= 0:
            raise Error(
                "generate_image_chat: exactly one image per prompt in this slice"
            )
        var mmproj_path = find_mmproj_beside(self.parser.file_path)
        if mmproj_path == "":
            raise Error("generate_image_chat: no mmproj found beside the model")
        var mmproj = MmprojFile(mmproj_path)
        var spec = mmproj.vision_spec()
        spec.check_language_match(self.parser.config.embedding_length)
        var rows = encode_image_rows(mmproj_path, image_path)
        var width = self.parser.config.embedding_length
        if width <= 0 or len(rows) == 0 or len(rows) % width != 0:
            raise Error(
                "generate_image_chat: encoder rows do not match the language width"
            )
        var n_soft = len(rows) // width
        var expanded = String(prompt[codepoint=0:first])
        for _ in range(n_soft):
            expanded += marker
        expanded += tail
        var toks = self.tokenizer.encode(expanded, True)
        var span_start = -1
        var run = 0
        for i in range(len(toks)):
            if toks[i] == marker_id:
                if span_start < 0:
                    span_start = i
                run += 1
            elif run > 0 and run < n_soft:
                raise Error("generate_image_chat: image marker run is interrupted")
        if span_start < 0 or run != n_soft:
            raise Error(
                "generate_image_chat: image marker run does not match the encoder row count"
            )
        self.image_span_start = span_start
        self.image_span_rows = rows^
        self.image_span_width = width
        try:
            var result = self._run_generation(expanded, config, Int32(-1), False)
            self._clear_image_span()
            return result^
        except e:
            self._clear_image_span()
            raise e

    def generate(mut self, prompt: String) raises -> String:
        """Compatibility facade for a verified 32-token greedy request."""
        var result = self.generate_tokens(prompt, 32)
        return result.text

    def generate_stream(mut self, prompt: String, client_fd: Int32) raises:
        """
        Runs the autoregressive token generation loop, decoding each sampled token ID
        via RuneWeaver.decode() and streaming it immediately through BifrostGate.send_chunk().
        """
        var config = GenerationConfig(max_new_tokens=32)
        _ = self._run_generation(prompt, config, client_fd, True)
        var done_payload = String("{\"model\":\"aesir\",\"response\":\"\",\"done\":true}\n")
        BifrostGate.send_chunk_static(client_fd, done_payload)
        BifrostGate.close_client_static(client_fd)
        print("Streaming inference complete. Stream closed.")

    def generate_chat(
        mut self,
        messages: List[ChatMessage],
        config: GenerationConfig,
        template_format: String = "chatml",
    ) raises -> GenerationResult:
        """Formats multi-turn ChatMessage turns into a canonical prompt and runs inference."""
        var template = RuneChatTemplate(template_format)
        var formatted_prompt = template.format_chat(messages)
        return self._run_generation(formatted_prompt, config, Int32(-1), False)

    def generate_session(
        mut self,
        mut session: SessionContext,
        prompt: String,
        config: GenerationConfig,
    ) raises -> GenerationResult:
        """Runs generation bound to a SessionContext, checking cancellation status and updating active token counts."""
        session.validate()
        var res = self._run_generation(prompt, config, Int32(-1), False, session.is_cancelled)
        session.active_tokens += res.generated_token_count()
        return res
