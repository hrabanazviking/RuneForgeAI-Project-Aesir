# tests/bench_sliding_window_battery_a123.mojo
# A-123: Sliding-window attention parity -- one-command
# driver.
#
# Usage: bench_sliding_window_battery_a123
#
# Runs the sliding-window battery
# (core/sliding_window_battery_a123): the banked CPU
# kernel judged against an independent reference at
# window-boundary lengths over the SYNTHETIC fixture
# (labelled SYNTHETIC in every line), plus the seeded
# boundary cases, and prints the whole battery with
# the summary and the FNV-1a digest. No real model is
# executed and no accelerator claim is made -- non-CPU
# rows are filed NOT_GRADED (see the module header).

from core.sliding_window_battery_a123 import (
    battery_line,
    battery_render,
    run_battery,
)


def main() raises:
    print(battery_line())
    var report = run_battery()
    print(battery_render(report.copy()))
    print("A123_BATTERY_DIGEST", report.digest)
    print("A123_BENCH_DONE rows=", report.total)
