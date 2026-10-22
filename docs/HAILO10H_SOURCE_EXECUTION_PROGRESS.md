# Mojo source-model execution progress

The owner's fixed target is Aesir in Mojo running source models that fit the
Hailo-10H hardware. Only the owner may change it. The precompiled-only branch
interpretation was withdrawn in `cd8f397`; historical receipts remain intact.

Latest owner clarification (2026-10-20): **broad model support is 100% the
target**. Aesir must own loading/internal translation of ordinary model files;
no outside compiler or specially precompiled model prerequisite. Active native
slice: `TASK_hailo10h_numerical_encoding_sources.md`, alongside remaining source-format work. Full controlling scope:
`HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

Active parent: `TASK_hailo10h_mojo_model_execution.md`. Automatically complete,
verify, publish and advance each bounded work slice.

| Work slice | State | Evidence / next action |
|---|---|---|
| Owned default/linear rotary scaling | Verified mathematical compiler integration | `HAILO10H_MOJO_DECODER_SCALING.md`;161 methods/6387 calls,64 builds,16 frozen GGUF/8 ordinary outputs and160 recovery cycles. Other variants/full ordinary/numerical device gates stay open. |
| Standalone dynamic context/coefficient primitive | Verified integer arithmetic | `HAILO10H_MOJO_DYNAMIC_CONTEXT.md`;4 methods/122 calls and one clean build,197 existing source hashes/64 controls unchanged. No current graph/cache consumer or dynamic source admission. |
| Source-bound dynamic policy/insertion history | Verified source/integer compiler boundary | `HAILO10H_MOJO_DYNAMIC_SOURCE_HISTORY.md`;4 methods/244 calls,2 clean builds,8 complete source descriptor comparisons and30 ownership traces. No graph/cache data integration or numerical execution. |
| Dynamic source graph and frequency recipes | Verified mathematical compiler integration | `HAILO10H_MOJO_DYNAMIC_GRAPH_LOWERING.md`;70 clean builds/208 relevant sources,173 methods/7059 primary calls. New4/306,84 mutation fields;67 frozen controls covered by3129 success-output/3287 handled-error comparisons. No model or numerical Hailo execution. |
| Remaining scaling/modifier semantics | Active qualification | `TASK_hailo10h_dynamic_scaling_semantics.md`;192 static initializer cases plus576 state callbacks/1728 words and432 fixed-pair identities;64 frozen controls. Standalone context/coefficient primitive now verified under `HAILO10H_MOJO_DYNAMIC_CONTEXT.md`. Next:`TASK_hailo10h_dynamic_decoder_integration.md`;five native probes reproduce source-context/capacity coupling,199 source hashes/65 controls frozen. Phase1 source/history binding verified;next:`TASK_hailo10h_dynamic_graph_lowering.md`. Phase2 now verified under `HAILO10H_MOJO_DYNAMIC_GRAPH_LOWERING.md`. Remaining architecture/format/modifier semantics and actual numerical encoding/configuration/delivery/results stay open; continue `TASK_hailo10h_numerical_encoding_sources.md`. |
| Ordinary window semantics | Verified mathematical compiler integration | `HAILO10H_MOJO_DECODER_WINDOW.md`;154 methods/5455 calls,58 builds,16 frozen GGUF/8 ordinary outputs and160 recovery cycles. No physical compaction or numerical device claim. |
| Ordinary cache/session semantics | Verified mathematical compiler integration | `HAILO10H_MOJO_DECODER_SESSION.md`;147 methods/4730 calls,51 builds,8 complete frozen GGUF/2 ordinary comparisons and160 recovery cycles. No numerical device proof. |
| Source activation selection/lowering | Verified mathematical compiler integration | `HAILO10H_MOJO_DECODER_ACTIVATION.md`;140 methods/4124 calls,46 builds,8 complete frozen GGUF and4 additional full comparisons. Other activations/full ordinary/numerical device gates remain open. |
| Source-bound projection bias arithmetic | Verified mathematical compiler integration | `HAILO10H_MOJO_DECODER_BIAS_GRAPH.md`;131 methods/3621 calls,41 builds,8 complete frozen outputs. Original vector addition and cache/matrix/storage integration; full ordinary/device gates open. |
| Qualified ordinary head/bias schema | Verified source-header binding | `HAILO10H_MOJO_ORDINARY_PROJECTION_SCHEMA.md`;14 methods/326 calls,4 builds,9 complete frozen outputs. Seven optional bias sources/layer and qualified heads; bias math/full ordinary/device gates open. |
| Exact source scalar propagation | Verified source representation/math boundary | `HAILO10H_MOJO_SOURCE_SCALAR_PRECISION.md`;115 methods/3111 calls including shared-import closure,32/64 source words through typed/recipe/expanded IR, no implicit narrowing. Complete ordinary semantics and numerical Hailo execution remain open. |
| Explicit source-bound rotary recipes | Verified mathematical compiler integration | `HAILO10H_MOJO_ROTARY_RECIPES.md`;104 methods/2864 calls, explicit two-input/basis mapping and recomputed storage. Ordinary scalar/modifier adapter and numerical Hailo execution remain open. |
| Qualified ordinary omitted/null defaults | Verified source interpretation refinement | `HAILO10H_MOJO_ORDINARY_DEFAULTS.md`;44 methods/1285 calls,28 complete explicit old outputs and326 actual header geometries. Raw fields/origins and all remaining execution gates retained. |
| Owned ordinary projection bindings | Verified source compiler boundary | `HAILO10H_MOJO_DECODER_PROJECTIONS.md`;38 methods/1168 calls, actual326 header bindings, independent source Q/K/V widths and explicit output intent. Complete rotary/modifier adaptation and numerical execution remain open. |
| Owned ordinary parameter/modifier intent | Verified source interpretation | `HAILO10H_MOJO_DECODER_ARCHITECTURE.md`;31 methods/1053 calls, exact scalar words and raw/layer/default ownership. Actual source aliases/axes/output binding and full architecture/numerical execution remain open. |
| Explicit typed decoder graph/cache policy | Verified compiler structure | `HAILO10H_MOJO_DECODER_GRAPH_POLICY.md`;99 methods/2711 calls,40 complete NoPE graphs and108 frozen consumer comparisons. Actual ordinary architecture/alias/modifier adapter and numerical execution remain open. |
| Owned ordinary decoder-layer intent | Verified source interpretation | `HAILO10H_MOJO_DECODER_LAYERS.md`;19 methods/701 calls, retained raw modifiers and source/default mask provenance. Explicit graph/cache NoPE policy and complete architecture/numerical execution remain open. |
| Tagged semantic storage migration | Verified compiler boundary | `HAILO10H_MOJO_SEMANTIC_STORAGE.md`;94 methods/2559 native calls,108 complete frozen consumer comparisons. Actual ordinary architecture/rotary/modifier adapter and numerical device execution remain open. |
| Integrated-device envelope | Verified as a host protocol primitive | `HAILO10H_MOJO_HRPC_FRAMING.md`; native tool, independent wire checks and ownership/refusal checks pass. |
| Typed device requests/replies | Verified as a host wire primitive | `HAILO10H_DMA_PROTOCOL_CORRECTIONS.md`; status 1 now matches observed requests, ten independent protobuf methods pass; replies retain status-0 success. |
| Running driver ABI | Verified as a host byte primitive | `HAILO10H_MOJO_SOC_ABI.md`; twelve ioctl values and 84 complete buffers match the installed C UAPI oracle. |
| Owned native driver query | Verified on the actual Pi driver | `HAILO10H_MOJO_DRIVER_OWNER.md`; actual properties/version, identity and observed close/refusal/error/unwind checks. No connection or DMA. |
| PCIe descriptor / connection lifecycle | Verified on the actual Pi driver | `HAILO10H_MOJO_SESSION_LIFECYCLE.md`; actual assigned channels, ordered close, six injected failures and exception cleanup. |
| Reference DMA interface observation | Verified reference facts | `HAILO10H_DMA_OBSERVATION.md`: actual 2068-byte submissions, positive descriptor-count returns, request status 1, complete mapping tuples. Not independent Mojo exchange. |
| Driver transfer-result handling | Verified host/API correction | `HAILO10H_DMA_PROTOCOL_CORRECTIONS.md`; positive count 5 preserved, errno/error distinctions checked, all rebuilt driver/connection lifecycle tests pass. |
| USERPTR mapping / sync ABI | Verified host byte primitive | `HAILO10H_MOJO_DMA_STORAGE_ABI.md`; fifteen ioctl values, twelve methods including 40 new C-object buffer comparisons. |
| Owned RPC host storage | Verified physical mapping/lifetime primitive | `HAILO10H_MOJO_DMA_STORAGE_OWNER.md`; two actual USERPTR mappings, explicit sync, 32 child runs including eleven injected pre-effect faults and two post-effect malformed map replies. No transfer. |
| Native bounded worker | Verified host ownership/deadline primitive | `HAILO10H_MOJO_BOUNDED_WORKER.md`; nine methods/48 native runs, actual monotonic timeouts, native callback, rescue joins and whole-process terminal invariant. |
| Assigned interrupt cancellation | Verified physical empty-channel gate | `HAILO10H_MOJO_ASSIGNED_WAIT.md`; six methods/18 native runs, disable retry, join before cleanup, persistent-cancel terminal path and fresh-session recovery. No launch. |
| Owned RPC byte access | Verified host copy/bounds gate | `HAILO10H_MOJO_RPC_BYTES.md`; independent protobuf/header vectors, actual host allocation, complete zero padding, owned snapshots and seven direct refusals. |
| RPC descriptor / completion accounting | Verified host policy and pending-state gate | `HAILO10H_MOJO_RPC_ACCOUNTING.md`; exact aligned descriptor counts, both directions required, error/duplicate refusal; actual mapped-storage pending guards prove no transfer. |
| Owned DMA transfer / typed RPC | Verified physical message exchange | `HAILO10H_MOJO_NATIVE_RPC.md`; actual USERPTR submissions, exact counts, both completions, synchronized reply bytes and correlation; no model/compute. |
| Independent Mojo read-only device round-trip | Verified on Hailo-10H without HailoRT linkage | `HAILO10H_MOJO_NATIVE_RPC.md`; five methods/36 child runs, repeated create/identify/destroy, timeout and failure cleanup with fresh-session recovery. |
| Ordinary safetensors source inventory | Verified compiler input metadata | `HAILO10H_MOJO_SAFETENSORS_INVENTORY.md`; eleven methods/219 calls, repaired existing parser, full axes/scalar/empty/Unicode/NUL/bounds/coverage/cleanup. Initial F16/BF16/F32 metadata only; shard/config/semantics/immutable identity and device execution remain open. |
| Ordinary safetensors static constants | Verified source representation | `HAILO10H_MOJO_SAFETENSORS_CONSTANTS.md`; nine methods/97 calls,264204 exact raw/expanded words, exhaustive16-bit spaces, ownership/window/error-path cleanup. Source-neutral semantics and device precision/packing/execution remain open. |
| Source tensor inventory | Verified compiler input snapshot | `HAILO10H_MOJO_SOURCE_INVENTORY.md`; original typed descriptors, exact source extents, no backend registry restriction, UTF-8/NUL preservation; six methods/16 fixture runs, no execution. |
| Semantic operation graph | Verified compiler structure | `HAILO10H_MOJO_SEMANTIC_PLAN.md`; typed operations, exact source bindings, distinct Q/K/V shapes, residual and persistent-KV lifetimes; nine methods/56 child runs. No numerical lowering or execution. |
| Storage arithmetic | Verified hypothetical compiler scenario | `HAILO10H_MOJO_STORAGE_ESTIMATE.md`; explicit policy/budget provenance, alias-aware timeline and overflow checks; seven methods/61 native calls. Not placed memory or hardware fit. |
| RMSNorm/SiLU mathematical recipes | Verified compiler expansion | `HAILO10H_MOJO_PRIMITIVE_RECIPES.md`; source-bound arithmetic IR, exact epsilon bits, local shapes/domains/lifetimes; six methods/39 native calls and four tiny isolated arithmetic fixtures. Not device numerical acceptance. |
| Stable softmax recipe | Verified compiler expansion | `HAILO10H_MOJO_SOFTMAX_RECIPE.md`; exact reductions/broadcasts, masked-value preconditions and retained local lifetimes; seven methods/44 native calls, five tiny primitive math fixtures including regressions. |
| Expanded graph / updated lifetimes | Verified compiler integration | `HAILO10H_MOJO_EXPANDED_GRAPH.md`; global source/local mapping, explicit constants/predicates/indices/KV aliases, new lifetimes; five methods/45 native calls. No numerical execution. |
| Expanded storage accounting | Verified hypothetical compiler scenario | `HAILO10H_MOJO_EXPANDED_STORAGE.md`; typed roles, exact last uses and explicit predicate width; seven methods/88 native calls. Not physical placement or hardware fit. |
| Floating source constants | Verified source representation reader | `HAILO10H_MOJO_SOURCE_FLOAT_CONSTANTS.md`; bounded owned F32/F16/BF16 windows; six methods/64 native calls, all 131,072 16-bit patterns, source inventory/storage regressions. Not device format or execution. |
| Q8_0 source constants and byte tiles | Verified source representation/conversion | `HAILO10H_MOJO_Q8_SOURCE_CONSTANTS.md`;76 clean Mojo builds,200 methods/9309 primary calls,74 frozen controls covered. New10/137,actual payload fields and byte tiles;10 ownership traces. No numerical Hailo/source-model execution. |
| Q4_K source constants | Verified source affine component reader | `HAILO10H_MOJO_SOURCE_Q4K_CONSTANTS.md`; eight methods/57 native calls, full group-factor/nibble coverage and exact external reference on 4096 synthetic constants. Not device precision or execution. |
| Source-bound cache address scenarios | Verified hypothetical relative addressing | `HAILO10H_MOJO_CACHE_LAYOUT.md`; six methods/89 calls, 3353 independent element-offset checks, source/alias/policy/index/ownership refusals. No physical layout/ring mutation/execution. |
| Native source-bound matrix schedules | Verified mathematical scheduling | `HAILO10H_MOJO_MATRIX_TILES.md`; seven methods/860 native calls,729 small domains/6672 coordinates, lazy tails/source binding/head splits/ownership/overflow. Actual packed source tile reads are next; no device numerical program. |
| Native source weight byte tiles | Verified source storage | `HAILO10H_MOJO_SOURCE_WEIGHT_TILES.md`; five methods/286 calls and88368 exact byte checks, live source binding, packed block spans, copied payload and ownership. No numerical evaluation or device packing/execution. |
| Original Q5_K/Q6_K source components | Verified static representation | `HAILO10H_MOJO_SOURCE_Q5Q6_CONSTANTS.md`; seven methods/88 calls,94416 components and8192 exact static reference checks. Integer field readers only, no device precision/packing/execution. |
| Owned typed decoder configuration | Verified structural graph boundary | `HAILO10H_MOJO_TYPED_DECODER.md`;54 methods/1933 calls with30 complete pre-refactor graph comparisons. GGUF storage remains explicit; tagged storage/config/name integration follows. No model/device execution. |
| Exact admitted GGUF source axes | Verified copied source metadata | `HAILO10H_MOJO_GGUF_SOURCE_SHAPES.md`;28 methods/669 calls preserve declared vector/matrix rank and graph compatibility. Tagged storage/config/name connection remains open. |
| Tagged ordinary-source storage | Verified file metadata/byte arithmetic | `HAILO10H_MOJO_TAGGED_SOURCE_STORAGE.md`;46 methods/1340 calls preserve format/dtype/axes/names/path/spans. Config/shards/semantic migration and execution remain open. |
| Ordinary shard-index metadata | Verified source metadata and exact file admission | `HAILO10H_MOJO_SOURCE_INDEX.md`;37 methods/1289 calls including rebuilt consumers and5 extra header probes. Original names/labels/raw metadata, limits, cleanup and strict JSON; no shard opens or execution. Ordinary config loading follows. |
| Ordinary configuration values | Verified source metadata | `HAILO10H_MOJO_SOURCE_CONFIG.md`;16 methods/706 calls retain31 real fixture fields and all raw modifiers. Semantic adapters and shard binding remain open; owned root/fd admission follows. |
| Beneath-root regular shard descriptors | Verified actual filesystem ownership | `HAILO10H_MOJO_MODEL_ROOT.md`;21 methods/783 calls including77 real admission/transfer/fault/cleanup calls and rebuilt readers. Same-fd parser integration and full shard matching remain open. |
| Same-descriptor safetensors headers | Verified actual owned source metadata | `HAILO10H_MOJO_SAFETENSORS_FD.md`;53 methods/1916 calls including365 new and1551 rebuilt regressions. No source payload read/mmap; exact indexed multi-shard binding follows. |
| Actual indexed shard collection | Verified source metadata binding | `HAILO10H_MOJO_SHARD_COLLECTION.md`;58 methods/2121 calls verify actual JSON/shard fds, original name/label/span/total matching and cleanup. Unindexed input and full semantics/numerical execution remain open. |
| Ordinary unindexed source collection | Verified actual file metadata | `HAILO10H_MOJO_UNINDEXED_SOURCE.md`;62 methods/2299 calls, no generated index or source payload reads. Tagged per-file semantic migration and full config/backend semantics follow. |
| Physical resource placement / backend lowering | Open | Establish actual widths, layouts, weight conversion, workspace, hardware budgets and program encoding; hypotheses cannot admit inference. |
| Nondefault LCU control record codec | Verified host byte primitive | `HAILO10H_MOJO_LCU_ACTIONS.md`;6 clean builds,17 methods/2113 primary calls,244 additional frozen pairs. New456 vectors/492 refusals,seven traces. No physical LCU/numerical/source execution. |
| Public context-action byte codec | Verified host primitive | `HAILO10H_MOJO_CONTEXT_ACTIONS.md`; four public record types, owned values, exact field widths and 244 native calls against independent struct and C++ header oracles. No numerical program or upload. |
| Configuration upload/activation endpoint | Public program receiver mapped; physical original upload open | `HAILO10H_PROGRAM_DELIVERY_BOUNDARY.md`; matching driver rejects NNC firmware controls on the Pi SoC path. hRPC action 2 accepts separate compiled-program bytes, followed by configure/activate lifecycles. Original metadata/lifecycle codec is verified as host bytes; active `TASK_hailo10h_program_delivery.md` continues container/CCW facts. Actual upload, raw-context endpoint and numerical encoding remain open. |
| Original program metadata/lifecycle codec | Verified host wire primitive | `HAILO10H_MOJO_PROGRAM_RPC_CODEC.md`; eight methods/140 calls against generated public-schema protobuf, ten device codec regressions pass. No program transfer or activation. |
| Original configure/stream codec | Verified host wire primitive | `HAILO10H_MOJO_CONFIGURE_RPC_CODEC.md`; eight methods/83 calls, exact public-schema fields/raw float words/NMS sentinels/body limits/strict replies. Program/device regressions pass. No hardware configure or resource ownership. |
| Original program outer integrity | Verified host corruption-check primitive | `HAILO10H_MOJO_PROGRAM_INTEGRITY.md`; eleven methods/2072 calls, all length classes, pinned isolated oracle, 8 MiB/bounds/tamper/ownership. Selected checksum range only; no numerical program/firmware CRC/device acceptance. |
| Original owned program outer envelope | Verified host serialization | `HAILO10H_MOJO_PROGRAM_ENVELOPE.md`; eight methods/194 calls, independent complete bytes, extents/selector/ownership. Opaque supplied protobuf/CCWs remain unqualified; no program execution. |
| Original compiled-program structure | Verified header/layout primitive | `HAILO10H_MOJO_PROGRAM_HEADER.md`; eight methods/151 native calls, independent exact bytes/section arithmetic, overflow/extents/ownership. No checksum/complete program. Public numerical compilation interface leads are recorded in `HAILO10H_PUBLIC_LLM_COMPILER_INTERFACES.md`; source-bound cache address scenario is independently verified. Active parent `TASK_hailo10h_program_delivery.md` continues actual configuration/CCW discovery. |
| Outside-compiler first primitive source experiment | Withdrawn by owner clarification | `HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`; unpublished prototype preserved outside production tree. Continue native source-bound tiling under `TASK_hailo10h_native_matrix_tiles.md`; no external compiler prerequisite. |
| Executable compute-context generation | Open | Learn and emit actual CCW operation/register/configuration/scheduling data and establish upload/activation, then prove the first operation on hardware. |
| Source-model execution and architecture breadth | Open | Earn complete model, format, quantization, memory, numerical and lifecycle gates toward the same broad target. |

These rows organize implementation dependencies. They do not reduce the
owner's requested model scope or make host-only primitives count as device
execution. Old catalog-selection work orders must not resume.

Latest numerical/configuration leads: `HAILO10H_NUMERICAL_ENCODING_LEADS_2026-10-20.md`.
Action4 codec passes8/83; outer integrity passes11/2072. Owned envelope
construction passes8/194; public release delta study follows under
`TASK_hailo10h_public_encoding_delta.md`. Results are now recorded in
`HAILO10H_PUBLIC_ENCODING_DELTA_2026-10-20.md`; no new numerical ISA was found
in that delta. Safetensors inventory passes11/219 and static words9/97; next input work is
tagged full-shape storage/name provenance and ordinary config/index facts; typed
configuration/compatible graph construction passes54 methods/1933 calls,
while actual encoding/configuration/placement/transport work remains open. Architectural
patents are not a device ISA.

Latest integrated-platform qualification:
`HAILO10H_INTEGRATED_NNC_BOUNDARY_2026-10-21.md`. Public receiver/profile facts do
not establish H10H numerical instruction fields or an alternative Pi raw-control
route. Numerical source/configuration/placement/program work stays active.

2026-10-22 bounded target/control qualification:
`HAILO10H_PROGRAM_TARGET_AND_LCU_BOUNDARY_2026-10-22.md` separates the program
target namespace and partial-layout conditions, and qualifies three additional
LCU record bodies for original Mojo serialization. Next native contract:
`TASK_hailo10h_lcu_action_codec.md`. This is public-interface research, with no
new capability ID,numerical instruction,physical acceptance or source execution.

Next source representation work:`TASK_hailo10h_q8_source_constants.md`;
`HAILO10H_Q8_SOURCE_LAYOUT.md` qualifies actual Q8_0 fields and an exact pre-code
loader/constant/byte-tile contract.637 source identities/74 controls are frozen.
No Q8 implementation or device execution is claimed by this contract.

Q8_0 implementation checkpoint:`HAILO10H_MOJO_Q8_SOURCE_CONSTANTS.md` now
records the verified native importer/constant/byte-tile slice under9b69894.
Remaining source ranks/formats/architecture semantics and actual H10H numerical
encoding/configuration/placement/delivery/results continue toward the full target.
