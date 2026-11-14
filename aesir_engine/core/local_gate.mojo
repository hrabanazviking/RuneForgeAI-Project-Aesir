"""A-117: Local gate script -- the gate POLICY, encoded
once (Wave 13, Oracle infrastructure).

The roadmap text: "The whole matrix as one local command
(no GitHub Actions -- house law). Acceptance: script +
timing filed; keeper can run it as the full-tier gate."

The deliverable script is scripts/gate_local.sh: ONE local
command that runs (1) the A-114 full matrix runner
(tests/bench_matrix_a114.mojo, 228 cells, a verdict per
cell) and (2) the E-MASTER suite
(aesir_engine/tests/run_all.mojo) under the gfx1151
compile target with the seat staging shims, judges both
logs, files per-phase and total timings, and exits 0 only
on PASS. It is local and manual-only: no GitHub Actions,
no CI, no network gate of any kind (house law).

This module is the ONE encoding of the gate's pass rule,
so the bash judge in scripts/gate_local.sh and any future
keeper tooling cannot drift apart silently -- the same
pattern as A-111 (band encoded once) and A-112 (checklist
automated once). The script's judge mirrors these numbers
exactly; the suite cases in
tests/test_local_gate_a117.mojo pin them here.

THE RULE, PRE-REGISTERED (stated here before any test in
tests/test_local_gate_a117.mojo was run):
  Matrix account (from the A-114 filed run):
    (M1) total == 228 and the per-verdict counts sum to
         the total (faithful 4, near_tie 2, divergent 2,
         artifact 2, fixture_limited 9, not_graded 209 on
         the banked A-114 filing). A matrix that emits
         fewer cells, or counts that do not sum, FAILS --
         a partial matrix never files as a gate pass.
         The filed counts are the A-114 base filing;
         A-135 / A-209 re-file the matrix and this account
         is updated in that slice, never silently.
    (M2) divergent / artifact cells do NOT fail the gate:
         they are filed verdicts of the A-114 matrix
         (quant-noise divergences and A-045 fixture-
         artifacts), not gate failures. The gate fails on
         an INCOMPLETE or unexplained matrix, not on an
         honest divergent verdict.
  Suite account (E-MASTER, green-to-baseline shape):
    (S1) passed + failed + skipped == total, total > 0.
    (S2) skipped == 2 (the 2 pre-declared skips).
    (S3) failed == 0, OR failed == 1 with the sole
         failure gguf.tensor_directory_interface
         (pre-existing J-022 drift). Any other failure
         FAILS. (The named intermittents --
         resilience.state_vault_rejects_growth,
         gpu.amd_hip_stream_async_round_trip,
         gguf.weight_residency_gpu_visibility,
         memory.budget_live_meminfo_pressure -- are a
         keeper re-run concern, not a gate tolerance:
         the gate stays strict like scripts/gate_full.sh,
         and a named intermittent is cleared by a solo
         re-run before banking, never tolerated in-log.)
  Combined verdict:
    (G1) NOT_RUN if either phase did not run.
    (G2) PASS iff the matrix account is complete AND
         the suite account is green-to-baseline.
    (G3) FAIL otherwise.

INTEGRATION POINTS (honest, no unbanked dependency):
A-115 (token-exactness policy, team-25, NOT banked at
build time) can refine S3's judging per quant family when
it banks; A-116 (first-divergence localisation, team-26,
NOT banked) is the tool a keeper runs on a gate FAIL
before filing a divergence. Neither is called here.

This module executes nothing, opens no device, and
claims no accelerator execution: pure arithmetic on
stated accounts. gfx1151 in the script is a compile
target, not an execution claim.
"""

comptime LG_MATRIX_TOTAL = 228
comptime LG_MATRIX_FAITHFUL = 4
comptime LG_MATRIX_NEAR_TIE = 2
comptime LG_MATRIX_DIVERGENT = 2
comptime LG_MATRIX_ARTIFACT = 2
comptime LG_MATRIX_FIXTURE_LIMITED = 9
comptime LG_MATRIX_NOT_GRADED = 209
comptime LG_EXPECTED_SKIPS = 2
comptime LG_PASS = 0
comptime LG_FAIL = 1
comptime LG_NOT_RUN = 2


struct SuiteAccount(Copyable, ImplicitlyCopyable):
    var passed: Int
    var failed: Int
    var skipped: Int
    var total: Int
    var sole_failure_is_j022: Bool

    def __init__(out self, passed: Int, failed: Int, skipped: Int, total: Int, sole_failure_is_j022: Bool):
        self.passed = passed
        self.failed = failed
        self.skipped = skipped
        self.total = total
        self.sole_failure_is_j022 = sole_failure_is_j022


struct MatrixAccount(Copyable, ImplicitlyCopyable):
    var total: Int
    var faithful: Int
    var near_tie: Int
    var divergent: Int
    var artifact: Int
    var fixture_limited: Int
    var not_graded: Int

    def __init__(out self, total: Int, faithful: Int, near_tie: Int, divergent: Int, artifact: Int, fixture_limited: Int, not_graded: Int):
        self.total = total
        self.faithful = faithful
        self.near_tie = near_tie
        self.divergent = divergent
        self.artifact = artifact
        self.fixture_limited = fixture_limited
        self.not_graded = not_graded


def suite_counts_sum(a: SuiteAccount) -> Bool:
    return a.passed + a.failed + a.skipped == a.total and a.total > 0


def suite_green_to_baseline(a: SuiteAccount) -> Bool:
    if not suite_counts_sum(a):
        return False
    if a.skipped != LG_EXPECTED_SKIPS:
        return False
    if a.failed == 0:
        return True
    return a.failed == 1 and a.sole_failure_is_j022


def matrix_counts_sum(m: MatrixAccount) -> Bool:
    return m.faithful + m.near_tie + m.divergent + m.artifact + m.fixture_limited + m.not_graded == m.total


def matrix_complete(m: MatrixAccount) -> Bool:
    if m.total != LG_MATRIX_TOTAL or not matrix_counts_sum(m):
        return False
    return (m.faithful == LG_MATRIX_FAITHFUL and m.near_tie == LG_MATRIX_NEAR_TIE and m.divergent == LG_MATRIX_DIVERGENT and m.artifact == LG_MATRIX_ARTIFACT and m.fixture_limited == LG_MATRIX_FIXTURE_LIMITED and m.not_graded == LG_MATRIX_NOT_GRADED)


def gate_verdict(matrix_ran: Bool, suite_ran: Bool, m: MatrixAccount, a: SuiteAccount) -> Int:
    if not matrix_ran or not suite_ran:
        return LG_NOT_RUN
    if matrix_complete(m) and suite_green_to_baseline(a):
        return LG_PASS
    return LG_FAIL


def gate_verdict_name(v: Int) -> String:
    if v == LG_PASS:
        return String("PASS")
    if v == LG_FAIL:
        return String("FAIL")
    return String("NOT_RUN")


def local_gate_line() -> String:
    return String("A-117 local gate: scripts/gate_local.sh -- one local command (matrix + E-MASTER), no GitHub Actions")
