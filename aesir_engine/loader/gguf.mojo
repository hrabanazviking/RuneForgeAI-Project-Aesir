# loader/gguf.mojo
# Bounds-checked GGUF v3 loader with real mmap-backed F16 tensor views.

from std.collections import Dict
from std.ffi import external_call
from std.memory import Pointer, bitcast

from core.mimir_well import (
    CompressedFormatType,
    MimirWell,
    RuneTensor,
    f16,
)
from loader.tokenizer import RuneWeaver


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
    comptime GPTQ_4BIT = 20
    comptime AWQ_4BIT = 21
    comptime EXL2 = 22
    comptime HQQ = 23
    comptime SMOOTHQUANT = 24

    @staticmethod
    def to_compressed_format(ggml_type: UInt32) -> CompressedFormatType:
        if ggml_type == 2:
            return CompressedFormatType(CompressedFormatType.Q4_0)
        elif ggml_type == 3:
            return CompressedFormatType(CompressedFormatType.Q4_1)
        elif ggml_type == 6:
            return CompressedFormatType(CompressedFormatType.Q5_0)
        elif ggml_type == 7:
            return CompressedFormatType(CompressedFormatType.Q5_1)
        elif ggml_type == 8:
            return CompressedFormatType(CompressedFormatType.Q8_0)
        elif ggml_type == 9:
            return CompressedFormatType(CompressedFormatType.Q8_1)
        elif ggml_type == 10:
            return CompressedFormatType(CompressedFormatType.Q2_K)
        elif ggml_type == 11:
            return CompressedFormatType(CompressedFormatType.Q3_K_M)
        elif ggml_type == 12:
            return CompressedFormatType(CompressedFormatType.Q4_K_M)
        elif ggml_type == 13:
            return CompressedFormatType(CompressedFormatType.Q5_K_M)
        elif ggml_type == 14:
            return CompressedFormatType(CompressedFormatType.Q6_K)
            return CompressedFormatType(CompressedFormatType.Q8_1)
        elif ggml_type == 20:
            return CompressedFormatType(CompressedFormatType.GPTQ_4BIT)
        elif ggml_type == 21:
            return CompressedFormatType(CompressedFormatType.AWQ_4BIT)
        elif ggml_type == 22:
            return CompressedFormatType(CompressedFormatType.EXL2_VARBIT)
        elif ggml_type == 23:
            return CompressedFormatType(CompressedFormatType.HQQ)
        elif ggml_type == 24:
            return CompressedFormatType(CompressedFormatType.SMOOTHQUANT_INT8)
        elif ggml_type == 25:
            return CompressedFormatType(CompressedFormatType.IQ1_S)
        elif ggml_type == 19:
            return CompressedFormatType(CompressedFormatType.IQ2_XXS)
        elif ggml_type == 27:
            return CompressedFormatType(CompressedFormatType.TERNARY_155BIT)
        return CompressedFormatType(CompressedFormatType.Q4_K_M)


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

    def head_dim(self) -> Int:
        if self.head_dim_override > 0:
            return self.head_dim_override
        if self.head_count <= 0:
            return 0
        return self.embedding_length // self.head_count

    def kv_dim(self) -> Int:
        return self.head_dim() * self.head_count_kv

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
        if offset > Int(self.file_size) or byte_count > Int(self.file_size) - offset:
            raise Error("GGUF is truncated or contains an out-of-range offset")

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
        var bytes = List[Int8]()
        for index in range(string_length):
            bytes.append(self.mmap_ptr.unsafe_offset(offset + 8 + index).unsafe_load())
        bytes.append(0)
        return String(unsafe_from_utf8_ptr=bytes.unsafe_ptr())

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
        if key == "general.architecture" and value_type == 8:
            self.config.architecture = self._read_string(offset)
        elif key.endswith(".context_length") and value_type == 4:
            self.config.context_length = Int(self._read_u32(offset))
        elif key.endswith(".embedding_length") and value_type == 4:
            self.config.embedding_length = Int(self._read_u32(offset))
        elif key.endswith(".feed_forward_length") and value_type == 4:
            self.config.feed_forward_length = Int(self._read_u32(offset))
        elif key.endswith(".block_count") and value_type == 4:
            self.config.block_count = Int(self._read_u32(offset))
        elif key.endswith(".attention.head_count") and value_type == 4:
            self.config.head_count = Int(self._read_u32(offset))
        elif key.endswith(".attention.key_length") and value_type == 4:
            self.config.head_dim_override = Int(self._read_u32(offset))
        elif key.endswith(".attention.head_count_kv") and value_type == 4:
            self.config.head_count_kv = Int(self._read_u32(offset))
        elif key.endswith(".rope.dimension_count") and value_type == 4:
            self.config.rope_dimension_count = Int(self._read_u32(offset))
        elif key.endswith(".rope.freq_base") and value_type == 6:
            self.config.rope_freq_base = self._read_f32(offset)
        elif key.endswith(".attention.layer_norm_rms_epsilon") and value_type == 6:
            self.config.rms_epsilon = self._read_f32(offset)
        elif key == "general.alignment" and value_type == 4:
            self.alignment = Int(self._read_u32(offset))
        elif key == "tokenizer.ggml.unknown_token_id" and value_type == 4:
            self.config.unknown_token_id = Int(self._read_u32(offset))
        elif key == "tokenizer.ggml.bos_token_id" and value_type == 4:
            self.config.bos_token_id = Int(self._read_u32(offset))
        elif key == "tokenizer.ggml.eos_token_id" and value_type == 4:
            self.config.eos_token_id = Int(self._read_u32(offset))
        elif key == "tokenizer.ggml.add_bos_token" and value_type == 7:
            self._require_range(offset, 1)
            tokenizer.add_bos_token = (
                self.mmap_ptr.unsafe_offset(offset).unsafe_load() != 0
            )
        elif key == "tokenizer.ggml.add_space_prefix" and value_type == 7:
            self._require_range(offset, 1)
            tokenizer.add_space_prefix = self.mmap_ptr.unsafe_load(offset) != 0
        return self.skip_value(value_type, offset)

    def _open_and_map(mut self) raises:
        var path_bytes = List[Int8]()
        var source = self.file_path.as_bytes()
        for index in range(len(source)):
            path_bytes.append(Int8(source[index]))
        path_bytes.append(0)
        self.fd = external_call["open64", Int32](path_bytes.unsafe_ptr(), Int32(0), Int32(0))
        _ = path_bytes
        if self.fd < 0:
            raise Error("Failed to open GGUF model: " + self.file_path)

        self.file_size = external_call["lseek", Int64](self.fd, Int64(0), Int32(2))
        _ = external_call["lseek", Int64](self.fd, Int64(0), Int32(0))
        if self.file_size < 24:
            raise Error("GGUF file is smaller than the v3 header")

        var mapped_address = external_call["mmap", Int](
            Int(0), self.file_size, Int32(1), Int32(1), self.fd, Int64(0)
        )
        if mapped_address == -1:
            raise Error("Failed to mmap GGUF model")
        self.mmap_ptr = Pointer[Int8, MutUntrackedOrigin](
            unsafe_from_address=mapped_address
        )
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
        if self.config.architecture == "qwen2":
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
            return element_count * 2
        elif tensor_type == GGMLType.F32:
            return element_count * 4
        elif tensor_type == GGMLType.Q4_0:
            return (element_count // 32) * 18
        elif tensor_type == GGMLType.Q4_1:
            return (element_count // 32) * 20
        elif tensor_type == GGMLType.Q8_0:
            return (element_count // 32) * 34
        elif tensor_type == GGMLType.Q4_K:
            return (element_count // 256) * 144
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
        var element_count = rows * cols
        var byte_size = self._tensor_byte_size(element_count, tensor_type)
        if tensor_offset < 0 or tensor_offset % self.alignment != 0:
            raise Error("GGUF tensor offset is not correctly aligned: " + name)
        var absolute_offset = self.data_offset + tensor_offset
        self._require_range(absolute_offset, byte_size)

        if tensor_type == GGMLType.F16:
            var tensor_ptr = self.mmap_ptr.unsafe_offset(absolute_offset).unsafe_bitcast[Scalar[DType.float16]]()
            self.tensors[name] = RuneTensor[f16].checked(rows, cols, tensor_ptr, False)
        elif tensor_type == GGMLType.F32:
            if pool.offset + element_count > pool.capacity:
                raise Error("MimirWell cannot hold converted F32 normalization tensor")
            var destination = pool.allocate(element_count)
            var source = self.mmap_ptr.unsafe_offset(absolute_offset).unsafe_bitcast[Float32]()
            for index in range(element_count):
                destination.unsafe_store(index, source.unsafe_load(index).cast[f16]())
            self.tensors[name] = RuneTensor[f16].checked(rows, cols, destination, False)
        else:
            var tensor_ptr = self.mmap_ptr.unsafe_offset(absolute_offset).unsafe_bitcast[Scalar[DType.float16]]()
            var fmt = GGMLType.to_compressed_format(tensor_type)
            var is_q = True
            if name == "token_embd.weight" or name == "output.weight":
                self.tensors[name] = RuneTensor[f16].checked(rows, cols, tensor_ptr, is_q, fmt)
            else:
                self.tensors[name] = RuneTensor[f16].checked(cols, rows, tensor_ptr, is_q, fmt)
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
            var cols = Int(self._read_u64(cursor))
            cursor += 8
            var rows = 1
            if dimension_count == 2:
                rows = Int(self._read_u64(cursor))
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
        if (tensor.rows != expected_rows or tensor.cols != expected_cols) and (tensor.rows != expected_cols or tensor.cols != expected_rows):
            raise Error("GGUF required tensor has an invalid shape: " + name + " actual: " + String(tensor.rows) + "x" + String(tensor.cols) + " expected: " + String(expected_rows) + "x" + String(expected_cols))
        var actual_type = self.tensor_types.get(name, UInt32(99))
        if actual_type == UInt32(99):
            raise Error("GGUF required tensor has an invalid type: " + name)

    def _validate_required_tensors(mut self) raises:
        if "output.weight" not in self.tensors and "token_embd.weight" in self.tensors:
            self.tensors["output.weight"] = self.tensors["token_embd.weight"].copy()
            self.tensor_types["output.weight"] = self.tensor_types.get("token_embd.weight", UInt32(1))
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
            var q_rows = self.tensors[prefix + "attn_q.weight"].rows
            var q_cols = self.tensors[prefix + "attn_q.weight"].cols
            var k_rows = self.tensors[prefix + "attn_k.weight"].rows
            var k_cols = self.tensors[prefix + "attn_k.weight"].cols
            var v_rows = self.tensors[prefix + "attn_v.weight"].rows
            var v_cols = self.tensors[prefix + "attn_v.weight"].cols
            self._require_tensor_shape(
                prefix + "attn_q.weight", q_rows, q_cols, GGMLType.F16
            )
            self._require_tensor_shape(
                prefix + "attn_k.weight", k_rows, k_cols, GGMLType.F16
            )
            self._require_tensor_shape(
                prefix + "attn_v.weight", v_rows, v_cols, GGMLType.F16
            )
            var out_cols = self.tensors[prefix + "attn_output.weight"].cols
            var out_rows = self.tensors[prefix + "attn_output.weight"].rows
            self._require_tensor_shape(
                prefix + "attn_output.weight", out_rows, out_cols, GGMLType.F16
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

    def _cleanup(mut self):
        if self.is_mapped:
            if self.mmap_ptr != Pointer[Int8, MutUntrackedOrigin](unsafe_from_address=1):
                _ = external_call["munmap", Int32](self.mmap_ptr, self.file_size)
            self.mmap_ptr = Pointer[Int8, MutUntrackedOrigin](unsafe_from_address=1)
            self.is_mapped = False
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
