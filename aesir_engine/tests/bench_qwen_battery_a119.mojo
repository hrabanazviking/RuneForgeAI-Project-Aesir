# tests/bench_qwen_battery_a119.mojo
# A-119: Qwen-family battery -- one-command driver.
#
# Usage: bench_qwen_battery_a119
#
# Runs the qwen-family battery (core/qwen_battery_a119)
# over the banked records, judged per the canonical A-115
# policy, and prints the whole battery, one line per row
# with its verdict and policy obligation, plus the summary
# and the FNV-1a digest. Pure enumeration over filed
# records: no model is executed, no device is opened, and
# no accelerator claim is made -- every row is filed
# NOT_GRADED with a named reason (see the module header).

from core.qwen_battery_a119 import (
    qwen_battery_line,
    qwen_battery_render,
    run_qwen_battery,
)


def main() raises:
    print(qwen_battery_line())
    var report = run_qwen_battery()
    print(qwen_battery_render(report.copy()))
    print("A119_BATTERY_DIGEST", report.digest)
    print("A119_BENCH_DONE rows=", report.total)
