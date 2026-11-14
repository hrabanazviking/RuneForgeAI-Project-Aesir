# A-125 — Wrong-Tokenizer Adversarial

Wave 14, Architecture breadth. Roadmap text: "Wrong-tokenizer adversarial.
Mismatched tokenizer/model pairs must fail loudly at load. Acceptance:
adversarial set passes (all rejected with named errors, none silently
generate)."

## What was built

`aesir_engine/core/wrong_tokenizer_a125.mojo` files a 14-case adversarial
set of tokenizer presentations against one reference (model-side)
tokenizer, judged by the banked J-074 comparison
(`core/cross_model_pairing.mojo` `compare_tokenizers`, called — never
re-implemented): same tokenizer model string, same vocabulary length,
every token string equal at every index, merges equal at every index where
both sides carry merges (a one-sided merges section is itself a mismatch),
equal BOS / EOS ids, and the comparison must actually have been run
(verified, not assumed — J-074 rule 4).

## Pre-registered verdict rule (W1–W9, stated in the module header first)

W1 not verified → REFUSED / TOKENIZER_UNVERIFIED · W2 empty vocab →
REFUSED / EMPTY_VOCAB · W3 model string differs → REFUSED /
TOKENIZER_MODEL_MISMATCH · W4 vocab length differs → REFUSED /
VOCAB_LENGTH_MISMATCH · W5 any token differs → REFUSED / TOKEN_DIVERGENCE
(first index carried) · W6 merges one-sided → REFUSED / MERGES_ONE_SIDED ·
W7 any merge differs → REFUSED / MERGE_DIVERGENCE · W8 BOS differs →
REFUSED / BOS_MISMATCH · W9 EOS differs → REFUSED / EOS_MISMATCH ·
otherwise the banked `identical()` must hold → ADMITTED / MATCH_VERIFIED.
Any residual divergence files REFUSED / UNKNOWN_DIVERGENCE and counts as
unexplained; the filed battery has zero.

## Filed battery (hidden_files/a125_battery.log, MOJO_EXIT=0)

Digest **14975126816450906016**. Total 14: **admitted 2, refused 12,
silent 0, unexplained 0**.

| Case | Verdict | Reason | Witness |
|---|---|---|---|
| control_identical | ADMITTED | MATCH_VERIFIED | 12 tokens compared, 0 mismatches |
| control_both_absent_merges | ADMITTED | MATCH_VERIFIED | SPM form: both sides merges-free |
| unverified | REFUSED | TOKENIZER_UNVERIFIED | identical tables, comparison never run |
| empty_vocab | REFUSED | EMPTY_VOCAB | diverges at 0, 12 mismatches |
| model_string_mismatch | REFUSED | TOKENIZER_MODEL_MISMATCH | llama-bpe vs qwen-bpe |
| vocab_truncated | REFUSED | VOCAB_LENGTH_MISMATCH | diverges at 10 (shorter length) |
| vocab_extended | REFUSED | VOCAB_LENGTH_MISMATCH | diverges at 12 (reference length) |
| token_content_divergence | REFUSED | TOKEN_DIVERGENCE | index 5, exactly 1 mismatch |
| token_order_permutation | REFUSED | TOKEN_DIVERGENCE | index 3, exactly 2 mismatches — a vocab is a table, not a bag |
| special_token_text_divergence | REFUSED | TOKEN_DIVERGENCE | index 0 (`<bos>` → `<s>`) |
| merges_divergence | REFUSED | MERGE_DIVERGENCE | merge index 1, exactly 1 mismatch |
| merges_one_sided | REFUSED | MERGES_ONE_SIDED | candidate carries no merges, reference does |
| bos_mismatch | REFUSED | BOS_MISMATCH | BOS 0 vs 2 |
| eos_mismatch | REFUSED | EOS_MISMATCH | EOS 1 vs 2 |

## No silent grading

A refused pair is never graded: every row carries `graded=-1` — no
teacher-forcing rank, no logit gap, no faithfulness verdict is filed for
any row of this battery. Admission is a gate, not a grade (J-074).
Grading discipline for admitted pairs stays in A-109..A-115 (RAW prompts,
CPU vs CPU, near-tie band, IQ coherence-only, comparator artifacts a
verdict class); none of it is exercised or claimed here.

## Honest limits

The tables are SYNTHETIC fixtures (12-token vocabulary, 4 merges, labelled
`fixture=SYNTHETIC` on every row): no real model file is opened, no
forward is executed, no generation is attempted, and no accelerator claim
is made. What is proven is the load-time gate over the banked comparison.
A real-file leg (sha-pinned GGUF pairs through the host contract of J-074)
retires this limit; it is not claimed here.

## Suite

15 new E-MASTER cases (`wtok.battery_*`), run_all pin 827 → 842. Suite
counts are filed in CAMPAIGN_STATE.md and hidden_files/A125_LEDGER.md from
the run logs.
