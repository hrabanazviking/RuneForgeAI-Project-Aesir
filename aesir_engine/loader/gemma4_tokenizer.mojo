"""Native Gemma 4 merge-rank BPE; plain text never invents control tokens."""
from std.collections import Dict
from loader.packed_gguf import PackedGGUF
from loader.tokenizer import RuneWeaver


struct Gemma4Tokenizer:
    var vocabulary: RuneWeaver
    var ranks: Dict[String, Int]

    def __init__(out self, model: PackedGGUF) raises:
        self.vocabulary = RuneWeaver()
        self.ranks = Dict[String, Int]()
        if model.text("tokenizer.ggml.model") != "gemma4":
            raise Error("Gemma 4 requires its own BPE tokenizer")
        var offset = model.array_offset("tokenizer.ggml.tokens", 8)
        var count = Int(model.source._read_u64(offset + 4))
        if count != 262144:
            raise Error("Gemma 4 E4B vocabulary size mismatch")
        var cursor = offset + 12
        for token in range(count):
            var word = model.source._read_string(cursor)
            cursor = model.source._string_end(cursor)
            self.vocabulary.add_token(word, token)
        offset = model.array_offset("tokenizer.ggml.merges", 8)
        count = Int(model.source._read_u64(offset + 4))
        if count <= 0 or count > 2000000:
            raise Error("Gemma 4 invalid BPE merge count")
        cursor = offset + 12
        for rank in range(count):
            var pair = model.source._read_string(cursor)
            cursor = model.source._string_end(cursor)
            if pair not in self.ranks:
                self.ranks[pair] = rank
        self.vocabulary.set_special_tokens(
            model.integer("tokenizer.ggml.unknown_token_id"),
            model.integer("tokenizer.ggml.bos_token_id"),
            model.integer("tokenizer.ggml.eos_token_id"),
        )
        self.vocabulary.validate_vocabulary()

    def control(self, spelling: String) raises -> Int:
        if spelling not in self.vocabulary.token_to_id:
            raise Error("Gemma 4 missing control token " + spelling)
        return self.vocabulary.token_to_id[spelling]

    def _segment(self, text: String, mut output: List[Int]):
        # Upstream Gemma 4 uses raw UTF-8, escaped spaces and newline boundaries,
        # without GPT-2 byte encoding or word-level regular-expression splits.
        var normalized = text.replace(" ", "▁")
        if text.startswith("\n") and normalized in self.vocabulary.token_to_id:
            output.append(self.vocabulary.token_to_id.get(normalized, 3))
            return
        var pieces = List[String]()
        self.vocabulary._append_utf8_symbols(normalized, pieces)
        while len(pieces) > 1:
            var best = -1
            var best_rank = 2147483647
            for index in range(len(pieces) - 1):
                var pair = pieces[index] + " " + pieces[index + 1]
                var rank = self.ranks.get(pair, 2147483647)
                if rank < best_rank:
                    best = index
                    best_rank = rank
            if best < 0:
                break
            var merged = String(pieces[best]) + String(pieces[best + 1])
            pieces[best] = merged
            _ = pieces.pop(best + 1)
        for piece in pieces:
            self.vocabulary._append_piece_tokens(piece, output)

    def encode(self, text: String, add_bos: Bool = False) -> List[Int]:
        var result = List[Int]()
        if add_bos:
            result.append(self.vocabulary.bos_token_id)
        var raw = text.as_bytes()
        var start = 0
        for i in range(1, len(raw)):
            if (raw[i] == 10) != (raw[i - 1] == 10):
                self._segment(String(text[byte=start:i]), result)
                start = i
        if start < len(raw):
            self._segment(String(text[byte=start:len(raw)]), result)
        return result^

    def append_text(self, mut tokens: List[Int], text: String):
        var encoded = self.encode(text)
        for token in encoded:
            tokens.append(token)

    def append_message(self, mut tokens: List[Int], role: String, text: String) raises:
        if role != "system" and role != "user" and role != "model":
            raise Error("Unsupported Gemma 4 text message role")
        tokens.append(self.control("<|turn>"))
        self.append_text(tokens, role + "\n" + text)
        tokens.append(self.control("<turn|>"))
        self.append_text(tokens, "\n")

    def append_generation_prompt(self, mut tokens: List[Int]) raises:
        tokens.append(self.control("<|turn>"))
        self.append_text(tokens, "model\n")
