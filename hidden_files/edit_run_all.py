import sys

p = "/home/volmarr/aesir-team-26/aesir_engine/tests/run_all.mojo"
src = open(p).read()

# 1. import block, appended after the A-121 block
anchor1 = """from tests.test_moe_battery_a121 import (
    test_moe_axes_product,
    test_moe_backend_not_graded,
    test_moe_checks_discriminate,
    test_moe_cpu_faithful,
    test_moe_digest_deterministic,
    test_moe_enumeration_unique,
    test_moe_invalid_axes_refused,
    test_moe_layer_witnesses,
    test_moe_policy_obligation,
    test_moe_summary_sums,
    test_moe_synthetic_defects,
    test_moe_synthetic_labelled,
    test_moe_synthetic_raw_rule,
)
"""
add1 = anchor1 + """from tests.test_sliding_window_battery_a123 import (
    test_sliding_axes_product,
    test_sliding_backend_not_graded,
    test_sliding_boundary_probe,
    test_sliding_boundary_witnesses,
    test_sliding_checks_discriminate,
    test_sliding_cpu_faithful,
    test_sliding_digest_deterministic,
    test_sliding_enumeration_unique,
    test_sliding_invalid_axes_refused,
    test_sliding_policy_obligation,
    test_sliding_seeded_defects,
    test_sliding_summary_sums,
    test_sliding_synthetic_labelled,
)
"""
assert src.count(anchor1) == 1, "anchor1 count %d" % src.count(anchor1)
src = src.replace(anchor1, add1)

# 2. run_case lines after the last A-121 case
anchor2 = '    run_case(ledger, "moe.battery_digest_deterministic", test_moe_digest_deterministic)\n'
add2 = anchor2 + """    run_case(ledger, "sliding.battery_axes_product", test_sliding_axes_product)
    run_case(ledger, "sliding.battery_enumeration_unique", test_sliding_enumeration_unique)
    run_case(ledger, "sliding.battery_policy_obligation", test_sliding_policy_obligation)
    run_case(ledger, "sliding.battery_cpu_faithful", test_sliding_cpu_faithful)
    run_case(ledger, "sliding.battery_boundary_witnesses", test_sliding_boundary_witnesses)
    run_case(ledger, "sliding.battery_backend_not_graded", test_sliding_backend_not_graded)
    run_case(ledger, "sliding.battery_summary_sums", test_sliding_summary_sums)
    run_case(ledger, "sliding.battery_checks_discriminate", test_sliding_checks_discriminate)
    run_case(ledger, "sliding.battery_synthetic_labelled", test_sliding_synthetic_labelled)
    run_case(ledger, "sliding.battery_boundary_probe", test_sliding_boundary_probe)
    run_case(ledger, "sliding.battery_seeded_defects", test_sliding_seeded_defects)
    run_case(ledger, "sliding.battery_invalid_axes_refused", test_sliding_invalid_axes_refused)
    run_case(ledger, "sliding.battery_digest_deterministic", test_sliding_digest_deterministic)
"""
assert src.count(anchor2) == 1, "anchor2 count %d" % src.count(anchor2)
src = src.replace(anchor2, add2)

# 3. re-pin comment + finish(814) -> finish(827)
anchor3 = """    # A-121 union re-pin at banking: 801 -> 814 -- thirteen
    # MoE battery cases (moe.battery_* in
    # tests/test_moe_battery_a121.mojo) counted on top of
    # the A-120 seat pin (A-119/A-120 built in parallel
    # on the same seat; union reconciles at banking).
    ledger.finish(814)
"""
add3 = """    # A-121 union re-pin at banking: 801 -> 814 -- thirteen
    # MoE battery cases (moe.battery_* in
    # tests/test_moe_battery_a121.mojo) counted on top of
    # the A-120 seat pin (A-119/A-120 built in parallel
    # on the same seat; union reconciles at banking).
    # A-123 re-pin: 814 -> 827 -- thirteen sliding-window
    # battery cases (sliding.battery_* in
    # tests/test_sliding_window_battery_a123.mojo) counted
    # on top of the A-121 seat pin.
    ledger.finish(827)
"""
assert src.count(anchor3) == 1, "anchor3 count %d" % src.count(anchor3)
src = src.replace(anchor3, add3)

open(p, "w").write(src)
print("run_all.mojo edits applied OK")
