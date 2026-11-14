# QC-4 — llama.cpp cross-check of the QC-3a compressed model (2026-11-14)

Worker slice on worktree /home/volmarr/aesir-qc-4, branch yrsa/qc-4,
base 7e61f79a (= origin/yrsa/hip-serve tip, re-read by ls-remote at
start; main untouched at 31ab9363). Deliverable definition:
QC-0-PLAN.md section 6 (QC-4) as scoped by the commission's four
numbered items. Method: ONE worker running the six Forge roles
sequentially (recon -> spec -> build -> proof -> regressions ->
bank). No sub-agents were spawned (depth limit), per the commission.

Machine state: purpleraider up 5h38 at start (NOT freshly booted),
MemAvailable ~23 GB of 121 GB at start (heavy resident usage on the
box). The sibling Q35-6 worker was ACTIVE in
/home/volmarr/aesir-q35-6 throughout; its tree was never touched.
CONTENTION IS THEREFORE PRESENT and is recorded honestly: every
number below is a correctness number (byte identity, rank/gap,
token identity), never a timing (llama-cli prints t/s lines into
its logs; none are claimed). All builds/runs ran as systemd user
scopes fenced MemoryHigh=24G / MemoryMax=32G. No aesir-gate /
Ollama / Voxta processes were observed at recon; services stayed
down per Volmarr's orders, untouched.

Referee: llama.cpp at ~/llama.cpp-build, upstream commit
a956a852c9c8bc1fb07206364838ddef299178c0 (llama-cli reports
"version: 1.0.0-dev (build 1, commit a956a85)", qc-4-llama-
version.log), native build, CPU-only runs (n_gpu_layers=0 in the
grade tool; llama-cli default device on this box is CPU here).
U-QC1 is thereby settled for this box: the build tree exists and
was used as-is; nothing in llama.cpp was modified (it is the
independent referee). The teacher-forcing tool is qc4grade.cpp
(new, this folder), built on the Q35-3b q35grade pattern
(~/llama.cpp-build/q35grade/q35grade.cpp) and extended to dump
FULL logit rows (vocab 512, so rows are tiny) and to run the
greedy witness on all six prompts.

## 1. Determinism — the emitted file reproduces byte-identically

`aesir quantize` from THIS merged tree on the pinned source
fixture (sha256 57a81ed1...09da1a0e, re-verified this run,
qc-4-source-sha.log) emitted:

- sha256 **5d4df894e4ed0d16f84d94c0a2a7524a4915123fe96148dc0e41b7bc1a6d77b7**,
  **379,152 B** (qc-4-emitted-sha.log, qc-4-quantize-cli.log) —
  EXACTLY QC-3a's banked sha and size. Byte-identity holds; the
  conversion is deterministic across worktrees and runs. No
  determinism finding; the reproduced file was used for all
  legs below. The QC-3a conversion+load proof also reran green
  from this tree (qc-4-qc3a-test.log, ALL PASS).

## 2. llama.cpp load verdict — the MIXED file is accepted as-is (U-QC5 SETTLED)

The emitted file is MIXED: 32x Q8_0 + 5x F16 (ffn_down, dim0 172)
+ 11x F32 (norms) under general.file_type 7. llama.cpp's loader
(qc-4-qc4grade-q8.log, verbatim lines):

- "loaded meta data with 21 key-value pairs and 48 tensors from
  ... stories260K.Q8_0.gguf (version GGUF V3 (latest))"
- KV dump reads "general.file_type u32 = 7" and
  "general.quantization_version u32 = 2".
- Type census as loaded: "- type f32: 11 tensors", "- type f16:
  5 tensors", "- type q8_0: 32 tensors" — the loader sees the
  true per-tensor mix, not the label.
- No warning, error, refusal, or fallback line anywhere in the
  load log (grep-verified); tensors load via mmap, contexts
  build, decode runs to QC4GRADE_DONE, exit 0.
- llama-cli independently loads it and reports "ftype : Q8_0"
  (qc-4-llama-load-q8.log, exit 0); the F16 source control loads
  identically with "ftype : F16" (qc-4-llama-load-f16.log,
  exit 0).

U-QC5 SETTLED (for file_type 7 / Q8_0 class): llama.cpp does NOT
care beyond the label — the label is used for the ftype display,
while loading and execution dispatch purely on each tensor's own
type tag. A mixed file whose kept tensors carry their source
types is a first-class GGUF citizen outside Aesir. (The file_type
15 / Q4_K_M instance of the same question re-opens with QC-5's
own cross-load, as the plan already schedules.)

