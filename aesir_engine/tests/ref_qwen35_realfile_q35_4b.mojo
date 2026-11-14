# tests/ref_qwen35_realfile_q35_4b.mojo
# Q35-4b: in-process reference for the REAL-file resident serve proof.
#
# Drives Qwen35CPUSession over the real 27B GGUF in Q8_0-resident
# mode with EXACTLY the call sequence serve_loaded's OpenAI route
# uses (the Q35-4a session-test contract), with the serve's own
# default sampling (NativeSamplingConfig() — temperature 0,
# repetition_penalty 1.0 as mapped by the session; see Q35-4b R2).
# The HTTP bench compares its replies against this reference:
# equality proves the served resident continuation and the served
# stateless snapshot reuse are the in-process continuations on the
# same path (R3: same-path seeds only).
#
# Modes:
#   turns — turn 1 + resident turn 2 + stateless snapshot resend
#           + the Q35-7 stop case ("Say the word hello.", cap 8:
#           the Q35-4b F-4b-2 shape — the reply must halt on the
#           model's end/control tokens, clean text, finish eos,
#           generated < cap). Q35-7: replies on this driver carry
#           the session's F-4b-1 trim (no leading "Assistant:"
#           marker) — the same rule the serve applies, since both
#           run through Qwen35CPUSession.next_chunk.
#   stop  — only the Q35-7 stop case, on a fresh session.
#   long <prompt-file> — one long-prompt turn (R1 serve-length
#           witness), run twice from reset; the two replies must
#           agree exactly (same-path determinism at length).
#
# Usage: ref_qwen35_realfile_q35_4b <real.gguf> turns
#        ref_qwen35_realfile_q35_4b <real.gguf> long <prompt-file>

from std.sys import argv

from qwen35_session import Qwen35CPUSession
from core.sampling_config import NativeSamplingConfig


def esc(text: String) -> String:
    return text.replace("\n", "<NL>")


def run_turn(mut session: Qwen35CPUSession, prompt: String, system: String, max_tokens: Int) raises -> String:
    session.configure_sampling(NativeSamplingConfig())
    session.configure_output("")
    session.configure_tool("", "")
    session.configure_control(900000, -1)
    session.begin_turn(prompt, system, max_tokens)
    var answer = String("")
    while session.status().generating:
        answer += session.next_chunk()
    return answer


def main() raises:
    var args = argv()
    if len(args) < 3:
        raise Error("usage: ref_qwen35_realfile_q35_4b <real.gguf> turns|long [prompt-file]")
    var path = args[1]
    var mode = args[2]
    var system = String("You are a helpful assistant.")
    var u1 = String("What is the capital of France? Name one famous museum there.")
    var u2 = String("What language do most people speak in that city?")

    if mode == "stop":
        var sstop = Qwen35CPUSession(path, 4096, NativeSamplingConfig(), resident_q8=True)
        print("STOP_TOKENS " + sstop.stop_token_summary())
        sstop.reset()
        var rs = run_turn(sstop, "User: Say the word hello.\n", "", 8)
        var sts = sstop.status()
        print("STOPCASE=" + esc(rs))
        print("STOPCASE generated=" + String(sts.generated_tokens) + " finish=" + sts.finish_reason)
        if "<|" in rs:
            raise Error("stop case leaked a control-token spelling into the reply")
        if sts.finish_reason != "eos":
            raise Error("stop case did not finish on a stop token")
        if sts.generated_tokens >= 8:
            raise Error("stop case ran to the token cap instead of stopping")
        print("Q35-7 stop case: ALL PASS")
    elif mode == "turns":
        var session = Qwen35CPUSession(path, 4096, NativeSamplingConfig(), resident_q8=True)
        print("WEIGHT_LOAD_MODE=" + session.weight_load_mode())
        session.reset()
        var r1 = run_turn(session, "User: " + u1 + "\n", system, 32)
        var st1 = session.status()
        print("R1=" + esc(r1))
        print("T1 prompt_tokens=" + String(st1.prompt_tokens) + " reused=" + String(st1.reused_prompt_tokens) + " generated=" + String(st1.generated_tokens))
        print("POS1=" + String(st1.position))
        var pos1 = st1.position
        var r2 = run_turn(session, u2, "", 32)
        var st2 = session.status()
        print("R2=" + esc(r2))
        print("T2 prompt_tokens=" + String(st2.prompt_tokens) + " reused=" + String(st2.reused_prompt_tokens) + " generated=" + String(st2.generated_tokens))
        print("POS2=" + String(st2.position))
        if r1 == "" or r2 == "":
            raise Error("empty reply from the real-file resident session")
        # Stateless snapshot resend (Q35-5 text-extension path).
        session.reset()
        var resent = "User: " + u1 + "\n" + "Assistant: " + r1 + "\n" + "User: " + u2 + "\n"
        session.configure_sampling(NativeSamplingConfig())
        session.configure_output("")
        session.configure_tool("", "")
        session.configure_control(900000, -1)
        session.begin_turn(resent, system, 32)
        var st5 = session.status()
        print("STATELESS prompt_tokens=" + String(st5.prompt_tokens) + " reused=" + String(st5.reused_prompt_tokens) + " position=" + String(st5.position))
        if st5.reused_prompt_tokens != pos1:
            raise Error("stateless reuse did not restore the turn-1 boundary")
        var r2s = String("")
        while session.status().generating:
            r2s += session.next_chunk()
        print("R2S=" + esc(r2s))
        if r2s != r2:
            raise Error("stateless snapshot continuation diverged from the resident reference")
        print("PASS (stateless): snapshot resend reuses turn-1 boundary, reply == resident R2")
        # Q35-7 stop case, same session after reset (the Q35-4b
        # intervening-request shape, in-process).
        print("STOP_TOKENS " + session.stop_token_summary())
        session.reset()
        var rs = run_turn(session, "User: Say the word hello.\n", "", 8)
        var sts = session.status()
        print("STOPCASE=" + esc(rs))
        print("STOPCASE generated=" + String(sts.generated_tokens) + " finish=" + sts.finish_reason)
        if "<|" in rs:
            raise Error("stop case leaked a control-token spelling into the reply")
        if sts.finish_reason != "eos":
            raise Error("stop case did not finish on a stop token")
        if sts.generated_tokens >= 8:
            raise Error("stop case ran to the token cap instead of stopping")
        print("PASS (stopcase): reply halts on the model's stop tokens, clean text")
        print("Q35-4b in-process turns reference: ALL PASS")
    elif mode == "long":
        if len(args) < 4:
            raise Error("long mode needs a prompt file")
        var prompt = String("")
        with open(args[3], "r") as f:
            prompt = f.read()
        var session = Qwen35CPUSession(path, 4096, NativeSamplingConfig(), resident_q8=True)
        print("WEIGHT_LOAD_MODE=" + session.weight_load_mode())
        session.reset()
        var ra = run_turn(session, "User: " + prompt + "\n", "", 48)
        var sta = session.status()
        print("LONG prompt_tokens=" + String(sta.prompt_tokens) + " generated=" + String(sta.generated_tokens))
        print("LONG_R=" + esc(ra))
        session.reset()
        var rb = run_turn(session, "User: " + prompt + "\n", "", 48)
        print("LONG_R2=" + esc(rb))
        if rb != ra:
            raise Error("long-prompt rerun from reset diverged (same-path determinism failed)")
        print("PASS (long): same-path rerun at serve length reproduces exactly")
        print("Q35-4b in-process long reference: ALL PASS")
    else:
        raise Error("unknown mode: " + mode)
