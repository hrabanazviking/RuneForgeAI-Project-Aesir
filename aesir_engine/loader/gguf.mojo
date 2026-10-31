# loader/gguf.mojo
# Bounds-checked GGUF v3 loader with real mmap-backed F16 tensor views.

from std.collections import Dict
from std.ffi import external_call
from std.memory import Pointer, bitcast
from std.memory.alloc import unsafe_alloc

from core.mimir_well import (
    CompressedFormatType,
    MimirWell,
    RuneTensor,
    convert_bf16_to_f16,
    f16,
)
from loader.tokenizer import RuneWeaver
from hailbru.source_sealed_copy import _require_sealed_source
from hailbru.syscall import os_host_architecture, os_mmap, os_close_descriptor


struct GGMLType:
    comptime F32 = 0
    comptime F16 = 1
    comptime Q4_0 = 2
    comptime Q4_1 = 3
    comptime Q5_0 = 6
    comptime Q5_1 = 7
    comptime Q8_0 = 8
    comptime Q8_1 = 9
    comptime Q2_K = 10
    comptime Q3_K = 11
    comptime Q4_K = 12
    comptime Q5_K = 13
    comptime Q6_K = 14
    comptime Q8_K = 15
    comptime IQ2_XXS = 16
    comptime IQ2_XS = 17
    comptime IQ3_XXS = 18
    comptime IQ1_S = 19
    comptime IQ4_NL = 20
    comptime IQ3_S = 21
    comptime IQ2_S = 22
    comptime IQ4_XS = 23
    comptime IQ1_M = 29
    comptime TQ1_0 = 34
    comptime TQ2_0 = 35
    comptime BF16 = 30

    @staticmethod
    def to_compressed_format(ggml_type: UInt32) raises -> CompressedFormatType:
        """Map only GGML tensor types whose execution layout is implemented."""
        if ggml_type == GGMLType.Q4_0:
            return CompressedFormatType(CompressedFormatType.Q4_0)
        elif ggml_type == GGMLType.Q4_1:
            return CompressedFormatType(CompressedFormatType.Q4_1)
        elif ggml_type == GGMLType.Q5_0:
            return CompressedFormatType(CompressedFormatType.Q5_0)
        elif ggml_type == GGMLType.Q5_1:
            return CompressedFormatType(CompressedFormatType.Q5_1)
        elif ggml_type == GGMLType.Q8_0:
            return CompressedFormatType(CompressedFormatType.Q8_0)
        elif ggml_type == GGMLType.Q8_1:
            return CompressedFormatType(CompressedFormatType.Q8_1)
        elif ggml_type == GGMLType.Q2_K:
            return CompressedFormatType(CompressedFormatType.Q2_K)
        elif ggml_type == GGMLType.Q3_K:
            return CompressedFormatType(CompressedFormatType.Q3_K_M)
        elif ggml_type == GGMLType.Q4_K:
            return CompressedFormatType(CompressedFormatType.Q4_K_M)
        elif ggml_type == GGMLType.Q5_K:
            return CompressedFormatType(CompressedFormatType.Q5_K_M)
        elif ggml_type == GGMLType.Q6_K:
            return CompressedFormatType(CompressedFormatType.Q6_K)
        elif ggml_type == GGMLType.IQ2_XXS:
            return CompressedFormatType(CompressedFormatType.IQ2_XXS)
        elif ggml_type == GGMLType.IQ2_XS:
            return CompressedFormatType(CompressedFormatType.IQ2_XS)
        elif ggml_type == GGMLType.IQ3_XXS:
            return CompressedFormatType(CompressedFormatType.IQ3_XXS)
        elif ggml_type == GGMLType.IQ1_S:
            return CompressedFormatType(CompressedFormatType.IQ1_S)
        elif ggml_type == GGMLType.IQ3_S:
            return CompressedFormatType(CompressedFormatType.IQ3_S)
        elif ggml_type == GGMLType.IQ2_S:
            return CompressedFormatType(CompressedFormatType.IQ2_S)
        elif ggml_type == GGMLType.IQ4_NL:
            return CompressedFormatType(CompressedFormatType.IQ4_NL)
        elif ggml_type == GGMLType.IQ4_XS:
            return CompressedFormatType(CompressedFormatType.IQ4_XS)
        elif ggml_type == GGMLType.IQ1_M:
            return CompressedFormatType(CompressedFormatType.IQ1_M)
        elif ggml_type == GGMLType.TQ1_0:
            return CompressedFormatType(CompressedFormatType.TQ1_0)
        elif ggml_type == GGMLType.TQ2_0:
            return CompressedFormatType(CompressedFormatType.TQ2_0)
        raise Error("unsupported GGML tensor type " + String(ggml_type))


