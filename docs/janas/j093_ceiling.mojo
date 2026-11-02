"""J-093 memory ceiling harness: the ceiling tables
for the dense ladder witness and the combined
process, printed from core/memory_ceiling.mojo.

Form A witness (fixed, stated): Qwen2.5-Coder-7B
(28 layers, hidden 3584, ffn 18944, 28 query heads,
4 kv heads, head_dim 128, vocab 152064, profile cap
32768), Q4_K_M file 4,683,074,688 B (sha256
8053aeda222ba79e865a6eddd268332fd4e4dbe406371318d6df1f9beae9502b,
the wave crown pin). GPU machine facts: usable VRAM
5,368,709,120 B (J-031, purplelongship RTX 2060) --
filed in the head line for context; the ceiling
itself is the admission total, not a fit claim.
Activation elements 208,896 fixed + 28 per context
token (the profile's own activation_elements shape);
sampling device bytes 905,728 (core/sampling_config),
GPU line only.

Form B stated machine (an accounting input in the
J-018/J-026 test style, not a measured machine):
total = free-at-open = 17,179,869,184 B (16 GiB),
hard cap unset, tenants N = 2. MoE tenant: OLMoE
(resident 311,027,712 B, routed body 3,900,702,720 B,
per-token routed demand 487,587,840 B, KV at context
512 -- its J-022/J-030 standard configuration --
f16 131,072 B/token, int8 67,584 B/token CF;
activation allowance 16,777,216 B, J-031).

Per rung and precision one CEILING line prints the
Form A session peak (write-leg session context) per
line with its itemised KV and activation, the read
leg's GPU total, the KV share of the GPU peak, and
the read/write peak verdicts per line under the
tree's integration facts (int8 integrated on neither
line); one COMBINED line prints Form B's summed KV
and scratch, the pool's reserve/budget/floor, the
combined peak and accounted ceiling, and the
below-floor flag. One GROWTH line per line/precision
(form A) and per precision (form B) prints the
top/base ratio in floored ppm beside Janas's
published shape ratio (1,884,615 ppm) and the
pre-registered verdict.

Every number is exact arithmetic through
core/kv_ladder / core/kv_account / core/kv_int8 /
core/expert_cache via core/memory_ceiling. NO LIVE
PEAK IS MEASURED OR PRINTED: this VM is below its
inference gate and purplelongship is unreachable;
every live peak is deferred to the J-098 gate recipe
in the J-093 doc (section 7). Deterministic:
identical output on every run.
"""
from core.kv_ladder import (
    LADDER_GEN_TOKENS,
    LADDER_LINE_CPU,
    LADDER_LINE_GPU,
    LADDER_PRECISION_F16,
    LADDER_PRECISION_INT8,
    LADDER_READ,
    LADDER_RUNG_COUNT,
    LADDER_WRITE,
    ladder_rung,
    ladder_verdict_name,
)
from core.memory_ceiling import (
    JANAS_SHAPE_RATIO_PPM,
    ceiling_activation_bytes,
    ceiling_arbiter,
    ceiling_combined_accounted,
    ceiling_combined_peak,
    ceiling_dense_peak_at_rung,
    ceiling_kv_at_context,
    ceiling_peak_verdict,
    ceiling_pool_sizing,
    ceiling_ratio_ppm,
    ceiling_shape_name,
    ceiling_shape_verdict,
    ceiling_share_ppm,
)

comptime LAYERS = 28
comptime KV_HEADS = 4
comptime HEAD_DIM = 128
comptime PROFILE_CAP = 32768
comptime WEIGHTS = 4683074688
comptime ACT_FIXED = 208896
comptime ACT_PER_CONTEXT = 28
comptime SAMPLING = 905728
comptime USABLE = 5368709120
comptime OLMOE_LAYERS = 16
comptime OLMOE_KV_HEADS = 16
comptime OLMOE_RESIDENT = 311027712
comptime OLMOE_BODY = 3900702720
comptime OLMOE_ROUTED = 487587840
comptime OLMOE_KV_F16_AT_512 = 67108864
comptime OLMOE_KV_INT8_AT_512 = 34603008
comptime OLMOE_ACT_ALLOWANCE = 16777216
comptime RESIDENT_TOTAL = 4994102400
comptime STATED_TOTAL = 17179869184


def _olmoe_kv(precision: Int) -> Int:
    return OLMOE_KV_F16_AT_512 if precision == LADDER_PRECISION_F16 else OLMOE_KV_INT8_AT_512


def _prec_name(precision: Int) -> String:
    return String("f16") if precision == LADDER_PRECISION_F16 else String("int8")


