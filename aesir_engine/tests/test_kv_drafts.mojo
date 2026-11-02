"""KV + drafts (J-095): rollback exactness at 8 bits and
acceptance under 8-bit KV, graded through the tree's own
modules -- the validation gates reproducing J-075's filed
acceptance fixture totals and J-072's filed multi-round
totals EXACTLY, the int8 store rollback exercise
(committed preservation, never-drafted bit-equality,
dead-row attention irrelevance, tamper controls), the
account-level acceptance invariance replay with its
changed-target control, and the per-precision byte price
of a round. No live session, no wall, no live acceptance
claimed here: the live legs are deferred to the J-098
gate recipe in the J-095 doc (section 7).
"""
from core.kv_drafts import (
    KVD_ACCEPT_DIFFERS,
    KVD_ACCEPT_UNCHANGED,
    KVD_PRECISION_F16,
    KVD_PRECISION_INT8,
    KVD_ROLLBACK_EXACT,
    KVD_ROLLBACK_NOT_EXACT,
    acceptance_difference,
    acceptance_verdict,
    committed_rows_bytes,
    draft_kv_per_token,
    int8_code_diff_count,
    int8_max_dequant_diff,
    int8_scale_diff_count,
    int8_state_diff_count,
    kvd_accept_name,
    kvd_precision_name,
    kvd_rollback_name,
    rollback_rows_bytes,
    rollback_verdict,
    tentative_rows_bytes,
)
from core.kv_int8 import Int8KVStore, attention_int8_head
from core.speculative_acceptance import (
    LANG_ENGLISH,
    LANG_ITALIAN,
    LANG_NOT_APPLICABLE,
    PAIR_ID_QWEN3_06B_TO_4B,
    TEXT_CODE,
    TEXT_PROSE,
    TEXT_STRUCTURED,
    AcceptanceLedger,
    AcceptanceRow,
    ledger_totals,
    rate_basis_points,
    record_round,
    row_totals_reproduce,
)
from core.speculative_loop import LoopState, run_loop
from core.speculative_verify import (
    PROPOSER_CROSS_MODEL,
    SLOT_CROSS_MODEL,
    VerifyAccount,
    plan_verify,
    sequences_identical,
)

# The rollback exercise's store shape (stated): 2 layers,
# 2 kv-heads, head_dim 16, capacity 24.
comptime LAYERS = 2
comptime HEADS = 2
comptime HD = 16
comptime WIDTH = 32
comptime CAP = 24
comptime PREFIX = 6
comptime FINAL_LEN = 11


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "KvDrafts " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("KvDrafts: expected true -- " + what)


def synth(i: Int) -> Float32:
    """Deterministic synthetic values in [-1, 1] (J-088's)."""
    return Float32((i * 37) % 17 - 8) / Float32(8.0)


def row_values(layer: Int, pos: Int, salt: Int) -> List[Float32]:
    var row = List[Float32]()
    for j in range(WIDTH):
        row.append(synth(layer * 4096 + pos * WIDTH + j + salt))
    return row^


def append_pos(
    mut store: Int8KVStore, pos: Int, k_salt: Int, v_salt: Int
) raises:
    for layer in range(LAYERS):
        store.append(
            layer, pos, row_values(layer, pos, k_salt), row_values(layer, pos, v_salt)
        )


def build_plain_store() raises -> Int8KVStore:
    """The store that never drafted: plain rows 0..10."""
    var store = Int8KVStore(LAYERS, HEADS, HD, CAP)
    for pos in range(FINAL_LEN):
        append_pos(store, pos, 11, 5000)
    return store^


def build_prefix_store() raises -> Int8KVStore:
    var store = Int8KVStore(LAYERS, HEADS, HD, CAP)
    for pos in range(PREFIX):
        append_pos(store, pos, 11, 5000)
    return store^


