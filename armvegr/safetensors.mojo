# armvegr/safetensors.mojo
# H043/H044 — safetensors parser + tensor loader (Domain D1 ARMVEGR, pure Mojo).
#
# Format: u64 LE header size N | N bytes of JSON | tensor data.
# The JSON header maps each tensor name to {"dtype", "shape", "data_offsets"},
# plus an optional "__metadata__" object. The JSON parser below is hand-rolled
# (L1: no JSON library, Mojo stdlib + POSIX only) and schema-driven: it parses
# exactly the safetensors header shape and skips anything else.
#
# H044 conversions (all little-endian, explicit):
#   F16  -> bit-exact copy
#   F32  -> fp32_to_fp16 (H031 kernel)
#   BF16 -> bf16_to_fp16_rne: round-to-nearest-even, fully specified below.
#
# BF16->FP16 RNE CONTRACT (documented, tested exhaustively in H044):
#   The BF16 value is decoded to its exact real value v. v is then rounded to
#   binary16 with round-to-nearest-even:
#     - NaN  -> quiet NaN 0x7E00 (sign preserved)
#     - +-Inf -> +-Inf (0x7C00 / 0xFC00)
#     - |v| > 65504 -> +-Inf (overflow)
#     - BF16 subnormals (|v| <= 127 * 2^-133, far below half an FP16-subnormal
#       ULP of 2^-25) always round to signed zero.
#     - Normal BF16 values are EXACTLY representable in FP16 (7 mantissa bits
#       fit in 10; exponent range is the smaller constraint), so no rounding
#       occurs there; values overflowing the FP16 exponent go to Inf, values
#       underflowing into the FP16 subnormal range are rounded RNE (ties to
#       the even 10-bit mantissa).
#   Max absolute error vs the FP64 reference: 0.5 ULP of the FP16 result;
#   the implementation is bit-exact against the independent integer-arithmetic
#   reference on all 65536 BF16 bit patterns (H044 evidence).

from std.collections import Dict
from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin

from armvegr.quant import fp32_to_fp16


struct STTensorDesc(Copyable, Movable):
    """One safetensors tensor descriptor: name, dtype, shape, file offsets."""
    var name: String
    var dtype: UInt8  # 0 = F16, 1 = BF16, 2 = F32
    var shape: List[Int]
    var data_start: Int  # absolute file offset of the first payload byte
    var data_end: Int  # one past the last payload byte

    def __init__(out self):
        self.name = ""
        self.dtype = UInt8(255)
        self.shape = List[Int]()
        self.data_start = -1
        self.data_end = -1

    def element_count(self) raises -> Int64:
        # Empty axes make the mathematical product zero before any multiply.
        for dim in self.shape:
            if dim < 0:
                raise Error("safetensors: negative shape dimension")
        for dim in self.shape:
            if dim == 0:
                return 0
        var n = Int64(1)
        for dim in self.shape:
            if n > Int64(9223372036854775807) // Int64(dim):
                raise Error("safetensors: shape product overflows Int64")
            n *= Int64(dim)
        return n


