# loader/gguf_writer.mojo
# GGUF v3 writer core (QC-1): emits a spec-exact GGUF byte stream from
# an in-memory model description, plus a metadata-copy reader path that
# parses a source file's header/KV/directory without materializing
# tensors. The emission spec is OUR reader (loader/gguf.mojo GGUFSeer +
# loader/packed_gguf.mojo PackedGGUF), field by field; where the plan
# (QC-0 section 2) and the readers disagreed, the readers arbitrated
# (see hidden_files/qwen35-adapter/QC-1-NOTES.md).
#
# Emission contract (all little-endian):
# - Header (24 B): magic u32 0x46554747 ("GGUF"), version u32 == 3
#   ONLY, tensor_count u64 @8, kv_count u64 @16.
# - Metadata KVs from offset 24, in caller order: key = GGUF string
#   (u64 length + UTF-8 bytes, no NUL), value_type u32, then the value.
#   Duplicate keys are REFUSED on write (the reader refuses them on
#   read). Value types: 0/1/7 = 1 B, 2/3 = 2 B, 4/5/6 = 4 B,
#   10/11/12 = 8 B, 8 = string, 9 = array (u32 elem type + u64 count +
#   elements; elem type must be < 13 and != 9 — PackedGGUF refuses
#   nested arrays outright).
# - Typed-key contract mirrors GGUFSeer._parse_metadata_value: known
#   keys must carry the value type the reader demands, or the write is
#   refused here instead of the read failing later.
# - Tensor directory immediately after metadata, in caller order:
#   name string, n_dims u32 (1..3, GGML dim order: dim0 = columns),
#   dims u64 each, type u32 (GGML number), offset u64 RELATIVE to
#   data_offset. Duplicate tensor names refused.
# - Data section: data_offset = directory end rounded UP to the
#   alignment (default 32); every tensor offset is alignment-divisible
#   (zero padding between payloads); file size == data_offset + the
#   final tensor's end exactly — no trailing bytes.
# - Tensor payload sizes come from GGUFSeer._tensor_byte_size itself
#   (single pricing source of truth), and dim0 must be an exact
#   multiple of the type's block geometry or the write is refused
#   (the reader prices with integer division and PackedGGUF refuses
#   non-aligned rows outright; a writer must not emit either shape).
#
# KV values are carried as RAW encoded bytes (the exact bytes that
# follow the u32 type tag). That is what makes the metadata-copy path
# exact for every value type — including per-layer arrays the flat
# reader only summarizes (gemma4 feed_forward_length, QC-0 U-QC4):
# the copy path never has to interpret a value to reproduce it.

from std.ffi import external_call
from std.memory import bitcast

from loader.gguf import GGUFSeer


struct GGUFValueType:
    comptime UINT8 = 0
    comptime INT8 = 1
    comptime UINT16 = 2
    comptime INT16 = 3
    comptime UINT32 = 4
    comptime INT32 = 5
    comptime FLOAT32 = 6
    comptime BOOL = 7
    comptime STRING = 8
    comptime ARRAY = 9
    comptime UINT64 = 10
    comptime INT64 = 11
    comptime FLOAT64 = 12


def _append_u16(mut bytes: List[UInt8], value: UInt16):
    bytes.append(UInt8(value & 0xff))
    bytes.append(UInt8((value >> 8) & 0xff))


def _append_u32(mut bytes: List[UInt8], value: UInt32):
    for shift in range(4):
        bytes.append(UInt8((value >> UInt32(shift * 8)) & 0xff))


def _append_u64(mut bytes: List[UInt8], value: UInt64):
    for shift in range(8):
        bytes.append(UInt8((value >> UInt64(shift * 8)) & 0xff))


def _append_string(mut bytes: List[UInt8], value: String):
    _append_u64(bytes, UInt64(len(value.as_bytes())))
    for byte in value.as_bytes():
        bytes.append(UInt8(byte))


