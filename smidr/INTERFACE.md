# SMIÐR source compiler boundary

`source_inventory.mojo` exposes move-only `SourceTensorInventory` and value
`SourceTensorBinding` descriptors. `read_source_inventory(path)` owns a bounded
read-only GGUF parse; `inventory_from_source(source)` borrows an existing live
parse. Only checked value descriptors escape. Neither verifies source identity
for subsequent reopening; hashing/revalidation is a later runtime requirement.

`semantic_plan.mojo` exposes move-only `SemanticPlan`, typed `SemanticTensor`
and `SemanticOperation` values, checked positive shape multiplication and
`read_dense_semantic_plan(path, query_tokens, past_tokens, context_capacity)`.
The current incremental importer constructs dense Llama decoder graph semantics
without importing a backend registry or invoking model execution. Other
architectures/modifiers are named importer work, never a hardware allowlist.

Linear source columns are input width, rows output width. Tensor lifetimes are
inclusive operation indices; -1 means external/preexisting storage and
len(operations) is the retained-output/session-end sentinel. Persistent KV base
tensors span the graph. Append views alias those bases and never own additional
storage. Query and KV heads, key and value dimensions and query/past/capacity
are distinct. Required runtime values/preconditions and unresolved layout,
RoPE, precision, quantization, resource and device-program gates must be carried
forward; the inspector reports each proof flag false.

These are host compiler structures, not executable programs or hardware fit
certificates. Do not pass their JSON or legacy COMPUTE_UNKNOWN/SMIDR-CFG
payloads to a device as compute. Evidence and complete limitations:
`docs/HAILO10H_MOJO_SOURCE_INVENTORY.md` and
`docs/HAILO10H_MOJO_SEMANTIC_PLAN.md`.

`storage_estimate.mojo` exposes `StorageAssumptions`, `StorageEstimate`, checked
byte arithmetic and `estimate_storage(plan, policy)`. The policy must explicitly
supply widths/alignment, aggregate device-weight/workspace bytes, budget and
provenance. Owning tensors are counted once; persistent aliases own zero bytes.
The returned timeline/peak is aggregate live byte volume, not a placed arena or
hardware fit certificate. There is no inference admission or allocation path.
See `docs/HAILO10H_MOJO_STORAGE_ESTIMATE.md` for exact interpretation and proof.

`context_actions.mojo` exposes a tagged, owned `ContextAction(kind, timestamp,
values)` and exact bounded `encode_context_action` / `decode_context_action`.
Kinds 0/3/27/35 only; field order, ownership, range checks and independent
public-header evidence are in `docs/HAILO10H_MOJO_CONTEXT_ACTIONS.md`. This byte
primitive is neither a CCW/numerical program nor an hRPC upload payload. No
device/syscall access or submission consumer exists in this codec slice.

`primitive_recipes.mojo` exposes `PrimitiveRecipes`, owned local
`PrimitiveRecipe`/`RecipeValue`/`RecipeOperation` values and
`lower_primitive_recipes(plan)`. RMSNorm and SiLU are expanded into mathematical
IR; untouched source operation IDs remain named. No production arithmetic is
evaluated. Exact source bindings/scalar bits, local reference conventions,
shape/lifetime evidence and unresolved device/precision/storage gates are in
`docs/HAILO10H_MOJO_PRIMITIVE_RECIPES.md`.

The primitive pass additionally expands last-axis softmax. Every recipe now
carries runtime preconditions; masked -infinity is allowed only with at least
one finite value per row and no NaN/+infinity. They are obligations, not already
validated runtime data. Current regression/softmax evidence:
`docs/HAILO10H_MOJO_SOFTMAX_RECIPE.md`. Expanded graph/storage integration is
contracted in `TASK_hailo10h_expanded_graph.md`.