One llama-cli front-end observation, named as a COMPARATOR
ARTIFACT, not a model finding: llama-cli's own text tokenization
of the prompt "One day, Timmy went to" generates identical
gibberish ("He?" / "Her meants sm") from BOTH the F16 source and
the Q8_0 file — while the raw-token-ID path (qc4grade, the
campaign discipline; Aesir's streams; the fixture's pinned
llama.cpp oracle prefix) produces coherent TinyStories text from
both files. llama-cli's text front-end therefore tokenizes this
fixture differently from the reference stream; it affects both
files identically and is not evidence about either file. Cause
class: llama-cli prompt-text tokenization vs the fixture's
reference token stream (BOS/piece handling); not pursued further
— llama.cpp is the referee, not a fix target, and the load +
raw-ID evidence is the commissioned surface.

## 3. Cross-grade — both pairings FAITHFUL, exact at argmax level

Discipline identical to QC-3a: teacher-forcing rank + logit gap
on RAW prompts, identical token-ID streams (the QC-3a streams:
RAW prompt + Aesir-source greedy 16; qc-4-streams.txt /
qc-4-prompts.txt, transcribed from the banked QC-3a grade log and
cross-verified — the rerun QC-3a CSV's true_next column
reproduces all 157 stream positions, asserted in the harness),
CPU-vs-CPU, record = rank + gap of the COMPARATOR's argmax in the
CANDIDATE's row, band rank <= 2 AND gap < 1.0. 157 records.
Harness: qc4grade (llama.cpp full rows) + qc4_crossgrade.py.

- (a) llama.cpp-compressed vs llama.cpp-source
  (qc-4-crossgrade-llama-vs-llama.log): 157 records — exact 157,
  near-tie 0, divergent 0. In-band **157/157 = 100.00%**.
  Argmax agreement **157/157 = 100.00%**. Worst rank 0.
  Verdict **FAITHFUL**. Inside llama.cpp, the compression cost
  at argmax level is zero on this account: not one position
  changes its winner. (Gap is 0 by construction wherever argmax
  agrees; the underlying rows DO differ — max abs logit
  difference 0.4316, qc-4-margin-probe.log.)
- (b) llama.cpp-compressed vs Aesir-source (the QC-3a reference;
  comparator argmaxes from the rerun QC-3a grade CSV)
  (qc-4-crossgrade-llama-vs-aesir.log): 157 records — exact 157,
  near-tie 0, divergent 0. In-band **157/157 = 100.00%**.
  Argmax agreement **157/157 = 100.00%**. Worst rank 0.
  Verdict **FAITHFUL**.
- Sanity pairing (context, same weights, cross-engine):
  llama.cpp-F16 vs Aesir-F16 (qc-4-crossgrade-sanity.log) also
  agrees on all 157 argmaxes — the two engines' F16 forwards are
  argmax-identical on this account, so pairing (b)'s result is
  not an artifact of comparator choice.
- Per-prompt and per-segment subtotals are uniformly 100% in
  both pairings (logs carry the full tables).

Against QC-3a's own account (in-band 157/157, agreement 156/157,
worst gap 0.007): the cross-check is in the same band class and
one step stronger at argmax level — see section 4 for the one
record that differs and why.

## 4. Greedy witness — llama.cpp sees NO divergence (the QC-3a near-tie resolves the other way)

Greedy 16 per prompt from the prompt prefix, llama.cpp, both
files (qc-4-gen-llama-f16.txt / qc-4-gen-llama-q8.txt):

- llama.cpp-F16 generations are token-identical to Aesir's
  source greedy on all 6 prompts (cross-engine witness).
- llama.cpp-Q8_0 generations are token-identical to
  llama.cpp-F16 on ALL 6 prompts — including prompt 2.
- QC-3a's divergence was prompt 2 at generation step 3 (Aesir
  Q8_0 picked 426 over the source's 335). llama.cpp does NOT
  see that divergence. The underlying record is the same
  near-tie, resolved the other way by llama.cpp's numerics
  (qc-4-margin-probe.log): at prompt 2 pos 10, margin(335-426)
  is +0.0090 in llama-F16 and +0.0068 in llama-Q8_0 —
  compression narrows the margin in the same direction Aesir
  measured, but it stays positive, so 335 keeps the win. It is
  the smallest top-1/top-2 margin in the entire llama-Q8_0
  account (next: 0.0093 at prompt 5 pos 26). In Aesir's own
  Q8_0 row the same margin lands at -0.007 (426 wins by 7
  milli-logits). Both engines agree the record is a coin-flip
  near-tie; they disagree only on which side the coin lands —
  exactly the near-tie band's meaning. No contradiction, no
  defect in either engine or in the file.

