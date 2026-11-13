# core/accum_policy.mojo
# A-075: Accumulation policy -- per-kernel accumulate dtype for the
# Vulkan shader set (aesir_engine/shaders, SHADER_MANIFEST order) and
# the CPU reduction sites, chosen by numerics evidence.
#
# Policy (ratified by the A-075 evidence battery, docs/bench/
# A075_ACCUMULATION_POLICY.md): every reduction in the engine
# accumulates in FP32. FP16/BF16 accumulation is rejected at model
# scale by direct measurement (this module's emulation accumulators,
# graded in tests/test_accum_policy_a075.mojo and filed by
# tests/bench_accum_policy_a075.mojo):
#
#   * Dot products (GEMV/GEMM, lm_head): sequential FP16/BF16
#     accumulation error grows with K and, at production K (4096 /
#     14336), moves lm_head-shaped logit rows out of the law-3
#     faithful band (rank <= 2 with gap < 1.0) against the Float64
#     reference row, while FP32 accumulation stays rank 1.
#   * Sum-of-squares (RMSNorm): FP16 accumulation overflows to +inf
#     at FFN width (n = 14336) on residual-scale inputs; BF16
#     accumulation relative error is orders of magnitude above FP32.
#   * Attention weighted-V / softmax mass: same growth law at
#     context scale (T = 4096).
#
# FP16/BF16 remain lawful as STORAGE (quant block scale fields are
# FP16, decoded to Float32 before any arithmetic -- see the GEMV
# shaders' half_to_float) and as GEMM operand storage on the CPU
# paths (A-047: F16/BF16 GEMM relative error is flat in K precisely
# because both accumulate in F32). Accumulation is the lever, and
# the evidence pins it to FP32.
#
# Pipeline note: the A-055 shader pipeline targets vulkan1.0 /
# SPIR-V 1.0 with no FP16 arithmetic extension declared and the
# Vulkan 1.0 context enables no shaderFloat16 feature, so an FP16
# accumulator variant could not even compile or run today (A-073
# subgroup precedent); the RADV hardware itself reports
# shaderFloat16 = true. The numerics verdict makes that migration
# unnecessary on evidence grounds, not merely unavailable.
#
# Emulation model (what "FP16 accumulate" means in the battery):
# products are formed in Float32 (Float64 for the reference mode),
# and the running sum is rounded to the named dtype after every
# addition -- the accumulator-register model. Serial order is the
# conservative case; the shipped kernels' blocked/tree reductions
# in FP32 sit strictly inside the FP32 error envelope measured here.

from std.math import sqrt


# Accumulate-dtype policy codes.
comptime ACCUM_NONE = 0  # kernel performs no reduction
comptime ACCUM_FP32 = 1
comptime ACCUM_FP16 = 2
comptime ACCUM_BF16 = 3

# Emulation modes for the evidence accumulators below.
comptime MODE_F64 = 0  # Float64 reference (the oracle arithmetic)
comptime MODE_FP32 = 1
comptime MODE_FP16 = 2
comptime MODE_BF16 = 3

# Evidence classes: which A-075 measurement backs a policy row.
comptime EV_NONE = 0  # no reduction; nothing to accumulate
comptime EV_DOT = 1  # dot-product K-scaling + lm_head logit-gap battery
comptime EV_ATTN = 2  # attention QK / weighted-V battery
comptime EV_NORM = 3  # sum-of-squares overflow/precision battery
comptime EV_MASS = 4  # exp-mass (softmax denominator) battery
comptime EV_ARGMAX = 5  # comparison reduction over FP32 logits

# Vulkan kernel ids, in SHADER_MANIFEST.json order (A-055, 25 kernels).
comptime K_ATTENTION_DECODE = 0
comptime K_ATTENTION_DECODE_STRIDED = 1
comptime K_ATTENTION_PREFILL = 2
comptime K_ELEMENTWISE = 3
comptime K_EMBED_GATHER = 4
comptime K_GEMM_F32 = 5
comptime K_GEMV_F32 = 6
comptime K_IQ1_S_GEMV = 7
comptime K_IQ2_XXS_GEMV = 8
comptime K_IQ3_XXS_GEMV = 9
comptime K_IQ4_NL_GEMV = 10
comptime K_KV_APPEND = 11
comptime K_KV_APPEND_CHUNK = 12
comptime K_Q4K_GEMV = 13
comptime K_Q5K_GEMV = 14
comptime K_Q6K_GEMV = 15
comptime K_Q8_0_GEMM = 16
comptime K_Q8_0_GEMV = 17
comptime K_RMSNORM = 18
comptime K_ROPE = 19
comptime K_ROPE_BATCHED = 20
comptime K_SAMPLING_GREEDY = 21
comptime K_SAMPLING_SAMPLE = 22
comptime K_SOFTMAX = 23
comptime K_VEC_ADD = 24
comptime KERNEL_COUNT = 25

