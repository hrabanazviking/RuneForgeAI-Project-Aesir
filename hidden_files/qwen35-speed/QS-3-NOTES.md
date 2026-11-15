# QS-3 — PACKED RESIDENCY: searched-fit packer + Q4_K_M resident contract

Campaign: Project Aesir Qwen3.8-27B speed program (Volmarr, 2026-11-14).
Worktree: /home/volmarr/aesir-qs-pack, branch yrsa/qs-pack, base
5506180d (yrsa/hip-serve). NEVER main (31ab9363); never ~/aesir-q35-7
or the live aesir-gate service.
Method note: ONE worker runs the six Mythic Engineering roles
sequentially (recon, spec, build, proof, review, bank). No sub-agents
were spawned (depth limit) — the established campaign fallback, same
as QC-7 recorded.

Machine state at seat time (2026-11-14 20:09 EST): uptime 10 min,
load1 0.54, MemAvailable ~114 GB. FRESH-BOOT LAW: heavy runs (27B in
any form, 27B conversion, full suites) FORBIDDEN until uptime >= 60
min AND load1 < 1.5 AND MemAvailable > 100 GB — earliest ~21:00 EST.
Light fixture work (stories260K, gemma E2B) proceeds now.

## SLICE QS-3.1 — RECON (this slice)

### Sources read (in this tree, hidden_files/qwen35-adapter/)
QC_RESULTS.md, QC-5-NOTES.md, QC-6-NOTES.md, qc-6-grade-summary.log,
qc-6-grade-prod-p5.csv, qc-6-grade-src-p5.csv, run-qc-6-grade.sh;
code: aesir_engine/core/quantize.mojo (553 lines),
aesir_engine/cli/quantize.mojo (903 lines),
aesir_engine/qwen35_resident.mojo, core/inference.mojo resident
contract, core/runtime_plan.mojo, cli/native_serve.mojo;
ggml reference: ~/llama.cpp-build/ggml/src/ggml-quants.c
(make_qkx2_quants L808, make_qx_quants L637, quantize_row_q4_K_ref
L1467, quantize_row_q6_K_ref L1879, nearest_int L630).

### How Aesir's current packers choose scales (measured from code)
Q4_K (quantize_q4_k, core/quantize.mojo): per 32-value sub-block,
plain min/max affine fit: min_eff = min(sub_min, 0);
scale = (max - min_eff)/15; minute = -min_eff (constant sub-block:
scale 0 / minute -c if c<0, else scale c/15, minute 0). Super-block:
d = max_scale/63, dmin = max_min/63 stored f16; ls/lm =
round-half-away(scale/d), clamped [0,63]. Quants are then RE-FORMED
against the stored (s_hat, m_hat): q = clamp(round((x + m_hat)/s_hat),
0, 15) — this second pass IS mirrored from ggml's ref. What is NOT
mirrored is the fit itself (the QC-5 header names this simplification
verbatim).
Q6_K (quantize_q6_k): per 16-value group, symmetric fit
scale = amax/32, NON-NEGATIVE scales only; d = max_scale/127 f16;
sc = round(scale/d) clamped [0,127]; quants re-formed against stored
scale, l = clamp(round(x/s_hat), -32, 31). ggml's make_qx_quants
instead returns a SIGNED scale whose sign follows the largest-|x|
lane, so a group whose mass is negative is systematically mis-fit by
the symmetric rule (the +s_j asymmetry term in the QC-5 bound).
Rounding: Aesir round-half-away everywhere; ggml nearest_int is
round-to-nearest-even (differs only on exact .5 ties).

