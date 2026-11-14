# A-126 — Special-token handling

> "Special-token handling. EOS/BOS/pad behaviour per family across backends.
> Acceptance: battery judged; stop-reason correctness included."
> (docs/AESIR_Z13_MASSIVE_ROADMAP.md, Wave 14 closer)

## What was built

- `aesir_engine/core/special_token_battery_a126.mojo` — the per-family
  special-token battery: 5 families (llama, qwen2, qwen3, gemma4, mistral3)
  × 4 Z13 backends (A-109 `tf_harness_backends` by call) = 20 rows, every row
  with a verdict AND the A-115 policy obligation of Q4_K_M (read from
  `core/exactness_policy.mojo` by call), zero unexplained.
- `aesir_engine/tests/test_special_token_battery_a126.mojo` — 13 E-MASTER
  cases (`special_token_*`), including the cross-verification of the battery's
  engine stop-rule transcription against the REAL `generation_stop_reason`
  from `aesir.mojo`.
- `aesir_engine/tests/bench_special_token_battery_a126.mojo` — one-command
  driver; filed run at `hidden_files/a126_battery.log` (MOJO_EXIT=0).

## The surface — what exists to judge, honestly

No filed record anywhere in the tree graded special-token or stop behaviour
before this slice (the A-109/A-114/A-115/A-118–A-120 surfaces contain zero
EOS/BOS/pad grades). The battery files its specs from the banked records:

- **Dense GQA profiles, called not re-typed:** llama eos 128001 / turn 128009 /
  add_bos True; qwen2 + qwen3 eos = turn 151645 (`<|im_end|>`) / add_bos False.
- **Native tokenizer validations:** llama BOS 128000 `<|begin_of_text|>`;
  qwen BOS 151643 `<|endoftext|>` (native surface). On the GGUF/RuneWeaver
  surface, Qwen's BOS is metadata-carried and never prepended
  (`add_bos_token` forced False for qwen2/qwen3/qwen35 in `loader/gguf.mojo`).
- **Gemma 4:** ids are GGUF-metadata-carried in code (the filed fixture pins
  explicit GGUF BOS = 2 for unsloth/gemma-4-E4B-it; no EOS id is pinned
  anywhere), so the spec files the `<bos>`/`<eos>` spellings and the
  SB_FROM_METADATA sentinel; its session stop is
  `token == vocabulary.eos_token_id OR token == control("<eos>")`.
- **Mistral3:** an A-114 matrix arch with NO tokenizer surface anywhere —
  no spec can be filed.
- **PAD:** no pad surface exists in the engine at all — no pad field on any
  tokenizer, no `tokenizer.ggml.padding_token_id` key in the GGUF parser, no
  pad masking in any session. Every family files pad −1, NO_PAD_SURFACE; the
  absence IS the filed behaviour.
- **Stop reasons** are plain strings, no enum: CPU `generation_stop_reason`
  files eos → stop_token → length → context_exhausted under a SINGLE eos id;
  `GenerationControl` files cancelled/timeout; the CUDA sessions file the
  richer set and stop on both terminators where a family has two.

## Judging — pre-registered rule S1–S3 (module header)

- S1: non-cpu backend → NOT_GRADED / BACKEND_NO_CPU_COMPARATOR (CPU vs CPU
  only; accelerator-visible is not accelerator-run).
- S2: cpu + no filed surface (mistral3) → NOT_GRADED / NO_FILED_SURFACE.
- S3: cpu rows execute the checks: (a) the BOS rule on the banked RuneWeaver
  (proxy ids; the rule executes, not the ids) — encode of the empty prompt
  yields [bos] iff the family's filed add_bos flag is set; (b) EOS stop;
  (c) turn stop — the engine's filed stop set must contain the family's turn
  terminator; (d) pad filed as data on every row.
- Stop-reason correctness is judged on a 6-scenario grid per family
  (EOS_TOKEN, TURN_TOKEN, STOP_TOKEN, LENGTH, CONTEXT, CONTINUE) under the
  filed precedence, spec stop-set vs engine single-eos transcription.

## The genuine divergence

**llama cpu row: DIVERGENT / STOP_SET_INCOMPLETE.** The family's filed stop
set is {128001, 128009} (dense profile + CUDA session), but the CPU generate
path stops on the single metadata eos alone. The filed A-104 GGUF record
files `tokenizer.ggml.eos_token_id = 128009` for Meta-Llama-3.1-8B-Instruct,
so on the tree's own reference model a generated `<|end_of_text|>` (128001)
runs on; with eos metadata 128001 the mirror case holds for `<|eot_id|>`
(suite-proven against the real function both ways). This is a genuine ENGINE
row: **A-116 is the named tool for it, and its Wave-14 in-anger condition IS
met by this row** — the first Wave-14 battery to file one. The fix surface is
named (a second stop id on the tokenizer surface, populated from the
profile/GGUF record, checked beside `eos_token_id` in the generate loop and
in `generation_stop_reason`) and recorded as the immediate next work in the
team's CAMPAIGN_STATE.md; the battery files the verdict and does not
silently re-wire the generate path mid-battery.

## Filed battery

`hidden_files/a126_battery.log`, MOJO_EXIT=0, digest 17053524392034059918:
total 20 — FAITHFUL 3 (qwen2, qwen3, gemma4 cpu), DIVERGENT 1 (llama cpu,
STOP_SET_INCOMPLETE), NOT_GRADED 16 (15 BACKEND_NO_CPU_COMPARATOR + 1
NO_FILED_SURFACE); policy owed 20 / coherence 0. Teacher-forcing account
filed, not hidden: total 20, graded 0, not_graded 20 (NO_FILED_RECORDS — no
TF record grades special tokens; the near-tie band is not invoked).
SYNTHETIC fixture (labelled SYNTHETIC in every line): total 5, faithful 1
(SYN_OK), divergent 3 (SYN_EOS_ONLY / STOP_SET_INCOMPLETE,
SYN_TURN_AS_TEXT / TURN_TOKEN_NOT_A_STOP, SYN_PAD_AS_EOS /
PAD_TOKEN_AS_STOP), artifact 1 (SYN_MISMATCH / BACKEND_MISMATCH).

Suite: see hidden_files/A126_LEDGER.md for the filed E-MASTER runs.