def _append_bytes(mut bytes: List[UInt8], source: List[UInt8]):
    for byte in source:
        bytes.append(byte)


def _raw_need(raw: List[UInt8], offset: Int, count: Int) raises:
    if offset < 0 or count < 0 or offset > len(raw) or count > len(raw) - offset:
        raise Error("GGUF writer: raw value byte range out of bounds")


def _raw_u32(raw: List[UInt8], offset: Int) raises -> UInt32:
    _raw_need(raw, offset, 4)
    var value = UInt32(0)
    for i in range(4):
        value |= UInt32(raw[offset + i]) << UInt32(i * 8)
    return value


def _raw_u64(raw: List[UInt8], offset: Int) raises -> UInt64:
    _raw_need(raw, offset, 8)
    var value = UInt64(0)
    for i in range(8):
        value |= UInt64(raw[offset + i]) << UInt64(i * 8)
    return value


def _raw_skip_value(raw: List[UInt8], value_type: UInt32, offset: Int) raises -> Int:
    """End offset of one encoded value in raw bytes; mirrors
    GGUFSeer.skip_value exactly, bounds-checked against the buffer."""
    if value_type == 0 or value_type == 1 or value_type == 7:
        _raw_need(raw, offset, 1)
        return offset + 1
    if value_type == 2 or value_type == 3:
        _raw_need(raw, offset, 2)
        return offset + 2
    if value_type == 4 or value_type == 5 or value_type == 6:
        _raw_need(raw, offset, 4)
        return offset + 4
    if value_type == 10 or value_type == 11 or value_type == 12:
        _raw_need(raw, offset, 8)
        return offset + 8
    if value_type == 8:
        var length = Int(_raw_u64(raw, offset))
        _raw_need(raw, offset + 8, length)
        return offset + 8 + length
    if value_type == 9:
        var elem_type = _raw_u32(raw, offset)
        if elem_type >= 13:
            raise Error("GGUF writer: array element type out of range")
        var count = _raw_u64(raw, offset + 4)
        if count > UInt64(len(raw)):
            raise Error("GGUF writer: array length exceeds the value bytes")
        var cursor = offset + 12
        for _ in range(Int(count)):
            cursor = _raw_skip_value(raw, elem_type, cursor)
        return cursor
    raise Error("GGUF writer: invalid metadata value type " + String(value_type))


struct GGUFKVValue(Copyable, Movable):
    """One metadata value: its GGUF type tag plus the exact encoded
    bytes that follow the tag in the file. Typed constructors build
    the bytes; the copy path captures them verbatim."""

    var value_type: UInt32
    var raw: List[UInt8]

    def __init__(out self, value_type: UInt32, raw: List[UInt8]):
        self.value_type = value_type
        self.raw = raw.copy()

    def as_u32(self) raises -> UInt32:
        if self.value_type != UInt32(GGUFValueType.UINT32):
            raise Error("GGUF writer: value is not UINT32")
        return _raw_u32(self.raw, 0)

    def as_i32(self) raises -> Int32:
        if self.value_type != UInt32(GGUFValueType.INT32):
            raise Error("GGUF writer: value is not INT32")
        return Int32(_raw_u32(self.raw, 0))

    def as_f32(self) raises -> Float32:
        if self.value_type != UInt32(GGUFValueType.FLOAT32):
            raise Error("GGUF writer: value is not FLOAT32")
        return bitcast[DType.float32](_raw_u32(self.raw, 0))

    def as_bool(self) raises -> Bool:
        if self.value_type != UInt32(GGUFValueType.BOOL):
            raise Error("GGUF writer: value is not BOOL")
        _raw_need(self.raw, 0, 1)
        return self.raw[0] != 0

    def as_string(self) raises -> String:
        if self.value_type != UInt32(GGUFValueType.STRING):
            raise Error("GGUF writer: value is not STRING")
        var length = Int(_raw_u64(self.raw, 0))
        _raw_need(self.raw, 8, length)
        var bytes = List[UInt8]()
        bytes.reserve(length)
        for i in range(length):
            bytes.append(self.raw[8 + i])
        return String(from_utf8=bytes)

    def array_header(self) raises -> Tuple[UInt32, Int]:
        """(element type, element count) for ARRAY values."""
        if self.value_type != UInt32(GGUFValueType.ARRAY):
            raise Error("GGUF writer: value is not ARRAY")
        return (_raw_u32(self.raw, 0), Int(_raw_u64(self.raw, 4)))


