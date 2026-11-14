# Q35-1 — Loader truth for the real file — slice notes

Date: 2026-11-14. Seat: /home/volmarr/aesir-hipserve, branch yrsa/hip-serve,
HEAD at start 940cf23f. Worker ran the six Forge roles sequentially itself
(recon -> design -> build -> test -> repair -> record); sole writer;
NOT committed / NOT pushed (coordinator verifies and banks).

## What changed

1. `aesir_engine/loader/gguf.mojo`, `_validate_qwen35_tensors` only
   (git diff: 45 lines in that one function; line ~1353ff):
   - NEW `qkv_width = 2 * groups * state + inner` from config fields
     (no hard-coded 10240).
   - `attn_qkv.weight`: expected rows `3 * inner` -> `qkv_width`.
   - `ssm_conv1d.weight`: expected rows `inner * 3` -> `qkv_width`
     (cols remain ssm_conv_kernel, type F32).
   - Type constants aligned to the real census (below): every weight
     matrix F16 -> GGMLType.Q8_0 (token_embd, output, ffn_gate/up/down,
     full-attn attn_q/k/v/output, attn_qkv, attn_gate, ssm_alpha,
     ssm_beta, ssm_out). F32 entries unchanged (output_norm, attn_norm,
     post_attention_norm, attn_q_norm, attn_k_norm, ssm_a, ssm_conv1d,
     ssm_dt.bias, ssm_norm). Function docstring records the census and
     the U2 policy.
2. `scripts/make_qwen35_fixtures.py` (NEW): deterministic python GGUF
   v3 writer (repo had only a llama-specific corpus writer in
   prof/armvegr/). Tiny geometry: hidden 32, ffn 64, vocab 16,
   block_count 4, full_attention_interval 4 (3 SSM + 1 full-attn),
   heads 4 / kv 2 / head_dim 8, groups 2, state 8, dt_rank 3,
   inner = dt_rank*state = 24, qkv = 2*groups*state + inner = 56,
   conv_kernel 4. Types mirror the real census (Q8_0 matrices, F32
   small tensors).
3. Generated fixtures (on disk, deterministic; sha256 / bytes):
   - `aesir_engine/tests/fixtures/qwen35_tiny.gguf` — good.
     51872 B, sha256 93d5864dd94bc8b617b84130d07e8ba08fefdf1aa995ab0dee51e78af43abfd2
   - `aesir_engine/tests/fixtures/qwen35_tiny_bad_qkv.gguf` — attn_qkv
     rows 88 instead of 56. 55136 B, sha256 6b10c8956a1097a105de94307a35267dc79255f74516befd7bfa4155ba89b5e1
   - `aesir_engine/tests/fixtures/qwen35_tiny_type_probe.gguf` —
     attn_gate stored F16 instead of Q8_0. 53984 B, sha256 32175aa01fb11866aafab68dd6a112b19d587cb327cbb79f8719733b9fee8a7e
   Convention note: `*.gguf` is gitignored repo-wide (.gitignore:20)
   and fixture_manifest.json's checker requires *tracked* fixture
   paths, so the binary fixtures are deliberately NOT registered in
   fixture_manifest.json (registering them would fail the checker);
   they are regenerable artifacts of the tracked generator script.
   `python3 scripts/check_fixture_manifest.py` after this slice:
   "PASSED: fixture classification, provenance, and storage policy".
4. `aesir_engine/tests/test_qwen35_loader_q35_1.mojo` (NEW): the
   three-probe test (a)/(b)/(c), existing test style, argv paths.