def build_drafted_store() raises -> Int8KVStore:
    """Prefix, then one verify pass's tentative rows:
    positions 6..8 carry the plain rows (the accepted
    prefix + the correction position), positions 9..10
    carry the rejected drafts' rows (wrong salts)."""
    var store = build_prefix_store()
    for pos in range(PREFIX, 9):
        append_pos(store, pos, 11, 5000)
    for pos in range(9, FINAL_LEN):
        append_pos(store, pos, 777, 9000)
    return store^


def query_for(head: Int) -> List[Float32]:
    var q = List[Float32]()
    for j in range(HD):
        q.append(synth(head * HD + j + 97))
    return q^


def attn_equal(
    a: Int8KVStore, b: Int8KVStore, seq_len: Int
) raises -> Bool:
    for layer in range(LAYERS):
        for h in range(HEADS):
            var oa = attention_int8_head(a, layer, h, query_for(h), seq_len)
            var ob = attention_int8_head(b, layer, h, query_for(h), seq_len)
            for j in range(HD):
                if oa[j] != ob[j]:
                    return False
    return True


def test_codes_and_prices() raises:
    expect_eq(draft_kv_per_token(KVD_PRECISION_F16, 28, 4, 128), 57344, "Coder f16/token (J-087)")
    expect_eq(draft_kv_per_token(KVD_PRECISION_INT8, 28, 4, 128), 29568, "Coder int8/token (J-088)")
    expect_eq(draft_kv_per_token(KVD_PRECISION_F16, 32, 8, 128), 131072, "8B f16/token")
    expect_eq(draft_kv_per_token(KVD_PRECISION_INT8, 32, 8, 128), 67584, "8B int8/token")
    expect_eq(draft_kv_per_token(KVD_PRECISION_F16, 16, 32, 64), 131072, "OLMoE f16/token")
    expect_eq(draft_kv_per_token(KVD_PRECISION_INT8, 16, 32, 64), 69632, "OLMoE int8/token")
    if kvd_precision_name(KVD_PRECISION_INT8) != String("int8"):
        raise Error("KvDrafts: int8 name")
    if kvd_rollback_name(KVD_ROLLBACK_EXACT) != String("EXACT"):
        raise Error("KvDrafts: rollback name")
    if kvd_accept_name(KVD_ACCEPT_UNCHANGED) != String("UNCHANGED"):
        raise Error("KvDrafts: accept name")
    print("PASS: codes + prices -- per-token KV through J-087/J-088 accounting (Coder 57,344 f16 / 29,568 int8)")


def make_account(accepted: Int) raises -> VerifyAccount:
    """J-075's fixture round shape: cross-model, k=4, the
    draft matching the target for exactly `accepted`."""
    var target = List[Int]()
    for i in range(5):
        target.append(100 + i)
    var draft = List[Int]()
    for i in range(4):
        if i < accepted:
            draft.append(100 + i)
        else:
            draft.append(900 + i)
    return plan_verify(PROPOSER_CROSS_MODEL, draft, target, 0, 256, 0, 0)


def record_list(
    mut ledger: AcceptanceLedger,
    text_type: Int,
    language: Int,
    accepted_list: List[Int],
) raises:
    for i in range(len(accepted_list)):
        var account = make_account(accepted_list[i])
        record_round(
            ledger, PAIR_ID_QWEN3_06B_TO_4B, text_type, language, account
        )


def fixture_ledger(english_first: Int) raises -> AcceptanceLedger:
    """J-075's filed SIMULATED fixture, verbatim lists
    (test_speculative_acceptance.mojo's measure fixture);
    english_first lets the control replay change one
    round's accepted count by changing its target match."""
    var ledger = AcceptanceLedger()
    var en: List[Int] = [english_first, 4, 3, 4, 3, 4, 4, 3, 4, 1]
    record_list(ledger, TEXT_PROSE, LANG_ENGLISH, en)
    var it: List[Int] = [2, 1, 1, 2, 1, 0, 2, 1, 1, 1]
    record_list(ledger, TEXT_PROSE, LANG_ITALIAN, it)
    var code: List[Int] = [4, 3, 4, 4, 2, 4, 3, 4, 4, 4]
    record_list(ledger, TEXT_CODE, LANG_NOT_APPLICABLE, code)
    var structured: List[Int] = [3, 3, 4, 3, 2, 3, 4, 3, 3, 3]
    record_list(ledger, TEXT_STRUCTURED, LANG_NOT_APPLICABLE, structured)
    return ledger^