struct GGUFKV(Copyable, Movable):
    var key: String
    var value: GGUFKVValue

    def __init__(out self, key: String, value: GGUFKVValue):
        self.key = String(key)
        self.value = value.copy()


def gguf_kv_equal(a: GGUFKV, b: GGUFKV) -> Bool:
    if a.key != b.key or a.value.value_type != b.value.value_type:
        return False
    if len(a.value.raw) != len(b.value.raw):
        return False
    for i in range(len(a.value.raw)):
        if a.value.raw[i] != b.value.raw[i]:
            return False
    return True


def _kv(key: String, value_type: UInt32, raw: List[UInt8]) -> GGUFKV:
    return GGUFKV(key, GGUFKVValue(value_type, raw))


def gguf_kv_u8(key: String, value: UInt8) -> GGUFKV:
    var raw = List[UInt8]()
    raw.append(value)
    return _kv(key, UInt32(GGUFValueType.UINT8), raw)


def gguf_kv_i8(key: String, value: Int8) -> GGUFKV:
    var raw = List[UInt8]()
    raw.append(UInt8(value))
    return _kv(key, UInt32(GGUFValueType.INT8), raw)


def gguf_kv_u16(key: String, value: UInt16) -> GGUFKV:
    var raw = List[UInt8]()
    _append_u16(raw, value)
    return _kv(key, UInt32(GGUFValueType.UINT16), raw)


def gguf_kv_i16(key: String, value: Int16) -> GGUFKV:
    var raw = List[UInt8]()
    _append_u16(raw, UInt16(value))
    return _kv(key, UInt32(GGUFValueType.INT16), raw)


def gguf_kv_u32(key: String, value: UInt32) -> GGUFKV:
    var raw = List[UInt8]()
    _append_u32(raw, value)
    return _kv(key, UInt32(GGUFValueType.UINT32), raw)


def gguf_kv_i32(key: String, value: Int32) -> GGUFKV:
    var raw = List[UInt8]()
    _append_u32(raw, UInt32(value))
    return _kv(key, UInt32(GGUFValueType.INT32), raw)


def gguf_kv_f32(key: String, value: Float32) -> GGUFKV:
    var raw = List[UInt8]()
    _append_u32(raw, bitcast[DType.uint32](value))
    return _kv(key, UInt32(GGUFValueType.FLOAT32), raw)


def gguf_kv_u64(key: String, value: UInt64) -> GGUFKV:
    var raw = List[UInt8]()
    _append_u64(raw, value)
    return _kv(key, UInt32(GGUFValueType.UINT64), raw)


def gguf_kv_i64(key: String, value: Int64) -> GGUFKV:
    var raw = List[UInt8]()
    _append_u64(raw, UInt64(value))
    return _kv(key, UInt32(GGUFValueType.INT64), raw)


def gguf_kv_f64(key: String, value: Float64) -> GGUFKV:
    var raw = List[UInt8]()
    _append_u64(raw, bitcast[DType.uint64](value))
    return _kv(key, UInt32(GGUFValueType.FLOAT64), raw)


def gguf_kv_bool(key: String, value: Bool) -> GGUFKV:
    var raw = List[UInt8]()
    raw.append(UInt8(1) if value else UInt8(0))
    return _kv(key, UInt32(GGUFValueType.BOOL), raw)


def gguf_kv_string(key: String, value: String) -> GGUFKV:
    var raw = List[UInt8]()
    _append_string(raw, value)
    return _kv(key, UInt32(GGUFValueType.STRING), raw)


