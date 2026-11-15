# QS-4.1 probe: what does the qwen35 CPU serve path DO with
# min_p and repeat_last_n today? Drives Qwen35CPUSession on the
# k256 fixture with fixed seeds and compares committed token
# streams across sampling configurations.
#
# Runs:
#  A  min_p=0.00 rep=1.0 rln=64   (baseline)
#  B  min_p=0.95 rep=1.0 rln=64   (min_p should bite if wired)
#  C  min_p=0.00 rep=2.5 rln=1    (window 1 if wired)
#  D  min_p=0.00 rep=2.5 rln=8192 (window huge if wired)
#  E  min_p=0.00 rep=1.0 rln=64 seed=42 (== A: determinism check)
# Prints _gen_config().min_p under B as the direct drop witness.
from std.sys import argv
from qwen35_session import Qwen35CPUSession
from core.sampling_config import NativeSamplingConfig


def run_stream(path: String, cfg: NativeSamplingConfig) raises -> List[Int]:
    var session = Qwen35CPUSession(path, 512, cfg)
    session.configure_output("")
    session.configure_tool("", "")
    session.configure_control(120000, -1)
    session.begin_turn(String("The old lighthouse keeper"), String(""), 24)
    while session.status().generating:
        _ = session.next_chunk()
    return session.stream.copy()


def show(name: String, s: List[Int]):
    var out = name + " len=" + String(len(s)) + " stream="
    for i in range(len(s)):
        if i > 0:
            out += ","
        out += String(s[i])
    print(out)


def same(a: List[Int], b: List[Int]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True


def main() raises:
    var args = argv()
    if len(args) < 2:
        raise Error("usage: probe_qwen35_sampling_qs_4 <qwen35.gguf>")
    var path = args[1]
    var base = NativeSamplingConfig(temperature=Float32(1.0), top_k=256, top_p=Float32(1.0), min_p=Float32(0.0), repetition_penalty=Float32(1.0), repeat_last_n=64, seed=UInt64(42))
    var a = run_stream(path, base)
    show("A", a)
    var cfg_b = NativeSamplingConfig(temperature=Float32(1.0), top_k=256, top_p=Float32(1.0), min_p=Float32(0.95), repetition_penalty=Float32(1.0), repeat_last_n=64, seed=UInt64(42))
    var probe_session = Qwen35CPUSession(path, 512, cfg_b)
    print("WITNESS gen_config.min_p under sampling.min_p=0.95 -> " + String(probe_session._gen_config().min_p))
    var b = run_stream(path, cfg_b)
    show("B", b)
    var cfg_c = NativeSamplingConfig(temperature=Float32(1.0), top_k=256, top_p=Float32(1.0), min_p=Float32(0.0), repetition_penalty=Float32(2.5), repeat_last_n=1, seed=UInt64(42))
    var c = run_stream(path, cfg_c)
    show("C", c)
    var cfg_d = NativeSamplingConfig(temperature=Float32(1.0), top_k=256, top_p=Float32(1.0), min_p=Float32(0.0), repetition_penalty=Float32(2.5), repeat_last_n=8192, seed=UInt64(42))
    var d = run_stream(path, cfg_d)
    show("D", d)
    print("A==B (min_p no-op if True): " + String(same(a, b)))
    print("C==D (repeat_last_n no-op if True): " + String(same(c, d)))
    print("A==C (repetition_penalty wired if False): " + String(same(a, c)))
