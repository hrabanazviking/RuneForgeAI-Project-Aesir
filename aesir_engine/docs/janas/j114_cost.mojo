"""J-114 cost driver: the vocabulary restriction's
per-token scan cost at module level, on deterministic
synthetic candidate sets (no model, no inference).

Per stated size (256 / 1024 / 4096 candidate texts
over the 6-word list "the cat sat on the mat" --
five admitted pieces and three refused pieces in a
fixed rotation), two scans over the same
TokenCandidate lists are timed:
  baseline   -- a greedy max-scan (no validity calls):
                what an unrestricted greedy step pays
                to look at the same candidates;
  restricted -- cg_apply_vocab_mask's validity scan
                (VocabRestrictor.is_token_valid per
                candidate, disallowed forced to -1e9).
Discipline (the tree's bench shape): one settle round
per size is executed and DISCARDED, then five measured
rounds; the filed number is the MEDIAN per-scan time
in nanoseconds, with min/max beside it. The admitted
counts are accumulated and printed so the scan cannot
be optimised away. These are module-level scan costs
on the machine that ran the driver -- MEASURED-
INDICATIVE, never a generation speed, never tok/s.
"""
from std.collections import InlineArray
from std.ffi import external_call
from core.constrained_generation import cg_apply_vocab_mask, cg_scan_account
from core.sampler import TokenCandidate
from core.vocab_restriction import VocabRestrictor, vr_parse_word_list


def monotonic_ns() raises -> Int:
    var ts = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), ts.unsafe_ptr()) != 0:
        raise Error("J114Cost: cannot observe monotonic clock")
    if ts[0] < 0 or ts[1] < 0 or ts[1] >= 1000000000:
        raise Error("J114Cost: invalid monotonic clock reading")
    return Int(ts[0]) * 1000000000 + Int(ts[1])


def _median(mut values: List[Int]) -> Int:
    for i in range(1, len(values)):
        var key = values[i]
        var j = i - 1
        while j >= 0 and values[j] > key:
            values[j + 1] = values[j]
            j -= 1
        values[j + 1] = key
    return values[len(values) // 2]


def _build(size: Int) -> List[TokenCandidate]:
    var pieces = List[String]()
    pieces.append(" the")
    pieces.append(" cat")
    pieces.append(" sat")
    pieces.append(" on")
    pieces.append(" mat")
    pieces.append(" dog")
    pieces.append(" bird")
    pieces.append(" xy")
    _ = pieces
    var out = List[TokenCandidate]()
    for i in range(size):
        out.append(TokenCandidate(i, Float32((i * 7) % 13) - Float32(6.0)))
    return out^


def _texts(size: Int) -> List[String]:
    var pieces = List[String]()
    pieces.append(" the")
    pieces.append(" cat")
    pieces.append(" sat")
    pieces.append(" on")
    pieces.append(" mat")
    pieces.append(" dog")
    pieces.append(" bird")
    pieces.append(" xy")
    var out = List[String]()
    for i in range(size):
        out.append(pieces[i % 8])
    return out^


def _baseline_scan(candidates: List[TokenCandidate]) -> Float32:
    var best = Float32(-1e30)
    for c in candidates:
        if c.logit > best:
            best = c.logit
    return best


def main() raises:
    var vocab = vr_parse_word_list("the cat sat on the mat")
    var sizes = List[Int]()
    sizes.append(256)
    sizes.append(1024)
    sizes.append(4096)
    print("J-114 restriction scan cost (module level, synthetic candidates)")
    for size in sizes:
        var texts = _texts(size)
        var account = cg_scan_account(texts)
        var restrictor = VocabRestrictor(vocab)
        var reps = 200000 // size
        if reps < 1:
            reps = 1
        # Settle round (discarded) for both scans.
        var settle_sink = Float32(0.0)
        var settle_admitted = 0
        for _ in range(reps):
            settle_sink += _baseline_scan(_build(size))
            var fresh = _build(size)
            settle_admitted += cg_apply_vocab_mask(fresh, texts, restrictor)
        _ = settle_sink
        _ = settle_admitted
        var base_times = List[Int]()
        var restr_times = List[Int]()
        var admitted_total = 0
        var base_sink = Float32(0.0)
        for _round in range(5):
            var start = monotonic_ns()
            for _ in range(reps):
                base_sink += _baseline_scan(_build(size))
            base_times.append((monotonic_ns() - start) // reps)
            start = monotonic_ns()
            for _ in range(reps):
                var fresh = _build(size)
                admitted_total += cg_apply_vocab_mask(
                    fresh, texts, restrictor)
            restr_times.append((monotonic_ns() - start) // reps)
        _ = base_sink
        var base_med = _median(base_times)
        var restr_med = _median(restr_times)
        var base_min = base_times[0]
        var restr_min = restr_times[0]
        var admitted_per_scan = admitted_total // 5 // reps
        var ratio_milli = 0
        if base_med > 0:
            ratio_milli = restr_med * 1000 // base_med
        print(
            "size=" + String(size)
            + " reps_per_round=" + String(reps)
            + " account_candidates=" + String(account.candidates_scanned)
            + " account_bytes=" + String(account.text_bytes)
            + " admitted_per_scan=" + String(admitted_per_scan)
            + " baseline_ns_per_scan_median=" + String(base_med)
            + " baseline_first=" + String(base_min)
            + " restricted_ns_per_scan_median=" + String(restr_med)
            + " restricted_first=" + String(restr_min)
            + " delta_ns=" + String(restr_med - base_med)
            + " ratio_milli=" + String(ratio_milli))
    print("COST DRIVER DONE")