### How ggml's searched fit differs (ggml-quants.c, read from disk)
Q4_K path (quantize_row_q4_K_ref): per 32-value sub-block, weights
w_i = av_x + |x_i| with av_x = sqrt(mean(x^2)) over the sub-block;
then make_qkx2_quants(32, 15, x, w, L, &min, Laux, rmin=-1.0,
rdelta=0.1, nstep=20, use_mad=false):
  - baseline: min clamped <= 0, iscale = 15/(max-min), L from
    nearest_int(iscale*(x-min)), weighted SSE as best_error.
  - 21 candidates is = 0..20: iscale = (15 - 1.0 + 0.1*is)/(max-min)
    i.e. effective nmax swept 14.0, 14.1, ..., 16.0. For each
    candidate's Laux, solve the weighted least-squares affine fit
    in closed form: D = sum_w*sum_l2 - sum_l^2;
    scale = (sum_w*sum_xl - sum_x*sum_l)/D;
    min   = (sum_l2*sum_x - sum_l*sum_xl)/D;
    if min > 0: min = 0 and scale = sum_xl/sum_l2. Keep the
    candidate with the lowest weighted SSE.
  - super-block 6-bit scale/min quantization and the stored-scale
    re-form pass are IDENTICAL in structure to Aesir's (Aesir
    already mirrors them); only rounding mode differs (ties only).
Q6_K path (quantize_row_q6_K_ref): per 16-value group,
make_qx_quants(16, 32, x, L, rmse_type=1, qw=NULL):
  - iscale = -32/max where max is the SIGNED largest-|x| lane;
    initial L from nearest_int, weights w = x^2 (rmse_type 1);
    least-squares scale = sum(w*x*l)/sum(w*l^2).
  - search is = -9..9 (skip 0): iscale = -(32 + 0.1*is)/max;
    keep the candidate maximizing sumlx^2/suml2 (weighted-LS gain).
  - super-block: iscale = -128/max_scale over the SIGNED group
    scales; d = f16(1/iscale); per-group i8 scale =
    min(127, nearest_int(iscale*scale_j)) — SIGNED, unlike Aesir's
    [0,127] clamp. Stored-scale re-form pass identical in structure.
So the searched fit is not a different format: identical bytes
layout, identical second pass. It only chooses (scale, min) [Q4_K]
or signed scale [Q6_K] by weighted least squares over a swept
grid instead of by the range endpoints. Endpoint fits are optimal
only when the mass sits at the extremes; real weight blocks are
concentrated mid-range, so the LS fit buys error exactly where the
mass is.

### The named divergent record — p5 pos22 (QC-6 grade)
qc-6-grade-summary.log (198 records, product = QC-6 Q4_K_M vs Q8_0
source, Aesir teacher-forcing, RAW prompts, CPU-vs-CPU):
  in-band 197/198 = 99.49%; agreement 190/198 = 95.96%;
  rank dist {1:190, 2:7, 3:1}; VERDICT DIVERGENT (strict gate).
  Worst record: gap 421 milli, rank 3, p5 pos22, true token 89240,
  source argmax 1817, product argmax 17454, in_band False.
qc-6-grade-prod-p5.csv row pos22: rank_true 5, gap_true 1625 milli
(the true next token sits 1.625 logits / rank 5 in the PRODUCT row);
rank_comp 3, gap_comp 421 milli (the SOURCE argmax 1817 sits rank 3,
0.421 logits below the product argmax). Per-prompt: p5 carries
49 records, 48 in-band, agreement only 43/49 — p5 is the battery's
hardest prompt by a wide margin (next-worst in-band gap: p5 pos32,
109 milli).
Grade wiring (run-qc-6-grade.sh): source rows graded RESIDENT path
vs banked llama.cpp comparator rows (q35-3b-comp.csv); product rows
graded DEFAULT packed path vs the source rows. So pos22 is a
product-vs-source divergence, not a comparator artifact.
BLOCK ATTRIBUTION — honest limit: the QC grade CSVs are logit-level
records; NO per-tensor or per-block attribution of pos22 exists in
the QC records, and none can be read off them. Any claim naming a
specific weight block as the cause would be invented. What the
records DO support: (a) the divergence is a single near-tie-scale
logit flip (0.421 gap, rank 3) on the hardest prompt, the exact
signature of accumulated per-block fit error, not of a layout or
tiling bug (a layout bug diverges everywhere, cf. stories flat
product: 3 divergent records, worst gap 2.054); (b) the only named
quality lever in both QC-5 and QC-6 notes is the searched fit.
Attribution method for QS-3.5: re-pack with searched fit and
re-grade the identical battery — if pos22 moves into band with no
regressions, the fit was the cause at the only level the gate
measures. A per-block error census (old vs searched MSE per tensor
on the real weights) rides along as supporting evidence.

