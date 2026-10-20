# Owned ordinary shard-index metadata

Date: 2026-10-20. Parent: `TASK_hailo10h_source_neutral_semantics.md`.
Facts first: `docs/HAILO10H_ORDINARY_MODEL_METADATA_FACTS.md`.
Owner scope: `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

Consumer: original native source-model loading and future checked multi-file
storage binding. Implement a real standalone metadata parser/API and inspector
for ordinary `model.safetensors.index.json`, retaining original tensor names and
file labels. This is a source index, not an architecture/shape/math/device plan.

Audit/reuse the existing strict JsonParser byte cursor through a documented
shared interface. Preserve current safetensors behavior; avoid duplicating JSON
string/number/recursive unknown-value grammar. Add only the complete index
object grammar. Own returned name-to-file strings, input path/extent and validated
raw JSON values for metadata and unknown root fields so fields such as
`total_parameters` are not discarded. Require an object-valued `weight_map`
with string names/file labels; reject duplicate decoded keys and wrong required
field types, malformed UTF-8/escapes/numbers, trailing data and truncated JSON.
Handle optional metadata/unknown objects without inventing architecture defaults.
Any total-size interpretation must retain original raw values and enforce actual
nonnegative integer semantics explicitly; a declared count is not a tensor sum
or immutable source/file-size certificate.

Both a borrowed bounded byte API and a path wrapper should return owned values.
Introduce/use a proper bounded regular metadata-file admission/read owner: do not
mistake the existing cap-truncating read_file_bytes or byte-to-character helper
for whole-file UTF-8 validation. Use nonblocking/read-only regular-file admission,
explicit byte/count/work/nesting limits and cleanup on success/error. Keep byte
buffers/mappings alive for the cursor and never return borrowed pointers. Refuse
oversize input rather than accepting a valid truncated prefix. Preserve current
unrelated file helper callers; document any new shared API and its policies.

Do not open/download shard labels, execute remote code, resolve canonical aliases
or infer dtype/shape/orientation/RoPE from a name pattern. Index file labels are
metadata until a later explicit model-root resolution/binding step; preserve
original spelling and distinguish labels from verified backing-file paths.
Subsequent shard aggregation must check actual files/tensors/extents and all
config modifiers. This first boundary must not count metadata size or parsing
as hardware fit, full architecture support or source-model execution.

Verification: independent JSON/UTF-8/escape/duplicate/type/number/depth/trailing/
truncation fixtures, original Unicode/NUL tensor names and exact file labels,
metadata/unknown-value preservation, ownership after input mutation/destruction,
byte/count/work limits, special/oversized file refusal and success/error cleanup.
Use tiny independent synthetic indexes and cross-check parsed public metadata
only under its recorded provenance; no weight or checkpoint payloads needed.
Regress existing safetensors JSON/parser/inventory/constants and tagged storage
consumers after any shared cursor change. No CPU/CUDA/cloud model/layer/attention
forward, outside compiler, special conversion, vendor artifact prerequisite,
guessed register/opcode, device write/reset or firmware/kernel change. Publish
verified original implementation, then automatically continue configuration,
shard storage/semantic migration and actual numerical Hailo execution work.
