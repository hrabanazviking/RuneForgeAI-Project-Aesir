# Present tied-output tensors require actual source comparison

Date:2026-10-23. Consumer:original ordinary source compiler.
Controlling scope:`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Broad ordinary unmodified source-model support100% remains fixed.

## Qualified public facts

The complete Apache2 root licenses were read before documentation inspection.
Transformers4.57.1 is pinned to
`8cb5963cc22174954e7dca2c0a3320b7dc2f4edc`;
Safetensors0.6.2 to`aa6c43d729868fc43918e862d42bfeaf60485d1d`.
No external implementation body is adopted or translated. Examples in the
shared-tensor documentation were read as documentation and never executed.

The [versioned configuration reference](https://huggingface.co/docs/transformers/v4.57.1/en/main_classes/configuration)
defines`tie_word_embeddings`as input/output embedding sharing intent. It also
distinguishes configuration loading from loading weights. This flag supplies
no comparison of two tensors already present in an arbitrary source file.

The [versioned shared-tensor guide](https://github.com/huggingface/safetensors/blob/aa6c43d729868fc43918e862d42bfeaf60485d1d/docs/source/torch_shared_tensors.mdx)
describes serialization that chooses one name for a complete shared buffer and
can omit other names. Loading can use the model's known sharing relationships.
This explains missing duplicate names; it does not establish equal bytes for
two separately present tensor spans.

## Actual Aesir gap and original next action

`smidr/decoder_projections.mojo`keeps both canonical bindings when present,
selects the embedding for declared tying and records unresolved duplicate-output
identity. The existing semantic plan refuses the unused separate output tensor.
The owned ordinary compiler's four preserved fixture refusals demonstrate this
gap. Do not delete the head, change the source flag or mark it untied to bypass it.

First qualify a bounded original full representation comparison on the actual
retained sealed sources. Reuse existing parsing, revalidation and static constant
readers; compare their raw words, with no floating arithmetic. Same format, kind,
axes and exact shape are prerequisites. Signed zero and every NaN payload remain
distinct. Different representation or shape needs explicit further compiler work.

The returned observation keeps both source names, original names, paths, spans
and layouts. It is not a persistent identity token or permission to rewrite a
graph. A separately contracted typed alias integration must preserve both source
bindings and revalidate comparison before use. Neither step establishes actual
numerical H10H configuration, placement, delivery or source-model execution.

Pre-code snapshots, full licenses, fetch order, pinned documentation, compiler
identity and150 frozen native controls are retained in
`evidence/ordinary-identity-contract-2026-10-23/archive-identities.json`.
Rendered Safetensors versioned URL failed in the web tool; the exact pinned
documentation file was fetched successfully after license review. No model,
framework forward, new device request or outside compiler was used.
