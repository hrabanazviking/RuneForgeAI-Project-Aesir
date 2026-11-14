# tests/bench_attention_battery_a122.mojo
# A-122: Attention variants battery -- one-command driver.
#
# Usage: bench_attention_battery_a122
#
# Runs the attention variants battery
# (core/attention_battery_a122): 4 variants x 19 quants
# x 4 backends = 304 per-variant rows judged from the
# banked A-045/A-109/A-114 records (GQA graded by
# delegation; MHA/MQA/MLA honestly NOT_GRADED), and
# prints the whole battery with the summary and the
# FNV-1a digest. No model is executed on this machine,
# no device is opened, and no accelerator claim is
# made -- non-CPU rows are filed NOT_GRADED (see the
# module header).

from core.attention_battery_a122 import (
    attention_battery_line,
    attention_battery_render,
    run_attention_battery,
)


def main() raises:
    print(attention_battery_line())
    var report = run_attention_battery()
    print(attention_battery_render(report.copy()))
    print("A122_BATTERY_DIGEST", report.digest)
    print("A122_BENCH_DONE rows=", report.total)