def gguf_kv_string_array(key: String, values: List[String]) -> GGUFKV:
    var raw = List[UInt8]()
    _append_u32(raw, UInt32(GGUFValueType.STRING))
    _append_u64(raw, UInt64(len(values)))
    for value in values:
        _append_string(raw, value)
    return _kv(key, UInt32(GGUFValueType.ARRAY), raw)


def gguf_kv_u32_array(key: String, values: List[UInt32]) -> GGUFKV:
    var raw = List[UInt8]()
    _append_u32(raw, UInt32(GGUFValueType.UINT32))
    _append_u64(raw, UInt64(len(values)))
    for value in values:
        _append_u32(raw, value)
    return _kv(key, UInt32(GGUFValueType.ARRAY), raw)


def gguf_kv_i32_array(key: String, values: List[Int32]) -> GGUFKV:
    var raw = List[UInt8]()
    _append_u32(raw, UInt32(GGUFValueType.INT32))
    _append_u64(raw, UInt64(len(values)))
    for value in values:
        _append_u32(raw, UInt32(value))
    return _kv(key, UInt32(GGUFValueType.ARRAY), raw)


def gguf_kv_f32_array(key: String, values: List[Float32]) -> GGUFKV:
    var raw = List[UInt8]()
    _append_u32(raw, UInt32(GGUFValueType.FLOAT32))
    _append_u64(raw, UInt64(len(values)))
    for value in values:
        _append_u32(raw, bitcast[DType.uint32](value))
    return _kv(key, UInt32(GGUFValueType.ARRAY), raw)


def gguf_kv_bool_array(key: String, values: List[Bool]) -> GGUFKV:
    var raw = List[UInt8]()
    _append_u32(raw, UInt32(GGUFValueType.BOOL))
    _append_u64(raw, UInt64(len(values)))
    for value in values:
        raw.append(UInt8(1) if value else UInt8(0))
    return _kv(key, UInt32(GGUFValueType.ARRAY), raw)


struct GGUFWriterTensor(Copyable, Movable):
    """One tensor to emit: name, dims in GGML order (dim0 = columns /
    innermost), GGML type number, and the exact payload bytes. The
    payload length must equal the reader-priced byte size."""

    var name: String
    var dims: List[UInt64]
    var tensor_type: UInt32
    var payload: List[UInt8]

    def __init__(
        out self,
        name: String,
        dims: List[UInt64],
        tensor_type: UInt32,
        payload: List[UInt8],
    ):
        self.name = String(name)
        self.dims = dims.copy()
        self.tensor_type = tensor_type
        self.payload = payload.copy()

    def element_count(self) raises -> Int:
        var total = 1
        for dim in self.dims:
            if dim <= 0 or dim > UInt64(9223372036854775807):
                raise Error("GGUF writer: tensor dimension out of range: " + self.name)
            if Int(dim) > 9223372036854775807 // total:
                raise Error("GGUF writer: tensor element count overflows: " + self.name)
            total *= Int(dim)
        return total

    def byte_size(self) raises -> Int:
        return gguf_tensor_byte_size(self.element_count(), self.tensor_type)


struct GGUFModelDesc(Copyable, Movable):
    """The in-memory model description the writer emits: metadata KV
    list (order preserved), tensor directory (order preserved), and
    the emission alignment. Payloads ride inside the tensor entries;
    callers fill them directly or through copy_gguf_model."""

    var kvs: List[GGUFKV]
    var tensors: List[GGUFWriterTensor]
    var alignment: Int

    def __init__(out self):
        self.kvs = List[GGUFKV]()
        self.tensors = List[GGUFWriterTensor]()
        self.alignment = 32

    def add_kv(mut self, kv: GGUFKV):
        self.kvs.append(kv.copy())

    def add_tensor(mut self, tensor: GGUFWriterTensor):
        self.tensors.append(tensor.copy())


