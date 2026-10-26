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
- [x] AES-NUM-006 slice4.6 Track R R2 SoC session readiness
  study (+F1 readback question):R2 ESTABLISHED at source
  level — NO wire-level readiness signal exists in any pinned
  session implementation;readiness is a per-transport LOCAL
  queue-admission rule (INTEGRATED/ETH → OsSession, size
  ignored, wait_for_enqueue_ready; PCIe contrast is
  size-sensitive — cross-transport inference forbidden);
  size arrives via the preceding RPC message; one async
  transfer of the total size, 10s default timeout. Firmware
  transfer cap below the session layer NOT PROVEN. F1:a
  program-result readback path IS described @pin (client
  registers read_buffers; read after success reply, before
  callback; configured-infer-model client builds them from
  output bindings) but remains UNQUALIFIED in Aesir. Layers
  4/7 re-graded by addendum;4.4 gate re-run on changed
  layers only:PASS. Campaign4 exit NOT met.
  `docs/HAILO10H_SOC_SESSION_READINESS_STUDY_2026-10-24.md`.
- [x] AES-NUM-007 slice4.7 Track R R3 placement counts and
  safe assignment values study:NOT PROVEN on both parts —
  no searched source states the Hailo-10H's cluster/
  subcluster/APU/aligner/bank counts, and none establishes
  any cluster index, packed LCU id, active_* bitmap pattern
  or L2/L3 offset as safe for a real program. The pinned
  placement-owning header (context_switch_defs.h @pin, read
  in full) contains NO count define; widths confirmed as
  group B only (packed id 4-bit unit + 3-bit cluster = 128
  encodable combinations, encoding capacity not census;
  separate full-u8 sequencer cluster_index; sequencer_config
  bitmap widths). Ancillary literal: default LCU-enable
  kernel-done address 1 / count 2 (an R4 completion fact).
  DFC v3 place() hint recorded as a non-grading near-miss.
  Layer3 unchanged (no re-grade, no gate re-run); Campaign4
  exit NOT met.
  `docs/HAILO10H_PLACEMENT_VALUES_STUDY_2026-10-24.md`.
- [x] AES-NUM-008 slice4.8 Track R R4 action sequencing
  study:PARTIALLY ESTABLISHED — the ordering discipline is
  ESTABLISHED at source level (pinned configure path,
  resource_manager_builder.cpp @pin:fetch insertion per
  WriteDataCcw with its total_ccw_burst;edge activation
  before the single TriggerNewData group,outputs→DDR
  inputs→inputs;config-channel activate/deactivate wrap
  per config buffer;repeated-action compression;end-of-
  context terms last;context build order activation→
  batch-switching→preliminary→dynamics — build order NOT
  execution order,device execution order NOT PROVEN).
  Counts/addresses established as functions + the default
  literal (kernel-done address 1 / count 2 lands from 4.7);
  no safe non-default completion address (NOT PROVEN).
  A minimal AUTHORABLE sequence is NOT PROVEN:the base
  list is HEF-parsed (hef/core_op_metadata.cpp @pin),
  DFC-authored,blocked by R1+R3. F1 unchanged (path stays
  unqualified;layer7 not re-graded). Layer6 re-graded by
  addendum (discipline in,base list out — stays
  INCOMPLETE);4.4 gate re-run on layer6 only:PASS.
  Campaign4 exit NOT met.
  `docs/HAILO10H_ACTION_SEQUENCING_STUDY_2026-10-24.md`.
- [x] AES-NUM-009 slice4.9 Track R R5 partial-state teardown
  study:PARTIALLY ESTABLISHED — handler-level preconditions
  ESTABLISHED at source level (pinned hailort_server.cpp +
  hrpc server/resource-manager + infer_model.cpp @pin):the
  destroy actions carry NO preconditions (destroy-infer
  checks nothing about live configured children — the tiers
  are registered independently and the configured object
  holds a shared network group,not the infer model;
  destroy-configured shuts down internally,result void-cast,
  any manager-held state;all destroy handlers reply success
  even for missing handles,while use of a destroyed handle
  fails NOT_FOUND). Partial-configure residue ESTABLISHED
  (registration precedes the reply in create-configured).
  Disconnect cleanup trigger + tier order ESTABLISHED for
  the pinned server (serve loop runs it on any request-
  handling exit);its applicability to Aesir's profile NOT
  PROVEN,and firmware consequences of out-of-order teardown
  NOT PROVEN. Layer8 re-graded by addendum (stays SPECIFIED
  host / NOT ESTABLISHED device,partial states);4.4 gate
  re-run on layer8 only:PASS. Campaign4 exit NOT met.
  `docs/HAILO10H_PARTIAL_STATE_TEARDOWN_STUDY_2026-10-24.md`.
- [x] Campaign4 iteration (Track R,dependency order):R1 done
  (NOT PROVEN,above);R2 done (ESTABLISHED,above) — slice4.6;
  R3 done (NOT PROVEN,above) — slice4.7;R4 done (PARTIAL,
  above) — slice4.8;R5 done (PARTIAL,above) — slice4.9.
  Track R study pass COMPLETE. Campaign4 exit still turns
  on R1/R3-class public evidence (CCW layout,placement
  census) no searched source contains;Campaign5 NOT
  contracted. Then broad
  ordinary UNMODIFIED source-model support100%.
- [x] AES-NUM-010 slice4.10 empirical program start (Volmarr's
  never-stop order,2026-10-24 — the study-pass endpoint above
  is a route marker,not a stop):HEF corpus inventory (one
  real MiniLM HEF + twister workshop sources in reach) and
  first wire-level static map (header 56 B,arch 103 observed
  in a real artifact,6,183 regions,weights/config separation
  mapped;CCW sits in small structured fields,not a blob).
  `docs/HAILO10H_HEF_CORPUS_INVENTORY_2026-10-24.md`.
- [x] AES-NUM-011 slice4.11 schema-guided CCW isolation
  (hef.proto fetched at the pin — the twister forks are
  driver trees,holding no proto):ALL 1,605 configuration
  actions in the MiniLM HEF are pointer-form;9,832,200
  referenced bytes on channels 0/1/2;modal burst 24 B =
  3 CCW words in sequential twin streams. Offset base and
  word meanings open by design.
  `docs/HAILO10H_CCW_ISOLATION_MINILM_2026-10-24.md`.
- [x] AES-NUM-012 slice4.12 offset base RESOLVED (pinned
  hef.cpp:offsets are CCWS-section-relative,zero = header +
  proto + padding;numeric consistency vs the artifact
  verified) + differential design (same-family pair,one
  declared parameter;fall-back = intra-artifact layer-block
  differential).
  `docs/HAILO10H_OFFSET_BASE_AND_DIFFERENTIAL_DESIGN_2026-10-24.md`.
- [x] AES-NUM-013 slice4.13 zero point CONFIRMED empirically
  (57,344:header decode + source formula + lane-structure
  emergence,three-way agreement) + burst lane structure
  (lane0 header word x132/153;6 aligned contexts at
  57/57/56/58/56/59 small bursts;lanes1-2 packed operands).
  `docs/HAILO10H_ZERO_POINT_AND_BURST_STRUCTURE_2026-10-24.md`.
- [x] AES-NUM-014 slice4.14 census hunt:driver trees hold
  NO census constants (transport corpus class exhausted,
  principled negative) — but the MiniLM artifact's 286 LCU
  triggers measure an addressing floor of >=5 clusters x
  >=16 LCUs (indices 0-4 / 0-15).
  `docs/HAILO10H_CENSUS_HUNT_AND_ADDRESSING_FLOOR_2026-10-24.md`.
- [x] AES-NUM-015 slice4.15 pair acquisition:the hailo-
  ollama store is FOUND (six HEF blobs,12 GB,corpus
  1 -> 7 artifacts) + cross-artifact differential (two
  GenAI HEFs walked by an mmap walker whose MiniLM
  control reproduces -011/013/014 exactly):lane0's
  dominant header word is the same across three network
  families;lane2 is a <=3-byte field (bytes3-7 all-zero
  in 9,757 bursts);per-context lane comparison done
  (lane0 fixed at 17/24 aligned positions);census
  floor not raised.
  `docs/HAILO10H_PAIR_ACQUISITION_AND_CROSS_ARTIFACT_DIFFERENTIAL_2026-10-24.md`.
- [x] AES-NUM-016 slice4.16 full-corpus walk (remaining
  four ollama blobs):lane0 champion universal across all
  7 artifacts (86-97%);lane2 <=3-byte law zero exceptions
  in 25,758 bursts;census floor unmoved at scale (5x16
  leading candidate).
  `docs/HAILO10H_FULL_CORPUS_WALK_2026-10-24.md`.
- [x] AES-NUM-017 slice4.17 lane-1 structure hunt:lane1 =
  flags + enum{0,0x1000,0x2000,0x2001} + const 0x0250 +
  address ladder (stride 0x200);lane2 = 24-bit datum with
  per-network constants repeated once per context.
  `docs/HAILO10H_LANE1_STRUCTURE_HUNT_2026-10-24.md`.
- [x] AES-NUM-018 slice4.18 ladder/datum/non-champion:
  ladder = fixed slot set (5 rungs 0x10f0-0x18f0 stride
  0x200 + special 0x2d80,2/context,same in both
  artifacts);datum top pair identical at u24 across both
  networks (shared pool,38/62 overlap;float reading
  excluded,identity NOT PROVEN);non-champion lane0
  classes 0x28xx/0x08xx carry data-class lane1 (champion
  anatomy does not transfer) but keep the lane2 width
  law;enum refined to class x low-bit.
  `docs/HAILO10H_LADDER_DATUM_NONCHAMPION_2026-10-24.md`.
