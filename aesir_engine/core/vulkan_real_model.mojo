# core/vulkan_real_model.mojo
# VulkanRealModel: real-model GPU decode (slice A-067).
#
# A 7-8B-class Q4_K_M fixture (sha-pinned, see the A-067 ledger)
# decoding on the GPU: every transformer layer of a llama-arch
# GGUF is composed ONLY from the banked Wave 7 Vulkan gateways -
# RMSNorm + RoPE (A-060), Q4_K GEMV (A-057), Q5_K/Q6_K GEMV
# (A-058), decode attention (A-062), elementwise + gated SiLU
# (A-061) - plus the A-063 VulkanSampling gateway for the greedy
# cross-check. Logit rows are produced per decode position for
# teacher-forcing grading under raw-oracle discipline (law 3):
# the CPU comparator is the engine's own forward_pass logit sink
# (A-045) on the identical RAW token sequence, never a template.
#
# A-063 next-work item (1) DISCHARGED HERE: this is the first
# engine-integration slice that feeds raw engine logits toward
# sampling, so every logit row leaving decode_step is sanitized
# with the CPU sampler's exact policy (core/sampler.sanitize_
# logit: NaN/Inf lanes become -1e9) and the replaced-lane count
# is recorded on the model (last_nonfinite_count). No raw row
# reaches VulkanSampling or the grader unsanitized.
#
# Residency design (A-064 follow-on, filed in the ledger): the
# A-014 shim caps live buffers at AESIR_VK_MAX_BUFFERS = 128
# slots, so the 291 tensors of an 8B model can never be resident
# as one allocation per tensor. This module therefore uses
# STREAMED residency: seven reusable weight buffers (one per
# matrix role) are refilled from the GGUF mmap per layer, which
# is exact because every llama layer has identical shapes. The
# lm_head (128256 rows) IS resident, split into <= 32768-row
# chunk buffers (see below). A future shim with offset-addressed
# GEMV or a raised slot cap can make residency total; the decode
# maths here does not change.
#
# lm_head chunking: the shim dispatches GEMV with workgroup
# count = rows, and Vulkan guarantees only 65535 workgroups on
# an axis, so any GEMV wider than 32768 rows is executed in
# row chunks with per-chunk output buffers stitched on the host.
#
# RoPE convention bridge (measured, not assumed): the CPU llama
# path (core/inference TransformerBlock, rope_neox = False for
# llama) rotates ADJACENT pairs (2i, 2i+1) with the ladder
# base^(-2i/head_dim); the A-060 GPU RoPE kernel rotates
# rotate-half pairs (i, i + head_dim/2) with the same ladder.
# The two are the same rotation under the fixed dimension
# permutation p[i] = x[2i], p[i + head_dim/2] = x[2i + 1], and
# attention is invariant when q and k carry the same permutation
# (v is untouched), so decode_step permutes q/k on the host
# between the projection GEMV and the GPU RoPE dispatch. The
# permutation is a pure reindex - no arithmetic, no precision
# change. K is stored in the KV history already permuted+roped,
# so every position attends in one consistent space.
#
# KV scope: K/V history is held on the host (per layer, Float32)
# and the packed [kv_heads][kv_len][head_dim] operand the A-062
# kernel consumes is uploaded per layer-step. That is the
# honest pre-A-066 state: A-066 (full decode loop) owns the
# persistent device KV cache + append kernel; the keeper
# reconciles at banking in roadmap order. Nothing here claims
# A-066's road.
#
# A-070 (lawful CPU assist): every host participation in
# this path is instrumented in CpuAssistStats (streamed
# weight upload, norm-gain upload, embedding gather, RoPE
# permutation round trip, KV history readback + pack
# upload, lm_head readback + stitch, logit sanitize),
# accumulated per decode_step and exposed via
# assist_stats(). Verdicts + measurements:
# docs/bench/A070_CPU_ASSIST_INVENTORY.md. Removed in
# A-070: the lm_head zero-fill pass (the row is built by
# appending chunk outputs directly). Roaded there with
# evidence: total weight residency (streaming is
# load-bearing under the 128-slot shim cap), persistent
# device KV for this path (A-066 owns the pattern), and
# a GPU RoPE permutation.
#
# Embedding lookup is a host gather + dequant of ONE row per
# step (a memory read, not a matrix op): token_embd stays in the
# mmap and only the selected row is dequantized. All matrix
# maths - every projection, the attention, and the lm_head -
# runs on the device. Fail-closed throughout: any unsupported
# tensor format, shape drift between layers, or Vulkan failure
# raises; nothing is computed on the host instead.

from std.math import isinf, isnan
from std.time import perf_counter_ns
from std.memory import Pointer, bitcast
from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver
from core.mimir_well import MimirWell, RuneTensor, CompressedFormatType
from core.compute import dequantize_ggml_k
from core.sampler import sanitize_logit
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation
from core.vulkan_gemv import VulkanGemv
from core.vulkan_norm_rope import VulkanNormRope
from core.vulkan_attention import VulkanAttention
from core.vulkan_elementwise import VulkanElementwise
from core.vulkan_sampling import VulkanSampling

comptime _MAX_POS = 512
comptime _GEMV_ROW_CHUNK = 32768