# CPU reduction sites (ids offset by KERNEL_COUNT).
comptime C_GEMM_F16 = 25  # core/compute.mojo gemm_f16 (F32 accumulation)
comptime C_GEMM_BF16 = 26  # core/compute.mojo gemm_bf16 (F32 accumulation)
comptime C_GEMM_QUANT = 27  # Q8_0 / K-quant / IQ GEMM family (F32 accum)
comptime C_RMSNORM = 28  # core/compute.mojo rmsnorm (F32 sumsq)
comptime C_ATTENTION = 29  # fused attention online softmax (F32 accum)
comptime CPU_SITE_COUNT = 5
comptime POLICY_ROW_COUNT = 30


def accum_dtype_name(code: Int) -> String:
    if code == ACCUM_FP32:
        return String("fp32")
    if code == ACCUM_FP16:
        return String("fp16")
    if code == ACCUM_BF16:
        return String("bf16")
    return String("none")


def kernel_name(kernel_id: Int) -> String:
    if kernel_id == K_ATTENTION_DECODE:
        return String("attention_decode")
    if kernel_id == K_ATTENTION_DECODE_STRIDED:
        return String("attention_decode_strided")
    if kernel_id == K_ATTENTION_PREFILL:
        return String("attention_prefill")
    if kernel_id == K_ELEMENTWISE:
        return String("elementwise")
    if kernel_id == K_EMBED_GATHER:
        return String("embed_gather")
    if kernel_id == K_GEMM_F32:
        return String("gemm_f32")
    if kernel_id == K_GEMV_F32:
        return String("gemv_f32")
    if kernel_id == K_IQ1_S_GEMV:
        return String("iq1_s_gemv")
    if kernel_id == K_IQ2_XXS_GEMV:
        return String("iq2_xxs_gemv")
    if kernel_id == K_IQ3_XXS_GEMV:
        return String("iq3_xxs_gemv")
    if kernel_id == K_IQ4_NL_GEMV:
        return String("iq4_nl_gemv")
    if kernel_id == K_KV_APPEND:
        return String("kv_append")
    if kernel_id == K_KV_APPEND_CHUNK:
        return String("kv_append_chunk")
    if kernel_id == K_Q4K_GEMV:
        return String("q4k_gemv")
    if kernel_id == K_Q5K_GEMV:
        return String("q5_k_gemv")
    if kernel_id == K_Q6K_GEMV:
        return String("q6_k_gemv")
    if kernel_id == K_Q8_0_GEMM:
        return String("q8_0_gemm")
    if kernel_id == K_Q8_0_GEMV:
        return String("q8_0_gemv")
    if kernel_id == K_RMSNORM:
        return String("rmsnorm")
    if kernel_id == K_ROPE:
        return String("rope")
    if kernel_id == K_ROPE_BATCHED:
        return String("rope_batched")
    if kernel_id == K_SAMPLING_GREEDY:
        return String("sampling_greedy")
    if kernel_id == K_SAMPLING_SAMPLE:
        return String("sampling_sample")
    if kernel_id == K_SOFTMAX:
        return String("softmax")
    if kernel_id == K_VEC_ADD:
        return String("vec_add")
    return String("")


def cpu_site_name(site_id: Int) -> String:
    if site_id == C_GEMM_F16:
        return String("cpu.gemm_f16")
    if site_id == C_GEMM_BF16:
        return String("cpu.gemm_bf16")
    if site_id == C_GEMM_QUANT:
        return String("cpu.gemm_quant_family")
    if site_id == C_RMSNORM:
        return String("cpu.rmsnorm")
    if site_id == C_ATTENTION:
        return String("cpu.fused_attention")
    return String("")


def kernel_evidence(kernel_id: Int) -> Int:
    # Attention family: QK dot + weighted-V accumulation.
    if (
        kernel_id == K_ATTENTION_DECODE
        or kernel_id == K_ATTENTION_DECODE_STRIDED
        or kernel_id == K_ATTENTION_PREFILL
    ):
        return EV_ATTN
    # Dot-product family: every GEMV/GEMM.
    if (
        kernel_id == K_GEMM_F32
        or kernel_id == K_GEMV_F32
        or kernel_id == K_IQ1_S_GEMV
        or kernel_id == K_IQ2_XXS_GEMV
        or kernel_id == K_IQ3_XXS_GEMV
        or kernel_id == K_IQ4_NL_GEMV
        or kernel_id == K_Q4K_GEMV
        or kernel_id == K_Q5K_GEMV
        or kernel_id == K_Q6K_GEMV
        or kernel_id == K_Q8_0_GEMM
        or kernel_id == K_Q8_0_GEMV
    ):
        return EV_DOT
    if kernel_id == K_RMSNORM:
        return EV_NORM
    if kernel_id == K_SOFTMAX or kernel_id == K_SAMPLING_SAMPLE:
        return EV_MASS
    if kernel_id == K_SAMPLING_GREEDY:
        return EV_ARGMAX
    return EV_NONE


