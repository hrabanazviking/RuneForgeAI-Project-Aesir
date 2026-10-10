# GAUNTLET — D7 measurement and judgment framework (MÍMISBRUNNR Campaign 10).
#
# The judge. GAUNTLET measures production behavior and emits PASS/FAIL
# verdicts against machine-checkable gates. It NEVER fixes anything:
# GAUNTLET measures and judges only; implementation fixes go back to the
# owning domains (ARMVEGR, HAILBRÚ, VÖRÐR) in clean commits.
#
# ARCHITECTURAL LAW (H181): no gauntlet/*.mojo file may import anything
# outside the Mojo standard library. Enforced mechanically by
# prof/gauntlet/test_gauntlet_purity.py (every `from X` must satisfy
# X startswith "std"). GAUNTLET reads measurement logs and judges;
# repair/recovery/fix code paths are unreachable by construction.
#
# Modules:
#   metrics  — Metric / Measurement primitives + trend statistics
#   gates    — Gate definitions: metric -> measurement -> threshold -> verdict
#   verdict  — Verdict / VerdictSet structs and JSON emission