struct JsonParser:
    """Minimal hand-rolled JSON reader over the safetensors header bytes."""
    var buf: Pointer[UInt8, MutUntrackedOrigin]
    var n: Int
    var pos: Int
    var max_depth: Int

    def __init__(out self, buf: Pointer[UInt8, MutUntrackedOrigin], n: Int, max_depth: Int = 64):
        self.buf = buf
        self.n = n
        self.pos = 0
        self.max_depth = max_depth

    def _peek(self) -> UInt8:
        if self.pos >= self.n:
            return UInt8(0)
        return self.buf.unsafe_offset(self.pos).unsafe_load()

    def peek(self) raises -> UInt8:
        """Shared bounded cursor lookahead; caller keeps borrowed bytes alive."""
        if self.n < 0 or self.pos < 0 or self.pos > self.n:
            raise Error("safetensors: invalid shared JSON cursor position")
        return self._peek()

    def copy_raw_span(self, first: Int, end: Int) raises -> String:
        """Copy checked UTF-8 bytes; this method alone does not validate JSON."""
        if first < 0 or end < first or end > self.n:
            raise Error("safetensors: invalid raw JSON byte span")
        var bytes = List[UInt8]()
        bytes.reserve(end - first)
        for i in range(first, end):
            bytes.append(self.buf.unsafe_offset(i).unsafe_load())
        return String(from_utf8=bytes^)

    def parse_raw_value(mut self) raises -> String:
        """Validate one bounded JSON value and copy its exact non-outer-WS text."""
        _ = self.peek()
        if self.max_depth <= 0 or self.max_depth > 64:
            raise Error("safetensors: shared JSON depth must be1..64")
        self.skip_ws()
        var first = self.pos
        self.skip_value()
        return self.copy_raw_span(first, self.pos)

    def skip_ws(mut self) raises:
        while self.pos < self.n:
            var c = self._peek()
            if c == UInt8(32) or c == UInt8(9) or c == UInt8(10) or c == UInt8(13):
                self.pos += 1
            else:
                break

    def expect(mut self, c: UInt8) raises:
        self.skip_ws()
        if self.pos >= self.n or self._peek() != c:
            raise Error("safetensors: malformed JSON header")
        self.pos += 1

    def _hex(self, c: UInt8) raises -> Int:
        if c >= UInt8(48) and c <= UInt8(57):
            return Int(c - UInt8(48))
        if c >= UInt8(97) and c <= UInt8(102):
            return Int(c - UInt8(97)) + 10
        if c >= UInt8(65) and c <= UInt8(70):
            return Int(c - UInt8(65)) + 10
        raise Error("safetensors: bad \\u escape in JSON header")

    def _append_utf8(mut self, mut dst: List[UInt8], cp: Int) raises:
        if cp < 0 or cp > 1114111 or (cp >= 55296 and cp <= 57343):
            raise Error("safetensors: bad code point in JSON header")
        if cp < 128:
            dst.append(UInt8(cp))
        elif cp < 2048:
            dst.append(UInt8(0xC0 | (cp >> 6)))
            dst.append(UInt8(0x80 | (cp & 63)))
        elif cp < 65536:
            dst.append(UInt8(0xE0 | (cp >> 12)))
            dst.append(UInt8(0x80 | ((cp >> 6) & 63)))
            dst.append(UInt8(0x80 | (cp & 63)))
        else:
            dst.append(UInt8(0xF0 | (cp >> 18)))
            dst.append(UInt8(0x80 | ((cp >> 12) & 63)))
            dst.append(UInt8(0x80 | ((cp >> 6) & 63)))
            dst.append(UInt8(0x80 | (cp & 63)))

    def parse_string(mut self) raises -> String:
        self.skip_ws()
        if self._peek() != UInt8(34):
            raise Error("safetensors: expected JSON string")
        self.pos += 1
        var out = List[UInt8]()
        while True:
            if self.pos >= self.n:
                raise Error("safetensors: unterminated JSON string")
            var c = self._peek()
            self.pos += 1
            if c == UInt8(34):
                break
            if c == UInt8(92):
                if self.pos >= self.n:
                    raise Error("safetensors: truncated escape in JSON header")
                var e = self._peek()
                self.pos += 1
                if e == UInt8(34):
                    out.append(34)
                elif e == UInt8(92):
                    out.append(92)
                elif e == UInt8(47):
                    out.append(47)
                elif e == UInt8(98):
                    out.append(8)
                elif e == UInt8(102):
                    out.append(12)
                elif e == UInt8(110):
                    out.append(10)
                elif e == UInt8(114):
                    out.append(13)
                elif e == UInt8(116):
                    out.append(9)
                elif e == UInt8(117):
                    if self.pos + 4 > self.n:
                        raise Error("safetensors: truncated \\u escape")
                    var cp = 0
                    for _ in range(4):
                        cp = cp * 16 + self._hex(self._peek())
                        self.pos += 1
                    if cp >= 55296 and cp <= 56319:
                        # high surrogate: expect \uDC00-\uDFFF
                        if (
                            self.pos + 6 > self.n
                            or self._peek() != UInt8(92)
                            or self.buf.unsafe_offset(self.pos + 1).unsafe_load()
                            != UInt8(117)
                        ):
                            raise Error("safetensors: lone surrogate in JSON header")
                        self.pos += 2
                        var lo = 0
                        for _ in range(4):
                            lo = lo * 16 + self._hex(self._peek())
                            self.pos += 1
                        if lo < 56320 or lo > 57343:
                            raise Error("safetensors: bad low surrogate")
                        cp = 65536 + (cp - 55296) * 1024 + (lo - 56320)
                    self._append_utf8(out, cp)
                else:
                    raise Error("safetensors: bad escape in JSON header")
            elif c < UInt8(32):
                raise Error("safetensors: control character in JSON string")
            else:
                out.append(c)
        return String(from_utf8=out)

    def parse_int(mut self) raises -> Int64:
        self.skip_ws()
        var neg = False
        if self._peek() == UInt8(45):
            neg = True
            self.pos += 1
        var v = Int64(0)
        var digits = 0
        var leading_zero = self._peek() == UInt8(48)
        while self.pos < self.n:
            var c = self._peek()
            if c < UInt8(48) or c > UInt8(57):
                break
            # overflow guard: shapes/offsets must fit Int64
            if v > (Int64(9223372036854775807) - Int64(c - UInt8(48))) // Int64(10):
                raise Error("safetensors: integer overflow in JSON header")
            v = v * Int64(10) + Int64(c - UInt8(48))
            self.pos += 1
            digits += 1
        if digits > 1 and leading_zero:
            raise Error("safetensors: leading zero in JSON integer")
        if digits == 0:
            raise Error("safetensors: expected JSON integer")
        return -v if neg else v

    def parse_size(mut self) raises -> Int64:
        self.skip_ws()
        if self._peek() == UInt8(45):
            raise Error("safetensors: unsigned shape/offset required")
        return self.parse_int()

    def skip_value(mut self) raises:
        self._skip_value(0)

    def _skip_value(mut self, depth: Int) raises:
        """Validate and skip one bounded unknown-field JSON value."""
        if depth >= self.max_depth:
            raise Error("safetensors: JSON nesting bound exceeded")
        self.skip_ws()
        var c = self._peek()
        if c == UInt8(34):
            _ = self.parse_string()
        elif c == UInt8(123):
            self.pos += 1
            self.skip_ws()
            if self._peek() == UInt8(125):
                self.pos += 1
                return
            var fields = Dict[String, Bool]()
            while True:
                var key = self.parse_string()
                if key in fields:
                    raise Error("safetensors: duplicate skipped object key")
                fields[key] = True
                self.expect(UInt8(58))
                self._skip_value(depth + 1)
                self.skip_ws()
                var d = self._peek()
                if d == UInt8(44):
                    self.pos += 1
                elif d == UInt8(125):
                    self.pos += 1
                    break
                else:
                    raise Error("safetensors: malformed JSON object")
        elif c == UInt8(91):
            self.pos += 1
            self.skip_ws()
            if self._peek() == UInt8(93):
                self.pos += 1
                return
            while True:
                self._skip_value(depth + 1)
                self.skip_ws()
                var d = self._peek()
                if d == UInt8(44):
                    self.pos += 1
                elif d == UInt8(93):
                    self.pos += 1
                    break
                else:
                    raise Error("safetensors: malformed JSON array")
        elif c == UInt8(116):  # true
            self.expect_word("true")
        elif c == UInt8(102):  # false
            self.expect_word("false")
        elif c == UInt8(110):  # null
            self.expect_word("null")
        elif (c >= UInt8(48) and c <= UInt8(57)) or c == UInt8(45):
            _ = self.parse_number_raw()
        else:
            raise Error("safetensors: malformed JSON value")

    def expect_word(mut self, w: String) raises:
        for i in range(len(w.as_bytes())):
            if self.pos >= self.n or self._peek() != w.as_bytes()[i]:
                raise Error("safetensors: malformed JSON literal")
            self.pos += 1

    def _number_digits(mut self) raises:
        var start = self.pos
        while self.pos < self.n and self._peek() >= 48 and self._peek() <= 57:
            self.pos += 1
        if self.pos == start:
            raise Error("safetensors: expected JSON number digits")

    def parse_number_raw(mut self) raises:
        self.skip_ws()
        if self._peek() == 45:
            self.pos += 1
        if self._peek() == 48:
            self.pos += 1
            if self._peek() >= 48 and self._peek() <= 57:
                raise Error("safetensors: leading zero in JSON number")
        else:
            self._number_digits()
        if self._peek() == 46:
            self.pos += 1
            self._number_digits()
        if self._peek() == 101 or self._peek() == 69:
            self.pos += 1
            if self._peek() == 43 or self._peek() == 45:
                self.pos += 1
            self._number_digits()


