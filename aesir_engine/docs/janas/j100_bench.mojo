"""J-100 filed driver: the `bench` command at the lightest target.

Build (from the worktree root, the slices' filed recipe):
    mojo build -I aesir_engine -Xlinker -L<staging> -Xlinker -laesir_par \
        aesir_engine/docs/janas/j100_bench.mojo -o <build>/j100_bench
Run:
    LD_LIBRARY_PATH=<staging> <build>/j100_bench [--settle N] [--rounds N] \
        [--pass prompt|reply|draft-check]

It calls cli/bench.mojo's bench_main(), which dispatches over the
real argv -- the same dispatch_bench the CLI's commands.mojo routes
`aesir bench` to. Timings it prints are harness mechanics on the
machine it runs on, not placement verdicts for any model.
"""
from cli.bench import bench_main


def main() raises:
    bench_main()
