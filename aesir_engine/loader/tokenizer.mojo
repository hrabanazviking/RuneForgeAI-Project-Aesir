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
        """Applies Llama's SentencePiece space marker and returns UTF-8 symbols."""
        var uses_space_marker = "▁" in self.token_to_id
        var normalized = String("")
        if uses_space_marker:
            normalized += String("▁")
        var prompt_bytes = prompt.as_bytes()
        var byte_index = 0
        while byte_index < len(prompt_bytes):
            if uses_space_marker and prompt_bytes[byte_index] == 0x20:
                normalized += String("▁")
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
        """Encodes text with model scores, UTF-8 safety, and byte fallback."""
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

        var pieces = self._initial_pieces(prompt)
        pieces = self._merge_sentencepiece(pieces)
        for piece_index in range(len(pieces)):
            self._append_piece_tokens(String(pieces[piece_index]), tokens)
        return tokens^

    def decode(self, token: Int) -> String:
        """Decodes one token and reverses the visible SentencePiece space marker."""
        if token < 0 or token >= len(self.vocab):
            return String("")
        var value = String(self.vocab[token])
        if value.startswith("▁"):
            return String(" ") + String(value[byte=3 : len(value.as_bytes())])
        if value.startswith("<0x") and value.endswith(">"):
            return String("")
        return value