def bf16_to_fp16_rne(src: Pointer[UInt16, MutUntrackedOrigin], dst: Pointer[Float16, MutUntrackedOrigin], n: Int):
    """BF16 -> FP16 with round-to-nearest-even (see module contract)."""
    for i in range(n):
        var w = src.unsafe_offset(i).unsafe_load()
        var sign = UInt16(0)
        if (w & UInt16(0x8000)) != UInt16(0):
            sign = UInt16(0x8000)
        var exp8 = Int((w >> 7) & UInt16(0xFF))
        var mant7 = Int(w & UInt16(0x7F))
        var out = UInt16(0)
        if exp8 == 255:
            # Inf / NaN
            if mant7 == 0:
                out = sign | UInt16(0x7C00)
            else:
                out = sign | UInt16(0x7E00)  # quiet NaN
        elif exp8 == 0:
            # Subnormal or zero: exact value v = mant7 * 2^-133.
            # FP16-exact only for v == 0; otherwise round mant7 * 2^-133 to FP16.
            # The quotient below (before rounding) in units of 2^-24 is
            # q = mant7 * 2^(e+24) with e = -133-... done via the general path:
            # represent v as m * 2^e with m in [1,2): m = mant7/64, e = -139.
            if mant7 == 0:
                out = sign
            else:
                out = sign | _f16_rne_bits_subnormal(mant7)
        else:
            var e = exp8 - 127  # unbiased binary32 exponent
            var e5 = e + 15
            if e5 >= 31:
                out = sign | UInt16(0x7C00)  # overflow -> Inf
            elif e5 <= 0:
                # Rounds into the FP16 subnormal range (or zero).
                out = sign | _f16_rne_bits_subnormal_full(e, mant7)
            else:
                # Normal: value = (128 + mant7) * 2^(e-7) = (1 + mant7/128) * 2^e.
                # In FP16: (1 + M10/1024) * 2^e5 with M10 = mant7 * 8 — the 7
                # BF16 mantissa bits fit exactly in FP16's 10, so no rounding.
                var m10 = mant7 * 8  # in [0, 1016]
                out = sign | UInt16(UInt16(e5 << 10) | UInt16(m10))
        dst[unsafe_offset=i] = _f16_from_bits_exact(out)


