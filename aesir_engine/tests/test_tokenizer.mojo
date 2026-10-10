from loader.tokenizer import RuneWeaver, RuneStreamDecoder

def test_tokenizer() raises:
    print("--- Testing RuneWeaver ---")
    var weaver = RuneWeaver()
    
    # 1. Fallback encoding without vocabulary
    var prompt = String("hello world")
    var tokens = weaver.encode(prompt)
    print("Fallback tokens count:", len(tokens))
    if len(tokens) != 11:
        raise Error("Fallback tokens count mismatch")
    
    # 2. Add tokens and test BPE merges
    weaver.add_token("h", 100)
    weaver.add_token("e", 101)
    weaver.add_token("l", 102)
    weaver.add_token("o", 103)
    weaver.add_token(" ", 104)
    weaver.add_token("w", 105)
    weaver.add_token("r", 106)
    weaver.add_token("d", 107)
    weaver.add_token("ll", 200)
    weaver.add_token("he", 201)
    weaver.add_token("ld", 202)
    weaver.add_token("wo", 203)
    weaver.add_token("hell", 204)
    weaver.add_token("rld", 205)
    weaver.add_token("hello", 300)
    weaver.add_token("world", 301)
    
    if weaver.vocab_size != 302:
        raise Error("Vocab size mismatch")
    
    var bpe_tokens = weaver.encode(prompt)
    print("BPE merged tokens count:", len(bpe_tokens))
    if len(bpe_tokens) != 3:
        raise Error("BPE merged tokens count mismatch")
    if bpe_tokens[0] != 300 or bpe_tokens[1] != 104 or bpe_tokens[2] != 301:
        raise Error("BPE merged token IDs mismatch")
    
    # 3. Decode verification
    var decoded = weaver.decode(300)
    if decoded != "hello":
        raise Error("Decoded token mismatch")

    # 4. Vocabulary validation test
    weaver.validate_vocabulary()
    print("RuneWeaver vocabulary validation: PASS")
    print("RuneWeaver: PASS")

def test_stream_decoder() raises:
    print("--- Testing RuneStreamDecoder Stateful UTF-8 Split Decoding ---")
    var decoder = RuneStreamDecoder()
    
    # Simulates 4-byte emoji (😀: 0xF0 0x9F 0x98 0x80) split across two byte fallback tokens
    var chunk1 = decoder.decode_token("<0xF0>")
    if chunk1 != "":
        raise Error("Incomplete UTF-8 byte 1 must emit empty string")
    var chunk2 = decoder.decode_token("<0x9F>")
    if chunk2 != "":
        raise Error("Incomplete UTF-8 byte 2 must emit empty string")
    var chunk3 = decoder.decode_token("<0x98>")
    if chunk3 != "":
        raise Error("Incomplete UTF-8 byte 3 must emit empty string")
    var chunk4 = decoder.decode_token("<0x80>")
    if chunk4 != "😀":
        raise Error("Completed 4-byte UTF-8 emoji token must emit 😀")

    # SentencePiece space marker token
    var chunk_sp = decoder.decode_token("▁hello")
    if chunk_sp != " hello":
        raise Error("SentencePiece space marker ▁ must decode to leading space")

    print("RuneStreamDecoder: PASS")

def test_multilingual_corpora() raises:
    print("--- Testing Multilingual Differential Corpora & Round-Trip Fidelity ---")
    var weaver = RuneWeaver()
    var test_corpora = List[String]()
    test_corpora.append("hello world")
    test_corpora.append("Hello World") # English
    test_corpora.append("こんにちは") # Japanese
    test_corpora.append("안녕하세요") # Korean
    test_corpora.append("Привет мир") # Cyrillic
    test_corpora.append("مرحبا بالعالم") # Arabic
    test_corpora.append("नमस्ते") # Devanagari
    test_corpora.append("😀🎉🚀") # Emoji
    test_corpora.append("café & naïve") # Accented Latin
    test_corpora.append("multiple   spaces") # Whitespace

    for i in range(len(test_corpora)):
        var prompt = String(test_corpora[i])
        var tokens = weaver.encode(prompt, False)
        var decoder = RuneStreamDecoder()
        var reconstructed = String("")
        for tok_idx in range(len(tokens)):
            reconstructed += decoder.decode_id(tokens[tok_idx], weaver)
        reconstructed += decoder.flush()

        var expected = prompt
        if reconstructed != expected:
            raise Error("Round-trip text mismatch for prompt index " + String(i) + ": got '" + reconstructed + "', expected '" + expected + "'")

    print("Multilingual differential corpora round-trip: PASS")

