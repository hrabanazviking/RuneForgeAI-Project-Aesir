# tests/bench_cpu_assist_a070.mojo
# A-070: lawful CPU assist - baseline + inventory driver
# (standalone, not in run_all). Usage:
#   bench_cpu_assist_a070 <fixture.gguf>
#
# Baseline section: external timings on the GPU path as
# banked at A-068 (per-step wall, embed gather, RoPE
# permutation, KV pack replica, sanitize, host argmax vs
# device greedy, allocator pair cost). After the A-070
# instrumentation lands, the same driver also prints the
# in-path CpuAssistStats accounting (A070_STATS lines).
# Raw-oracle discipline: prompts are RAW token ids (no
# template); the CPU engine is only the tokenizer/comparator.

from std.sys import argv
from std.time import perf_counter_ns
from core.vulkan_buffers import VulkanBuffers
from core.vulkan_real_model import (
    VulkanRealModel,
    sanitize_logit_row,
    permute_rope_pairs,
)
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
        raise Error("usage: bench_cpu_assist_a070 <fixture.gguf>")
    var path = String(args[1])
    if not _vk_present():
        print("A070_ABSENT no RADV STRIX_HALO device on this host")
        return
    VulkanBuffers.init()
    var info = VulkanBuffers.device_info()
    print("A070_DEVICE vendor=", info.vendor_id, "type=", info.device_type)
    var engine = AesirEngine(path)
    var ids = engine.tokenizer.encode("The capital of France is", True)
    print("A070_PROMPT_TOKENS", len(ids))
    var model = VulkanRealModel(path)
    var tl0 = perf_counter_ns()
    model.load()
    var tl1 = perf_counter_ns()
    print("A070_GPU_LOAD_MS", (tl1 - tl0) // 1_000_000)
    print(
        "A070_MODEL layers=", model.layers, "dim=", model.dim,
        "kv_dim=", model.kv_dim, "vocab=", model.vocab,
    )
    model.reset_kv()
    var row = List[Float32]()
    var total_steps = 16
    var step_ms = List[Int]()
    for p in range(total_steps):
        var tok: Int
        if p < len(ids):
            tok = ids[p]
        else:
            tok = _argmax(row)
        var t0 = perf_counter_ns()
        row = model.decode_step(tok, p)
        var t1 = perf_counter_ns()
        step_ms.append(Int((t1 - t0) // 1_000_000))
        print("A070_STEP pos=", p, "ms=", step_ms[p], "argmax=", _argmax(row))
    # Embedding gather + dequant of ONE row (host assist).
    var te0 = perf_counter_ns()
    var emb_len = 0
    for _ in range(200):
        var e = model._embed(791)
        emb_len = len(e)
    var te1 = perf_counter_ns()
    print(
        "A070_EMBED_US_PER_CALL", (te1 - te0) // 200 // 1000,
        "row_len=", emb_len,
    )
    # RoPE permutation round trip sizes (host assist, per layer).
    var q = List[Float32]()
    for i in range(model.dim):
        q.append(row[i])
    var tp0 = perf_counter_ns()
    var plen = 0
    for _ in range(200):
        var pq = permute_rope_pairs(q, model.head_dim)
        plen = len(pq)
    var tp1 = perf_counter_ns()
    print(
        "A070_PERMUTE_Q_US_PER_CALL", (tp1 - tp0) // 200 // 1000,
        "len=", plen,
    )
    var kk = List[Float32]()
    for i in range(model.kv_dim):
        kk.append(row[i])
    var tp2 = perf_counter_ns()
    for _ in range(200):
        var pk = permute_rope_pairs(kk, model.head_dim)
        plen = len(pk)
    var tp3 = perf_counter_ns()
    print(
        "A070_PERMUTE_K_US_PER_CALL", (tp3 - tp2) // 200 // 1000,
        "len=", plen,
    )
    # Sanitize scan over the full vocab row (host assist).
    var ts0 = perf_counter_ns()
    var replaced = 0
    for _ in range(200):
        var rc = row.copy()
        replaced = sanitize_logit_row(rc)
    var ts1 = perf_counter_ns()
    print(
        "A070_SANITIZE_US_PER_CALL", (ts1 - ts0) // 200 // 1000,
        "replaced=", replaced,
    )
    # Host argmax over the row already on host (host assist).
    var ta0 = perf_counter_ns()
    var best = 0
    for _ in range(200):
        best = _argmax(row)
    var ta1 = perf_counter_ns()
    print(
        "A070_HOST_ARGMAX_US_PER_CALL", (ta1 - ta0) // 200 // 1000,
        "best=", best,
    )
    # Device greedy alternative: upload row + dispatch + read.
    var tg0 = perf_counter_ns()
    var gbest = 0
    for _ in range(20):
        gbest = model.gpu_greedy_token(row)
    var tg1 = perf_counter_ns()
    print(
        "A070_GPU_GREEDY_US_PER_CALL", (tg1 - tg0) // 20 // 1000,
        "best=", gbest,
    )
    # Allocator pair cost (A-066 decode loop churn model).
    var tb0 = perf_counter_ns()
    for _ in range(1000):
        var a = VulkanBuffers.allocate(16384)
        VulkanBuffers.free(a)
    var tb1 = perf_counter_ns()
    print("A070_ALLOC_FREE_US_PER_PAIR", (tb1 - tb0) // 1000 // 1000)
    # KV pack replica for layer 0 at the final position
    # (host assist as written in VulkanRealModel._layer).
    var kv_len = total_steps
    var tk0 = perf_counter_ns()
    var pack_len = 0
    for _ in range(20):
        var kpack = List[Float32]()
        var vpack = List[Float32]()
        for hh in range(model.kv_heads):
            for p in range(kv_len):
                var src_base = p * model.kv_dim + hh * model.head_dim
                for d in range(model.head_dim):
                    kpack.append(model._k_hist[0][src_base + d])
                    vpack.append(model._v_hist[0][src_base + d])
        pack_len = len(kpack)
    var tk1 = perf_counter_ns()
    print(
        "A070_KVPACK_REPLICA_US_PER_LAYER", (tk1 - tk0) // 20 // 1000,
        "pack_floats=", pack_len, "kv_len=", kv_len,
    )
    var st = model.assist_stats()
    print("A070_STATS steps=", st.steps, "step_ms_avg=", st.step_ns // st.steps // 1_000_000)
    print("A070_STATS stream_uploads=", st.stream_uploads, "stream_mb=", st.stream_bytes // 1_000_000, "stream_ms_per_step=", st.stream_ns // st.steps // 1_000_000)
    print("A070_STATS gains_uploads=", st.gains_uploads, "gains_us_per_step=", st.gains_ns // st.steps // 1000)
    print("A070_STATS embed_calls=", st.embed_calls, "embed_us_per_step=", st.embed_ns // st.steps // 1000)
    print("A070_STATS permute_calls=", st.permute_calls, "permute_us_per_step=", st.permute_ns // st.steps // 1000)
    print("A070_STATS kvpack_calls=", st.kvpack_calls, "kvpack_us_per_step=", st.kvpack_ns // st.steps // 1000, "kvpack_kb_per_step=", st.kvpack_bytes // st.steps // 1000)
    print("A070_STATS logits_kb_per_step=", st.logits_readback_bytes // st.steps // 1000, "logits_us_per_step=", st.logits_ns // st.steps // 1000)
    print("A070_STATS sanitize_us_per_step=", st.sanitize_ns // st.steps // 1000)
    print("A070_STATS assist_ms_per_step=", st.assist_ns() // st.steps // 1_000_000, "assist_pct_x10=", st.assist_ns() * 1000 // st.step_ns)
    model.close()
    print("A070_DONE")