def row_of(
    ledger: AcceptanceLedger, text_type: Int, language: Int
) raises -> AcceptanceRow:
    var idx = ledger.find_row(
        PROPOSER_CROSS_MODEL, PAIR_ID_QWEN3_06B_TO_4B, text_type, language
    )
    if idx < 0:
        raise Error("KvDrafts: fixture row missing")
    return ledger.rows[idx].copy()


def test_validation_gate_j075() raises:
    var ledger = fixture_ledger(4)
    var en = row_of(ledger, TEXT_PROSE, LANG_ENGLISH)
    expect_eq(en.rounds, 10, "J-075 english rounds")
    expect_eq(en.drafted, 40, "J-075 english drafted")
    expect_eq(en.accepted, 34, "J-075 english accepted")
    expect_eq(rate_basis_points(en), 8500, "J-075 english rate bp")
    var it = row_of(ledger, TEXT_PROSE, LANG_ITALIAN)
    expect_eq(it.accepted, 12, "J-075 italian accepted")
    expect_eq(rate_basis_points(it), 3000, "J-075 italian rate bp")
    var code = row_of(ledger, TEXT_CODE, LANG_NOT_APPLICABLE)
    expect_eq(code.accepted, 36, "J-075 code accepted")
    var st = row_of(ledger, TEXT_STRUCTURED, LANG_NOT_APPLICABLE)
    expect_eq(st.accepted, 31, "J-075 structured accepted")
    var total = ledger_totals(ledger, PROPOSER_CROSS_MODEL, PAIR_ID_QWEN3_06B_TO_4B)
    expect_eq(total.rounds, 40, "J-075 total rounds")
    expect_eq(total.drafted, 160, "J-075 total drafted")
    expect_eq(total.accepted, 113, "J-075 total accepted")
    expect_eq(rate_basis_points(total), 7062, "J-075 total rate bp (70.62%)")
    expect_true(row_totals_reproduce(en), "J-075 english row reproduces")
    expect_true(row_totals_reproduce(it), "J-075 italian row reproduces")
    print("PASS: validation gate A -- J-075 fixture reproduced EXACTLY (40 rounds, 160 drafted, 113 accepted; en 34 / it 12 / code 36 / structured 31)")


def test_validation_gate_j072() raises:
    # J-072's filed multi-round scenario, verbatim fixture
    # (test_speculative_loop.mojo): six rounds, 24 tokens,
    # accepted 18, rollback rows 6, KV 67 -> 91. The loop
    # drive takes no precision input: this IS the rollback
    # account at both precisions.
    var plain: List[Int] = [
        11, 4, 19, 7, 23, 5, 17, 2, 29, 13,
        3, 31, 37, 41, 43, 47, 53, 59, 61, 67,
        71, 73, 79, 83,
    ]
    var ks: List[Int] = [4, 4, 3, 5, 4, 4]
    var wrongs: List[Int] = [-1, 2, 0, -1, 3, -1]
    var drafts_flat = List[Int]()
    var pos = 0
    for r in range(len(ks)):
        for i in range(ks[r]):
            if i == wrongs[r]:
                drafts_flat.append(900 + r)
            else:
                drafts_flat.append(plain[pos + i])
        var acc = ks[r]
        if wrongs[r] != -1:
            acc = wrongs[r]
        pos += acc + 1
    expect_eq(pos, 24, "fixture covers the continuation")
    var initial = LoopState(4096, 67, 67, UInt64(2024), 67)
    var result = run_loop(
        initial, SLOT_CROSS_MODEL, PROPOSER_CROSS_MODEL, drafts_flat, ks, plain
    )
    expect_eq(result.rounds, 6, "J-072 rounds")
    expect_eq(result.total_accepted, 18, "J-072 accepted total")
    expect_eq(result.total_rollback_rows, 6, "J-072 rollback total")
    expect_eq(result.final_kv_length, 91, "J-072 final KV")
    expect_eq(result.final_draft_kv_length, 85, "J-072 proposer KV")
    expect_true(result.rng_word == UInt64(2024), "J-072 RNG unchanged")
    expect_true(sequences_identical(result.emitted, plain), "J-072 emission identical")
    print("PASS: validation gate B -- J-072 scenario reproduced EXACTLY (24 tokens, accepted 18, rollback 6, KV 67->91, RNG unchanged)")


