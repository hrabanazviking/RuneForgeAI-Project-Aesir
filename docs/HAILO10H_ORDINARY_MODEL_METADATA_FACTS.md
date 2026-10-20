# Ordinary model metadata and shard-index facts

Date: 2026-10-20. Parent: `TASK_hailo10h_source_neutral_semantics.md`.
Tagged storage is published at `c7ce976`; this is the next bounded facts/audit
slice, not source-model execution or support for the inspected architecture.

## Pinned public data, license first

The public HuggingFaceTB/SmolLM3-3B repository is pinned at
`a07cc9a04f16550a088caea529712d1d335b0ac1`. Its model-card header declares
Apache-2.0; there is no separate LICENSE file in that pinned file listing. The
full Apache-2.0 terms had already been read for the pinned Transformers study;
the repository declaration was reviewed before config/index bodies. Declaration,
URLs, exact byte counts and SHA-256 values are under
`evidence/ordinary-model-metadata-2026-10-20/`. Only public repository metadata,
the card and two ordinary JSON metadata files were read. No weight file,
checkpoint tensor data, model implementation or compiler was downloaded/run.

The pinned [index](https://huggingface.co/HuggingFaceTB/SmolLM3-3B/blob/a07cc9a04f16550a088caea529712d1d335b0ac1/model.safetensors.index.json)
contains326 original tensor names mapped to two shard filenames. Metadata also
has `total_parameters`, beyond the documented `total_size`; unknown metadata
must not be silently discarded. Global names are `model.embed_tokens.weight`
and `model.norm.weight`. Each of36 numbered layers has the same nine suffixes:
`input_layernorm.weight`, `post_attention_layernorm.weight`,
`self_attn.q_proj.weight`, `self_attn.k_proj.weight`, `self_attn.v_proj.weight`,
`self_attn.o_proj.weight`, `mlp.gate_proj.weight`, `mlp.up_proj.weight` and
`mlp.down_proj.weight`. These are original-name/file associations, not evidence
of source shape, numerical equivalence, canonical alias correctness or device
layout. No shard payload was opened.

The pinned [configuration](https://huggingface.co/HuggingFaceTB/SmolLM3-3B/blob/a07cc9a04f16550a088caea529712d1d335b0ac1/config.json)
declares `model_type=smollm3`,36 layers,16 query heads,4 KV heads, tied embeddings
and BF16. It includes `no_rope_layer_interval`, `no_rope_layers` and `layer_types`
arrays, plus `pretraining_tp`, `use_cache` and window fields. Preserve their
actual values/types. A familiar projection-name pattern does not establish
that the existing every-layer-RoPE Llama recipe implements this configuration.
The per-layer flags need their documented mathematical semantics. This is a
specific current integration gap to implement toward broad support, not a new
model allowlist or an architecture excluded from the target.

## Existing project reader audit

The owned tagged catalog retains each file's actual source kind/axes/name/path/
extents. It has no shard index or configuration parser and performs no canonical
name remapping. The old semantic/matrix/cache/source-byte types still use GGUF
bindings; changing dtype/name labels cannot migrate them correctly.

The existing project `armvegr.safetensors.JsonParser` already validates UTF-8
strings, JSON strings/integers/numbers, duplicate keys in skipped objects and
bounded nested unknown values. Its byte cursor can be reused through a documented
shared interface; no competing JSON grammar is needed. Borrowed bytes must
remain alive while the cursor is active. Public standalone index parsing needs
strict top-level/object types, duplicate handling, exact end-of-input and owned
copies, not just generic skip success.

`hailbru.syscall.read_file_bytes` returns at most its cap and may return a
truncated prefix without signaling oversized input. It opens with O_RDONLY,
without the nonblocking regular-file admission used by the model readers.
`read_file_str` builds characters from individual bytes rather than validating
UTF-8 as a byte string. These helpers are not a complete untrusted ordinary
metadata-file admission boundary. Do not route index parsing through them
unchanged or advertise their cap as whole-file validation. Their existing
non-model callers are preserved. A bounded regular-file owner/read must reject
oversize/special files and keep exact byte ownership/cleanup.

## Next original implementation

`TASK_hailo10h_source_index_metadata.md` narrows an owned ordinary shard-index
reader/native inspector, preserving original name-to-file mapping and raw
validated metadata/unknown fields. It does not load shards, invent model
architecture, infer tensor shapes from names or certify index size as model fit.
Ordinary config semantics, alias/orientation/rotary facts, complete semantic
storage migration and actual Hailo numerical encoding/configuration/placement/
program execution remain required. The full broad ordinary-model target is
unchanged; all LLM execution stays on Hailo-10H.
