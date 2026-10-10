# armvegr/bpe.mojo
# H046 — byte-pair encoding tokenizer in pure Mojo (Domain D1 ARMVEGR).
#
# GPT-2-style BPE: byte-unicode codec, ordered-alternative pre-tokenizer
# (faithful to the GPT-2 regex
#   's|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+),
# merge-rank application, and byte-fallback (every byte is a vocab token).
# Model data (vocab, merges, Unicode L/N/whitespace ranges) loads from the
# frozen data files produced by prof/armvegr/make_tokenizer_data.py; the
# byte<->unicode codec is computed algorithmically (it is derived, not data).
#
# Unicode tables: data/armvegr/unicode_classes.bin — L (letter), N (number),
# and W (regex-\s whitespace, from the `regex` module tiktoken uses) ranges.

from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin
from std.collections import Dict


struct UnicodeClasses:
    """L/N/W code-point ranges with binary search. Loaded from data file."""
    var l_starts: List[Int]
    var l_ends: List[Int]
    var n_starts: List[Int]
    var n_ends: List[Int]
    var w_starts: List[Int]
    var w_ends: List[Int]

    def __init__(out self):
        self.l_starts = List[Int]()
        self.l_ends = List[Int]()
        self.n_starts = List[Int]()
        self.n_ends = List[Int]()
        self.w_starts = List[Int]()
        self.w_ends = List[Int]()

    def load(mut self, path: String) raises:
        var data = _read_file(path)
        var pos = 0
        for cls in range(3):
            var count = Int(_u32_le(data, pos))
            pos += 4
            for _ in range(count):
                var s = Int(_u32_le(data, pos))
                var e = Int(_u32_le(data, pos + 4))
                pos += 8
                if cls == 0:
                    self.l_starts.append(s)
                    self.l_ends.append(e)
                elif cls == 1:
                    self.n_starts.append(s)
                    self.n_ends.append(e)
                else:
                    self.w_starts.append(s)
                    self.w_ends.append(e)
        if pos != len(data):
            raise Error("bpe: trailing bytes in unicode_classes.bin")
        _ = data

    def _has(self, starts: List[Int], ends: List[Int], cp: Int) -> Bool:
        var lo = 0
        var hi = len(starts)
        while lo < hi:
            var mid = (lo + hi) // 2
            if cp < starts[mid]:
                hi = mid
            elif cp > ends[mid]:
                lo = mid + 1
            else:
                return True
        return False

    def is_letter(self, cp: Int) -> Bool:
        return self._has(self.l_starts, self.l_ends, cp)

    def is_number(self, cp: Int) -> Bool:
        return self._has(self.n_starts, self.n_ends, cp)

    def is_space(self, cp: Int) -> Bool:
        return self._has(self.w_starts, self.w_ends, cp)


struct ByteCodec:
    """GPT-2 bytes<->unicode codec, computed algorithmically."""
    var enc: List[Int]  # byte -> unicode code point (size 256)
    var dec: List[Int]  # code point -> byte or -1 (size 324)

    def __init__(out self):
        var bs = List[Int]()
        for b in range(33, 127):
            bs.append(b)
        for b in range(161, 173):
            bs.append(b)
        for b in range(174, 256):
            bs.append(b)
        var n = 0
        for b in range(256):
            var found = False
            for k in range(len(bs)):
                if bs[k] == b:
                    found = True
                    break
            if not found:
                bs.append(b)
                n += 1
        self.enc = List[Int]()
        self.dec = List[Int]()
        for _ in range(256):
            self.enc.append(0)
        for _ in range(324):
            self.dec.append(-1)
        for i in range(len(bs)):
            var cp = bs[i] if i < 188 else 256 + (i - 188)
            self.enc[bs[i]] = cp
            self.dec[cp] = bs[i]


