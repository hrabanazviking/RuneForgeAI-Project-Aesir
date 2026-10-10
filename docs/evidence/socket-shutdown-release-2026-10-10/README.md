# Socket ownership and shutdown release gate — 2026-10-10

AES500-250 release verification against source revision `743d9f2ecee423225ff23d0998dfa45c91c5124b`.

- Fresh build: `pixi run mojo build --target-accelerator sm_89 aesir_engine/main.mojo -o /tmp/aesir-socket-shutdown-250` — passed.
- Binary SHA-256: `1906adace947ddaabd2e77b81763aed1c9e41bdf30362209149b2073d2f0cfbd`.
- `/tmp/aesir-socket-shutdown-250 --help` — exit 0.
- `pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/run_all.mojo` — 245 passed, 0 failed, 1 external-fixture skip (246 total).
- `pixi run mojo run --target-accelerator sm_89 aesir_engine/tests/test_local_transport_ownership.mojo` — transfer/release and socket admission boundary cases passed.
- `python3 scripts/test_check_doc_drift.py`, `python3 scripts/check_doc_drift.py`, and `git diff --check` — passed. Repository checker notes pre-existing warnings: 24 duplicate root assets, 7 generated executables, and one zero-byte placeholder model.
- Current checkout cannot run the real-model service harness because `aesir_engine/model.gguf` is a zero-byte placeholder. Historical Llama3 active-shutdown results are recorded in the baseline and are not claimed for this revision.
- Hosted Actions was checked for the pushed chain; at the latest observed query, recent runs were queued/in progress and none was reported successful for this new release SHA. Do not infer completion from those states.

The release gate verifies compilation, CLI capability output, focused ownership behavior, counted local master coverage and docs. It does not prove physical-model shutdown on this checkout, GPU-kernel preemption, or independent agent review.
