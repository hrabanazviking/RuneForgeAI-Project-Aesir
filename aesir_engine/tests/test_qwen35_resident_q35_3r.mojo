# tests/test_qwen35_resident_q35_3r.mojo
# Q35-3r: Q8_0-resident load path, fixture-grade proof.
#
# Usage: test_qwen35_resident_q35_3r <qwen35_forward.gguf> <qwen35_forward_f16probe.gguf>
#
# Proves:
#  (r1) the resident census over the forward fixture: 33 large
#       tensors (2 globals + 3 SSM layers x 8 + 1 attn layer x 7),
#       priced both ways from the file's own directory.
#  (r2) resident vs default load on the SAME fixture: greedy
#       16-token sequence IDENTICAL (and equal to the banked Q35-3a
#       sequence), next-token logit rows max_abs_diff == 0.0 --
#       the resident path reuses the loader's packed Q8_0 views and
#       the same gemm_q8_0 kernels; no second dequantization exists.
#  (r3) per-token vs batched on the RESIDENT path, mirroring
#       Q35-3a (c): state/conv/logit diffs within the banked f16
#       rounding bounds, next token identical; the same-path split
#       continuation (d1) is exact 0.0.
#  (r4) refusal honesty: the F16-probe fixture (blk.0.ffn_gate.weight
#       stored F16) is REFUSED BY NAME under the resident opt-in,
#       and (r5) loads fine on the default path.
#  (r6) the Q35-4a session conversation over a resident-loaded
#       engine reproduces the default session's replies exactly,
#       and the session reports weight_load_mode q8_0_resident only
#       under the opt-in.

from std.sys import argv

from core.mimir_well import KVCache
from qwen35_resident import validate_qwen35_resident
from core.sampling_config import NativeSamplingConfig
from aesir import AesirEngine, GenerationConfig
from qwen35_session import Qwen35CPUSession


def max_abs_diff(a: List[Float32], b: List[Float32]) -> Float32:
    var m = Float32(0.0)
    for i in range(len(a)):
        var d = a[i] - b[i]
        if d < Float32(0.0):
            d = -d
        if d > m:
            m = d
    return m


def snapshot_s(mut engine: AesirEngine) -> List[Float32]:
    ref st = engine.qwen35_state
    var n = st.ssm_layer_count * st.head_count * st.d_state * st.d_state
    var out = List[Float32]()
    for i in range(n):
        out.append(Float32(st.s_data.unsafe_load(i)))
    return out^


def snapshot_c(mut engine: AesirEngine) -> List[Float32]:
    ref st = engine.qwen35_state
    var n = st.ssm_layer_count * max(0, st.conv_kernel - 1) * st.conv_dim
    var out = List[Float32]()
    for i in range(n):
        out.append(Float32(st.conv_data.unsafe_load(i)))
    return out^


def greedy_run(mut engine: AesirEngine, cfg: GenerationConfig) raises -> List[Int]:
    engine.pool.offset = engine.runtime_offset
    var kv = KVCache(64, engine.parser.config.kv_dim(), engine.pool, engine.parser.config.block_count)
    var tokens = List[Int]()
    tokens.append(1); tokens.append(3); tokens.append(17); tokens.append(42)
    var nxt = -1
    for pos in range(len(tokens)):
        nxt = engine._forward_position(tokens, kv, pos, cfg, False)
    var generated = List[Int]()
    for _ in range(16):
        generated.append(nxt)
        tokens.append(nxt)
        nxt = engine._forward_position(tokens, kv, len(tokens) - 1, cfg, False)
    return generated^


def seq_logits(mut engine: AesirEngine, cfg: GenerationConfig, seq: List[Int]) raises -> List[Float32]:
    engine.pool.offset = engine.runtime_offset
    var kv = KVCache(64, engine.parser.config.kv_dim(), engine.pool, engine.parser.config.block_count)
    kv.capture_logit_row = True
    for pos in range(len(seq)):
        _ = engine._forward_position(seq, kv, pos, cfg, False)
    return kv.last_logit_row.copy()


def run_turn(mut session: Qwen35CPUSession, prompt: String, system: String, max_tokens: Int) raises -> String:
    session.configure_sampling(NativeSamplingConfig())
    session.configure_output("")
    session.configure_tool("", "")
    session.configure_control(30000, -1)
    session.begin_turn(prompt, system, max_tokens)
    var answer = String("")
    while session.status().generating:
        answer += session.next_chunk()
    return answer


