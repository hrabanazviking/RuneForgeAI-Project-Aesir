# engine/aesir.mojo
# The central intelligence that unites the components of the Aesir Engine.

from std.math import max
from core.mimir_well import MimirWell, KVCache, MimirStore, RuneTensor, DeviceTopology, NPUBackendType, GPURealmType, f16
from core.inference import forward_pass, TransformerBlock
from core.sampler import RuneRNG, sample_token_from_logits
from core.session import SessionContext, SessionManager
from core.supervisor import SelfHealingSupervisor
from core.state_vault import StateVault
from core.event_bus import AesirEventBus
from core.thread_pool import RuneThreadPool
from core.swarm import SwarmCluster
from loader.gguf import GGUFModelConfig, GGUFSeer
from loader.tokenizer import RuneWeaver
from loader.chat_template import ChatMessage, RuneChatTemplate
from server.api import BifrostGate


def calculate_runtime_pool_bytes(
    config: GGUFModelConfig,
    vocab_size: Int,
    knowledge_capacity: Int,
) -> Int:
    """Derives the F16 workspace size from validated model dimensions."""
    var hidden = config.embedding_length
    var kv_dim = config.kv_dim()
    var converted_norms = (2 * config.block_count + 1) * hidden
    var kv_cache = (
        2 * config.block_count * config.context_length * kv_dim
    )
    var layer_workspace = (
        4 * hidden
        + 2 * kv_dim
        + 2 * config.feed_forward_length
        + vocab_size
    )
    var knowledge_store = max(1, knowledge_capacity) * hidden
    return 2 * (
        converted_norms + kv_cache + layer_workspace + knowledge_store
    )


