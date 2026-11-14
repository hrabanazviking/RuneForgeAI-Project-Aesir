# A-127 — Coherence grading harness

Wave 15 (Coherence & quality, opener). Roadmap text:
"Coherence grading harness. Sampled generations
scored for coherence (the S-095 road pattern) for
the quant/backend cells where exactness is not
owed. Acceptance: harness scores filed for the IQ
matrix; scorer sanity-checked against known-good
and known-broken samples."

## What was built

- `aesir_engine/core/coherence_harness_a127.mojo`
  — the harness: the IQ matrix (the 9 IQ quants
  from A-114's `matrix_quants()` filtered by its
  `is_iq_quant`, both called, x A-114's 3 archs x
  A-109's 4 backends = 108 cells), every cell filed
  a score row with its A-115 obligation read by
  call from `policy_for_quant`, plus a pure
  byte-arithmetic text scorer (pre-registered rule
  S1-S8) and the labelled SYNTHETIC sanity fixture
  that sanity-checks the scorer.
- `aesir_engine/tests/test_coherence_harness_a127.
  mojo` — 15 E-MASTER cases (`coherence.harness_*`).
- `aesir_engine/tests/bench_coherence_harness_
  a127.mojo` — one-command driver; log
  `hidden_files/a127_battery.log`.

## The surface — what exists to score, honestly

The cells where exactness is not owed are exactly
the nine IQ families: the banked A-115 policy
files them COHERENCE_ONLY. Zero filed sampled-
generation records exist for any IQ cell in the
banked tree: A-114 filed the IQ rows FIXTURE_
LIMITED for teacher-forcing (the stories260K
fixture cannot satisfy the 256-value IQ super-
block), and A-115 states that no coherence evidence
exists in the banked records yet, so every IQ row
grades NOT_GRADED until such evidence is filed.
This harness therefore files a score row for every
one of the 108 IQ cells — verdict NOT_GRADED with
a named reason and score −1 (the absence stated,
never zero-filled into a fake perfect row) — and
proves the scorer itself on the synthetic sanity
fixture. The rows retire cell by cell as sampled-
generation records are filed (A-128's filed
samples are the first named source), re-verdicted
at A-135.

## The scorer (S-095 pattern)

A pure text scorer in the pattern of the tree's
own frozen coherence rubric f1-coherence-v1.1
(`data/armvegr/coherence_rubric_v1_1.json`, frozen
by H138): ≥3 complete sentences, no long repeated
runs, no garbage characters, predominantly real
words, on-topic. Per the S-095 road pattern the
expectations are set from the tree's own filed
behaviour on the same material, never against an
imagined ideal — and never by token-exactness:
ggml's own CPU vs CUDA IQ kernels disagree (S-029),
so token-exact parity for IQ is not proven by
construction and is never demanded. Metrics (all
filed as x1000 integers): words, sentences,
unique ratio, max repeated-word run, garbage
characters (control bytes + U+FFFD sequences),
alpha ratio, vowel-less long-word (gibberish)
ratio, topic hit; verdict codes are A-115's own
POL_COHERENCE_PASS / POL_COHERENCE_FAIL. An empty
or whitespace-only sample is refused, never graded.
Pre-registered order S1–S8: garbage → non-alpha →
prompt echo → too short → too few sentences →
repetition run / low diversity → gibberish words →
off-topic → COHERENCE_PASS.

## Filed harness (hidden_files/a127_battery.log)

- 108 CH_ROW lines, all NOT_GRADED: 81 non-cpu
  (BACKEND_NO_CPU_COMPARATOR — CPU vs CPU only, no
  device-execution evidence, accelerator-visible is
  not accelerator-run), 18 cpu non-llama
  (NO_FILED_RECORDS), 9 cpu llama
  (NO_FILED_GENERATIONS). Policy: coherence 108 /
  owed 0. Zero unexplained cells; digest
  3903033312964371200.
- Synthetic sanity fixture (SYNTHETIC in every
  line): total 9, pass 2, fail 7. Known-good:
  SYN_GOOD_HOSPITALITY (43 words, score 830) and
  SYN_GOOD_HARBOUR (49 words, score 800) both
  COHERENCE_PASS. Known-broken, each with its
  defect named: SYN_LOOP REPETITION_LOW_DIVERSITY,
  SYN_GARBAGE GARBAGE_CHARS, SYN_SHORT TOO_SHORT,
  SYN_PUNCT NON_ALPHA_CONTENT, SYN_OFFTOPIC
  OFF_TOPIC, SYN_ECHO PROMPT_ECHO, SYN_EMPTY
  EMPTY_SAMPLE_REFUSED. The fixture proves the
  scorer discriminates; it is not generation
  evidence for any matrix cell.

## Suite

E-MASTER solo (ps-checked before every launch):
run 1 (`hidden_files/a127_run_all.log`) 863 passed
/ 3 failed / 2 skipped / 868 total — the
pre-existing J-022, one in-slice witness defect
(the metrics test's hand-counted byte total, 52
for the true 51; fixed in-slice before filing),
and the named intermittent resilience.state_vault_
rejects_growth. Re-run (`hidden_files/a127_run_
all_rerun.log`): 864 passed / 2 failed / 2 skipped
/ 868 total — J-022 plus the same named
intermittent; all 15 coherence.harness_* cases
PASS in the re-run (14 of 15 in run 1, the fixed
witness case among them). Baseline on this base
was 850 / 1 / 2 / 853; run_all finish pin
853 → 868. The named intermittent clears solo:
`hidden_files/a127_vault_solo.log` files
resilience.state_vault_rejects_growth PASS 3/3 in
isolation (SOLO_EXIT 0 each). GREEN-TO-BASELINE.

## Integration points (named, honest)

A-115 and A-114 are BANKED and called (policy,
axes, verdict codes, digest). A-125 (team-25) and
A-126 (team-26) build in parallel; no dependency
taken on either. A-128 files the first real sampled
generations this harness can score; A-135
re-verdicts the IQ matrix. The harness executes
no model on this machine, opens no device, and
claims no accelerator execution.

## Capability Ledger

Section 26 entry Z13-P5-127 added; E-MASTER
registered count advanced 853 → 868.
