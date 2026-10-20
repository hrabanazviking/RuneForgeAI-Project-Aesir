# Ordinary single weight file without a user-supplied index

Date: 2026-10-20. Parent: `TASK_hailo10h_source_neutral_semantics.md`.
Fixed scope: `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.
Prior connection: actual indexed collection from `TASK_hailo10h_shard_collection.md`.

Publish the exact API/ownership plan before code. Add an original native loader
for an ordinary unindexed safetensors weight file plus its ordinary config,
using explicit root-relative input labels and caller policies. The user must
not create an index/manifest, convert weights or compile a model. File labels
are inputs, never a vendor catalog or naming-pattern eligibility check. This
bounded file-format implementation does not limit the broad target; other
containers/dtypes/architectures remain work.

Reuse actual model-root fd admission, consumed positional JSON/header readers,
owned full-rank storage and exact config raw values. Factor common admission/
policy/accounting helpers with the indexed loader where appropriate. Preserve
its existing API and complete output. Do not pretend a generated index was read
from disk or report index-to-source verification when no index was supplied.
Represent absent index provenance explicitly. Header names alone establish
source namespace, not semantic aliases, tied weights, orientation/RoPE defaults
or an executable architecture. No source payload/model evaluation or device work.

Expose a real inspector consuming ordinary files. Verify tiny single-file cases
with scalar/empty/full-rank tensors, initial floating dtypes, original Unicode/
NUL names, raw unknown config modifiers, ownership, aggregate/per-parser policy
boundaries, path containment, missing/malformed input and success/error/repeated
cleanup. Trace only the actual config/weight file opens, no phantom index open,
source mmap, payload reads or device access. Regress indexed and shared readers.
After verified publication, continue complete tagged semantic storage/ordinary
config adapter integration and actual numerical Hailo encoding/execution.


Concrete published-first design:
`docs/HAILO10H_UNINDEXED_SOURCE_COLLECTION_DESIGN.md`.


Implementation receipt: `docs/HAILO10H_MOJO_UNINDEXED_SOURCE.md`;62 methods/2299
native calls including regressions. Ordinary input metadata is verified, not
model execution. Next: `TASK_hailo10h_semantic_storage_migration.md`.
