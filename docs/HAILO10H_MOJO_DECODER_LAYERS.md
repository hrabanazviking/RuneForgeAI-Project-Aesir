# Owned ordinary decoder-layer intent

Date:2026-10-20. Contract: `TASK_hailo10h_decoder_layer_intent.md`.
Public facts/design: `HAILO10H_ORDINARY_LAYER_SEMANTICS.md`, narrowed ownership/
accounting contract published to both branches at `11e3580` before code.
Fixed owner scope: `HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Implemented original Mojo boundary

`smidr/decoder_layers.mojo` exposes DecoderLayerPolicy(layers,entries,work),
move-only SourceDecoderLayers, source_decoder_layers, validate_decoder_layers
and decoder_layer_uses_rope. It reuses the strict shared JSON cursor, with owned
byte buffers retained through the final pointer use. No second JSON grammar,
external model library/compiler or inference runtime is introduced.

The result owns the complete original configuration snapshot, including unknown
and inactive modifiers, plus source/default origins, declared mask tails,
effective per-layer rotary flags, original attention layer strings, interval,
window fields, unresolved notes, owned policy and exact entry/work accounting.
Explicit integer0/1 masks are distinct from boolean/float/string values. Source
masks must cover the actual layers; extra bounded entries remain retained.
Absent/null masks generate1 except every configured NoPE interval. The absent
interval uses its documented4 default; an explicit interval must be positive.
The mask's documented1=RoPE/0=NoPE meaning is independently checked against the
pinned public ordinary config's27/9 result.

Layer types remain independent source data. Missing/null patterns are preserved
as such with an unresolved note. Unimplemented layer-type strings are retained
with notes. No sliding-window attention pattern is invented. Positive/null raw
window fields survive even while windowing is disabled. Model configuration
bias/tie/cache/scaling/training values remain untouched in the owned raw fields;
this is not their complete architecture lowering or model execution.

Initial semantic interpretation is the documented SmolLM3 schema. Other
architecture semantics and broader valid modifier behavior remain implementation
work toward broad support, never permanent eligibility rules or a vendor-model
catalog. Source/dtype/architecture breadth and numerical Hailo execution remain
open. The complete dense graph still needs actual ordinary adaptation.

Validation rederives the intent from its owned config and compares every derived
array, origin, note and accounting field. Lookups validate before checking the
index. Policies are positive and explicit; entries=root fields+declared mask+
source layer types+effective flags. Work=4*(decoded key UTF-8 bytes+retained raw
value UTF-8 bytes)+entries+layer_count. Charges precede allocation/traversal.
Existing config document admission/depth/work policies are separate. Original
config accounting is rechecked without claiming immutable file identity.

Native inspector: `smidr/tools/decoder_layers.mojo`, taking the config path,
config[bytes,fields,work,depth], layer[layers,entries,work] and optional layer query.
Its architecture/layout/identity/execution claims remain false. Actual indexed
and unindexed collection configs feed the new API in native checks after their
file owners have closed; returned layer snapshots outlive source mutations.

## Acceptance

Final inspector/API builds are clean on Mojo1.1.0. Six new methods pass
**199 native calls:88 accepted,111 expected refusals**, including72 seeded
configs, exact independent raw/source/default/array/accounting checks, public
27/9 mask, long tails, interval boundaries, exact/short policy limits, large
integer/overflow refusal before growth, Unicode/NUL/unknown fields, strict JSON
and typed fields, query bounds, mutable snapshots and independent owned results.
Forty in-process invalid-source/valid-source cycles pass. Actual ordinary
indexed/unindexed sources pass, including semantic refusal after file cleanup.
Traces show no device/inference-library access or source weight mapping.

Unchanged source-config regression:6 methods/190 calls. Unchanged tagged semantic
regression:7 methods/312 calls,108 complete frozen consumer comparisons. The
saved existing Mojo source manifest remains identical, justifying reuse of those
verified regression binaries. Full slice: **19 methods/701 native calls**.
All cases perform metadata interpretation/structure only; no model/layer/
attention forward, numerical program, physical fit or hardware result is claimed.

The initial inspector compile needed a raises annotation for Dict lookup; that
failure is preserved. An API unused-loop-variable warning was removed and the
API rebuilt cleanly, followed by the complete199-call acceptance rerun. Initial,
pre-cleanup and final evidence and source/binary hashes remain committed under
`docs/evidence/decoder-layers-2026-10-20/`.

Whole-repository consistency/CI failures remain separate from targeted success.
Final consistency reports12480 issues =11357 baseline +1123 new receipt-path
diagnostics, with no new production/test source-path or ledger-count issue.
Output accompanies this receipt; no full master pass is
claimed and its historical CPU model forwards were not run.

## Next automatic graph connection

`TASK_hailo10h_decoder_graph_policy.md` audits/contracts source-neutral explicit
per-layer rotary/output policies and graph/cache consumer migration. In the
current graph every layer emits rope_query/rope_key; cache_layout requires a
named k_rotary writer and rope_key producer. NoPE needs a direct, checked key
projection writer instead. Missing names must not substitute for an explicit
validated policy. Preserve complete existing GGUF behavior and layout gates,
then continue actual ordinary dimensions/aliases/tie/bias/window/scaling/norm/
activation semantics and numerical Hailo compiler/configuration/execution work.
Broad model support and exclusive Hailo LLM execution remain the fixed target.
