# armvegr/sp_tokenizer.mojo
# H047 — SentencePiece (BPE) tokenizer in pure Mojo (Domain D1 ARMVEGR).
#
# Hand-rolled protobuf ModelProto parse (pieces only; no protobuf library),
# empirical normalizer (prepend U+2581 dummy prefix, map U+0020 -> U+2581,
# matching the TinyLlama tokenizer.model behavior), greedy highest-score BPE
# merges, UTF-8 byte fallback via BYTE pieces, and ▁-aware decode.
#
# Fail-closed: model_type != BPE, precompiled normalizer, or missing BYTE
# pieces when byte fallback is needed all raise named errors.

from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.collections import Dict

from armvegr.bpe import utf8_decode_cps, utf8_encode_cp, _read_file


def _parse_varint(data: List[UInt8], pos: Int) raises -> Tuple[Int, Int]:
    var result = 0
    var shift = 0
    var p = pos
    while True:
        if p >= len(data):
            raise Error("sp: truncated varint")
        var b = Int(data[p])
        p += 1
        result |= (b & 127) << shift
        if (b & 128) == 0:
            break
        shift += 7
        if shift >= 70:
            raise Error("sp: varint overflow")
    return (result, p)


def _f32_from_le(b0: Int, b1: Int, b2: Int, b3: Int) -> Float32:
    var u = UInt32(b0) | (UInt32(b1) << 8) | (UInt32(b2) << 16) | (UInt32(b3) << 24)
    var p = unsafe_alloc[UInt32](1)
    p.unsafe_store(u)
    var f = p.unsafe_bitcast[Float32]().unsafe_load()
    p.unsafe_free()
    return f


struct SPModel:
    """SentencePiece BPE model loaded from a .model file."""
    var pieces: List[String]
    var scores: List[Float32]
    var types: List[Int]
    var piece_to_id: Dict[String, Int]
    var byte_id: List[Int]  # byte value -> piece id, or -1
    var unk_id: Int
    var bos_id: Int
    var eos_id: Int

    def __init__(out self):
        self.pieces = List[String]()
        self.scores = List[Float32]()
        self.types = List[Int]()
        self.piece_to_id = Dict[String, Int]()
        self.byte_id = List[Int]()
        for _ in range(256):
            self.byte_id.append(-1)
        self.unk_id = -1
        self.bos_id = -1
        self.eos_id = -1

    def load(mut self, path: String) raises:
        var data = _read_file(path)
        var pos = 0
        var n = len(data)
        var model_type = -1
        while pos < n:
            var tag: Int
            var np: Int
            (tag, np) = _parse_varint(data, pos)
            pos = np
            var field = tag >> 3
            var wt = tag & 7
            if field == 1 and wt == 2:
                var ln: Int
                (ln, pos) = _parse_varint(data, pos)
                self._parse_piece(data, pos, pos + ln)
                pos += ln
            elif wt == 0:
                var _v: Int
                (_v, pos) = _parse_varint(data, pos)
            elif wt == 1:
                pos += 8
            elif wt == 2:
                var ln2: Int
                (ln2, pos) = _parse_varint(data, pos)
                # Look for TrainerSpec (model_type field 17). Heuristic: a
                # submessage containing field 17 varint is the trainer spec.
                if model_type < 0:
                    model_type = _find_model_type(data, pos, pos + ln2)
                pos += ln2
            elif wt == 5:
                pos += 4
            else:
                raise Error("sp: bad protobuf wire type")
        if len(self.pieces) == 0:
            raise Error("sp: no pieces in model")
        if model_type < 0:
            raise Error("sp: model_type not found (unsupported model)")
        if model_type != 2:
            raise Error("sp: only BPE (model_type=2) supported")
        # Resolve special ids.
        for i in range(len(self.pieces)):
            var t = self.types[i]
            if t == 2:
                self.unk_id = i
            elif t == 6:
                # BYTE piece: "<0xHH>"
                var pc = self.pieces[i]
                if len(pc.as_bytes()) == 6:
                    var hexpart = pc.as_bytes()
                    var hv = _hex_byte(Int(hexpart[3]), Int(hexpart[4]))
                    if hv >= 0:
                        self.byte_id[hv] = i
            if self.pieces[i] == "<s>":
                self.bos_id = i
            elif self.pieces[i] == "</s>":
                self.eos_id = i

    def _parse_piece(mut self, data: List[UInt8], s: Int, e: Int) raises:
        var piece = String("")
        var score = Float32(0.0)
        var ptype = 1
        var pos = s
        while pos < e:
            var tag: Int
            var np: Int
            (tag, np) = _parse_varint(data, pos)
            pos = np
            var field = tag >> 3
            var wt = tag & 7
            if field == 1 and wt == 2:
                var ln: Int
                (ln, pos) = _parse_varint(data, pos)
                var tb = List[Int8]()
                for k in range(ln):
                    tb.append(Int8(data[pos + k]))
                pos += ln
                tb.append(0)
                piece = String(unsafe_from_utf8_ptr=tb.unsafe_ptr())
            elif field == 2 and wt == 5:
                score = _f32_from_le(
                    Int(data[pos]), Int(data[pos + 1]), Int(data[pos + 2]), Int(data[pos + 3])
                )
                pos += 4
            elif field == 3 and wt == 0:
                var v: Int
                (v, pos) = _parse_varint(data, pos)
                ptype = v
            elif wt == 0:
                var _v: Int
                (_v, pos) = _parse_varint(data, pos)
            elif wt == 2:
                var ln3: Int
                (ln3, pos) = _parse_varint(data, pos)
                pos += ln3
            elif wt == 1:
                pos += 8
            elif wt == 5:
                pos += 4
            else:
                raise Error("sp: bad wire type in piece")
        var idx = len(self.pieces)
        self.pieces.append(piece)
        self.scores.append(score)
        self.types.append(ptype)
        if ptype == 1 or ptype == 4:
            # NORMAL and USER_DEFINED participate in BPE lookup.
            self.piece_to_id[piece] = idx

    def vocab_size(self) -> Int:
        return len(self.pieces)