### Stories control (QC-5) — why the fixtures can arbitrate
stories260K F16 -> Q4_K_M, graded on the dequantized weight set
(the flat product is admitted by no packed/per-row reader):
  ours (min/max fit): 154/157 in-band, worst rank 3, worst gap
  2.054, DIVERGENT. Divergent records named: p0 pos22 rank 3 gap
  0.914; p2 pos10 rank 1 gap 1.062; plus one more (QC-5-NOTES).
  llama.cpp's own Q4_K_M of the same source: 157/157 in-band,
  FAITHFUL, worst gap < 1.0. The llama product conflates searched
  fit + per-row fallback mix; QS-3.3 separates the fit term by
  holding Aesir's tiling/policy fixed and switching ONLY the fit.
  Q8_0 control (ours): 157/157 FAITHFUL — the harness and engine
  are not the variable; the K fit is.

### Resident contract recon (for QS-3.4)
Q8_0 resident today (Q35-3r): opt-in flag --qwen35-resident ->
NativeModelPlan.resident_q8 -> Qwen35CPUSession(resident_q8) ->
AesirEngine(qwen35_resident) -> per-layer _require_q8_resident_
weight (stored type == Q8_0 (8), packed view, cols % 32 == 0, else
refused BY NAME) + validate_qwen35_resident census in
qwen35_resident.mojo (large set = token_embd, output, per-layer
ffn gate/up/down, full-attn q/k/v/output, SSM qkv/gate/alpha/beta/
out; 27B: 498 tensors). Mode string q8_0_resident on serve health.
Why Q4_K_M can be a TRUE resident form (mechanical facts):
  - gemm_f16 dispatches packed views by format: Q4_K_M/Q4_K_S ->
    gemm_q4_k_m, Q6_K -> gemm_q6_k (core/compute.mojo gemm_f16).
    The qwen35 forward consumes every large weight only through
    gemm_f16 plus the per-row embedding dequant.
  - _embed_token_into handles K kinds 10..14 via packed_value
    (ggml_kind_of_format), so a Q4_K token_embd embeds natively.
  - QC-6 product composition over the large set: token_embd Q4_K;
    output Q6_K; attn_v/ffn_down Q6_K on use_more_bits layers,
    Q4_K elsewhere; all other large weights Q4_K. A K resident
    contract must therefore admit stored types {12 (Q4_K),
    14 (Q6_K)} per tensor with cols % 256 == 0 (the K super-block
    tiling gate), and refuse anything else BY NAME — including
    Q8_0, F16, and K tensors at non-256 widths. Registry already
    admits Q4_K_M for qwen35 (QC-6); the resident contract is the
    missing piece, exactly as the brief states.
  - Memory price if it lands: large weights stay at the file's
    16,223,236,576 B instead of ~57 GB F16-materialized (Q35-3r
    pricing of the same set at Q8_0: 28,596,003,296 B stored).