- [x] AES-NUM-019 slice4.19 special-slot/datum-pool/
  0x08xx:0x2d80 = fixed pair at skeleton indices
  10-11 of the 22-burst unit,carrying the two datum
  constants one each;datum pool = graded shared pool
  (union 1,189 u24,30 in all 7 artifacts,top pair
  repeats exactly context-count times everywhere,
  MiniLM zero private values;identity NOT PROVEN);
  0x08xx = structured minority (lane0 const 0xbff8,
  no 0x0250/ladder,lane2 law holds;data-like in
  MiniLM,low-entropy in the blob).
  `docs/HAILO10H_SPECIAL_SLOT_DATUM_POOL_08XX_2026-10-24.md`.
- [x] AES-NUM-020 slice4.20 skeleton-unit/28xx/datum-id:
  ladder slot = palindrome over the 22-burst unit
  (paired rungs descend to the 0x2d80 pair at 10-11,
  ascend in mirror;blob second half rigid,first half
  varies between sister units);datum = per-position
  operand,positions 10-11 the only near-constant
  bursts;0x28xx lane1 does NOT alternate across
  bursts — it replicates one u16 x4 inside the burst
  (0x7ffe x4 dominant);datum identity test NEGATIVE
  (tensor/gap triples at chance,proto-float encodings
  zero intersection) — identity NOT PROVEN.
  `docs/HAILO10H_SKELETON_UNIT_28XX_DATUM_IDENTITY_2026-10-24.md`.
- [x] AES-NUM-021 slice4.21 datum vs proto varints (route
  CLOSED — leading pair 0× in 576,769 varints);sister-unit
  co-determination (datum equality ⟺ operand equality,
  95×22, zero counterexamples);0x28xx scalar distribution
  (0x7ffe ×264, disjoint from pool).
  `docs/HAILO10H_DATUM_VARINT_PAIRDIFF_REPL28_2026-10-24.md`.
- [x] AES-NUM-022 slice4.22 codetermination corpus-wide:
  datum is a bijective context-free image of lane1
  (62↔62,417↔417,zero violations);minimal set flags+enum+
  ladder;special-pair splitter = flags bit (0x4000/0x8000
  ⟺ datum pair, complementary positions).
  `docs/HAILO10H_CODETERMINATION_BIJECTION_SPLITTER_2026-10-24.md`.
- [x] AES-NUM-023 slice4.23 closed-form hunt I:the datum
  map is GF(2)-LINEAR — zero inconsistencies over 479
  samples (~9,700 bit-constraints);ladder step XORs the
  datum by one of only 3 values in both artifacts.
  `docs/HAILO10H_DATUM_LINEARITY_PROOF_2026-10-24.md`.
- [x] AES-NUM-024 slice4.24 matrix extraction + cross-
  validation:one global GF(2)-linear map (blob-fit predicts
  MiniLM 62/62 exact;MiniLM-fit predicts blob 272/272
  in-span exact;zero wrong);combined rank 14;determined
  columns are dense mixes.
  `docs/HAILO10H_DATUM_MATRIX_XVAL_2026-10-24.md`.
- [x] AES-NUM-025 slice4.25 span growth:1,189 operand
  words,rank 16,zero inconsistencies across all 7
  artifacts;field varieties closed (flags 65,enum 5,
  ladder 7);variety ceiling ≈16 = rank (saturation
  hypothesis). `docs/HAILO10H_SPAN_SATURATION_2026-10-24.md`.
- [x] AES-NUM-026 slice4.26 encoder freeze:basis frozen
  (hailbru/ccw_datum_basis.json, canonical sha 7a1635cb…)
  + Mojo encoder (hailbru/ccw_datum.mojo);built on Mimir,
  CHECKED 1189 FAILED 0;out-of-span refuses.
  `docs/HAILO10H_ENCODER_FREEZE_2026-10-24.md`.
- [x] AES-NUM-027 slice4.27 lane0 families:61 families,
  5,699 bursts — operand→datum function + GF(2)-affine +
  width law hold in EVERY family (aggregate zeros).
  `docs/HAILO10H_LANE0_FAMILIES_CENSUS_2026-10-24.md`.
- [x] AES-NUM-028 slice4.28 corpus family census:174
  families,35,515 bursts across all 7 artifacts;function
  + affine + width laws hold in EVERY family (aggregate
  zeros);champion 1,189 keys reproduced exactly. Six
  largest non-champion families frozen
  (hailbru/ccw_family_bases.json + ccw_family_datum.mojo;
  Mimir harness CHECKED 177 FAILED 0);frozen datum
  coverage 94.6% of bursts. Stocktake: Campaign-5 may be
  contracted for the datum component only.
  `docs/HAILO10H_FAMILY_CENSUS_FREEZE_STOCKTAKE_2026-10-24.md`.
- [x] AES-NUM-029 slice4.29 census of the remaining CCW
  surface:745,849 pointer actions / 11,096,892,840 bytes
  across all 7 artifacts;inline/write/compressed forms
  ZERO everywhere;channels only 0/1/2,all sizes mult of
  8. Channel-0 carries 43,486 more 24 B bursts (champion
  42,118,width law 43,486/43,486) — total 24 B population
  79,001. Small forms <=512 B:128,787 actions,structured
  ladder,15.8% zero words;large forms weights-class.
  `docs/HAILO10H_REMAINING_CCW_SURFACE_CENSUS_2026-10-24.md`.
- [x] AES-NUM-030 slice4.30 channel-0 burst treatment:104
  families,43,486 bursts across all 7 artifacts;function
  + affine + width laws hold in EVERY family (aggregate
  zeros). Frozen family encoders predict their channel-0
  bursts exactly (51/51 distinct,0 wrong);the frozen
  champion encoder does NOT extend — channel-0 champion
  operands are disjoint from channels 1/2 (0 shared of
  1,120 vs 1,189;1 in-span,predicted correctly) and its
  own map is linear rank 27. Pooled frozen coverage
  35,192/79,001 (44.5%).
  `docs/HAILO10H_CHANNEL0_BURST_TREATMENT_2026-10-24.md`.
- [x] AES-NUM-031 slice4.31 channel-0 freezes:channel-0
  champion basis frozen linear rank 27 (1,120 pairs,0
  inc;canonical sha cfd5c488…a7bd) in
  hailbru/ccw_ch0_datum_basis.json +
  hailbru/ccw_ch0_datum.mojo;six largest channel-0
  non-champion families frozen affine (ranks 9–16,133
  pairs) in hailbru/ccw_ch0_family_bases.json +
  hailbru/ccw_ch0_family_datum.mojo. Mimir harnesses
  CHECKED 1120 + 133,FAILED 0. Channel-0 frozen
  coverage 42,627/43,486 (98.0%);pooled 76,207/79,001
  (96.5%). `docs/HAILO10H_CHANNEL0_FREEZES_2026-10-24.md`.
- [x] AES-NUM-032 slice4.32 small-form word anatomy:42
  size classes <=512 B (controls exact:128,787 actions,
  79,001 bursts);41 non-24 classes = 49,786 actions /
  1,289,731 words,33.0% all-zero words vs ZERO in all
  237,003 burst words. Three species:skeleton templates
  (72/120/416 B one segment x1,504;96 B two-word
  skeleton),framed sparse arrays (176/248/344/376/424 B),
  dense data (328 B,uniform-byte classes). 80 B walking-
  bit ladder across positions 1-8. Chunk test:champion
  heads zero chunks — small forms are NOT burst strings.
  1,340 non-24 segments shared in >=2 artifacts;pair
  5ab3537d/773470cd shares 83.5% of segments.
  `docs/HAILO10H_SMALL_FORM_WORD_ANATOMY_2026-10-24.md`.
- [x] AES-NUM-033 slice4.33 skeleton-class deep-dive:96 B
  = 2 segments in perfect p0/p11 bijection,1+1 per
  context in every artifact;80 B walking bit is
  all-or-nothing (2,219 full,0 partial),148 distinct
  end-determined segments;72/120/416 B one segment
  corpus-wide each,1 per context;all 1,504 contexts
  hold exactly the quartet {72x1,96x2,120x1,416x1}.
  `docs/HAILO10H_SKELETON_CLASS_DEEP_DIVE_2026-10-24.md`.
- [x] AES-NUM-034 slice4.34 walking-pool sharing,quartet
  ordering,002c vocabulary:pool mostly private (81/148 in
  1 artifact,none universal;sister pair shares 36);
  quartet is an end-anchored trailer — order 72/416/96/
  96/120,gaps (7,1,11,4) and end-offsets invariant in
  all 1,504 contexts;002c = fixed 19-word vocabulary,
  each word exactly once per context at rigid slots.
  `docs/HAILO10H_WALK_POOL_QUARTET_ORDER_002C_2026-10-24.md`.
- [x] AES-NUM-035 slice4.35 head census,176 B anatomy,
  trailing 28:head positions 0-3 always 24 B with
  monotonically decaying rigidity and no fixed head
  block or channel law;176 B = 4 once-per-context
  002c heads partitioning 199 segments (2 byte-fixed,
  p18 always zero,p21 segment-unique);the 28 actions
  after the quartet are a single invariant size+channel
  sequence — a fixed end block with the quartet.
  `docs/HAILO10H_HEAD_176B_TRAIL_2026-10-24.md`.
- [x] AES-NUM-036 slice4.36 end-block burst datum,
  176 B variable pools,head burst-runs:all 31,584
  trailing bursts champion-headed and PERFECTLY
  predicted by the frozen encoders (2,049/2,049
  distinct,0 wrong,0 out-of-span);t0 = the invariant
  special-slot burst;five disjoint operand pools for
  t1-t20 with no intra-context reuse;176 B pools are
  sparse frames with a unique trailer word and no
  pairwise varying-position law;head runs 4-10.
  `docs/HAILO10H_END_BLOCK_176B_HEADRUN_2026-10-24.md`.
