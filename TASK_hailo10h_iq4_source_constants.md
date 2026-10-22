# Original nonlinear IQ4 source components

Date: 2026-10-22. Publish before production edits. Parent:
TASK_hailo10h_source_compiler_plan.md. Fixed scope:
docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md. Q2_K/Q3_K native slice is verified
and published4d16930. Qualified nonlinear fields:
docs/HAILO10H_IQ4_SOURCE_LAYOUT.md. No numerical Hailo/source-model claim.

## Exact native implementation contract

Add GGUF20 IQ4_NL geometry32 elements/18 bytes and GGUF23 IQ4_XS geometry256/136
to packed_block_geometry. Preserve old geometries, width limits, signatures and
unrelated diagnostic routing. Add an explicit32-element IQ4_NL row path with
its own alignment diagnostic; do not route it through the256-element K fallback.
The existing source_weight_tiles consumer must use shared geometry without a
duplicate kind dispatch. Preserve every owner/schedule/span/bound guard.

Add original smidr/source_iq4_constants.mojo with implicitly copyable/movable
IQ4Constant: d_bits:UInt16, d_binary32_bits:UInt32, group_scale_present:Bool,
scale:Int8, code:UInt8 and q:Int8. IQ4_NL has absent group scale with scale=1;
IQ4_XS has present signed scale-32..31. Preserve original code0..15 separately
from its published nonlinear signed source value q. Preserve every scale word,
expanded representation, signed zero and special pattern. No production
floating product or model evaluation. The public16-value table is source-format
data; attribute its pinned MIT public definition and retain the license. Do not
copy/translate any external implementation algorithm or runtime dependency.

A movable IQ4ConstantWindow owns SourceTensorBinding, first:Int and components.
Public read_iq4_constants(source:PackedGGUF,name:String,first:Int,count:Int,
host_element_bound:Int) infers exactly20/23; add read_iq4_constant_window for an
owned path. Reuse original binary16 bit expansion. Check live mapped owner,
exact axes/kind, checked products, full source/data-origin/tensor span, selection
and host bound before requested allocation/payload. File offsets are not NPU
addresses. Use original bit access from the qualified field contract.

## Verification, controls and continuation

Before code646 source hashes/actual snapshots,100 current binary controls and65
Python identities are preserved and verified. Inventory actual affected safe
compiler/metadata entrypoints and tests, including the full source-storage suite;
exclude CPU/CUDA/model/historical/master execution. Freeze actual Python contents
before changing any input. Identify newly admitted20/23 cases by GGUF namespace;
retain every original case and narrowly record any intentional admission delta.
Metadata types, safetensors dtypes and device/control enums stay separate.

Independent source writers must cover every packed quant/scale bit, all16
nonlinear codes, signed group extremes, word specials, lane16/32/256 and
block/row/final-byte boundaries, vectors/matrices, Unicode/NUL names, malformed
ranges/truncation/overflow, bounds, live/schedule mutations, copied ownership and
recovery. Exercise actual source compiler graph bindings and lazy byte-tile tails.
Use separately compiled pinned public-header objects and tiny isolated static
constant functions only; no external model/context/graph/forward API or host LLM.

Rebuild the actual safe closure from stable inputs. Pair complete old success
stdout and nonzero exit/stdout/handled errors by actual source identity. Classify
API requests separately from ldd dependency inspection; direct and strace-wrapped
API calls must all remain paired. Inspect dependencies on both sides separately.
No unrelated native comparison skip. Preserve all failure attempts and identities.
PID-aware unfinished/resumed trace joins must accept normal whitespace; prove
unchanged fixture bytes, matched read-only whole mappings and cleanup, and no
target-device/network/ioctl/inference-runtime access. Derive actual trace counts.
Keep runner status/report names distinct. Record test-only amendments explicitly.

Verify, commit/publish Hailo branch, read remote head/tree, fast-forward main and
verify both clean checkouts;continue automatically. If multiple local commits
represent a single connector-published equivalent tree, preserve their history
and compare complete trees before reconciling checkout ancestry. No owner prompt.
Numerical ISA/register/configuration, precision/packing/placement, valid original
program delivery/activation/results/cleanup and broad model execution remain
required work alongside remaining source/architecture/operation implementation.
No DFC/outside compiler or machine/precompiled prerequisite/proxy, guessed device
write, reset/rebind or kernel/firmware change. All LLM execution stays on Hailo-10H;
missing coverage never narrows the fixed broad target.
