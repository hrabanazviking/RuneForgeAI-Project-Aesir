# tests/bench_coherence_harness_a127.mojo
# A-127: Coherence grading harness -- one-command
# driver.
#
# Usage: bench_coherence_harness_a127
#
# Runs the coherence harness (core/
# coherence_harness_a127): the 108 IQ matrix score
# rows (every cell NOT_GRADED with a named reason --
# no filed sampled generations exist for any IQ
# cell), plus the SYNTHETIC sanity fixture cases
# (labelled SYNTHETIC in every line: 2 known-good
# pass, 7 known-broken fail with named defects),
# and prints the whole harness with the summaries
# and the FNV-1a digest. No model is executed on
# this machine, no device is opened, and no
# accelerator claim is made -- non-CPU rows are
# filed NOT_GRADED (see the module header).

from core.coherence_harness_a127 import (
    harness_line,
    harness_render,
    run_harness,
)


def main() raises:
    print(harness_line())
    var report = run_harness()
    print(harness_render(report.copy()))
    print("A127_HARNESS_DIGEST", report.digest)
    print("A127_BENCH_DONE rows=", report.total)
