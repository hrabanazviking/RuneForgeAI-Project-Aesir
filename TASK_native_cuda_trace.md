# SPD-00 — owned native CUDA timeline slice

Established 2026-10-01. Owner: optional performance tools and evidence.

## Authorization and current truth

Volmarr authorizes continued roadmap slices, with each verified implementation
pushed before proceeding to the next. Main is clean at 2d63984. Use Mythic
Engineering sequential roles; this is approval to implement the scoped slices.
The first SPD-00 slice provides independent four-vector 3B logits and host-stage
timing, but no detailed actual kernel/API timeline. Production binary remains
f3442a1e and the supervised native CUDA service is ready.

Installed optional Nsight Systems is 2023.4.4.54. Its local CLI supports CUDA
trace, disabled CPU sampling/context-switch collection, non-overwriting report
creation and SQLite export. Check its actual driver compatibility through a small
owned-process capture. Do not change drivers, privileges, profiler permissions
or dependencies if unsupported; preserve that failure and use a separately
documented supported tracing method. Presence is not execution evidence.

## Reviewable outcome

An opt-in owned-process profiler runs the validated native executable with one
public prompt and explicit model/context/greedy limits. It captures CUDA kernel,
API and transfer rows using the installed tool, exports SQLite, validates the
observed schema/identity/timestamps, and emits reproducible grouped timing plus
CPU launch/synchronization and timeline-gap observations. An unprofiled matched
completion gates profiler non-mutation; profiled time is never a speed score.
Distinguish actual measured kernel families from unobserved per-Q/K/V/FFN labels.

Preserve complete raw trace/transcript/report artifacts outside Git, with hashes,
tool/runtime/model identities, command semantics and public summary in Git. A
read-only parser has strict input/schema/row admission, no mutable SQL execution,
and adversarial synthetic SQLite tests. No fabricated CUDA rows or partial traces
may report successful attribution. Preserve failures and refuse existing paths.

## Files and boundaries

- scripts/profile_native_cuda.py: optional capture/process/artifact ownership.
- scripts/check_cuda_trace.py: read-only validated timeline analysis.
- scripts/test_check_cuda_trace.py: schema/identity/count/time/incomplete gates.
- scripts/INTERFACE.md, scripts/README_AI.md and docs/NATIVE_CUDA_TRACE.md:
  operation, resources, schemas, exact tool boundary and reproduction.
- docs/evidence/native-cuda-trace-2026-10-01/: public summaries/provenance.
- .github/workflows/ci.yml: portable parser tests only; never profiler execution
  on a GPU-less runner.
- TODO.md, roadmap, capability ledger, README_AI.md and DEVLOG.md: narrow truth.

Production compute, model bytes, original corpus/embeddings, service settings,
credentials and provider policy stay unchanged. No native trace instrumentation
or foreign inference. Read model metadata and observed VRAM to admit the owned
process; never stop unrelated services to make headroom. Record initialization
versus generation boundaries where observed, with explicit unavailable fields.

## Verification and onward sequence

Physically capture a small public completion and a representative longer prompt
with GPU work serialized. Compare complete unprofiled/profiled replies and counts,
validate all actual exported records, and preserve failures and limitations. Prove
parser rejection using explicitly synthetic databases; run existing related
regressions, repository/fixture/hygiene checks and exact pushed CI. Publish the
slice, then continue to remaining SPD-00 controls or SPD-01 once its prerequisites
have actual evidence. Do not claim the overall speed program complete from this
trace slice.