def sanitize_logit_row(mut row: List[Float32]) -> Int:
    """Apply the CPU sampler's non-finite policy to a whole row.

    Every NaN/Inf lane becomes -1e9 via core/sampler.
    sanitize_logit (the identical function the CPU sampler
    uses), so a sanitized GPU row and a sanitized CPU row obey
    one policy. Returns the number of replaced lanes.
    """
    var replaced = 0
    for i in range(len(row)):
        if isnan(row[i]) or isinf(row[i]):
            replaced += 1
        row[i] = sanitize_logit(row[i])
    return replaced


def permute_rope_pairs(x: List[Float32], head_dim: Int) -> List[Float32]:
    """Reindex one [rows][head_dim] block from the CPU llama
    interleaved RoPE layout to the GPU rotate-half layout:
    p[i] = x[2i], p[i + head_dim/2] = x[2i + 1] per head row.
    Pure reindex; see the file header for why this is exact.
    """
    var out = List[Float32]()
    var half = head_dim // 2
    var rows = len(x) // head_dim
    for r in range(rows):
        var base = r * head_dim
        for i in range(half):
            out.append(x[base + 2 * i])
        for i in range(half):
            out.append(x[base + 2 * i + 1])
    return out^


def _fmt_block_bytes(fmt: Int) raises -> Int:
    """Bytes per 256-value block for the K-quant formats the
    banked GEMV gateways consume. Raises for anything else."""
    if fmt == CompressedFormatType.Q4_K_S or fmt == CompressedFormatType.Q4_K_M:
        return 144
    if fmt == CompressedFormatType.Q5_K_S or fmt == CompressedFormatType.Q5_K_M:
        return 176
    if fmt == CompressedFormatType.Q6_K:
        return 210
    raise Error(
        "VAL-003 VALUE_OUT_OF_RANGE: VulkanRealModel: tensor format "
        + String(fmt) + " has no banked Vulkan GEMV gateway"
    )


def _fmt_ggml_type(fmt: Int) raises -> Int:
    """GGML type id for core/compute.dequantize_ggml_k."""
    if fmt == CompressedFormatType.Q4_K_S or fmt == CompressedFormatType.Q4_K_M:
        return 12
    if fmt == CompressedFormatType.Q5_K_S or fmt == CompressedFormatType.Q5_K_M:
        return 13
    if fmt == CompressedFormatType.Q6_K:
        return 14
    raise Error(
        "VAL-003 VALUE_OUT_OF_RANGE: VulkanRealModel: no GGML dequant "
        "type for tensor format " + String(fmt)
    )