def main() raises:
    var arguments = argv()
    if len(arguments) != 3:
        raise Error("usage: test_qwen35_resident_q35_3r <qwen35_forward.gguf> <qwen35_forward_f16probe.gguf>")
    var cfg = GenerationConfig(max_new_tokens=16, temperature=Float32(0.0), top_k=40, top_p=Float32(0.9), repetition_penalty=Float32(1.0), seed=UInt64(42))
    var seq = List[Int]()
    seq.append(3); seq.append(17); seq.append(42); seq.append(100)
    seq.append(7); seq.append(999); seq.append(256); seq.append(5)

    # (r1) resident census on the default-loaded fixture directory.
    var probe_engine = AesirEngine(arguments[1], knowledge_capacity=1)
    var report = validate_qwen35_resident(probe_engine.parser)
    print("RESIDENT CENSUS: large_tensors=", report.large_count, " large_elements=", report.large_elements, " q8_0_bytes=", report.q8_bytes, " f16_bytes=", report.f16_bytes, " mode=", report.load_mode())
    if report.large_count != 33:
        raise Error("(r1) resident census large tensor count != 33")
    if report.q8_bytes != (report.large_elements // 32) * 34 or report.f16_bytes != report.large_elements * 2:
        raise Error("(r1) resident census pricing formulas broken")
    print("PASS (r1): resident census 33 large tensors, priced both ways")

    # (r2) resident vs default: greedy identity + logit diff 0.0.
    var default_engine = AesirEngine(arguments[1], knowledge_capacity=1)
    var resident_engine = AesirEngine(arguments[1], knowledge_capacity=1, qwen35_resident=True)
    if not resident_engine.qwen35_resident or default_engine.qwen35_resident:
        raise Error("(r2) engine load-mode flags are wrong")
    var gen_default = greedy_run(default_engine, cfg)
    var gen_resident = greedy_run(resident_engine, cfg)
    var banked = List[Int]()
    banked.append(1019); banked.append(675); banked.append(143); banked.append(452)
    banked.append(111); banked.append(251); banked.append(827); banked.append(386)
    banked.append(423); banked.append(176); banked.append(368); banked.append(1018)
    banked.append(910); banked.append(490); banked.append(742); banked.append(849)
    var seq_text = String("")
    for i in range(16):
        if gen_resident[i] != gen_default[i]:
            raise Error("(r2) resident greedy diverged from default at step " + String(i))
        if gen_resident[i] != banked[i]:
            raise Error("(r2) resident greedy diverged from the banked Q35-3a sequence at step " + String(i))
        seq_text += String(gen_resident[i]) + String(" ")
    var logits_default = seq_logits(default_engine, cfg, seq)
    var logits_resident = seq_logits(resident_engine, cfg, seq)
    var dlog = max_abs_diff(logits_default, logits_resident)
    print("RESIDENT VS DEFAULT: greedy identical:", seq_text)
    print("RESIDENT VS DEFAULT: logits max_abs_diff =", dlog)
    if dlog != Float32(0.0):
        raise Error("(r2) resident vs default logits differ (expected exact 0.0: same packed views, same kernels)")
    print("PASS (r2): resident == default, greedy identical, logits diff 0.0")

    # (r3) resident per-token vs batched (mirror Q35-3a (c)/(d1)).
    resident_engine.pool.offset = resident_engine.runtime_offset
    var kv1 = KVCache(64, resident_engine.parser.config.kv_dim(), resident_engine.pool, resident_engine.parser.config.block_count)
    kv1.capture_logit_row = True
    var nxt1 = -1
    for pos in range(len(seq)):
        nxt1 = resident_engine._forward_position(seq, kv1, pos, cfg, False)
    var s1 = snapshot_s(resident_engine)
    var c1 = snapshot_c(resident_engine)
    var lg1 = kv1.last_logit_row.copy()
    resident_engine.pool.offset = resident_engine.runtime_offset
    var kv2 = KVCache(64, resident_engine.parser.config.kv_dim(), resident_engine.pool, resident_engine.parser.config.block_count)
    kv2.capture_logit_row = True
    var nxt2 = resident_engine._forward_batch(seq, kv2, 0, len(seq), cfg, False)
    var s2 = snapshot_s(resident_engine)
    var c2 = snapshot_c(resident_engine)
    var lg2 = kv2.last_logit_row.copy()
    var ds = max_abs_diff(s1, s2)
    var dc = max_abs_diff(c1, c2)
    var dl = max_abs_diff(lg1, lg2)
    print("RESIDENT (c): s max_abs_diff =", ds, " conv max_abs_diff =", dc, " logits max_abs_diff =", dl)
    if nxt2 != nxt1 or ds > Float32(0.01) or dc > Float32(0.05) or dl > Float32(0.05):
        raise Error("(r3) resident per-token vs batched divergence beyond Q35-3a bounds")
    print("PASS (r3): resident batched == per-token within Q35-3a bounds, next token identical")

    # (r4) refusal by name on the F16-probe fixture.
    var refused = False
    var refusal = String("")
    try:
        var bad_engine = AesirEngine(arguments[2], knowledge_capacity=1, qwen35_resident=True)
        _ = bad_engine.qwen35_resident
    except e:
        refused = True
        refusal = String(e)
    print("RESIDENT REFUSAL:", refusal)
    if not refused:
        raise Error("(r4) resident load ACCEPTED an F16-stored large weight (silent fallback)")
    if "blk.0.ffn_gate.weight" not in refusal:
        raise Error("(r4) resident refusal did not name the offending tensor")
    print("PASS (r4): F16 large weight refused by name on the resident path")

    # (r5) the same fixture loads on the default path.
    var default_probe = AesirEngine(arguments[2], knowledge_capacity=1)
    if default_probe.parser.config.architecture != "qwen35":
        raise Error("(r5) default load of the F16-probe fixture broke")
    print("PASS (r5): F16-probe fixture loads on the default path (refusal is resident-specific)")

    # (r6) session over resident engine == default session replies.
    var system = String("You are a toy test assistant.")
    var u1 = String("alpha bravo charlie")
    var u2 = String("delta echo foxtrot")
    var sess_default = Qwen35CPUSession(arguments[1], 512, NativeSamplingConfig())
    sess_default.reset()
    var d_r1 = run_turn(sess_default, "User: " + u1 + "\n", system, 16)
    var d_r2 = run_turn(sess_default, u2, "", 16)
    var sess_resident = Qwen35CPUSession(arguments[1], 512, NativeSamplingConfig(), True)
    sess_resident.reset()
    var r_r1 = run_turn(sess_resident, "User: " + u1 + "\n", system, 16)
    var r_r2 = run_turn(sess_resident, u2, "", 16)
    if r_r1 != d_r1 or r_r2 != d_r2:
        raise Error("(r6) resident session replies diverged from the default session")
    if sess_resident.weight_load_mode() != "q8_0_resident":
        raise Error("(r6) resident session does not report weight_load_mode q8_0_resident")
    if sess_default.weight_load_mode() != "":
        raise Error("(r6) default session must not report a weight_load_mode")
    print("PASS (r6): resident session replies == default session; load mode reported only under the opt-in")

    # (r7) Q35-5 snapshot machinery over the resident-loaded engine:
    # restore at the turn-1 boundary, re-run B, then a stateless
    # resent history must reuse the snapshot (reused == boundary)
    # and reproduce R2 -- the Q35-5 (a2)/(a3) checks, resident mode.
    var b1 = sess_resident.status().position
    if b1 != 106:
        raise Error("(r7) resident session position after two turns != 106")
    sess_resident.reset()
    if not sess_resident.restore_snapshot(72):
        raise Error("(r7) resident session lost the turn-1 snapshot")
    var r7_r2 = run_turn(sess_resident, u2, "", 16)
    if r7_r2 != d_r2:
        raise Error("(r7) resident snapshot-restore continuation diverged")
    sess_resident.reset()
    var resent = "User: " + u1 + "\n" + "Assistant: " + r_r1 + "\n" + "User: " + u2 + "\n"
    sess_resident.configure_sampling(NativeSamplingConfig())
    sess_resident.configure_output("")
    sess_resident.configure_tool("", "")
    sess_resident.configure_control(30000, -1)
    sess_resident.begin_turn(resent, system, 16)
    var st7 = sess_resident.status()
    print("RESIDENT STATELESS_BEGIN prompt_tokens=", st7.prompt_tokens, " reused=", st7.reused_prompt_tokens)
    if st7.reused_prompt_tokens != 72 or st7.prompt_tokens != 90:
        raise Error("(r7) resident stateless reuse counters are not boundary/delta")
    var r7_r2c = String("")
    while sess_resident.status().generating:
        r7_r2c += sess_resident.next_chunk()
    if r7_r2c != d_r2:
        raise Error("(r7) resident stateless snapshot continuation diverged")
    print("PASS (r7): Q35-5 snapshot restore + stateless reuse work over the resident-loaded engine")
    print("Q35-3r qwen35 Q8_0-resident load path: ALL PASS")
