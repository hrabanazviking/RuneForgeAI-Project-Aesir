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

def test_validate_vocabulary_duplicate_spelling() raises:
    print("--- Testing validate_vocabulary duplicate spelling detection (R001) ---")
    var weaver = RuneWeaver()
    weaver.add_token("alpha", 10)
    weaver.add_token("beta", 11)
    weaver.add_token("alpha", 12)
    var raised = False
    try:
        weaver.validate_vocabulary()
    except error:
        raised = True
        if "12" not in String(error) and "10" not in String(error):
            raise Error("duplicate-spelling error must name the offending id: " + String(error))
    if not raised:
        raise Error("validate_vocabulary must raise when one spelling covers two ids")
    print("validate_vocabulary duplicate spelling: PASS")

def test_validate_vocabulary_missing_coverage() raises:
    print("--- Testing validate_vocabulary missing token_to_id coverage (R001) ---")
    var weaver = RuneWeaver()
    weaver.add_token("alpha", 10)
    weaver.add_token("beta", 11)
    # Direct struct manipulation: vocab spelling present, token_to_id entry gone.
    weaver.vocab[11] = "gamma"
    var raised = False
    try:
        weaver.validate_vocabulary()
    except error:
        raised = True
        if "11" not in String(error):
            raise Error("missing-coverage error must name the offending id: " + String(error))
    if not raised:
        raise Error("validate_vocabulary must raise when a non-empty vocab spelling is missing from token_to_id")
    print("validate_vocabulary missing coverage: PASS")

def test_validate_vocabulary_empty_special_spelling() raises:
    print("--- Testing validate_vocabulary empty special spelling (R001) ---")
    var weaver = RuneWeaver()
    weaver.add_token("<unk>", 0)
    weaver.add_token("<s>", 1)
    # eos id 2 is intentionally left as a "" gap-fill placeholder.
    weaver.set_special_tokens(0, 1, 2)
    var raised = False
    try:
        weaver.validate_vocabulary()
    except error:
        raised = True
        if "eos_token_id" not in String(error):
            raise Error("empty-special error must name the special: " + String(error))
    if not raised:
        raise Error("validate_vocabulary must raise when a special token id has an empty spelling")
    # Control case: fully configured specials validate cleanly.
    var good = RuneWeaver()
    good.add_token("<unk>", 0)
    good.add_token("<s>", 1)
    good.add_token("</s>", 2)
    good.set_special_tokens(0, 1, 2)
    good.validate_vocabulary()
    print("validate_vocabulary empty special spelling: PASS")

def test_add_token_negative_id() raises:
    print("--- Testing add_token negative id rejection (R002) ---")
    var weaver = RuneWeaver()
    var raised = False
    try:
        weaver.add_token("x", -1)
    except error:
        raised = True
        if "non-negative" not in String(error):
            raise Error("negative-id error must say the id must be non-negative: " + String(error))
    if not raised:
        raise Error("add_token must raise for a negative token id")
    print("add_token negative id: PASS")

def test_encode_special_token_resolution() raises:
    print("--- Testing encode special-token id resolution (R003) ---")
    var weaver = RuneWeaver()
    weaver.add_token("a", 0)
    weaver.add_token("b", 1)
    # "<|im_start|>" is not registered: encode must raise naming the spelling.
    var raised = False
    try:
        _ = weaver.encode("<|im_start|>ab")
    except error:
        raised = True
        if "<|im_start|>" not in String(error):
            raise Error("encode error must name the missing special spelling: " + String(error))
    if not raised:
        raise Error("encode must raise when a special spelling is absent from the vocabulary")
    # Register it: the prompt must now encode the spelling to its vocab id.
    weaver.add_token("<|im_start|>", 2)
    var tokens = weaver.encode("<|im_start|>ab")
    if len(tokens) != 3:
        raise Error("special-token prompt must encode to 3 tokens")
    if tokens[0] != 2 or tokens[1] != 0 or tokens[2] != 1:
        raise Error("registered special spelling must encode to its vocab id")
    print("encode special-token id resolution: PASS")

def test_decode_token_invalid_hex() raises:
    print("--- Testing decode_token hex validation (R004) ---")
    var decoder = RuneStreamDecoder()
    var raised = False
    try:
        _ = decoder.decode_token("<0xZZ>")
    except error:
        raised = True
        if "<0xZZ>" not in String(error):
            raise Error("hex error must name the bad token: " + String(error))
    if not raised:
        raise Error("decode_token must raise for a non-hex byte token")
    # Valid hex still decodes: 0xF0 starts a 4-byte sequence, stays pending.
    var chunk = decoder.decode_token("<0xF0>")
    if chunk != "":
        raise Error("valid <0xF0> must stay pending as an incomplete sequence")
    print("decode_token hex validation: PASS")

def test_stream_decoder_invalid_byte_replacement() raises:
    print("--- Testing invalid byte U+FFFD replacement (R005) ---")
    var decoder = RuneStreamDecoder()
    # A lone continuation byte can never complete: replaced immediately.
    var chunk = decoder.decode_token("<0x80>")
    var tail = decoder.flush()
    var combined = chunk + tail
    if combined != "\uFFFD":
        raise Error("lone 0x80 must decode to exactly U+FFFD, got '" + combined + "'")
    var combined_bytes = combined.as_bytes()
    if len(combined_bytes) != 3 or combined_bytes[0] != 0xEF or combined_bytes[1] != 0xBF or combined_bytes[2] != 0xBD:
        raise Error("U+FFFD must be bytes EF BF BD")
    for i in range(len(combined_bytes)):
        if combined_bytes[i] == 0x80:
            raise Error("raw 0x80 leaked into decoded output")
    # flush() with a truncated sequence pending: 0xE2 stays pending in
    # _pop_complete_utf8, then flush() replaces it with U+FFFD.
    var decoder2 = RuneStreamDecoder()
    var pending_chunk = decoder2.decode_token("<0xE2>")
    if pending_chunk != "":
        raise Error("truncated 0xE2 lead must stay pending")
    var flushed = decoder2.flush()
    if flushed != "\uFFFD":
        raise Error("truncated lead 0xE2 must flush to U+FFFD, got '" + flushed + "'")
    print("invalid byte U+FFFD replacement: PASS")

def main() raises:
    test_tokenizer()
    test_stream_decoder()
    test_multilingual_corpora()
    test_validate_vocabulary_duplicate_spelling()
    test_validate_vocabulary_missing_coverage()
    test_validate_vocabulary_empty_special_spelling()
    test_add_token_negative_id()
    test_encode_special_token_resolution()
    test_decode_token_invalid_hex()
    test_stream_decoder_invalid_byte_replacement()
