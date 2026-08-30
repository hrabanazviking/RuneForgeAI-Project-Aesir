"""Packed GGUF ownership for architectures which do not use F16 RuneTensors.

The loader validates byte ranges before exposing offsets. It does not allocate
GPU memory, dequantize tensors, or decide model execution policy.
"""
from std.collections import Dict
from loader.gguf import GGUFSeer


@fieldwise_init
struct PackedTensor(ImplicitlyCopyable, Movable):
    var offset: Int
    var columns: Int
    var rows: Int
    var kind: Int
    var byte_count: Int


def packed_row_bytes(kind: Int, columns: Int) raises -> Int:
    if columns <= 0 or columns > 1048576:
        raise Error("Packed GGUF: invalid row width")
    if kind == 0:
        return columns * 4
    if kind == 1 or kind == 30:
        return columns * 2
    if columns % 256 != 0:
        raise Error("Packed GGUF: K-quant row is not block aligned")
    if kind == 12:
        return columns // 256 * 144
    if kind == 13:
        return columns // 256 * 176
    if kind == 14:
        return columns // 256 * 210
    raise Error("Packed GGUF: unsupported tensor type " + String(kind))


struct PackedGGUF:
    var source: GGUFSeer
    var fields: Dict[String, Int]
    var field_types: Dict[String, Int]
    var tensors: Dict[String, PackedTensor]
    var data_offset: Int

    def __init__(out self, path: String) raises:
        self.source = GGUFSeer(path)
        self.fields = Dict[String, Int]()
        self.field_types = Dict[String, Int]()
        self.tensors = Dict[String, PackedTensor]()
        self.data_offset = 0
        self.source._open_and_map()
        self.source._parse_header()
        if self.source.kv_count > 4096 or self.source.tensor_count > 100000:
            raise Error("Packed GGUF: unreasonable table count")
        var cursor = 24
        for _ in range(self.source.kv_count):
            var key = self.source._read_string(cursor)
            cursor = self.source._string_end(cursor)
            var kind = self.source._read_u32(cursor)
            cursor += 4
            if key in self.fields:
                raise Error("Packed GGUF: duplicate metadata " + key)
            self.fields[key] = cursor
            self.field_types[key] = Int(kind)
            if kind == 9 and self.source._read_u32(cursor) == 9:
                raise Error("Packed GGUF: nested metadata arrays unsupported")
            cursor = self.source.skip_value(kind, cursor)
        var alignment = self.integer("general.alignment", 32)
        if alignment <= 0 or alignment > 4096 or alignment & (alignment - 1) != 0:
            raise Error("Packed GGUF: invalid alignment")
        var names = List[String]()
        for _ in range(self.source.tensor_count):
            var name = self.source._read_string(cursor)
            cursor = self.source._string_end(cursor)
            var dims = Int(self.source._read_u32(cursor))
            cursor += 4
            if dims < 1 or dims > 2:
                raise Error("Packed GGUF: only dense vectors/matrices supported: " + name)
            var columns = Int(self.source._read_u64(cursor))
            cursor += 8
            var rows = 1
            if dims == 2:
                rows = Int(self.source._read_u64(cursor))
                cursor += 8
            var kind = Int(self.source._read_u32(cursor))
            var relative = Int(self.source._read_u64(cursor + 4))
            cursor += 12
            if rows <= 0 or rows > 1048576 or relative < 0 or relative % alignment != 0:
                raise Error("Packed GGUF: invalid tensor extent: " + name)
            var byte_count = packed_row_bytes(kind, columns) * rows
            if name in self.tensors:
                raise Error("Packed GGUF: duplicate tensor " + name)
            self.tensors[name] = PackedTensor(relative, columns, rows, kind, byte_count)
            names.append(name)
        self.data_offset = (cursor + alignment - 1) // alignment * alignment
        for name in names:
            var tensor = self.tensors[name]
            self.source._require_range(self.data_offset, tensor.offset)
            tensor.offset += self.data_offset
            self.source._require_range(tensor.offset, tensor.byte_count)
            self.tensors[name] = tensor
        for i in range(len(names)):
            var a = self.tensors[names[i]]
            for j in range(i):
                var b = self.tensors[names[j]]
                if a.offset < b.offset + b.byte_count and b.offset < a.offset + a.byte_count:
                    raise Error("Packed GGUF: overlapping tensors")

    def integer(self, key: String, default: Int = -1) raises -> Int:
        if key not in self.fields:
            if default >= 0:
                return default
            raise Error("Packed GGUF: missing metadata " + key)
        var kind = self.field_types[key]
        var offset = self.fields[key]
        if kind == 4:
            return Int(self.source._read_u32(offset))
        if kind == 7:
            return Int(self.source.mmap_ptr.unsafe_load(offset))
        raise Error("Packed GGUF: expected integer/bool " + key)

    def floating(self, key: String) raises -> Float32:
        if self.field_types.get(key, -1) != 6:
            raise Error("Packed GGUF: expected float " + key)
        return self.source._read_f32(self.fields[key])

    def text(self, key: String) raises -> String:
        if self.field_types.get(key, -1) != 8:
            raise Error("Packed GGUF: expected string " + key)
        return self.source._read_string(self.fields[key])

    def array_offset(self, key: String, kind: Int) raises -> Int:
        if self.field_types.get(key, -1) != 9:
            raise Error("Packed GGUF: expected array " + key)
        var offset = self.fields[key]
        if Int(self.source._read_u32(offset)) != kind:
            raise Error("Packed GGUF: incorrect array element type " + key)
        return offset

    def require_tensor(self, name: String, columns: Int, rows: Int = 1) raises -> PackedTensor:
        if name not in self.tensors:
            raise Error("Packed GGUF: missing tensor " + name)
        var tensor = self.tensors[name]
        if tensor.columns != columns or tensor.rows != rows:
            raise Error("Packed GGUF: unexpected shape " + name)
        return tensor
