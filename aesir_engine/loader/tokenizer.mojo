# loader/tokenizer.mojo
# The Rune Weaver: Pure Mojo BPE Tokenizer
# 
# Translates the intent of Midgard (text) into the sacred runes (tokens)
# understood by the Aesir Engine.

from std.collections import Dict

struct RuneWeaver:
    """RuneWeaver: Pure Mojo BPE Tokenizer. No bloated Python runtime."""
    var vocab: List[String]
    var token_to_id: Dict[String, Int]
    var vocab_size: Int

    def __init__(out self):
        self.vocab = List[String]()
        self.token_to_id = Dict[String, Int]()
        self.vocab_size = 0

    def add_token(mut self, token: String, id: Int):
        """Adds a token rune to the sacred vocabulary list and lookup map."""
        while len(self.vocab) <= id:
            self.vocab.append("")
        self.vocab[id] = token
        self.token_to_id[token] = id
        self.vocab_size = len(self.vocab)

    def byte_to_hex_token(self, b: UInt8) -> String:
        """Formats a single byte into the sacred byte rune format <0xXX>."""
        var hex_digits = String("0123456789ABCDEF")
        var h1 = String(hex_digits[byte=Int(b >> 4):Int((b >> 4) + 1)])
        var h2 = String(hex_digits[byte=Int(b & 0xF):Int((b & 0xF) + 1)])
        return String("<0x") + h1 + h2 + String(">")

    def encode(self, prompt: String) -> List[Int]:
        """Weaves a Midgard text prompt into sacred rune token IDs via BPE merging."""
        print("Weaving prompt into runes...")
        var pieces = List[String]()
        var prompt_bytes = prompt.as_bytes()
        var n_bytes = len(prompt_bytes)

        if n_bytes == 0:
            return List[Int]()

        # Initial byte/char tokenization into pieces
        for i in range(n_bytes):
            var piece = String(prompt[byte=i:i+1])
            if piece in self.token_to_id:
                pieces.append(piece)
            else:
                var hex_piece = self.byte_to_hex_token(prompt_bytes[i])
                if hex_piece in self.token_to_id:
                    pieces.append(hex_piece)
                else:
                    pieces.append(piece)

        # BPE merge loop: iteratively find and merge highest priority (lowest token ID) adjacent pairs
        while len(pieces) > 1:
            var best_pair_idx = -1
            var min_token_id = 1 << 30 # Infinity sentinel for min search

            for i in range(len(pieces) - 1):
                var p1 = String(pieces[i])
                var p2 = String(pieces[i+1])
                var merged = p1 + p2
                if merged in self.token_to_id:
                    var tid = self.token_to_id.get(merged, -1)
                    if tid >= 0 and tid < min_token_id:
                        min_token_id = tid
                        best_pair_idx = i

            if best_pair_idx == -1:
                break # No valid merges remaining in vocabulary

            # Perform merge at best_pair_idx
            var p1 = String(pieces[best_pair_idx])
            var p2 = String(pieces[best_pair_idx + 1])
            var merged_str = p1 + p2
            var new_pieces = List[String]()
            for i in range(len(pieces)):
                if i == best_pair_idx:
                    new_pieces.append(merged_str)
                elif i == best_pair_idx + 1:
                    continue # Merged into previous token
                else:
                    new_pieces.append(String(pieces[i]))
            pieces = new_pieces^

        # Convert merged token pieces into final token IDs
        var tokens = List[Int]()
        for i in range(len(pieces)):
            var piece = String(pieces[i])
            if piece in self.token_to_id:
                var tid = self.token_to_id.get(piece, -1)
                if tid >= 0:
                    tokens.append(tid)
                else:
                    var p_bytes = piece.as_bytes()
                    if len(p_bytes) == 1:
                        tokens.append(Int(p_bytes[0]))
                    else:
                        tokens.append(0)
            else:
                var p_bytes = piece.as_bytes()
                if len(p_bytes) == 1:
                    tokens.append(Int(p_bytes[0]))
                else:
                    tokens.append(0)
        return tokens^

    def decode(self, token: Int) -> String:
        """Translates a sacred rune token ID back into Midgard text."""
        if token >= 0 and token < len(self.vocab):
            var s = String(self.vocab[token])
            if len(s.as_bytes()) > 0:
                return s
        if token >= 0 and token < 256:
            var b = List[Int8]()
            b.append(Int8(token))
            b.append(0)
            return String(b.unsafe_ptr(), 1)
        return String("rune_") + String(token)