`expanded_graph.mojo` exposes move-only `ExpandedGraph` owning the original
semantic plan/recipes plus global `ExpandedValue`/`ExpandedOperation` values.
`expand_semantic_graph(plan)` consumes the source plan, splices recipes into
global IDs and recomputes lifetimes. All weight constants are explicit and
deduplicated; predicates/index values and KV aliases are explicit. This is IR,
not device lowering or storage qualification. Complete conventions/evidence:
`docs/HAILO10H_MOJO_EXPANDED_GRAPH.md`.

`expanded_storage.mojo` exposes `ExpandedStorageAssumptions`,
`ExpandedStorageEstimate`, `validate_expanded_storage_graph` and
`estimate_expanded_storage`. Predicate width and all other byte assumptions,
aggregate pools/budget and provenance are explicit. Source constants/KV views
are not duplicate allocations. Exact global last uses and typed roles are
validated before checked event accounting. This remains a hypothetical live
byte volume, never hardware fit/admission. Evidence and complete limits:
`docs/HAILO10H_MOJO_EXPANDED_STORAGE.md`.

`source_float_constants.mojo` exposes move-only `FloatingConstantWindow`,
integer half/BF16-to-binary32 bit conversion, `read_floating_constants` over a
live PackedGGUF owner with an explicit host bound, and a path wrapper returning
only copied bindings/bits. This is source representation decoding, not device
precision/packing or numerical inference. Payload rules, exhaustive 16-bit
pattern evidence and identity/concurrency limits:
`docs/HAILO10H_MOJO_SOURCE_FLOAT_CONSTANTS.md`.

`source_q4k_constants.mojo` exposes move-only `Q4KConstantWindow`, value
`Q4KConstant`, `read_q4k_constants` over a live PackedGGUF owner and an owned
path wrapper. Return source d/dmin bits, binary32 representation bits and
unsigned q/scale/min factors in exact source order under an explicit host bound.
No floating model arithmetic or device packing is performed. Schema, external
static reference evidence and remaining identity/device gates:
`docs/HAILO10H_MOJO_SOURCE_Q4K_CONSTANTS.md`.

`program_header.mojo` exposes value `ProgramHeaderV3` / `ProgramSectionLayout`,
owned 56-byte big-endian encode/decode and `layout_program_sections` with checked
UInt64 sums, explicit positive host bound and exact total extent. Hash fields
are unverified integers; no full container, checksum, device target/CCW or
execution admission is provided. Evidence/remaining gates:
`docs/HAILO10H_MOJO_PROGRAM_HEADER.md`.

`cache_layout.mojo` exposes explicit `CacheLayoutAssumptions`, owned
`CacheLayout`/`CacheRegion`, `plan_cache_layout`, `validate_cache_layout` and
`cache_element_offset`. Source cache/view identities and relative token-major
row addresses are checked under caller-supplied widths, strides, alignment, pool
and provenance. No physical layout, allocation, ring mutation, cache data or
execution is admitted. Exact scope/evidence:
`docs/HAILO10H_MOJO_CACHE_LAYOUT.md`.

`matrix_tiles.mojo` exposes owned `MatrixTilePolicy`, `MatrixSchedule`,
`MatrixTile`, `plan_matrix_contraction`, `validate_matrix_schedule`,
`matrix_workspace_bytes`, `matrix_tile_count` and lazy `matrix_tile`.
Source-bound M/N/C contractions retain logical head splits, packed source
binding and explicit workspace assumptions. Tile origins are logical element
indices, not packed file/device byte addresses. This is mathematical scheduling,
not numerical hardware code or hardware admission. Exact traversal, checks,
independent evidence and remaining gates: `docs/HAILO10H_MOJO_MATRIX_TILES.md`.

`source_weight_tiles.mojo` exposes owned `SourceWeightSpan`, move-only
`SourceWeightTile` and `read_source_weight_tile(source,schedule,index,bound)`.
The live source binding must match the checked schedule. Minimal complete
packed-block spans and copied source bytes retain prefix/suffix metadata and
survive source/schedule destruction. The aggregate bound covers payload only.
This is source byte streaming, not immutable identity/device packing/compute.
Exact ownership, byte-oracle evidence and limitations:
`docs/HAILO10H_MOJO_SOURCE_WEIGHT_TILES.md`.

