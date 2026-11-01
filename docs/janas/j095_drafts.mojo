"""J-095 KV + drafts harness: the rollback exercise and
the acceptance replay, printed from the tree's own
modules (core/kv_drafts over core/kv_int8,
core/speculative_verify, core/speculative_loop and
core/speculative_acceptance).

ROLLBACK EXERCISE (deterministic, stated): int8 store
shape 2 layers x 2 kv-heads x head_dim 16 (width 32),
capacity 24; synthetic rows synth(i) = ((i*37) % 17 - 8)
/ 8 exactly as J-088's bench, row index
layer*4096 + pos*32 + j + salt, K salt 11 / V salt 5000
for plain rows, K salt 777 / V salt 9000 for the rejected
drafts' tentative rows. The drafted store appends plain
rows 0..5 (the committed prefix), tentative rows 6..10
(6..8 plain -- the accepted prefix and the correction
position; 9..10 the rejected drafts' rows), and after
the length-restore rollback the plain continuation's
rows at 9..10. The never-drafted store appends plain
rows 0..10. Printed: the committed-preservation diffs
(up to 6), the intermediate control diff (up to 11,
before the overwriting appends), the final diffs, the
dequantized max difference, the tamper diffs (one code,
one scale), and the quantization round-trip maximum on
the crafted bound row.

ACCEPTANCE REPLAY: J-075's filed SIMULATED fixture
(cross-model pair 1, k=4, ten rounds per row; the
verbatim accepted-count lists of
test_speculative_acceptance.mojo) replayed twice through
plan_verify + J-075's ledger. Printed per row and in
total, with the two replays' exact difference and the
changed-target control (one english round matching one
fewer target token: difference exactly (0, 0, -1)).

PRICE LINES: the per-round byte price at f16 vs int8
for the Coder ladder shape (28 x 4 x 128) on a k=4,
accepted=1 account, and J-085's filed 930 rollback rows
priced at the OLMoE shape (16 x 32 x 64).

Every number is exact arithmetic or a deterministic
exercise through the tree's own modules. NO WALL, NO
LIVE ACCEPTANCE AND NO LIVE ROLLBACK IS MEASURED OR
PRINTED: no live session integrates the int8 store
(INTEGRATION_BLOCKED, J-091), this VM is below its
inference gate and purplelongship is unreachable; the
live legs are deferred to the J-098 gate recipe in the
J-095 doc (section 7). Deterministic: identical output
on every run.
"""
from core.kv_drafts import (
    KVD_PRECISION_F16,
    KVD_PRECISION_INT8,
    acceptance_difference,
    acceptance_verdict,
    committed_rows_bytes,
    draft_kv_per_token,
    int8_code_diff_count,
    int8_max_dequant_diff,
    int8_scale_diff_count,
    int8_state_diff_count,
    kvd_accept_name,
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
)
from core.speculative_verify import PROPOSER_CROSS_MODEL, VerifyAccount, plan_verify

comptime LAYERS = 2
comptime HEADS = 2
comptime HD = 16
comptime WIDTH = 32
comptime CAP = 24
comptime PREFIX = 6
comptime FINAL_LEN = 11


def synth(i: Int) -> Float32:
    return Float32((i * 37) % 17 - 8) / Float32(8.0)


def row_values(layer: Int, pos: Int, salt: Int) -> List[Float32]:
    var row = List[Float32]()
    for j in range(WIDTH):
        row.append(synth(layer * 4096 + pos * WIDTH + j + salt))
    return row^


def append_pos(mut store: Int8KVStore, pos: Int, k_salt: Int, v_salt: Int) raises:
    for layer in range(LAYERS):
        store.append(
            layer, pos, row_values(layer, pos, k_salt), row_values(layer, pos, v_salt)
        )


def build_plain_store() raises -> Int8KVStore:
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


def attn_equal(a: Int8KVStore, b: Int8KVStore, seq_len: Int) raises -> Bool:
    for layer in range(LAYERS):
        for h in range(HEADS):
            var oa = attention_int8_head(a, layer, h, query_for(h), seq_len)
            var ob = attention_int8_head(b, layer, h, query_for(h), seq_len)
            for j in range(HD):
                if oa[j] != ob[j]:
                    return False
    return True


def make_account(accepted: Int) raises -> VerifyAccount:
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
        record_round(ledger, PAIR_ID_QWEN3_06B_TO_4B, text_type, language, account)


def fixture_ledger(english_first: Int) raises -> AcceptanceLedger:
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
        raise Error("KvDrafts harness: fixture row missing")
    return ledger.rows[idx].copy()


def print_row(
    ledger: AcceptanceLedger, label: String, text_type: Int, language: Int
) raises:
    var r = row_of(ledger, text_type, language)
    print(
        "ACCEPT row=" + label
        + " rounds=" + String(r.rounds)
        + " drafted=" + String(r.drafted)
        + " accepted=" + String(r.accepted)
        + " rate_bp=" + String(rate_basis_points(r))
    )


