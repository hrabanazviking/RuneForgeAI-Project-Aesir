# core/parity_battery.mojo
# A-045: CPU parity battery -- pure grading arithmetic for teacher-forcing
# rank / logit-gap rows. Shared by the reusable battery driver
# (tests/bench_parity_battery_a045.mojo) and the E-MASTER cases in
# tests/test_parity_battery_a045.mojo, so every later backend grades
# with exactly the same arithmetic.
#
# Raw-oracle discipline: rows come from teacher-forcing on RAW token
# sequences (never template-rendered prompts), CPU engine vs CPU
# comparator only. Verdict bands:
#   rank == 1                          -> faithful
#   rank <= 2 and gap < 1.0 (sub-logit)-> near-tie (counted faithful)
#   otherwise                          -> divergence (needs a verdict
#                                         class in the ledger)
# IQ formats are graded with these same rank/gap bands plus a
# coherence note in the ledger -- never token-exactness.


def parity_top_token(row: List[Float32]) -> Int:
    # First (lowest-id) index of the maximum logit; -1 on empty row.
    if len(row) == 0:
        return -1
    var best = 0
    for i in range(1, len(row)):
        if row[i] > row[best]:
            best = i
    return best


def parity_logit_rank(row: List[Float32], target: Int) -> Int:
    # 1-indexed rank of target: 1 + number of logits strictly greater
    # than the target logit. Ties share the better rank (a tied top
    # token is rank 1). -1 when target is out of range.
    if target < 0 or target >= len(row):
        return -1
    var rank = 1
    var tv = row[target]
    for i in range(len(row)):
        if row[i] > tv:
            rank += 1
    return rank


def parity_logit_gap(row: List[Float32], target: Int) -> Float32:
    # Top-1 logit minus target logit; 0.0 when target is top-1.
    # Returns -1.0 when target is out of range (fail-closed sentinel;
    # real gaps are always >= 0).
    if target < 0 or target >= len(row):
        return Float32(-1.0)
    var top = row[0]
    for i in range(1, len(row)):
        if row[i] > top:
            top = row[i]
    return top - row[target]


def parity_verdict_code(rank: Int, gap: Float32) -> Int:
    # 0 = faithful, 1 = near-tie (faithful band), 2 = divergence,
    # -1 = invalid row (rank/gap sentinel from an out-of-range target).
    if rank < 1 or gap < Float32(0.0):
        return -1
    if rank == 1:
        return 0
    if rank <= 2 and gap < Float32(1.0):
        return 1
    return 2


def parity_verdict_name(code: Int) -> String:
    if code == 0:
        return String("faithful")
    if code == 1:
        return String("near-tie")
    if code == 2:
        return String("divergence")
    return String("invalid")
