# tests/bench_matrix_a114.mojo
# A-114: The full matrix runner -- one-command driver.
#
# Usage: bench_matrix_a114
#
# Runs the full quant x architecture x backend matrix
# (core/matrix_runner.run_matrix) over the banked A-045 /
# A-109 records under the A-111 gate and prints the whole
# matrix, one line per cell with its verdict, plus the
# summary and the FNV-1a digest. Pure enumeration over
# filed records: no model is executed, no device is
# opened, and no accelerator claim is made -- non-CPU
# cells are filed NOT_GRADED (see the module header).

from core.matrix_runner import matrix_line, matrix_render, run_matrix


def main() raises:
    print(matrix_line())
    var report = run_matrix()
    print(matrix_render(report))
    print("A114_MATRIX_DIGEST", report.digest)
    print("A114_BENCH_DONE cells=", report.total)