- [x] AES-NUM-037 slice4.37 trailing pools vs global,
  176 B joint,304 B break:trailing 2,049 operands =
  1,191 shared + 858 private (t0 + five closing
  positions + remainders);champion operands are
  channel-exclusive corpus-wide (2,309);four sister
  pools per group equal-sized and disjoint;176 B
  joint block near-unique but non-determining;304 B
  breaker = one fixed sparse segment per artifact,
  sister pair never breaks at 304 B,complementary
  walking byte pair p2-p17.
  `docs/HAILO10H_TRAILING_POOL_176B_JOINT_304B_BREAK_2026-10-24.md`.
- [x] AES-NUM-038 slice4.38 sister breaks,non-breaker
  304 B,sister-pool subfields:sisters break head runs
  only at large unique data actions (215/219 >=9,336 B,
  zero shared segments);non-breaker 304 B = 11 channel-2
  singletons in two slots/anatomies;sister pools are
  exact enum relabellings (ladder = group rung,flags
  sets identical,enum sole separator).
  `docs/HAILO10H_SISTER_BREAK_NONBREAKER_304_SISTER_POOLS_2026-10-24.md`.
- [x] AES-NUM-039 slice4.39 body enum,framed 464 B,
  sister census:body rungs are exact enum relabellings
  (three classes per rung,equal pools,flags/projection
  identical and injective;exceptions = 14 invariant
  once-per-context singletons + 6 rare operands);
  framed 304 B is the tail of the 464 B form in
  0a0d378c (words 21-57,19 shared constant words),not
  kin to the 176 B/424 B frames;sister breaks are the
  rare tail of their large censuses (13/14 break sizes
  census-exhaustive;never-break sizes carry ~72.5%
  of large occurrences).
  `docs/HAILO10H_BODY_ENUM_FRAMED464_SISTER_CENSUS_2026-10-24.md`.
- [x] AES-NUM-040 slice4.40 class-channel mapping,464 B
  preamble,singleton positions:body enum class = channel
  index exactly on all five rungs;trailing fourth class
  0x4000 shares channel 0 (position slot,512 ops);
  corpus-wide enum-high values exactly {0,1,2,4,8} —
  class 3 never occurs (single-bit pattern);464 B
  preamble is a constant 21-word header sharing only
  zero + two generic markers with the framed 304 B form;
  12 of 14 invariant singletons are end-anchored at fixed
  from-end offsets in one invariant order (two inside the
  trailing head),the 0x2d80 pair roams in the body.
  `docs/HAILO10H_CLASS_CHANNEL_464PREAMBLE_SINGLETONS_2026-10-24.md`.
- [x] AES-NUM-041 slice4.41 non-champion enum test,0x2d80
  pair burst ordinal,cc9b9d1c 464 B:the champion enum-bit /
  class = channel law does NOT transfer (non-champion slot
  takes all values 0-8,7 dominant at 48.6% of bursts,class
  matches channel in only 6.3%);the 0x2d80 pair is adjacent
  in champion burst ordinal in 94.9% of contexts (ordinals
  15/16),exceptions = two fixed patterns (12->16 x39,
  16->14 x28) concentrated in 76c3a8ff/0a0d378c;cc9b9d1c
  464 B is one template with a per-segment parameter byte
  (0xb0/0x64/0x70/0xf8;0x72 in 0a0d378c,0x46 in 0856a10c),
  sharing only six generic constants with the 0a0d378c
  preamble and embedding no 304 B tail.
  `docs/HAILO10H_NONCHAMPION_ENUM_PAIR464_2026-10-24.md`.
- [x] AES-NUM-042 slice4.42 displaced-pair gap contents,
  cc9b9d1c parameter recurrence,high-7 vs pointer offset:
  gap bursts are the contexts' own ladder rungs in fixed
  enum = channel forms (displacement = reordering,no
  inserted block,totals unchanged);the 464 B parameter
  recurs in the 232-360 B classes under a denser slot
  pattern [1..12,evens] while at data scale the values
  are ordinary payload;the high-7 operand is NOT an
  address field (no formula,no monotonicity,one
  indivisible co-varying unit per family).
  `docs/HAILO10H_DISPLACED_GAP_PARAM_HIGH7_2026-10-24.md`.
- [x] AES-NUM-043 slice4.43 232-360 B parameter-family
  template anatomy vs the 464 B form;high-7 function +
  affine test;displaced contexts outside the pair
  region: the family is one construction across
  232-464 B (exact dense slot pattern [1..12,evens to
  words-5];head byte 6 <-> parameter bijection over
  all 12 segments;parameter+1 slot word in both
  vocabularies) sharing no substantive constant word
  (intersection = zero + 0100000000000000 only);the
  high-7 datum map is a per-family GF(2)-affine
  function,zero violations in all 68 families,and is
  NOT an operand-only function (the family is part of
  the key);displaced contexts are a periodically
  placed low-action context type (private head,
  standard tail,actions 85-123 vs adjacent minima
  232-280).
  `docs/HAILO10H_PARAM_TEMPLATE_HIGH7_FUNCTION_DISPLACED_TYPE_2026-10-24.md`.
- [x] AES-NUM-044 slice4.44 low-action context class
  census;parameter+1 slot census;336-action outlier
  anatomy: the low-action class is 79 contexts at
  <=150 actions (75 displaced + 4 adjacent) separated
  by empty gaps of 115-157,skeleton + trailer
  complete,data body nearly removed;the parameter+1
  marker is universal — exactly one (X+1) word at
  word (words-3) in 210/212 dense-skeleton segments
  (71 distinct X) and all 20 family segments (0856a10c
  in the 0200 shape);the 336-action outlier is a
  standard context whose pair straddles the
  rare-ladder pair in a local anomaly zone at
  76c3a8ff cidx 105-106.
  `docs/HAILO10H_LOW_ACTION_CENSUS_PARAMPLUS1_OUTLIER_2026-10-24.md`.
- [x] Slice4.45 marker-word anatomy,pair-order census,
  anomaly zones,intermediate class: the marker is a
  closed-form function of the preceding strict word
  (byte2 +1,byte4 -4 small / +16 at 464 B) and the law
  is 212/212 under modal X;pair order is a balanced
  two-state variable (693/735) at fixed ordinals with
  no measured correlate;76c3a8ff holds TWO mirrored
  rare-ladder zones (97-98,105-106);the intermediate
  class is exact (156 x26 at 111+9k,173 x2 at 94/102,
  two middle species).
  `docs/HAILO10H_MARKER_FUNCTION_PAIR_ORDER_ANOMALY_ZONES_2026-10-24.md`.
- [x] Slice4.46 freeze the marker derivation as an
  Aesir-side encoder rule + host-test against all 212
  dense segments and the 20 family segments (incl.
  the 0856a10c 0200 shape):`hailbru/ccw_marker.mojo`
  (copy,byte2 +1,byte4 -4 small / +16 at 464 B,form 2
  sets byte0 02),segment rule check 220/220 and the
  on-device Mojo harness CHECKED 78 FAILED 0 over the
  distinct triples.Contract scope was the freeze only
  (TASK_hailo10h_marker_encoder_2026-10-25.md).
  `docs/HAILO10H_MARKER_ENCODER_FREEZE_2026-10-24.md`.
- [x] Slice4.47 pair-order determination hunt;zone-pair
  body comparison;156 middle motif anatomy: order is
  NOT a function of the champion operand sequence
  (0856a10c cidx 15/27/39 share the identical non-pair
  champion stream and pair datums yet take both orders;
  headseq accuracy 0.9993 is a proxy,not a law);the
  five post-pair bursts are one universal coda;zone
  pairs share only the skeleton tail outside the
  rare/pair region;the 156 middle is a 12-block motif
  (3856 x12 per context) with private payloads (1,924
  distinct segments / 2,288 occurrences,8 universal
  pre-motif positions) — correcting the 4.45 unit
  wording.
  `docs/HAILO10H_PAIR_ORDER_ZONE_BODY_156_MOTIF_2026-10-24.md`.
- [x] Slice4.48 pair-order vs body datum sequence:
  datum stream does NOT determine order either (the
  0856a10c triple's non-pair datum streams are
  byte-identical;only datum diff is the pair swap
  itself);head-level combined keys still fail on
  the triple;full-stream separations are uniqueness/
  tautology,not laws;motif variants are positional
  (block0 no-30480 + block4 no-32784 in 26/26;
  channel tuples an exact per-index law;leads
  private,82 values 8104-8832 all mult of 8);rare
  bursts 15/15 EXACT under the frozen champion maps
  (body champion control 43,631/43,631 exact).
  `docs/HAILO10H_DATUM_ORDER_MOTIF_RARE_2026-10-24.md`.
- [x] Slice4.49 pair-order vs middle action stream:
  no tested middle feature determines order (channel
  counts strongest at 0.9979 yet carry two real
  mixed groups in 0856a10c;combined separations
  with nopair_op are single-counterexample
  artefacts,not laws);motif leads are NOT copies
  of own contexts' sizes (0/312 on every arm;band
  actions inside 156 contexts are exactly the 312
  leads;values are shared vocabulary,16,105 in
  standard middles);variant forms are generic in
  standard middles (20,411 windows:full 14.6% /
  no30480 22.7% / no32784 4.3% / other 58.4%,at
  scattered ordinals) — the motif's distinction is
  fixed-ordinal pinning at blocks 0 and 4.
  `docs/HAILO10H_MIDDLE_STREAM_LEAD_EXCLUSIVITY_VARIANTS_2026-10-24.md`.
- [x] Slice4.50 pair-order vs middle channel
  sequence:the bit IS a function of the channel
  sequence's GLOBAL forms (run-order alone:438
  keys,129 multi groups / 1,119 ctx,0 mixed;
  transitions/full seq/last-20/first-40-runs the
  same) — the first stream to pass the function
  test;every local form fails (prefixes <=100,
  strides,run prefixes <=20;first-50's one mixed
  group is a periodic 0a0d378c stack);lead-band
  role is corpus-wide (64.2% of standard band
  actions lead a 3856 window vs 3.18% base;50.6%
  of all standard windows band-led;band middle-
  only 16,105/7/0);no variant-ordinal
  concentration in the 311 >=12-3856 contexts
  (no variant class >=0.90 at any ordinal 0-30;
  the motif's double pin occurs once,76c3a8ff
  cidx 4).
  `docs/HAILO10H_CHANNEL_SEQ_BAND_ROLE_VARIANT_CONCENTRATION_2026-10-24.md`.