VERDICT: **FAITHFUL** — the QC-3a-emitted Q8_0 file loads and
runs in llama.cpp as a mixed-type GGUF citizen (U-QC5 settled),
reproduces byte-identically from the banked tooling, and grades
exact at argmax level against both its llama.cpp source and the
Aesir source reference on the full 157-record account.

## Regressions

- Full engine compile exit 0 (qc-4-build.log, ENGINE_BUILD_EXIT=0;
  QC-3 test + grade target builds exit 0).
- QC-3a grade rerun from this tree (qc-4-regress-qc3a-grade.log):
  AGGREGATE FAITHFUL_NEAR_TIE, 157 steps, exact 156, near-tie 1,
  worst rank 1, worst gap 7 milli; BAND 157/157; agreement
  156/157; prompt segment 61/61 exact; continuation 95 exact +
  1 near-tie — every number reproduces QC-3a's banked account,
  and the rerun CSV is byte-identical to the banked
  qc-3-grade.csv (diff-verified). Independent Python re-grade
  agrees (qc-4-regress-qc3a-summary.log).
- QC-3a conversion + load proof rerun: ALL PASS
  (qc-4-qc3a-test.log).
- Full 905 matrix not re-run (slice order; baseline stands).

## Scope gap vs QC-0-PLAN section 6, named (not silently dropped)

The plan's QC-4 paragraph also names the reverse leg (Aesir
loads a llama.cpp-quantized Q8_0 of stories260K). The
commission's numbered scope for this slice (items 1-4) does not
include it, and the kept llama.cpp build tree carries no
llama-quantize binary (build/bin holds llama-cli +
llama-perplexity only; build/tools/quantize is a directory, no
binary). The reverse leg is therefore NOT done here; it is
named for the coordinator — it needs either a llama-quantize
build step or a commission line. QC-5's arbitration leg (plan
section 6 QC-5 iii) needs the same binary.

## Files

- qc4grade.cpp + qc4grade (built binary, on disk; sources banked),
  qc4_crossgrade.py, qc-4-streams.txt, qc-4-prompts.txt,
  build-qc-4.sh, run-qc-4-aesir.sh, run-qc-4-llama.sh.
- Logs: qc-4-build.log, qc-4-tool-build.log, qc-4-shaders.log,
  qc-4-source-sha.log, qc-4-quantize-cli.log, qc-4-emitted-sha.log,
  qc-4-qc3a-test.log, qc-4-regress-qc3a-grade.log/.csv,
  qc-4-regress-qc3a-summary.log, qc-4-llama-version.log,
  qc-4-llama-load-q8.log, qc-4-llama-load-f16.log,
  qc-4-llama-cli-singleturn-q8.log, qc-4-llama-cli-verbose-q8.log,
  qc-4-llama-cli-nocnv-q8.log (a discarded probe: invalid flag
  spelling -no-cnv, harness error only, no llama.cpp behavior),
  qc-4-qc4grade-f16.log, qc-4-qc4grade-q8.log,
  qc-4-gen-llama-f16.txt, qc-4-gen-llama-q8.txt,
  qc-4-crossgrade-llama-vs-llama.log,
  qc-4-crossgrade-llama-vs-aesir.log, qc-4-crossgrade-sanity.log,
  qc-4-margin-probe.log.
- On disk, not banked (git-ignored, regenerable by the run
  scripts): stories260K.Q8_0.gguf (the reproduced file),
  qc-4-rows-llama-f16.bin, qc-4-rows-llama-q8.bin,
  qc-4-test-out.gguf.

## Risks / handoff to QC-3b and QC-5

- QC-3b (gemma-4-E2B): unchanged from QC-3a's handoff (dequant-
  izing input path + streaming writer are prerequisites). QC-4
  adds one comfort and one caution: llama.cpp accepts mixed-
  type files per-tensor, so an E2B emission with kept tensors
  will cross-load the same way IF its metadata copies cleanly
  (U-QC4 still open — header-copy proof is not re-emission
  proof); and gemma4's tokenizer/front-end behavior in llama
  tooling should be witnessed via raw token IDs from the start,
  per the llama-cli artifact above.
- QC-5 (Q4_K_M): (1) U-QC5 re-opens for file_type 15 — the
  per-tensor dispatch evidence here is encouraging but the
  K-quant label class must be cross-loaded on its own file.
  (2) The arbitration leg (llama.cpp Q4_K_M of the same source,
  graded the same way) needs a llama-quantize binary that the
  kept build tree does not currently carry — build it as a
  named first step of QC-5, do not discover it mid-slice.
  (3) Near-tie records WILL flip between engines at K-quant
  margins; the QC-4 precedent (same record, opposite coin side,
  both FAITHFUL) is the verdict pattern to apply — grade the
  band, never a single greedy stream.
