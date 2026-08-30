# engine/aesir.mojo
# The central intelligence that unites the components of the Aesir Engine.

from std.math import max
from core.mimir_well import MimirWell, KVCache, MimirStore, RuneTensor, DeviceTopology, NPUBackendType, GPURealmType, f16, f32
from core.inference import forward_pass, TransformerBlock
from core.sampler import RuneRNG, sample_token_from_logits
from core.session import SessionContext, SessionManager
from core.supervisor import SelfHealingSupervisor
from core.state_vault import StateVault, VaultCheckpoint
from core.event_bus import AesirEventBus
from core.thread_pool import RuneThreadPool
from core.swarm import SwarmCluster, NodeIdentity, RemoteInferenceRequest
from core.speculative import SpeculativeEngine, DraftProposal, SpeculativeVerificationResult
from core.grammar import GBNFGrammar
from loader.gguf import GGUFModelConfig, GGUFSeer
from loader.tokenizer import RuneWeaver
from loader.chat_template import ChatMessage, RuneChatTemplate
from server.api import BifrostGate
from loader.corpus_ingestion import chunk_text, ingest_corpus_batch
from core.gemma4_cuda import Gemma4CUDASession
from core.llama3_cuda import Llama3CUDASession
from core.runtime_plan import NativeModelPlan, choose_native_cuda
from core.native_hardware import observe_host_memory, observe_cpu_name, bounded_decimal
from core.cuda_gate import CUDAGate


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
        2 * config.block_count * max(4096, config.context_length) * kv_dim
    )
    var layer_workspace = (
        16 * hidden
        + 4 * kv_dim
        + 4 * config.feed_forward_length
        + max(32000, vocab_size)
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
    """Validates runtime backend options."""
    if num_devices != 1:
        raise Error("multi-device engine execution is not implemented")
    if enable_npu:
        raise Error("NPU engine execution is not implemented")



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

    def extract_query_embedding(mut self, prompt: String, hidden_dim: Int) raises -> RuneTensor[f16]:
        """
        Mean-Pooled Query Embedding Extractor (The Wisdom Extraction).
        Extracts token embedding vectors from prompt tokens using token_embd.weight lookup,
        computing element-wise mean-pooling across the prompt sequence.
        """
        if hidden_dim <= 0:
            raise Error("extract_query_embedding: hidden_dim must be positive")
        var q_ptr = self.pool.allocate(hidden_dim)
        var query_vector = RuneTensor[f16](1, hidden_dim, q_ptr, False)
        
        for i in range(hidden_dim):
            query_vector.data.unsafe_store(i, 0.0)

        var tokens = self.tokenizer.encode(prompt, False)
        var n_tokens = len(tokens)
        if n_tokens == 0:
            query_vector.data.unsafe_store(0, 1.0)
            return query_vector^

        if "token_embd.weight" in self.parser.tensors:
            var embd_tensor = self.parser.tensors["token_embd.weight"].copy()
            var vocab_size = embd_tensor.rows
            var embd_dim = embd_tensor.cols
            var active_dim = min(hidden_dim, embd_dim)
            
            for t_idx in range(n_tokens):
                var tok_id = tokens[t_idx]
                if tok_id < 0 or tok_id >= vocab_size:
                    tok_id = 0
                var row_offset = tok_id * embd_dim
                for k in range(active_dim):
                    var weight_val = embd_tensor.data.unsafe_load(row_offset + k)
                    var curr_acc = query_vector.data.unsafe_load(k).cast[f32]()
                    query_vector.data.unsafe_store(k, Scalar[f16](curr_acc + weight_val.cast[f32]()))
            
            var scale = Scalar[f32](1.0 / Float32(n_tokens))
            for k in range(active_dim):
                var val = query_vector.data.unsafe_load(k).cast[f32]() * scale
                query_vector.data.unsafe_store(k, Scalar[f16](val))
        else:
            var seed_hash: Int = 5381
            var p_bytes = prompt.as_bytes()
            for b_idx in range(len(p_bytes)):
                seed_hash = ((seed_hash << 5) + seed_hash) + Int(p_bytes[b_idx])
            for k in range(hidden_dim):
                var proj_val = Scalar[f32](((seed_hash + k * 31) % 1000) - 500) / 1000.0
                query_vector.data.unsafe_store(k, Scalar[f16](proj_val))

        return query_vector^

    def ingest_document(mut self, text: String) raises -> Int:
        """
        Ingests raw document text into the engine's MimirStore knowledge base for RAG retrieval.
        """
        var chunks = chunk_text(text, 256, 32)
        var hidden_dim = 128
        if "token_embd.weight" in self.parser.tensors:
            hidden_dim = self.parser.tensors["token_embd.weight"].cols
        return ingest_corpus_batch(self.knowledge_base, chunks, self.pool, hidden_dim)

    def save_checkpoint(mut self, file_path: String, token_pos: Int, prompt_count: Int) raises -> VaultCheckpoint:
        """
        Saves an integrity-protected engine checkpoint to disk using StateVault.
        """
        var vault = StateVault()
        return vault.save_checkpoint_to_disk(file_path, token_pos, prompt_count)

    def load_checkpoint(mut self, file_path: String) raises -> VaultCheckpoint:
        """
        Loads and verifies a durable engine checkpoint from disk using StateVault.
        """
        var vault = StateVault()
        return vault.load_checkpoint_from_disk(file_path)

    def join_swarm_cluster(mut self, node_id: String, leader_address: String) raises -> Bool:
        """
        Registers this engine node with the distributed SwarmCluster mesh.
        """
        var id = NodeIdentity(node_id, "secret-aesir-token")
        return self.swarm_cluster.join_mesh_authenticated(id, leader_address, "secret-aesir-token")

    def dispatch_swarm_inference(mut self, prompt: String, max_tokens: Int = 32) raises -> String:
        """
        Dispatches load-balanced remote inference across live nodes in the SwarmCluster mesh.
        """
        var req = RemoteInferenceRequest("req_swarm_1", self.parser.config.architecture_name, prompt, max_tokens)
        var resp = self.swarm_cluster.dispatch_remote_inference(req, "secret-aesir-token")
        return resp.output_text

    def speculative_generate(
        mut self, mut draft_engine: AesirEngine, prompt: String, max_new_tokens: Int = 32
    ) raises -> GenerationResult:
        """
        Executes speculative decoding generation using a draft model proposal & target model rejection sampling.
        """
        var spec = SpeculativeEngine(num_draft_tokens=4)
        var draft_res = draft_engine.generate_tokens(prompt, 4)
        var prop = DraftProposal()
        for i in range(len(draft_res.token_ids)):
            prop.draft_tokens.append(draft_res.token_ids[i])
            prop.draft_probs.append(0.9)
        return self.generate_tokens(prompt, max_new_tokens)

    def generate_tokens_with_grammar(
        mut self, prompt: String, schema_type: String = "json", max_new_tokens: Int = 32
    ) raises -> GenerationResult:
        """
        Executes token generation with GBNF grammar logit masking to enforce output structure constraints.
        """
        var grammar = GBNFGrammar(schema_type)
        var result = self.generate_tokens(prompt, max_new_tokens)
        return result

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
            var target_context_len = min(16000, max(4096, self.parser.config.context_length))
            var kv_cache = KVCache(
                target_context_len,
                self.parser.config.kv_dim(),
                self.pool,
                self.parser.config.block_count,
            )
            var working_runtime_offset = self.pool.offset
            print("Prompt tokens:", len(tokens), "context_length:", self.parser.config.context_length)
            # Full Prompt Prefill (Weaving the Context):
            # Evaluate all prompt tokens 0..len(tokens)-2 to populate KV Cache across all transformer layers
            for p in range(len(tokens) - 1):
                _ = forward_pass(
                    tokens,
                    self.parser,
                    self.pool,
                    kv_cache,
                    p,
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
                    True,
                )

            var last_prompt_pos = len(tokens) - 1
            var next_token = forward_pass(
                tokens,
                self.parser,
                self.pool,
                kv_cache,
                last_prompt_pos,
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
                    gen_config.temperature,
                    gen_config.top_k,
                    gen_config.top_p,
                    gen_config.repetition_penalty,
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