def main() raises:
    test_tokenizer()
    test_byte_bpe_merge_baseline()
    test_stream_decoder()
    test_multilingual_corpora()

def test_byte_bpe_merge_baseline() raises:
    var tie = RuneWeaver()
    tie.add_token("a", 1)
    tie.add_token("b", 2)
    tie.add_token("c", 3)
    tie.add_token("ab", 4, 1.0)
    tie.add_token("bc", 5, 1.0)
    var tied = tie.encode("abc")
    if len(tied) != 2 or tied[0] != 4 or tied[1] != 3:
        raise Error("equal-score BPE tie no longer selects leftmost pair")

    var ranked = RuneWeaver()
    ranked.add_token("a", 1)
    ranked.add_token("b", 2)
    ranked.add_token("c", 3)
    ranked.add_token("ab", 4, 1.0)
    ranked.add_token("bc", 5, 5.0)
    var right_first = ranked.encode("abc")
    if len(right_first) != 2 or right_first[0] != 1 or right_first[1] != 5:
        raise Error("higher-score right pair did not win merge selection")

    var chained = RuneWeaver()
    chained.add_token("a", 1)
    chained.add_token("b", 2)
    chained.add_token("c", 3)
    chained.add_token("ab", 4, 1.0)
    chained.add_token("bc", 5, 0.0)
    chained.add_token("abc", 6, 2.0)
    var chain = chained.encode("abc")
    if len(chain) != 1 or chain[0] != 6:
        raise Error("BPE did not repeat score-ranked merges to convergence")

    var fallback = RuneWeaver()
    fallback.add_token("<0xF0>", 11)
    fallback.add_token("<0x9F>", 12)
    fallback.add_token("<0x98>", 13)
    fallback.add_token("<0x80>", 14)
    var emoji = fallback.encode("😀")
    if len(emoji) != 4 or emoji[0] != 11 or emoji[1] != 12 or emoji[2] != 13 or emoji[3] != 14:
        raise Error("UTF-8 byte fallback vector changed")
    print("PASS: byte BPE tie, score order, chaining and UTF-8 fallback baseline")

def test_byte_bpe_merge_interface() raises:
    var weaver = RuneWeaver()
    weaver.add_token("x", 1)
    weaver.add_token("y", 2)
    weaver.add_token("xy", 3, 0.75)
    var merged = weaver.encode("xy", False)
    if len(merged) != 1 or merged[0] != 3:
        raise Error("public add_token/encode merge interface changed")
    var empty = weaver.encode("", False)
    if len(empty) != 0:
        raise Error("empty tokenizer input must emit no token without BOS")
    print("PASS: byte BPE public vocabulary-to-encode interface")

def test_byte_bpe_merge_adversarial() raises:
    var tie = RuneWeaver()
    tie.add_token("a", 1)
    tie.add_token("b", 2)
    tie.add_token("c", 3)
    tie.add_token("ab", 4, 1.0)
    tie.add_token("bc", 5, 1.0)
    var first = tie.encode("abc", False)
    var second = tie.encode("abc", False)
    if len(first) != len(second) or len(first) != 2:
        raise Error("repeated tie vector changed result length")
    if first[0] != 4 or first[1] != 3 or second[0] != first[0] or second[1] != first[1]:
        raise Error("repeated tie vector is not deterministic")

    var partial_fallback = RuneWeaver()
    partial_fallback.unknown_token_id = 99
    partial_fallback.add_token("<0xF0>", 11)
    var emoji = partial_fallback.encode("😀", False)
    if len(emoji) != 4 or emoji[0] != 11 or emoji[1] != 99 or emoji[2] != 99 or emoji[3] != 99:
        raise Error("partial UTF-8 byte fallback did not use unknown ID for missing bytes")
    print("PASS: byte BPE repeatability and partial byte fallback boundaries")

def test_byte_bpe_merge_integration() raises:
    var weaver = RuneWeaver()
    weaver.add_token("<0xF0>", 11)
    weaver.add_token("<0x9F>", 12)
    weaver.add_token("<0x98>", 13)
    weaver.add_token("<0x80>", 14)
    var encoded = weaver.encode("😀", False)
    var decoder = RuneStreamDecoder()
    var decoded = String("")
    for index in range(len(encoded)):
        decoded += decoder.decode_token(weaver.vocab[encoded[index]])
    if decoded != "😀":
        raise Error("encoded byte-fallback vector did not stream-decode to original UTF-8")
    print("PASS: RuneWeaver byte fallback integrates with streaming UTF-8 decoder")

