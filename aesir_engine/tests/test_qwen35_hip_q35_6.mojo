# tests/test_qwen35_hip_q35_6.mojo
# Q35-6a: HIP execution for qwen35, fixture-grade proof.
#
# Fixture: aesir_engine/tests/fixtures/qwen35_forward.gguf (the
# Q35-3a forward fixture; hidden 128, 4 blocks, interval 4 =>
# 3 delta-net layers + 1 full-attention layer, rope 64/64 on the
# fixture -- the kernel implements the general partial case).
#
# Usage: test_qwen35_hip_q35_6 <qwen35_forward.gguf>
#
# Proves (device admitted beside the live gate; the shell wrapper
# checks gate health + MemAvailable before and after):
#  (a) the HIP executor constructs on the fixture under the
#      Q8_0-resident admission (every large weight Q8_0 by name);
#  (b) TRAJECTORY: per-token device forward vs the CPU engine on
#      the same token stream -- after EVERY token the device SSM
#      state (s + conv rings, read back from the device buffer)
#      and the logits are compared elementwise to the CPU state;
#      diffs printed against the Q35-3a (c) band (s 0.0008479953 /
#      conv 0.0078125 / logits 0.013671875). Bit-exactness is
#      claimed only at measured 0.0; the fallback grade is
#      teacher-forcing rank + logit gap of the device argmax in
#      the CPU logit row (near-tie: rank <= 2, sub-logit gap).
#  (c) GREEDY: 16 device-argmax continuations vs the CPU greedy
#      sequence (identical sequence = the trajectory grade that
#      matters for serve).
#  (d) BATCHED vs GEMV-LOOP prefill on device: final state +
#      logits diffs (device-vs-device, same kernels).
#  (e) PREFILL MEASUREMENT: 64-token prefill timed both ways
#      (per-token GEMV loop vs batched GEMM), printed with tok/s;
#      the session's strategy follows the measured winner.
#  (f) SNAPSHOT SEAM: state + KV readback at a boundary,
#      writeback into a reset executor, continuation logits vs
#      the resident continuation (byte-copy seam: 0.0 expected).
#
# Fail-closed: without the gfx1151 HIP gate the test asserts the
# executor raises and passes as honest-absent (A-082 discipline).

from std.sys import argv
from std.time import perf_counter_ns

from core.mimir_well import KVCache
from core.hip_gemv import HipGemv
from core.qwen35_hip import Qwen35HipExecutor
from aesir import AesirEngine, GenerationConfig


def argmax_row(row: List[Float32]) -> Int:
    var best = 0
    for i in range(len(row)):
        if row[i] > row[best]:
            best = i
    return best


def max_abs_diff(a: List[Float32], b: List[Float32]) -> Float32:
    var m = Float32(0.0)
    var n = min(len(a), len(b))
    for i in range(n):
        var d = a[i] - b[i]
        if d < Float32(0.0):
            d = -d
        if d > m:
            m = d
    return m


def rank_and_gap(cpu_logits: List[Float32], token: Int) -> Tuple[Int, Float32]:
    var target = cpu_logits[token]
    var rank = 1
    var best = cpu_logits[argmax_row(cpu_logits)]
    for i in range(len(cpu_logits)):
        if cpu_logits[i] > target:
            rank += 1
    return (rank, best - target)


def cpu_state_image(mut engine: AesirEngine) -> List[Float32]:
    ref st = engine.qwen35_state
    var s_n = st.ssm_layer_count * st.head_count * st.d_state * st.d_state
    var c_n = st.ssm_layer_count * max(0, st.conv_kernel - 1) * st.conv_dim
    var out = List[Float32](capacity=s_n + c_n)
    for i in range(s_n):
        out.append(Float32(st.s_data.unsafe_load(i)))
    for i in range(c_n):
        out.append(Float32(st.conv_data.unsafe_load(i)))
    return out^