def test_committed_preservation() raises:
    var drafted = build_drafted_store()
    var prefix = build_prefix_store()
    expect_eq(int8_code_diff_count(drafted, prefix, PREFIX), 0, "R-A code diff over the committed prefix")
    expect_eq(int8_scale_diff_count(drafted, prefix, PREFIX), 0, "R-A scale diff over the committed prefix")
    expect_eq(int8_state_diff_count(drafted, prefix, PREFIX), 0, "R-A total diff")
    expect_true(attn_equal(drafted, prefix, PREFIX), "R-C attention over the committed length unchanged by tentative rows")
    print("PASS: R-A/R-C -- tentative appends changed 0 committed scalars; attention over the committed length identical")


def test_never_drafted_equality() raises:
    var drafted = build_drafted_store()
    var plain = build_plain_store()
    # Control first: before the overwriting appends, the
    # rejected positions DO differ -- the exercise wrote
    # real tentative rows, not a vacuous comparison.
    var control = int8_state_diff_count(drafted, plain, FINAL_LEN)
    expect_true(control > 0, "intermediate diff over the rejected positions is real (> 0)")
    # Rollback is the length restore; the next appends
    # overwrite the rolled-back positions with the plain
    # continuation's rows.
    for pos in range(9, FINAL_LEN):
        append_pos(drafted, pos, 11, 5000)
    expect_eq(int8_code_diff_count(drafted, plain, FINAL_LEN), 0, "R-B code diff, final state")
    expect_eq(int8_scale_diff_count(drafted, plain, FINAL_LEN), 0, "R-B scale diff, final state")
    expect_eq(int8_state_diff_count(drafted, plain, FINAL_LEN), 0, "R-B total diff")
    expect_true(int8_max_dequant_diff(drafted, plain, FINAL_LEN) == Float32(0), "R-B dequantized rows identical")
    expect_eq(rollback_verdict(int8_state_diff_count(drafted, plain, FINAL_LEN)), KVD_ROLLBACK_EXACT, "R-B verdict EXACT")
    expect_true(attn_equal(drafted, plain, FINAL_LEN), "final attention identical at every head/layer")
    print("PASS: R-B -- after rollback + overwrite the int8 state is BIT-EXACT against the never-drafted state (diff 0 codes, 0 scales)")


def test_tamper_controls() raises:
    var plain = build_plain_store()
    var t1 = build_plain_store()
    var orig = t1.k_data[0]
    t1.k_data[0] = Int8(5) if orig != Int8(5) else Int8(6)
    expect_eq(int8_code_diff_count(t1, plain, FINAL_LEN), 1, "one flipped code seen exactly once")
    expect_eq(int8_scale_diff_count(t1, plain, FINAL_LEN), 0, "code tamper leaves scales clean")
    expect_eq(rollback_verdict(int8_state_diff_count(t1, plain, FINAL_LEN)), KVD_ROLLBACK_NOT_EXACT, "tampered state grades NOT_EXACT")
    var t2 = build_plain_store()
    t2.k_scales[0] = t2.k_scales[0] + Float32(0.5)
    expect_eq(int8_scale_diff_count(t2, plain, FINAL_LEN), 1, "one shifted scale seen exactly once")
    expect_eq(int8_code_diff_count(t2, plain, FINAL_LEN), 0, "scale tamper leaves codes clean")
    print("PASS: tamper controls -- one flipped code / one shifted scale each seen as exactly 1 diff, verdict NOT_EXACT")


