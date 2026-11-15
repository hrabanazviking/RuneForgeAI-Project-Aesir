# tests/test_qwen35_resident_k_qs_3.mojo
# QS-3 stage 4 proof: the Q4_K_M-resident load contract for qwen35.
#
# Usage: test_qwen35_resident_k_qs_3 <qwen35_k256_q8.gguf> <qwen35_k256_q4km.gguf>
# Fixture: the Q35-3 forward geometry re-proportioned so every
# large matrix input width is a multiple of 256 (hidden 512,
# ffn 512, q_width 512, ssm inner 256); the product is the CLI's
# streaming Q4_K_M conversion of the Q8_0 fixture (all 33 large
# tensors K-packed; norms/conv kept at source types).
#
# Proves (mirroring test_qwen35_resident_q35_3r):
#  (k1) K census over the product: 33 large tensors, all Q4_K or
#       Q6_K, priced from the file's own directory (144 B / 210 B
#       per 256 elements by stored type; F16 price = elements*2).
#  (k2) K-resident vs default load on the SAME product file:
#       greedy 16-token sequence IDENTICAL and next-token logit
#       rows max_abs_diff == 0.0 -- same packed bytes, same GEMM
#       dispatch (gemm_q4_k_m / gemm_q6_k); no second dequant.
#  (k3) refusal honesty, all by name: K-resident over the Q8_0
#       source refuses (names token_embd.weight); Q8_0-resident
#       over the K product refuses; both modes together refused.
#  (k4) session surface: weight_load_mode == q4_k_m_resident only
#       under the opt-in, and a resident-K session's reply equals
#       the default session's reply on the same prompt.

from std.sys import argv

from core.mimir_well import KVCache
from qwen35_resident import validate_qwen35_resident_k
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
        raise Error("usage: test_qwen35_resident_k_qs_3 <qwen35_k256_q8.gguf> <qwen35_k256_q4km.gguf>")
    var cfg = GenerationConfig(max_new_tokens=16, temperature=Float32(0.0), top_k=40, top_p=Float32(0.9), repetition_penalty=Float32(1.0), seed=UInt64(42))
    var seq = List[Int]()
    seq.append(3); seq.append(17); seq.append(42); seq.append(100)
    seq.append(7); seq.append(999); seq.append(256); seq.append(5)

    # (k1) K census on the product.
    var probe_engine = AesirEngine(arguments[2], knowledge_capacity=1)
    var report = validate_qwen35_resident_k(probe_engine.parser)
    print("K RESIDENT CENSUS: large_tensors=", report.large_count, " q4_k=", report.q4_count, " q6_k=", report.q6_count, " large_elements=", report.large_elements, " k_bytes=", report.k_bytes, " f16_bytes=", report.f16_bytes, " mode=", report.load_mode())
    if report.large_count != 33:
        raise Error("(k1) K census large tensor count != 33")
    if report.q4_count + report.q6_count != 33:
        raise Error("(k1) K census type split does not cover the large set")
    if report.q6_count < 1:
        raise Error("(k1) expected at least the output tensor at Q6_K")
    if report.f16_bytes != report.large_elements * 2:
        raise Error("(k1) K census F16 pricing formula broken")
    if report.k_bytes >= report.f16_bytes:
        raise Error("(k1) K resident price must beat the F16 price")
    print("PASS (k1): K census 33 large tensors, priced both ways")

    # (k2) K-resident vs default on the same product: identity.
    var default_engine = AesirEngine(arguments[2], knowledge_capacity=1)
    var resident_engine = AesirEngine(arguments[2], knowledge_capacity=1, qwen35_resident_k=True)
    if not resident_engine.qwen35_resident_k or default_engine.qwen35_resident_k:
        raise Error("(k2) engine K load-mode flags are wrong")
    var gen_default = greedy_run(default_engine, cfg)
    var gen_resident = greedy_run(resident_engine, cfg)
    var seq_text = String("")
    for i in range(16):
        if gen_resident[i] != gen_default[i]:
            raise Error("(k2) K-resident greedy diverged from default at step " + String(i))
        seq_text += String(gen_resident[i]) + String(" ")
    var logits_default = seq_logits(default_engine, cfg, seq)
    var logits_resident = seq_logits(resident_engine, cfg, seq)
    var dlog = max_abs_diff(logits_default, logits_resident)
    print("K RESIDENT VS DEFAULT: greedy identical:", seq_text)
    print("K RESIDENT VS DEFAULT: logits max_abs_diff =", dlog)
    if dlog != Float32(0.0):
        raise Error("(k2) K-resident vs default logits differ (expected exact 0.0: same packed views, same kernels)")
    print("PASS (k2): K-resident == default, greedy identical, logits diff 0.0")

    # (k3) refusals by name.
    var refused_k_on_q8 = False
    var refusal_k = String("")
    try:
        var bad = AesirEngine(arguments[1], knowledge_capacity=1, qwen35_resident_k=True)
        _ = bad.qwen35_resident_k
    except e:
        refused_k_on_q8 = True
        refusal_k = String(e)
    print("K-ON-Q8 REFUSAL:", refusal_k)
    if not refused_k_on_q8 or "blk.0.ffn_gate.weight" not in refusal_k:
        raise Error("(k3) K-resident load did not refuse the Q8_0 source naming its first offending tensor (blk.0.ffn_gate.weight, the block-constructor check that fires before the whole-model census)")
    var refused_q8_on_k = False
    try:
        var bad2 = AesirEngine(arguments[2], knowledge_capacity=1, qwen35_resident=True)
        _ = bad2.qwen35_resident
    except e:
        refused_q8_on_k = True
        print("Q8-ON-K REFUSAL:", String(e))
    if not refused_q8_on_k:
        raise Error("(k3) Q8_0-resident load ACCEPTED the K product")
    var refused_both = False
    try:
        var bad3 = AesirEngine(arguments[2], knowledge_capacity=1, qwen35_resident=True, qwen35_resident_k=True)
        _ = bad3.qwen35_resident_k
    except e:
        refused_both = True
        print("BOTH-MODES REFUSAL:", String(e))
    if not refused_both:
        raise Error("(k3) engine accepted both resident modes at once")
    print("PASS (k3): cross-form and both-mode refusals by name")

    # (k4) session surface + reply equality.
    var session_default = Qwen35CPUSession(arguments[2], 512, NativeSamplingConfig())
    var session_k = Qwen35CPUSession(arguments[2], 512, NativeSamplingConfig(), resident_k=True)
    if session_default.weight_load_mode() != String(""):
        raise Error("(k4) default session must not report a resident mode")
    if session_k.weight_load_mode() != String("q4_k_m_resident"):
        raise Error("(k4) K session must report q4_k_m_resident, got: " + session_k.weight_load_mode())
    var reply_default = run_turn(session_default, "Hello", "", 12)
    var reply_k = run_turn(session_k, "Hello", "", 12)
    print("SESSION REPLIES equal:", reply_default == reply_k, " reply:", reply_k)
    if reply_default != reply_k:
        raise Error("(k4) K-resident session reply differs from default session")
    print("PASS (k4): session mode surface + reply equality")
    print("ALL QS-3 K-RESIDENT TESTS PASS")
