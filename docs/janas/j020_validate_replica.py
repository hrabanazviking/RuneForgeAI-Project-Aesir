#!/usr/bin/env python3
"""J-020: validate the Python ExpertCache replica against the REAL Mojo
module's replay output (/tmp/j020/replay_out.txt): per-token miss sets
must be identical for cold, warm and prose_cold segmented runs, the
LRU run likewise, and run totals must match the Mojo TOTAL lines."""
import csv
import sys

sys.path.insert(0, "/home/hatch/workspace/model-tests/janas")
from j020_policy import ExpertCacheReplica, HIT

MEAN = 3720
BUDGET = 512 * MEAN


def load(path):
    rows = []
    with open(path) as f:
        for r in csv.reader(f):
            rows.append(tuple(int(x) for x in r))
    return rows


def mojo_side():
    toks, miss, total = {}, {}, {}
    for line in open("/tmp/j020/replay_out.txt"):
        p = line.split()
        if not p:
            continue
        if p[0] == "TOK":
            toks.setdefault(p[1], []).append([int(x) for x in p[2:]])
        elif p[0] == "MISS":
            miss.setdefault(p[1], []).append(
                (int(p[2]), int(p[3]), int(p[4])))
        elif p[0] == "TOTAL":
            kv = {}
            for field in p[2:]:
                k, v = field.split("=")
                kv[k] = int(v)
            total[p[1]] = kv
    return toks, miss, total


def run_replica(accesses, policy, cache=None, label=""):
    if cache is None:
        cache = ExpertCacheReplica(BUDGET, policy)
    per_token = {}
    miss_list = []
    for (ti, L, e, sz) in accesses:
        code = cache.access(L, e, sz)
        d = per_token.setdefault(ti, [0, 0, 0, 0])
        if code == HIT:
            d[0] += 1
        else:
            d[1] += 1
            d[3] += sz
            if code == -1:
                d[2] += 1
            miss_list.append((ti, L, e))
    return cache, per_token, miss_list


def compare(run, per_token, miss_list, cache, mtoks, mmiss, mtotal):
    ok = True
    mrows = {r[0]: r for r in mtoks[run]}
    for ti, d in sorted(per_token.items()):
        m = mrows[ti]
        mine = [ti, d[0], d[1], d[2], d[3]]
        if mine != m[:5]:
            print(f"  MISMATCH {run} token {ti}: replica {mine} mojo {m[:5]}")
            ok = False
            break
    if miss_list != mmiss[run]:
        print(f"  MISMATCH {run} miss stream (len {len(miss_list)} "
              f"vs {len(mmiss[run])})")
        for i, (a, b) in enumerate(zip(miss_list, mmiss[run])):
            if a != b:
                print(f"    first diff at {i}: replica {a} mojo {b}")
                break
        ok = False
    st = cache.stats
    mt = mtotal[run]
    for k in ("hits", "misses", "cold_misses", "bypasses", "admissions",
              "promotions", "evictions", "bytes_streamed"):
        # warm TOTAL in the Mojo output is cumulative over both passes;
        # the replica run for warm starts from the cold cache, so its
        # stats are cumulative in the same way.
        if st[k] != mt[k]:
            print(f"  MISMATCH {run} total {k}: replica {st[k]} mojo {mt[k]}")
            ok = False
    print(f"{run}: {'EXACT MATCH' if ok else 'FAILED'} "
          f"(hits={st['hits']} misses={st['misses']} "
          f"streamed={st['bytes_streamed']})")
    return ok


def main():
    mtoks, mmiss, mtotal = mojo_side()
    session = load("/tmp/j020/session_accesses.csv")
    prose = load("/tmp/j020/prose_accesses.csv")
    ok = True
    cache, pt, ml = run_replica(session, "segmented")
    ok &= compare("cold", pt, ml, cache, mtoks, mmiss, mtotal)
    # warm: continue the SAME replica cache over the session again
    _, pt2, ml2 = run_replica(session, "segmented", cache=cache)
    ok &= compare("warm", pt2, ml2, cache, mtoks, mmiss, mtotal)
    pcache, ppt, pml = run_replica(prose, "segmented")
    ok &= compare("prose_cold", ppt, pml, pcache, mtoks, mmiss, mtotal)
    lcache, lpt, lml = run_replica(session, "lru")
    ok &= compare("lru_cold", lpt, lml, lcache, mtoks, mmiss, mtotal)
    print("REPLICA VALIDATION:", "PASS — replica is exact on all four runs"
          if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
