# Safetensors parser consumes an admitted owned descriptor

Date: 2026-10-20. Parent: `TASK_hailo10h_shard_collection.md`.
Fixed scope: `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Prior owner: `docs/HAILO10H_MOJO_MODEL_ROOT.md`.

Audit/publish the exact transfer API before code. Extend the existing parser
through its documented interface to consume one already admitted regular-file
fd, with ownership on entry and success/error cleanup. Reuse existing strict
header/descriptor/shape/coverage validation; never reopen a descriptive path,
duplicate JSON grammar or weaken existing path/CPU guards. Avoid a domain cycle
between parser and SMIÐR owners: explicit fd/architecture transfer is appropriate.
The parser must verify actual fd regular type/size and enforce header/tensor/
rank/work/depth policies; no supplied path/size metadata can replace that check.
Use the same owned mapping/constant consumer contract or document any changed
source representation before implementation. Live mmap concurrency/immutable
identity limitations remain explicit rather than falsely certified.

Connect a native model-root-to-safetensors inventory consumer, closing root/
file/parser on all paths. Transfer refusal, pre-existing parser state, invalid
fd, short/malformed header, special file, injected statx/mmap/parse/close failures,
source rename/path replacement, copied output and repeated/late cleanup need
independent tiny-file verification. Test direct transferred-fd ownership and
regress existing inventory/static constants/tagged storage/index/config readers
if shared behavior changes. No tensor/model forward or external model compiler.
After verified publication, automatically aggregate distinct indexed shards and
check exact original names/labels/counts/extents against the source index.
Numerical Hailo execution and broad model/architecture support remain required.
