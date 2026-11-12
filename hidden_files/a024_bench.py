#!/usr/bin/env python3
"""A-024 placed-vs-unplaced CPU benchmark on purpleraider (Z13).

Method (pre-registered before any number was measured):
- Topology is read from the machine's own sysfs (online list,
  thread_siblings_list, L3 shared_cpu_list) and the placement
  maps are computed with the same policy definitions as
  core/thread_placement.mojo (SPREAD / PACK / CCD_LOCAL).
- Workload: W worker processes (multiprocessing, fork). Each
  worker optionally pins itself with os.sched_setaffinity to its
  assigned single CPU (placed configs) or leaves the inherited
  mask untouched (unplaced), verifies its mask, then runs a
  fixed amount of deterministic integer work (LCG + FNV-style
  mixing, result checked against the serial oracle value so the
  work cannot be optimized away or silently skipped).
- Each (workers, config) pair runs ROUNDS rounds; configs are
  interleaved round-by-round in rotating order so slow machine
  drift (other crews' load) hits every config alike. Reported:
  per-round wall seconds (parent-measured, spawn to all-joined),
  median / min / max per config.
- Verdict rule: a placed config is WORSE than unplaced iff its
  median exceeds unplaced median by more than 5% (the house
  noise band, J-039) AND its min exceeds unplaced min by more
  than 2%. The acceptance question is about the DEFAULT placed
  configuration (SPREAD): it must not be WORSE by this rule at
  either worker count. Every config's numbers are reported
  whatever the verdict -- a variant that loses is filed as
  losing, never hidden.
"""
import json
import os
import statistics
import sys
import time
import multiprocessing as mp

CTX = mp.get_context('fork')  # explicit: forkserver children re-import
# the module and would see EXPECTED=None (found in-slice, first run).

SYSFS = "/sys/devices/system/cpu"
ITERS = 900_000
ROUNDS = 7


def parse_cpu_list(text):
    out = []
    for part in text.strip().split(","):
        part = part.strip()
        if "-" in part:
            lo, hi = part.split("-", 1)
            out.extend(range(int(lo), int(hi) + 1))
        else:
            out.append(int(part))
    return out


def read_topology():
    with open(f"{SYSFS}/online") as f:
        online = parse_cpu_list(f.read())
    sib_distinct, l3_distinct = [], []
    for cpu in online:
        with open(f"{SYSFS}/cpu{cpu}/topology/thread_siblings_list") as f:
            s = f.read().strip()
        with open(f"{SYSFS}/cpu{cpu}/cache/index3/shared_cpu_list") as f:
            l = f.read().strip()
        if s not in sib_distinct:
            sib_distinct.append(s)
        if l not in l3_distinct:
            l3_distinct.append(l)
    cores = sorted((parse_cpu_list(s) for s in sib_distinct), key=lambda c: c[0])
    domains = sorted((parse_cpu_list(s) for s in l3_distinct), key=lambda c: c[0])
    return online, cores, domains


def core_of(cores):
    m = {}
    for idx, sibs in enumerate(cores):
        for cpu in sibs:
            m[cpu] = idx
    return m


def ccd_of(domains):
    m = {}
    for idx, cpus in enumerate(domains):
        for cpu in cpus:
            m[cpu] = idx
    return m


def policy_order(cores, domains, policy):
    co, cd = core_of(cores), ccd_of(domains)
    if policy == "spread":
        per_ccd = []
        for d in range(len(domains)):
            per_ccd.append(sorted({co[c] for c in domains[d]}))
        order_cores = []
        for rank in range(max(len(x) for x in per_ccd)):
            for d in range(len(domains)):
                if rank < len(per_ccd[d]):
                    order_cores.append(per_ccd[d][rank])
        order = []
        for rank in range(max(len(c) for c in cores)):
            for core in order_cores:
                if rank < len(cores[core]):
                    order.append(cores[core][rank])
        return order
    if policy == "pack":
        order = []
        for sibs in cores:
            order.extend(sibs)
        return order
    if policy == "ccd_local":
        order = []
        for d in range(len(domains)):
            dcores = sorted({co[c] for c in domains[d]})
            for rank in range(max(len(cores[c]) for c in dcores)):
                for core in dcores:
                    if rank < len(cores[core]):
                        order.append(cores[core][rank])
        return order
    raise ValueError(policy)


def work(iters):
    x = 0x243F6A8885A308D3
    for i in range(iters):
        x = ((x * 6364136223846793005) + 1442695040888963407) & 0xFFFFFFFFFFFFFFFF
        x ^= (x >> 33) + i
        x &= 0xFFFFFFFFFFFFFFFF
    return x


