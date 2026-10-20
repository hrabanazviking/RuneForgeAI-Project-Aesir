# Native ordinary safetensors static weight windows

Date: 2026-10-20. Contract before implementation.
Parent: `TASK_hailo10h_safetensors_inventory.md`.
Scope: `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Facts: `docs/HAILO10H_SAFETENSORS_SOURCE_FACTS.md` and existing published
`docs/HAILO10H_MOJO_SOURCE_FLOAT_CONSTANTS.md` representation contracts.

Connect the repaired existing source owner to bounded static F32/F16/BF16
constant windows for the original SMIÐR compiler. Retain the ordinary tensor
name, source dtype namespace, all shape axes, checked element count/file span,
requested first/count, raw source representation words and exact binary32
representation words in independent owned values. Reuse the original Aesir
binary16 bit expansion and BF16 integer shift, never external code. F32 words
must retain all NaN/sign/zero/payload bits. Do not evaluate any model/layer/
attention, activation or matrix product; static source representation conversion
is host compiler work. Do not call the historical FP16 tensor-load routines.

Require all existing positive source parse/work policies and a separate positive
window element bound before output allocation. Use subtraction-based element
and source byte checks before mapping reads. Handle scalar and empty shapes,
including valid zero-length windows, without inventing nonempty data. The owner
must be live for all reads; the path wrapper must close on success/error, and
returned values must survive its destruction. Do not assume immutable source
identity against concurrent external file mutation; establish that separately.

Verify exact raw/expanded words using independent tiny and exhaustive 16-bit
synthetic fixtures, F32 special/payload patterns, arbitrary-rank flat row-major
windows, empty/scalar/tails, all bounds, ownership and read-only traces. Preserve
all results and run targeted reader regression. No model download, special user
conversion, external model/hash runtime, outside compiler or device access.
Initial three-dtype representation coverage is incremental; integer/sub-byte/
quantized/sharded/config/architecture mapping and actual Hailo numerical lowering,
precision/packing/placement/upload/activation/results remain required toward
broad ordinary-model support. Publish verified narrow progress and continue
actual compiler/transport dependencies automatically.
