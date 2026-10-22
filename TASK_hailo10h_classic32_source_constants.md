# Original classic Q4/Q5 source constants and shared byte geometry

Date: 2026-10-22. Publish before production edits. Parent:
TASK_hailo10h_source_compiler_plan.md. Fixed scope:
docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md. Qualified fields:
docs/HAILO10H_CLASSIC32_SOURCE_LAYOUT.md. Q8_0 slice6673169 is verified.

## Original shared geometry and source import

Add an owned, implicitly copyable PackedBlockGeometry(elements:Int,bytes:Int)
and packed_block_geometry(kind:Int) in loader/packed_gguf.mojo. Its namespace
is GGUF only. Cover existing kinds0/1/30/8/12/13/14 and new2/3/6/7 from published
source facts. Unknown kinds refuse; no Hailo dtype cast or resource assertion.
Keep packed_row_bytes' public signature and width limits. New four kinds require
32-element row alignment. Preserve supported old geometry/diagnostics and the
old unknown-kind routing outside the explicitly newly implemented tags.

Have source_weight_tiles obtain block geometry from this shared helper, removing
its duplicated source-kind block selection. Preserve every live-owner, source/
schedule/binding/shape/span/workspace/host-byte guard and all existing output
fields. Copy complete touched source blocks with original row, prefix/suffix and
payload-offset arithmetic. Do not infer NPU precision, padding or placement.

## Original field reader API

Add smidr/source_classic32_constants.mojo with Classic32Constant fields
 d_bits:UInt16,m_bits:UInt16,d_binary32_bits:UInt32,m_binary32_bits:UInt32,
 bias_present:Bool,q:Int8. A movable Classic32ConstantWindow owns binding,first
and components. Public read_classic32_constants(source:PackedGGUF,name,first,
count,host_element_bound) infers actual kind and accepts exactly2/3/6/7.
Add an owned-path read_classic32_constant_window with the same window arguments.

Validate live source, exact admitted axes, kind, checked products, file/data
origin, complete source span, selection and explicit positive host bound before
payload access or requested component allocation. Reuse the original binary16
bit expander. Preserve every d/m word, including special values and signed zeros.
Absent m fields are unique zero words with bias_present=false. Present biases
retain bias_present=true even for zero words. Quant centering follows the
published field table; no production floating product/addition or model work.
Use original field descriptors/byte access, never translated vendor algorithms.

## Verification and intentional admission changes

Freeze all640 current Mojo identities,76 controls and63 old Python tests before
code. Rebuild the affected source/compiler consumer closure from one stable
snapshot. Preserve old source contents, negative evidence and concurrent work.
All old positive outputs for already-supported formats must remain identical.

New tags2/3/6/7 intentionally change source admission. Before altering any legacy
test, identify exact cases involving those GGUF tags (not safetensors' independent
tag namespace). Retain their original fixture identities and frozen refusals;
prove the new behavior with independent valid source bytes. Record any changed
refusal phase for a newly parsed tag as an explicit, narrowly keyed delta.
Do not globally skip negative comparisons or weaken unrelated guards. Preserve
negative coverage with genuinely unsupported tags where a former test used a
newly implemented tag solely as its unsupported sentinel. All other legacy
success/error outputs and original signatures remain preserved.

Independent writers must cover all quant values, nibble half boundaries, every
Q5 high-plane bit, special d/m words, original bias presence, block/row/final-byte
edges, vectors/matrices, names, truncation, overflow, source mutations, ownership
and recovery. Exercise actual source graph bindings and lazy byte-tile tails.
Use separately compiled pinned public-header size/offset objects and Python byte
packing. The pinned isolated ggml-base library may check only synthetic static
constants for these four types; CPU backend disabled, no model/context/graph or
forward APIs, and no external production dependency. No host LLM execution.

Record complete comparisons versus any digest coverage separately. Syscall
audits must join PID-scoped unfinished/resumed records and verify read-only
whole-fixture maps (including payload), matched close/unmap, unchanged source
bytes and zero device/network/ioctl/inference-runtime access. Use distinct
runner-status and test-report paths to preserve all transcripts. Freeze all
build/test/audit inputs, keep failed runs and compare final identities.

Verify, commit, publish, verify remote, fast-forward main and continue the next
slice automatically. No owner action required. Numerical H10H instruction/
register/packing/placement, original program delivery/activation/results/cleanup
remain open. Continue bounded license-first physical-interface research alongside
source coverage. No guessed device write, reset/rebind/kernel/firmware change,
DFC/outside compiler/machine, precompiled prerequisite or inference proxy.
The full broad ordinary-model target remains100%; other coverage stays work.