- [x] Slice4.51 channel-separation emergence:
  exact thresholds all zero-mixed (35 channel runs /
  34 full runs / last 18 channels / last-runs in
  16-20 / first 122 channels);from run-prefix 22
  the only mixed group corpus-wide is the 0a0d378c
  stack,which splits at ONE channel-0 vs channel-2
  divergence at middle position 121 (228 differing
  positions vs every normal;rev = unique sequence);
  band non-3856 followers are 49.4% two forms —
  the FIXED 8208->4112->3088->32784 chain (673/672/
  597 of 683) and the scattered 3856-avoiding 4368
  continuation (never followed directly by 3856,
  0/2,594);76c3a8ff cidx 4 is NOT a motif relative
  (its window-4 pin is led by 9216,out of band;
  windows 4-7 led by a 9168-9248 cluster).
  `docs/HAILO10H_CHANNEL_EMERGENCE_FOLLOWERS_CIDX4_2026-10-24.md`.
- [x] Slice4.52 last-runs exact emergence:
  RLE-channel last-N runs CLEAN at exactly 17
  (sole holdout through 16 = 0856a10c cidx 3 rev
  vs 25/37 nor);RLE-full last-N runs clean at
  every scanned N from 5 (threshold <=5);sister
  group resolves at run-prefix 22 via run 21's
  flip (normal (0,5) vs reversed (2,2));position-
  121 diverging action = 8208 on channel 0 (rev)
  vs ~5.5 KB on channel 2 (all 14 normals),one-
  slot phase shift (normals' own 8208 at pos 132
  ch2);8208->4112->3088 chain is SISTERS-ONLY
  (672 = 112 contexts x 6;32784 tail 0-16;
  terminators led by 29712 x375;20 full size
  sequences;segment bytes private 672/672);
  9168-9248 cluster IS a second lead ladder
  (11 step-8 values,743 windows) but concentrated
  (cc9b9d1c 688 in 19 contexts;76c3a8ff 55 in 2;
  32016 dialect behind its 3856s).
  `docs/HAILO10H_LASTRUNS_POS121_CHAIN_CLUSTER_2026-10-24.md`.
- [x] Slice4.53 cluster-context selection in
  cc9b9d1c:whole-context and band-exclusive (0 band
  leads in the 19 positives' 1,758 windows;corpus
  exclusion fails only in 76c3a8ff cidx 3/4);window
  density/size/champion/order/ng do NOT select (61
  negatives equally window-dense,0 cluster);positive
  cidx gap sequence repeats once exactly (from 14
  and from 155) without paired copies;positives'
  other leads hug the window (9160,9256-9280);
  32016 dialect = full vocabulary swap at comparable
  rhythm (32016 in 47.4% of cluster windows,multi-
  plicity to 3,30480 in 7.4%;band mirror 3.5%/76.8%);
  chain contexts = the sisters' shared 232-239-action
  class on an identical step-3 (2-80) / break (94,95)
  / step-4 (99-203) train,positions identical 54/56
  (exceptions = the break pair).
  `docs/HAILO10H_CLUSTER_SELECTION_DIALECT_CHAIN_SELECTION_2026-10-24.md`.
- [x] Slice4.54 wider lead-family census:family is
  exactly 9144-9264 (16 step-8 values,900 windows),
  exclusive to the same 19 cc9b9d1c contexts (ZERO in
  all 252 negatives) — membership does NOT re-grade,
  dose grows 688->900,edges sharp;dense negatives run
  a disjoint ladder vocabulary (94xx 0.288,low
  8960-9136 0.194,97xx 0.194,band 0.000;vocab 64 vs
  109,16 POS-only = the exclusive zone);cidx-1 edge
  member (1 ordinary core window,exclusive dose 9,
  32016 dialect full strength 96/0 — dose != dialect).
  `docs/HAILO10H_WIDER_FAMILY_DENSE_VOCAB_CIDX1_2026-10-24.md`.
- [x] Slice4.55 94xx ladder anatomy:NOT a family —
  continuous 9352-9696 ladder,no exclusive zone;
  dose bimodal (26 high carriers 45-63,10 low,235
  cc9 zero);high carriers marked by total low-ladder
  absence (0.0 vs 34.4) and speak the shared 32016
  dialect (30480 behind 94xx windows 0/1,508);97xx
  ladder is cc9-only,a fixed-dose common module
  (carriers capped at exactly 32,identical anatomy
  in both dialects);shoulder gap = ONE shoulder per
  context (9 lower-only,10 upper-only,0 both in cc9;
  gap 220/963,uncorrelated with core dose).
  `docs/HAILO10H_94XX_97XX_SHOULDER_GAP_2026-10-24.md`.
- [x] Slice4.56 shoulder-side selection:NONE of pair
  order/97xx carriage/cidx/position selects the side;
  low family dose always upper (5/5),upper always
  low-ladder-free (10/10),side runs in 8 stretches;
  dense negatives are FOUR populations (high94 25
  full-window,low94 8,zero94/low-high 16,zero94/
  low-none 12 = 93xx/89xx-led maximal all-reversed);
  97xx module clustered never one run (599 runs,
  gap-1 74.4%,canonical 21-block at ordinal 0 or
  43,exact templates x10/x8).
  `docs/HAILO10H_SHOULDER_SIDE_DENSE_SPLIT_97XX_POSITIONS_2026-10-24.md`.
- [x] Slice4.57 low-none population corpus-wide:
  form is cc9-only,21 contexts (15 maximal reversed
  + 6 reduced normal),three mutually exclusive lead
  segments 93-led 9288-9392 / 89-led 8888-8952 /
  98-led 9800-9856,spans POS/DENSE/OTHER;97xx block
  at ordinal 43 only in maximal ng0 contexts,at 0
  predominantly ng1 (11/13);shoulder stretches are
  short-gap runs (4.9 vs 23.9) and the cc9 stream
  mirrors at cidx +137 in lead sequences (72/134
  identical,POS 9/10 recurring,side 8/9 preserved);
  intervening contexts differ only in low-ladder
  dose (0.91 vs 5.29).
  `docs/HAILO10H_LOWNONE_CORPUS_97XX_PLACEMENT_STRETCHES_2026-10-24.md`.
- [x] Slice4.58 +137 lead-mirror extent corpus-wide:
  mirror RETRACTED (057's 72/134 = 60 empty==empty +
  12 trivial single-window [80] pairs;60 of 72
  both-nonempty pairs differ;no non-trivial mirror
  at any offset in any artifact;windowed contexts
  in only 3 of 7 artifacts,all-distinct outside
  cc9);reduced six are a separate grade (606-607
  acts,32016 x32,normal,3088-led,three +137 profile
  pairs with sequences differing ~90%);block0 ng0
  exceptions 54/110 are reduced-grade all-97
  contexts (31/32,32/32),their block degenerate;
  606/607 class is a step-4 rail of 55 cc9-only
  contexts (2-110,143-247).
  `docs/HAILO10H_MIRROR_EXTENT_REDUCED_SIX_BLOCK0_EXCEPTIONS_2026-10-24.md`.
- [x] Slice4.59 step-4 rail grades:seventeen window
  counts (32-96) organised as +137 pairs with
  (near-)identical family-dose profiles (the four
  TODO values are members,not the grade set);the
  all-97 quartet (50/54/110/187) is the 32-count
  grade filled by the capped 97xx module;+137
  profile recurrence over all cc9 (nwin 0.978,pop
  0.985,n32016 0.985,segment 0.978,cls97 0.843,
  order 0.769,nacts 0.582 vs baselines 0.099-0.671;
  ng flips 0/134);0856a10c/76c3a8ff windowed
  populations are band monocultures (92.8%/91.7%
  band,pools 112/139,quantised 16/24/28/140 and
  24/28/140 classes) vs cc9's mixed vocabulary.
  `docs/HAILO10H_RAIL_GRADES_137_PROFILE_WINDOWED_POPS_2026-10-24.md`.
- [x] Slice4.60 the shared 140-count class in both
  monocultures: a step-3 rail in the interleaved
  windowed head block (cidx 0-83) of both streams,
  lead pools intersecting in 58 step-8 values (two
  contiguous runs); companion CORRECTED to n30480
  at the window count (140; 139 at 0856 cidx
  7/19/31) — the n32016 x24 dose belongs to 76c3's
  24/52-count classes, not the 140 class; cidx 0-2
  differ at +137 because partners 137-139 are
  off-cycle seam uniques (137/138 windowless) before
  the second pass's shifted period-4 cycle locks in
  at 140; cidx 139 is a unique 432-action context
  whose 64 windows are all 9400-9488, lead set a
  strict subset of cidx 2's, missing its 97xx family.
  `docs/HAILO10H_SHARED140_SEAM_PAIRS_139_2026-10-24.md`.
- [x] Slice4.61 seam trio anatomy:137/138 are complete
  contexts (skeleton,trailer,champion 29,ng 1;499/507
  unique corpus-wide) built on a 96-fold triplet block
  (7952/32784/26896 x96,disjoint 6160s/6500s small
  vocabularies);0856 24-class n32016 dose = filled
  amount of a templated middle block (two full-dose
  position templates,8-dose = exact prefix,sparse
  off-template,no selector);per-window companion
  pairing REFUTED (30480 intervals irregular in all
  140-class contexts;count equality is global only;
  exceptions are a step-12 sub-rail 7/19/31);second
  pass cycle = first pass merged+shifted (738/245
  preserved,259->256 by -3x80B/-1x32784,607+606
  merged into 606 with rail head cidx 2 replaced by
  seam 139;classes 28->27,ng flips).
  `docs/HAILO10H_SEAM_TRIO_COMPANION_CYCLE2_2026-10-24.md`.
