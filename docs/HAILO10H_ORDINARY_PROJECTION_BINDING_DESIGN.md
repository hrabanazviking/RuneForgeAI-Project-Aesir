# Ordinary source projection bindings: facts and exact native contract

Date:2026-10-20. Task: TASK_hailo10h_ordinary_source_bindings.md.
Owned parameter intent is verified/published on both branches at25539ba.
Owner scope remains HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md.

## Licensed public interfaces and actual source metadata

The PyTorch2.8 BSD-style license was read before its public Linear/Embedding
interfaces. Direct document downloads returned403; the public web tool retrieved
the official declarations, and those negative requests remain recorded. No
PyTorch implementation was downloaded or imported. The pinned Transformers
Apache-2.0 license/model-card declaration were reviewed before ordinary source
metadata, as recorded in prior receipts.

[Linear](https://docs.pytorch.org/docs/2.8/generated/torch.nn.Linear.html)
declares weight axes[output,input] and bias[output].
[Embedding](https://docs.pytorch.org/docs/2.8/generated/torch.nn.Embedding.html)
declares weight axes[vocabulary,embedding width]. The
[configuration interface](https://huggingface.co/docs/transformers/v4.57.1/en/main_classes/configuration#transformers.PretrainedConfig)
defines tying as sharing input/output word embeddings. Its generic default does
not by itself prove every architecture's inherited/overridden missing-field
behavior. This first adapter continues to require an explicit tie declaration
for an output decision; it must not infer tying from a missing output name.

Four bounded HTTP206 ranges at the already pinned ordinary model revision
retrieved exactly37760 bytes: two8-byte length prefixes,29944 and7800 header
bytes. No weight payload was downloaded. Both reported file totals, full payload
span coverage, BF16 byte arithmetic, all326 original names and their shard
assignments match the pinned index. The headers account for6150197248 payload
bytes; they do not establish full-file identity or an actual local model.

Observed shapes: embedding[128256,2048], norms[2048], each layer Q[2048,2048],
K/V[512,2048], output projection[2048,2048], gate/up[11008,2048],
down[2048,11008]. All36 layers agree on geometric key/value widths128 with the
explicit16 query/4KV heads. The explicit tie=true config and absent lm_head
support a declared embedding output-binding candidate; absence alone would not.
No source rotary pairing or complete architecture execution follows from these
header facts. Evidence: evidence/ordinary-projection-facts-2026-10-20/.

## Exact original Mojo adapter

Implement DecoderProjectionPolicy(source:SourceSemanticPolicy,work:Int,
provenance:String), move-only SourceProjectionIntent and
bind_decoder_projections(architecture,files:List[SourceStorageInventory],policy),
plus validate_decoder_projections(intent,policy). The result independently owns
its complete SourceDecoderArchitecture, original file metadata/tensors, fully
tagged SourceTensorInventory, uniform key_dim/value_dim, explicit output_weight
(empty when unresolved), unresolved notes, owned policy and projection work.
Return no SemanticPlan, numerical program or architecture-execution certificate.

Initial source role schema is the documented/observed ordinary SmolLM3 naming
family, independent of a particular checkpoint/dimension/dtype/file split.
Map model.embed_tokens.weight→token_embd.weight, model.norm.weight→output_norm.weight,
optional lm_head.weight→output.weight. Per layer map input_layernorm and
post_attention_layernorm to attn_norm/ffn_norm; q/k/v/o_proj to attn_q/k/v/output;
mlp gate/up/down_proj to ffn_gate/up/down. Preserve each original source tag,
dtype, name, file path, full axes, span and arbitrary source metadata. Reuse
append_source_storage/validate_source_inventory/validate_source_weight.

Every original tensor must have one checked role. An unknown role/rank/format
raises named implementation-unresolved work without modifying inputs; it cannot
be silently dropped or become a permanent model eligibility rule. Bias and
other missing roles must be implemented next when encountered. Distinct actual
files and global names must stay unique. No source flattening or bare dtype-ID
cast is allowed. Initial operation views remain the checked one/two-axis views.

Check embedding[vocab,hidden] and vector norm[hidden]. Derive key_dim from each
Q projection's output extent/query-head count; check exact division, positive
products, input hidden width and K extent=KVheads*key_dim. Derive value_dim from
V output/KVheads, independently of key_dim, and check output projection input
extent=query_heads*value_dim. Check each FFN/norm role against actual config.
Current graph uses shared head widths: source layers with differing widths must
raise explicit unresolved recipe work; extending that recipe remains required.
Explicit KV-head semantics are required here until omitted/null meaning is
established; a tensor ratio cannot override an unresolved source configuration.

Explicit tie=true selects token_embd.weight. If a separate lm_head is present,
retain it as output.weight and add an unresolved duplicate-tied-output identity
note; do not claim equality or consume it silently. Explicit tie=false requires
a correctly shaped lm_head and selects output.weight. Missing/null tying leaves
output_weight empty plus an unresolved note even if lm_head happens to exist.
Preserve every inherited parameter/layer/modifier note, and retain explicit
source-layout/pairing, complete modifier, identity and numerical execution gates.
No graph may bypass those unresolved semantics by receiving renamed tensors.

## Exact bounds and independent verification

Both source policy and projection work/provenance are explicit and positive.
Admit file/tensor counts before scanning/cloning; require enough actual tensor
evidence for9*layers+2 using subtraction/division before alias-table allocation.
Reserve9*layers+3 expected alias slots. Projection work charges128 units per
slot,8 per actual tensor,1 per file, provenance UTF-8 bytes once per file, every
actual original-name/source-path byte and each file-path byte. Check every sum/
product before growth. The128 slot reserve covers both generated fixed-schema
names including maximal signed-Int layer digits. Existing source/storage/
architecture policies separately bound their own validation passes. This is a
metadata work/allocation contract, not an elapsed-cycle bound.

Keep file data/tensors/metadata and architecture snapshots independent of mutable
inputs. Validation rederives the binding intent from its owned original files
and architecture, then compares all aliases, descriptor/tag/shape/extents,
provenance, policies, output/head decisions and notes. This is not immutable
source identity. No reopen, source payload read/mmap or device access occurs in
the binding API; actual root-admitted collection integration happens separately.

Verify independent shape/alias/output/provenance/ownership/policy/overflow and
mutation oracles over varied layers, GQA/value dimensions, tied/untied/missing/
duplicate outputs, actual F16/BF16/F32 single/multiple ordinary sources and
indexed/unindexed collection cleanup. Include an actual-header fixture route
that labels remote extents explicitly rather than creating a fake local model.
Run every affected compiler regression and preserve complete GGUF outputs.

Publish this contract before code. After verification/publication, continue
actual remaining roles/architectures/modifiers/rotary pairing and original
numerical Hailo lowering/configuration/precision/packing/placement/upload/
activation/results/cleanup. Broad support remains100% the target. No external
compiler/DFC, special user conversion or vendor-precompiled artifact prerequisite;
all LLM execution stays on Hailo-10H.