`source_q5q6_constants.mojo` exposes owned Q5K/Q6K component/window values,
`read_q5k_constants` / `read_q6k_constants` over a live PackedGGUF owner and
path wrappers returning copied values after mapping destruction. Q5 affine
factors and Q6 centered/signed factors retain raw half words and exact binary32
representation bits. Explicit bounds apply; no floating model math or device
format/admission is performed. Schema, independent/static-oracle evidence and
remaining gates: `docs/HAILO10H_MOJO_SOURCE_Q5Q6_CONSTANTS.md`.

`program_integrity.mojo` exposes `xxh3_64_window(data,offset,count,work_bound)`
for borrowed bounded byte windows and scalar `ProgramIntegrityResult` values
from `validate_program_integrity(data,host_buffer_limit)`. The latter checks
exact version-3 section extents and the header-selected protobuf-only or full
residue checksum. It never authenticates an unselected domain or validates
executable metadata, numerical CCWs or hardware compatibility. Default unseeded
XXH3-64 is implemented in Mojo with fixed-size hash state and no external hash
runtime. Facts, independent vectors/oracle and limitations:
`docs/HAILO10H_MOJO_PROGRAM_INTEGRITY.md`.

`program_envelope.mojo` connects the checked header/layout and hash primitives.
`plan_program_envelope(protobuf_bytes,ccw_bytes,additional_bytes,padding,bound)`
returns a checked host-representable layout without allocating declared bytes.
`build_program_envelope(protobuf,ccws,additional,padding,protobuf_only,bound)`
returns one independent owned byte list with copied sections, zero-filled
explicit padding and computed checksums; it validates its selected domain.
These are opaque outer bytes, not executable protobuf/CCW validation or hardware
alignment/target/placement/admission. Receipt and ownership/complete-byte oracle:
`docs/HAILO10H_MOJO_PROGRAM_ENVELOPE.md`.

`safetensors_inventory.mojo` exposes owned `SafetensorsTensor` values (name,
source dtype, full shape, elements, file offset/count), move-only
`SafetensorsInventory` (source/data extent, tensors, metadata) and
`read_safetensors_inventory(path,header_bound,tensor_bound,rank_bound,work_bound,depth_bound)`.
It reuses the repaired project `armvegr.safetensors.SafetensorsLoader` metadata
parser and closes mappings before returning copied values. Source dtype IDs
are 0 F16,1 BF16,2 F32; they are distinct from GGUF IDs. It performs no value
loading/conversion or inference and does not fabricate model architecture.
The reader's default `open(path)` remains usable; all optional bounds must be
positive, depth is currently at most64 for recursive unknown-field skipping,
and the descriptor-work policy bounds4*n*n before appending tensor n. `close`
now clears descriptors/metadata/extents; copy desired values before closing.
Other dtypes/shards/semantic mapping/immutable identity and numerical execution
remain work. Exact policies, tests and limits:
`docs/HAILO10H_MOJO_SAFETENSORS_INVENTORY.md`.

`safetensors_constants.mojo` exposes owned `SafetensorsConstantWindow` and
`read_safetensors_constants(source,name,first,count,element_bound)` over a live
existing SafetensorsLoader. The path wrapper `read_safetensors_constant_window`
also accepts all five positive parser policies and closes on success/error.
Windows retain full-rank source bindings/provenance, raw source words and exact
binary32 representation words. Zero-length valid windows are supported. F32
words retain all bits, F16/BF16 reuse integer bit expansion; no floating model
math/value-loader/activation/device packing occurs. Source dtype IDs remain
0 F16,1 BF16,2 F32. Evidence and limits:
`docs/HAILO10H_MOJO_SAFETENSORS_CONSTANTS.md`.

