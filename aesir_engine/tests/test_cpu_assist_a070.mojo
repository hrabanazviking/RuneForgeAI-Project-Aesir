"""Lawful CPU assist (A-070): every CPU participation in the
GPU path is inventoried, measured, and judged under the
Accelerator-First law - CPU only as (1) spillover for what
exceeds device residency or (2) an assist that measurably,
massively speeds up the whole run.

The inventory (canonical order, core/vulkan_real_model
ASSIST_* ids): stream_upload (spillover - the 128-slot shim
cap makes total residency impossible for an 8B model),
gains_upload, embed_gather, rope_permute, kv_pack,
lm_head_stitch, sanitize, host_argmax, gpu_greedy_check,
decode_alloc_churn (A-066 loop, removed by ping-pong).

Removed in A-070: the lm_head zero-fill pass (unmeasured
host work - the row is now built by stitch_chunk_append)
and the A-066 per-layer allocator churn. Roaded with
measurements in docs/bench/A070_CPU_ASSIST_INVENTORY.md:
persistent device KV for the real-model path (kv_pack does
not pay at long context), a GPU RoPE permutation bridge,
total weight residency under a raised slot cap.

These cases are pure host policy/accounting and always run;
no device or fixture is needed. The in-path measurements
themselves are filed by tests/bench_cpu_assist_a070.mojo.
"""
from std.memory import bitcast
from core.vulkan_real_model import (
    VulkanRealModel,
    CpuAssistStats,
    sanitize_logit_row,
    stitch_chunk_append,
    stitch_chunk_scatter,
    assist_name,
    assist_verdict,
    assist_is_lawful,
    ASSIST_STREAM_UPLOAD,
    ASSIST_GAINS_UPLOAD,
    ASSIST_EMBED_GATHER,
    ASSIST_ROPE_PERMUTE,
    ASSIST_KV_PACK,
    ASSIST_LM_HEAD_STITCH,
    ASSIST_SANITIZE,
    ASSIST_HOST_ARGMAX,
    ASSIST_GPU_GREEDY_CHECK,
    ASSIST_DECODE_ALLOC_CHURN,
    ASSIST_COUNT,
    VERDICT_LAWFUL_SPILLOVER,
    VERDICT_LAWFUL_MASSIVE,
    VERDICT_LAWFUL_TRIVIAL,
    VERDICT_UNMEASURED,
    VERDICT_UNMEASURED_DOMINANT,
    VERDICT_DOES_NOT_PAY,
)


def test_cpu_assist_stats_accounting() raises:
    print("--- Testing CPU assist stats accounting (A-070) ---")
    var s = CpuAssistStats()
    if s.steps != 0 or s.step_ns != 0 or s.assist_ns() != 0:
        raise Error("stats: fresh accumulator must be all zero")
    if s.stream_uploads != 0 or s.kvpack_calls != 0 or s.embed_calls != 0:
        raise Error("stats: fresh counters must be zero")
    s.stream_ns = 100
    s.gains_ns = 20
    s.embed_ns = 3
    s.permute_ns = 40
    s.kvpack_ns = 50
    s.logits_ns = 60
    s.sanitize_ns = 7
    if s.assist_ns() != 280:
        raise Error("stats: assist_ns must be the disjoint sum, got " + String(s.assist_ns()))
    var snap = s.copy()
    s.stream_ns = 999
    s.steps = 4
    s.step_ns = 670_000_000
    if snap.stream_ns != 100 or snap.steps != 0:
        raise Error("stats: snapshot copy must be independent of the original")
    if s.assist_ns() != 1179:
        raise Error("stats: accumulation must update the sum, got " + String(s.assist_ns()))


def test_cpu_assist_policy_verdicts() raises:
    print("--- Testing CPU assist lawful policy verdicts (A-070) ---")
    var step = 670_000_000
    # Streamed weight upload: spillover under the slot cap.
    if assist_verdict(True, True, 200_000_000, 0, step) != VERDICT_LAWFUL_SPILLOVER:
        raise Error("policy: residency spillover must be lawful")
    if not assist_is_lawful(True, True, 200_000_000, 0, step):
        raise Error("policy: spillover must report lawful")
    # Embed gather: 4 us host vs ~524 us device round trip.
    if assist_verdict(True, False, 4_000, 524_000, step) != VERDICT_LAWFUL_MASSIVE:
        raise Error("policy: >=10x measured assist must be lawful-massive")
    # Sanitize: policy-required scan, trivial share of step.
    if assist_verdict(True, False, 109_000, 0, step) != VERDICT_LAWFUL_TRIVIAL:
        raise Error("policy: sub-1% measured assist must be lawful-trivial")
    # Host argmax over the already-resident row: 150 vs 524 us.
    if assist_verdict(True, False, 150_000, 524_000, step) != VERDICT_LAWFUL_TRIVIAL:
        raise Error("policy: host argmax on a resident row must be lawful")
    if assist_is_lawful(True, False, 150_000, 524_000, step) != True:
        raise Error("policy: host argmax must report lawful")
    # KV pack at max position (replica-scaled 45 ms): does not pay.
    if assist_verdict(True, False, 45_000_000, 0, step) != VERDICT_DOES_NOT_PAY:
        raise Error("policy: dominant non-spillover assist must not pay")
    if assist_is_lawful(True, False, 45_000_000, 0, step):
        raise Error("policy: does-not-pay must report unlawful")
    # Unmeasured assists never survive.
    if assist_verdict(False, False, 0, 0, step) != VERDICT_UNMEASURED:
        raise Error("policy: unmeasured assist must be VERDICT_UNMEASURED")
    if assist_verdict(False, True, 0, 0, step) != VERDICT_UNMEASURED:
        raise Error("policy: unmeasured beats the spillover claim")
    if assist_is_lawful(False, False, 0, 0, step):
        raise Error("policy: unmeasured must report unlawful")
    # Unmeasured + dominant share is the worst class.
    if assist_verdict(False, False, 400_000_000, 0, step) != VERDICT_UNMEASURED_DOMINANT:
        raise Error("policy: unmeasured dominant assist misclassified")


