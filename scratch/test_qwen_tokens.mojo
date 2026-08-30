from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver
from core.mimir_well import MimirWell

def main() raises:
    var seer = GGUFSeer("qwen2.5-0.5b-instruct-q4_0.gguf")
    var well = MimirWell(10 * 1024 * 1024)
    var weaver = RuneWeaver()
    seer.mmap_and_load(well, weaver)
    var text = "Hello! Who are you?"
    var tokens = weaver.encode(text, False)
    print("Tokens for 'Hello! Who are you?':")
    for i in range(len(tokens)):
        print("  Token", i, ":", tokens[i], "-> '", weaver.decode(tokens[i]), "'")
