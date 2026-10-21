# Qualified ordinary projection headers and optional bias sources

Date:2026-10-21. Publish before code. Parent:
TASK_hailo10h_ordinary_rotary_modifiers.md. Fixed owner scope remains
HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md. Broad support is the target; this
bounded source-schema addition is not a complete model adapter or execution.

## Qualified facts

The pinned Transformers4.57.1 SmolLM3 constructor interface was queried on the
meta device, after reviewing Apache2 licensing and Torch BSD/bundled notices.
All parameters/buffers were meta; full models, source weights and forward calls
were excluded. Global and direct forward guards were installed. Twelve cases
record head extensions, bias declarations, activation selection, cache/training
headers, nondivisible hidden/head counts and small/odd head dimensions.

Observed parameter headers select explicit positive head_dim when supplied;
otherwise head_dim is floor(hidden_size/query_heads). Q/K/V/O source matrices
have row-major shapes [Q*D,H], [KV*D,H], [KV*D,H], [H,Q*D]. Enabling
attention_bias adds corresponding output-axis vectors; enabling mlp_bias adds
gate/up vectors [FF] and down [H]. Norm weight is [H]. MLP weights remain
[FF,H], [FF,H], [H,FF]. SiLU/GELU names selected different activation classes.
These are constructor/header facts only: neither odd dimension nor successful
construction certifies valid rotary/attention math. Cache false and tp2 changed
no observed headers; their execution semantics remain open. Do not derive
numerical algorithms by copying/translating external implementations.

Primary API documentation:
https://huggingface.co/docs/transformers/v4.57.1/en/model_doc/smollm3
Exact test-only probe, output, audit and source-module/license identities:
evidence/ordinary-projection-schema-facts-2026-10-21/.

## Original Mojo API and ownership

Keep SourceProjectionIntent, bind_decoder_projections and all existing inspector
outputs unchanged. Their geometric intent permits independent source K/V widths;
it must not silently become complete architecture certification.

Add OrdinaryProjectionSchema(Movable) in smidr/ordinary_projection_schema.mojo:
binding:SourceProjectionIntent, head_dim:Int, head_dim_origin:String,
schema_provenance:String, work_units:Int. bind_ordinary_projection_schema takes
an owned ordinary architecture snapshot, original storage inventories and the
existing explicit DecoderProjectionPolicy. It returns independent owned copies
of every raw configuration, layer/modifier note, file metadata, original tagged
tensor binding and alias decision. Qualification provenance is a fixed versioned
constructor-fact identifier. Activation remains the exact source selector in the
architecture, with all unresolved numerical notes retained.

Factor a private common binder with an explicit extended-role switch; the old
public binder always selects its original behavior. The new API alone selects
seven additional bias aliases per layer: attn_q/k/v/output.bias and
ffn_gate/up/down.bias, mapped from corresponding ordinary projection names.
All required bias vectors must be present with exact output-axis rank/size when
their source flag is true. Unexpected vectors when false are inconsistent source
evidence. Each original name is admitted once across all files, including bias
sources, with full payload/header coverage retained. Never manufacture a bias or
remove tensor bytes from an admitted inventory.

The new API resolves head_dim from strict positive integer raw extension or
floor(H/Q), requires a positive result, and checks actual Q/K/V/O geometry
against that qualified declaration. Its head_dim_origin distinguishes explicit
source and qualified derived value. No hidden divisibility or evenness gate is
added to the source-header layer. Different architectures remain implementation
work; no model-size or permanent architecture allowlist is introduced here.

Common extended role work reserves128 units for each of16 layer roles plus3
global roles; existing count/name/path/metadata/source policy charges remain.
New wrapper work additionally charges128+8*layers. Admit the complete work bound
before role dictionaries/copies/derived allocations. All products/counts use
checked arithmetic. Old work counts remain unchanged. The new validator
rederives from the complete owned source and compares every decision, policy,
source binding, unresolved note, head origin, provenance and accounting value.
The wrapper's binding must be validated through its new qualified API, never
passed to the old schema validator which intentionally accepts fewer roles.

## Consumers and acceptance

Add an indexed/unindexed native inspector and an ownership/mutation/remote-
metadata API harness. Reuse the old JSON binding formatter only after validation
by the corresponding schema; all safety flags stay false. Expose head dimension,
origin, qualification provenance, work and complete nested source facts. No
payload inference, numerical operation, device access or source fingerprint claim.

Independently check default/explicit heads, nondivisible H/Q, odd/tiny headers,
all four bias-flag combinations, true/false/omitted tie, F16/BF16/F32 and multiple
shards; source rank/shape/role/count/overflow/policy/bias/config mismatch refusals;
owned input independence and retained-source/derived mutations. Test exact work
limits, raw unknown/Unicode/NUL field retention, repeated refusal/recovery and
root/fd cleanup. Verify pinned actual326 source headers as metadata only. Rebuild
affected legacy consumers and compare complete frozen outputs. No full-model,
layer or attention forward, CPU/CUDA/cloud LLM execution, DFC or outside compiler.

After publication continue original bias arithmetic graph integration, remaining
activation/scaling/window/cache/training semantics and full ordinary adapter,
alongside actual Hailo numerical encoding/configuration/placement/upload/
activation/results/cleanup. Header binding does not complete any of those gates.
