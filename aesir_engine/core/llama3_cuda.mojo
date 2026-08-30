"""Persistent native CUDA inference for the admitted Llama 3 8B GGUF profile."""
from max.gpu.host import DeviceContext, DeviceBuffer, HostBuffer
from std.memory import unsafe_memcpy
from loader.packed_gguf import PackedGGUF
from loader.llama3_tokenizer import Llama3Tokenizer
from loader.tokenizer import RuneStreamDecoder
from core.gemma4_kernels import Bytes, Floats, embedding_kernel, matvec_kernel, norm_kernel, element_kernel, argmax_kernel
from core.llama3_kernels import Halves, llama_rope, llama_silu, llama_cache, llama_scores, llama_softmax, llama_attention

comptime X = 0
comptime N = X + 4096
comptime Q = N + 4096
comptime K = Q + 4096
comptime V = K + 1024
comptime ATT = V + 1024
comptime TEMP = ATT + 4096
comptime UP = TEMP + 4096
comptime GATE = UP + 14336
comptime LOGITS = GATE + 14336
comptime SCORES = LOGITS + 128256


def validate_llama3(model: PackedGGUF, context_length: Int) raises:
    if model.text("general.architecture") != "llama":
        raise Error("Native Llama 3 CUDA requires llama architecture")
    var keys: List[String] = ["block_count", "embedding_length", "feed_forward_length", "attention.head_count", "attention.head_count_kv", "rope.dimension_count"]
    var values: List[Int] = [32, 4096, 14336, 32, 8, 128]
    for i in range(len(keys)):
        if model.integer("llama." + keys[i]) != values[i]:
            raise Error("Unsupported Llama 3 8B metadata: " + keys[i])
    if context_length < 2 or context_length > min(8192, model.integer("llama.context_length")):
        raise Error("Llama 3 CUDA context must be within 2..8192 tokens")
    if model.floating("llama.rope.freq_base") != 500000 or model.floating("llama.attention.layer_norm_rms_epsilon") != Float32(1e-5):
        raise Error("Unsupported Llama 3 RoPE or normalization")
    if "llama.rope.scaling.type" in model.fields and model.text("llama.rope.scaling.type") != "none":
        raise Error("Scaled Llama RoPE is not supported")
    _ = model.require_tensor("token_embd.weight", 4096, 128256)
    _ = model.require_tensor("output.weight", 4096, 128256)
    _ = model.require_tensor("output_norm.weight", 4096)
    for layer in range(32):
        var prefix = "blk." + String(layer) + "."
        _ = model.require_tensor(prefix + "attn_norm.weight", 4096)
        _ = model.require_tensor(prefix + "ffn_norm.weight", 4096)
        _ = model.require_tensor(prefix + "attn_q.weight", 4096, 4096)
        _ = model.require_tensor(prefix + "attn_k.weight", 4096, 1024)
        _ = model.require_tensor(prefix + "attn_v.weight", 4096, 1024)
        _ = model.require_tensor(prefix + "attn_output.weight", 4096, 4096)
        _ = model.require_tensor(prefix + "ffn_gate.weight", 4096, 14336)
        _ = model.require_tensor(prefix + "ffn_up.weight", 4096, 14336)
        _ = model.require_tensor(prefix + "ffn_down.weight", 14336, 4096)
    # Exactly the dense bias-free profile; do not silently ignore extra tensors.
    if len(model.tensors) != 291:
        raise Error("Unsupported Llama 3 tensor set")
    for name in model.tensors.keys():
        var t = model.tensors[name]
        if t.rows == 1 and t.kind != 0:
            raise Error("Llama normalization tensors must be F32")


