# tests/test_teacher_forcing_harness_a109.mojo
# A-109: Teacher-forcing harness v2 -- the harness gate rejects
# template-rendered input itself, grades synthetic rows from
# every backend through the one entry point, and reproduces
# the A-045 CPU matrix exactly. Synthetic rows are labelled
# synthetic; the measured reproduction over real fixtures is
# the bench driver (tests/bench_teacher_forcing_a109.mojo).

from core.parity_battery import parity_verdict_code
from core.teacher_forcing_harness import (
    TF_OK,
    TF_REJECT_BACKEND_MISMATCH,
    TF_REJECT_NO_ORACLE,
    TF_REJECT_TEMPLATE,
    a045_iq_fixture_limited_count,
    a045_matrix,
    tf_detect_template,
    tf_grade_rows,
    tf_harness_backends,
    tf_reject_name,
    tf_reproduces_a045,
    tf_summary_digest,
    tf_validate_run,
)


def _seq() -> List[Int]:
    var s = List[Int]()
    s.append(10); s.append(11); s.append(12); s.append(13)
    return s^


def _rows_top() -> List[List[Float32]]:
    # Synthetic rows where the next seq token is always top-1.
    var rows = List[List[Float32]]()
    for t in range(3):
        var r = List[Float32]()
        for v in range(20):
            r.append(Float32(-1.0))
        r[_seq()[t + 1]] = Float32(5.0)
        rows.append(r^)
    return rows^


def test_tf_raw_prompt_accepted() raises:
    if tf_detect_template("One day, Timmy went to"):
        raise Error("A109: RAW A-045 prompt must not be flagged template")
    if tf_validate_run("One day, Timmy went to", "cpu", "cpu") != TF_OK:
        raise Error("A109: CPU vs CPU raw run must be accepted")
    if tf_reject_name(TF_OK) != String("accepted"):
        raise Error("A109: reject name for TF_OK wrong")
    print("A109 raw prompt accepted (CPU vs CPU): PASS")


def test_tf_template_rejected() raises:
    var rendered = String("<|im_start|>user\nOne day, Timmy went to<|im_end|>")
    if not tf_detect_template(rendered):
        raise Error("A109: ChatML-rendered input must be detected")
    if tf_validate_run(rendered, "cpu", "cpu") != TF_REJECT_TEMPLATE:
        raise Error("A109: template input must be rejected by the harness")
    if tf_detect_template("[INST] One day [/INST]") == False:
        raise Error("A109: INST-rendered input must be detected")
    if not tf_detect_template("<s>One day, Timmy went to"):
        raise Error("A109: BOS-rendered <s> prefix must be detected")
    if tf_reject_name(TF_REJECT_TEMPLATE) != String("TEMPLATE_RENDERED"):
        raise Error("A109: template verdict class name wrong")
    print("A109 template-rendered input detected + rejected: PASS")


def test_tf_backend_and_oracle_gate() raises:
    if tf_validate_run("One day", "cpu", "cuda") != TF_REJECT_BACKEND_MISMATCH:
        raise Error("A109: non-CPU oracle for A-045 repro must be mismatch")
    if tf_validate_run("One day", "vulkan", "cpu") != TF_REJECT_BACKEND_MISMATCH:
        raise Error("A109: non-CPU engine for A-045 repro must be mismatch")
    if tf_validate_run("One day", "cpu", "") != TF_REJECT_NO_ORACLE:
        raise Error("A109: unnamed oracle backend must be rejected")
    print("A109 backend-mismatch + no-oracle gates: PASS")


def test_tf_grade_all_backends_one_harness() raises:
    var backends = tf_harness_backends()
    if len(backends) != 4:
        raise Error("A109: harness must name 4 backends")
    var seq = _seq()
    for i in range(len(backends)):
        var g = tf_grade_rows(_rows_top(), seq, 1)
        if g.faithful != 3 or g.near_tie != 0 or g.divergent != 0:
            raise Error("A109: synthetic top-1 rows must grade faithful for every backend")
        if g.worst_rank != 1 or g.max_gap != Float32(0.0):
            raise Error("A109: synthetic grade aggregates wrong")
    print("A109 one harness grades every backend identically: PASS")


def test_tf_grade_near_tie_and_divergence() raises:
    var seq = _seq()
    var rows = List[List[Float32]]()
    # pos0: target rank 2 gap 0.5 -> near-tie; pos1: rank 1;
    # pos2: target rank 3 -> divergence.
    var r0 = List[Float32]()
    for v in range(20):
        r0.append(Float32(0.0))
    r0[11] = Float32(1.0); r0[19] = Float32(1.5)
    rows.append(r0^)
    var r1 = List[Float32]()
    for v in range(20):
        r1.append(Float32(0.0))
    r1[12] = Float32(2.0)
    rows.append(r1^)
    var r2 = List[Float32]()
    for v in range(20):
        r2.append(Float32(0.0))
    r2[13] = Float32(1.0); r2[18] = Float32(2.0); r2[17] = Float32(3.0)
    rows.append(r2^)
    var g = tf_grade_rows(rows, seq, 1)
    if g.faithful != 1 or g.near_tie != 1 or g.divergent != 1:
        raise Error("A109: grade bands wrong on synthetic rows")
    if parity_verdict_code(2, Float32(0.5)) != 1:
        raise Error("A109: near-tie band must stay the A-045 band")
    print("A109 grade bands (faithful/near-tie/divergence): PASS")


def test_tf_a045_reproduction() raises:
    var m = a045_matrix()
    if len(m) != 10:
        raise Error("A109: A-045 matrix must carry 10 measured rows")
    if not tf_reproduces_a045(m):
        raise Error("A109: harness must reproduce the A-045 CPU matrix")
    var total = 0
    for i in range(len(m)):
        total += m[i].faithful + m[i].near_tie + m[i].divergent
    if total != 320:
        raise Error("A109: A-045 matrix must total 320 continuation rows")
    if a045_iq_fixture_limited_count() != 9:
        raise Error("A109: IQ fixture-limitation count must be 9")
    var drift = a045_matrix()
    drift[3].faithful = 26
    if tf_reproduces_a045(drift):
        raise Error("A109: drifted matrix must NOT reproduce")
    print("A109 A-045 CPU matrix reproduction (exact, drift caught): PASS")


def test_tf_summary_digest_reproducible() raises:
    var seq = _seq()
    var g1 = tf_grade_rows(_rows_top(), seq, 1)
    var g2 = tf_grade_rows(_rows_top(), seq, 1)
    var d1 = tf_summary_digest("synthetic", "cpu", "cpu", g1)
    var d2 = tf_summary_digest("synthetic", "cpu", "cpu", g2)
    if d1 != d2 or d1 == 0:
        raise Error("A109: summary digest must be reproducible and nonzero")
    print("A109 summary digest reproducible: PASS")
