"""A persistent native Mojo CUDA session for dense, text-only Gemma 4 E4B."""
from max.gpu.host import DeviceContext, DeviceBuffer, HostBuffer
from std.math import sqrt
from loader.packed_gguf import PackedGGUF, PackedTensor
from loader.gemma4_tokenizer import Gemma4Tokenizer
from loader.tokenizer import RuneStreamDecoder
from core.inference_memory import gemma4_memory_plan
from core.cuda_sampling import NativeCUDASampler
from core.cuda_upload import upload_cuda_bytes
from core.sampling_config import NativeSamplingConfig
from core.generation_control import GenerationControl, NativeGenerationStatus, ControlledTextSession
from core.gemma4_kernels import (
    Bytes, Floats, embedding_kernel, matvec_kernel, norm_kernel,
    element_kernel, rope_kernel, cache_kernel, scores_kernel,
    softmax_kernel, attention_kernel, argmax_kernel,
)

# Disjoint regions within the session's device-only activation arena.
comptime X = 0
comptime N = 2560
comptime Q = 5120
comptime K = 9216
comptime V = 10240
comptime ATT = 11264
comptime TEMP = 15360
comptime UP = 17920
comptime GATE = 28160
comptime PLE = 38400
comptime PLE_TEMP = 49152
comptime LOGITS = 59904
comptime SCORES = LOGITS + 262144


def validate_gemma4(model: PackedGGUF, context_length: Int) raises:
    if model.text("general.architecture") != "gemma4":
        raise Error("Native CUDA session requires dense Gemma 4 E4B")
    var keys: List[String] = ["block_count", "embedding_length", "feed_forward_length", "attention.head_count", "attention.head_count_kv", "attention.key_length", "attention.value_length", "attention.key_length_swa", "attention.value_length_swa", "attention.sliding_window", "attention.shared_kv_layers", "embedding_length_per_layer_input", "rope.dimension_count", "rope.dimension_count_swa"]
    var values: List[Int] = [42, 2560, 10240, 8, 2, 512, 512, 256, 256, 512, 18, 256, 512, 256]
    for i in range(len(keys)):
        if model.integer("gemma4." + keys[i]) != values[i]:
            raise Error("Unsupported Gemma 4 E4B metadata: " + keys[i])
    if context_length < 1 or context_length > min(32768, model.integer("gemma4.context_length")):
        raise Error("Gemma 4 CUDA context must be within 1..32768 tokens")
    if model.floating("gemma4.rope.freq_base") != 1000000 or model.floating("gemma4.rope.freq_base_swa") != 10000 or model.floating("gemma4.final_logit_softcapping") != 30:
        raise Error("Unsupported Gemma 4 RoPE or logit scale")
    if model.floating("gemma4.attention.layer_norm_rms_epsilon") != Float32(1e-6):
        raise Error("Unsupported Gemma 4 normalization epsilon")
    var pattern = model.array_offset("gemma4.attention.sliding_window_pattern", 7)
    if model.source._read_u64(pattern + 4) != 42:
        raise Error("Gemma 4 sliding-window pattern length mismatch")
    for layer in range(42):
        if Bool(model.source.mmap_ptr.unsafe_load(pattern + 12 + layer)) != (layer % 6 != 5):
            raise Error("Unsupported Gemma 4 sliding-window pattern")
    _ = model.require_tensor("token_embd.weight", 2560, 262144)
    _ = model.require_tensor("per_layer_token_embd.weight", 10752, 262144)
    _ = model.require_tensor("per_layer_model_proj.weight", 2560, 10752)
    _ = model.require_tensor("per_layer_proj_norm.weight", 256)
    _ = model.require_tensor("output_norm.weight", 2560)
    _ = model.require_tensor("rope_freqs.weight", 256)
    for layer in range(42):
        var prefix = "blk." + String(layer) + "."
        var width = 256 if layer % 6 != 5 else 512
        _ = model.require_tensor(prefix + "attn_q.weight", 2560, width * 8)
        _ = model.require_tensor(prefix + "attn_output.weight", width * 8, 2560)
        _ = model.require_tensor(prefix + "attn_q_norm.weight", width)
        if layer < 24:
            _ = model.require_tensor(prefix + "attn_k.weight", 2560, width * 2)
            _ = model.require_tensor(prefix + "attn_v.weight", 2560, width * 2)
            _ = model.require_tensor(prefix + "attn_k_norm.weight", width)
        var norms: List[String] = ["attn_norm", "post_attention_norm", "ffn_norm", "post_ffw_norm", "post_norm"]
        for norm in norms:
            _ = model.require_tensor(prefix + norm + ".weight", 2560)
        _ = model.require_tensor(prefix + "ffn_up.weight", 2560, 10240)
        _ = model.require_tensor(prefix + "ffn_gate.weight", 2560, 10240)
        _ = model.require_tensor(prefix + "ffn_down.weight", 10240, 2560)
        _ = model.require_tensor(prefix + "inp_gate.weight", 2560, 256)
        _ = model.require_tensor(prefix + "proj.weight", 256, 2560)
        _ = model.require_tensor(prefix + "layer_output_scale.weight", 1)
        if prefix + "ffn_gate_inp.weight" in model.tensors:
            raise Error("Gemma 4 MoE is not supported by the dense CUDA path")
    # Vector kernels consume F32 weights, so reject other storage explicitly.
    for name in model.tensors.keys():
        var t = model.tensors[name]
        if t.rows == 1 and t.kind != 0:
            raise Error("Gemma 4 norm/scale tensors must be F32: " + name)
    if "output.weight" in model.tensors:
        raise Error("This Gemma 4 CUDA profile requires tied output embeddings")


