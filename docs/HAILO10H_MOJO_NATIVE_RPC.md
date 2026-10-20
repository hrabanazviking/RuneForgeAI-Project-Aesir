# Independent native Mojo device RPC: physical round-trip

Date: 2026-10-19. Contract: `TASK_hailo10h_native_rpc_roundtrip.md`.

## Verified result

The native Mojo client physically creates a logical device, identifies it and
destroys it on this Pi's Hailo-10H. Three requests receive correlated typed
success replies. Each exchange earns one H2D and one D2H completion; each
2068-byte submission returns five descriptors. Identity reports protocol 2,
HAILO10H architecture 6 and firmware 5.3.0. No model or inference is requested.

The binary links Mojo runtime/system libraries and **does not link HailoRT**.
No Python bridge, service/proxy, catalog model, vendor-precompiled artifact,
CPU/CUDA/cloud LLM inference, firmware change, reset or rebinding is involved.
The already installed Linux driver and device firmware remain the hardware
interface. This verifies transport, not the source-model compiler.

## Ownership and protocol

`hailbru/soc_rpc.mojo` exposes `open_soc_rpc()` and movable `SocRpcClient`.
`exchange(frame, timeout_ms)` owns one request/reply pair. It checks the pinned
request status and bounded frame, prepares owned CPU message bytes, performs
explicit cache sync, enables only assigned interrupts **before** launch, posts
D2H before H2D and validates each exact descriptor count. No new request may
reuse pending storage.

A total monotonic deadline and maximum 32 IRQ snapshots bound each exchange's
userspace wait. Zero progress is not completion. The existing progress owner
requires both distinct directional completions and rejects error/inactive,
unowned, duplicate and impossible records. Only then may D2H sync for CPU and
copy its bytes. The padded frame decoder validates magic/body bounds; reply
message ID/action and status must match before a typed consumer parses it.

An admitted exchange failure closes its session through stop/join, channel
quiescence, mapping/list cleanup, driver-fd close and host-memory release.
Uncertain launch state stays armed through that cleanup. The single-threaded
Mojo owner and Movable-only resources prevent shared accidental copies; this
slice does not claim arbitrary concurrent client use.

`smidr/tools/soc_rpc_device.mojo` consumes create/identify/destroy. Zero logical
handles are valid and tracked by separate presence state. On an error with a
known handle and healthy transport it attempts bounded destroy; if transport
has already failed, it reports logical cleanup as unconfirmed rather than
inventing successful remote destruction. No claim is made that an unknown
handle after a corrupt create reply can be recovered. Published output omits
private identifiers and payloads.

## Physical verification

Five methods pass across **36 native child runs**, each with a ten-second
outer deadline:

- Eight fresh complete create/identify/destroy lifecycles, exact firmware/
  architecture, three correlated exchanges, three completions per direction,
  six real launch returns of five and full teardown.
- Six pre-create EIO faults: input CPU/device sync, output device sync,
  interrupt enable and each launch. After RX has actually posted, TX failure
  retains storage until channel/file cleanup. Fresh successful sessions follow.
- Two wrong positive launch-count faults are refused. These pre-effect fault
  returns are negative tests, never hardware-completion evidence.
- Missing TX after real RX posting: the test makes TX return five without
  executing that syscall. No create request reaches the device. The exchange
  times out internally, disables/joins, quiesces and cleans up; a fresh complete
  lifecycle succeeds afterward.
- Five errors after successful remote destroy: channel close, each unmap and
  each descriptor release. Cleanup retains host pages through fd finalization;
  every fault is followed by a fresh complete lifecycle.

Every ordinary run matches both owned allocations to exactly one host munmap
following actual driver-fd close. strace observes complete syscall/thread
records without dumping RPC bodies or weights. Wait snapshot counts can vary
because the two directions may complete separately or together.

Rebuilt regressions pass: assigned wait six methods/18 child runs; byte access
four methods/38 invocations; progress six methods/44 invocations; independent
protobuf ten methods. Subsequent supported identify succeeds after the entire
suite. Runtime dependencies and native/UAPI SHA-256 fingerprints are recorded.

Evidence: `evidence/native-rpc-2026-10-19`: `rpc-tests.txt`, complete
`physical-rpc-traces.jsonl`, wait-regression traces, targeted logs, build
records, dependencies, fingerprints and sanitized post-run identification.
Generic hosted CI retains its recorded unrelated legacy inference-test issue;
these passes are targeted native evidence, not full hosted-CI certification.

## Return to the compiler

This closes the independent read-only device RPC gate. The new active contract
is `TASK_hailo10h_source_compiler_plan.md`: source/tensor-to-plan connection,
actual operation lowering, numerical recipes, executable context/configuration
encoding, program upload/activation and numerical device proof. The historical
SMIDR-CFG vectors and COMPUTE_UNKNOWN descriptors remain non-executable. Broad
source-model execution remains the owner's target and is not yet achieved.
