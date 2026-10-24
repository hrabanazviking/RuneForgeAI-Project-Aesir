# Original typed grouped device lifecycle: host qualification

Date:2026-10-24. Pre-code contract:`TASK_hailo10h_grouped_device_rpc.md`,
published626e9d6. Owner scope:`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Broad ordinary UNMODIFIED source-model support100% remains the fixed target.
This slice qualifies original host control ownership. Numerical source-model
execution and physical grouped DMA remain open.

## Original Mojo owner

`hailbru/soc_group_device.mojo` exposes `run_group_device(roots,timeout_ms)`.
Each call opens its own fresh published grouped client and reuses the existing
create20,identify22,destroy21 request/reply codecs. There is no caller-supplied
remote handle or borrowed-session constructor. Parsed handle presence is separate
from its UInt32 value;zero is valid. The result retains accepted identity,
attempt counts,logical-destruction confirmation and separate primary,logical
cleanup and file-finalization errors. A known handle in a diagnostic result is
an observed value,not authority to reuse a destroyed or failed owner.

The single lifecycle admission deadline starts after session establishment.
It covers exchange admission,typed parsing and admitted logical cleanup. Each
exchange receives only remaining budget;later phases never renew it. Invalid,
backward and late clock observations fail closed,with a60000ms ceiling.
Userspace checks reject late results;they do not preempt arbitrary synchronous
kernel calls. Each acceptance child has an independent20-second private-process-
group watchdog with bounded termination/kill handling.

Normal success uses IDs0/1/2 for create/identify/destroy. Destroy-attempted is set
before the exchange. Failure preserves the primary error. One cleanup destroy
with ID3 is possible only for a parsed known handle,healthy available transport,
remaining overall budget and no prior destroy attempt. Unknown create handles
are never guessed. Poisoned clients are never reused. Possibly completed destroy
requests are never retried. The contract allowed at most four attempts;this
implementation and all observed outcomes have at most three.

A valid correlated typed destroy reply confirms logical destruction. Local
file close does not supply that confirmation. The existing session owner handles
stop/join,channel/list/map/file finalization and backing retention. Unconfirmed
file close retains the actual views and forbids fd retry. Public void-stop and
ignored remote-close limits remain documented in
`HAILO10H_GROUP_SESSION_FINALIZATION_BOUNDARY_2026-10-24.md`;software finalization
is not all-failure hardware-idle or remote-cleanup proof.

The explicit host diagnostic is`smidr/tools/group_rpc_device_mock.mojo`;
`tests/hailo_group_device_api.mojo` consumes the API directly. Mock identity
protocol2,firmware5.3.7,logger4,architecture6 is synthetic. It is no new physical
firmware/profile observation.

## Acceptance and independent oracles

**90 methods and5134 complete current/frozen comparisons** pass:
2970 command-exit acceptances and2164 expected
refusals. Diagnostic API success can report an expected failed first lifecycle
plus fresh-owner recovery;these classifications are not model admission counts.
Every pair compares full stdout,stderr and exit status. New-image pairs are
reproducibility checks. Independent public-header and actual public protobuf
oracles supply byte/field expectations.

- Twelve typed methods:392 full pairs,784 full syscall traces and392 complete
  normalized fault-state comparisons. Zero/nonzero/max UInt32 handles,typed
  presence,malformed create/identify/destroy bodies,all three exchange phases,
  effectful faults,poison,clock/deadline boundaries,one-shot cleanup,uncertain
  close and fresh-owner recovery are exercised.
- Ten existing grouped-client methods:287 pairs. The actual invoked images
  match the final build byte for byte.
- Eight selected suites:68 methods/4450 pairs. Group8/1856,ABI12/323,frame8/89,
  typed-device10/73,progress6/44,exchange9/1884,session6/132 and new auxiliary
  worker9/49. Fourteen historical-image pairs include two intentional old
  close-gap observations;they are not corrected-behavior proof.
- Four additional new-worker clock/late-census refusal pairs. Real syscall
  injection makes the post-join census clock fail or return after its admission
  budget;complete paired traces and process results are retained.
- One paired test-only protoc execution compiles the actual pinned public
  `6-rpc.proto`. Its generated descriptors independently validate4607 complete
  fixture streams. Test-only protobuf tooling is not a model compiler or a
  production dependency.

The logical policy replay checks733 current-image outcomes,including390
confirmed logical destructions,43 single cleanup attempts and6 unconfirmed
file contexts. Request/reply bodies use real existing typed functions;no new
protobuf production implementation or server implementation is copied.

## Actual host resource observations

Per typed image,1768 actual IRQ workers exit before owning-file close attempts.
118652 actual file-fd generations balance118649 closes plus3 deliberately
retained mock-driver fds.733 mock context opens balance730 actual closes plus
those3 retentions.1466 actual owned VMAs balance1454 unmaps plus12 deliberate
retentions from6 uncertain contexts. There are13740 actual protection changes,
including6932 PROT_NONE transitions,and3404 complete request/reply wire checks.
All assigned storage and worker observations join their actual PID/TID/file
and mapping generations. Mock launch effects do not establish physical DMA.

The new auxiliary worker audit accounts2390 file generations/2386 explicit
closes plus4 pipe fds reclaimed by two expected fail-closed process exits.
102 owned callbacks are distinguished from416 startup runtime-pool threads
across106 traces. These runtime threads are host orchestration,not LLM inference.
The bounded post-join census is separate from actual pthread join. The original
probe and all its old source/test bodies remain preserved.

Two invalid-argument children exited before any device owner existed while a
runtime naming/wait syscall was unfinished. Their explicit process/thread exits
classify those cancellations. They are not unresolved owning IRQ calls. The
first overly strict audit assumption and its corrected classifier are retained.
All accepted host child calls,owned fd/VMA release or deliberate retention and worker
exits are accounted. There is no actual Hailo open/ioctl,network inference,
DMA,RPC packet,program activation,model loading or numerical operation.

## Inputs,builds and retained failures

Fresh pre-code inputs:718 actual Mojo/91 Python files,168 controls,compiler,
C/UAPI/schema/helper copies and823 contract archive paths. Final inputs:722/92.
Zero old production or test bodies changed. All22 Mojo and5 C/C++ consumers
link;58 ELF tables include separate test-only protoc inspection. Zero warnings
occur on new statements. Inherited warnings are retained separately. Compiler
SHA-256:`be46936245ae995680155dcc2f61af5dac8678254c634110e99ceff25ce57c39`.

The full closure was built before the new acceptance runs. Existing selected
consumer images were linked before their runs and are byte-identical to the
final build. Later auxiliary refinements were linked and frozen before their
own acceptance. The typed production Mojo implementation is unchanged from
its first successful build.

Retained history includes an initial pre-code manifest-literal typo;an oracle
that compared a fresh recovery against a corrupted fixture;mock enable-phase
selection errors;and synthetic-clock timestamps incorrectly used as real
pthread deadlines. The original mock now translates only the observed relative
join budget to the actual real clock and calls the real pthread join;it never
fabricates a join result. Backward timestamps are normalized across seconds.

One duplicate selected replay hit its600-second suite limit during method09;
the earlier same-image grouped suite passed all ten methods in533.249s. The
superseded whole-index collector hit1800 seconds during method08. The per-child
collector's superseded run passed all12 methods in1717.387s;the final run passed
in1553.584s. Partial/superseded runs are not counted as final acceptance.

The preserved old worker fixture twice differed between identical images at
its immediate procfs task-count assertion,including a single-CPU replay. A new
auxiliary consumer adds a bounded post-join census without editing that fixture
or the production worker. It passes all9 methods on the allowed CPUs. Its final
clock/late-result checks also pass the four independent refusal pairs. Initial
worker-audit thread classification wrongly included startup runtime-pool threads;
the corrected audit classifies callbacks and runtime threads separately. Every
failed/superseded source copy,build,run and diagnostic is retained.

`evidence/grouped-device-rpc-native-2026-10-24/archive-identities.json` pins
**52416 files/2478514275 aggregate bytes**,in7 pages
across33 immutable raw roots. Manifest SHA-256:
`2950a3d00f8690d71245f50def6bc7e50d7d7d631ecec325e893406eb46eef46`. Exact executed commands/scripts,copies,images,traces,
stdout/stderr and process outcomes are pinned. Publication review runs outside
the immutable roots;reruns require fresh output names.

Census becomes146 verified/191 total,29 partial,15 missing and one historical
noncanonical status. Nine inherited schema diagnostics and23757 drift findings
remain. No whole-repository or hosted-CI pass is claimed.

Continue a separately contracted,bounded physical grouped lifecycle,then actual
numerical configuration,packing,placement,original program/results and remaining
format/architecture/operation implementation. Broad ordinary UNMODIFIED source-
model support100% remains fixed. Aesir owns its Mojo loading,conversion,lowering,
device generation and execution;all eventual LLM execution stays Hailo-10H.
No DFC,outside model compiler/machine,vendor-precompiled prerequisite,CPU/CUDA/
cloud LLM inference or inference proxy is introduced.