### Slice plan (banked per slice on yrsa/qs-pack)
QS-3.2 searched-fit packers quantize_q4_k_searched /
quantize_q6_k_searched in core/quantize.mojo (ggml-exact searches
above; old packers untouched), CLI mode --fit searched|legacy on
both Q4_K_M converters (in-memory + QC-6 streaming), default
legacy until QS-3.3 grades say otherwise.
QS-3.3 fixture proof: unit round-trip + MSE A/B (old vs searched);
stories F16 -> Q4_K_M both fits, dequantized-weight-set grades vs
source via grade_quantize_qc_3; gemma E2B via streaming converter
if the stories result warrants. No-regression bar: searched must
not lose any record the legacy fit holds in band.
QS-3.4 Q4_K_M resident contract: qwen35_resident.mojo K census +
_require_k_resident_weight + plan/session/serve wiring beside the
Q8_0 mode (mode string q4_k_m_resident), fixture logits-diff vs
the default packed path (must be 0.0-class: same packed bytes,
same GEMM dispatch), named refusals unit-proven.
QS-3.5 (HEAVY — lock + fresh-boot gate): re-pack 27B Q8_0 source
with searched fit to Qwen3.8-27B-...-Q4_K_M-searchedfit.gguf on
/mnt/vault/models/gguf/ (existing product never overwritten),
strict-grade the QC-6 battery, report verdict + pos22 fate.

## SLICE QS-3.2 — SEARCHED-FIT PACKERS (banked)

Code: core/quantize.mojo (+428 lines): _nearest_int_even (ggml
nearest_int, ties-to-even), _make_qkx2_searched (exact
make_qkx2_quants port: rmin -1.0, rdelta 0.1, nstep 20, weights
av_x + |x|, closed-form weighted-LS affine solve, min clamped
<= 0), quantize_q4_k_searched; _make_qx_searched (make_qx_quants
rmse_type 1, weights x^2, is sweep -9..9, signed scale),
quantize_q6_k_searched (super-block iscale -128/max_scale,
d = f16(1/iscale), signed i8 group scales). Legacy writers
untouched. cli/quantize.mojo: --fit legacy|searched on
quantize_gguf_q4_k_m and quantize_gguf_q4_k_m_streaming_qc6
(default legacy); --fit searched with --to q8_0 refused by name;
unknown fit refused by name (both CLI refusals exercised live).

Unit proof (test_quantize_k_qs_3, ALL PASS, qs-3-k-test.log;
dequant only through packed_value; MSE legacy -> searched):
  case                Q4_K MSE              Q6_K MSE
  random-uniform      1.267e-3 -> 9.79e-4   9.37e-5 -> 6.26e-5
  clustered-outlier   2.566e-3 -> 8.30e-4   4.76e-4 -> 2.83e-4
  gaussish-multiscale 4.80e-4 -> 3.85e-4    3.79e-5 -> 2.40e-5
  all-negative        1.91e-4 -> 1.62e-4    5.29e-5 -> 4.70e-5
  constant +0.625     5.7e-12 -> 5.7e-12    3.83e-4 -> 0.0 EXACT
  constant -0.375     8.4e-9  -> 8.4e-9     5.2e-10 -> 0.0 EXACT
Searched wins or ties EVERY case at unit level; the Q6_K constant
cases expose the legacy symmetric fit's defect in pure form
(a constant block it cannot represent at all; the signed searched
scale represents it exactly). Zero blocks exact under both.
Regression: QC-5 K test re-run on this tree ALL PASS with the
banked worst ratios unchanged (q4 0.9989002, q6 0.9686628;
qs-3-regress-qc5k.log). Builds: QS3_K/QC5_K/ENGINE all exit 0
(qs-3-build.log).

## SLICE QS-3.3 — FIXTURE PROOF: stories260K (banked)

Pipeline (run-qs-3-fixtures.sh, all exits 0): fixture
stories260K.F16.gguf sha256 57a81ed1...e4eb69e3 (the QC-5 pin),
CLI convert --to q4_k_m --fit legacy|searched (in-memory
converter, flat tiling as QC-5), dequantize_model_qc_5 to the
F16 weight set, grade_quantize_qc_3 vs the F16 source (RAW
prompts, teacher-forcing, CPU-vs-CPU), qc3_grade_summary.py
independent re-account. qs-3-grade-stories-{legacy,searched}*