def test_byte_bpe_merge_negative_scores() raises:
    var weaver = RuneWeaver()
    weaver.add_token("a", 1)
    weaver.add_token("b", 2)
    weaver.add_token("c", 3)
    weaver.add_token("ab", 4, -3.0)
    weaver.add_token("bc", 5, -1.0)
    var ranked = weaver.encode("abc", False)
    if len(ranked) != 2 or ranked[0] != 1 or ranked[1] != 5:
        raise Error("negative BPE scores did not select the numerically highest pair")

    var tied = RuneWeaver()
    tied.add_token("a", 1)
    tied.add_token("b", 2)
    tied.add_token("c", 3)
    tied.add_token("ab", 4, -2.0)
    tied.add_token("bc", 5, -2.0)
    var tie = tied.encode("abc", False)
    if len(tie) != 2 or tie[0] != 4 or tie[1] != 3:
        raise Error("equal negative BPE scores did not preserve leftmost tie")
    print("PASS: BPE negative-score ranking and tie boundary")

def test_unicode_normalization_baseline() raises:
    var weaver = RuneWeaver()
    weaver.add_token("<0xC3>", 11)
    weaver.add_token("<0xA9>", 12)
    weaver.add_token("<0x65>", 13)
    weaver.add_token("<0xCC>", 14)
    weaver.add_token("<0x81>", 15)
    var composed = weaver.encode("é", False)
    var decomposed = weaver.encode("é", False)
    if len(composed) != 2 or composed[0] != 11 or composed[1] != 12:
        raise Error("composed Unicode byte vector changed")
    if len(decomposed) != 3 or decomposed[0] != 13 or decomposed[1] != 14 or decomposed[2] != 15:
        raise Error("decomposed Unicode byte vector changed")
    if len(composed) == len(decomposed):
        raise Error("Unicode canonical forms were unexpectedly normalized together")
    print("PASS: RuneWeaver preserves composed and decomposed Unicode byte vectors")

def test_unicode_normalization_interface() raises:
    var sentencepiece = RuneWeaver()
    sentencepiece.add_token("▁", 1)
    sentencepiece.add_token("a", 2)
    var marked = sentencepiece.encode(" a", False)
    if len(marked) != 2 or marked[0] != 1 or marked[1] != 2:
        raise Error("vocabulary-driven SentencePiece space marker interface changed")

    var literal = RuneWeaver()
    literal.add_token(" ", 1)
    literal.add_token("a", 2)
    var unchanged = literal.encode(" a", False)
    if len(unchanged) != 2 or unchanged[0] != 1 or unchanged[1] != 2:
        raise Error("literal ASCII space was not preserved without marker vocabulary")
    print("PASS: Unicode-preserving public encode and vocabulary-driven space interface")

def test_unicode_normalization_integration() raises:
    var weaver = RuneWeaver()
    weaver.add_token("<0xC3>", 11)
    weaver.add_token("<0xA9>", 12)
    weaver.add_token("<0x65>", 13)
    weaver.add_token("<0xCC>", 14)
    weaver.add_token("<0x81>", 15)

    var composed_ids = weaver.encode("é", False)
    var composed_decoder = RuneStreamDecoder()
    var composed_output = String("")
    for index in range(len(composed_ids)):
        composed_output += composed_decoder.decode_token(weaver.vocab[composed_ids[index]])
    if composed_output != "é":
        raise Error("composed Unicode form changed through token stream round trip")

    var decomposed_ids = weaver.encode("é", False)
    var decomposed_decoder = RuneStreamDecoder()
    var decomposed_output = String("")
    for index in range(len(decomposed_ids)):
        decomposed_output += decomposed_decoder.decode_token(weaver.vocab[decomposed_ids[index]])
    if decomposed_output != "é":
        raise Error("decomposed Unicode form changed through token stream round trip")
    print("PASS: composed and decomposed Unicode round trips remain distinct")

def test_unicode_normalization_adversarial() raises:
    var weaver = RuneWeaver()
    weaver.add_token("▁", 1)
    weaver.add_token("<0xC2>", 2)
    weaver.add_token("<0xA0>", 3)
    weaver.add_token("a", 4)
    var tokens = weaver.encode(" a", False)
    if len(tokens) != 3 or tokens[0] != 2 or tokens[1] != 3 or tokens[2] != 4:
        raise Error("non-breaking space was incorrectly rewritten as ASCII space marker")
    print("PASS: non-breaking space stays distinct from ASCII space marker")
