# armvegr/gguf_loader.mojo
# H042 — GGUF tensor loader (Domain D1 ARMVEGR, pure Mojo).
#
# Memory-maps a GGUF file, parses the v2/v3 header with a self-contained
# bounds-checked parser (independent of aesir_engine/loader), and dequantizes
# tensors into FP16 working buffers using the H031/H032 kernels:
#   F32  -> fp32_to_fp16   F16 -> direct copy
#   Q8_0 -> q80_to_fp16    Q4_0 -> q40_to_fp16
# Any other dtype fails closed with a named error. Corrupt or truncated input
# fails closed with a named error — never a crash, never silent garbage.
#
# The module is portable Mojo: the same sources build on x86_64 and AArch64.
# The H042 cross-check builds this module + armvegr/quant.mojo + armvegr/q4.mojo
# on the forge (x86_64) in a TEST-ONLY harness and compares tensor-by-tensor
# against the Mimir (ARM64) output.

from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin

from armvegr.q4 import q40_to_fp16
from armvegr.quant import fp32_to_fp16, q80_to_fp16


struct GGUFTensorDesc(Copyable, Movable):
    """One tensor's parsed descriptor: name, shape, dtype, file offset."""
    var name: String
    var rows: Int  # ne[1], or 1 when the tensor has a single dimension
    var cols: Int  # ne[0]
    var ggml_type: UInt32
    var data_offset: Int  # absolute file offset of the tensor payload

    def __init__(out self):
        self.name = ""
        self.rows = 0
        self.cols = 0
        self.ggml_type = UInt32(0xFFFFFFFF)
        self.data_offset = -1

    def element_count(self) -> Int:
        return self.rows * self.cols


