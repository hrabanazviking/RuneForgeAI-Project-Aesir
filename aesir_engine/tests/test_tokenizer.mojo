# tests/test_tokenizer.mojo

from loader.tokenizer import RuneWeaver

def test_tokenizer():
    print("--- Testing RuneWeaver ---")
    var weaver = RuneWeaver()
    
    # 1. Fallback encoding without vocabulary
    var prompt = String("hello world")
    var tokens = weaver.encode(prompt)
    print("Fallback tokens count:", len(tokens))
    assert len(tokens) == 11
    
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
    
    assert weaver.vocab_size == 302
    
    var bpe_tokens = weaver.encode(prompt)
    print("BPE merged tokens count:", len(bpe_tokens))
    assert len(bpe_tokens) == 3 # ["hello", " ", "world"]
    assert bpe_tokens[0] == 300
    assert bpe_tokens[1] == 104
    assert bpe_tokens[2] == 301
    
    # 3. Decode verification
    var decoded = weaver.decode(300)
    assert decoded == "hello"
    
    print("RuneWeaver: PASS")

def main():
    test_tokenizer()
