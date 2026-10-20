# Owned ordinary decoder architecture intent: exact first contract

Date:2026-10-20. Parent: TASK_hailo10h_decoder_architecture_intent.md.
Graph/cache policy is published/verified on both branches at0f16a3d.
Owner scope remains HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md.

## Licensed declaration facts

The already reviewed pinned Apache-2.0 license and rendered public declaration
were rechecked before this study. No model implementation or checkpoint was
downloaded, copied, translated or executed. The
[versioned public configuration declaration](https://huggingface.co/docs/transformers/v4.57.1/en/model_doc/smollm3#transformers.SmolLM3Config)
specifies hidden/intermediate/vocabulary/context dimensions, head counts,
activation, RMS epsilon, rotary base, bias and cache flags. Its KV-head
constructor default and explanatory prose disagree; this first native intent
must preserve omitted/null KV-head values as unresolved instead of choosing a
meaning. The pinned actual config explicitly declares4, so that case is clear.

Existing source facts give36 layers, hidden2048, intermediate11008, heads16,
KVheads4, vocabulary128256 and context65536. Dividing2048 by16 gives128 only as
an arithmetic head-width candidate; source projection shape/orientation and
rotary component pairing still need actual proof. tie_word_embeddings=true is
an explicit declaration, not byte identity or an absent-output heuristic.

## Exact original Mojo API

Implement DecoderArchitecturePolicy(entries,work), move-only
SourceDecoderArchitecture and source_decoder_architecture(layer_intent,policy),
plus validate_decoder_architecture(intent,policy). The result independently owns
an entire rederived SourceDecoderLayers (therefore the full raw source config),
its own policy, dimensions:Dict[String,Int], flags:Dict[String,Bool],
scalars:Dict[String,Float64], activation:String, field_origins:Dict[String,String],
unresolved:List[String], entry_count and work_units. No SemanticPlan or complete
architecture certificate is returned by this dependency.

Use the existing strict JSON cursor/helpers, not another grammar. Required
source model/layer identity comes from validated owned layer intent. For absent
vocab_size/hidden_size/intermediate_size/num_attention_heads/max_position_embeddings
use the documented128256/2048/11008/16/32768 defaults, retaining origins. Explicit
values must be positive integers, never bool/float/string/null. num_hidden_layers
must remain the checked source layer count. Explicit positive KV-head count
must divide query heads; absent/null remains absent in dimensions with a note.

A divisible hidden/query-head relationship supplies only head_dim_candidate;
nonintegral default or any explicit head_dim extension records unresolved head
semantics and supplies no candidate. Check positive/overflow arithmetic before
deriving values. Candidate dimensions never prove actual source projection axes.

Read attention_bias/mlp_bias/use_cache as strict booleans, using their documented
false/false/true defaults when absent. Explicit tie_word_embeddings boolean is
retained; omitted/null tie semantics remain unresolved, with no output binding
selection. hidden_act is a source string or documented silu default; other
activation strings survive with a lowering note. rms_norm_eps/rope_theta are
finite positive JSON numbers, defaults1e-6/2000000; retain original raw values
in the owned config and do not claim device precision from Float64 conversion.

rope_scaling must be absent/null/object; preserve its complete raw object and
note unresolved scaling lowering. Window/layer intent, biases, cache intent,
training and every unknown/inactive modifier survive in the owned source. Add
explicit unresolved notes for source aliases/orientation, rotary pairing,
architecture modifier integration and numerical device execution. This is a
bounded prerequisite, not a new permanent model eligibility rule.

## Accounting, ownership and acceptance

Both policies are explicit positive values. Validate the supplied layer intent
under its own policy. Architecture entries count original root fields plus every
derived dimension/flag/scalar/origin/activation/note. Architecture work is4 times
all retained decoded root-key/raw-value UTF-8 bytes plus architecture entries.
Check raw bytes and original parser accounting before copying or parsing. Charge
each derived entry before adding it, check sums by subtraction/division, and
copy/rederive the independent layer owner only after the architecture charge is
admitted. The existing layer/config accounting remains separately enforced.
Validation rederives and compares all values, policies, notes, accounting and
origins; it also validates the owned layer snapshot.

Verify pinned actual config, independent documented/default/explicit/null/type/
head-relationship cases, unknown/scaling/window/bias/tie retention, positive/
exact/short/overflow policies, mutation/ownership and actual indexed/unindexed
collection connections after descriptor cleanup. Run affected config/layer and
graph regressions. No CPU/CUDA/cloud model/layer/attention forward.

After verification/publication, immediately continue actual ordinary source
weight alias/orientation/projection/output-tie validation, complete modifier/
component-pairing adaptation and original numerical Hailo encoding/configuration/
precision/packing/placement/upload/activation/results/cleanup. No DFC, outside
compiler/machine, special user conversion or vendor-artifact prerequisite.
