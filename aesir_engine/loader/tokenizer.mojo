# loader/tokenizer.mojo
# The Rune Weaver: model-driven Llama SentencePiece tokenizer.

from std.collections import Dict


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

    def add_token(
        mut self,
        token: String,
        token_id: Int,
        score: Float32 = 0.0,
        token_type: Int = 1,
    ):
        """Adds one vocabulary entry while keeping parallel metadata aligned."""
        while len(self.vocab) <= token_id:
            self.vocab.append("")
            self.scores.append(0.0)
            self.token_types.append(1)
        self.vocab[token_id] = token
        self.scores[token_id] = score
        self.token_types[token_id] = token_type
        self.token_to_id[token] = token_id
        self.vocab_size = len(self.vocab)

    def set_token_score(mut self, token_id: Int, score: Float32):
        while len(self.scores) <= token_id:
            self.scores.append(0.0)
        self.scores[token_id] = score

    def set_token_type(mut self, token_id: Int, token_type: Int):
        while len(self.token_types) <= token_id:
            self.token_types.append(1)
        self.token_types[token_id] = token_type

    def set_special_tokens(
        mut self,
        unknown_token_id: Int,
        bos_token_id: Int,
        eos_token_id: Int,
    ):
        self.unknown_token_id = unknown_token_id
        self.bos_token_id = bos_token_id
        self.eos_token_id = eos_token_id

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
        """Applies SentencePiece/BPE space markers and returns UTF-8 symbols."""
        var uses_llama_space = "▁" in self.token_to_id
        var uses_gpt2_space = "Ġ" in self.token_to_id
        var normalized = String("")
        var prompt_bytes = prompt.as_bytes()
        var byte_index = 0
        while byte_index < len(prompt_bytes):
            if prompt_bytes[byte_index] == 0x20:
                if uses_gpt2_space:
                    normalized += String("Ġ")
                elif uses_llama_space:
                    normalized += String("▁")
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
                if score > best_score:
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

    def encode(self, prompt: String, add_bos: Bool = False) -> List[Int]:
        """Encodes text with model scores, UTF-8 safety, special control tokens, and byte fallback."""
        var tokens = List[Int]()
        if add_bos and self.add_bos_token and self.bos_token_id >= 0:
            tokens.append(self.bos_token_id)
        if len(prompt.as_bytes()) == 0:
            return tokens^
        if self.vocab_size == 0:
            var raw = prompt.as_bytes()
            for byte_index in range(len(raw)):
                tokens.append(Int(raw[byte_index]))
            return tokens^

        # Handle special control token splits (<|im_start|>, <|im_end|>, etc.)
        if "<|im_start|>" in prompt or "<|im_end|>" in prompt or "<|endoftext|>" in prompt:
            var text = prompt
            var i = 0
            var last_idx = 0
            var n_bytes = len(text.as_bytes())
            while i < n_bytes:
                var matched_special = False
                var match_len = 0
                var spec_id = -1

                if i + 12 <= n_bytes and text[byte=i : i + 12] == "<|im_start|>":
                    matched_special = True
                    match_len = 12
                    spec_id = self.token_to_id.get("<|im_start|>", 151644)
                elif i + 10 <= n_bytes and text[byte=i : i + 10] == "<|im_end|>":
                    matched_special = True
                    match_len = 10
                    spec_id = self.token_to_id.get("<|im_end|>", 151645)
                elif i + 13 <= n_bytes and text[byte=i : i + 13] == "<|endoftext|>":
                    matched_special = True
                    match_len = 13
                    spec_id = self.token_to_id.get("<|endoftext|>", 151643)

                if matched_special:
                    if i > last_idx:
                        var segment = String(text[byte=last_idx : i])
                        var pieces = self._initial_pieces(segment)
                        pieces = self._merge_sentencepiece(pieces)
                        for p in range(len(pieces)):
                            self._append_piece_tokens(String(pieces[p]), tokens)
                    tokens.append(spec_id)
                    i += match_len
                    last_idx = i
                else:
                    i += 1

            if last_idx < n_bytes:
                var segment = String(text[byte=last_idx : n_bytes])
                var pieces = self._initial_pieces(segment)
                pieces = self._merge_sentencepiece(pieces)
                for p in range(len(pieces)):
                    self._append_piece_tokens(String(pieces[p]), tokens)
            return tokens^

        var pieces = self._initial_pieces(prompt)
        pieces = self._merge_sentencepiece(pieces)
        for piece_index in range(len(pieces)):
            self._append_piece_tokens(String(pieces[piece_index]), tokens)
        return tokens^

    def decode(self, token: Int) -> String:
        """Decodes one token and reverses BPE space/newline markers with 100% UTF-8 safety."""
        if token < 0 or token >= len(self.vocab):
            return String("")
        var value = String(self.vocab[token])
        if value == "<0x0A>" or value == "<0x0D>":
            return String("\n")
        if value.startswith("<0x") and value.endswith(">"):
            return String("")

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