- [x] Slice4.62 triplet block anatomy:seam block is a
  FORWARD A->B->C->A rotation (0.742/0.649 forward
  share,cyclic trigram 0.587/0.467,modal gap 4,smalls
  at the C->A boundary,strict period REFUTED);0a0d
  128/160-dose blocks differ in third member (25872,
  not 26896) and run REVERSE (0.594/0.616),as does
  the true-triplet 623 class (0.769,band 5648-5704);
  sparse doses are NOT a third template (near-full =
  exact subsets 23=F3-363,22=F0-231/264,8=F0 subseq
  idx 0,1,3,5,7,8,11,12 — correcting 4.61's prefix
  wording;true sparse = per-context scatter);four
  exact full-dose templates F0-F3; interruption
  zones are one fixed 21-context non-cycle block
  written twice at +137 (identical count sequence,
  classes nowhere else in corpus),unique tails
  (244/247 singletons,186 pair),ng flip at cidx 134,
  zone2 stream-final at cidx 270.
  `docs/HAILO10H_TRIPLET_ROTATION_SPARSE_ZONES_2026-10-24.md`.
- [x] Slice4.63 rotation-direction census over the
  remaining block classes corpus-wide (0a0d 48-dose
  290 class + 80-dose 419 class,76c3a8ff tail triplet
  contexts); 186 pair + 244/247 singleton anatomy;
  cidx20 dose-14 scatter vs 32016 block slots:ONE
  rotational sense corpus-wide (anti-sorted cyclic;
  290 seam-fwd 0.664/pooled 0.622,419 0.753/0.695,
  623 0.769 — AES-NUM-062's forward/reverse split
  was a letter-assignment artefact,corrected);
  76c3 has NO triplet rotation (32784 runs + 14
  two-member 32784/26896 alternations);186 pair are
  both rotations (135 purest 0.958/0.936) but only
  97/186 positions shared;244/247 copy rotates
  cleaner (0.823 vs 0.646),+3 = 3088 smalls;cidx20
  scatter tail-clustered (5/14 in 356-367) but
  slot-free (union 7/14,per-template <=4).
  `docs/HAILO10H_ROTATION_CENSUS_186_244_SCATTER_2026-10-24.md`.
- [x] Slice4.64 two-member alternation anatomy;
  collapsed/degraded members inside 290/419/623;
  135 vs 134 at position level:76c3 B/C is the only
  genuine two-member population (dense = B-runs +
  single C separators,cross BC/CB symmetric,self
  lopsided B; sparse 776 near-1:1); all other
  two-member subsequences are projections of triplet
  rotations (99 0a0d + 171 cc9 contexts); collapse
  order fixed (32784 first,26896 second,7952 last),
  55xx band invariant, partials fill 31-32k,
  collapsed fill diverse 74xx/25xxx (distinct
  119-251 vs 46-56); 135 has one block interruption,
  134 breaks at head + tail.
  `docs/HAILO10H_TWO_MEMBER_COLLAPSED_135_134_2026-10-24.md`.
- [x] Slice4.65 small genuine two-member remnants
  (0856 B/C x5, cc9 B/C 151/203) vs 76c3 regimes;
  zero-context replacement vocabularies compared
  across classes; 134 sparse tail members vs the
  end block's bursts:remnants are NOT alternations
  (B-carrier streams with 1-4 isolated minor-member
  insertions; cc9 pair = one C head prefix + 64-B
  run); zero vocabularies are ONE shared pool (union
  389, 22 universal, ZERO private sizes, cross-class
  zero pairs to J0.774, collapsed-vs-zero <=0.208);
  134 tail sits in the body (pos 103-129 vs end
  block at 158), end block written intact after it.
  `docs/HAILO10H_REMNANTS_ZERO_VOCAB_134_TAIL_2026-10-24.md`.
- [x] Slice4.66 remnant singleton insertion positions;
  cross-class zero-pair overlap anatomy; 123-class
  A/B pattern in the alt frame: no universal insertion
  slot (two fixed head insertions — 623 collapsed BB
  pair at positions 13/17 in 4/4, cc9 C prefix at 16
  in 2/2; other 22 scattered); six J>=0.72 pairs are
  exactly the ordinal-matched state-matched 419<->623
  pairs k=1..6, overlap carried by large sizes (15
  small of 132-202), positions not preserved, diff
  one-sided (419 lacks 9-11, 623 lacks 34-49); 123
  alt = one fixed balanced 24-letter template in all
  16 contexts, corpus rotation sense degraded — a
  projection, not a new block.
  `docs/HAILO10H_INSERTION_ZERO_PAIR_ALT123_2026-10-24.md`.
- [x] Slice4.67 290-class ordinal-matching at lower
  dose; 623 extra vocabulary vs surviving triplet
  dose; scattered-singleton follower test: the train
  is three-class (state sequences identical in
  290/419/623; 290<->623 matched J 0.564-0.641 all
  above mismatched max 0.456; 290<->419 mean 0.450 vs
  control 0.197; 290 lacks exactly 8 sizes vs its 623
  twin in all six pairs, coverage 0.966); 623 extra
  vocabulary is a fixed residue, not dose debris
  (nine-size all-six core; surviving B dose constant
  at exactly 2, C at 0, A 0-73; class-wide vocab vs
  total dose -0.979 both classes); scattered-minor
  follower law is real and per-artifact (4368/3856 in
  13/22 = 59.1% vs 0/1,609 major in same contexts;
  76c3 -> 4368 7/8, 0856 -> 3856 5/14).
  `docs/HAILO10H_290_TRAIN_623_EXTRA_FOLLOWER_2026-10-24.md`.
- [x] Slice4.68 fixed 8-size 290-vs-623 difference
  (identity + recurrence); nine-size residue core
  outside collapsed/zero contexts; per-artifact
  follower identity at larger scope: the 8-size
  difference is one identical set {200x3, 360, 8576,
  13176, 13480, 14224, 20488, 32600} at fixed counts
  and first positions in all six pairs, in all 16
  290-class contexts and no 419/623 context; the
  nine-size core is a 623-class invariant (16/16,
  eight counts frozen, 32784 = B dose; eight non-B
  sizes in zero 290/419 contexts); the band follower
  does not generalise (population B adds no case;
  0a0d minors follow 2824/21408/26896, cc9's 424,
  MiniLM + sisters hold no minors).
  `docs/HAILO10H_8SIZE_RESIDUE_FOLLOWER_SCOPE_2026-10-24.md`.
- [x] Slice4.69 290 signature positions/neighbours;
  264 + 2824 companions of the 623 fixture;
  0a0d scattered-B 26896 follower mechanism: the
  signature is a fixed head template at positions
  13-27 (one order in 16/16, deterministic
  neighbours, fixed fillers 24/216, identical in
  collapsed/zero and full-dose contexts); 264 is a
  fixed slot x1 in 16/16 623 (@30, after core 1280)
  and 16/16 419 (@17), 0/16 in 290; 2824 is fixed
  @14 in 16/16 623 (after 32784, before 328), extras
  only at 213 (cidx 7, 43) and 451 (cidx 43); the
  scattered-B 26896 follower is the next seam member
  at gap 1 in 3/4 (adjacent rotation C), head-fixed
  B's take template followers (2824/21408, 0/6).
  `docs/HAILO10H_290_TEMPLATE_264_2824_SCATTERED_B_2026-10-24.md`.
- [x] Slice4.70 shared head template at positions
  0-35 across the 290/419/623 classes; extra 2824
  occurrences at 213/451 and their surroundings;
  B->C seam adjacency as a rotation diagnostic at
  corpus scope: ONE shared scaffold at 0-12 (419
  deviates at 9/12 only), THREE distinct
  single-sequence class templates at 13-28 (623
  runs to 31), then dissolution at 29 (290/419) /
  32 (623); extra 2824s are channel-normal in-band
  body occurrences (channel windows at 205-221 and
  443-459 single-valued in 16/16; cidx 7's extra
  displaces no seam member); B->C gap-1 adjacency
  is a valid pair-specific rotation diagnostic
  (95.40% corpus, 99.35% 0a0d, vs C->A 0/4,603).
  `docs/HAILO10H_HEAD_TEMPLATES_2824_EXTRAS_BC_ADJACENCY_2026-10-24.md`.
- [x] Slice4.71 channel scaffold at corpus scope;
  the A-boundary law; C->A gap distribution /
  rotation reset structure: NO artifact-scope
  scaffold (0 single-channel positions at artifact
  alignment in all 7 artifacts; 623 windows carry
  33/29 distinct channel sequences artifact-wide);
  class-scope scaffold near-total in templated
  classes (290: 290/290 positions single-channel,
  419: 417/419, 623: 613/623; channel more rigid
  than size, 0a0d classes 65.2% vs 26.0%); the
  A-boundary is marked by a 5-7k data action on
  A's own channel (99.7% / 98.99%, gap 1 into A
  0/19,064 in 0a0d+cc9); C->A reset = that marker
  alone at gap 2 in 92.6% (4,263/4,603), no fixed
  reset sequence, long gaps 11/12 cc9 step-4 rail
  only (54). `docs/HAILO10H_CHANNEL_SCAFFOLD_A_BOUNDARY_CA_RESET_2026-10-24.md`.
- [x] Slice4.72 marker action's exact size
  selection (41/58-value pools vs context /
  position / following A-B pair); channel-rigid
  classes in cc9's loose population (the
  39-window block); 763 class channel
  dissolution vs its size stream: marker pools
  are COMPLETE step-8 ladders (0a0d 5,536-5,856
  41 rungs, cc9 6,112-6,568 58 rungs, no gaps;
  C-predecessor markers in-ladder 100%) but no
  tested feature selects the rung (all function
  tests at chance; rung recurs as an ordinary
  in-context size 98.6%/84.0%) - selection NOT
  PROVEN; the 39-window block is the universal
  55-action end block (last-55 size+channel
  sequences 1 distinct per artifact; 39 =
  55-17+1) and cc9/0856 loose classes hold no
  single window outside it; 763 dissolution is
  subgroup mixing (9 channel sequences over 32
  contexts, groups 12/10/4 periodic + 6
  singletons; size single ~588/763 within
  subgroups vs 72 class-wide).
  `docs/HAILO10H_MARKER_LADDER_CC9_ENDBLOCK_763_SUBGROUPS_2026-10-24.md`.