struct GGUFModelConfig(Copyable):
    """Validated architecture and tokenizer settings read from GGUF metadata."""

    var architecture: String
    var context_length: Int
    var embedding_length: Int
    var feed_forward_length: Int
    var block_count: Int
    var head_count: Int
    var head_count_kv: Int
    var rope_dimension_count: Int
    var rms_epsilon: Float32
    var rope_freq_base: Float32
    var head_dim_override: Int
    var unknown_token_id: Int
    var bos_token_id: Int
    var eos_token_id: Int
    # Architecture scale/shape modifiers (0 = absent, engine default rules).
    # granite: embedding_scale 12.0, attention_scale 0.015625,
    # residual_scale 0.22, logit_scale 8.0. gemma2: attn/final logit
    # softcapping (50/30) and sliding_window 4096.
    var embedding_scale: Float32
    var attention_scale: Float32
    var residual_scale: Float32
    var logit_scale: Float32
    var attn_logit_softcapping: Float32
    var final_logit_softcapping: Float32
    var sliding_window: Int
    # Qwen3.5 hybrid SSM (Gated DeltaNet) hyperparameters.
    var ssm_conv_kernel: Int
    var ssm_state_size: Int
    var ssm_group_count: Int
    var ssm_time_step_rank: Int
    var ssm_inner_size: Int
    var full_attention_interval: Int
    # Gemma 4 (S-039): dual head dims, shared-KV and per-layer inputs.
    # Flat fields above describe the GLOBAL geometry (head_dim_override
    # comes from attention.key_length); these carry the local/SWA side.
    var head_dim_swa: Int
    var rope_freq_base_swa: Float32
    var shared_kv_layers: Int
    var per_layer_input_length: Int
    var sliding_window_pattern_mask: UInt64
    var sliding_window_pattern_count: Int

    def __init__(out self):
        self.architecture = ""
        self.context_length = 0
        self.embedding_length = 0
        self.feed_forward_length = 0
        self.block_count = 0
        self.head_count = 0
        self.head_count_kv = 0
        self.rope_dimension_count = 0
        self.rms_epsilon = 1e-5
        self.rope_freq_base = 10000.0
        self.head_dim_override = 0
        self.unknown_token_id = 0
        self.bos_token_id = 1
        self.eos_token_id = 2
        self.embedding_scale = 0.0
        self.attention_scale = 0.0
        self.residual_scale = 0.0
        self.logit_scale = 0.0
        self.attn_logit_softcapping = 0.0
        self.final_logit_softcapping = 0.0
        self.sliding_window = 0
        self.ssm_conv_kernel = 0
        self.ssm_state_size = 0
        self.ssm_group_count = 0
        self.ssm_time_step_rank = 0
        self.ssm_inner_size = 0
        self.full_attention_interval = 4
        self.head_dim_swa = 0
        self.rope_freq_base_swa = 0.0
        self.shared_kv_layers = 0
        self.per_layer_input_length = 0
        self.sliding_window_pattern_mask = UInt64(0)
        self.sliding_window_pattern_count = 0

    def __copyinit__(out self, existing: Self):
        self.architecture = String(existing.architecture)
        self.context_length = existing.context_length
        self.embedding_length = existing.embedding_length
        self.feed_forward_length = existing.feed_forward_length
        self.block_count = existing.block_count
        self.head_count = existing.head_count
        self.head_count_kv = existing.head_count_kv
        self.rope_dimension_count = existing.rope_dimension_count
        self.rms_epsilon = existing.rms_epsilon
        self.rope_freq_base = existing.rope_freq_base
        self.head_dim_override = existing.head_dim_override
        self.unknown_token_id = existing.unknown_token_id
        self.bos_token_id = existing.bos_token_id
        self.eos_token_id = existing.eos_token_id
        self.embedding_scale = existing.embedding_scale
        self.attention_scale = existing.attention_scale
        self.residual_scale = existing.residual_scale
        self.logit_scale = existing.logit_scale
        self.attn_logit_softcapping = existing.attn_logit_softcapping
        self.final_logit_softcapping = existing.final_logit_softcapping
        self.sliding_window = existing.sliding_window
        self.ssm_conv_kernel = existing.ssm_conv_kernel
        self.ssm_state_size = existing.ssm_state_size
        self.ssm_group_count = existing.ssm_group_count
        self.ssm_time_step_rank = existing.ssm_time_step_rank
        self.ssm_inner_size = existing.ssm_inner_size
        self.full_attention_interval = existing.full_attention_interval
        self.head_dim_swa = existing.head_dim_swa
        self.rope_freq_base_swa = existing.rope_freq_base_swa
        self.shared_kv_layers = existing.shared_kv_layers
        self.per_layer_input_length = existing.per_layer_input_length
        self.sliding_window_pattern_mask = existing.sliding_window_pattern_mask
        self.sliding_window_pattern_count = existing.sliding_window_pattern_count

    def head_dim(self) -> Int:
        if self.head_dim_override > 0:
            return self.head_dim_override
        if self.head_count <= 0:
            return 0
        return self.embedding_length // self.head_count

    def kv_dim(self) -> Int:
        return self.head_dim() * self.head_count_kv

    def gemma4_is_local(self, layer: Int) -> Bool:
        """True when layer uses sliding-window (local) attention, from
        the parsed sliding_window_pattern bitmask (bit set = local)."""
        if layer < 0 or layer >= self.sliding_window_pattern_count:
            return False
        return ((self.sliding_window_pattern_mask >> UInt64(layer)) & UInt64(1)) == UInt64(1)

    def gemma4_head_dim(self, layer: Int) -> Int:
        return self.head_dim_swa if self.gemma4_is_local(layer) else self.head_dim()

    def gemma4_owns_kv(self, layer: Int) -> Bool:
        return layer < self.block_count - self.shared_kv_layers

    def gemma4_kv_layer(self, layer: Int) -> Int:
        """Owning layer whose KV a (possibly shared) layer reads: the
        last owning local layer for local layers, the last owning
        global layer for global layers (E2B: 13 / 14)."""
        if self.gemma4_owns_kv(layer):
            return layer
        var want_local = self.gemma4_is_local(layer)
        var best = layer
        for cand in range(self.block_count - self.shared_kv_layers):
            if self.gemma4_is_local(cand) == want_local:
                best = cand
        return best

    def validate(mut self) raises:
        if len(self.architecture.as_bytes()) == 0:
            raise Error("GGUF architecture is not supported: empty")
        if self.context_length <= 0 or self.embedding_length <= 0:
            print("GGUF Metadata Debug: arch=", self.architecture, "ctx=", self.context_length, "emb=", self.embedding_length, "ffn=", self.feed_forward_length, "blk=", self.block_count, "heads=", self.head_count, "kv_heads=", self.head_count_kv, "rope=", self.rope_dimension_count)
            raise Error("GGUF model dimensions are incomplete")
        if self.feed_forward_length <= 0 or self.block_count <= 0:
            raise Error("GGUF layer metadata is incomplete")
        if self.head_count <= 0 or self.head_count_kv <= 0:
            raise Error("GGUF attention metadata is incomplete")
        if self.embedding_length % self.head_count != 0:
            raise Error("GGUF embedding length is not divisible by head count")
        if self.head_count % self.head_count_kv != 0:
            raise Error("GGUF query heads are not divisible by KV heads")
        if self.rope_dimension_count <= 0:
            self.rope_dimension_count = self.head_dim()
        elif self.rope_dimension_count != self.head_dim():
            raise Error("GGUF RoPE dimension does not match attention head size")


struct GGUFState:
    comptime UNOPENED = 0
    comptime HEADER_PARSED = 1
    comptime TENSORS_MAPPED = 2
    comptime VALIDATED = 3
    comptime FAILED = 4
    comptime CLOSED = 5

    @staticmethod
    def to_string(state: Int) -> String:
        if state == 0:
            return "UNOPENED"
        elif state == 1:
            return "HEADER_PARSED"
        elif state == 2:
            return "TENSORS_MAPPED"
        elif state == 3:
            return "VALIDATED"
        elif state == 4:
            return "FAILED"
        elif state == 5:
            return "CLOSED"
        return "UNKNOWN"


