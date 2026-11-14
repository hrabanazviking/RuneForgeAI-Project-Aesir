# Q35-3r — Q8_0-resident load path (worker slice)

Worker ran all six Forge roles sequentially in one seat (recon ->
design -> build -> test -> repair -> record); no sub-agents. Seat:
/home/volmarr/aesir-q35-3r @ yrsa/q35-3r, base 88c71564 (Q35-5 tip).
Scope: fixture-grade only. NO real GGUF was loaded through any
forward path. The real 27B and 40B files were read ONLY through
the Q35-1 no-materialization directory seam (probe peaks ~174 MiB).

## Recon finding that shaped the design (read from disk, not assumed)

The campaign premise priced a real-file load at ~57 GB because the
weights would be dequantized to F16 at load. The code says the
engine-core CPU path never does that:

- GGUFSeer._map_tensor maps Q8_0 tensors as ZERO-COPY PACKED VIEWS
  into the mmap (is_quantized=True, format Q8_0); only F32 tensors
  convert into the pool (27B census: 2,645,504 elements, ~5.3 MB).
- Qwen35Block consumes every large weight ONLY through gemm_f16,
  which dispatches a packed Q8_0 operand to gemm_q8_0: the
  single-row decode shape fuses dequant into a SIMD GEMV (no
  scratch); the batched shape decodes ONE weight row at a time
  into a bounded F32 scratch (a_cols floats). The output head goes
  through the same gemm; token embedding dequantizes ONE row per
  token (_embed_token_into). Direct element reads touch only the
  small F32-derived tensors (norms, ssm_a, dt_bias, conv1d,
  ssm_norm) -- megabytes, converted at load on both paths.

So the resident MECHANICS already existed. What was missing -- and
what this slice adds -- is the CONTRACT around them:

1. Nothing verified a file's large weights actually are Q8_0. The
   loader records types without enforcing them (Q35-1 U2): a file
   with F16-stored large weights loads silently today and runs via
   gemm_f16_direct over mmap views. Under a resident claim that is
   a silent fallback; the gate could not turn on an unverified path.
2. Nothing reported the load mode anywhere (plan or health).
3. The footprint was priced by assumption (~57 GB / ~83 GB), not
   measured or formula-priced from the files' own directories.

## Design chosen (least-invasive seam; ONE forward implementation)

An opt-in resident mode threaded through the existing admission
chain, in the established Q35-4a style (explicit flag, plan field,
honest health surface), enforcing the contract at load:

- NEW aesir_engine/qwen35_resident.mojo (engine root, beside
  qwen35_session.mojo -- the Q35-4 placement precedent: `loader`
  imports do not resolve from core/ when reached via a test root;
  the first build proved it and the module moved):
  validate_qwen35_resident(seer) checks EVERY large weight -- the
  exact Q35-1 validator set (token_embd, output, per-layer ffn
  gate/up/down, full-attn q/k/v/output, SSM qkv/gate/alpha/beta/
  out; 2 + 16*7 + 48*8 = 498 on the 27B) -- against the recorded
  tensor types. Not Q8_0, not a packed view, or input width not a
  multiple of 32 => REFUSED BY NAME, no fallback. Returns a census
  report pricing the admitted set both ways (stored Q8_0 bytes =
  elements/32*34; F16-materialized bytes = elements*2).
- Qwen35Block.__init__ gains resident_q8: Bool = False; under it,
  each layer's large weights pass _require_q8_resident_weight
  (same named refusal) at construction.
- AesirEngine gains qwen35_resident: Bool = False + a same-named
  field; refuses the mode on non-qwen35 files; passes the flag to
  every Qwen35Block; after construction runs the whole-model
  validation (covers the globals) and prints the census line.
- Qwen35CPUSession gains resident_q8: Bool = False (trailing param;
  all existing constructions unchanged) and weight_load_mode():
  "q8_0_resident" under the opt-in, "" otherwise.
- NativeModelPlan gains qwen35_resident (5th param) -> resident_q8
  field, set only in the qwen35 branch; the mode on any other
  profile is refused by name at the end of plan construction.
- Serve: --qwen35-resident flag (misuse on another profile refused
  by name; on the cpu+non-qwen35 gate it refuses with the existing
  no-CPU-fallback message first -- order recorded, both refusals
  proven). serve_loaded gains optional weight_load_mode; /health
  emits "weight_load_mode" inside capabilities ONLY when a mode is
  reported, so every other profile's payload is byte-identical and
  the qwen35 default payload is unchanged. No forward code, no
  GEMM, no state code was touched: one forward implementation.

### Rejected alternatives

