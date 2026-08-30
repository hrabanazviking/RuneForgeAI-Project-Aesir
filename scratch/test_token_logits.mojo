from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver
from loader.chat_template import ChatMessage, RuneChatTemplate
from core.mimir_well import MimirWell, RuneTensor, f16
from core.inference import TransformerBlock
from core.compute import gemm_f16, rmsnorm, apply_rope, silu
from std.memory import Pointer, alloc, Layout

def main() raises:
    var seer = GGUFSeer("qwen2.5-0.5b-instruct-q4_0.gguf")
    seer.parse_header()
    var weaver = RuneWeaver.from_gguf(seer)

    var prompt = "<|im_start|>user\nHello! Who are you?<|im_end|>\n<|im_start|>assistant\n"
    var tokens = weaver.encode(prompt)
    print("Encoded prompt token count:", len(tokens))
    for i in range(len(tokens)):
        print("  Token", i, ":", tokens[i], "->", weaver.decode(tokens[i]))

    var well = MimirWell(512 * 1024 * 1024)
    var embed_key = "token_embd.weight"
    if embed_key not in seer.tensors:
        raise Error("Missing embed key")
    var embed_tensor = seer.tensors[embed_key].copy()
    
    var hidden_dim = embed_tensor.cols
    var vocab_size = embed_tensor.rows
    print("Hidden dim:", hidden_dim, "Vocab size:", vocab_size)