def test_quantization_is_not_rollback_error() raises:
    # A row whose maxabs is 1.0 and which carries 0.5: its
    # round-trip error is exactly half the row scale
    # (J-088's bound), yet two identically-built stores --
    # one of them the rolled-back one of the R-B group --
    # differ by zero: the quantization error is in BOTH
    # states and is not charged to rollback.
    var store = Int8KVStore(1, 1, HD, 4)
    var krow = List[Float32]()
    var vrow = List[Float32]()
    for j in range(HD):
        krow.append(Float32(1.0) if j == 0 else (Float32(0.5) if j == 1 else Float32(0)))
        vrow.append(Float32(0))
    store.append(0, 0, krow, vrow)
    var back = store.read_k(0, 0)
    var worst = Float32(0)
    for j in range(HD):
        var d = back[j] - krow[j]
        if d < Float32(0):
            d = -d
        if d > worst:
            worst = d
    expect_true(worst > Float32(0.0039), "quantization error is real (> 0.0039)")
    expect_true(worst <= Float32(0.0039371), "quantization error at J-088's bound (<= scale/2)")
    print("PASS: quantization != rollback error -- round-trip error at the J-088 bound in both states; rollback extra diff is 0 (R-B group)")


def test_acceptance_invariance() raises:
    var a = fixture_ledger(4)
    var b = fixture_ledger(4)
    var rows: List[Int] = [TEXT_PROSE, TEXT_PROSE, TEXT_CODE, TEXT_STRUCTURED]
    var langs: List[Int] = [LANG_ENGLISH, LANG_ITALIAN, LANG_NOT_APPLICABLE, LANG_NOT_APPLICABLE]
    for i in range(4):
        var d = acceptance_difference(row_of(a, rows[i], langs[i]), row_of(b, rows[i], langs[i]))
        expect_true(d.is_zero(), "row replay difference is zero")
        expect_eq(acceptance_verdict(d), KVD_ACCEPT_UNCHANGED, "row verdict UNCHANGED")
    var ta = ledger_totals(a, PROPOSER_CROSS_MODEL, PAIR_ID_QWEN3_06B_TO_4B)
    var tb = ledger_totals(b, PROPOSER_CROSS_MODEL, PAIR_ID_QWEN3_06B_TO_4B)
    var dt = acceptance_difference(ta, tb)
    expect_true(dt.is_zero(), "total replay difference is (0,0,0)")
    expect_eq(acceptance_verdict(dt), KVD_ACCEPT_UNCHANGED, "total verdict UNCHANGED")
    print("PASS: acceptance invariance (account level) -- two replays of the filed fixture differ by exactly (0, 0, 0), UNCHANGED")


def test_acceptance_changed_target_control() raises:
    # The ONLY channel by which precision could change
    # acceptance: a changed target list. One english round
    # whose draft matches one fewer target token moves the
    # totals by exactly (0, 0, -1) -- the replay sees it.
    var base = fixture_ledger(4)
    var changed = fixture_ledger(3)
    var tb = ledger_totals(base, PROPOSER_CROSS_MODEL, PAIR_ID_QWEN3_06B_TO_4B)
    var tc = ledger_totals(changed, PROPOSER_CROSS_MODEL, PAIR_ID_QWEN3_06B_TO_4B)
    var d = acceptance_difference(tc, tb)
    expect_eq(d.rounds, 0, "control rounds diff")
    expect_eq(d.drafted, 0, "control drafted diff")
    expect_eq(d.accepted, -1, "control accepted diff is exactly -1")
    expect_eq(acceptance_verdict(d), KVD_ACCEPT_DIFFERS, "control verdict DIFFERS")
    var en = row_of(changed, TEXT_PROSE, LANG_ENGLISH)
    expect_eq(en.accepted, 33, "control english row accepted 33")
    print("PASS: changed-target control -- one changed target match moves acceptance by exactly (0, 0, -1), DIFFERS")


