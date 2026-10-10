# tests/c7_h139_check.mojo
# H139 — SKIPTI AUTO = CPU-only honest mode acceptance (TEST-ONLY).
#
# Runs anywhere (no model needed — pure dispatch logic):
#   1. 50 dispatches across ops/shapes with want AUTO or CPU:
#      50/50 resolve to BACKEND_CPU.
#   2. 50/50 log lines contain the NPU-unavailable reason string
#      ("NPU unavailable (Phase-D NO-GO"), verified by log grep.
#   3. Explicit NPU selection raises the named NpuUnavailable error
#      citing the H111 verdict (message verified, not just the raise).
#   4. No log entry is recorded for a refused NPU dispatch.
#
# Prints H139-ALL-PASS or H139-FAIL: <reason>.

from std.collections import List

from armvegr.backend import (
    BACKEND_CPU,
    BACKEND_NPU,
    BACKEND_AUTO,
    NPU_UNAVAILABLE_REASON,
    NpuBackendStub,
    select_backend,
)


def main() raises:
    var fails = List[String]()
    var log = List[String]()

    var ops = List[String]()
    ops.append("gemv")
    ops.append("rmsnorm")
    ops.append("rope")
    ops.append("attention")
    ops.append("ffn_silu")
    ops.append("softmax")
    ops.append("matmul")
    ops.append("embedding")
    ops.append("sampler_topk")
    ops.append("kv_append")

    # 50 dispatches across ops/shapes; AUTO and CPU wants interleaved.
    var n_cpu = 0
    for i in range(50):
        var op = ops[i % 10]
        var m = 64 * ((i % 5) + 1)
        var n = 128 * (((i // 5) % 5) + 1)
        var k = 256 * (((i // 25) % 2) + 1)
        var want = BACKEND_AUTO()
        if i % 3 == 2:
            want = BACKEND_CPU()
        var r = select_backend(op, m, n, k, want, log)
        if r == BACKEND_CPU():
            n_cpu += 1
    if n_cpu == 50:
        print("H139 check 1/4 PASS: 50/50 dispatches resolve to CPU")
    else:
        fails.append("only " + String(n_cpu) + "/50 dispatches resolved to CPU")

    # Log grep: every line carries the declared NPU-unavailable reason.
    var n_logged = 0
    for i in range(len(log)):
        var entry = log[i]
        if entry.find("-> CPU") >= 0 and entry.find("NPU unavailable (Phase-D NO-GO") >= 0:
            n_logged += 1
        else:
            fails.append("log line missing reason: " + entry)
    if n_logged == 50:
        print("H139 check 2/4 PASS: 50/50 log lines carry the NPU-unavailable reason")
    # The reason string itself names the verified CPU path.
    if NPU_UNAVAILABLE_REASON().find("verified CPU path") < 0:
        fails.append("reason string does not name the verified CPU path")

    # Explicit NPU selection -> named NpuUnavailable error citing H111.
    var npu_named = 0
    for i in range(5):
        try:
            _ = select_backend(ops[i], 64, 128, 256, BACKEND_NPU(), log)
            fails.append("explicit NPU dispatch did not raise")
        except e:
            var msg = String(e)
            if msg.find("NpuUnavailable") >= 0 and msg.find("H111") >= 0:
                npu_named += 1
            else:
                fails.append("NPU error misnamed/uncited: " + msg)
    if npu_named == 5:
        print("H139 check 3/4 PASS: 5/5 explicit NPU -> named NpuUnavailable (H111 cited)")
    if len(log) != 50:
        fails.append("refused NPU dispatch polluted the log")

    # The stub still exists (extension point) but can never be selected:
    # select_backend has no branch that returns NPU (verified by the 50/50
    # above plus source inspection in the C7 review).
    var stub = NpuBackendStub()
    if not stub.is_ready():
        print("H139 check 4/4 PASS: NPU stub never ready; no NPU selection branch")
    else:
        fails.append("NPU stub reports ready")

    if len(fails) == 0:
        print("H139-ALL-PASS")
    else:
        print("H139-FAIL:")
        for i in range(len(fails)):
            print("  - " + fails[i])
        raise Error("c7_h139: acceptance failed")
