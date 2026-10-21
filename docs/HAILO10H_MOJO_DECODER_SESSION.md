# Original source cache-return and decoder session semantics

Date:2026-10-21. Exact pre-code contract71dfa61:
docs/HAILO10H_DECODER_SESSION_DESIGN.md. Broad ordinary source-model support and
Hailo-only LLM execution remain fixed.

## Implemented source/mathematical boundary

DecoderSessionPolicy owns explicit cached_append/full_prefix input mode,
source and selected cache-return flags, return origin, provenance and bounded
work. Exact logical charge128*layers+2+UTF8(mode/origin/provenance) is checked
before copying the policy or allocating exports. A source projector validates
the full original architecture, inherits its cache-return preference or records
an explicit override, while retaining raw/default/unresolved source facts. It
never infers input mode from the return flag or silently drops supplied past.

New typed/source-scalar builder overloads retain existing source/bias/activation/
rotary/output decisions. cached_append preserves existing persistent bases and
append views; return preference controls formal cache exports independently.
full_prefix requires past0 and sends selected post-bias/rotary K and selected
post-bias V directly to causal attention, without cache bases, append operations
or alias/views. It avoids unallocated capacity*KV products and retains genuine
query/feature/context bounds. This is mathematical graph construction, never a
host attention forward or proof of numerical cache-reuse equivalence on Hailo.

Cache exports have exact K,V layer order and end-of-graph lifetimes. Independent
recipe snapshots and source/global mapping checks reject stale policies, mode/
past/producer/source/bias/rotary/GQA/export/alias/lifetime mutations. Source export
helpers migrate bias/activation/semantic/expanded storage lifetimes together.
Cache and matrix consumers validate the same session owner before using it.

CacheLayout preserves its old positional constructor, adding an optional mode.
full_prefix produces a checked empty persistent layout with total0, skips phantom
capacity/width/stride/pool products and refuses every cache address lookup.
Returned cache activations remain activation storage under caller-supplied width
assumptions; no physical cache layout or returned-value serialization is certified.
Explicit session JSON uses schema5 and formal source/global cache exports. All
old complete outputs remain unchanged; source32/64 words are retained exactly.

## Acceptance

Fifty-one entrypoints rebuild without diagnostics under one unchanged178-file
Mojo source snapshot. Twenty-two suites pass 147 methods/4730 native child calls. New seven
methods/606 calls comprise181 accepted and
425 expected refusals. Eight complete frozen GGUF outputs
and two complete ordinary graphs match after removing only explicit session/
schema metadata. Both input modes, source/default/override flags, mixed per-layer
bias/rotary/GQA paths, independent K/V widths, exact source32/64 words, index
bounds, large unallocated capacity and all downstream mutations pass.

Eight independent ownership traces cover160 in-process refusal/fresh-construction
cycles. Source/binary/oracle identities, commands, all51 build diagnostics,22
suite logs, final run identities, two complete representative traces and the
full external archive census are retained in docs/evidence/decoder-session-2026-10-21/.
No failed or preliminary artifact contributes to these acceptance totals.

Owned caller policy/geometry/scalar/decoder/bias/activation state is mutated after
construction without changing the resulting graph. Session/export recipe snapshots
remain independent of subsequent source-plan mutation. Repeated refusal/fresh graph
cycles exercise descriptor cleanup with unchanged source bytes. Trace audits cover
source header reads, no shard payload mmap, no Hailo open or ioctl. Tests evaluate
only graph/byte/lifetime/index arithmetic, not model/layer/attention forwards.

An initial exact-budget test shared its tiny session limit with a bias-enabled
fixture and correctly hit the bias work bound first. The test now uses a zero-bias
fixture to isolate exact session accounting. That negative run and corrected probe
are retained. Final acceptance uses only freshly rebuilt binaries under a matching
unchanged source snapshot. No failed/preliminary evidence counts as final success.

## Fixed-target frontier

This verifies source/session mathematical compiler behavior, not complete ordinary
architecture adaptation, immutable source identity, device precision/packing/
placement, executable numerical configuration, program upload/activation/results/
cleanup, physical fit or source-model execution. Remaining window/scaling/training/
activation/architecture coverage is implementation work toward broad support,
never permanent model eligibility rules. No DFC, outside compiler/machine, user
conversion, vendor-precompiled prerequisite, inference proxy or CPU/CUDA/cloud LLM
inference was introduced. Actual numerical Hailo encoding/execution remains open.

Whole-repository consistency remains failing:baseline20098/current21006;
all908 added diagnostics concern retained session receipt paths, with no new
nonreceipt issue after Markdown line normalization. Ledger census111 verified/
156 unique IDs. The historical ledger-schema diagnostics are unchanged; the
schema does not pass. Targeted local acceptance passes; no historical-master,
whole-repository or hosted-CI pass is claimed.
