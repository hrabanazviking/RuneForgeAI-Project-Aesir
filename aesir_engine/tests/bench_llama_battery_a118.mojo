# tests/bench_llama_battery_a118.mojo
# A-118: Llama-family battery -- one-command driver.
#
# Usage: bench_llama_battery_a118
#
# Runs the llama-family battery (core/llama_battery_a118)
# over the banked A-045 / A-109 records, judged per the
# A-115 policy mirror, and prints the whole battery, one
# line per row with its verdict and policy obligation,
# plus the summary and the FNV-1a digest. Pure enumeration
# over filed records: no model is executed, no device is
# opened, and no accelerator claim is made -- non-CPU rows
# are filed NOT_GRADED (see the module header).

from core.llama_battery_a118 import battery_line, battery_render, run_battery


def main() raises:
    print(battery_line())
    var report = run_battery()
    print(battery_render(report.copy()))
    print("A118_BATTERY_DIGEST", report.digest)
    print("A118_BENCH_DONE rows=", report.total)