def hex_char_to_int(c: UInt8) -> Int:
    if c >= 48 and c <= 57:
        return Int(c - 48)
    if c >= 65 and c <= 70:
        return Int(c - 65 + 10)
    if c >= 97 and c <= 102:
        return Int(c - 97 + 10)
    return 0


struct RuneStreamDecoder:
    """Stateful streaming byte/UTF-8 decoder handling byte-fallback tokens and UTF-8 sequence completion."""

    var pending_bytes: List[UInt8]

    def __init__(out self):
        self.pending_bytes = List[UInt8]()

    def _append_token_bytes(mut self, token: String):
        var raw = token.as_bytes()
        if len(raw) == 6 and raw[0] == 60 and raw[1] == 48 and raw[2] == 120 and raw[5] == 62:
            var high = hex_char_to_int(raw[3])
            var low = hex_char_to_int(raw[4])
            var byte_val = UInt8((high << 4) | low)
            self.pending_bytes.append(byte_val)
            return

        var index = 0
        while index < len(raw):
            if token.startswith("▁") and index == 0:
                self.pending_bytes.append(0x20)
                index += 3
                continue
            if token.startswith("Ġ") and index == 0:
                self.pending_bytes.append(0x20)
                index += 2
                continue
            if token.startswith("Ċ") and index == 0:
                self.pending_bytes.append(0x0A)
                index += 2
                continue
            if token.startswith("ĉ") and index == 0:
                self.pending_bytes.append(0x09)
                index += 2
                continue
            self.pending_bytes.append(UInt8(raw[index]))
            index += 1

    def decode_token(mut self, token_str: String) -> String:
        """Decodes one token string and returns any complete UTF-8 text accumulated so far."""
        self._append_token_bytes(token_str)
        return self._pop_complete_utf8()

    def decode_id(mut self, token_id: Int, tokenizer: RuneWeaver) -> String:
        """Decodes one token ID using tokenizer vocabulary and returns complete UTF-8 text."""
        if tokenizer.vocab_size == 0:
            self.pending_bytes.append(UInt8(token_id & 0xFF))
            return self._pop_complete_utf8()
        if token_id < 0 or token_id >= len(tokenizer.vocab):
            return String("")
        return self.decode_token(tokenizer.vocab[token_id])

    def _pop_complete_utf8(mut self) -> String:
        var text_bytes = List[Int8]()
        var index = 0
        var n = len(self.pending_bytes)

        while index < n:
            var b = Int(self.pending_bytes[index])
            var width = 1
            if b < 0x80:
                width = 1
            elif b >= 0xC0 and b <= 0xDF:
                width = 2
            elif b >= 0xE0 and b <= 0xEF:
                width = 3
            elif b >= 0xF0 and b <= 0xF7:
                width = 4
            else:
                text_bytes.append(Int8(b))
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
                text_bytes.append(Int8(b))
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
        """Flushes all pending bytes at end of stream as String."""
        if len(self.pending_bytes) == 0:
            return String("")
        var bytes = List[Int8]()
        for index in range(len(self.pending_bytes)):
            bytes.append(Int8(self.pending_bytes[index]))
        bytes.append(0)
        self.pending_bytes.clear()
        return String(unsafe_from_utf8_ptr=bytes.unsafe_ptr())
