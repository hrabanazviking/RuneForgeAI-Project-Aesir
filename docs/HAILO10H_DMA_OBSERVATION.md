# Read-only reference DMA observation

Completed 2026-10-19 under `TASK_hailo10h_dma_observation.md`, acceptance
slices 1–3. This is a bounded observation of the installed reference runtime,
not the independent Mojo RPC client or a model execution result.

An independently authored test-only `tests/hailo_dma_observer.c` includes the
operator's installed UAPI and observes ioctl parameters in a private
`hailortcli fw-control identify` child. It forwards the original ioctl, result
and errno. It records paired calls, fixed outgoing RPC headers and bounded
interface fields; it never dumps a model, weights, arbitrary memory, reply
identity payload or software implementation. No observer is installed into
any service, global environment or production runtime. Existing evidence
paths are refused atomically before the first ioctl is forwarded.

## Established facts for this installed profile

The final reference child exits successfully, stderr empty. The checker pairs
all 548 observed calls with their actual returns and validates ownership and
cleanup across 258 buffer maps/unmaps. Firmware/architecture identification
succeeds; the observer's host page size is 16384 and launch ABI size is 141.

| Interface fact | Observed value / interpretation |
|---|---|
| Session port / channels | 12133; assigned H2D 0, D2H 16 |
| Descriptor lists | Two circular 65536-entry lists, 512-byte descriptor pages |
| Message transfers | Exactly **2068 bytes**, one user-pointer buffer per submission, engine zero |
| Host pointer alignment | Every observed message/map pointer is aligned to the actual 16384-byte host page |
| Transfer mode | `is_cyclic=false` with pre-mapped buffers in this runtime |
| Successful transfer ioctl result | **5**, the descriptors consumed: ceiling(2068 / 512); nonzero is not an error |
| Request envelope | Little-endian magic `0x8A554432`, status **1** (`HAILO_UNINITIALIZED`) |
| Outgoing control actions | 20 create, 33 notification registration twice, 22 identify, 21 destroy; message IDs 0–4 |
| Completion | Five H2D and five D2H one-transfer completion records; one additional D2H receive remains outstanding at shutdown |
| Shutdown | Owned interrupt mask disabled, connection close succeeds, all mapped buffers are unmapped, descriptors released |
| Unmap identity | Original address/size/direction/type tuple, **not** the output mapping handle |
| Explicit sync ioctl | None observed; this alone does **not** prove a portable cache-coherence policy |

This resolves the nominal-size ambiguity for the observed 5.3.0 integrated
RPC path: 2068 is actually submitted. The older low-level multiple-of-eight
documentation does not describe these observed message submissions. Do not
invent 2072-byte padding or another transfer pattern to reconcile it. This
finding is scoped to this profile and still needs the independent Mojo gate.

Pinned MIT HailoRT `client.cpp` corroborates request status initialization
and whole message-buffer submission. The installed status declaration assigns
`HAILO_UNINITIALIZED=1`. Installed driver interface study corroborates the
positive descriptor-count result and unmap tuple lookup. These are recorded
interface facts; no vendor implementation was copied/translated.

## Verification and discovery corrections

```sh
gcc -std=c11 -shared -fPIC -Wall -Wextra -Werror -I "$HAILO_DRIVER_UAPI" \
  tests/hailo_dma_observer.c -o work/hailo-dma-observer.so -ldl -pthread
timeout 10s env LD_PRELOAD=work/hailo-dma-observer.so \
  AESIR_DMA_TRACE=work/new-identify-trace.jsonl hailortcli fw-control identify
python3 tests/check_hailo_dma_observation.py work/new-identify-trace.jsonl
python3 tests/test_hailo_dma_observation.py --trace work/new-identify-trace.jsonl -v
```

The native observer build passes. The strict checker passes on the actual
trace, and all eight adversarial checker methods pass. Missing/duplicate calls,
2072-byte guessed padding, zero transfer return, wrong channel/descriptor,
wrong unmap tuple, zero request status, IRQ error and failed ioctls reject.
An attempted second observation into the same path exits 126 and leaves every
existing byte unchanged. Subsequent uninstrumented identify and the independent
Mojo descriptor/connection lifecycle both succeed.

An earlier observation's checker failed because it tried to pair unmaps by
the output-only map handle. Interface study corrected the interpretation and
the observer now records the actual unmap tuple. The earlier raw records are
retained as discovery history, not claimed as final acceptance. Operational
stdout excerpts omit device identifiers; original stdout hashes are retained.
Instrumented timing is not a submission-overhead performance measurement.

## Required next implementation

Before a live Mojo transfer:

1. Correct the low-level request result handler: preserve successful positive
   transfer counts; keep negative errno failures distinct. Its current
   nonzero-error rule would reject a successful launch.
2. Emit request status 1 in typed requests; reply status 0 still means success.
3. Add independently checked buffer map/unmap/sync codecs and owned storage.
   Derive cache visibility from the driver contract and prove it; absence of
   sync in the reference trace does not authorize a generic no-op.
4. Prove bounded interrupt waiting, cancellation, waiter shutdown and buffer
   lifetime, then the actual correlated Mojo create/identify/destroy exchange.

The uploaded compiler ideas remain candidates toward the fixed broad target.
This control observation does not solve executable contexts, dynamic weight
legality, numerical fidelity, source lowering or model coverage. Those gaps
remain work rather than a change to the target.

[Receipt](evidence/dma-reference-observation-2026-10-19/receipt.json),
[checked summary](evidence/dma-reference-observation-2026-10-19/summary.json),
[final raw trace](evidence/dma-reference-observation-2026-10-19/final.jsonl),
[checker tests](evidence/dma-reference-observation-2026-10-19/tests.txt).