def _read_file(path: String) raises -> List[UInt8]:
    """Read a whole file into a List[UInt8] (for small data files)."""
    var path_bytes = List[Int8]()
    var source = path.as_bytes()
    if len(source) == 0 or len(source) >= 4096 or "\0" in path:
        raise Error("bpe: bad data path")
    for i in range(len(source)):
        path_bytes.append(Int8(source[i]))
    path_bytes.append(0)
    var fd = external_call["open64", Int32](
        path_bytes.unsafe_ptr(), Int32(526336), Int32(0)
    )
    _ = path_bytes
    if fd < 0:
        raise Error("bpe: cannot open " + path)
    var size = external_call["lseek", Int64](fd, Int64(0), Int32(2))
    if size < 0 or size > Int64(1) << 32:
        _ = external_call["close", Int32](fd)
        raise Error("bpe: cannot size " + path)
    _ = external_call["lseek", Int64](fd, Int64(0), Int32(0))
    var out = List[UInt8]()
    var chunk = unsafe_alloc[UInt8](65536)
    var remaining = Int(size)
    while remaining > 0:
        var want = 65536
        if want > remaining:
            want = remaining
        var got = external_call["read", Int](Int(fd), chunk, want)
        if got <= 0:
            chunk.unsafe_free()
            _ = external_call["close", Int32](fd)
            raise Error("bpe: short read on " + path)
        for i in range(Int(got)):
            out.append(chunk.unsafe_offset(i).unsafe_load())
        remaining -= Int(got)
    chunk.unsafe_free()
    _ = external_call["close", Int32](fd)
    return out.copy()


def _u32_le(data: List[UInt8], pos: Int) -> UInt32:
    return (
        UInt32(data[pos])
        | (UInt32(data[pos + 1]) << 8)
        | (UInt32(data[pos + 2]) << 16)
        | (UInt32(data[pos + 3]) << 24)
    )


def utf8_encode_cp(cp: Int) -> String:
    """Encode one code point as a UTF-8 Mojo String."""
    var b = List[Int8]()
    if cp < 128:
        b.append(Int8(cp))
    elif cp < 2048:
        b.append(Int8(0xC0 | (cp >> 6)))
        b.append(Int8(0x80 | (cp & 63)))
    elif cp < 65536:
        b.append(Int8(0xE0 | (cp >> 12)))
        b.append(Int8(0x80 | ((cp >> 6) & 63)))
        b.append(Int8(0x80 | (cp & 63)))
    else:
        b.append(Int8(0xF0 | (cp >> 18)))
        b.append(Int8(0x80 | ((cp >> 12) & 63)))
        b.append(Int8(0x80 | ((cp >> 6) & 63)))
        b.append(Int8(0x80 | (cp & 63)))
    b.append(0)
    return String(unsafe_from_utf8_ptr=b.unsafe_ptr())


def utf8_decode_cps(s: String) raises -> List[Int]:
    """Decode a Mojo String (UTF-8) into code points. Fails closed on bad UTF-8."""
    var bs = s.as_bytes()
    var out = List[Int]()
    var i = 0
    var n = len(bs)
    while i < n:
        var b0 = Int(bs[i])
        if b0 < 128:
            out.append(b0)
            i += 1
        elif b0 >= 194 and b0 < 224:
            if i + 1 >= n:
                raise Error("bpe: truncated UTF-8")
            var b1 = Int(bs[i + 1])
            if b1 < 128 or b1 >= 192:
                raise Error("bpe: bad UTF-8 continuation")
            out.append(((b0 & 31) << 6) | (b1 & 63))
            i += 2
        elif b0 >= 224 and b0 < 240:
            if i + 2 >= n:
                raise Error("bpe: truncated UTF-8")
            var b1 = Int(bs[i + 1])
            var b2 = Int(bs[i + 2])
            if b1 < 128 or b1 >= 192 or b2 < 128 or b2 >= 192:
                raise Error("bpe: bad UTF-8 continuation")
            var cp = ((b0 & 15) << 12) | ((b1 & 63) << 6) | (b2 & 63)
            if cp < 2048 or (cp >= 55296 and cp <= 57343):
                raise Error("bpe: overlong/surrogate UTF-8")
            out.append(cp)
            i += 3
        elif b0 >= 240 and b0 < 245:
            if i + 3 >= n:
                raise Error("bpe: truncated UTF-8")
            var b1 = Int(bs[i + 1])
            var b2 = Int(bs[i + 2])
            var b3 = Int(bs[i + 3])
            if b1 < 128 or b1 >= 192 or b2 < 128 or b2 >= 192 or b3 < 128 or b3 >= 192:
                raise Error("bpe: bad UTF-8 continuation")
            var cp = ((b0 & 7) << 18) | ((b1 & 63) << 12) | ((b2 & 63) << 6) | (b3 & 63)
            if cp < 65536 or cp > 1114111:
                raise Error("bpe: bad UTF-8 code point")
            out.append(cp)
            i += 4
        else:
            raise Error("bpe: bad UTF-8 lead byte")
    return out.copy()


