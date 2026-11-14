# tests/test_qwen35_snapshot_q35_5.mojo
# Q35-5: snapshot/restore proofs for the Qwen35 CPU serve session.
#
# (a) Primitives + same-path continuation: run turn A, snapshot is
#     taken at the committed boundary; continue resident with B and
#     record final SSM state + next-token logits. reset() +
#     restore_snapshot(B1) must reproduce the boundary state BIT-
#     EXACTLY (state, conv, KV prefix), and running B again must
#     reproduce the final state + logits BIT-EXACTLY and the reply.
# (a2) Stateless text-extension: after reset(), a begin_turn whose
#     prompt is the full resent history (turn A + reply + B in the
#     serve's chat format) restores the turn-A snapshot: reused ==
#     B1, prompt_tokens == B1 + len(B tokens), reply and final
#     state identical to the resident run.
# (c) Diverged history: resent history edited inside turn A
#     (diverges before the turn-A boundary) reuses NOTHING
#     (reused == 0) and its reply equals a fresh session's cold
#     evaluation of the same diverged stream.
# (d) Store bound: with snapshot_limit == 4, driving 6 turns keeps
#     exactly 4 turn-boundary snapshots and evicts the oldest;
#     restore_snapshot(oldest) returns False.
#
# Usage: test_qwen35_snapshot_q35_5 <qwen35_forward.gguf>

from std.sys import argv

from qwen35_session import Qwen35CPUSession
from core.sampling_config import NativeSamplingConfig


def esc(text: String) -> String:
    return text.replace("\n", "<NL>")


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


def copy_s(session: Qwen35CPUSession) -> List[Float32]:
    ref st = session.engine.qwen35_state
    var n = st.ssm_layer_count * st.head_count * st.d_state * st.d_state
    var out = List[Float32]()
    for i in range(n):
        out.append(Float32(st.s_data.unsafe_load(i)))
    return out^


def copy_c(session: Qwen35CPUSession) -> List[Float32]:
    ref st = session.engine.qwen35_state
    var n = st.ssm_layer_count * max(0, st.conv_kernel - 1) * st.conv_dim
    var out = List[Float32]()
    for i in range(n):
        out.append(Float32(st.conv_data.unsafe_load(i)))
    return out^


def copy_kv(session: Qwen35CPUSession, boundary: Int) -> List[Float32]:
    var out = List[Float32]()
    var hidden = session.kv.hidden_dim
    for li in range(len(session.engine.qwen35_blocks)):
        if not session.engine.qwen35_blocks[li].is_full_attn:
            continue
        var base = li * session.kv.max_seq_len * hidden
        for j in range(boundary * hidden):
            out.append(Float32(session.kv.k.data.unsafe_load(base + j).cast[DType.float32]()))
            out.append(Float32(session.kv.v.data.unsafe_load(base + j).cast[DType.float32]()))
    return out^


def max_diff(a: List[Float32], b: List[Float32]) -> Float32:
    if len(a) != len(b):
        return Float32(1e30)
    var m = Float32(0.0)
    for i in range(len(a)):
        var d = a[i] - b[i]
        if d < Float32(0.0):
            d = -d
        if d > m:
            m = d
    return m


def has_boundary(session: Qwen35CPUSession, boundary: Int) -> Bool:
    for b in session.snapshot_boundaries():
        if b == boundary:
            return True
    return False