- [x] Slice4.73 763 subgroup anatomy (subgroup
  size templates vs each other; singletons vs
  subgroups; cidx periodicity vs proto
  ordering); marker-rung distribution vs the
  contexts' own 5-7k data-action size
  distribution; 321 class's 57-action end
  region vs the universal 55: the 763 class is
  two proto-order trains (ng0 cidx 1+4k, ng1
  76+6k, 16 slots each), one size family per
  train (G10 == G4 wherever both single, split
  by 3 channel positions; S13/S37 restore G12
  to 14 slots at 1/3 channel flips; trains
  unrelated, Hamming ~465); marker rung mirrors
  the marker-bearing contexts' own band
  distribution (0a0d Pearson 0.968 / TV 0.091;
  cc9 0.868 / 0.213) — selection still NOT
  PROVEN; 321 end = universal 55 + two-action
  class fixture ((25872, ch1) 15/16, (24, ch1)
  16/16), no 56th universal action.
  `docs/HAILO10H_763_TRAINS_MARKER_DISTRIBUTION_321_END_2026-10-24.md`.
- [x] Slice4.74 proto-train census across all
  0a0d classes (strides / per-ng families /
  cross-class family relations); S76/S82
  early-train divergence in the ng1 train;
  cc9 band strays (5480, 5616, 5808, 5904,
  6880 at x2 each) and their contexts:
  0a0d is a complete residue partition (ng0
  stride-4 residues 0-3 over ngpos 0-63; ng1
  stride-6 residues 0-5 over ngpos 0-95; 763
  the only dual-group class) plus a mirrored
  ten-context tail per group with the same
  class sequence; cross-class relations are
  the universal last-55, a shared head size
  scaffold (9-13/13) with private channels,
  and 759/950 tail families shared across
  groups where jointly single (75/76, 65/65);
  S76/S82 divergence is a two-slot step at
  the ng1 train head (182 + 180 size
  exceptions / 54 + 4; slots 2-15 exact),
  confined to positions <=673/<=621; cc9's
  five strays occur exactly twice each,
  never as markers, as paired draws at band
  slots (modal rung 6160), every pair at
  cidx +137 / ngpos +3.
  `docs/HAILO10H_PROTO_TRAIN_CENSUS_S76_S82_CC9_STRAYS_2026-10-24.md`.
- [x] Slice4.75 cc9 ngpos+3 context pairing
  at artifact scope (paired contexts' slot
  values generally vs rare draws only);
  S76 diff runs as channel transforms
  (per-run flip maps vs G10); 0a0d tail
  singletons 85/92 and the 758/760/768
  cross-group mismatch: the +3 pairing is
  artifact-wide (134/134 paired; multiset
  overlap 0.9695 vs 0.60-0.64 elsewhere,
  -1 secondary 0.7689; 250/266 doubletons
  hosted by +3 pairs, zero rare sharing at
  +1/+2/+4; class map identity/-3/-1 with
  one exception; partners are
  near-permutations, positional median
  0.36); S76 is no relabelling (flip map
  non-functional) - its runs are local
  two-direction pair swaps (84.6%
  adjacent flips; two one-way 2->0 runs),
  S82 by contrast a near-pure 0<->2 swap
  (51/54); 758/760/768 mismatch is
  body-only (last 55 identical in size AND
  channel 55/55 x3; no shift repairs;
  class pairing ~ cross-class background);
  85/92 share head 12/13 + end block,
  multiset 76/85, differ by 7 actions with
  +7 channel alignment 65/85 (insertion
  NOT PROVEN).
  `docs/HAILO10H_CC9_PAIRING_S76_TRANSFORMS_TAIL_SINGLETONS_2026-10-24.md`.
- [x] Slice4.76 +3 pair order structure
  (how the ng-1 partner permutes the ng-0
  original at block/seam level; what the
  -3/-1 class deltas 259->256 / 607->606
  drop); S76 swap-run converse test (pair
  agreement inside runs); 85->92 insertion
  alignment test: the +3 permutation is
  blockwise (61.2% of matched material in
  blocks >=16, displacement median 1,
  -1 control far weaker) but does NOT
  respect seam segmentation (length
  sequences identical 0/134); the deltas
  are net effects of larger stereotyped
  swaps (259->256 common core 9-out/6-in
  in all 27 pairs; 607->606 exactly
  10-out/9-in, identical 23/25), not fixed
  deletions; the S76 converse HOLDS
  (pair positions flip 128/128 long runs,
  162/162 span>=2, ZERO agreements; pure
  swap reconstruction 121/131, S82 exact
  22/22); 85->92 insertion is REJECTED
  (0 insert opcodes, LCS 75/85) and
  replaced by ONE rewritten segment
  a[12:29]->b[12:36] ((9144,184) motif ->
  (528,80) motif + 80-run, +7 exactly,
  head 12 and suffix 56 untouched).
  `docs/HAILO10H_PLUS3_ORDER_S76_CONVERSE_85_92_SEGMENT_2026-10-24.md`.
- [x] Slice4.77 segment-substitution census
  (other context pairs sharing head+suffix
  with one rewritten motif segment; the
  (9144,184)/(528,80) motif families
  wherever they occur); S76 outside-pair
  span positions vs neighbouring runs
  (spillover test): the single-replace form
  occurs NOWHERE (0 hits in 3,478 strict +
  7,930 loose candidates; 85->92 itself is
  several replaces between equal islands);
  under the region definition (islands <=2,
  head >=12, suffix >=20) localized
  substitution (region <=40) is UNIQUE to
  85->92 in 0a0d+cc9 (1 hit; all 153 other
  region hits are whole-body >=191, cc9's
  five all involve outlier cidx 132); the
  motif pairs never repeat contiguously
  ((9144,184) 7 occ / 2 contexts, always
  24-flanked 7/7; (528,80) 551 occ / 339
  contexts, all artifacts; x2/x3 and both
  full motifs all 0); S76 spillover PARTIAL
  (6/10 outside-pair flips are neighbour-run
  swaps, all 10 at edge distance <=2; 4/10
  match neither neighbour; S82 stays 0).
  `docs/HAILO10H_SEGMENT_SUBSTITUTION_MOTIFS_SPILLOVER_2026-10-24.md`.
- [x] Slice4.78 region census extended to
  the remaining five artifacts (localized
  substitution corpus-wide); the four
  unexplained S76 flips (173, 517, 618,
  619) vs second-neighbour runs and span
  extension: the remaining five give 377
  K2 hits / 374 localized (corpus 531 /
  375); localized hits split by scale —
  micro (region <=5) 373, a repeated-family
  property (76c3a8ff 156 hits = one len-89
  signature, position 18 = 21392/21648
  across 25 step-9 contexts, 13x12
  cross-camp; sisters 109/107, 11
  signatures each), and segment scale
  exactly ONE more: 0856a10c 85->91
  (region 16->22, (9144,184)x4 ->
  (528,80)x3, suffix 56, ng0->ng1) — the
  segment class has exactly 2 members
  corpus-wide, both the same motif
  rewrite at a-len 85; single-replace 299
  in the five vs 0 in 0a0d+cc9. The S76
  residue fails every radius-2 test
  (second-neighbour swap, span extension
  by 2, gap-bridged super-run internality
  all 0/4); it stands, mechanism NOT
  PROVEN.
  `docs/HAILO10H_REGION_CENSUS_CORPUS_S76_RESIDUE_2026-10-24.md`.
- [x] Slice4.79 the two segment exemplars
  compared whole-context (0856a10c 85->91
  vs 0a0d378c 85->92: a/b contexts related
  across artifacts? head 13 vs 12, suffix
  identity); 76c3a8ff len-89 camp anatomy
  (what besides position 18 separates the
  21392/21648 camps); sister len-496
  5->5 signature region contents: the
  exemplars are ONE construction — a-side
  size multisets identical (85/85), the
  56-action suffix size-identical in all
  four contexts with exactly one free
  channel slot (suffix pos 0: a0/b1 = 2,
  a1/b0 = 1), head scaffold offset by one
  24 B burst (head 12 vs 13), head
  channels/bytes private, suffix bytes
  28/56 universal across all pairings and
  5 differing in all. The len-89 camps
  differ by the position-18 size ALONE
  (21392 vs 21648, delta 256): channels
  identical in all 300 pairs, the same 11
  positions carry per-context offsets and
  bytes in both camps, the other 78 are
  byte-identical across all 25. The
  sister 5->5 region is the frame
  (X, 328, 24, Y, Z) at positions 22-26,
  channels all 2 — 8 tuples per sister
  (4 shared; modal (18648,328,24,32776,
  15304) x13/x14), no slot a function of
  another; bytes per-context except the
  universal position-24 burst, the 328
  payload pool fully shared cross-sister
  (28/28), the Y-slot pool fully private.
  `docs/HAILO10H_SEGMENT_EXEMPLARS_LEN89_CAMPS_SISTER496_2026-10-24.md`.
