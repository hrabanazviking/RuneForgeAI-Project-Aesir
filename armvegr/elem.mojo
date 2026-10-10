# H025 — NEON FP16 elementwise family: add, mul, scale, axpy.
#
# All four ops run through ONE fused-loop code path (elem_kernel, mode
# parameter). Fusion points, documented:
#   - F1: the residual add (c = a + b) and the scale (c = a * alpha) share
#     the same 8-wide load/compute/store skeleton; only the ALU op differs.
#   - F2: axpy (c = a * alpha + b) is the add+scale fusion: one pass over
#     memory instead of two, which is how residual blocks will call it.
#   - F3: mul (c = a * b) rides the same path for kernels that gate
#     activations (SwiGLU-style gating arrives in later campaigns).
# Keeping one path means one place to keep numerically honest.

from std.memory import Pointer
from std.origin import MutUntrackedOrigin


def elem_kernel(
    mode: Int,
    a: Pointer[Float16, MutUntrackedOrigin],
    b: Pointer[Float16, MutUntrackedOrigin],
    c: Pointer[Float16, MutUntrackedOrigin],
    alpha: Float16,
    n: Int,
):
    # mode: 0 = add (c = a + b), 1 = mul (c = a * b),
    #       2 = scale (c = a * alpha), 3 = axpy (c = a * alpha + b).
    # For mode 2 the b pointer is ignored; callers may alias b = a.
    var i = 0
    while i + 8 <= n:
        var av = a.unsafe_offset(i).unsafe_load[8]()
        if mode == 0:
            var bv = b.unsafe_offset(i).unsafe_load[8]()
            c.unsafe_store(i, av + bv)
        elif mode == 1:
            var bv = b.unsafe_offset(i).unsafe_load[8]()
            c.unsafe_store(i, av * bv)
        elif mode == 2:
            c.unsafe_store(i, av * alpha)
        else:
            var bv = b.unsafe_offset(i).unsafe_load[8]()
            c.unsafe_store(i, av * alpha + bv)
        i += 8
    for kk in range(i, n):
        var x = a[unsafe_offset=kk]
        if mode == 0:
            c[unsafe_offset=kk] = x + b[unsafe_offset=kk]
        elif mode == 1:
            c[unsafe_offset=kk] = x * b[unsafe_offset=kk]
        elif mode == 2:
            c[unsafe_offset=kk] = x * alpha
        else:
            c[unsafe_offset=kk] = x * alpha + b[unsafe_offset=kk]


def elem_add(
    a: Pointer[Float16, MutUntrackedOrigin],
    b: Pointer[Float16, MutUntrackedOrigin],
    c: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
):
    elem_kernel(0, a, b, c, Float16(0), n)


def elem_mul(
    a: Pointer[Float16, MutUntrackedOrigin],
    b: Pointer[Float16, MutUntrackedOrigin],
    c: Pointer[Float16, MutUntrackedOrigin],
    n: Int,
):
    elem_kernel(1, a, b, c, Float16(0), n)


def elem_scale(
    a: Pointer[Float16, MutUntrackedOrigin],
    c: Pointer[Float16, MutUntrackedOrigin],
    alpha: Float16,
    n: Int,
):
    # b aliased to a (ignored in mode 2); the op still rides the one
    # fused path.
    elem_kernel(2, a, a, c, alpha, n)


def elem_axpy(
    a: Pointer[Float16, MutUntrackedOrigin],
    b: Pointer[Float16, MutUntrackedOrigin],
    c: Pointer[Float16, MutUntrackedOrigin],
    alpha: Float16,
    n: Int,
):
    elem_kernel(3, a, b, c, alpha, n)
