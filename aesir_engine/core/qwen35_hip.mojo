# core/qwen35_hip.mojo
# Qwen35HipExecutor: HIP execution for the qwen35 hybrid (slice Q35-6a).
#
# Shape follows the established Llama3CUDASession HIP road
# (core/llama3_cuda.mojo): ONE persistent DeviceContext(api="hip"),
# ONE device weights buffer holding the whole GGUF file image
# (uploaded once through core/cuda_upload), device-resident f32
# activation / KV / SSM-state buffers, and Mojo-native kernels
# launched on the context's ordered stream. The Q8_0 GEMV kernel
# body is the A-082 kernel (core/hip_gemv.mojo) verbatim in shape:
# one thread per output row, per-block fp16 scale x int8 x f32
# activation accumulated in sequential k order; A-082's own filed
# lesson (context creation ~13-16 ms per call) is why this executor
# keeps ONE context and resident buffers instead of dispatching
# through the per-call HipGemv gateway.
#
# Numerics contract vs the CPU path (core/inference.mojo Q35-3a):
# the CPU path stores every intermediate as f16, so every kernel
# here that produces a value the CPU path would store in an f16
# tensor rounds its output through f16 before storing it into the
# f32 activation buffers. The SSM state (s + conv rings) is f32 on
# BOTH paths and is never rounded. Small tensors the CPU loader
# converts F32->F16 at load (norms, ssm_a, dt_bias, conv1d,
# ssm_norm) are read through packed_value and f16-rounded in-kernel
# when stored F32, so the device sees the same values the CPU sees.
# Remaining legitimate differences: GEMM accumulation order and
# libm exp/sqrt precision. Graded in the Q35-6 test against the
# Q35-3a (c) band, with teacher-forcing rank + logit gap as the
# fallback grade (Aesir comparator discipline).
#
# Admission: the executor REQUIRES every large qwen35 weight to be
# stored Q8_0 (the Q35-3r resident contract, checked by name at
# construction; no F16 materialization anywhere). Fail-closed like
# A-082: HIP gate not satisfied => raise, no host fallback.

from std.gpu import global_idx
from std.memory import Pointer
from std.math import sqrt, exp, log, cos, sin
from max.gpu.host import DeviceContext, DeviceBuffer, HostBuffer
from loader.packed_gguf import PackedGGUF, PackedTensor
from core.packed_quantization import Bytes, packed_value
from core.qwen35_profile import Qwen35Profile, qwen35_profile_for, validate_qwen35
from core.hip_gemv import HipGemv
from core.cuda_upload import upload_cuda_bytes

comptime Floats = Pointer[Float32, MutUntrackedOrigin]
comptime Ints = Pointer[Int32, MutUntrackedOrigin]


@fieldwise_init
struct Q35TensorRef(Copyable, ImplicitlyCopyable, Movable):
    var base: Int
    var kind: Int
    var rows: Int
    var cols: Int


def _f16r(v: Float32) -> Float32:
    return Float16(v).cast[DType.float32]()


def _small_value(w: Bytes, base: Int, kind: Int, idx: Int) -> Float32:
    var v = packed_value(w, base, kind, idx)
    if kind == 0:
        return _f16r(v)
    return v


def _sigmoid(x: Float32) -> Float32:
    return Float32(1.0) / (Float32(1.0) + exp(-x))


def _softplus(x: Float32) -> Float32:
    if x > Float32(20.0):
        return x
    return log(Float32(1.0) + exp(x))


def _q8_gemm_kernel(w: Bytes, a: Floats, base_arg: Int64, rows_arg: Int64, cols_arg: Int64, src_arg: Int64, dst_arg: Int64, batch_arg: Int64):
    """y[b, r] = sum_k dequant Q8_0(w[r, k]) * a[b, k], f16-rounded
    on store (the CPU gemm_f16 output store). One thread per
    (b, r); sequential block/k order like A-082."""
    var base = Int(base_arg)
    var rows = Int(rows_arg)
    var cols = Int(cols_arg)
    var src = Int(src_arg)
    var dst = Int(dst_arg)
    var idx = Int(global_idx.x)
    if idx < Int(batch_arg) * rows:
        var b = idx // rows
        var row = idx % rows
        var blocks = cols // 32
        var wf = w.unsafe_offset(base).unsafe_bitcast[Scalar[DType.float16]]()
        var acc: Float32 = 0.0
        for blk in range(blocks):
            var gblk = row * blocks + blk
            var scale = wf.unsafe_load(gblk * 17).cast[DType.float32]()
            var bbase = gblk * 34 + 2
            var k0 = blk * 32
            for lane in range(32):
                var raw = Int(w.unsafe_offset(base).unsafe_load(bbase + lane))
                var q = raw - 256 if raw >= 128 else raw
                acc += scale * Float32(q) * a.unsafe_load(src + b * cols + k0 + lane)
        a.unsafe_store(dst + b * rows + row, _f16r(acc))


def _embed_kernel(w: Bytes, a: Floats, toks: Ints, base_arg: Int64, width_arg: Int64, dst_arg: Int64, batch_arg: Int64):
    """x[b, i] = dequant Q8_0 token_embd row toks[b], f16-rounded
    (the CPU _embed_token_into Q8_0 branch; no arch scale for
    qwen35 -- the CPU scale branch is Gemma-only metadata)."""
    var base = Int(base_arg)
    var width = Int(width_arg)
    var dst = Int(dst_arg)
    var idx = Int(global_idx.x)
    if idx < Int(batch_arg) * width:
        var b = idx // width
        var i = idx % width
        var token = Int(toks.unsafe_load(b))
        var blocks = width // 32
        var blk = i // 32
        var lane = i % 32
        var gblk = token * blocks + blk
        var wf = w.unsafe_offset(base).unsafe_bitcast[Scalar[DType.float16]]()
        var scale = wf.unsafe_load(gblk * 17).cast[DType.float32]()
        var raw = Int(w.unsafe_offset(base).unsafe_load(gblk * 34 + 2 + lane))
        var q = raw - 256 if raw >= 128 else raw
        a.unsafe_store(dst + b * width + i, _f16r(scale * Float32(q)))


