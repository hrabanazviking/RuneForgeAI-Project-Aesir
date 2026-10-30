# loader/tokenizer.mojo
# The Rune Weaver: model-driven Llama SentencePiece tokenizer.

from std.collections import Dict
from std.collections.string import ord
from loader.unicode_categories import llama_character_class


def _canonical_special_spellings() -> List[String]:
    """Canonical chat-control spellings encode resolves fail-closed (R003).

    These spellings are matched by shape in the prompt even when the
    model's vocabulary never registered them as CONTROL/USER_DEFINED:
    resolution goes through special_token_id, which raises naming the
    spelling when the model did not ship it, so a template's control
    token can never be silently byte-encoded into nonsense.
    """
    var spellings = List[String]()
    spellings.append("<start_of_turn>")
    spellings.append("<end_of_turn>")
    spellings.append("<|im_start|>")
    spellings.append("<|im_end|>")
    spellings.append("<|endoftext|>")
    return spellings^


struct RuneWeaver:
    """Pure Mojo tokenizer state loaded from GGUF metadata."""

    var vocab: List[String]
    var token_to_id: Dict[String, Int]
    var scores: List[Float32]
    var token_types: List[Int]
    var vocab_size: Int
    var unknown_token_id: Int
    var bos_token_id: Int
    var eos_token_id: Int
    var add_bos_token: Bool
    var add_space_prefix: Bool
    var special_tokens_configured: Bool
    # BPE state: raw merge strings ("pieceA pieceB") mapped to their rank.
    # A vocabulary ships merges exactly when it is a byte-level BPE vocab
    # (tokenizer.ggml.model == "gpt2"); SentencePiece vocabs ship scores
    # instead and keep the score-greedy path.
    var merge_ranks: Dict[String, Int]
    var merge_count: Int
    var bpe_mode: Bool
    var special_spellings: List[String]
    # tokenizer.ggml.model string ("gpt2", "llama", "gemma4", ...).
    # Gemma 4 ships merges but is NOT GPT-2 byte-level BPE: its encode
    # is merge-rank BPE over raw UTF-8 with space->marker replacement
    # (see _encode_segment_gemma4), and decode must not apply the
    # GPT-2 byte-map inversion (see decode).
    var model_name: String
    # tokenizer.ggml.pre ("llama-bpe", "qwen2", "default", ...).
    var pre_tokenizer: String

    def __init__(out self):
        self.vocab = List[String]()
        self.token_to_id = Dict[String, Int]()
        self.scores = List[Float32]()
        self.token_types = List[Int]()
        self.vocab_size = 0
        self.unknown_token_id = 0
        self.bos_token_id = 1
        self.eos_token_id = 2
        self.add_bos_token = True
        self.add_space_prefix = False
        self.special_tokens_configured = False
        self.merge_ranks = Dict[String, Int]()
        self.merge_count = 0
        self.bpe_mode = False
        self.special_spellings = List[String]()
        self.model_name = String("")
        self.pre_tokenizer = String("")

    def add_merge(mut self, raw_merge: String):
        """Records one GGUF BPE merge line; file order is the rank order."""
        if raw_merge in self.merge_ranks:
            return
        self.merge_ranks[raw_merge] = self.merge_count
        self.merge_count += 1
        self.bpe_mode = True

    def _note_special_spelling(mut self, token_id: Int, token_type: Int):
        """Collects CONTROL/USER_DEFINED spellings for encode-time splits.

        GGUF token types: 3 = CONTROL, 4 = USER_DEFINED. Byte tokens
        (type 6, "<0xXX>") are data, never literal text markers, and stay
        excluded. Matching is longest-wins, so no ordering is needed.
        """
        if token_type != 3 and token_type != 4:
            return
        if token_id < 0 or token_id >= len(self.vocab):
            return
        var spelling = String(self.vocab[token_id])
        if len(spelling.as_bytes()) < 2:
            return
        if spelling.startswith("<0x"):
            return
        if spelling not in self.special_spellings:
            self.special_spellings.append(spelling)

    def add_token(
        mut self,
        token: String,
        token_id: Int,
        score: Float32 = 0.0,
        token_type: Int = 1,
    ) raises:
        """Adds one vocabulary entry while keeping parallel metadata aligned."""
        if token_id < 0:
            raise Error(
                "add_token: token id must be non-negative, got "
                + String(token_id)
            )
        while len(self.vocab) <= token_id:
            self.vocab.append("")
            self.scores.append(0.0)
            self.token_types.append(1)
        self.vocab[token_id] = token
        self.scores[token_id] = score
        self.token_types[token_id] = token_type
        self.token_to_id[token] = token_id
        self.vocab_size = len(self.vocab)
        self._note_special_spelling(token_id, token_type)

    def set_token_score(mut self, token_id: Int, score: Float32):
        while len(self.scores) <= token_id:
            self.scores.append(0.0)
        self.scores[token_id] = score

    def set_token_type(mut self, token_id: Int, token_type: Int):
        while len(self.token_types) <= token_id:
            self.token_types.append(1)
        self.token_types[token_id] = token_type
        self._note_special_spelling(token_id, token_type)

    def set_special_tokens(
        mut self,
        unknown_token_id: Int,
        bos_token_id: Int,
        eos_token_id: Int,
    ):
        self.unknown_token_id = unknown_token_id
        self.bos_token_id = bos_token_id
        self.eos_token_id = eos_token_id
        self.special_tokens_configured = True

    def validate_vocabulary(self) raises:
        """Validates parallel list lengths, vocabulary size, and special token bounds."""
        if self.vocab_size <= 0:
            raise Error("Tokenizer vocabulary is empty")
        if len(self.vocab) != self.vocab_size:
            raise Error("Tokenizer vocab length does not match vocab_size")
        if len(self.scores) != self.vocab_size:
            raise Error("Tokenizer scores length does not match vocab_size")
        if len(self.token_types) != self.vocab_size:
            raise Error("Tokenizer token_types length does not match vocab_size")
        if self.unknown_token_id < 0 or self.unknown_token_id >= self.vocab_size:
            raise Error("Tokenizer unknown_token_id is out of bounds")
        if self.bos_token_id < 0 or self.bos_token_id >= self.vocab_size:
            raise Error("Tokenizer bos_token_id is out of bounds")
        if self.eos_token_id < 0 or self.eos_token_id >= self.vocab_size:
            raise Error("Tokenizer eos_token_id is out of bounds")
        # Every populated spelling must map back to its own id through
        # token_to_id. "" entries are add_token gap-fill placeholders for
        # skipped ids and stay valid, so they are skipped. This catches both
        # missing coverage (spelling absent from token_to_id) and duplicate
        # strings (token_to_id keeps the last id, so the earlier id fails).
        for i in range(self.vocab_size):
            var spelling = String(self.vocab[i])
            if spelling == "":
                continue
            if self.token_to_id.get(spelling, -1) != i:
                raise Error(
                    "Tokenizer vocabulary coverage error at token id "
                    + String(i)
                    + ": spelling '"
                    + spelling
                    + "' does not map back to this id (missing from token_to_id or duplicated)"
                )
        # Declared special token ids must carry real, non-empty spellings.
        # Enforced only when set_special_tokens was explicitly called: a
        # hand-built weaver with default ids 0/1/2 over "" gap-fill slots
        # must keep validating.
        if self.special_tokens_configured:
            if self.vocab[self.unknown_token_id] == "":
                raise Error(
                    "Tokenizer unknown_token_id "
                    + String(self.unknown_token_id)
                    + " has an empty spelling"
                )
            if self.vocab[self.bos_token_id] == "":
                raise Error(
                    "Tokenizer bos_token_id "
                    + String(self.bos_token_id)
                    + " has an empty spelling"
                )
            if self.vocab[self.eos_token_id] == "":
                raise Error(
                    "Tokenizer eos_token_id "
                    + String(self.eos_token_id)
                    + " has an empty spelling"
                )

    def byte_to_hex_token(self, byte_value: UInt8) -> String:
        """Formats one raw byte using GGUF's canonical byte-token spelling."""
        var hex_digits = String("0123456789ABCDEF")
        var high = Int(byte_value >> 4)
        var low = Int(byte_value & 0xF)
        return (
            String("<0x")
            + String(hex_digits[byte=high : high + 1])
            + String(hex_digits[byte=low : low + 1])
            + String(">")
        )

    def _is_valid_utf8(self, text: String) -> Bool:
        var raw = text.as_bytes()
        var index = 0
        while index < len(raw):
            var first = raw[index]
            if first <= 0x7F:
                index += 1
                continue
            var continuation_count: Int
            var second_min = UInt8(0x80)
            var second_max = UInt8(0xBF)
            if first >= 0xC2 and first <= 0xDF:
                continuation_count = 1
            elif first == 0xE0:
                continuation_count = 2
                second_min = 0xA0
            elif (first >= 0xE1 and first <= 0xEC) or (first >= 0xEE and first <= 0xEF):
                continuation_count = 2
            elif first == 0xED:
                continuation_count = 2
                second_max = 0x9F
            elif first == 0xF0:
                continuation_count = 3
                second_min = 0x90
            elif first >= 0xF1 and first <= 0xF3:
                continuation_count = 3
            elif first == 0xF4:
                continuation_count = 3
                second_max = 0x8F
            else:
                return False
            if index + continuation_count >= len(raw):
                return False
            var second = raw[index + 1]
            if second < second_min or second > second_max:
                return False
            for continuation_index in range(2, continuation_count + 1):
                var continuation = raw[index + continuation_index]
                if continuation < 0x80 or continuation > 0xBF:
                    return False
            index += continuation_count + 1
        return True

    def _append_utf8_symbols(self, text: String, mut pieces: List[String]):
        """Splits UTF-8 text into complete code-point symbols without truncation."""
        var raw = text.as_bytes()
        var index = 0
        while index < len(raw):
            var first = raw[index]
            var width = 1
            if first >= 0xF0:
                width = 4
            elif first >= 0xE0:
                width = 3
            elif first >= 0xC0:
                width = 2
            if index + width > len(raw):
                width = 1
            pieces.append(String(text[byte=index : index + width]))
            index += width

    def _initial_pieces(self, prompt: String) -> List[String]:
        """Applies model space markers without Unicode normalization."""
        # Preserve caller code points: model vocabularies may distinguish
        # canonically equivalent forms. Only ASCII space gets marker rewriting.
        var uses_llama_space = "▁" in self.token_to_id
        var uses_gpt2_space = "Ġ" in self.token_to_id
        var normalized = String("")
        # The prefix is the SPM space marker whenever this vocab uses
        # it; a stray Ġ token elsewhere in the vocab (Oprius ships one
        # at id 31937) must not suppress it: llama.cpp prefixes every
        # SPM fragment for add_space_prefix vocabs regardless.
        if self.add_space_prefix and uses_llama_space:
            normalized = "▁"
        var prompt_bytes = prompt.as_bytes()
        var byte_index = 0
        while byte_index < len(prompt_bytes):
            if prompt_bytes[byte_index] == 0x20:
                # SentencePiece vocabs mark spaces with ▁. Some (Gemma)
                # also contain a stray Ġ token; preferring Ġ here floods
                # the merge with a marker the model never trained on.
                # Byte-level BPE vocabs never reach this path (they use
                # the byte-map initial pieces instead).
                if uses_llama_space:
                    normalized += String("▁")
                elif uses_gpt2_space:
                    normalized += String("Ġ")
                else:
                    normalized += String(" ")
                byte_index += 1
                continue
            var width = 1
            if prompt_bytes[byte_index] >= 0xF0:
                width = 4
            elif prompt_bytes[byte_index] >= 0xE0:
                width = 3
            elif prompt_bytes[byte_index] >= 0xC0:
                width = 2
            if byte_index + width > len(prompt_bytes):
                width = 1
            normalized += String(prompt[byte=byte_index : byte_index + width])
            byte_index += width

        var pieces = List[String]()
        self._append_utf8_symbols(normalized, pieces)
        return pieces^

    def _merge_sentencepiece(self, mut pieces: List[String]) -> List[String]:
        """Greedily merges the adjacent vocabulary pair with the highest score."""
        while len(pieces) > 1:
            var best_pair_index = -1
            var best_score = Float32(-3.4028235e38)

            for index in range(len(pieces) - 1):
                var merged = String(pieces[index]) + String(pieces[index + 1])
                if merged not in self.token_to_id:
                    continue
                var token_id = self.token_to_id.get(merged, -1)
                if token_id < 0 or token_id >= len(self.scores):
                    continue
                var score = self.scores[token_id]
                # Stable score ordering: equal scores keep the earliest pair.
                if score > best_score or (
                    score == best_score
                    and (best_pair_index < 0 or index < best_pair_index)
                ):
                    best_score = score
                    best_pair_index = index

            if best_pair_index < 0:
                break

            var next_pieces = List[String]()
            for index in range(len(pieces)):
                if index == best_pair_index:
                    next_pieces.append(
                        String(pieces[index]) + String(pieces[index + 1])
                    )
                elif index == best_pair_index + 1:
                    continue
                else:
                    next_pieces.append(String(pieces[index]))
            pieces = next_pieces.copy()
        return pieces.copy()

    def _bpe_symbol(self, byte_value: UInt8) -> String:
        """Maps one raw byte to its GPT-2 byte-level BPE symbol string.

        Printable ranges map to themselves; every other byte maps to
        U+0100+n in increasing byte order (space -> Ġ, newline -> Ċ,
        tab -> ĉ), the standard bytes_to_unicode table GGUF BPE
        vocabularies are spelled in.
        """
        var b = Int(byte_value)
        var direct = (
            (b >= 0x21 and b <= 0x7E)
            or (b >= 0xA1 and b <= 0xAC)
            or (b >= 0xAE and b <= 0xFF)
        )
        if direct:
            return chr(b)
        var n = 0
        for v in range(b):
            var is_direct = (
                (v >= 0x21 and v <= 0x7E)
                or (v >= 0xA1 and v <= 0xAC)
                or (v >= 0xAE and v <= 0xFF)
            )
            if not is_direct:
                n += 1
        return chr(256 + n)

    def _initial_pieces_bpe(self, segment: String) -> List[String]:
        """Splits a text segment into GPT-2 byte-level BPE symbols."""
        var pieces = List[String]()
        var raw = segment.as_bytes()
        for i in range(len(raw)):
            pieces.append(self._bpe_symbol(raw[i]))
        return pieces^

    def _merge_bpe(self, mut pieces: List[String]) -> List[String]:
        """Merges adjacent pieces by GGUF BPE merge rank, lowest first."""
        while len(pieces) > 1:
            var best_pair_index = -1
            var best_rank = 0
            for index in range(len(pieces) - 1):
                var key = (
                    String(pieces[index])
                    + String(" ")
                    + String(pieces[index + 1])
                )
                if key not in self.merge_ranks:
                    continue
                var rank = self.merge_ranks.get(key, -1)
                if rank < 0:
                    continue
                if best_pair_index < 0 or rank < best_rank:
                    best_rank = rank
                    best_pair_index = index
            if best_pair_index < 0:
                break
            var next_pieces = List[String]()
            for index in range(len(pieces)):
                if index == best_pair_index:
                    next_pieces.append(
                        String(pieces[index]) + String(pieces[index + 1])
                    )
                elif index == best_pair_index + 1:
                    continue
                else:
                    next_pieces.append(String(pieces[index]))
            pieces = next_pieces.copy()
        return pieces.copy()

    def _encode_segment_gemma4(self, text: String, mut tokens: List[Int]):
        """Gemma 4 segment encode: raw UTF-8 symbols, spaces escaped to
        the sentencepiece marker, then lowest-merge-rank pairing until
        no pair remains in the merge table. Mirrors loader/
        gemma4_tokenizer.mojo (the CUDA session's tokenizer) exactly:
        callers split the text at newline boundaries first."""
        var normalized = text.replace(" ", "▁")
        if text.startswith("\n") and normalized in self.token_to_id:
            tokens.append(self.token_to_id.get(normalized, self.unknown_token_id))
            return
        var pieces = List[String]()
        self._append_utf8_symbols(normalized, pieces)
        while len(pieces) > 1:
            var best = -1
            var best_rank = 2147483647
            for index in range(len(pieces) - 1):
                var pair = pieces[index] + " " + pieces[index + 1]
                var rank = self.merge_ranks.get(pair, 2147483647)
                if rank < best_rank:
                    best = index
                    best_rank = rank
            if best < 0:
                break
            var merged = String(pieces[best]) + String(pieces[best + 1])
            pieces[best] = merged
            _ = pieces.pop(best + 1)
        for piece in pieces:
            self._append_piece_tokens(piece, tokens)

    def _gpt2_segments(self, text: String, digit_limit: Int) -> List[String]:
        """GPT-2 regex pre-tokenization without a regex runtime.

        Mirrors loader/llama3_tokenizer.mojo's _native_gpt2_segments
        exactly (classes from loader.unicode_categories: 1=letter,
        2=number, 3=regex whitespace, 0=other): contractions, an
        optional single non-letter prefix plus a letter run, digit runs
        (capped at digit_limit when > 0), symbol runs with trailing
        newlines, and the whitespace rules (a whitespace run keeps its
        last space for the next pre-token unless it ends in a newline
        or reaches the end of the text).
        """
        var chars = List[String]()
        self._append_utf8_symbols(text, chars)
        var classes = List[Int]()
        for char in chars:
            classes.append(llama_character_class(ord(char)))
        var output = List[String]()
        var i = 0
        while i < len(chars):
            var end = i
            if chars[i] == "'":
                var suffixes: List[String] = ["s", "t", "re", "ve", "m", "ll", "d"]
                for suffix in suffixes:
                    var size = suffix.byte_length()
                    if i + size < len(chars):
                        var candidate = String("")
                        for j in range(i + 1, i + size + 1):
                            candidate += chars[j]
                        if candidate.lower() == suffix:
                            end = i + size + 1
                            break
            if end == i:
                var first_letter = i
                if classes[i] != 1 and classes[i] != 2 and chars[i] != "\r" and chars[i] != "\n":
                    first_letter += 1
                if first_letter < len(chars) and classes[first_letter] == 1:
                    end = first_letter + 1
                    while end < len(chars) and classes[end] == 1:
                        end += 1
            if end == i and classes[i] == 2:
                end = i + 1
                var digit_end = len(chars) if digit_limit == 0 else min(i + digit_limit, len(chars))
                while end < digit_end and classes[end] == 2:
                    end += 1
            if end == i:
                var first_punct = i + (1 if chars[i] == " " else 0)
                if first_punct < len(chars) and classes[first_punct] == 0:
                    end = first_punct + 1
                    while end < len(chars) and classes[end] == 0:
                        end += 1
                    while end < len(chars) and (chars[end] == "\n" or chars[end] == "\r"):
                        end += 1
            if end == i and classes[i] == 3:
                var last_newline = -1
                var stop = i
                while stop < len(chars) and classes[stop] == 3:
                    if chars[stop] == "\n" or chars[stop] == "\r":
                        last_newline = stop
                    stop += 1
                if last_newline >= 0:
                    end = last_newline + 1
                elif stop == len(chars):
                    end = stop
                else:
                    end = max(i + 1, stop - 1)
            if end == i:
                end = i + 1
            var segment = String("")
            for j in range(i, end):
                segment += chars[j]
            output.append(segment)
            i = end
        return output^

    def _encode_segment(self, segment: String, mut tokens: List[Int]):
        """Encodes one special-token-free text segment into tokens."""
        if len(segment.as_bytes()) == 0:
            return
        if self.model_name == "gemma4":
            var raw = segment.as_bytes()
            var start = 0
            for i in range(1, len(raw)):
                if (raw[i] == 10) != (raw[i - 1] == 10):
                    self._encode_segment_gemma4(String(segment[byte=start:i]), tokens)
                    start = i
            if start < len(raw):
                self._encode_segment_gemma4(String(segment[byte=start:len(raw)]), tokens)
            return
        if self.bpe_mode:
            if self.pre_tokenizer == "llama-bpe" or self.pre_tokenizer == "qwen2":
                # GPT-2-family pre-tokenization first (the same regex the
                # native Llama3Tokenizer implements): merges never cross
                # pre-token boundaries. llama-bpe caps digit runs at 3;
                # qwen2 leaves them uncapped.
                var digit_limit = 3 if self.pre_tokenizer == "llama-bpe" else 0
                var segs = self._gpt2_segments(segment, digit_limit)
                for si in range(len(segs)):
                    var spieces = self._initial_pieces_bpe(segs[si])
                    spieces = self._merge_bpe(spieces)
                    for p in range(len(spieces)):
                        self._append_piece_tokens(String(spieces[p]), tokens)
            else:
                var bpieces = self._initial_pieces_bpe(segment)
                bpieces = self._merge_bpe(bpieces)
                for p in range(len(bpieces)):
                    self._append_piece_tokens(String(bpieces[p]), tokens)
        else:
            var spieces = self._initial_pieces(segment)
            spieces = self._merge_sentencepiece(spieces)
            for p in range(len(spieces)):
                self._append_piece_tokens(String(spieces[p]), tokens)

    def _match_special_at(self, text: String, byte_index: Int) -> Int:
        """Returns the longest special spelling matching at byte_index."""
        var n_bytes = len(text.as_bytes())
        var best = -1
        var best_len = 0
        for s in range(len(self.special_spellings)):
            var spelling = String(self.special_spellings[s])
            var slen = len(spelling.as_bytes())
            if slen <= best_len:
                continue
            if byte_index + slen <= n_bytes:
                # Byte-exact compare: slicing the text into a String span
                # at an arbitrary byte offset traps in the stdlib when
                # the offset is not a codepoint boundary (any multibyte
                # character followed by enough text crashed encode).
                # llama.cpp's special-token scan is byte-level; so is
                # this. A spelling can only match where its bytes do.
                var text_bytes = text.as_bytes()
                var spelling_bytes = spelling.as_bytes()
                var matches = True
                for k in range(slen):
                    if text_bytes[byte_index + k] != spelling_bytes[k]:
                        matches = False
                        break
                if matches:
                    best = s
                    best_len = slen
        return best

    def _match_canonical_special_at(
        self, text: String, byte_index: Int, spellings: List[String]
    ) -> Int:
        """Returns the longest canonical special spelling matching at byte_index."""
        var n_bytes = len(text.as_bytes())
        var best = -1
        var best_len = 0
        for s in range(len(spellings)):
            var spelling = String(spellings[s])
            var slen = len(spelling.as_bytes())
            if slen <= best_len:
                continue
            if byte_index + slen <= n_bytes:
                # Byte-exact compare: slicing the text into a String span
                # at an arbitrary byte offset traps in the stdlib when
                # the offset is not a codepoint boundary (any multibyte
                # character followed by enough text crashed encode).
                # llama.cpp's special-token scan is byte-level; so is
                # this. A spelling can only match where its bytes do.
                var text_bytes = text.as_bytes()
                var spelling_bytes = spelling.as_bytes()
                var matches = True
                for k in range(slen):
                    if text_bytes[byte_index + k] != spelling_bytes[k]:
                        matches = False
                        break
                if matches:
                    best = s
                    best_len = slen
        return best

    def _append_piece_tokens(self, piece: String, mut tokens: List[Int]):
        """Appends a vocabulary token or lossless byte-fallback tokens."""
        if piece in self.token_to_id:
            tokens.append(self.token_to_id.get(piece, self.unknown_token_id))
            return

        var raw = piece.as_bytes()
        for byte_index in range(len(raw)):
            var byte_token = self.byte_to_hex_token(raw[byte_index])
            if byte_token in self.token_to_id:
                tokens.append(
                    self.token_to_id.get(byte_token, self.unknown_token_id)
                )
            else:
                tokens.append(self.unknown_token_id)

    def special_token_id(self, spelling: String) raises -> Int:
        """Returns the vocabulary id for a special control-token spelling.

        Raises naming the spelling when it is absent from the vocabulary:
        encode must never invent hardcoded fallback ids for spellings the
        model did not ship.
        """
        if spelling in self.token_to_id:
            return self.token_to_id.get(spelling, -1)
        raise Error(
            "RuneWeaver special token spelling is not in the vocabulary: "
            + spelling
        )

    def encode(self, prompt: String, add_bos: Bool = False) raises -> List[Int]:
        """Encodes text with model scores, UTF-8 safety, special control tokens, and byte fallback."""
        var tokens = List[Int]()
        if add_bos and self.add_bos_token and self.bos_token_id >= 0:
            tokens.append(self.bos_token_id)
        if not self._is_valid_utf8(prompt):
            tokens.append(self.unknown_token_id)
            return tokens^
        if len(prompt.as_bytes()) == 0:
            return tokens^
        if self.vocab_size == 0:
            var raw = prompt.as_bytes()
            for byte_index in range(len(raw)):
                tokens.append(Int(raw[byte_index]))
            return tokens^

        # Split out special control/user-defined tokens wherever they
        # appear (<|begin_of_text|>, <|im_start|>, <start_of_turn>, ...):
        # the spellings come from the model's own vocabulary, longest
        # first, exactly as llama.cpp's parse_special pass treats them.
        # Text between specials goes through the model's tokenizer mode
        # (rank-based BPE when the GGUF ships merges, else SPM scores).
        # Canonical chat-control spellings are matched by shape as well
        # and resolved through the same special_token_id gate (R003
        # fail-closed): one that appears in the prompt but was never
        # registered in the vocabulary raises naming the spelling,
        # instead of being silently byte-encoded into nonsense.
        var canonical_spellings = _canonical_special_spellings()
        var n_bytes = len(prompt.as_bytes())
        var i = 0
        var last_idx = 0
        while i < n_bytes:
            var spelling = String("")
            var hit = self._match_special_at(prompt, i)
            if hit >= 0:
                spelling = String(self.special_spellings[hit])
            else:
                var canonical_hit = self._match_canonical_special_at(
                    prompt, i, canonical_spellings
                )
                if canonical_hit >= 0:
                    spelling = String(canonical_spellings[canonical_hit])
            if len(spelling.as_bytes()) > 0:
                if i > last_idx:
                    self._encode_segment(
                        String(prompt[byte=last_idx : i]), tokens
                    )
                tokens.append(self.special_token_id(spelling))
                i += len(spelling.as_bytes())
                last_idx = i
            else:
                i += 1

        if last_idx < n_bytes:
            self._encode_segment(String(prompt[byte=last_idx : n_bytes]), tokens)
        return tokens^

    def decode(self, token: Int) -> String:
        """Decodes one token and reverses BPE space/newline markers with 100% UTF-8 safety."""
        if token < 0 or token >= len(self.vocab):
            return String("")
        var value = String(self.vocab[token]).replace("▁", " ")
        if value == "<0x0A>" or value == "<0x0D>":
            return String("\n")
        if value.startswith("<0x") and value.endswith(">"):
            return String("")
        if self.model_name == "gemma4":
            # Gemma 4 token spellings are raw UTF-8 with the space
            # marker already replaced above; no byte-map inversion.
            return value
        if self.bpe_mode:
            # Full GPT-2 byte-map inversion: each codepoint of the token
            # string maps back to exactly one original byte (see
            # _bpe_inverted_bytes). The marker loop below only covers
            # space/newline/tab and would double-encode everything else.
            var inv = _bpe_inverted_bytes(value)
            var inv_i8 = List[Int8]()
            for b in inv:
                inv_i8.append(Int8(b))
            inv_i8.append(0)
            return String(unsafe_from_utf8_ptr=inv_i8.unsafe_ptr())

        var raw = value.as_bytes()
        var n_bytes = len(raw)
        if n_bytes == 0:
            return String("")

        var out_bytes = List[Int8]()
        var i = 0
        while i < n_bytes:
            # Check Ġ (0xC4 0xA0) -> Space (0x20)
            if i + 2 <= n_bytes and raw[i] == 0xC4 and raw[i + 1] == 0xA0:
                out_bytes.append(0x20)
                i += 2
                continue
            # Check Ċ (0xC4 0x8A) -> Newline (0x0A)
            if i + 2 <= n_bytes and raw[i] == 0xC4 and raw[i + 1] == 0x8A:
                out_bytes.append(0x0A)
                i += 2
                continue
            # Check ĉ (0xC4 0x89) -> Tab (0x09)
            if i + 2 <= n_bytes and raw[i] == 0xC4 and raw[i + 1] == 0x89:
                out_bytes.append(0x09)
                i += 2
                continue
            
            out_bytes.append(Int8(raw[i]))
            i += 1

        out_bytes.append(0)
        return String(unsafe_from_utf8_ptr=out_bytes.unsafe_ptr())


