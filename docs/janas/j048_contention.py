#!/usr/bin/env python3
"""J-048 contention sweep: SIMULATED on MEASURED inputs.

Validation gate (must pass before any sweep number is trusted):
the filed J-024 tournament fsketch counters and the filed J-028
pressure-schedule counters are reproduced EXACTLY from the
campaign copies of their results files (every counter checked
against the values their docs file).

Planner: a Python mirror of core/placement_pressure.mojo's
plan_placement_pressure charging order (fixed first, cache
elastic capped at open/body, floor threshold, degrade for an
optional cache, refuse for a required one, auto duplicate copy
closed at the floor line). Inputs are Aesir's filed OLMoE
numbers only: pair 3,809,280 B full-scale (J-016/J-028 scaled
3,720 x 1,024), floor 128 pairs, body 1,024 pairs =
3,900,702,720 B, resident 311,027,712 B, allowances
352,321,536 B, usable device budget 5,368,709,120 B (J-031).
Cache-quality figures attached to a swept budget are the filed
fsketch counters at that exact pair budget (J-024 global runs /
J-028 base) -- the device cache's own hit behaviour is NOT
measured; reusing the host trace counters at equal pair budgets
is the simulation's stated assumption.
"""
import json
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
CAMP = pathlib.Path.home() / "workspace/model-tests/janas"

PAIR = 3720 * 1024
FLOOR_PAIRS = 128
BODY_PAIRS = 1024
BODY = 3900702720
RESIDENT = 311027712
ALLOW = 352321536
FIXED = RESIDENT + ALLOW
DEVPOOL = 5368709120
FLOOR = FLOOR_PAIRS * PAIR

FULL, SHRUNK, NO_CACHE, REFUSE = "full", "shrunk", "no_cache", "refuse"


def plan(pool, fixed, open_bytes, required, copy_bytes=0, copy_manual=False):
    charged = 0
    closed = False
    if copy_bytes > 0:
        if copy_manual:
            charged = copy_bytes
        elif pool - fixed - copy_bytes >= FLOOR:
            charged = copy_bytes
        else:
            closed = True
    avail = pool - fixed - charged
    if avail < 0:
        return dict(decision=REFUSE, cache_bytes=0, copy_charged=charged,
                    copy_closed=closed, placement_stands=False)
    target = min(open_bytes, avail, BODY)
    if target < FLOOR:
        if required:
            return dict(decision=REFUSE, cache_bytes=0, copy_charged=charged,
                        copy_closed=closed, placement_stands=False)
        return dict(decision=NO_CACHE, cache_bytes=0, copy_charged=charged,
                    copy_closed=closed, placement_stands=True)
    return dict(decision=FULL if target >= open_bytes else SHRUNK,
                cache_bytes=target, copy_charged=charged,
                copy_closed=closed, placement_stands=True)


def gate():
    t = json.loads((CAMP / "j024_tournament_results.json").read_text())
    g = t["global_runs"]
    expect = {"fsketch@128": (25953, 182425387008), "fsketch@256": (39394, 131338125312),
              "fsketch@512": (56781, 65190789120), "fsketch@1024": (72832, 3900702720)}
    out = {}
    for k, (hits, streamed) in expect.items():
        assert g[k]["hits"] == hits and g[k]["streamed_full_bytes"] == streamed, k
        out[k] = "EXACT"
    p = json.loads((CAMP / "j028_pressure_results.json").read_text())
    s = p["schedules"]
    assert s["base"]["hits"] == 56781 and s["step"]["hits"] == 40277
    assert s["crash"]["refusal"]["token"] == 288
    assert s["crash"]["refusal"]["pressured_pairs"] == 64
    assert s["crash"]["refusal"]["floor_pairs"] == 128
    assert p["validation_gate"]["tournament@512"] == "EXACT"
    out["j028_base_step_crash"] = "EXACT"
    filed = {int(k.split("@")[1]): (v["hit_rate"], v["streamed_mb_per_token"])
             for k, v in g.items() if k.startswith("fsketch@")}
    return out, filed


def main():
    gate_out, filed = gate()
    rows = []
    for pairs in (1024, 512, 256, 128, 64):
        pool = FIXED + pairs * PAIR
        dev = plan(pool, FIXED, BODY, required=False)
        host = plan(pool, FIXED, BODY, required=True)
        row = dict(cache_pairs=pairs, pool_bytes=pool,
                   device_pool=dev, host_pool=host)
        if pairs in filed:
            row["filed_fsketch_hit_rate"] = filed[pairs][0]
            row["filed_fsketch_streamed_mb_per_token"] = filed[pairs][1]
        rows.append(row)
    stated = plan(DEVPOOL, FIXED, BODY, required=False)
    assert stated["decision"] == FULL and stated["cache_bytes"] == BODY
    assert DEVPOOL - FIXED - BODY == 804657152
    # Auto-copy scenario: copy sized at 256 pairs of bytes (a stated
    # scenario input in measured units, not a measured copy size).
    copy_bytes = 256 * PAIR
    copy_closed = plan(FIXED + copy_bytes + FLOOR - 1, FIXED, BODY,
                       required=False, copy_bytes=copy_bytes)
    copy_open = plan(FIXED + copy_bytes + FLOOR, FIXED, BODY,
                     required=False, copy_bytes=copy_bytes)
    assert copy_closed["copy_closed"] and copy_closed["cache_bytes"] == copy_bytes + FLOOR - 1
    assert not copy_open["copy_closed"] and copy_open["cache_bytes"] == FLOOR
    results = dict(
        gate=gate_out,
        inputs=dict(pair_bytes=PAIR, floor_pairs=FLOOR_PAIRS, floor_bytes=FLOOR,
                    body_bytes=BODY, resident_bytes=RESIDENT,
                    allowances_bytes=ALLOW, fixed_bytes=FIXED,
                    stated_device_budget_bytes=DEVPOOL),
        stated_machine=dict(plan=stated, headroom_bytes=DEVPOOL - FIXED - BODY),
        sweep=rows,
        auto_copy_scenario=dict(copy_bytes=copy_bytes,
                                at_floor_minus_1=copy_closed,
                                at_floor=copy_open),
        verdict="PASS: gate EXACT; stated machine FULL; device pool "
                "degrades at 64 pairs while host pool refuses there; "
                "auto copy closes exactly at the floor line",
    )
    out_path = HERE / "j048_contention_results.json"
    out_path.write_text(json.dumps(results, indent=1) + "\n")
    print(json.dumps(results, indent=1))


if __name__ == "__main__":
    main()