def _rmsnorm_kernel(w: Bytes, a: Floats, weight_arg: Int64, kind_arg: Int64, width_arg: Int64, src_arg: Int64, dst_arg: Int64, batch_arg: Int64, eps: Float32):
    """Per-row RMSNorm over width, in place allowed (src == dst):
    reads the row fully before storing. Weight via _small_value.
    One thread per row (sequential reduction, CPU order)."""
    var weight = Int(weight_arg)
    var kind = Int(kind_arg)
    var width = Int(width_arg)
    var src = Int(src_arg)
    var dst = Int(dst_arg)
    var b = Int(global_idx.x)
    if b < Int(batch_arg):
        var ss: Float32 = 0.0
        for i in range(width):
            var v = a.unsafe_load(src + b * width + i)
            ss += v * v
        var scale = Float32(1.0) / sqrt(ss / Float32(width) + eps)
        for i in range(width):
            var v = a.unsafe_load(src + b * width + i) * scale * _small_value(w, weight, kind, i)
            a.unsafe_store(dst + b * width + i, _f16r(v))


def _head_norm_kernel(w: Bytes, a: Floats, weight_arg: Int64, kind_arg: Int64, head_dim_arg: Int64, heads_arg: Int64, src_arg: Int64, batch_arg: Int64, eps: Float32):
    """Per-(row, head) RMSNorm over head_dim, in place (the CPU
    Qwen35Block._head_rmsnorm). One thread per (b, head)."""
    var weight = Int(weight_arg)
    var kind = Int(kind_arg)
    var hd = Int(head_dim_arg)
    var src = Int(src_arg)
    var idx = Int(global_idx.x)
    if idx < Int(batch_arg) * Int(heads_arg):
        var base = src + idx * hd
        var ss: Float32 = 0.0
        for d in range(hd):
            var v = a.unsafe_load(base + d)
            ss += v * v
        var scale = Float32(1.0) / sqrt(ss / Float32(hd) + eps)
        for d in range(hd):
            var v = a.unsafe_load(base + d) * scale * _small_value(w, weight, kind, d)
            a.unsafe_store(base + d, _f16r(v))


