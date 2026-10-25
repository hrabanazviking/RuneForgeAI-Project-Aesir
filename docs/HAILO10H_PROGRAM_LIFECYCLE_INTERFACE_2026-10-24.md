# Program resource lifecycle — interface qualification (2026-10-24)

Roadmap Campaign 3, slice 3.1. **Specification only — no code, no
physical run.** Each roadmap question is answered ESTABLISHED (with
its source) or NOT ESTABLISHED. Sources: the pinned-source study
`docs/HAILO10H_PROGRAM_DELIVERY_BOUNDARY.md` (HailoRT
`d503417f2a0db186a838390fb08690c4ea0f415e`, MIT; drivers
`45e5fc53`, v5.3.0 — interface facts only, no implementation copied),
the repo's own host-qualified codecs (`hailbru/hrpc_program.mojo`,
`hailbru/hrpc_configure.mojo`, `hailbru/hrpc_device.mojo`), the
AES-CONTROL-008/-009 sealed two-part work, and the Campaign 2
primitive (AES-TRANSFER-001..004).

## Q1 — The creation request that allocates the remote resource

**ESTABLISHED.** hRPC **action 2, create-infer-model**, over the
grouped control transport. Protobuf metadata (never the program
bytes): field 1 = nested virtual-device handle (scalar id at nested
field 1, u32); field 2 = declared compiled-program byte count (u64);
field 3 = UTF-8 program name. The receiver reads the declared byte
count, then the separate program buffer (Q2), then calls its local
create-infer-model. Reply: field 1 = the new **infer-model handle**
(same nested form). The all-ones handle is the published invalid
sentinel and must be rejected. Aesir's codec exists and is
host-qualified: `program_create_request(message_id, vdevice_handle,
program_bytes, name, host_program_limit)` — the host limit is an
explicit Aesir-side bound, neither memory discovery nor a device
admission rule. The virtual-device handle this consumes is the one
the Campaign 1/2 control lifecycle creates (device CREATE, action
20 — physically exercised in AES-CONTROL-018 and AES-TRANSFER-004).

## Q2 — The payload-transfer phase

**PARTIALLY ESTABLISHED.** Established: the program bytes are a
**separate phase** — they do not ride inside the 2048-byte protobuf
body; the receiver reads exactly the declared byte count after the
action-2 metadata. Aesir's own staged form is the AES-CONTROL-008/009
**two-part payload**: control metadata and program bytes in distinct
backings, whose two-part USERPTR driver mappings are already
physically verified (including physical children) — as mappings,
not as a program delivery.
**NOT ESTABLISHED:** the exact transport mechanics of the separate
phase on this control connection — whether the receiver pulls the
bytes over the same grouped DMA path as a follow-on transfer, what
buffer/handle the phase names, and how a byte count larger than one
storage extent is presented. No chunk-size or single-buffer
assumption is admitted (the roadmap forbids both). Slice 3.2's host
implementation must therefore treat the transfer phase as a distinct
owned stage whose wire mechanics are pinned by its own contract —
and 3.3's physical contract may need a Lane E question of its own
before any program byte moves.

## Q3 — Offset/chunk representation

**NOT ESTABLISHED** for the program payload phase (see Q2). What is
established is only the control transport's own representation
(Campaign 2, S1): grouped USERPTR spans `(address, size)`, span
map-offsets divisible by the descriptor page, descriptor counts
returned per launch. Whether the program phase reuses span offsets,
a stream with no offsets, or something else is exactly what Q2
leaves open.

## Q4 — Completion and readiness signals

**ESTABLISHED at the interface level.** Each lifecycle stage is a
request/reply exchange on the control transport: completion of a
stage is its typed reply under the Campaign 2 completion law
(distinct directional completions, exact id/action, status 0).
There is no separate readiness poll in the published interface:
**readiness to execute is a distinct stage** — action 4,
create-configured-infer-model (Q5) — whose reply (configured handle
+ async queue size) is the readiness artifact. Whether the device
signals any asynchronous readiness beyond that reply is NOT
ESTABLISHED and is not assumed.

## Q5 — Finalization

**ESTABLISHED.** hRPC **action 4, create-configured-infer-model**
is the finalize/configure step. Request (Aesir codec
`hailbru/hrpc_configure.mojo`, host-qualified): the infer-model
handle + virtual-device handle, requested input/output stream
formats, batch size, power mode, latency flags, KV-cache enable.
The receiver applies the settings, calls configure, and replies
with the **configured handle** and **async queue size**. A
structurally valid program must therefore also carry valid
stream/network/architecture metadata for this stage to accept it —
a Campaign 4/5 concern, recorded here as an interface fact.

## Q6 — Teardown of partially created objects

**PARTIALLY ESTABLISHED.** The teardown actions exist and their
codecs are host-qualified, all handle-only requests with empty
replies: **action 3** destroy-infer-model, **action 5**
destroy-configured, **action 12** shutdown (configured),
**action 11** deactivate, **action 10** activate. **NOT
ESTABLISHED:** the required ordering and preconditions among them
for partial states — e.g. whether a configured object must be shut
down before its infer model may be destroyed, what the receiver
does when destroy is called on an infer model with live configured
children, and which failures leave server-side residue. Slice 3.4
contracts and host-tests partial-creation teardown against the
mock; the physical preconditions remain a Lane E question, never
an assumption baked into 3.2.

## Q7 — The handle used later for activation/configuration

**ESTABLISHED.** Two handle tiers, never interchangeable: the
**infer-model handle** (from action 2's reply) is consumed by
configure (action 4) and destroy-infer (action 3); the
**configured handle** (from action 4's reply) is what activate
(10), deactivate (11), shutdown (12) and destroy-configured (5)
operate on. Both are server-owned u32 handles in the nested
protobuf form; the all-ones value is the invalid sentinel.

## The lifecycle, as qualified

```
device CREATE (20) ──► vdevice handle            [physically exercised]
        │
action 2 create-infer-model (metadata) ──► infer handle
        │  + separate program-bytes phase        [mechanics NOT ESTABLISHED]
action 4 configure ──► configured handle + queue size
action 10/11 activate / deactivate               [configured handle]
action 12 shutdown, action 5 destroy-configured  [ordering NOT ESTABLISHED]
action 3 destroy-infer-model                     [infer handle]
device DESTROY (21)                              [Campaign 1: unproven physically]
```

## What 3.2 may build on

The host implementation (slice 3.2) is a program-object lifecycle
in Mojo over the Campaign 2 primitive, carrying the roadmap's
`ProgramIdentity` record (source digest, compiler version,
target-profile digest, numerical-plan digest, placement digest,
encoded-program digest, transport-metadata digest), printable
before any physical run. It may embody Q1/Q4/Q5/Q7 as established
and must model Q2's transfer phase and Q6's teardown ordering as
explicit, fail-closed stages — never as convenient defaults.

## NOT ESTABLISHED (summary, binding on later slices)

- Program-bytes phase transport mechanics and chunk/offset
  representation (Q2/Q3).
- Teardown ordering/preconditions for partial states (Q6).
- Any asynchronous readiness signal beyond the action-4 reply (Q4).
- Everything numerical: CCW semantics, configuration values,
  placement, activation effects on arithmetic. This spec is a
  resource-lifecycle interface, not execution.
