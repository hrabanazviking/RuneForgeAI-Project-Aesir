# J-028 real-module replay: feeds the J-016 measured OLMoE trace
# (pre-flattened by j028_flatten.py to token,layer,expert,scaled_size
# rows) through the REAL ExpertCache (fsketch, the shipping default)
# driven by the REAL plan_pressure_budget through the RECOVERY
# pressure schedule of j028_pressure.py: 512 pairs open, shrink to
# 256 at token 144, shrink to 128 (the floor) at token 288, regrow
# to 512 at token 360. Events apply at token boundaries, before the
# token's first access -- the documented host cadence.
#
# The planner is exercised on a reserve-free scaled machine
# (resident/KV/scratch 0, total 4 so the OS headroom total//5 is 0):
# raw pressured budget then equals the free sample, and each event's
# free sample is set to the schedule's target, so the planner's
# decision and target are what the host applies -- via
# resize_budget for shrink/regrow, exactly as the contract
# prescribes. The reserve arithmetic itself is pinned by the unit
# tests on a stated machine; this replay isolates the decision +
# cache mechanics. The floor is one token's full routed demand in
# scaled bytes (128 pairs x 3720 = 476160).
#
# The counters printed here must reproduce j028_pressure.py's
# RECOVERY counters EXACTLY (the simulator is the J-024-gate-
# validated one; this replay is the cross-check that the pressure
# machinery in the real module behaves identically).
from core.expert_cache import (
    ExpertCache,
    PRESSURE_CONTINUE,
    PRESSURE_REGROW,
    PRESSURE_REFUSE,
    PRESSURE_SHRINK,
    plan_pressure_budget,
)


def event_target(token: Int) -> Int:
    """RECOVERY schedule targets in scaled bytes, or -1 (no event)."""
    if token == 144:
        return 256 * 3720
    if token == 288:
        return 128 * 3720
    if token == 360:
        return 512 * 3720
    return -1


def decision_name(decision: Int) -> String:
    if decision == PRESSURE_SHRINK:
        return String("shrink")
    if decision == PRESSURE_REGROW:
        return String("regrow")
    if decision == PRESSURE_REFUSE:
        return String("refuse")
    return String("continue")


def main() raises:
    var text: String
    with open("j028_accesses.csv", "r") as source:
        text = source.read()
    var open_budget = 512 * 3720
    var floor_bytes = 128 * 3720
    var cache = ExpertCache(open_budget, String("fsketch"))
    var current_token = -1
    for line in text.split("\n"):
        if line.byte_length() == 0:
            continue
        var parts = line.split(",")
        var token = atol(String(parts[0]))
        if token != current_token:
            current_token = token
            var target = event_target(token)
            if target >= 0:
                var plan = plan_pressure_budget(
                    target, 4, 0, 0, 0, 0, floor_bytes, open_budget,
                    cache.budget_bytes,
                )
                print(
                    "event token",
                    token,
                    plan.describe(),
                    "resident_before",
                    cache.snapshot().bytes_resident_now,
                )
                if plan.decision == PRESSURE_REFUSE:
                    raise Error("replay schedule must never refuse")
                if plan.decision != PRESSURE_CONTINUE:
                    var left = cache.resize_budget(plan.target_bytes)
                    print(
                        " applied",
                        decision_name(plan.decision),
                        "resident_after",
                        left,
                    )
        _ = cache.access(
            atol(String(parts[1])),
            atol(String(parts[2])),
            atol(String(parts[3])),
        )
    print("recovery", cache.snapshot().describe())
