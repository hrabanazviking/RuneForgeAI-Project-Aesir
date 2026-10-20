# Checked ordinary safetensors shard collection

Date: 2026-10-20. Parent: `TASK_hailo10h_source_neutral_semantics.md`.
Owner scope: `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Inputs: owned ordinary index/config and tagged source storage APIs.

Connect ordinary model-root/index labels to real bounded safetensors shard
inventories, preserving original names, labels, dtype namespaces, full axes,
backing paths/byte spans and separate per-shard metadata. Read config without
executing remote code. The source loader must obtain this automatically from
ordinary files; no user-generated compilation or manifest prerequisite.

First bounded child: `TASK_hailo10h_model_root_admission.md`. Publish its ABI/
ownership design before code. Establish one owned regular shard descriptor from
an owned model-root directory, then consume that same descriptor in the existing
safetensors parser. A lexical path precheck followed by a separate path reopen
cannot establish root containment. Do not silently follow escape symlinks or
special files, block on a FIFO, reset the device or alter legacy CPU guards.

After that owner is verified, implement automatic distinct-label enumeration,
per-shard bounded parsing/cleanup and exact index-to-actual-tensor matching.
Check missing/misdirected/extra tensor names and duplicate global names, actual
file spans/coverage and aggregate overflow/policies. Retain per-shard metadata
without merging colliding keys. Compare declared total_size to actual tensor
payload-byte sum when present, never file header sizes or a hardware-fit claim.
Mutable descriptors/path snapshots do not become immutable source identity.

Independent tiny multi-shard files/indexes/configs must cover label reuse,
Unicode/NUL tensor names, shapes/scalars/empty tensors, different source dtypes,
metadata collisions, absent/missing/extra/misdirected/duplicate names, malformed
shard header, oversized inputs and late failure cleanup. Regress shared
safetensors/index/config/storage consumers after each shared change. Source
representation only; no CPU/CUDA/cloud model forward or model weight downloads.
Do not invent numerical opcodes, silently erase architecture modifiers or count
collection metadata as source-model execution. Continue semantic migration and
actual Hailo numerical encoding/configuration/transport/results automatically.


Implementation receipt: `docs/HAILO10H_MOJO_SHARD_COLLECTION.md`;58 methods/2121
native calls including regressions. Actual indexed metadata binding is verified;
source-model execution remains open. Next ordinary single-file input:
`TASK_hailo10h_unindexed_source_collection.md`, then full semantic/backend work.
