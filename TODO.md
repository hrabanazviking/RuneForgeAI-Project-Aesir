## 2026-10-24 — Aligned grouped backing,host qualification

- [x] AES-CONTROL-017 aligned backing under
  `TASK_hailo10h_aligned_grouped_control.md`:typed layout admission
  (power-of-two page in[64,32768]),header@0/body@page,extent page+2048,
  CPU-owned scatter/gather with deterministic gap clearing and exact
  2068-byte projection;legacy defaults preserved. New aligned suites pass
  (storage6,control10,lifecycle12);legacy grouped control10/device12 pass
  rebuilt with byte-identical observable outputs vs pristine baselines
  (574+784 runs);storage bytes4 and session finalization6 pass.
  `docs/HAILO10H_ALIGNED_GROUPED_CONTROL_2026-10-24.md`. No physical child
  was built or run under this contract.
- [x] AES-CONTROL-018 one-shot physical grouped lifecycle on the aligned
  backing under `TASK_hailo10h_aligned_grouped_physical.md` (roadmap
  slice1.4):exactly one child on the real Hailo-10H. CREATE completed
  end-to-end (both launches return5;the -016 EINVAL is gone;exact typed
  reply,real handle);IDENTIFY launched (5/5,spans@0/512) but its
  directional completions were not established,no reply CPU-visible;
  client poisoned correctly,no destroy on poisoned transport,retained
  views0,finalization confirmed. Acceptance FAILED (attempts2,identity
  unmatched);batch CLOSED,no rerun. Campaign1 exit NOT met.
  `docs/HAILO10H_ALIGNED_GROUPED_PHYSICAL_2026-10-24.md`.
- [x] AES-TRANSFER-001 Campaign2 slice2.1 transfer-semantics extraction
  on the Campaign1 evidence only:span description and the physical
  offset-admission rule,launch-return = descriptor count under the
  observed-return policy,IRQ completion records (data 0xFE/0xFF are
  failure indications,never counts),cache-sync sequence,ownership until
  completion,late-completion quarantine.
  `docs/HAILO10H_GROUPED_TRANSFER_SEMANTICS_2026-10-24.md`. New decoded
  datum:identify's second wait in -018 reported 0xFF NOT_ACTIVE for both
  owned channels;cause not established.
