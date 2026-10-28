"""Persistent native CUDA inference for admitted dense GQA GGUF profiles."""
from max.gpu.host import DeviceContext, DeviceBuffer, HostBuffer
from std.gpu import global_idx
from loader.packed_gguf import PackedGGUF, PackedTensor
from loader.llama3_tokenizer import Llama3Tokenizer
from loader.tokenizer import RuneStreamDecoder
from core.gemma4_kernels import Bytes, Floats, embedding_kernel, matvec_kernel, packed_matvec_kernel, norm_kernel, element_kernel, argmax_kernel
from core.llama3_kernels import Halves, llama_residual, llama_rope, llama_scaled_rope, llama_silu, llama_cache, llama_scores, llama_softmax, llama_attention, llama_attention_tiled, llama_add_bias
from core.inference_memory import llama3_memory_plan, InferenceMemoryPlan
from core.dense_gqa_profile import (
    DenseGQAProfile, dense_gqa_profile_for, validate_dense_gqa,
    LLAMA3_8B_HIDDEN_SIZE, LLAMA3_8B_FEED_FORWARD_SIZE,
    LLAMA3_8B_KV_HEADS, LLAMA3_8B_HEAD_DIM, LLAMA3_8B_VOCABULARY_SIZE,
    LLAMA3_8B_CONTEXT_CAP,
)
from core.cuda_sampling import NativeCUDASampler
from core.cuda_upload import upload_cuda_bytes, upload_cuda_bytes_at
from core.packed_projection import block_matvec_kernel, four_matvec_kernel
from core.dense_buffers import DenseBufferLayout
from core.dense_normalization import dense_norm_kernel
from core.dense_gqa_execution import DenseGQALayer, prepare_dense_gqa_layers
from core.prompt_prefix import reusable_prompt_prefix
from core.sampling_config import NativeSamplingConfig, sampling_device_bytes
from core.generation_control import GenerationControl, NativeGenerationStatus, ControlledTextSession
from core.grammar import BooleanJSONGrammar

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


def copy_hidden_kernel(x: Floats, dst: Floats, src_offset: Int64, width: Int64):
    var index = Int(global_idx.x)
    if index < Int(width):
        dst.unsafe_store(index, x.unsafe_load(Int(src_offset) + index))


@fieldwise_init
struct FrontTensorSlice(ImplicitlyCopyable, Movable):
    """One front tensor's move from its GGUF file offset to its compacted
    device offset. Real quant files scatter tensor data in arbitrary order,
    so the device image is a compaction of exactly the front tensors,
    never a file prefix."""
    var file_offset: Int
    var device_offset: Int
    var byte_count: Int


def _front_place(mut slices: List[FrontTensorSlice], mut cursor: Int,
                 file_offset: Int, byte_count: Int) -> Int:
    var aligned = (cursor + 31) // 32 * 32
    slices.append(FrontTensorSlice(file_offset, aligned, byte_count))
    cursor = aligned + byte_count
    return aligned


def llama3_compact_front(model: PackedGGUF, mut layers: List[DenseGQALayer],
                         mut embedding: PackedTensor, mut rope_offset: Int,
                         exec_layers: Int,
                         mut slices: List[FrontTensorSlice]) raises -> Int:
    """Rewrite descriptor copies (front layers, embedding, rope offset)
    from GGUF file offsets to compact device offsets covering exactly the
    front tensors, recording every move in slices for the upload. The
    model's own directory keeps true file offsets: the host tokenizer and
    the CPU tail read through it. Returns the compact total in bytes.
    Device offsets are 32-byte aligned, matching GGUF tensor alignment."""
    var cursor = 0
    embedding.offset = _front_place(slices, cursor, embedding.offset,
                                    embedding.byte_count)
    if rope_offset >= 0:
        var rope = model.tensors["rope_freqs.weight"]
        rope_offset = _front_place(slices, cursor, rope.offset,
                                   rope.byte_count)
    for layer in range(exec_layers):
        var plan = layers[layer]
        var prefix = "blk." + String(layer) + "."
        plan.attention_norm = _front_place(slices, cursor, plan.attention_norm,
            model.tensors[prefix + "attn_norm.weight"].byte_count)
        plan.query.offset = _front_place(slices, cursor, plan.query.offset, plan.query.byte_count)
        plan.key.offset = _front_place(slices, cursor, plan.key.offset, plan.key.byte_count)
        plan.value.offset = _front_place(slices, cursor, plan.value.offset, plan.value.byte_count)
        plan.attention_output.offset = _front_place(slices, cursor, plan.attention_output.offset, plan.attention_output.byte_count)
        plan.feed_forward_norm = _front_place(slices, cursor, plan.feed_forward_norm,
            model.tensors[prefix + "ffn_norm.weight"].byte_count)
        plan.gate.offset = _front_place(slices, cursor, plan.gate.offset, plan.gate.byte_count)
        plan.up.offset = _front_place(slices, cursor, plan.up.offset, plan.up.byte_count)
        plan.down.offset = _front_place(slices, cursor, plan.down.offset, plan.down.byte_count)
        if plan.query_norm >= 0:
            plan.query_norm = _front_place(slices, cursor, plan.query_norm,
                model.tensors[prefix + "attn_q_norm.weight"].byte_count)
        if plan.key_norm >= 0:
            plan.key_norm = _front_place(slices, cursor, plan.key_norm,
                model.tensors[prefix + "attn_k_norm.weight"].byte_count)
        layers[layer] = plan
    return cursor


