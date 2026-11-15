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