def validate_runtime_backend_config(
    num_devices: Int,
    enable_npu: Bool,
    enable_gpu_realm: Bool,
) raises:
    """Rejects runtime paths that have no real execution backend."""
    if num_devices != 1:
        raise Error("multi-device engine execution is not implemented")
    if enable_npu:
        raise Error("NPU engine execution is not implemented")
    if enable_gpu_realm:
        raise Error("GPU engine execution is not implemented")


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
        max_new_tokens: Int = 32,
        stop_tokens: List[Int] = List[Int](),
        stop_strings: List[String] = List[String](),
        temperature: Float32 = 0.0,
        top_k: Int = 1,
        top_p: Float32 = 1.0,
        repetition_penalty: Float32 = 1.0,
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
    AesirEngine: Coordinates the Well (Memory), the Seer (Weights), and the Weaver (Tokenizer).
    Strictly decouples inference from the transport (Server) layer.
    Preserves development scaffolds for resilience, eventing, threading, and
    swarm work without claiming those subsystems execute operationally.
    """
    var pool: MimirWell
    var parser: GGUFSeer
    var tokenizer: RuneWeaver
    var knowledge_base: MimirStore
    var topology: DeviceTopology
    var blocks: List[TransformerBlock]
    var enable_npu: Bool
    var target_backend: NPUBackendType
    var enable_gpu_realm: Bool
    var target_gpu_realm: GPURealmType
    var supervisor: SelfHealingSupervisor
    var event_bus: AesirEventBus
    var thread_pool: RuneThreadPool
    var swarm_cluster: SwarmCluster
    var runtime_offset: Int

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
        
        self.blocks = List[TransformerBlock]()
        for layer_idx in range(self.parser.config.block_count):
            self.blocks.append(
                TransformerBlock(
                    layer_idx,
                    self.parser.config.head_dim(),
                    self.parser.config.head_count,
                    self.parser,
                )
            )

    def _prepare_prompt(mut self, prompt: String) raises -> String:
        """Applies the existing optional knowledge context before tokenization."""
        var active_prompt = prompt
        if self.knowledge_base.count > 0:
            var hidden_dim = self.parser.config.embedding_length
            if "token_embd.weight" in self.parser.tensors:
                hidden_dim = self.parser.tensors["token_embd.weight"].cols
            var q_ptr = self.pool.allocate(hidden_dim)
            var query_vector = RuneTensor[f16](1, hidden_dim, q_ptr, False)
            for k in range(hidden_dim):
                query_vector.data.unsafe_store(k, Scalar[f16](0.1))
            var docs = self.knowledge_base.search_knn(query_vector, 3)
            if len(docs) > 0:
                var context_str = String("[CONTEXT]: ")
                for i in range(len(docs)):
                    if i > 0:
                        context_str += String(" ")
                    context_str += docs[i]
                active_prompt = context_str + String("\n") + prompt
                print("RAG Context Augmented:", context_str)
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
        if not self.parser.is_loaded:
            raise Error("AesirEngine cannot generate without a validated GGUF model")
        config.validate(self.parser.config.context_length)

        print("Starting deterministic generation loop (The Weaving of Fate)...")

        try:
            self.pool.offset = self.runtime_offset
            var active_prompt = self._prepare_prompt(prompt)

            var tokens = self.tokenizer.encode(active_prompt, True)
            if len(tokens) == 0:
                raise Error("RuneWeaver produced no prompt tokens")
            if len(tokens) > self.parser.config.context_length:
                raise Error("Prompt token count exceeds the model context length")

            # One request owns one KV cache. forward_pass() reclaims only its
            # temporary workspace, leaving these cached positions intact.
            self.pool.offset = self.runtime_offset
            var kv_cache = KVCache(
                self.parser.config.context_length,
                self.parser.config.kv_dim(),
                self.pool,
                self.parser.config.block_count,
            )
            var next_token = 0
            for position in range(len(tokens)):
                next_token = forward_pass(
                    tokens,
                    self.parser,
                    self.pool,
                    kv_cache,
                    position,
                    self.parser.config.block_count,
                    self.parser.config.head_dim(),
                    self.parser.config.head_count,
                    self.topology,
                    self.blocks,
                    self.enable_npu,
                    self.target_backend,
                    self.enable_gpu_realm,
                    self.target_gpu_realm,
                )

            var current_tokens = tokens.copy()
            var generated_token_ids = List[Int]()
            var response_text = String("")
            var stop_reason = String("")

            for _ in range(config.max_new_tokens):
                if is_cancelled:
                    stop_reason = "cancelled"
                    break
                generated_token_ids.append(next_token)
                current_tokens.append(next_token)

                # EOS is part of the model output contract but never visible text.
                if next_token == self.tokenizer.eos_token_id:
                    stop_reason = "eos"
                    break
                if next_token in config.stop_tokens:
                    stop_reason = "stop_token"
                    break

                var token_text = self.tokenizer.decode(next_token)
                response_text += token_text
                if stream_chunks:
                    var chunk_payload = String("{\"model\":\"aesir\",\"response\":\"") + token_text + String("\",\"done\":false}\n")
                    BifrostGate.send_chunk_static(client_fd, chunk_payload)

                var matched_stop_string = False
                for s_idx in range(len(config.stop_strings)):
                    var stop_str = config.stop_strings[s_idx]
                    if stop_str in response_text:
                        stop_reason = "stop_string"
                        var match_pos = response_text.find(stop_str)
                        if match_pos >= 0:
                            var truncated = String(response_text[byte=0 : match_pos])
                            response_text = truncated
                        matched_stop_string = True
                        break
                if matched_stop_string:
                    break

                var next_position = len(current_tokens) - 1
                stop_reason = generation_stop_reason(
                    next_token,
                    self.tokenizer.eos_token_id,
                    len(generated_token_ids),
                    config,
                    next_position,
                    self.parser.config.context_length,
                )
                if stop_reason != "":
                    break

                # Evaluate exactly the newly generated token at its absolute
                # position to obtain the following greedy token.
                next_token = forward_pass(
                    current_tokens,
                    self.parser,
                    self.pool,
                    kv_cache,
                    next_position,
                    self.parser.config.block_count,
                    self.parser.config.head_dim(),
                    self.parser.config.head_count,
                    self.topology,
                    self.blocks,
                    self.enable_npu,
                    self.target_backend,
                    self.enable_gpu_realm,
                    self.target_gpu_realm,
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
        var config = GenerationConfig(max_new_tokens=max_new_tokens)
        return self._run_generation(prompt, config, Int32(-1), False)

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
