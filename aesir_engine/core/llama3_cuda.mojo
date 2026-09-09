"""Persistent native CUDA inference for the admitted Llama 3 8B GGUF profile."""
from max.gpu.host import DeviceContext, DeviceBuffer, HostBuffer
from loader.packed_gguf import PackedGGUF
from loader.llama3_tokenizer import Llama3Tokenizer
from loader.tokenizer import RuneStreamDecoder
from core.gemma4_kernels import Bytes, Floats, embedding_kernel, matvec_kernel, norm_kernel, element_kernel, argmax_kernel
from core.llama3_kernels import Halves, llama_rope, llama_silu, llama_cache, llama_scores, llama_softmax, llama_attention
from core.inference_memory import llama3_memory_plan
from core.llama3_profile import (
    Llama3Profile, llama3_profile_for, validate_llama3,
    LLAMA3_8B_HIDDEN_SIZE, LLAMA3_8B_FEED_FORWARD_SIZE,
    LLAMA3_8B_KV_HEADS, LLAMA3_8B_HEAD_DIM, LLAMA3_8B_VOCABULARY_SIZE,
    LLAMA3_8B_CONTEXT_CAP,
)
from core.cuda_sampling import NativeCUDASampler
from core.cuda_upload import upload_cuda_bytes
from core.sampling_config import NativeSamplingConfig
from core.generation_control import GenerationControl, NativeGenerationStatus, ControlledTextSession

comptime X = 0
comptime N = X + LLAMA3_8B_HIDDEN_SIZE
comptime Q = N + LLAMA3_8B_HIDDEN_SIZE
comptime K = Q + LLAMA3_8B_HIDDEN_SIZE
comptime V = K + LLAMA3_8B_KV_HEADS * LLAMA3_8B_HEAD_DIM
comptime ATT = V + LLAMA3_8B_KV_HEADS * LLAMA3_8B_HEAD_DIM
comptime TEMP = ATT + LLAMA3_8B_HIDDEN_SIZE
comptime UP = TEMP + LLAMA3_8B_HIDDEN_SIZE
comptime GATE = UP + LLAMA3_8B_FEED_FORWARD_SIZE
comptime LOGITS = GATE + LLAMA3_8B_FEED_FORWARD_SIZE
comptime SCORES = LOGITS + LLAMA3_8B_VOCABULARY_SIZE


