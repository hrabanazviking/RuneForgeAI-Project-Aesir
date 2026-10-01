# SPD-00 — portable provider measurement and physical feasibility slice

Established 2026-10-01. Owner: performance tools and opt-in physical tests.

## Authorization and current truth

Volmarr says continue after the published speed roadmap and previously authorizes
AESIR improvements and pushes to main. Apply Mythic Engineering sequentially.
Start from clean main 3863950; production native compute remains the measured
59094de algorithm. Native 3B sm_75 four-token prefill/F16 KV is ready. The current
provider script fixes output at 32, groups providers, retains hashes without
complete replies, and only observes wall time. It cannot certify M2/M3.

## Reviewable outcome

Deliver a connected first SPD-00 measurement slice: portable 32/128/256-token
provider suites, deterministic balanced ordering, explicit loaded/as-is residency,
observed cache/precision boundaries, complete redacted public request/reply evidence,
failure-aware statistics and adversarial evidence tests. Preserve default request
semantics and existing summary fields where applicable. Reserve report paths
before requests and retain failures without converting them into favorable scores.

Add an opt-in native physical measurement probe for real begin-turn/decode timing,
checked active packed-tensor accounting, streaming bandwidth and full-logit export.
An optional pinned llama-cpp-python reference tool independently evaluates the
exact exported input IDs against the same GGUF bytes on CPU. It is test-only;
no external engine or Python inference enters the native runtime. Declare numerical
budgets before observing comparisons and retain every failing comparison.
Record a measured conditional bandwidth ceiling and the next optimization decision.

## Ownership and planned files

- scripts/benchmark_second_brain.py: provider requests/scheduling/report boundary.
- scripts/test_benchmark_second_brain.py: actual-socket and malformed evidence gates.
- scripts/check_llama3_logits.py: optional independent CPU numerical oracle.
- aesir_engine/tests/test_cuda_measurement.mojo: physical timing/traffic/logits probe.
- scripts/README_AI.md, scripts/INTERFACE.md, tests/INTERFACE.md: public contracts.
- .github/workflows/ci.yml: offline benchmark regressions and probe compile gate.
- docs/SPEED_MEASUREMENT.md and docs/evidence/speed-measurement-2026-10-01/:
  operation, provenance, observed feasibility and exact remaining boundaries.
- TODO.md, README_AI.md, DEVLOG.md and CAPABILITY_LEDGER.md: narrow actual progress.

## Invariants and failure rules

Preserve live provider/embedding/corpus policy, model bytes, credentials, auth,
limits and production compute numerics. No driver/dependency upgrades, copied
vendor kernels, unsafe cache clearing, hidden prompt truncation or counter permission
changes. Device tasks run serially, with admitted VRAM; only owned test processes
are stopped. Preserve current binary/manifest before changes and validate the
launcher after final Mojo edits. No private paths, keys or corpus enter Git.

Missing telemetry, unsupported cache-disable controls or unavailable independent
oracle prerequisites are explicit boundaries. Stage timings are host-monotonic,
synchronized actual native calls; they are not isolated GPU-only or CPU-enqueue
measurements. Full SPD-00 stays open until its complete tracing, cache/residency
matrix and independent numerical/feasibility gates pass. This task must not check
all SPD-00, claim a speed lead, or implement SPD-01 opportunistically.

## Verification and completion

Use primary/pinned source for API semantics and optional oracle. Prove limits,
ordering, response identity/counts, exclusive output and retained failure artifacts
with real loopback sockets and malformed inputs. Physically execute the probe and
independent oracle when available, archive public raw results/checksums and limits,
and refresh a paired provider series. Run appropriate Python tests, counted master,
negative control, relevant CUDA compile/execution, doc/fixture/hygiene checks.
Rebuild/check the launcher when required, preserve ready supervision, push main,
verify remote SHA and exact CI, and provide operator instructions plus publication
receipt. Runtime ledger remains partial outside the narrowly exercised subset.