def _rne_shift(v: Int, drop: Int) -> Int:
    """Shift v right by `drop` bits with round-to-nearest-even. v >= 0."""
    var q = v >> drop
    var mask = (1 << drop) - 1
    var rem = v & mask
    var half = 1 << (drop - 1)
    if rem > half or (rem == half and (q & 1) == 1):
        q += 1
    return q


def _f16_rne_bits_subnormal(mant7: Int) -> UInt16:
    """RNE of v = mant7 * 2^-133 (mant7 in 1..127) to FP16 subnormal/zero bits."""
    # In units of 2^-24 (FP16 subnormal LSB): q = mant7 * 2^-109. Only the
    # tie case mant7 * 2^-109 == 0.5, i.e. never for integer mant7 in 1..127
    # (2^-109 * 127 < 0.5), can round up; every nonzero value here is < 0.5
    # ulp so RNE gives 0, EXCEPT nothing reaches 0.5. Hence: always zero.
    # (Documented: no BF16 subnormal is within half an FP16-subnormal-ULP
    # of the smallest FP16 subnormal; all flush to signed zero.)
    return UInt16(0)


def _f16_rne_bits_subnormal_full(e: Int, mant7: Int) -> UInt16:
    """RNE of v = (128 + mant7) * 2^(e-7) with e+15 <= 0 to FP16 subnormal bits."""
    # Target: 10-bit subnormal mantissa M = round((128 + mant7) * 2^(e+17)).
    var base = 128 + mant7  # in [128, 255]
    var shift = e + 17  # <= 2 (since e <= -15)
    var m: Int
    if shift >= 0:
        m = base << shift  # exact
    elif shift < -10:
        # base * 2^shift < 2^8 * 2^-10 = 0.5, and it can never be exactly 0.5
        # (that would need base = 2^(-shift-1) >= 1024 > 255), so RNE -> 0.
        # (This also avoids 64-bit overflow in _rne_shift for huge drops.)
        m = 0
    else:
        m = _rne_shift(base, -shift)
    if m >= 1024:
        # Rounded up into the normal range: smallest normal 0x0400.
        return UInt16(0x0400)
    return UInt16(m)


