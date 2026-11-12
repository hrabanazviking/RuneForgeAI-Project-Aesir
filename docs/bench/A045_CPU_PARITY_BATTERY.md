# A-045 — CPU parity battery (Wave 5 closer)

Method (raw-oracle discipline): RAW prompt "One day, Timmy went to"
(tokenizer add_bos=True, no chat template — the A-004/A-030 standard
run) + the 32 pinned oracle greedy IDs. Oracle = pinned
stories260K.F16.gguf, sha256
57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3
(verified before the runs), run on this same CPU engine (CPU vs CPU).
Every candidate teacher-forces that exact 40-token sequence through
AesirEngine.teacher_forcing_logit_rows (KVCache.capture_logit_row sink:
the exact scaled/softcapped pre-sampling row); at each of the 32
continuation positions the oracle token is graded with
core/parity_battery rank (1 + #logits strictly greater) and logit gap
(top1 − target). Bands: rank 1 = faithful; rank ≤2 with gap <1.0 =
near-tie (faithful band); otherwise divergence, which requires a
verdict class below. Reusable driver:
aesir_engine/tests/bench_parity_battery_a045.mojo <oracle> <candidate>
<label>; grading arithmetic: aesir_engine/core/parity_battery.mojo.
Full per-position divergent rows + greedy generations:
hidden_files/a045_battery.log (sha256
216684ced747f50ee77ec0bc604ac19d7904fd0085c4724341e0d6e90d4d2268).

| Format | Faithful | Near-tie | Divergent | Worst rank | Max gap | Mean gap | Greedy match | Verdict |
|---|---|---|---|---|---|---|---|---|
| F16 | 32 | 0 | 0 | 1 | 0.0 | 0.0 | 32/32 | faithful (oracle self-check) |
| BF16 | 32 | 0 | 0 | 1 | 0.0 | 0.0 | 32/32 | faithful (real BF16 tensors, type 30) |
| Q8_0 | 32 | 0 | 0 | 1 | 0.0 | 0.0 | 32/32 | faithful |
| Q4_0 | 27 | 3 | 2 | 3 | 1.5703 | 0.0962 | 10/32 | divergence — quant noise (see ledger) |
| Q5_0 | 31 | 1 | 0 | 2 | 0.0156 | 0.0005 | 16/32 | faithful + near-tie; greedy drift is the near-tie flip compounding, TF rows all in band |
| Q2_K | 27 | 3 | 2 | 3 | 1.5703 | 0.0962 | 10/32 | FIXTURE ARTIFACT — tensor bytes byte-identical to Q4_0 (converter fallback); true Q2_K NOT measured. Road A-046 |
| Q3_K_M | 29 | 1 | 2 | 5 | 1.3828 | 0.0657 | 4/32 | divergence — quant noise, K-mix fixture (Q4_0/Q5_0/Q5_1 tensors) |
| Q4_K_M | 31 | 1 | 0 | 2 | 0.0938 | 0.0029 | 29/32 | faithful + near-tie, K-mix fixture |
| Q5_K_M | 32 | 0 | 0 | 1 | 0.0 | 0.0 | 32/32 | faithful, K-mix fixture |
| Q6_K | 32 | 0 | 0 | 1 | 0.0 | 0.0 | 32/32 | FIXTURE ARTIFACT — tensors are Q8_0 (type 8), bytes identical to Q8_0 file; true Q6_K NOT measured. Road A-046 |
| IQ1_S | — | — | — | — | — | — | — | DIVERGENCE — fixture limitation (below) |
| IQ1_M | — | — | — | — | — | — | — | DIVERGENCE — fixture limitation |
| IQ2_XXS | — | — | — | — | — | — | — | DIVERGENCE — fixture limitation |
| IQ2_XS | — | — | — | — | — | — | — | DIVERGENCE — fixture limitation |
| IQ2_S | — | — | — | — | — | — | — | DIVERGENCE — fixture limitation |
| IQ3_XXS | — | — | — | — | — | — | — | DIVERGENCE — fixture limitation |
| IQ3_S | — | — | — | — | — | — | — | DIVERGENCE — fixture limitation |
| IQ4_NL | — | — | — | — | — | — | — | DIVERGENCE — fixture limitation |
| IQ4_XS | — | — | — | — | — | — | — | DIVERGENCE — fixture limitation |

IQ fixture limitation (verdict class, applies to all 9 IQ rows): the
IQ-labelled files collapse to TWO distinct tensor-data payloads
(sha-group 97467401a9c2: IQ1_S/IQ1_M/IQ2_XXS/IQ2_XS; 20eb8c11f9ee:
IQ2_S/IQ3_XXS/IQ3_S/IQ4_NL/IQ4_XS), and their 2-D tensors are
IQ4_NL-typed (ggml type 20) converter fallbacks, not the labelled
formats. Worse, stories260K inner dimensions are 64/32 while the
engine's IQ GEMM requires complete 256-value super-blocks
(core/compute.mojo gemm_iq: A.cols % 256 == 0), so every IQ run stops
at "gemm_iq4_nl: invalid shape or incomplete quantization block" —
IQ end-to-end parity is impossible on this fixture BY CONSTRUCTION,
not an engine dequant defect (the E-MASTER IQ known-value / SIMD
parity cases pass in the A-045 suite). True IQ end-to-end rows need a
≥256-wide fixture: road A-046 (quant census), noted as immediate next
work in team-03 CAMPAIGN_STATE.md. IQ is graded on rank/gap/coherence
when such a fixture exists — never token-exactness.

Prompt-internal positions (7, informational only): even the F16
oracle run grades only 5/7 faithful+near-tie there — the prompt is
context to condition on, not oracle continuation; prompt-boundary
effects are a comparator-artifact class and are excluded from the
verdicts above. Oracle self-check: oracle_rank1 = 32/32 on
continuation positions for every candidate run (comparator stable).
