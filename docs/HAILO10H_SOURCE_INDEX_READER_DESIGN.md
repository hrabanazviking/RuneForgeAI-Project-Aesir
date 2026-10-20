# Native ordinary index reader: concrete boundaries

Date: 2026-10-20. Implements published
`TASK_hailo10h_source_index_metadata.md`. This narrowing is published before
production changes. Scope is ordinary metadata, never a model/device pass.

## Exact bounded regular-file read

Extend the existing HAILBRU syscall gateway with a checked regular-file-size
query using the already supported Linux statx syscall. Installed UAPI stat.h
SPDX (`GPL-2.0 WITH Linux-syscall-note`) was read before its public declarations.
The fixed256-byte record has mode at28 and unsigned size at40; TYPE|SIZE is
0x201, requested/present fields must be checked. Independent compiled C offsetof/
sizeof/constants agree. Hash and output: `evidence/source-index-facts-2026-10-20/`.
Only public ABI facts are used, no external implementation copied/translated.

A new source metadata byte reader will use host architecture detection and
existing gateway calls. Admit nonempty non-NUL paths and positive byte bounds,
open read-only/nonblocking/close-on-exec, require a regular fd and an initial
size within the bound. Read from that same fd up to size+1 with checked short
reads; reject extra data, early EOF or a changed final size. Close on every
success/error path. Return copied bytes. Do not reopen the path or use mmap for
this boundary; avoid truncated mmap faults if the file shrinks. Same-size
concurrent rewrites remain outside immutable identity guarantees. Linux ARM64
is the tested path; other host syscall coverage must be described truthfully.

## Shared JSON cursor and schema

Reuse `armvegr.safetensors.JsonParser` through documented public `peek`, raw
checked byte-span copy and validated raw-value copy methods. Preserve its
existing grammar and consumers. A complete first pass validates JSON, decoded
key uniqueness, bounded nesting and exact end of input; a schema pass reads
root/metadata/weight-map objects into owned strings. No external JSON runtime.

Public owned policy fields: byte bound, tensor-entry bound, schema-member bound,
work-unit bound, nesting bound. Bounds are positive, recursive nesting at most64
for current host-stack policy. Work units are4*input bytes plus schema members
(root fields, direct metadata fields and weight-map entries), charged with
checked arithmetic. Nested unknown fields remain raw validated JSON, bounded by
bytes/work/depth; schema-member count does not pretend to count those members.
This is an explicit metadata policy, not CPU instruction/time accounting.
Whole-JSON validation precedes schema count checks; input byte/work bounds are
checked before that pass and bound its memory/work independently.

`SourceShardIndex` owns original decoded name-to-file labels, raw JSON values
for metadata/unknown root fields, input extent/path (empty for byte-only API),
metadata-presence, parsed nonnegative total_size when present, and policy usage.
Raw total_size is retained; fractional/boolean/string/negative/overflow values
cannot become a valid declared byte count. Empty weight maps and optional
metadata are representable. Labels are preserved strings, not opened paths.
No shard resolution, architecture/default/shape/alias/orientation inference or
hardware identity/fit/execution is certified.

Native inspector, direct borrowed-byte/ownership API and independent malformed/
Unicode/bounds/file cleanup oracles will consume the new boundary. Rebuild
existing safetensors reader/constants and tagged storage after cursor changes.
Preserve all failed evidence and publish verified original code, then continue
configuration/shard/semantic/numerical execution work toward broad support.
