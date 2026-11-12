"""A-031 opt-in loader timing harness (not part of run_all).

Times GGUF load phases on the caller's model:
  meta_ns = GGUFSeer.inspect_metadata (open+mmap+header+metadata;
            metadata parsing builds the RuneWeaver tokenizer vocab)
  load_ns = GGUFSeer.mmap_and_load (full load: same phases plus
            tensor mapping and required-tensor validation)
  enc_ns  = RuneWeaver.encode of a fixed probe sentence with the
            tokenizer built by the full load
Clock: clock_gettime(CLOCK_MONOTONIC) via armvegr.util.now_ns.
Usage: bench_loader_a031 <model.gguf> <reps>
"""
from std.sys import argv
from armvegr.util import now_ns
from core.mimir_well import MimirWell
from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver

def main() raises:
    var args = argv()
    if len(args) < 3:
        raise Error("usage: bench_loader_a031 <model.gguf> <reps>")
    var path = String(args[1])
    var reps = Int(args[2])
    print("A031_BENCH path=", path, " reps=", reps)
    for r in range(reps):
        var well = MimirWell(64 * 1024 * 1024)
        var t0 = now_ns()
        var meta_seer = GGUFSeer(path)
        var meta_tok = RuneWeaver()
        meta_seer.inspect_metadata(meta_tok)
        var t1 = now_ns()
        var seer = GGUFSeer(path)
        var tok = RuneWeaver()
        seer.mmap_and_load(well, tok)
        var t2 = now_ns()
        var ids = tok.encode(String("The quick brown fox jumps over the lazy dog."), True)
        var t3 = now_ns()
        print("A031_RUN", r, " meta_ns=", t1 - t0, " load_ns=", t2 - t1, " enc_ns=", t3 - t2, " tokens=", len(ids), " tensors=", seer.tensor_count, " kv=", seer.kv_count)
        seer.close()
        meta_seer.close()
