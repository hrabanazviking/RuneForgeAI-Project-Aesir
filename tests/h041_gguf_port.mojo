# tests/h041_gguf_port.mojo
# H041 — GGUFSeer ARM64 port check harness (TEST-ONLY driver, not shipped).
#
# Exercises every GGUFSeer parse path on one GGUF file and prints a canonical,
# deterministic text dump: header, config, tokenizer, and per-tensor
# descriptors (names sorted). Run the same binary built for x86_64 and for
# ARM64 over the same corpus; the outputs must be byte-identical
# (see data/armvegr/gguf_port_diff.txt).
#
# Usage: h041_gguf_port <path-to-gguf>
# Exit 0 always; parse failures print "REJECT: <error>" (the rejection itself
# is part of the port contract, e.g. the v2 version gate).

from std.sys import argv

from core.mimir_well import MimirWell
from loader.gguf import GGUFSeer, GGUFState
from loader.tokenizer import RuneWeaver


def sorted_names(names: List[String]) -> List[String]:
    var out = names.copy()
    for i in range(1, len(out)):
        var key = out[i].copy()
        var j = i - 1
        while j >= 0 and out[j] > key:
            out[j + 1] = out[j].copy()
            j -= 1
        out[j + 1] = key.copy()
    return out^


def dump_canonical(path: String) raises:
    var seer = GGUFSeer(path)
    var well = MimirWell(1024 * 1024)
    var tok = RuneWeaver()
    try:
        seer.mmap_and_load(well, tok)
    except e:
        print("file: " + path)
        print("REJECT: " + String(e))
        print("state: " + GGUFState.to_string(seer.state))
        return
    print("file: " + path)
    print("version: " + String(seer.version))
    print("tensor_count: " + String(seer.tensor_count))
    print("kv_count: " + String(seer.kv_count))
    print("alignment: " + String(seer.alignment))
    print("data_offset: " + String(seer.data_offset))
    print("state: " + GGUFState.to_string(seer.state))
    print("config.architecture: " + seer.config.architecture)
    print("config.context_length: " + String(seer.config.context_length))
    print("config.embedding_length: " + String(seer.config.embedding_length))
    print("config.feed_forward_length: " + String(seer.config.feed_forward_length))
    print("config.block_count: " + String(seer.config.block_count))
    print("config.head_count: " + String(seer.config.head_count))
    print("config.head_count_kv: " + String(seer.config.head_count_kv))
    print("config.rope_dimension_count: " + String(seer.config.rope_dimension_count))
    print("config.rope_freq_base: " + String(seer.config.rope_freq_base))
    print("config.rms_epsilon: " + String(seer.config.rms_epsilon))
    print("config.bos_token_id: " + String(seer.config.bos_token_id))
    print("config.eos_token_id: " + String(seer.config.eos_token_id))
    print("config.unknown_token_id: " + String(seer.config.unknown_token_id))
    print("tokenizer.vocab_size: " + String(tok.vocab_size))
    print("tokenizer.bos_token_id: " + String(tok.bos_token_id))
    print("tokenizer.eos_token_id: " + String(tok.eos_token_id))
    print("tokenizer.unknown_token_id: " + String(tok.unknown_token_id))
    print("tokenizer.add_bos_token: " + String(tok.add_bos_token))
    print("tokenizer.add_space_prefix: " + String(tok.add_space_prefix))
    for i in range(len(tok.vocab)):
        print("tokenizer.vocab[" + String(i) + "]: " + tok.vocab[i])
    var names = List[String]()
    for k in seer.tensor_types.keys():
        names.append(k)
    for name in sorted_names(names):
        var ttype = seer.tensor_types[name]
        var off = seer.tensor_file_offsets[name]
        ref tensor = seer.tensors[name]
        print(
            "tensor: " + name + " type=" + String(ttype)
            + " rows=" + String(tensor.rows)
            + " cols=" + String(tensor.cols)
            + " offset=" + String(off)
        )
    seer.close()


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: h041_gguf_port <path-to-gguf>")
    dump_canonical(args[1])
