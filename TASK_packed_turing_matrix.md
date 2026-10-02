# SPD-01/02 — optional original packed-weight Turing matrix projection

Established 2026-10-01. Volmarr authorizes successive scoped slices and pushes.
The physical public MMA prerequisite is published at e5e988c. Its exact CI is
pending independently; final publication claims require its actual conclusion.
No SIMT tuning candidate earns batch-four default dispatch. Build on the proven
explicit sm_75/PTX6.5 public F16/F32 m16n8k8 operation, preserving strict paths.

## Owned implementation and fixed gates

core/packed_turing_matrix.mojo owns an optional bounded Q4_K/Q5_K/Q6_K matrix
candidate, using existing packed_quantization equations and matrix span admission.
Each warp computes16 weight rows by8 token columns in F32 accumulation, with
bounded F16 conversion of original packed values and F32 activations. Warp-uniform
row/token tile admission and explicit zeros guard all tails. No full F16 model
copy, extra persistent device allocation, tensor/quant-format reinterpretation,
assembly fallback or library/driver/dependency patch. Existing scalar/block/four
projection kernels, batch-four control boundaries and default service stay intact.

Reuse the physical matrix harness through an explicit optional candidate selector
with existing SIMT defaults unchanged. New opt-in test_packed_turing_matrix.mojo
owns all three formats, widths256/512/3072/8192, row1/7/33 tails and batches4/8/16/32,
12 invalid metadata rejections, all1,658,880 real native-reference outputs and560
alternating paired timing records. Seven layer-zero actual Q/K/V/O/gate/up/down
shapes use the unchanged original model bytes and exact prior input formula.
The fixed primitive budgets remain scaled per-value<=0.002 and normalized
RMS<=0.0002, declared before implementation. Independent gguf0.19.0/NumPy2.4.4
Float64 dots cover five selected rows per tensor/batch (2100 outputs), separately
identified from complete native coverage. Failed budgets stay failures; do not
loosen them or claim whole-model quality from selected primitive outputs.

The checker admits a declared MMA mode marker and complete ordered CSV only;
SIMT/legacy defaults remain supported. Extend portable adversarial checks and
CI compile without a GPU claim. Test resident warmed original weights, exclude
allocation/export/printing from timing, and finish host compilation before final
scored captures. Retain all failures, raw CSVs and tool/source/binary identities
outside Git. Candidate must pass precision and every current batch-four shape
speed gate before considering broader integration; a loss stays optional.

Update owning INTERFACE/README_AI, operation/evidence, roadmap/ledger/TODO/DEVLOG,
rebuild launcher and verify unchanged production checksum/active readiness.
Push the reviewed slice and verify exact CI. Next choose measured kernel/layout
refinement if it loses, or separately scoped full-model precision/state/control/
restore/cancellation/provider gates if it wins. Never promote on compiler success
or a single primitive ratio.

## Precision refinement after the first physical rejection

The initial single-F16 weight conversion compiles and executes, but fails the
fixed synthetic per-value budget before real-shape timing. Preserve that failure.
Before implementing refinement, keep the same budgets and explicitly represent
each decoded weight by F16 high plus F16 residual (value-F32(high)), using two
public MMA calls per8-column step. Activation still converts once to F16; the
current exact binary test inputs are representable and broader full-model
activation-conversion quality remains open. No larger workspace or model copy.
Record the refined mode distinctly so evidence never describes the rejected
single-component path as passing.
