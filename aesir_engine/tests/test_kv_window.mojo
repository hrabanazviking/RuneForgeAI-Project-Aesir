"""Sliding-window service (J-097): the divergence
exercise on concretely edited token sequences for
every pre-registered shape, the reuse cap (the
tree's final-token rule), the per-shape account
graded against J-094's filed read totals EXACTLY,
conservation, the KV rewrite prices, and the mix
verdict under the pre-registered rule. No live
session, no wall and no editor latency claimed
here: the live legs are deferred to the J-098 gate
recipe in the J-097 doc (section 7), and J-111
inherits them.
"""
from core.kv_ladder import ladder_rung
from core.kv_window import (
    KW_APPEND,
    KW_DELETE,
    KW_DOC_LINES,
    KW_DOC_TOKENS,
    KW_EDIT_IN_PLACE,
    KW_INSERT,
    KW_KEPT,
    KW_MIN_SAVED_PPM,
    KW_MOVE,
    KW_NOT_KEPT,
    KW_NO_CHANGE,
    KW_NO_SAVE,
    KW_SAVES,
    KW_TOKENS_PER_LINE,
    kw_account,
    kw_first_divergence,
    kw_reusable,
    kw_saved_ppm,
    kw_service_verdict,
    kw_shape_first_divergence,
    kw_shape_new_len,
    kw_shape_verdict,
    kw_verdict_name,
    kw_work_at,
)

# The ladder witness (J-091/J-094): Qwen2.5-Coder-7B.
comptime LAYERS = 28
comptime HEADS = 4
comptime HD = 128
comptime HIDDEN = 3584
comptime QW = 3584
comptime KVW = 512
comptime FFN = 18944


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "KVWindow " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("KVWindow: expected true -- " + what)


# -- the deterministic document and its concrete edits --------------------


def line_tokens(line: Int) -> List[Int]:
    var out = List[Int]()
    for off in range(KW_TOKENS_PER_LINE):
        out.append(line * 1000 + off)
    return out^


def doc_tokens() -> List[Int]:
    var out = List[Int]()
    for line in range(KW_DOC_LINES):
        var lt = line_tokens(line)
        for i in range(len(lt)):
            out.append(lt[i])
    return out^


def edited_doc(line: Int) -> List[Int]:
    var out = doc_tokens()
    for off in range(KW_TOKENS_PER_LINE):
        out[line * KW_TOKENS_PER_LINE + off] = 500000 + line * 1000 + off
    return out^


def moved_doc(a: Int, b: Int) -> List[Int]:
    var order = List[Int]()
    for line in range(KW_DOC_LINES):
        if line != a:
            order.append(line)
    var reordered = List[Int]()
    for i in range(len(order) + 1):
        if i == b:
            reordered.append(a)
        if i < len(order):
            reordered.append(order[i])
    var out = List[Int]()
    for i in range(len(reordered)):
        var lt = line_tokens(reordered[i])
        for j in range(len(lt)):
            out.append(lt[j])
    return out^


def inserted_doc(a: Int) -> List[Int]:
    var out = List[Int]()
    for line in range(KW_DOC_LINES):
        if line == a:
            for off in range(KW_TOKENS_PER_LINE):
                out.append(900000 + off)
        var lt = line_tokens(line)
        for j in range(len(lt)):
            out.append(lt[j])
    return out^


def deleted_doc(a: Int) -> List[Int]:
    var out = List[Int]()
    for line in range(KW_DOC_LINES):
        if line != a:
            var lt = line_tokens(line)
            for j in range(len(lt)):
                out.append(lt[j])
    return out^


def appended_doc() -> List[Int]:
    var out = doc_tokens()
    var lt = line_tokens(KW_DOC_LINES)
    for j in range(len(lt)):
        out.append(lt[j])
    return out^


# -- the pre-registered shape table -----------------------------------------
# (shape code, a, b, new_len, divergence, reuse, naive,
#  avoided, window cost, saved ppm, kv rewritten f16, int8)