def _rope_kernel(a: Floats, width_arg: Int64, heads_arg: Int64, head_dim_arg: Int64, rope_dims_arg: Int64, src_arg: Int64, pos_arg: Int64, batch_arg: Int64, theta: Float32):
    """Partial NEOX RoPE (CPU apply_rope_partial_neox): pairs
    (i, i + rope_dims/2) for i < rope_dims/2 at position
    pos + b; dims >= rope_dims pass through. cos/sin f16-rounded
    and the rotation result f16-rounded, as the CPU stores."""
    var width = Int(width_arg)
    var hd = Int(head_dim_arg)
    var rope_dims = Int(rope_dims_arg)
    var src = Int(src_arg)
    var half = rope_dims // 2
    var idx = Int(global_idx.x)
    var total = Int(batch_arg) * Int(heads_arg) * half
    if idx < total:
        var i = idx % half
        var h = (idx // half) % Int(heads_arg)
        var b = idx // (half * Int(heads_arg))
        var freq = Float32(1.0) / exp(log(theta) * Float32(2 * i) / Float32(rope_dims))
        var val = Float32(Int(pos_arg) + b) * freq
        var fcr = _f16r(cos(val))
        var fci = _f16r(sin(val))
        var base = src + b * width + h * hd
        var q0 = a.unsafe_load(base + i)
        var q1 = a.unsafe_load(base + i + half)
        a.unsafe_store(base + i, _f16r(q0 * fcr - q1 * fci))
        a.unsafe_store(base + i + half, _f16r(q0 * fci + q1 * fcr))


def _kv_store_kernel(a: Floats, kv: Floats, kv_width_arg: Int64, src_arg: Int64, layer_base_arg: Int64, pos_arg: Int64, ctx_arg: Int64, batch_arg: Int64):
    """Copy one of K/V (src rows) into the KV buffer at
    [layer_base + (pos + b) * kv_width]. Values are already
    f16-rounded in the activation buffer; the CPU cache stores
    f16, so the stored f32 here carries the identical value."""
    var kvw = Int(kv_width_arg)
    var src = Int(src_arg)
    var layer_base = Int(layer_base_arg)
    var idx = Int(global_idx.x)
    if idx < Int(batch_arg) * kvw:
        var b = idx // kvw
        var i = idx % kvw
        kv.unsafe_store(layer_base + (Int(pos_arg) + b) * kvw + i, a.unsafe_load(src + b * kvw + i))


def _attention_kernel(a: Floats, kv: Floats, q_arg: Int64, att_arg: Int64, k_base_arg: Int64, v_base_arg: Int64, ctx_arg: Int64, pos_arg: Int64, batch_arg: Int64, heads_arg: Int64, kv_heads_arg: Int64, head_dim_arg: Int64):
    """Causal GQA attention for decode rows: thread per
    (b, q_head, d); online softmax over positions [0, pos + b]
    in f32 (the CPU flash_attention_gqa reduction class), output
    f16-rounded. scale = 1/sqrt(head_dim) (CPU default)."""
    var hd = Int(head_dim_arg)
    var heads = Int(heads_arg)
    var kv_heads = Int(kv_heads_arg)
    var ctx = Int(ctx_arg)
    var idx = Int(global_idx.x)
    if idx < Int(batch_arg) * heads * hd:
        var d = idx % hd
        var h = (idx // hd) % heads
        var b = idx // (hd * heads)
        var kvh = h // (heads // kv_heads)
        var seq = Int(pos_arg) + b + 1
        var qbase = Int(q_arg) + b * heads * hd + h * hd
        var scale = Float32(1.0) / sqrt(Float32(hd))
        var m: Float32 = -1e30
        var l: Float32 = 0.0
        var acc: Float32 = 0.0
        for p in range(seq):
            var kbase = Int(k_base_arg) + p * kv_heads * hd + kvh * hd
            var score: Float32 = 0.0
            for j in range(hd):
                score += a.unsafe_load(qbase + j) * kv.unsafe_load(kbase + j)
            score *= scale
            var vval = kv.unsafe_load(Int(v_base_arg) + p * kv_heads * hd + kvh * hd + d)
            if score > m:
                var rescale = exp(m - score) if l > Float32(0.0) else Float32(0.0)
                acc = acc * rescale + vval
                l = l * rescale + Float32(1.0)
                m = score
            else:
                var wgt = exp(score - m)
                acc += wgt * vval
                l += wgt
        a.unsafe_store(Int(att_arg) + b * heads * hd + h * hd + d, _f16r(acc / l))


def _split_q_gate_kernel(a: Floats, qf_arg: Int64, q_arg: Int64, gate_arg: Int64, q_width_arg: Int64, head_dim_arg: Int64, batch_arg: Int64):
    """q_full rows are [q_head | gate_head] pairs per head (CPU
    full-attention branch split)."""
    var qw = Int(q_width_arg)
    var hd = Int(head_dim_arg)
    var idx = Int(global_idx.x)
    if idx < Int(batch_arg) * qw:
        var b = idx // qw
        var i = idx % qw
        var h = i // hd
        var d = i % hd
        var src = Int(qf_arg) + b * 2 * qw + h * 2 * hd
        a.unsafe_store(Int(q_arg) + b * qw + i, a.unsafe_load(src + d))
        a.unsafe_store(Int(gate_arg) + b * qw + i, a.unsafe_load(src + hd + d))


def _gate_mul_kernel(a: Floats, att_arg: Int64, gate_arg: Int64, count_arg: Int64):
    """att[i] = f16(att[i] * sigmoid(gate[i])) (CPU gated output)."""
    var idx = Int(global_idx.x)
    if idx < Int(count_arg):
        var v = a.unsafe_load(Int(att_arg) + idx) * _sigmoid(a.unsafe_load(Int(gate_arg) + idx))
        a.unsafe_store(Int(att_arg) + idx, _f16r(v))


def _add_kernel(a: Floats, dst_arg: Int64, src_arg: Int64, count_arg: Int64):
    """dst[i] = f16(dst[i] + src[i]) (CPU residual add store)."""
    var idx = Int(global_idx.x)
    if idx < Int(count_arg):
        a.unsafe_store(Int(dst_arg) + idx, _f16r(a.unsafe_load(Int(dst_arg) + idx) + a.unsafe_load(Int(src_arg) + idx)))


def _silu_mul_kernel(a: Floats, gate_arg: Int64, up_arg: Int64, count_arg: Int64):
    """up[i] = f16(silu_f16(gate[i]) * up[i]) (CPU SwiGLU pair:
    silu stored f16 first, then the product stored f16)."""
    var idx = Int(global_idx.x)
    if idx < Int(count_arg):
        var g = a.unsafe_load(Int(gate_arg) + idx)
        var s = _f16r(g * _sigmoid(g))
        a.unsafe_store(Int(up_arg) + idx, _f16r(s * a.unsafe_load(Int(up_arg) + idx)))


def _copy_kernel(a: Floats, dst_arg: Int64, src_arg: Int64, count_arg: Int64):
    var idx = Int(global_idx.x)
    if idx < Int(count_arg):
        a.unsafe_store(Int(dst_arg) + idx, a.unsafe_load(Int(src_arg) + idx))


def _conv_silu_kernel(w: Bytes, a: Floats, st: Floats, convw_arg: Int64, kind_arg: Int64, qkv_arg: Int64, conv_arg: Int64, ring_arg: Int64, conv_dim_arg: Int64, kernel_arg: Int64, row_arg: Int64):
    """Causal depthwise conv1d + SiLU for ONE row (the ring is
    sequential state): conv[c] = f16(silu(f16(sum_tap w[c, tap] *
    sample_tap))) with samples from the f32 ring (previous raw
    qkv rows, exactly as the CPU stores them) and the current
    qkv row as the last tap."""
    var convw = Int(convw_arg)
    var kind = Int(kind_arg)
    var conv_dim = Int(conv_dim_arg)
    var kernel = Int(kernel_arg)
    var c = Int(global_idx.x)
    if c < conv_dim:
        var acc: Float32 = 0.0
        for tap in range(kernel):
            var kval = _small_value(w, convw, kind, c * kernel + tap)
            var sample: Float32
            if tap < kernel - 1:
                sample = st.unsafe_load(Int(ring_arg) + tap * conv_dim + c)
            else:
                sample = a.unsafe_load(Int(qkv_arg) + Int(row_arg) * conv_dim + c)
            acc += kval * sample
        var v = _f16r(acc)
        a.unsafe_store(Int(conv_arg) + Int(row_arg) * conv_dim + c, _f16r(v * _sigmoid(v)))


def _ring_shift_stage_kernel(a: Floats, st: Floats, tmp: Floats, qkv_arg: Int64, ring_arg: Int64, conv_dim_arg: Int64, kernel_arg: Int64, row_arg: Int64):
    """Stage the shifted ring into tmp (Q35-6 D2 fix): tap t of
    tmp = old ring tap t+1, newest tap = the current raw qkv
    row. The inherited kernel shifted IN PLACE in one parallel
    launch -- thread tap t read slot t+1 while thread tap t+1
    stored into it (launch-order dependent corruption; the CPU
    shifts sequentially, inference.mojo conv block). Staging
    through a separate buffer makes every read precede every
    write; _ring_commit_kernel then copies tmp back."""
    var conv_dim = Int(conv_dim_arg)
    var kernel = Int(kernel_arg)
    var idx = Int(global_idx.x)
    if idx < (kernel - 1) * conv_dim:
        var tap = idx // conv_dim
        var c = idx % conv_dim
        var ring = Int(ring_arg)
        if tap < kernel - 2:
            tmp.unsafe_store(tap * conv_dim + c, st.unsafe_load(ring + (tap + 1) * conv_dim + c))
        else:
            tmp.unsafe_store(tap * conv_dim + c, a.unsafe_load(Int(qkv_arg) + Int(row_arg) * conv_dim + c))


def _ring_commit_kernel(st: Floats, tmp: Floats, ring_arg: Int64, count_arg: Int64):
    var idx = Int(global_idx.x)
    if idx < Int(count_arg):
        st.unsafe_store(Int(ring_arg) + idx, tmp.unsafe_load(idx))


def _l2norm_kernel(a: Floats, conv_arg: Int64, conv_dim_arg: Int64, qk_band_arg: Int64, d_state_arg: Int64, groups_arg: Int64, row_arg: Int64):
    """L2-normalize the q and k group bands of one conv row in
    place (CPU: scale = 1/sqrt(sum + 1e-6), stored f16). One
    thread per group."""
    var conv_dim = Int(conv_dim_arg)
    var qk_band = Int(qk_band_arg)
    var d_state = Int(d_state_arg)
    var g = Int(global_idx.x)
    if g < Int(groups_arg):
        var base = Int(conv_arg) + Int(row_arg) * conv_dim
        var q_off = g * d_state
        var k_off = qk_band + g * d_state
        var qn: Float32 = 0.0
        var kn: Float32 = 0.0
        for d in range(d_state):
            var qv = a.unsafe_load(base + q_off + d)
            var kv = a.unsafe_load(base + k_off + d)
            qn += qv * qv
            kn += kv * kv
        var qs = Float32(1.0) / sqrt(qn + Float32(1e-6))
        var ks = Float32(1.0) / sqrt(kn + Float32(1e-6))
        for d in range(d_state):
            a.unsafe_store(base + q_off + d, _f16r(a.unsafe_load(base + q_off + d) * qs))
            a.unsafe_store(base + k_off + d, _f16r(a.unsafe_load(base + k_off + d) * ks))


def _delta_kernel(w: Bytes, a: Floats, st: Floats, ssm_a_arg: Int64, kind_arg: Int64, conv_arg: Int64, alpha_arg: Int64, beta_arg: Int64, dt_bias_arg: Int64, scr_arg: Int64, s_base_arg: Int64, conv_dim_arg: Int64, qk_band_arg: Int64, d_state_arg: Int64, v_heads_arg: Int64, groups_arg: Int64, row_arg: Int64):
    """Gated delta-rule recurrence for one row, thread per
    (v_head, j): the j-th state column is independent given the
    row's q/k/v, so decay -> mem -> delta -> rank-1 update ->
    readout run per column in exactly the CPU's per-column f32
    order. s is f32 and never rounded (both paths). The readout
    (times 1/sqrt(d_state), the CPU head_scale) lands in the
    scratch row for the gated-norm kernel."""
    var d_state = Int(d_state_arg)
    var qk_band = Int(qk_band_arg)
    var conv_dim = Int(conv_dim_arg)
    var row = Int(row_arg)
    var idx = Int(global_idx.x)
    if idx < Int(v_heads_arg) * d_state:
        var vh = idx // d_state
        var j = idx % d_state
        var g = vh % Int(groups_arg)  # Q35-3b U1: ggml broadcasts q/k TILED (g = vh % groups), inference.mojo:2511; the contiguous vh // v_per_group was the pre-U1 mirror defect (Q35-6 D1)
        var q_off = g * d_state
        var k_off = qk_band + g * d_state
        var v_off = 2 * qk_band + vh * d_state
        var cbase = Int(conv_arg) + row * conv_dim
        var a_val = _small_value(w, Int(ssm_a_arg), Int(kind_arg), vh)
        var dt = _softplus(a.unsafe_load(Int(alpha_arg) + row * Int(v_heads_arg) + vh) + _small_value(w, Int(dt_bias_arg), Int(kind_arg), vh))
        var decay = exp(a_val * dt)
        var beta = _sigmoid(a.unsafe_load(Int(beta_arg) + row * Int(v_heads_arg) + vh))
        var s_head = Int(s_base_arg) + vh * d_state * d_state
        for i in range(d_state):
            var idxi = s_head + i * d_state + j
            st.unsafe_store(idxi, st.unsafe_load(idxi) * decay)
        var mem: Float32 = 0.0
        for i in range(d_state):
            mem += st.unsafe_load(s_head + i * d_state + j) * a.unsafe_load(cbase + k_off + i)
        var delta = (a.unsafe_load(cbase + v_off + j) - mem) * beta
        for i in range(d_state):
            var idxi = s_head + i * d_state + j
            st.unsafe_store(idxi, st.unsafe_load(idxi) + a.unsafe_load(cbase + k_off + i) * delta)
        var acc: Float32 = 0.0
        for i in range(d_state):
            acc += st.unsafe_load(s_head + i * d_state + j) * a.unsafe_load(cbase + q_off + i)
        var head_scale = Float32(1.0) / sqrt(Float32(d_state))
        a.unsafe_store(Int(scr_arg) + (row * Int(v_heads_arg) + vh) * d_state + j, acc * head_scale)


def _gated_norm_kernel(w: Bytes, a: Floats, normw_arg: Int64, kind_arg: Int64, scr_arg: Int64, z_arg: Int64, y_arg: Int64, d_state_arg: Int64, v_heads_arg: Int64, row_arg: Int64, eps: Float32):
    """Per-v-head RMSNorm of the readout, gated by silu(z)
    (CPU: norm in f32 over the readout, times ssm_norm weight,
    times silu(z), stored f16). One thread per v-head."""
    var d_state = Int(d_state_arg)
    var row = Int(row_arg)
    var vh = Int(global_idx.x)
    if vh < Int(v_heads_arg):
        var sbase = Int(scr_arg) + (row * Int(v_heads_arg) + vh) * d_state
        var mean: Float32 = 0.0
        for d in range(d_state):
            var v = a.unsafe_load(sbase + d)
            mean += v * v
        var nscale = Float32(1.0) / sqrt(mean / Float32(d_state) + eps)
        for d in range(d_state):
            var v = a.unsafe_load(sbase + d) * nscale
            var wgt = _small_value(w, Int(normw_arg), Int(kind_arg), d)
            var zg = a.unsafe_load(Int(z_arg) + row * Int(v_heads_arg) * d_state + vh * d_state + d)
            var silu_z = zg / (Float32(1.0) + exp(-zg))
            a.unsafe_store(Int(y_arg) + row * Int(v_heads_arg) * d_state + vh * d_state + d, _f16r(v * wgt * silu_z))


def _zero_kernel(p: Floats, count_arg: Int64):
    var idx = Int(global_idx.x)
    if idx < Int(count_arg):
        p.unsafe_store(idx, Float32(0.0))


struct Q35HipLayer(Copyable, Movable):
    var is_full_attn: Bool
    var ssm_slot: Int
    var attn_slot: Int
    var attn_norm: Q35TensorRef
    var post_attn_norm: Q35TensorRef
    var ffn_gate: Q35TensorRef
    var ffn_up: Q35TensorRef
    var ffn_down: Q35TensorRef
    var q: Q35TensorRef
    var k: Q35TensorRef
    var v: Q35TensorRef
    var o: Q35TensorRef
    var q_norm: Q35TensorRef
    var k_norm: Q35TensorRef
    var qkv: Q35TensorRef
    var gate: Q35TensorRef
    var alpha: Q35TensorRef
    var beta: Q35TensorRef
    var ssm_a: Q35TensorRef
    var dt_bias: Q35TensorRef
    var conv1d: Q35TensorRef
    var ssm_norm: Q35TensorRef
    var ssm_out: Q35TensorRef

    def __init__(out self, is_full_attn: Bool, ssm_slot: Int, attn_slot: Int):
        self.is_full_attn = is_full_attn
        self.ssm_slot = ssm_slot
        self.attn_slot = attn_slot
        var empty = Q35TensorRef(-1, -1, 0, 0)
        self.attn_norm = empty
        self.post_attn_norm = empty
        self.ffn_gate = empty
        self.ffn_up = empty
        self.ffn_down = empty
        self.q = empty
        self.k = empty
        self.v = empty
        self.o = empty
        self.q_norm = empty
        self.k_norm = empty
        self.qkv = empty
        self.gate = empty
        self.alpha = empty
        self.beta = empty
        self.ssm_a = empty
        self.dt_bias = empty
        self.conv1d = empty
        self.ssm_norm = empty
        self.ssm_out = empty



def _ref_of(model: PackedGGUF, name: String) raises -> Q35TensorRef:
    if name not in model.tensors:
        raise Error("Qwen35HipExecutor: missing required tensor '" + name + "'")
    var t = model.tensors[name]
    return Q35TensorRef(t.offset, t.kind, t.rows, t.columns)


def _require_q8_of(model: PackedGGUF, name: String) raises:
    var t = model.tensors[name]
    if t.kind != 8:
        raise Error("Qwen35HipExecutor: HIP load refused tensor '" + name + "': stored GGML type " + String(t.kind) + " is not Q8_0 (8); the HIP path consumes the Q35-3r resident packed views and never materializes F16 weights")
    if t.columns % 32 != 0:
        raise Error("Qwen35HipExecutor: HIP load refused tensor '" + name + "': input width is not a multiple of 32")

struct Qwen35HipExecutor:
    """Device-resident qwen35 forward over one HIP context.
    Weights, activations, KV and the SSM state (s + conv rings)
    all live on the device across tokens; the host reads back
    only logits (per forward) and state/KV (snapshot + proof
    seams). See the file header for the numerics contract."""

    var model: PackedGGUF
    var profile: Qwen35Profile
    var layers: List[Q35HipLayer]
    var context: DeviceContext
    var weights: DeviceBuffer[DType.uint8]
    var acts: DeviceBuffer[DType.float32]
    var kv_buf: DeviceBuffer[DType.float32]
    var state_buf: DeviceBuffer[DType.float32]
    var ring_tmp: DeviceBuffer[DType.float32]
    var toks: DeviceBuffer[DType.int32]
    var host_toks: HostBuffer[DType.int32]
    var host_acts: HostBuffer[DType.float32]
    var host_state: HostBuffer[DType.float32]
    var host_kv: HostBuffer[DType.float32]
    var embd: Q35TensorRef
    var out_w: Q35TensorRef
    var out_norm: Q35TensorRef
    var context_length: Int
    var max_batch: Int
    var o_x: Int
    var o_res: Int
    var o_qkv: Int
    var o_z: Int
    var o_alpha: Int
    var o_beta: Int
    var o_conv: Int
    var o_y: Int
    var o_qf: Int
    var o_q: Int
    var o_gate: Int
    var o_k: Int
    var o_v: Int
    var o_att: Int
    var o_fg: Int
    var o_fu: Int
    var o_logits: Int
    var o_scr: Int
    var s_elems: Int
    var ring_elems: Int
    var kv_elems: Int

    def __init__(out self, path: String, context_length: Int, max_batch: Int = 32) raises:
        if not HipGemv.gate_ok():
            raise Error("GPU-002 DEVICE_NOT_FOUND: Qwen35HipExecutor: HIP gate (A-010-A-012) not satisfied - runtime absent, device count != 1, or device is not gfx1151 (honest-absent / wrong-device refused)")
        self.model = PackedGGUF(path)
        self.profile = qwen35_profile_for(self.model)
        validate_qwen35(self.model, self.profile, context_length)
        if context_length < 2 or context_length > self.profile.context_cap:
            raise Error("Qwen35HipExecutor: context_length outside the profile cap")
        self.context_length = context_length
        self.max_batch = max_batch
        ref p = self.profile
        self.embd = _ref_of(self.model, "token_embd.weight")
        self.out_w = _ref_of(self.model, "output.weight")
        self.out_norm = _ref_of(self.model, "output_norm.weight")
        _require_q8_of(self.model, "token_embd.weight")
        _require_q8_of(self.model, "output.weight")
        self.layers = List[Q35HipLayer]()
        var ssm_slot = 0
        var attn_slot = 0
        for li in range(p.layer_count):
            var full = p.is_full_attention(li)
            var layer = Q35HipLayer(full, -1 if full else ssm_slot, attn_slot if full else -1)
            if full:
                attn_slot += 1
            else:
                ssm_slot += 1
            var prefix = String("blk.") + String(li) + String(".")
            layer.attn_norm = _ref_of(self.model, prefix + "attn_norm.weight")
            layer.post_attn_norm = _ref_of(self.model, prefix + "post_attention_norm.weight")
            layer.ffn_gate = _ref_of(self.model, prefix + "ffn_gate.weight")
            layer.ffn_up = _ref_of(self.model, prefix + "ffn_up.weight")
            layer.ffn_down = _ref_of(self.model, prefix + "ffn_down.weight")
            _require_q8_of(self.model, prefix + "ffn_gate.weight")
            _require_q8_of(self.model, prefix + "ffn_up.weight")
            _require_q8_of(self.model, prefix + "ffn_down.weight")
            if full:
                layer.q = _ref_of(self.model, prefix + "attn_q.weight")
                layer.k = _ref_of(self.model, prefix + "attn_k.weight")
                layer.v = _ref_of(self.model, prefix + "attn_v.weight")
                layer.o = _ref_of(self.model, prefix + "attn_output.weight")
                layer.q_norm = _ref_of(self.model, prefix + "attn_q_norm.weight")
                layer.k_norm = _ref_of(self.model, prefix + "attn_k_norm.weight")
                _require_q8_of(self.model, prefix + "attn_q.weight")
                _require_q8_of(self.model, prefix + "attn_k.weight")
                _require_q8_of(self.model, prefix + "attn_v.weight")
                _require_q8_of(self.model, prefix + "attn_output.weight")
            else:
                layer.qkv = _ref_of(self.model, prefix + "attn_qkv.weight")
                layer.gate = _ref_of(self.model, prefix + "attn_gate.weight")
                layer.alpha = _ref_of(self.model, prefix + "ssm_alpha.weight")
                layer.beta = _ref_of(self.model, prefix + "ssm_beta.weight")
                layer.ssm_a = _ref_of(self.model, prefix + "ssm_a")
                layer.dt_bias = _ref_of(self.model, prefix + "ssm_dt.bias")
                layer.conv1d = _ref_of(self.model, prefix + "ssm_conv1d.weight")
                layer.ssm_norm = _ref_of(self.model, prefix + "ssm_norm.weight")
                layer.ssm_out = _ref_of(self.model, prefix + "ssm_out.weight")
                _require_q8_of(self.model, prefix + "attn_qkv.weight")
                _require_q8_of(self.model, prefix + "attn_gate.weight")
                _require_q8_of(self.model, prefix + "ssm_alpha.weight")
                _require_q8_of(self.model, prefix + "ssm_beta.weight")
                _require_q8_of(self.model, prefix + "ssm_out.weight")
            self.layers.append(layer^)
        # Activation layout (f32 elements, batch-major rows).
        var b = max_batch
        var hidden = p.hidden_size
        var cursor = 0
        self.o_x = cursor; cursor += b * hidden
        self.o_res = cursor; cursor += b * hidden
        self.o_qkv = cursor; cursor += b * p.qkv_width()
        self.o_z = cursor; cursor += b * p.ssm_inner_size
        self.o_alpha = cursor; cursor += b * p.ssm_time_step_rank
        self.o_beta = cursor; cursor += b * p.ssm_time_step_rank
        self.o_conv = cursor; cursor += b * p.qkv_width()
        self.o_y = cursor; cursor += b * p.ssm_inner_size
        self.o_qf = cursor; cursor += b * 2 * p.query_width()
        self.o_q = cursor; cursor += b * p.query_width()
        self.o_gate = cursor; cursor += b * p.query_width()
        self.o_k = cursor; cursor += b * p.kv_width()
        self.o_v = cursor; cursor += b * p.kv_width()
        self.o_att = cursor; cursor += b * p.query_width()
        self.o_fg = cursor; cursor += b * p.feed_forward_size
        self.o_fu = cursor; cursor += b * p.feed_forward_size
        self.o_logits = cursor; cursor += p.vocabulary_size
        self.o_scr = cursor; cursor += b * p.ssm_time_step_rank * p.ssm_state_size
        var act_elems = cursor
        self.s_elems = p.ssm_state_elements()
        self.ring_elems = p.ssm_layers() * max(0, p.ssm_conv_kernel - 1) * p.qkv_width()
        self.kv_elems = p.kv_elements(context_length)
        self.context = DeviceContext(0, api="hip")
        if self.context.api() != "hip" or not self.context.is_compatible():
            raise Error("Qwen35HipExecutor: a compatible AMD HIP device is required; no CPU fallback")
        var file_bytes = Int(self.model.source.file_size)
        self.weights = self.context.enqueue_create_buffer[DType.uint8](file_bytes)
        _ = upload_cuda_bytes(self.context, self.weights, self.model.source.mmap_ptr.unsafe_bitcast[UInt8](), file_bytes)
        self.acts = self.context.enqueue_create_buffer[DType.float32](act_elems)
        self.kv_buf = self.context.enqueue_create_buffer[DType.float32](max(1, self.kv_elems))
        self.state_buf = self.context.enqueue_create_buffer[DType.float32](max(1, self.s_elems + self.ring_elems))
        self.ring_tmp = self.context.enqueue_create_buffer[DType.float32](max(1, self.ring_elems))
        self.toks = self.context.enqueue_create_buffer[DType.int32](max_batch)
        self.host_toks = self.context.enqueue_create_host_buffer[DType.int32](max_batch)
        self.host_acts = self.context.enqueue_create_host_buffer[DType.float32](act_elems)
        self.host_state = self.context.enqueue_create_host_buffer[DType.float32](max(1, self.s_elems + self.ring_elems))
        self.host_kv = self.context.enqueue_create_host_buffer[DType.float32](max(1, self.kv_elems))
        self.reset_state()

    def w(self) -> Bytes:
        return Bytes(unsafe_from_address=Int(self.weights.unsafe_ptr()))

    def a(self) -> Floats:
        return Floats(unsafe_from_address=Int(self.acts.unsafe_ptr()))

    def s(self) -> Floats:
        return Floats(unsafe_from_address=Int(self.state_buf.unsafe_ptr()))

    def rtmp(self) -> Floats:
        return Floats(unsafe_from_address=Int(self.ring_tmp.unsafe_ptr()))

    def kvp(self) -> Floats:
        return Floats(unsafe_from_address=Int(self.kv_buf.unsafe_ptr()))

    def _gemm(mut self, t: Q35TensorRef, src: Int, dst: Int, batch: Int) raises:
        var n = batch * t.rows
        self.context.enqueue_function[_q8_gemm_kernel](self.w(), self.a(), Int64(t.base), Int64(t.rows), Int64(t.cols), Int64(src), Int64(dst), Int64(batch), grid_dim=(n + 255) // 256, block_dim=256)

    def _norm(mut self, t: Q35TensorRef, src: Int, dst: Int, width: Int, batch: Int) raises:
        self.context.enqueue_function[_rmsnorm_kernel](self.w(), self.a(), Int64(t.base), Int64(t.kind), Int64(width), Int64(src), Int64(dst), Int64(batch), Float32(1e-5), grid_dim=(batch + 255) // 256, block_dim=256)

    def _copy(mut self, dst: Int, src: Int, count: Int) raises:
        self.context.enqueue_function[_copy_kernel](self.a(), Int64(dst), Int64(src), Int64(count), grid_dim=(count + 255) // 256, block_dim=256)

    def _add(mut self, dst: Int, src: Int, count: Int) raises:
        self.context.enqueue_function[_add_kernel](self.a(), Int64(dst), Int64(src), Int64(count), grid_dim=(count + 255) // 256, block_dim=256)

    def _ffn(mut self, layer: Q35HipLayer, batch: Int) raises:
        ref p = self.profile
        self._copy(self.o_res, self.o_x, batch * p.hidden_size)
        self._norm(layer.post_attn_norm, self.o_x, self.o_x, p.hidden_size, batch)
        self._gemm(layer.ffn_gate, self.o_x, self.o_fg, batch)
        self._gemm(layer.ffn_up, self.o_x, self.o_fu, batch)
        var n = batch * p.feed_forward_size
        self.context.enqueue_function[_silu_mul_kernel](self.a(), Int64(self.o_fg), Int64(self.o_fu), Int64(n), grid_dim=(n + 255) // 256, block_dim=256)
        self._gemm(layer.ffn_down, self.o_fu, self.o_x, batch)
        self._add(self.o_x, self.o_res, batch * p.hidden_size)

    def _layer_ssm(mut self, layer: Q35HipLayer, batch: Int, pos: Int) raises:
        ref p = self.profile
        self._copy(self.o_res, self.o_x, batch * p.hidden_size)
        self._norm(layer.attn_norm, self.o_x, self.o_x, p.hidden_size, batch)
        self._gemm(layer.qkv, self.o_x, self.o_qkv, batch)
        self._gemm(layer.gate, self.o_x, self.o_z, batch)
        self._gemm(layer.alpha, self.o_x, self.o_alpha, batch)
        self._gemm(layer.beta, self.o_x, self.o_beta, batch)
        var conv_dim = p.qkv_width()
        var ring = self.s_elems + layer.ssm_slot * max(0, p.ssm_conv_kernel - 1) * conv_dim
        var s_base = layer.ssm_slot * p.ssm_time_step_rank * p.ssm_state_size * p.ssm_state_size
        for r in range(batch):
            self.context.enqueue_function[_conv_silu_kernel](self.w(), self.a(), self.s(), Int64(layer.conv1d.base), Int64(layer.conv1d.kind), Int64(self.o_qkv), Int64(self.o_conv), Int64(ring), Int64(conv_dim), Int64(p.ssm_conv_kernel), Int64(r), grid_dim=(conv_dim + 255) // 256, block_dim=256)
            if p.ssm_conv_kernel > 1:
                var rn = (p.ssm_conv_kernel - 1) * conv_dim
                self.context.enqueue_function[_ring_shift_stage_kernel](self.a(), self.s(), self.rtmp(), Int64(self.o_qkv), Int64(ring), Int64(conv_dim), Int64(p.ssm_conv_kernel), Int64(r), grid_dim=(rn + 255) // 256, block_dim=256)
                self.context.enqueue_function[_ring_commit_kernel](self.s(), self.rtmp(), Int64(ring), Int64(rn), grid_dim=(rn + 255) // 256, block_dim=256)
            self.context.enqueue_function[_l2norm_kernel](self.a(), Int64(self.o_conv), Int64(conv_dim), Int64(p.ssm_group_count * p.ssm_state_size), Int64(p.ssm_state_size), Int64(p.ssm_group_count), Int64(r), grid_dim=1, block_dim=256)
            var dn = p.ssm_time_step_rank * p.ssm_state_size
            self.context.enqueue_function[_delta_kernel](self.w(), self.a(), self.s(), Int64(layer.ssm_a.base), Int64(layer.ssm_a.kind), Int64(self.o_conv), Int64(self.o_alpha), Int64(self.o_beta), Int64(layer.dt_bias.base), Int64(self.o_scr), Int64(s_base), Int64(conv_dim), Int64(p.ssm_group_count * p.ssm_state_size), Int64(p.ssm_state_size), Int64(p.ssm_time_step_rank), Int64(p.ssm_group_count), Int64(r), grid_dim=(dn + 255) // 256, block_dim=256)
            self.context.enqueue_function[_gated_norm_kernel](self.w(), self.a(), Int64(layer.ssm_norm.base), Int64(layer.ssm_norm.kind), Int64(self.o_scr), Int64(self.o_z), Int64(self.o_y), Int64(p.ssm_state_size), Int64(p.ssm_time_step_rank), Int64(r), p.normalization_epsilon, grid_dim=1, block_dim=256)
        self._gemm(layer.ssm_out, self.o_y, self.o_x, batch)
        self._add(self.o_x, self.o_res, batch * p.hidden_size)
        self._ffn(layer, batch)

    def _layer_attn(mut self, layer: Q35HipLayer, batch: Int, pos: Int) raises:
        ref p = self.profile
        self._copy(self.o_res, self.o_x, batch * p.hidden_size)
        self._norm(layer.attn_norm, self.o_x, self.o_x, p.hidden_size, batch)
        self._gemm(layer.q, self.o_x, self.o_qf, batch)
        self._gemm(layer.k, self.o_x, self.o_k, batch)
        self._gemm(layer.v, self.o_x, self.o_v, batch)
        var qw = p.query_width()
        var kvw = p.kv_width()
        var n = batch * qw
        self.context.enqueue_function[_split_q_gate_kernel](self.a(), Int64(self.o_qf), Int64(self.o_q), Int64(self.o_gate), Int64(qw), Int64(p.head_dim), Int64(batch), grid_dim=(n + 255) // 256, block_dim=256)
        self.context.enqueue_function[_head_norm_kernel](self.w(), self.a(), Int64(layer.q_norm.base), Int64(layer.q_norm.kind), Int64(p.head_dim), Int64(p.attention_heads), Int64(self.o_q), Int64(batch), p.normalization_epsilon, grid_dim=(batch * p.attention_heads + 255) // 256, block_dim=256)
        self.context.enqueue_function[_head_norm_kernel](self.w(), self.a(), Int64(layer.k_norm.base), Int64(layer.k_norm.kind), Int64(p.head_dim), Int64(p.kv_heads), Int64(self.o_k), Int64(batch), p.normalization_epsilon, grid_dim=(batch * p.kv_heads + 255) // 256, block_dim=256)
        var rn_q = batch * p.attention_heads * (p.rope_dimension_count // 2)
        self.context.enqueue_function[_rope_kernel](self.a(), Int64(qw), Int64(p.attention_heads), Int64(p.head_dim), Int64(p.rope_dimension_count), Int64(self.o_q), Int64(pos), Int64(batch), p.rope_frequency_base, grid_dim=(rn_q + 255) // 256, block_dim=256)
        var rn_k = batch * p.kv_heads * (p.rope_dimension_count // 2)
        self.context.enqueue_function[_rope_kernel](self.a(), Int64(kvw), Int64(p.kv_heads), Int64(p.head_dim), Int64(p.rope_dimension_count), Int64(self.o_k), Int64(pos), Int64(batch), p.rope_frequency_base, grid_dim=(rn_k + 255) // 256, block_dim=256)
        var k_base = layer.attn_slot * self.context_length * kvw
        var v_base = p.full_attention_layers() * self.context_length * kvw + k_base
        var kn = batch * kvw
        self.context.enqueue_function[_kv_store_kernel](self.a(), self.kvp(), Int64(kvw), Int64(self.o_k), Int64(k_base), Int64(pos), Int64(self.context_length), Int64(batch), grid_dim=(kn + 255) // 256, block_dim=256)
        self.context.enqueue_function[_kv_store_kernel](self.a(), self.kvp(), Int64(kvw), Int64(self.o_v), Int64(v_base), Int64(pos), Int64(self.context_length), Int64(batch), grid_dim=(kn + 255) // 256, block_dim=256)
        var an = batch * qw
        self.context.enqueue_function[_attention_kernel](self.a(), self.kvp(), Int64(self.o_q), Int64(self.o_att), Int64(k_base), Int64(v_base), Int64(self.context_length), Int64(pos), Int64(batch), Int64(p.attention_heads), Int64(p.kv_heads), Int64(p.head_dim), grid_dim=(an + 255) // 256, block_dim=256)
        self.context.enqueue_function[_gate_mul_kernel](self.a(), Int64(self.o_att), Int64(self.o_gate), Int64(n), grid_dim=(n + 255) // 256, block_dim=256)
        self._gemm(layer.o, self.o_att, self.o_x, batch)
        self._add(self.o_x, self.o_res, batch * p.hidden_size)
        self._ffn(layer, batch)

    def reset_state(mut self) raises:
        var n = self.s_elems + self.ring_elems
        self.context.enqueue_function[_zero_kernel](self.s(), Int64(n), grid_dim=(n + 255) // 256, block_dim=256)
        self.context.synchronize()

    def forward_chunk(mut self, tokens: List[Int], start_pos: Int, want_logits: Bool, batch_cap: Int) raises -> List[Float32]:
        """Run tokens[start-implied range] at positions
        start_pos.. through the device layer stack. State resets
        exactly when start_pos == 0 (the CPU rule). batch_cap == 1
        is the per-token GEMV-loop strategy; batch_cap > 1 is the
        batched-GEMM prefill strategy (SSM conv/recurrence stay
        per-row sequential on device, as on CPU). Returns the
        last token's logits when want_logits, else empty."""
        if len(tokens) == 0:
            raise Error("Qwen35HipExecutor.forward_chunk: tokens cannot be empty")
        if start_pos == 0:
            self.reset_state()
        ref p = self.profile
        var cap = batch_cap if batch_cap >= 1 else 1
        if cap > self.max_batch:
            cap = self.max_batch
        var logits = List[Float32]()
        var done = 0
        while done < len(tokens):
            var b_len = min(cap, len(tokens) - done)
            for i in range(b_len):
                self.host_toks[i] = Int32(tokens[done + i])
            self.context.enqueue_copy(self.toks, self.host_toks)
            var pos = start_pos + done
            var en = b_len * p.hidden_size
            self.context.enqueue_function[_embed_kernel](self.w(), self.a(), self.toks.unsafe_ptr(), Int64(self.embd.base), Int64(p.hidden_size), Int64(self.o_x), Int64(b_len), grid_dim=(en + 255) // 256, block_dim=256)
            for li in range(len(self.layers)):
                var layer = self.layers[li].copy()
                if layer.is_full_attn:
                    self._layer_attn(layer, b_len, pos)
                else:
                    self._layer_ssm(layer, b_len, pos)
            done += b_len
            if want_logits and done == len(tokens):
                var last_src = self.o_x + (b_len - 1) * p.hidden_size
                var onorm = self.out_norm.copy()
                var ow = self.out_w.copy()
                self._norm(onorm, last_src, last_src, p.hidden_size, 1)
                self._gemm(ow, last_src, self.o_logits, 1)
                self.context.enqueue_copy(self.host_acts, self.acts)
                self.context.synchronize()
                for i in range(p.vocabulary_size):
                    logits.append(self.host_acts[self.o_logits + i])
            else:
                self.context.synchronize()
        return logits^

    def readback_state(mut self) raises -> List[Float32]:
        """Whole device state image: s[0..s_elems) then the conv
        rings, in Qwen35State order. Proof/snapshot seam."""
        var n = self.s_elems + self.ring_elems
        self.context.enqueue_copy(self.host_state, self.state_buf)
        self.context.synchronize()
        var out = List[Float32](capacity=n)
        for i in range(n):
            out.append(self.host_state[i])
        return out^

    def writeback_state(mut self, image: List[Float32]) raises:
        var n = self.s_elems + self.ring_elems
        if len(image) != n:
            raise Error("Qwen35HipExecutor.writeback_state: image size mismatch")
        for i in range(n):
            self.host_state[i] = image[i]
        self.state_buf.enqueue_copy_from(self.host_state.unsafe_ptr())
        self.context.synchronize()

    def readback_kv_prefix(mut self, boundary: Int) raises -> List[Float32]:
        """KV rows [0, boundary) for every full-attention layer,
        K block then V block, in device layout. Snapshot seam."""
        ref p = self.profile
        var per = p.full_attention_layers() * self.context_length * p.kv_width()
        var out = List[Float32]()
        for half in range(2):
            for slot in range(p.full_attention_layers()):
                var base = half * per + slot * self.context_length * p.kv_width()
                var n = boundary * p.kv_width()
                self.context.enqueue_copy(self.host_kv, self.kv_buf)
                self.context.synchronize()
                for i in range(n):
                    out.append(self.host_kv[base + i])
        return out^

    def writeback_kv_prefix(mut self, image: List[Float32], boundary: Int) raises:
        ref p = self.profile
        var per = p.full_attention_layers() * self.context_length * p.kv_width()
        var idx = 0
        for half in range(2):
            for slot in range(p.full_attention_layers()):
                var base = half * per + slot * self.context_length * p.kv_width()
                var n = boundary * p.kv_width()
                self.context.enqueue_copy(self.host_kv, self.kv_buf)
                self.context.synchronize()
                for i in range(n):
                    self.host_kv[base + i] = image[idx + i]
                self.kv_buf.enqueue_copy_from(self.host_kv.unsafe_ptr())
                self.context.synchronize()
                idx += n
        if idx != len(image):
            raise Error("Qwen35HipExecutor.writeback_kv_prefix: image size mismatch")
