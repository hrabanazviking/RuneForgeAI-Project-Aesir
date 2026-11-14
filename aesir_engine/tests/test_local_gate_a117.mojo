# tests/test_local_gate_a117.mojo
# A-117: Local gate script -- the gate policy encoded in
# core/local_gate.mojo: the filed A-114 matrix account is
# complete only at 228 cells with summing, filed counts;
# the E-MASTER suite account is green-to-baseline only in
# the established shape (counts sum, 2 pre-declared skips,
# no failure or the sole tolerated J-022 failure); the
# combined verdict is PASS only when both hold, NOT_RUN
# when a phase did not run, FAIL otherwise.

from core.local_gate import (
    LG_FAIL,
    LG_NOT_RUN,
    LG_PASS,
    MatrixAccount,
    SuiteAccount,
    gate_verdict,
    gate_verdict_name,
    local_gate_line,
    matrix_complete,
    matrix_counts_sum,
    suite_counts_sum,
    suite_green_to_baseline,
)


def _filed_matrix() -> MatrixAccount:
    return MatrixAccount(228, 4, 2, 2, 2, 9, 209)


def _baseline_suite() -> SuiteAccount:
    return SuiteAccount(724, 1, 2, 727, True)


def test_local_gate_constants() raises:
    if LG_PASS != 0 or LG_FAIL != 1 or LG_NOT_RUN != 2:
        raise Error("local gate verdict codes drifted")
    var line = local_gate_line()
    if "gate_local.sh" not in line or "no GitHub Actions" not in line:
        raise Error("local gate line lost the script or house law")


def test_local_gate_suite_baseline() raises:
    if not suite_green_to_baseline(_baseline_suite()):
        raise Error("filed baseline 724/1/2/727 J-022 not green")
    if not suite_counts_sum(_baseline_suite()):
        raise Error("baseline counts do not sum")


def test_local_gate_suite_clean() raises:
    if not suite_green_to_baseline(SuiteAccount(725, 0, 2, 727, False)):
        raise Error("clean suite 725/0/2/727 not green")


def test_local_gate_suite_extra_failure() raises:
    if suite_green_to_baseline(SuiteAccount(723, 2, 2, 727, True)):
        raise Error("two failures filed green")
    if suite_green_to_baseline(SuiteAccount(724, 1, 2, 727, False)):
        raise Error("sole non-J-022 failure filed green")


def test_local_gate_suite_shape_refused() raises:
    if suite_green_to_baseline(SuiteAccount(724, 1, 3, 728, True)):
        raise Error("skip drift filed green")
    if suite_green_to_baseline(SuiteAccount(724, 1, 2, 999, True)):
        raise Error("non-summing counts filed green")
    if suite_green_to_baseline(SuiteAccount(0, 0, 0, 0, False)):
        raise Error("empty suite filed green")


def test_local_gate_matrix_filed() raises:
    if not matrix_complete(_filed_matrix()):
        raise Error("filed A-114 matrix account not complete")
    if not matrix_counts_sum(_filed_matrix()):
        raise Error("filed matrix counts do not sum")


def test_local_gate_matrix_incomplete() raises:
    if matrix_complete(MatrixAccount(227, 4, 2, 2, 2, 9, 208)):
        raise Error("227-cell matrix filed complete")
    if matrix_complete(MatrixAccount(228, 4, 2, 2, 2, 9, 208)):
        raise Error("non-summing matrix filed complete")
    if matrix_complete(MatrixAccount(228, 5, 2, 2, 2, 9, 208)):
        raise Error("drifted verdict counts filed complete")


def test_local_gate_verdict_pass() raises:
    var v = gate_verdict(True, True, _filed_matrix(), _baseline_suite())
    if v != LG_PASS or gate_verdict_name(v) != String("PASS"):
        raise Error("complete matrix + baseline suite not PASS")


def test_local_gate_verdict_fail() raises:
    var bad = SuiteAccount(700, 25, 2, 727, False)
    if gate_verdict(True, True, _filed_matrix(), bad) != LG_FAIL:
        raise Error("failing suite not FAIL")
    if gate_verdict(True, True, MatrixAccount(0, 0, 0, 0, 0, 0, 0), _baseline_suite()) != LG_FAIL:
        raise Error("empty matrix not FAIL")


def test_local_gate_verdict_not_run() raises:
    if gate_verdict(False, True, _filed_matrix(), _baseline_suite()) != LG_NOT_RUN:
        raise Error("unrun matrix not NOT_RUN")
    if gate_verdict(True, False, _filed_matrix(), _baseline_suite()) != LG_NOT_RUN:
        raise Error("unrun suite not NOT_RUN")
    if gate_verdict_name(LG_NOT_RUN) != String("NOT_RUN"):
        raise Error("NOT_RUN name drifted")