struct Llama3CUDASession(ControlledTextSession):
    var model: PackedGGUF
    var profile: Llama3Profile
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
    var sampler: NativeCUDASampler
    var control: GenerationControl
    var reset_required: Bool

    def __init__(out self, path: String, context_length: Int = LLAMA3_8B_CONTEXT_CAP,
                 device_index: Int = 0, reserve_bytes: Int = 268435456,
                 sampling: NativeSamplingConfig = NativeSamplingConfig()) raises:
        sampling.validate()
        if device_index < 0 or reserve_bytes < 0:
            raise Error("Invalid CUDA device index or memory reserve")
        self.model = PackedGGUF(path)
        self.profile = llama3_profile_for(self.model)
        validate_llama3(self.model, self.profile, context_length)
        self.tokenizer = Llama3Tokenizer(self.model)
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
        self.context = DeviceContext(device_index, api="cuda")
        if self.context.api() != "cuda" or not self.context.is_compatible():
            raise Error("A compatible NVIDIA CUDA device is required; no CPU fallback")
        var memory = llama3_memory_plan(Int(self.model.source.file_size), context_length, self.profile)
        memory.admit_observed(Int(self.context.get_memory_info()[0]), reserve_bytes)
        self.weights = self.context.enqueue_create_buffer[DType.uint8](Int(self.model.source.file_size))
        self.activations = self.context.enqueue_create_buffer[DType.float32](self.profile.activation_elements(context_length))
        self.cache = self.context.enqueue_create_buffer[DType.float16](self.profile.kv_elements(context_length))
        self.output = self.context.enqueue_create_buffer[DType.int32](1)
        self.host_output = self.context.enqueue_create_host_buffer[DType.int32](1)
        self.sampler = NativeCUDASampler(self.context, self.profile.vocabulary_size, sampling)
        var staging_bytes = upload_cuda_bytes(self.context, self.weights,
            self.model.source.mmap_ptr.unsafe_bitcast[UInt8](), Int(self.model.source.file_size))
        print("[CUDA] native Mojo " + self.profile.label() + "; device=" + String(device_index) + " api=cuda layers=" + String(self.profile.layer_count) + "/" + String(self.profile.layer_count) + " weights_bytes=" + String(self.model.source.file_size) + " kv_bytes=" + String(memory.kv_bytes) + " context=" + String(context_length) + " host_staging_bytes=" + String(staging_bytes) + " cpu_offload=0")

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
        self.context.enqueue_function[norm_kernel](self.w(), self.a(), Int64(self.model.tensors[name].offset), Int64(src), Int64(dst), Int64(self.profile.hidden_size), Int64(1), self.profile.normalization_epsilon, Float32(1), grid_dim=1, block_dim=128)

    def residual(self) raises:
        self.context.enqueue_function[element_kernel](self.w(), self.a(), Int64(1), Int64(X), Int64(TEMP), Int64(X), Int64(self.profile.hidden_size), Float32(1), grid_dim=(self.profile.hidden_size + 127) // 128, block_dim=128)

    def forward(mut self, token: Int, need_logits: Bool = True) raises -> Int:
        if not self.healthy:
            raise Error("CUDA session cannot be reused after an execution failure")
        if token < 0 or token >= self.profile.vocabulary_size or self.position >= self.context_length:
            raise Error("Llama 3 token/context bound exceeded")
        self.healthy = False
        self.sampler.record(token)
        var embedding = self.model.tensors["token_embd.weight"]
        self.context.enqueue_function[embedding_kernel](self.w(), self.a(), Int64(embedding.offset), Int64(embedding.kind), Int64(self.profile.hidden_size), Int64(token), Int64(X), Float32(1), grid_dim=(self.profile.hidden_size + 127) // 128, block_dim=128)
        for layer in range(self.profile.layer_count):
            var prefix = "blk." + String(layer) + "."
            var offset = layer * 2 * self.context_length * self.profile.kv_width()
            self.norm(prefix + "attn_norm.weight", X, N)
            self.matvec(prefix + "attn_q.weight", N, Q)
            self.matvec(prefix + "attn_k.weight", N, K)
            self.matvec(prefix + "attn_v.weight", N, V)
            self.context.enqueue_function[llama_rope](self.a(), Int64(Q), Int64(self.profile.attention_heads), Int64(self.position), grid_dim=(self.profile.attention_heads + 1) // 2, block_dim=128)
            self.context.enqueue_function[llama_rope](self.a(), Int64(K), Int64(self.profile.kv_heads), Int64(self.position), grid_dim=(self.profile.kv_heads + 1) // 2, block_dim=128)
            self.context.enqueue_function[llama_cache](self.a(), self.kv(), Int64(K), Int64(V), Int64(offset), Int64(self.context_length), Int64(self.position), grid_dim=self.profile.kv_heads, block_dim=128)
            var count = self.position + 1
            self.context.enqueue_function[llama_scores](self.a(), self.kv(), Int64(Q), Int64(SCORES), Int64(offset), Int64(count), grid_dim=self.profile.kv_heads * count, block_dim=128)
            self.context.enqueue_function[llama_softmax](self.a(), Int64(SCORES), Int64(count), grid_dim=self.profile.kv_heads, block_dim=128)
            self.context.enqueue_function[llama_attention](self.a(), self.kv(), Int64(SCORES), Int64(ATT), Int64(offset), Int64(self.context_length), Int64(count), grid_dim=self.profile.attention_heads, block_dim=128)
            self.matvec(prefix + "attn_output.weight", ATT, TEMP)
            self.residual()
            self.norm(prefix + "ffn_norm.weight", X, N)
            self.matvec(prefix + "ffn_gate.weight", N, GATE)
            self.matvec(prefix + "ffn_up.weight", N, UP)
            self.context.enqueue_function[llama_silu](self.a(), Int64(GATE), Int64(UP), Int64(self.profile.feed_forward_size), grid_dim=(self.profile.feed_forward_size + 127) // 128, block_dim=128)
            self.matvec(prefix + "ffn_down.weight", UP, TEMP)
            self.residual()
        var result = -1
        if need_logits:
            self.norm("output_norm.weight", X, N)
            self.matvec("output.weight", N, LOGITS)
            self.sampler.select(self.a(), LOGITS, self.output.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), self.profile.ordinary_token_limit, self.profile.eos_token_id, self.profile.end_of_turn_token_id)
            self.context.enqueue_copy(self.host_output, self.output)
            self.context.synchronize()
            result = Int(self.host_output[0])
            if result < 0 or result >= self.profile.vocabulary_size:
                raise Error("Llama 3 CUDA produced non-finite logits")
        else:
            self.context.synchronize()
        self.position += 1
        self.healthy = True
        return result

    def begin_turn(mut self, prompt: String, system: String, max_tokens: Int) raises:
        if self.reset_required:
            raise Error("Interrupted prefill requires an explicit conversation reset")
        if not self.healthy or self.generating:
            raise Error("CUDA session is busy or unusable")
        if prompt.byte_length() == 0 or prompt.byte_length() > 65536 or system.byte_length() > 65536:
            raise Error("Chat text exceeds admission bounds")
        if max_tokens < 1 or max_tokens > self.profile.context_cap:
            raise Error("Llama 3 completion ceiling must be within 1.." + String(self.profile.context_cap))
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
        self.control.start()
        for i in range(len(tokens)):
            var reason: String
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
        _ = self.forward(self.profile.end_of_turn_token_id, False)
        self.pending_token = -1
        self.finish_reason = reason
        self.generating = False
        self.control.deadline_ms = 0
        return self.decoder.flush()

    def next_chunk(mut self) raises -> String:
        if not self.generating:
            raise Error("No active CUDA generation")
        var stop = self.control.stop_reason()
        if stop != "":
            return self.cancel(stop)
        var token = self.pending_token
        if token == self.profile.eos_token_id or token == self.profile.end_of_turn_token_id:
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
            _ = self.forward(self.profile.end_of_turn_token_id, False)
            self.finish_reason = "context_exhausted" if full else "length"
            self.generating = False
            chunk += self.decoder.flush()
        return chunk

    def status(self) -> NativeGenerationStatus:
        return NativeGenerationStatus(self.healthy, self.generating, self.prompt_tokens,
                                      self.generated_tokens, self.position, self.finish_reason)
