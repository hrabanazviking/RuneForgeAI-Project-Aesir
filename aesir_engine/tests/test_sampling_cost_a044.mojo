# tests/test_sampling_cost_a044.mojo
# A-044: sampling cost proof -- correctness parity for the sampler
# hot-path fixes (SIMD sanitized max/argmax, stable merge sort,
# quickselect top-k). Every changed routine is checked against an
# independent in-test reference implementing the ORIGINAL scalar
# algorithms, on deterministic inputs with heavy ties, non-finite
# lanes, tail lengths, and large candidate counts. The cost numbers
# themselves are measured by tests/bench_sampling_a044.mojo and the
# A-036 phase bench, and filed in hidden_files/A044_LEDGER.md.
from std.memory import Pointer, bitcast, dealloc
from std.memory.alloc import alloc, Layout
from core.compute import MutUntrackedOrigin
from core.mimir_well import f16, f32
from core.sampler import (
    RuneRNG,
    TokenCandidate,
    _simd_logits_max,
    apply_top_k,
    sample_token_from_logits,
    sanitize_logit,
    sort_candidates_descending,
)


def _pattern_value(i: Int) -> Float32:
    var h = (i * 2654435761) % 1000
    return Float32(h) / Float32(125.0) - Float32(4.0)


def _ref_insertion_sort(mut c: List[TokenCandidate]):
    # The pre-A-044 sort, verbatim algorithm: stable insertion sort.
    var n = len(c)
    for i in range(1, n):
        var key_id = c[i].id
        var key_logit = c[i].logit
        var j = i - 1
        while j >= 0 and c[j].logit < key_logit:
            c[j + 1].id = c[j].id
            c[j + 1].logit = c[j].logit
            j -= 1
        c[j + 1].id = key_id
        c[j + 1].logit = key_logit


def _check_same(a: List[TokenCandidate], b: List[TokenCandidate], what: String) raises:
    if len(a) != len(b):
        raise Error("A044 length mismatch in " + what)
    for i in range(len(a)):
        if a[i].id != b[i].id or a[i].logit != b[i].logit:
            raise Error("A044 element mismatch in " + what + " at " + String(i))


def test_sampling_cost_simd_max_parity() raises:
    # _simd_logits_max must equal the scalar sanitized max on every
    # buffer: pattern data, a non-multiple-of-16 tail, and injected
    # NaN / +Inf / -Inf lanes (which sanitize to -1e9).
    var vocabs = List[Int]()
    vocabs.append(1); vocabs.append(5); vocabs.append(16)
    vocabs.append(17); vocabs.append(512); vocabs.append(1030)
    for v_idx in range(len(vocabs)):
        var vocab = vocabs[v_idx]
        var allocation = alloc(Layout[Scalar[f16]](count=vocab))
        var ptr = allocation.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
        for i in range(vocab):
            ptr.unsafe_store(i, Scalar[f16](_pattern_value(i)))
        var expected = sanitize_logit(ptr.unsafe_load(0).cast[f32]())
        for i in range(1, vocab):
            var v = sanitize_logit(ptr.unsafe_load(i).cast[f32]())
            if v > expected:
                expected = v
        if _simd_logits_max(ptr, vocab) != expected:
            dealloc(allocation^)
            raise Error("A044 SIMD max != scalar max at vocab " + String(vocab))
        if vocab >= 17:
            ptr.unsafe_store(3, bitcast[DType.float16](UInt16(0x7c00)))
            ptr.unsafe_store(5, bitcast[DType.float16](UInt16(0x7e00)))
            ptr.unsafe_store(7, bitcast[DType.float16](UInt16(0xfc00)))
            var expected2 = sanitize_logit(ptr.unsafe_load(0).cast[f32]())
            for i in range(1, vocab):
                var v2 = sanitize_logit(ptr.unsafe_load(i).cast[f32]())
                if v2 > expected2:
                    expected2 = v2
            if _simd_logits_max(ptr, vocab) != expected2:
                dealloc(allocation^)
                raise Error("A044 SIMD max != scalar max with non-finite lanes")
        dealloc(allocation^)
    print("A044 SIMD max parity (tails, non-finite): PASS")