def main() raises:
    var path = String(argv()[1])
    if not HipGemv.gate_ok():
        var refused = False
        try:
            var ex = Qwen35HipExecutor(path, 512)
            _ = ex
        except:
            refused = True
        if not refused:
            raise Error("Q35-6: executor must refuse when the HIP gate is absent")
        print("Q35-6 HIP gate absent: executor refused fail-closed (honest-absent)")
        print("Q35_6_TEST ALL PASS (honest-absent)")
        return
    print("Q35-6 HIP gate ok: device=", HipGemv.device_name())
    var cfg = GenerationConfig(max_new_tokens=16, temperature=Float32(0.0), top_k=40, top_p=Float32(0.9), repetition_penalty=Float32(1.0), seed=UInt64(42))  # Q35-6 H1: pinned banked greedy config (test_qwen35_forward_q35_3 line 97); GenerationConfig() defaults (temp 0.7, rep 1.1) made the old (c) compare device argmax vs a SAMPLED CPU stream
    var prompt = List[Int]()
    prompt.append(1); prompt.append(3); prompt.append(17); prompt.append(42)
    # (a) + (b): per-token trajectory, CPU vs device.
    var engine = AesirEngine(path, knowledge_capacity=1)
    engine.pool.offset = engine.runtime_offset
    var kv = KVCache(64, engine.parser.config.kv_dim(), engine.pool, engine.parser.config.block_count)
    kv.capture_logit_row = True
    var ex = Qwen35HipExecutor(path, 512)
    print("Q35-6 (a) executor constructed: layers=", ex.profile.layer_count, " ssm_layers=", ex.profile.ssm_layers(), " attn_layers=", ex.profile.full_attention_layers())
    var s_elems = ex.s_elems
    var worst_s = Float32(0.0)
    var worst_c = Float32(0.0)
    var worst_l = Float32(0.0)
    var worst_rank = 0
    var worst_gap = Float32(0.0)
    var stream = prompt.copy()
    var cpu_next = -1
    var last_dev_logits = List[Float32]()
    for pos in range(len(prompt)):
        cpu_next = engine._forward_position(stream, kv, pos, cfg, pos < len(prompt) - 1)
        var cpu_logits = kv.last_logit_row.copy()
        var dev_logits = ex.forward_chunk(List[Int]([stream[pos]]), pos, True, 1)
        last_dev_logits = dev_logits.copy()
        var cpu_img = cpu_state_image(engine)
        var dev_img = ex.readback_state()
        var dev_s = List[Float32]()
        var cpu_s = List[Float32]()
        var dev_c = List[Float32]()
        var cpu_c = List[Float32]()
        for i in range(s_elems):
            dev_s.append(dev_img[i]); cpu_s.append(cpu_img[i])
        for i in range(s_elems, len(dev_img)):
            dev_c.append(dev_img[i]); cpu_c.append(cpu_img[i])
        var ds = max_abs_diff(dev_s, cpu_s)
        var dc = max_abs_diff(dev_c, cpu_c)
        var dl = max_abs_diff(dev_logits, cpu_logits)
        var rg = rank_and_gap(cpu_logits, argmax_row(dev_logits))
        print("Q35-6 (b) pos=", pos, " s_diff=", ds, " conv_diff=", dc, " logits_diff=", dl, " dev_argmax_rank_in_cpu=", rg[0], " gap=", rg[1])
        if ds > worst_s: worst_s = ds
        if dc > worst_c: worst_c = dc
        if dl > worst_l: worst_l = dl
        if rg[0] > worst_rank: worst_rank = rg[0]
        if rg[1] > worst_gap: worst_gap = rg[1]
    print("Q35-6 (b) WORST s=", worst_s, " conv=", worst_c, " logits=", worst_l, " rank=", worst_rank, " gap=", worst_gap)
    print("Q35-6 (b) BAND q35-3a(c): s 0.0008479953 / conv 0.0078125 / logits 0.013671875")
    # (c): greedy continuation -- both engines sit exactly after
    # the prompt (CPU next-token in hand, device logits in hand).
    var cpu_seq = List[Int]()
    var dev_seq = List[Int]()
    var cpu_stream = stream.copy()
    var dlog = last_dev_logits.copy()
    for _ in range(16):
        cpu_seq.append(cpu_next)
        dev_seq.append(argmax_row(dlog))
        cpu_stream.append(cpu_next)
        cpu_next = engine._forward_position(cpu_stream, kv, len(cpu_stream) - 1, cfg, False)
        var dnxt = argmax_row(dlog)
        dlog = ex.forward_chunk(List[Int]([dnxt]), len(cpu_stream) - 1, True, 1)
    var same = True
    for i in range(len(cpu_seq)):
        if dev_seq[i] != cpu_seq[i]:
            same = False
    var cpu_str = String("")
    var dev_str = String("")
    for i in range(len(cpu_seq)):
        cpu_str += String(cpu_seq[i]) + " "
        dev_str += String(dev_seq[i]) + " "
    print("Q35-6 (c) cpu_greedy=", cpu_str)
    print("Q35-6 (c) dev_greedy=", dev_str)
    print("Q35-6 (c) greedy_identical=", same)
    if not same:
        raise Error("Q35-6 (c): device greedy sequence diverged from the CPU greedy sequence")
    # (d): batched vs GEMV-loop prefill on device (fresh executors,
    # prompt only): final state + logits must agree closely (same
    # kernels; only the projection batching differs).
    var ex3 = Qwen35HipExecutor(path, 512)
    var batched_logits = ex3.forward_chunk(prompt.copy(), 0, True, 32)
    var batched_img = ex3.readback_state()
    var exl = Qwen35HipExecutor(path, 512)
    var loop_logits = List[Float32]()
    for pos in range(len(prompt)):
        loop_logits = exl.forward_chunk(List[Int]([prompt[pos]]), pos, True, 1)
    var loop_img = exl.readback_state()
    var d_state = max_abs_diff(batched_img, loop_img)
    var d_logits = max_abs_diff(batched_logits, loop_logits)
    print("Q35-6 (d) batched_vs_loop state_diff=", d_state, " logits_diff=", d_logits)
    if d_state > Float32(0.001) or d_logits > Float32(0.01):
        raise Error("Q35-6 (d): batched and loop prefill disagree beyond rounding")
    # (e): prefill measurement, 64 tokens both ways.
    var bench_tokens = List[Int]()
    for i in range(64):
        bench_tokens.append(prompt[i % len(prompt)])
    var ex4 = Qwen35HipExecutor(path, 512)
    var t0 = perf_counter_ns()
    _ = ex4.forward_chunk(bench_tokens.copy(), 0, False, 1)
    var loop_ns = perf_counter_ns() - t0
    var ex5 = Qwen35HipExecutor(path, 512)
    t0 = perf_counter_ns()
    _ = ex5.forward_chunk(bench_tokens.copy(), 0, False, 32)
    var batch_ns = perf_counter_ns() - t0
    print("Q35-6 (e) prefill 64 tokens: gemv_loop_ms=", Float64(loop_ns) / 1e6, " batched_ms=", Float64(batch_ns) / 1e6, " gemv_loop_tok_s=", Float64(64) / (Float64(loop_ns) / 1e9), " batched_tok_s=", Float64(64) / (Float64(batch_ns) / 1e9))
    # (f): snapshot seam on ex5 (state after 64 bench tokens).
    var img = ex5.readback_state()
    var kvimg = ex5.readback_kv_prefix(64)
    var cont_logits_resident = ex5.forward_chunk(List[Int]([7]), 64, True, 1)
    var ex6 = Qwen35HipExecutor(path, 512)
    ex6.writeback_state(img)
    ex6.writeback_kv_prefix(kvimg, 64)
    var cont_logits_restored = ex6.forward_chunk(List[Int]([7]), 64, True, 1)
    var f_diff = max_abs_diff(cont_logits_resident, cont_logits_restored)
    print("Q35-6 (f) snapshot_restore_continuation_logits_diff=", f_diff)
    if f_diff != Float32(0.0):
        raise Error("Q35-6 (f): snapshot writeback continuation is not bit-exact on the device path")
    print("Q35_6_TEST ALL PASS")
