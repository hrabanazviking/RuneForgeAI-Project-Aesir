# Original Q8_0 source representation and byte-tile integration

Date:2026-10-22. Publish before production edits. Parents:
TASK_hailo10h_source_compiler_plan.md and TASK_hailo10h_numerical_encoding_sources.md.
Fixed owner scope:docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md. Broad ordinary
unmodified source-model support stays100% the target; all LLM execution Hailo-only.

The current PackedGGUF rejects Q8_0. Add its source representation to the owned
compiler path using original Mojo and published field facts in
 docs/HAILO10H_Q8_SOURCE_LAYOUT.md. No outside implementation is copied/translated.
This is source conversion/importer work,not device INT8 arithmetic admission.

## API and existing consumer integration

Add kind8 to packed_row_bytes after float-kind branches and before K-block
alignment checks:columns positive<=1048576,divisible32,result=(columns//32)*34.
Keep all old kind geometry/diagnostics unchanged,including unimplemented kinds.
The existing constructor still owns/parses/maps and validates complete tensor
ranges. New kind8 source storage/bindings retain exact GGUF axes/kind/path/extents;
no dtype namespace cast or backend registry decision. Existing source_storage
uses this shared arithmetic; prove it through actual headers and bounded plans.

Add smidr/source_q8_constants.mojo with Q8Constant fields d_bits:UInt16,
d_binary32_bits:UInt32,q:Int8, and movable Q8ConstantWindow(binding,first,
components). APIs read_q8_constants(source:PackedGGUF,name,first,count,
host_element_bound) and owned-path read_q8_constant_window(path,name,first,
count,host_element_bound). Validate live owner,kind8,exact original shape,
checked element/byte products,data origin/file extent,selection and explicit
positive count/bound before allocation/byte access. Preserve every scale word,
including signed zero,subnormal,infinity and NaN payload; reuse the already
verified original binary16 bit expander. Decode signed quant bytes exactly.
No floating product is evaluated by the production reader. Source expression
remains scale*quant intent for future compilation. No model/layer forward runs.

Update source_weight_tiles' block selection only for actual kind8 to32elements/
34bytes. All bounds,live binding/axes,span validation,host byte limit and owned
payload behavior stay active. Do not let the prior scalar fallback interpret
Q8_0 as two bytes/element. Across row/block/tile tails copy only whole touched
source blocks and preserve covered-column/prefix/suffix accounting. No target
packing or physical memory address is inferred from source file spans.

## Acceptance before publication

Freeze all637 current Mojo source identities and74 existing controls plus old
Python tests before edits; retain all earlier source/binary/negative evidence.
New independent GGUF writer covers vectors/matrices,all256 quant byte values,
scale-word special cases,block/row/tile boundaries and tiny static constant
reference checks through the pinned isolated ggml-base oracle(CPU backend off).
The only external callable is the static Q8_0 constant decoder; no graph,context,
model,CPU backend or forward API. No external production dependency is added.
A separate bounded test probe may digest synthetic component words across all
65536 binary16 scale patterns with an independent Python bit oracle. Production
must still expose only bounded windows,never allocate by a full model size.

Verify returned ownership after source destruction,mutable descriptor/closed/
shape/span/kind/bound refusals and fresh success. Direct lazy matrix schedules
and actual source graph metadata prove new byte-span handling; use only
structure/constant/index checks,no numerical layer/attention/model evaluation.
Syscall traces pin read-only fixture mapping,balanced close/unmap,unchanged
fixture bytes and zero device/network/ioctl/inference-runtime access. Whole-file
GGUF mmap is expected and must be reported honestly,not header-only access.

Rebuild the affected existing native consumer closure from one stable snapshot
and pair existing accepted stdout/error outputs against current frozen controls;
run only targeted source/compiler/control suites,never historical master/E-REAL.
Record any intentional newly accepted Q8 cases separately from legacy stability.
Keep all diagnostics/failures and exact source/input/binary identities. Verify,
commit,publish to docs/cross-cutting-hailo-mission,verify remote,FFmain,continue.

Numerical H10H precision/packing/placement,CCW/register/LCU instruction fields,
original upload/activation/results/cleanup remain open. Continue bounded
license-first primary research in parallel. No guessed device request,kernel/
firmware/reset/rebind,DFC,outside compiler/machine,precompiled prerequisite,
inference proxy or CPU/CUDA/cloud LLM inference is introduced.

## Verified source conversion checkpoint

docs/HAILO10H_MOJO_Q8_SOURCE_CONSTANTS.md records76 clean Mojo builds and
30 suites/200 methods/9309 primary child calls. New10/137 includes actual
Q8_0 source fields,graph bindings and byte tiles;74 frozen controls remain
covered. Digest coverage,complete comparisons,static oracle values and extra
context rerun are explicitly separated. No numerical Hailo/source-model
execution is claimed. Continue source-format/architecture coverage and
TASK_hailo10h_numerical_encoding_sources.md toward the same broad target.
