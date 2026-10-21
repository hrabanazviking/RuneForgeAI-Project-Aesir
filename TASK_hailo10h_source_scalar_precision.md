# Ordinary source scalar precision through native mathematical lowering

Date:2026-10-21. Active child:TASK_hailo10h_ordinary_rotary_modifiers.md.
Owner scope remains docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md. Explicit rotary
lowering is published on both branches2c320f4,104 methods/2864 calls. Continue
this slice automatically; broad source support remains the fixed target.

## Concrete boundary found

SourceDecoderArchitecture.scalars retains Float64 values and raw config fields.
DenseDecoderParameters/SemanticPlan use Float32 rms_epsilon/rope_base; recipes and
expanded operations retain UInt32 epsilon/base words. The pinned ordinary source
rms_norm_eps=0.000001 has binary64 word4517329193108106637; its binary32 projection
897988541 is9.999999974752427e-7. Theta5000000 is exactly preserved by binary32.
This is a source representation audit, not a source-model numerical result or
hardware precision policy. The exact untouched config identity and observed words
are recorded in docs/evidence/ordinary-scalar-boundary-2026-10-21/.

## Next bounded design and implementation

Read current scalar, ordinary projection, primitive, expanded and storage owners.
Publish an exact API/ownership/bounds/compatibility contract before code. Preserve
source scalar words, source representation and provenance through the typed
mathematical plan and every affected recipe/expanded consumer. Do not silently
narrow an ordinary value through a legacy compatibility field, and do not make
exact Float32 representability a permanent model eligibility rule. Initial formats
and unsupported modifiers remain implementation work toward the broad target.

Distinguish source logical constants, explicitly requested internal conversion
and actual device arithmetic/approximation. Unknown Hailo precision must remain
an open gate. No Float64 device arithmetic claim follows from retaining a source
word. Old GGUF/default APIs and complete inspector outputs must stay unchanged;
source-derived adapters must retain all raw fields/qualified origins and unresolved
scaling/window/activation/cache/training semantics. Carry checks through source
and derived ownership, policy limits, malformed tags/words/finite-positive values,
source consistency and exact metadata propagation. Rebuild all affected consumers,
compare complete frozen outputs and use only isolated constant/primitive oracles.

No model/layer/attention forward, CPU/CUDA/cloud inference, external compiler/DFC,
user conversion, vendor artifact or external machine prerequisite. Host parsing,
Aesir-owned compiler constant conversion and orchestration remain permitted.
After verify/publish/remote-head checks continue full ordinary modifier/graph
integration and actual Hailo numerical instruction/register/configuration,
packing/placement/upload/activation/results/cleanup automatically. Do not invent
opcodes or count source words/host IR as numerical device execution.