struct GGUFSeer:
    """Owns a validated read-only GGUF mmap and tensor descriptors into it."""

    var file_path: String
    var state: Int
    var tensors: Dict[String, RuneTensor[f16]]
    var tensor_file_offsets: Dict[String, Int]
    var tensor_types: Dict[String, UInt32]
    var config: GGUFModelConfig
    var fd: Int32
    var file_size: Int64
    # Captured only from a successful mapping, independent of declared size.
    var _mapping_extent: Int64
    # Admission route persists after cleanup; a provenance label is never a path.
    var _sealed_route: Bool
    var mmap_ptr: Pointer[Int8, MutUntrackedOrigin]
    var is_mapped: Bool
    var is_loaded: Bool
    var version: UInt32
    var tensor_count: Int
    var kv_count: Int
    var alignment: Int
    var data_offset: Int

    def __init__(out self, file_path: String):
        self.file_path = file_path
        self.state = GGUFState.UNOPENED
        self.tensors = Dict[String, RuneTensor[f16]]()
        self.tensor_file_offsets = Dict[String, Int]()
        self.tensor_types = Dict[String, UInt32]()
        self.config = GGUFModelConfig()
        self.fd = -1
        self.file_size = 0
        self._mapping_extent = 0
        self._sealed_route = False
        self.mmap_ptr = Pointer[Int8, MutUntrackedOrigin](unsafe_from_address=1)
        self.is_mapped = False
        self.is_loaded = False
        self.version = 0
        self.tensor_count = 0
        self.kv_count = 0
        self.alignment = 32
        self.data_offset = 0

    def _require_range(self, offset: Int, byte_count: Int) raises:
        if offset < 0 or byte_count < 0:
            raise Error("GGUF contains a negative byte range")
        if offset > Int(self.file_size) or byte_count > Int(self.file_size) - offset or offset > Int(self._mapping_extent) or byte_count > Int(self._mapping_extent) - offset:
            raise Error("GGUF is truncated or contains an out-of-range offset")

    def _read_u16(self, offset: Int) raises -> UInt16:
        if not self.is_mapped:
            raise Error("GGUF source is not mapped")
        self._require_range(offset, 2)
        var ptr = self.mmap_ptr.unsafe_offset(offset).unsafe_bitcast[UInt8]()
        return UInt16(ptr.unsafe_load()) | (UInt16(ptr.unsafe_offset(1).unsafe_load()) << 8)

    def _read_u32(self, offset: Int) raises -> UInt32:
        self._require_range(offset, 4)
        var ptr = self.mmap_ptr.unsafe_offset(offset).unsafe_bitcast[UInt8]()
        var b0 = UInt32(ptr.unsafe_offset(0).unsafe_load())
        var b1 = UInt32(ptr.unsafe_offset(1).unsafe_load())
        var b2 = UInt32(ptr.unsafe_offset(2).unsafe_load())
        var b3 = UInt32(ptr.unsafe_offset(3).unsafe_load())
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)

    def _read_i32(self, offset: Int) raises -> Int32:
        return Int32(self._read_u32(offset))

    def _read_u64(self, offset: Int) raises -> UInt64:
        self._require_range(offset, 8)
        var ptr = self.mmap_ptr.unsafe_offset(offset).unsafe_bitcast[UInt8]()
        var b0 = UInt64(ptr.unsafe_offset(0).unsafe_load())
        var b1 = UInt64(ptr.unsafe_offset(1).unsafe_load())
        var b2 = UInt64(ptr.unsafe_offset(2).unsafe_load())
        var b3 = UInt64(ptr.unsafe_offset(3).unsafe_load())
        var b4 = UInt64(ptr.unsafe_offset(4).unsafe_load())
        var b5 = UInt64(ptr.unsafe_offset(5).unsafe_load())
        var b6 = UInt64(ptr.unsafe_offset(6).unsafe_load())
        var b7 = UInt64(ptr.unsafe_offset(7).unsafe_load())
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24) | (b4 << 32) | (b5 << 40) | (b6 << 48) | (b7 << 56)

    def _read_f32(self, offset: Int) raises -> Float32:
        self._require_range(offset, 4)
        var bits = self._read_u32(offset)
        return bitcast[DType.float32](bits)

    def _read_string(self, offset: Int) raises -> String:
        var string_length = Int(self._read_u64(offset))
        self._require_range(offset + 8, string_length)
        var bytes = List[UInt8]()
        bytes.reserve(string_length)
        for index in range(string_length):
            bytes.append(UInt8(self.mmap_ptr.unsafe_offset(offset + 8 + index).unsafe_load()))
        # GGUF strings are length-prefixed UTF-8, not C strings. Preserve embedded
        # NULs and reject malformed UTF-8 instead of trusting an unsafe pointer.
        return String(from_utf8=bytes)

    def _string_end(self, offset: Int) raises -> Int:
        var string_length = Int(self._read_u64(offset))
        self._require_range(offset + 8, string_length)
        return offset + 8 + string_length

    def skip_value(self, value_type: UInt32, offset: Int) raises -> Int:
        if value_type == 0 or value_type == 1 or value_type == 7:
            self._require_range(offset, 1)
            return offset + 1
        if value_type == 2 or value_type == 3:
            self._require_range(offset, 2)
            return offset + 2
        if value_type == 4 or value_type == 5 or value_type == 6:
            self._require_range(offset, 4)
            return offset + 4
        if value_type == 10 or value_type == 11 or value_type == 12:
            self._require_range(offset, 8)
            return offset + 8
        if value_type == 8:
            return self._string_end(offset)
        if value_type == 9:
            var array_type = self._read_u32(offset)
            var array_length = self._read_u64(offset + 4)
            if array_type >= 13:
                raise Error("GGUF array contains an invalid element type")
            if array_length > UInt64(self.file_size):
                raise Error("GGUF array length exceeds the file size")
            var cursor = offset + 12
            for _ in range(Int(array_length)):
                cursor = self.skip_value(array_type, cursor)
            return cursor
        raise Error("GGUF contains an invalid metadata value type")

    def _parse_string_array(
        mut self,
        offset: Int,
        mut tokenizer: RuneWeaver,
    ) raises -> Int:
        var array_type = self._read_u32(offset)
        var array_length = Int(self._read_u64(offset + 4))
        if array_type != 8:
            raise Error("tokenizer.ggml.tokens must be a string array")
        var cursor = offset + 12
        for token_id in range(array_length):
            var token = self._read_string(cursor)
            cursor = self._string_end(cursor)
            tokenizer.add_token(token, token_id)
        return cursor

    def _parse_merge_array(
        mut self,
        offset: Int,
        mut tokenizer: RuneWeaver,
    ) raises -> Int:
        var array_type = self._read_u32(offset)
        var array_length = Int(self._read_u64(offset + 4))
        if array_type != 8:
            raise Error("tokenizer.ggml.merges must be a string array")
        var cursor = offset + 12
        for _ in range(array_length):
            var merge = self._read_string(cursor)
            cursor = self._string_end(cursor)
            tokenizer.add_merge(merge)
        return cursor

    def _parse_score_array(
        mut self,
        offset: Int,
        mut tokenizer: RuneWeaver,
    ) raises -> Int:
        var array_type = self._read_u32(offset)
        var array_length = Int(self._read_u64(offset + 4))
        if array_type != 6:
            raise Error("tokenizer.ggml.scores must be a float32 array")
        var cursor = offset + 12
        self._require_range(cursor, array_length * 4)
        for token_id in range(array_length):
            tokenizer.set_token_score(token_id, self._read_f32(cursor))
            cursor += 4
        return cursor

    def _parse_type_array(
        mut self,
        offset: Int,
        mut tokenizer: RuneWeaver,
    ) raises -> Int:
        var array_type = self._read_u32(offset)
        var array_length = Int(self._read_u64(offset + 4))
        if array_type != 5:
            raise Error("tokenizer.ggml.token_type must be an int32 array")
        var cursor = offset + 12
        self._require_range(cursor, array_length * 4)
        for token_id in range(array_length):
            tokenizer.set_token_type(token_id, Int(self._read_i32(cursor)))
            cursor += 4
        return cursor

    def _parse_metadata_value(
        mut self,
        key: String,
        value_type: UInt32,
        offset: Int,
        mut tokenizer: RuneWeaver,
    ) raises -> Int:
        if key == "tokenizer.ggml.tokens":
            if value_type != 9:
                raise Error("tokenizer.ggml.tokens is not an array")
            return self._parse_string_array(offset, tokenizer)
        if key == "tokenizer.ggml.scores":
            if value_type != 9:
                raise Error("tokenizer.ggml.scores is not an array")
            return self._parse_score_array(offset, tokenizer)
        if key == "tokenizer.ggml.token_type":
            if value_type != 9:
                raise Error("tokenizer.ggml.token_type is not an array")
            return self._parse_type_array(offset, tokenizer)
        if key == "tokenizer.ggml.merges":
            if value_type != 9:
                raise Error("tokenizer.ggml.merges is not an array")
            return self._parse_merge_array(offset, tokenizer)
        if key.endswith(".attention.sliding_window_pattern"):
            if value_type != 9:
                raise Error("sliding_window_pattern is not an array")
            var pat_elem = self._read_u32(offset)
            if pat_elem != 7:
                raise Error("sliding_window_pattern must hold BOOL values")
            var pat_count = Int(self._read_u64(offset + 4))
            if pat_count < 0 or pat_count > 64:
                raise Error("sliding_window_pattern length out of range")
            self._require_range(offset + 12, pat_count)
            var mask = UInt64(0)
            for li in range(pat_count):
                if self.mmap_ptr.unsafe_load(offset + 12 + li) != 0:
                    mask |= UInt64(1) << UInt64(li)
            self.config.sliding_window_pattern_mask = mask
            self.config.sliding_window_pattern_count = pat_count
            return offset + 12 + pat_count
        # Some architectures (gemma4) store per-layer configuration as an
        # ARRAY of the scalar type (e.g. feed_forward_length has one entry
        # per layer). The flat config takes element 0; architectures that
        # need every element read the array through their own profile path.
        var scalar_type = value_type
        var scalar_offset = offset
        if value_type == 9:
            var norm_elem_type = self._read_u32(offset)
            var elem_count = self._read_u64(offset + 4)
            if elem_count >= 1 and (norm_elem_type == 4 or norm_elem_type == 5 or norm_elem_type == 6):
                # INT32 array elements share the UINT32 byte layout for the
                # non-negative configuration values stored this way.
                scalar_type = UInt32(4) if norm_elem_type == 5 else norm_elem_type
                scalar_offset = offset + 12
        if key.endswith(".feed_forward_length") and value_type == 9:
            # Some converters (gemma4) store per-layer feed-forward
            # widths as a u32 array. The scalar config summary is the
            # maximum: arena and workspace sizing must cover the
            # widest layer, while per-layer GEMMs read their shapes
            # from the weight tensors themselves.
            var elem_type = self._read_u32(offset)
            if elem_type != 4 and elem_type != 5:
                raise Error("feed_forward_length array must hold integer widths")
            var layer_count = Int(self._read_u64(offset + 4))
            var cursor = offset + 12
            self._require_range(cursor, layer_count * 4)
            var widest = 0
            for _ in range(layer_count):
                var width = 0
                if elem_type == 4:
                    width = Int(self._read_u32(cursor))
                else:
                    width = Int(self._read_i32(cursor))
                if width > widest:
                    widest = width
                cursor += 4
            self.config.feed_forward_length = widest
            return cursor
        var expected_type = UInt32(4294967295)
        if key == "general.architecture" or key == "tokenizer.ggml.model" or key == "tokenizer.ggml.pre":
            expected_type = 8
        elif (
            key.endswith(".context_length")
            or key.endswith(".embedding_length")
            or key.endswith(".feed_forward_length")
            or key.endswith(".block_count")
            or key.endswith(".attention.head_count")
            or key.endswith(".attention.key_length")
            or key.endswith(".attention.head_count_kv")
            or key.endswith(".rope.dimension_count")
            or key.endswith(".attention.sliding_window")
            or key.endswith(".attention.key_length_swa")
            or key.endswith(".attention.shared_kv_layers")
            or key.endswith(".embedding_length_per_layer_input")
            or key.endswith(".ssm.conv_kernel")
            or key.endswith(".ssm.state_size")
            or key.endswith(".ssm.group_count")
            or key.endswith(".ssm.time_step_rank")
            or key.endswith(".ssm.inner_size")
            or key.endswith(".full_attention_interval")
            or key == "general.alignment"
            or key == "tokenizer.ggml.unknown_token_id"
            or key == "tokenizer.ggml.bos_token_id"
            or key == "tokenizer.ggml.eos_token_id"
        ):
            expected_type = 4
        elif (
            key.endswith(".rope.freq_base")
            or key.endswith(".rope.freq_base_swa")
            or key.endswith(".attention.layer_norm_rms_epsilon")
            or key.endswith(".embedding_scale")
            or key.endswith(".attention.scale")
            or key.endswith(".residual_scale")
            or key.endswith(".logit_scale")
            or key.endswith(".attn_logit_softcapping")
            or key.endswith(".final_logit_softcapping")
        ):
            expected_type = 6
        elif (
            key == "tokenizer.ggml.add_bos_token"
            or key == "tokenizer.ggml.add_space_prefix"
        ):
            expected_type = 7
        if expected_type != UInt32(4294967295) and scalar_type != expected_type:
            raise Error("GGUF metadata key has unexpected value type: " + key)
        if key == "general.architecture" and scalar_type == 8:
            self.config.architecture = self._read_string(scalar_offset)
        elif key.endswith(".context_length") and scalar_type == 4:
            self.config.context_length = Int(self._read_u32(scalar_offset))
        elif key.endswith(".embedding_length") and scalar_type == 4:
            self.config.embedding_length = Int(self._read_u32(scalar_offset))
        elif key.endswith(".feed_forward_length") and scalar_type == 4:
            self.config.feed_forward_length = Int(self._read_u32(scalar_offset))
        elif key.endswith(".block_count") and scalar_type == 4:
            self.config.block_count = Int(self._read_u32(scalar_offset))
        elif key.endswith(".attention.head_count") and scalar_type == 4:
            self.config.head_count = Int(self._read_u32(scalar_offset))
        elif key.endswith(".attention.key_length") and scalar_type == 4:
            self.config.head_dim_override = Int(self._read_u32(scalar_offset))
        elif key.endswith(".attention.head_count_kv") and scalar_type == 4:
            self.config.head_count_kv = Int(self._read_u32(scalar_offset))
        elif key.endswith(".rope.dimension_count") and scalar_type == 4:
            self.config.rope_dimension_count = Int(self._read_u32(scalar_offset))
        elif key.endswith(".rope.freq_base") and scalar_type == 6:
            self.config.rope_freq_base = self._read_f32(scalar_offset)
        elif key.endswith(".attention.layer_norm_rms_epsilon") and scalar_type == 6:
            self.config.rms_epsilon = self._read_f32(scalar_offset)
        elif key.endswith(".embedding_scale") and scalar_type == 6:
            self.config.embedding_scale = self._read_f32(scalar_offset)
        elif key.endswith(".attention.scale") and scalar_type == 6:
            self.config.attention_scale = self._read_f32(scalar_offset)
        elif key.endswith(".residual_scale") and scalar_type == 6:
            self.config.residual_scale = self._read_f32(scalar_offset)
        elif key.endswith(".logit_scale") and scalar_type == 6:
            self.config.logit_scale = self._read_f32(scalar_offset)
        elif key.endswith(".attn_logit_softcapping") and scalar_type == 6:
            self.config.attn_logit_softcapping = self._read_f32(scalar_offset)
        elif key.endswith(".final_logit_softcapping") and scalar_type == 6:
            self.config.final_logit_softcapping = self._read_f32(scalar_offset)
        elif key.endswith(".attention.sliding_window") and scalar_type == 4:
            self.config.sliding_window = Int(self._read_u32(scalar_offset))
        elif key == "tokenizer.ggml.model" and scalar_type == 8:
            tokenizer.model_name = self._read_string(scalar_offset)
        elif key == "tokenizer.ggml.pre" and scalar_type == 8:
            tokenizer.pre_tokenizer = self._read_string(scalar_offset)
        elif key.endswith(".attention.key_length_swa") and scalar_type == 4:
            self.config.head_dim_swa = Int(self._read_u32(scalar_offset))
        elif key.endswith(".rope.freq_base_swa") and scalar_type == 6:
            self.config.rope_freq_base_swa = self._read_f32(scalar_offset)
        elif key.endswith(".attention.shared_kv_layers") and scalar_type == 4:
            self.config.shared_kv_layers = Int(self._read_u32(scalar_offset))
        elif key.endswith(".embedding_length_per_layer_input") and scalar_type == 4:
            self.config.per_layer_input_length = Int(self._read_u32(scalar_offset))
        elif key.endswith(".ssm.conv_kernel") and scalar_type == 4:
            self.config.ssm_conv_kernel = Int(self._read_u32(scalar_offset))
        elif key.endswith(".ssm.state_size") and scalar_type == 4:
            self.config.ssm_state_size = Int(self._read_u32(scalar_offset))
        elif key.endswith(".ssm.group_count") and scalar_type == 4:
            self.config.ssm_group_count = Int(self._read_u32(scalar_offset))
        elif key.endswith(".ssm.time_step_rank") and scalar_type == 4:
            self.config.ssm_time_step_rank = Int(self._read_u32(scalar_offset))
        elif key.endswith(".ssm.inner_size") and scalar_type == 4:
            self.config.ssm_inner_size = Int(self._read_u32(scalar_offset))
        elif key.endswith(".full_attention_interval") and scalar_type == 4:
            self.config.full_attention_interval = Int(self._read_u32(scalar_offset))
        elif key == "general.alignment" and scalar_type == 4:
            self.alignment = Int(self._read_u32(scalar_offset))
        elif key == "tokenizer.ggml.unknown_token_id" and scalar_type == 4:
            self.config.unknown_token_id = Int(self._read_u32(scalar_offset))
        elif key == "tokenizer.ggml.bos_token_id" and scalar_type == 4:
            self.config.bos_token_id = Int(self._read_u32(scalar_offset))
        elif key == "tokenizer.ggml.eos_token_id" and scalar_type == 4:
            self.config.eos_token_id = Int(self._read_u32(scalar_offset))
        elif key == "tokenizer.ggml.add_bos_token" and value_type == 7:
            self._require_range(offset, 1)
            tokenizer.add_bos_token = (
                self.mmap_ptr.unsafe_offset(offset).unsafe_load() != 0
            )
        elif key == "tokenizer.ggml.add_space_prefix" and value_type == 7:
            self._require_range(offset, 1)
            tokenizer.add_space_prefix = self.mmap_ptr.unsafe_load(offset) != 0
        return self.skip_value(value_type, offset)

    def _adopt_owned_sealed_fd(mut self, owned_fd: Int64, expected_size: Int64) raises:
        # Busy refusal must not close an alias of this instance's live descriptor.
        if self.fd >= 0 or self.is_mapped or self._sealed_route:
            if owned_fd != Int64(self.fd):
                _ = os_close_descriptor(owned_fd)
            raise Error("GGUF sealed admission requires a fresh unmapped owner")
        self._sealed_route = True
        if owned_fd < 0 or owned_fd > 2147483647:
            raise Error("GGUF sealed source requires an exact live descriptor")
        self.fd = Int32(owned_fd)
        try:
            var arch = os_host_architecture()
            _require_sealed_source(arch, owned_fd, expected_size)
            if expected_size < 24:
                raise Error("GGUF file is smaller than the v3 header")
            var mapped_address = os_mmap(arch, expected_size, 1, 1, owned_fd, 0)
            if mapped_address == -1:
                raise Error("Failed to mmap GGUF model")
            self.file_size = expected_size
            self._mapping_extent = expected_size
            self.mmap_ptr = Pointer[Int8, MutUntrackedOrigin](unsafe_from_address=Int(mapped_address))
            self.is_mapped = True
        except e:
            self._cleanup()
            raise e

    def _open_and_map(mut self) raises:
        if self._sealed_route:
            if not self.is_mapped or self.fd < 0 or self._mapping_extent <= 0:
                raise Error("GGUF sealed source is closed or unmapped")
            return
        var path_bytes = List[Int8]()
        var source = self.file_path.as_bytes()
        if len(source) == 0 or len(source) >= 4096 or "\0" in self.file_path:
            raise Error("GGUF model path must contain 1..4095 non-NUL bytes")
        for index in range(len(source)):
            path_bytes.append(Int8(source[index]))
        path_bytes.append(0)
        # O_RDONLY | O_NONBLOCK | O_CLOEXEC. Final symlinks remain supported so
        # cataloged model links work, but their targets must be regular files.
        self.fd = external_call["open64", Int32](
            path_bytes.unsafe_ptr(), Int32(526336), Int32(0)
        )
        _ = path_bytes
        if self.fd < 0:
            raise Error("Failed to open GGUF model: " + self.file_path)

        # H041 (Mojo 1.1.0): InlineArray was removed from std.collections.
        # Same semantics via a raw 144-byte buffer (struct stat = 18 x UInt64).
        var stat = unsafe_alloc[UInt64](18)
        for si in range(18):
            stat[unsafe_offset=si] = 0
        if external_call["fstat", Int32](self.fd, stat) != 0:
            stat.unsafe_free()
            raise Error("Failed to inspect GGUF model")
        # H041 (aarch64 ABI): struct stat lays st_mode at word index 2 on
        # aarch64 but index 3 on x86_64; the other slot holds st_nlink, a small
        # hard-link count whose S_IFMT bits (0xF000) are zero in practice.
        # OR-ing both slots accepts S_IFREG on either ABI with zero behavior
        # change on x86_64 and fixes the regular-file check on ARM64.
        var mode_word = stat[unsafe_offset=2] | stat[unsafe_offset=3]
        if mode_word & 61440 != 32768:
            stat.unsafe_free()
            raise Error("GGUF model must be a regular file")
        if stat[unsafe_offset=6] < 24 or stat[unsafe_offset=6] > 9223372036854775807:
            stat.unsafe_free()
            raise Error("GGUF file is smaller than the v3 header")
        self.file_size = Int64(stat[unsafe_offset=6])
        stat.unsafe_free()

        var mapped_address = external_call["mmap", Int](
            Int(0), self.file_size, Int32(1), Int32(1), self.fd, Int64(0)
        )
        if mapped_address == -1:
            raise Error("Failed to mmap GGUF model")
        self.mmap_ptr = Pointer[Int8, MutUntrackedOrigin](
            unsafe_from_address=mapped_address
        )
        self._mapping_extent = self.file_size
        self.is_mapped = True

    def parse_header_bytes[origin: Origin](mut self, bytes_ptr: Pointer[UInt8, origin], size_bytes: Int, mut well: MimirWell) raises:
        if size_bytes < 24:
            raise Error("GGUF header byte buffer size must be at least 24 bytes")
        var b0 = UInt32(bytes_ptr.unsafe_offset(0).unsafe_load())
        var b1 = UInt32(bytes_ptr.unsafe_offset(1).unsafe_load())
        var b2 = UInt32(bytes_ptr.unsafe_offset(2).unsafe_load())
        var b3 = UInt32(bytes_ptr.unsafe_offset(3).unsafe_load())
        var magic = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
        if magic != 0x46554747:
            raise Error("GGUF magic bytes are invalid")
        var b4 = UInt32(bytes_ptr.unsafe_offset(4).unsafe_load())
        var b5 = UInt32(bytes_ptr.unsafe_offset(5).unsafe_load())
        var b6 = UInt32(bytes_ptr.unsafe_offset(6).unsafe_load())
        var b7 = UInt32(bytes_ptr.unsafe_offset(7).unsafe_load())
        var version = b4 | (b5 << 8) | (b6 << 16) | (b7 << 24)
        if version != 3:
            raise Error("Only GGUF version 3 is supported by this inference slice")

    def _parse_header(mut self) raises:
        if self._read_u32(0) != 0x46554747:
            raise Error("GGUF magic bytes are invalid")
        self.version = self._read_u32(4)
        if self.version != 3:
            raise Error("Only GGUF version 3 is supported by this inference slice")
        var tensor_count = self._read_u64(8)
        var kv_count = self._read_u64(16)
        if tensor_count > UInt64(self.file_size) or kv_count > UInt64(self.file_size):
            raise Error("GGUF entry counts exceed the file size")
        self.tensor_count = Int(tensor_count)
        self.kv_count = Int(kv_count)

    def _parse_metadata(
        mut self,
        mut tokenizer: RuneWeaver,
    ) raises -> Int:
        var cursor = 24
        var seen_keys = List[String]()
        for _ in range(self.kv_count):
            var key = self._read_string(cursor)
            if key in seen_keys:
                raise Error("GGUF contains duplicate metadata key: " + key)
            seen_keys.append(key)
            cursor = self._string_end(cursor)
            var value_type = self._read_u32(cursor)
            cursor += 4
            cursor = self._parse_metadata_value(
                key, value_type, cursor, tokenizer
            )
        if (
            self.alignment <= 0
            or self.alignment > 4096
            or (self.alignment & (self.alignment - 1)) != 0
        ):
            raise Error("GGUF alignment must be a power of two up to 4096")
        if self.config.architecture == "qwen2" or self.config.architecture == "qwen3" or self.config.architecture == "qwen35":
            tokenizer.add_bos_token = False
            tokenizer.bos_token_id = -1
        if self.config.architecture == "llama" and "tokenizer.ggml.add_space_prefix" not in seen_keys:
            tokenizer.add_space_prefix = True
        tokenizer.set_special_tokens(
            self.config.unknown_token_id,
            self.config.bos_token_id,
            self.config.eos_token_id,
        )
        tokenizer.validate_vocabulary()
        return cursor

    def _tensor_byte_size(
        self,
        element_count: Int,
        tensor_type: UInt32,
    ) raises -> Int:
        if tensor_type == GGMLType.F16:
            if element_count < 0 or element_count > 9223372036854775807 // 2:
                raise Error("GGUF tensor byte size overflows host index")
            return element_count * 2
        elif tensor_type == GGMLType.BF16:
            if element_count < 0 or element_count > 9223372036854775807 // 2:
                raise Error("GGUF tensor byte size overflows host index")
            return element_count * 2
        elif tensor_type == GGMLType.F32:
            if element_count < 0 or element_count > 9223372036854775807 // 4:
                raise Error("GGUF tensor byte size overflows host index")
            return element_count * 4
        elif tensor_type == GGMLType.Q4_0:
            if element_count < 0 or element_count // 32 > 9223372036854775807 // 18:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 32) * 18
        elif tensor_type == GGMLType.Q4_1:
            if element_count < 0 or element_count // 32 > 9223372036854775807 // 20:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 32) * 20
        elif tensor_type == GGMLType.Q8_0:
            if element_count < 0 or element_count // 32 > 9223372036854775807 // 34:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 32) * 34
        elif tensor_type == GGMLType.Q4_K:
            if element_count < 0 or element_count // 256 > 9223372036854775807 // 144:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 256) * 144
        elif tensor_type == GGMLType.Q2_K:
            if element_count < 0 or element_count // 256 > 9223372036854775807 // 84:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 256) * 84
        elif tensor_type == GGMLType.Q3_K:
            if element_count < 0 or element_count // 256 > 9223372036854775807 // 110:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 256) * 110
        elif tensor_type == GGMLType.Q5_K:
            if element_count < 0 or element_count // 256 > 9223372036854775807 // 176:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 256) * 176
        elif tensor_type == GGMLType.Q6_K:
            if element_count < 0 or element_count // 256 > 9223372036854775807 // 210:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 256) * 210
        elif tensor_type == GGMLType.IQ2_XXS:
            if element_count < 0 or element_count // 256 > 9223372036854775807 // 66:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 256) * 66
        elif tensor_type == GGMLType.IQ1_S:
            if element_count < 0 or element_count // 256 > 9223372036854775807 // 50:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 256) * 50
        elif tensor_type == GGMLType.IQ2_XS:
            if element_count < 0 or element_count // 256 > 9223372036854775807 // 74:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 256) * 74
        elif tensor_type == GGMLType.IQ3_XXS:
            if element_count < 0 or element_count // 256 > 9223372036854775807 // 98:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 256) * 98
        elif tensor_type == GGMLType.IQ3_S:
            if element_count < 0 or element_count // 256 > 9223372036854775807 // 110:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 256) * 110
        elif tensor_type == GGMLType.IQ2_S:
            if element_count < 0 or element_count // 256 > 9223372036854775807 // 82:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 256) * 82
        elif tensor_type == GGMLType.IQ4_NL:
            if element_count < 0 or element_count // 32 > 9223372036854775807 // 18:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 32) * 18
        elif tensor_type == GGMLType.IQ4_XS:
            if element_count < 0 or element_count // 256 > 9223372036854775807 // 136:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 256) * 136
        elif tensor_type == GGMLType.IQ1_M:
            if element_count < 0 or element_count // 256 > 9223372036854775807 // 56:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 256) * 56
        elif tensor_type == GGMLType.Q5_0:
            if element_count < 0 or element_count // 32 > 9223372036854775807 // 22:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 32) * 22
        elif tensor_type == GGMLType.Q5_1:
            if element_count < 0 or element_count // 32 > 9223372036854775807 // 24:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 32) * 24
        elif tensor_type == GGMLType.Q8_1:
            if element_count < 0 or element_count // 32 > 9223372036854775807 // 36:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 32) * 36
        elif tensor_type == GGMLType.TQ1_0:
            if element_count < 0 or element_count // 256 > 9223372036854775807 // 54:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 256) * 54
        elif tensor_type == GGMLType.TQ2_0:
            if element_count < 0 or element_count // 256 > 9223372036854775807 // 66:
                raise Error("GGUF tensor byte size overflows host index")
            return (element_count // 256) * 66
        if element_count < 0 or element_count // 32 > 9223372036854775807 // 18:
            raise Error("GGUF tensor byte size overflows host index")
        return (element_count // 32) * 18

    def _map_tensor(
        mut self,
        name: String,
        rows: Int,
        cols: Int,
        tensor_type: UInt32,
        tensor_offset: Int,
        mut pool: MimirWell,
    ) raises:
        # silent map
        if name in self.tensors:
            raise Error("GGUF contains a duplicate tensor name: " + name)
        if rows <= 0 or cols <= 0 or rows > 9223372036854775807 // cols:
            raise Error("GGUF tensor element count overflows host index: " + name)
        var element_count = rows * cols
        var byte_size = self._tensor_byte_size(element_count, tensor_type)
        if tensor_offset < 0 or tensor_offset % self.alignment != 0:
            raise Error("GGUF tensor offset is not correctly aligned: " + name)
        if tensor_offset > 9223372036854775807 - self.data_offset:
            raise Error("GGUF tensor absolute offset overflows host index: " + name)
        var absolute_offset = self.data_offset + tensor_offset
        self._require_range(absolute_offset, byte_size)

        if tensor_type == GGMLType.F16:
            var tensor_ptr = self.mmap_ptr.unsafe_offset(absolute_offset).unsafe_bitcast[Scalar[DType.float16]]()
            self.tensors[name] = RuneTensor[f16].checked(rows, cols, tensor_ptr, False)
        elif tensor_type == GGMLType.F32:
            if pool.offset < 0 or pool.offset > pool.capacity or element_count > pool.capacity - pool.offset:
                raise Error("MimirWell cannot hold converted F32 normalization tensor")
            var destination = pool.allocate(element_count)
            var source = self.mmap_ptr.unsafe_offset(absolute_offset).unsafe_bitcast[Float32]()
            for index in range(element_count):
                destination.unsafe_store(index, source.unsafe_load(index).cast[f16]())
            self.tensors[name] = RuneTensor[f16].checked(rows, cols, destination, False)
        elif tensor_type == GGMLType.BF16:
            # BF16 tensors (e.g. gemma4's per-layer projection) are
            # converted into the pool as f16 at load, the same
            # treatment F32 tensors get above; bf16 -> f32 is exact
            # and f32 -> f16 rounds identically to the F32 route.
            # S-089: the conversion is the shared convert_bf16_to_f16
            # primitive in core/mimir_well (the vision line's at-load
            # conversion, generalized) — same arithmetic, factored out.
            if pool.offset < 0 or pool.offset > pool.capacity or element_count > pool.capacity - pool.offset:
                raise Error("MimirWell cannot hold converted BF16 tensor")
            var destination = pool.allocate(element_count)
            var source = self.mmap_ptr.unsafe_offset(absolute_offset).unsafe_bitcast[UInt16]()
            convert_bf16_to_f16(source, destination, element_count)
            self.tensors[name] = RuneTensor[f16].checked(rows, cols, destination, False)
        else:
            var tensor_ptr = self.mmap_ptr.unsafe_offset(absolute_offset).unsafe_bitcast[Scalar[DType.float16]]()
            var fmt = GGMLType.to_compressed_format(tensor_type)
            var is_q = True
            self.tensors[name] = RuneTensor[f16].checked(rows, cols, tensor_ptr, is_q, fmt)
        self.tensor_file_offsets[name] = absolute_offset
        self.tensor_types[name] = tensor_type

    def _parse_tensors(
        mut self,
        table_offset: Int,
        mut pool: MimirWell,
    ) raises:
        var names = List[String]()
        var rows_list = List[Int]()
        var cols_list = List[Int]()
        var types = List[UInt32]()
        var offsets = List[Int]()
        var cursor = table_offset

        for _ in range(self.tensor_count):
            var name = self._read_string(cursor)
            cursor = self._string_end(cursor)
            var dimension_count = Int(self._read_u32(cursor))
            cursor += 4
            if dimension_count <= 0 or dimension_count > 2:
                raise Error("Inference tensor must have one or two dimensions: " + name)
            var cols_u64 = self._read_u64(cursor)
            if cols_u64 > UInt64(9223372036854775807):
                raise Error("GGUF tensor dimension exceeds host index: " + name)
            var cols = Int(cols_u64)
            cursor += 8
            var rows = 1
            if dimension_count == 2:
                var rows_u64 = self._read_u64(cursor)
                if rows_u64 > UInt64(9223372036854775807):
                    raise Error("GGUF tensor dimension exceeds host index: " + name)
                rows = Int(rows_u64)
                cursor += 8
            if rows <= 0 or cols <= 0:
                raise Error("GGUF tensor has a non-positive dimension: " + name)
            var tensor_type = self._read_u32(cursor)
            cursor += 4
            var tensor_offset = Int(self._read_u64(cursor))
            cursor += 8
            names.append(name)
            rows_list.append(rows)
            cols_list.append(cols)
            types.append(tensor_type)
            offsets.append(tensor_offset)

        self.data_offset = (
            (cursor + self.alignment - 1) // self.alignment
        ) * self.alignment
        self._require_range(self.data_offset, 0)
        for index in range(len(names)):
            self._map_tensor(
                names[index],
                rows_list[index],
                cols_list[index],
                types[index],
                offsets[index],
                pool,
            )

    def _require_tensor_shape(
        self,
        name: String,
        expected_rows: Int,
        expected_cols: Int,
        expected_type: UInt32,
    ) raises:
        if name not in self.tensors:
            raise Error("GGUF is missing required tensor: " + name)
        ref tensor = self.tensors[name]
        if tensor.rows != expected_rows or tensor.cols != expected_cols:
            raise Error("GGUF required tensor has an invalid shape: " + name + " actual: " + String(tensor.rows) + "x" + String(tensor.cols) + " expected: " + String(expected_rows) + "x" + String(expected_cols))
        var actual_type = self.tensor_types.get(name, UInt32(99))
        if actual_type == UInt32(99):
            raise Error("GGUF required tensor has an invalid type: " + name)

    def _validate_required_tensors(mut self) raises:
        if "output.weight" not in self.tensors and "token_embd.weight" in self.tensors:
            self.tensors["output.weight"] = self.tensors["token_embd.weight"].copy()
            self.tensor_types["output.weight"] = self.tensor_types.get("token_embd.weight", UInt32(1))
            self.tensor_file_offsets["output.weight"] = self.tensor_file_offsets["token_embd.weight"]
        if self.config.architecture == "qwen35":
            self._validate_qwen35_tensors()
            return
        if self.config.architecture == "gemma4":
            self._validate_gemma4_tensors()
            return
        var required = List[String]()
        required.append("token_embd.weight")
        required.append("output_norm.weight")
        required.append("output.weight")
        for layer_index in range(self.config.block_count):
            var prefix = String("blk.") + String(layer_index) + String(".")
            required.append(prefix + String("attn_norm.weight"))
            required.append(prefix + String("attn_q.weight"))
            required.append(prefix + String("attn_k.weight"))
            required.append(prefix + String("attn_v.weight"))
            required.append(prefix + String("attn_output.weight"))
            required.append(prefix + String("ffn_norm.weight"))
            required.append(prefix + String("ffn_gate.weight"))
            required.append(prefix + String("ffn_up.weight"))
            required.append(prefix + String("ffn_down.weight"))
        for index in range(len(required)):
            if required[index] not in self.tensors:
                raise Error("GGUF is missing required tensor: " + required[index])

        var hidden = self.config.embedding_length
        var kv_dim = self.config.kv_dim()
        var ffn = self.config.feed_forward_length
        var vocab = self.tensors["token_embd.weight"].rows
        self._require_tensor_shape(
            "token_embd.weight", vocab, hidden, GGMLType.F16
        )
        self._require_tensor_shape(
            "output_norm.weight", 1, hidden, GGMLType.F32
        )
        self._require_tensor_shape(
            "output.weight", vocab, hidden, GGMLType.F16
        )
        for layer_index in range(self.config.block_count):
            var prefix = String("blk.") + String(layer_index) + String(".")
            self._require_tensor_shape(
                prefix + "attn_norm.weight", 1, hidden, GGMLType.F32
            )
            var q_width = self.config.head_count * self.config.head_dim()
            self._require_tensor_shape(
                prefix + "attn_q.weight", q_width, hidden, GGMLType.F16
            )
            self._require_tensor_shape(
                prefix + "attn_k.weight", kv_dim, hidden, GGMLType.F16
            )
            self._require_tensor_shape(
                prefix + "attn_v.weight", kv_dim, hidden, GGMLType.F16
            )
            self._require_tensor_shape(
                prefix + "attn_output.weight", hidden, q_width, GGMLType.F16
            )
            self._require_tensor_shape(
                prefix + "ffn_norm.weight", 1, hidden, GGMLType.F32
            )
            self._require_tensor_shape(
                prefix + "ffn_gate.weight", ffn, hidden, GGMLType.F16
            )
            self._require_tensor_shape(
                prefix + "ffn_up.weight", ffn, hidden, GGMLType.F16
            )
            self._require_tensor_shape(
                prefix + "ffn_down.weight", hidden, ffn, GGMLType.F16
            )


    def _validate_gemma4_tensors(mut self) raises:
        """Layer-aware validation for Gemma 4 (S-039).

        Gemma 4 breaks the flat required-tensor assumptions three ways:
        shared-KV layers (the last `shared_kv_layers` layers carry no
        attn_k/attn_v tensors of their own), dual head dims (global
        512 vs sliding-window 256, per the sliding_window_pattern), and
        per-layer feed-forward widths. Shapes are therefore checked
        relationally, from each layer's own tensors: q width from
        attn_q, FFN width from ffn_gate, KV only on owning layers.
        Plus the global per-layer-input (PLE) tensors."""
        var hidden = self.config.embedding_length
        var heads = self.config.head_count
        var kv_heads = self.config.head_count_kv
        var layers = self.config.block_count
        if self.config.shared_kv_layers <= 0 or self.config.shared_kv_layers >= layers:
            raise Error("GGUF gemma4 shared_kv_layers metadata is incomplete")
        if self.config.head_dim_swa <= 0 or self.config.per_layer_input_length <= 0:
            raise Error("GGUF gemma4 SWA / per-layer-input metadata is incomplete")
        if self.config.sliding_window_pattern_count != layers:
            raise Error("GGUF gemma4 sliding_window_pattern does not cover every layer")
        var vocab = self.tensors["token_embd.weight"].rows
        self._require_tensor_shape(
            "token_embd.weight", vocab, hidden, GGMLType.F16
        )
        self._require_tensor_shape(
            "output_norm.weight", 1, hidden, GGMLType.F32
        )
        self._require_tensor_shape(
            "output.weight", vocab, hidden, GGMLType.F16
        )
        var ple_width = layers * self.config.per_layer_input_length
        self._require_tensor_shape(
            "per_layer_token_embd.weight", vocab, ple_width, GGMLType.F16
        )
        self._require_tensor_shape(
            "per_layer_model_proj.weight", ple_width, hidden, GGMLType.F16
        )
        self._require_tensor_shape(
            "per_layer_proj_norm.weight", 1, self.config.per_layer_input_length, GGMLType.F32
        )
        self._require_tensor_shape(
            "rope_freqs.weight", 1, self.config.head_dim() // 2, GGMLType.F32
        )
        for layer_index in range(layers):
            var prefix = String("blk.") + String(layer_index) + String(".")
            var head_dim = self.config.gemma4_head_dim(layer_index)
            var q_width = heads * head_dim
            self._require_tensor_shape(
                prefix + "attn_norm.weight", 1, hidden, GGMLType.F32
            )
            self._require_tensor_shape(
                prefix + "attn_q.weight", q_width, hidden, GGMLType.F16
            )
            self._require_tensor_shape(
                prefix + "attn_q_norm.weight", 1, head_dim, GGMLType.F32
            )
            self._require_tensor_shape(
                prefix + "attn_output.weight", hidden, q_width, GGMLType.F16
            )
            if self.config.gemma4_owns_kv(layer_index):
                var kv_width = kv_heads * head_dim
                self._require_tensor_shape(
                    prefix + "attn_k.weight", kv_width, hidden, GGMLType.F16
                )
                self._require_tensor_shape(
                    prefix + "attn_v.weight", kv_width, hidden, GGMLType.F16
                )
                self._require_tensor_shape(
                    prefix + "attn_k_norm.weight", 1, head_dim, GGMLType.F32
                )
            for norm_name in ["post_attention_norm.weight", "ffn_norm.weight", "post_ffw_norm.weight", "post_norm.weight"]:
                self._require_tensor_shape(
                    prefix + norm_name, 1, hidden, GGMLType.F32
                )
            var ffn = self.tensors[prefix + "ffn_gate.weight"].rows
            self._require_tensor_shape(
                prefix + "ffn_gate.weight", ffn, hidden, GGMLType.F16
            )
            self._require_tensor_shape(
                prefix + "ffn_up.weight", ffn, hidden, GGMLType.F16
            )
            self._require_tensor_shape(
                prefix + "ffn_down.weight", hidden, ffn, GGMLType.F16
            )
            var ple = self.config.per_layer_input_length
            self._require_tensor_shape(
                prefix + "inp_gate.weight", ple, hidden, GGMLType.F16
            )
            self._require_tensor_shape(
                prefix + "proj.weight", hidden, ple, GGMLType.F16
            )
            self._require_tensor_shape(
                prefix + "layer_output_scale.weight", 1, 1, GGMLType.F32
            )

    def _validate_qwen35_tensors(mut self) raises:
        """Layer-type-aware validation for the Qwen3.5 hybrid arch.

        Every `full_attention_interval`-th layer (1-based) is a full
        attention layer with a fused query+gate projection of twice the
        query width; the rest are Gated DeltaNet SSM layers. No layer
        carries ffn_norm.weight: post_attention_norm.weight plays the
        pre-FFN norm role for both layer types.
        """
        var hidden = self.config.embedding_length
        var kv_dim = self.config.kv_dim()
        var ffn = self.config.feed_forward_length
        var vocab = self.tensors["token_embd.weight"].rows
        var interval = self.config.full_attention_interval
        if interval <= 0:
            interval = 4
        var inner = self.config.ssm_inner_size
        var groups = self.config.ssm_group_count
        var state = self.config.ssm_state_size
        var dt_rank = self.config.ssm_time_step_rank
        if inner <= 0 or groups <= 0 or state <= 0 or dt_rank <= 0:
            raise Error("GGUF qwen35 SSM metadata is incomplete")
        self._require_tensor_shape(
            "token_embd.weight", vocab, hidden, GGMLType.F16
        )
        self._require_tensor_shape(
            "output_norm.weight", 1, hidden, GGMLType.F32
        )
        self._require_tensor_shape(
            "output.weight", vocab, hidden, GGMLType.F16
        )
        for layer_index in range(self.config.block_count):
            var prefix = String("blk.") + String(layer_index) + String(".")
            self._require_tensor_shape(
                prefix + "attn_norm.weight", 1, hidden, GGMLType.F32
            )
            self._require_tensor_shape(
                prefix + "post_attention_norm.weight", 1, hidden, GGMLType.F32
            )
            self._require_tensor_shape(
                prefix + "ffn_gate.weight", ffn, hidden, GGMLType.F16
            )
            self._require_tensor_shape(
                prefix + "ffn_up.weight", ffn, hidden, GGMLType.F16
            )
            self._require_tensor_shape(
                prefix + "ffn_down.weight", hidden, ffn, GGMLType.F16
            )
            var q_width = self.config.head_count * self.config.head_dim()
            if (layer_index + 1) % interval == 0:
                self._require_tensor_shape(
                    prefix + "attn_q.weight", 2 * q_width, hidden, GGMLType.F16
                )
                self._require_tensor_shape(
                    prefix + "attn_k.weight", kv_dim, hidden, GGMLType.F16
                )
                self._require_tensor_shape(
                    prefix + "attn_v.weight", kv_dim, hidden, GGMLType.F16
                )
                self._require_tensor_shape(
                    prefix + "attn_output.weight", hidden, q_width, GGMLType.F16
                )
                self._require_tensor_shape(
                    prefix + "attn_q_norm.weight", 1, self.config.head_dim(), GGMLType.F32
                )
                self._require_tensor_shape(
                    prefix + "attn_k_norm.weight", 1, self.config.head_dim(), GGMLType.F32
                )
            else:
                self._require_tensor_shape(
                    prefix + "attn_qkv.weight", 3 * inner, hidden, GGMLType.F16
                )
                self._require_tensor_shape(
                    prefix + "attn_gate.weight", inner, hidden, GGMLType.F16
                )
                self._require_tensor_shape(
                    prefix + "ssm_alpha.weight", dt_rank, hidden, GGMLType.F16
                )
                self._require_tensor_shape(
                    prefix + "ssm_beta.weight", dt_rank, hidden, GGMLType.F16
                )
                self._require_tensor_shape(
                    prefix + "ssm_a", 1, dt_rank, GGMLType.F32
                )
                self._require_tensor_shape(
                    prefix + "ssm_conv1d.weight", inner * 3, self.config.ssm_conv_kernel, GGMLType.F32
                )
                self._require_tensor_shape(
                    prefix + "ssm_dt.bias", 1, dt_rank, GGMLType.F32
                )
                self._require_tensor_shape(
                    prefix + "ssm_norm.weight", 1, state, GGMLType.F32
                )
                self._require_tensor_shape(
                    prefix + "ssm_out.weight", hidden, inner, GGMLType.F16
                )

    def _cleanup(mut self):
        if self.is_mapped:
            if self.mmap_ptr != Pointer[Int8, MutUntrackedOrigin](unsafe_from_address=1):
                _ = external_call["munmap", Int32](self.mmap_ptr, self._mapping_extent)
            self.mmap_ptr = Pointer[Int8, MutUntrackedOrigin](unsafe_from_address=1)
            self.is_mapped = False
        self._mapping_extent = 0
        if self.fd >= 0:
            _ = external_call["close", Int32](self.fd)
            self.fd = -1
        self.is_loaded = False

    def close(mut self):
        self._cleanup()
        self.state = GGUFState.CLOSED

    def mmap_and_load(mut self, mut pool: MimirWell) raises:
        var tokenizer = RuneWeaver()
        self.mmap_and_load(pool, tokenizer)

    def inspect_metadata(
        mut self,
        mut tokenizer: RuneWeaver,
    ) raises:
        """Reads validated header and model metadata without mapping tensors."""
        try:
            self._open_and_map()
            self._parse_header()
            self.state = GGUFState.HEADER_PARSED
            _ = self._parse_metadata(tokenizer)
        except e:
            self._cleanup()
            self.state = GGUFState.FAILED
            raise e

    def mmap_and_load(
        mut self,
        mut pool: MimirWell,
        mut tokenizer: RuneWeaver,
    ) raises:
        try:
            self._open_and_map()
            self._parse_header()
            self.state = GGUFState.HEADER_PARSED
            var tensor_table_offset = self._parse_metadata(tokenizer)
            self._parse_tensors(tensor_table_offset, pool)
            self.state = GGUFState.TENSORS_MAPPED
            self._validate_required_tensors()
            self.state = GGUFState.VALIDATED
            self.is_loaded = True
            print(
                "GGUF validated:",
                self.tensor_count,
                "tensors,",
                self.kv_count,
                "metadata entries, architecture",
                self.config.architecture,
            )
        except e:
            self._cleanup()
            self.state = GGUFState.FAILED
            raise e

    def __deinit__(deinit self):
        self._cleanup()
