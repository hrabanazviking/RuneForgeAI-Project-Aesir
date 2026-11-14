# Q35-3b tokenize-once probe (not a suite test).
# Parses ONLY the GGUF header+metadata of the real file (the Q35-1/3r
# no-materialization seam), then encodes the fixed RAW prompt set with
# the file's own tokenizer (RuneWeaver) and writes ONE token stream per
# prompt to the tokens file. Both engines (Aesir + llama.cpp) consume
# these exact IDs; neither side tokenizes independently. No chat
# template is applied anywhere. add_bos follows the file's own
# tokenizer metadata (RuneWeaver.encode honors add_bos_token).
# Usage: probe_qwen35_tokens_q35_3b <real.gguf> <tokens_out.txt>

from std.sys import argv

from core.mimir_well import MimirWell
from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver, RuneStreamDecoder


def prompts() -> List[String]:
    var p = List[String]()
    p.append(String("The capital of France is"))
    p.append(String("In a small village by the sea, an old fisherman mended his nets and watched the"))
    p.append(String("def quicksort(arr):\n    if len(arr) <= 1:\n        return arr\n    pivot = arr[len(arr) // 2]"))
    p.append(String("The history of the Roman Empire is a story of roads, laws, and legions. From a small city on the banks of the Tiber, Rome grew to rule the Mediterranean world, and its language, Latin, became the foundation of many modern tongues spoken today across Europe and beyond the sea."))
    p.append(String("One, two, three, four, five, six, seven, eight, nine, ten, eleven, twelve, thirteen, fourteen, fifteen, sixteen, seventeen, eighteen, nineteen, twenty"))
    p.append(String("Photosynthesis is the process by which green plants convert sunlight, water, and carbon dioxide into oxygen and glucose. This biochemical pathway sustains nearly all life on Earth, either directly or indirectly, and has shaped the atmosphere over billions of years of evolution."))
    return p^


def main() raises:
    var arguments = argv()
    if len(arguments) != 3:
        raise Error("usage: probe_qwen35_tokens_q35_3b <real.gguf> <tokens_out.txt>")
    var tokenizer = RuneWeaver()
    var seer = GGUFSeer(arguments[1])
    seer._open_and_map()
    seer._parse_header()
    _ = seer._parse_metadata(tokenizer)
    print("arch:", seer.config.architecture, "vocab:", tokenizer.vocab_size, "bos:", tokenizer.bos_token_id, "eos:", tokenizer.eos_token_id, "add_bos_token:", tokenizer.add_bos_token)
    var ps = prompts()
    var out = String("")
    for pi in range(len(ps)):
        var ids = tokenizer.encode(ps[pi], True)
        print("PROMPT", pi, "chars:", ps[pi].byte_length(), "tokens:", len(ids))
        var line = String("")
        for i in range(len(ids)):
            if i > 0:
                line += String(" ")
            line += String(ids[i])
        out += line + String("\n")
        # round-trip witness: decode(ids) must reproduce the raw text
        var dec = RuneStreamDecoder()
        var back = String("")
        for i in range(len(ids)):
            back += dec.decode_id(ids[i], tokenizer)
        back += dec.flush()
        print("ROUNDTRIP", pi, "match:", back == ps[pi])
    var handle = open(arguments[2], "w")
    handle.write(out)
    handle.close()
    print("TOKENS WRITTEN:", arguments[2])
