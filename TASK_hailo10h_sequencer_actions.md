# Original packed sequencer configuration and completion codec

Date:2026-10-23. Publish before production. Parent:
`TASK_hailo10h_numerical_encoding_sources.md`. Fixed broad owner scope:
`docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Field facts:`docs/HAILO10H_SEQUENCER_INTERFACE_2026-10-23.md`.

## Authorized slice

Add ONLY new `smidr/sequencer_actions.mojo`, a bounded diagnostic tool and
scoped tests. Zero old production edits. Implement original scalar/value
encode/decode for context trigger1 and completion17. A copyable/movable owned
value retains kind,timestamp,index and all eight configuration members.
Use unsigned64 storage with explicit narrower width validation; do not lose
high-bit bitmap or offset values. Completion requires zero absent fields.
Validate every mutable value before emitting bytes. Decoding requires exactly
49 or6 bytes and a qualified kind. The diagnostic CLI bounds hex and scalar
text before allocation/parsing and rejects malformed/negative/overflow input.
Caller-supplied timestamps remain explicit; the published initializer is a
known vector, never a discovered timing policy.

No protobuf conversion, guessed bitmap masks/resource limits, instruction
generation, register semantics, physical placement/address selection, raw OS
interface or device access. Reuse existing hex diagnostics where appropriate;
do not copy/translate external implementations. This codec accepts wire intent,
not hardware-safe configurations. Diagnostic tools must not become a user
model-conversion workflow. All LLM execution remains Hailo-10H only; broad
source support and unresolved numerical work remain required implementation.

## Freeze and independent gates

Before production freeze actual current Mojo/Python copies, compiler identity
and all126 existing native controls, then reverify against this published
contract. Keep all older evidence immutable. Build all new consumers and
selected existing context/LCU inspectors and ownership controls with their C++
header oracles. Freeze all linked entries and source inputs before acceptance.
The test-only oracle may instantiate the pinned licensed public declarations;
it must not link or invoke vendor runtime or numerical implementations.

Compare complete accepted bytes and round trips against independent Python
struct packing and C++ public-header object bytes. Check actual enum values,
packed sizes, member offsets and little-endian host condition. Cover zero,
maximum, asymmetric, seeded random, every walking bit of all fields, every
index, high-bit unsigned64 values, initial-offset/timestamp boundaries and
every truncation/trailing length. Refuse wrong kinds, narrow-width overflow,
nonzero absent fields and malformed CLI input. Direct API exercises mutable
fields, copied/moved values, byte/value independence, refusal followed by fresh
success and exact canonical recovery. No model/layer/attention forward.

Rerun both selected old context/LCU Python suites against clean builds; compare
all invoked old Mojo outputs with their frozen binaries, complete stdout,
stderr, exit and handled messages. Retain independent full outputs. Trace all
new consumer calls for device/network/ioctl/process/runtime effects; qualify
actual executable dependencies separately. Publish narrow observed bytes and
ownership only. Retain failures and scope any unrelated inherited gate errors.
Verify -> commit/publish Hailo -> verify exact remote tree/head -> fast-forward
main preserving owner work -> verify clean -> continue numerical/physical work.

Actual numerical encoding/configuration/packing/placement, original program
transport/activation/results/cleanup remain open. No DFC, outside compiler or
machine, vendor-precompiled prerequisite, host LLM forward, inference proxy,
guessed opcode/register/write, reset/rebind or firmware/kernel changes.
