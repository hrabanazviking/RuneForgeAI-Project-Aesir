# Slice 139 — repeatable physical backend acceptance

Implemented 2026-10-19. The TEST-ONLY runner
`tests/test_hailo10h_hardware.py` executes the actual canonical Mojo binary.
It requires explicit executable, model, profile and fresh evidence directory;
it never supplies a substitute inference implementation or silently skips a
missing device. The profile contains only public test prompts.

```sh
bash scripts/build_hailo10h.sh work/hailo-build
python3 tests/test_hailo10h_acceptance_contract.py -v
python3 tests/test_hailo10h_boundary.py \
  --library work/hailo-build/libaesir_hailo10h.so \
  --binary work/hailo-build/aesir -v
python3 tests/test_hailo10h_hardware.py \
  --binary work/hailo-build/aesir --model-path "$AESIR_HAILO_MODEL" \
  --profile tests/fixtures/hailo10h_qwen25_1_5b.json \
  --evidence-dir work/hailo-acceptance-run-1
```

The physical runner records source/executable/library/profile/model hashes,
checks model bytes independently against the pinned profile, and rehashes
all inputs after execution. Raw input/stdout/stderr, process exit/timeout and
duration are retained, including failures. An existing evidence directory is
rejected. Missing/mismatched provenance, nonzero exit, malformed JSON, wrong
device/model, unfinished generation or corrupted context cannot earn a pass.
Durations include loading and fingerprinting; they are not token-speed scores.

The declared physical checks are fresh readiness, single-shot arithmetic,
multi-turn recall, oversized-context rejection without history mutation,
recall after rejection, explicit reset to zero, and another generation after
reset. Word recall and exact word-only formatting are recorded separately.

Seven synthetic validator regressions pass. They test the checker using
explicitly synthetic records and do not constitute hardware evidence.
Eleven local C ABI/CLI tests pass (hardware class explicitly skipped).
Warnings-as-errors C++ compilation and the canonical Mojo build pass.

The admission tests exposed a real FIFO hang before file-type validation.
Read-only `O_NONBLOCK` open now reaches `fstat` without waiting for a pipe
writer. FIFO, FIFO symlink, empty file and directory inputs reject before
device creation; regular artifact loading remains subject to slice 140.

Hardware identity on this boot is exposed through `h1x-0`; assuming a
`hailo0` device filename would falsely diagnose a missing accelerator.
Use supported HailoRT discovery and identity queries. No driver, firmware,
service, binding or OS change was made for this slice.

The next acceptance is a fresh physical run. HailoRT API identity and actual
completion are not independent per-layer utilization telemetry or broad
model-quality certification.