def shape_rows() -> List[List[Int]]:
    var rows = List[List[Int]]()
    rows.append(List[Int]([
        KW_EDIT_IN_PLACE, 96, 0, 8192, 6144, 6144, 60190493769728,
        43880149942272, 16310343827456, 729021, 117440512, 60555264]))
    rows.append(List[Int]([
        KW_EDIT_IN_PLACE, 8, 0, 8192, 512, 512, 60190493769728,
        3367305740288, 56823188029440, 55944, 440401920, 227082240]))
    rows.append(List[Int]([
        KW_EDIT_IN_PLACE, 0, 0, 8192, 0, 0, 60190493769728,
        0, 60190493769728, 0, 469762048, 242221056]))
    rows.append(List[Int]([
        KW_MOVE, 100, 127, 8192, 6400, 6400, 60190493769728,
        45872906240000, 14317587529728, 762128, 102760448, 52985856]))
    rows.append(List[Int]([
        KW_MOVE, 8, 96, 8192, 512, 512, 60190493769728,
        3367305740288, 56823188029440, 55944, 440401920, 227082240]))
    rows.append(List[Int]([
        KW_INSERT, 32, 0, 8256, 2048, 2048, 60713756393472,
        13784903057408, 46928853336064, 227047, 355991552, 183558144]))
    rows.append(List[Int]([
        KW_DELETE, 32, 0, 8128, 2048, 2048, 59668053229568,
        13784903057408, 45883150172160, 231026, 348651520, 179773440]))
    rows.append(List[Int]([
        KW_APPEND, 0, 0, 8256, 8192, 8192, 60713756393472,
        60190493769728, 523262623744, 991381, 3670016, 1892352]))
    rows.append(List[Int]([
        KW_NO_CHANGE, 0, 0, 8192, 8192, 8191, 60190493769728,
        60182324314112, 8169455616, 999864, 57344, 29568]))
    return rows^


def concrete_new(shape: Int, a: Int, b: Int) -> List[Int]:
    if shape == KW_EDIT_IN_PLACE:
        return edited_doc(a)
    if shape == KW_MOVE:
        return moved_doc(a, b)
    if shape == KW_INSERT:
        return inserted_doc(a)
    if shape == KW_DELETE:
        return deleted_doc(a)
    if shape == KW_APPEND:
        return appended_doc()
    return doc_tokens()


def test_codes_geometry() raises:
    expect_eq(KW_DOC_LINES * KW_TOKENS_PER_LINE, KW_DOC_TOKENS, "document geometry 128 x 64")
    expect_eq(KW_DOC_TOKENS, 8192, "document is the 8192 ladder rung")
    expect_eq(KW_MIN_SAVED_PPM, 250000, "pre-registered mix bar")
    if kw_verdict_name(KW_KEPT) != String("KEPT"):
        raise Error("KVWindow: verdict name")
    print("PASS: codes + geometry -- document 128 lines x 64 tokens = 8,192 (a ladder rung); mix bar 250,000 ppm pre-registered")


def test_gate_work_j094() raises:
    var works: List[Int] = [
        6787224829952, 28411619704832, 60190493769728,
        133850004979712, 321576079720448,
    ]
    for i in range(5):
        var rung = ladder_rung(i)
        expect_eq(
            kw_work_at(LAYERS, HIDDEN, QW, KVW, FFN, rung), works[i],
            "J-094 read work at rung " + String(rung),
        )
    expect_eq(kw_work_at(LAYERS, HIDDEN, QW, KVW, FFN, 0), 0, "W(0) == 0 by definition")
    print("PASS: validation gate -- J-094 read-work totals reproduced EXACTLY at all 5 rungs; W(0) == 0")


def test_divergence_exercise() raises:
    var old = doc_tokens()
    var rows = shape_rows()
    for i in range(len(rows)):
        var r = rows[i].copy()
        var new = concrete_new(r[0], r[1], r[2])
        expect_eq(len(new), r[3], "concrete new length, shape row " + String(i))
        expect_eq(
            kw_shape_new_len(r[0], KW_DOC_LINES, KW_TOKENS_PER_LINE), r[3],
            "predicted new length, shape row " + String(i),
        )
        expect_eq(
            kw_shape_first_divergence(
                r[0], KW_DOC_LINES, KW_TOKENS_PER_LINE, r[1], r[2]),
            r[4], "predicted divergence, shape row " + String(i),
        )
        expect_eq(
            kw_first_divergence(old, new), r[4],
            "computed divergence of the concrete edit, shape row " + String(i),
        )
    # Prefix controls: one sequence a prefix of the other
    # diverges at the shorter length; identical short
    # sequences diverge at their length.
    var short = List[Int]([7, 8, 9])
    var longer = List[Int]([7, 8, 9, 10])
    expect_eq(kw_first_divergence(short, longer), 3, "prefix-of diverges at the shorter length")
    expect_eq(kw_first_divergence(short, short.copy()), 3, "identical sequences diverge at their length")
    var other = List[Int]([7, 1, 9])
    expect_eq(kw_first_divergence(short, other), 1, "mid-sequence divergence")
    print("PASS: divergence exercise -- predicted == computed first divergence on the concretely edited sequences for all 9 shapes; prefix controls exact")