5. `aesir_engine/tests/probe_qwen35_realfile_q35_1.mojo` (NEW):
   real-file probe driver (see seam below). Lives under tests/ because
   `core`/`loader` imports resolve from aesir_engine/ (first build
   attempt from hidden_files/ failed with "unable to locate module
   'core'"; repaired by relocating, like inject_mmproj.mojo).
6. `hidden_files/qwen35-adapter/build-q35-1.sh` (NEW): build script
   following hidden_files/hip-serve/build-1.sh (pixi run --frozen mojo
   build -I . --target-accelerator gfx1151 + shim link line). Logs:
   q35-1-build.log (TEST_BUILD_EXIT=0, PROBE_BUILD_EXIT=0),
   q35-1-test.log, q35-1-realfile-probe.log, q35-1-regress.log.

## Real-file census (read-only python header parse, this session)

851 tensors: 498 Q8_0 + 353 F32 (matches the plan). blk.0 (SSM):
attn_qkv 10240x5120 Q8_0, ssm_conv1d 10240x4 F32, attn_gate 6144x5120
Q8_0, ssm_alpha/beta 48x5120 Q8_0, ssm_a 1x48 F32, ssm_dt.bias 1x48
F32, ssm_norm 1x128 F32, ssm_out 5120x6144 Q8_0. blk.3 (full attn):
attn_q 12288x5120 Q8_0, attn_k/v 1024x5120 Q8_0, attn_output
5120x6144 Q8_0, q/k norms 1x256 F32. Globals: token_embd + output
248320x5120 Q8_0, output_norm F32. Counts decompose exactly
(48 SSM x (8 Q8_0 + 6 F32) + 16 full x (7 Q8_0 + 4 F32) + globals),
so the per-type alignment above holds for every layer. F32 total:
2,645,504 elements (~5.3 MB converted to f16).

## U2 verdict — types recorded, NOT enforced (settled)

Code read (re-verified): `_require_tensor_shape` (~line 1092) raises
only on a missing tensor or a rows/cols mismatch; it fetches the
actual type and raises only when the record is missing (sentinel 99);
the expected_type argument is never compared.
Behavioral probe (c) confirms it: the type-probe fixture stores
blk.*.attn_gate.weight as F16 while the validator passes
GGMLType.Q8_0 for it, and the fixture still reaches VALIDATED;
seer.tensor_types records F16 for it. Test log line verbatim:
"PASS (c) U2: attn_gate stored F16 (validator records Q8_0) still
validates; types recorded, not enforced". Validation stays
shape-driven; the Q8_0 constants above are truthful records of the
real census, not an enforcement change.

## Test results (verbatim, q35-1-test.log; fenced 24G/32G, exit 0)

    GGUF validated: 56 tensors, 23 metadata entries, architecture qwen35
    PASS (a): good qwen35 fixture validates via loader path, attn_qkv 56x32 Q8_0, ssm_conv1d 56x4
    PASS (b): mutated qkv fixture rejected: GGUF required tensor has an invalid shape: blk.0.attn_qkv.weight actual: 88x32 expected: 56x32
    GGUF validated: 56 tensors, 23 metadata entries, architecture qwen35
    PASS (c) U2: attn_gate stored F16 (validator records Q8_0) still validates; types recorded, not enforced
    Q35-1 qwen35 loader validation: ALL PASS

MemAvailable was checked before every build/run (27.6-27.7 GB each
time, above the ~10 GB stand-down floor). aesir-gate / ollama / voxta
were never touched and remained active throughout.

## Real-file probe (q35-1-realfile-probe.log) — PASS

Seam found: the inject_mmproj.mojo staging precedent — _open_and_map
+ _parse_header + _parse_metadata + _parse_tensors, then call
_validate_required_tensors() directly. This does NOT materialize the
~57 GB F16 pool: _map_tensor maps F16/Q8_0 tensors as zero-copy views
into the mmap and converts only the file's F32 tensors into the pool
(2,645,504 elements). No AesirEngine / Seer dequantization involved.
Run fenced (MemoryHigh=24G/MemoryMax=32G), unit exit 0, systemd
reported memory peak 226.1M. Verbatim log:

    arch: qwen35 blocks: 64 hidden: 5120 tensors: 851
    ssm: groups 16 state 128 dt_rank 48 inner 6144 kernel 4 interval 4
    tensor directory parsed; pool F32-converted elements: 2645504
    REALFILE VALIDATION: PASS - _validate_qwen35_tensors accepted the real 27B tensor directory
    blk.0.attn_qkv: 10240 x 5120 type 8
    blk.0.ssm_conv1d: 10240 x 4 type 0

## Regression evidence / bugs found

- scripts/check_fixture_manifest.py: PASSED (above).
- Neighboring test_gguf_metadata_types (built + run standalone,
  q35-1-regress.log): metadata-type matrix + integration PASS, then
  test_gguf_tensor_directory_interface fails with "tensor directory
  admission differs for rank 3" (rank-3 entry now parses via the 3-D
  MoE fold, so the stale expectation misses). This is the documented
  PRE-EXISTING baseline failure `gguf.tensor_directory_interface`
  (GATE_AND_27B_RESULTS.md: full suite 901/905, this + hip_q4k_gemv
  the only failures, both proven pre-existing). NOT caused by this
  slice (the diff touches only _validate_qwen35_tensors) and NOT
  fixed here — out of scope; named as next work for whoever owns the
  J-022 test: update the rank-3 expectation to the 3-D fold behavior
  or restore the rejection. No bug was found inside this slice's
  scope; the two build errors during the build role (RuneTensor
  copyability -> `ref` bindings; probe import root -> relocated
  under aesir_engine/tests/) were repaired in-slice and are recorded
  above.
- Full suite was NOT re-run (memory-tight box, live services);
  baseline to defend remains 901/905 per the gate doc.

## Files left in the worktree (uncommitted, for the coordinator)

Modified: aesir_engine/loader/gguf.mojo (+ the pre-existing live-gate
modification to hidden_files/hip-serve/serve-bench.log, not mine).
New: scripts/make_qwen35_fixtures.py,
aesir_engine/tests/test_qwen35_loader_q35_1.mojo,
aesir_engine/tests/probe_qwen35_realfile_q35_1.mojo,
aesir_engine/tests/fixtures/qwen35_tiny{,_bad_qkv,_type_probe}.gguf
(gitignored bytes, regenerable), hidden_files/qwen35-adapter/
{build-q35-1.sh, Q35-1-NOTES.md, q35-1-build.log, q35-1-test.log,
q35-1-realfile-probe.log, q35-1-regress.log} + built binaries
test_qwen35_loader_q35_1 / probe_qwen35_realfile_q35_1 /
test_gguf_metadata_types_regress in hidden_files/qwen35-adapter/.
