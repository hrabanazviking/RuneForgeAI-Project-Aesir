# Original ordinary head declarations and bias source bindings

Date:2026-10-21. Exact design and licensed constructor facts published on both
branches aaedcd2 before production edits. Fixed owner scope remains broad LLM
support through Aesir-owned loading/lowering/execution on Hailo-10H.

## Implemented boundary

Separate OrdinaryProjectionSchema owns the complete original architecture,
source files, tagged bindings, aliases and raw/unknown modifiers. It resolves
an explicit positive head_dim or qualified floor(H/Q), checks actual Q/K/V/O
headers, binds all seven optional per-layer bias vectors according to source
flags and validates their exact output-axis rank/size. All original inventory
coverage, source extents, dtype tags and tying decisions are retained. Source
activation remains its exact selector, with unresolved numerical notes intact.

The old geometric projection API and its independent K/V widths remain intact.
A private common binder selects extended roles only for the new API; validators
rederive through their corresponding schema. Header acceptance adds no evenness
or hidden/head divisibility restriction and certifies no valid rotary forward.
Explicit provenance, checked pre-allocation role/wrapper budgets, deep copies
and full retained/derived mutation checks are implemented. Qualified wrapper
work=extended binding work+128+8*layers; old work/JSON schemas are unchanged.

## Independent acceptance

Four affected entrypoints rebuild without warnings. New7 methods/211 calls
pass:86 accepted,125 expected refusals. Existing7 methods/115 calls also pass;
combined14 methods/326 calls,136 accepted and190 expected refusals. Nine complete
legacy outputs match frozen binaries, including independent source K/V widths.
The new suite checks nondivisible hidden/head counts, explicit/odd/tiny heads,
all four bias flag combinations,3 source dtypes, indexed/unindexed collections,
three shards, true/false/omitted/null output intent, unknown raw Unicode/NUL
fields, exact work boundaries, malformed source/configuration, bias/source/role/
shape mismatches, owned input independence, retained/derived mutation refusals
and repeated refusal/recovery. Metadata-only pinned actual326 header bindings
still match, D128, with no local full model admission. Read-only fd/header traces
show no payload mmap or device access; temporary source bytes remain unchanged.

Commands, exact source/binary/run identities, logs and traces:
docs/evidence/ordinary-projection-schema-2026-10-21/. Test-only external
constructor/header facts:docs/evidence/ordinary-projection-schema-facts-2026-10-21/.
No production Python/Torch/Transformers/compiler dependency was added.

## Remaining work under the fixed target

These are source-header bindings, not numerical bias operations, full ordinary
architecture support, immutable source identity, physical placement/fit or a
Hailo program. Complete activation/scaling/window/cache/training semantics,
ordinary mathematical graph integration, numerical encoding/precision/packing/
placement/configuration/upload/activation/results/cleanup remain open. Continue
original bias arithmetic graph integration next. No CPU/CUDA/cloud LLM execution,
inference proxy, DFC, outside compiler/machine or specially compiled model route.

Whole-repository consistency remains failing: baseline18343/current18689;
all346 new diagnostics are retained receipt paths, with no new nonreceipt
issue after Markdown line normalization. Ledger census108 verified/153 IDs,
no duplicates. Historical master is not executed; prior CI compile failure is
not replaced by a whole-suite pass.
