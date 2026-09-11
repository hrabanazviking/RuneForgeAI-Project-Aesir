"""Persistent native Mojo CUDA sessions for admitted dense text-only Gemma 4 profiles."""
from max.gpu.host import DeviceContext, DeviceBuffer, HostBuffer
from std.math import sqrt
from loader.packed_gguf import PackedGGUF
from loader.gemma4_tokenizer import Gemma4Tokenizer
from loader.tokenizer import RuneStreamDecoder
from core.gemma4_profile import Gemma4Profile, gemma4_profile_for, validate_gemma4
from core.inference_memory import gemma4_profile_memory_plan
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
comptime GATE = 30208
comptime PLE = 42496
comptime PLE_TEMP = 53248
comptime LOGITS = 64000
comptime SCORES = LOGITS + 262144


struct Gemma4CUDASession(ControlledTextSession):
    var model: PackedGGUF
    var profile: Gemma4Profile
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
    var committed_tokens: List[Int]
    var decoder: RuneStreamDecoder
    var sampler: NativeCUDASampler
    var control: GenerationControl
    var reset_required: Bool

    def __init__(out self, path: String, context_length: Int = 0,
                 device_index: Int = 0, reserve_bytes: Int = 268435456,
                 sampling: NativeSamplingConfig = NativeSamplingConfig()) raises:
        sampling.validate()
        if device_index < 0 or reserve_bytes < 0:
            raise Error("Invalid CUDA device index or memory reserve")
        self.model = PackedGGUF(path)
        self.profile = gemma4_profile_for(self.model)
        var admitted_context = context_length
        if admitted_context == 0:
            admitted_context = self.profile.context_cap
        validate_gemma4(self.model, self.profile, admitted_context)
        self.tokenizer = Gemma4Tokenizer(self.model)
        self.context_length = admitted_context
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
        self.committed_tokens = List[Int]()
        self.decoder = RuneStreamDecoder()
        self.kv_offsets = List[Int]()
        var cache_elements = 0
        for layer in range(self.profile.layer_count - self.profile.shared_kv_layers):
            self.kv_offsets.append(cache_elements)
            var width = self.profile.head_dim(layer)
            var capacity = 512 if self.profile.is_local(layer) else admitted_context
            cache_elements += 2 * capacity * self.profile.kv_heads * width
        self.context = DeviceContext(device_index, api="cuda")
        if self.context.api() != "cuda" or not self.context.is_compatible():
            raise Error("A compatible NVIDIA CUDA device is required; no CPU fallback")
        var memory = gemma4_profile_memory_plan(Int(self.model.source.file_size), admitted_context, self.profile)
        memory.admit_observed(Int(self.context.get_memory_info()[0]), reserve_bytes)
        self.weights = self.context.enqueue_create_buffer[DType.uint8](Int(self.model.source.file_size))
        self.activations = self.context.enqueue_create_buffer[DType.float32](SCORES + self.profile.attention_heads * admitted_context)
        self.cache = self.context.enqueue_create_buffer[DType.float32](cache_elements)
        self.output = self.context.enqueue_create_buffer[DType.int32](1)
        self.host_output = self.context.enqueue_create_host_buffer[DType.int32](1)
        self.sampler = NativeCUDASampler(self.context, self.profile.vocabulary_size, sampling)
        # One initial upload. No layer weights or KV are staged through the CPU
        # during prefill or decoding. The staging allocation dies after sync.
        var staging_bytes = upload_cuda_bytes(self.context, self.weights,
            self.model.source.mmap_ptr.unsafe_bitcast[UInt8](), Int(self.model.source.file_size))
        print("[CUDA] native Mojo " + self.profile.label() + "; device=" + String(device_index) + " api=cuda layers=" + String(self.profile.layer_count) + "/" + String(self.profile.layer_count) + " weights_bytes=" + String(self.model.source.file_size) + " kv_bytes=" + String(memory.kv_bytes) + " context=" + String(admitted_context) + " host_staging_bytes=" + String(staging_bytes) + " cpu_offload=0")

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
        if token < 0 or token >= self.profile.vocabulary_size or self.position >= self.context_length:
            raise Error("Gemma 4 token/context bound exceeded")
        # Poison until the complete token operation has succeeded.
        self.healthy = False
        self.sampler.record(token)
        self.embed("token_embd.weight", token, X, sqrt(Float32(self.profile.hidden_size)))
        self.embed("per_layer_token_embd.weight", token, PLE, 16)
        self.matvec("per_layer_model_proj.weight", X, PLE_TEMP)
        self.norm("per_layer_proj_norm.weight", PLE_TEMP, PLE_TEMP, self.profile.per_layer_input_size, self.profile.layer_count, 1.0 / sqrt(Float32(self.profile.hidden_size)))
        self.element(1, PLE, PLE_TEMP, PLE, self.profile.layer_count * self.profile.per_layer_input_size, 1.0 / sqrt(Float32(2)))
        for layer in range(self.profile.layer_count):
            var prefix = "blk." + String(layer) + "."
            var local = self.profile.is_local(layer)
            var width = self.profile.head_dim(layer)
            var capacity = 512 if local else self.context_length
            var factors = -1 if local else self.model.tensors["rope_freqs.weight"].offset
            var freq_base = Float32(10000 if local else 1000000)
            var kv_layer = self.profile.kv_layer(layer)
            var kv_offset = self.kv_offsets[kv_layer]
            self.norm(prefix + "attn_norm.weight", X, N, self.profile.hidden_size)
            self.matvec(prefix + "attn_q.weight", N, Q)
            self.norm(prefix + "attn_q_norm.weight", Q, Q, width, self.profile.attention_heads)
            self.context.enqueue_function[rope_kernel](self.w(), self.a(), Int64(Q), Int64(width), Int64(self.profile.attention_heads), Int64(self.position), freq_base, Int64(factors), grid_dim=(width * self.profile.attention_heads // 2 + 127) // 128, block_dim=128)
            if self.profile.owns_kv(layer):
                self.matvec(prefix + "attn_k.weight", N, K)
                self.matvec(prefix + "attn_v.weight", N, V)
                self.norm(prefix + "attn_k_norm.weight", K, K, width, self.profile.kv_heads)
                self.norm("", V, V, width, self.profile.kv_heads)
                var kv_width = width * self.profile.kv_heads
                self.context.enqueue_function[rope_kernel](self.w(), self.a(), Int64(K), Int64(width), Int64(self.profile.kv_heads), Int64(self.position), freq_base, Int64(factors), grid_dim=(kv_width // 2 + 127) // 128, block_dim=128)
                self.context.enqueue_function[cache_kernel](self.a(), self.kv(), Int64(K), Int64(V), Int64(kv_offset), Int64(capacity), Int64(kv_width), Int64(self.position), grid_dim=(kv_width + 127) // 128, block_dim=128)
            var count = min(self.position + 1, capacity)
            var start = self.position + 1 - count
            self.context.enqueue_function[scores_kernel](self.a(), self.kv(), Int64(Q), Int64(SCORES), Int64(kv_offset), Int64(capacity), Int64(width), Int64(self.profile.attention_heads), Int64(self.profile.kv_heads), Int64(start), Int64(count), grid_dim=(self.profile.attention_heads * count * 32 + 127) // 128, block_dim=128)
            self.context.enqueue_function[softmax_kernel](self.a(), Int64(SCORES), Int64(count), Int64(self.profile.attention_heads), grid_dim=(self.profile.attention_heads * 32 + 127) // 128, block_dim=128)
            self.context.enqueue_function[attention_kernel](self.a(), self.kv(), Int64(SCORES), Int64(ATT), Int64(kv_offset), Int64(capacity), Int64(width), Int64(self.profile.attention_heads), Int64(self.profile.kv_heads), Int64(start), Int64(count), grid_dim=(self.profile.attention_heads * width + 127) // 128, block_dim=128)
            self.matvec(prefix + "attn_output.weight", ATT, TEMP)
            self.norm(prefix + "post_attention_norm.weight", TEMP, TEMP, self.profile.hidden_size)
            self.element(1, X, TEMP, X, self.profile.hidden_size)
            self.norm(prefix + "ffn_norm.weight", X, N, self.profile.hidden_size)
            self.matvec(prefix + "ffn_up.weight", N, UP)
            self.matvec(prefix + "ffn_gate.weight", N, GATE)
            self.element(2, GATE, UP, UP, self.profile.ffn_size(layer))
            self.matvec(prefix + "ffn_down.weight", UP, TEMP)
            self.norm(prefix + "post_ffw_norm.weight", TEMP, TEMP, self.profile.hidden_size)
            self.element(1, X, TEMP, X, self.profile.hidden_size)
            self.matvec(prefix + "inp_gate.weight", X, N)
            self.element(2, N, PLE + layer * self.profile.per_layer_input_size, N, self.profile.per_layer_input_size)
            self.matvec(prefix + "proj.weight", N, TEMP)
            self.norm(prefix + "post_norm.weight", TEMP, TEMP, self.profile.hidden_size)
            self.element(1, X, TEMP, X, self.profile.hidden_size)
            self.element(3, X, self.model.tensors[prefix + "layer_output_scale.weight"].offset, X, self.profile.hidden_size)
        var result = -1
        if need_logits:
            self.norm("output_norm.weight", X, N, self.profile.hidden_size)
            self.matvec("token_embd.weight", N, LOGITS)
            self.element(4, LOGITS, 0, LOGITS, self.profile.vocabulary_size, 30)
            self.sampler.select(self.a(), LOGITS, self.output.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), self.profile.vocabulary_size, -1, -1)
            self.context.enqueue_copy(self.host_output, self.output)
            self.context.synchronize()
            result = Int(self.host_output[0])
            if result < 0 or result >= self.profile.vocabulary_size:
                raise Error("Gemma 4 CUDA produced non-finite logits")
        else:
            self.context.synchronize()
        self.position += 1
        self.committed_tokens.append(token)
        self.healthy = True
        return result

    def begin_turn(mut self, prompt: String, system: String, max_tokens: Int) raises:
        """Admit and prefill a turn without truncating existing conversation KV."""
        if self.reset_required:
            raise Error("Interrupted prefill requires an explicit conversation reset")
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
        self.committed_tokens.clear()
        self.reset_required = False
        self.control.deadline_ms = 0
        self.decoder = RuneStreamDecoder()
        self.healthy = True

    def conversation_tokens(self) -> List[Int]:
        """Returns the exact token stream already committed to conversation KV."""
        return self.committed_tokens.copy()

    def restore_conversation(
        mut self, tokens: List[Int], sampler_draws: Int
    ) raises:
        """Replays one validated exact token stream into an empty session."""
        if not self.healthy or self.generating or self.position != 0:
            raise Error("Conversation restore requires an empty healthy CUDA session")
        if len(tokens) > self.context_length:
            raise Error("Saved conversation exceeds this session context")
        if sampler_draws < 0:
            raise Error("Saved sampler draw count must not be negative")
        for token in tokens:
            if token < 0 or token >= self.profile.vocabulary_size:
                raise Error("Saved conversation token is outside the model vocabulary")
        for token in tokens:
            _ = self.forward(token, False)
        self.sampler.draws = UInt64(sampler_draws)
        self.pending_token = -1
        self.prompt_tokens = 0
        self.generated_tokens = 0
        self.max_new_tokens = 0
        self.finish_reason = "restored"
        self.control.deadline_ms = 0

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
