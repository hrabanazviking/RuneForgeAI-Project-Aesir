# tests/bench_moe_battery_a121.mojo
# A-121: MoE battery -- one-command driver.
#
# Usage: bench_moe_battery_a121
#
# Runs the MoE battery (core/moe_battery_a121): the real
# OLMoE routing rows judged from the banked J-016 measured
# trace over the real tensors, plus the SYNTHETIC fixture
# cases (labelled SYNTHETIC in every line), and prints the
# whole battery with the summary and the FNV-1a digest.
# No model is executed on this machine, no device is
# opened, and no accelerator claim is made -- non-CPU rows
# are filed NOT_GRADED (see the module header).

from core.moe_battery_a121 import battery_line, battery_render, run_battery


def main() raises:
    print(battery_line())
    var report = run_battery()
    print(battery_render(report.copy()))
    print("A121_BATTERY_DIGEST", report.digest)
    print("A121_BENCH_DONE rows=", report.total)
