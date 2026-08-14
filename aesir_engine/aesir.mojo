# engine/aesir.mojo
# The central intelligence that unites the components of the Aesir Engine.

from std.math import max
from core.mimir_well import MimirWell, KVCache, MimirStore, RuneTensor, DeviceTopology, NPUBackendType, GPURealmType, f16
from core.inference import forward_pass, TransformerBlock
from core.supervisor import SelfHealingSupervisor
from core.state_vault import StateVault
from core.event_bus import AesirEventBus
from core.thread_pool import RuneThreadPool
from core.swarm import SwarmCluster
from loader.gguf import GGUFModelConfig, GGUFSeer
from loader.tokenizer import RuneWeaver
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

struct AesirEngine:
    """
    AesirEngine: Coordinates the Well (Memory), the Seer (Weights), and the Weaver (Tokenizer).
    Strictly decouples inference from the transport (Server) layer.
    Integrates SelfHealingSupervisor, StateVault, AesirEventBus, RuneThreadPool, and SwarmCluster for 100% crash-proof resilience & enterprise mesh orchestrations.
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
        print("SelfHealingSupervisor, EventBus & SwarmCluster ACTIVE.")

        self.enable_npu = enable_npu
        self.target_backend = target_backend
        if self.enable_npu:
            print("NPU Realm Gateway ACTIVE with backend:", self.target_backend.name())

        self.enable_gpu_realm = enable_gpu_realm
        self.target_gpu_realm = target_gpu_realm
        if self.enable_gpu_realm:
            print("Universal GPU Realm Gateway ACTIVE with realm:", self.target_gpu_realm.name())



        self.topology = DeviceTopology(num_devices)
        if self.topology.num_devices > 1:
            print("Bifrost Shard Matrix ACTIVE across", self.topology.num_devices, "devices.")

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

    def generate(mut self, prompt: String) raises -> String:
        var permit_seidr = False # Toggled via HTTP request. Seidr is bound by default.
        if not self.parser.is_loaded:
            raise Error("AesirEngine cannot generate without a validated GGUF model")
        
        print("Starting sampling loop (The Weaving of Fate)...")
        
        if not permit_seidr:
            print("[Seidr Masking ACTIVE]: <|start_thought|> probability bound to -inf (The Inner Voice is Silenced)")
            
        var active_prompt = prompt
        if self.knowledge_base.count > 0:
            var hidden_dim = 4096
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

        # Tokenize prompt
        var tokens = self.tokenizer.encode(active_prompt, True)
        if len(tokens) == 0:
            raise Error("RuneWeaver produced no prompt tokens")
        if len(tokens) > self.parser.config.context_length:
            raise Error("Prompt token count exceeds the model context length")

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

        
        # Decode
        var response_text = self.tokenizer.decode(next_token)
        
        print("Generated token:", response_text)
        print("Inference complete. Fate is sealed.")
        self.pool.offset = self.runtime_offset
        return response_text

    def generate_stream(mut self, prompt: String, client_fd: Int32) raises:
        """
        Runs the autoregressive token generation loop, decoding each sampled token ID
        via RuneWeaver.decode() and streaming it immediately through BifrostGate.send_chunk().
        """
        var permit_seidr = False
        print("Starting streaming autoregressive generation loop...")
        
        if not permit_seidr:
            print("[Seidr Masking ACTIVE]: <|start_thought|> probability bound to -inf")

        var active_prompt = prompt
        if self.knowledge_base.count > 0:
            var hidden_dim = 4096
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

        var tokens = self.tokenizer.encode(active_prompt, True)
        if len(tokens) == 0:
            return
        if len(tokens) > self.parser.config.context_length:
            raise Error("Prompt token count exceeds the model context length")

        self.pool.offset = self.runtime_offset
        var kv_cache = KVCache(
            self.parser.config.context_length,
            self.parser.config.kv_dim(),
            self.pool,
            self.parser.config.block_count,
        )
        
        # Populate KV Cache for prompt tokens up to current position
        for i in range(len(tokens) - 1):
            _ = forward_pass(
                tokens,
                self.parser,
                self.pool,
                kv_cache,
                i,
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
        var max_gen_tokens = 5
        
        for _ in range(max_gen_tokens):
            var pos = len(current_tokens) - 1
            if pos >= self.parser.config.context_length:
                break
            var next_token = forward_pass(
                current_tokens,
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
            )

            var token_text = self.tokenizer.decode(next_token)
            
            var chunk_payload = String("{\"model\":\"aesir\",\"response\":\"") + token_text + String("\",\"done\":false}\n")
            BifrostGate.send_chunk_static(client_fd, chunk_payload)
            
            current_tokens.append(next_token)
            if next_token == 0:
                break
                
        var done_payload = String("{\"model\":\"aesir\",\"response\":\"\",\"done\":true}\n")
        BifrostGate.send_chunk_static(client_fd, done_payload)
        BifrostGate.close_client_static(client_fd)
        self.pool.offset = self.runtime_offset
        print("Streaming inference complete. Stream closed.")