- A separate resident block type + forked forwards: doubles the
  geometry surface Q35-3a just repaired; the forwards already
  consume packed weights, so a fork buys nothing and risks drift.
- A Q8_0-aware matmul wrapper dequantizing per-use into scratch:
  gemm_q8_0 already IS that (fused GEMV / one-row scratch). Adding
  a second dequant layer would change numerics for no benefit and
  forfeit the exact-0.0 equality proof below.
- Dequantize-on-load into a bounded cache of F16 blocks: still a
  materialization policy, with cache-invalidation hazards across
  snapshot/restore; rejected in favor of the mmap-resident truth.
- Enforcing Q8_0 in the loader validator for everyone (flipping
  U2): changes the default path's proven behavior for all archs;
  enforcement belongs to the opt-in that claims residency.

## Numerics honesty

The resident path reuses the loader's exact packed representation
and the same gemm_q8_0 kernels as the default path -- there is no
second Q8_0->F16 conversion to diverge from. Proof (a) therefore
targets and MEASURES max_abs_diff 0.0 (below), not near-tie
grading; the teacher-forcing harness was not needed.

## Proofs (logs in this folder; build-q35-3r.sh / run-q35-3r-tests.sh)

(a) Resident vs default, qwen35_forward fixture
    (q35-3r-test.log, ALL PASS):
    - (r1) census: 33 large tensors, 822,272 elements,
      q8_0_bytes=873,664, f16_bytes=1,644,544.
    - (r2) greedy 16 tokens IDENTICAL on both paths and equal to
      the banked Q35-3a sequence (1019 675 143 452 111 251 827
      386 423 176 368 1018 910 490 742 849); next-token logits
      max_abs_diff = 0.0 exactly.
    - (r4) REFUSAL: resident load of the new F16-probe fixture
      (blk.0.ffn_gate.weight stored F16) raises "Qwen35Block:
      resident Q8_0 load refused tensor 'blk.0.ffn_gate.weight':
      stored GGML type 1 is not Q8_0 (8)..."; (r5) the same
      fixture loads fine on the default path.
(b) Per-token vs batched ON THE RESIDENT PATH (r3): s 0.0008479953,
    conv 0.0078125, logits 0.013671875 -- bit-for-bit the Q35-3a
    (c) numbers, as they must be (same kernels); next token
    identical. (The same-path exact-0.0 continuation property is
    re-proven at session level in (r7).)
(c) Footprint, qwen35_large fixture (NEW profile: hidden 512, ffn
    1408, vocab 8192, 8 blocks, 30,982,144 large elements,
    33,200,896 B file; /usr/bin/time -v, load + 12 forwards):
    - default:    peak RSS 113,248 KB
    - resident:   peak RSS 113,612 KB (delta +364 KB = validation
      and reporting overhead, noise class; generated tokens
      identical to default)
    - materialize (deliberate whole-model F16 dequantization of
      the same file, held in heap buffers -- the behavior the
      gate prices, performed ONLY by the bench mode): peak RSS
      174,460 KB. Delta vs resident +60,848 KB vs the formula
      61,964,288 B of F16 buffers: the avoided cost is measured,
      and it closes against the formula.
    Formula-priced real files (exact censuses from the probe):
    - 27B: 498 large tensors, 26,893,352,960 elements; stored Q8_0
      28,574,187,520 B; F16-materialized 53,786,705,920 B; avoided
      25,212,518,400 B. (Closes: + F32 10,582,016 B + header/
      tokenizer = file 28,596,003,296 B.)
    - 40B: 746 large tensors, 39,068,631,040 elements; stored Q8_0
      41,510,420,480 B; F16-materialized 78,137,262,080 B; avoided
      36,626,841,600 B.
    The gate's ~57 GB / ~83 GB figures were pricings with pool/KV
    assumptions on top; the exact large-weight terms are the ones
    above. FIT, stated plainly for Q35-3b: residency removes the
    53.8 GB anonymous F16 term entirely, but a full 27B forward
    still touches ~28.6 GB of file-backed weight pages plus the
    ~4.2 GB runtime pool plus ctx KV/state -- at the campaign's
    ~26.5-27.7 GB MemAvailable beside the live set, a real-file
    serve does NOT yet fit; the remaining decision is the quiet
    window, not another code path.
    Directory-phase probe peaks (no materialization, no forward):
    27B 178,348 KB, 40B 178,864 KB; both files PASS resident
    validation (every large weight stored Q8_0).
