# H035 — Multi-head attention orchestration.
#
# The complete attention block as the transformer will call it:
#   Q/K/V projections (via the H023 gemm_fp16) -> RoPE on Q and K (H030)
#   -> per-head fused causal attention (H034) -> output projection.
# Two execution orders are provided over the SAME per-head code path:
#   mha_forward_seq : heads 0..H-1, each writing its slice of a shared
#                     concat buffer (the "sequential" order).
#   mha_forward_par : heads H-1..0, each into a private per-head buffer,
#                     concatenated afterwards (the "head-parallel" order).
# Both are single-threaded in C2; the bit-identical comparison between
# them catches race/shared-buffer bugs before any threading is
# introduced (there is none yet, and the buffers prove it).

from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from std.memory.alloc import unsafe_alloc
from armvegr.gemm import gemm_fp16
from armvegr.rope import rope_fp16
from armvegr.attn import attn_sdpa_causal_fp16


def mha_project(
    x: Pointer[Float16, MutUntrackedOrigin],
    w: Pointer[Float16, MutUntrackedOrigin],
    y: Pointer[Float16, MutUntrackedOrigin],
    seq: Int,
    d_in: Int,
    d_out: Int,
):
    # y[seq, d_out] = x[seq, d_in] @ w[d_in, d_out] via the H023 driver.
    gemm_fp16(x, w, y, seq, d_out, d_in)


def mha_forward_seq(
    x: Pointer[Float16, MutUntrackedOrigin],
    wq: Pointer[Float16, MutUntrackedOrigin],
    wk: Pointer[Float16, MutUntrackedOrigin],
    wv: Pointer[Float16, MutUntrackedOrigin],
    wo: Pointer[Float16, MutUntrackedOrigin],
    outp: Pointer[Float16, MutUntrackedOrigin],
    seq: Int,
    n_heads: Int,
    head_dim: Int,
    theta: Float32,
):
    var d_model = n_heads * head_dim
    var q = unsafe_alloc[Float16](seq * d_model)
    var k = unsafe_alloc[Float16](seq * d_model)
    var vv = unsafe_alloc[Float16](seq * d_model)
    var qr = unsafe_alloc[Float16](seq * d_model)
    var kr = unsafe_alloc[Float16](seq * d_model)
    var ctx = unsafe_alloc[Float16](seq * d_model)
    mha_project(x, wq, q, seq, d_model, d_model)
    mha_project(x, wk, k, seq, d_model, d_model)
    mha_project(x, wv, vv, seq, d_model, d_model)
    for s in range(seq):
        for h in range(n_heads):
            rope_fp16(
                q.unsafe_offset(s * d_model + h * head_dim),
                qr.unsafe_offset(s * d_model + h * head_dim),
                head_dim,
                s,
                theta,
            )
            rope_fp16(
                k.unsafe_offset(s * d_model + h * head_dim),
                kr.unsafe_offset(s * d_model + h * head_dim),
                head_dim,
                s,
                theta,
            )
    # Sequential head order, shared concat buffer.
    # qr/kr/vv are [seq, d_model]; head h must be gathered into a
    # contiguous [seq, head_dim] buffer: attn_sdpa_causal_fp16 indexes
    # row i at i * head_dim, so a strided offset would read the wrong
    # rows for i > 0.
    for h in range(n_heads):
        var qh = unsafe_alloc[Float16](seq * head_dim)
        var kh = unsafe_alloc[Float16](seq * head_dim)
        var vh = unsafe_alloc[Float16](seq * head_dim)
        var oh = unsafe_alloc[Float16](seq * head_dim)
        for s in range(seq):
            for d in range(head_dim):
                qh[unsafe_offset=s * head_dim + d] = qr[
                    unsafe_offset=s * d_model + h * head_dim + d
                ]
                kh[unsafe_offset=s * head_dim + d] = kr[
                    unsafe_offset=s * d_model + h * head_dim + d
                ]
                vh[unsafe_offset=s * head_dim + d] = vv[
                    unsafe_offset=s * d_model + h * head_dim + d
                ]
        _ = attn_sdpa_causal_fp16(qh, kh, vh, oh, seq, head_dim)
        for s in range(seq):
            for d in range(head_dim):
                ctx[unsafe_offset=s * d_model + h * head_dim + d] = oh[
                    unsafe_offset=s * head_dim + d
                ]
    mha_project(ctx, wo, outp, seq, d_model, d_model)


def mha_forward_par(
    x: Pointer[Float16, MutUntrackedOrigin],
    wq: Pointer[Float16, MutUntrackedOrigin],
    wk: Pointer[Float16, MutUntrackedOrigin],
    wv: Pointer[Float16, MutUntrackedOrigin],
    wo: Pointer[Float16, MutUntrackedOrigin],
    outp: Pointer[Float16, MutUntrackedOrigin],
    seq: Int,
    n_heads: Int,
    head_dim: Int,
    theta: Float32,
):
    # Same arithmetic as mha_forward_seq, but heads run in REVERSE order
    # into private per-head buffers, concatenated afterwards. Bit-identical
    # output proves no cross-head contamination through shared buffers.
    var d_model = n_heads * head_dim
    var q = unsafe_alloc[Float16](seq * d_model)
    var k = unsafe_alloc[Float16](seq * d_model)
    var vv = unsafe_alloc[Float16](seq * d_model)
    var qr = unsafe_alloc[Float16](seq * d_model)
    var kr = unsafe_alloc[Float16](seq * d_model)
    var ctx = unsafe_alloc[Float16](seq * d_model)
    mha_project(x, wq, q, seq, d_model, d_model)
    mha_project(x, wk, k, seq, d_model, d_model)
    mha_project(x, wv, vv, seq, d_model, d_model)
    for s in range(seq):
        for h in range(n_heads):
            rope_fp16(
                q.unsafe_offset(s * d_model + h * head_dim),
                qr.unsafe_offset(s * d_model + h * head_dim),
                head_dim,
                s,
                theta,
            )
            rope_fp16(
                k.unsafe_offset(s * d_model + h * head_dim),
                kr.unsafe_offset(s * d_model + h * head_dim),
                head_dim,
                s,
                theta,
            )
    var h = n_heads - 1
    while h >= 0:
        var qh = unsafe_alloc[Float16](seq * head_dim)
        var kh = unsafe_alloc[Float16](seq * head_dim)
        var vh = unsafe_alloc[Float16](seq * head_dim)
        var oh = unsafe_alloc[Float16](seq * head_dim)
        for s in range(seq):
            for d in range(head_dim):
                qh[unsafe_offset=s * head_dim + d] = qr[
                    unsafe_offset=s * d_model + h * head_dim + d
                ]
                kh[unsafe_offset=s * head_dim + d] = kr[
                    unsafe_offset=s * d_model + h * head_dim + d
                ]
                vh[unsafe_offset=s * head_dim + d] = vv[
                    unsafe_offset=s * d_model + h * head_dim + d
                ]
        _ = attn_sdpa_causal_fp16(qh, kh, vh, oh, seq, head_dim)
        for s in range(seq):
            for d in range(head_dim):
                ctx[unsafe_offset=s * d_model + h * head_dim + d] = oh[
                    unsafe_offset=s * head_dim + d
                ]
        h -= 1
    mha_project(ctx, wo, outp, seq, d_model, d_model)