- [x] Slice4.80 exemplar head channel
  sequences vs the corpus (does either
  head channel pattern recur in other
  contexts?); len-89 position-18
  three-value train (24/21392/21648
  interleaving over the full step-9
  train, incl. the 528 singleton at
  cidx 110); sister modal-tuple
  contexts ((18648,32776,15304) cidx
  pattern; what separates them at other
  region signatures): 0a0d's head
  patterns recur nowhere (0/1,503 each),
  0856's recur joint-exact in 22/27
  contexts as train heads in other
  artifacts; the len-89 train is two
  interleaved step-9 sub-trains, each
  one uniform main form (25) plus one
  shifted-region head, position 18 a
  sub-train/head artefact, camps a
  B-main choice alone; the sisters'
  len-496 families hold 9 size
  sequences each and share exactly one
  (5ab's modal sequence, in 773 only
  cidx 97), modal contexts separated
  by positions {9,22,25,26} and
  signature-poor (own region only).
  `docs/HAILO10H_HEAD_RECURRENCE_LEN89_TRAIN_MODAL_TUPLE_2026-10-24.md`.
- [x] Slice4.81 head-pattern trains
  (0a0d len-623 step-4 contexts with
  0856 a's head; len-763 step-6 with
  0856 b's head — whole-context
  relation to the exemplars?); camp
  choice vs the len-89 B-main form's
  11 byte-variable positions (contents
  at position 18 / offsets); len-496
  template census (all 9 sequences per
  sister: cluster sizes, tuple
  mapping, cidx pattern per template):
  the trains share ONLY the 13-action
  head (len-623 joint prefix exactly
  13 in 16/16, per-context bodies;
  len-763 splits by ng — ng1 step-6
  carries b's head with channel prefix
  28, ng0 step-4 carries neither);
  camp choice is written at position
  18 alone (within-camp content prefix
  exactly 6,408 B 144/144, cross-camp
  0 B 156/156, first bytes 02..a6 vs
  03..a8; other ten positions
  camp-blind); len-496 census 9
  templates per sister (13-dominant,
  singleton tails), tuple ~bijective
  to template, frames fixed (18,22,
  473), 773 cidx 97 a full joint
  transplant of 5ab's modal template.
  `docs/HAILO10H_HEAD_TRAINS_CAMP_CONTENT_TEMPLATE_CENSUS_2026-10-24.md`.
- [x] Slice4.82 position-18 segment
  anatomy (byte-0/byte-3 camp word;
  6,408 B shared prefix vs per-context
  tail; where the +256 sits); ng1
  channel-prefix-28 extension vs
  exemplar b; sister singleton
  templates' nearest-template
  distances: camp word 02 28 f0 a6 vs
  03 28 f0 a8 (bytes 0 and 3 locked,
  header rest fixed); global prefix
  exactly 6,408 B both camps; the
  whole +256 in the tail (14,984 vs
  15,240 B, ~83% zero, 98.8% of tail
  positions camp-constant, first tail
  byte per-context distinct);
  one-block insertion excluded 0/156;
  channel-prefix-28 is a zero plateau
  (b chans[13:28] all zero, 48,146
  subsequence occurrences; full
  chans[0:28] exactly 27, all at
  offset 0; ng1 channels constant to
  position 54); singletons 1–2 size
  edits from resident templates
  (channel Hamming 0) except 773
  cidx 97 at 314/193/L1 4,641,152.
  `docs/HAILO10H_POS18_ANATOMY_CHAN28_SINGLETON_NEAREST_2026-10-24.md`.
- [x] Slice4.83 position-18 tail
  per-context anatomy (exactly 187
  variable positions per camp: 180 in
  a dense band at rel <=490, rel mod 4
  in {0,1,2} only; 72 binary slots
  with camp-flavoured alternate byte
  0xa3 vs 0xb3; opening word
  per-context; 37 single-position camp
  separators; sparse slots drift
  +64/+128/+256); corpus census of
  the 16 B header pattern (exact only
  at the 25 known starts; generalised
  exactly twice, both 0856a10c; raw
  suffix only in 76c3a8ff/0856a10c,
  zero elsewhere); ng1 channel plateau
  past 28 (group pattern (1,1,0,0)
  over 33–53; b's prefix vs the group
  exactly 28, agreements 11/26 all at
  group-zero slots, never at a
  group-1 slot).
  `docs/HAILO10H_POS18_TAIL_HEADER_CENSUS_PLATEAU_PAST28_2026-10-24.md`.
- [x] Slice4.84 binary-tier choice
  structure (two positional blocks
  of 36 slots, one bit per block:
  head block Q pair {a2,a3|b3},
  late block P pair {01,02};
  popcounts only {0,36,72}; camp
  21392 Q implies P, camp 21648
  all four combos); 02 28 50 71
  sibling occurrences inside
  76c3a8ff (all 26 at action starts:
  position 20, size 14,528, channel
  0, step-9 ng1 train of 400-action
  contexts, cidx %9 == 5; segments
  share exactly 108 B prefix, all
  distinct — correcting AES-NUM-083's
  never-at-an-action-start clause;
  5 suffix-less words mid-segment);
  sparse-slot drift landmarks (four
  ff-word slots = one repeated
  per-context scalar, mostly +9
  steps; final 3 sparse bytes =
  tail's last word; drift is
  start-anchored at rel 2161,
  end-anchored at end-159 and the
  final word, stretched between).
  `docs/HAILO10H_BINARY_BLOCKS_SIBLING_HOME_SPARSE_SCALAR_2026-10-24.md`.
- [x] Slice4.85 sibling segments
  past their 108 B prefix (flat,
  camp-less: 600 variable positions,
  544 two-valued, diffuse, no
  prefix/tail split); the two block
  bits are independent of the tail's
  other per-context scalars (ff
  scalar, byte 0 — no determination,
  threshold or parity law); ff-frame
  census inside the position-18
  segments (exactly 43 ff-words per
  segment: 4 variable + 39 constant
  over {15 x27, 35 x4, 2 x4, 71 x2,
  11 x2}).
  `docs/HAILO10H_SIBLING_ANATOMY_BLOCKBITS_FF_CENSUS_2026-10-24.md`.
- [x] Slice4.86 sibling 544
  two-valued positions are ONE
  partition (cidx 113, the first
  segment, deviates at all 544; the
  other 25 are unanimous there —
  no per-slot/block choice); the 39
  constant ff offsets drift on one
  monotonic +64 staircase
  (thresholds 9044/11292/15508/
  17204; scalars rank-locked,
  identical 39/39 across camps);
  the sibling segments' 18 ff-words
  sit at one fixed offset set (15
  constant {15 x11, 5 x2, 104 x2} +
  3 variable slots repeating the
  rank-ladder scalar 21+9xrank).
  `docs/HAILO10H_DISTINGUISHED_SEGMENT_FF_STAIRCASE_SIBLING_FF_2026-10-24.md`.
- [x] Slice4.87 cidx 113 IS
  distinguished context-wide
  (private (size,channel) schedule
  at 249/400 positions where the
  other 25 are unanimous; private
  content at 23 of the 80 consensus
  positions — 15 skeleton bursts,
  3x328 B, 2x48 B, 80 B, 5008 B,
  32784 B; no first-segment
  privilege in the pos18 camps and
  no second len-400 train exists);
  the staircase thresholds are
  ordinary ff-15 fixture words
  (ranks 2/8/22/26, next ff +192,
  no variable positions nearby);
  the pos18 variable ff scalar is
  NOT a rank ladder but equals
  cidx - 92 exactly in both camps
  — and the sibling 21+9xrank
  ladder is the same law (51/51
  segments).
  `docs/HAILO10H_DISTINGUISHED_CONTEXT_THRESHOLDS_CIDX_LAW_2026-10-24.md`.
- [x] Slice4.88 the cidx law is
  corpus-wide: scalar = cidx + C
  in all 372 scanned ff populations
  (slope exactly 1; C = +1 in 181
  groups, one negative per-artifact
  constant in 191 — 0856 -99, 0a0d
  -73, sisters -94, 76c3 -92, cc9b
  -133); context 92 is ordinary in
  every blob and MiniLM has none;
  cidx 113's schedule is a DIFFERENT
  multiset (not a permutation, not
  a re-grouping; totals differ;
  partial kinship with 302/311);
  each staircase +64 lives in the
  single inter-ff region before
  ff ranks 2/8/22/26, and the four
  extra tails share a 32 B opening.
  `docs/HAILO10H_CIDX_LAW_CORPUS_SCHEDULE_REGIONS_2026-10-24.md`.
- [x] Slice4.89 the separator is
  network-group membership
  exactly (ng 0 -> C = +1, 181
  groups; ng 1 -> the artifact's
  negative constant, 191; every
  other feature mixed) and the
  constant is 1 minus the ng-1
  start cidx (100/74/95/93/134 ->
  -99/-73/-94/-92/-133): ONE law,
  scalar = cidx - ng_start + 1,
  the context's 1-based position
  in its own network group; the
  113/302/311 kinship DISSOLVES
  (302/311 agree with consensus
  at 296, with each other at
  298, content-equal 0 incl.
  0/155; 113 agrees with all at
  the same 62 tail positions);
  the four extra tails share
  bytes 0-57, differ at byte 58
  (86/88/84/8a), are camp-constant
  and occur once in BOTH camps,
  displaced by 64 x step index.
  `docs/HAILO10H_NG_SCALAR_LAW_KINSHIP_TAILS_2026-10-24.md`.
- [x] Slice4.90 every aligned ff
  word in the scanned populations
  is CONST (17,351) or the
  within-ng index (3,290) of
  20,645 common offsets in 374
  groups; the only OTHER offsets
  are 4 two-valued ngidx==1 step
  pairs (15/0 and 1/7) in the
  single 0a0d exception group,
  whose offset 10976 is NGIDX;
  camp tails are region-final
  content present once in BOTH
  camps (neither duplicated nor
  displaced — camp B's +64 per
  grown region lives in the
  middle window, A 168 B vs
  B 232 B, between common prefix
  and common suffix 172);
  first-in-train distinction is
  the norm (52 trains: 28 unique
  first-member outliers up to
  D = 342, 13 unanimous, 11 with
  the outlier elsewhere; content
  in 25 of 28; sibling D = 249
  and content = 23 reproduce).
  `docs/HAILO10H_FF_CLASSIFICATION_CAMP_ALIGNMENT_TRAINS_2026-10-24.md`.
