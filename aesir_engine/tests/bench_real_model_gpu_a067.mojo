# tests/bench_real_model_gpu_a067.mojo
# A-067: real-model GPU decode battery driver (standalone, not in
# run_all). Usage: bench_real_model_gpu_a067 <fixture.gguf>
#
# Method (raw-oracle discipline, law 3): three RAW prompts (no
# chat template, add_bos=True - the A-004/A-045 standard). The
# CPU engine (AesirEngine on the identical fixture) greedily
# continues each prompt for 8 tokens; that sequence is then
# teacher-forced through BOTH engines. At every position the
# parity_battery library grades the NEXT sequence token in the
# GPU row (rank + logit gap + verdict code) and, as a control,
# in the CPU row. The driver also free-runs a 32-token GPU
# greedy generation from prompt 1 for the coherence sample and
# cross-checks one GPU row's argmax against the A-063
# VulkanSampling greedy kernel on device.
# Divergences are DATA (printed, filed in the A-067 ledger);
# the driver raises only on harness failure.

from std.sys import argv
from std.time import perf_counter_ns
from core.parity_battery import (
    parity_logit_gap,
    parity_logit_rank,
    parity_top_token,
    parity_verdict_code,
    parity_verdict_name,
)
from core.vulkan_buffers import VulkanBuffers
from core.vulkan_gemv import VulkanGemv
from core.vulkan_norm_rope import VulkanNormRope
from core.vulkan_attention import VulkanAttention
from core.vulkan_elementwise import VulkanElementwise
from core.vulkan_sampling import VulkanSampling
from core.vulkan_real_model import VulkanRealModel
from aesir import AesirEngine


def _vk_present() -> Bool:
    if not VulkanBuffers.runtime_available():
        return False
    if not VulkanBuffers.dispatch_available():
        return False
    try:
        var info = VulkanBuffers.device_info()
        if info.vendor_id != 0x1002:
            return False
        if info.device_type == 4:
            return False
        return VulkanBuffers.device_name_is_radv()
    except:
        return False


