# Preserve present tied-output identities through ordinary graph lowering

Date:2026-10-23. Original next design;no production implementation is claimed.
Owner scope:`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Prior qualified comparison:`HAILO10H_MOJO_ORDINARY_TENSOR_IDENTITY.md`.

## Actual coupled gates

The declared tied-output schema selects`token_embd.weight`and retains a separate
`output.weight`when present. The semantic builder refuses the unused source.
`bias_graph.mojo`also checks complete consumed and actual operation-weight sets.
Expanded storage requires one mapped constant for every retained source binding
and the complete original packed byte total. Treating the extra name as used
without representing its sharing relationship would conceal these checks.

Add explicit typed source-weight sharing intent to the mathematical plan.
Initially one qualified relation is`output.weight`to`token_embd.weight`,with
bounded provenance/work and exact compatible source layout. Keep both original
source bindings,files,spans and raw bytes. Operations use the existing selected
embedding;the plan records how the retained output is accounted for through
that used target. A common validator checks exact coverage of actual operation
weights plus declared relations,refusing cycles,self-reference,duplicates,
unconsumed targets,extra names and incompatible representations.

Expansion must still emit a distinct source-constant reference for both names,
with the existing source-weight role and existing full-lifetime accounting.
Both source byte spans remain in the packed byte total. No new weight-memory
deduplication,KV-style alias role,physical storage saving or device budget is
qualified here. Existing full constant-map and storage validation must pass.

## Actual byte authority stays with retained source owners

The mathematical sharing record is editable IR. Its structural validation
cannot establish equal file bytes. A new retained ordinary compiler branch
must derive the existing tie decision from freshly revalidated source config,
compare both full stored representations through the published comparison,
then build the typed relation and existing mathematical graph. Different bytes
or representations refuse explicitly;do not flip tying or drop a tensor.

Repeat actual source comparison and decision derivation before guarded static
operation reads. Compare every sharing/request/source field against fresh
intent before selecting a component. Ignore cached success flags or edited
comparison statistics. Keep the original complete schema,including its original
notes,and record this branch's narrowly qualified sharing decision separately.
All source/architecture,domain,precision and physical gates remain explicit.

Existing compiler entrypoints keep their default empty sharing intent and
historical duplicate-output refusals. The new branch is an internal Aesir
compiler path for ordinary unmodified files;it introduces no user conversion
or external compiler requirement. Wider source aliases and representations
remain required implementation toward the fixed broad target100%.

## Pre-code evidence boundary

Actual698 Mojo/84 Python copies and152 immutable controls are retained in
`evidence/tied-output-contract-2026-10-23/archive-identities.json`.
The import census distinguishes existing qualified controls from other entrypoints;
being in an import closure does not authorize running a host model or device tool.
A closed-input type probe checks copying sharing records and moving retained
indexed/unindexed bindings with ExpandedGraph/request fields. It is never run.
This is composition feasibility only,no new graph correctness or execution.

Public tying/serialization facts stay scoped to the previously licensed pinned
references in`HAILO10H_TIED_OUTPUT_IDENTITY_BOUNDARY_2026-10-23.md`.
No external implementation or model is needed for this original design.
Numerical H10H configuration,packing,placement,program delivery/activation/results
and all missing format/architecture/operation coverage remain active work.
