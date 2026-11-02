"""J-097 sliding-window service harness: the nine
pre-registered editor edit shapes over the stated
document (128 lines x 64 tokens = 8,192 tokens of
the ladder witness, Qwen2.5-Coder-7B: 28 layers,
hidden 3584, ffn 18944, 28 query heads, 4 kv heads,
head_dim 128, J-091/J-094), printed from the tree's
own modules (core/kv_window over core/prompt_read
and core/kv_persistence).

WINDOW lines print, per shape: the old and new
lengths, the predicted first divergence (the
module's shape function), the computed first
divergence (exact token comparison over the
concretely edited sequences, built below), the
reuse under the final-token cap, the naive full
re-read work (J-094), the avoided work (exactly
W(reuse), J-096 conservation), the window cost, the
saved ppm, the KV bytes the suffix rewrite writes
at f16 and at int8, and the per-shape verdict. The
MIX line prints the unweighted nine-shape totals
and their saved ppm; the SERVICE line prints the
pre-registered verdict (exact divergence exercise,
never worse, mix saved ppm >= 250,000).

Every number is exact arithmetic or a deterministic
exercise through the tree's own modules. NO WALL,
NO LIVE EDITOR AND NO LIVE BENEFIT IS MEASURED OR
PRINTED: no session wires this service today
(INTEGRATION_BLOCKED for any editor surface), this
VM is below its inference gate and purplelongship
is unreachable; the live legs are deferred to the
J-098 gate recipe in the J-097 doc (section 7),
and J-111 inherits them. Deterministic: identical
output on every run.
"""
from core.kv_window import (
    KW_APPEND,
    KW_DELETE,
    KW_DOC_LINES,
    KW_DOC_TOKENS,
    KW_EDIT_IN_PLACE,
    KW_INSERT,
    KW_MOVE,
    KW_NO_CHANGE,
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
    kw_shape_verdict_name,
)

comptime LAYERS = 28
comptime HEADS = 4
comptime HD = 128
comptime HIDDEN = 3584
comptime QW = 3584
comptime KVW = 512
comptime FFN = 18944


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


def main() raises:
    print(
        "WINDOWHEAD witness=coder-28x4x128 doc_lines=128 tokens_per_line=64"
        " doc_tokens=8192 min_saved_ppm=250000"
    )
    var names: List[String] = [
        "EDIT_LATE", "EDIT_EARLY", "EDIT_FIRST", "MOVE_LATE",
        "MOVE_EARLY", "INSERT_MID", "DELETE_MID", "APPEND", "NO_CHANGE",
    ]
    var shapes: List[Int] = [
        KW_EDIT_IN_PLACE, KW_EDIT_IN_PLACE, KW_EDIT_IN_PLACE, KW_MOVE,
        KW_MOVE, KW_INSERT, KW_DELETE, KW_APPEND, KW_NO_CHANGE,
    ]
    var aa: List[Int] = [96, 8, 0, 100, 8, 32, 32, 0, 0]
    var bb: List[Int] = [0, 0, 0, 127, 96, 0, 0, 0, 0]
    var old = doc_tokens()
    var ta = 0
    var tn = 0
    var exact = True
    var never_worse = True
    for i in range(9):
        var shape = shapes[i]
        var new = concrete_new(shape, aa[i], bb[i])
        var predicted = kw_shape_first_divergence(
            shape, KW_DOC_LINES, KW_TOKENS_PER_LINE, aa[i], bb[i])
        var computed = kw_first_divergence(old, new)
        if predicted != computed or len(new) != kw_shape_new_len(
            shape, KW_DOC_LINES, KW_TOKENS_PER_LINE
        ):
            exact = False
        var reuse = kw_reusable(KW_DOC_TOKENS, len(new), computed)
        var acct = kw_account(
            LAYERS, HIDDEN, QW, KVW, FFN, HEADS, HD, len(new), reuse)
        if acct.window_work > acct.naive_work:
            never_worse = False
        ta += acct.avoided_work
        tn += acct.naive_work
        print(
            "WINDOW shape=" + names[i]
            + " old_len=" + String(KW_DOC_TOKENS)
            + " new_len=" + String(len(new))
            + " div_predicted=" + String(predicted)
            + " div_computed=" + String(computed)
            + " reuse=" + String(reuse)
            + " naive=" + String(acct.naive_work)
            + " avoided=" + String(acct.avoided_work)
            + " cost=" + String(acct.window_work)
            + " saved_ppm=" + String(acct.saved_ppm)
            + " kv_rewritten_f16=" + String(acct.kv_rewritten_f16)
            + " kv_rewritten_int8=" + String(acct.kv_rewritten_int8)
            + " verdict=" + kw_shape_verdict_name(
                kw_shape_verdict(acct.naive_work, acct.window_work))
        )
    print(
        "MIX shapes=9 avoided=" + String(ta)
        + " naive=" + String(tn)
        + " saved_ppm=" + String(kw_saved_ppm(ta, tn))
        + " exact=" + String(exact)
        + " never_worse=" + String(never_worse)
    )
    print(
        "SERVICE verdict="
        + kw_verdict_name(kw_service_verdict(ta, tn, never_worse, exact))
        + " consumer=J-111_NOT_YET_BUILT"
    )
    print("WINDOWDONE live=NOT_PROVEN_DEFERRED_J098 walls=NOT_PROVEN j111_handoff=FILED")
