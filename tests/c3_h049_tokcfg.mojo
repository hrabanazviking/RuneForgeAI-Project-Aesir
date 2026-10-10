# tests/c3_h049_tokcfg.mojo
# H049 — tokenizer config check (TEST-ONLY driver, not shipped).
#
# Verifies data/armvegr/model_tokenizer_configs.json loads for the three
# families with the expected special-token ids, and that an unknown family
# fails closed.
# Usage: c3_h049_tokcfg   (run from the repo root)

from armvegr.tokenizer_config import get_tokenizer_config


def main() raises:
    var path = "data/armvegr/model_tokenizer_configs.json"

    var gpt2 = get_tokenizer_config(path, "gpt2")
    if gpt2.tokenizer != "bpe" or gpt2.vocab_size != 50257:
        print("H049-FAIL gpt2 basics")
        return
    if gpt2.eos_id != 50256 or gpt2.bos_id != -1 or gpt2.unk_id != -1:
        print("H049-FAIL gpt2 special tokens")
        return
    if gpt2.add_bos_default or gpt2.add_eos_default:
        print("H049-FAIL gpt2 add_bos/eos")
        return

    var llama = get_tokenizer_config(path, "llama")
    if llama.tokenizer != "sp" or llama.vocab_size != 32000:
        print("H049-FAIL llama basics")
        return
    if llama.bos_id != 1 or llama.eos_id != 2 or llama.unk_id != 0:
        print("H049-FAIL llama special tokens")
        return
    if not llama.add_bos_default or llama.add_eos_default:
        print("H049-FAIL llama add_bos/eos")
        return
    if not llama.byte_fallback:
        print("H049-FAIL llama byte_fallback")
        return

    var mistral = get_tokenizer_config(path, "mistral")
    if mistral.tokenizer != "sp" or mistral.vocab_size != 32000:
        print("H049-FAIL mistral basics")
        return
    if mistral.bos_id != 1 or mistral.eos_id != 2 or mistral.unk_id != 0:
        print("H049-FAIL mistral special tokens")
        return

    # Unknown family must fail closed.
    var failed_closed = False
    try:
        var _x = get_tokenizer_config(path, "bert")
    except:
        failed_closed = True
    if not failed_closed:
        print("H049-FAIL unknown family did not fail closed")
        return

    print("H049 families: gpt2(bpe,50257,eos=50256) llama(sp,32000,bos=1,eos=2) mistral(sp,32000,bos=1,eos=2)")
    print("H049 unknown family: fail-closed PASS")
    print("H049-ALL-PASS")
