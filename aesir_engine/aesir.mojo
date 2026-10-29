# engine/aesir.mojo
# The central intelligence that unites the components of the Aesir Engine.

from std.math import max, min
from core.mimir_well import MimirWell, KVCache, MimirStore, RuneTensor, DeviceTopology, NPUBackendType, GPURealmType, f16, f32
from core.inference import forward_pass, forward_pass_batched, TransformerBlock, Qwen35Block, Qwen35State, forward_pass_qwen35, forward_pass_qwen35_batched
from core.parallel import _env_int
from core.sampler import RuneRNG, sample_token_from_logits
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
from core.runtime_plan import NativeModelPlan, NativeCUDASelection, choose_native_cuda, choose_native_cuda_plan, explain_host_fit
from core.inference_memory import MemoryFitExplanation, llama3_memory_plan
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

    def __init__(
        out self,
        token_ids: List[Int],
        text: String,
        stop_reason: String,
        prompt_token_count: Int,
    ):
        self.token_ids = token_ids.copy()
        self.text = text
        self.stop_reason = stop_reason
        self.prompt_token_count = prompt_token_count

    def __copyinit__(out self, existing: Self):
        self.token_ids = existing.token_ids.copy()
        self.text = existing.text
        self.stop_reason = existing.stop_reason
        self.prompt_token_count = existing.prompt_token_count

    @always_inline
    def copy(self) -> Self:
        return Self(
            self.token_ids.copy(),
            self.text,
            self.stop_reason,
            self.prompt_token_count,
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
    var qwen35_state: Qwen35State
    var enable_npu: Bool
    var target_backend: NPUBackendType
    var enable_gpu_realm: Bool
    var target_gpu_realm: GPURealmType
    var supervisor: SelfHealingSupervisor
    var event_bus: AesirEventBus
    var thread_pool: RuneThreadPool
    var swarm_cluster: SwarmCluster
    var runtime_offset: Int
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
    ) raises:
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
        if self.parser.config.architecture != "qwen35":
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
                    )
                )
            var fai = self.parser.config.full_attention_interval
            if fai <= 0:
                fai = 4
            qwen35_ssm_layers = (
                self.parser.config.block_count
                - self.parser.config.block_count // fai
            )
        self.qwen35_state = Qwen35State(
            qwen35_ssm_layers,
            self.parser.config.ssm_group_count,
            self.parser.config.ssm_state_size,
            3 * self.parser.config.ssm_inner_size,
            self.parser.config.ssm_conv_kernel,
        )

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
        )

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

            if stop_reason == "":
                stop_reason = "length"

            var result = GenerationResult(
                generated_token_ids,
                response_text,
                stop_reason,
                len(tokens),
            )
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