def _bpe_inverted_bytes(value: String) -> List[UInt8]:
    """Inverts the GPT-2 bytes-to-unicode map for one token string.

    Every codepoint of a BPE token string denotes exactly one original
    byte: codepoints in the self-mapped ranges (0x21-0x7E, 0xA1-0xAC,
    0xAE-0xFF) denote the byte of the same value, and codepoints
    0x100-0x143 denote the 68 remaining bytes in increasing order
    (0x00-0x20, 0x7F-0xA0, 0xAD). Codepoints outside the byte alphabet
    (special-token spellings are handled by callers) are re-encoded as
    UTF-8 so nothing is silently dropped.
    """
    var out = List[UInt8]()
    for cp in value.codepoints():
        var c = Int(cp.to_u32())
        if 256 <= c and c < 324:
            var n = c - 256
            if n < 33:
                out.append(UInt8(n))
            elif n < 67:
                out.append(UInt8(0x7F + (n - 33)))
            else:
                out.append(UInt8(0xAD))
        elif (0x21 <= c and c <= 0x7E) or (0xA1 <= c and c <= 0xAC) or (0xAE <= c and c <= 0xFF):
            out.append(UInt8(c))
        elif c < 0x80:
            out.append(UInt8(c))
        elif c < 0x800:
            out.append(UInt8(0xC0 | (c >> 6)))
            out.append(UInt8(0x80 | (c & 0x3F)))
        elif c < 0x10000:
            out.append(UInt8(0xE0 | (c >> 12)))
            out.append(UInt8(0x80 | ((c >> 6) & 0x3F)))
            out.append(UInt8(0x80 | (c & 0x3F)))
        else:
            out.append(UInt8(0xF0 | (c >> 18)))
            out.append(UInt8(0x80 | ((c >> 12) & 0x3F)))
            out.append(UInt8(0x80 | ((c >> 6) & 0x3F)))
            out.append(UInt8(0x80 | (c & 0x3F)))
    return out^


