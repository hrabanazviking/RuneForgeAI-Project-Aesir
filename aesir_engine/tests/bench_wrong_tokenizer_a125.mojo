# tests/bench_wrong_tokenizer_a125.mojo
# A-125: Wrong-tokenizer adversarial -- one-command driver.
#
# Usage: bench_wrong_tokenizer_a125
#
# Runs the wrong-tokenizer adversarial battery
# (core/wrong_tokenizer_a125): a 14-case adversarial
# set judged by the banked J-074 compare_tokenizers
# over the full tables (2 verified-identical
# controls admitted, 12 mismatched presentations
# refused with named errors, none silently graded),
# and prints the whole battery with the summary and
# the FNV-1a digest. No model is executed on this
# machine, no device is opened, and no accelerator
# claim is made -- the fixtures are SYNTHETIC and
# the battery proves the load-time gate only (see
# the module header).

from core.wrong_tokenizer_a125 import (
    run_wrong_tokenizer_battery,
    wrong_tokenizer_line,
    wrong_tokenizer_render,
)


def main() raises:
    print(wrong_tokenizer_line())
    var report = run_wrong_tokenizer_battery()
    print(wrong_tokenizer_render(report.copy()))
    print("A125_BATTERY_DIGEST", report.digest)
    print("A125_BENCH_DONE rows=", report.total)
