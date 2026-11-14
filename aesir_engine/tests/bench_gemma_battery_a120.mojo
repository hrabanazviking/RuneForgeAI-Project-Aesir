# tests/bench_gemma_battery_a120.mojo
# A-120: Gemma-family battery -- one-command driver.
#
# Usage: bench_gemma_battery_a120
#
# Runs the gemma-family battery (core/gemma_battery_a120)
# over the banked A-114 matrix cells for gemma4, judged
# per the banked A-115 policy, and prints the whole
# battery, one line per row with its verdict and policy
# obligation, plus the summary and the FNV-1a digest.
# Pure enumeration over filed records: no model is
# executed, no device is opened, and no accelerator
# claim is made -- every row is filed NOT_GRADED with
# a named reason (see the module header).

from core.gemma_battery_a120 import (
    gemma_battery_line,
    gemma_battery_render,
    gemma_comparator_reference,
    run_gemma_battery,
)


def main() raises:
    print(gemma_battery_line())
    print("A120_COMPARATOR_REFERENCE", gemma_comparator_reference())
    var report = run_gemma_battery()
    print(gemma_battery_render(report.copy()))
    print("A120_BATTERY_DIGEST", report.digest)
    print("A120_BENCH_DONE rows=", report.total)