def _tensor_bytes(t: RuneTensor[DType.float16]) raises -> Int:
    var elems = t.rows * t.cols
    if elems % 256 != 0:
        raise Error(
            "VAL-003 VALUE_OUT_OF_RANGE: VulkanRealModel: tensor element "
            "count is not a whole number of 256-value blocks"
        )
    return (elems // 256) * _fmt_block_bytes(t.quant_format.value)


def _copy_bytes(
    dst: Pointer[UInt8, MutUntrackedOrigin],
    src: Pointer[UInt8, MutUntrackedOrigin],
    n: Int,
):
    """Host memcpy in UInt64 lanes (the streamed-residency path
    moves ~127 MB per layer-step; scalar byte loops are 8x the
    iterations for the identical bytes)."""
    var words = n // 8
    var dw = dst.unsafe_bitcast[UInt64]()
    var sw = src.unsafe_bitcast[UInt64]()
    for i in range(words):
        dw.unsafe_store(i, sw.unsafe_load(i))
    for i in range(words * 8, n):
        dst.unsafe_store(i, src.unsafe_load(i))


struct CpuAssistStats(Copyable, ImplicitlyCopyable):
    """Per-assist CPU accounting for the GPU decode path
    (A-070). Times are host wall nanoseconds spent in the
    named assist inside decode_step/_layer; bytes are the
    bytes that assist moves. step_ns is the decode_step
    wall the assists are part of. Zero = nothing measured."""

    var steps: Int
    var step_ns: Int
    var stream_uploads: Int
    var stream_bytes: Int
    var stream_ns: Int
    var gains_uploads: Int
    var gains_bytes: Int
    var gains_ns: Int
    var embed_calls: Int
    var embed_ns: Int
    var permute_calls: Int
    var permute_bytes: Int
    var permute_ns: Int
    var kv_readback_bytes: Int
    var kvpack_calls: Int
    var kvpack_bytes: Int
    var kvpack_ns: Int
    var logits_readback_bytes: Int
    var logits_ns: Int
    var sanitize_ns: Int

    def __init__(out self):
        self.steps = 0
        self.step_ns = 0
        self.stream_uploads = 0
        self.stream_bytes = 0
        self.stream_ns = 0
        self.gains_uploads = 0
        self.gains_bytes = 0
        self.gains_ns = 0
        self.embed_calls = 0
        self.embed_ns = 0
        self.permute_calls = 0
        self.permute_bytes = 0
        self.permute_ns = 0
        self.kv_readback_bytes = 0
        self.kvpack_calls = 0
        self.kvpack_bytes = 0
        self.kvpack_ns = 0
        self.logits_readback_bytes = 0
        self.logits_ns = 0
        self.sanitize_ns = 0

    def assist_ns(self) -> Int:
        """Sum of the named assist times (disjoint regions)."""
        return (
            self.stream_ns + self.gains_ns + self.embed_ns
            + self.permute_ns + self.kvpack_ns + self.logits_ns
            + self.sanitize_ns
        )


# A-070 assist inventory + lawful-assist policy (pure).
# Canonical inventory order; every id has exactly one
# name and every in-path assist above has a stats field.
comptime ASSIST_STREAM_UPLOAD = 0
comptime ASSIST_GAINS_UPLOAD = 1
comptime ASSIST_EMBED_GATHER = 2
comptime ASSIST_ROPE_PERMUTE = 3
comptime ASSIST_KV_PACK = 4
comptime ASSIST_LM_HEAD_STITCH = 5
comptime ASSIST_SANITIZE = 6
comptime ASSIST_HOST_ARGMAX = 7
comptime ASSIST_GPU_GREEDY_CHECK = 8
comptime ASSIST_DECODE_ALLOC_CHURN = 9
comptime ASSIST_COUNT = 10

comptime VERDICT_LAWFUL_SPILLOVER = 0
comptime VERDICT_LAWFUL_MASSIVE = 1
comptime VERDICT_LAWFUL_TRIVIAL = 2
comptime VERDICT_UNMEASURED = 3
comptime VERDICT_UNMEASURED_DOMINANT = 4
comptime VERDICT_DOES_NOT_PAY = 5

comptime MASSIVE_SPEEDUP_X10 = 10
comptime DOMINANT_SHARE_PCT = 50


def assist_name(assist_id: Int) -> String:
    """Canonical inventory name for an assist id."""
    if assist_id == ASSIST_STREAM_UPLOAD:
        return String("stream_upload")
    if assist_id == ASSIST_GAINS_UPLOAD:
        return String("gains_upload")
    if assist_id == ASSIST_EMBED_GATHER:
        return String("embed_gather")
    if assist_id == ASSIST_ROPE_PERMUTE:
        return String("rope_permute")
    if assist_id == ASSIST_KV_PACK:
        return String("kv_pack")
    if assist_id == ASSIST_LM_HEAD_STITCH:
        return String("lm_head_stitch")
    if assist_id == ASSIST_SANITIZE:
        return String("sanitize")
    if assist_id == ASSIST_HOST_ARGMAX:
        return String("host_argmax")
    if assist_id == ASSIST_GPU_GREEDY_CHECK:
        return String("gpu_greedy_check")
    if assist_id == ASSIST_DECODE_ALLOC_CHURN:
        return String("decode_alloc_churn")
    return String("unknown")


def assist_verdict(
    measured: Bool,
    spillover: Bool,
    assist_ns: Int,
    alternative_ns: Int,
    step_ns: Int,
) -> Int:
    """Accelerator-First verdict for one assist. CPU work
    is lawful only as (1) spillover for what exceeds
    device residency, or (2) a measured assist that
    massively helps (>= 10x the GPU alternative) or is
    a trivial share (< 1%) of the step it serves. An
    unmeasured assist never survives; one that is also
    a dominant share of the step is the worst class."""
    if not measured:
        if step_ns > 0 and assist_ns * 100 >= step_ns * DOMINANT_SHARE_PCT:
            return VERDICT_UNMEASURED_DOMINANT
        return VERDICT_UNMEASURED
    if spillover:
        return VERDICT_LAWFUL_SPILLOVER
    if alternative_ns >= assist_ns * MASSIVE_SPEEDUP_X10:
        return VERDICT_LAWFUL_MASSIVE
    if step_ns > 0 and assist_ns * 100 < step_ns:
        return VERDICT_LAWFUL_TRIVIAL
    return VERDICT_DOES_NOT_PAY


def assist_is_lawful(
    measured: Bool,
    spillover: Bool,
    assist_ns: Int,
    alternative_ns: Int,
    step_ns: Int,
) -> Bool:
    var v = assist_verdict(
        measured, spillover, assist_ns, alternative_ns, step_ns
    )
    return (
        v == VERDICT_LAWFUL_SPILLOVER
        or v == VERDICT_LAWFUL_MASSIVE
        or v == VERDICT_LAWFUL_TRIVIAL
    )


def stitch_chunk_append(chunks: List[List[Float32]]) -> List[Float32]:
    """lm_head stitch, A-070 form: the logit row is built
    by appending chunk outputs directly (no zero-fill)."""
    var out = List[Float32]()
    for c in range(len(chunks)):
        var chunk = chunks[c].copy()
        for i in range(len(chunk)):
            out.append(chunk[i])
    return out^


def stitch_chunk_scatter(
    chunks: List[List[Float32]], total: Int
) -> List[Float32]:
    """Pre-A-070 lm_head stitch, kept as the equivalence
    oracle: zero-fill a total-length row, scatter chunks."""
    var out = List[Float32]()
    for _ in range(total):
        out.append(Float32(0.0))
    var done = 0
    for c in range(len(chunks)):
        var chunk = chunks[c].copy()
        for i in range(len(chunk)):
            out[done + i] = chunk[i]
        done += len(chunk)
    return out^


struct VulkanRealModel:
    """One loaded llama-arch GGUF decoding on the Vulkan device.

    Lifecycle: __init__ (unloaded) -> load(path) -> reset_kv()
    -> decode_step(token, position) per position, or the
    teacher_forcing_rows / greedy_from conveniences.
    """

    var loaded: Bool
    var dim: Int
    var ffn: Int
    var layers: Int
    var heads: Int
    var kv_heads: Int
    var head_dim: Int
    var kv_dim: Int
    var vocab: Int
    var eps: Float32
    var rope_base: Float32
    var last_nonfinite_count: Int
    var assist: CpuAssistStats
    var _seer: GGUFSeer
    var _pool: MimirWell
    var _weaver: RuneWeaver
    var _wq: VulkanAllocation
    var _wk: VulkanAllocation
    var _wv: VulkanAllocation
    var _wo: VulkanAllocation
    var _wg: VulkanAllocation
    var _wu: VulkanAllocation
    var _wd: VulkanAllocation
    var _g_attn: VulkanAllocation
    var _g_ffn: VulkanAllocation
    var _g_out: VulkanAllocation
    var _lm_chunks: List[VulkanAllocation]
    var _lm_chunk_rows: List[Int]
    var _lm_fmt: Int
    var _x_a: VulkanAllocation
    var _x_b: VulkanAllocation
    var _h: VulkanAllocation
    var _q: VulkanAllocation
    var _k: VulkanAllocation
    var _v: VulkanAllocation
    var _attn: VulkanAllocation
    var _proj: VulkanAllocation
    var _res: VulkanAllocation
    var _h2: VulkanAllocation
    var _gate: VulkanAllocation
    var _up: VulkanAllocation
    var _mlp: VulkanAllocation
    var _down: VulkanAllocation
    var _chunk_y: VulkanAllocation
    var _kpack: VulkanAllocation
    var _vpack: VulkanAllocation
    var _tok: VulkanAllocation
    var _k_hist: List[List[Float32]]
    var _v_hist: List[List[Float32]]

    def __init__(out self, path: String = "") raises:
        self.loaded = False
        self.dim = 0
        self.ffn = 0
        self.layers = 0
        self.heads = 0
        self.kv_heads = 0
        self.head_dim = 0
        self.kv_dim = 0
        self.vocab = 0
        self.eps = Float32(1.0e-5)
        self.rope_base = Float32(10000.0)
        self.last_nonfinite_count = 0
        self.assist = CpuAssistStats()
        self._seer = GGUFSeer(path)
        self._pool = MimirWell(268435456)
        self._weaver = RuneWeaver()
        var zero = VulkanAllocation(0, 0, 0, 0, 0)
        self._wq = zero
        self._wk = zero
        self._wv = zero
        self._wo = zero
        self._wg = zero
        self._wu = zero
        self._wd = zero
        self._g_attn = zero
        self._g_ffn = zero
        self._g_out = zero
        self._lm_chunks = List[VulkanAllocation]()
        self._lm_chunk_rows = List[Int]()
        self._lm_fmt = 0
        self._x_a = zero
        self._x_b = zero
        self._h = zero
        self._q = zero
        self._k = zero
        self._v = zero
        self._attn = zero
        self._proj = zero
        self._res = zero
        self._h2 = zero
        self._gate = zero
        self._up = zero
        self._mlp = zero
        self._down = zero
        self._chunk_y = zero
        self._kpack = zero
        self._vpack = zero
        self._tok = zero
        self._k_hist = List[List[Float32]]()
        self._v_hist = List[List[Float32]]()

    def _tensor(self, name: String) raises -> RuneTensor[DType.float16]:
        if name not in self._seer.tensors:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanRealModel: GGUF is "
                "missing required tensor " + name
            )
        return self._seer.tensors[name].copy()

    def _upload(
        mut self, alloc: VulkanAllocation, t: RuneTensor[DType.float16]
    ) raises:
        var n = _tensor_bytes(t)
        if alloc.requested_size < n:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanRealModel: weight "
                "buffer is smaller than the tensor bytes"
            )
        var t0 = perf_counter_ns()
        var dst = VulkanBuffers.map(alloc)
        _copy_bytes(dst, t.data.unsafe_bitcast[UInt8](), n)
        VulkanBuffers.unmap(alloc)
        self.assist.stream_uploads += 1
        self.assist.stream_bytes += n
        self.assist.stream_ns += perf_counter_ns() - t0

    def _upload_gains(
        mut self, alloc: VulkanAllocation, t: RuneTensor[DType.float16]
    ) raises:
        if t.cols != self.dim or t.rows != 1:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanRealModel: norm gain "
                "tensor is not a single row of dim Float32"
            )
        var t0 = perf_counter_ns()
        var dst = VulkanBuffers.map(alloc).unsafe_bitcast[Float32]()
        for i in range(self.dim):
            dst.unsafe_store(
                i, t.data.unsafe_load(i).cast[DType.float32]()
            )
        VulkanBuffers.unmap(alloc)
        self.assist.gains_uploads += 1
        self.assist.gains_bytes += self.dim * 4
        self.assist.gains_ns += perf_counter_ns() - t0

    def _gemv(
        self,
        fmt: Int,
        w: VulkanAllocation,
        x: VulkanAllocation,
        y: VulkanAllocation,
        rows: Int,
        cols: Int,
    ) raises:
        if fmt == CompressedFormatType.Q4_K_S or fmt == CompressedFormatType.Q4_K_M:
            VulkanBuffers.q4k_gemv(w, x, y, cols, rows)
        elif fmt == CompressedFormatType.Q5_K_S or fmt == CompressedFormatType.Q5_K_M:
            VulkanGemv.q5_k_gemv(w, x, y, rows, cols)
        elif fmt == CompressedFormatType.Q6_K:
            VulkanGemv.q6_k_gemv(w, x, y, rows, cols)
        else:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanRealModel: tensor "
                "format " + String(fmt)
                + " has no banked Vulkan GEMV gateway"
            )

    def load(mut self) raises:
        """Parse the GGUF, validate the llama geometry, allocate
        the streamed-residency + scratch buffers, and upload the
        resident lm_head chunks and final norm gains."""
        if self.loaded:
            raise Error("VulkanRealModel: model is already loaded")
        self._seer.mmap_and_load(self._pool, self._weaver)
        var cfg = self._seer.config.copy()
        if cfg.architecture != "llama":
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanRealModel: A-067 GPU "
                "decode covers the llama architecture, got "
                + cfg.architecture
            )
        self.dim = cfg.embedding_length
        self.ffn = cfg.feed_forward_length
        self.layers = cfg.block_count
        self.heads = cfg.head_count
        self.kv_heads = cfg.head_count_kv
        self.head_dim = cfg.head_dim()
        self.kv_dim = cfg.kv_dim()
        self.eps = cfg.rms_epsilon
        self.rope_base = cfg.rope_freq_base
        if self.dim <= 0 or self.dim % 256 != 0:
            raise Error("VulkanRealModel: embedding_length must be a positive multiple of 256")
        if self.ffn <= 0 or self.ffn % 256 != 0:
            raise Error("VulkanRealModel: feed_forward_length must be a positive multiple of 256")
        if self.layers <= 0 or self.heads <= 0 or self.kv_heads <= 0:
            raise Error("VulkanRealModel: layer/head counts must be positive")
        if self.heads % self.kv_heads != 0:
            raise Error("VulkanRealModel: head_count must be an exact multiple of head_count_kv")
        if self.head_dim * self.heads != self.dim:
            raise Error("VulkanRealModel: head_dim * head_count must equal embedding_length")
        var embd = self._tensor("token_embd.weight")
        self.vocab = embd.rows
        if embd.cols != self.dim:
            raise Error("VulkanRealModel: token_embd cols must equal embedding_length")
        # Validate every layer's tensors once: same shapes as
        # layer 0 (streamed residency depends on it), formats in
        # the banked GEMV set (fail-closed at load, not mid-step).
        var roles = List[String]()
        roles.append("attn_q.weight")
        roles.append("attn_k.weight")
        roles.append("attn_v.weight")
        roles.append("attn_output.weight")
        roles.append("ffn_gate.weight")
        roles.append("ffn_up.weight")
        roles.append("ffn_down.weight")
        var want_rows = List[Int]()
        want_rows.append(self.dim)
        want_rows.append(self.kv_dim)
        want_rows.append(self.kv_dim)
        want_rows.append(self.dim)
        want_rows.append(self.ffn)
        want_rows.append(self.ffn)
        want_rows.append(self.dim)
        var want_cols = List[Int]()
        want_cols.append(self.dim)
        want_cols.append(self.dim)
        want_cols.append(self.dim)
        want_cols.append(self.dim)
        want_cols.append(self.dim)
        want_cols.append(self.dim)
        want_cols.append(self.ffn)
        var max_bytes = List[Int]()
        for _ in range(7):
            max_bytes.append(0)
        for layer in range(self.layers):
            var prefix = "blk." + String(layer) + "."
            for r in range(7):
                var t = self._tensor(prefix + roles[r])
                if t.rows != want_rows[r] or t.cols != want_cols[r]:
                    raise Error(
                        "VulkanRealModel: shape drift at " + prefix
                        + roles[r] + " (streamed residency needs "
                        "identical layer shapes)"
                    )
                var n = _tensor_bytes(t)
                if n > max_bytes[r]:
                    max_bytes[r] = n
            var gn = self._tensor(prefix + "attn_norm.weight")
            if gn.cols != self.dim or gn.rows != 1:
                raise Error("VulkanRealModel: attn_norm shape drift at " + prefix)
            var gf = self._tensor(prefix + "ffn_norm.weight")
            if gf.cols != self.dim or gf.rows != 1:
                raise Error("VulkanRealModel: ffn_norm shape drift at " + prefix)
        # Streamed weight buffers, sized to the largest layer.
        self._wq = VulkanBuffers.allocate(max_bytes[0])
        self._wk = VulkanBuffers.allocate(max_bytes[1])
        self._wv = VulkanBuffers.allocate(max_bytes[2])
        self._wo = VulkanBuffers.allocate(max_bytes[3])
        self._wg = VulkanBuffers.allocate(max_bytes[4])
        self._wu = VulkanBuffers.allocate(max_bytes[5])
        self._wd = VulkanBuffers.allocate(max_bytes[6])
        self._g_attn = VulkanBuffers.allocate(self.dim * 4)
        self._g_ffn = VulkanBuffers.allocate(self.dim * 4)
        self._g_out = VulkanBuffers.allocate(self.dim * 4)
        # Activations + scratch.
        self._x_a = VulkanBuffers.allocate(self.dim * 4)
        self._x_b = VulkanBuffers.allocate(self.dim * 4)
        self._h = VulkanBuffers.allocate(self.dim * 4)
        self._q = VulkanBuffers.allocate(self.dim * 4)
        self._k = VulkanBuffers.allocate(self.kv_dim * 4)
        self._v = VulkanBuffers.allocate(self.kv_dim * 4)
        self._attn = VulkanBuffers.allocate(self.dim * 4)
        self._proj = VulkanBuffers.allocate(self.dim * 4)
        self._res = VulkanBuffers.allocate(self.dim * 4)
        self._h2 = VulkanBuffers.allocate(self.dim * 4)
        self._gate = VulkanBuffers.allocate(self.ffn * 4)
        self._up = VulkanBuffers.allocate(self.ffn * 4)
        self._mlp = VulkanBuffers.allocate(self.ffn * 4)
        self._down = VulkanBuffers.allocate(self.dim * 4)
        self._chunk_y = VulkanBuffers.allocate(_GEMV_ROW_CHUNK * 4)
        var pack_floats = self.kv_heads * _MAX_POS * self.head_dim
        self._kpack = VulkanBuffers.allocate(pack_floats * 4)
        self._vpack = VulkanBuffers.allocate(pack_floats * 4)
        self._tok = VulkanBuffers.allocate(4)
        # Resident lm_head: output.weight, or token_embd when the
        # file ties embeddings (no separate output tensor).
        var lm_name = String("output.weight")
        if lm_name not in self._seer.tensors:
            lm_name = "token_embd.weight"
        var lm = self._tensor(lm_name)
        if lm.rows != self.vocab or lm.cols != self.dim:
            raise Error("VulkanRealModel: lm_head shape must be [vocab][dim]")
        self._lm_fmt = lm.quant_format.value
        var row_bytes = (self.dim // 256) * _fmt_block_bytes(self._lm_fmt)
        var src = lm.data.unsafe_bitcast[UInt8]()
        var done = 0
        while done < self.vocab:
            var chunk = _GEMV_ROW_CHUNK
            if done + chunk > self.vocab:
                chunk = self.vocab - done
            var alloc = VulkanBuffers.allocate(chunk * row_bytes)
            var dst = VulkanBuffers.map(alloc)
            _copy_bytes(
                dst, src.unsafe_offset(done * row_bytes), chunk * row_bytes
            )
            VulkanBuffers.unmap(alloc)
            self._lm_chunks.append(alloc)
            self._lm_chunk_rows.append(chunk)
            done += chunk
        var gout = self._tensor("output_norm.weight")
        var bgo = self._g_out.copy()
        self._upload_gains(bgo, gout)
        for _ in range(self.layers):
            self._k_hist.append(List[Float32]())
            self._v_hist.append(List[Float32]())
        self.loaded = True

    def close(mut self) raises:
        """Release every device allocation this model holds.
        Suite cases load/close per case: the shim caps live
        buffers at 128 and one loaded model holds ~32."""
        if not self.loaded:
            return
        var named = List[VulkanAllocation]()
        named.append(self._wq)
        named.append(self._wk)
        named.append(self._wv)
        named.append(self._wo)
        named.append(self._wg)
        named.append(self._wu)
        named.append(self._wd)
        named.append(self._g_attn)
        named.append(self._g_ffn)
        named.append(self._g_out)
        named.append(self._x_a)
        named.append(self._x_b)
        named.append(self._h)
        named.append(self._q)
        named.append(self._k)
        named.append(self._v)
        named.append(self._attn)
        named.append(self._proj)
        named.append(self._res)
        named.append(self._h2)
        named.append(self._gate)
        named.append(self._up)
        named.append(self._mlp)
        named.append(self._down)
        named.append(self._chunk_y)
        named.append(self._kpack)
        named.append(self._vpack)
        named.append(self._tok)
        for i in range(len(named)):
            if named[i].id != 0:
                VulkanBuffers.free(named[i])
        for i in range(len(self._lm_chunks)):
            if self._lm_chunks[i].id != 0:
                VulkanBuffers.free(self._lm_chunks[i])
        self._lm_chunks = List[VulkanAllocation]()
        self._lm_chunk_rows = List[Int]()
        self.loaded = False

    def reset_kv(mut self):
        for l in range(len(self._k_hist)):
            self._k_hist[l] = List[Float32]()
            self._v_hist[l] = List[Float32]()

    def _embed(mut self, token: Int) raises -> List[Float32]:
        var t0 = perf_counter_ns()
        var embd = self._tensor("token_embd.weight")
        var out = List[Float32]()
        if embd.is_quantized:
            var ggml = _fmt_ggml_type(embd.quant_format.value)
            var row_block_bytes = (self.dim // 256) * _fmt_block_bytes(
                embd.quant_format.value
            )
            var src = embd.data.unsafe_bitcast[UInt8]().unsafe_offset(
                token * row_block_bytes
            )
            var buf = alloc[Scalar[DType.float16]](self.dim)
            dequantize_ggml_k(src, buf, self.dim, ggml)
            for i in range(self.dim):
                out.append(buf[i].cast[DType.float32]())
            buf.free()
        else:
            for i in range(self.dim):
                out.append(
                    embd.data.unsafe_load(token * self.dim + i).cast[
                        DType.float32
                    ]()
                )
        self.assist.embed_calls += 1
        self.assist.embed_ns += perf_counter_ns() - t0
        return out^

    def _write_f32(
        self, alloc: VulkanAllocation, values: List[Float32], offset: Int = 0
    ) raises:
        var dst = VulkanBuffers.map(alloc).unsafe_bitcast[Float32]()
        for i in range(len(values)):
            dst.unsafe_store(offset + i, values[i])
        VulkanBuffers.unmap(alloc)

    def _read_f32(
        self, alloc: VulkanAllocation, count: Int
    ) raises -> List[Float32]:
        var src = VulkanBuffers.map(alloc).unsafe_bitcast[Float32]()
        var out = List[Float32]()
        for i in range(count):
            out.append(src.unsafe_load(i))
        VulkanBuffers.unmap(alloc)
        return out^

    def _layer(
        mut self,
        x_in: VulkanAllocation,
        dst: VulkanAllocation,
        layer: Int,
        position: Int,
    ) raises:
        var prefix = "blk." + String(layer) + "."
        var tq = self._tensor(prefix + "attn_q.weight")
        var tk = self._tensor(prefix + "attn_k.weight")
        var tv = self._tensor(prefix + "attn_v.weight")
        var to = self._tensor(prefix + "attn_output.weight")
        var tg = self._tensor(prefix + "ffn_gate.weight")
        var tu = self._tensor(prefix + "ffn_up.weight")
        var td = self._tensor(prefix + "ffn_down.weight")
        var bwq = self._wq.copy()
        var bwk = self._wk.copy()
        var bwv = self._wv.copy()
        var bwo = self._wo.copy()
        var bwg = self._wg.copy()
        var bwu = self._wu.copy()
        var bwd = self._wd.copy()
        self._upload(bwq, tq)
        self._upload(bwk, tk)
        self._upload(bwv, tv)
        self._upload(bwo, to)
        self._upload(bwg, tg)
        self._upload(bwu, tu)
        self._upload(bwd, td)
        var bga = self._g_attn.copy()
        var bgf = self._g_ffn.copy()
        self._upload_gains(
            bga, self._tensor(prefix + "attn_norm.weight")
        )
        self._upload_gains(
            bgf, self._tensor(prefix + "ffn_norm.weight")
        )
        VulkanNormRope.rmsnorm(x_in, self._g_attn, self._h, self.dim, 1, self.eps)
        self._gemv(tq.quant_format.value, self._wq, self._h, self._q, self.dim, self.dim)
        self._gemv(tk.quant_format.value, self._wk, self._h, self._k, self.kv_dim, self.dim)
        self._gemv(tv.quant_format.value, self._wv, self._h, self._v, self.kv_dim, self.dim)
        # RoPE convention bridge: permute q/k on the host, rope
        # on the device (see the file header).
        var tp0 = perf_counter_ns()
        var q_host = permute_rope_pairs(self._read_f32(self._q, self.dim), self.head_dim)
        self._write_f32(self._q, q_host)
        var k_host = permute_rope_pairs(self._read_f32(self._k, self.kv_dim), self.head_dim)
        self._write_f32(self._k, k_host)
        self.assist.permute_calls += 2
        self.assist.permute_bytes += (self.dim + self.kv_dim) * 8
        self.assist.permute_ns += perf_counter_ns() - tp0
        VulkanNormRope.rope(self._q, self.head_dim, self.heads, position, self.rope_base)
        VulkanNormRope.rope(self._k, self.head_dim, self.kv_heads, position, self.rope_base)
        var tk0 = perf_counter_ns()
        var k_roped = self._read_f32(self._k, self.kv_dim)
        var v_host = self._read_f32(self._v, self.kv_dim)
        for i in range(self.kv_dim):
            self._k_hist[layer].append(k_roped[i])
            self._v_hist[layer].append(v_host[i])
        # Pack the KV operand [kv_heads][kv_len][head_dim].
        var kv_len = position + 1
        var kpack = List[Float32]()
        var vpack = List[Float32]()
        for hh in range(self.kv_heads):
            for p in range(kv_len):
                var src_base = p * self.kv_dim + hh * self.head_dim
                for d in range(self.head_dim):
                    kpack.append(self._k_hist[layer][src_base + d])
                    vpack.append(self._v_hist[layer][src_base + d])
        self._write_f32(self._kpack, kpack)
        self._write_f32(self._vpack, vpack)
        self.assist.kv_readback_bytes += self.kv_dim * 8
        self.assist.kvpack_calls += 1
        self.assist.kvpack_bytes += (len(kpack) + len(vpack)) * 4
        self.assist.kvpack_ns += perf_counter_ns() - tk0
        VulkanAttention.decode_attention(
            self._q, self._kpack, self._vpack, self._attn,
            self.head_dim, kv_len, self.heads, self.heads // self.kv_heads,
        )
        self._gemv(to.quant_format.value, self._wo, self._attn, self._proj, self.dim, self.dim)
        VulkanElementwise.elementwise(x_in, self._proj, self._res, self.dim, 2)
        VulkanNormRope.rmsnorm(self._res, self._g_ffn, self._h2, self.dim, 1, self.eps)
        self._gemv(tg.quant_format.value, self._wg, self._h2, self._gate, self.ffn, self.dim)
        self._gemv(tu.quant_format.value, self._wu, self._h2, self._up, self.ffn, self.dim)
        VulkanElementwise.elementwise(self._gate, self._up, self._mlp, self.ffn, 3)
        self._gemv(td.quant_format.value, self._wd, self._mlp, self._down, self.dim, self.ffn)
        VulkanElementwise.elementwise(self._res, self._down, dst, self.dim, 2)

    def decode_step(mut self, token: Int, position: Int) raises -> List[Float32]:
        """One GPU decode position: embed -> all layers -> final
        norm -> lm_head -> sanitize. Returns the sanitized logit
        row (what the sampler and the grader see)."""
        if not self.loaded:
            raise Error("VulkanRealModel: decode_step before load")
        if token < 0 or token >= self.vocab:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanRealModel: token id "
                + String(token) + " is outside the vocabulary"
            )
        if position < 0 or position >= _MAX_POS:
            raise Error(
                "VAL-003 VALUE_OUT_OF_RANGE: VulkanRealModel: position "
                + String(position) + " is outside the filed KV capacity"
            )
        if len(self._k_hist[0]) // self.kv_dim != position:
            raise Error(
                "VulkanRealModel: decode positions must be sequential "
                "(reset_kv, then 0, 1, 2, ...)"
            )
        var t_step0 = perf_counter_ns()
        var x = self._embed(token)
        var xa = self._x_a
        var xb = self._x_b
        self._write_f32(xa, x)
        var use_a = True
        for layer in range(self.layers):
            if use_a:
                self._layer(xa, xb, layer, position)
            else:
                self._layer(xb, xa, layer, position)
            use_a = not use_a
        var x_final = xa if use_a else xb
        VulkanNormRope.rmsnorm(x_final, self._g_out, self._h, self.dim, 1, self.eps)
        var tl0 = perf_counter_ns()
        var chunks = List[List[Float32]]()
        for c in range(len(self._lm_chunks)):
            var rows = self._lm_chunk_rows[c]
            self._gemv(self._lm_fmt, self._lm_chunks[c], self._h, self._chunk_y, rows, self.dim)
            chunks.append(self._read_f32(self._chunk_y, rows))
        var logits = stitch_chunk_append(chunks)
        self.assist.logits_readback_bytes += self.vocab * 4
        self.assist.logits_ns += perf_counter_ns() - tl0
        if len(logits) != self.vocab:
            raise Error("VulkanRealModel: lm_head stitch length drift")
        var ts0 = perf_counter_ns()
        self.last_nonfinite_count = sanitize_logit_row(logits)
        self.assist.sanitize_ns += perf_counter_ns() - ts0
        self.assist.steps += 1
        self.assist.step_ns += perf_counter_ns() - t_step0
        return logits^

    def assist_stats(self) -> CpuAssistStats:
        """Snapshot of the A-070 per-assist accounting."""
        return self.assist.copy()

    def gpu_greedy_token(mut self, logits: List[Float32]) raises -> Int:
        """Cross-check: upload a sanitized row and let the A-063
        VulkanSampling greedy kernel pick the token on device."""
        var alloc = VulkanBuffers.allocate(len(logits) * 4)
        self._write_f32(alloc, logits)
        VulkanSampling.greedy(alloc, self._tok, len(logits))
        var p = VulkanBuffers.map(self._tok).unsafe_bitcast[UInt32]()
        var winner = Int(p.unsafe_load(0))
        VulkanBuffers.unmap(self._tok)
        VulkanBuffers.free(alloc)
        return winner

    def teacher_forcing_rows(
        mut self, tokens: List[Int]
    ) raises -> List[List[Float32]]:
        self.reset_kv()
        var rows = List[List[Float32]]()
        for p in range(len(tokens)):
            rows.append(self.decode_step(tokens[p], p))
        return rows^

    def greedy_from(
        mut self, prompt_tokens: List[Int], count: Int
    ) raises -> List[Int]:
        """Greedy continuation: teacher-force the prompt, then
        feed back host argmax picks over the sanitized rows."""
        self.reset_kv()
        var row = List[Float32]()
        for p in range(len(prompt_tokens)):
            row = self.decode_step(prompt_tokens[p], p)
        var out = List[Int]()
        var pos = len(prompt_tokens)
        for _ in range(count):
            var best = 0
            for i in range(len(row)):
                if row[i] > row[best]:
                    best = i
            out.append(best)
            if best == 128001 or best == 128009:
                break
            row = self.decode_step(best, pos)
            pos += 1
        return out^
