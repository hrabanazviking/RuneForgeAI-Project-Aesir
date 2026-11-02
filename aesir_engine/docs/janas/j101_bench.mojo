"""J-101 filed driver: the `bench` command at the lightest target,
including its --report mode.

Build (from the worktree root, the slices' filed recipe):
    mojo build -I aesir_engine -Xlinker -L<staging> -Xlinker -laesir_par \
        aesir_engine/docs/janas/j101_bench.mojo -o <build>/j101_bench
Run:
    LD_LIBRARY_PATH=<staging> <build>/j101_bench [--settle N] [--rounds N] \
        [--pass prompt|reply|draft-check] [--report]

It calls cli/bench.mojo's bench_main(), which dispatches over the
real argv -- the same dispatch_bench the CLI's commands.mojo routes
`aesir bench` to. With --report it prints the machine report
artefact (core/machine_report.mojo). Timings it prints are harness
mechanics on the machine it runs on, not placement verdicts for
any model; the artefact's per-model cells are filed evidence at
the honesty classes printed on their lines.
"""
from cli.bench import bench_main


def main() raises:
    bench_main()