def bounds_text(session: Qwen35CPUSession) -> String:
    var out = String("")
    for b in session.snapshot_boundaries():
        out += String(b) + " "
    return out


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: test_qwen35_snapshot_q35_5 <qwen35_forward.gguf>")
    var system = String("You are a toy test assistant.")
    var u1 = String("alpha bravo charlie")
    var u2 = String("delta echo foxtrot")
    var max_tokens = 16

    var session = Qwen35CPUSession(args[1], 512, NativeSamplingConfig())
    session.reset()
    var r1 = run_turn(session, "User: " + u1 + "\n", system, max_tokens)
    var b1 = session.status().position
    print("R1=" + esc(r1))
    print("B1=" + String(b1))
    if b1 != 72:
        raise Error("turn-1 boundary is not the Q35-4a committed position 72")
    if not has_boundary(session, b1):
        raise Error("no snapshot stored at the turn-1 boundary")
    print("BOUNDARIES_AFTER_T1=" + bounds_text(session))
    var s_a = copy_s(session)
    var c_a = copy_c(session)
    var kv_a = copy_kv(session, b1)
    # Resident B (Q35-4a path) with the logit-row sink on.
    session.kv.capture_logit_row = True
    var r2 = run_turn(session, u2, "", max_tokens)
    var s_b = copy_s(session)
    var c_b = copy_c(session)
    var logits_b = session.kv.last_logit_row.copy()
    print("R2=" + esc(r2))
    print("POS2=" + String(session.status().position))
    # (a) restore primitives must be bit-exact copies.
    session.reset()
    var ok = session.restore_snapshot(b1)
    if not ok:
        raise Error("restore_snapshot(turn-1 boundary) returned False")
    var d_s = max_diff(copy_s(session), s_a)
    var d_c = max_diff(copy_c(session), c_a)
    var d_kv = max_diff(copy_kv(session, b1), kv_a)
    print("RESTORE_DIFF s=" + String(d_s) + " conv=" + String(d_c) + " kv=" + String(d_kv))
    if d_s != Float32(0.0) or d_c != Float32(0.0) or d_kv != Float32(0.0):
        raise Error("(a) snapshot restore is not bit-exact")
    print("PASS (a1): restore reproduces boundary s/conv/KV bit-exact (diffs 0.0)")
    session.kv.capture_logit_row = True
    var r2b = run_turn(session, u2, "", max_tokens)
    var d_s2 = max_diff(copy_s(session), s_b)
    var d_c2 = max_diff(copy_c(session), c_b)
    var d_l2 = max_diff(session.kv.last_logit_row, logits_b)
    print("RERUN_B DIFF s=" + String(d_s2) + " conv=" + String(d_c2) + " logits=" + String(d_l2))
    if r2b != r2 or d_s2 != Float32(0.0) or d_c2 != Float32(0.0) or d_l2 != Float32(0.0):
        raise Error("(a) re-running B after restore diverged from the resident run")
    print("PASS (a2): B after restore == resident B bit-exact (state + logits), reply equal")
    # (a3) stateless text-extension through begin_turn after reset.
    session.reset()
    session.kv.capture_logit_row = True
    var resent = "User: " + u1 + "\n" + "Assistant: " + r1 + "\n" + "User: " + u2 + "\n"
    session.configure_sampling(NativeSamplingConfig())
    session.configure_output("")
    session.configure_tool("", "")
    session.configure_control(30000, -1)
    session.begin_turn(resent, system, max_tokens)
    var st5 = session.status()
    print("STATELESS_BEGIN prompt_tokens=" + String(st5.prompt_tokens) + " reused=" + String(st5.reused_prompt_tokens) + " position=" + String(st5.position))
    if st5.reused_prompt_tokens != b1 or st5.prompt_tokens != b1 + 18:
        raise Error("(a3) stateless reuse counters are not boundary/delta")
    var r2c = String("")
    while session.status().generating:
        r2c += session.next_chunk()
    var d_s3 = max_diff(copy_s(session), s_b)
    var d_l3 = max_diff(session.kv.last_logit_row, logits_b)
    print("STATELESS_RERUN DIFF s=" + String(d_s3) + " logits=" + String(d_l3))
    if r2c != r2 or d_s3 != Float32(0.0) or d_l3 != Float32(0.0):
        raise Error("(a3) stateless snapshot continuation diverged from the resident reference")
    print("PASS (a3): stateless resent history reuses snapshot at " + String(b1) + ", evaluates only the delta, reply == resident R2")
    # (c) diverged history: edit inside turn 1, before the boundary.
    session.reset()
    var div_text = "User: alpha bravo DELTA\n" + "Assistant: " + r1 + "\n" + "User: " + u2 + "\n"
    session.configure_sampling(NativeSamplingConfig())
    session.configure_output("")
    session.configure_tool("", "")
    session.configure_control(30000, -1)
    session.begin_turn(div_text, system, max_tokens)
    var stc = session.status()
    print("DIVERGED_BEGIN prompt_tokens=" + String(stc.prompt_tokens) + " reused=" + String(stc.reused_prompt_tokens))
    if stc.reused_prompt_tokens != 0:
        raise Error("(c) diverged history reused tokens past the divergence")
    var rdiv = String("")
    while session.status().generating:
        rdiv += session.next_chunk()
    print("R_DIV=" + esc(rdiv))
    var fresh = Qwen35CPUSession(args[1], 512, NativeSamplingConfig())
    fresh.reset()
    var rdiv2 = run_turn(fresh, div_text, system, max_tokens)
    if rdiv2 != rdiv:
        raise Error("(c) diverged reply differs from the fresh cold reference")
    print("PASS (c): diverged history reuses 0 and matches the fresh cold reference exactly")
    # (d) store bound: 6 turns, limit 4 -> oldest evicted.
    var s2 = Qwen35CPUSession(args[1], 512, NativeSamplingConfig())
    s2.reset()
    _ = run_turn(s2, "User: " + u1 + "\n", system, 4)
    var first_boundary = s2.status().position
    print("D_FIRST_BOUNDARY=" + String(first_boundary))
    var extras = List[String]()
    extras.append("golf hotel india")
    extras.append("juliet kilo lima")
    extras.append("mike november oscar")
    extras.append("papa quebec romeo")
    extras.append("sierra tango uniform")
    for t in extras:
        _ = run_turn(s2, t, "", 4)
        print("D_BOUNDARIES=" + bounds_text(s2))
    var stored = len(s2.snapshot_boundaries()) - 1
    if stored != s2.snapshot_limit:
        raise Error("(d) snapshot store is not bounded at the limit")
    if has_boundary(s2, first_boundary):
        raise Error("(d) oldest snapshot was not evicted")
    var gone = s2.restore_snapshot(first_boundary)
    if gone:
        raise Error("(d) restore of an evicted boundary succeeded")
    print("PASS (d): store holds exactly " + String(stored) + " snapshots; oldest boundary " + String(first_boundary) + " evicted and unrestorable")
    print("Q35-5 qwen35 snapshot session test: ALL PASS")