def main() raises:
    print(
        "ROLLBACKHEAD layers=2 heads=2 head_dim=16 width=32 cap=24"
        " prefix=6 final=11 salts_plain_k=11 salts_plain_v=5000"
        " salts_wrong_k=777 salts_wrong_v=9000"
    )
    var drafted = build_drafted_store()
    var prefix = build_prefix_store()
    var plain = build_plain_store()
    print(
        "PRESERVE upto=6 code_diff=" + String(int8_code_diff_count(drafted, prefix, PREFIX))
        + " scale_diff=" + String(int8_scale_diff_count(drafted, prefix, PREFIX))
        + " attn_committed_equal=" + String(attn_equal(drafted, prefix, PREFIX))
    )
    print(
        "CONTROL upto=11 state_diff_before_overwrite="
        + String(int8_state_diff_count(drafted, plain, FINAL_LEN))
        + " code_diff=" + String(int8_code_diff_count(drafted, plain, FINAL_LEN))
        + " scale_diff=" + String(int8_scale_diff_count(drafted, plain, FINAL_LEN))
    )
    for pos in range(9, FINAL_LEN):
        append_pos(drafted, pos, 11, 5000)
    var final_diff = int8_state_diff_count(drafted, plain, FINAL_LEN)
    print(
        "FINAL upto=11 code_diff=" + String(int8_code_diff_count(drafted, plain, FINAL_LEN))
        + " scale_diff=" + String(int8_scale_diff_count(drafted, plain, FINAL_LEN))
        + " state_diff=" + String(final_diff)
        + " dequant_max=" + String(int8_max_dequant_diff(drafted, plain, FINAL_LEN))
        + " attn_final_equal=" + String(attn_equal(drafted, plain, FINAL_LEN))
        + " verdict=" + kvd_rollback_name(rollback_verdict(final_diff))
    )
    var t1 = build_plain_store()
    var orig = t1.k_data[0]
    t1.k_data[0] = Int8(5) if orig != Int8(5) else Int8(6)
    var t2 = build_plain_store()
    t2.k_scales[0] = t2.k_scales[0] + Float32(0.5)
    print(
        "TAMPER code_diff=" + String(int8_code_diff_count(t1, plain, FINAL_LEN))
        + " scale_diff=" + String(int8_scale_diff_count(t2, plain, FINAL_LEN))
        + " verdict=" + kvd_rollback_name(
            rollback_verdict(int8_state_diff_count(t1, plain, FINAL_LEN))
        )
    )
    var qstore = Int8KVStore(1, 1, HD, 4)
    var krow = List[Float32]()
    var vrow = List[Float32]()
    for j in range(HD):
        krow.append(Float32(1.0) if j == 0 else (Float32(0.5) if j == 1 else Float32(0)))
        vrow.append(Float32(0))
    qstore.append(0, 0, krow, vrow)
    var back = qstore.read_k(0, 0)
    var worst = Float32(0)
    for j in range(HD):
        var d = back[j] - krow[j]
        if d < Float32(0):
            d = -d
        if d > worst:
            worst = d
    print("QUANT bound_row_max_err=" + String(worst) + " bound=0.003937006")

    var la = fixture_ledger(4)
    var lb = fixture_ledger(4)
    print_row(la, "english", TEXT_PROSE, LANG_ENGLISH)
    print_row(la, "italian", TEXT_PROSE, LANG_ITALIAN)
    print_row(la, "code", TEXT_CODE, LANG_NOT_APPLICABLE)
    print_row(la, "structured", TEXT_STRUCTURED, LANG_NOT_APPLICABLE)
    var ta = ledger_totals(la, PROPOSER_CROSS_MODEL, PAIR_ID_QWEN3_06B_TO_4B)
    var tb = ledger_totals(lb, PROPOSER_CROSS_MODEL, PAIR_ID_QWEN3_06B_TO_4B)
    var dt = acceptance_difference(ta, tb)
    print(
        "ACCEPTTOTAL rounds=" + String(ta.rounds)
        + " drafted=" + String(ta.drafted)
        + " accepted=" + String(ta.accepted)
        + " rate_bp=" + String(rate_basis_points(ta))
        + " replay_diff=(" + String(dt.rounds) + "," + String(dt.drafted)
        + "," + String(dt.accepted) + ")"
        + " verdict=" + kvd_accept_name(acceptance_verdict(dt))
    )
    var lc = fixture_ledger(3)
    var tc = ledger_totals(lc, PROPOSER_CROSS_MODEL, PAIR_ID_QWEN3_06B_TO_4B)
    var dc = acceptance_difference(tc, ta)
    print(
        "ACCEPTCONTROL diff=(" + String(dc.rounds) + "," + String(dc.drafted)
        + "," + String(dc.accepted) + ")"
        + " verdict=" + kvd_accept_name(acceptance_verdict(dc))
    )
    var account = make_account(1)
    print(
        "PRICE shape=coder-28x4x128 account_k=4 accepted=1"
        + " tentative_f16=" + String(tentative_rows_bytes(account, KVD_PRECISION_F16, 28, 4, 128))
        + " tentative_int8=" + String(tentative_rows_bytes(account, KVD_PRECISION_INT8, 28, 4, 128))
        + " committed_f16=" + String(committed_rows_bytes(account, KVD_PRECISION_F16, 28, 4, 128))
        + " committed_int8=" + String(committed_rows_bytes(account, KVD_PRECISION_INT8, 28, 4, 128))
        + " rollback_f16=" + String(rollback_rows_bytes(account, KVD_PRECISION_F16, 28, 4, 128))
        + " rollback_int8=" + String(rollback_rows_bytes(account, KVD_PRECISION_INT8, 28, 4, 128))
    )
    print(
        "PRICE shape=olmoe-16x32x64 rollback_rows=930"
        + " rollback_f16=" + String(930 * draft_kv_per_token(KVD_PRECISION_F16, 16, 32, 64))
        + " rollback_int8=" + String(930 * draft_kv_per_token(KVD_PRECISION_INT8, 16, 32, 64))
    )
    print("DRAFTSDONE live=NOT_PROVEN_DEFERRED_J098 walls=NOT_PROVEN")