(d) Session/snapshot/regression, all against the final tree:
    - (r6) resident session two-turn replies == default session
      replies exactly; load mode reported only under the opt-in.
    - (r7) Q35-5 machinery over the resident engine: snapshot at
      boundary 72 restores, B re-run == R2; stateless resend
      prompt=90 reused=72, reply == R2.
    - Q35-4a session test ALL PASS unchanged; Q35-5 snapshot test
      ALL PASS unchanged (default sessions, q35-3r-regress-q35-5).
    - Serve (side port 18435, units stopped, port free, gate
      untouched): resident bench ALL PASS -- /health carries
      "weight_load_mode": "q8_0_resident" (raw body in
      q35-3r-health-resident.json), T1/T2 == in-process reference,
      reused=72. Default bench ALL PASS -- /health has NO
      weight_load_mode key, replies == reference.
    - Serve refusals: f16probe + --qwen35-resident exits 1 naming
      blk.0.ffn_gate.weight (q35-3r-refusal-f16probe.log);
      --qwen35-resident with --profile llama3 exits 1
      (q35-3r-refusal-profile.log).
    - Q35-1 loader ALL PASS; Q35-2 registry ALL PASS; Q35-3a
      forward ALL PASS (greedy identical); ripple probe ALL PASS
      (unchanged expectations); full engine compile exit 0.
      Full 905 matrix NOT re-run (Q35-7 owns it).

## Fixtures (scripts/make_qwen35_fixtures.py)

Generator extended by parameterization only (defaults preserve the
banked RNG stream): all four pre-existing fixtures regenerate
BYTE-IDENTICAL (sha256 93d5864d.., 6b10c895.., 32175aa0..,
140e1750.. re-verified after the edit). New, additive only:
- qwen35_forward_f16probe.gguf (943,264 B, sha256 9759ec25..):
  forward geometry with blk.0.ffn_gate.weight stored F16.
- qwen35_large.gguf (33,200,896 B, sha256 28804e4c..): footprint
  profile above (seed 20261115).

## Files changed

- aesir_engine/qwen35_resident.mojo: NEW contract + census.
- aesir_engine/core/inference.mojo: GGMLType import;
  _require_q8_resident_weight; Qwen35Block resident_q8 param +
  per-layer checks (default off; forward bodies untouched).
- aesir_engine/aesir.mojo: qwen35_resident field/param, non-qwen35
  refusal, block wiring, whole-model validation + census print.
- aesir_engine/qwen35_session.mojo: resident_q8 field/param +
  weight_load_mode().
- aesir_engine/core/runtime_plan.mojo: plan resident_q8 field +
  qwen35_resident param, named refusal off-profile.
- aesir_engine/cli/native_serve.mojo: --qwen35-resident flag +
  misuse refusal; serve_loaded weight_load_mode param + health
  key (emitted only when set); qwen35 session wiring.
- scripts/make_qwen35_fixtures.py: parameterized forward builder +
  f16probe + large profiles (old outputs byte-identical).
- aesir_engine/tests/test_qwen35_resident_q35_3r.mojo: NEW (r1-r7).
- aesir_engine/tests/probe_qwen35_resident_realfile_q35_3r.mojo: NEW.
- aesir_engine/tests/bench_qwen35_resident_footprint_q35_3r.mojo: NEW.
- hidden_files/qwen35-adapter/: build-q35-3r.sh,
  run-q35-3r-tests.sh, run-q35-3r-serve.sh, q35_3r_bench.py,
  q35-3r-*.log, Q35-3r-NOTES.md, LEDGER/MAP drafts.

## Repair trail (in-slice)

- Build 1: native_serve health fragment had an invalid escape
  (a backslash-colon assembled by hand) and qwen35_resident sat
  in core/ where `loader` does not resolve via test roots; module
  moved to engine root (Q35-4 precedent), fragment rebuilt
  programmatically. A colon-inside-the-key JSON defect in the
  same fragment was caught by the resident serve bench (default
  bench passed, isolating it) and fixed; final health body is
  valid JSON with the key exactly as designed.
- Serve runner: first attempt used a 15-char API key; the serve
  requires 32..256 chars. Runner artifacts only; no code impact.

## Named risks carried to Q35-3b

- FIT (above): residency is necessary, not sufficient; the 27B
  beside the live set still needs the parent's quiet-window call.
- U1 semantics (oracle grading) unchanged by this slice: resident
  mode changes no numerics, so Q35-3b grades the same forward it
  would have graded anyway, now loadable under the contract.
- The batched Q8_0 GEMM decodes one weight row per output into an
  F32 scratch per worker thread; at the real shape that is
  5120 floats per thread -- bounded and shape-derived, recorded
  here so the real-file peak accounting in Q35-3b includes it.
- Snapshot store cost (Q35-5) is unchanged and additive to any
  real-file residency arithmetic.
