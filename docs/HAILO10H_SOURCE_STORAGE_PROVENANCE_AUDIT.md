# Source storage provenance: axis-loss finding and narrowed contract

Date: 2026-10-20. Parent: `TASK_hailo10h_source_neutral_semantics.md`.
Typed parameters/compatible graph were published and verified at `2134a37`.
The fixed broad ordinary-model scope remains in
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Current project facts

`aesir_engine/loader/packed_gguf.mojo` parses a declared rank of one or two,
then stores only columns and rows in `PackedTensor`. Rows default to one for
a vector. Consequently `[N]` and `[N,1]` are indistinguishable after parsing.
`SourceTensorBinding` copies that same descriptor; it has no container tag,
original full shape, original-name/alias distinction or backing-file key.
This loss must be repaired before claiming exact source axis provenance.
Do not reconstruct rank by guessing that every row-count-one tensor is a vector.

The existing safetensors inventory preserves full row-major axes, including
scalars and zero-sized axes, plus original names, dtype namespace and file
extents. GGUF and safetensors numeric dtype IDs have different meanings. Current
matrix schedules and expanded-storage validation still call GGUF packed-row
arithmetic. Merely changing a filename/name/dtype integer cannot connect them.

## Licensed public configuration/index facts

Transformers v4.57.1 annotated tag object is
`a47e6666f8f9a61e44a5d149c5e3d230e6c8053c`; its peeled commit is
`8cb5963cc22174954e7dca2c0a3320b7dc2f4edc`. Apache-2.0 LICENSE was read first.
Documentation hashes and URLs are retained under
`evidence/source-storage-audit-2026-10-20/`. No external model implementation
was copied/translated, no checkpoint downloaded and no inference run.
An initial raw URL used the annotated tag object and returned404; the peeled
commit and current documentation filename `models.md` resolved successfully.

The pinned [loading documentation](https://github.com/huggingface/transformers/blob/8cb5963cc22174954e7dca2c0a3320b7dc2f4edc/docs/source/en/models.md)
describes `model.safetensors.index.json`: `weight_map` associates original
parameter names with shard filenames; `metadata.total_size` describes total
model size. Its example names include `lm_head.weight`,
`model.embed_tokens.weight`, `model.layers.0.input_layernorm.weight` and
`model.layers.0.mlp.down_proj.weight`. These examples are not a full alias or
matrix-orientation specification. Aesir must check actual indexed names,
backing files, tensor presence and byte extents rather than treating the index
size or filename as proof of weight semantics. This conclusion is an Aesir
integration requirement inferred from the published file mapping.

The versioned [LlamaConfig public declaration](https://huggingface.co/docs/transformers/v4.57.1/en/model_doc/llama#transformers.LlamaConfig)
exposes hidden/intermediate/layer/vocabulary sizes, attention/KV heads, head
dimension, context, RMS epsilon, RoPE base/scaling, tied embeddings, activation
and bias flags. KV heads default to attention heads; head dimension defaults
to hidden size divided by attention heads. Those defaults alone do not prove
all modifier semantics or source-to-GGUF rotary/axis equivalence. Preserve
modifiers and trace actual names/layout facts before a semantic adapter.
The rendered API is versioned and hashed, distinct from the pinned raw docs.
No external model constructor/forward implementation was used as Aesir code.

## First implementation: preserve exact admitted GGUF dimensions

Add an owned per-name source-shape index while parsing the already admitted
one/two-dimensional GGUF directory. Expose a copied `tensor_shape(name)` value.
Preserve `[N]`, `[N,1]`, `[1,N]` and `[N,M]` exactly in declared GGUF axis order.
Do not alter `PackedTensor` field layout/constructor, columns/rows semantics,
source kinds, offsets, byte counts, alignment/overlap/refusal or existing graph
output. No duplicate parser and no inferred/transposed dimensions.

Revalidate lookup consistency with the current descriptor and return independent
shape storage; missing names or inconsistent mutable index/descriptor state
must raise. Shape results may outlive the parser/mapping. Explain that values
are descriptive metadata, not backing-file identity or mathematical layout.
The current one/two-rank loader coverage remains implementation work to broaden,
never a permanent model eligibility restriction.

Verify independent explicit-rank GGUF fixtures, including the previously
indistinguishable row-count-one pair, all existing packed kinds, Unicode/NUL
names, permutations, ownership/mutation/missing/inconsistent state, malformed
ranks/dimensions/truncation and read-only cleanup. Rebuild inventory and semantic
regressions and compare complete graph output to the existing baseline. No
model/layer/attention forward, outside compiler or device access.

## Following connection

After exact source shape preservation, implement tagged storage descriptors
retaining container and dtype namespace, full original axes/order, original
name and backing-file provenance. Reuse existing parsers. Connect checked
storage arithmetic and semantic aliases incrementally without dropping fields
or relabeling unimplemented layouts. Ordinary config/index parsing and complete
canonical alias/orientation/rotary facts are still required for safetensors
semantics. Numerical Hailo CCW/register/precision/packing/placement and original
program execution remain open and continue under their existing contracts.