`semantic_plan.mojo` exposes owned `DenseDecoderParameters` and
`build_dense_semantic_plan(source,parameters,query,past,capacity)`; source is
consumed, configuration is copied into the graph. Configuration fields cover
layers, hidden/feed-forward widths, query/KV heads, key/value/rotary widths,
vocabulary/source context, Float32 RoPE base/RMS epsilon and source layout.
`gguf_dense_decoder_parameters(live_source)` handles existing GGUF metadata
semantics; `read_dense_semantic_plan` delegates and closes before graph building.
`validate_dense_gguf_inventory` checks mutable descriptive bindings/byte spans,
not backing-file identity. `validate_dense_decoder_parameters` checks typed
math/session inputs. Existing storage remains GGUF-specific; safetensors dtype
integers must not be passed as GGUF kinds. The graph and unresolved gates remain
compatible. Exact independent complete-graph, ownership and regression evidence:
`docs/HAILO10H_MOJO_TYPED_DECODER.md`.

`source_storage.mojo` exposes owned `SourceStorageTensor` and move-only
`SourceStorageInventory` with container/dtype tags, original names/paths/full
axes/order/elements/spans, file/data extents and safetensors metadata.
`source_storage_bytes(tensor)` checks container-specific byte arithmetic;
`validate_source_storage(inventory,tensor_bound,rank_bound,work_bound)` checks
mutable descriptive consistency, sorted spans/coverage and explicit policies.
`gguf_source_storage(live_source,tensor_bound,rank_bound,work_bound)` projects
existing descriptors; `read_gguf_source_storage` owns/closes its parser.
`read_safetensors_source_storage(path,header,tensors,rank,work,depth)` applies
existing parser policies, then projects copied values after source close.
New work units are n*(2*ceil(log2(n))+3)+sum(ranks); GGUF parser admission/work
still occurs before projection. These values are not a file identity, semantic
alias, physical layout or execution certificate. Existing graph storage remains
GGUF-specific. Schema, exact cross-format projection/ownership/bounds evidence
and remaining integration: `docs/HAILO10H_MOJO_TAGGED_SOURCE_STORAGE.md`.

`source_metadata_file.read_source_metadata_bytes(path,byte_bound)` returns an
owned exact byte list from a read-only/nonblocking regular Linux file. One fd
is used for initial size, short-read loop/one-byte lookahead and final size;
oversize, early EOF, extra bytes, errors and changed extent refuse with cleanup.
It does not mmap or authenticate same-size concurrent rewrites.

`source_index.mojo` exposes owned `SourceIndexPolicy(bytes,tensors,fields,work,depth)`
and move-only `SourceShardIndex`: source path/extent, original weight_map labels,
raw validated metadata/unknown-root JSON values, metadata presence, declared
integer total_size (or-1 absent), and policy usage. `parse_source_index(data,policy)`
borrows bounded bytes and returns independent values with an empty source path;
`read_source_index(path,policy)` uses the exact file reader and attaches the path.
Policies are positive, depth at most64. Work units are4*input bytes plus root,
direct metadata and weight-map members. A complete JSON/duplicate/depth/EOF pass
precedes schema-count checks; byte/work admission precedes both passes.
Labels are strings and are never opened/resolved. No architecture, shape,
immutable identity, hardware fit or execution follows from index metadata.
Shared cursor ownership contract: `armvegr/INTERFACE.md`. Full independent
boundary evidence: `docs/HAILO10H_MOJO_SOURCE_INDEX.md`.


`source_config.mojo` exposes `SourceConfigPolicy(bytes,fields,work,depth)` and
move-only `SourceConfiguration(source_path,source_bytes,fields,work_units)`.
`parse_source_config(data,policy)` borrows bytes and returns owned original root
names/raw validated JSON values with an empty path. `read_source_config` uses
the exact regular-file owner and attaches the path. Root must be an object;
empty objects and arbitrary field types are retained without defaults. Positive
policies/depth at most64 and exact EOF apply; logical work is4*bytes+root fields.
Whole-document validation precedes field collection. No semantic interpretation,
model code, shard/tensor loading, immutable identity, hardware fit or execution
is certified. Receipt: `docs/HAILO10H_MOJO_SOURCE_CONFIG.md`.


