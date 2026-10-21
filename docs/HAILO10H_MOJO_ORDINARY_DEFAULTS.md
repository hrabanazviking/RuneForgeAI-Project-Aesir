# Qualified ordinary omitted/null defaults in original Mojo

Date:2026-10-20. Contract: TASK_hailo10h_ordinary_defaults.md.
Exact pre-code design/facts were published on both branches at6fe8f4d:
HAILO10H_ORDINARY_DEFAULTS_DESIGN.md. Broad owner scope remains unchanged.

## Implemented behavior

The original decoder_layers and decoder_architecture modules now apply the
qualified SmolLM3 configuration defaults without changing their owned types or
raw input fields. Omitted num_hidden_layers uses36, with separate default
origin and policy/entry/work admission before flag allocation. Explicit integer/
null/type rules and every mask/tail/window check remain. Architecture intent
inherits the checked layer-count origin instead of hardcoding source.

Omitted KV heads uses4; explicit null uses the checked query-head count. Both
now have known semantic origins; explicit positive values retain source origin.
Native positivity/divisibility checks still apply, and actual source Q/K/V
shapes must agree. A tensor ratio never overrides the source default decision.
The obsolete missing/null KV unresolved note is removed only for this qualified
schema. Omitted tying now supplies true with documented default origin; explicit
booleans remain source values and explicit null tying remains unresolved.
Projection selection follows that checked flag, preserving duplicate tied heads
and all source bindings instead of inferring ties from a missing output file.

No raw field is inserted, deleted or normalized in the original source snapshot.
No window pattern, rotary basis, activation/norm/scaling meaning, source identity,
numerical precision, device program or complete architecture claim is added.
Historical conservative default receipts remain preserved and are superseded
only for these now-established semantics. Other architecture/version behavior
and full ordinary/numerical execution remain required implementation work.

## Independent evidence and acceptance

A separate4.57.1 environment contains no Torch, TensorFlow or Flax. Thirty-one
public configuration-constructor cases, exact module/license identities and a
trace establish the omitted/null distinctions. The trace has no Torch library,
network connection or Hailo device. No model class/weights or model/layer/
attention forward was used; no external implementation was copied/translated.
The earlier installed5.7.0 probe imported Torch and failed isolation; that
negative evidence is retained, not represented as an isolated success. The
configuration-only oracle remains outside production and is not a user/runtime
dependency.

Seven affected entrypoints rebuild warning-free. Five new methods pass
**109 native calls:92 accepted,17 expected refusals**, including31 frozen oracle
cases (two permissive-constructor/invalid-GQA cases correctly refused), policy/
null/type distinctions,28 complete old explicit-source comparisons across three
inspectors, source shape/tie validation and all326 real header geometries under
a minimal config. That route explicitly remains remote metadata only, with no
locally admitted model, source payload or full-file identity claim.

Six other suites pass39 methods/1176 calls: config6/190, layer7/207,
architecture7/200, projections7/115, graph policy5/152 and semantic storage7/312.
This includes40 complete NoPE graphs and108 complete frozen GGUF consumer
outputs. Full slice: **44 methods/1285 native calls**. All suites pass on the
first native implementation run; no native compile/test failure is hidden.
Older negative receipts remain immutable. New independent expectations reflect
the qualified admission behavior, including the formerly refused omitted layer
field; invalid types, bounds and actual projection geometry remain rejected.

Only two production modules changed. Direct ordinary import consumers and the
graph-policy API were rebuilt. The other verified compiler implementations are
unchanged by the saved source manifest delta. Source/binary identities, complete
native outcomes and syscall evidence are in evidence/ordinary-defaults-2026-10-20/.
Whole-repository consistency and historical-master hosted CI remain separate;
no full master pass or CPU/CUDA/cloud LLM execution is claimed. Consistency
reports17493 diagnostics:16174 baseline plus1319 new raw receipt-path issues;
no new nonreceipt issue after normalizing shifted historical diagnostic lines.

## Next automatic work

Return to TASK_hailo10h_ordinary_rotary_modifiers.md for actual rotary pairing,
remaining modifiers and original mathematical operation lowering. Complete the
ordinary source-to-graph path and actual numerical Hailo instruction/configuration/
precision/packing/placement/upload/activation/results/cleanup. Broad model
support stays100% the target; no outside compiler/DFC/machine, vendor artifact,
inference proxy or special user conversion becomes a prerequisite.