def test_cpu_assist_stitch_equivalence() raises:
    print("--- Testing lm_head stitch append == scatter (A-070) ---")
    var chunks = List[List[Float32]]()
    var c0 = List[Float32]()
    c0.append(Float32(1.5))
    c0.append(Float32(-2.25))
    c0.append(Float32(3.0))
    var c1 = List[Float32]()
    var c2 = List[Float32]()
    c2.append(Float32(4.5))
    c2.append(Float32(5.75))
    chunks.append(c0^)
    chunks.append(c1^)
    chunks.append(c2^)
    var a = stitch_chunk_append(chunks)
    var b = stitch_chunk_scatter(chunks, 5)
    if len(a) != 5 or len(b) != 5:
        raise Error("stitch: lengths must be 5")
    for i in range(5):
        if a[i] != b[i]:
            raise Error("stitch: append and scatter differ at lane " + String(i))
    if a[0] != Float32(1.5) or a[3] != Float32(4.5) or a[4] != Float32(5.75):
        raise Error("stitch: values landed in the wrong lanes")
    var empty = List[List[Float32]]()
    if len(stitch_chunk_append(empty)) != 0:
        raise Error("stitch: zero chunks must give an empty row")
    if len(stitch_chunk_scatter(empty, 0)) != 0:
        raise Error("stitch: zero chunks scatter must give an empty row")
    var ra = a.copy()
    var rb = b.copy()
    if sanitize_logit_row(ra) != sanitize_logit_row(rb):
        raise Error("stitch: sanitize counts must agree on both forms")
    for i in range(5):
        if ra[i] != rb[i]:
            raise Error("stitch: sanitized forms differ at lane " + String(i))


def test_cpu_assist_sanitize_policy() raises:
    print("--- Testing CPU assist sanitize policy pin (A-070) ---")
    var nan = bitcast[DType.float32](UInt32(0x7FC00000))
    var inf = bitcast[DType.float32](UInt32(0x7F800000))
    var row = List[Float32]()
    row.append(Float32(0.25))
    row.append(nan)
    row.append(inf)
    row.append(Float32(-7.5))
    var replaced = sanitize_logit_row(row)
    if replaced != 2:
        raise Error("sanitize: expected 2 replaced lanes, got " + String(replaced))
    if row[1] != Float32(-1.0e9) or row[2] != Float32(-1.0e9):
        raise Error("sanitize: non-finite lanes must become -1e9")
    if row[0] != Float32(0.25) or row[3] != Float32(-7.5):
        raise Error("sanitize: finite lanes must be untouched")
    var clean = List[Float32]()
    clean.append(Float32(1.0))
    if sanitize_logit_row(clean) != 0:
        raise Error("sanitize: clean row must report 0 replacements")


def test_cpu_assist_inventory_completeness() raises:
    print("--- Testing CPU assist inventory completeness (A-070) ---")
    if ASSIST_COUNT != 10:
        raise Error("inventory: ASSIST_COUNT must be 10")
    var ids = List[Int]()
    ids.append(ASSIST_STREAM_UPLOAD)
    ids.append(ASSIST_GAINS_UPLOAD)
    ids.append(ASSIST_EMBED_GATHER)
    ids.append(ASSIST_ROPE_PERMUTE)
    ids.append(ASSIST_KV_PACK)
    ids.append(ASSIST_LM_HEAD_STITCH)
    ids.append(ASSIST_SANITIZE)
    ids.append(ASSIST_HOST_ARGMAX)
    ids.append(ASSIST_GPU_GREEDY_CHECK)
    ids.append(ASSIST_DECODE_ALLOC_CHURN)
    if len(ids) != ASSIST_COUNT:
        raise Error("inventory: id list length must equal ASSIST_COUNT")
    var names = List[String]()
    for i in range(len(ids)):
        if ids[i] != i:
            raise Error("inventory: ids must be contiguous from 0 in canonical order")
        var n = assist_name(ids[i])
        if n.byte_length() == 0 or n == String("unknown"):
            raise Error("inventory: every id must have a real name")
        for j in range(len(names)):
            if names[j] == n:
                raise Error("inventory: duplicate assist name " + n)
        names.append(n)
    if assist_name(ASSIST_COUNT) != String("unknown"):
        raise Error("inventory: out-of-range id must be unknown")
    if assist_name(-1) != String("unknown"):
        raise Error("inventory: negative id must be unknown")


def test_cpu_assist_stats_absent_model() raises:
    print("--- Testing CPU assist stats on an unloaded model (A-070) ---")
    var m = VulkanRealModel("/nonexistent/a070.gguf")
    var st = m.assist_stats()
    if st.steps != 0 or st.step_ns != 0 or st.assist_ns() != 0:
        raise Error("absent: unloaded model must report zeroed stats")
    if st.stream_uploads != 0 or st.stream_bytes != 0 or st.kvpack_bytes != 0:
        raise Error("absent: unloaded model must report zero counters")
    if st.logits_readback_bytes != 0 or st.sanitize_ns != 0:
        raise Error("absent: unloaded model must report zero logits accounting")
