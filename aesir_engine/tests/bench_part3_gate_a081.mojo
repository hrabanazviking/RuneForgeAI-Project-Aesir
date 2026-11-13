# tests/bench_part3_gate_a081.mojo
# A-081: Part III gate bench (standalone, not in run_all).
# Usage: bench_part3_gate_a081 <fixture.gguf>
#
# Method: the SAME pinned 8B-class Q4 fixture (Meta-Llama-3.1-8B-
# Instruct-Q4_K_M, sha256 7b064f58..557c) decoded greedily on BOTH
# paths on this machine, RAW prompt (no chat template, add_bos=True,
# the A-004/A-045/A-067 standard):
#   CPU: AesirEngine.generate_tokens, PhaseTimings decode span
#        (A-036 disjoint timings), 3 reps.
#   GPU: VulkanRealModel (A-067 path as banked through A-078:
#        A-070 assist accounting, A-074 subgroup attention),
#        prompt teacher-forced untimed, then 32 greedy decode
#        steps timed individually, 3 reps.
# Filed against BOTH gate readings:
#   (a) the roadmap/Capability-Ledger reading: GPU 8B decode
#       tok/s vs 2x the A-030 CPU baseline decode number
#       (8,745.9 tok/s on stories260K) = 17,491.8 tok/s;
#   (b) the same-fixture reading: GPU 8B decode tok/s vs 2x the
#       CPU 8B decode tok/s measured in this same run.
# GPU greedy ids are compared token-exact against the CPU greedy
# ids (raw-oracle discipline). Device execution is proven by the
# RADV STRIX_HALO identity guard (llvmpipe refused) plus the
# A-070 assist/dispatch accounting snapshot at the end.

from std.sys import argv
from std.time import perf_counter_ns
from core.vulkan_buffers import VulkanBuffers
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
        raise Error("usage: bench_part3_gate_a081 <fixture.gguf>")
    var path = String(args[1])
    if not _vk_present():
        print("A081_ABSENT no RADV STRIX_HALO device on this host")
        return
    VulkanBuffers.init()
    var info = VulkanBuffers.device_info()
    print("A081_DEVICE vendor=", info.vendor_id, "type=", info.device_type)
    var prompt = String("The capital of France is")
    var n_decode = 32
    # ---- CPU path on the 8B fixture (the same-fixture baseline) ----
    var engine = AesirEngine(path)
    var prompt_ids = engine.tokenizer.encode(prompt, True)
    print("A081_PROMPT_TOKENS", len(prompt_ids))
    var cpu_ids = List[Int]()
    var cpu_toks = List[Float64]()
    for rep in range(3):
        var cont = engine.generate_tokens(prompt, n_decode)
        var dtoks = Float64(cont.timings.generated_tokens) * 1.0e9 / Float64(cont.timings.decode_ns)
        cpu_toks.append(dtoks)
        print("A081_CPU_REP", rep, "decode_ns=", cont.timings.decode_ns, "generated=", cont.timings.generated_tokens, "tok_s=", dtoks)
        if rep == 0:
            cpu_ids = cont.token_ids.copy()
    var cpu_sorted = cpu_toks.copy()
    # median of 3 = middle value after simple sort
    for i in range(3):
        for j in range(i + 1, 3):
            if cpu_sorted[j] < cpu_sorted[i]:
                var tmp = cpu_sorted[i]
                cpu_sorted[i] = cpu_sorted[j]
                cpu_sorted[j] = tmp
    var cpu_median = cpu_sorted[1]
    print("A081_CPU_MEDIAN_TOK_S", cpu_median)
    # ---- GPU path on the 8B fixture ----
    var model = VulkanRealModel(path)
    var tl0 = perf_counter_ns()
    model.load()
    var tl1 = perf_counter_ns()
    print("A081_GPU_LOAD_MS", (tl1 - tl0) // 1_000_000)
    print("A081_MODEL layers=", model.layers, "dim=", model.dim, "ffn=", model.ffn, "heads=", model.heads, "kv_heads=", model.kv_heads, "head_dim=", model.head_dim, "vocab=", model.vocab)
    var gpu_ids = List[Int]()
    var gpu_toks = List[Float64]()
    for rep in range(3):
        model.reset_kv()
        var row = List[Float32]()
        for p in range(len(prompt_ids)):
            row = model.decode_step(prompt_ids[p], p)
        var pos = len(prompt_ids)
        var rep_ids = List[Int]()
        var t_start = perf_counter_ns()
        for _ in range(n_decode):
            var best = _argmax(row)
            rep_ids.append(best)
            var ts0 = perf_counter_ns()
            row = model.decode_step(best, pos)
            var ts1 = perf_counter_ns()
            _ = ts0
            _ = ts1
            pos += 1
        var t_end = perf_counter_ns()
        # NOTE: the loop above times n_decode decode_steps but the
        # last step produces a row that is never argmaxed; the
        # honest decode rate counts every timed step.
        var gtoks = Float64(n_decode) * 1.0e9 / Float64(t_end - t_start)
        gpu_toks.append(gtoks)
        print("A081_GPU_REP", rep, "decode_wall_ns=", t_end - t_start, "steps=", n_decode, "tok_s=", gtoks)
        if rep == 0:
            gpu_ids = rep_ids.copy()
    var gpu_sorted = gpu_toks.copy()
    for i in range(3):
        for j in range(i + 1, 3):
            if gpu_sorted[j] < gpu_sorted[i]:
                var tmp = gpu_sorted[i]
                gpu_sorted[i] = gpu_sorted[j]
                gpu_sorted[j] = tmp
    var gpu_median = gpu_sorted[1]
    print("A081_GPU_MEDIAN_TOK_S", gpu_median)
    var exact = 0
    var n_cmp = len(cpu_ids)
    if len(gpu_ids) < n_cmp:
        n_cmp = len(gpu_ids)
    for i in range(n_cmp):
        if gpu_ids[i] == cpu_ids[i]:
            exact += 1
    print("A081_ID_EXACT", exact, "of", n_cmp)
    var st = model.assist_stats()
    print("A081_STATS steps=", st.steps, "step_ms_avg=", st.step_ns // st.steps // 1_000_000, "stream_ms_per_step=", st.stream_ns // st.steps // 1_000_000, "stream_mb_per_step=", st.stream_bytes // st.steps // 1_000_000)
    var a030 = Float64(8745.9)
    print("A081_A030_BASELINE_TOK_S", a030)
    print("A081_THRESHOLD_2X_A030_TOK_S", 2.0 * a030)
    print("A081_RATIO_GPU_VS_A030_X1000", Int(gpu_median / a030 * 1000.0))
    print("A081_RATIO_GPU_VS_CPU8B_X1000", Int(gpu_median / cpu_median * 1000.0))
    print("A081_PRIMARY_READING_A", gpu_median >= 2.0 * a030)
    print("A081_PRIMARY_READING_B", gpu_median >= 2.0 * cpu_median)
    print("A081_DONE")