- [x] Slice4.91 grown-region
  middles are camp-constant and
  insertion-shaped but not a pure
  insertion (best k 111/112,
  21/168 mismatches, all ranks);
  extra chunk 0x in camp 21392,
  48x in camp 21648 (4/segment);
  step pairs do NOT recur in the
  extension bands (87 groups,
  3,689 offsets, CONST/NGIDX
  only; in-band OTHER 4 all
  STEP reproduce); no feature
  separates distinguished firsts
  (pools ALL/NONE/SOME by ng;
  step==9 7/28 vs 0/24 only).
  `docs/HAILO10H_CAMP_MIDDLE_STEP_RECURRENCE_TRAIN_MECHANISM_2026-10-24.md`.
- [x] Slice4.92 the 21 middle
  mismatches are one rank-
  identical tail list (thirds
  1/4/16; 16 B rhythm, no exact
  period); the sparse ff scan
  completes the census (31,568
  offsets; 26 non-step OTHER,
  step does not recur); firsts
  differ from other outliers in
  kind (3,089 vs 176 D-positions;
  both-changed 47.3% vs 15.9%).
  `docs/HAILO10H_MISMATCH_ANATOMY_SPARSE_FF_DPOSITIONS_2026-10-24.md`.
- [x] Slice4.93 the 26 sparse
  OTHER ff offsets are mostly
  per-ng forms (per-ng CONST 14,
  combined per-ng CONST/NGIDX
  19/26; residue 4 one-deviation
  NGIDX, 1 index-at-one-instance,
  2 uninformative pairs); middle
  16 B units share only units
  1-4 verbatim (crowd in units
  7-10, no unit repetition at
  any lag); firsts' pair is not
  a function of the consensus
  pair under any tested key.
  `docs/HAILO10H_PERNG_FORMS_UNIT_ANATOMY_PAIR_FUNCTION_2026-10-24.md`.
- [x] Slice4.94 the deviating ff
  instances are exactly the
  sparse-neighbourhood instances
  (value-0 instances share one
  byte-identical sparse tuple
  across artifacts; twin is
  per-ng CONST); middles differ
  across ranks only in unit 0
  (units 1-4 shared everywhere,
  B vocabulary >= 5 disjoint);
  per-ng adds no form inside the
  classified population (CONST
  equal across ngs 6,805/6,805;
  NGIDX degeneracy = single-
  instance ngs).
  `docs/HAILO10H_DEVIATING_INSTANCES_RANK_UNITS_PERNG_CLASSIFIED_2026-10-24.md`.
- [x] Slice4.95 sparse-form
  census (sparse does NOT predict
  values habitat-wide: common-arm
  zero rates SPARSE 8/141, per-ng
  follow 79/135 vs DENSE 93/196;
  whole-arm zero enrichment 6.3%
  vs 2.2%/0.9%, no law); unit 0
  is a per-rank form (camps differ
  only byte 0; every segment
  carries it exactly; recurs
  nowhere else); B06/B11 two
  copies, aligned mismatches
  2 vs 4, neither in the chunk.
  `docs/HAILO10H_SPARSE_FORM_UNIT0_B06B11_2026-10-24.md`.
- [x] Slice4.96 sparse zero
  anatomy (F 144 exact; z3 5.9%,
  z4 8.6%, z5 none; masks 3, all
  trailing-11; zeros at 37/869
  offsets, shared 7.8% vs single
  2.1%); second 8900 pair in
  region 0's 02-field, unanimous
  in both camps; copy spans
  rank-invariant, k=112 chunk =
  B units 7-10 verbatim.
  `docs/HAILO10H_SPARSE_ZERO_8900_PAIR_COPY_SPANS_2026-10-24.md`.
- [x] Slice4.97 mask law test
  (trailing pair necessary —
  FN 0/2,280 — not sufficient:
  1,841 FP; mask 10011 richest
  108/549); region 0 zero-
  dominated (02 = 150/2,056),
  89/82 unanimous singletons;
  six pairs at all 257 lags,
  a9->3e only at -16/+64.
  `docs/HAILO10H_MASK_LAW_REGION0_02FIELD_LAG_CENSUS_2026-10-24.md`.
- [x] Slice4.98 sparse zeros
  per-offset deterministic
  (22 zero (mask, offset)
  pairs, no partial offset;
  11011 only in the two
  0856a10c groups); region-0
  block = 26x7 units, 3
  families, x36 words are
  per-segment values not
  consensus content; 20>3e
  shift set exactly positional
  (257/257), +31 = repeated
  pair at 80-spacing.
  `docs/HAILO10H_PERMASK_ANATOMY_DATABLOCK_SHIFTSET_2026-10-24.md`.
- [x] Slice4.99 zero pairs
  have almost no counterparts
  (2 total in 2,280, both
  non-zero 11011; offsets are
  mask-exclusive); block head
  values = one constant per
  segment per family (fam0
  ffffff7f everywhere, fam1/2
  injective labels, disjoint
  across families/camps);
  positional law exact for
  ALL byte pairs (0 differing
  triples, 602 pairs).
  `docs/HAILO10H_ZERO_PAIR_COUNTERPARTS_HEAD_POPULATION_POSITIONAL_LAW_2026-10-24.md`.
- [x] Slice4.100 the 22 zero
  offsets are DENSE/MID-poor
  (4 candidates vs 616 at
  control offsets) but NOT
  form-exclusive (one DENSE
  zero at 28768); label values
  carry no non-degenerate
  stated function of segment
  metadata (501 hits, all
  degenerate); positional law
  exact on all 36 ungrown
  region pairs + in reverse
  (pooled = forward exactly).
  `docs/HAILO10H_ZERO_OFFSET_FORMS_LABELS_POSITIONAL_2026-10-24.md`.
- [x] Slice4.101 the single
  DENSE zero at 28768 shares
  only the centre ff word with
  the SPARSE zeros there
  (tuple/instance/group all
  disjoint; its group holds a
  run of 4 DENSE zeros at
  28760..28772); block tails
  are one constant per family
  in all 25 segments (fam0
  00000000, fam1 00020000,
  fam2 00000000 — no label
  reading from tails exists);
  positional law exact on
  non-camp segment pairs
  (A0xB0 and A0xA1, 0 differing
  triples on 5.49M/5.48M
  tallies).
  `docs/HAILO10H_DENSE_ZERO_TAIL_CONSTANCY_NONCAMP_POSITIONAL_2026-10-24.md`.
- [x] Slice4.102 the DENSE-zero
  run of four is a raw ff-word
  run in one instance (cidx 5,
  mask 00000 x4) and one of 15
  single-instance runs corpus-
  wide (14 of length 4, 1 of
  length 3; 59/64 DENSE zeros
  in runs); block variation is
  exactly the two family labels
  (110/182 constant per camp
  and pooled, 72 varying =
  fam1/2 head slots only, all
  72 label-exhausted in both
  camps); positional law exact
  on B0xA0 (mirror of A0xB0)
  and B0xB1 (0 differing).
  `docs/HAILO10H_DENSE_RUN_BLOCK_VARIATION_POSITIONAL_COMPLETION_2026-10-24.md`.
- [x] Slice4.103 the 5 singleton
  DENSE zeros and the length-3
  run (maximal raw ff000000 run
  anatomy for all 64 DENSE
  zeros); the fam1/fam2 label
  pair within a segment (25
  paired labels, as-function /
  affine hunts); positional law
  on the consensus-camp pair
  consA x consB; then broad
  ordinary UNMODIFIED source-
  model support100%.

- [x] Slice4.104 the candidate-
  less raw word at 17344 in
  (0a0d378c, 20, 32752) cidx 44:
  17344 IS a common offset of
  its group (commons [13664,
  17344]) — exclusion EXPLAINED
  by the population definition;
  the word is a common-arm
  DENSE zero, one of exactly 2
  corpus-wide; edge census 65
  raw positions / 64 candidates
  / 1 missing (the common
  offset itself). Singleton vs
  run-member neighbourhoods:
  per-position value sets
  disjoint at all four positions,
  0 shared tuples, but no exact
  separation — distinction NOT
  PROVEN. Labels vs cidx /
  segidx / pooled rank: every
  as-function hit degenerate,
  affine/XOR hits 0 — NOT
  PROVEN.
  `docs/HAILO10H_CANDIDATELESS_17344_NEIGHBOURHOODS_CIDX_LABELS_2026-10-24.md`.

- [x] Slice4.105 the second
  common-arm DENSE zero
  (MiniLM, 23, 32768) p 9272
  cidx 5 mask 01000: 9272 IS a
  common offset of its group
  (its ONLY common offset) —
  exclusion EXPLAINED by the
  population definition, as at
  17344; cidx 5 record value 0,
  z 1, DENSE, mask 01000, per-ng
  form OTHER (no prediction);
  raw run length 1 in cidx 5,
  cidx 3 word ff7f0000.
  Disjointness control: 0 of
  2,000 seeded random 5-splits
  disjoint at even one position;
  7 deterministic splits none —
  the 4.104 disjointness is NOT
  a small-n artefact (exact-
  separation law still NOT
  PROVEN). Labels vs ngidx / ng:
  ng constant 1 in all 25
  segments; ngidx injective in
  every scope, affine/XOR hits
  0 — NOT PROVEN; every stated
  metadata determiner exhausted.
  `docs/HAILO10H_SECOND_COMMONARM_DISJOINT_CONTROL_NG_LABELS_2026-10-24.md`.

- [ ] Slice4.106 the singleton-
  only neighbourhood values
  themselves (identity across
  the 5 singletons' groups /
  offsets; recurrence anywhere
  else in the corpus
  populations); the cidx-3
  counterpart at 9272 word-by-
  word vs the cidx-5 DENSE
  zero's neighbourhood; label
  values vs the segments' own
  block positional structure;
  then broad ordinary
  UNMODIFIED source-model
  support100%.

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
