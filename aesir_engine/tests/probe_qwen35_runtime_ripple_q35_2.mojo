# tests/probe_qwen35_runtime_ripple_q35_2.mojo
# Q35-2 ripple guard, UPDATED BY Q35-4a (superseded expectation):
# Q35-2 required NativeModelPlan to refuse qwen35 entirely, because
# serve admission was Q35-4's slice. Q35-4a IS that slice, so the
# truth is now: the plan ADMITS qwen35 -- the real signature file
# natively (auto and explicit, experimental=False), and a
# non-signature qwen35 geometry (the forward fixture) ONLY under
# the explicit experimental opt-in (experimental=True); without
# the opt-in the fixture is still refused, and an unknown profile
# is still refused by name. The aesir-gate unit (HIP llama3) does
# not pass through this code at runtime and is untouched.
# Usage: probe_qwen35_runtime_ripple_q35_2 <real-qwen35-27b.gguf> <qwen35_forward.gguf>

from std.sys import argv

from loader.packed_gguf import PackedGGUF
from core.runtime_plan import NativeModelPlan  # direct loader import anchors the package root (Q35-1 lesson)


def expect_refusal(path: String, requested: String, experimental: Bool) raises -> String:
    var error_text = String("")
    try:
        var plan = NativeModelPlan(path, requested, 0, experimental)
        _ = plan.profile
    except error:
        error_text = String(error)
    if error_text == "":
        raise Error("RIPPLE: NativeModelPlan admitted '" + requested + "' experimental=" + String(experimental) + " unexpectedly")
    return error_text


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: probe_qwen35_runtime_ripple_q35_2 <real-qwen35-27b.gguf> <qwen35_forward.gguf>")
    var auto_plan = NativeModelPlan(args[1], "auto", 0)
    if auto_plan.profile != "qwen35" or auto_plan.experimental:
        raise Error("RIPPLE: auto plan for the real file is not native qwen35")
    print("PASS (r1): NativeModelPlan(auto) admits the real file natively: profile=", auto_plan.profile, " variant=", auto_plan.variant, " experimental=", auto_plan.experimental)
    var explicit_plan = NativeModelPlan(args[1], "qwen35", 0)
    if explicit_plan.profile != "qwen35" or explicit_plan.experimental:
        raise Error("RIPPLE: explicit plan for the real file is not native qwen35")
    print("PASS (r2): NativeModelPlan(qwen35) admits the real file natively, variant=", explicit_plan.variant)
    var e3 = expect_refusal(args[2], "qwen35", False)
    print("PASS (r3): fixture refused without the experimental opt-in:", e3)
    var fixture_plan = NativeModelPlan(args[2], "qwen35", 0, True)
    if fixture_plan.profile != "qwen35" or not fixture_plan.experimental:
        raise Error("RIPPLE: fixture plan under the opt-in is not experimental qwen35")
    print("PASS (r4): fixture admitted under the opt-in as experimental: variant=", fixture_plan.variant, " context=", fixture_plan.context_length)
    var e5 = expect_refusal(args[1], "qwen35x", False)
    print("PASS (r5): unknown profile still refused:", e5)
    print("Q35-4a runtime admission probe: ALL PASS (supersedes the Q35-2 refusal guard)")
