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
    test_stream_decoder()
    test_multilingual_corpora()
