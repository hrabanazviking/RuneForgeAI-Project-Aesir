# Qualified ordinary attention-pattern and isolated window-index facts

Date:2026-10-21. Fixed owner scope remains broad ordinary model support with
all LLM execution on Hailo-10H. This audit is a next implementation dependency,
not a source-model or numerical Hailo execution capability.

## License and public interface

Pinned Transformers4.57.1 Apache-2.0 license SHA256
77fd4710def9ec3c0f6225800e0235f15a425abd4a8b03559127fcd782612049
matches the previously reviewed full license. Configuration constructor module
SHA2564fec68b228fec767ddc8f8cd4c40f8eaf374c3c44bf38c0cf1618382c7731cdf
is unchanged. Public parameter declarations describe layer_types as the
per-layer attention pattern, a window flag/size, and automatic generation.
[Versioned SmolLM3 interface](https://huggingface.co/docs/transformers/v4.57.1/model_doc/smollm3).

Only public constructors and isolated public integer predicates were called;
no external implementation is copied or translated into Aesir. The test-only
Torch2.11.0+cpu license matches its prior reviewed SHA256
a0d7abc10248a062a2f309bf12981524973f2a61aadccf4c5099d96d8c388cf4.
The constructor process imports neither Torch nor the model module. The separate
index process imports Torch for library availability, creates no tensors, blocks
module/SDPA forwards, never imports the model module and invokes only pure
integer predicate callables. No network or device access occurred. External
libraries remain isolated test oracles, never runtime/user prerequisites.

## Observed facts

Forty-six constructor probes:44 accepted metadata cases and2 expected empty
layer-list refusals. Explicit full/sliding/mixed layer_types survive either
window flag, including disagreements. When types are generated, these tested
cases use sliding attention at NoPE positions only when the flag is true and
the window is non-null. Null window generates full types even with the flag
true. max_window_layers values1/4 are retained without changing this generated
pattern in these probes. This establishes constructor behavior, not valid-model
semantics or whether a downstream attention implementation honors every field.

An initial audit incorrectly expected a true flag alone to generate sliding
types; six null-window cases disproved that expectation. The failed expectation
and unchanged complete oracle output are retained. No failed artifact counts as
implementation acceptance.

A separate119-case isolated index oracle checks4760 boolean results at windows
1/2/3/4/8/64/IntMax and query positions0–16 against keys0–19. Its admitted set is
[max(0,q-W+1),q], inclusive. This is only a bounded predicate/index fact; it does
not evaluate scores, attention, a layer or a model, certify numerical precision,
prove a particular model's selected mask or determine physical cache eviction.
[Public mask primitive interface](https://github.com/huggingface/transformers/blob/v4.57.1/src/transformers/masking_utils.py).

## Required native contract

Retain all raw source fields, origins, masks and unresolved facts. Separate
source pattern selection from a caller's explicit mathematical recipe, source
cache-return preference, session mode and physical cache policy. Qualify exact
positive/null/type/bounds handling and conflicting source declarations before
projecting them. Do not silently replace explicit patterns with flag heuristics
or treat constructor permissiveness as admission of a numerical model.

Publish an exact owned per-layer window policy, full/cached mask operation/
recipe/index domains and metadata, lifetimes, snapshots and all consumers before
production changes. Freeze51 current controls and require complete old outputs,
independent integer boundaries, work/overflow, ownership/mutation/refusal/recovery
checks. Window mask selection must not imply cache compaction, physical placement
or support for unimplemented architectures. Remaining coverage is work toward
the same broad target. Actual Hailo numerical configuration/register/CCW encoding,
precision/packing/placement, upload/activation/results/cleanup remain open.

Whole-repository consistency remains failing:baseline21006/current21025,
all19 new diagnostics confined to retained audit receipts. No new nonreceipt
issue after Markdown line normalization. All178 current Mojo sources remain
unchanged;51 controls are copied byte-for-byte with modes/hashes. No native
window implementation or whole-repository/hosted-CI pass is claimed by this audit.
The exact next contract is HAILO10H_DECODER_WINDOW_DESIGN.md.
