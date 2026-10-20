# Original program metadata and lifecycle RPC codec

Date: 2026-10-20. Contract before implementation.
Parent: `TASK_hailo10h_program_delivery.md`.
Published wire/interface facts: `docs/HAILO10H_PROGRAM_DELIVERY_BOUNDARY.md`.

Consumer: the future HAILBRÚ original-program delivery owner, receiving compiled
output from SMIÐR. Implement pure owned Mojo protobuf/HrpcFrame construction
for create-infer-model metadata (action 2) with explicit positive declared
program bytes and caller-supplied host bound, virtual-device handle and name.
Return no borrowed source/program bytes; this metadata does not transmit the
separate buffer. Implement typed handle-only lifecycle requests and success
reply checks for destroy-infer (3), destroy-configured (5), activate (10),
deactivate (11), shutdown (12); parse action-2 handle reply with correlation,
status, duplicate/wire/bounds checks. Zero handles remain representable; the
published all-ones invalid sentinel rejects. No configure/run request yet:
those require additional stream/numerical/ownership acceptance.

Reuse the project's existing protobuf reader/checks, preserving old device
codec behavior. Check UTF-8 byte lengths/body limit before copying name data,
u64 size boundaries, explicit host bound, default/present nesting, unknown
valid fields, malformed replies and independent ownership. Compare complete
wire bytes with independent Python generated protobuf from the frozen public
schema and enum values with a public-header test oracle if buildable. External
source/license/dependency facts must be recorded before oracle use. Rebuild
and run existing device codec regressions if shared code changes.

Acceptance is host wire correctness only. No device open or driver/firmware
write, no actual program upload/activation, no vendor compiled-container
inspection and no model/CPU/CUDA/cloud/proxy inference. A future physical owner
must bind declared length to actual immutable original program bytes, own
virtual/infer/configured handles, enforce deadlines/cleanup and independently
establish valid numerical CCWs, metadata, resources and first hardware result.
Keep these gates explicit, publish the verified slice, then advance toward the
same fixed owner objective without another continuation request.
