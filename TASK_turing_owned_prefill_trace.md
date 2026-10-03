# SPD-00/04 — owned, range-delimited batched prefill tracing

Established 2026-10-02 before implementation. Volmarr authorizes repeated scoped
slices and pushes. Strategy2 has accepted complete logits/cache/decode/checkpoint
and cooperative-control evidence; normal production admission remains one/four.
This slice earns a trustworthy inference-only timeline before further tuning.

## Observed defect and owned design

Four retained earlier MMA captures failed strict admission: overlong dictionary
strings, Python launcher identity, missing child identity or CUDA API timestamps
outside the declared analysis interval. Matching split-package import succeeded;
that recovery alone did not validate those captures. Keep all failures and existing
timestamp/identity/correlation/resource gates intact.

Add an opt-in native Mojo probe for accepted public case1 (37 IDs) and case3
(1070 IDs), precision0/strategy2/context1536/F16 KV. Load installed NVTX dynamically
through pinned OwnedDLHandle, require actual push/pop symbols before model work,
and delimit only fresh prefill with one named range after initialization/reset
has synchronized. Synchronize before popping; numerical export and complete
guarded-cache digest stay outside. Print actual PID, exact committed IDs/state,
all128256 F32 logits, actual host enqueue counts, cache identity and guards.
No new kernel arithmetic, runtime dispatch, device allocations or service stop.

Extend bounded read-only Nsight2023 admission optionally with exact expected PID
and one completed same-thread NVTX push/pop range. Require every matched launch
to belong to that range/thread, all actual GPU work within synchronized range,
and actual executable identity. Preserve legacy default admission. Return observed
kernel/API groups and unions with explicit semantic-range boundary; shared kernel
names do not certify per-projection attribution. No timestamp clipping or caller
supplied executable SQL, no foreign process rows admitted as CUDA owner.

Add an exclusive-report checker binding probe PID/strategy/model/complete vectors,
source CSV/report and actual full guarded-cache bytes to accepted strategy2. Both
unprofiled and profiled probes must match all source F32 bits (signed zero too),
IDs/state/counts/cache/guards; rehash every artifact after validation. Retain
structural, numerical, mutation and interruption failures. All trace/process
durations are unscored; no provider or old-to-new speed ratio.

## Files and acceptance

Own tests/test_turing_prefill_trace.mojo, scripts/check_cuda_trace.py,
scripts/check_turing_prefill_trace.py and portable adversarial contracts, wired
into existing CI proof/compile steps. Finish sm75/sm89/master/normal builds before
serial GPU captures. Use installed Nsight2023.4.4.54 with CUDA/NVTX tracing,
sampling/context switching disabled, explicit named NVTX capture and bounded
owned process lifetime. Preserve raw .qdstrm/.nsys-rep/SQLite/logs privately and
matching installed importer recovery when necessary. Never attach to production
or change drivers/counter permissions/dependencies.

Exercise two public cases unprofiled/profiled, strict ownership/range/correlation
admission and source equality. Add portable wrong PID/range/thread/timestamp,
duplicate/missing records, changed artifacts and exclusive/interrupt report gates.
If installed capture cannot meet strict admission, publish exact failed evidence
without relaxing gates or claiming success. Update owner interfaces/manual,
ledger/TODO/roadmap/devlog, retain unchanged production binary/readiness, push
and verify exact implementation CI. Broader context/concurrency/soak/persistence,
production32 and refreshed Ollama lead remain separate acceptance gates.
