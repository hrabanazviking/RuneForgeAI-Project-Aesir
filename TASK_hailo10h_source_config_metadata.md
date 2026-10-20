# Owned ordinary model configuration metadata

Date: 2026-10-20. Parent: `TASK_hailo10h_source_neutral_semantics.md`.
Scope: `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Prior boundary: `docs/HAILO10H_MOJO_SOURCE_INDEX.md`.
Public metadata facts: `docs/HAILO10H_ORDINARY_MODEL_METADATA_FACTS.md`.

Implement an original Mojo owned ordinary configuration object reader and
native inspector. Reuse the published strict JsonParser cursor and exact bounded
regular-file byte owner. Both borrowed-byte and file APIs must preserve every
root field name and its validated raw JSON value, original numeric/escape
spelling and nested modifiers. Record descriptive path/byte extent, field/work
counts and explicit caller policies. A configuration root must be an object;
empty objects are representable. No required architecture fields or invented
defaults at this generic boundary. A field such as model_type, architectures,
rope/no_rope/window/bias/tied metadata is retained even when its semantic
adapter is unimplemented. Never silently convert SmolLM3 modifiers into the
existing every-layer Llama recipe.

Use positive byte/root-member/logical-work/depth bounds with checked arithmetic,
global maximum nesting64 and exact EOF. Work units are4*input bytes plus root
members, not a deadline. Reject malformed UTF-8/JSON, duplicate decoded keys
at any depth, invalid policies and over-limit input before partial success.
Own returned raw strings across input mutation/destruction. Inspector flags
must state metadata-only: no tensors/shards loaded, no semantic model adapter,
immutable fingerprint, hardware fit or numerical execution certified.

Verify independent tiny JSON, Unicode/NUL/escape/numeric/raw-text preservation,
all root types, duplicates/nesting/truncation/trailing/malformed UTF-8, exact
policy edges, borrowed ownership and file cleanup. Hash-check the already
recorded pinned ordinary config fixture without downloading weights. Regress
source-index and existing safetensors consumers if any shared behavior changes.
Do not run a CPU/CUDA/cloud LLM/layer/attention forward, outside compiler,
remote model code or guessed device instruction. Publish verified code and
advance automatically to checked shard storage and full architecture semantics,
while actual numerical Hailo encoding/configuration/execution remains open.
