# tests/bench_rope_scaling_battery_a124.mojo
# A-124: RoPE scaling parity -- one-command driver.
#
# Usage: bench_rope_scaling_battery_a124
#
# Runs the RoPE scaling battery (core/
# rope_scaling_battery_a124): the NTK/YaRN-scaled
# long-context ladder rows judged against the filed
# independent reference records, the teacher-forcing
# account (NOT_GRADED, NO_FILED_RECORDS), plus the
# SYNTHETIC defect fixture cases (labelled SYNTHETIC
# in every line), and prints the whole battery with
# the summaries and the FNV-1a digest. No model is
# executed on this machine, no device is opened, and
# no accelerator claim is made -- non-CPU rows are
# filed NOT_GRADED (see the module header).

from core.rope_scaling_battery_a124 import (
    battery_line,
    battery_render,
    run_battery,
)


def main() raises:
    print(battery_line())
    var report = run_battery()
    print(battery_render(report.copy()))
    print("A124_BATTERY_DIGEST", report.digest)
    print("A124_BENCH_DONE rows=", report.total)