def main() raises:
    print(
        "CEILHEAD model=qwen2.5-coder-7b weights="
        + String(WEIGHTS)
        + " gen="
        + String(LADDER_GEN_TOKENS)
        + " usable_gpu="
        + String(USABLE)
        + " stated_total="
        + String(STATED_TOTAL)
        + " janas_ratio_ppm="
        + String(JANAS_SHAPE_RATIO_PPM)
    )
    var precisions = List[Int]()
    precisions.append(LADDER_PRECISION_F16)
    precisions.append(LADDER_PRECISION_INT8)
    for precision in precisions:
        var base_gpu = 0
        var top_gpu = 0
        var base_cpu = 0
        var top_cpu = 0
        var base_comb = 0
        var top_comb = 0
        for i in range(LADDER_RUNG_COUNT):
            var rung = ladder_rung(i)
            var session = rung + LADDER_GEN_TOKENS
            var kv_sess = ceiling_kv_at_context(
                LAYERS, KV_HEADS, HEAD_DIM, precision, session
            )
            var act_sess = ceiling_activation_bytes(
                ACT_FIXED, ACT_PER_CONTEXT, session
            )
            var gpu_peak = ceiling_dense_peak_at_rung(
                WEIGHTS, LAYERS, KV_HEADS, HEAD_DIM, precision, rung,
                LADDER_WRITE, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING, LADDER_LINE_GPU,
            )
            var cpu_peak = ceiling_dense_peak_at_rung(
                WEIGHTS, LAYERS, KV_HEADS, HEAD_DIM, precision, rung,
                LADDER_WRITE, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING, LADDER_LINE_CPU,
            )
            var gpu_read = ceiling_dense_peak_at_rung(
                WEIGHTS, LAYERS, KV_HEADS, HEAD_DIM, precision, rung,
                LADDER_READ, ACT_FIXED, ACT_PER_CONTEXT, SAMPLING, LADDER_LINE_GPU,
            )
            print(
                "CEILING L="
                + String(rung)
                + " prec="
                + _prec_name(precision)
                + " session="
                + String(session)
                + " kv_sess="
                + String(kv_sess)
                + " act_sess="
                + String(act_sess)
                + " gpu_read="
                + String(gpu_read)
                + " gpu_peak="
                + String(gpu_peak)
                + " cpu_peak="
                + String(cpu_peak)
                + " kv_share_gpu_ppm="
                + String(ceiling_share_ppm(kv_sess, gpu_peak))
                + " cpu_read_verdict="
                + ladder_verdict_name(
                    ceiling_peak_verdict(
                        LADDER_LINE_CPU, precision, rung, LADDER_READ,
                        False, False, PROFILE_CAP,
                    )
                )
                + " cpu_peak_verdict="
                + ladder_verdict_name(
                    ceiling_peak_verdict(
                        LADDER_LINE_CPU, precision, rung, LADDER_WRITE,
                        False, False, PROFILE_CAP,
                    )
                )
                + " gpu_read_verdict="
                + ladder_verdict_name(
                    ceiling_peak_verdict(
                        LADDER_LINE_GPU, precision, rung, LADDER_READ,
                        False, False, PROFILE_CAP,
                    )
                )
                + " gpu_peak_verdict="
                + ladder_verdict_name(
                    ceiling_peak_verdict(
                        LADDER_LINE_GPU, precision, rung, LADDER_WRITE,
                        False, False, PROFILE_CAP,
                    )
                )
            )
            var kv_total = kv_sess + _olmoe_kv(precision)
            var scratch = act_sess + OLMOE_ACT_ALLOWANCE
            var sizing = ceiling_pool_sizing(
                STATED_TOTAL, STATED_TOTAL, RESIDENT_TOTAL, kv_total,
                scratch, OLMOE_ROUTED,
            )
            var comb = ceiling_combined_peak(
                RESIDENT_TOTAL, kv_total, scratch, sizing.budget_bytes, OLMOE_BODY
            )
            var accounted = ceiling_combined_accounted(
                RESIDENT_TOTAL, kv_total, scratch, sizing.budget_bytes
            )
            print(
                "COMBINED L="
                + String(rung)
                + " prec="
                + _prec_name(precision)
                + " kv_total="
                + String(kv_total)
                + " scratch_total="
                + String(scratch)
                + " reserve="
                + String(sizing.reserve_bytes)
                + " pool="
                + String(sizing.budget_bytes)
                + " floor="
                + String(ceiling_arbiter(sizing.budget_bytes, 2).floor_bytes)
                + " combined_peak="
                + String(comb)
                + " accounted_ceiling="
                + String(accounted)
                + " below_floor="
                + String(sizing.below_floor)
            )
            if i == 0:
                base_gpu = gpu_peak
                base_cpu = cpu_peak
                base_comb = comb
            if i == LADDER_RUNG_COUNT - 1:
                top_gpu = gpu_peak
                top_cpu = cpu_peak
                top_comb = comb
        var ratio_gpu = ceiling_ratio_ppm(top_gpu, base_gpu)
        var ratio_cpu = ceiling_ratio_ppm(top_cpu, base_cpu)
        var ratio_comb = ceiling_ratio_ppm(top_comb, base_comb)
        print(
            "GROWTH prec="
            + _prec_name(precision)
            + " gpu_ratio_ppm="
            + String(ratio_gpu)
            + " gpu_shape="
            + ceiling_shape_name(ceiling_shape_verdict(ratio_gpu))
            + " cpu_ratio_ppm="
            + String(ratio_cpu)
            + " cpu_shape="
            + ceiling_shape_name(ceiling_shape_verdict(ratio_cpu))
            + " combined_ratio_ppm="
            + String(ratio_comb)
            + " combined_shape="
            + ceiling_shape_name(ceiling_shape_verdict(ratio_comb))
        )
    print("CEILDONE rungs=5 live_peaks=NOT_PROVEN_DEFERRED_J098")