struct BPEModel:
    """GPT-2 BPE model: vocab, merge ranks, pre-tokenizer, encode/decode."""
    var id2token: List[String]
    var token2id: Dict[String, Int]
    var merge_rank: Dict[Int64, Int]  # (Int64(a) << 32) | Int64(b) -> rank
    var classes: UnicodeClasses
    var codec: ByteCodec

    def __init__(out self):
        self.id2token = List[String]()
        self.token2id = Dict[String, Int]()
        self.merge_rank = Dict[Int64, Int]()
        self.classes = UnicodeClasses()
        self.codec = ByteCodec()

    def load(mut self, bpe_path: String, classes_path: String) raises:
        self.classes.load(classes_path)
        var data = _read_file(bpe_path)
        var pos = 0
        var vocab_size = Int(_u32_le(data, pos))
        pos += 4
        for idx in range(vocab_size):
            var tlen = Int(UInt16(data[pos]) | (UInt16(data[pos + 1]) << 8))
            pos += 2
            var tb = List[Int8]()
            for k in range(tlen):
                tb.append(Int8(data[pos + k]))
            pos += tlen
            tb.append(0)
            var tok = String(unsafe_from_utf8_ptr=tb.unsafe_ptr())
            self.id2token.append(tok)
            self.token2id[tok] = idx
        var n_merges = Int(_u32_le(data, pos))
        pos += 4
        for r in range(n_merges):
            var a = Int(_u32_le(data, pos))
            var b = Int(_u32_le(data, pos + 4))
            pos += 8
            self.merge_rank[(Int64(a) << 32) | Int64(b)] = r
        if pos != len(data):
            raise Error("bpe: trailing bytes in gpt2_bpe.bin")
        _ = data

    def vocab_size(self) -> Int:
        return len(self.id2token)

    # -- pre-tokenizer: ordered alternatives of the GPT-2 pattern ----------

    def _try_contraction(self, cps: List[Int], i: Int) -> Int:
        # Returns match length or 0. Alternatives in pattern order.
        if cps[i] != 39:  # '
            return 0
        var n = len(cps)
        if i + 1 < n and cps[i + 1] == 115:  # 's
            return 2
        if i + 1 < n and cps[i + 1] == 116:  # 't
            return 2
        if i + 2 < n and cps[i + 1] == 114 and cps[i + 2] == 101:  # 're
            return 3
        if i + 2 < n and cps[i + 1] == 118 and cps[i + 2] == 101:  # 've
            return 3
        if i + 1 < n and cps[i + 1] == 109:  # 'm
            return 2
        if i + 2 < n and cps[i + 1] == 108 and cps[i + 2] == 108:  # 'll
            return 3
        if i + 1 < n and cps[i + 1] == 100:  # 'd
            return 2
        return 0

    def pretok_spans(self, cps: List[Int]) -> List[Int]:
        """Split code points into pre-token (start, end) span pairs."""
        var spans = List[Int]()
        var i = 0
        var n = len(cps)
        while i < n:
            var clen = self._try_contraction(cps, i)
            if clen > 0:
                spans.append(i)
                spans.append(i + clen)
                i += clen
                continue
            # ' ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+' — optional single space.
            var j = i
            if cps[j] == 32:
                j += 1
            var matched = False
            if j < n and self.classes.is_letter(cps[j]):
                var k = j
                while k < n and self.classes.is_letter(cps[k]):
                    k += 1
                spans.append(i)
                spans.append(k)
                i = k
                matched = True
            elif j < n and self.classes.is_number(cps[j]):
                var k = j
                while k < n and self.classes.is_number(cps[k]):
                    k += 1
                spans.append(i)
                spans.append(k)
                i = k
                matched = True
            else:
                var j2 = i
                if cps[j2] == 32:
                    j2 += 1
                if j2 < n and not self.classes.is_space(cps[j2]) and not self.classes.is_letter(
                    cps[j2]
                ) and not self.classes.is_number(cps[j2]):
                    var k = j2
                    while k < n and not self.classes.is_space(cps[k]) and not self.classes.is_letter(
                        cps[k]
                    ) and not self.classes.is_number(cps[k]):
                        k += 1
                    spans.append(i)
                    spans.append(k)
                    i = k
                    matched = True
            if matched:
                continue
            # '\s+(?!\S)': longest whitespace run not followed by non-space.
            if self.classes.is_space(cps[i]):
                var k = i
                while k < n and self.classes.is_space(cps[k]):
                    k += 1
                var m = k
                while m > i and m < n and not self.classes.is_space(cps[m]):
                    m -= 1
                if m > i:
                    spans.append(i)
                    spans.append(m)
                    i = m
                    continue
                # fall through to plain \s+
                spans.append(i)
                spans.append(k)
                i = k
                continue
            # Unreachable: every code point matches some alternative above.
            spans.append(i)
            spans.append(i + 1)
            i += 1
        return spans.copy()

    # -- BPE core -----------------------------------------------------------

    def _bpe_piece(self, piece: String) raises -> List[Int]:
        """Encode one pre-token string to ids via merge ranks."""
        var chars = List[String]()
        var cps = utf8_decode_cps(piece)
        for k in range(len(cps)):
            chars.append(utf8_encode_cp(cps[k]))
        var ids = List[Int]()
        if len(chars) == 0:
            return ids.copy()
        if len(chars) == 1:
            var single = self.token2id.get(chars[0], -1)
            if single < 0:
                raise Error("bpe: char not in vocab")
            ids.append(single)
            return ids.copy()
        var word = chars.copy()
        while True:
            var best_rank = 1 << 60
            var best_idx = -1
            for k in range(len(word) - 1):
                var a = self.token2id.get(word[k], -1)
                var b = self.token2id.get(word[k + 1], -1)
                if a < 0 or b < 0:
                    raise Error("bpe: piece not in vocab")
                var key = (Int64(a) << 32) | Int64(b)
                var r = self.merge_rank.get(key, 1 << 60)
                if r < best_rank:
                    best_rank = r
                    best_idx = k
            if best_idx < 0:
                break
            var merged = List[String]()
            var k = 0
            while k < len(word):
                if k == best_idx:
                    var left = String(word[k])
                    var right = String(word[k + 1])
                    merged.append(left + right)
                    k += 2
                else:
                    merged.append(word[k])
                    k += 1
            word = merged.copy()
            if len(word) == 1:
                break
        for k in range(len(word)):
            var wid = self.token2id.get(word[k], -1)
            if wid < 0:
                raise Error("bpe: merged piece not in vocab")
            ids.append(wid)
        return ids.copy()

    def encode(self, text: String) raises -> List[Int]:
        """Encode text to token ids (GPT-2 BPE).

        Faithful to tiktoken: the pre-tokenizer regex runs on the ORIGINAL
        text; each pre-token is then UTF-8 encoded, byte-mapped through the
        byte-unicode codec, and BPE-merged.
        """
        var cps = utf8_decode_cps(text)
        var spans = self.pretok_spans(cps)
        var ids = List[Int]()
        var s = 0
        while s < len(spans):
            var a = spans[s]
            var b = spans[s + 1]
            s += 2
            # Original substring -> UTF-8 bytes -> byte-unicode code points.
            var piece = String("")
            for k in range(a, b):
                piece += utf8_encode_cp(cps[k])
            var pbs = piece.as_bytes()
            var mapped = String("")
            for k in range(len(pbs)):
                mapped += utf8_encode_cp(self.codec.enc[Int(pbs[k])])
            var pids = self._bpe_piece(mapped)
            for k in range(len(pids)):
                ids.append(pids[k])
        return ids.copy()

    def decode(self, ids: List[Int]) raises -> String:
        """Decode token ids to text (inverse of encode)."""
        var cps = List[Int]()
        for k in range(len(ids)):
            var idx = ids[k]
            if idx < 0 or idx >= len(self.id2token):
                raise Error("bpe: token id out of range")
            var pcs = utf8_decode_cps(self.id2token[idx])
            for q in range(len(pcs)):
                cps.append(pcs[q])
        # unicode chars -> bytes
        var out = List[Int8]()
        for k in range(len(cps)):
            var cp = cps[k]
            if cp < 0 or cp >= 324 or self.codec.dec[cp] < 0:
                raise Error("bpe: token chars not byte-decodable")
            out.append(Int8(self.codec.dec[cp]))
        out.append(0)
        return String(unsafe_from_utf8_ptr=out.unsafe_ptr())


def bpe_version() -> String:
    return "0.1.0"