def _f16_from_bits_exact(w: UInt16) -> Float16:
    """Exact UInt16 bit pattern -> Float16 (all classes incl. NaN/subnormals).

    Uses a pointer bitcast (not scalar bitcast, which Mojo 1.1.0 removed):
    the 16 bits are stored and reloaded as Float16, so the value's bit
    pattern is exactly `w` on every architecture — in particular quiet-NaN
    payloads do not depend on how each CPU renders Inf/Inf.
    """
    var bits = unsafe_alloc[UInt16](1)
    bits[unsafe_offset=0] = w
    var v = bits.unsafe_bitcast[Float16]().unsafe_offset(0).unsafe_load()
    bits.unsafe_free()
    return v


struct SafetensorsLoader:
    """mmap-backed safetensors header parser + FP16 tensor loader."""
    var fd: Int32
    var file_size: Int64
    var map: Pointer[UInt8, MutUntrackedOrigin]
    var header_size: Int64
    var descs: List[STTensorDesc]
    var opened: Bool
    var metadata: Dict[String, String]
    var header_bound: Int
    var tensor_bound: Int
    var rank_bound: Int
    var work_bound: Int
    var depth_bound: Int

    def __init__(out self):
        self.fd = Int32(-1)
        self.file_size = Int64(0)
        self.map = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=1)
        self.header_size = Int64(0)
        self.descs = List[STTensorDesc]()
        self.opened = False
        self.metadata = Dict[String, String]()
        self.header_bound = 100000000
        self.tensor_bound = 100000
        self.rank_bound = 64
        self.work_bound = 100000000
        self.depth_bound = 64

    def _req(self, offset: Int64, byte_count: Int64) raises:
        if not self.opened:
            raise Error("safetensors: live mapped source required")
        if offset < 0 or byte_count < 0:
            raise Error("safetensors: negative byte range")
        if offset > self.file_size or byte_count > self.file_size - offset:
            raise Error("safetensors: truncated file or out-of-range offset")

    def _u64(self, offset: Int64) raises -> UInt64:
        self._req(offset, 8)
        var v = UInt64(0)
        for i in range(8):
            v |= UInt64(self.map.unsafe_offset(Int(offset) + i).unsafe_load()) << UInt64(8 * i)
        return v

    def open(mut self, path: String, header_bound: Int = 100000000,
             tensor_bound: Int = 100000, rank_bound: Int = 64,
             work_bound: Int = 100000000, depth_bound: Int = 64) raises:
        if self.opened:
            raise Error("safetensors: already open")
        if header_bound <= 0 or tensor_bound <= 0 or rank_bound <= 0 or work_bound <= 0 or depth_bound <= 0:
            raise Error("safetensors: explicit policy bounds must be positive")
        if depth_bound > 64:
            raise Error("safetensors: recursive skip depth exceeds current host stack policy 64")
        self.header_bound = header_bound
        self.tensor_bound = tensor_bound
        self.rank_bound = rank_bound
        self.work_bound = work_bound
        self.depth_bound = depth_bound
        self.descs.clear()
        self.metadata.clear()
        self.file_size = 0
        self.header_size = 0
        var path_bytes = List[Int8]()
        var source = path.as_bytes()
        if len(source) == 0 or len(source) >= 4096 or "\0" in path:
            raise Error("safetensors: path must contain 1..4095 non-NUL bytes")
        for i in range(len(source)):
            path_bytes.append(Int8(source[i]))
        path_bytes.append(0)
        self.fd = external_call["open64", Int32](
            path_bytes.unsafe_ptr(), Int32(526336), Int32(0)
        )
        _ = path_bytes
        if self.fd < 0:
            raise Error("safetensors: failed to open " + path)
        var size = external_call["lseek", Int64](self.fd, Int64(0), Int32(2))
        if size < 0:
            self.close()
            raise Error("safetensors: cannot seek " + path)
        self.file_size = size
        if self.file_size < 8:
            self.close()
            raise Error("safetensors: file smaller than the 8-byte header prefix")
        var addr = external_call["mmap", Int](
            Int(0), Int(self.file_size), Int32(1), Int32(2), self.fd, Int64(0)
        )
        if addr == -1:
            self.close()
            raise Error("safetensors: mmap failed on " + path)
        self.map = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=addr)
        self.opened = True
        try:
            self._parse_header()
        except e:
            self.close()
            raise e

    def _parse_header(mut self) raises:
        var raw_size = self._u64(0)
        if raw_size < 2 or raw_size > UInt64(self.header_bound):
            raise Error("safetensors: header length outside explicit bound")
        var n = Int64(raw_size)
        self._req(8, n)
        self.header_size = n
        var parser = JsonParser(self.map.unsafe_offset(8), Int(n), self.depth_bound)
        if parser._peek() != 123:
            raise Error("safetensors: header must begin with object byte")
        parser.expect(123)
        parser.skip_ws()
        var seen_meta = False
        if parser._peek() == 125:
            parser.pos += 1
        else:
            while True:
                var key = parser.parse_string()
                parser.expect(58)
                if key == "__metadata__":
                    if seen_meta:
                        raise Error("safetensors: duplicate __metadata__")
                    seen_meta = True
                    self._parse_metadata(parser)
                else:
                    self._parse_tensor_desc(key, parser)
                parser.skip_ws()
                if parser._peek() == 44:
                    parser.pos += 1
                elif parser._peek() == 125:
                    parser.pos += 1
                    break
                else:
                    raise Error("safetensors: malformed header object")
        parser.skip_ws()
        if parser.pos != parser.n:
            raise Error("safetensors: trailing bytes after header JSON")
        self._validate_descs()

    def _parse_metadata(mut self, mut parser: JsonParser) raises:
        parser.expect(123)
        parser.skip_ws()
        if parser._peek() == 125:
            parser.pos += 1
            return
        while True:
            var key = parser.parse_string()
            if key in self.metadata:
                raise Error("safetensors: duplicate metadata key")
            parser.expect(58)
            self.metadata[key] = parser.parse_string()
            parser.skip_ws()
            if parser._peek() == 44:
                parser.pos += 1
            elif parser._peek() == 125:
                parser.pos += 1
                return
            else:
                raise Error("safetensors: malformed metadata string map")

    def _parse_tensor_desc(mut self, name: String, mut parser: JsonParser) raises:
        var proposed = len(self.descs) + 1
        if proposed > self.tensor_bound or proposed > (self.work_bound // 4) // proposed:
            raise Error("safetensors: tensor count or descriptor work bound exceeded")
        parser.expect(UInt8(123))
        var dtype = UInt8(255)
        var shape = List[Int]()
        var off0 = Int64(-1)
        var off1 = Int64(-1)
        var fields = Dict[String, Bool]()
        while True:
            parser.skip_ws()
            var fkey = parser.parse_string()
            if fkey in fields:
                raise Error("safetensors: duplicate tensor descriptor field")
            fields[fkey] = True
            parser.expect(UInt8(58))
            if fkey == "dtype":
                var ds = parser.parse_string()
                if ds == "F16":
                    dtype = UInt8(0)
                elif ds == "BF16":
                    dtype = UInt8(1)
                elif ds == "F32":
                    dtype = UInt8(2)
                else:
                    raise Error("safetensors: unsupported dtype " + ds)
            elif fkey == "shape":
                parser.expect(UInt8(91))
                parser.skip_ws()
                if parser._peek() != UInt8(93):
                    while True:
                        var dim = parser.parse_size()
                        if dim < 0:
                            raise Error("safetensors: negative shape dimension")
                        if len(shape) >= self.rank_bound:
                            raise Error("safetensors: rank bound exceeded")
                        shape.append(Int(dim))
                        parser.skip_ws()
                        var dd = parser._peek()
                        if dd == UInt8(44):
                            parser.pos += 1
                        elif dd == UInt8(93):
                            parser.pos += 1
                            break
                        else:
                            raise Error("safetensors: malformed shape array")
                else:
                    parser.pos += 1
            elif fkey == "data_offsets":
                parser.expect(UInt8(91))
                off0 = parser.parse_size()
                parser.expect(UInt8(44))
                off1 = parser.parse_size()
                parser.expect(UInt8(93))
            else:
                parser.skip_value()
            parser.skip_ws()
            var d = parser._peek()
            if d == UInt8(44):
                parser.pos += 1
            elif d == UInt8(125):
                parser.pos += 1
                break
            else:
                raise Error("safetensors: malformed tensor descriptor")
        if "shape" not in fields or "data_offsets" not in fields:
            raise Error("safetensors: missing required descriptor field")
        if dtype == UInt8(255):
            raise Error("safetensors: tensor descriptor missing dtype: " + name)
        if off0 < 0 or off1 < 0 or off1 < off0:
            raise Error("safetensors: bad data_offsets for " + name)
        var desc = STTensorDesc()
        desc.name = name
        desc.dtype = dtype
        desc.shape = shape.copy()
        # absolute offsets resolved in _validate_descs (needs header_size)
        desc.data_start = Int(off0)
        desc.data_end = Int(off1)
        for i in range(len(self.descs)):
            if self.descs[i].name == name:
                raise Error("safetensors: duplicate tensor name " + name)
        self.descs.append(desc.copy())

    def _validate_descs(mut self) raises:
        var base = Int64(8) + self.header_size  # _req already established this sum
        var payload = self.file_size - base
        var covered = Int64(0)
        for i in range(len(self.descs)):
            ref d = self.descs[i]
            var n = d.element_count()
            var bpe = Int64(2)
            if d.dtype == UInt8(2):
                bpe = 4
            if n > Int64(9223372036854775807) // bpe:
                raise Error("safetensors: tensor byte size overflows")
            var begin = Int64(d.data_start)
            var end = Int64(d.data_end)
            if begin < 0 or begin > end or end > payload:
                raise Error("safetensors: relative tensor extent outside payload")
            if end - begin != n * bpe:
                raise Error("safetensors: data_offsets size mismatch")
            if end - begin > payload - covered:
                raise Error("safetensors: aggregate tensor bytes exceed payload")
            covered += end - begin
            d.data_start = Int(base + begin)
            d.data_end = Int(base + end)
        for i in range(len(self.descs)):
            ref a = self.descs[i]
            if a.data_start == a.data_end:
                var boundary = a.data_start == Int(base)
                for j in range(len(self.descs)):
                    ref b = self.descs[j]
                    if b.data_start < b.data_end and a.data_start == b.data_end:
                        boundary = True
                if not boundary:
                    raise Error("safetensors: empty tensor is not at a data boundary")
            else:
                for j in range(i + 1, len(self.descs)):
                    ref b = self.descs[j]
                    if b.data_start < b.data_end and a.data_start < b.data_end and b.data_start < a.data_end:
                        raise Error("safetensors: overlapping data offsets")
        if covered != payload:
            raise Error("safetensors: data buffer has holes or unindexed trailing bytes")

    # -- query / load ------------------------------------------------------

    def tensor_count(self) -> Int:
        return len(self.descs)

    def find(self, name: String) raises -> Int:
        for i in range(len(self.descs)):
            if self.descs[i].name == name:
                return i
        raise Error("safetensors: tensor not found: " + name)

    def load_fp16(
        self,
        name: String,
        dst: Pointer[Float16, MutUntrackedOrigin],
    ) raises:
        """Load tensor `name` into `dst` as FP16 (must hold element_count)."""
        if not self.opened:
            raise Error("safetensors: live mapped source required")
        var idx = self.find(name)
        ref d = self.descs[idx]
        var n = Int(d.element_count())
        var src = self.map.unsafe_offset(d.data_start)
        if d.dtype == UInt8(0):
            var src16 = src.unsafe_bitcast[Float16]()
            for i in range(n):
                dst[unsafe_offset=i] = src16.unsafe_offset(i).unsafe_load()
        elif d.dtype == UInt8(2):
            fp32_to_fp16(src.unsafe_bitcast[Float32](), dst, n)
        elif d.dtype == UInt8(1):
            bf16_to_fp16_rne(src.unsafe_bitcast[UInt16](), dst, n)
        else:
            raise Error("safetensors: unknown dtype for " + name)

    def close(mut self):
        if self.opened:
            _ = external_call["munmap", Int32](self.map, Int(self.file_size))
        if self.fd >= 0:
            _ = external_call["close", Int32](self.fd)
        self.fd = Int32(-1)
        self.opened = False
        self.map = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=1)
        self.file_size = 0
        self.header_size = 0
        self.descs.clear()
        self.metadata.clear()


def safetensors_version() -> String:
    return "0.1.0"