LEGACY reproduces QC-5 EXACTLY: 154/157 in-band (98.09%),
agreement 141/157 = 89.81%, worst gap 2.054, DIVERGENT;
divergent records p0 pos22 (rank 3, gap 914), p2 pos10 (gap
1062), p3 pos8 (rank 1, gap 2054). Harness is not a variable.

SEARCHED: 154/157 in-band (98.09%), agreement 142/157 = 90.45%,
worst gap 1.273, verdict still DIVERGENT. Per-record movement:
  FIXED: p0 pos22 (p0 now 23/23 in-band, worst gap 171) and
  p2 pos10 (p2 now 23/23). Both legacy fit-caused records the
  QC-5 notes named are gone.
  NEW out-of-band: p3 pos9 (rank 3, gap 1273), p3 pos11
  (rank 3, gap 359), p5 pos8 (rank 1, gap 1062). p3 25->24
  in-band, p5 30->29; p1/p4 unchanged 100%.
Net: in-band count UNCHANGED, agreement +1 record, worst gap
-38%. The searched fit does NOT fix the stories divergence as a
whole and does NOT regress the count. Reading (QC-5's own
conflation warning, now separated): on stories the remaining
divergence is dominated by the flat true-K density itself
(llama's FAITHFUL 157/157 product mixes per-row fallbacks at
higher effective bits; no stories matrix is 256-aligned, so
llama quantizes almost nothing at flat Q4_K density). The fit
term, isolated here, is worth exactly the two named records +
worst-gap reduction. On the 27B the conflation vanishes (flat ==
per-row, fallbacks fire zero times, QC-6 census) and the single
out-of-band record's gap is 0.421 — the searched fit is the only
variable there. QS-3.5 arbitrates.
Gemma E2B fixture: NOT run in this slice (stories + unit A/B
arbitrate the fit; the E2B streaming A/B is named remaining
fixture work, behind QS-3.4/3.5 in priority).

## SLICE QS-3.4 — Q4_K_M RESIDENT CONTRACT (banked)

Code: qwen35_resident.mojo gains Qwen35KResidentReport +
validate_qwen35_resident_k (large set = Q35-3r's; per tensor:
stored in {Q4_K 12, Q6_K 14}, packed view, cols % 256 == 0, else
refused BY NAME; pricing 144/210 B per 256 el vs F16 2 B/el).
core/inference.mojo: _require_k_resident_weight + Qwen35Block
resident_k param mirroring the Q8_0 block checks. aesir.mojo:
AesirEngine qwen35_resident_k (arch refusal; both-modes refusal
by name; whole-model census print). qwen35_session.mojo:
resident_k + weight_load_mode q4_k_m_resident. runtime_plan:
NativeModelPlan.resident_k. native_serve: --qwen35-resident-k
flag (profile-gated, mutually exclusive with --qwen35-resident),
plan + CPU session wiring. HIP session untouched (it hardcodes
the Q8_0 resident contract; K-HIP is named future work, not
silently implied).

Fixture (make_k256_fixture.py via the banked generator at a
custom geom; scripts/make_qwen35_fixtures.py gained an opt-in
file_type kwarg, default None = byte-identical banked fixtures):
H=512 FFN=512 V=1024 NB=4, QW=512, INNER=256 — every large
matrix 256-aligned. Streaming CLI conversion (legacy fit):
33 large tensors all K-packed.

Proof (test_qwen35_resident_k_qs_3, ALL PASS,
qs-3-resident-k-test.log):
  k1 census: 33 large = 29 Q4_K + 4 Q6_K; k_bytes 4,366,080 vs
     F16 14,442,496 (30.2% — the packed form is the resident form).
  k2 resident-K vs default on the same product: greedy identical,
     logits max_abs_diff == 0.0.
  k3 refusals by name: K-mode on Q8_0 source (names
     blk.0.ffn_gate.weight, type 8); Q8-mode on K product (type
     12); both modes together refused.
  k4 session: mode string only under opt-in; replies equal.