`source_root.mojo` exposes `SourceRootPolicy(path_bytes,files,work,source_bytes)`,
move-only `SourceModelRoot`/`SourceRegularFile` and
`open_source_model_root(path,policy)`. `root.open_file(label)` admits the actual
beneath-root regular fd; files counts valid-label attempts, work charges root
bytes+sum(label bytes+1), including failed opens. Positive policies/path at most
4095, ARM64 Linux only currently. Absolute/empty/NUL labels, escaping/special
files and unavailable kernel interfaces refuse. Original labels/paths/sizes
are descriptive, not immutable fingerprints. Root/file `close()` is idempotent;
`file.take_fd()` transfers responsibility once, leaving it disarmed. Explicit
close errors raise; destructors provide last cleanup. Consumers must not mutate
owner fd/architecture or close borrowed descriptors. File can outlive root.
Next parser must consume the same transferred fd, closing on every path.
Actual independent admission/transfer/cleanup evidence and policy limits:
`docs/HAILO10H_MOJO_MODEL_ROOT.md`. No tensor parser or execution claim.


`safetensors_fd.mojo` exposes `SafetensorsFdPolicy(header_bytes,tensors,rank,
work,depth,read_bytes)` and `read_safetensors_owned_fd(fd,policy)`. The function
consumes exclusive ownership on entry, including invalid-policy/host/read/parse
errors. Actual regular TYPE/SIZE is checked on the same fd; positional reads
copy only8-byte prefix+bounded declared header, never payload or a pathname
reopen. Full extent is rechecked, then native close must succeed before return.
Positive policies/depth at most64 apply; read_bytes includes the prefix, work
is the existing descriptor-count guard, not a total instruction/deadline cap.
Currently verified ARM64 Linux. Returned SafetensorsInventory owns copied
metadata after fd close and carries no mapping. Caller retains original label/
descriptive path separately for shard binding; no immutable identity follows.
`safetensors_inventory_from_header(header)` copies a validated, unmodified
SafetensorsHeader projection; it is not a validator for arbitrary mutated fields.
Existing path inventory/static constants retain separate full-map behavior.
Diagnostic format is shared through `describe_safetensors_inventory`.
Exact equivalence/read/cleanup/regression limits:
`docs/HAILO10H_MOJO_SAFETENSORS_FD.md`.


`source_metadata_file.read_source_metadata_owned_fd(fd,byte_bound)` consumes
exclusive ownership on entry, returns exact owned regular-file bytes with
positional short reads/lookahead/size recheck and native close on success/error.
Positive byte bound, representable size+1 and ARM64 positional ABI apply. No
format/UTF-8/JSON interpretation occurs here. Existing path reader retains
current-offset syscall read/close while sharing exact read arithmetic.
`safetensors_source_storage(inventory,path,tensors,rank,work)` is the shared
owned tagged-storage projection/validator; path is descriptive, not immutable
identity. The ordinary path reader delegates to it after source close.

`shard_collection.mojo` exposes move-only SourceShardFile/SourceShardCollection,
ShardCollectionPolicy(shards,tensors,metadata_bytes,payload_bytes,work) and
read_indexed_shard_collection(root,index_label,config_label,root_policy,
index_policy,config_policy,fd_policy,collection_policy). It opens actual root
JSON/shard fds, preserves exact source metadata and verifies every original
name against its indexed label, missing/extra/global duplicate names and optional
payload total_size. Shard metadata remains separate. Aggregate metadata bytes
include both JSON files and all shard prefixes/headers; work = metadata bytes
+ indexed names + distinct labels + actual tensors + sum(ranks). All policies
are positive and checked; remaining read/count caps apply before growth. The
result owns values after every file/root is closed, no payload read/mmap or model
execution. Mutation invalidates earlier validation. Initial format/dtype/host
coverage is explicit implementation work, not permanent model eligibility.
Receipt: `docs/HAILO10H_MOJO_SHARD_COLLECTION.md`.