def test_reuse_cap() raises:
    var rows = shape_rows()
    for i in range(len(rows)):
        var r = rows[i].copy()
        expect_eq(
            kw_reusable(KW_DOC_TOKENS, r[3], r[4]), r[5],
            "reuse, shape row " + String(i),
        )
    # The final-token rule on a synthetic pair: identical
    # sequences of length 11 reuse 10, never 11 (the
    # core/prompt_prefix law this service follows).
    expect_eq(kw_reusable(11, 11, 11), 10, "final token always recomputes")
    expect_eq(kw_reusable(11, 11, 4), 4, "a mid divergence is uncapped")
    print("PASS: reuse cap -- reuse == min(divergence, new_len - 1, old_len) on all 9 shapes; identical length-11 sequences reuse 10 (final-token rule)")


def test_account_pins() raises:
    var rows = shape_rows()
    for i in range(len(rows)):
        var r = rows[i].copy()
        var acct = kw_account(
            LAYERS, HIDDEN, QW, KVW, FFN, HEADS, HD, r[3], r[5])
        expect_eq(acct.naive_work, r[6], "naive, shape row " + String(i))
        expect_eq(acct.avoided_work, r[7], "avoided, shape row " + String(i))
        expect_eq(acct.window_work, r[8], "window cost, shape row " + String(i))
        expect_eq(acct.saved_ppm, r[9], "saved ppm, shape row " + String(i))
    print("PASS: account pins -- naive / avoided / window cost / saved ppm exact for all 9 shapes (EDIT_LATE saves 729,021 ppm; EDIT_FIRST 0; APPEND 991,381)")


def test_conservation_and_verdicts() raises:
    var rows = shape_rows()
    for i in range(len(rows)):
        var r = rows[i].copy()
        var acct = kw_account(
            LAYERS, HIDDEN, QW, KVW, FFN, HEADS, HD, r[3], r[5])
        expect_eq(
            acct.avoided_work + acct.window_work, acct.naive_work,
            "conservation, shape row " + String(i),
        )
        expect_true(
            acct.window_work <= acct.naive_work,
            "never worse, shape row " + String(i),
        )
        var want = KW_SAVES if r[5] > 0 else KW_NO_SAVE
        expect_eq(
            kw_shape_verdict(acct.naive_work, acct.window_work), want,
            "shape verdict, shape row " + String(i),
        )
    print("PASS: conservation + shape verdicts -- avoided + cost == naive and cost <= naive on all 9 shapes; SAVES wherever reuse > 0, NO_SAVE only at C = 0")


def test_kv_rewritten() raises:
    var rows = shape_rows()
    for i in range(len(rows)):
        var r = rows[i].copy()
        var acct = kw_account(
            LAYERS, HIDDEN, QW, KVW, FFN, HEADS, HD, r[3], r[5])
        expect_eq(acct.kv_rewritten_f16, r[10], "kv rewritten f16, shape row " + String(i))
        expect_eq(acct.kv_rewritten_int8, r[11], "kv rewritten int8, shape row " + String(i))
    print("PASS: KV rewritten -- suffix rewrite bytes exact at both precisions on all 9 shapes (EDIT_LATE 117,440,512 f16 / 60,555,264 int8; NO_CHANGE one token)")


