# tests/test_qwen35_session_q35_4.mojo
# Q35-4a: in-process reference for the Qwen35 CPU serve session.
#
# Drives Qwen35CPUSession with EXACTLY the call sequence
# serve_loaded's OpenAI route uses (reset -> configure_* ->
# begin_turn(chat_prompt, system) -> next_chunk* for turn 1; then
# NO reset and begin_turn(raw new user content, "") for the
# resident turn 2), with greedy sampling. The HTTP bench compares
# its replies against this reference: equality proves the served
# resident continuation is the in-process A+B continuation on one
# persistent Qwen35State (token IDs printed as ground truth).
#
# Also proves: after reset(), the same turn 1 reproduces exactly
# (the position-0 state wipe), and a fresh session reproduces too.
#
# Usage: test_qwen35_session_q35_4 <qwen35_forward.gguf>

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


def stream_text(session: Qwen35CPUSession) -> String:
    var out = String("")
    for token in session.stream:
        out += String(token) + " "
    return out


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: test_qwen35_session_q35_4 <qwen35_forward.gguf>")
    var system = String("You are a toy test assistant.")
    var u1 = String("alpha bravo charlie")
    var u2 = String("delta echo foxtrot")
    var max_tokens = 16

    var session = Qwen35CPUSession(args[1], 512, NativeSamplingConfig())
    session.reset()
    var r1 = run_turn(session, "User: " + u1 + "\n", system, max_tokens)
    print("R1=" + esc(r1))
    print("STREAM1=" + stream_text(session))
    print("POS1=" + String(session.status().position))
    # Resident turn 2: no reset; the serve feeds the raw new user
    # message content as the delta prompt with an empty system.
    var r2 = run_turn(session, u2, "", max_tokens)
    print("R2=" + esc(r2))
    print("STREAM2=" + stream_text(session))
    print("POS2=" + String(session.status().position))
    if r1 == "" or r2 == "":
        raise Error("empty reply from the qwen35 CPU session")
    # After reset the conversation restarts: turn 1 must reproduce
    # exactly (position-0 forward wipes the SSM state).
    session.reset()
    var r1b = run_turn(session, "User: " + u1 + "\n", system, max_tokens)
    print("R1_RESET=" + esc(r1b))
    if r1b != r1:
        raise Error("turn 1 after reset diverged from the first run")
    print("PASS (reset): turn 1 after reset reproduces exactly")
    # A fresh session/engine reproduces turn 1 + resident turn 2.
    var fresh = Qwen35CPUSession(args[1], 512, NativeSamplingConfig())
    fresh.reset()
    var fr1 = run_turn(fresh, "User: " + u1 + "\n", system, max_tokens)
    var fr2 = run_turn(fresh, u2, "", max_tokens)
    if fr1 != r1 or fr2 != r2:
        raise Error("fresh session diverged from the resident reference")
    print("PASS (fresh): fresh session reproduces R1 and resident R2 exactly")
    print("Q35-4 qwen35 CPU session reference: ALL PASS")
