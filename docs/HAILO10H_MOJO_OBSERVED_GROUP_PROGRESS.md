# Observed launch counts and total exchange deadline

Date: 2026-10-24. Pre-code contract:
`TASK_hailo10h_observed_group_progress.md`, published at
`ca6dcc6e8173374e16def351a332a388e459bba8` before implementation.
Capability: AES-CONTROL-011. Fixed scope:
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Implemented boundary

The existing `hailbru/soc_progress.mojo` now has a distinct four-argument
constructor accepting the two allocated descriptor ring capacities. Each
positive returned launch count must be below its own capacity; the input and
output counts may differ and are retained separately. This checks an observed
return value. It does not predict counts or establish enough capacity before
submission. There is no byte/page/span counting formula for grouped transfers.
The original three-argument exact-count constructor and existing IRQ decoder
remain in use by the unchanged native RPC client.

Original `hailbru/soc_exchange_progress.mojo` owns the event state for one
D2H-before-H2D pair. It checks a nonnegative monotonic start, a 1–60000ms timeout,
overflow-safe absolute deadline, nondecreasing timestamps and 1–32 IRQ snapshot
budget. Launch returns, wait admission and IRQ snapshots must arrive strictly
before the deadline. A final completion at the deadline is refused. Zero IRQ
progress spends a snapshot; the last permitted snapshot may complete.

Every refused admitted event permanently poisons that owner. A malformed IRQ
batch cannot commit partial directional completion. Both launch returns and
both distinct transfer completions are required. An IRQ count of one means one
completed transfer; it does not mean one descriptor. Prepare queue status is
not accepted as a launch count. No copied vendor algorithm is introduced.

The module has no OS clock, fd, backing, mapping or quiescence authority.
Timestamps supplied to the bounded inspector are synthetic test inputs.
Completion here is host event accounting. This slice does not submit anything
or prove DMA completion, cache coherence, safe memory release or model execution.

## Verification

Nine new methods and six unmodified legacy methods pass: **1928 primary calls**,
**1928 complete stdout/stderr/exit comparisons**, 1129 accepted and 799 refused.
Of those comparisons, 44 are pre-edit versus final legacy observations; 1884
are reproducibility comparisons against frozen copies of the new linked
images. These latter comparisons are not evidence of a pre-existing capability.
There are 3856 retained full result triples in total.

The independent Python expectations cover all 256 assigned directional channel
pairs, distinct per-direction count/capacity edges, all 256 IRQ completion count
bytes, both completion orders, combined/empty/zero snapshots, record errors,
inactive/unowned/duplicate channels, header/length refusal, exact deadlines,
clock reversal/overflow and snapshot exhaustion. All **771 new inspector
refusals** are individually followed by fresh successful construction. The
direct API consumer adds **34 refusal/recovery cycles**, including 24 attempts
to revive a poisoned owner, eight atomic refusal cases and ordinary move/scope
expiry. No external model or numerical oracle is run.

Before acceptance, all four actual affected executable consumers were linked:
new inspector, direct API, legacy progress and existing RPC device client.
The device client is **link-only and never executed**. Eight ELF tables exclude
vendor inference/hash/protobuf runtime dependencies. Actual import closure is
retained in `evidence/observed-group-progress-2026-10-24/affected-closure.json`.

All **1884 new consumer traces** have joined PID/call records with every line
classified and no opaque syscall record. They contain **35796 observed file-fd
generations and 35796 closes**; these are file descriptors, not DMA descriptor
counts. There are no Hailo opens, ioctls, network connections or memfds.
The 101703 mmap and 40600 munmap calls are ordinary process/runtime events;
no grouped backing or DMA lifetime qualification is inferred from them.

Fresh pre-code snapshots contain 708 Mojo files, 87 Python test files, 158
qualified controls and two pre-edit links. Final snapshots contain 711 Mojo
files and 88 Python tests. Only the contracted existing production module
changed; no old test changed. All control binaries, compiler identity and 806
pre-code archive paths were reverified. The compiler SHA-256 remains
`be46936245ae995680155dcc2f61af5dac8678254c634110e99ceff25ce57c39`.

The first four link attempts failed on unsupported tuple iteration and a missing
`raises` annotation in a test helper. The next four linked, but the new-statement
warning gate refused two unused test loop names. Both attempts and actual source
copies remain retained. The final four links have zero new-statement warnings;
existing ABI/session/storage warnings are separately recorded. There were no
acceptance failures. No whole-repository or hosted-CI pass is claimed.

## Retained evidence and next work

`evidence/observed-group-progress-2026-10-24/archive-identities.json` pins
**12894 raw paths / 158530791 aggregate bytes**, in two pages. Manifest SHA-256:
`8953cae8473e7a9ba228fa39c103441e7a5a802492dc4e14dda6aac8ab5cdfb9`.
These include all failed attempts, actual source/test copies, compiler and
control identities, full results and traces. Raw roots remain immutable;
publication checks run outside them.

Next: same-file assigned channel/list and sealed-buffer ownership, preparation
side effects, returned counts, total deadlines and confirmed late cleanup need
a separate original owner and host fault qualification before a bounded live
control RPC. Prepared cancellation is not active-DMA quiescence. Actual numerical
configuration, precision/packing, placement, original program activation/results
and remaining format/architecture/operation support remain implementation work.
Broad ordinary UNMODIFIED source-model support is still 100% the owner's target.
No DFC, external compiler/machine, precompiled prerequisite, host/CUDA/cloud LLM
execution or proxy is introduced. No numerical source-model execution is claimed.

Publication checks retain nine identical inherited schema diagnostics. Census
reports 142 verified of 187 entries (29 partial,15 missing and one historical
noncanonical status). The scoped ledger summary is reconciled. The drift check
still fails: 23731 baseline findings plus 26 retained local compiler/build/warning
paths in evidence copies. Initial absolute-manifest noise and the first stale
ledger-summary review are preserved outside the immutable raw roots; the final
manifest uses paths relative to the task work directory. No clean global gate
or hosted CI result is asserted.