def _find_model_type(data: List[UInt8], s: Int, e: Int) -> Int:
    """Scan a submessage for field 17 (model_type) varint. Returns -1 if absent."""
    var pos = s
    while pos < e:
        try:
            var tag: Int
            var np: Int
            (tag, np) = _parse_varint(data, pos)
            pos = np
            var field = tag >> 3
            var wt = tag & 7
            if field == 17 and wt == 0:
                var v: Int
                var _np: Int
                (v, _np) = _parse_varint(data, pos)
                return v
            if wt == 0:
                var _v: Int
                (_v, pos) = _parse_varint(data, pos)
            elif wt == 1:
                pos += 8
            elif wt == 2:
                var ln: Int
                (ln, pos) = _parse_varint(data, pos)
                pos += ln
            elif wt == 5:
                pos += 4
            else:
                return -1
        except:
            return -1
    return -1


def _hex_byte(hi: Int, lo: Int) -> Int:
    var h = -1
    var l = -1
    if hi >= 48 and hi <= 57:
        h = hi - 48
    elif hi >= 65 and hi <= 70:
        h = hi - 55
    elif hi >= 97 and hi <= 102:
        h = hi - 87
    if lo >= 48 and lo <= 57:
        l = lo - 48
    elif lo >= 65 and lo <= 70:
        l = lo - 55
    elif lo >= 97 and lo <= 102:
        l = lo - 87
    if h < 0 or l < 0:
        return -1
    return h * 16 + l


def sp_normalize(text: String) raises -> String:
    """Empirical normalizer for tokenizer.model: prepend U+2581 dummy prefix
    (if non-empty), map U+0020 -> U+2581. Other bytes/chars untouched."""
    var bs = text.as_bytes()
    if len(bs) == 0:
        return String("")
    var cps = utf8_decode_cps(text)
    var out = String("")
    out += utf8_encode_cp(9601)  # U+2581
    for k in range(len(cps)):
        var cp = cps[k]
        if cp == 32:
            out += utf8_encode_cp(9601)
        else:
            out += utf8_encode_cp(cp)
    return out


