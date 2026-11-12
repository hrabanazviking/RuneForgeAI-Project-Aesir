# A-044 -- Sampling cost proof (Z13, purpleraider)

Slice A-044, team-06, branch yrsa/aesir-team-06, base d8c57f2a
(A-042 banked, 42 of 216). Roadmap: "CPU sampling measured per
token. Acceptance: either <1% of token time proven, or the hotspot
is fixed and re-measured." Cites A-037 census row C-006
(core::sampler::sample_token_from_logits, 2.56% self-time).

## Verdict

Both halves of the acceptance are met, in order:

1. Pre-fix, sampling was NOT <1%: the engine's own disjoint phase
   accounting (A-036 hooks) measured sample time at a median
   4.14% of generation time on the standard run, and the direct
   microbench reproduced the census scale (greedy 2,420 ns/call at
   the fixture vocab). The hotspot was therefore fixed in-slice.
2. Post-fix, the same measurements prove sampling at a median
   0.26% of generation time (<1%) on the standard run, with every
   correctness sink and the 32-token greedy oracle unchanged.

## Method

- Real token time: A-036 phase bench (tests/bench_phase_timing_
  a036.mojo) on the pinned stories260K.F16.gguf fixture (sha256
  57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3),
  facade standard run, raw prompt "One day, Timmy went to", 8
  prefill + 32 greedy decode, oracle-exact 32 IDs every rep
  (A-004/A-030 pattern, CPU vs CPU, raw-oracle discipline).
  Phases are disjoint by A-036 construction: sample_ns is the
  sampler's own accumulated time, subtracted from the spans that
  contain it, so share = sample / (prefill + decode + sample) is
  an honest per-token sampling share of generation time.
- Direct cost: tests/bench_sampling_a044.mojo batch-times
  sample_token_from_logits with the timer OUTSIDE the loop (two
  clock reads per trial, amortised over 5-20,000 calls), at vocab
  512 (the fixture vocab, token_embd rows) and vocab 32,000
  (realistic LLM scale, labelled synthetic). Deterministic F16
  logits, spread [-4, 4] with a unique peak at index 37; every
  stochastic candidate falls inside the sampler's 15.0 window, so
  candidate count == vocab (worst case, labelled as such).
  Sinks (sums of returned ids) must match pre/post exactly.
- Machine: purpleraider, CPU path only; gfx1151 is a compile
  target only. No accelerator execution is claimed.

## Real engine: sampling share of generation time

| Run | Pre-fix sample_ns | Pre-fix share | Post-fix sample_ns | Post-fix share |
|---|---|---|---|---|
| rep 0 | 79,704 | 4.02% | 5,549 | 0.29% |
| rep 1 | 79,482 | 4.14% | 4,849 | 0.26% |
| rep 2 | 79,480 | 4.16% | 4,394 | 0.24% |
| median | 79,482 | 4.14% | 4,849 | 0.26% |

Sample time per standard run fell 16.4x (median). Both runs:
A036_BENCH PASS, all 32 greedy IDs oracle-exact. Evidence:
hidden_files/a044_pre_phase.log, hidden_files/a044_post_phase.log.
Note: post-fix sample_ns still contains the A-036 hook overhead
(two clock reads, each allocating, per sampler call); the true
sampler work per greedy call at this vocab is 59 ns (microbench).

## Direct sampler cost per call (median of 3 trials, ns)

| Config | Vocab | Pre-fix | Post-fix | Speedup | Sink pre == post |
|---|---|---|---|---|---|
| greedy | 512 | 2,420 | 59 | 41.0x | 740,000 == 740,000 |
| greedy | 32,000 | 154,032 | 3,315 | 46.5x | 74,000 == 74,000 |
| stoch temp 0.8, top_k 40, top_p 0.95 | 512 | 26,128 | 9,455 | 2.8x | 74,000 == 74,000 |
| stoch temp 0.8, top_k 40, top_p 0.95 | 32,000 | 63,733,161 | 478,755 | 133.1x | 185 == 185 |
| stoch untruncated temp 1.0 | 512 | 6,100 | 3,838 | 1.6x | 131,007 == 131,007 |
| stoch untruncated temp 1.0 | 32,000 | 374,643 | 232,197 | 1.6x | 2,677,916 == 2,677,916 |

Evidence: hidden_files/a044_pre_micro.log,
hidden_files/a044_post_micro.log. Token-time scale for context:
A-030 pure decode median 8,745.9 tok/s (~114 us/token) and A-037
aggregate 8,141.9 tok/s on this fixture -- so the pre-fix
stochastic top-k cost at a realistic 32k vocab (63.7 ms) was
hundreds of whole token times, and even the pre-fix greedy scan
at 32k (154 us) exceeded one small-model token time. Post-fix
greedy at 32k is 3.3 us.

## The hotspots and the fixes (all in core/sampler.mojo)

1. Greedy argmax was a scalar per-element scan with a per-element
   suppress-list loop: 4.8 ns/element. Fix: width-16 SIMD sanitized
   max (_simd_logits_max) + first-index scan (_simd_argmax_first)
   on the no-suppress path. Exactness is by construction: F16 lanes
   are finite iff |x| <= 65,504; the pass also reduces min and sum,
   so any non-finite lane (or a NaN-poisoned sum) is detected and
   the function recomputes with the ORIGINAL scalar sanitize loop,
   bit-identical for every input. Ties keep the lowest id (first
   raw match on the all-finite path). The suppress path is the
   original scalar loop, unchanged.
2. sort_candidates_descending was an O(n^2) insertion sort, and
   apply_top_k fully sorted every candidate just to keep top_k:
   at 32k candidates that one sort was ~63 ms per token. Fix:
   stable merge sort (O(n log n), same stable result: ties keep
   original order, merge takes the left run on >=), an O(n)
   already-descending fast path (the re-sorts in apply_top_p /
   apply_min_p after a sort now cost one scan), the original
   insertion sort kept for n <= 24, and quickselect top-k: the
   winning set is selected in average O(n) under the exact stable
   total order (logit descending, original position ascending),
   collected in original order, and only the kept k are sorted.
   The result is element-for-element the first k of the old full
   stable sort -- proven against an in-test insertion-sort
   reference, including dense tie cutoffs (suite cases
   sampling_cost.sort_stable_reference and
   sampling_cost.topk_reference), and the 32k stochastic bench
   sink is unchanged (185).
3. The stochastic path's max scan reuses _simd_logits_max.

Remaining known cost, honestly stated: the candidate-collection
pass and the untruncated softmax walk are still scalar O(vocab)
(232 us/call at 32k untruncated, worst-case flat window). They are
linear, not the hotspot this slice was charged with; the <1%
proof above is for the engine's standard (greedy) run, and the
stochastic numbers are filed per-config, not hidden inside it.

## Correctness discipline

- Raw-oracle: the standard run's 32 greedy IDs are checked exact
  against the pinned llama.cpp oracle (CPU vs CPU) in both the
  pre- and post-fix phase benches -- PASS both times. No template-
  rendered comparator was used.
- Sampler parity: bench sinks identical pre/post for all six
  configurations (same seeds, same returned-id sums); five new
  E-MASTER cases (sampling_cost.*) check the changed routines
  against independent in-test references of the original
  algorithms: SIMD max parity (tails, NaN/+Inf/-Inf), greedy
  argmax parity (unique maxima at head/middle/tail, lowest-id
  tie, sanitized +Inf, suppressed maximum), stable sort ==
  insertion-sort reference at 7 sizes, top-k == full-sort prefix
  at 12 (n, k) pairs, and seeded stochastic determinism at
  vocab 5000 over 128 draws.
