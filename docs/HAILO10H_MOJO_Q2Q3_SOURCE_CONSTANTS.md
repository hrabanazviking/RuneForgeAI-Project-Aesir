# Original Mojo Q2_K/Q3_K source components

Date: 2026-10-22. Pre-code contract: TASK_hailo10h_q2q3_source_constants.md,
published at `5ec7420`. Qualified fields: HAILO10H_Q2Q3_SOURCE_LAYOUT.md.
The full broad ordinary, unmodified source-model target remains unchanged.

## Implementation

The packed GGUF loader adds source tags10/11: Q2_K has256 elements/84 bytes,
Q3_K256/110. Existing formats, row limits, alignment and unrelated diagnostic
routing remain unchanged. The existing lazy source-weight tile reader uses the
shared geometry; it needs no duplicate format dispatch or production edit.

Original source_q2q3_constants APIs return owned bounded windows containing
d/dmin binary16 words and exact expanded binary32 representations, explicit
minimum presence, group scale/minimum and quant fields. Q2 preserves unsigned
scale/minimum0..15 and quant0..3; Q3 preserves signed scale-32..31 and quant-4..3,
with absent minimum uniquely zero. Signed zeros, special words and absent versus
present-zero fields stay distinct. Production computes no floating product or
subtraction. Live owner, exact axes/kind, checked arithmetic, data origin/full
span, selection and explicit host bound are checked before requested component
allocation and payload field access.

These are source-format components and file offsets. Actual device precision,
packing, placement, instruction/configuration generation and numerical execution
remain open. Dense vector/matrix import is the current boundary; other formats,
ranks, architectures and operations remain implementation work toward100% of
the same broad target.

## Verified acceptance

| Gate | Recorded result |
|---|---|
| Native builds | 100 current Mojo entrypoints plus17 late pre-code-snapshot controls;117 builds with zero diagnostics.646 exact current source identities and actual snapshots. |
| Targeted acceptance | 42 suites,291 methods,12853 recorded primary child calls. Existing isolated C/C++ oracle calls in those suites are included in the child-call census and are not Mojo builds. |
| New Q2/Q3 suite | 13 methods/530 calls:339 accepted,191 expected refusals.439026 complete component comparisons and32248 source-byte comparisons. |
| Preserved behavior | 98 controls covered by6040 complete successful stdout pairs and5370 nonzero exit/stdout/handled-error pairs.97 controls have successful cases; the original storage-scenario API is mutation-only.81 binaries frozen before production;17 compiled later from preserved sources. |
| Source lifetime/access | 27 actual new trace files,36 matched read-only whole-fixture mapping/open/close/unmap lifecycles;unchanged bytes and zero target-device/network/ioctl/inference-runtime access. |
| Independent format oracles | Public-header C++ object sizes/offsets and2048 finite isolated static constant-value checks. No model/context/graph/forward API or production external dependency. |

All64 old Python test inputs and642 of643 prior Mojo sources are unchanged.
Only packed GGUF geometry changes among the old Mojo sources; three new Mojo
files bring the source census to646. The full source-storage suite is included
by actual inspector/API source path. Conservative import inventory adds17 safe
metadata/compiler entrypoints beyond81 pre-code frozen binary controls. Their
17 baseline binaries were compiled after implementation from actual preserved
643-file pre-code snapshots, with snapshot-only working directory/import roots.
They are not described as binaries frozen before production. CPU/CUDA/model,
historical and master-suite entrypoints remain excluded from execution.

Every old success is compared by complete stdout. Nonzero cases compare exit,
stdout and handled error routing/message. No unrelated pair is skipped. Real
source_storage_api arithmetic proves GGUF10/11 change from unsupported source
tags to256 elements/84 or110 bytes. Existing tests contain no valid/newly
admitted tag10/11 cases; their inputs need no change. Safetensors dtypes,
metadata type tags and device/control enums retain separate namespaces.

The independent bit writer tests1504 one-bit/group cases and385024 complete
component records, plus special words, seeded combinations, element/block/row/
final-byte windows, original Unicode/NUL names, malformed headers, bounds,
mutable source/schedule guards, owned copies and recovery. Actual original
compiler graph bindings and lazy byte tiles are exercised. Independent pinned
public-header C++ objects confirm fields and sizes. Only two isolated static
constant decoders check2048 finite synthetic constant values; these are a
subset of component reads, not model/layer/attention execution or exact signed-
zero reference comparisons. Production preserves source bits independently.

## Retained runner/preparation history and audit

The initial expanded42-suite runner completed41 suites successfully. All97
native safetensors calls and264204 raw/expanded word comparisons also passed,
but the wrapper then misclassified an ldd dependency-inspection argument as a
native API command and invoked the control without arguments. The failure,
original runner and all inputs remain intact. An additive reviewed wrapper
pairs direct API commands and strace-wrapped commands; ldd is inspected separately
for both current/snapshot binaries. The unchanged nine-method/97-call suite
passes under that classification. No native comparison is skipped, no production
or old test input changes, and repeated native calls are not added twice to the
final primary-call census. All42 final suites and four trace audits pass.

The first selected API build failed on Python-style deletion syntax in the
new test seam; Dict.pop corrected it. Its next build succeeded with an unused
initial-scale warning; a declaration without the redundant value removed that
warning before the full source freeze. All117 final Mojo builds have zero
diagnostics. The initial C++ test scaffold was not compiled or executed: its
public declaration macro and anonymous-union member paths were reviewed after
Mojo builds and recorded as an explicit test-only before/after hash amendment.
The corrected independent C++ build has zero diagnostics. Mojo/Python inputs
remain frozen throughout acceptance.

The initial command planner stopped before executing tests because a historical
root-layout JSON path was missing. The final planner points to fresh output
from the independently built public-UAPI C object; temporary planner bytes are
not evidence. A cached inventory note incorrectly described termination of the
first scan; the first scan had already completed successfully. A separate
pre-code review explicitly corrects that wording. Full snapshots/controls were
verified before production edits. These preparation artifacts remain preserved.

PID-aware syscall auditing joins unfinished/resumed records with whitespace on
both sides of closing parentheses. Whole-fixture read-only shared mappings
include synthetic payload; exact fixture hashes and matched cleanup are checked.
Trace counts come from actual run records. Runner status and report paths are
distinct. Original full outputs remain in the hashed outside archive; published
per-call receipts retain output sizes/hashes and small outputs. This avoids
representing digest receipts as complete component comparisons: the test code
performed the full comparisons before generating receipts.

Evidence: docs/evidence/q2q3-source-constants-2026-10-22. Repository consistency
still reports23296 historical diagnostics and nine existing strict ledger-schema
issues; normalized additions/removals for this slice are zero added/zero removed. No complete
repository or hosted-CI pass is claimed. No numerical Hailo or source-model
execution, hardware packing/fit acceptance, external compiler/model requirement,
model download or device access is introduced.

## Continued work

Two bounded public-interface searches established no new numerical instruction,
register or placement field. This is an observation, not an absence proof or
new capability. Original numerical lowering, physical configuration/precision/
packing/placement, valid original program delivery/activation/results/cleanup
and broad ordinary-source execution remain required work under
TASK_hailo10h_numerical_encoding_sources.md and the fixed owner scope.