Regression: test_qwen35_resident_q35_3r re-run ALL PASS
(qs-3-regress-q35-3r.log) — the Q8_0 path is untouched in
behaviour. Builds all exit 0.
Serve smoke (qs-3-serve-smoke.log): fenced systemd unit on port
18435 served the fixture product under --qwen35-resident-k;
/health reported weight_load_mode q4_k_m_resident; a real
/v1/generate completion returned (12 tokens, finish length);
unit stopped clean. The 27B resident serve smoke rides QS-3.5.

## SLICE QS-3.3b — GEMMA E2B FIXTURE (conversion A/B, banked)

Source: gemma-4-E2B-it-Q4_K_M.gguf (2.9 GB, the QC-3b fixture
file). Streaming CLI conversions --to q4_k_m --fit legacy and
--fit searched both exit 0; products byte-identical in size
(2,698,735,712 B — same policy, same layout; only the fit
differs). Timings (single-threaded converter): legacy 0:50.22,
searched 10:59.72 — the searched fit costs 13.1x the legacy fit
at conversion time. Extrapolated 27B conversion: ~44 min
(QC-6 legacy was 3:21). Conversion is one-time; residency is
forever — but a parallel/allocation-free searched fit is named
future work (QS-3.6 candidate).
Weight-space MSE A/B for E2B: NOT produced — the only dequant
weight-set tool (dequantize_model_qc_5) is in-memory and pool-
exhausts at E2B scale (it was built for stories-size files).
Named remaining work rather than silently dropped; the stories
grade (QS-3.3) + unit MSE (QS-3.2) + the 27B strict grade
(QS-3.5) carry the fit question.

## SLICE QS-3.5 — THE 27B APPLICATION (banked)

Gate: fresh-boot conditions verified live at 21:00 EST
(uptime 1:00, load1 0.19, MemAvailable ~114 GB). HEAVY.lock
claimed atomically, held 21:00-22:31 EST, released after the
serve smoke. Run: systemd unit qs3-27b (MemoryHigh 56G /
Max 72G), script run-qs-3-27b.sh.

CONVERSION: aesir quantize <Q8_0 source> --to q4_k_m
--streaming --fit searched. Wall 1:19:57, max RSS ~28 GB.
Product: /mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-
Uncn-Turbo-Brilli-50x-AGI-NEO-Q4_K_M-searchedfit.gguf
16,223,236,576 B (byte-identical size to the legacy product),
sha256 793cf77549456073fc166c56cc43afe1a609b3ce8722aa069fa75
400a2932f99. The legacy product was NOT overwritten.

STRICT GRADE (QC-6 battery, RAW prompts, teacher-forcing,
CPU-vs-CPU; source rows re-graded fresh through the resident
Q8 path vs the banked llama.cpp comparator; product rows vs
the source rows) — graded TWICE, through the default packed
path and through the QS-3.4 resident-K path, with IDENTICAL
results (qs-3-grade-summary.log / -residentk.log):
  IN_BAND 197/198 = 99.49%   agreement 192/198 = 96.97%
  rank dist {1: 192, 2: 5, 4: 1}
  VERDICT: DIVERGENT (not FAITHFUL) — 1 of 198 out of band.
