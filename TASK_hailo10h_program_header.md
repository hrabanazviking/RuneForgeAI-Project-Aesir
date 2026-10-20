# Original program header and checked section layout

Date: 2026-10-20. Contract before implementation.
Parent: `TASK_hailo10h_program_delivery.md`.
Published field facts: `docs/HAILO10H_ORIGINAL_PROGRAM_STRUCTURE.md`.

Consumer: the future SMIÐR original compiled-program output builder. Implement
original Mojo owned value/header encoding and exact fixed-header decoding for
outer version 3 only as incremental output-format coverage, with explicit
big-endian fields and zero reserved bytes. Expose checked UInt64 section
length/origin arithmetic, padding≤CCW-with-padding, caller-supplied positive
host buffer bound and exact total-extent validation. Do not allocate a declared
program, infer physical allocation or accept unknown versions. Separate the
header's integer hash fields from verified checksum state; never label the
header-only result a valid executable/integrity-checked program. Preserve
separate device/container architecture namespaces; this codec does not choose
a hardware target or lower an operation.

Acceptance: complete bytes/offsets against independent Python struct vectors,
seeded/extreme integer fields, all section origins/lengths against checked
arithmetic, round trips and retained ownership; wrong magic/version/length/
reserved data, overflow, inconsistent padding/extent and explicit bound
refusals. Only synthetic bytes are permitted. No vendor compiled-file input,
full-container/payload writing, checksum implementation claim, device open,
program upload/activation or CPU/CUDA/cloud/proxy/model/layer execution.

Keep actual target/layout/stream/configuration metadata, checksum scopes and
alignment, numerical CCW/register encoding, original immutable program owner,
upload/configure/cleanup and first Hailo arithmetic result explicit. Publish
the verified primitive and continue bounded numerical configuration research
toward the owner's same broad source-model objective; do not substitute
container metadata or catalog artifacts for execution.
