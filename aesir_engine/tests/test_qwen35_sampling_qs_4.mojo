# QS-4: sampling parity on the qwen35 CPU path.
#
# QS-4.2 (min_p):
#  (m1) apply_min_p keep sets on a known logit ladder (reference
#       semantics: keep prob >= min_p * max_prob over the
#       candidate set; llama.cpp ratio form).
#  (m2) distribution: sample_token_from_logits with min_p=0.95
#       must NEVER draw the token sitting at prob ratio 0.905 of
#       max, over 512 seeded draws; with min_p=0 it must be
#       drawn often. Deterministic seeds.
#  (m3) session level on the k256 fixture: min_p=0 reproduces
#       the PRE-FIX probe stream bit-exactly (defaults preserve
#       behavior); min_p=0.95 changes the stream; the session
#       _gen_config() witness carries min_p through.
# QS-4.3 (repeat_last_n) cases live below the QS-4.3 marker.
from std.sys import argv
from std.memory import dealloc
from std.memory.alloc import alloc, Layout
from core.compute import MutUntrackedOrigin
from core.sampler import RuneRNG, TokenCandidate, sample_token_from_logits, apply_min_p
from qwen35_session import Qwen35CPUSession
from core.sampling_config import NativeSamplingConfig


def test_min_p_keep_sets() raises:
    var c = List[TokenCandidate]()
    c.append(TokenCandidate(0, Float32(2.0)))
    c.append(TokenCandidate(1, Float32(1.0)))
    c.append(TokenCandidate(2, Float32(0.0)))
    c.append(TokenCandidate(3, Float32(-1.0)))
    # probs: .644 .237 .087 .032; max .644
    var a = c.copy()
    apply_min_p(a, Float32(0.1))  # threshold .0644 -> keep 0,1,2
    if len(a) != 3 or a[0].id != 0 or a[1].id != 1 or a[2].id != 2:
        raise Error("(m1) min_p=0.1 keep set wrong")
    var b = c.copy()
    apply_min_p(b, Float32(0.5))  # threshold .322 -> keep 0 only
    if len(b) != 1 or b[0].id != 0:
        raise Error("(m1) min_p=0.5 keep set wrong")
    var d = c.copy()
    apply_min_p(d, Float32(0.0))
    if len(d) != 4:
        raise Error("(m1) min_p=0 must be a no-op")
    print("(m1) apply_min_p keep sets: PASS")


def test_min_p_distribution() raises:
    var allocation = alloc(Layout[Scalar[DType.float16]](count=8))
    var logits = allocation.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    logits.unsafe_store(0, Scalar[DType.float16](3.0))
    logits.unsafe_store(1, Scalar[DType.float16](2.9))
    for i in range(2, 8):
        logits.unsafe_store(i, Scalar[DType.float16](-10.0))
    var ctx = List[Int]()
    var rng = RuneRNG(UInt64(1234))
    var ones = 0
    var unexpected = 0
    for _ in range(512):
        var t = sample_token_from_logits(logits, 8, Float32(1.0), 8, Float32(1.0), Float32(1.0), ctx, rng, min_p=Float32(0.95))
        if t == 1:
            ones += 1
        elif t != 0:
            unexpected += 1
    var rng2 = RuneRNG(UInt64(1234))
    var ones2 = 0
    for _ in range(512):
        var t2 = sample_token_from_logits(logits, 8, Float32(1.0), 8, Float32(1.0), Float32(1.0), ctx, rng2, min_p=Float32(0.0))
        if t2 == 1:
            ones2 += 1
    dealloc(allocation^)
    if unexpected != 0:
        raise Error("(m2) min_p=0.95 drew an unexpected token")
    if ones != 0:
        raise Error("(m2) min_p=0.95 drew the below-threshold token")
    if ones2 < 50:
        raise Error("(m2) min_p=0 control drew token 1 too rarely: " + String(ones2))
    print("(m2) min_p distribution (control token1 draws=" + String(ones2) + "/512): PASS")


def run_stream(path: String, cfg: NativeSamplingConfig) raises -> List[Int]:
    var session = Qwen35CPUSession(path, 512, cfg)
    session.configure_output("")
    session.configure_tool("", "")
    session.configure_control(120000, -1)
    session.begin_turn(String("The old lighthouse keeper"), String(""), 24)
    while session.status().generating:
        _ = session.next_chunk()
    return session.stream.copy()


def test_session_min_p(path: String) raises:
    var expected = List[Int]()
    for v in [56, 76, 73, 4, 83, 80, 72, 4, 80, 77, 75, 76, 88, 76, 83, 89, 87, 73, 4, 79, 73, 73, 84, 73, 86, 951, 290, 738, 704, 273, 714, 796, 969, 1012, 704, 501, 32, 823, 635, 568, 877, 978, 130, 355, 603, 81, 24, 537, 843]:
        expected.append(v)
    var cfg_a = NativeSamplingConfig(temperature=Float32(1.0), top_k=256, top_p=Float32(1.0), min_p=Float32(0.0), repetition_penalty=Float32(1.0), repeat_last_n=64, seed=UInt64(42))
    var a = run_stream(path, cfg_a)
    if len(a) != len(expected):
        raise Error("(m3) default stream length changed")
    for i in range(len(a)):
        if a[i] != expected[i]:
            raise Error("(m3) default (min_p=0) stream diverged from pre-fix probe at " + String(i))
    var cfg_b = NativeSamplingConfig(temperature=Float32(1.0), top_k=256, top_p=Float32(1.0), min_p=Float32(0.95), repetition_penalty=Float32(1.0), repeat_last_n=64, seed=UInt64(42))
    var probe = Qwen35CPUSession(path, 512, cfg_b)
    if probe._gen_config().min_p != Float32(0.95):
        raise Error("(m3) _gen_config dropped min_p again")
    var b = run_stream(path, cfg_b)
    var differ = len(a) != len(b)
    if not differ:
        for i in range(len(a)):
            if a[i] != b[i]:
                differ = True
                break
    if not differ:
        raise Error("(m3) min_p=0.95 stream identical to min_p=0 (still a no-op)")
    print("(m3) session min_p: default bit-exact, min_p=0.95 bites: PASS")


def main() raises:
    var args = argv()
    if len(args) < 2:
        raise Error("usage: test_qwen35_sampling_qs_4 <qwen35.gguf>")
    test_min_p_keep_sets()
    test_min_p_distribution()
    test_session_min_p(args[1])
    print("QS-4 SAMPLING TESTS: PASS")