struct GGUFDirectoryEntry(Copyable, Movable):
    """One parsed tensor-directory row (metadata-copy path output)."""

    var name: String
    var dims: List[UInt64]
    var tensor_type: UInt32
    var relative_offset: Int
    var byte_size: Int

    def __init__(
        out self,
        name: String,
        dims: List[UInt64],
        tensor_type: UInt32,
        relative_offset: Int,
        byte_size: Int,
    ):
        self.name = String(name)
        self.dims = dims.copy()
        self.tensor_type = tensor_type
        self.relative_offset = relative_offset
        self.byte_size = byte_size


struct GGUFHeaderCopy(Copyable, Movable):
    """Header + KV + directory of a source file, parsed WITHOUT
    materializing tensors (GGUFSeer mmap + cursor walk only; no
    MimirWell, no tensor payload copies)."""

    var version: UInt32
    var alignment: Int
    var data_offset: Int
    var directory_end: Int
    var kvs: List[GGUFKV]
    var directory: List[GGUFDirectoryEntry]

    def __init__(out self):
        self.version = 0
        self.alignment = 32
        self.data_offset = 0
        self.directory_end = 0
        self.kvs = List[GGUFKV]()
        self.directory = List[GGUFDirectoryEntry]()


def gguf_block_elements(tensor_type: UInt32) raises -> Int:
    """Elements per block for a GGML type; 1 for dense types. The set
    of accepted types is exactly the set GGUFSeer._tensor_byte_size
    prices explicitly — anything else (e.g. 15 Q8_K, which the reader
    would fall through to a Q4_0 default price for and then refuse
    in to_compressed_format) is refused here, up front."""
    if tensor_type == 0 or tensor_type == 1 or tensor_type == 30:
        return 1
    if (
        tensor_type == 2 or tensor_type == 3 or tensor_type == 6
        or tensor_type == 7 or tensor_type == 8 or tensor_type == 9
        or tensor_type == 20
    ):
        return 32
    if (
        tensor_type == 10 or tensor_type == 11 or tensor_type == 12
        or tensor_type == 13 or tensor_type == 14 or tensor_type == 16
        or tensor_type == 17 or tensor_type == 18 or tensor_type == 19
        or tensor_type == 21 or tensor_type == 22 or tensor_type == 23
        or tensor_type == 29 or tensor_type == 34 or tensor_type == 35
    ):
        return 256
    raise Error("GGUF writer: unsupported tensor type " + String(tensor_type))


def gguf_tensor_byte_size(element_count: Int, tensor_type: UInt32) raises -> Int:
    """Byte size of a tensor payload, priced by GGUFSeer itself so
    writer and reader can never disagree. The probe seer is never
    opened; _tensor_byte_size is a pure function of its arguments."""
    _ = gguf_block_elements(tensor_type)
    var probe = GGUFSeer("gguf-writer-size-probe.gguf")
    return probe._tensor_byte_size(element_count, tensor_type)