def test_moved_line_honesty() raises:
    var old = doc_tokens()
    var new = moved_doc(100, 127)
    # The moved line's token sequence survives verbatim
    # at its new home (positions 8128..8192) -- and the
    # service still reuses nothing of it: reuse stops
    # at the divergence 6,400, far below 8,128, because
    # its position and causal ancestry changed.
    var same_seq = True
    for off in range(KW_TOKENS_PER_LINE):
        if new[8128 + off] != old[6400 + off]:
            same_seq = False
    expect_true(same_seq, "the moved line's tokens are verbatim at their new position")
    var reuse = kw_reusable(KW_DOC_TOKENS, KW_DOC_TOKENS, kw_first_divergence(old, new))
    expect_eq(reuse, 6400, "reuse stops at the earlier endpoint of the move")
    expect_true(reuse < 8128, "no row of the moved line is reused at its new position")
    print("PASS: moved-line honesty -- the moved line's tokens are verbatim at the new position yet none of its rows is reused (position + ancestry changed); reuse stops at 6,400")


def test_mix_verdict() raises:
    var rows = shape_rows()
    var ta = 0
    var tn = 0
    for i in range(len(rows)):
        var r = rows[i].copy()
        var acct = kw_account(
            LAYERS, HIDDEN, QW, KVW, FFN, HEADS, HD, r[3], r[5])
        ta += acct.avoided_work
        tn += acct.naive_work
    expect_eq(ta, 244430291861504, "mix avoided total")
    expect_eq(tn, 542238528634880, "mix naive total")
    expect_eq(kw_saved_ppm(ta, tn), 450780, "mix saved ppm")
    expect_eq(
        kw_service_verdict(ta, tn, True, True), KW_KEPT,
        "the service is KEPT under the pre-registered rule",
    )
    # The rule can fail, on each clause:
    expect_eq(kw_service_verdict(ta, tn, False, True), KW_NOT_KEPT, "a worse shape rejects")
    expect_eq(kw_service_verdict(ta, tn, True, False), KW_NOT_KEPT, "an inexact divergence rejects")
    expect_eq(
        kw_service_verdict(tn // 10, tn, True, True), KW_NOT_KEPT,
        "a mix saving under the bar rejects",
    )
    expect_eq(
        kw_service_verdict(tn // 4, tn, True, True), KW_KEPT,
        "boundary: exactly 250,000 ppm keeps",
    )
    print("PASS: mix + service verdict -- mix saves 450,780 ppm (avoided 244,430,291,861,504 of 542,238,528,634,880); KEPT; all three failure clauses and the boundary exercised")


def test_refusals() raises:
    var refused = 0
    try:
        _ = kw_shape_first_divergence(9, KW_DOC_LINES, KW_TOKENS_PER_LINE, 0, 0)
    except:
        refused += 1
    try:
        _ = kw_shape_first_divergence(KW_EDIT_IN_PLACE, KW_DOC_LINES, KW_TOKENS_PER_LINE, 128, 0)
    except:
        refused += 1
    try:
        _ = kw_shape_first_divergence(KW_MOVE, KW_DOC_LINES, KW_TOKENS_PER_LINE, 8, 128)
    except:
        refused += 1
    try:
        _ = kw_shape_new_len(KW_DELETE, 1, KW_TOKENS_PER_LINE)
    except:
        refused += 1
    try:
        _ = kw_reusable(0, 8192, 0)
    except:
        refused += 1
    try:
        _ = kw_reusable(8192, 8192, 8193)
    except:
        refused += 1
    try:
        _ = kw_account(LAYERS, HIDDEN, QW, KVW, FFN, HEADS, HD, 8192, 8192)
    except:
        refused += 1
    try:
        _ = kw_shape_verdict(100, 101)
    except:
        refused += 1
    try:
        _ = kw_service_verdict(200, 100, True, True)
    except:
        refused += 1
    expect_eq(refused, 9, "all refusals raised")
    print("PASS: refusals -- unknown shape, line/destination outside the document, one-line deletion, zero length, divergence outside both documents, reuse == new length, window above naive, avoided above naive (9/9)")


def main() raises:
    test_codes_geometry()
    test_gate_work_j094()
    test_divergence_exercise()
    test_reuse_cap()
    test_account_pins()
    test_conservation_and_verdicts()
    test_kv_rewritten()
    test_moved_line_honesty()
    test_mix_verdict()
    test_refusals()
    print("ALL PASS: kv window (10 groups)")
