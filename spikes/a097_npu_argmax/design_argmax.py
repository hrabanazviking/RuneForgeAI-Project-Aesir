#
# A-097 -- NPU sampler experiment: single-core argmax over a bf16 logits row.
# Project Aesir, team-27. Derived from the banked A-092 single-core matmul
# design (spikes/a092_npu_hello/design_single_core.py, AMD Apache-2.0) and
# the IRON 1.4.5 kernels.argmax reduction kernel.
#
# One AIE compute tile streams the vocab row in tiles of T bf16 logits and
# emits one 2-word int32 record per tile: (winning value bit-cast, index
# within tile). The host merges the V/T records in order (ties -> lowest
# global index, matching numpy.argmax). Greedy sampling (temperature 0)
# is exactly this argmax; the stochastic path is priced on CPU in the
# companion bench (see docs/bench/A097_NPU_SAMPLER.md).
#
"""Single-core argmax -- IRON API design with ``@iron.jit`` compilation."""

import argparse

import aie.iron as iron
import aie.iron.kernels as kernels
import numpy as np
from ml_dtypes import bfloat16
from aie.helpers.taplib import TensorAccessPattern
from aie.iron import (
    CompileTime,
    In,
    ObjectFifo,
    Out,
    Program,
    Runtime,
    TaskGroup,
    Worker,
    str_to_dtype,
)
from aie.iron.controlflow import range_
from aie.utils.hostruntime.argparse import add_compile_args, add_trace_arg
from aie.utils.hostruntime.cli import run_design_cli
from aie.utils.trace import TraceConfig


@iron.jit
def single_core_argmax(
    A: In,
    C: Out,
    *,
    V: CompileTime[int],
    T: CompileTime[int],
    trace_config: CompileTime[TraceConfig | None] = None,
):
    assert V % T == 0
    tiles = V // T

    argmax_kernel = kernels.argmax(tile_size=T, dtype=np.dtype(bfloat16))

    A_ty = np.ndarray[(V,), np.dtype[bfloat16]]
    C_ty = np.ndarray[(2 * tiles,), np.dtype[np.int32]]
    a_ty = np.ndarray[(T,), np.dtype[bfloat16]]
    c_ty = np.ndarray[(2,), np.dtype[np.int32]]

    inA = ObjectFifo(a_ty, name="inA")
    memA = inA.cons().forward(name="memA")

    memC = ObjectFifo(c_ty, name="memC")
    outC = memC.cons().forward(name="outC")

    def core_fn(of_a, of_c, argmax_k):
        for _ in range_(tiles) if tiles > 1 else range(1):
            elem_in = of_a.acquire(1)
            elem_out = of_c.acquire(1)
            argmax_k(elem_in, elem_out, T, 0)
            of_a.release(1)
            of_c.release(1)

    worker = Worker(
        core_fn,
        [memA.cons(), memC.prod(), argmax_kernel],
        stack_size=0xD00,
        trace=1 if trace_config else 0,
    )

    A_tiles = TensorAccessPattern.full((V,)).tile((T,))
    C_tiles = TensorAccessPattern.full((2 * tiles,)).tile((2,))

    def sequence(A, C, inA_h, outC_h):
        # Groups of 4 tiles: one big group overflows the shim tile's 16
        # buffer descriptors at 16 tiles (V=131072 compile error, A-097).
        per = 4
        for base in range(0, tiles, per):
            hi = min(base + per, tiles)
            tg = TaskGroup()
            for t in range(base, hi):
                inA_h.fill(A, tap=A_tiles[t], group=tg)
            outC_h.drain(C, tap=C_tiles[base:hi], group=tg, wait=True)
            tg.finish()

    rt = Runtime(sequence, [A_ty, C_ty, inA.prod(), outC.cons()])
    prog = Program(iron.get_current_device(), rt, workers=[worker])
    if trace_config:
        prog.enable_trace(trace_config.trace_size, workers=[worker])

    return prog.resolve_program()


def _make_argparser():
    p = argparse.ArgumentParser(prog="AIE Argmax (A-097)")
    add_compile_args(p, short_dev=None)
    p.add_argument("-V", type=int, default=32768)
    p.add_argument("-T", type=int, default=8192)
    add_trace_arg(p, with_short=False)
    return p


def _compile_kwargs(opts):
    return dict(
        V=opts.V,
        T=opts.T,
        trace_config=(
            TraceConfig(trace_size=opts.trace_size) if opts.trace_size > 0 else None
        ),
    )


def main():
    opts = _make_argparser().parse_args()
    run_design_cli(
        single_core_argmax,
        opts,
        compile_kwargs=_compile_kwargs,
    )


if __name__ == "__main__":
    main()