def _expected_kv_type(key: String) -> Int:
    """The scalar value type GGUFSeer._parse_metadata_value demands
    for a key, or -1 when the reader accepts any type. Mirrors the
    reader's list exactly (QC-1 notes record the correspondence)."""
    if key == "general.architecture" or key == "tokenizer.ggml.model" or key == "tokenizer.ggml.pre":
        return 8
    if (
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
        or key.endswith(".expert_count")
        or key.endswith(".expert_used_count")
        or key == "general.alignment"
        or key == "tokenizer.ggml.unknown_token_id"
        or key == "tokenizer.ggml.bos_token_id"
        or key == "tokenizer.ggml.eos_token_id"
    ):
        return 4
    if (
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
        return 6
    if key == "tokenizer.ggml.add_bos_token" or key == "tokenizer.ggml.add_space_prefix":
        return 7
    return -1


def _validate_kv_structure(kv: GGUFKV) raises:
    if kv.value.value_type > 12:
        raise Error("GGUF writer: invalid metadata value type for key " + kv.key)
    var end = _raw_skip_value(kv.value.raw, kv.value.value_type, 0)
    if end != len(kv.value.raw):
        raise Error("GGUF writer: metadata value bytes are malformed for key " + kv.key)
    if kv.value.value_type == UInt32(GGUFValueType.ARRAY):
        var header = kv.value.array_header()
        if header[0] >= 13 or header[0] == 9:
            raise Error("GGUF writer: array element type refused for key " + kv.key)


def _validate_kv_contract(desc: GGUFModelDesc) raises:
    var seen = List[String]()
    var has_alignment_key = False
    for kv in desc.kvs:
        if kv.key in seen:
            raise Error("GGUF writer: duplicate metadata key refused: " + kv.key)
        seen.append(String(kv.key))
        _validate_kv_structure(kv)
        var vt = kv.value.value_type
        if kv.key == "tokenizer.ggml.tokens" or kv.key == "tokenizer.ggml.merges":
            if vt != 9 or kv.value.array_header()[0] != 8:
                raise Error("GGUF writer: " + kv.key + " must be an array of strings")
            continue
        if kv.key == "tokenizer.ggml.scores":
            if vt != 9 or kv.value.array_header()[0] != 6:
                raise Error("GGUF writer: tokenizer.ggml.scores must be a float32 array")
            continue
        if kv.key == "tokenizer.ggml.token_type":
            if vt != 9 or kv.value.array_header()[0] != 5:
                raise Error("GGUF writer: tokenizer.ggml.token_type must be an int32 array")
            continue
        if kv.key.endswith(".attention.sliding_window_pattern"):
            var header = kv.value.array_header()
            if vt != 9 or header[0] != 7 or header[1] > 64:
                raise Error("GGUF writer: sliding_window_pattern must be a bool array of at most 64")
            continue
        var expected = _expected_kv_type(kv.key)
        if expected >= 0:
            if vt == 9:
                # The reader normalizes an array of u32/i32/f32 to its
                # first element for scalar keys (gemma4 per-layer
                # arrays); i32 elements share the u32 byte layout.
                var elem = kv.value.array_header()[0]
                if elem != 4 and elem != 5 and elem != 6:
                    raise Error("GGUF writer: metadata key has unexpected value type: " + kv.key)
                var scalar = 4 if elem == 5 else Int(elem)
                if scalar != expected:
                    raise Error("GGUF writer: metadata key has unexpected value type: " + kv.key)
            elif Int(vt) != expected:
                raise Error("GGUF writer: metadata key has unexpected value type: " + kv.key)
        if kv.key == "general.alignment":
            has_alignment_key = True
            if Int(kv.value.as_u32()) != desc.alignment:
                raise Error("GGUF writer: general.alignment does not match the emission alignment")
    if desc.alignment != 32 and not has_alignment_key:
        raise Error("GGUF writer: non-default alignment requires a general.alignment key")


def validate_gguf_desc(desc: GGUFModelDesc) raises:
    """Every write-side refusal, checked before any byte is emitted:
    the writer refuses exactly what the readers would refuse, plus
    the shapes the readers would silently misprice."""
    if desc.alignment <= 0 or desc.alignment > 4096 or (desc.alignment & (desc.alignment - 1)) != 0:
        raise Error("GGUF writer: alignment must be a power of two up to 4096")
    _validate_kv_contract(desc)
    var names = List[String]()
    for tensor in desc.tensors:
        if tensor.name in names:
            raise Error("GGUF writer: duplicate tensor name refused: " + tensor.name)
        names.append(String(tensor.name))
        if len(tensor.dims) < 1 or len(tensor.dims) > 3:
            raise Error("GGUF writer: tensor must have one to three dimensions: " + tensor.name)
        var block = gguf_block_elements(tensor.tensor_type)
        if Int(tensor.dims[0]) % block != 0:
            raise Error("GGUF writer: tensor dim0 is not block aligned: " + tensor.name)
        var expected_size = tensor.byte_size()
        if len(tensor.payload) != expected_size:
            raise Error(
                "GGUF writer: tensor payload size mismatch for " + tensor.name
                + ": payload " + String(len(tensor.payload))
                + " bytes, reader-priced size " + String(expected_size)
            )


def gguf_tensor_offsets(desc: GGUFModelDesc) raises -> List[Int]:
    """Relative tensor offsets: caller order, each rounded UP to the
    emission alignment (zero padding between payloads)."""
    var offsets = List[Int]()
    var cursor = 0
    for tensor in desc.tensors:
        var aligned = ((cursor + desc.alignment - 1) // desc.alignment) * desc.alignment
        offsets.append(aligned)
        cursor = aligned + tensor.byte_size()
    return offsets^


def build_gguf_bytes(desc: GGUFModelDesc) raises -> List[UInt8]:
    validate_gguf_desc(desc)
    var offsets = gguf_tensor_offsets(desc)
    var bytes = List[UInt8]()
    bytes.append(0x47)
    bytes.append(0x47)
    bytes.append(0x55)
    bytes.append(0x46)
    _append_u32(bytes, 3)
    _append_u64(bytes, UInt64(len(desc.tensors)))
    _append_u64(bytes, UInt64(len(desc.kvs)))
    for kv in desc.kvs:
        _append_string(bytes, kv.key)
        _append_u32(bytes, kv.value.value_type)
        _append_bytes(bytes, kv.value.raw)
    for i in range(len(desc.tensors)):
        ref tensor = desc.tensors[i]
        _append_string(bytes, tensor.name)
        _append_u32(bytes, UInt32(len(tensor.dims)))
        for dim in tensor.dims:
            _append_u64(bytes, dim)
        _append_u32(bytes, tensor.tensor_type)
        _append_u64(bytes, UInt64(offsets[i]))
    while len(bytes) % desc.alignment != 0:
        bytes.append(0)
    var data_offset = len(bytes)
    for i in range(len(desc.tensors)):
        while len(bytes) - data_offset < offsets[i]:
            bytes.append(0)
        _append_bytes(bytes, desc.tensors[i].payload)
    return bytes^


def write_gguf_file(path: String, desc: GGUFModelDesc) raises -> Int:
    """Builds the byte stream and writes it (create/truncate, 0644).
    Returns the exact file size: data_offset + the final tensor's end."""
    var bytes = build_gguf_bytes(desc)
    var path_bytes = List[Int8]()
    for byte in path.as_bytes():
        path_bytes.append(Int8(byte))
    path_bytes.append(0)
    # O_WRONLY | O_CREAT | O_TRUNC, mode 0644.
    var fd = external_call["open64", Int32](path_bytes.unsafe_ptr(), Int32(577), Int32(420))
    if fd < 0:
        raise Error("GGUF writer: failed to open output file: " + path)
    var offset = 0
    while offset < len(bytes):
        var wrote = external_call["write", Int](Int(fd), bytes.unsafe_ptr().unsafe_offset(offset), len(bytes) - offset)
        if wrote <= 0:
            _ = external_call["close", Int32](fd)
            raise Error("GGUF writer: failed to write output file: " + path)
        offset += wrote
    if external_call["close", Int32](fd) != 0:
        raise Error("GGUF writer: failed to close output file: " + path)
    return len(bytes)


def read_gguf_header_copy(path: String) raises -> GGUFHeaderCopy:
    """Metadata-copy reader path: parses a source file's header, KV
    sequence and tensor directory WITHOUT materializing tensors —
    the GGUFSeer mmap is walked with the reader's own bounds-checked
    helpers and only the KV value bytes and directory rows are
    copied out. Tensor payloads are never read. Duplicate keys and
    duplicate tensor names are refused, mirroring both readers."""
    var seer = GGUFSeer(path)
    seer._open_and_map()
    seer._parse_header()
    var copy = GGUFHeaderCopy()
    copy.version = seer.version
    var cursor = 24
    var seen_keys = List[String]()
    for _ in range(seer.kv_count):
        var key = seer._read_string(cursor)
        if key in seen_keys:
            raise Error("GGUF writer copy: duplicate metadata key: " + key)
        seen_keys.append(String(key))
        cursor = seer._string_end(cursor)
        var value_type = seer._read_u32(cursor)
        cursor += 4
        var value_start = cursor
        cursor = seer.skip_value(value_type, cursor)
        var raw = List[UInt8]()
        raw.reserve(cursor - value_start)
        for index in range(value_start, cursor):
            raw.append(UInt8(seer.mmap_ptr.unsafe_offset(index).unsafe_load()))
        var kv = GGUFKV(key, GGUFKVValue(value_type, raw))
        if key == "general.alignment" and value_type == 4:
            copy.alignment = Int(kv.value.as_u32())
        copy.kvs.append(kv.copy())
    if copy.alignment <= 0 or copy.alignment > 4096 or (copy.alignment & (copy.alignment - 1)) != 0:
        raise Error("GGUF writer copy: alignment must be a power of two up to 4096")
    var seen_names = List[String]()
    for _ in range(seer.tensor_count):
        var name = seer._read_string(cursor)
        if name in seen_names:
            raise Error("GGUF writer copy: duplicate tensor name: " + name)
        seen_names.append(String(name))
        cursor = seer._string_end(cursor)
        var dimension_count = Int(seer._read_u32(cursor))
        cursor += 4
        if dimension_count < 1 or dimension_count > 3:
            raise Error("GGUF writer copy: tensor must have one to three dimensions: " + name)
        var dims = List[UInt64]()
        var elements = 1
        for _ in range(dimension_count):
            var dim = seer._read_u64(cursor)
            cursor += 8
            if dim <= 0 or dim > UInt64(9223372036854775807):
                raise Error("GGUF writer copy: tensor dimension out of range: " + name)
            if Int(dim) > 9223372036854775807 // elements:
                raise Error("GGUF writer copy: tensor element count overflows: " + name)
            elements *= Int(dim)
            dims.append(dim)
        var tensor_type = seer._read_u32(cursor)
        cursor += 4
        var relative_offset = Int(seer._read_u64(cursor))
        cursor += 8
        if relative_offset < 0 or relative_offset % copy.alignment != 0:
            raise Error("GGUF writer copy: tensor offset is not correctly aligned: " + name)
        var byte_size = gguf_tensor_byte_size(elements, tensor_type)
        seer._require_range(copy.data_offset + relative_offset, 0)
        copy.directory.append(
            GGUFDirectoryEntry(name, dims, tensor_type, relative_offset, byte_size).copy()
        )
    copy.directory_end = cursor
    copy.data_offset = ((cursor + copy.alignment - 1) // copy.alignment) * copy.alignment
    for entry in copy.directory:
        seer._require_range(copy.data_offset + entry.relative_offset, entry.byte_size)
    return copy^


def copy_gguf_model(path: String) raises -> GGUFModelDesc:
    """Full model description of a source file: the header copy plus
    each tensor's payload bytes lifted from the source mmap, ready
    to re-emit through write_gguf_file. Payloads are copied one
    tensor at a time into the description; the source tensors are
    never converted or materialized as engine tensors."""
    var head = read_gguf_header_copy(path)
    var seer = GGUFSeer(path)
    seer._open_and_map()
    seer._parse_header()
    var desc = GGUFModelDesc()
    desc.alignment = head.alignment
    for kv in head.kvs:
        desc.add_kv(kv)
    for entry in head.directory:
        var payload = List[UInt8]()
        payload.reserve(entry.byte_size)
        var base = head.data_offset + entry.relative_offset
        seer._require_range(base, entry.byte_size)
        for index in range(entry.byte_size):
            payload.append(UInt8(seer.mmap_ptr.unsafe_offset(base + index).unsafe_load()))
        desc.add_tensor(GGUFWriterTensor(entry.name, entry.dims, entry.tensor_type, payload))
    return desc^
