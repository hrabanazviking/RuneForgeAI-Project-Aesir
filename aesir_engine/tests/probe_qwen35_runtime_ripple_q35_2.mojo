# tests/probe_qwen35_runtime_ripple_q35_2.mojo
# Q35-2 ripple guard: classify()/inspect() now report the real file
# READY under native_profile "qwen35" for INSPECTION. Serve admission
# is Q35-4's slice, so NativeModelPlan must still refuse this file
# today -- under "auto" (which adopts the inspected native_profile)
# and under an explicit "qwen35" request. This probe passes only if
# both constructions raise; if either ever succeeds, Q35-2 has
# leaked into serve admission and must stop.
# Usage: probe_qwen35_runtime_ripple_q35_2 <real-qwen35-27b.gguf>

from std.sys import argv

from loader.packed_gguf import PackedGGUF
from core.runtime_plan import NativeModelPlan  # direct loader import anchors the package root (Q35-1 lesson)


def expect_refusal(path: String, requested: String) raises -> String:
    var error_text = String("")
    try:
        var plan = NativeModelPlan(path, requested, 0)
        _ = plan.profile
    except error:
        error_text = String(error)
    if error_text == "":
        raise Error("RIPPLE: NativeModelPlan admitted qwen35 under profile " + requested)
    return error_text


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("usage: probe_qwen35_runtime_ripple_q35_2 <real-qwen35-27b.gguf>")
    var e1 = expect_refusal(args[1], "auto")
    print("PASS (r1): NativeModelPlan(auto) refuses qwen35 today:", e1)
    var e2 = expect_refusal(args[1], "qwen35")
    print("PASS (r2): NativeModelPlan(qwen35) refuses explicitly:", e2)
    print("Q35-2 runtime ripple guard: PASS - no serve admission leaked")