def hex_char_to_int(c: UInt8) -> Int:
    if c >= 48 and c <= 57:
        return Int(c - 48)
    if c >= 65 and c <= 70:
        return Int(c - 65 + 10)
    if c >= 97 and c <= 102:
        return Int(c - 97 + 10)
    return 0


def _is_hex_digit(c: UInt8) -> Bool:
    return (c >= 48 and c <= 57) or (c >= 65 and c <= 70) or (c >= 97 and c <= 102)


def hex_pair_to_byte(hi: UInt8, lo: UInt8) raises -> UInt8:
    """Validates two hex digits and returns the combined byte value.

    Raises naming the offending "<0x??>" token when either digit is not a
    hex digit (hex_char_to_int silently returns 0 for such input, which is
    kept for backward compatibility).
    """
    if not _is_hex_digit(hi) or not _is_hex_digit(lo):
        raise Error(
            "Invalid hex digits in byte token: <0x"
            + chr(Int(hi))
            + chr(Int(lo))
            + ">"
        )
    return UInt8((hex_char_to_int(hi) << 4) | hex_char_to_int(lo))


struct RuneStreamDecoder:
    """Stateful streaming byte/UTF-8 decoder handling byte-fallback tokens and UTF-8 sequence completion."""

    var pending_bytes: List[UInt8]

    def __init__(out self):
        self.pending_bytes = List[UInt8]()

    def _append_token_bytes(mut self, token: String) raises:
        var raw = token.as_bytes()
        if len(raw) == 6 and raw[0] == 60 and raw[1] == 48 and raw[2] == 120 and raw[5] == 62:
            var byte_val = hex_pair_to_byte(raw[3], raw[4])
            self.pending_bytes.append(byte_val)
            return

        var index = 0
        while index < len(raw):
            # Markers convert wherever they occur in the piece, not
            # only at its start: SentencePiece pieces can carry an
            # internal ▁ (e.g. ",▁captain"), which used to decode as
            # the literal marker character.
            if index + 2 < len(raw) and raw[index] == 0xE2 and raw[index + 1] == 0x96 and raw[index + 2] == 0x81:
                self.pending_bytes.append(0x20)
                index += 3
                continue
            if index + 1 < len(raw) and raw[index] == 0xC4 and raw[index + 1] == 0xA0:
                self.pending_bytes.append(0x20)
                index += 2
                continue
            if index + 1 < len(raw) and raw[index] == 0xC4 and raw[index + 1] == 0x8A:
                self.pending_bytes.append(0x0A)
                index += 2
                continue
            if index + 1 < len(raw) and raw[index] == 0xC4 and raw[index + 1] == 0x89:
                self.pending_bytes.append(0x09)
                index += 2
                continue
            self.pending_bytes.append(UInt8(raw[index]))
            index += 1

    def decode_token(mut self, token_str: String) raises -> String:
        """Decodes one token string and returns any complete UTF-8 text accumulated so far."""
        self._append_token_bytes(token_str)
        return self._pop_complete_utf8()

    def decode_id(mut self, token_id: Int, tokenizer: RuneWeaver) raises -> String:
        """Decodes one token ID using tokenizer vocabulary and returns complete UTF-8 text."""
        if tokenizer.vocab_size == 0:
            self.pending_bytes.append(UInt8(token_id & 0xFF))
            return self._pop_complete_utf8()
        if token_id < 0 or token_id >= len(tokenizer.vocab):
            return String("")
        var token_str = tokenizer.vocab[token_id]
        if tokenizer.bpe_mode and tokenizer.model_name != "gemma4" and not (
            token_str.startswith("<0x") and token_str.endswith(">")
        ):
            for b in _bpe_inverted_bytes(token_str):
                self.pending_bytes.append(b)
            return self._pop_complete_utf8()
        return self.decode_token(token_str)

    def _pop_complete_utf8(mut self) -> String:
        # INVALID-BYTE POLICY: any byte that cannot belong to a complete,
        # valid UTF-8 sequence is deterministically replaced with U+FFFD
        # (bytes EF BF BD) instead of being emitted raw. That covers lone
        # continuation bytes (0x80-0xBF), invalid lead bytes (0xF8-0xFF),
        # and lead bytes followed by a non-continuation byte. Truncated but
        # otherwise well-formed sequences at the end stay pending so split
        # multi-byte tokens can still complete on later decode_token calls.
        var text_bytes = List[Int8]()
        var index = 0
        var n = len(self.pending_bytes)

        while index < n:
            var b = Int(self.pending_bytes[index])
            var width: Int
            if b < 0x80:
                width = 1
            elif b >= 0xC0 and b <= 0xDF:
                width = 2
            elif b >= 0xE0 and b <= 0xEF:
                width = 3
            elif b >= 0xF0 and b <= 0xF7:
                width = 4
            else:
                # Lone continuation byte or invalid lead byte: U+FFFD.
                text_bytes.append(Int8(-17))  # 0xEF
                text_bytes.append(Int8(-65))  # 0xBF
                text_bytes.append(Int8(-67))  # 0xBD
                index += 1
                continue

            if index + width > n:
                break

            var valid = True
            for offset in range(1, width):
                var cb = Int(self.pending_bytes[index + offset])
                if (cb & 0xC0) != 0x80:
                    valid = False
                    break

            if not valid:
                # Lead byte not followed by valid continuations: replace the
                # lead with U+FFFD; the following byte is reprocessed on its
                # own and replaced as well if it is invalid.
                text_bytes.append(Int8(-17))  # 0xEF
                text_bytes.append(Int8(-65))  # 0xBF
                text_bytes.append(Int8(-67))  # 0xBD
                index += 1
                continue

            for offset in range(width):
                text_bytes.append(Int8(self.pending_bytes[index + offset]))
            index += width

        var remaining = List[UInt8]()
        for rem_idx in range(index, n):
            remaining.append(self.pending_bytes[rem_idx])
        self.pending_bytes = remaining.copy()

        if len(text_bytes) == 0:
            return String("")
        text_bytes.append(0)
        return String(unsafe_from_utf8_ptr=text_bytes.unsafe_ptr())

    def flush(mut self) -> String:
        """Flushes all pending bytes at end of stream as String.

        Applies the same invalid-byte policy as _pop_complete_utf8: bytes
        that cannot belong to a complete, valid UTF-8 sequence are replaced
        with U+FFFD (bytes EF BF BD). Trailing truncated sequences can never
        complete at end of stream, so each of their bytes is replaced too.
        """
        if len(self.pending_bytes) == 0:
            return String("")
        var text_bytes = List[Int8]()
        var index = 0
        var n = len(self.pending_bytes)
        while index < n:
            var b = Int(self.pending_bytes[index])
            var width = 0
            if b < 0x80:
                width = 1
            elif b >= 0xC0 and b <= 0xDF:
                width = 2
            elif b >= 0xE0 and b <= 0xEF:
                width = 3
            elif b >= 0xF0 and b <= 0xF7:
                width = 4
            var valid = width > 0 and index + width <= n
            if valid:
                for offset in range(1, width):
                    var cb = Int(self.pending_bytes[index + offset])
                    if (cb & 0xC0) != 0x80:
                        valid = False
                        break
            if valid:
                for offset in range(width):
                    text_bytes.append(Int8(self.pending_bytes[index + offset]))
                index += width
            else:
                text_bytes.append(Int8(-17))  # 0xEF
                text_bytes.append(Int8(-65))  # 0xBF
                text_bytes.append(Int8(-67))  # 0xBD
                index += 1
        text_bytes.append(0)
        self.pending_bytes.clear()
        return String(unsafe_from_utf8_ptr=text_bytes.unsafe_ptr())