- [x] AES-TRANSFER-002 slice2.2 minimal transfer primitive in Mojo on
  S1-S6 only:`hailbru/soc_transfer.mojo` (SocGroupedTransfer,one
  outstanding raw grouped exchange;framing stays the caller's) +
  `smidr/tools/group_transfer_mock.mojo` diagnostic. Builds clean
  (Mojo1.0.0);physical-root/argument refusals smoked. The qualified
  RPC client sources are deliberately untouched.
  `docs/HAILO10H_GROUPED_TRANSFER_PRIMITIVE_2026-10-24.md`.
- [x] AES-TRANSFER-003 slice2.3 host qualification of the primitive:
  11 tests OK,574 runs,byte-identical comparisons incl. test_11
  cross-check vs the RPC client diagnostic. Two iterations failed
  only on reply-framing faults — resolved as a qualified
  consumer-layer poison contract (the primitive stays framing-free).
  `docs/HAILO10H_GROUPED_TRANSFER_QUALIFICATION_2026-10-24.md`.
- [x] Slice2.4 contract published before code:
  `TASK_hailo10h_grouped_transfer_physical.md` — exactly one physical
  child,one CREATE exchange through the primitive on aligned backing,
  consumer-layer reply validation,known handle residue stated up
  front,host gates on the Pi first.
- [x] AES-TRANSFER-004 slice2.4 physical confirmation:diagnostic
  host-qualified on the Pi (7 tests OK),then exactly ONE physical
  child under the contract — ACCEPTED:one CREATE exchange through
  the primitive completed on the real Hailo-10H (descriptors 5/5,
  completions 1/1,typed reply validated,retained 0,finalization
  confirmed). Campaign2 exit MET. The created handle was not
  logically destroyed (contract-stated residue);Campaign1 exit
  still unmet. `docs/HAILO10H_GROUPED_TRANSFER_PHYSICAL_2026-10-24.md`.
- [x] AES-PROG-001 Campaign3 slice3.1 program lifecycle interface
  qualification:creation = hRPC action2 (vdevice handle + declared
  byte count + name -> infer handle);program bytes are a separate
  phase of exactly the declared count (transport mechanics NOT
  ESTABLISHED;no chunk assumption);readiness/finalization =
  action4 configure -> configured handle + queue size;teardown
  actions 3/5/10/11/12 exist (ordering for partial states NOT
  ESTABLISHED);two handle tiers never interchangeable.
  `docs/HAILO10H_PROGRAM_LIFECYCLE_INTERFACE_2026-10-24.md`.
- [x] AES-PROG-002 slice3.2 host implementation:SocProgram lifecycle
  owner over the primitive (7 stages,consumer validation,
  ProgramIdentity printable pre-run,payload-attestation gate +
  conservative teardown order as fail-closed laws);dedicated
  program-action test oracle (the -018 device oracle is hardcoded
  to actions 20/22/21 and cannot serve program actions);suite on
  Mimir:8 tests OK,116 runs. `docs/HAILO10H_PROGRAM_LIFECYCLE_HOST_2026-10-24.md`.
- [x] AES-PROG-003 slice3.3 physical observation:contract at
  b34e11e1,diagnostic host-qualified on the Pi (6 tests OK),one
  physical child — branch B2:Phase A device CREATE completed;
  action-2 metadata earned NO reply and did not complete (5
  snapshots,prompt failure,owner poisoned,clean close). The
  receiver does not answer metadata alone on this channel;the
  payload phase precedes any reply. Phase-A handle residue
  recorded (contract pre-stated). Campaign3 exit NOT met.
  `docs/HAILO10H_PROGRAM_LIFECYCLE_PHYSICAL_2026-10-24.md`.
- [x] AES-PROG-004 slice3.4 failure teardown + payload source
  study:fail-at-<stage> accounting qualified on Mimir (10 tests
  OK,148 runs;create failure = handle-never-learned worst class;
  adoption deliberately not implemented). Track R:the payload
  phase's SHAPE is established from the pinned receiver —
  read_buffer of exactly hef_size bytes between metadata and
  reply (matches B2);destroy-configured performs shutdown
  receiver-side;disconnect cleanup releases all client
  resources. The SoC connection layer's read/write realization
  remains NOT ESTABLISHED and gates any payload contract.
  `docs/HAILO10H_PROGRAM_FAILURE_TEARDOWN_2026-10-24.md`.
- [x] AES-NUM-001 Campaign4 slice4.1 field table:five groups
  graded (container metadata IN as references;context action
  layouts IN with ID35 address values OUT;CCW words OUT
  entirely;numerical semantics group E ALL OUT;transport group
  D the physically corroborated minority). Recorded prediction:
  no operation clears all eight layers until a CCW word layout
  or equivalent encoding exists. Track R addendum:the payload
  phase is ONE async session read of the declared size after a
  readiness wait;the SoC session readiness protocol remains
  NOT ESTABLISHED. `docs/HAILO10H_NUMERICAL_FIELD_TABLE_2026-10-24.md`.
- [x] AES-NUM-002 slice4.2 selection:the ELEMENTWISE IDENTITY
  COPY (only candidate depending on no OUT field;byte-exact
  oracle;1-in/1-out). ReLU = alternate#1;fill/add/GEMV rejected
  with reasons. Pre-stated 4.3 prediction:layers 1-4,7,8
  completable at source level;5-6 blocked on CCW/sequencing;
  Campaign4 does not exit this pass.
  `docs/HAILO10H_FIRST_OPERATION_SELECTION_2026-10-24.md`.
- [x] AES-NUM-003 slice4.3 eight-layer description of the identity
  copy (roadmap layer list):L1 COMPLETE;L2 tile plan + L3
  resource plan INCOMPLETE (group-E/CCW OUT);L4 specified host /
  not established device (session readiness);L5/L6 INCOMPLETE as
  predicted;L7 completion contract SPECIFIED (terms sourced,
  satisfiability = Campaign5);L8 cleanup specified host / device
  partial states open. FINDING:AES-NUM-002's prediction used a
  different layer list than the roadmap's — corrected mapping
  recorded. Operation UNQUALIFIED;Campaign4 does not exit.
  `docs/HAILO10H_IDENTITY_COPY_EIGHT_LAYER_SPEC_2026-10-24.md`.
- [x] AES-NUM-004 slice4.4 spec review gate:field-by-field
  audit of AES-NUM-003 against AES-NUM-001 + all 16 Do Not
  Infer entries — 0 violated (IRQ/closed-file/math≠executable
  actively enforced by the spec's own terms). F1:L7's
  "qualified result path" overreaches (no program-result
  readback qualified;joins R2/R4). F2:2048 cap is messages,
  not the payload read;spec's context-only disclaimer
  confirmed load-bearing. Corrected AES-NUM-002 layer mapping
  CERTIFIED. Spec PASSES as an honest specification;Campaign4
  EXIT NOT MET (OUT fields have sourced unknown status,not
  known meanings);Campaign5 NOT contracted.
  `docs/HAILO10H_IDENTITY_COPY_SPEC_REVIEW_2026-10-24.md`.
- [x] AES-NUM-005 slice4.5 Track R R1 CCW layout study
  (lane D + pinned sources + repo evidence):NOT PROVEN — no
  source defines a non-zero CCW word's fields;pinned
  config-buffer code carries CCW bytes opaquely;lane D
  delegates CCW generation to DFC (none of its 17 findings
  touches CCW words). Ancillary IN:64-bit word unit,all-zero
  NOP with CSM pop/no-forward/no-CRC/credit semantics,two
  header constants literal-only. Layers2/5 unchanged (no
  re-grade,no gate re-run);Campaign4 exit NOT met.
  `docs/HAILO10H_CCW_LAYOUT_STUDY_2026-10-24.md`.
- [ ] Campaign4 iteration (Track R,dependency order):R1 done
  (NOT PROVEN,above);R2 session readiness (+F1 readback question) — slice4.6;
  R3 placement values;R4 action sequencing;R5 partial-state
  teardown. Each landing re-grades its layers by addendum and
  re-runs the 4.4 gate on changed layers only;then broad
  ordinary UNMODIFIED source-model support100%.

## 2026-10-24 — One grouped physical attempt,offset rejection

- [x] Host-qualify the new diagnostic/observer:7 methods,88 four-way comparisons
  and2 auxiliary pairs;preserve complete raw and failure evidence.
- [ ] AES-CONTROL-016 physical grouped lifecycle remains partial:one D2H return5,
  H2D EINVAL at map offset20/page512;no accepted handle/identity. Batch closed;
  no repeat. `docs/HAILO10H_GROUPED_DEVICE_PROBE_2026-10-24.md`.
- [ ] Continue aligned grouped backing and CPU-owned scatter/gather under its
  host contract,then numerical configuration/packing/placement/program/results
  and broad ordinary UNMODIFIED source-model support100%. No DFC/external
  compiler/machine,precompiled prerequisite or host/proxy LLM inference.

## 2026-10-24 — Typed grouped device lifecycle,host qualification

- [x] AES-CONTROL-015 fresh typed create/identify/destroy ownership,one lifecycle
  deadline,no destroy retry and uncertain cleanup;90 methods/5134 full frozen
  comparisons. `docs/HAILO10H_MOJO_GROUP_DEVICE_RPC.md`.
- [ ] Continue separately bounded physical grouped lifecycle and actual numerical
  configuration/packing/placement/program/results plus remaining ordinary source
  formats/architectures/operations toward broad UNMODIFIED model support100%.

## 2026-10-24 — Owned grouped control frames,host qualification

- [x] AES-CONTROL-014 bind natural header/body spans to owned session storage,
  actual returned-count policy,total deadline and permanent failure refusal;
  78 methods/4737 complete frozen comparisons.
  `docs/HAILO10H_MOJO_GROUP_CONTROL_RPC.md`. No physical DMA or model execution.
- [ ] Continue typed non-inference grouped lifecycle/cleanup and separately
  bounded physical evidence,then actual numerical configuration/program/results
  and remaining broad ordinary UNMODIFIED source-model support100%.

## 2026-10-24 — Same-file physical session maps

- [x] AES-CONTROL-013 qualify one baseline plus three same-file two-part map-only
  children;6 real mappings and complete owning-file/host cleanup.
  `docs/HAILO10H_MOJO_SESSION_TRANSFER_PIN_PROBE.md`.
- [ ] Continue actual grouped counts/completion/total deadlines/late cleanup and
  numerical configuration/packing/placement/program/results toward broad ordinary
  UNMODIFIED source-model support100%. No DMA or numerical execution follows.

## 2026-10-24 — Same-file sealed session ownership

- [x] AES-CONTROL-012 bind both actual sealed views/backing to the session file
  that owns assigned channels/lists;76 methods/5554 full frozen comparisons.
  `docs/HAILO10H_MOJO_SESSION_TRANSFER_PIN.md`.
- [ ] Qualify a separately bounded physical map-only session,then actual grouped
  transfer/completion/late cleanup and numerical program/results toward broad
  ordinary UNMODIFIED source-model support100%.

## 2026-10-24 — Observed grouped exchange progress

- [x] AES-CONTROL-011 separate actual launch counts from IRQ transfer completion
  and bound events by total deadline/budget;15 methods/1928 full frozen pairs.
  `docs/HAILO10H_MOJO_OBSERVED_GROUP_PROGRESS.md`.
- [ ] Continue same-file channel/list/sealed-buffer ownership,host faults and
  bounded physical control RPC,then actual numerical configuration/program/
  results and broad remaining source-model implementation work.

## 2026-10-24 — Prepare and cancellation wire codecs

- [x] AES-CONTROL-010 own exact139/8-byte prepare/cancellation values while
  reusing existing group/scalar guards;25 methods/2763 complete frozen pairs.
  `docs/HAILO10H_MOJO_SOC_PREPARE.md`.
- [ ] Continue actual same-file channel/storage/descriptor/status/completion/
  deadline/late cleanup and numerical configuration/program/results,with broad
  remaining source/model coverage and no metadata-as-execution claim.

## 2026-10-24 — Owned two-part sealed driver mappings

- [x] AES-CONTROL-009 retain both actual sealed parts through driver mapping and
  confirmed finalization;69 methods/4976 complete frozen pairs,7 physical children.
  `docs/HAILO10H_MOJO_SEALED_TRANSFER_PIN.md`.
- [ ] Continue actual grouped descriptors,completion/total deadlines/late cleanup,
  numerical encoding/packing/placement/program/results and remaining source/model
  coverage toward broad ordinary UNMODIFIED model support100%.

## 2026-10-23 — Retained tied-output mathematical source integration

- [x] AES-SOURCE-037 preserve both ordinary source tensors through typed sharing,
  fresh raw-byte guards and mathematical lowering;401 methods/18405 complete
  frozen pairs. `docs/HAILO10H_MOJO_OWNED_TIED_OUTPUT_COMPILER.md`.
- [ ] Continue actual H10H numerical configuration,packing,placement,program
  transport/activation/results and remaining format/architecture/operation work
  toward broad ordinary UNMODIFIED source-model support100%.

## 2026-10-23 — Retained ordinary raw representation comparison

- [x] AES-SOURCE-036 complete source-bit comparison through actual retained
  ordinary owners;33 methods/2412 complete frozen comparisons. Evidence:
  `docs/HAILO10H_MOJO_ORDINARY_TENSOR_IDENTITY.md`. No graph alias or execution.
- [ ] Qualify typed tied-output source aliases preserving both bindings with
  fresh byte checks;continue actual H10H numerical configuration/program/results
  and every remaining format/architecture/operation toward broad support100%.

## 2026-10-20 — Current native source-model frontier

- [x] Merge all current original remote/local committed branch heads into main;
  remote integration `1edae4f` and exact tree/ancestry verified.
- [x] Independent native control RPC and source semantic/expanded graph;
  static constant readers, hypothetical storage/cache and lazy matrix schedules.
- [x] Native matrix schedule acceptance: seven methods/860 calls; mathematical
  structure only. `docs/HAILO10H_MOJO_MATRIX_TILES.md`.
- [x] Source weight byte tiles: five methods/286 native calls,88368 byte checks.
- [x] Original Q5/Q6 components: seven methods/88 calls,94416 component checks.
- [x] Numerical source lead study: LCU/configuration descriptions, no actual ISA.
- [x] Original configure/stream codec: eight methods/83 calls; program/device
  regressions pass. Host bytes only, no device configuration or model inference.
- [x] Original outer integrity: eleven methods/2072 native calls; header8/151
  regression. Selected-domain host checks only, no executable/device claim.
- [x] Owned outer envelope: eight methods/194 native calls; complete synthetic
  byte output only, no executable metadata/CCW/hardware claim.
- [x] Public v5.4 delta: pinned schema/control/transfer facts; no numerical ISA.
- [x] Ordinary safetensors inventory: eleven methods/219 native calls; owned
  metadata only, no tensor/model execution or immutable source identity.
- [x] Ordinary safetensors static words: nine methods/97 native calls and
  264204 exact word checks; reader11/219 regression. No model/device math.
- [x] Owned typed decoder configuration and compatible graph builder:54 methods/
  1933 native calls including30 complete pre-refactor graph comparisons.
  `docs/HAILO10H_MOJO_TYPED_DECODER.md`; no model/device execution.
- [x] Exact declared GGUF source axes retained:28 methods/669 native calls;
  `docs/HAILO10H_MOJO_GGUF_SOURCE_SHAPES.md`. Vectors differ from one-row matrices.
- [x] Tagged source storage/name/path/axes/dtype provenance:46 methods/1340
  native calls; `docs/HAILO10H_MOJO_TAGGED_SOURCE_STORAGE.md`. Metadata only.
- [x] Owned ordinary shard-index metadata and exact bounded file admission:
  37 methods/1289 native calls including rebuilt consumers and5 extra probes;
  `docs/HAILO10H_MOJO_SOURCE_INDEX.md`. No shard resolution or model execution.
- [x] Owned ordinary configuration raw values:16 methods/706 native calls;
  `docs/HAILO10H_MOJO_SOURCE_CONFIG.md`. Full modifiers retained, semantics open.
- [x] Actual beneath-root regular shard descriptors:21 methods/783 calls;
  `docs/HAILO10H_MOJO_MODEL_ROOT.md`. No tensor/header/model execution claim.
- [x] Same-fd safetensors owned header decoder/inventory:53 methods/1916 calls;
  `docs/HAILO10H_MOJO_SAFETENSORS_FD.md`. Header bytes only, no source mmap.
- [x] Actual indexed source collection/name/label/span matching:58 methods/2121
  calls; `docs/HAILO10H_MOJO_SHARD_COLLECTION.md`. Metadata binding only.
- [x] Ordinary unindexed weight/config loading:62 methods/2299 calls;
  `docs/HAILO10H_MOJO_UNINDEXED_SOURCE.md`. No phantom index or model execution.
- [x] Tagged per-file/full-axis bindings across current semantic consumers:
  94 methods/2559 native calls,108 complete frozen consumer comparisons;
  `docs/HAILO10H_MOJO_SEMANTIC_STORAGE.md`. Compiler metadata/structure only.
- [x] Public per-layer rotary meaning confirmed without model execution:
  pinned config27 rotary/9 NoPE layers; docs/HAILO10H_ORDINARY_LAYER_SEMANTICS.md.
- [x] Owned decoder-layer intent:19 methods/701 native calls; source/default
  masks, tails, window facts and every raw modifier retained. Metadata only.
- [x] Explicit typed per-layer rotary/output graph and direct/rotary cache policy:
  99 methods/2711 native calls,40 complete NoPE graph and108 frozen consumer
  comparisons. `docs/HAILO10H_MOJO_DECODER_GRAPH_POLICY.md`. Structure only.
- [x] Owned ordinary parameter/modifier intent:31 methods/1053 native calls;
  full raw config/layer ownership and explicit unresolved source semantics.
  `docs/HAILO10H_MOJO_DECODER_ARCHITECTURE.md`. Metadata interpretation only.
- [x] Owned ordinary projection binding intent:38 methods/1168 native calls;
  actual326 header tensor roles/shapes, explicit ties, independent widths and
  original per-file metadata. No model/device execution.
- [x] Qualified ordinary omitted/null defaults:44 methods/1285 native calls;
  raw/source/default origins retained,28 explicit old outputs unchanged.
  `docs/HAILO10H_MOJO_ORDINARY_DEFAULTS.md`. Metadata/structure only.
- [x] Explicit rotary mathematical lowering and expanded storage:104 methods/2864
  calls,30 rebuilt entrypoints and18 complete new legacy comparisons.
  `docs/HAILO10H_MOJO_ROTARY_RECIPES.md`. No numerical device execution.
- [x] Exact source scalar words through math/expanded lowering:108 methods/2996
  calls,32 rebuilt entrypoints,20 new complete old outputs.
  `docs/HAILO10H_MOJO_SOURCE_SCALAR_PRECISION.md`. Source/IR only.
- [x] Qualified ordinary head/bias source schema:14 methods/326 calls,4 builds,
  9 complete frozen outputs. Header binding only; bias math/device work remains.
  `docs/HAILO10H_MOJO_ORDINARY_PROJECTION_SCHEMA.md`.
- [x] Source-bound projection bias mathematical graph/recipe/cache/storage:
  131 methods/3621 calls,41 builds,8 complete frozen outputs. No device execution.
  `docs/HAILO10H_MOJO_DECODER_BIAS_GRAPH.md`.
- [x] Source activation mathematical selection/expansion:140 methods/4124 calls,
  46 builds,8 complete frozen GGUF and4 additional full comparisons. No device
  execution. `docs/HAILO10H_MOJO_DECODER_ACTIVATION.md`.
- [x] Source cache-return/session mathematical graph and export lifetimes:
  147 methods/4730 native child calls,51 builds,8 complete frozen GGUF/2 ordinary
  comparisons and160 recovery cycles. No device execution.
  `docs/HAILO10H_MOJO_DECODER_SESSION.md`.
- [x] Source windows/original mask lowering and temporary-index accounting:
  154 methods/5455 native child calls,58 builds,16 frozen GGUF/8 ordinary outputs,
  2720 integer admissions/10 extrema and160 recovery cycles. No device execution.
  `docs/HAILO10H_MOJO_DECODER_WINDOW.md`.
- [x] Original default/linear source scaling and exact factor ownership:
  161 methods/6387 native child calls,64 builds,16 frozen GGUF/8 ordinary outputs,
  560 mutation refusals and160 recovery cycles. Mathematical compiler only.
  `docs/HAILO10H_MOJO_DECODER_SCALING.md`.
- [ ] Active: `TASK_hailo10h_dynamic_scaling_semantics.md`: dynamic/context/
  cache-basis qualification; other scaling/modifiers remain under the parent task.
- [ ] Active: `TASK_hailo10h_ordinary_rotary_modifiers.md`: actual source basis/
  modifiers and original mathematical lowering, then complete ordinary graph
  integration and numerical Hailo configuration/execution.
- [ ] Continue exact numerical CCW/register/target/placement discovery in parallel.
- [ ] Actual device numerical encoding, precision/packing/placement, original
  program upload/activation/result/cleanup and broad architecture/format support.
  No CPU/CUDA/cloud LLM inference, outside compiler or specially compiled model
  prerequisite. `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md` controls scope.

## Owner target authority — 2026-10-19

- Fixed target: Project Aesir in Mojo must provide the source-model execution
  path for models of the right size for Hailo-10H. The owner prohibits target
  changes and rejects a compatible-vendor-precompiled-model limitation.
- Vendor catalog slice 142 and its dependent precompiled-only work orders are
  withdrawn before implementation; prior receipts remain historical evidence.
- Active parent: `TASK_hailo10h_mojo_model_execution.md`. Mojo integrated RPC
  framing, typed control messages and packed driver ABI are verified. A native
  driver query/owner and assigned descriptor/connection lifecycle are physically
  verified; next work is owned DMA buffers, completion and cancellation,
  then a bounded read-only round-trip. Source import/lowering/configuration
  generation remain part of the same fixed target. See
  `docs/HAILO10H_SOURCE_EXECUTION_PROGRESS.md`.
- Preserve the automatic complete → verify → publish → next-slice workflow
  under this fixed target. Never mark a narrower substitute as completion.

## 2026-10-19 — Active Hailo-only campaign

- [x] Reconcile the existing Hailo branch through slices 133–138 against its
  implementation receipts; historical MIMISBRUNNR CPU work is superseded here.
- [x] Slice 139: repeatable canonical-CLI hardware acceptance seam, pinned public
  profile and adversarial validator tests; reject special model files before
  blocking or device allocation. See `docs/HAILO10H_SLICE_139_HARDWARE_SEAM.md`.
- [x] Slice 140: fresh physical direct-backend acceptance, 12/12 boundary and
  lifecycle checks, and Mojo exception cleanup pass. Evidence:
  `docs/HAILO10H_SLICE_140_SMOKE.md`. Exact word-only recall formatting remains
  a model quality limitation; recall and context lifecycle pass.
- [ ] Slices 141–150: formalize first-model metadata, artifact/runtime pin,
  compatibility and operation coverage without broadening beyond evidence.

## 2026-10-01 — Measured speed-lead program

- [x] Document the installed-provider baseline and publish the focused
  [AESIR speed-lead roadmap](ROADMAP_AESIR_SPEED_LEAD.md), with per-case 2× goals,
  3× stretch goals, ownership, dependencies and numerical/recovery gates.
- [ ] SPD-00: integrate fair 32/128/256-token provider modes, independent
  full-model logits, stage timings and a measured hardware feasibility decision.
- [x] First SPD-00 slice: portable balanced/seeded provider modes, full redacted
  replies and failure-aware scoring; physical native stage/traffic/D2D measurements;
  independent F32-expanded CPU reference for four strict-3B final-prompt vectors.
  See [measurement operation](docs/SPEED_MEASUREMENT.md). Preserve packed-reference
  failures and fixed budgets. The owned CUDA timeline slice below resolves first
  actual kernel/API tracing. Complete cache/residency isolation,
  second-session lead certification and broader numerical/quality gates stay open.
- [x] SPD-00 owned native CUDA trace: matched short/long public replies, validated
  kernel/API/copy rows, non-overwriting raw evidence and split-package importer
  recovery. See [trace operation](docs/NATIVE_CUDA_TRACE.md). Detailed semantic
  stage attribution, cache/residency and broad quality gates remain open.
- [x] SPD-01 first optional SIMT matrix candidate: all 1,658,880 real native
  reference values and 2100 selected independent dots pass fixed primitive
  budgets. It loses at batch 4 and is not promoted. Batch 32 gains are modest
  and shape-specific. See [candidate operation](docs/NATIVE_MATRIX_CANDIDATE.md).
- [x] SPD-01 shared-tile tuning: six configurations repeat all primitive gates,
  preserving 9,953,280 real native-reference values and 12600 selected independent
  dots. Every batch-four candidate loses; default stays strict reference.
  [Physical evidence](docs/evidence/matrix-tile-tuning-2026-10-01/README.md).
- [x] SPD-02 physical primitive prerequisite: public m16n8k8 F16/F32 MMA passes
  all50688 independent exact outputs,5400 guards and9 invalid-span rejections
  on actual sm_75. An isolated PTX6.5 target resolves the pinned PTX6.3 mismatch;
  no library/driver/dependency patch. [Operation](docs/NATIVE_TURING_MMA.md).
- [x] SPD-01/02 optional original packed-weight MMA: split-weight refinement
  passes all1,658,880 native values/2100 selected independent dots after the first
  F16 conversion fails. All28 speed cases lose; no default promotion.
  [Operation](docs/NATIVE_PACKED_TURING_MATRIX.md). Next measure shared staging.
- [x] SPD-01/02 shared Turing staging: three CTA choices pass4,976,640 native
  values/6300 selected independent dots and all guards. Rows64/batch32 earns up
  to1.92x primitive speed; V and every batch4 shape still lose. No promotion.
  Wider staging evidence follows; full-model/control integration stays open.
- [x] SPD-01/02 wider shared-input staging: all four configurations pass6,635,520
  native values/8400 selected independent dots and all guards. Wider timing is
  worse than prior32-column staging; retain its default and complete samples.
  Next gate ordinary F32 activation precision before full-model integration.
- [x] SPD-01/02 captured ordinary native F32 inputs: two public final-layer
  captures pass1,990,656 full native outputs and2520 selected independent dots
  under unchanged budgets. Almost every source value requires F16 rounding.
  Q/K/V use representative FFN-normalized inputs; batch32 repeats four sources.
  No full-model quality/speed promotion. Next scope bounded full-model prefill.
- [x] SPD-01/02 isolated whole-model matrix prefill: all513024 logits per mode
  pass fixed independent .05-max/.005-RMS/matching-argmax gates through1070
  input tokens. Exact repeats/commits and4352 guards pass; long fresh prefill
  improves12.717s to7.578s in this fixture. Small tail-only cases lose slightly.
  Normal policy stays unchanged. Next measure activation-residual precision/cost,
  then separately earn runtime/control/generation/restore/provider gates.
- [x] SPD-01/02 activation-residual precision/cost: both three/four-term
  candidates pass captured-input and original independent model budgets, but
  miss the stricter predeclared .0005 native-model RMS target. Four terms reduce
  long deviation about4.03x; retain all96 timing records and withhold failed
  ratios. Next measure scaled residual representation without relaxing budgets.
- [x] SPD-01/02 scaled residual representation: modes3/4 improve captured
  projection RMS but miss the unchanged .0005 complete-model native goal. All
  original independent budgets pass; retain all96 timings and withhold failed
  ratios. Next harden checked workspace/profile/device admission for the original
  passing matrix candidate before production memory/control/generation gates.
- [x] SPD-01/02 fixture workspace/device admission: strict full geometry and
  observed capability7.5, checked canonical layout/headroom, every field and
  actual span rechecked before tiles. Master188 passes/one skip; new mode0 full
  vectors match previous bytes and independent gates, preserving1.676x long
  fixture prefill. Next separately earn larger-tile control/recovery gates.
- [x] SPD-01/02 larger-tile fixture controls/recovery: actual deadline/SIGINT/
  invalid-descriptor aborts preserve uncommitted position/IDs and require explicit
  reset; recovered complete vectors match prior bytes and allocations. Unexpected
  observer exception poisons reuse. Master189 passes/one skip; disabled mode0
  independent gates preserve1.676x fixture prefill. Generation/sampling/restore
  and production admission/provider gates remain separate.
- [x] SPD-01/02 complete post-prefill decode/seeded replay:96 frames/all12312576
  logits per mode pass unchanged CPU/native budgets after public37/1070 prefixes.
  Greedy32/seeded16 actual samples agree and own fresh vectors replay bit-exactly;
  complete committed IDs/state/draws and4352 guards pass. Bounded streaming
  validation retains all metrics without a speed score. Next separately preserve
  execution boundaries across restoration before production32/provider admission.
- [x] SPD-01/02 owning-context checkpoint replay: copied/sealed exact tile/ID/
  policy/draw/pending/owner plans preflight before reset/GPU. Four continuations
  per greedy/seeded45-ID checkpoint pass1026048 logits per mode, unchanged
  independent/native/source/sample gates and actual own F32 bits. Twelve damaged
  plans refuse without mutation;4352 guards pass. Master190 passes/one skip.
  In-memory same-context only; persisted/long-history/runtime/provider gates open.
  Next scope bounded batched causal attention/launch reduction under exact vectors.

- [x] SPD-03/04 optional batched rotary/cache launches: four/32 grid-y rows retain
  original arithmetic/causal reads, exact513024 logits per model owner and all
  full guarded-cache hashes. Long actual host calls reduce89880 to3192; fresh
  native/fixture medians13.0394/7.43515s give1.75375x exploratory fixture gain.
  Complete96-frame decode and eight-frame checkpoint gates repeat every unchanged
  CPU/sample/state/bit/source/guard condition. Master190 passes/one skip; six new
  portable contracts pass. Production admission stays one/four. [Operation](docs/NATIVE_TURING_BATCHED_ROPE_CACHE.md).
  Next batch independent normalization/residual/SiLU launches under exact state.

- [x] SPD-04 optional batched RMS/residual/SiLU: separate3072/33824 strided
  RMS sibling and disjoint cell grids preserve every complete vector/cache byte.
  Long actual elementwise host calls5321 versus original149801 plan; fresh
  native/fixture medians12.8261/6.94205s earn1.84759x exploratory fixture ratio.
  Complete96-frame decode/eight-frame checkpoint gates repeat all original
  independent/sample/state/bit/source/guard conditions. Master190 passes/one skip;
  seven portable grid contracts pass. [Operation](docs/NATIVE_TURING_BATCHED_ELEMENTWISE.md).
  Next earn enabled controls/recovery on this new strategy before promotion.
- [x] SPD-04 enabled controls for new batched strategy2: actual pre-expired/
  10ms/owned-SIGINT/invalid-fd aborts at0/2/8/0 synced layers, explicit reset
  clears uncommitted sampler state with allocations intact. All513024 recovered
  values per owner equal accepted2 bytes;9792 guards/mask/poison/refusal checks
  pass. Eleven control contracts bind matching strategy/full source/hash and
  preserve mutation/interrupt failures. [Operation](docs/NATIVE_TURING_BATCHED_CONTROLS.md).
  Cooperative only; broader context/concurrency/soak/runtime/provider gates open.
  Next earn owned stage tracing for the accepted batched path.
- [x] SPD-00/04 owned inference-only strategy2 timeline: public37/1070 plain/
  profiled cases preserve all513024 source F32 values, full guarded-cache hashes,
  committed IDs/state/counts and4352 guards. Full-session ownership/correlation
  gates precede same-thread named NVTX selection;4837/120919 kernels pass.
  Retain rejected NVTX-triggered/UTC time-domain exports. No timing score.
  Long observed staged matrix kernels65.43%, attention21.47%; next earn explicit
  projection attribution before another kernel change. [Operation](docs/NATIVE_TURING_PREFILL_TRACE.md).
- [x] SPD-00/01/04 actual projection attribution: tensor-bound default-disabled
  NVTX labels and source32/4/1 plans attribute589/7449 child ranges to981/20385
  actual projection kernels in public37/1070 traces. All513024 source F32/cache/
  state values/4352 guards remain; eight attribution/nine probe contracts pass.
  Long batch32 FFN gate/up/down3.46973s (52.04% recorded kernel duration), down
  largest1.26654s. No speed score. [Operation](docs/NATIVE_TURING_PROJECTION_TRACE.md).
  Next scope bounded FFN packed-block decoding/staging with original accumulation.
- [x] SPD-01 bounded block-header reuse: separate default-disabled kernel keeps
  all1658880 cached/original F32 bits and2100 independent dots within fixed
  gates;144 synthetic/12 invalid spans/1622640 guards/840 timings pass. Batch32
  gate/up/down old-to-cached ratios .6843/.6890/.9025 reject this speed candidate.
  Fourteen portable contracts/master190 passes/one skip; defaults remain original.
  [Operation](docs/NATIVE_TURING_BLOCK_HEADERS.md). Next scope larger CTA row reuse
  under exact original bits and bounded shared storage.
- [x] SPD-01 larger row CTA sharing: final128 passes1658880 exact original bits/
  2100 independent dots/144 synthetic/12 invalid spans/1622640 guards/840 timings.
  Batch32 down gains1.10414x, gate/up lose .76896/.76027 old-to-new. Initial256
  physical resource failure is retained and admission removed; actual pre-model
  refusal passes. Sixteen portable contracts/master190 passes/one skip.
  [Operation](docs/NATIVE_TURING_LARGE_ROWS.md). Next gate narrow down-only real-F32
  activation/full-model support before any fixture selection.
- [x] SPD-01 narrow down-only128 actual-F32 gate: two public normal captures retain
  all114688 accepted source inputs/states and1990656 native/original/new F32 bytes.
  All2520 selected independent dots/1938600 guards/12 spans pass unchanged budgets;
  only two batch32 down cases select128. Ten portable contracts/master190 passes/
  one skip, strict source report/model/capture rehash and failure retention pass.
  [Operation](docs/NATIVE_TURING_DOWN_ACTIVATIONS.md). No speed score/full-model
  promotion. Next gate complete down-only model/cache/state before selection.
- [x] SPD-01/04 down-only128 complete model strategy3: all513024 native/matrix
  values/owner, actual IDs/state/full guarded-cache hashes match accepted2;
  unchanged CPU budgets/own fresh F32 bits/4352 guards/eight invalid tiles pass.
  Actual down calls0/28/0/924 and closed trace/control admission pass. Long paired
  native/new12.66775/6.80087s=1.86267x exploratory fixture ratio; no old2/new3 or
  provider score. Eight portable contracts/master190 passes/one skip, atomic
  finite scoring/provenance rehash/failure retention pass. [Operation](docs/NATIVE_TURING_DOWN_MODEL.md).
  Next earn strategy3 decode/sample/replay/enabled-control gates before selection.
- [x] SPD-01/04 down-only128 decode/sample gate: all96 complete frames and
  12312576 F32 values per owner pass fixed independent/native quality, samples,
  causal state, exact own fresh bits,4352 guards and accepted3 initial vectors.
  Actual initial/replay down counts28/924; nine portable contracts plus previous
  gates/master190 passes/one skip. Source numeric/predecessor/hash admission and
  after-oracle all-artifact rehash/interrupt cleanup retain failures; no speed
  score or production selection. [Operation](docs/NATIVE_TURING_DOWN_DECODE.md).
  Next earn strategy3 sealed owning-context replay and enabled-control recovery.
- [x] SPD-01/04 down-only128 sealed owning-context replay: two45-ID greedy/seeded
  checkpoints/eight continued frames/1026048 values per owner/four baseline-
  restored owners pass exact actual bits/causal/sample/draw/config/allocation/
  tile/source/independent budgets and4352 guards. Down calls28 before/after;
  18 damaged-plan/flag refusals preserve healthy state/counters/owners before
  reset. Seven portable contracts/master190 passes/one skip; pure3 owner/seal/
  strategy4/native-mode refusal and all-artifact rehash/cleanup interrupts pass.
  [Operation](docs/NATIVE_TURING_DOWN_CHECKPOINT.md). Preliminary accepted capture
  stays; final strengthens explicit refusal counter/allocation comparisons.
  Next earn strategy3 cooperative control recovery; no elapsed/crash/production gate.
- [x] SPD-01/04 down-only128 opt-in cooperative controls: default-disabled
  capability preserves ordinary3 refusal. Disabled capable model matches all
  prior2/prior3 F32/IDs/full cache and unchanged CPU/own-bit/4352-guard gates.
  Four real aborts at0/2/8/0 synced layers/down calls recover exact513024 values
  per owner after reset, preserve allocations/IDs/owned SIGINT/mask/refusals and
  9792 guards. Observer exception poisons at1 layer/call and refuses reuse/reset.
  Six portable contracts/master190 passes/one skip; actual capability/source/hash
  gates/negative pre-model refusals pass. Disabled long paired native/new
  12.70594/6.83303s=1.85949x exploratory; enabled control time unscored.
  [Operation](docs/NATIVE_TURING_DOWN_CONTROLS.md). Next earn owned3 projection
  tracing before next measured speed change; production/broader/provider gates stay.
- [ ] SPD-01/02: validate real packed-weight matrix prefill and full-model
  support in the locked toolchain before promoting either path.
- [ ] SPD-03–07: improve attention, launch overhead, sustained decode, bounded
  cache/buffer use and verified speculative decode when the ceiling requires it.
- [ ] SPD-08–10: validate concurrent throughput, thermal/recovery/memory soak
  and the complete refreshed provider lead before integration policy changes.

The first measurement slice is implemented; the overall speed-lead program remains
open. Runtime capability statuses stay governed by the ledger. The focused SPD
track fits inside the wider S01–S48 application program.

## 2026-10-01 long-token and buffer acceptance

- [x] Publish task contract before implementation; preserve working binary.
- [x] Add bounded four-token prefill only for exercised strict 3B profile.
- [x] Check compact disjoint spans, actual bytes, context/tile bounds and overflow.
- [x] Physically compare all native sequential/tiled logits in five cases,
  greedy/seeded replies and exact-token restore continuation.
- [x] Prove four-projection tails, long-attention reference/independent equations,
  invalid-tile non-mutation and deadline/reset/API recovery.
- [x] Complete controlled fresh-prompt speed evidence, retaining raw failures
  and whole-response/count equality. Final remote CI/deployment are separately
  recorded by exact revision and binary checksum in publication artifacts.
- [ ] Extend whole-model coverage to maximum context, longer generation and other
  profiles/devices. The first SPD-00 oracle covers four 3B final-prompt vectors;
  broader independent full-model coverage remains open.

# Project A.E.S.I.R. — Evidence-Backed TODO

## Native efficiency follow-up — 2026-10-01

- [x] **[partial, AES-OPS-001]** Bound quant byte arithmetic to Int32 while
  preserving wide spans and reference float order; schedule RMS loads in small
  fixed-width tiles. Physical projection/RMS references and independent equations
  pass. Same-policy whole replies match in all 34 paired HTTP benchmark samples.
- [x] Measure standard cache-disabled and cached work plus 1070-token prefill and
  128-token sustained output. Achieved another 1.60–1.66x on this model/device.
- [x] Add a fail-closed evidence comparator and extended benchmark controls;
  mismatched replies/settings/models/failures cannot publish speed ratios.

See [efficiency operation and verification](docs/NATIVE_EFFICIENCY.md). The open
batched-prefill/full-logit/device/context-recreation gates below remain open.

## Native performance milestone — 2026-10-01

- [x] **[partial, AES-OPS-001]** Profile real 3B CUDA work and optimize packed
  projections without changing reference accumulation; preserve exact whole
  replies across the archived/new binaries. Prepare layer descriptors once.
- [x] **[partial, AES-OPS-001]** Add bounded exact-prefix reuse with cache-disable
  control, fresh final logits, rebuilt sampler state and physical recovery gates.
- [x] Repair persistent Llama snapshot family mapping after actual chat failure.
- [ ] Implement and physically validate true batched matrix prefill, full independent
  logits, representative long-context attention and broader profile/device speeds.
- [ ] Isolate/fix locked-runtime in-process CUDA context recreation; retain process
  replacement for model switching until that gate passes.

See [native performance manual](docs/NATIVE_PERFORMANCE.md). This milestone does
not establish universal optimality, all-model/device speed or an Ollama advantage.

Current program: [best-in-class application gameplan](BEST_IN_CLASS_GAMEPLAN.md).
Its S01–S48 sequence drives new work; this backlog retains detailed historical
items and the capability ledger retains present-tense implementation authority.

This backlog is governed by [`CAPABILITY_LEDGER.md`](CAPABILITY_LEDGER.md) and
[`PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md`](PROJECT_AESIR_REALITY_AUDIT_AND_BUILDOUT_REPORT.md).
Execution order and anti-fabrication file rules are defined in
[`ROADMAP_REALITY_FIRST_COMPLETION.md`](ROADMAP_REALITY_FIRST_COMPLETION.md).
An enum, interface, banner, synthetic happy path, or predetermined output never
counts as completion of an external capability.

Earlier completed native profile: Stheno Q4_K_S download, Llama 3 CUDA inference
and 20-turn roleplay with an 8K ceiling. See [the evidence and remaining
limits](docs/STHENO_CUDA.md). General model support, full-model logit parity,
and optimized batched prefill remain future work. Native CUDA sampling now has
an independent device/reference gate; see [runtime controls](docs/NATIVE_RUNTIME.md).

- [x] Connect native CPU/CUDA hardware reporting, checked model memory plans,
  fitting-device selection and automatic CUDA single-shot profile detection.
  Five counted cases and both physical CUDA profile integrations passed;
  [limits and commands](docs/NATIVE_RUNTIME.md) retain unverified devices.

- [x] Native CUDA temperature/top-k/top-p/min-p/repetition controls, seeded
  device selection and explicit session reset/settings. Independent GPU sampler
  reference and both real model/control integrations pass.
- [x] Bound pinned host upload staging to 64 MiB; physical exact-byte and
  final-chunk checks pass. GPU weight/KV memory requirements are unchanged.

> “I know that I sat nine days and nights, the friend of Mímir, seeking wisdom, until I was given to myself, and my own mind was won.”
> — Hávamál, Stanza 141


## Status Rules

- `[x]` means the narrowly worded task has executable evidence and its stated
  acceptance boundary passed.
- `[ ]` means work remains. The bracketed ledger status (`partial`, `scaffold`,
  `simulated`, or `missing`) records the current starting point.
- A task moves to `[x]` only in the same change that records its exact proving
  command, result, evidence boundary, and relevant ledger status change.
- A verified narrow primitive may still have unchecked hardening/generalization
  tasks. “Verified” does not mean production-ready.
- The canonical five-value status vocabulary lives in `CAPABILITY_LEDGER.md`.

## Second-brain integration — 2026-10-01

- [x] Strict Llama 3.2 3B Q4_K_M with tied weights and scaled RoPE on sm_75;
  Turing residual PTX repair; 35 real-weight and 52,210 primitive comparisons.
- [x] Add truthful native model/capability discovery and a checked user-service
  recipe; actual HTTP faults and supervisor restart proved in the
  [second-brain evidence](docs/evidence/second-brain-2026-10-01.md).
- [x] Connect independent Bifröst chat routing with bounded admission, explicit
  fallback/circuit recovery and unchanged corpus embeddings. Live read-only
  corpus and recovery checks pass; default remains measured faster Ollama.
- [x] Measure generic versus specialized Q4_K/Q6_K kernels: 15–17% lower native
  warm HTTP latency; observed baseline/optimized native text/count replay matches.
- [ ] Beat Ollama on representative same-weight workloads. Native remains slower;
  batched prefill, prefix reuse and measured kernel/scheduling work are open.

## Verified Forge Milestones

- [x] **Complete reality and function-level audit:** Inventory all 379 tracked
  Mojo declarations, record AER-001 through AER-115, classify affected
  functions, and publish the staged Forge 0 through Stage 10 buildout plan.
- [x] **Forge 0A — fail-closed tests:** Replace identified print-only and
  early-return assertion failures with raised errors; prove a deliberate failed
  expectation exits nonzero.
- [x] **Forge 0B — counted proving summary:** Register 49 executable named cases
  and one explicit external-fixture skip; continue after case failures; emit
  stable case/summary lines; raise after a failing summary.
- [x] **Pinned real GGUF vertical slice:** Validate one external GGUF v3 Llama
  F16 model, mmap F16 matrices, convert F32 norms, load tokenizer metadata,
  execute grouped-query CPU inference, and match first-token `llama.cpp` parity.
- [x] **Pinned deterministic multi-token slice:** Reuse one request KV cache,
  enforce EOS/length/context policy, match all 32 greedy token IDs and exact text,
  preserve the one-token result, and stop safely at the 128-token context edge.
- [x] **Narrow CPU primitive proofs:** Preserve the currently tested CPU GEMM,
  RMSNorm/RoPE/GQA path, SiLU, cosine similarity, host tensor partitioning,
  sequential host reduction/GEMM, and in-memory vector-store invariants. These
  checks do not establish hardware acceleration or general production kernels.
- [x] **Stage 37.1 Hardening — RAG Hidden Dim Parameter Bounds (`AES-RAG-005`):** Hardened `_prepare_prompt()` in `aesir.mojo` for non-positive hidden dimensions (`hidden_dim <= 0`).
- [x] **Stage 38.1 Hardening — Pure Native Mojo Zero-Python Runtime (`AES-FND-004`):** Audited and confirmed zero `std.python` imports in engine runtime execution.
- [x] **Stage 39.1 Hardening — Arena Pool KV Cache Reset Restoration (`AES-MEM-005`):** Hardened `MimirWell.reset_kv_cache(runtime_offset)` pool restoration and offset advancement tests.
- [x] **Stage 40.1 Hardening — Repository Artifact Hygiene & `.gitignore` (`AES-FND-007`):** Configured `.gitignore` protecting against `.pixi/`, binaries, objects, and logs.
- [x] **Stage 41.1 Hardening — Query Embedding Truth Boundary (`AES-RAG-003`):** Removed fabricated fallback embeddings; real query embeddings now require loaded token-embedding weights.
- [x] **Stage 42.1 Hardening — Chat Template Formatter Empty Message List Bounds:** Hardened `format_chatml()`, `format_llama3()`, and `format_llama2()` in `loader/chat_template.mojo` to reject empty message lists.
- [x] **Stage 43.1 Hardening — Deep Bug Audit & Attention Head Bounds:** Hardened `incremental_causal_attention()` in `core/compute.mojo` for non-positive `head_dim` and non-divisible query/kv head ratio safeguards.

### Most Important Issues to Address First - ASAP!!! (TOP PRIORITY: HARDWARE ACCELERATION)

- [x] **Modular Max Support:** Add full support for MAX by Modular
- [x] **Config Data File:** Add config file that is human readable and can be manually edited by the user. All options should be included and explain all options, settings, and features very well.
- [x] **Acceleration Selection:** Add command that allows the User to select which acceleration system is being used. 
- [ ] **[partial, AES-OPS-004] Complete the optional TUI:** The formatter now validates caller-observed snapshots and refuses to invent live values. Connect it to native session measurements, define snapshot freshness, and add terminal integration tests.
- [x] **Add Help Commands:** Add very useful, well written, complete help command system.
- [ ] **[missing, AES-SYS-001] Cognitive Inference Architecture:** Define real semantic state ownership, snapshots, retrieval/reconstruction and model-equivalence evidence; configuration intent currently fails closed.
- [ ] **[missing, AES-SYS-001] Wave Inference Computing:** Supply a falsifiable physical/numerical specification, model transform, reference output and measured hardware evidence; the synthetic cosine path was removed.
- [ ] **[missing, AES-SYS-001] Neural Spectral Fractal Inference:** Define trained representation/conversion, reconstruction error bounds and inference parity; the sine/cosine weight generator was removed.
- [ ] **[verified, AES-GEN-005] Complete SKÁLDBRØÐIR integration:** A bounded exact-period detector and configuration intent exist. Wire its intervention signals into native generation, define reset/session ownership, and verify quality impact; it currently does not compute entropy or modify logits.
- [ ] **[verified, AES-GEN-011] Complete tool use:** Strict bounded schema formatting and call parsing work; add an allowlisted executor, authorization, sandboxing, deadlines, cancellation, result framing, audit records, and model-loop integration.
- [ ] **[verified, AES-GEN-010] Complete thinking control:** Literal thought-block redaction works across split tokens; add per-model reasoning controls and native CUDA streaming integration. Text redaction alone cannot ensure a model did not reason internally.
- [x] **Compute Improvements:** Read RuneForgeAI_Aesir_Compute_Optimization_Manifest.md and implement all suggested improvements.
- [x] **NPU Gate Improvements:** Read RuneForgeAI_NPU_Gate_Optimization_Manifest.md and implement all suggested improvements.
- [ ] **[missing, AES-SYS-001] New inference research:** Treat MQARI or any new method as research until it has a falsifiable method, real model integration, output-equivalence tests and physical speed evidence.
- [ ] **[verified, AES-RES-006] Expand caller-reported failure diagnostics into runtime crash handling:** Persist redacted structured records, capture owned runtime context, add a lifecycle supervisor, define safe restart/backend-switch policies, and prove them with injected failures. The current formatter does not intercept, restart, switch hardware, or call AI.
- [x] **#1 PRIORITY PHASE 1 — NVIDIA CUDA GPU Acceleration (`AES-ACC-001`/`AES-ACC-004`):** Implemented native CUDA driver/runtime FFI bindings (`cuda_gate.mojo`), VRAM allocation, host-to-device transfers, and CUDA GEMM kernel dispatch.
- [x] **#1 PRIORITY PHASE 2 — Apple Metal GPU Acceleration (`AES-ACC-002`/`AES-ACC-005`):** Implemented native Metal framework FFI bindings (`metal_gate.mojo`), zero-copy buffer allocation, and Metal GEMM kernel dispatch.
- [x] **#1 PRIORITY PHASE 3 — Intel OneAPI / Level Zero GPU Acceleration (`AES-ACC-003`):** Implemented native Intel Level Zero FFI bindings (`intel_gate.mojo`), VRAM allocation, and Level Zero GEMM kernel dispatch.
- [x] **#1 PRIORITY PHASE 4 — AMD ROCm / HIP GPU Acceleration (`AES-ACC-004`):** Implemented native AMD HIP FFI bindings (`amd_gate.mojo`), VRAM allocation, and hipBLAS GEMM kernel dispatch.
- [x] **#1 PRIORITY PHASE 5 — Major NPU Acceleration Integration (`AES-ACC-006`/`AES-ACC-007`):** Implemented vendor NPU driver gateways (`npu_gate.mojo`) for Qualcomm Hexagon, Apple Neural Engine (ANE), Hailo-10, and Intel NPU.
- [x] **#1 PRIORITY HARDENING — Hardware Acceleration Hardening, Crash-Proofing & Self-Healing Resilience (`AES-ACC-008`/`AES-ACC-009`):** Harden all 5 hardware gateways (`CUDAGate`, `MetalGate`, `IntelGate`, `AMDGate`, `NPUGate`) with strict bounds checking, non-positive allocation rejection, self-healing memory reclamation, and crash-proof error isolation.
- [x] **Automated CI/CD Pipeline (`.github/workflows/ci.yml`):** Added GitHub Actions CI workflow executing master test runner (`run_all.mojo`) and doc drift verification on push/PR.
- [x] **Repository Structure & Asset Cleanup:** Consolidated 20+ root image files into `docs/assets/images/`, moved `TASK_*.md` documentation files into `docs/tasks/`, and updated all markdown image links.
- [x] **Quantized GGUF Inference Vertical Slice (Q4_K_M):** Connect `dequantize_q4_k_m()` kernel to `GGUFSeer` loader and `forward_pass()` model execution pipeline with real quantized GGUF model fixture tests.
- [x] **Live OpenAI REST API Inference Connection (`AES-SRV-006`):** Connect bare-metal POSIX socket `/v1/chat/completions` REST endpoint directly to the local GGUF engine runner for streaming inference.
- [x] **[partial, AES-MEM-004] Paged KV Cache Pool:** Add real multi-sequence
  logical page tables, bounded physical ownership, translated K/V access,
  exhaustion, release/reuse, and per-layer initialization guards.
- [ ] Connect paged K/V storage to model attention and scheduling; add eviction,
  prefix sharing/reference counts, copy-on-write, GPU pages, and measured
  fragmentation/memory efficiency (`AES-MEM-004`).
- [x] **Security Fuzzing & Resource Limits:** Add GGUF parser fuzzing harness, enforce system-level generation token limits, and document threat model (`AES-OPS-003`).

### Remaining Audit & Hardening Remedies (Backlog)

- [x] **[verified, AES-CPU-008] Multi-head GQA/MQA Execution Integration:** Extend `incremental_causal_attention` with full multi-head caching and GQA ratio scaling across custom GGUF architectures.
- [x] **[verified, AES-GEN-009] Stop Reason Policy Integration:** Implement full stop token and sequence policy parsing for multi-token streaming generation.
- [ ] **[partial, AES-SRV-006] Live OpenAI REST API Engine Connection:** Live bounded chat execution and incremental SSE exist; official-client conformance and broader API features remain open.

## Forge 0 — Restore Truth Before Expanding Runtime Claims

### Forge 0C — Canonical capability ledger (completed)

- [x] **Publish the canonical capability ledger:** Cover all major
  README, TODO, vision, architecture, interface, and runtime claim families with
  stable IDs, one allowed status, exact evidence, evidence boundaries, next
  acceptance gates, owners, and AER links.
- [x] Mechanically validate unique IDs, allowed statuses, summary counts, cited
  files, and named master-suite cases.
- [x] Link the ledger from README, TODO, the reality audit, and DEVLOG.
- [x] Re-run the 49/0/1/50 master suite, external pinned GGUF integration, clean
  Mojo build, and real built-CLI generation before marking Forge 0C complete.

### Forge 0D — Eliminate fabricated operational output (completed)

- [x] **[verified, AES-GEN-009] Implement or disable Masking Seidr:** Stop
  claiming a thought token is bound to `-inf` until tokenizer resolution and
  real logit masking are verified.
- [x] **[partial, AES-CLI-005] Correct `list`/`show`/`ps` output:** Remove fixed
  catalogs, CUDA utilization, expiry, architecture, parameters, and sampler
  values unless derived from real current state.
- [x] **[partial, AES-CLI-006] Correct `pull`/`push`/`create` output:** `pull`
  performs the documented pinned, verified public GGUF download and `create`
  records a validated durable recipe without inventing model-byte metadata;
  `push` remains explicitly unsupported.
- [x] **[partial, AES-CLI-007] Correct `rm`/`cp`/`stop` output:** Do not report
  storage or process mutations that occurred only in an ephemeral seeded list.
- [x] **[partial, AES-CLI-008] Correct REPL output:** The legacy sample loop is
  bounded; native Gemma/Llama CUDA chat supplies separate real interactive paths.
- [x] **[partial, AES-SRV-006] Correct OpenAI route output:** Stop returning a
  fixed assistant response as successful inference.
- [x] **[missing, AES-SRV-007] Correct llama.cpp route output:** Remove fixed
  completion/token/detokenize/health/metrics responses and parity wording.
- [x] **[partial, AES-ACC-003] Correct device discovery:** Return only
  configured/observed devices, or explicit unavailable status; never append all
  backends as detected.
- [x] **[missing, AES-ACC-006] [partial, AES-ACC-008] Correct accelerator banners:** Do not
  print NPU/GPU “ACTIVE,” CUDA, Tensor Core, or hardware-realm execution when the
  selected function runs on the CPU.
- [x] **[partial, AES-ECO-003] Correct Hugging Face download output:** Return
  unsupported without “downloading”/registration success until bytes are
  transferred and stored.
- [x] **[partial, AES-ECO-004] Correct ONNX output:** Remove fixed IR version,
  node count, and validated/mapped status.
- [x] **[missing, AES-ECO-005] [missing, AES-ECO-006] Correct ExLlama/llama CLI output:**
  Remove fixed completion, server health, bitrate, cache, benchmark, and
  perplexity claims.
- [x] **[missing, AES-RES-005] Correct self-healing output:** Reject the legacy
  recovery entry point without reporting recovery of state that was never lost.
- [x] **[missing, AES-SWM-003] [missing, AES-SWM-004] [missing, AES-SWM-005] Correct swarm output:** Remove fixed
  peers, VRAM, health, join, dispatch, and remote execution success.
- [x] **[partial, AES-OPS-001] Delete fabricated benchmark numbers:** Retain no
  tokens/s, perplexity, model size, backend, or utilization number that was not
  measured by a recorded harness.
- [x] Add negative tests proving unsupported branches fail nonzero and cannot
  emit success/healthy/validated/completed language.

### Forge 0E — Reconcile all present-tense documentation (completed)

- [x] Replace all Chinese in documents or code with the proper English words.
- [x] **[verified, AES-OPS-006] Rewrite README technical claims:** Preserved the
  vision while labeling the pinned CPU slice, partial primitives, scaffolds,
  simulations, and missing capabilities exactly (`python3 scripts/check_doc_drift.py`).
- [x] Replace the README's direct mmap-to-GPU analogy with the verified CPU mmap
  boundary; reserve device-memory claims for real accelerator evidence.
- [x] Replace “PagedAttention” with the actual contiguous request KV-cache
  status until page allocation/mapping exists.
- [x] Replace “stateless sampler” with verified greedy argmax and explicit
  missing sampling/zero-allocation work.
- [x] Remove NVIDIA RTX/Tensor Core optimization language until physical backend
  execution and measurements pass.
- [x] Reconcile `ARCHITECTURE.md`, `DATA_FLOW.md`, `docs/ARCHITECTURE.md`,
  `docs/DATA_FLOW.md`, `docs/SYSTEM_VISION.md`, `docs/Vision.md`,
  `docs/REPO_OVERVIEW.md`, and `docs/DOMAIN_MAP.md` with the ledger.
- [x] Reconcile root/domain `INTERFACE.md` files so contracts distinguish
  implemented behavior from desired interfaces and unsupported backends.
- [x] Classify duplicated/historical docs explicitly; choose canonical files and
  prevent their copies from drifting (`docs/historical/2026-08-16/`).
- [x] Add a documentation drift check for prohibited maturity terms without a
  ledger ID/evidence link (`scripts/check_doc_drift.py`).

## Stage 1 — Memory and Unsafe-Boundary Hardening

### `MimirWell` and allocation ownership (completed)

- [x] **[verified, AES-MEM-001; AER-002] Replace address-1 exhaustion:** Made
  `MimirWell.allocate()` raise catchable `Error("MimirWell: memory pool exhausted")` before returning any invalid pointer (`pixi run mojo run aesir_engine/tests/run_all.mojo`).
- [x] Reject nonpositive pool sizes and negative allocation requests.
- [x] Add checked add/multiply arithmetic for pool sizing and offset advancement.
- [x] Define and enforce alignment for each tensor/buffer allocation.
- [x] Add explicit checkpoint/rewind ownership instead of accepting arbitrary
  offsets in `reset_kv_cache` or related helpers.
- [x] Prove exhaustion, overflow, alignment, repeat-failure, and offset-integrity
  behavior without unsafe dereference.
- [x] Ensure construction and generation failures reclaim owned allocations and
  preserve the persistent runtime boundary.

### Tensor, buffer, and cache contracts

- [x] **[verified, AES-MEM-002; AER-005] Add checked `RuneTensor` construction:**
  Reject negative/overflowed shapes, invalid spans, null/sentinel pointers, and
  provide checked `get_checked` / `set_checked` indexing.
- [x] Define borrowed versus owned, mutable versus immutable, and lifetime
  relationships for mmap-, pool-, shard-, and result-backed tensors.
- [x] Add checked boundary alternatives for `RuneTensor.get()` and `set()`.
- [x] Validate `KVCache` layer count, context, KV width, products, and pool
  capacity during construction.
- [x] Validate `KVCache.append()` layer, position, key width, and value width.
- [x] Validate `get_k_slice()`/`get_v_slice()` layer and requested sequence span.
- [x] **[partial, AES-MEM-004]** Replace the PagedKVCache counter with real
  multi-sequence page tables, physical ownership, translated access,
  per-layer initialization bounds, exhaustion, release, and reuse.
- [ ] Integrate the paged pool with attention/session scheduling and add
  eviction, shared-prefix reference counts/copy-on-write, GPU pages, and
  memory-efficiency measurements (`AES-MEM-004`).
- [x] Remove misleading ring-buffer behavior and wording: fixed-capacity
  appends now reject overflow without mutation; chronological wraparound remains
  explicitly unimplemented.
- [x] Replace sentinel-bearing usable `TransformerBlock` constructors: the
  GGUF-backed path now requires nine usable tensors, the legacy overload raises,
  and the copy path preserves only validated views.
- [x] Make `NPUBuffer`/`GPUBuffer` honest host-view descriptors until real device
  allocation exists; validate sizes and ownership.

### Memory-store and hot-path refinement

- [ ] **[verified, AES-MEM-005] Instrument dynamic allocations:** Extend the
  narrowly verified pool restoration and ownership boundary by defining the exact
  steady-state token region and measure every list/string/block/workspace heap
  allocation.
- [x] Remove per-token transformer-block copies and avoid hot-path list growth.
- [x] Add exception-safe workspace guards around transformer blocks and
  `forward_pass()`.
- [x] Validate `MimirStore` capacity, dimension, products, embedding ownership,
  and copied-document lifetime.
- [x] Make full-capacity/dimension failures explicit results rather than warning
  and silent truncation.

## Stage 2 — CPU Kernel Contract and Numerical Hardening

- [x] **[verified, AES-CPU-008] Create one uniform checked-kernel boundary:**
  Validate tensor shapes, spans, alias rules, output sizes, and finite policies
  before unsafe kernel loops.
- [x] Add randomized F32-reference tests for `gemm_f16` across rectangular
  shapes, zero/one dimensions, lane tails, magnitudes, NaN, and infinity.
- [x] Add direct RMSNorm F32-reference tests across widths/tails/extremes and
  reject mismatched weights or zero width.
- [x] Add RoPE reference tests for positions, head widths, model theta, scaling
  variants, odd-width rejection, and negative positions.
- [x] Add causal GQA/MHA attention reference tests across query/KV head ratios,
  sequence lengths, masks, and finite extremes.
- [x] **[verified, AES-CPU-005] Repair or relabel `flash_attention_2`:** Add safe
  tails and causal semantics, then prove algorithmic parity; otherwise stop
  calling it fused FlashAttention-2.
- [x] Complete SiLU numerical/bounds coverage.
- [x] Define GEGLU math/output shape, reject odd sizes, compare to a reference,
  and clarify the actual SwiGLU transformer path.
- [x] Make `cosine_similarity` reject dimension mismatch; define zero-vector,
  NaN, infinity, and tie behavior.
- [x] Validate all shard list lengths/spans; never silently take a minimum when
  contracts disagree.
- [x] Use wider accumulation where required and publish explicit tolerances.

## Stage 3 — GGUF and Tokenizer Generalization

### GGUF loader

- [x] **[verified, AES-LDR-005] Refactor loader state:** Separate unopened,
  header-parsed, tensor-mapped, validated, failed, and closed states.
- [x] Add checked integer conversions/arithmetic for all offsets, lengths,
  counts, alignments, shapes, and products.
- [x] Define duplicate metadata/tensor-key behavior.
- [x] Replace architecture-unsafe unaligned/native-endian reads with portable
  bounded reads.
- [x] Guarantee unmap/free/close cleanup on every partial parse or mapping error.
- [ ] Build a malformed GGUF corpus covering magic, versions, types, truncation,
  alignment, overlapping/out-of-range tensors, dimensions, duplicate keys,
  invalid UTF-8, and resource limits.
- [ ] Add a loader fuzz harness and regression seeds.
- [ ] Add real F16 fixtures for tied output, RoPE metadata/scaling variants,
  tokenizer variants, and at least one additional architecture only when its
  inference path exists.

### Tokenizer and decoder

- [x] Validate vocabulary finalization, parallel metadata lengths, duplicate
  tokens, sparse IDs, special-token ranges/types, and model add-BOS policy.
- [ ] Replace potentially quadratic greedy merge behavior with a profiled,
  correct candidate data structure without changing reference IDs.
- [x] **[verified, AES-TOK-003] Implement a stateful byte/UTF-8 decoder:** Accumulate
  byte tokens, emit only complete sequences, define invalid-byte and flush rules,
  and handle special/control tokens.
- [x] **[verified, AES-TOK-004] Add multilingual differential corpora:** Cover
  whitespace, combining marks, emoji, CJK, RTL scripts, invalid bytes, controls,
  and tokenizer normalizer metadata against authoritative references.
- [x] Add encode/decode round-trip tests where the source tokenizer contract
  permits round trips.

## Stage 4 — Generation Quality and Request Semantics

- [x] Add one validated `GenerationConfig` with explicit greedy mode and bounds.
- [x] **[verified, AES-GEN-006] Add configurable stop-token sets.**
- [x] Add sequence-aware stop strings spanning token and streaming boundaries,
  with explicit visible-text exclusion behavior.
- [x] Add model-produced EOS fixtures rather than testing EOS policy only as a
  helper function.
- [x] Add `cancelled` and `error` result states with deterministic cleanup.
- [x] **[verified, AES-GEN-005] Implement sampling:** Temperature, top-k, top-p,
  repetition/frequency/presence penalties, optional min-p/typical-p, explicit
  composition order, validated RNG, and deterministic seed.
- [x] Compare seeded sampling vectors and end-to-end sequences with an
  authoritative reference.
- [x] **[verified, AES-GEN-007] Implement GGUF chat templates and message roles:**
  Validate escaping, control tokens, system/user/assistant transitions, and
  model-specific reference transcripts.
- [x] **[verified, AES-GEN-008] Design batching and concurrent sessions:** Explicit
  request/cache ownership, scheduler fairness, cancellation, error isolation,
  and resource limits.
- [x] Add broad multi-model/multi-prompt numerical, token, text, EOS, context,
  stop, failure-cleanup, and cancellation regression corpora.
- [x] Make logit argmax initialization and finite-logit handling correct for all
  representable values.
- [x] **[verified, AES-GEN-009] Implement real thought-token masking and logit suppression.**

## Stage 5 — Persistent CLI, Model Store, and Distribution

### CLI grammar and REPL

- [x] **[partial, AES-CLI-009] Implement CLI flag option parser:** `--verbose`, `--format json|text`, `--keepalive <duration>`, `--modelfile <path>`, `--raw`, `--insecure`, `--max-tokens N`, configuration/acceleration intent, and duration parsing. Operational wiring remains incomplete for the broader capability.
- [x] Replace the line-based configuration approximation with strict bounded
  nested JSON syntax, schema/type/range checks, duplicate rejection, and
  adversarial parser coverage.
- [x] **[verified, AES-CLI-003] Complete the chosen Modelfile grammar:** Quoting,
  multiline directives, validation, errors, and compatibility corpus.
- [ ] Connect parsed parameters, templates, system messages, and licenses to the
  actual stored model/generation configuration.
- [ ] **[partial, AES-CLI-008] Build a general interactive REPL:** Unify
  multi-turn conversation state, slash commands (`/set`, `/show`, `/clear`,
  `/bye`), parameter tuning, and stream execution beyond the native Gemma/Llama
  CUDA chat profiles.
- [x] Reject ordinary legacy REPL input and bare interactive `run` without
  turning model/runtime errors into assistant messages or mutating history.

### Persistent model store

- [x] **[partial, AES-CLI-004] Add the content-addressed model store:** The
  empty versioned catalog now owns immutable `blobs/sha256/<digest>` objects.
  `create --model` hashes the exact opened inode, records its measured size,
  deduplicates safely, and `verify` performs a full rehash.
- [x] Compute real SHA-256 digests and sizes from imported bytes; recipe-only
  manifests retain their explicitly unknown byte metadata.
- [x] Implement atomic add/copy/remove/update with rollback and restart tests.
- [x] Define the durable schema as strict `catalog.v1`; reject unknown versions
  on normal load and admit the legacy delimiter format only through explicit
  empty-destination migration. See
  [catalog schema contract](TASK_catalog_schema_versioning.md) and
  [schema evidence](docs/evidence/catalog-schema-integration-2026-10-10/README.md).
- [x] Define content-addressed identity pairings: zero-sized `fnv1a64:` recipe
  fingerprints versus positive-sized lowercase SHA-256 blob identities; optional
  expected digest/size must match measured source bytes. See
  [blob identity contract](TASK_content_addressed_blob_identity.md) and
  [integration evidence](docs/evidence/blob-identity-integration-2026-10-10/README.md).
- [x] Define atomic model-registration visibility and rollback: expected
  identity is checked against measured bytes before catalog publication; mismatch
  rolls back only a newly published blob, while post-rename sync uncertainty
  retains the referenced blob. See
  [registration contract](TASK_atomic_model_registration.md) and
  [adversarial evidence](docs/evidence/atomic-registration-adversarial-2026-10-10/README.md).
- [x] **[partial, AES-CLI-005] Connect catalog output:** `list`, `show`, `create`, `cp`, and `rm` use the restart-safe recipe catalog with built-CLI process evidence.
- [ ] Connect `ps` and `stop` only after a real live-session registry exists.
- [x] Define model-in-use, not-found, duplicate, permission, corruption, and
  concurrent mutation semantics.
- [x] Add locked, reference-aware blob garbage collection. `gc` validates the
  complete directory and every catalog size before deletion, removes unreachable
  blobs and strict stale-stage names, synchronizes the directory, and reports
  exact accounting. Systematic process-crash/fault injection at every filesystem
  boundary remains open.

### Network distribution

- [ ] **[partial, AES-ECO-003] Implement real Hugging Face HTTPS download:**
  Revisions, filenames, URL encoding, redirects, authentication, resume/range,
  timeouts, cancellation, byte counts, and errors.
- [x] Verify expected size/digest again inside the locked store transaction
  before atomic catalog promotion; mismatch rolls back a newly created blob.
- [ ] Protect tokens/secrets from logs, command output, crash reports, and
  committed files.
- [x] Connect public pinned `pull --name` to the content-addressed store and
  prove it with a live external GGUF registration/reverification harness.
- [ ] Scope `push` separately with authentication, conflict, retry, and integrity
  semantics; otherwise return explicit unsupported.
- [ ] Implement `create` as real manifest/layer construction from a validated
  Modelfile.
- [ ] **[partial, AES-CLI-009] Build an Ollama CLI differential conformance suite
  for only the explicitly supported version and commands.**

## Stage 6 — Service Boundary and Protocol Conformance

Native milestone (2026-08-31): authenticated loopback `/health` and
`/v1/generate` now execute on both loaded CUDA profiles with strict bounds,
deadline recovery and active shutdown. See [native service](docs/NATIVE_SERVICE.md).
The legacy formatters below are not exposed compatibility APIs.

### Socket and HTTP foundation

- [x] Define and verify bounded live HTTP request parsing: 8 KiB head, 64
  unique headers, 1024-byte header values, 128 KiB declared body, exact-length
  reads and one absolute read deadline. See
  [request parser contract](TASK_request_parser_bounds.md) and the dated
  baseline/unit/integration/adversarial receipts under
  `docs/evidence/request-parser-*-2026-10-10/`.
- [x] Reject ambiguous HTTP request framing: duplicate header names (including
  case variants), Transfer-Encoding, Expect, malformed request lines/CRLF,
  unsupported methods and unsupported GET/POST body policies. See
  [framing rejection contract](TASK_http_framing_rejection.md) and the dated
  framing evidence under `docs/evidence/http-framing-*-2026-10-10/`.
- [x] Define the live service listener/client/queue ownership lifecycle and
  borrowed cancellation descriptor; document cooperative shutdown limits in
  [the socket ownership contract](TASK_socket_ownership_shutdown.md), with
  baseline, unit, integration, and adversarial receipts under
  `docs/evidence/socket-shutdown-*-2026-10-10/`.
- [ ] Move transport serialization and socket ownership out of `AesirEngine`
  behind a service/request API.
- [x] **[verified, AES-SRV-001] Add loopback bind/listen/accept/close tests:** POSIX socket setup, `SO_REUSEADDR`, `set_nonblocking()` (`fcntl`), and deterministic cleanup.
- [ ] Build a platform-safe socket abstraction before claiming another OS.
- [x] **[verified, AES-SRV-002] Implement HTTP/1.1 request parser & router:** Request line (method, path, protocol), header block (`Content-Length`), body isolation, and route dispatching (`HTTPRequest`).
- [x] **[verified, AES-SRV-003] Implement write-all and HTTP response framing:** `write_all_bytes()`, `build_http_response()`, `build_sse_chunk()`, and `build_http_chunk()`.
- [x] Use a real JSON serializer/escaper for prompts, model output, errors, and
  Unicode rather than concatenating untrusted strings.
- [x] **[verified, AES-SRV-010] Native serialized service:** request sequence,
  bounded errors/I/O, deadlines, cancellation and cooperative shutdown.
- [ ] Add multi-client session ownership, scheduling, streaming backpressure
  and sustained load/security evidence.

### Compatibility surfaces

- [ ] Choose one first compatibility API and record its exact supported version,
  endpoints, schemas, and exclusions.
- [ ] **[partial, AES-SRV-005] [partial, AES-SRV-006] OpenAI:** Extend the live
  text-only request/response subset, usage/error contracts and incremental SSE
  with official-client tests; embeddings remain a separate unshipped capability.
- [ ] **[missing, AES-SRV-007] llama.cpp server:** Connect real tokenize,
  detokenize, completion, health, props, slots, and metrics only where supported;
  pass differential tests against a pinned server.
- [ ] **[partial, AES-SRV-008] Ollama HTTP:** Extend the live generate/chat/model
  subset and incremental NDJSON with real-client differential tests.
- [ ] **[verified, AES-SRV-004] Streaming:** Extend the narrowly verified framing
  utilities: pick protocol framing, use stateful
  UTF-8 decoding, escape chunks, handle partial writes/backpressure/disconnect,
  propagate cancellation, and prove the final frame.
- [ ] **[partial, AES-SRV-009] Add bounded concurrent service operation:** Worker
  ownership, queue limits, fairness, cancellation, race, soak, and load tests.

## Stage 7 — Real Embeddings and RAG

- [x] Harden cosine similarity dimension/finite/zero-vector contracts and
  randomized reference coverage.
- [x] Harden `MimirStore` dimensions, capacity, ownership, result/tie semantics,
  and hot allocations.
- [ ] **[partial, AES-RAG-003] Replace the constant query tensor with a real
  embedding model or verified extraction path.**
- [ ] **[partial, AES-RAG-004] Build corpus ingestion:** File/document parsing,
  deterministic chunking, metadata, embedding batches, versioning, and durable
  index storage.
- [ ] Add update/delete/reindex, corruption, restart, and compatibility behavior.
- [ ] Build a retrieval evaluation corpus with recall/ranking metrics and
  reproducible expected results.
- [ ] **[partial, AES-RAG-005] Complete end-to-end RAG:** Query embedding,
  retrieval, context budgeting, prompt integration, source metadata/citations,
  grounded-answer tests, and explicit no-result behavior.

## Stage 8 — Quantized Inference, One Format at a Time

- [x] Choose one authoritative GGML quantized format; Q4_K_M is the current
  advertised candidate and is implemented (`AES-QNT-001`).
- [x] Replace toy block structs with the exact upstream byte layout, scales,
  minima/zeros, packing, alignment, and tail contract.
- [x] Validate exact input byte spans and reject unsupported/tail cases before
  reads or writes (`AES-QNT-002`).
- [x] Compare full dequantized blocks against an independent authoritative
  decoder across fixed and randomized fixtures (`AES-QNT-002`).
- [x] Extend `GGUFSeer` to map/own that one quantized type safely (`AES-QNT-003`).
- [x] Implement a correct dequantized or fused quantized matmul path (`AES-QNT-003`).
- [ ] **[partial, AES-QNT-003] Load a real quantized GGUF and compare logits,
  first token, and a deterministic sequence with pinned `llama.cpp`.**
- [ ] Add each additional GGML format only with its own exact fixture and oracle.
- [ ] Connect the working GPTQ, AWQ, EXL2, HQQ, and SmoothQuant host primitives
  to parsed model tensors, external fixtures, and measured accelerator kernels.
- [x] Implement canonical IQ2_XXS 66-byte host decoding/GEMM with the upstream
  codebook and an independent raw-block oracle regression (`AES-QNT-010`).
- [x] Implement canonical IQ1_S 50-byte host decoding/GEMM with the complete
  upstream grid and an independent raw-block oracle regression (`AES-QNT-010`).
- [x] Implement canonical GGML TQ1_0 54-byte ternary host decoding/GEMM, retain
  `TERNARY_155BIT` as a compatibility alias, and verify all packed regions with
  an independent raw-block oracle regression (`AES-QNT-010`).
- [x] Replace guessed quantization metadata with exact fixed-block records and
  explicit external-metadata boundaries for every internal discriminant
  (`AES-QNT-011`).
- [x] Measure fused packed and dequantize-then-F16 host GEMM candidates, require
  numerical agreement, publish atomically from caller-owned scratch, and cache
  the exact-device/format/shape winner in memory (`AES-QNT-011`).
- [x] Serialize and transactionally restore a bounded, checksummed v1 tuning
  cache tied to caller-supplied build and device identities (`AES-QNT-011`).
- [x] Add locked, no-follow, bounded, private-stage/fsync/rename/fsync Linux
  cache-file persistence around the core codec (`AES-QNT-011`).
- [ ] Derive automatic executable/physical-device fingerprints, add synchronized
  CUDA and metadata-bearing candidates, and build a representative statistical
  benchmark matrix (`AES-QNT-011`).
- [x] Remove any dispatcher fallback that silently treats an unknown format as a
  different format (`AES-QNT-003`).

## Stage 9 — Real Hardware and Multi-Device Execution

### Honest discovery and unsupported behavior

- [ ] **[partial, AES-ACC-003] Separate configured from discovered devices:**
  Probe the platform and return only available backends with capability/error
  metadata.
- [x] Make absent GPU/NPU backends return explicit unsupported errors, never CPU
  fallback under a hardware execution label (`AES-ACC-003`).
- [x] Rename/describe host SIMD variants honestly; compiling a lane width does
  not prove ARM NEON, CUDA, OpenCL, or a vendor NPU (`AES-ACC-003`).

### First physical accelerator vertical slice

- [x] Select exactly one physically available GPU or NPU backend: NVIDIA CUDA
  through MAX 26.5 on the observed RTX host.
- [x] Implement real runtime/driver discovery and version/capability checks for
  the selected CUDA slice.
- [x] Implement backend allocation, ownership, host/device transfer or a precise
  zero-copy contract, synchronization, and error propagation.
- [x] Implement at least one genuine device kernel and compare its output with a
  CPU F32/verified reference on physical hardware.
- [x] Connect GPU-2 resource ownership to one reusable production-core CUDA F16
  GEMM and prove exact/tolerance parity, rejected-request safety, repeatability,
  and a deliberate post-kernel mismatch on physical hardware.
- [x] Add bounded GPU-2/GPU-3 allocation-lifetime diagnostics, CPU adversarial
  accounting evidence, and physical synchronous-path integration receipts;
  retain single-host-thread, no-implicit-fence, no-driver-reuse boundaries
  (`AES500-021` through `AES500-029`; see
  `TASK_cuda_allocation_lifetime_tracking.md`).
- [ ] Connect the kernel to one real-model inference slice and preserve token/
  logit parity.
- [x] Record reproducible GPU-0 through GPU-3 physical commands, device/toolchain
  identity, independent reference checks, repeated processes, and negative
  controls before promoting `AES-ACC-008` to `partial`. Trusted hardware CI
  remains open.
- [ ] Measure actual latency/throughput/memory only after correctness passes.

### Multi-device

- [x] Harden host shard functions for counts, divisibility, list lengths, spans,
  ownership, and cleanup while retaining honest host-only names (`AES-ACC-004`).
- [ ] **[missing, AES-ACC-004] Redesign multi-device GQA inference:** Explicit
  placement, correct Q/K/V partitioning, reconstruction, attention ownership,
  and cache layout.
- [ ] Implement asynchronous device work, transfer/compute overlap where valid,
  real collectives, synchronization, failure propagation, and cancellation.
- [ ] Prove single-device parity, multi-device correctness, device-loss behavior,
  and scaling on physical systems.
- [ ] **[missing, AES-ACC-009] Make any direct mmap/device-memory claim
  backend-specific and evidence-backed; otherwise keep it unsupported.**

## Stage 10 — Optional Ecosystems as Separate Projects

### ONNX

- [x] **[partial, AES-ECO-004] Decode bounded ONNX protobuf metadata:** Real
  file-backed/in-memory IR, producer, default opset and node fields with strict
  wire bounds, UTF-8 validation, rollback and recognized-operator rejection.
- [ ] Parse a pinned ONNX conformance model's TensorProto initializers,
  attributes, graph inputs/outputs, types and shapes.
- [ ] Define and implement an executable operator/type/shape subset; then build
  a planner and compare outputs with ONNX Runtime conformance fixtures.

### ExLlama/EXL2

- [ ] **[missing, AES-ECO-005] Scope an actual EXL2 parser/runtime for AESIR.**
- [x] Require a real EXL2 model, authoritative decoder/runtime comparison, and
  physical CUDA evidence before any parity claim (`AES-ECO-005`).

### llama.cpp CLI

- [ ] **[missing, AES-ECO-006] Define an intentionally supported subcommand and
  version subset; pass differential argument/output/error/exit tests.**
- [x] Never infer CLI/server parity from the pinned token-oracle comparison alone (`AES-ECO-006`).

### Grammar-constrained generation

- [x] **[verified, AES-ECO-007] Implement real decoded-token prefix automata
  and logit masking for the exact boolean and JSON-number schemas.**
- [x] Reject token-ID-only masking and unsupported JSON/general-GBNF requests
  without mutating logits or claiming constrained model generation.
- [ ] Parse a versioned GBNF subset, connect real tokenizer vocabulary text and
  the generation loop, and pass independent constrained-generation fixtures.

### Speculative decoding

- [x] **[verified, AES-ECO-008] Implement and validate the isolated sequential
  `min(1, p_target/p_draft)` token acceptance-prefix arithmetic.**
- [x] Remove fabricated repeated-argmax proposals, logits-as-probabilities and
  silent normal-generation fallback; incomplete integration paths fail closed.
- [ ] Implement real per-step draft proposals, batched target probabilities,
  residual correction sampling and transactional target/draft KV coordination.
- [ ] Prove target-distribution equivalence and a measured speed benefit before
  enabling speculative generation.

### Resilience, eventing, and concurrency

- [ ] Expand `ErrorGuard` into checked ownership/span/alignment/finite boundaries
  or remove the implication that a helper can sanitize unsafe pointers globally.
- [ ] **[verified, AES-RES-002] Expand the restart-safe `StateVault` marker:**
  Versioned bounded marker records, corruption checks, atomic replacement, and
  restart parsing work. Define complete session-state ownership, coordinate
  concurrent writers, add authenticated records where required, and prove
  injected write/sync/permission failures before calling it runtime recovery.
- [ ] **[verified, AES-RES-003] Expand the bounded synchronous local event bus:**
  Define ownership and add synchronization, reentrancy, durable replay,
  acknowledgement/retry, and cross-thread failure semantics.
- [ ] **[verified, AES-RES-004] Expand the bounded task descriptor queue into a real worker pool:** Threads, bounded
  queue, task completion/errors, synchronization, cancellation, and shutdown.
- [ ] **[missing, AES-RES-005] Define real recoverable failure boundaries and
  inject faults:** Prove model/KV/session/socket continuity or document explicit
  loss semantics.

### Swarm/distributed execution

- [ ] **[verified, AES-SWM-001] Expand the local protocol/version and node
  descriptors into an authenticated, authorized, encrypted discovery and
  membership model.**
- [ ] Replace the current caller-owned peer records with observed cross-process
  state and real heartbeat freshness/failure handling (`AES-SWM-003`).
- [ ] Extend the local capacity selector with reservations, concurrent updates,
  fairness, staleness, and scheduling policy (`AES-SWM-002`).
- [ ] **[missing, AES-SWM-003] Prove join/leave/heartbeat between separate
  authenticated processes.**
- [ ] **[missing, AES-SWM-004] Execute one real inference request remotely:**
  Model availability, prompt/result transport, streaming, cancellation,
  timeout, retry/idempotency, and validation.
- [ ] Derive CLI/REST state from a live cluster and pass multi-process failure
  tests before emitting `ONLINE`, `HEALTHY`, `JOINED`, or `DISPATCHED` (`AES-SWM-004`).

## Stage 11 — Operations, Security, Portability, and Release Readiness

### Continuous integration and portability

- [ ] **[partial, AES-FND-005] Complete CI coverage:** The clean Linux checkout,
  dependency lock, `E-BUILD`, `E-MASTER`, deliberate negative control, ledger,
  fixture, and artifact/path gates exist. Add required branch protection,
  supported-target coverage, formatting, and content-level secret scanning.
- [ ] Add opt-in/cached external-fixture jobs without committing model weights.
- [ ] **[missing, AES-FND-006] Build platform abstractions and CI for every
  explicitly supported OS/architecture; keep untested platforms unsupported.**
- [ ] Define dependency/toolchain update, lockfile, compatibility, and rollback
  policy.

### Benchmarks and efficiency

- [ ] **[partial, AES-OPS-001] Build a real benchmark harness:** Timer, token
  accounting, correctness gate, warmup, repeated samples/statistics, raw output,
  hardware/software/model/prompt metadata, and reproducibility command.
- [ ] **[missing, AES-OPS-002] Measure latency, throughput, memory, utilization,
  power, and thermal behavior before claiming fast, efficient, cold, or maximum
  hardware use.**
- [ ] Compare only equivalent models, precisions, prompts, contexts, sampling,
  and correctness outcomes.

### Security and observability

- [ ] **[partial, AES-OPS-003] Complete the threat model:** Untrusted GGUF/ONNX/
  Modelfile inputs, local/network clients, model registries, secrets, filesystem,
  unsafe pointers, resource exhaustion, and swarm peers.
- [ ] Add parser fuzzing, resource limits, secure filesystem permissions,
  checksum/signature policy, secret redaction, and dependency review.
- [ ] Decide safe network exposure defaults; add authentication/TLS policy before
  recommending non-loopback use.
- [ ] **[partial, AES-OPS-004] Add structured logs, real health/metrics, request/
  session correlation, error taxonomy, and observed-state consistency tests.**

### Repository and release hygiene

- [x] Prevent new tracked executable/build/model/archive/runtime-state/private-key
  format artifacts, tiny placeholder models, and duplicate canonical root assets
  with a baseline-locked policy, deterministic self-tests, and fatal CI
  enforcement.
- [x] Require fixture classification, ownership, purpose, consumer, evidence
  boundary, license, immutable source/construction, exact size, and SHA-256;
  keep registered external references outside Git.
- [ ] **[partial, AES-FND-007] Remove generated executables from source tracking
  through a reviewed, recoverable migration; preserve required source/history.**
- [ ] Add ignore and CI checks for binaries, model weights, secrets, caches,
  absolute local paths, and unrelated generated artifacts.
- [ ] Define supported build artifact formats, checksums/signatures, provenance,
  installation/uninstallation, configuration, data paths, and upgrade behavior.
- [ ] Keep AGPL/NOTICE/third-party attribution synchronized with every imported
  dependency or adapted source.

### Production readiness gate

- [ ] **[missing, AES-OPS-005] Do not label A.E.S.I.R. production-ready until:**
  all applicable safety blockers close; supported capabilities have external
  evidence; CI is sustained; platform, security, observability, release,
  recovery, concurrency, load, and upgrade gates pass; and no operational output
  is fabricated.

### Ongoing Ledger and Audit Discipline

- [x] Mechanically reject unknown or ledger-mismatched status tags in this TODO;
  keep checkbox completion distinct from capability maturity.
- [x] Separate current evidence from preserved historical milestone claims in
  both active vision documents and reject pre-boundary status drift.
- [ ] Update the capability ledger in the same commit as every material status
  change; never silently promote a claim.
- [ ] Add a stable capability ID when splitting a broad claim; never repurpose an
  existing ID for different behavior.
- [ ] Keep every `verified` entry tied to an executable command and explicit
  evidence boundary.
- [ ] Keep every simulated/scaffolded/missing behavior visible until its
  acceptance gate passes or Volmarr approves removal.
- [ ] Add every newly found missing, incomplete, buggy, unsafe, misleading, or
  refinement-needing function to the reality audit and link it from this TODO.
- [ ] Re-run function census and claim search after every major stage so new
  public declarations and marketing language cannot escape accounting.

### Future After All Core Systems Work and Are Stable (These are immutable until fully won)

- [ ] Crush all bugs and send them to Hel!
- [ ] Make Project A.E.S.I.R. so stable that even Ragnarok could not crash it!
- [ ] Create a roadmap to add back in all previously rejected or removed features, and get every single one of those features to a true working stable state, and then follow that roadmap all the way to Valhalla.
- [ ] Create a roadmap to make Project A.E.S.I.R. the number one best and most popular Local-LLM-Inference-Server on Earth Midgard, and then carry out that roadmap till it turns into manifest reality.
- [ ] Create a roadmap to get all AI harnesses to have support for using Project A.E.S.I.R. and follow that roadmap till it turns into manifest reality!
- [ ] Create a roadmap to get RuneForgeAI so well known that all the Cyber-Viking skalds in all the Nine Worlds are writing poetry to sing its praises! Follow that roadmap till it becomes manifest reality!

- [x] SPD-00/04 explicit strategy3 projection resources: public37/1070 plain/
  profiled vectors/cache/IDs/state match accepted3 exactly. Full4837/120919 kernels
  and recorded resources precede589/7449 ordered ranges and981/20385 projection
  correlations. Down32 selects actual grid24/block256/static19008/register255;
  gate/up/down long3.452520s of6.648634s summed kernels (51.9283%). Ten contracts/
  master190 passes/one skip. No cause/occupancy/spill/service ratio inferred.
  [Operation](docs/NATIVE_TURING_DOWN_PROJECTION_TRACE.md). Next measure narrower
  shared staging as a register/resource experiment, retaining original kernels.

- [x] SPD-01/02 isolated16-column staging: rows64/128 preserve complete1658880
  F32 bits per configuration/2100 independent dots/1622640 guards/840 timings;
  all56 same-capture comparisons lose to original64 (best.946255), no promotion.
  Nineteen contracts/master190/one skip; finite atomic scores now reject per-call
  underflow/ratio overflow with complete metrics retained.
  [Operation](docs/NATIVE_TURING_NARROW_STAGING.md). Next keep proven32-column
  width and measure bounded loop structure.

- [x] SPD-01/02 bounded runtime-group32 staging: both64/128 numerical/bit/guard/
  independent gates pass, all56 original64 comparisons lose (best.826220); no
  promotion.22 portable contracts/master190/one skip.
  [Operation](docs/NATIVE_TURING_LOOP_STAGING.md). Next test paired FFN gate/up
  input staging reuse under independent complete bytes/span/timing gates.

- [x] SPD-01/02 paired FFN gate/up experiment: 983040 complete values per owner,
  original F32 bits, 600 independent dots, 6720 guards, 144 synthetic pairs,
  12 span refusals and all120 rotated timings pass. Batch4 original/pair1.136289
  loses native; batch32 original/pair0.778242 loses staged. No selection.
  Ten contracts/master190/one skip; retained checker-formula failure and new
  exclusive successful revalidation. [Operation](docs/NATIVE_TURING_PAIRED_FFN.md).
  Next isolate causal attention under independent complete math/guard gates.

- [x] **[verified, AES-ACC-010] SPD-03 bounded shared-score causal primitive:**
  39 cases /1370112 complete original F32 bits and independent outputs /364518
  guards/full query and KV input immutability/16 span refusals/all780 rotated
  times pass. Full4/32 improve in one capture; long single queries lose. No
  selection. Nine contracts/master190/one skip, checked fixture33824 stride.
  [Operation](docs/NATIVE_FUSED_CAUSAL_ATTENTION.md).
- [ ] SPD-03 actual model Q/K/V or source-bound full-model exact state/CPU
  quality; generation/replay/controls/context/device/concurrency/soak/runtime
  gates before production selection. Keep original slow-case path.

- [x] SPD-03 optional strategy4 full-model prefill: all513024 values per owner
  retain source3 F32 bits/IDs/full cache; independent CPU/own-repeat/4352 guards/
  eight invalid tiles/32 paired timings pass. Actual fused196/56/196/1008 and
  original queries56/28/84/56 prove selection. Seven contracts/master190/one skip.
  Explicit CLI/binary/source/after-hash gates; controls/tracing/replay4 closed.
  [Operation](docs/NATIVE_FUSED_ATTENTION_MODEL.md).
- [x] SPD-03 strategy4 causal greedy/seeded generation: all96 full frames /
  12312576 values per owner / independent CPU / own UInt32 fresh replay / exact
  source4 initial bits / causal samples/state /4352 guards / actual fused/down/
  original-query counters pass. Eleven contracts/master190/one skip; exclusive
  source CSV/report/binary and current binary before/after hash fences.
  [Operation](docs/NATIVE_FUSED_ATTENTION_DECODE.md). No speed score.
- [x] SPD-03 strategy4 sealed owning-context replay:45-ID checkpoints/eight
  full continuation frames/all four vectors/actual UInt32 bits/CPU/source choices/
  sample/state/4352 guards/28 mutation-free refusals and down/fused/original
  counters pass. Nine contracts/master190/one skip; explicit plan/live/source
  capability/current and accepted decode binary hashes. No speed score.
  [Operation](docs/NATIVE_FUSED_ATTENTION_CHECKPOINT.md).
- [x] SPD-03 strategy4 enabled-control recovery: final default-false capability,
  fresh disabled4 full source4 bits/IDs/cache/CPU/binary gate; healthy synced
  uncommitted/reset-required timeout/cancel/fd aborts, preserved allocations and
  all513024 recovered vectors/9792 guards/actual layer counters/caller mask plus
  observer poison policy pass.15 adversarial contracts/master190/one skip.
  [Operation](docs/NATIVE_FUSED_ATTENTION_CONTROLS.md). No enabled-control speed score.
- [ ] SPD-03 strategy4 owned tracing/control-capable sealed replay and broader context/device/concurrency/soak/runtime/
  refreshed-provider acceptance before production selection.

- [x] SPD-03/04 explicit fused4 owned trace: public37/1070 plain/profiled full
  source bits/cache/IDs/state/counters and4352 combined guards pass. Complete
  1869/32215 kernel resources precede589/7449 projection ranges with981/20385
  projection kernels plus56/1008 owned fused kernels. Long FFN3.456781s of
  6.046571s=57.1693%, fused attention.814218s=13.4658%, diagnostic/unscored.
  Nine contracts/master190 passes/one skip/seven builds; actual fused grid24x4/32,
  block128/register46/static16384. [Operation](docs/NATIVE_FUSED_ATTENTION_TRACE.md).
  Next measure per-CTA token partitioning to reduce FFN accumulation live state.

- [x] SPD-01/04 four bounded token partitions: complete144/12 synthetic/refusals,
  1,658,880 outputs/2100 independent dots/840 rotated timing records per variant
  pass original bits/fixed numeric/guards/hash gates. Seven contracts/master190/
  one skip and target/original build gates pass. No canonical batch32 FFN candidate beats both comparison owners in this session. Keep selected kernels and retain this experiment; choose the next measured bottleneck experiment.
  [Operation](docs/NATIVE_TURING_TOKEN_PARTITION.md).

- [x] SPD-03 small-score isolated primitive: all33 cases/1142784 outputs per owner/
  full original UInt32 bits/pinned unchanged CPU/906066 guards/full query+KV/
  17 refusals/660 samples, and all2178 complete profiled resources/correlations/PID.
  Static shared16384→6144 is62.5% smaller; no normal selector/model/provider claim.
  [Operation](docs/NATIVE_SMALL_FUSED_ATTENTION.md).10+8 hostile contracts/master190;
  retained interval/executable capture refusals; six final builds precede fresh GPU.
- [x] SPD-03 small-score default-disabled actual model/full cache/IDs/logits/counters/
  own bits/source4/independent CPU gate: all513024 per owner/4352 guards/8 invalid
  tiles/legacy `ADMISSION,5,12,0` metadata/32 timings pass in the dated
  2026-10-03 receipt, strict actual current/source binaries. Current COUNTS1
  collectors separately record executed refusal counts.
  [Operation](docs/NATIVE_SMALL_ATTENTION_MODEL.md). Seven hostile contracts/master190.
- [x] SPD-03 small-score causal generation/state: all96 full frames/12312576 F32
  per owner/source5 initial bits/independent CPU/own UInt32 replay/samples/history/
  draws/state/4352 guards/actual small/down/closed-fused/scalar counters pass.
  Twelve hostile contracts/master190/seven builds/strict source/current binary
  and all after-fences. [Operation](docs/NATIVE_SMALL_ATTENTION_DECODE.md).
- [x] SPD-03 small-score sealed owning-context replay:45-ID checkpoints/eight
  full continuation frames/1026048 values per baseline/restored owner/UInt32 bits/
  source choices/state/fixed CPU/4352 guards/40 mutation-free refusals/actual down/
  small/closed-fused/scalar counts. Ten hostile contracts/master190/seven builds,
  explicit plan/live/source/current binary gates. No speed score.
  [Operation](docs/NATIVE_SMALL_ATTENTION_CHECKPOINT.md).
- [x] SPD-03 small-score enabled cooperative control recovery: fresh capable-but-
  disabled model baseline, independent CPU, pre-expired/mid-tile timeout, owned
  SIGINT, invalid-fd, explicit reset/recovery, poison/refusal, exact vectors,
  guards, signal mask, all three sm_75 target builds and focused portable checks.
  [Operation](docs/NATIVE_SMALL_ATTENTION_CONTROLS.md) and
  [evidence](docs/evidence/small-attention-controls-2026-10-09/README.md).
  Fixture-only; no production selection or speed promotion.
- [x] AES500-002 independently executed observed disabled-control baseline:
  fresh COUNTS1 actual 8/0 refusals, 32 STATE1 owner snapshots, full source5
  bytes/cache/IDs/counters/guards and unchanged fixed CPU quality. Service
  restored with authenticated ready/CUDA/context4096/prefill4/offload0 health.
  [Evidence](docs/evidence/small-attention-controls-baseline-2026-10-10/README.md).
  No speed score or fresh enabled-control revalidation; next independent gate
  was AES500-003 interface admission and rejection evidence.
- [x] AES500-003 current controls constructor interface: all13 declared
  pre-load refusal modes pass exact first exceptions and known Mojo diagnostics.
  Accepted002 binary/source inventory and active service/PID/health stay unchanged.
  [Evidence](docs/evidence/small-attention-controls-interface-2026-10-10/README.md).
  Source-reviewed defaults/methods and inherited positive002 scope are distinct;
  next independent gate is AES500-004 implementation execution.
- [x] SPD-03 owned strategy5 tracing for the declared public37/public1070
  fixture scope: implementation, adversarial checker contracts, independent
  review correction and physical attribution are recorded in the trace evidence
  receipt. The exact hosted release gate remains separate.
- [ ] Continue with AES500-019 documentation and AES500-020 release verification,
  then runtime/context/device/concurrency/soak/refreshed provider acceptance.
  Control recovery remains closed only for its declared fixture/model/device
  scope; broader runtime/provider gates remain.

## AES500 cross-cutting execution

- [x] AES500-061–069: define, baseline, expose, implement, test, integrate,
  adversarially exercise, independently review, and document pure checked
  half-open span arithmetic. Evidence covers the CPU-only Turing fixture planner
  and does not prove allocation ownership, pointer validity, lifetimes, or
  device bounds. See `TASK_checked_span_construction.md` and
  `docs/evidence/checked-span-baseline-2026-10-10/README.md`.
- [ ] AES500-070 release gate: exact-head hosted CI and the complete Mojo build/
  master suite are addressed locally with the sm_89-targeted build and runner;
  193 tests pass, zero fail, one is explicitly skipped. Exact-head hosted CI is
  still in progress.
- [x] AES500-071–079: define, baseline, publish, centralize, integrate,
  adversarially review and document the current two-dimensional contiguous
  row-major scalar indexing contract. The dedicated master case checks unique
  3x4 values and checked coordinate boundaries; it
  does not prove arbitrary strides or allocation bounds.
- [ ] AES500-080 release gate: local sm_89 target build, CLI help smoke and
  194-case master suite pass; verify exact-head hosted CI before promotion.
- [x] AES500-081–083: contract, source baseline, and current-interface boundary
  reviewed by Architect/Auditor; allocation records are deferred because the
  arena has no stable owner identity and raw-pointer tensor views can escape,
  copy, alias, and survive offset rewinds without invalidation. The interface
  and AES-MEM-001 ledger now state the unsupported ownership/lifetime claims
  and correct the unverified allocator-addition overflow claim. See
  `TASK_allocation_ownership_records.md` and
  `docs/evidence/allocation-ownership-baseline-2026-10-10/README.md`.
- [ ] AES500-084 implementation deferred: establish non-reused live-owner
  identity plus defined arena copy/move/lifetime and reset invalidation before
  adding records. Do not ship a token/generation that cannot validate the live
  owner or prevents ABA revival. Unit, integration, and adversarial evidence
  remain pending that prerequisite architecture.
- [x] AES500-085 current allocator unit evidence: `memory.allocation_bounds`
  confirms adjacent addresses, exact-capacity admission, and unchanged arena
  offset after zero, negative, and oversized request rejection. Full sm_89
  master suite: 194 passed, 0 failed, 1 explicitly skipped, 195 total. These
  checks do not establish ownership, provenance, or lifetime.
- [x] AES500-086 integration disposition: no current owner-record interface
  exists, so migrating a raw-pointer consumer would invent the deferred
  semantics. No consumer is changed; this is a recorded defer, not integration
  evidence.
- [ ] AES500-087 adversarial evidence pending an accepted AES500-084 owner and
  reset-invalidation contract; stale-record and wrong-owner checks cannot be
  implemented against the current API.
- [x] AES500-088 independent review of the deferral boundary: Auditor confirms
  the current raw-pointer arena lacks owner identity and reset-aware lifetime;
  interface, ledger, baseline and tests avoid unsupported ownership claims.
  This closes review of the disposition only; AES500-087 record adversarial
  tests remain pending. Receipt is in
  `docs/evidence/allocation-ownership-baseline-2026-10-10/README.md`.
- [x] AES500-089 documentation reconciliation: task, interface, ledger, roadmap,
  TODO and devlog distinguish current allocator evidence from deferred
  ownership-record implementation, integration, and adversarial work.
  `git diff --check`, `scripts/test_check_doc_drift.py`,
  `scripts/check_doc_drift.py`, and baseline-aware Markdown validation pass.
- [x] AES500-090 release gate: hosted Project Aesir CI run `38018008916` for
  `dc869a320816b30f684f71ebf55e743a53f3ec32` completed successfully. This is
  historical for AES500-090 and says nothing about later heads.
- [x] AES500-091 RMSNorm oracle contract: Architect and Auditor reviewed the
  exact F32 reduction/normalization/multiply order, flat weight-prefix behavior,
  then-current epsilon comparison behavior, and missing pointer-provenance
  checks. Later AES500-094/097 slices record finite-epsilon and tested IEEE
  behavior. General tolerance and F32 overflow/underflow remain open. See
  `TASK_rmsnorm_oracle_breadth.md`.
- [x] AES500-092 baseline: Mojo 1.0.0 source hashes, focused existing short-weight
  rejection, deterministic 2-row captures at widths 3/15/16/17/33, and
  independent NumPy scalar F32 comparison are preserved in
  `docs/evidence/rmsnorm-baseline-2026-10-10/README.md`. All 168 baseline
  outputs match after F16 rounding; this does not establish a broad tolerance
  or exceptional-value policy.
- [x] AES500-093 interface: `core/INTERFACE.md` records that slice's shape/
  weight/epsilon boundary (epsilon is tightened in AES500-094).
  `compute.rmsnorm_interface` passes a valid two-row input
  with overlong non-vector-shaped weights and proves rejected zero/negative
  dimensions using an allocated sentinel, and short weights/zero-negative
  epsilon using logical-range snapshots; every rejection checks the intended
  error. The accepted case asserts descriptor admission only, not numerical
  weight-prefix parity. Final sm_89 master suite: 195 passed, 0 failed,
  1 skipped, 196 total.

- [x] AES500-094 RMSNorm implementation: `rmsnorm` now rejects NaN and either
  infinity alongside zero/negative epsilon before mutation. Focused admission
  tests assert the expected error and unchanged logical input for all five
  invalid epsilon classes. AES500-097 later records bounded tensor/weight
  IEEE behavior; wider finite overflow/underflow policy remains open.
- [x] AES500-095 RMSNorm unit evidence: `compute.rmsnorm_reference` independently
  computes scalar F32 normalization for two rows at widths 3, 15, 16, 17, and
  33, then requires exact final F16 values. The passing corpus is deterministic
  and does not establish a general tolerance or exceptional-value policy. Full
master suite: 196 passed, 0 failed, 1 skipped, 197 total.
- [x] AES500-096 RMSNorm integration: `inference.rmsnorm_integration` checks
  deterministic `forward_pass` output normalization, selected token, restored
  arena offset on success and rejection, and propagation of a short output-
  weight and non-finite epsilon errors. Final output RMSNorm errors now restore
  temporary activation and convenience-overload KV-cache allocations. The
  existing transformer forward case still exercises block consumers; no
  model-quality claim is introduced.
- [x] AES500-097 RMSNorm adversarial evidence: `compute.rmsnorm_adversarial`
  matches scalar F32 results for F16 min-subnormal and max-finite rows and
  records tested IEEE propagation for NaN/±Inf inputs and weights. This does
  not establish wide-distribution F32 overflow/underflow behavior. Full master
  suite: 198 passed, 0 failed, 1 skipped, 199 total.
- [x] AES500-098 primary-agent review and correction: final output RMSNorm
  failures restore the caller's arena offset, including temporary cache storage
  from the convenience overload. Receipt: `docs/evidence/rmsnorm-review-2026-10-10/`.
  Independent subagent approval is unavailable in this run because agent
  creation returned `agent thread limit reached`; no independent pass is claimed.
- [x] AES500-099 documentation sync: baseline wording is anchored to its source
  commit, exact deterministic equality is kept separate from general tolerance,
  integration rollback behavior is recorded, and all new named cases appear in
  the capability ledger and interfaces. `python3 scripts/test_check_doc_drift.py`
  and `python3 scripts/check_doc_drift.py` pass.
- [x] AES500-100 local release checks: pinned Pixi/Mojo native build and
  `--help` smoke pass; full sm_89 master suite reports 198 passed, 0 failed,
  1 skipped, 199 total; both documentation checks and `git diff --check` pass.
  Exact-head hosted CI is tracked against the release receipt commit and is not
  inferred from these local results.
- [x] AES500-101 RoPE contract: `TASK_rope_edge_matrix.md` defines the CPU owner,
  input/output layout, interleaved/NeoX pair mapping, row positions, ordered
  formula, current admission checks, and theta/integer-overflow exclusions.
  `core/INTERFACE.md` now matches the actual `neox` parameter. No source changed.
- [x] AES500-102 RoPE baseline: deterministic interleaved and NeoX captures
  use Q=2x8 and K=3x4 with start_pos=5/head_dim=4; the independent scalar
  oracle matches the captured F16 outputs. The capture exposes that K's third
  row remains unchanged because both loops use Q.rows. Reproduction and limits
  are in `docs/evidence/rope-baseline-2026-10-09/README.md`.
- [x] AES500-103 RoPE interface: focused cases accept distinct Q/K head counts,
  reject invalid position/head width/column divisibility/zero rows before
  mutating either tensor, and record that zero columns are currently admitted.
  `test_rope_interface.mojo` passes; this slice makes no behavior change.
- [x] AES500-104 RoPE implementation: zero-column Q or K is rejected during
  pre-mutation admission. Q and K now rotate in independent row loops, so
  distinct row counts transform fully. The focused interface test proves K's
  third row changes when Q has only two rows.
- [x] AES500-105 RoPE unit evidence: `compute.rope_reference` compares both
  interleaved and NeoX layouts across multiple heads, distinct Q/K row counts,
  and positions 0/7 against an independent scalar F32 calculation; exact F16
  equality passes for this corpus only.
- [x] AES500-106 RoPE integration evidence: transformed K values survive
  `KVCache.append`/`get_k_slice` exactly, and the adjacent V tensor is preserved
  unchanged. Scope is one deterministic cache position and row shape.
- [x] AES500-107 RoPE adversarial evidence: theta=0 and theta=-1 are admitted
  and produce NaN in Q and K for the exercised case. This is a captured unsafe
  behavior, not a contract; NaN/Inf theta admission remains uncharacterized.
- [x] AES500-108 RoPE review/fix: theta=0, negative, NaN, +Inf, and -Inf now
  reject with a finite-positive error before Q/K mutation. The adversarial test
  snapshots both tensors and verifies rejection for all five classes.
- [x] AES500-109 RoPE documentation sync: task and interface now describe the
  current positive-row/column, finite-positive-theta boundary, independent Q/K
  row loops, and historical AES500-102/107 defects alongside remaining
  overflow/pointer limits.
- [x] AES500-110 RoPE release gate: sm_89 native build and `--help` smoke pass;
  master suite passes 202, zero fail, one skip (203 total); doc-drift and
  whitespace checks pass. The theta adversarial test runs last to avoid a
  reproducible Mojo 1.0.0 same-process crash when later filesystem-heavy tests
  follow its caught-error path. Hosted exact-head CI remains to be verified.
- [x] AES500-111 causal attention contract: `TASK_causal_attention_reference_suite.md`
  defines inclusive prefix semantics, shape and arithmetic expectations, and
  identifies the current missing future-position mask. No source changed.
- [x] AES500-112 causal attention baseline: deterministic 3-row/2-head capture
  differs from causal scalar F16 output at 10/12 values (max error 12.671875)
  and is far closer to the all-row oracle. Reproduction, hashes, raw capture,
  and oracle are in `docs/evidence/causal-attention-baseline-2026-10-10/`.
- [x] AES500-113 attention interface: `compute.attention_interface` verifies a
  valid multi-head call and mutation-free output rejection for invalid sequence
  and head dimensions, Q divisibility, K/V/output columns, and each short-row
  descriptor.
- [x] AES500-114 causal attention implementation: the tiled key loop now ends
  at `i+1`, admitting only positions `0..i`. The retained probe now emits the
  first value row unchanged for query row 0, as required by its single-key
  causal prefix.
- [x] AES500-115 causal attention unit evidence: width-3 tail computation is
  compared with an independent scalar F32 `[0,i]` oracle at 0.05 absolute F16
  error; row 0 is exact and the test repeats with +100 future-row values.
- [x] AES500-116 causal attention integration: two appended KV-cache rows feed
  active K/V slices into the attention kernel; row 0 equals the first cached V
  exactly, while row 1 consumes its two-position causal prefix.
- [x] AES500-117 causal attention adversarial evidence: sequence 33 crosses the
  32-key tile edge; a position-32 value of 1024 leaves row 31 at exactly 2 and
  enters row 32's average within 0.1 absolute error.
- [x] AES500-118 causal attention review: primary review reconciles causal mask,
  baseline, interface, scalar, cache, and tile-boundary evidence. F16 partial
  output rounding and pointer/index safety remain open. Agent service hit its
  thread cap, so no independent subagent pass is claimed; see review receipt.
- [x] AES500-119 causal attention documentation sync: task/interface and
  AES-CPU-005 ledger entry describe implemented inclusive causal prefixes and
  link bounded scalar/cache/tile evidence without broad numeric or safety claims.
- [x] AES500-120 causal attention release gate: sm_89 build and `--help` smoke
  pass; master suite reports 206 passed, 0 failed, 1 skipped (207 total); docs
  consistency and whitespace checks pass. Hosted exact-head CI is checked after
  this receipt is pushed.
- [x] AES500-121 GGUF header version contract: `TASK_gguf_header_version_matrix.md`
  defines the 24-byte little-endian header and v3-only admission across file
  and byte-buffer owners, noting the byte helper's current version-check gap.
- [x] AES500-122 GGUF header baseline: raw-header helper accepts 0, 1, 2, 3,
  4, and UInt32::MAX. Mapped `_parse_header` v3-only behavior is source-only
  evidence. Raw output, reproduction, and hashes are retained in
  `docs/evidence/gguf-header-version-baseline-2026-10-10/`.
- [x] AES500-123 GGUF header interface: `gguf.version_interface` writes minimal
  mapped headers and exercises raw bytes for 0/2/3/4/UInt32::MAX. It asserts
  the current raw-helper acceptance versus mapped v3-only rejection and cleans
  its temporary files.
- [x] AES500-124 GGUF header implementation: `parse_header_bytes` now decodes
  the little-endian version and rejects non-3 values with the mapped path's
  diagnostic. The interface case requires both paths to agree on the v3 matrix.
- [x] AES500-125 GGUF version unit evidence: tests cover 24-byte valid v3,
  23-byte truncation, malformed magic, v4 rejection, stable diagnostics, and
  unchanged input bytes after rejection.
- [x] AES500-126 GGUF version integration: minimal mapped v3 passes the version
  gate and fails later on absent metadata; v4 fails at the version gate. Both
  `inspect_metadata` paths end `FAILED` with mappings cleaned up.
- [x] AES500-127 GGUF adversarial header counts: oversized UInt64 tensor and
  metadata counts in a 24-byte v3 file reject at the file-size gate and leave
  failed loader state unmapped; registered as `gguf.header_adversarial`.
  Focused and master checks pass (210 passed, 0 failed, 1 skipped / 211 total);
  docs consistency and whitespace checks pass.
- [x] AES500-128 GGUF primary Auditor pass: source confirms both UInt64 count
  comparisons precede `Int` conversion and entry loops; test checks FAILED
  state and mmap cleanup. Independent Auditor subagent unavailable because the
  collaboration service thread limit rejected assignment; no independent pass
  is claimed. Receipt is in `TASK_gguf_header_version_matrix.md`.

- [x] AES500-129 GGUF documentation sync: task, TODO, devlog, roadmap, and
  capability ledger agree on the v3 admission matrix, the two tiny-file count
  rejection cases, local suite totals, and the explicit arithmetic/scope limits.

- [x] AES500-131 GGUF metadata type contract: `TASK_gguf_metadata_type_matrix.md`
  records scalar/string/array traversal, consumed key types, current mismatch
  fallback, implementation owners, and scope exclusions before code changes.

- [x] AES500-132 GGUF metadata type baseline: four synthetic mapped fixtures
  reproduce selected-key type mismatches being skipped with default values
  unchanged; source/tool identities, hashes, scope limits, and command are in
  `docs/evidence/gguf-metadata-type-baseline-2026-10-10/README.md`. Registered
  as `gguf.metadata_type_baseline`. Master suite: 211 passed, 0 failed, 1
  skipped (212 total); documentation consistency and whitespace checks pass.

- [x] AES500-133 GGUF metadata interface: synthetic mapped v3 harness pins
  `inspect_metadata` and verifies four mismatched selected values leave defaults
  unchanged under the current behavior. This remains green before AES500-134
  changes the contract; no public API signature changed.

- [x] AES500-134 GGUF metadata type implementation: selected known scalar/string
  keys reject a wrong value type with a key-specific diagnostic before field
  mutation; unknown keys retain generic skipping. Four focused rejection/state
  cleanup cases pass.

- [x] AES500-135 GGUF metadata type unit evidence: eight adversarial files cover
  integer, float, bool, and array declaration mismatches; diagnostics and
  FAILED/unmapped cleanup are asserted. Focused Mojo module passes.

- [x] AES500-136 GGUF metadata integration: full `mmap_and_load` rejects the
  malformed context-length type before tensor allocation, cleans loader state,
  and leaves the allocation pool offset unchanged. Focused module passes.

- [x] AES500-137 GGUF metadata adversarial evidence: invalid tokenizer-array
  element type and invalid type-13 unknown-key value reject with stable errors
  and FAILED/unmapped cleanup. Focused module passes.

- [x] AES500-138 GGUF metadata review: primary review confirms type branches,
  array-specific handling, unknown-key structural skip, and cleanup evidence.
  Independent Auditor assignment was blocked by service thread cap; no separate
  agent signoff is claimed.

- [x] AES500-139 GGUF metadata documentation sync: loader interface, task
  matrix, roadmap, TODO, devlog, and evidence agree on selected-key types,
  dedicated array validation, unknown-key traversal, suite count, and limits.

- [x] AES500-140 GGUF metadata type release gate: native sm_89 build/help and
  master suite pass (212 passed, 0 failed, 1 skipped / 213 total); docs and
  whitespace checks pass. Pushed; hosted exact-head runs remain in progress.

- [x] AES500-141 GGUF tensor directory contract: `TASK_gguf_tensor_directory.md`
  specifies record layout, rank and dimensions, alignment/range gates, mapping
  modes, required tensor checks, parser owners, and explicit safety exclusions.

- [x] AES500-142 GGUF tensor-directory baseline: generated rank-one 1x1 F16
  tensor maps before the incomplete fixture fails required-tensor validation;
  source/tool hashes, command, and limits are in the baseline evidence README.
  Registered as `gguf.tensor_directory_baseline`. Master suite: 213 passed,
  0 failed, 1 skipped / 214 total; docs and whitespace checks pass.

- [x] AES500-143 GGUF tensor directory interface: rank-1/rank-2 positive shapes
  reach mapping; rank-3 and zero dimensions reject before tensor map mutation.
  Failure cleanup is asserted; registered `gguf.tensor_directory_interface`.

- [x] AES500-144 GGUF tensor arithmetic: dimension conversion, element product,
  supported byte-size multiplications, absolute data offset and F32 pool bound
  now use checked/subtraction-based guards. Native build and focused GGUF module
  pass; block divisibility/layout coverage remains separate.

- [x] AES500-145 GGUF tensor arithmetic unit evidence: hostile UInt64 dimension,
  element product, F16 byte size, and aligned absolute offset all reject before
  tensor-map mutation with cleanup. Focused module passes; registered as
  `gguf.tensor_directory_adversarial`.

- [x] AES500-146 GGUF tensor integration: 1x1 F32 fixture maps and consumes
  exactly one pool element before later model completeness rejection; cleanup
  is asserted. Registered as `gguf.tensor_directory_integration`.

- [x] AES500-147 GGUF pool adversarial evidence: two-element F32 conversion
  against one available pool element rejects without descriptor or pool mutation,
  then closes mapping. Registered `gguf.tensor_directory_pool_adversarial`.

- [x] AES500-148 GGUF tensor directory review: primary review reconciles host
  arithmetic guards, mapping/pool order, and synthetic evidence limits.
  Independent Auditor unavailable at service thread cap; no separate approval
  claimed.

- [x] AES500-149 tensor-directory documentation sync: loader interface and
  task/roadmap/TODO/devlog agree on accepted ranks, mapping modes, checked
  arithmetic, F32 pool admission, evidence, and remaining unsupported cases.

- [x] AES500-150 GGUF tensor-directory release gate: native build/help,
  master suite (217 passed, 0 failed, 1 skipped / 218 total), docs, and
  whitespace checks pass. Recent hosted runs remain in progress.

- [x] AES500-151 byte BPE merge-vector contract: `TASK_byte_bpe_merge_vectors.md`
  records owners, score-priority merge order, earliest tie behavior, space marker
  normalization, UTF-8 symbols, byte fallback, and exclusions before edits.

- [x] AES500-152 byte BPE baseline: deterministic tie/ranking/chaining and
  exact emoji fallback IDs are captured with source/tool hashes; master suite
  passes 218/0/1 (219 total). Evidence is in the baseline README.

- [x] AES500-153 byte BPE interface: public `add_token`/`encode` emits exact
  merged ID and empty no-BOS input emits no tokens; master suite 219/0/1
  (220 total).

- [x] AES500-154 byte BPE merge implementation: explicit stable leftmost
  tie comparator preserves exact baseline vectors; master suite 219/0/1
  (220 total).

- [x] AES500-155 byte BPE unit evidence: repeated tie is deterministic and
  incomplete UTF-8 byte vocabulary falls back per byte to unknown ID; master
  suite 220/0/1 (221 total).

- [x] AES500-156 byte BPE integration: RuneWeaver fallback IDs pass through
  vocabulary spellings into RuneStreamDecoder and reconstruct exact emoji;
  master suite 221/0/1 (222 total).

- [x] AES500-157 byte BPE adversarial evidence: negative-score ranking and
  negative tie behavior match the contract; master suite 222/0/1 (223 total).

- [x] AES500-158 byte BPE review: primary review confirms score/tie behavior,
  chaining, fallback and integration vectors. Independent Auditor unavailable
  at service thread cap; no independent signoff claimed.

- [x] AES500-159 byte BPE documentation sync: loader interface, task, roadmap,
  TODO and devlog agree on merge and fallback behavior and evidence limits.

- [x] AES500-160 byte BPE release gate: native build/help, master 222/0/1
  (223 total), documentation and whitespace checks pass; recent hosted runs
  remain in progress.

- [x] AES500-161 Unicode normalization contract: `TASK_unicode_normalization_policy.md`
  defines preservation, ASCII-space marker behavior, owning path, and explicit
  Unicode/malformed-input scope limits before edits.

- [x] AES500-162 Unicode baseline: composed/decomposed canonical forms retain
  distinct exact byte-token vectors; source/tool hashes and limits are recorded.
  Master suite 223/0/1 (224 total).

- [x] AES500-163 Unicode interface: public encode confirms vocabulary-driven
  `▁` rewriting and literal-space preservation otherwise; master suite 224/0/1
  (225 total).

- [x] AES500-164 Unicode policy implementation: `_initial_pieces` documents
  code-point preservation and ASCII-space-only rewriting; master suite 224/0/1
  (225 total) confirms unchanged vectors.

- [x] AES500-166 Unicode integration: composed and decomposed strings encode
  and stream-decode to their exact original forms; master suite 225/0/1
  (226 total).

- [x] AES500-167 Unicode adversarial case: NBSP remains distinct from ASCII
  space marker; master suite 226/0/1 (227 total).

- [x] AES500-168 Unicode review: primary review reconciles preserve/no-normalize
  policy, ASCII-space-only rewrite and vectors. Independent Auditor unavailable
  at service thread cap; no independent pass claimed.

- [x] AES500-169 Unicode docs sync: loader interface and project records align
  on canonical preservation, ASCII-space rewrite, evidence, and exclusions.

- [x] AES500-170 Unicode release gate: native build/help, master 226/0/1
  (227 total), docs and whitespace checks pass; hosted runs remain in progress.

- [x] AES500-171 invalid UTF-8 contract: `TASK_invalid_utf8_policy.md` records
  String-only input, current width heuristic, malformed-byte gap, desired fail-closed
  policy, and exclusions before behavior changes.

- [x] AES500-172 invalid UTF-8 baseline: unsafe truncated/invalid byte Strings
  preserve bytes through raw/fallback outputs; source/tool hashes and safe-API
  caveat recorded. Master suite 227/0/1 (228 total).

- [x] AES500-173 invalid UTF-8 interface: pins non-raising `encode(String) ->
  List[Int]` and fail-closed unknown-ID behavior with optional enabled BOS; safe
  valid input behavior remains the compatibility boundary.

- [x] AES500-174 invalid UTF-8 implementation: strict scalar/continuation checks
  fail closed to unknown ID, preserving optional BOS and valid input path; master
  suite 227/0/1 (228 total).

- [x] AES500-175 UTF-8 boundary evidence: isolated continuation, 3/4-byte
  overlong encodings and illegal lead reject; U+10FFFF remains accepted. Master
  suite 228/0/1 (229 total).

- [x] AES500-176 invalid UTF-8 integration: rejected malformed bytes enter
  stream decoding only as one `<unk>` token; master suite 229/0/1 (230 total).

- [x] AES500-177 invalid UTF-8 adversarial sweep: all 128 isolated high-byte
  values fail closed to one unknown ID; master suite 230/0/1 (231 total).

- [x] AES500-178 invalid UTF-8 review: primary review confirms scalar/continuation
  constraints and fail-closed output. Independent Auditor unavailable at service
  thread cap; no agent signoff claimed.

- [x] AES500-179 invalid UTF-8 documentation sync: loader interface and project
  records agree on pre-tokenization validation, unknown/BOS result, tested edges,
  and unsafe-input limits.

- [x] AES500-180 invalid UTF-8 release gate: CI-targeted native CLI build and
  binary help pass; master suite 230/0/1 (231 total); documentation drift and
  whitespace checks pass. Hosted Actions for pre-commit head 2d57f5e remained
  in progress at verification time.

- [x] AES500-181 greedy tie contract: finite equal maxima choose the lowest
  token ID; CPU/CUDA non-finite and suppression differences remain explicit.
- [x] AES500-182 greedy tie baseline: pinned Mojo 1.0.0 CPU executable returns
  token 1 for equal maxima at IDs 1, 2, and 4; source hashes and CUDA source-only
  evidence are recorded.
- [x] AES500-183/184 greedy tie interface and implementation: contracts are
  explicit, and both existing selectors already implement the selected rule.
- [x] AES500-185 greedy tie unit evidence: tied and unique maxima pass in the
  master suite, now 231 passed, zero failed, one skipped (232 total).
- [x] AES500-186/187 greedy tie integration and adversarial evidence: CPU path
  passes; CUDA physical probe failed PTX JIT (`CUDA_ERROR_INVALID_PTX`) and is
  not claimed. First/middle/final tie matrix passes; master 232/0/1 (233 total).
- [x] AES500-188/189 primary review and documentation sync: source tie rule and
  CPU/CUDA evidence boundary recorded; independent Auditor unavailable at
  thread cap and not claimed.
- [x] AES500-190 greedy tie release gate: pinned CLI build/help, master 232/0/1
  (233 total), docs tests, drift and whitespace pass. CUDA physical probe remains
  blocked by PTX JIT invalid PTX; no hardware tie result claimed.
- [x] AES500-191 temperature-distribution contract and AES500-192 baseline:
  CPU/CUDA owners and distinct PRNG/filter contracts recorded with source hashes.
- [x] AES500-193/194 temperature interface and implementation: formula and
  order documented; existing CPU sampler already matches the chosen contract.
- [x] AES500-195 temperature oracle: 4,096 paired seeds at T=0.5/1.0 agree
  with analytic softmax within 0.025 and higher temperature flattens mass;
  master suite 233/0/1 (234 total).
- [x] AES500-196/197 temperature integration/adversarial: validated config
  returns an in-range token; negative T rejects, extreme finite F16 selects max,
  and NaN sanitization remains in-range. Master 235/0/1 (236 total).
- [x] AES500-198/199 primary review and docs sync: formula, tolerances, engine
  limits, no-calibration claim, and CUDA PTX JIT failure recorded. Independent
  Auditor unavailable at thread cap; no independent review claimed.
- [x] AES500-200 temperature release gate: CI-targeted CLI build/help, master
  235/0/1 (236 total), docs tests, drift and whitespace pass; CUDA JIT limitation
  remains explicit.
- [x] AES500-201/202 top-k contract and baseline: CPU helper boundaries and
  stable ties separated from CUDA public 1..256 validation and lower-ID ties;
  hashes and physical CUDA limitation recorded.
- [x] AES500-203/204 top-k interface and implementation: core contract synced;
  existing behavior matches, with no algorithm change needed.
- [x] AES500-205 top-k boundary tests: empty, k=0/1/n/>n, tied maxima, and
  stable cutoff pass; master suite 236/0/1 (237 total).
- [x] AES500-206/207 top-k integration/adversarial tests: top_k=1 suppression
  path, singleton, max k=256, rejected zero, and dense tie cutoff pass; master
  suite 238/0/1 (239 total).
- [x] AES500-208/209 primary review and docs sync: CPU/CUDA-specific tie rules
  and physical CUDA PTX failure stated; Auditor unavailable at thread cap.
- [x] AES500-210 top-k release gate: pinned CLI build/help, master 238/0/1
  (239 total), docs tests, drift and whitespace pass; remote and hosted CI
  checked after push.