def test_sampling_cost_greedy_argmax_parity() raises:
    # Greedy sample_token_from_logits must equal a brute-force scalar
    # reference (sanitize, suppress to -1e9, lowest-id tie break) on
    # a 1030-wide buffer: unique maxima at head/middle/tail, a tie,
    # non-finite lanes, and the suppressed-maximum path.
    var vocab = 1030
    var allocation = alloc(Layout[Scalar[f16]](count=vocab))
    var ptr = allocation.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    for i in range(vocab):
        ptr.unsafe_store(i, Scalar[f16](_pattern_value(i)))
    var suppress_none = List[Int]()
    var peaks = List[Int]()
    peaks.append(0); peaks.append(37); peaks.append(511); peaks.append(1029)
    for p_idx in range(len(peaks)):
        var peak = peaks[p_idx]
        for i in range(vocab):
            ptr.unsafe_store(i, Scalar[f16](_pattern_value(i)))
        ptr.unsafe_store(peak, Scalar[f16](10.0))
        var rng = RuneRNG(42)
        var got = sample_token_from_logits(ptr, vocab, Float32(0.0), 40, Float32(1.0), Float32(1.0), List[Int](), rng, suppress_tokens=suppress_none)
        if got != peak:
            dealloc(allocation^)
            raise Error("A044 greedy unique max wrong at peak " + String(peak))
    # Tie at 100 and 900: lowest id wins.
    ptr.unsafe_store(100, Scalar[f16](10.0))
    ptr.unsafe_store(900, Scalar[f16](10.0))
    ptr.unsafe_store(1029, Scalar[f16](-4.0))
    var rng_tie = RuneRNG(42)
    var tied = sample_token_from_logits(ptr, vocab, Float32(0.0), 40, Float32(1.0), Float32(1.0), List[Int](), rng_tie, suppress_tokens=suppress_none)
    if tied != 100:
        dealloc(allocation^)
        raise Error("A044 greedy tie must choose lowest id")
    # +Inf at index 3 sanitizes to -1e9 and must NOT win over the
    # finite 10.0 maxima; suppressing 100 then leaves 900.
    ptr.unsafe_store(3, bitcast[DType.float16](UInt16(0x7c00)))
    var rng_inf = RuneRNG(42)
    var after_inf = sample_token_from_logits(ptr, vocab, Float32(0.0), 40, Float32(1.0), Float32(1.0), List[Int](), rng_inf, suppress_tokens=suppress_none)
    if after_inf != 100:
        dealloc(allocation^)
        raise Error("A044 greedy must ignore sanitized +Inf lane")
    var suppress = List[Int]()
    suppress.append(100)
    var rng_sup = RuneRNG(42)
    var after_sup = sample_token_from_logits(ptr, vocab, Float32(0.0), 40, Float32(1.0), Float32(1.0), List[Int](), rng_sup, suppress_tokens=suppress)
    dealloc(allocation^)
    if after_sup != 900:
        raise Error("A044 greedy suppressed maximum must fall to next")
    print("A044 greedy argmax parity (ties, tail, non-finite, suppress): PASS")


def test_sampling_cost_sort_stable_reference() raises:
    # sort_candidates_descending must reproduce the old insertion
    # sort element-for-element at n above and below the merge-sort
    # threshold, with heavy ties (1000 pattern levels over n items).
    var sizes = List[Int]()
    sizes.append(2); sizes.append(23); sizes.append(24); sizes.append(25)
    sizes.append(100); sizes.append(500); sizes.append(2000)
    for s_idx in range(len(sizes)):
        var n = sizes[s_idx]
        var a = List[TokenCandidate]()
        var b = List[TokenCandidate]()
        for i in range(n):
            a.append(TokenCandidate(i, _pattern_value(i)))
            b.append(TokenCandidate(i, _pattern_value(i)))
        sort_candidates_descending(a)
        _ref_insertion_sort(b)
        _check_same(a, b, String("sort n=") + String(n))
    print("A044 stable sort == insertion-sort reference: PASS")


def test_sampling_cost_topk_reference() raises:
    # apply_top_k must equal the first k of the full stable sort for
    # every k pattern, including dense tie cutoffs at the boundary.
    var ns = List[Int]()
    ns.append(10); ns.append(40); ns.append(257); ns.append(1000)
    var ks = List[Int]()
    ks.append(1); ks.append(3); ks.append(40)
    for n_idx in range(len(ns)):
        var n = ns[n_idx]
        for k_idx in range(len(ks)):
            var k = ks[k_idx]
            if k >= n:
                continue
            var a = List[TokenCandidate]()
            var b = List[TokenCandidate]()
            for i in range(n):
                a.append(TokenCandidate(i, _pattern_value(i * 7)))
                b.append(TokenCandidate(i, _pattern_value(i * 7)))
            apply_top_k(a, k)
            _ref_insertion_sort(b)
            if len(a) != k:
                raise Error("A044 top_k length wrong")
            for i in range(k):
                if a[i].id != b[i].id or a[i].logit != b[i].logit:
                    raise Error("A044 top_k mismatch vs full-sort reference")
    print("A044 top_k == full stable sort prefix: PASS")


def test_sampling_cost_stochastic_determinism_large() raises:
    # Stochastic path at vocab 5000 (candidate window = whole vocab
    # on pattern data): same seed reproduces the same 128-token
    # sequence exactly after the sort/top-k changes; a different
    # seed diverges; every token stays in vocabulary.
    var vocab = 5000
    var allocation = alloc(Layout[Scalar[f16]](count=vocab))
    var ptr = allocation.unsafe_ptr().unsafe_origin_cast[MutUntrackedOrigin]()
    for i in range(vocab):
        ptr.unsafe_store(i, Scalar[f16](_pattern_value(i)))
    var seq_a = List[Int]()
    var rng_a = RuneRNG(777)
    for _ in range(128):
        seq_a.append(sample_token_from_logits(ptr, vocab, Float32(0.8), 40, Float32(0.95), Float32(1.0), List[Int](), rng_a))
    var rng_b = RuneRNG(777)
    for t in range(128):
        var tok = sample_token_from_logits(ptr, vocab, Float32(0.8), 40, Float32(0.95), Float32(1.0), List[Int](), rng_b)
        if tok != seq_a[t] or tok < 0 or tok >= vocab:
            dealloc(allocation^)
            raise Error("A044 stochastic sequence not deterministic at " + String(t))
    var rng_c = RuneRNG(778)
    var differs = False
    for t in range(128):
        var tok_c = sample_token_from_logits(ptr, vocab, Float32(0.8), 40, Float32(0.95), Float32(1.0), List[Int](), rng_c)
        if tok_c != seq_a[t]:
            differs = True
    dealloc(allocation^)
    if not differs:
        raise Error("A044 stochastic sequences must diverge across seeds")
    print("A044 stochastic determinism at vocab 5000: PASS")
