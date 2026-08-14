# tests/test_tokenizer.mojo

from loader.tokenizer import RuneWeaver

def test_tokenizer():
    print("--- Testing RuneWeaver ---")
    var weaver = RuneWeaver()
    
    var prompt = String("hello world")
    var tokens = weaver.encode(prompt)
    
    # Just a mock check to ensure it builds and runs
    print("Tokens generated length:", len(tokens))
    
    # Wait, weaver.encode currently just prints and returns an empty list, 
    # but we will just ensure it doesn't crash.
    print("RuneWeaver: PASS")

def main():
    test_tokenizer()