EXPECTED = None  # filled in main from a serial run


def worker(idx, cpu, expected, q):
    try:
        if cpu is not None:
            os.sched_setaffinity(0, {cpu})
            got = os.sched_getaffinity(0)
            if got != {cpu}:
                q.put((idx, None, f"affinity readback {sorted(got)} != {{{cpu}}}"))
                return
        t0 = time.perf_counter()
        result = work(ITERS)
        dt = time.perf_counter() - t0
        if result != expected:
            q.put((idx, None, "checksum mismatch vs serial oracle"))
            return
        q.put((idx, dt, ""))
    except Exception as e:  # noqa: BLE001 - reported, never hidden
        q.put((idx, None, f"{type(e).__name__}: {e}"))


def run_round(workers, cpus):
    q = CTX.Queue()
    procs = []
    t0 = time.perf_counter()
    for i in range(workers):
        cpu = None if cpus is None else cpus[i]
        p = CTX.Process(target=worker, args=(i, cpu, EXPECTED, q))
        p.start()
        procs.append(p)
    results = {}
    for _ in range(workers):
        idx, dt, err = q.get()
        results[idx] = (dt, err)
    for p in procs:
        p.join()
    wall = time.perf_counter() - t0
    errs = [results[i][1] for i in range(workers) if results[i][1]]
    if errs:
        raise RuntimeError(f"worker errors: {errs}")
    return wall


def main():
    global EXPECTED
    online, cores, domains = read_topology()
    print(f"topology: online={len(online)} cores={len(cores)} l3_domains={len(domains)}")
    print(f"cores (sibling sets): {cores}")
    print(f"l3 domains: {domains}")
    EXPECTED = work(ITERS)
    print(f"serial oracle checksum: {EXPECTED:#x} iters={ITERS}")
    configs = []
    for workers in (8, 16):
        cfgs = [("unplaced", None)]
        for pol in ("spread", "pack", "ccd_local"):
            cfgs.append((pol, policy_order(cores, domains, pol)[:workers]))
        if workers == 16:
            cfgs = [c for c in cfgs if c[0] in ("unplaced", "spread", "ccd_local")]
        for name, cpus in cfgs:
            configs.append((workers, name, cpus))
    rounds_data = {}
    for r in range(ROUNDS):
        ordered = configs[r % len(configs):] + configs[:r % len(configs)]
        for workers, name, cpus in ordered:
            wall = run_round(workers, cpus)
            rounds_data.setdefault((workers, name), []).append(round(wall, 4))
            print(f"round {r} workers={workers} config={name} wall={wall:.4f}s", flush=True)
    summary = {}
    print("\n=== summary (seconds, parent wall per round) ===")
    for (workers, name), walls in sorted(rounds_data.items()):
        med = statistics.median(walls)
        summary.setdefault(str(workers), {})[name] = {
            "rounds": walls, "median": round(med, 4),
            "min": min(walls), "max": max(walls),
        }
        print(f"workers={workers} {name:9s} median={med:.4f} min={min(walls):.4f} max={max(walls):.4f}")
    print("\n=== verdicts (worse iff median > unplaced*1.05 AND min > unplaced*1.02) ===")
    verdicts = {}
    for workers in ("8", "16"):
        base = summary[workers]["unplaced"]
        for name, s in summary[workers].items():
            if name == "unplaced":
                continue
            worse = s["median"] > base["median"] * 1.05 and s["min"] > base["min"] * 1.02
            verdicts[f"{workers}/{name}"] = "WORSE" if worse else "NOT-WORSE"
            print(f"workers={workers} {name:9s} -> {'WORSE' if worse else 'NOT-WORSE'} "
                  f"(median {s['median']:.4f} vs unplaced {base['median']:.4f})")
    out = {"topology": {"online": online, "cores": cores, "l3_domains": domains},
           "iters_per_worker": ITERS, "rounds": ROUNDS,
           "summary": summary, "verdicts": verdicts}
    with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "a024_bench.json"), "w") as f:
        json.dump(out, f, indent=1)
    spread_ok = all(v == "NOT-WORSE" for k, v in verdicts.items() if k.endswith("/spread"))
    print("\nACCEPTANCE (default SPREAD never worse):", "PASS" if spread_ok else "FAIL")
    return 0 if spread_ok else 1


if __name__ == "__main__":
    sys.exit(main())