struct GGUFLoader:
    """mmap-backed GGUF v2/v3 tensor loader with FP16 dequantization."""
    var fd: Int32
    var file_size: Int64
    var map: Pointer[UInt8, MutUntrackedOrigin]
    var version: UInt32
    var alignment: Int
    var data_base: Int
    var descs: List[GGUFTensorDesc]
    var opened: Bool

    def __init__(out self):
        self.fd = Int32(-1)
        self.file_size = Int64(0)
        self.map = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=1)
        self.version = UInt32(0)
        self.alignment = 32
        self.data_base = 0
        self.descs = List[GGUFTensorDesc]()
        self.opened = False

    # -- low-level helpers -------------------------------------------------

    def _req(self, offset: Int, byte_count: Int) raises:
        if offset < 0 or byte_count < 0:
            raise Error("gguf_loader: negative byte range")
        if offset > Int(self.file_size) or byte_count > Int(self.file_size) - offset:
            raise Error("gguf_loader: truncated file or out-of-range offset")

    def _u32(self, offset: Int) raises -> UInt32:
        self._req(offset, 4)
        var b0 = UInt32(self.map.unsafe_offset(offset).unsafe_load())
        var b1 = UInt32(self.map.unsafe_offset(offset + 1).unsafe_load())
        var b2 = UInt32(self.map.unsafe_offset(offset + 2).unsafe_load())
        var b3 = UInt32(self.map.unsafe_offset(offset + 3).unsafe_load())
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)

    def _u64(self, offset: Int) raises -> UInt64:
        self._req(offset, 8)
        var v = UInt64(0)
        for i in range(8):
            v |= UInt64(self.map.unsafe_offset(offset + i).unsafe_load()) << UInt64(8 * i)
        return v

    def _f32(self, offset: Int) raises -> Float32:
        return self._u32(offset).bitcast[DType.float32]()

    def _string(self, offset: Int) raises -> String:
        var n = Int(self._u64(offset))
        self._req(offset + 8, n)
        var bytes = List[Int8]()
        for i in range(n):
            bytes.append(Int8(self.map.unsafe_offset(offset + 8 + i).unsafe_load()))
        bytes.append(0)
        return String(unsafe_from_utf8_ptr=bytes.unsafe_ptr())

    def _string_end(self, offset: Int) raises -> Int:
        var n = Int(self._u64(offset))
        self._req(offset + 8, n)
        return offset + 8 + n

    def _skip_value(self, value_type: UInt32, offset: Int) raises -> Int:
        # GGUF value types: 0=u8 1=i8 2=u16 3=i16 4=u32 5=i32 6=f32 7=bool
        # 8=string 9=array 10=u64 11=i64 12=f64.
        if value_type <= UInt32(7):
            var sizes = List[Int]()
            sizes.append(1)
            sizes.append(1)
            sizes.append(2)
            sizes.append(2)
            sizes.append(4)
            sizes.append(4)
            sizes.append(4)
            sizes.append(1)
            self._req(offset, sizes[Int(value_type)])
            return offset + sizes[Int(value_type)]
        if value_type == UInt32(8):
            return self._string_end(offset)
        if value_type == UInt32(10) or value_type == UInt32(11) or value_type == UInt32(12):
            self._req(offset, 8)
            return offset + 8
        if value_type == UInt32(9):
            var elem_type = self._u32(offset)
            var count = Int(self._u64(offset + 4))
            var cursor = offset + 12
            for _ in range(count):
                cursor = self._skip_value(elem_type, cursor)
            return cursor
        raise Error("gguf_loader: unknown GGUF metadata value type")

    # -- open / parse ------------------------------------------------------

    def open(mut self, path: String) raises:
        """mmap the file and parse the v2/v3 header + tensor table."""
        if self.opened:
            raise Error("gguf_loader: already open")
        var path_bytes = List[Int8]()
        var source = path.as_bytes()
        if len(source) == 0 or len(source) >= 4096 or "\0" in path:
            raise Error("gguf_loader: path must contain 1..4095 non-NUL bytes")
        for i in range(len(source)):
            path_bytes.append(Int8(source[i]))
        path_bytes.append(0)
        # O_RDONLY | O_NONBLOCK | O_CLOEXEC.
        self.fd = external_call["open64", Int32](
            path_bytes.unsafe_ptr(), Int32(526336), Int32(0)
        )
        _ = path_bytes
        if self.fd < 0:
            raise Error("gguf_loader: failed to open " + path)
        # File size via lseek(SEEK_END): portable, no struct-stat ABI dependence.
        var size = external_call["lseek", Int64](self.fd, Int64(0), Int32(2))
        if size < 0:
            _ = external_call["close", Int32](self.fd)
            self.fd = Int32(-1)
            raise Error("gguf_loader: cannot seek (not a regular file?) " + path)
        self.file_size = size
        # Regular-file gate via fstat S_ISREG. struct stat lays st_mode at
        # word 2 on aarch64 and word 3 on x86_64 (H041 finding); the other
        # slot holds st_nlink, a small count whose S_IFMT bits are zero in
        # practice, so OR-ing both slots is correct on either ABI.
        var stat = unsafe_alloc[UInt64](18)
        for si in range(18):
            stat[unsafe_offset=si] = 0
        if external_call["fstat", Int32](self.fd, stat) != 0:
            stat.unsafe_free()
            _ = external_call["close", Int32](self.fd)
            self.fd = Int32(-1)
            raise Error("gguf_loader: fstat failed on " + path)
        var mode_word = stat[unsafe_offset=2] | stat[unsafe_offset=3]
        stat.unsafe_free()
        if mode_word & UInt64(61440) != UInt64(32768):
            _ = external_call["close", Int32](self.fd)
            self.fd = Int32(-1)
            raise Error("gguf_loader: not a regular file: " + path)
        if self.file_size < 24:
            _ = external_call["close", Int32](self.fd)
            self.fd = Int32(-1)
            raise Error("gguf_loader: file smaller than the GGUF header")
        var addr = external_call["mmap", Int](
            Int(0), Int(self.file_size), Int32(1), Int32(2), self.fd, Int64(0)
        )
        if addr == -1:
            _ = external_call["close", Int32](self.fd)
            self.fd = Int32(-1)
            raise Error("gguf_loader: mmap failed on " + path)
        self.map = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=addr)
        try:
            self._parse()
        except e:
            _ = external_call["munmap", Int32](self.map, Int(self.file_size))
            _ = external_call["close", Int32](self.fd)
            self.fd = Int32(-1)
            self.map = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=1)
            raise e
        self.opened = True

    def _parse(mut self) raises:
        if self._u32(0) != UInt32(0x46554747):
            raise Error("gguf_loader: bad GGUF magic")
        self.version = self._u32(4)
        if self.version != UInt32(2) and self.version != UInt32(3):
            raise Error("gguf_loader: unsupported GGUF version")
        var tensor_count = Int(self._u64(8))
        var kv_count = Int(self._u64(16))
        if tensor_count < 0 or kv_count < 0:
            raise Error("gguf_loader: negative entry count")
        var cursor = 24
        # GGUF v3 header is 24 bytes: magic + version + tensor_count + kv_count.
        # There is no alignment field in the header; alignment defaults to 32
        # and may be overridden by the general.alignment metadata key below.
        self.alignment = 32
        # Metadata table: honor general.alignment, skip everything else.
        for _ in range(kv_count):
            var key = self._string(cursor)
            cursor = self._string_end(cursor)
            var value_type = self._u32(cursor)
            cursor += 4
            if key == "general.alignment" and value_type == UInt32(4):
                var a = Int(self._u32(cursor))
                if a <= 0:
                    raise Error("gguf_loader: non-positive general.alignment")
                self.alignment = a
            cursor = self._skip_value(value_type, cursor)
        # Tensor info table.
        var names = List[String]()
        var rows_l = List[Int]()
        var cols_l = List[Int]()
        var types_l = List[UInt32]()
        var offs_l = List[Int]()
        for _ in range(tensor_count):
            var name = self._string(cursor)
            cursor = self._string_end(cursor)
            var n_dims = Int(self._u32(cursor))
            cursor += 4
            if n_dims <= 0 or n_dims > 4:
                raise Error("gguf_loader: bad dimension count for " + name)
            var cols = Int(self._u64(cursor))
            cursor += 8
            var rows = 1
            if n_dims >= 2:
                rows = Int(self._u64(cursor))
                cursor += 8
            for _ in range(2, n_dims):
                rows *= Int(self._u64(cursor))
                cursor += 8
            if rows <= 0 or cols <= 0:
                raise Error("gguf_loader: non-positive dimension for " + name)
            var ttype = self._u32(cursor)
            cursor += 4
            var toff = Int(self._u64(cursor))
            cursor += 8
            names.append(name)
            rows_l.append(rows)
            cols_l.append(cols)
            types_l.append(ttype)
            offs_l.append(toff)
        self.data_base = ((cursor + self.alignment - 1) // self.alignment) * self.alignment
        self._req(self.data_base, 0)
        for i in range(len(names)):
            var n = rows_l[i] * cols_l[i]
            var ttype = types_l[i]
            var bsize = self._tensor_bytes(n, ttype, names[i])
            var toff = offs_l[i]
            if toff < 0 or toff % self.alignment != 0:
                raise Error("gguf_loader: misaligned tensor offset for " + names[i])
            var absolute = self.data_base + toff
            self._req(absolute, bsize)
            var d = GGUFTensorDesc()
            d.name = names[i]
            d.rows = rows_l[i]
            d.cols = cols_l[i]
            d.ggml_type = ttype
            d.data_offset = absolute
            self.descs.append(d.copy())

    def _tensor_bytes(self, n: Int, ttype: UInt32, name: String) raises -> Int:
        if ttype == UInt32(0):
            return n * 4
        if ttype == UInt32(1):
            return n * 2
        if ttype == UInt32(8):
            if n % 32 != 0:
                raise Error("gguf_loader: Q8_0 element count not a multiple of 32: " + name)
            return (n // 32) * 34
        if ttype == UInt32(2):
            if n % 32 != 0:
                raise Error("gguf_loader: Q4_0 element count not a multiple of 32: " + name)
            return (n // 32) * 18
        raise Error("gguf_loader: unsupported dtype for tensor " + name)

    # -- query / dequantize --------------------------------------------------

    def tensor_count(self) -> Int:
        return len(self.descs)

    def find(self, name: String) raises -> Int:
        for i in range(len(self.descs)):
            if self.descs[i].name == name:
                return i
        raise Error("gguf_loader: tensor not found: " + name)

    def dequantize(
        self,
        name: String,
        dst: Pointer[Float16, MutUntrackedOrigin],
    ) raises:
        """Dequantize tensor `name` into `dst` (must hold rows*cols FP16)."""
        var idx = self.find(name)
        ref d = self.descs[idx]
        var n = d.element_count()
        var src = self.map.unsafe_offset(d.data_offset)
        if d.ggml_type == UInt32(1):
            var src16 = src.unsafe_bitcast[Float16]()
            for i in range(n):
                dst[unsafe_offset=i] = src16.unsafe_offset(i).unsafe_load()
        elif d.ggml_type == UInt32(0):
            fp32_to_fp16(src.unsafe_bitcast[Float32](), dst, n)
        elif d.ggml_type == UInt32(8):
            q80_to_fp16(src.unsafe_bitcast[Int8](), dst, n)
        elif d.ggml_type == UInt32(2):
            q40_to_fp16(src.unsafe_bitcast[Int8](), dst, n)
        else:
            raise Error("gguf_loader: unsupported dtype for tensor " + name)

    def close(mut self):
        if self.opened:
            _ = external_call["munmap", Int32](self.map, Int(self.file_size))
            _ = external_call["close", Int32](self.fd)
            self.fd = Int32(-1)
            self.opened = False


def gguf_loader_version() -> String:
    return "0.1.0"
