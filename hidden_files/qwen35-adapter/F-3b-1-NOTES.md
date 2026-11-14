# F-3b-1 — gemma4 registry profile admits Q8_0 (small fix slice)

Six Forge roles run sequentially by one worker (Scout, Architect,
Builder, Tester, Gatekeeper, Archivist), recorded here per brief.
Seat: /home/volmarr/aesir-f3b1, branch yrsa/f-3b-1, base
67293f1e (origin/yrsa/hip-serve, re-read by ls-remote at start).
Builds/tests under systemd-run MemoryHigh=24G / MemoryMax=32G.
Services aesir-gate/Ollama/Voxta left down per Volmarr's order.

## Why Q8_0 was absent — verdict: OMISSION, not deliberate exclusion

Evidence:
- The gemma4 branch of ModelArchitectureRegistry.classify
  (aesir_engine/core/model_registry.mojo) admitted quantization
  via the SHARED helper native_quantization_supported()
  (Q4_K_S, Q4_K_M, Q5_K_S, Q5_K_M, Q6_K, F16, BF16, F32). That
  list dates from the original registry commit (5ec8a956,
  "feat(models): add architecture compatibility registry") —
  before any gemma4 Q8_0 file existed in this project.
- No comment, note, or test pins a gemma4 Q8_0 exclusion. The
  registry test asserted only E2B Q4_K_M READY/VERIFIED and
  E4B Q5_K_M COMPATIBLE; nothing asserted gemma4+Q8_0 refused.
- The one deliberate Q8_0 decision on record cuts the other
  way: Q35-2 added qwen35_quantization_supported() scoped to
  qwen35, with a docstring saying the shared lists are NOT
  extended because the Q8_0 evidence was qwen35-only. The
  pattern is evidence-scoped admission per architecture.
- QC-3b is the first gemma4 Q8_0 evidence: the converted
  gemma-4-E2B Q8_0 file loads VALIDATED in GGUFSeer, constructs
  in PackedGGUF, and the engine kernels already read Q8_0
  (Q35-3r's Q8_0-resident path). The exclusion was a stale
  shared list, not a reasoned refusal. Fixed, not reported-only.

## What changed (2 files)

- aesir_engine/core/model_registry.mojo:
  - NEW gemma4_quantization_supported(name): scoped to gemma4,
    returns native_quantization_supported(name) or Q8_0, with a
    docstring citing the QC-3b evidence and stating the shared
    lists are NOT extended (mirrors the qwen35 scoping).
  - gemma4 branch: admission check now calls
    gemma4_quantization_supported; supported_quantizations is
    now "Q4_K_S, Q4_K_M, Q5_K_S, Q5_K_M, Q6_K, Q8_0, F16, BF16,
    F32". VERIFIED stays pinned to Q4_K_M (unchanged), so a
    Q8_0 gemma4 file files READY / COMPATIBLE.
- aesir_engine/tests/test_model_registry.mojo: import + F-3b-1
  assertions — gemma4 admits Q8_0 and Q4_K_M; the SHARED native
  list still refuses Q8_0; classify(gemma4 E2B, file_type 7)
  is READY/COMPATIBLE with the new supported list string.
  No pre-existing assertion was changed: none asserted the old
  exclusion (see verdict above).

## Every place the profile speaks about quantization — state now

- Registry admission (model_registry.mojo): gemma4 branch uses
  gemma4_quantization_supported — Q8_0 ADMITTED. llama branch
  (native_k_quantization_supported), qwen3 branch (same),
  qwen35 branch (qwen35_quantization_supported), mistral
  (display string only, still NOT READY by design): UNCHANGED.
- supported_quantizations display string: consumed only by
  cli/model_inspect.mojo (text + JSON) — now names Q8_0 for
  gemma4. No other consumer.
- Serve planning: core/runtime_plan.mojo and cli/cuda_chat.mojo
  both gate through ModelArchitectureRegistry.inspect — the
  same single admission point; no second quantization check
  exists in the serve path (grep-verified). CONSISTENT.
- Memory pricing: inspect() runs gemma4_profile_memory_plan
  (core/inference_memory.mojo) AFTER admission; the plan prices
  weights from the stored file size and is quantization-name
  agnostic — it cannot refuse Q8_0. Proof below: the Q8_0
  inspect returns Estimated VRAM bytes 5171679844 with tensor
  validation passed, i.e. the planning path consumed the file.
- gemma4_profile.mojo (CUDA dimension profile) speaks no
  quantization at all — untouched, correctly.

## Proofs (logs in this directory, f3b1-*)

(a) Emitted file (QC-3b's, read-only, not regenerated):
  /home/volmarr/aesir-qc-3b/hidden_files/qwen35-adapter/
  gemma-4-E2B-it-Q8_0.gguf
  BEFORE (QC-3b, qc-3b-inspect-q8.log): Status NOT READY,
  reason "The Gemma 4 adapter does not support this GGUF
  quantization."
  AFTER (f3b1-inspect-q8.log, exit 0):
    Quantization:            Q8_0
    Supported quantizations: Q4_K_S, Q4_K_M, Q5_K_S, Q5_K_M,
                             Q6_K, Q8_0, F16, BF16, F32
    Tensor validation:       passed
    Estimated VRAM bytes:    5171679844
    Compatibility:           COMPATIBLE
    Status:                  READY
    Reason:                  Matched a native Gemma 4 variant profile.
(b) Source Q4_K_M (f3b1-inspect-source.log, exit 0): Status
  READY, Compatibility VERIFIED — unchanged.
(c) Unchanged neighbours (both exit 0): qwen35 27B Q8_0 file
  Status READY (f3b1-inspect-qwen35.log); llama stories260K
  Q8_0 fixture Status NOT READY (f3b1-inspect-llama-q8.log) —
  the shared lists were not extended, so llama Q8_0 admission
  is exactly as before.

## Regressions

- Engine compile: ENGINE_BUILD_EXIT=0 (f3b1-build.log).
- Q35-2 profile/registry tests: test_qwen35_registry_q35_2
  (which also runs the full native.model_registry case,
  including the new F-3b-1 assertions, as its case e1):
  ALL PASS, exit 0 (f3b1-q35-2-test.log).
- gguf metadata suite (test_gguf_metadata_types): build exit
  0; run: 13 PASS then the KNOWN pre-existing failure
  "tensor directory admission differs for rank 3" — the
  gguf.tensor_directory_interface case, byte-identical to the
  failure recorded in QC-3b-era logs. No NEW failures.
- QC-3b load proofs unaffected: the emitted file was used
  read-only; nothing in loader/ or writer/ changed, and the
  inspect run above re-exercised PackedGGUF construction +
  tensor validation on it (passed).

## Named remainder (not this slice)

inspect on the emitted file still reports "CPU support: no"
for gemma4 — the gemma4 CPU forward gap recorded by QC-3b is
unchanged and out of scope here. Admission truth after this
slice: the profile no longer refuses the Q8_0 quantization;
the remaining forward gap stays named exactly as before.
