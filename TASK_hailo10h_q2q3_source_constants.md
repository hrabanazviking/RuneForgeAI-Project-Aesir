# Original Q2_K/Q3_K source components

Date: 2026-10-22. Publish before production edits. Parent:
TASK_hailo10h_source_compiler_plan.md. Fixed owner scope:
docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md. Prior classic32 implementation
is verified and published at d6dfd7d. Qualified fields:
docs/HAILO10H_Q2Q3_SOURCE_LAYOUT.md.

## Original importer and component reader

Add GGUF source kinds 10/11 to packed_block_geometry in loader/packed_gguf.mojo:
256 elements and 84/110 bytes per block. Preserve packed_row_bytes' signature,
width limits, 256-element alignment and unrelated diagnostics. Keep all existing
geometry unchanged. The shared source_weight_tiles consumer must use this
geometry without a duplicate dtype dispatch or any new device packing claim.
Preserve its source, schedule, ownership, span and host-bound checks.

Add original smidr/source_q2q3_constants.mojo. Define implicitly copyable
Q2Q3Constant with d_bits,dmin_bits:UInt16; d_binary32_bits,dmin_binary32_bits:UInt32;
minimum_present:Bool; scale:Int8; minimum:UInt8; q:Int8. A movable
Q2Q3ConstantWindow owns binding:SourceTensorBinding, first:Int and components.
Public read_q2q3_constants(source:PackedGGUF,name:String,first:Int,count:Int,
host_element_bound:Int) infers the actual source kind, accepting exactly10/11.
Add the corresponding owned-path read_q2q3_constant_window API.

Q2_K preserves scale/minimum0..15 and quant0..3. Q3_K preserves signed scale
-32..31 and quant-4..3; its absent minimum is uniquely zero with presence=false.
Preserve every super-scale binary16 word, expanded representation and presence,
including special values and signed zeros. Reuse the original binary16 bit
expander. Use original descriptors/bit access, not an external algorithm copied
or translated into Mojo. No production floating product/subtraction or model work.

Validate live owner, exact admitted axes/kind, checked products, complete
file/data-origin/tensor spans, selection and explicit host bounds before payload
access or requested component allocation. File offsets are never NPU addresses.

## Verification and admission changes

Before code, freeze all643 Mojo identities,81 current native controls and64
Python test identities, with actual source snapshots preserved. Inventory every
affected consumer and its test entrypoints; do not assume an inherited runner
covers the closure. Include the full actual source-storage inspector/API and
its seven-method namespace/arithmetic/mutation/ownership suite. Identify tools
by source path, not ambiguous binary nicknames. Preserve all old inputs/results.

Build the affected closure from stable sources; compare complete old success
stdout and nonzero exit/stdout/handled errors against controls. Before changing
any old test, identify exact cases using newly admitted GGUF10/11, separately
from safetensors or control/device namespaces. Retain original cases/refusals,
prove new admission with independent valid source bytes, and record narrowly
keyed intentional deltas. No unrelated comparison may be skipped.

Independent writers must cover every quant/scale/minimum bit and group,
lanes16/32/128/256, special super-scale words, block/row/final-byte edges,
vectors/matrices, original names, truncation, overflow, malformed ranges,
explicit host bounds, live/schedule mutations, owned copies and recovery.
Exercise actual compiler graph bindings and lazy byte-tile tails. Separately
compiled pinned public-header objects and isolated static constant decoders
may check synthetic source representation; no model/context/graph/forward API
from an external inference library, host LLM or external production dependency.

Use PID-aware unfinished/resumed syscall joins with normal whitespace handling.
Prove unchanged fixture bytes, matched read-only whole-fixture mappings and
close/unmap, and zero target-device/network/ioctl/inference-runtime access in
native production traces. Derive the trace-file census from actual runs rather
than an assumed count. Keep distinct runner status/report paths. Freeze all
build/test/audit inputs, retain failures and verify final identities.

Verify, commit, publish the Hailo branch, read back the remote head, fast-forward
main, verify both checkouts and continue automatically. No owner action needed.
Numerical H10H instructions/registers/configuration, precision/packing/placement,
valid original program delivery/activation/results/cleanup and broad source-model
execution remain open. Continue bounded license-first physical-interface research.
No guessed device write, reset/rebind/kernel/firmware change, DFC, outside model
compiler/machine, precompiled prerequisite or inference proxy. All LLM execution
stays on Hailo-10H. Missing coverage remains implementation work toward100% of
the broad ordinary unmodified model target.
