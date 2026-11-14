# tests/bench_special_token_battery_a126.mojo
# A-126: Special-token handling -- one-command driver.
#
# Usage: bench_special_token_battery_a126
#
# Runs the special-token battery (core/
# special_token_battery_a126): the per-family
# EOS/BOS/pad rows judged across Z13 backends,
# the stop-reason scenario grid (llama cpu row
# DIVERGENT, STOP_SET_INCOMPLETE), the
# teacher-forcing account (NOT_GRADED,
# NO_FILED_RECORDS), plus the SYNTHETIC defect
# fixture cases (labelled SYNTHETIC in every
# line), and prints the whole battery with the
# summaries and the FNV-1a digest. No model is
# executed on this machine, no device is opened,
# and no accelerator claim is made -- non-CPU
# rows are filed NOT_GRADED (see the module
# header).

# The loader import comes first on purpose: the
# battery module (in core/) imports
# loader.tokenizer, and this tree's Mojo
# package resolution only registers the
# loader package for a core module when the
# entry point imports it directly (the same
# reason core/gemma4_cuda compiles inside
# run_all's import graph but not standalone).
from loader.tokenizer import RuneWeaver
from core.special_token_battery_a126 import (
    battery_line,
    battery_render,
    run_battery,
)


def main() raises:
    print(battery_line())
    var report = run_battery()
    print(battery_render(report.copy()))
    print("A126_BATTERY_DIGEST", report.digest)
    print("A126_BENCH_DONE rows=", report.total)