def cpu_site_evidence(site_id: Int) -> Int:
    if site_id == C_RMSNORM:
        return EV_NORM
    if site_id == C_ATTENTION:
        return EV_ATTN
    return EV_DOT


def kernel_accum_policy(kernel_id: Int) -> Int:
    # The ratified policy: FP32 accumulation wherever a reduction
    # exists; ACCUM_NONE only for pure elementwise / copy kernels.
    if kernel_evidence(kernel_id) == EV_NONE:
        return ACCUM_NONE
    return ACCUM_FP32


def cpu_site_accum_policy(site_id: Int) -> Int:
    if cpu_site_name(site_id) == String(""):
        return ACCUM_NONE
    return ACCUM_FP32


# ---------------------------------------------------------------------------
# Evidence accumulators (emulation). These are measurement instruments,
# not engine paths: they reproduce, on the host, exactly what a kernel
# WOULD compute if its accumulator register were the named dtype.
# ---------------------------------------------------------------------------


def round_accum(value: Float32, mode: Int) -> Float32:
    # Round a running sum to the emulated accumulator dtype.
    if mode == MODE_FP16:
        return value.cast[DType.float16]().cast[DType.float32]()
    if mode == MODE_BF16:
        return value.cast[DType.bfloat16]().cast[DType.float32]()
    return value


def dot_accum(w: List[Float32], x: List[Float32], mode: Int) raises -> Float64:
    # Serial dot product under the named accumulation mode. MODE_F64 is
    # the reference: products and sum in Float64 over the exact stored
    # Float32 inputs. Other modes form products in Float32 and round
    # the running sum to the accumulator dtype after every addition.
    if len(w) != len(x):
        raise Error("dot_accum: length mismatch")
    if mode == MODE_F64:
        var acc = Float64(0.0)
        for i in range(len(w)):
            acc += Float64(w[i]) * Float64(x[i])
        return acc
    if mode != MODE_FP32 and mode != MODE_FP16 and mode != MODE_BF16:
        raise Error("dot_accum: unknown mode")
    var acc = Float32(0.0)
    for i in range(len(w)):
        acc = round_accum(acc + w[i] * x[i], mode)
    return Float64(acc)


def sumsq_accum(x: List[Float32], mode: Int) raises -> Float64:
    # Sum of squares under the named accumulation mode (RMSNorm core).
    if mode == MODE_F64:
        var acc = Float64(0.0)
        for i in range(len(x)):
            acc += Float64(x[i]) * Float64(x[i])
        return acc
    if mode != MODE_FP32 and mode != MODE_FP16 and mode != MODE_BF16:
        raise Error("sumsq_accum: unknown mode")
    var acc = Float32(0.0)
    for i in range(len(x)):
        acc = round_accum(acc + x[i] * x[i], mode)
    return Float64(acc)


def mass_accum(terms: List[Float32], mode: Int) raises -> Float64:
    # Plain sum of positive terms (softmax denominator / sampling
    # exp-mass shape) under the named accumulation mode.
    if mode == MODE_F64:
        var acc = Float64(0.0)
        for i in range(len(terms)):
            acc += Float64(terms[i])
        return acc
    if mode != MODE_FP32 and mode != MODE_FP16 and mode != MODE_BF16:
        raise Error("mass_accum: unknown mode")
    var acc = Float32(0.0)
    for i in range(len(terms)):
        acc = round_accum(acc + terms[i], mode)
    return Float64(acc)


struct AccumLcg:
    # Deterministic generator shared by the test and bench batteries
    # (same construction as the A-047 precision probe).
    var state: UInt64

    def __init__(out self, seed: UInt64):
        self.state = seed

    def next(mut self) -> UInt64:
        self.state = (
            self.state * 6364136223846793005 + 1442695040888963407
        )
        return self.state >> 11

    def unit(mut self) -> Float64:
        # Uniform in [0, 1).
        return Float64(self.next() % 9007199254740992) / 9007199254740992.0

    def gauss(mut self) -> Float64:
        # Roughly standard-normal via summed uniforms (deterministic;
        # distribution shape only needs to be activation-like).
        var s = Float64(0.0)
        for _ in range(4):
            s += self.unit()
        return (s - 2.0) * 1.224744871391589


def gen_activation(mut lcg: AccumLcg, n: Int, scale: Float64) -> List[Float32]:
    var out = List[Float32]()
    for _ in range(n):
        out.append(Float32(lcg.gauss() * scale))
    return out^


def gen_weights(
    mut lcg: AccumLcg, n: Int, scale: Float64
) -> List[Float32]:
    # Dequantized-weight-like values: small, roughly symmetric.
    var out = List[Float32]()
    for _ in range(n):
        out.append(Float32((lcg.unit() * 2.0 - 1.0) * scale))
    return out^
