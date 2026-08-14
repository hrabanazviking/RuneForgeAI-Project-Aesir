# loader/gguf.mojo
# Bounds-checked GGUF v3 loader with real mmap-backed F16 tensor views.

from std.collections import Dict
from std.ffi import external_call
from std.memory import Pointer

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
        if ggml_type == 10:
            return CompressedFormatType(CompressedFormatType.Q2_K)
        elif ggml_type == 11:
            return CompressedFormatType(CompressedFormatType.Q3_K_M)
        elif ggml_type == 2:
            return CompressedFormatType(CompressedFormatType.Q4_0)
        elif ggml_type == 3:
            return CompressedFormatType(CompressedFormatType.Q4_1)
        elif ggml_type == 12:
            return CompressedFormatType(CompressedFormatType.Q4_K_M)
        elif ggml_type == 6:
            return CompressedFormatType(CompressedFormatType.Q5_0)
        elif ggml_type == 7:
            return CompressedFormatType(CompressedFormatType.Q5_1)
        elif ggml_type == 13:
            return CompressedFormatType(CompressedFormatType.Q5_K_M)
        elif ggml_type == 14:
            return CompressedFormatType(CompressedFormatType.Q6_K)
        elif ggml_type == 8:
            return CompressedFormatType(CompressedFormatType.Q8_0)
        elif ggml_type == 9:
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
        self.unknown_token_id = existing.unknown_token_id
        self.bos_token_id = existing.bos_token_id
        self.eos_token_id = existing.eos_token_id

    def head_dim(self) -> Int:
        if self.head_count <= 0:
            return 0
        return self.embedding_length // self.head_count

    def kv_dim(self) -> Int:
        return self.head_dim() * self.head_count_kv

    def validate(self) raises:
        if self.architecture != "llama":
            raise Error("GGUF architecture is not supported: " + self.architecture)
        if self.context_length <= 0 or self.embedding_length <= 0:
            raise Error("GGUF model dimensions are incomplete")
        if self.feed_forward_length <= 0 or self.block_count <= 0:
            raise Error("GGUF layer metadata is incomplete")
        if self.head_count <= 0 or self.head_count_kv <= 0:
            raise Error("GGUF attention metadata is incomplete")
        if self.embedding_length % self.head_count != 0:
            raise Error("GGUF embedding length is not divisible by head count")
        if self.head_count % self.head_count_kv != 0:
            raise Error("GGUF query heads are not divisible by KV heads")
        if self.rope_dimension_count != self.head_dim():
            raise Error("GGUF RoPE dimension does not match attention head size")