def _argmax(row: List[Float32]) -> Int:
    var best = 0
    for i in range(len(row)):
        if row[i] > row[best]:
            best = i
    return best


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: bench_real_model_gpu_a067 <fixture.gguf>")
    var path = String(args[1])
    if not _vk_present():
        print("A067_ABSENT no RADV STRIX_HALO device on this host")
        return
    VulkanBuffers.init()
    var info = VulkanBuffers.device_info()
    print("A067_DEVICE vendor=", info.vendor_id, "type=", info.device_type)
    var t0 = perf_counter_ns()
    var engine = AesirEngine(path)
    var t1 = perf_counter_ns()
    print("A067_CPU_LOAD_MS", (t1 - t0) // 1_000_000)
    var model = VulkanRealModel(path)
    model.load()
    var t2 = perf_counter_ns()
    print("A067_GPU_LOAD_MS", (t2 - t1) // 1_000_000)
    print(
        "A067_MODEL layers=", model.layers, "dim=", model.dim,
        "ffn=", model.ffn, "heads=", model.heads,
        "kv_heads=", model.kv_heads, "head_dim=", model.head_dim,
        "vocab=", model.vocab,
    )
    var prompts = List[String]()
    prompts.append("The capital of France is")
    prompts.append("Water is made of hydrogen and")
    prompts.append("The quick brown fox jumps over the")
    var total_f = 0
    var total_n = 0
    var total_d = 0
    var total_pos = 0
    var total_agree = 0
    var total_nonfinite = 0
    for pi in range(len(prompts)):
        var prompt = prompts[pi]
        var ids = engine.tokenizer.encode(prompt, True)
        var cont = engine.generate_tokens(prompt, 8)
        var seq = ids.copy()
        for i in range(len(cont.token_ids)):
            seq.append(cont.token_ids[i])
        var cpu_rows = engine.teacher_forcing_logit_rows(seq)
        model.reset_kv()
        var gpu_rows = List[List[Float32]]()
        var tg0 = perf_counter_ns()
        for p in range(len(seq)):
            gpu_rows.append(model.decode_step(seq[p], p))
            total_nonfinite += model.last_nonfinite_count
        var tg1 = perf_counter_ns()
        print(
            "A067_GPU_TF_MS prompt=", pi,
            "ms=", (tg1 - tg0) // 1_000_000,
            "positions=", len(seq),
        )
        var f = 0
        var n = 0
        var d = 0
        var worst_rank = 0
        var max_gap = Float32(0.0)
        var agree = 0
        var cpu_f = 0
        for p in range(len(seq) - 1):
            var target = seq[p + 1]
            var rank = parity_logit_rank(gpu_rows[p], target)
            var gap = parity_logit_gap(gpu_rows[p], target)
            var code = parity_verdict_code(rank, gap)
            var o_rank = parity_logit_rank(cpu_rows[p], target)
            var o_gap = parity_logit_gap(cpu_rows[p], target)
            var o_code = parity_verdict_code(o_rank, o_gap)
            if o_code == 0 or o_code == 1:
                cpu_f += 1
            if code == 0:
                f += 1
            elif code == 1:
                n += 1
            else:
                d += 1
                print(
                    "A067_POS prompt=", pi, "pos=", p,
                    "target=", target, "rank=", rank, "gap=", gap,
                    "verdict=", parity_verdict_name(code),
                    "gpu_top=", parity_top_token(gpu_rows[p]),
                    "cpu_rank=", o_rank, "cpu_gap=", o_gap,
                )
            if rank > worst_rank:
                worst_rank = rank
            if gap > max_gap:
                max_gap = gap
            if parity_top_token(gpu_rows[p]) == parity_top_token(cpu_rows[p]):
                agree += 1
        var positions = len(seq) - 1
        print(
            "A067_SUMMARY prompt=", pi, "faithful=", f, "near_tie=", n,
            "divergent=", d, "positions=", positions,
            "worst_rank=", worst_rank, "max_gap=", max_gap,
            "top1_agree=", agree, "cpu_control_faithful=", cpu_f,
        )
        total_f += f
        total_n += n
        total_d += d
        total_pos += positions
        total_agree += agree
    print(
        "A067_BATTERY faithful=", total_f, "near_tie=", total_n,
        "divergent=", total_d, "positions=", total_pos,
        "top1_agree=", total_agree, "nonfinite_sanitized=", total_nonfinite,
    )
    # Dispatch evidence around one fresh decode step.
    var c_q4k0 = VulkanBuffers.q4k_gemv_dispatch_count()
    var c_q60 = VulkanGemv.q6_dispatch_count()
    var c_q50 = VulkanGemv.q5_dispatch_count()
    var c_rms0 = VulkanNormRope.rmsnorm_dispatch_count()
    var c_rope0 = VulkanNormRope.rope_dispatch_count()
    var c_attn0 = VulkanAttention.dispatch_count()
    var c_elem0 = VulkanElementwise.elementwise_dispatch_count()
    model.reset_kv()
    var probe_ids = engine.tokenizer.encode(prompts[0], True)
    var row0 = model.decode_step(probe_ids[0], 0)
    print(
        "A067_DISPATCH q4k=", VulkanBuffers.q4k_gemv_dispatch_count() - c_q4k0,
        "q6k=", VulkanGemv.q6_dispatch_count() - c_q60,
        "q5k=", VulkanGemv.q5_dispatch_count() - c_q50,
        "rmsnorm=", VulkanNormRope.rmsnorm_dispatch_count() - c_rms0,
        "rope=", VulkanNormRope.rope_dispatch_count() - c_rope0,
        "attn=", VulkanAttention.dispatch_count() - c_attn0,
        "elementwise=", VulkanElementwise.elementwise_dispatch_count() - c_elem0,
        "live_bytes=", VulkanBuffers.live_bytes(),
        "live_count=", VulkanBuffers.live_count(),
    )
    # Greedy cross-check: device sampling kernel vs host argmax
    # on the identical sanitized row.
    var host_best = _argmax(row0)
    var dev_best = model.gpu_greedy_token(row0)
    print(
        "A067_GREEDY_XCHECK host=", host_best, "device=", dev_best,
        "agree=", host_best == dev_best,
    )
    # Free-running GPU greedy generation sample (coherence).
    var gen_ids = model.greedy_from(probe_ids, 32)
    var text = String("")
    for i in range(len(gen_ids)):
        text += engine.tokenizer.decode(gen_ids[i])
    print("A067_GEN_TOKENS", len(gen_ids))
    for i in range(len(gen_ids)):
        print("A067_GEN_ID", i, gen_ids[i])
    print("A067_GEN_TEXT_BEGIN")
    print(text)
    print("A067_GEN_TEXT_END")
    print("A067_DONE")