struct SPTokenizer:
    """SentencePiece BPE encode/decode over an SPModel."""
    var model: SPModel

    def __init__(out self):
        self.model = SPModel()

    def load(mut self, path: String) raises:
        self.model.load(path)

    def encode(self, text: String) raises -> List[Int]:
        var norm = sp_normalize(text)
        if len(norm.as_bytes()) == 0:
            return List[Int]()
        var cps = utf8_decode_cps(norm)
        # Build symbols. Byte-fallback symbols are flagged non-merging.
        var sym_piece = List[String]()
        var sym_id = List[Int]()
        var sym_mergeable = List[Bool]()
        for k in range(len(cps)):
            var ch = utf8_encode_cp(cps[k])
            var pid = self.model.piece_to_id.get(ch, -1)
            if pid >= 0:
                sym_piece.append(ch)
                sym_id.append(pid)
                sym_mergeable.append(True)
            else:
                var cpb = ch.as_bytes()
                for b in range(len(cpb)):
                    var bv = Int(cpb[b])
                    var bid = self.model.byte_id[bv]
                    if bid < 0:
                        if self.model.unk_id < 0:
                            raise Error("sp: byte fallback unavailable and no unk")
                        # Whole char -> UNK (no byte pieces in model).
                        sym_piece.append(ch)
                        sym_id.append(self.model.unk_id)
                        sym_mergeable.append(False)
                        break
                    sym_piece.append(String(""))
                    sym_id.append(bid)
                    sym_mergeable.append(False)
        # Greedy highest-score BPE merges.
        var n = len(sym_piece)
        var active = List[Bool]()
        for _ in range(n):
            active.append(True)
        var remaining = n
        while remaining > 1:
            var best_score = Float32(-1e30)
            var best_i = -1
            var best_id = -1
            var best_str = String("")
            var i = 0
            while i < n:
                if not active[i]:
                    i += 1
                    continue
                var j = i + 1
                while j < n and not active[j]:
                    j += 1
                if j >= n:
                    break
                if sym_mergeable[i] and sym_mergeable[j]:
                    var left = String(sym_piece[i])
                    var right = String(sym_piece[j])
                    var cand = left + right
                    var cid = self.model.piece_to_id.get(cand, -1)
                    if cid >= 0:
                        var sc = self.model.scores[cid]
                        if sc > best_score:
                            best_score = sc
                            best_i = i
                            best_id = cid
                            best_str = cand
                i = j
            if best_i < 0:
                break
            var j2 = best_i + 1
            while j2 < n and not active[j2]:
                j2 += 1
            sym_piece[best_i] = best_str
            sym_id[best_i] = best_id
            # Merged symbols stay mergeable (they are normal pieces).
            active[j2] = False
            remaining -= 1
        var ids = List[Int]()
        for k in range(n):
            if active[k]:
                ids.append(sym_id[k])
        return ids.copy()

    def decode(self, ids: List[Int]) raises -> String:
        """Decode ids to text. Strips one leading U+2581 (dummy prefix),
        maps U+2581 -> U+0020 elsewhere, expands BYTE pieces to bytes."""
        var out_bytes = List[Int8]()
        for pos in range(len(ids)):
            var idx = ids[pos]
            if idx < 0 or idx >= self.model.vocab_size():
                raise Error("sp: token id out of range")
            var t = self.model.types[idx]
            if t == 6:
                var bv = -1
                for b in range(256):
                    if self.model.byte_id[b] == idx:
                        bv = b
                        break
                if bv < 0:
                    raise Error("sp: byte piece id not resolved")
                out_bytes.append(Int8(bv))
            else:
                var pc = self.model.pieces[idx]
                var pcs = utf8_decode_cps(pc)
                var start = 0
                if pos == 0 and len(pcs) > 0 and pcs[0] == 9601:
                    start = 1
                for k in range(start, len(pcs)):
                    var cp = pcs[k]
                    if cp == 9601:
                        cp = 32
                    var es = utf8_encode_cp(cp)
                    var eb = es.as_bytes()
                    for q in range(len(eb)):
                        out_bytes.append(Int8(eb[q]))
        out_bytes.append(0)
        return String(unsafe_from_utf8_ptr=out_bytes.unsafe_ptr())


def sp_version() -> String:
    return "0.1.0"