struct GGUFSeer:
    """Owns a validated read-only GGUF mmap and tensor descriptors into it."""

    var file_path: String
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
        return self.mmap_ptr.unsafe_offset(offset).unsafe_bitcast[UInt32]().unsafe_load()

    def _read_i32(self, offset: Int) raises -> Int32:
        self._require_range(offset, 4)
        return self.mmap_ptr.unsafe_offset(offset).unsafe_bitcast[Int32]().unsafe_load()

    def _read_u64(self, offset: Int) raises -> UInt64:
        self._require_range(offset, 8)
        return self.mmap_ptr.unsafe_offset(offset).unsafe_bitcast[UInt64]().unsafe_load()

    def _read_f32(self, offset: Int) raises -> Float32:
        self._require_range(offset, 4)
        return self.mmap_ptr.unsafe_offset(offset).unsafe_bitcast[Float32]().unsafe_load()

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
        elif key == "llama.context_length" and value_type == 4:
            self.config.context_length = Int(self._read_u32(offset))
        elif key == "llama.embedding_length" and value_type == 4:
            self.config.embedding_length = Int(self._read_u32(offset))
        elif key == "llama.feed_forward_length" and value_type == 4:
            self.config.feed_forward_length = Int(self._read_u32(offset))
        elif key == "llama.block_count" and value_type == 4:
            self.config.block_count = Int(self._read_u32(offset))
        elif key == "llama.attention.head_count" and value_type == 4:
            self.config.head_count = Int(self._read_u32(offset))
        elif key == "llama.attention.head_count_kv" and value_type == 4:
            self.config.head_count_kv = Int(self._read_u32(offset))
        elif key == "llama.rope.dimension_count" and value_type == 4:
            self.config.rope_dimension_count = Int(self._read_u32(offset))
        elif key == "llama.attention.layer_norm_rms_epsilon" and value_type == 6:
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
        return self.skip_value(value_type, offset)

    def _open_and_map(mut self) raises:
        var path_bytes = List[Int8]()
        var source = self.file_path.as_bytes()
        for index in range(len(source)):
            path_bytes.append(Int8(source[index]))
        path_bytes.append(0)
        self.fd = external_call["open", Int32](path_bytes.unsafe_ptr(), 0)
        _ = path_bytes
        if self.fd < 0:
            raise Error("Failed to open GGUF model: " + self.file_path)

        self.file_size = external_call["lseek", Int64](self.fd, 0, 2)
        _ = external_call["lseek", Int64](self.fd, 0, 0)
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
        for _ in range(self.kv_count):
            var key = self._read_string(cursor)
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
        self.config.validate()
        if tokenizer.vocab_size <= 0:
            raise Error("GGUF tokenizer vocabulary is empty")
        if len(tokenizer.scores) != tokenizer.vocab_size:
            raise Error("GGUF tokenizer score count does not match vocabulary")
        if len(tokenizer.token_types) != tokenizer.vocab_size:
            raise Error("GGUF tokenizer type count does not match vocabulary")
        tokenizer.set_special_tokens(
            self.config.unknown_token_id,
            self.config.bos_token_id,
            self.config.eos_token_id,
        )
        return cursor

    def _tensor_byte_size(
        self,
        element_count: Int,
        tensor_type: UInt32,
    ) raises -> Int:
        if tensor_type == GGMLType.F16:
            if element_count > Int(self.file_size) // 2:
                raise Error("GGUF F16 tensor byte size overflows the file")
            return element_count * 2
        if tensor_type == GGMLType.F32:
            if element_count > Int(self.file_size) // 4:
                raise Error("GGUF F32 tensor byte size overflows the file")
            return element_count * 4
        raise Error("Real inference slice supports only F16 and F32 tensors")

    def _map_tensor(
        mut self,
        name: String,
        rows: Int,
        cols: Int,
        tensor_type: UInt32,
        tensor_offset: Int,
        mut pool: MimirWell,
    ) raises:
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
            self.tensors[name] = RuneTensor[f16](rows, cols, tensor_ptr, False)
        else:
            if pool.offset + element_count > pool.capacity:
                raise Error("MimirWell cannot hold converted F32 normalization tensor")
            var destination = pool.allocate(element_count)
            var source = self.mmap_ptr.unsafe_offset(absolute_offset).unsafe_bitcast[Float32]()
            for index in range(element_count):
                destination.unsafe_store(index, source.unsafe_load(index).cast[f16]())
            self.tensors[name] = RuneTensor[f16](rows, cols, destination, False)
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
        if tensor.rows != expected_rows or tensor.cols != expected_cols:
            raise Error("GGUF required tensor has an invalid shape: " + name)
        if self.tensor_types.get(name, UInt32(99)) != expected_type:
            raise Error("GGUF required tensor has an invalid type: " + name)

    def _validate_required_tensors(self) raises:
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
            self._require_tensor_shape(
                prefix + "attn_q.weight", hidden, hidden, GGMLType.F16
            )
            self._require_tensor_shape(
                prefix + "attn_k.weight", kv_dim, hidden, GGMLType.F16
            )
            self._require_tensor_shape(
                prefix + "attn_v.weight", kv_dim, hidden, GGMLType.F16
            )
            self._require_tensor_shape(
                prefix + "attn_output.weight", hidden, hidden, GGMLType.F16
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

    def mmap_and_load(mut self, mut pool: MimirWell) raises:
        var tokenizer = RuneWeaver()
        self.mmap_and_load(pool, tokenizer)

    def inspect_metadata(
        mut self,
        mut tokenizer: RuneWeaver,
    ) raises:
        """Reads validated header and model metadata without mapping tensors."""
        self._open_and_map()
        self._parse_header()
        _ = self._parse_metadata(tokenizer)

    def mmap_and_load(
        mut self,
        mut pool: MimirWell,
        mut tokenizer: RuneWeaver,
    ) raises:
        self._open_and_map()
        self._parse_header()
        var tensor_table_offset = self._parse_metadata(tokenizer)
        self._parse_tensors(tensor_table_offset, pool)
        self._validate_required_tensors()
        self.is_loaded = True
        print(
            "GGUF validated:",
            self.tensor_count,
            "tensors,",
            self.kv_count,
            "metadata entries, architecture",
            self.config.architecture,
        )

    def __deinit__(deinit self):
        if self.is_mapped:
            _ = external_call["munmap", Int32](self.mmap_ptr, self.file_size)
        if self.fd >= 0:
            _ = external_call["close", Int32](self.fd)