def test_round_byte_prices() raises:
    var account = make_account(1)  # k=4, accepted=1, rollback 3
    expect_eq(tentative_rows_bytes(account, KVD_PRECISION_F16, 28, 4, 128), 286720, "tentative 5 rows f16 Coder")
    expect_eq(tentative_rows_bytes(account, KVD_PRECISION_INT8, 28, 4, 128), 147840, "tentative 5 rows int8 Coder")
    expect_eq(committed_rows_bytes(account, KVD_PRECISION_F16, 28, 4, 128), 114688, "committed 2 rows f16 Coder")
    expect_eq(committed_rows_bytes(account, KVD_PRECISION_INT8, 28, 4, 128), 59136, "committed 2 rows int8 Coder")
    expect_eq(rollback_rows_bytes(account, KVD_PRECISION_F16, 28, 4, 128), 172032, "rollback 3 rows f16 Coder")
    expect_eq(rollback_rows_bytes(account, KVD_PRECISION_INT8, 28, 4, 128), 88704, "rollback 3 rows int8 Coder")
    # J-085's filed rollback total (930 rows) priced at the
    # soak model's shape (OLMoE, J-087/J-088 prices):
    # exact arithmetic over a SIMULATED fixture count.
    expect_eq(930 * draft_kv_per_token(KVD_PRECISION_F16, 16, 32, 64), 121896960, "J-085 rollback rows at f16")
    expect_eq(930 * draft_kv_per_token(KVD_PRECISION_INT8, 16, 32, 64), 64757760, "J-085 rollback rows at int8")
    print("PASS: round byte prices -- rollback of 3 rows: 172,032 B f16 vs 88,704 B int8 (Coder); J-085's 930 rows: 121,896,960 vs 64,757,760 (OLMoE)")


def test_refusals() raises:
    var refused = 0
    var a = build_plain_store()
    var other_cap = Int8KVStore(LAYERS, HEADS, HD, 16)
    try:
        _ = int8_state_diff_count(a, other_cap, 4)
    except:
        refused += 1
    try:
        _ = int8_code_diff_count(a, a, 0)
    except:
        refused += 1
    try:
        _ = int8_scale_diff_count(a, a, CAP + 1)
    except:
        refused += 1
    try:
        _ = draft_kv_per_token(9, 28, 4, 128)
    except:
        refused += 1
    try:
        _ = rollback_verdict(-1)
    except:
        refused += 1
    var bad = VerifyAccount()
    bad.proposer_kind = PROPOSER_CROSS_MODEL
    bad.k = 4
    bad.verify_width = 5
    bad.accepted_count = 1
    bad.emitted_tokens.append(100)
    bad.emitted_tokens.append(101)
    bad.kv_after = 99  # inconsistent: must be kv_before + accepted + 1
    try:
        _ = rollback_rows_bytes(bad, KVD_PRECISION_INT8, 28, 4, 128)
    except:
        refused += 1
    var r1 = AcceptanceRow(PROPOSER_CROSS_MODEL, 1, TEXT_PROSE, LANG_ENGLISH)
    var r2 = AcceptanceRow(PROPOSER_CROSS_MODEL, 1, TEXT_PROSE, LANG_ITALIAN)
    try:
        _ = acceptance_difference(r1, r2)
    except:
        refused += 1
    expect_eq(refused, 7, "all refusals raised")
    print("PASS: refusals -- shape mismatch, length outside the stores, unknown precision, negative diff, inconsistent account, cross-row difference (7/7)")


def main() raises:
    test_codes_and_prices()
    test_validation_gate_j075()
    test_validation_gate_j072()
    test_committed_preservation()
    test_never_drafted_equality()
    test_tamper_controls()
    test_quantization_is_not_rollback_error()
    test_acceptance_invariance()
    test_acceptance_changed_target_control()
    test_round_byte_prices()
    test_refusals()
    print("ALL PASS: kv drafts (11 groups)")