struct Llama3CUDASession:
    var model: PackedGGUF
    var tokenizer: Llama3Tokenizer
    var context: DeviceContext
    var weights: DeviceBuffer[DType.uint8]
    var activations: DeviceBuffer[DType.float32]
    var cache: DeviceBuffer[DType.float16]
    var output: DeviceBuffer[DType.int32]
    var host_output: HostBuffer[DType.int32]
    var context_length: Int
    var position: Int
    var healthy: Bool
    var generating: Bool
    var generated_tokens: Int
    var prompt_tokens: Int
    var max_new_tokens: Int
    var pending_token: Int
    var finish_reason: String
    var decoder: RuneStreamDecoder

    def __init__(out self, path: String, context_length: Int = 8192) raises:
        self.model = PackedGGUF(path)
        validate_llama3(self.model, context_length)
        self.tokenizer = Llama3Tokenizer(self.model)
        self.context_length = context_length
        self.position = 0
        self.healthy = True
        self.generating = False
        self.generated_tokens = 0
        self.prompt_tokens = 0
        self.max_new_tokens = 0
        self.pending_token = -1
        self.finish_reason = ""
        self.decoder = RuneStreamDecoder()
        self.context = DeviceContext(0, api="cuda")
        if self.context.api() != "cuda" or not self.context.is_compatible():
            raise Error("A compatible NVIDIA CUDA device is required; no CPU fallback")
        self.weights = self.context.enqueue_create_buffer[DType.uint8](Int(self.model.source.file_size))
        self.activations = self.context.enqueue_create_buffer[DType.float32](SCORES + 32 * context_length)
        self.cache = self.context.enqueue_create_buffer[DType.float16](32 * 2 * context_length * 1024)
        self.output = self.context.enqueue_create_buffer[DType.int32](1)
        self.host_output = self.context.enqueue_create_host_buffer[DType.int32](1)
        var staging = self.context.enqueue_create_host_buffer[DType.uint8](Int(self.model.source.file_size))
        unsafe_memcpy(dest=staging.unsafe_ptr(), src=self.model.source.mmap_ptr.unsafe_bitcast[UInt8](), count=Int(self.model.source.file_size))
        self.context.enqueue_copy(self.weights, staging)
        self.context.synchronize()
        print("[CUDA] native Mojo Llama3; device=0 api=cuda layers=32/32 weights_bytes=" + String(self.model.source.file_size) + " kv_bytes=" + String(32 * 2 * context_length * 1024 * 2) + " context=" + String(context_length) + " cpu_offload=0")

    def w(self) -> Bytes:
        return Bytes(unsafe_from_address=Int(self.weights.unsafe_ptr()))

    def a(self) -> Floats:
        return Floats(unsafe_from_address=Int(self.activations.unsafe_ptr()))

    def kv(self) -> Halves:
        return Halves(unsafe_from_address=Int(self.cache.unsafe_ptr()))

    def matvec(self, name: String, src: Int, dst: Int) raises:
        var t = self.model.tensors[name]
        self.context.enqueue_function[matvec_kernel](self.w(), self.a(), Int64(t.offset), Int64(t.kind), Int64(t.columns), Int64(t.rows), Int64(src), Int64(dst), grid_dim=(t.rows * 32 + 127) // 128, block_dim=128)

    def norm(self, name: String, src: Int, dst: Int) raises:
        self.context.enqueue_function[norm_kernel](self.w(), self.a(), Int64(self.model.tensors[name].offset), Int64(src), Int64(dst), Int64(4096), Int64(1), Float32(1e-5), Float32(1), grid_dim=1, block_dim=128)

    def residual(self) raises:
        self.context.enqueue_function[element_kernel](self.w(), self.a(), Int64(1), Int64(X), Int64(TEMP), Int64(X), Int64(4096), Float32(1), grid_dim=32, block_dim=128)

    def forward(mut self, token: Int, need_logits: Bool = True) raises -> Int:
        if not self.healthy:
            raise Error("CUDA session cannot be reused after an execution failure")
        if token < 0 or token >= 128256 or self.position >= self.context_length:
            raise Error("Llama 3 token/context bound exceeded")
        self.healthy = False
        var embedding = self.model.tensors["token_embd.weight"]
        self.context.enqueue_function[embedding_kernel](self.w(), self.a(), Int64(embedding.offset), Int64(embedding.kind), Int64(4096), Int64(token), Int64(X), Float32(1), grid_dim=32, block_dim=128)
        for layer in range(32):
            var prefix = "blk." + String(layer) + "."
            var offset = layer * 2 * self.context_length * 1024
            self.norm(prefix + "attn_norm.weight", X, N)
            self.matvec(prefix + "attn_q.weight", N, Q)
            self.matvec(prefix + "attn_k.weight", N, K)
            self.matvec(prefix + "attn_v.weight", N, V)
            self.context.enqueue_function[llama_rope](self.a(), Int64(Q), Int64(32), Int64(self.position), grid_dim=16, block_dim=128)
            self.context.enqueue_function[llama_rope](self.a(), Int64(K), Int64(8), Int64(self.position), grid_dim=4, block_dim=128)
            self.context.enqueue_function[llama_cache](self.a(), self.kv(), Int64(K), Int64(V), Int64(offset), Int64(self.context_length), Int64(self.position), grid_dim=8, block_dim=128)
            var count = self.position + 1
            self.context.enqueue_function[llama_scores](self.a(), self.kv(), Int64(Q), Int64(SCORES), Int64(offset), Int64(count), grid_dim=8 * count, block_dim=128)
            self.context.enqueue_function[llama_softmax](self.a(), Int64(SCORES), Int64(count), grid_dim=8, block_dim=128)
            self.context.enqueue_function[llama_attention](self.a(), self.kv(), Int64(SCORES), Int64(ATT), Int64(offset), Int64(self.context_length), Int64(count), grid_dim=32, block_dim=128)
            self.matvec(prefix + "attn_output.weight", ATT, TEMP)
            self.residual()
            self.norm(prefix + "ffn_norm.weight", X, N)
            self.matvec(prefix + "ffn_gate.weight", N, GATE)
            self.matvec(prefix + "ffn_up.weight", N, UP)
            self.context.enqueue_function[llama_silu](self.a(), Int64(GATE), Int64(UP), Int64(14336), grid_dim=112, block_dim=128)
            self.matvec(prefix + "ffn_down.weight", UP, TEMP)
            self.residual()
        var result = -1
        if need_logits:
            self.norm("output_norm.weight", X, N)
            self.matvec("output.weight", N, LOGITS)
            self.context.enqueue_function[argmax_kernel](self.a(), self.output.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), Int64(LOGITS), Int64(128256), grid_dim=1, block_dim=32)
            self.context.enqueue_copy(self.host_output, self.output)
            self.context.synchronize()
            result = Int(self.host_output[0])
            if result < 0 or result >= 128256:
                raise Error("Llama 3 CUDA produced non-finite logits")
        else:
            self.context.synchronize()
        self.position += 1
        self.healthy = True
        return result

    def begin_turn(mut self, prompt: String, system: String, max_tokens: Int) raises:
        if not self.healthy or self.generating:
            raise Error("CUDA session is busy or unusable")
        if prompt.byte_length() == 0 or prompt.byte_length() > 65536 or system.byte_length() > 65536:
            raise Error("Chat text exceeds admission bounds")
        if max_tokens < 1 or max_tokens > 8192:
            raise Error("Llama 3 completion ceiling must be within 1..8192")
        var tokens = List[Int]()
        if self.position == 0:
            tokens.append(self.tokenizer.vocabulary.bos_token_id)
            if system != "":
                self.tokenizer.append_message(tokens, "system", system)
        self.tokenizer.append_message(tokens, "user", prompt)
        self.tokenizer.append_header(tokens, "assistant")
        if len(tokens) + 2 > self.context_length - self.position:
            raise Error("Llama 3 context cannot fit prompt, response and closing token; history was not truncated")
        self.prompt_tokens = len(tokens)
        self.generated_tokens = 0
        self.max_new_tokens = max_tokens
        self.finish_reason = ""
        self.decoder = RuneStreamDecoder()
        for i in range(len(tokens)):
            self.pending_token = self.forward(tokens[i], i == len(tokens) - 1)
        self.generating = True

    def next_chunk(mut self) raises -> String:
        if not self.generating:
            raise Error("No active CUDA generation")
        var token = self.pending_token
        if token == 128001 or token == 128009:
            _ = self.forward(token, False)
            self.finish_reason = "eos"
            self.generating = False
            return self.decoder.flush()
        var chunk = self.tokenizer.decode(token, self.decoder)
        self.generated_tokens += 1
        var limit = self.generated_tokens >= self.max_new_tokens
        var full = self.position + 2 >= self.context_length
        self.pending_token = self.forward(token, not limit and not full)
        if limit or full:
            _ = self.forward(128009, False)
            self.finish_reason = "context_exhausted" if full else "length"
            self.generating = False
            chunk += self.decoder.flush()
        return chunk
