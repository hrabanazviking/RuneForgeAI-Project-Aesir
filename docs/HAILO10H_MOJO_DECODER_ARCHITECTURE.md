# Owned ordinary decoder parameter and modifier intent

Date:2026-10-20. Parent: TASK_hailo10h_decoder_architecture_intent.md.
Pre-code design was published/verified on both branches at6fc6b0a:
HAILO10H_DECODER_ARCHITECTURE_DESIGN.md. The owner-fixed broad model target
and exclusive Hailo LLM execution remain unchanged.

## Original Mojo boundary

smidr/decoder_architecture.mojo exposes DecoderArchitecturePolicy(entries,work),
move-only SourceDecoderArchitecture, source_decoder_architecture(layer_intent,
policy), and validate_decoder_architecture. The result independently owns a
rederived complete SourceDecoderLayers, including its raw configuration,
original/effective masks, window facts, source/default origins and unresolved
notes. It additionally owns dimensions, boolean flags, Float64 scalar values,
activation string, architecture field origins, unresolved notes and accounting.

Documented dimension defaults and explicit positive integer fields remain
distinct. Explicit KV heads must divide query heads. The contradictory public
missing-KV descriptions produce an unresolved note for omission/null; the
pinned model's explicit4 is unambiguous. No default output tie is invented.
Explicit tie/bias/cache flags survive; absent/null tying stays unresolved.
Non-silu activations, scaling objects, biases, disabled cache, pretraining and
other modifiers remain source data and explicit outstanding semantics.

The hidden/query-head quotient is named head_dim_candidate. Nonintegral heads
or an explicit head_dim extension supply no candidate and retain unresolved
source semantics. This arithmetic is not actual projection-axis proof. Scalar
values must be finite positive JSON numbers; original raw values survive in
the source. The inspector additionally reports exact Float64 scalar words,
including subnormals; no device precision choice follows from that conversion.

The shared strict JSON parser and original layer helpers validate values; no
second grammar, model implementation, external compiler or inference runtime is
introduced. Raw bytes are charged before parsing/copying. Entries count original
root fields plus every derived dimension/flag/scalar/origin/activation/note;
work=4*(all decoded root-key/raw-value UTF-8 bytes)+entries. Layer/config limits
remain separately enforced. Each derived entry is admitted before growth; the
fresh independent layer owner is rederived after architecture charges pass.
Validation rederives and compares all mutable derived state and owned policies.

The inspector takes config[bytes,fields,work,depth], layer[layers,entries,work]
and architecture[entries,work]. Complete architecture/source-axis/execution
proof flags remain false. This component returns no SemanticPlan or source
alias map, and does not select output weights from missing file names.

## Independent acceptance

Seven new methods pass **200 native calls:69 accepted,131 expected refusals**.
Coverage includes48 seeded full configs, actual pinned model metadata, documented
fallbacks, missing/null KV and tie values, arbitrary head extensions, all retained
unknown/scaling/window/training/bias/cache data, strict types, finite/overflow/
underflow refusal, exact scalar words including the smallest positive Float64,
positive/exact/short policies,22 mutable-state refusals and independent owners.
Forty in-process invalid/valid architecture cycles pass.

Actual indexed/unindexed ordinary collection configs feed the API after source
file owners close. Independent snapshots survive mutations of both config and
layer inputs. Late scalar refusals verify matching openat/openat2 and close
counts for real config/weight descriptors. Traces show no source weight mmap,
device access or inference library. No model/layer/attention forward occurs.

Four unchanged-source regressions pass24 methods/853 calls: config6/190,
layer6/199, explicit graph policy5/152 and tagged semantics7/312 (including108
complete frozen consumer outputs). Source manifests prove these previously
verified binaries' implementation dependencies remain unchanged. Full slice:
**31 methods/1053 native calls**. Final tool/API builds are warning-free.

The initial194-call suite and all regressions passed. The extra edge run exposed
two harness issues: its syscall filter omitted openat2 and it briefly attempted
execution while a binary was being relinked. Both are preserved. Corrected final
trace/cleanup checks run against completed binaries and all200 calls pass.
Raw logs/hashes/provenance are under evidence/decoder-architecture-2026-10-20/.
Whole-repository consistency and hosted CI remain separate gates; no whole
historical master or CPU model execution was run. Consistency reports14923
diagnostics:13507 baseline plus1416 new raw receipt-path diagnostics, with no
new nonreceipt issue after normalizing shifted historical diagnostic lines.

## Next automatic work

TASK_hailo10h_ordinary_source_bindings.md continues actual source-weight name/
axis/projection/output-tie binding facts and original Mojo adapters, preserving
all owned parameter/layer/modifier intent. Complete rotary pairing/scaling,
norm/activation/window semantics and numerical Hailo instruction/configuration/
precision/packing/placement/upload/activation/results/cleanup remain required.
This is required implementation toward broad support, never a permanent model
restriction, outside compiler dependency or special user conversion workflow.