struct Llama3CUDASession(ControlledTextSession):
    var model: PackedGGUF
    var profile: DenseGQAProfile
    var buffers: DenseBufferLayout
    var prefill_batch: Int
    var layers: List[DenseGQALayer]
    var embedding_tensor: PackedTensor
    var output_tensor: PackedTensor
    var output_norm: Int
    var rope_factors_offset: Int
    var tokenizer: Llama3Tokenizer
    var context: DeviceContext
    var weights: DeviceBuffer[DType.uint8]
    var activations: DeviceBuffer[DType.float32]
    var cache: DeviceBuffer[DType.float16]
    var exec_layers: Int
    var spilled: Bool
    var hidden_out: DeviceBuffer[DType.float32]
    var host_hidden: HostBuffer[DType.float32]
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
    var committed_tokens: List[Int]
    var cached_tokens: List[Int]
    var prefix_cache: Bool
    var reused_prompt_tokens: Int
    var decoder: RuneStreamDecoder
    var sampler: NativeCUDASampler
    var control: GenerationControl
    var reset_required: Bool
    var boolean_grammar: BooleanJSONGrammar
    var x_offset: Int
    var norm_offset: Int
    var query_offset: Int
    var key_offset: Int
    var value_offset: Int
    var attention_offset: Int
    var temporary_offset: Int
    var up_offset: Int
    var gate_offset: Int
    var logits_offset: Int
    var scores_offset: Int

    def __init__(out self, path: String, context_length: Int = LLAMA3_8B_CONTEXT_CAP,
                 device_index: Int = 0, reserve_bytes: Int = 268435456,
                 sampling: NativeSamplingConfig = NativeSamplingConfig(),
                 prefix_cache: Bool = True, prefill_batch: Int = 0,
                 exec_layers: Int = 0) raises:
        sampling.validate()
        if device_index < 0 or reserve_bytes < 0:
            raise Error("Invalid CUDA device index or memory reserve")
        self.model = PackedGGUF(path)
        self.profile = dense_gqa_profile_for(self.model)
        validate_dense_gqa(self.model, self.profile, context_length)
        self.layers = prepare_dense_gqa_layers(self.model, self.profile)
        if exec_layers < 0 or exec_layers > self.profile.layer_count:
            raise Error("exec_layers must be within 0..layer_count")
        self.exec_layers = self.profile.layer_count if exec_layers == 0 else exec_layers
        self.spilled = self.exec_layers < self.profile.layer_count
        self.embedding_tensor = self.model.tensors["token_embd.weight"]
        self.output_tensor = self.model.tensors["token_embd.weight" if self.profile.tied_embeddings else "output.weight"]
        self.output_norm = self.model.tensors["output_norm.weight"].offset
        self.rope_factors_offset = -1
        if self.profile.rope_factors:
            self.rope_factors_offset = self.model.tensors["rope_freqs.weight"].offset
        self.buffers = DenseBufferLayout(self.profile, context_length, prefill_batch)
        self.prefill_batch = self.buffers.batch
        self.x_offset = 0
        self.norm_offset = self.buffers.norm
        self.query_offset = self.buffers.query
        self.key_offset = self.buffers.key
        self.value_offset = self.buffers.value
        self.attention_offset = self.buffers.attention
        self.temporary_offset = self.buffers.temporary
        self.up_offset = self.buffers.up
        self.gate_offset = self.buffers.gate
        self.logits_offset = self.buffers.logits
        self.scores_offset = self.buffers.scores
        self.tokenizer = Llama3Tokenizer(self.model)
        self.context_length = context_length
        self.position = 0
        self.healthy = True
        self.generating = False
        self.reset_required = False
        self.boolean_grammar = BooleanJSONGrammar()
        self.control = GenerationControl()
        self.generated_tokens = 0
        self.prompt_tokens = 0
        self.max_new_tokens = 0
        self.pending_token = -1
        self.finish_reason = ""
        self.committed_tokens = List[Int]()
        self.cached_tokens = List[Int]()
        self.prefix_cache = prefix_cache
        self.reused_prompt_tokens = 0
        self.decoder = RuneStreamDecoder()
        self.context = DeviceContext(device_index, api="cuda")
        if self.context.api() != "cuda" or not self.context.is_compatible():
            raise Error("A compatible NVIDIA CUDA device is required; no CPU fallback")
        var device_weights = Int(self.model.source.file_size)
        var kv_elems = self.profile.kv_elements(context_length)
        var front_slices = List[FrontTensorSlice]()
        if self.spilled:
            var front_layers = self.layers.copy()
            var front_embedding = self.embedding_tensor
            var front_rope = self.rope_factors_offset
            device_weights = llama3_compact_front(self.model, front_layers,
                front_embedding, front_rope, self.exec_layers, front_slices)
            self.layers = front_layers^
            self.embedding_tensor = front_embedding
            self.rope_factors_offset = front_rope
            kv_elems = self.exec_layers * 2 * context_length * self.profile.kv_width()
        var memory: InferenceMemoryPlan
        if self.spilled:
            memory = InferenceMemoryPlan(device_weights, kv_elems * 2,
                self.buffers.elements * 4 + sampling_device_bytes(self.profile.vocabulary_size))
        else:
            memory = llama3_memory_plan(device_weights, context_length, self.profile, self.prefill_batch)
        memory.admit_observed(Int(self.context.get_memory_info()[0]), reserve_bytes)
        self.weights = self.context.enqueue_create_buffer[DType.uint8](device_weights)
        self.activations = self.context.enqueue_create_buffer[DType.float32](self.buffers.elements)
        self.cache = self.context.enqueue_create_buffer[DType.float16](kv_elems)
        self.output = self.context.enqueue_create_buffer[DType.int32](1)
        self.host_output = self.context.enqueue_create_host_buffer[DType.int32](1)
        self.hidden_out = self.context.enqueue_create_buffer[DType.float32](self.profile.hidden_size)
        self.host_hidden = self.context.enqueue_create_host_buffer[DType.float32](self.profile.hidden_size)
        self.sampler = NativeCUDASampler(self.context, self.profile.vocabulary_size, sampling)
        var staging_bytes = 0
        if self.spilled:
            var source_base = self.model.source.mmap_ptr.unsafe_bitcast[UInt8]()
            for part in front_slices:
                staging_bytes = upload_cuda_bytes_at(self.context, self.weights,
                    part.device_offset, source_base.unsafe_offset(part.file_offset),
                    part.byte_count)
        else:
            staging_bytes = upload_cuda_bytes(self.context, self.weights,
                self.model.source.mmap_ptr.unsafe_bitcast[UInt8](), device_weights)
        print("[CUDA] native Mojo " + self.profile.label() + "; device=" + String(device_index) + " api=cuda layers=" + String(self.exec_layers) + "/" + String(self.profile.layer_count) + " weights_bytes=" + String(device_weights) + " kv_bytes=" + String(memory.kv_bytes) + " context=" + String(context_length) + " host_staging_bytes=" + String(staging_bytes) + " cpu_offload=" + String(self.profile.layer_count - self.exec_layers))

    def w(self) -> Bytes:
        return Bytes(unsafe_from_address=Int(self.weights.unsafe_ptr()))

    def a(self) -> Floats:
        return Floats(unsafe_from_address=Int(self.activations.unsafe_ptr()))

    def kv(self) -> Halves:
        return Halves(unsafe_from_address=Int(self.cache.unsafe_ptr()))

    def matvec(self, name: String, src: Int, dst: Int) raises:
        self.project(self.model.tensors[name], src, dst)

    def project(self, t: PackedTensor, src: Int, dst: Int) raises:
        var grid = (t.rows * 32 + 127) // 128
        if t.kind == 12 and t.columns % 256 == 0:
            self.context.enqueue_function[block_matvec_kernel[12]](self.w(), self.a(),
                Int64(t.offset), Int64(t.columns), Int64(t.rows), Int64(src),
                Int64(dst), grid_dim=grid, block_dim=128)
        elif t.kind == 14 and t.columns % 256 == 0:
            self.context.enqueue_function[block_matvec_kernel[14]](self.w(), self.a(),
                Int64(t.offset), Int64(t.columns), Int64(t.rows), Int64(src),
                Int64(dst), grid_dim=grid, block_dim=128)
        elif t.kind == 13 and t.columns % 256 == 0:
            self.context.enqueue_function[block_matvec_kernel[13]](self.w(), self.a(),
                Int64(t.offset), Int64(t.columns), Int64(t.rows), Int64(src), Int64(dst),
                grid_dim=grid, block_dim=128)
        else:
            self.context.enqueue_function[matvec_kernel](self.w(), self.a(),
                Int64(t.offset), Int64(t.kind), Int64(t.columns), Int64(t.rows),
                Int64(src), Int64(dst), grid_dim=grid, block_dim=128)

    def norm(self, name: String, src: Int, dst: Int) raises:
        self.norm_at(self.model.tensors[name].offset, src, dst, self.profile.hidden_size)

    def norm_at(self, weight: Int, src: Int, dst: Int, width: Int, groups: Int = 1) raises:
        if width == 3072:
            self.context.enqueue_function[dense_norm_kernel[3072]](self.w(), self.a(), Int64(weight), Int64(src), Int64(dst), Int64(groups), self.profile.normalization_epsilon, grid_dim=(groups * 32 + 127) // 128, block_dim=128)
        elif width == 4096:
            self.context.enqueue_function[dense_norm_kernel[4096]](self.w(), self.a(), Int64(weight), Int64(src), Int64(dst), Int64(groups), self.profile.normalization_epsilon, grid_dim=(groups * 32 + 127) // 128, block_dim=128)
        elif width == 128:
            self.context.enqueue_function[dense_norm_kernel[128]](self.w(), self.a(), Int64(weight), Int64(src), Int64(dst), Int64(groups), self.profile.normalization_epsilon, grid_dim=(groups * 32 + 127) // 128, block_dim=128)
        else:
            self.context.enqueue_function[norm_kernel](self.w(), self.a(), Int64(weight), Int64(src), Int64(dst), Int64(width), Int64(groups), self.profile.normalization_epsilon, Float32(1), grid_dim=(groups * 32 + 127) // 128, block_dim=128)

    def add_bias(self, bias_offset: Int, dst: Int, width: Int) raises:
        if bias_offset >= 0:
            self.context.enqueue_function[llama_add_bias](self.w(), self.a(), Int64(bias_offset), Int64(dst), Int64(width), grid_dim=(width + 127) // 128, block_dim=128)

    def residual(self) raises:
        self.residual_at(0)

    def residual_at(self, base: Int) raises:
        self.context.enqueue_function[llama_residual](self.a(),
            Int64(base + self.x_offset), Int64(base + self.temporary_offset), Int64(base + self.x_offset),
            Int64(self.profile.hidden_size),
            grid_dim=(self.profile.hidden_size + 127) // 128, block_dim=128)

    def rotate(self, offset: Int, heads: Int) raises:
        self.rotate_at(offset, heads, self.position)

    def rotate_at(self, offset: Int, heads: Int, position: Int) raises:
        var grid = (heads * self.profile.head_dim // 2 + 127) // 128
        if self.profile.rope_factors:
            self.context.enqueue_function[llama_scaled_rope](self.w(), self.a(),
                Int64(offset), Int64(self.profile.head_dim), Int64(heads),
                Int64(position), self.profile.rope_frequency_base,
                Int64(1 if self.profile.neox_rope else 0),
                Int64(self.rope_factors_offset),
                grid_dim=grid, block_dim=128)
        else:
            self.context.enqueue_function[llama_rope](self.a(), Int64(offset),
                Int64(self.profile.head_dim), Int64(heads), Int64(position),
                self.profile.rope_frequency_base,
                Int64(1 if self.profile.neox_rope else 0), grid_dim=grid, block_dim=128)

    def run_layer(mut self, layer: Int) raises:
        var plan = self.layers[layer]
        var offset = layer * 2 * self.context_length * self.profile.kv_width()
        self.norm_at(plan.attention_norm, self.x_offset, self.norm_offset, self.profile.hidden_size)
        self.project(plan.query, self.norm_offset, self.query_offset)
        self.project(plan.key, self.norm_offset, self.key_offset)
        self.project(plan.value, self.norm_offset, self.value_offset)
        self.add_bias(plan.query_bias, self.query_offset, self.profile.query_width())
        self.add_bias(plan.key_bias, self.key_offset, self.profile.kv_width())
        self.add_bias(plan.value_bias, self.value_offset, self.profile.kv_width())
        if self.profile.qk_norm:
            self.norm_at(plan.query_norm, self.query_offset, self.query_offset, self.profile.head_dim, self.profile.attention_heads)
            self.norm_at(plan.key_norm, self.key_offset, self.key_offset, self.profile.head_dim, self.profile.kv_heads)
        self.rotate(self.query_offset, self.profile.attention_heads)
        self.rotate(self.key_offset, self.profile.kv_heads)
        self.context.enqueue_function[llama_cache](self.a(), self.kv(), Int64(self.key_offset), Int64(self.value_offset), Int64(offset), Int64(self.context_length), Int64(self.profile.kv_width()), Int64(self.position), grid_dim=(self.profile.kv_width() + 127) // 128, block_dim=128)
        var count = self.position + 1
        self.context.enqueue_function[llama_scores](self.a(), self.kv(), Int64(self.query_offset), Int64(self.scores_offset), Int64(offset), Int64(count), Int64(self.profile.head_dim), Int64(self.profile.attention_heads), Int64(self.profile.kv_heads), grid_dim=(self.profile.attention_heads * count * 32 + 127) // 128, block_dim=128)
        self.context.enqueue_function[llama_softmax](self.a(), Int64(self.scores_offset), Int64(count), Int64(self.profile.attention_heads), grid_dim=(self.profile.attention_heads * 32 + 127) // 128, block_dim=128)
        self.context.enqueue_function[llama_attention_tiled](self.a(), self.kv(), Int64(self.scores_offset), Int64(self.attention_offset), Int64(offset), Int64(self.context_length), Int64(count), Int64(self.profile.head_dim), Int64(self.profile.attention_heads), Int64(self.profile.kv_heads), grid_dim=(self.profile.query_width() + 127) // 128, block_dim=128)
        self.project(plan.attention_output, self.attention_offset, self.temporary_offset)
        self.residual()
        self.norm_at(plan.feed_forward_norm, self.x_offset, self.norm_offset, self.profile.hidden_size)
        self.project(plan.gate, self.norm_offset, self.gate_offset)
        self.project(plan.up, self.norm_offset, self.up_offset)
        self.context.enqueue_function[llama_silu](self.a(), Int64(self.gate_offset), Int64(self.up_offset), Int64(self.profile.feed_forward_size), grid_dim=(self.profile.feed_forward_size + 127) // 128, block_dim=128)
        self.project(plan.down, self.up_offset, self.temporary_offset)
        self.residual()
    def forward_front(mut self, token: Int) raises:
        if not self.spilled:
            raise Error("forward_front requires a spilled session")
        if not self.healthy:
            raise Error("CUDA session cannot be reused after an execution failure")
        if token < 0 or token >= self.profile.vocabulary_size or self.position >= self.context_length:
            raise Error("Llama 3 token/context bound exceeded")
        self.healthy = False
        var embedding = self.embedding_tensor
        self.context.enqueue_function[embedding_kernel](self.w(), self.a(), Int64(embedding.offset), Int64(embedding.kind), Int64(self.profile.hidden_size), Int64(token), Int64(self.x_offset), Float32(1), grid_dim=(self.profile.hidden_size + 127) // 128, block_dim=128)
        for layer in range(self.exec_layers):
            self.run_layer(layer)
        self.context.enqueue_function[copy_hidden_kernel](self.a(), Floats(unsafe_from_address=Int(self.hidden_out.unsafe_ptr())), Int64(self.x_offset), Int64(self.profile.hidden_size), grid_dim=(self.profile.hidden_size + 127) // 128, block_dim=128)
        self.context.enqueue_copy(self.host_hidden, self.hidden_out)
        self.context.synchronize()
        self.position += 1
        self.committed_tokens.append(token)
        self.healthy = True

    def hidden_value(self, index: Int) -> Float32:
        return self.host_hidden[index]

    def forward(mut self, token: Int, need_logits: Bool = True) raises -> Int:
        if self.spilled:
            raise Error("Spilled session: use forward_front with the CPU tail")
        if not self.healthy:
            raise Error("CUDA session cannot be reused after an execution failure")
        if token < 0 or token >= self.profile.vocabulary_size or self.position >= self.context_length:
            raise Error("Llama 3 token/context bound exceeded")
        self.healthy = False
        self.sampler.record(token)
        var embedding = self.embedding_tensor
        self.context.enqueue_function[embedding_kernel](self.w(), self.a(), Int64(embedding.offset), Int64(embedding.kind), Int64(self.profile.hidden_size), Int64(token), Int64(self.x_offset), Float32(1), grid_dim=(self.profile.hidden_size + 127) // 128, block_dim=128)
        for layer in range(self.exec_layers):
            self.run_layer(layer)
        var result = -1
        if need_logits:
            self.norm_at(self.output_norm, self.x_offset, self.norm_offset, self.profile.hidden_size)
            self.project(self.output_tensor, self.norm_offset, self.logits_offset)
            if self.boolean_grammar.active:
                self.sampler.select_boolean_json(self.a(), self.logits_offset,
                    self.output.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](),
                    self.boolean_grammar.next_ids())
            else:
                self.sampler.select(self.a(), self.logits_offset, self.output.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin](), self.profile.ordinary_token_limit, self.profile.eos_token_id, self.profile.end_of_turn_token_id)
            self.context.enqueue_copy(self.host_output, self.output)
            self.context.synchronize()
            result = Int(self.host_output[0])
            if result < 0 or result >= self.profile.vocabulary_size:
                raise Error("Llama 3 CUDA produced non-finite logits")
        else:
            self.context.synchronize()
        self.position += 1
        self.committed_tokens.append(token)
        self.healthy = True
        return result

    def project_four(self, t: PackedTensor, src: Int, dst: Int) raises:
        var grid = (t.rows + 3) // 4
        if t.kind == 12 and t.columns % 256 == 0:
            self.context.enqueue_function[four_matvec_kernel[12]](self.w(), self.a(), Int64(t.offset), Int64(t.columns), Int64(t.rows), Int64(src), Int64(dst), Int64(self.buffers.stride), grid_dim=grid, block_dim=128)
        elif t.kind == 13 and t.columns % 256 == 0:
            self.context.enqueue_function[four_matvec_kernel[13]](self.w(), self.a(), Int64(t.offset), Int64(t.columns), Int64(t.rows), Int64(src), Int64(dst), Int64(self.buffers.stride), grid_dim=grid, block_dim=128)
        elif t.kind == 14 and t.columns % 256 == 0:
            self.context.enqueue_function[four_matvec_kernel[14]](self.w(), self.a(), Int64(t.offset), Int64(t.columns), Int64(t.rows), Int64(src), Int64(dst), Int64(self.buffers.stride), grid_dim=grid, block_dim=128)
        else:
            for token in range(4):
                var base = self.buffers.token_base(token)
                self.project(t, base + src, base + dst)

    def prefill_four(mut self, tokens: List[Int], start: Int) raises:
        if self.spilled:
            raise Error("Four-token prefill is unavailable on a spilled session")
        if not self.healthy or self.prefill_batch != 4 or self.buffers.batch != 4:
            raise Error("Four-token prefill requires a healthy admitted tile")
        if start < 0 or start > len(tokens) - 4 or self.position > self.context_length - 4:
            raise Error("Four-token prefill exceeds input or context bounds")
        for token in range(4):
            if tokens[start + token] < 0 or tokens[start + token] >= self.profile.vocabulary_size:
                raise Error("Prefill token exceeds vocabulary")
        self.healthy = False
        for token in range(4):
            var base = self.buffers.token_base(token)
            self.sampler.record(tokens[start + token])
            self.context.enqueue_function[embedding_kernel](self.w(), self.a(), Int64(self.embedding_tensor.offset), Int64(self.embedding_tensor.kind), Int64(self.profile.hidden_size), Int64(tokens[start + token]), Int64(base), Float32(1), grid_dim=(self.profile.hidden_size + 127) // 128, block_dim=128)
        for layer in range(self.profile.layer_count):
            var plan = self.layers[layer]
            var offset = layer * 2 * self.context_length * self.profile.kv_width()
            for token in range(4):
                var base = self.buffers.token_base(token)
                self.norm_at(plan.attention_norm, base, base + self.norm_offset, self.profile.hidden_size)
            self.project_four(plan.query, self.norm_offset, self.query_offset)
            self.project_four(plan.key, self.norm_offset, self.key_offset)
            self.project_four(plan.value, self.norm_offset, self.value_offset)
            if plan.query_bias >= 0:
                for token in range(4):
                    var base = self.buffers.token_base(token)
                    self.add_bias(plan.query_bias, base + self.query_offset, self.profile.query_width())
                    self.add_bias(plan.key_bias, base + self.key_offset, self.profile.kv_width())
                    self.add_bias(plan.value_bias, base + self.value_offset, self.profile.kv_width())
            for token in range(4):
                var base = self.buffers.token_base(token)
                var position = self.position + token
                self.rotate_at(base + self.query_offset, self.profile.attention_heads, position)
                self.rotate_at(base + self.key_offset, self.profile.kv_heads, position)
                self.context.enqueue_function[llama_cache](self.a(), self.kv(), Int64(base + self.key_offset), Int64(base + self.value_offset), Int64(offset), Int64(self.context_length), Int64(self.profile.kv_width()), Int64(position), grid_dim=(self.profile.kv_width() + 127) // 128, block_dim=128)
                var count = position + 1
                # Shared scores are consumed on this stream before the next token.
                # Only this token's causal positions are read even inside a tile.
                self.context.enqueue_function[llama_scores](self.a(), self.kv(), Int64(base + self.query_offset), Int64(self.scores_offset), Int64(offset), Int64(count), Int64(self.profile.head_dim), Int64(self.profile.attention_heads), Int64(self.profile.kv_heads), grid_dim=(self.profile.attention_heads * count + 3) // 4, block_dim=128)
                self.context.enqueue_function[llama_softmax](self.a(), Int64(self.scores_offset), Int64(count), Int64(self.profile.attention_heads), grid_dim=(self.profile.attention_heads + 3) // 4, block_dim=128)
                self.context.enqueue_function[llama_attention_tiled](self.a(), self.kv(), Int64(self.scores_offset), Int64(base + self.attention_offset), Int64(offset), Int64(self.context_length), Int64(count), Int64(self.profile.head_dim), Int64(self.profile.attention_heads), Int64(self.profile.kv_heads), grid_dim=(self.profile.query_width() + 127) // 128, block_dim=128)
            self.project_four(plan.attention_output, self.attention_offset, self.temporary_offset)
            for token in range(4):
                var base = self.buffers.token_base(token)
                self.residual_at(base)
                self.norm_at(plan.feed_forward_norm, base, base + self.norm_offset, self.profile.hidden_size)
            self.project_four(plan.gate, self.norm_offset, self.gate_offset)
            self.project_four(plan.up, self.norm_offset, self.up_offset)
            for token in range(4):
                var base = self.buffers.token_base(token)
                self.context.enqueue_function[llama_silu](self.a(), Int64(base + self.gate_offset), Int64(base + self.up_offset), Int64(self.profile.feed_forward_size), grid_dim=(self.profile.feed_forward_size + 127) // 128, block_dim=128)
            self.project_four(plan.down, self.up_offset, self.temporary_offset)
            for token in range(4):
                self.residual_at(self.buffers.token_base(token))
        self.context.synchronize()
        for token in range(4):
            self.committed_tokens.append(tokens[start + token])
        self.position += 4
        self.healthy = True

    def begin_turn(mut self, prompt: String, system: String, max_tokens: Int) raises:
        if self.reset_required:
            raise Error("Interrupted prefill requires an explicit conversation reset")
        if not self.healthy or self.generating:
            raise Error("CUDA session is busy or unusable")
        if prompt.byte_length() == 0 or prompt.byte_length() > 65536 or system.byte_length() > 65536:
            raise Error("Chat text exceeds admission bounds")
        if max_tokens < 1 or max_tokens > self.profile.context_cap:
            raise Error("Llama 3 completion ceiling must be within 1.." + String(self.profile.context_cap))
        if self.boolean_grammar.active and max_tokens < self.boolean_grammar.maximum_tokens():
            raise Error("Boolean JSON needs enough completion tokens for either literal")
        var tokens = List[Int]()
        if self.position == 0 and self.profile.add_bos:
            tokens.append(self.tokenizer.vocabulary.bos_token_id)
        if self.position == 0 and system != "":
            self.tokenizer.append_message(tokens, "system", system)
        self.tokenizer.append_message(tokens, "user", prompt)
        self.tokenizer.append_header(tokens, "assistant")
        if len(tokens) + 2 > self.context_length - self.position:
            raise Error("Llama 3 context cannot fit prompt, response and closing token; history was not truncated")
        if self.boolean_grammar.active and len(tokens) + self.boolean_grammar.maximum_tokens() + 1 > self.context_length - self.position:
            raise Error("Llama 3 context cannot fit Boolean JSON and closing token")
        self.prompt_tokens = len(tokens)
        self.generated_tokens = 0
        self.max_new_tokens = max_tokens
        self.finish_reason = ""
        self.decoder = RuneStreamDecoder()
        self.control.start()
        var reuse = 0
        self.reused_prompt_tokens = 0
        if self.position == 0 and self.prefix_cache:
            reuse = reusable_prompt_prefix(self.cached_tokens, tokens)
        var i = 0
        while i < len(tokens):
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
            if i < reuse:
                # Exact model/token/position equality preserves KV. Rebuild the
                # current request's history instead of inheriting old sampling
                # state. Synchronize before committing any reused token; an
                # execution failure leaves healthy=False and prevents reuse.
                self.healthy = False
                self.sampler.record(tokens[i])
                self.context.synchronize()
                self.position += 1
                self.committed_tokens.append(tokens[i])
                self.reused_prompt_tokens += 1
                self.healthy = True
            elif self.prefill_batch == 4 and len(tokens) - 1 - i >= 4:
                self.prefill_four(tokens, i)
                i += 4
                continue
            else:
                self.pending_token = self.forward(tokens[i], i == len(tokens) - 1)
            i += 1
        self.generating = True

    def reset(mut self) raises:
        if not self.healthy or self.generating:
            raise Error("Cannot reset a busy or failed CUDA session")
        self.healthy = False
        if self.prefix_cache:
            self.cached_tokens = self.committed_tokens.copy()
        self.sampler.clear()
        self.context.synchronize()
        self.position = 0
        self.generated_tokens = 0
        self.prompt_tokens = 0
        self.reused_prompt_tokens = 0
        self.pending_token = -1
        self.finish_reason = "reset"
        self.committed_tokens.clear()
        self.reset_required = False
        self.boolean_grammar.clear()
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
        var restored = 0
        while restored < len(tokens):
            if self.prefill_batch == 4 and len(tokens) - restored >= 4:
                self.prefill_four(tokens, restored)
                restored += 4
            else:
                _ = self.forward(tokens[restored], False)
                restored += 1
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

    def configure_output(mut self, output_mode: String) raises:
        if not self.healthy or self.generating:
            raise Error("Cannot configure output on a busy or failed CUDA session")
        self.boolean_grammar.clear()
        if output_mode == "":
            return
        if output_mode != "json_boolean":
            raise Error("Unsupported structured output mode")
        var true_tokens = self.tokenizer.encode("true")
        var false_tokens = self.tokenizer.encode("false")
        var true_decoder = RuneStreamDecoder()
        var false_decoder = RuneStreamDecoder()
        var true_text = String("")
        var false_text = String("")
        for token in true_tokens:
            true_text += self.tokenizer.decode(token, true_decoder)
        for token in false_tokens:
            false_text += self.tokenizer.decode(token, false_decoder)
        true_text += true_decoder.flush()
        false_text += false_decoder.flush()
        if true_text != "true" or false_text != "false":
            raise Error("Tokenizer cannot render exact JSON boolean literals")
        if self.sampler.config.temperature != 0 or self.sampler.config.repetition_penalty != 1:
            raise Error("Boolean JSON requires unpenalized greedy sampling")
        self.boolean_grammar.configure(true_tokens, false_tokens)

    def configure_tool(mut self, name: String, description: String) raises:
        _ = description
        if not self.healthy or self.generating:
            raise Error("Cannot configure a busy or failed CUDA session")
        if name != "":
            raise Error("Tool calls require the proven Gemma 4 tool template; this model is unsupported")

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
        if self.boolean_grammar.active:
            var complete = self.boolean_grammar.advance(token)
            self.pending_token = self.forward(token, not complete)
            if complete:
                _ = self.forward(self.profile.end_of_turn_token_id, False)
                self.finish_reason = "eos"
                self.generating = False
                chunk += self.decoder.flush()
            return chunk
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