struct Gemma4CUDASession(ControlledTextSession):
    var model: PackedGGUF
    var tokenizer: Gemma4Tokenizer
    var context: DeviceContext
    var weights: DeviceBuffer[DType.uint8]
    var activations: DeviceBuffer[DType.float32]
    var cache: DeviceBuffer[DType.float32]
    var output: DeviceBuffer[DType.int32]
    var host_output: HostBuffer[DType.int32]
    var kv_offsets: List[Int]
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
    var sampler: NativeCUDASampler
    var control: GenerationControl
    var reset_required: Bool

    def __init__(out self, path: String, context_length: Int = 32768,
                 device_index: Int = 0, reserve_bytes: Int = 268435456,
                 sampling: NativeSamplingConfig = NativeSamplingConfig()) raises:
        sampling.validate()
        if device_index < 0 or reserve_bytes < 0:
            raise Error("Invalid CUDA device index or memory reserve")
        self.model = PackedGGUF(path)
        validate_gemma4(self.model, context_length)
        self.tokenizer = Gemma4Tokenizer(self.model)
        self.context_length = context_length
        self.position = 0
        self.healthy = True
        self.generating = False
        self.reset_required = False
        self.control = GenerationControl()
        self.generated_tokens = 0
        self.prompt_tokens = 0
        self.max_new_tokens = 0
        self.pending_token = -1
        self.finish_reason = ""
        self.decoder = RuneStreamDecoder()
        self.kv_offsets = List[Int]()
        var cache_elements = 0
        for layer in range(24):
            self.kv_offsets.append(cache_elements)
            var width = 512 if layer % 6 == 5 else 256
            var capacity = context_length if layer % 6 == 5 else 512
            cache_elements += 2 * capacity * 2 * width
        self.context = DeviceContext(device_index, api="cuda")
        if self.context.api() != "cuda" or not self.context.is_compatible():
            raise Error("A compatible NVIDIA CUDA device is required; no CPU fallback")
        var memory = gemma4_memory_plan(Int(self.model.source.file_size), context_length)
        memory.admit_observed(Int(self.context.get_memory_info()[0]), reserve_bytes)
        self.weights = self.context.enqueue_create_buffer[DType.uint8](Int(self.model.source.file_size))
        self.activations = self.context.enqueue_create_buffer[DType.float32](SCORES + 8 * context_length)
        self.cache = self.context.enqueue_create_buffer[DType.float32](cache_elements)
        self.output = self.context.enqueue_create_buffer[DType.int32](1)
        self.host_output = self.context.enqueue_create_host_buffer[DType.int32](1)
        self.sampler = NativeCUDASampler(self.context, 262144, sampling)
        # One initial upload. No layer weights or KV are staged through the CPU
        # during prefill or decoding. The staging allocation dies after sync.
        var staging_bytes = upload_cuda_bytes(self.context, self.weights,
            self.model.source.mmap_ptr.unsafe_bitcast[UInt8](), Int(self.model.source.file_size))
        print("[CUDA] native Mojo Gemma4; device=" + String(device_index) + " api=cuda layers=42/42 weights_bytes=" + String(self.model.source.file_size) + " kv_bytes=" + String(memory.kv_bytes) + " context=" + String(context_length) + " host_staging_bytes=" + String(staging_bytes) + " cpu_offload=0")

    def w(self) -> Bytes:
        return Bytes(unsafe_from_address=Int(self.weights.unsafe_ptr()))

    def a(self) -> Floats:
        return Floats(unsafe_from_address=Int(self.activations.unsafe_ptr()))

    def kv(self) -> Floats:
        return Floats(unsafe_from_address=Int(self.cache.unsafe_ptr()))

    def matvec(self, name: String, src: Int, dst: Int) raises:
        var t = self.model.tensors[name]
        self.context.enqueue_function[matvec_kernel](self.w(), self.a(), Int64(t.offset), Int64(t.kind), Int64(t.columns), Int64(t.rows), Int64(src), Int64(dst), grid_dim=(t.rows * 32 + 127) // 128, block_dim=128)

    def norm(self, name: String, src: Int, dst: Int, width: Int, groups: Int = 1, scale: Float32 = 1) raises:
        var weight = -1
        if name != "":
            weight = self.model.tensors[name].offset
        self.context.enqueue_function[norm_kernel](self.w(), self.a(), Int64(weight), Int64(src), Int64(dst), Int64(width), Int64(groups), Float32(1e-6), scale, grid_dim=(groups * 32 + 127) // 128, block_dim=128)

    def element(self, op: Int, src: Int, second: Int, dst: Int, count: Int, scale: Float32 = 1) raises:
        self.context.enqueue_function[element_kernel](self.w(), self.a(), Int64(op), Int64(src), Int64(second), Int64(dst), Int64(count), scale, grid_dim=(count + 127) // 128, block_dim=128)

    def embed(self, name: String, token: Int, dst: Int, scale: Float32) raises:
        var t = self.model.tensors[name]
        self.context.enqueue_function[embedding_kernel](self.w(), self.a(), Int64(t.offset), Int64(t.kind), Int64(t.columns), Int64(token), Int64(dst), scale, grid_dim=(t.columns + 127) // 128, block_dim=128)

    def forward(mut self, token: Int, need_logits: Bool = True) raises -> Int:
        if not self.healthy:
            raise Error("CUDA session cannot be reused after an execution failure")
        if token < 0 or token >= 262144 or self.position >= self.context_length:
            raise Error("Gemma 4 token/context bound exceeded")
        # Poison until the complete token operation has succeeded.
        self.healthy = False
        self.sampler.record(token)
        self.embed("token_embd.weight", token, X, sqrt(Float32(2560)))
        self.embed("per_layer_token_embd.weight", token, PLE, 16)
        self.matvec("per_layer_model_proj.weight", X, PLE_TEMP)
        self.norm("per_layer_proj_norm.weight", PLE_TEMP, PLE_TEMP, 256, 42, 1.0 / sqrt(Float32(2560)))
        self.element(1, PLE, PLE_TEMP, PLE, 10752, 1.0 / sqrt(Float32(2)))
        for layer in range(42):
            var prefix = "blk." + String(layer) + "."
            var local = layer % 6 != 5
            var width = 256 if local else 512
            var capacity = 512 if local else self.context_length
            var factors = -1 if local else self.model.tensors["rope_freqs.weight"].offset
            var freq_base = Float32(10000 if local else 1000000)
            var kv_layer = layer if layer < 24 else (22 if local else 23)
            var kv_offset = self.kv_offsets[kv_layer]
            self.norm(prefix + "attn_norm.weight", X, N, 2560)
            self.matvec(prefix + "attn_q.weight", N, Q)
            self.norm(prefix + "attn_q_norm.weight", Q, Q, width, 8)
            self.context.enqueue_function[rope_kernel](self.w(), self.a(), Int64(Q), Int64(width), Int64(8), Int64(self.position), freq_base, Int64(factors), grid_dim=(width * 4 + 127) // 128, block_dim=128)
            if layer < 24:
                self.matvec(prefix + "attn_k.weight", N, K)
                self.matvec(prefix + "attn_v.weight", N, V)
                self.norm(prefix + "attn_k_norm.weight", K, K, width, 2)
                self.norm("", V, V, width, 2)
                self.context.enqueue_function[rope_kernel](self.w(), self.a(), Int64(K), Int64(width), Int64(2), Int64(self.position), freq_base, Int64(factors), grid_dim=(width + 127) // 128, block_dim=128)
                self.context.enqueue_function[cache_kernel](self.a(), self.kv(), Int64(K), Int64(V), Int64(kv_offset), Int64(capacity), Int64(width * 2), Int64(self.position), grid_dim=(width * 2 + 127) // 128, block_dim=128)
            var count = min(self.position + 1, capacity)
            var start = self.position + 1 - count
            self.context.enqueue_function[scores_kernel](self.a(), self.kv(), Int64(Q), Int64(SCORES), Int64(kv_offset), Int64(capacity), Int64(width), Int64(start), Int64(count), grid_dim=(8 * count * 32 + 127) // 128, block_dim=128)
            self.context.enqueue_function[softmax_kernel](self.a(), Int64(SCORES), Int64(count), grid_dim=2, block_dim=128)
            self.context.enqueue_function[attention_kernel](self.a(), self.kv(), Int64(SCORES), Int64(ATT), Int64(kv_offset), Int64(capacity), Int64(width), Int64(start), Int64(count), grid_dim=(8 * width + 127) // 128, block_dim=128)
            self.matvec(prefix + "attn_output.weight", ATT, TEMP)
            self.norm(prefix + "post_attention_norm.weight", TEMP, TEMP, 2560)
            self.element(1, X, TEMP, X, 2560)
            self.norm(prefix + "ffn_norm.weight", X, N, 2560)
            self.matvec(prefix + "ffn_up.weight", N, UP)
            self.matvec(prefix + "ffn_gate.weight", N, GATE)
            self.element(2, GATE, UP, UP, 10240)
            self.matvec(prefix + "ffn_down.weight", UP, TEMP)
            self.norm(prefix + "post_ffw_norm.weight", TEMP, TEMP, 2560)
            self.element(1, X, TEMP, X, 2560)
            self.matvec(prefix + "inp_gate.weight", X, N)
            self.element(2, N, PLE + layer * 256, N, 256)
            self.matvec(prefix + "proj.weight", N, TEMP)
            self.norm(prefix + "post_norm.weight", TEMP, TEMP, 2560)
            self.element(1, X, TEMP, X, 2560)
            self.element(3, X, self.model.tensors[prefix + "layer_output_scale.weight"].offset, X, 2560)
        var result = -1
        if need_logits:
            self.norm("output_norm.weight", X, N, 2560)
            self.matvec("token_embd.weight", N, LOGITS)
            self.element(4, LOGITS, 0, LOGITS, 262144, 30)
            self.sampler.select(self.a(), LOGITS, self.output.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), 262144, -1, -1)
            self.context.enqueue_copy(self.host_output, self.output)
            self.context.synchronize()
            result = Int(self.host_output[0])
            if result < 0 or result >= 262144:
                raise Error("Gemma 4 CUDA produced non-finite logits")
        else:
            self.context.synchronize()
        self.position += 1
        self.healthy = True
        return result

    def begin_turn(mut self, prompt: String, system: String, max_tokens: Int) raises:
        if self.reset_required:
            raise Error("Interrupted prefill requires an explicit conversation reset")
        """Admit and prefill a turn without truncating existing conversation KV."""
        if not self.healthy or self.generating:
            raise Error("CUDA session is busy or unusable")
        if prompt.byte_length() == 0 or prompt.byte_length() > 65536:
            raise Error("Chat prompt must contain 1..65536 UTF-8 bytes")
        if max_tokens < 1:
            raise Error("Chat completion limit must be positive")
        var tokens = List[Int]()
        if self.position == 0:
            tokens.append(self.tokenizer.vocabulary.bos_token_id)
            if system != "":
                self.tokenizer.append_message(tokens, "system", system)
        else:
            self.tokenizer.append_text(tokens, "\n")
        self.tokenizer.append_message(tokens, "user", prompt)
        self.tokenizer.append_generation_prompt(tokens)
        if max_tokens > self.context_length - self.position - len(tokens) - 1:
            raise Error("Chat context cannot fit history, prompt and requested maximum completion; history was not truncated")
        self.prompt_tokens = len(tokens)
        self.generated_tokens = 0
        self.max_new_tokens = max_tokens
        self.finish_reason = ""
        self.decoder = RuneStreamDecoder()
        self.control.start()
        for i in range(len(tokens)):
            var reason = String("")
            try:
                reason = self.control.stop_reason()
            except:
                self.reset_required = True
                self.finish_reason = "control_error"
                raise
            if reason != "":
                self.reset_required = True
                self.finish_reason = reason
                self.pending_token = -1
                raise Error("CUDA prefill " + reason + "; explicit reset required")
            self.pending_token = self.forward(tokens[i], i == len(tokens) - 1)
        self.generating = True

    def reset(mut self) raises:
        if not self.healthy or self.generating:
            raise Error("Cannot reset a busy or failed CUDA session")
        self.healthy = False
        self.sampler.clear()
        self.context.synchronize()
        self.position = 0
        self.generated_tokens = 0
        self.prompt_tokens = 0
        self.pending_token = -1
        self.finish_reason = "reset"
        self.reset_required = False
        self.control.deadline_ms = 0
        self.decoder = RuneStreamDecoder()
        self.healthy = True

    def configure_sampling(mut self, sampling: NativeSamplingConfig) raises:
        if not self.healthy or self.generating:
            raise Error("Cannot configure a busy or failed CUDA session")
        self.sampler.configure(sampling)

    def configure_control(mut self, timeout_ms: Int = 0, cancel_fd: Int = -1) raises:
        if not self.healthy or self.generating:
            raise Error("Cannot configure a busy or failed CUDA session")
        self.control = GenerationControl(timeout_ms, cancel_fd)

    def cancel(mut self, reason: String = "cancelled") raises -> String:
        if not self.healthy:
            raise Error("Cannot recover a failed CUDA session through cancellation")
        if reason != "cancelled" and reason != "timeout":
            raise Error("Unsupported native cancellation reason")
        if not self.generating:
            return ""
        # A pending prediction has not yet entered KV/history. Close the actual
        # assistant prefix with its native EOS so the next turn remains valid.
        _ = self.forward(self.tokenizer.vocabulary.eos_token_id, False)
        self.pending_token = -1
        self.finish_reason = reason
        self.generating = False
        self.control.deadline_ms = 0
        return self.decoder.flush()

    def next_chunk(mut self) raises -> String:
        """Advance native GPU decoding and return complete UTF-8 output bytes."""
        if not self.generating:
            raise Error("No active CUDA generation")
        var stop = self.control.stop_reason()
        if stop != "":
            return self.cancel(stop)
        var token = self.pending_token
        if token == self.tokenizer.vocabulary.eos_token_id or token == self.tokenizer.control("<eos>"):
            _ = self.forward(token, False)
            self.finish_reason = "eos"
            self.generating = False
            return self.decoder.flush()
        var spelling = self.tokenizer.vocabulary.vocab[token].replace("▁", " ")
        var chunk = self.decoder.decode_token(spelling)
        self.generated_tokens += 1
        self.pending_token = self.forward(token, self.generated_tokens < self.max_new_tokens)
        if self.generated_tokens == self.max_new_tokens:
            _ = self.forward(self.tokenizer.vocabulary.eos_token_id, False)
            self.finish_reason = "length"
            self.generating = False
            chunk += self.decoder.flush()
        return chunk

    def status(self) -> NativeGenerationStatus:
        return NativeGenerationStatus(self.healthy, self.generating, self.prompt_tokens,
                                      self.generated_tokens, self.position, self.finish_reason)