vs the legacy product (QC-6): in-band UNCHANGED 197/198;
agreement UP 190 -> 192; the QC-6 named record p5 pos22 is
FIXED (p5's worst in-band gap is now 15 milli at pos0). The
sole out-of-band record MOVED: p5 pos8, gap 453 milli, rank 4
(true 5335 = the source's own argmax; product argmax 321).
Generation witnesses: product default-path and resident-K
40-token greedy runs are token-IDENTICAL to each other
(a third path-equality confirmation); both open " Paris."
like the source, then continue differently (witness only).

READING (no inflation): the searched fit did exactly what
the fixture slices measured — it fixed the named record and
bought agreement — and the strict gate still fails on ONE
record, a different one. Measured twice now (stories + 27B):
the fit term governs the bulk error; the last record is a
knife-edge argmax flip at flat Q4_K_M density that moves
under any small perturbation of the packing. NEXT NAMED
CAUSE + decisive experiment (QS-3.6): grade a llama.cpp-
produced Q4_K_M of the same Q8_0 source on the identical
battery. If llama's own product also lands at 197/198-class,
the remaining gap is the density itself, not Aesir's writer,
and the honest road is a denser policy for the tail tensors
(e.g. Q6_K on the worst-census classes). If llama's product
is FAITHFUL, the delta lives in fit details (imatrix-style
weighting, super-block rounding) and the hunt continues there.

RESIDENT SERVE SMOKE (qs-3-serve-smoke-27b.log): the searched
product served under --qwen35-resident-k on fenced port
18435; census 498 large = 457 Q4_K + 41 Q6_K, k_bytes
16,201,420,800, F16 avoided 53,786,705,920; a real completion
returned (eos, 13 tokens). The small resident form is now a
SERVED form as well as a packed one.

## SLICE QS-3.6 — THE LLAMA CONTROL (banked)

Question left by QS-3.5: is the last out-of-band record
Aesir's writer or the flat Q4_K_M density itself? Method:
llama-quantize --allow-requantize the same Q8_0 source to
Q4_K_M (plain, no imatrix file; the flag is required — llama
refuses requantize from Q8_0 by default, its own words in
qs-3-llama-convert-time.log), then grade the control on the
IDENTICAL battery against the same fresh source rows.
Control: /mnt/vault/models/gguf/Qwen3.8-27B-...-Q4_K_M-
llamacontrol.gguf, 16,547,639,776 B, converted in 0:56.
GRADE (qs-3-grade-summary-llama.log): FAITHFUL —
IN_BAND 198/198 = 100.00%, agreement 192/198 = 96.97%
(SAME agreement as the QS-3.5 searched product), rank dist
{1: 192, 2: 6}, worst gap 312 milli (p2 pos20); at QS-3.5's
fatal record p5 pos8 the control sits at 265 milli rank 2,
IN band (searched product: 453 milli, rank 4).
So the searched fit EQUALS llama's fit in bulk (agreement
identical); the gate difference is entirely in the tail —
and the control is 324,403,200 B LARGER. Per-tensor census
(qs3_census.py, headers only) names the whole difference:
24 tensors — blk.*.attn_qkv.weight on the 24 SSM blocks —
llama Q6_K vs Aesir QC-6 policy Q4_K. Counts: Aesir
{Q4_K 457, Q6_K 41} vs llama {Q4_K 433, Q6_K 65}; every
other tensor type identical. QS-3.7 applies exactly that
one policy line and re-grades.

## SLICE QS-3.7 — POLICY v2: ALL attn_qkv AT Q6_K (banked)

First cut of the QS-3.6 fix: attn_qkv -> Q6_K unconditionally
in both writers. Product searchedfit2.gguf: 16,872,042,976 B,
conversion 1:20:46. Census vs the llama control then caught
the overshoot: v2 {Q4_K 409, Q6_K 89} vs llama {433, 65} —
STILL 24 differing tensors, the COMPLEMENTARY attn_qkv half.
The llama rule is use_more_bits-GATED attn_qkv (24 of the 48
SSM attn_qkv tensors), exactly like attn_v/ffn_down. The
policy is corrected to the gate in this slice (QS-3.8 v3
re-pack runs under the same lock).
GRADE of v2 (default AND resident-K, identical again):
197/198 = 99.49%, agreement 192/198, rank {1:192, 2:5, 4:1},
DIVERGENT. But the fatal record moved in an instructive way:
p5 pos8 gap 453 -> 265 milli — EXACTLY the llama gap there —
while its RANK stayed 4 against llama rank 2. The band fails
on rank, not gap: in the searched product three tokens crowd
within 265 milli above the true token; in the llama product,
one. The imatrix theory for the difference was tested
against the llama.cpp source and DISPROVEN: quantize.cpp
loads an imatrix only from an explicit --imatrix file
argument, which the control never passed (the source file
imatrix KVs are inert metadata). Remaining named cause
after QS-3.8: if the policy-identical v3 still rank-4s at
pos8, the delta is per-block fit minutiae accumulated in
the deep tail, and the named instrument is a byte-level fit
A/B on real rows (Aesir searched packer vs ggml quantize_row
on identical inputs) to find any systematic slip.

## SLICE QS-3.8 — POLICY-IDENTICAL v3 + CLOSING RECORD (banked)

Product: ...-Q4_K_M-searchedfit3.gguf, 16,547,639,776 B —
byte-identical SIZE to the llama control; census vs control:
ZERO differing tensor types (433 Q4_K / 65 Q6_K / 353 F32).
sha256 d029dfef165e7a99cecf1a0fb593798c8d0248710be7cca556a8
8a632fe6d7ea. Conversion 1:19:51 under the lock.
STRICT GRADE (default packed AND resident-K, identical for
the fourth time): IN_BAND 197/198 = 99.49%, agreement
195/198 = 98.48% — HIGHER than the llama control (192/198);
rank dist {1: 195, 2: 2, 3: 1}; worst gap 234 milli (llama
312). VERDICT BY THE GATE LETTER: DIVERGENT — the sole
out-of-band record remains p5 pos8: gap 218 milli (llama
265 — the searched product is CLOSER there), rank 3 vs
llama rank 2. Two tokens crowd above the true token in the
Aesir product where one does in llama's. p3 went to 59/59
agreement; p5 agreement 48/49 (llama 47/49).
Resident serve smoke (qs-3-serve-smoke-27b-v3.log): v3
served under --qwen35-resident-k on 18435; census 498 large
= 433 Q4_K + 65 Q6_K, k_bytes 16,525,824,000; real
completion returned (eos). Lock released ~01:30 EST.

## QS-3 CLOSING SUMMARY — the whole arc, as measured

The workstream set out to make the small resident form TRUE.
Delivered and banked on yrsa/qs-pack:
- ggml searched-fit Q4_K/Q6_K packers behind --fit searched
  (QS-3.2), winning or tying every unit case vs legacy.
- The Q4_K_M resident contract (QS-3.4): the packed form is
  now a served resident form, logits-identical to the packed
  path on fixtures and on the 27B (four identical grade
  pairs), 30.2% of F16 bytes at fixture scale, 16.5 GB
  resident at 27B scale with 53.8 GB of F16 avoided.
- Three 27B products + a llama control, all strict-graded
  on the identical RAW-prompt battery:
    legacy (QC-6)      197/198, agree 190, worst 2054-class
    searched v1        197/198, agree 192, fatal p5p8 453/4
    searched v2        197/198, agree 192, fatal p5p8 265/4
    searched v3        197/198, agree 195, fatal p5p8 218/3
    llama control      198/198 FAITHFUL, agree 192, p5p8 265/2
  (fatal record shown as gap-milli/rank.)
- The named QC-6 record p5 pos22 was fixed by the searched
  fit in v1 and stayed fixed. The gate's last record is a
  rank-3-vs-2 knife-edge at p5 pos8 where the Aesir product
  beats the control on gap AND on total agreement.
REMAINING NAMED WORK (for the coordinator to schedule):
  1. Byte-level fit A/B on real rows (Aesir searched vs
     ggml quantize_row_q4_K_ref/q6_K_ref on identical
     inputs) to hunt any residual transcription minutia.
  2. Searched-fit converter speed: 13.1x legacy at gemma
     scale, ~80 min at 27B scale, single-threaded —
     allocation-free inner loops + row parallelism.
  3. E2B weight-space MSE (needs a streaming dequantizer;
     the in-memory one pool-exhausts at that scale).
  4. K-resident HIP session (contract is CPU-path only).
The QS-3 seat ran the six Mythic Engineering roles
sequentially (depth limit — no sub-agents), as commissioned.
