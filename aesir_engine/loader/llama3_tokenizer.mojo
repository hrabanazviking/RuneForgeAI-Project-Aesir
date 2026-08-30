"""Native Llama 3 byte-level BPE with Unicode-aware pre-tokenization.

Model vocabulary and merge ranks come from GGUF; plain text cannot introduce
special tokens. Control framing is an explicit, separately validated operation.
"""
from std.collections import Dict
from std.collections.string import chr, ord
from loader.packed_gguf import PackedGGUF
from loader.tokenizer import RuneWeaver, RuneStreamDecoder
from loader.unicode_categories import llama_character_class


def llama3_segments(text: String) -> List[String]:
    """Implement the ordered Llama 3 regex alternatives over Unicode symbols."""
    var helper = RuneWeaver()
    var chars = List[String]()
    helper._append_utf8_symbols(text, chars)
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
            while end < min(i + 3, len(chars)) and classes[end] == 2:
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


struct Llama3Tokenizer:
    var vocabulary: RuneWeaver
    var ranks: Dict[String, Int]
    var byte_symbols: List[String]
    var symbol_bytes: Dict[String, Int]

    def __init__(out self, model: PackedGGUF) raises:
        self.vocabulary = RuneWeaver()
        self.ranks = Dict[String, Int]()
        self.byte_symbols = List[String]()
        self.symbol_bytes = Dict[String, Int]()
        if model.text("tokenizer.ggml.model") != "gpt2" or model.text("tokenizer.ggml.pre") != "llama-bpe":
            raise Error("Native Llama 3 requires the llama-bpe GPT-2 tokenizer")
        var extra = 0
        for byte in range(256):
            var code = byte
            if not (33 <= byte <= 126 or 161 <= byte <= 172 or 174 <= byte <= 255):
                code = 256 + extra
                extra += 1
            var symbol = chr(code)
            self.byte_symbols.append(symbol)
            self.symbol_bytes[symbol] = byte
        var offset = model.array_offset("tokenizer.ggml.tokens", 8)
        var count = Int(model.source._read_u64(offset + 4))
        if count != 128256:
            raise Error("Llama 3 vocabulary size mismatch")
        var cursor = offset + 12
        for token in range(count):
            var word = model.source._read_string(cursor)
            cursor = model.source._string_end(cursor)
            self.vocabulary.add_token(word, token)
        offset = model.array_offset("tokenizer.ggml.merges", 8)
        count = Int(model.source._read_u64(offset + 4))
        if count < 1 or count > 2000000:
            raise Error("Llama 3 invalid merge count")
        cursor = offset + 12
        for rank in range(count):
            var pair = model.source._read_string(cursor)
            cursor = model.source._string_end(cursor)
            if pair not in self.ranks:
                self.ranks[pair] = rank
        self.vocabulary.set_special_tokens(0, model.integer("tokenizer.ggml.bos_token_id"), model.integer("tokenizer.ggml.eos_token_id"))
        self.vocabulary.validate_vocabulary()
        if self.control("<|begin_of_text|>") != 128000 or self.control("<|start_header_id|>") != 128006 or self.control("<|end_header_id|>") != 128007 or self.control("<|eot_id|>") != 128009 or self.control("<|end_of_text|>") != 128001:
            raise Error("Llama 3 control-token layout mismatch")
        if self.vocabulary.bos_token_id != 128000 or self.vocabulary.eos_token_id not in (128001, 128009):
            raise Error("Llama 3 BOS/EOS metadata mismatch")

    def control(self, spelling: String) raises -> Int:
        if spelling not in self.vocabulary.token_to_id:
            raise Error("Llama 3 missing control token " + spelling)
        return self.vocabulary.token_to_id[spelling]

    def encode(self, text: String, add_bos: Bool = False) raises -> List[Int]:
        var output = List[Int]()
        if add_bos:
            output.append(self.vocabulary.bos_token_id)
        var segments = llama3_segments(text)
        for segment in segments:
            var pieces = List[String]()
            var whole = String("")
            for byte in segment.as_bytes():
                pieces.append(self.byte_symbols[Int(byte)])
                whole += self.byte_symbols[Int(byte)]
            # Llama 3's ignore_merges profile admits a vocabulary segment
            # directly before considering ranked pair merges.
            if whole in self.vocabulary.token_to_id:
                output.append(self.vocabulary.token_to_id[whole])
                continue
            while len(pieces) > 1:
                var best = -1
                var best_rank = 2147483647
                for i in range(len(pieces) - 1):
                    var rank = self.ranks.get(pieces[i] + " " + pieces[i + 1], 2147483647)
                    if rank < best_rank:
                        best_rank = rank
                        best = i
                if best < 0:
                    break
                var combined = String(pieces[best]) + String(pieces[best + 1])
                pieces[best] = combined
                _ = pieces.pop(best + 1)
            for piece in pieces:
                if piece not in self.vocabulary.token_to_id:
                    raise Error("Llama BPE produced an unknown byte sequence")
                output.append(self.vocabulary.token_to_id[piece])
        return output^

    def append_text(self, mut tokens: List[Int], text: String) raises:
        var encoded = self.encode(text)
        for token in encoded:
            tokens.append(token)

    def append_header(self, mut tokens: List[Int], role: String) raises:
        if role != "system" and role != "user" and role != "assistant":
            raise Error("Invalid Llama 3 role")
        tokens.append(self.control("<|start_header_id|>"))
        self.append_text(tokens, role)
        tokens.append(self.control("<|end_header_id|>"))
        self.append_text(tokens, "\n\n")

    def append_message(self, mut tokens: List[Int], role: String, text: String) raises:
        self.append_header(tokens, role)
        self.append_text(tokens, String(text.strip()))
        tokens.append(self.control("<|eot_id|>"))

    def decode(self, token: Int, mut decoder: RuneStreamDecoder) raises -> String:
        if token < 0 or token >= 128000:
            raise Error("Unexpected Llama 3 non-text output token")
        var symbols = List[String]()
        self.vocabulary._append_utf8_symbols(self.vocabulary.vocab[token], symbols)
        var text = String("")
        for symbol in symbols:
            if symbol not in self.symbol_bytes:
                raise Error("Llama 3 invalid byte-encoded output")
            text += decoder.decode_token(self.vocabulary.byte_to_hex_token(UInt8(self.symbol_bytes[symbol])))
        return text
