# Owned ordinary configuration values

Date: 2026-10-20. Published-first task at d39d481:
`TASK_hailo10h_source_config_metadata.md`. Fixed broad-model scope remains
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

## Original connected implementation

`smidr/source_config.mojo` returns move-only owned configuration metadata from
borrowed bytes or an exact bounded regular-file read. It retains every decoded
root name and exact raw validated JSON value, including unknown modifiers,
numeric/escape spelling and nested whitespace. Empty object configurations are
representable. Fields called model_type or architectures are retained even if
absent or of unusual types: this generic boundary supplies no architecture
validation/defaults. Config adapters must later interpret or explicitly report
unimplemented source semantics rather than discard them.

The shared JsonParser supplies complete UTF-8/JSON/duplicate/depth/EOF validation
before root-field collection. Returned strings survive original input mutation/
destruction, and the byte owner is explicitly pinned through all untracked
pointer use. Positive byte/root-field/work/depth policies are checked before
parsing; depth is at most64. Work units are4*input bytes plus root fields, with
checked arithmetic. They are logical metadata units, not CPU cycles/deadlines.
Unknown nested fields are governed by byte/work/depth bounds, not root counts.
Raw values exclude outer whitespace. Complete source path and byte extent are
descriptive; equal file lengths do not authenticate same-size rewrites.

The file wrapper reuses the already verified exact regular-fd owner, including
nonblocking read-only admission, short-read loop, lookahead, size checks and
success/error close. It does not reopen a path or load tensors/shards. Production
policies are caller-provided. The diagnostic borrowed hex helper admits32768
bytes; it is not the production parser's byte cap. Linux ARM64 is exercised;
other-host execution is not certified. Shared parser/file behavior was unchanged.

## Independent verification

Six new methods pass190 native calls (85 accept,105 expected refusal). Exact
raw text, original Unicode/NUL names/values, absent/unknown/typed modifiers,
sixty seeded configurations, root types, duplicate decoded keys at multiple
depths, malformed UTF-8/escapes/numbers/literals, every truncation of a multibyte
fixture and exact byte/field/work/global-depth limits are checked independently.
Copied dictionaries/raw text survive source mutation and local mutations.

Real configuration files at8191/8192/8193 bytes cross the file-reader chunk edge.
Oversized valid-prefix, FIFO, directory and missing paths refuse. Forty invalid-
then-valid read cycles match source open/close counts. Traces show metadata-only
opens/cleanup, no shard or device access/ioctl. Native linkage is retained.

The pinned ordinary SmolLM3 config (1915 bytes,31 fields) is checked against its
published SHA256 and independently decoded with Python JSON. All no_rope_layers,
layer_types, bias/window/tied/dtype values are preserved; this is not numerical
SmolLM3 or existing Llama recipe support. No model implementation or weights were
downloaded. Public license/provenance remains in
`HAILO10H_ORDINARY_MODEL_METADATA_FACTS.md`.

The source-index regression passes ten methods/516 calls, including its shared
file/cursor and fault/cleanup checks. Full slice: **16 methods/706 native calls**.
Both new builds are warning-free. The first cleanup test failed because its
boundary-file generator reused the reserved valid fixture pathname. A distinct
valid pathname fixes the harness; the failed run/trace remain, with no production
change or weakened assertion. Evidence: `evidence/source-config-2026-10-20/`.

Published index d39d481 CI runs39460369145/39460354407 fail historical master
compilation; later gates skip. New slice CI is observed after publication.
No complete repository or hardware model-execution pass is claimed.

## Next connection

This verifies configuration metadata, not an executable architecture adapter.
Tensor/shard binding, exact semantic storage migration, per-layer rotary/window/
bias/tied handling, device precision/packing/placement, actual numerical CCWs,
upload/activation/result/cleanup and broad model execution remain open. All
inspector semantic/identity/fit/execution flags remain false. Next task:
`TASK_hailo10h_shard_collection.md`.
