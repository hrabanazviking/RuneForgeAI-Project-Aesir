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

- [x] Slice4.106 the singleton-
  only neighbourhood values
  themselves: 17 (position,
  value) pairs / 13 distinct —
  shared across singletons only
  inside the MiniLM cidx-5 pair
  (11408/32248); 12 of 17 recur
  at the same position in
  non-singleton whole
  neighbourhoods (the values are
  mostly corpus-common; the
  disjointness is against the
  run-members specifically);
  fd000000 UNIQUE in everything
  scanned, e9ff0000 raw-unique.
  The cidx-3 counterpart at
  9272 vs the cidx-5 DENSE zero:
  position-equal 0/5, differing
  bytes 10/20, centres differ
  only in the value byte — not
  a near-copy. Labels vs block
  positional structure: own
  head slots definitional
  (36/36, excluded); slot +
  aggregate hunts affine 0
  everywhere, as-function 0
  except 72 camp-B-only hits
  (label1 byte1 from label2
  head bytes, both collisions
  agreeing — recorded, not a
  law); every in-segment
  determiner class closed.
  `docs/HAILO10H_SINGLETON_ONLY_9272_COUNTERPART_BLOCK_POSITIONAL_2026-10-24.md`.

- [x] Slice4.107 the camp-B
  label-pair correlation is
  chance-consistent (both-byte
  non-vacuous as-function in
  4,179/20,000 seeded size-12
  pooled subsamples and
  3,439/20,000 permutations —
  not a law; label-pair class
  closed). The rare singleton
  words are NOT rare wider:
  542,905 distinct referenced
  segments — fd000000 3,223
  occurrences in 1,549 segments
  (its uniqueness was a narrow-
  population artefact),
  e9ff0000 209, f6000000 2,286.
  Instance-pair agreement at
  common offsets: 789 pairs,
  distribution {0:25, 1:172,
  2:88, 3:2, 4:246, 5:256} —
  0/5 is a 3.2% exception, not
  the rule; centre position
  least agreed (275/789), +4
  most (742/789).
  `docs/HAILO10H_CAMPB_CHANCE_RAREWORDS_PAIR_AGREEMENT_2026-10-24.md`.

- [x] Slice4.108 the 25
  total-disagreement (0/5)
  instance pairs as a class
  (groups/offsets, forms and
  zero patterns vs the 256
  identical pairs); the
  near-empty exactly-3 band
  and the bimodality's group
  structure (agreement as a
  per-group property?); the
  rare-word concentration in
  cc9b9d1c (fd000000/f6000000
  density per referred byte
  vs the other artifacts);
  then broad ordinary
  UNMODIFIED source-model
  support100%.
  DONE (AES-NUM-108): the 25
  occupy exactly 4 cells
  (0a0d @17344 x6 identical
  pair; sisters @17272 x9
  each, one SPARSE B vs 9
  DENSE label-variants;
  MiniLM @9272 x1), all
  differing in exactly 10
  bytes (2/4/1/(1,2) per
  position); no group/offset
  separator (17344 cell holds
  both classes); exactly-3 =
  2 ordinary MID/MID pairs,
  agreement grades per-cell
  not per-group; cc9 density
  fd 841.7 / f6 726.9 per
  1e9 B (2.5-3x next blob),
  carried by 929 of 112,884
  cc9 segments.
  `docs/HAILO10H_ZERO25_EXACTLY3_CC9_DENSITY_2026-10-24.md`.

- [x] Slice4.109 the mixed
  0a0d378c @17344 cell pair
  by pair (its 6 zero pairs
  vs its 15 identical pairs:
  form/zero/word separator?);
  the cc9 rare-containing
  segments as a class
  (fd/f6/e9 set overlaps,
  joint size/offset structure
  vs the cc9 census); the
  sister cidx-95 SPARSE
  singleton's uniqueness in
  its group (do the 9 DENSE
  partners agree at any
  other common offset?);
  then broad ordinary
  UNMODIFIED source-model
  support100%.
  DONE (AES-NUM-109): the cell
  holds exactly 2 neighbourhoods
  — cidx 44 alone vs the other
  six identical; the 6 zero
  pairs are exactly 44 x each
  other, the 15 identical pairs
  are within the six; identity
  and the zero pair (0,1) vs
  (1,1) separate inside the
  cell, form does not (both
  (DENSE,DENSE)). The cc9 929
  are a distinct subpopulation:
  overlaps 100.2x/38.5x/37.4x
  independence (triple 1325x),
  only 11 sizes (32784 = 58.3%
  of the class), offset
  quartiles Q2+Q4 = 91.8%.
  Cidx 95 is unique at all 4
  common offsets of its group
  in both sisters (identity,
  form, zero count); eq vs
  partners 2/0/2/1 per offset —
  total disagreement confined
  to @17272.
  `docs/HAILO10H_MIXED_CELL_CC9_CLASS_SINGLETON_2026-10-24.md`.

- [x] Slice4.110 the mixed
  cell's second common offset
  and cidx 44's cross-group
  profile (same singleton kind
  elsewhere?); the cc9 929's
  referencing-action profile
  ((pos,size,channel) actions
  and contexts pointing at
  them vs all cc9 references);
  the cidx-95 singleton's
  per-offset differing
  positions (which positions
  carry its 2/0/2/1 distances)
  and its profile in the other
  groups of its artifacts;
  then broad ordinary
  UNMODIFIED source-model
  support100%.
  DONE (AES-NUM-110): at the
  second offset 13664 cidx 44
  is the singleton again (same
  two neighbourhoods), but at
  eq 1 (shared +4 zero word),
  and form separates here;
  cross-group its singleton
  status is confined to the
  cell's group (distinct
  33/295 offsets, any-eq5
  262/295, its only eq-0 pairs
  are the six @17344 pairs).
  The cc9 929 are referenced
  by all 271 contexts (1,855
  refs); one 304 B segment
  takes 813 of them (43.8%,
  all of cc9's size-304 refs)
  at head positions 5-12; the
  other 928 are referenced
  once/twice like ordinary
  segments. Cidx 95's 2/0/2/1
  distances sit in fixed
  position sets ([1,2,4] / all
  / [0,1,2] / [0,1,2,4]);
  agreements are shared zero
  words only, no mixed
  positions; cross-group
  vacuous in 5ab3537d (no
  second analysable group),
  near-total in 773470cd
  (distinct 13/14, one
  full-agreement offset).
  `docs/HAILO10H_SECOND_OFFSET_929_POINTING_SINGLETON_POSITIONS_2026-10-24.md`.

- [x] Slice4.111 cidx 44's
  distinctness events outside
  its cell (33 offsets in the
  pos 12/13/16/21/25/30
  groups: singleton-vs-many
  or general variation?); the
  813-reference segment's
  anatomy (its rare-word
  contents) and rotating
  (pos,channel) law, plus
  heavy cc9 contexts (21-48
  class refs) vs the 182
  exactly-3 contexts; cidx
  95's one non-distinct offset
  in 773470cd's pos-9 group
  pair by pair, and the same
  pos-9 group in 5ab3537d
  (why no common offset
  there); then broad ordinary
  UNMODIFIED source-model
  support100%.
  DONE (AES-NUM-111): all 31
  outside-cell distinctness
  events are general variation
  (partners mutually distinct;
  singleton-vs-shared occurs
  only at the cell's own 2
  offsets). The 813 segment is
  cc9's ONLY size-304 segment;
  its class membership rests
  on one fd000000 word (word
  20); every one of the 271
  contexts references it
  exactly 3x as a consecutive
  (pos,0),(pos+1,1),(pos+2,2)
  triple (starts 4-10, no
  stream period). Exactly-3
  contexts reference it ONLY;
  heavy contexts add the wider
  pool (856 distinct segments)
  on the same triple. Cidx
  95's non-distinct offset
  11608 is group-wide
  unanimity (all 8 share one
  neighbourhood, centre
  ff010000); 5ab3537d's pos-9
  group has 25 instances (95
  not a member) and no common
  offset (split grids, cidx
  208 disjoint).
  `docs/HAILO10H_GENERAL_VARIATION_813_SEGMENT_POS9_UNANIMITY_2026-10-24.md`.

- [x] Slice4.112 the centre
  ff-word value ladder as a
  population (per-instance
  centre value vs instance
  index; is ff010000 the
  ladder's base?); the
  813-triple start position
  as a function of the
  referencing context; and
  11608-class unanimity
  offsets across the corpus
  (how many (group,offset)
  cells are unanimous; do
  they share the value-1
  centre pattern?); then
  broad ordinary UNMODIFIED
  source-model support100%.
  DONE (AES-NUM-112): the
  ladder is per-cell —
  ff010000 is NOT its base
  (not minimum, not mode,
  not index-zero; mode is
  value 15 in all 256-value
  population and in the
  11,242 all-distinct ladder
  cells, where values are
  non-decreasing by rank in
  11,212 cells and step +4
  is modal over a step
  family). The 813 start is
  determined by NO tested
  per-context field
  (NOT PROVEN). Unanimity
  is the corpus norm:
  39,673/55,902 cells
  (71.0%), 71 centres,
  ff0f0000 dominant
  (24,276), ff010000 only
  1,016 (2.56%).
  `docs/HAILO10H_CENTRE_LADDER_813_START_UNANIMITY_CORPUS_2026-10-24.md`.

- [x] Slice4.113 the per-cell
  ladder's (base, step)
  parameters as a population
  (is the pair a function of
  the cell's group/offset;
  what governs the step
  family {+4, +3, +8, +9,
  +12, ...}?); the 813
  triple's start vs
  sub-sequence position
  (cidx-order locally
  periodic stretches — rank
  within its own (ng, size)
  train?); and unanimity in
  the 11608 setting proper
  (groups of >=8 instances:
  counts, centres, value-1
  share vs its 2.56% corpus
  share; is the unanimous
  centre a function of
  group/offset?); then
  broad ordinary UNMODIFIED
  source-model support100%.
  DONE (AES-NUM-113): the
  (base, step) pair is a
  function of NO tested
  group/offset field
  (NOT PROVEN) — only 72
  distinct pairs among 2,584
  AP cells; step is strongly
  conditioned by artifact
  (restricted per-artifact
  step subsets, several
  steps artifact-exclusive)
  and by cell length, and
  (base, length) determines
  step at 89/92 keys. The
  813 start is NOT a
  function of sub-sequence
  position (all rank/train
  tests ambiguous), but
  inside each stride-4
  train the starts collapse
  to constant or period-2
  after a <=3-rank head
  transient (lag-8 agreement
  0.6996 vs chance 0.2071).
  In the >=8 setting
  unanimity holds at the
  corpus rate (18,286/
  25,566, 71.52%), centres
  narrow to 29 values,
  ff0f0000 at 62.16%,
  ff010000 over-represented
  at 3.07% vs its 2.56%
  corpus share, and the
  unanimous centre is a
  function of no tested
  group/offset field.
  `docs/HAILO10H_LADDER_PARAMS_813_SUBSEQ_GE8_UNANIMITY_2026-10-24.md`.

- [x] Slice4.114 the ladder
  near-laws' exceptions (the
  3 ambiguous (base, length)
  keys and the 13 ambiguous
  group keys for (base,
  step); the step-0 split
  between base 127 and base
  15; the non-AP difference
  profile as a population —
  is the profile a function
  of group/offset?); the 813
  triple's start as a
  function of (train, rank
  regime) — per-train head
  length, steady-state form
  and phase, the in-train
  exception census, and the
  54 contexts in no train;
  and the centre-1
  concentration in the >=8
  setting (inside 0a0d378c,
  is centre 1 a function of
  (group, offset)?) plus the
  42 unanimous centres that
  vanish at >=8 and where
  they live in the <8
  population; then broad
  ordinary UNMODIFIED
  source-model support100%.
  DONE (AES-NUM-114): the 3
  ambiguous (base, length)
  keys dissolve under
  artifact (13,13) and (4,27)
  or segment size (4,16);
  the 13 ambiguous group
  keys are the same keys for
  base, step and pair, each
  coupling a step-0 pair
  with a rising pair at
  disjoint offsets. The
  step-0 split IS determined
  by group and by (pos,
  length): base 15 is
  length-3 only in
  76c3a8ff/cc9b9d1c with
  spread offsets, base 127
  spans lengths 3-27 in all
  artifacts with offsets
  confined to 5,988-8,672.
  The non-AP profile (317
  ordered profiles over
  4,148 cells) is a function
  of no tested single field
  (NOT PROVEN) but is
  group-determined at
  518/520 groups, ndiff
  exactly. The 813 start
  under (train, rank
  regime): four trains exact
  after heads of 1-3 ranks,
  train 49 constant with one
  head-absorbed deviant,
  three trains
  constant-dominant with
  exactly 10 steady
  exceptions, every deviant
  exactly +1 above its
  regime; the joint model
  is correct on 188/198
  steady ranks but is NOT a
  function (7/25 keys
  ambiguous). The 54
  train-less contexts are
  53 members of classes of
  size <=6 plus one residue
  outlier (cidx 2 of the
  (0,607) class). Inside
  0a0d378c centre 1 is a
  function of no tested
  field (NOT PROVEN); its
  >=8 centre set is exactly
  {0,1,3,7,15,31,63,127}.
  The 42 vanishing centres
  live in only 116 <8
  unanimous cells (0.54%),
  36/42 single-artifact,
  mostly cc9b9d1c size-2
  groups.
  `docs/HAILO10H_LADDER_EXCEPTIONS_TRAIN_REGIME_CENTRE1_2026-10-24.md`.

- [x] Slice4.115 the non-AP
  profile's last exceptions
  (the 2 groups of 520 whose
  non-AP profile varies
  within the group — do
  their variants separate
  by offset?); the train
  regime's two absorbed
  deviants (train 49's
  rank-10 start of 10 and
  the train-less cidx 2 of
  the (0,607) class — any
  tested mark of the
  deviation in the
  surrounding contexts?)
  plus the two size-6
  873-acts classes (any
  period in cidx organising
  their 12 starts?); and
  the 2^k-1 centre set (is
  0a0d378c's >=8 centre set
  {0,1,3,7,15,31,63,127} the
  shape of the other
  artifacts' >=8 centre
  sets, and of the <8
  population — the exact
  centre sets per artifact
  in both settings?); then
  broad ordinary UNMODIFIED
  source-model support100%.
  DONE (AES-NUM-115): the 2
  varying groups are mirror
  groups (5ab3537d and
  773470cd, both pos 21 /
  segsize 32776, identical
  cidxs and offsets), each
  with exactly 2 cells whose
  first nine centres are an
  exact +3 ladder and whose
  whole variation is the
  tenth centre (15 vs 11,
  the sole ng1 instance);
  no tested field separates
  the variants beyond cell
  identity and tautology
  (NOT PROVEN). Train 49's
  deviant is an isolated
  local anomaly with a
  measured head cause (one
  extra head act shifts the
  identical triple block by
  one position; not a phase
  slip). The train-less
  cidx 2 carries no mark —
  its start is
  in-distribution and its
  isolation is purely the
  missing cidx 6 classmate.
  The two 873 classes share
  cidx diffs [4,2,4,4,2];
  no tested field or period
  orders their 12 starts
  (NOT PROVEN). The 2^k-1
  completeness at >=8 is
  0a0d378c-only; the mirror
  pair shares one identical
  13-centre >=8 set but not
  its <8 set; the 42
  vanishing centres split
  88/13/9/4/1/1 per artifact
  in the <8 frame.
  `docs/HAILO10H_VARYING_GROUPS_DEVIANTS_CENTRE_SETS_2026-10-24.md`.

- [x] Slice4.116 the mirror
  pair 5ab3537d/773470cd
  anatomised (how deep the
  mirroring goes across the
  shared enumeration —
  shared groups, cells and
  centre distributions —
  and where the pair
  diverges, its <8 centre
  sets included); the 10
  steady exceptions of
  trains 48/50/51 given
  train 49's head-act
  treatment (does an extra
  head act mark them too?);
  and the <8-only high
  centres (>=192) per
  artifact, with
  cc9b9d1c's 199-255 cluster
  and 255's >=8-absence in
  0a0d378c; then broad
  ordinary UNMODIFIED
  source-model support100%.
  DONE (AES-NUM-116): on the
  2,981 shared cells the pair
  is centre-perfect (centres
  equal 2,981/2,981 and
  48,988/48,988 per instance,
  zero differing centre
  lists; words equal
  2,885/2,981, 96 cells
  centre-equal but
  word-different); the pair
  diverges by membership
  (only-A 3,989 cells,
  only-B 4,504; 2,171 shared
  triples with different
  cidx tuples) and by its
  <8 centre sets (13 a
  strict subset of 21),
  the >=8 set verified
  identical at 13 values.
  The 10 exceptions are
  nine at +1 and one at -1
  (train 50 rank 26 — the
  inherited "all +1" wording
  corrected); all ten carry
  an identical triple block
  and a head mark, the
  head-act explanation
  covering 7 measured (train
  49's form at train 48
  ranks 11/12) and 3 head-
  marked but unshifted
  (NOT PROVEN). No centre
  >=192 occurs at >=8
  anywhere; 23 values live
  in 49 <8 cells (cc9b9d1c
  38 cells / 20 values, all
  group size 2), and 255's
  >=8 absence in 0a0d378c is
  the same small-group
  rarity.
  `docs/HAILO10H_MIRROR_PAIR_TRAIN_EXCEPTIONS_HIGH_CENTRES_2026-10-24.md`.

- [x] Slice4.117 the mirror
  pair's 2,171 membership-
  divergent triples
  anatomised; the 37
  A-unanimous-but-not-B
  shared cells and the 96
  centre-equal word-
  different shared cells
  resolved to instances and
  lanes; and the three
  unshifted exceptions
  settled as far as head
  material decides DONE
  (AES-NUM-117): the
  divergent triples are
  mostly both-sides-
  different (1,997 of
  2,171; A-only-extra 92,
  B-only-extra 82) with
  gross extras per triple
  mode 9 (15,252 extras in
  all; A 7,164, B 8,088)
  and net length difference
  centred near 0 (+1 mode);
  common instances agree on
  centre 15,488/15,488.
  Inserted centres CONTINUE
  the common centre
  sequence wherever it is
  thick: UNANIMOUS-common
  extras CONT 11,795 /
  BREAK 373; NONAP extras
  never BREAK (CONT 599 /
  INDET 1,500); AP-common
  extras are a thin mostly-
  breaking family (CONT 17
  / BREAK 103 of 120);
  triple grades all-CONT
  1,679, any-BREAK 72,
  INDET 420. The 37 are
  three exact families: 13
  size-2 cells with 1
  breaker at index 0; 9
  size-27 centre-127 cells
  with the same 13 breakers
  at [2,4,8,9,10,11,12,13,
  14,17,18,24,25]; 15
  size-28 cells where B's
  word differs at 27 of 28
  instances and only index
  0 keeps A's word. All 535
  breakers are shared
  instances (0 membership),
  centres equal 535/535,
  lanes lane 0 (431) or
  lane 3 (104) only, 1 byte
  in 470. The 96 carry
  1,971 differing instances
  (60 cells differ at all
  27) and the centre lane
  differs in 0. Train 48
  ranks 1-2 share NO head
  material (prefix 0,
  suffix 0, equal positions
  none; shared-anomaly test
  empty) — two independent
  head anomalies, one shared
  anomaly NOT PROVEN. Train
  50 rank 26's head is one
  act shorter in count
  (6 vs 7) but the deletion
  alignment is empty — not
  a steady head minus an
  act; the -1 mechanism
  stays NOT PROVEN.
  `docs/HAILO10H_DIVERGENT_TRIPLES_BROKEN_UNANIMITY_UNSHIFTED_HEADS_2026-10-24.md`.

- [x] Slice4.118 thickness-
  graded continuation
  verdicts for the 2,171
  divergent triples; the
  37/96 differing words
  identified across
  artifacts; and the three
  unshifted heads' unique
  acts searched corpus-wide
  in cc9b9d1c DONE
  (AES-NUM-118): EVERY
  break rests on a common
  sequence of length 1 or
  2 — at length >=3 there
  are NO breaks in 11,952
  extras (CONT 10,452 /
  INDET 1,500); all 373
  unanimous breaks sit on
  a single shared instance
  (unanimous at length >=2
  continues 10,541/10,541)
  and all 103 AP breaks on
  a two-instance sequence
  (nine (71,19392) triples
  with common (38,44) step
  6, 11 breaks each, plus
  one (15,32608) triple,
  step 38, 4 breaks); the
  72 any-BREAK triples are
  62 at length 1 + 10 at
  length 2, listed in full
  with reasons. B's
  differing word is NO
  other artifact's word at
  the same group in any of
  the 1,971 differing
  instances (0 at group,
  cell, same-cidx and
  same-idx level; the A
  word 0 as control); the
  28-instance first-
  instance pattern appears
  in no other pair (no
  other pair shares even
  one cell) and counts 29
  cells inside the mirror
  pair (15 unanimous family
  + 14 DISTINCT/DISTINCT);
  44 of the 60 27-differing
  cells share a group with
  the 37 and 15 of the 60
  ARE family-3 cells. Of
  the three heads' 21
  unique-act entries, five
  acts in train 48 rank 2's
  head occur NOWHERE else
  in cc9b9d1c, and only
  three distinct unique
  acts head any other
  context; every opening
  pair occurs exactly once
  corpus-wide.
  `docs/HAILO10H_THICKNESS_GRADED_VERDICTS_WORD_IDENTITY_UNIQUE_HEAD_ACTS_2026-10-24.md`.

- [x] Slice4.119 the thin-
  common triples' extras
  read as sequences in
  their own right;
  lane-level cross-artifact
  identity for the 37/96
  differing words and a
  context/ng census; and
  train 48 rank 2's five
  cc9-unique acts (and its
  whole head) searched
  across all seven artifacts
  DONE (AES-NUM-119): the
  thin extras form NO
  progression of their own
  -- where they continue
  they are constant repeats
  of the common centre
  (253/315 at length 1;
  58/58 at length 2
  unanimous, 696/696
  extras), never strictly
  alternating with the
  common sequence (0/383),
  and the AP extras are not
  arithmetic (strict-AP
  1/10, step 0 vs common
  38, never the common
  step). Every differing
  lane is novel: 0/2,584
  differing B lanes occur
  in any other artifact at
  group/cell/same-cidx/
  same-idx level (A control
  1/2,584 group only),
  while non-differing lanes
  recur normally. The
  census: the mirror pair
  alone shares the skeleton
  -- identical contexts
  219/219, identical ng
  sizes {95,124}, 2,890
  identical-cidx-tuple
  groups, 5,152 shared
  triples (next best 41),
  2,981 shared cells (all
  other pairs 0). The five
  acts are CORPUS-unique:
  each exactly once in all
  seven artifacts (cc9
  cidx 144, own head
  position), heading no
  context; the whole head,
  its 512-run, its 7-tail
  and its opening pair each
  occur contiguously
  exactly once corpus-wide,
  no window within 2
  mismatches anywhere else.
  `docs/HAILO10H_THIN_EXTRAS_LANE_IDENTITY_FIVE_ACTS_2026-10-24.md`.

- [x] Slice4.120 the 62
  varying length-1 triples
  and the 9 varying AP
  triples against their
  continuing twins (centre
  sets, word sets, groups,
  gap shapes); the A->B
  differing-lane relation
  over the 2,584 differing
  lanes (is B's novel lane
  value a function of A's?);
  and train 48 rank 2's
  remaining head acts
  (positions 0, 5, 6) plus
  cidx 144's whole context
  against its train
  neighbours. DONE: the 62
  are distinguished by their
  common centre itself
  ({32, 40, 43, 51, 85, 122}
  DISJOINT from the 253's
  {0, 1, 2, 5, 15, 23, 34,
  69, 127}; groups/gaps/
  patterns identical; extras
  equal the centre 0/373 vs
  1,254/1,254); the 9 AP are
  clones except offset (same
  group, pair (38, 44), step
  6, gaps (7, 1, 4), same
  12-extra sequence); B is
  not a function of A pooled
  (52/934 counterexamples)
  nor in lanes 0/3/4, but
  lane 1 is a strict
  bijection (224<->224, 354
  lanes, 0 counterexamples)
  and the in-37 lanes are
  too (36<->36<->36, 535);
  head pos 0 occurs 7x (all
  cc9, heads 5 contexts),
  pos 5/6 exactly 2x each
  (144 + cidx 267, swapped);
  cidx 144 act-uniqueness
  ends at position 8 (counts
  1,060) but its prefixes
  stay unique through 40.
  `docs/HAILO10H_VARYING_THIN_LANE_FUNCTION_REMAINING_ACTS_2026-10-24.md`.

- [x] Slice4.121 the disjoint
  common-centre sets read
  corpus-wide (are {32, 40,
  43, 51, 85, 122} special
  in thick triples, >=8
  cells, other artifacts,
  against {0, 1, 2, 5, 15,
  23, 34, 69, 127}?); lane
  1's 224-pair bijection
  tabulated (affine,
  constant-XOR, or neither)
  and the in-37 bijection
  split per lane; cidx 267
  against cidx 144 (length,
  overlap, the 197-199
  window) and cidx 144's
  prefix uniqueness past
  length 40 to the first
  repeated prefix. DONE:
  the disjointness is exact
  only at thin length 1, but
  no varying centre ever
  anchors unanimity anywhere
  (0 unanimous centres at
  every other stratum, 0 of
  18,286 unanimous >=8
  cells, 0 unanimous-word
  cells in any artifact, at
  most once per cell), while
  every constant centre
  anchors it everywhere;
  lane 1's bijection has NO
  closed form (218 diffs,
  217 XORs, GF(2)-affine
  residuals 193/223); the
  in-37 bijection is
  per-lane (lane 0 29<->29
  over 431, lane 3 8<->8
  over 104, lanes 1/2/4
  zero); cidx 267 (842 acts)
  shares 36 acts with 144,
  the swapped pair isolated
  at 197/199, no head window
  >=2; cidx 144's prefixes
  stay unique through all
  245 acts (no repeat).
  `docs/HAILO10H_CENTRE_SETS_LANE1_FORMS_CIDX267_PREFIX_END_2026-10-24.md`.

- [x] Slice4.122 the varying
  centres as sequence
  members (position/step of
  32/40/43/51 inside the
  mid/thick common
  sequences) and the other
  single-centre anchors
  {7, 11, 95, 139} against
  the varying six; lane 1's
  224 pairs split by
  cell/group and byte 3's
  small-difference law as a
  function of A's byte 3;
  the +597 aligned region
  (144 pos 190-220 vs 267
  pos 787-817) read in full
  and cidx 267's own
  occurrence profile. DONE:
  varying members are start
  33 / interior 104 / END 0
  in 137 NONAP sequences,
  every local step already
  in the host's step set;
  40 is one rigid pattern
  (index 1, after 32, before
  44, steps (8, 4)); anchors
  7/11/95 are CONSTANT-LIKE
  (own-unanimous extras
  equality 41/41, 97/97,
  8/8) and 139 is NEITHER
  (no divergent triple, no
  extras, absent from the
  mirror pair, yet 28 per
  cell twice); lane 1's
  pairs live in 3 groups /
  16 cells — width is group
  (20, 32720)'s alone (216
  pairs/diffs/XORs), group
  (14, 9992)'s 5 pairs share
  ONE XOR; byte 3 NOT
  determined by A's byte 3
  (35/61 multi-valued; only
  0 -> +128 and 128 -> -128
  single); the region
  agrees 27 / differs 4
  (195/196/204/205, only
  component 1 differs); 267
  is far lonelier than 144
  (709/842 unique, mean
  14.88 vs 170/245, 49.26)
  on an identical high band
  (30 @271, 1 @1058, 2
  @1060).
  `docs/HAILO10H_VARYING_CENTRE_MEMBERS_ANCHORS_LANE1_SPLIT_ALIGNED_REGION_2026-10-24.md`.

- [x] Slice4.123 centre 139
  read in full (its 79
  cells, the two
  28-occurrence cells, its
  2 unanimous >=8 cells,
  its single non-divergent
  triple, its mirror cidx
  tuples) and anchors
  7/11/95 read as sequence
  members (position/step/
  neighbours in their
  mid/thick hosts); lane 1
  split the other way:
  group (20, 32720)'s 216
  pairs per offset block
  (6796-7272 step 68 —
  translates of each
  other?), group (14,
  9992)'s five repeated
  pairs in full (2 diffs,
  one shared XOR), byte 3
  retried as a function of
  (A byte 3, group) and of
  A's low bytes jointly;
  the region's two 2-act
  breaks against the
  corpus (the four 267-side
  break acts elsewhere;
  the 144-side break pairs
  as pairs) and cidx 130
  (111 of 267's 133
  non-unique acts) read
  against cidx 267 in full.
  DONE: the two 28-cells
  are ONE cell held
  identically by both
  mirror artifacts — key
  (21, 30768, 15368), same
  28 cidxs, same word in
  all 28 rows — and it is
  139's single
  non-divergent triple,
  its only mirror presence
  (divergent triples 0,
  extras 0); the other 77
  cells are DISTINCT, in
  0856a10c/76c3a8ff only,
  carrying 6 cidx tuples,
  with 139 always LAST in
  0856a10c (42/42) and
  always interior after
  130 in 76c3a8ff (35/35),
  centreword ff8b0000 in
  133/133; anchors 7/11/95
  as members obey the
  varying law — pooled
  non-unanimous hosts
  start 50 / interior 125
  / END 0, every local
  step in the host set (7
  always start, 11 always
  index 0/1, 95 always
  interior after 91);
  lane 1's wide group
  splits into 8 offset
  blocks pairwise DISJOINT
  in every projection (all
  intersections 0, pooled
  216 distinct throughout)
  with NO additive or XOR
  translate between them,
  while (14, 9992)'s five
  pairs and (19, 7712)'s
  three are pure SIGN
  FLIPS (XOR 0x80000000,
  diffs -2^31 x4 / +2^31
  x1); byte 3 NOT
  determined by (byte 3,
  group) — group adds
  nothing (same 35
  violating, all in (20,
  32720)) — nor by byte 3
  with any single low byte
  (byte 1 leaves 2 keys /
  4 pairs, byte 2 leaves 1
  key / 2 pairs), and the
  low three bytes jointly
  give 224 keys for 224
  pairs (injective only);
  the two 2-act breaks are
  breaks of the 144<->267
  alignment only — all 8
  acts solely in cc9b9d1c,
  267-side pairs in
  exactly 4 contexts {114,
  130, 251, 267} at
  792-793/801-802, 144-side
  pairs in exactly 27
  contexts at 195-196/
  204-205, reversed pairs
  0 — and cidx 130 is
  267's near-twin (842
  acts both, 709 unique
  each, identical high
  band) sharing 111 acts
  in IDENTICAL order (0
  inversions) in 19 runs,
  the longest 31 acts at
  identical positions
  787-817 CONTAINING both
  267-side break pairs.
  `docs/HAILO10H_CENTRE139_ANCHORS_MEMBERS_LANE1_BLOCKS_BYTE3_BREAKS_CIDX130_2026-10-24.md`.

- [x] Slice4.124 centre
  139's six DISTINCT-cell
  cidx-tuple families read
  as full centre sequences
  (the sequences 139 closes
  in 0856a10c and sits
  inside in 76c3a8ff) and
  the shared unanimous
  mirror cell (21, 30768,
  15368) read against the
  mirror pair's full
  shared-cell population;
  lane 1's byte-3
  near-misses in full (the
  6 pairs under the
  violating (byte 3, byte
  1) and (byte 3, byte 2)
  keys), f(A byte 3, A
  byte 1, A byte 2) tested
  exactly, and group (20,
  32720)'s per-cidx pair
  trajectories across its
  eight disjoint blocks
  (the same 27 contexts at
  eight offsets — what the
  offset changes); the
  four break contexts
  {114, 130, 251, 267}
  read against each other
  in full (lengths,
  profiles, pairwise
  shared acts and runs)
  and the non-shared spans
  between 130<->267's 19
  shared runs read in
  full. DONE: each of the
  six families carries
  exactly ONE centre
  sequence (the tuple
  determines it; a cidx
  carries the same centre
  in every family); the
  mirror cell is the
  UNIQUE single-centre-139
  cell among the pair's
  2,981 shared cells
  (2,386 both-unanimous;
  single-centre by centre
  15 x1708, 139 x1);
  byte 3's difference IS
  determined by (byte 3,
  byte 1, byte 2) - 222
  keys, 0 counterexamples,
  NOT injective (two
  narrow sign-flip keys
  carry two pairs each,
  differing only in
  byte 0); the five
  distinct near-miss pairs
  all sit in group
  (20, 32720)'s last two
  blocks; trajectories
  change every value at
  every step (8 distinct
  A/B/diff/XOR per cidx,
  nothing constant) yet A
  and B strictly increase
  with offset for all 27
  cidxs and all 189 steps
  on each side are
  positive and distinct;
  the four break contexts
  form two near-pairs
  ({114, 251} 168 shared
  acts / 21 runs; {130,
  267} 111 / 19) with
  cross-pairs at 37-40
  shared acts, the
  267-side pairs at
  792/801 in all four,
  the 144-side pairs'
  acts absent from all
  four, and 130x251 alone
  inverting (110 of 780);
  the spans between
  130<->267's runs total
  739 acts on EACH side
  (103 + 739 = 842) over
  20 spans, holding the
  8 isolated singles.
  `docs/HAILO10H_CENTRE139_FAMILIES_MIRRORPOP_BYTE3_TRAJECTORIES_BREAKCTX_SPANS_2026-10-24.md`.

- [x] Slice4.125 the
  (byte 3, byte 1, byte 2)
  determination read as a
  map (per-byte-3 tables
  over the 224 pairs;
  factoring through any
  arithmetic on
  (byte 1, byte 2)
  tested; the two narrow
  shared keys' byte-0
  freedom against all
  eight narrow pairs);
  group (20, 32720)'s
  trajectory steps as a
  population (the 189
  delta-A / delta-B /
  delta-diff triples per
  (cidx, block-step) in
  full; A at block k+1 as
  a function of A at
  block k over the 189
  steps); the four break
  contexts' common core
  (acts shared by all
  four, in order) in
  full, 114x251's shared
  population in full
  (168 acts, 21 runs, the
  54-act run), and
  130x251's 110 inversions
  localized to the
  specific shared acts
  that invert. DONE: the
  map spans 61 byte-3
  values with 24 distinct
  differences (modal -1
  x43; 168 negative / 14
  zero / 42 positive);
  60 of 61 byte-3 values
  have keys == pairs (only
  byte 3 = 128 splits,
  6 pairs / 4 keys); the
  difference is ALSO
  determined by (byte 3,
  byte 1 + byte 2) at the
  same 222 keys - no
  compression - while
  every other conditioned
  form fails on 1-12 keys
  and every direct formula
  fails on 202-224 pairs
  (closed form NOT
  PROVEN); the narrow
  byte 0 is free both
  ways (under each shared
  key it takes two values
  at the same difference,
  yet byte 0 = 20 and
  byte 0 = 68 each carry
  both signs, so byte 0
  alone determines
  nothing); the 189 step
  triples are pairwise
  distinct in every
  component, and each
  cidx's delta-A and
  delta-B sequences
  strictly decrease (27/27
  on both sides), while
  A(k+1) as a function of
  A(k) is VACUOUS (189
  distinct A values, zero
  collisions, per-step A
  sets pairwise disjoint;
  step source NOT
  PROVEN); the common
  core is exactly 37 acts
  (head 3-run + 34-act
  tail holding both
  267-side break pairs),
  order-identical in all
  four contexts (0 core
  inversions for every
  pair) and equal to the
  114x267 and 251x267
  shared sets; 114x251's
  168 shared acts sit at
  position difference 0
  for 93 of them, and the
  54-act run at identical
  positions 130-183 is
  made of acts occurring
  exactly twice in the
  whole corpus; 130x251's
  110 inversions are
  generated entirely by
  THREE displaced acts
  (130 positions 6, 7, 197
  standing at 251's
  positions 824, 822, 823;
  involvements 39, 38,
  35), every other shared
  act inverting only
  against those three
  (mechanisms NOT PROVEN).
  `docs/HAILO10H_BYTE3_MAP_STEPS_CORE_INVERSIONS_2026-10-24.md`.
  Then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.126 the
  (byte 3, byte 1 + byte 2)
  factoring's fibres in
  full and the map's
  difference fibres (the
  167 distinct (byte 3,
  difference) combinations
  against their 222 keys -
  which keys share a cell,
  and whether a fibre's
  (byte 1, byte 2) sets
  carry arithmetic
  structure); group
  (20, 32720)'s shrinking
  steps read as sequences
  (per-cidx delta-A /
  delta-B ratios and
  second differences in
  full over the 189 steps,
  stated decay forms
  tested exactly); the
  three displaced acts'
  corpus-wide profiles in
  full (all 8 occurrences
  each - artifacts,
  contexts, positions,
  neighbours), 251's
  closing segment
  (positions 818-841)
  against 130's head
  (positions 0-10) in
  full, and the
  occurrence-2 exclusivity
  population around the
  54-act run (acts
  occurring exactly twice
  in the corpus, both
  times in the 114/251
  pair). DONE: every one
  of the 222 factoring
  fibres carries exactly
  one distinct
  (byte 1, byte 2) pair
  (the two 2-pair fibres
  differ only in byte 0),
  so fibre arithmetic is
  vacuous; the 167
  difference cells hold
  32 multi-key cells, the
  16 two-key cells
  constant-gap only
  vacuously and all 16
  cells with >=3 keys
  failing the constant-gap
  test (gap gcd 1 in 13) -
  arithmetic structure NOT
  PROVEN; the 189 steps'
  324 ratios are pairwise
  distinct, all in (0, 1),
  and all 324 second
  differences are negative
  with exactly one
  repeated value
  (-38,363,136 at cidx 11
  and cidx 29, both
  k = 3, A side); each
  cidx's ratios span at
  most ~1.1e-6 yet decay
  forms F1-F5 all fail on
  every sequence (F1/F3/F5
  54 of 54 cidx-sides, F2
  161 of 162 per side, F4
  27 of 27 cidxs) - exact
  decay form NOT PROVEN;
  the three displaced acts
  live in exactly the same
  eight cc9b9d1c contexts,
  standing as the
  consecutive block D2,
  D3, D1 after the core's
  final act in 128, 251
  and 265; 251's closing
  segment and 130's head
  share exactly D1 and D2;
  the occurrence-2
  population is 127 of
  the 168 shared acts in
  24 runs, the 54-act run
  verified as RUN 8 with
  all 54 members in the
  population (mechanisms
  NOT PROVEN).
  `docs/HAILO10H_FIBRES_RATIOS_DISPLACED_PROFILES_2026-10-24.md`.
  Then broad ordinary
  UNMODIFIED
  source-model support100%.
- [x] Slice4.127 the
  (byte 3, byte 1 + byte 2)
  -> difference table read
  as a per-byte-3 function
  of the sum in full (per
  byte-3 keys ordered by
  sum, monotonicity and
  step structure tested
  exactly) and byte 0's
  own map over the 224
  pairs (A byte 0 ->
  B byte 0 in full, its
  determination status
  against the key); the
  near-geometric steps'
  wobble measured exactly
  (per-cidx ratio
  deviations from the
  sequence median in full;
  stated integer-rounding
  geometric forms tested
  exactly); the displaced
  trio's eight contexts in
  wider windows around
  every occurrence in
  full (the three block
  contexts against the
  five split contexts),
  the block's flanking
  acts profiled corpus-wide
  ((2817536, 24, 0) before
  the block,
  (1113626112, 24, 0)
  after it), and the 41
  shared 114x251 acts that
  are NOT occurrence-2
  read in full by
  occurrence-count class.
  DONE: the difference is
  NOT monotone in the sum
  (37 multi-key byte-3
  values: NEITHER 25,
  non-decreasing 8,
  non-increasing 2,
  constant 2; constant-step
  in 10 values, 8 of them
  two-key vacuous and the
  only >=3-key case being
  byte 3 = 128's constant
  -128) - per-byte-3 closed
  form NOT PROVEN; byte 0
  is determined by nothing
  tested (not A byte 0
  alone, 23 of 36 violate;
  not the full key, not
  the sum key - both fail
  on exactly the two
  narrow keys whose pairs
  differ only in byte 0);
  the wobble is never zero
  (0 of 324 ratios equal
  their median; max
  deviation ~0.839 ppm)
  and all six
  integer-rounding
  geometric forms fail on
  all 54 sequences
  (0 of 54 hold for any
  form x candidate) -
  exact decay form NOT
  PROVEN; the block
  contexts' +/-8 windows
  are the flanked core
  tail, the split contexts
  scatter the trio; the
  before-flank occurs once
  in each of 271 contexts,
  the after-flank exactly
  3 times, block-exclusive;
  the 41 acts fall in
  classes {3: 4, 4: 3,
  6: 1, 271: 30, 1058: 1,
  1060: 2} at position
  differences {0: 37,
  -1: 3, +4: 1}
  (mechanisms NOT PROVEN).
  `docs/HAILO10H_SUM_FUNCTION_BYTE0_WOBBLE_WINDOWS_2026-10-24.md`.
  Then broad ordinary
  UNMODIFIED
  source-model support100%.
- [x] Slice4.128 no ratio
  sequence is monotone in
  k (all 54 NEITHER,
  inversions 4-11 each
  way; 15 deviation sign
  patterns, modal +-+-+-
  x10); pooled steps 161
  in 32 values, step not
  a function of the sum
  pooled under either
  anchoring (27 violating
  sums each), per byte-3
  vacuous only; byte 0's
  failure localized to
  group (14, 9992)'s two
  narrow keys, the other
  two groups exact
  functions, all eight
  narrow pairs copy byte 0
  (XOR 0x80000000); the
  before-flank is
  end-anchored at
  from-end 20 in all 271
  contexts, followed by
  51 distinct (24, 0)
  acts (block-first only
  in the 3 block
  contexts); the 30
  class-271 acts hold
  identical order in 114
  and 251 (0 of 435
  inversions; 29 at diff
  0, lead at +4; 28 rigid
  with 20 positions, the
  first two 51/54); each
  after-flank following
  pair occurs consecutively
  exactly once corpus-wide
  (mechanisms NOT PROVEN).
  `docs/HAILO10H_RATIO_ORDER_STEP_CENSUS_BYTE0_GROUPS_FLANKS_2026-10-24.md`.
  Then broad ordinary
  UNMODIFIED
  source-model support100%.
- [x] Slice4.129 byte 0 IS
  determined by the full
  A word (extended key
  224 pairs / 224 keys /
  0 violations globally
  and per group; the key
  never repeats, the two
  narrow collisions split
  by A byte 0); identity
  is narrow-only (8/8
  narrow copy; beyond
  them 36 same / 180 diff,
  all in group (20,
  32720), differences
  -240..+240 in 40 values;
  all-pairs 44 same); the
  sides' sign patterns
  almost never relate
  (EQUAL 3, COMPLEMENT 0,
  REVERSE 1, COMP-OF-REV
  2 overlapping, NONE 23
  of 27); step NOT a
  function of (sum,
  starting diff) (5
  violating keys) and a
  function of (sum,
  byte 3) only vacuously
  (161 keys / 161 steps);
  the end block is fully
  rigid (28 acts constant
  from-end 54..20 in all
  271 contexts; all 27
  spacings constant:
  1 x24, 3 x2, 4 x1 into
  the before-flank); the
  loose pair floats (L0
  13 from-ends 55-87,
  distances 1-33; L1 12
  from-ends 55-68,
  distances 1-14), always
  before the block, order
  L1-before-L0 170 vs
  L0-before-L1 101
  (mechanisms NOT PROVEN).
  `docs/HAILO10H_BYTE0_EXTENDED_KEY_PATTERN_PAIRING_END_BLOCK_2026-10-24.md`.
  Then broad ordinary
  UNMODIFIED
  source-model support100%.
- [x] Slice4.130 the wide
  gaps are shape-constant
  but act-variable (gap 0:
  34 tuples, sizes (248,
  176) in all 271 contexts;
  gap 1: 30 tuples, (256,
  176); gap 2: 87 tuples,
  (328, 328, 328)); the
  loose distances do not
  determine each other
  (d1 = f(d0) fails 7/13
  keys; d0 = f(d1) 9/12);
  order is not a function
  of either distance alone
  (each fails only on its
  distance-4 key) but IS a
  function of (d0-d1) (19
  differences, 0 violating
  — the sign law); the
  distance-33 outlier is
  cidx 143 (L0 pos 518 /
  from-end 87, 32 large
  acts to the block, L1
  inside at distance 2);
  no proper sub-key
  separates the great
  group's byte-0 identity
  from rewriting with
  repetition to spare
  (two-byte keys near-miss
  on exactly one value
  each; (byte3, byte1,
  byte2) separates only by
  unique identification,
  216 values / 216 pairs);
  the byte-0 difference is
  not a function of A
  byte 0 (21 of 32 values
  violating) (mechanisms
  NOT PROVEN).
  `docs/HAILO10H_WIDE_GAPS_LOOSE_JOINT_SUBKEYS_2026-10-24.md`.
  Then broad ordinary
  UNMODIFIED
  source-model support100%.
- [x] Slice4.131 in the
  two-act gaps the second
  act IS an exact function
  of the first (gap 0: 34
  keys, gap 1: 30 keys, 0
  violating in either),
  though the offset is not
  constant (+248 in 187 of
  271 gap-0 contexts, +512
  in 46, negative in 38;
  +256 in 257 gap-1, +512
  in 8, negative in 6);
  in gap 2 no position is
  a function of an earlier
  one (7 of 70, 8 of 70,
  10 of 73 violating);
  every one of the 333
  distinct gap acts is
  gap-only corpus-wide;
  the outlier's 32-act run
  occurs exactly once (its
  own cidx 143) and 31 of
  its 32 acts occur exactly
  once corpus-wide (the
  exception being L1 at run
  index 30, 271 times), so
  no two run acts co-occur
  anywhere else; in modal
  contexts the distance-1
  loose act is followed by
  the first rigid act in
  every context (46/46,
  43/43); the four near-miss
  collisions are each
  exactly two pairs, two
  sharing the same identity
  pair; B byte 0 is NOT a
  function of any two-byte
  sub-key ((byte3, byte1)
  fails on exactly (249, 44)
  and (252, 84), (byte3,
  byte2) on exactly
  (249, 181), (byte1, byte2)
  on exactly (128, 146),
  (byte0, byte1) on 5 values,
  (byte0, byte3) on 27)
  (mechanisms NOT PROVEN).
  `docs/HAILO10H_GAP_FILLER_FUNCTIONS_OUTLIER_RUN_NEAR_MISS_2026-10-24.md`.
  Then broad ordinary
  UNMODIFIED
  source-model support100%.
- [x] Slice4.132 gap 2's
  broken chain in full
  (position-1 = f(position-0)
  fails 7 of 70 keys,
  (33312256, 328, 0) alone
  carrying 5 alternatives
  in 54 contexts;
  position-2 = f(position-0)
  8 of 70, that key carrying
  7 alternatives; position-2
  = f(position-1) 10 of 73);
  every violating key's
  carrying contexts share
  exactly one context length
  (and, the widest apart, one
  gap-0 and one gap-1 tuple),
  yet the alternatives split
  inside those families;
  gaps 0/1 wider lens: every
  repeating first act carries
  a contextual difference
  (22 of 22, 21 of 21 —
  always including the gap-2
  tuple) but its own tuple
  never differs, so the exact
  functions stand; the
  gap-only acts at offset
  level: exactly 1 of 333
  offsets is carried by
  another distinct act (the
  gap-2 act (120529920, 328,
  0) sharing its offset with
  (120529920, 32784, 0) in
  another artifact), and 0
  of 333 at (offset, size)
  level; the outlier run's
  31 unique acts likewise
  (0 of 31 at either level);
  B byte 0 against all four
  three-byte sub-keys is a
  function only by unique
  identification (216 values
  / 216 pairs, repetition 0,
  violating 0, every key);
  the identity pair
  A 682cb5f9 -> B 6884f5f8
  is the SAME side of both
  its status collisions and
  a singleton under every
  three-byte key (29 lines
  in hef132.out, 14 in the
  4.132 section) (mechanisms
  NOT PROVEN).
  `docs/HAILO10H_GAP2_CHAIN_OFFSET_LEVELS_THREEBYTE_2026-10-24.md`.
  Then broad ordinary
  UNMODIFIED
  source-model support100%.
- [x] Slice4.133 gap 2's
  chain against joint keys:
  NO joint key repairs it
  ((position-0, length) 70
  distinct keys — length adds
  none over position-0 alone —
  position-1 fails 7,
  position-2 8; (position-0,
  gap-0 tuple) and
  (position-0, gap-1 tuple)
  71 each, splitting only the
  widest first act into
  halves that still violate,
  failing 8 / 9;
  (position-0, loose order)
  73, failing 6 / 7, though
  (1098455040, 328, 0) and
  (961257984, 328, 0) fall
  silent there; the whole
  tuple as a function of
  (length, position-0) fails
  10 of 70, the union of the
  positions' failures); the
  offset-120529920 collision
  is offset-only (the gap
  act's 12 contexts identical
  in every printed feature;
  the large act's two
  5ab3537d contexts share
  ZERO distinct acts with
  each of them and contain
  no gap act at all);
  cross-size offsets with
  minimum size 328 number 19
  corpus-wide, not one; and
  beyond the great group
  exactly one three-byte key
  ever repeats without
  violating — (byte0, byte3,
  byte1) = (20, 128, 1)
  across groups, both pairs
  SAME at 20 — while
  (byte3, byte1, byte2) is
  NOT a function of the full
  224 pairs, failing on
  exactly its two repeated
  narrow values (mechanisms
  NOT PROVEN).
  `docs/HAILO10H_JOINT_KEYS_COLLISION_CENSUS_THREEBYTE_BEYOND_2026-10-24.md`.
  Then broad ordinary
  UNMODIFIED
  source-model support100%.
- [x] Slice4.134 gap 2's
  chain against compound
  joint keys: NO compound
  repairs it ((position-0,
  order, gap-0) and
  (position-0, order, gap-1)
  75 distinct each, failing
  6 / 7; (position-0, loose
  distances) 84 distinct —
  the strongest companion
  yet — failing only 3 / 4;
  the whole tuple as a
  function of (position-0,
  order) fails 9 of 73, the
  widest carrying 6 tuples
  under one order); the 19
  cross-size offsets hold
  exactly 19 distinct
  size-328 acts (one per
  offset): exactly ONE is a
  gap act (the target
  (120529920, 328, 0), gap-2
  position-0), NONE is
  class-271 / loose / rigid,
  18 are neither, and all
  21 partner acts are
  neither; and the two-byte
  cross-group sharings are
  exactly 7 values over the
  six sub-keys (agreeing
  (20, 1), (68, 1) and
  (20, 128), all small-group;
  violating (32, 1) — the
  only value touching the
  great group — (1, 176),
  (1, 0) and (1, 128); none
  under (byte0, byte2) or
  (byte2, byte3)); the
  agreeing three-byte pair's
  (byte1, byte3) projection
  is the widest violating
  value of all (mechanisms
  NOT PROVEN).
  `docs/HAILO10H_COMPOUND_JOINT_328POP_CROSSGROUP_2026-10-24.md`.
  Then broad ordinary
  UNMODIFIED
  source-model support100%.
- [x] Slice4.135 gap 2's chain against
  distance-compound joint
  keys: NO distance-
  compound repairs it
  ((position-0, distances,
  order) 84 distinct — the
  order adds NO key over
  the distances alone —
  failing 3 / 4, every
  violating key under
  L1-before-L0;
  (position-0, distances,
  gap-0) and (position-0,
  distances, gap-1) 86
  distinct each, failing
  only 2 / 3, a sister
  fill silencing exactly
  the widest key's (2, 4)
  branch; the whole tuple
  as a function of
  (position-0, distances)
  fails 4 of 84); the 19
  size-328 acts'
  occurrence geometry in
  full: every act confined
  to a single artifact, 18
  of 19 position-fixed,
  and the sole exception
  (791774208, 328, 0)
  fixed from the END
  (positions 725 / 727 in
  contexts of 749 / 751
  acts, position-from-end
  23 in both); their 21
  partners position-fixed
  in only 16 cases, all
  five twice-occurring
  partners moving and end-
  fixed neither; and the
  agreeing cross-group
  two-byte values' whole
  company is exactly their
  carriers ((20, 1) 3
  pairs, (68, 1) 2, (20,
  128) 2 — all SAME),
  while inside a single
  group NO three-byte
  value ever repeats
  agreeing under any key
  (the only agreeing
  three-byte repetition in
  the 224 pairs is the
  cross-group (20, 128, 1)
  itself; the only within-
  group repeats are the
  two violating (byte3,
  byte1, byte2) values of
  group (14, 9992))
  (mechanisms NOT PROVEN).
  `docs/HAILO10H_DISTCOMPO
  UND_GEOMETRY_PAIRCOMPANY
  _2026-10-24.md`. Then
  broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.136 gap 2's chain against the
  maximal compound joint
  key: NO maximal compound
  repairs it (86 distinct
  keys — the maximal key
  adds NO key over
  (position-0, distances,
  one sister) alone, and
  the violating sets are
  identical, 2 / 3; the
  whole tuple under either
  sister fails on the same
  3 keys); the end-
  anchoring census counted
  exactly (size-328 acts
  BOTH 18, END-ONLY 1 —
  the exception — partners
  BOTH 16 all trivially
  single-occurrence,
  NEITHER 5 exactly the
  twice-occurring ones;
  multi-occurrence split
  total: small acts
  anchored 9 of 9, partners
  0 of 5); the exception's
  two contexts share 689
  distinct acts of an 811
  union, only 126 at the
  same position, 563 at
  different positions; and
  B byte 0 answers to no
  two-byte sub-key inside
  any group (great group
  violates under all six
  keys — (byte0, byte3)
  34 repeats, 27 violating;
  group (14, 9992) byte-0
  keys never repeat and
  the rest repeat only
  violating; group
  (19, 7712) holds the one
  agreeing repeat (20, 1))
  (mechanisms NOT PROVEN).
  `docs/HAILO10H_MAXIMAL_C
  OMPOUND_ENDANCHOR_TWOBY
  TE_GROUPS_2026-10-24.md`.
  Then broad ordinary
  UNMODIFIED
  source-model support100%.
- [x] Slice4.137 gap 2's chain against the
  maximal compound joint
  key wed to the context
  length and to the gap's
  left position: NO wed
  repairs it (86 distinct
  keys under either wed —
  neither wed adds a key
  over the maximal key
  alone, so length and left
  position are each constant
  on every maximal family;
  violating sets identical,
  2 / 3 / 3, the violating
  keys carrying lengths
  245 / 606 / 873 and left
  positions 220 / 581 /
  848); the exception
  contexts' shared-act
  shift anatomy is exact
  (all 689 shared acts
  single-positioned in
  both; 69 distinct shifts
  −455..+434, +2 on 283,
  0 on 126, +3 on 55;
  466 positive, 97
  negative, 69 at |shift|
  ≥100; the 126 same-
  position acts at
  A-positions 2–614,
  clustered — sparse head,
  solid 242–270 block,
  dense 501–614 region
  ending solid 581–614;
  118 primary shift runs,
  longest 158 at +2 over
  A 26–183; 103 secondary
  runs); and B byte 0
  answers to no two-byte
  sub-key over the FULL
  224-pair population (63
  repeating values, 13
  agreeing, 50 violating;
  every key violates;
  (byte0,byte3) heaviest
  35 repeating, 27
  violating; only 7 of 63
  repeated values cross a
  group boundary, and
  (32,1) is the only one
  touching the great
  group) (mechanisms NOT
  PROVEN).
  `docs/HAILO10H_MAXIMAL_W
  ED_SHIFT_TWOBYTE_FULL
  _2026-10-24.md`. Then
  broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.138 the two wed redundancies
  CERTIFIED directly
  (context length IS a
  function of the maximal
  compound joint key — 86
  distinct, 15 repeating, 0
  violating; gap-2 left
  position IS a function —
  same counts; the maximal
  key wed to BOTH companions
  together still repairs
  nothing, 86 distinct,
  violating 2 / 3 / 3, the
  same keys with both wed
  values appended); the
  shift anatomy's long runs
  read act by act (exactly
  8 primary runs ≥20,
  carrying 394 of 689 acts:
  158/+2, 50/+2, 41/+3,
  37/+2, 34/0, 29/0, 25/0,
  20/−2 the only negative;
  the |shift| ≥100 tail is
  69 acts over 40 distinct
  shifts, 38 positive /
  31 negative; shift class
  by band of width 50 —
  totals ≤−10: 44, −9..−1:
  53, zero: 126, +1..+9:
  395, ≥+10: 71; bands
  50–149 purely +1..+9,
  550–599 purely zero,
  700–749 purely +1..+9);
  and B byte 0 against the
  six two-byte sub-keys wed
  to the group over the
  full 224 pairs (60
  repeating wed values, 11
  agreeing, 49 violating —
  no wed key is a function;
  the wed splits exactly
  the cross-group repeats)
  with the 13 agreeing
  repeats' status company
  (27 pairs with
  multiplicity: 19 SAME,
  8 DIFF; the 8 DIFF in
  exactly 4 great-group
  repeats, each pair-set
  sharing one nonzero diff
  +128 / −128 / +96 / +64)
  (mechanisms NOT PROVEN).
  `docs/HAILO10H_CERTIFIED
  _WED_LONGRUNS_WEDGROUP
  _2026-10-24.md`. Then
  broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.139 the loose and rigid
  positions CERTIFIED as
  functions of the
  doubly-wed key (L0, L1
  and R0 positions each:
  86 distinct, 15
  repeating, 0 violating);
  every further position
  wed still repairs
  nothing (86 distinct,
  violating 2 / 3 / 3, the
  same families with the
  certified position value
  appended); the long-run
  boundaries in full (16
  boundaries, all flanked,
  shift changes 4 zero /
  12 nonzero; 6 flank acts
  themselves tail acts);
  the tail cross-tabbed by
  band (sign-pure outside
  bands 350–449); the
  secondary runs ≥20
  exactly 7; and B byte 0
  against the four
  three-byte sub-keys wed
  to the group over the
  full 224 pairs (the
  three byte-0 keys
  injective, 0 repeats;
  (byte1, byte2, byte3)
  2 repeating, both
  violating) with the 11
  wed agreeing repeats'
  status company (22
  pairs: 14 SAME, 8 DIFF;
  7 purely SAME, 4 purely
  DIFF) (mechanisms NOT
  PROVEN).
  `docs/HAILO10H_DOUBLYWED
  _POSITIONS_BOUNDARIES
  _THREEBYTE_2026-10-24.md`.
  Then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.140 the artifact
  identity CERTIFIED as a
  function of the
  doubly-wed key (86
  distinct, 15 repeating, 0
  violating) and the
  context index NOT a
  function (all 15
  repeating keys violate);
  the artifact wed repairs
  nothing (86 distinct,
  violating 2 / 3 / 3, the
  same families with
  'cc9b9d1c' appended) and
  the cidx wed is vacuous
  (271 distinct, 0
  repeating); the
  secondary long runs'
  internal gaps almost all
  unit (431 gaps: 423 of
  size 1, only 8 larger,
  all in the three
  merging/extending runs);
  the 16 flanking acts
  classified (6 tail, 3
  same-position, 7
  neither); and B byte 0
  against the four
  three-byte sub-keys
  UNWED over the full 224
  pairs (two keys
  injective; (byte0, byte1,
  byte3) one agreeing
  cross-group repeat;
  (byte1, byte2, byte3)
  the same 2 violating
  repeats as wed) with the
  two wed violating
  repeats re-read against
  A byte 0 (B byte 0 = A
  byte 0 in all 4 pairs)
  (mechanisms NOT PROVEN).
  `docs/HAILO10H_ARTIFACT
  _CIDX_SECONDARYGAPS
  _FLANKS_UNWED
  _2026-10-24.md`.
  Then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.141 the cidx
  sets inside the 15
  repeating doubly-wed
  families are arithmetic
  (eight step-8 families
  pure progressions with
  residues 0-7 exactly
  once each; step-4
  families missing single
  lattice slots, three of
  one family's four
  missing slots exactly
  its sister family's
  whole set); the residue
  CERTIFIED as a function
  of the doubly-wed key
  (86 distinct, 15
  repeating, 0 violating),
  the quotient NOT a
  function (all 15
  violate), the residue
  wed repairing nothing
  (2 / 3 / 3) and the
  quotient wed vacuous
  (271 distinct); the
  acts at the 19 skipped
  A-positions of the 8
  non-unit secondary gaps
  ALL A-only (not in B at
  all, 19 of 19); and
  B byte 0 against the
  four three-byte sub-keys
  wed to the pair's status
  (two keys injective;
  (byte0, byte1, byte3)
  one agreeing repeat,
  the status wed not
  splitting it; (byte1,
  byte2, byte3) the same
  2 violating repeats,
  both SAME) with the
  unwed agreeing repeat's
  pairs re-read record by
  record (1 record against
  27, no shared record)
  (mechanisms NOT PROVEN).
  `docs/HAILO10H_CIDX
  _FAMILIES_SKIPPED_ACTS
  _STATUS_WED
  _2026-10-24.md`.
  Then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.142 every
  missing lattice slot is
  occupied (28 slots in
  four families, 22 by
  another repeating
  family's row, 6 by a
  singleton row, 0 empty;
  the [146…] family and
  its sister are mutual —
  18 of the sister's 19
  missing slots are the
  [146…] family's rows,
  and slot 182 is one
  singleton row filling
  both families); the
  B-side mirror is exact
  (B distance = A distance
  in all 8 gaps; the 19
  B-side skipped acts ALL
  B-only and corpus-unique,
  as are the 19 A-side
  skipped acts, one
  occurrence each); and
  B byte 0 against the
  four three-byte sub-keys
  wed to status AND group
  jointly earns no
  determination (three
  keys injective; (byte1,
  byte2, byte3) the same
  2 violating repeats;
  SAME-only repeats the
  pattern at subset scale,
  DIFF-only all injective;
  the violating pairs have
  B byte 0 = own A byte 0)
  (mechanisms NOT PROVEN).
  `docs/HAILO10H_MISSING
  _SLOTS_B_MIRROR_JOINT
  _WED_2026-10-24.md`.
  Then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.143 the
  missing-slot occupants
  are their slot families
  in everything but the
  loose distances and the
  tuple's third act
  (modal positions 0/1
  shared 28/28, position 2
  differing in 25, d0
  differing in 25, the
  two sets overlapping in
  23 only; singletons
  share 6/7 key components
  — loose distances only —
  except slot 184 at 5/7
  with the order too; slot
  182 shares 6/7 with both
  its families); the
  insertions side by side
  are size-identical in
  order at all 8 gaps
  (19/19) but channel-
  different at gaps 1–7
  (0/15, uniform per side)
  with zero offset
  differences, gap 8 alone
  channel-equal (4/4) at
  offset differences
  +404,667,368/+404,667,392
  (×3); and B byte 0 wed
  to status, group AND
  record count jointly
  earns no determination
  (three keys injective;
  (byte1, byte2, byte3)
  the same 2 violating
  repeats, all four pairs
  at 27 records; SAME-only
  repeats the pattern; the
  violating pairs differ
  only in the cell — 1744/
  6944 and 4336/9832 — with
  cidx/centre spans and
  poscat identical)
  (mechanisms NOT PROVEN).
  `docs/HAILO10H_OCCUPANTS
  _INSERTIONS_TRIPLEWED
  _2026-10-24.md`.
  Then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.144 the
  occupants match their
  OWN families' modal
  third act in all 28
  (slot modal matched
  only 3; position-2
  cross-tab (slot differs,
  own matches) 25, (both)
  3; repeating only 21/1);
  the own-family key
  match is identity by
  construction (d0
  cross-tab (slot differs,
  own equal) 25, repeating
  22/22, tautological on
  the own side); the
  per-gap channel mapping
  is NOT a function of
  the bounding acts
  (identical in both
  contexts, 16/16), the
  shifts or the distances
  (bounding-channel key
  (1, 0) violating at
  gaps 3 and 7; global
  paired map one-to-many
  in every channel); gap
  8's B-side insertion is
  a four-act 24 B block
  at offsets 1,196,444,160
  stepping 512, channels
  0, 1, 2, 0, in a region
  neither neighbour
  occupies; and B byte 0
  wed to status, group,
  record count AND cell
  jointly is injective
  under all four sub-keys
  (224 distinct, 0
  repeating — the cell
  splits the two violating
  repeats, 1744/6944 and
  4336/9832, each pair
  keeping its own byte)
  but earns no
  determination, while
  the cell as a companion
  is NOT a determinant
  (16 cells, 8 repeating
  all violating at 27
  pairs each in group
  (20, 32720); the third
  component alone the
  identical test; (cell,
  A byte 0) 36 violating)
  (mechanisms NOT PROVEN).
  `docs/HAILO10H_OWNFAMILY
  _GAPCHANNEL_CELLWED
  _2026-10-24.md`.
  Then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.145 gaps 3
  and 7 are the same gap
  twice over at their
  bounds (same run 74,
  shift 0, length 83,
  extents 524-614,
  bounding channels
  (1, 0), distances 2/2;
  32-feature table 13
  equal / 19 differing,
  every difference a
  location, an identity,
  or a skipped-act
  property; mappings
  ((2->0),) vs ((1->2),));
  the 8 violating cell
  repeats earn no rescue
  from any record-level
  companion over 216
  pairs (centre set the
  constant {127}, 1
  violating key; cidx
  set 27 all violating;
  poscat 3 all violating;
  (cidx, centre) seq 27
  all violating); and
  the quad-wed injectivity
  belongs to neither
  added companion (byte-0
  sub-keys: base wed
  already injective, both
  additions vacuous;
  (byte1, byte2, byte3):
  the 2 pair-pairs are
  separated by BOTH the
  cell and A byte 0, both
  separate 2, cell-only
  0, A-only 0) (mechanisms
  NOT PROVEN).
  `docs/HAILO10H_GAPS37
  _CELL_COMPANIONS_WED
  _DISSECTION_2026-10-24.md`.
  Then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.146 the
  per-gap channel mapping
  is NOT a function of
  the A-side skipped acts
  (sizes violating at
  gaps 3/5/6; residues
  mod 512 violating at
  gaps 3/5/6/7; count
  violating; channels and
  paired (size, channel)
  one agreeing repeat
  only, gaps 5/6); gaps
  3 and 7's skipped acts
  are corpus-unique (1
  occurrence each in the
  whole corpus); the 216
  earn no rescue from the
  remaining companions
  (idx sequence 27 all
  violating; in37 the
  constant (False,) 1
  violating; A byte 0 22
  repeating all
  violating; (cidx, idx)
  27 all violating; zero
  agreeing repeats in
  all eight single
  companions); and the
  two (byte1, byte2,
  byte3) pair-pairs are
  twins separated only
  by byte 0 (+4 in both
  groups; B byte 0 ==
  A byte 0 in all four)
  and the cell (thirds
  1744/6944, 4336/9832;
  35 differing / 171
  equal of 206 fields in
  both groups)
  (mechanisms NOT
  PROVEN).
  `docs/HAILO10H_SKIPPED
  _ACTS_REMAINING
  _COMPANIONS_PAIRPAIRS
  _2026-10-24.md`.
  Then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.147 the
  per-gap channel mapping
  as a function of the
  B-side skipped acts and
  the joint A/B skipped
  tuples over all 8 gaps,
  with gaps 3 and 7's
  skipped (offset, size)
  pairs read against the
  corpus channel-blind; B
  byte 0 over the 216
  violating-cell pairs
  against the JOINT
  companions of the eight
  exhausted singles
  ((idx sequence, A byte
  0), ((cidx, idx)
  sequence, A byte 0),
  (in37 pattern, A byte
  0), (idx sequence,
  in37 pattern)); and the
  two pair-pairs' byte-0
  step and cell-third
  step tested across
  every pair-pair sharing
  the (byte1, byte2,
  byte3) sub-key alone
  over the full 224
  pairs; then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.148 the two
  refining joints
  dissected over the 216
  (their 7 agreeing
  repeats in full; the
  two joints' pair-by-pair
  identity; (idx sequence,
  A byte 0) wed to the
  cell); the +4 byte-0
  step across every
  pair-pair sharing each
  of the other three
  three-byte sub-keys
  alone over the full 224;
  and the channel tuples
  wed to count and to
  sizes as determinants
  of the per-gap mapping
  over all 8 gaps; then
  broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.149 the 7
  agreeing repeats read
  record by record (each
  repeat's two pairs
  compared field by field,
  with the 35 violating
  repeats as control);
  the near-miss census
  for the two injective
  sub-keys (Hamming-1
  pair-pairs, byte-0 steps
  split by differing
  position); and gaps 5
  and 6 read in full
  against each other (the
  sole agreeing repeat of
  every mapping test, the
  AES-NUM-145 feature
  table); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.150 the 3
  control comparisons
  with the agreeing
  (12, 7) profile read
  in full (which repeat
  carries them; their
  differing seven against
  the agreeing seven);
  the 8 byte-0-differing
  near-miss pair-pairs
  read against each
  other (the +4 cases
  against the 8/12/64
  cases; the sub-keys'
  population overlap);
  and gap 4 read in full
  against gaps 5 and 6
  (feature tables; its
  four-long skipped block
  against their single
  skipped acts); then
  broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.151 the 6
  distinct byte-0
  near-miss pair-pairs
  as one population
  (the (14, 9992) ladder
  chain read against the
  full 224 — every pair
  sharing (byte1, byte3)
  = (1, 128)); the 50
  control comparisons
  decomposed by
  verdict-field pattern
  (B byte 0 only / status
  only / both / neither,
  status-only tested);
  and run 74's internal
  gaps as one sequence
  (steps 31, 33, 37) with
  skipped-block
  contiguity measured
  over all 8 gaps; then
  broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.152 gap 8's
  non-contiguous skipped
  block read in full
  against the contiguous
  blocks of gaps 1 and 2
  (its 512-stride 24-byte
  skipped acts; the
  A-side 488 first
  advance); the two
  (1, 128)-population
  pairs in no near-miss
  pair-pair (byte2 177 at
  byte0 20; byte2 160 at
  byte0 68) read against
  the four member pairs
  (their full sub-key
  neighbourhoods under
  both injective
  sub-keys); and run 74's
  remaining two gaps
  (3 at step 24, mapping
  ((2, 0),); 7 at step 48,
  mapping ((1, 2),)) read
  in full against gaps
  4, 5 and 6 (feature
  tables), completing
  run 74; then broad
  ordinary UNMODIFIED
  source-model
  support100%.
- [x] Slice4.153 gap 8's
  two skipped regions
  read against their
  contexts in full (every
  24-byte act at a 512
  stride around gap 8 in
  contexts A and B; side
  B's ladder at
  1,196,444,160 — wider
  ladder or isolated;
  where side A's ladder
  ends at the right
  bound); the
  byte2-differing
  Hamming-1 pair-pairs
  over the full 224 as a
  census (the mirror of
  the byte-0 census;
  listings, steps, and
  where the two
  non-members and the
  four members sit in
  it); and run 62's gaps
  1 and 2 read against
  each other (32-feature
  table), completing
  run 62; then broad
  ordinary UNMODIFIED
  source-model
  support100%.
- [x] Slice4.154 the two
  contexts' residue-0
  offset sets read in
  full against each
  other (37 distinct in
  context A vs 38 in
  context B: shared,
  A-only, B-only, and
  positional order);
  the byte2 census's hub
  pairs (individual pairs
  carrying >= 4 listings)
  read as one population;
  and run 102's single
  gap (gap 8) read
  against the run-62 /
  run-74 frame (the 9
  shared run-frame
  features) as a one-gap
  closure; then broad
  ordinary UNMODIFIED
  source-model
  support100%.
- [x] Slice4.155 the shared
  offsets' chain
  correspondence read in
  full (each A 512-chain
  against its B chains
  over the 25 shared
  offsets: surviving,
  splitting, merging);
  the hub closure's
  boundary (the 7 pairs
  carrying exactly 3
  listings, and the hub
  component's internal
  partner/degree
  structure); and gap 8
  read against run 74's
  gap 4 in full
  (32-feature table; the
  one split-kind match);
  then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.156 the surviving
  chains in context-position
  space (identical chains'
  rung positions in A vs B;
  the split 12-chain's two
  B fragments and the
  truncated 6-chain
  positionally); the three
  population as a graph in
  full (the 8 both-three
  listings as edges; the 5
  neither partners in full;
  second-component test);
  and the complete pairwise
  gap table (all 28 gap
  pairs on the 32 features);
  then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.157 the position-
  shift bands read in full
  (every shared act's shift
  as a function of position;
  the 0/+2 band boundary;
  the -7 singleton's
  neighbourhood); the one
  external listing (21) and
  its 1-listing partner in
  full (the leak's other
  side); and gaps 5 and 6
  in full (the maximum
  pair's 13 differing
  features); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.158 the +432/+434
  excursion at A positions
  184-191 in full (its 8
  acts and their flanks);
  the leaf chain's root
  (three 40f019ce in full;
  the chain leaf -> neither
  -> three as one graph);
  and gaps 3 x 5 and 3 x 6
  in full (the 15/32
  runners-up, completing
  run 74's top pairs); then
  broad ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.159 the excursion's
  B fragments in full (the
  B 616-625 neighbourhood:
  what sits around and
  between the +432 block,
  the in-place pair's B
  context, and the +434
  pair); the root triangle's
  two neither partners
  (4092dbce and 40fcb4ce)
  in full as a pair; and
  gap 4 in full (step 31,
  the one run-74 gap not
  yet read in full,
  completing run 74's five
  gaps); then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.160 the B 615
  intruder in full (the +93
  act at A 522; secondary
  run 72 at the seam); the
  partner-cell correspondence
  tested census-wide (every
  neither partner's cell vs
  the cells of the vertices
  it touches); and the
  first-skipped past-left-end
  values of all 8 gaps as
  one table (gap 4's 464 in
  the population); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.161 gap 8's
  B-side skipped population
  in full against its A side
  (its four B-side skipped
  acts, their B bounds, and
  each act's past-left-end
  against its own B
  neighbours); the (20,
  32720) 6864/6932 cell
  pair's full population
  (every pair carrying
  either cell, the induced
  listing graph, cell
  membership vs printed
  fields); and the seam
  runs 70/71/73's B
  neighbourhoods in full
  (B 276-290 and B 516-528);
  then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.162 gap 8's
  B-block offset region in
  full (offset ranks
  738-751, the B 674 offset
  predecessor's run); the
  6864/6932 split against
  the untested fields (full
  B value, byte1-byte3,
  byte3/full differences,
  XOR, factoring keys); and
  the seam's remaining
  displaced blocks (runs
  93, 19 and 20 in full;
  the B 280 singleton's A
  neighbourhood 668-674);
  then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.163 the top
  offset region's thirteen
  B-only acts against
  context A in full (each
  act's occurrence in A,
  its offset's rank in A's
  order, A's own top ranks
  in full); the 6864/6932
  split against the pairs'
  record-level fields
  (per-record cidx/idx/n/
  centre/poscat/in37
  sequences); and run 20's
  full context (A 276-300,
  B 301-310) plus runs
  92/94/95 in full; then
  broad ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.164 the offset-
  range boundary between
  the contexts in full
  (every B act above A's
  largest offset; the B
  rank where B passes it);
  the 6864/6932 split as a
  matched-pair comparison
  (the 6864 pair against
  the 6932 pair at each of
  the 27 shared cidx
  values); and runs
  21/22/23 and 46 in full;
  then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.165 the above-
  boundary population's
  B-position structure in
  full (the 30 acts in
  B-position order; the
  B 0-27 and B 747-750
  windows in full); the
  matched-pair byte3-
  difference confinement
  {14, 15, 16} against the
  remaining companions (the
  pairs' own byte3 values,
  cidx/idx order position,
  within-pair diffs, status);
  and runs 43/44/45 and
  47/48 in full; then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.166 the above
  population's B-position /
  offset-rank order relation
  in full (every adjacent
  pair in B-position order
  with its rank delta; the
  873M triple and the
  ceiling pair reversals
  against their full B
  neighbourhoods); the
  byte3-difference
  confinement against the
  matched pairs' remaining
  byte fields (byte0-byte2
  values and matched
  differences, each side,
  each cell); and runs
  42/53/60 and 61/62 in
  full; then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.167 run 62's
  two internal gaps in full
  (the B 447-448 and
  B 455-459 acts against
  both contexts in full;
  the skipped A acts at
  A 444-445 and A 452-456
  in full); the matched A
  byte2-difference to
  byte3-difference
  regularity against the
  wider pair population
  (all 224 pairs of the
  (20, 32720) group, and
  the other groups); and
  runs 65 and 67 in full;
  then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.168 the channel-
  disagreement correspondence
  across both full contexts
  (every A-only and B-only
  distinct act paired by
  (offset, size); the channel
  pairs; position correspondence;
  the unmatched residue in
  full); the per-ordered-cell-
  pair FUNCTION pattern in
  the great group (verdict
  against ordered-pair
  features; the never-
  contradicted keys -191/-145
  in the widened rows in
  full); and runs 63 and 64
  in full; then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.169 the 31
  correspondence pairs'
  position-delta law against
  neighbouring secondary-run
  shifts recomputed directly
  (the 10 exceptions in
  full); the unmatched
  residue's head-sequence
  relation (both heads aligned
  by position in full; the
  position-13 32,728/32,768
  split; offset differences
  at agreeing positions); and
  runs 68 and 69 in full;
  then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.170 the 31
  pairs' delta match-distance
  census (smallest run-order
  distance at which a run
  with shift == delta occurs,
  within three runs either
  side of both containing
  runs); the heads'
  offset-difference family
  structure (417-family
  differences against
  position/size/channel; the
  position-16 outlier in
  full; the 873-family
  relation across positions
  0/1/27); and runs 70 and
  71 in full; then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.171 the unbounded
  delta match-distance census
  for the eight NONE pairs
  (smallest distance over the
  full run table; every run
  whose shift equals their
  delta); the 417-family
  equal-diff pairing structure
  and the A-offset ordering
  of its positions (the
  position-16 A offset against
  every other head A offset);
  and runs 72 and 73 in full;
  then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.172 the full
  run-table shift census
  against the 31 pair deltas
  (every distinct shift with
  its runs; the NEVER deltas
  -205/-212 in full); the
  417-family A-offset ordering
  with position 16 removed
  and the (5, 6) reversal in
  full; and runs 74 and 75
  in full; then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.173 run 74's eight
  internal gaps in full (the
  delta-0 pairs inside its
  extent against the ninth at
  A 651); the head's three
  lowest A offsets (positions
  6, 16, 5) against the
  remaining 25; and runs 76
  and 77 in full; then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.174 the eight
  larger head gaps in full
  (rank pairs, positions
  separated, 417/diff status
  crossing each); the A
  640-660 placement region
  of the ninth delta-0 pair
  in full (runs 85 and 86
  against the seam at 651);
  and runs 78 and 79 in
  full; then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.175 the head's
  twelve non-417-family
  positions in full (nine
  of the twelve are diff-0
  identity acts; the other
  three (0, 1, 27) carry
  873-prefix B offsets, 0/1
  in reversed B order, 27
  the only size/channel
  mismatch); runs 84, 87
  and 88 in full; and runs
  80 and 81 in full (all
  five runs one contiguous
  B block each); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.176 the
  873-prefix trio's B-side
  placement (the three B
  acts are consecutive in
  B-offset order at ranks
  724-726, order 1, 0, 27,
  gaps 512/512, and are the
  only 873-prefix acts in
  either context; the 0/1
  reversal is the trio's
  only reversal, against
  107 inversions head-wide,
  41 involving a trio
  position); runs 82, 83
  and 89 in full; and runs
  90 and 91 in full (all
  five runs singletons, one
  contiguous B block each);
  then broad ordinary
  UNMODIFIED source-model
  support100%.
- [x] Slice4.177 the
  trio's B-offset-order
  flank acts in full (all
  four are B-only distinct
  with no A-side
  counterpart, at B
  indices 747-750, ranks
  722, 721, 723, 727);
  runs 92 and 93 in full;
  and runs 94 and 95 in
  full (run 92 a +1 pair,
  runs 93, 94 and 95
  singletons, all one
  contiguous B block
  each); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.178 the
  B-offset-order window's
  upper acts at ranks
  728-732 in full (all
  five are B-only distinct
  with no A-side
  counterpart, at B
  indices 5, 6, 8, 10,
  11) and its lower
  shared boundary at
  ranks 718-720 in full
  (three shared run-102
  acts at +2); runs 96
  and 97 in full; and
  runs 98 and 99 in full
  (all four runs
  singletons, one
  contiguous B block
  each); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.179 the
  B-offset-order acts
  above the window at
  ranks 733-736 in full
  (all four B-only distinct
  with no A-side
  counterpart, at B
  indices 13, 14, 15,
  16, consecutive in both
  orders, ranks 733-737
  one contiguous offset
  chain); runs 100 and 101
  in full (both singletons,
  one contiguous B block
  each); and run 102 in
  full (58 acts at +2 in
  TWO contiguous B blocks,
  B 685-734 and B 739-746,
  split by four B-only acts
  at B 735-738 and four
  A-only acts at A 733-736);
  then broad ordinary
  UNMODIFIED
  source-model support100%.
- [x] Slice4.180 the
  B-offset-order acts at
  ranks 737-742 in full
  (all six B-only distinct
  with no A-side
  counterpart, at B
  indices 17, 19, 20,
  22, 23, 25); the four
  B-only interrupter acts
  at B 735-738 in full
  (the last four acts in
  B-offset order, ranks
  747-750); and the four
  A-only acts at A 733-736
  in full (A-offset ranks
  740-743, same (size,
  channel) sequence as
  the interrupters, no
  shared act, key or
  offset); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.181 the
  B-offset-order acts at
  ranks 743-746 in full
  (all four B-only distinct
  with no A-side
  counterpart, at B
  indices 26, 229, 272,
  674); the A-only acts
  at A 745-747 in full
  (A-offset ranks
  745-747, no B-side
  counterpart or key);
  and the A-offset-order
  acts at ranks 744-748
  in full (one shared
  run-102 act at +2
  followed by four A-only
  acts closing both A
  orders); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.182 the
  three further B-only
  acts inside 4.181's
  B-index neighbourhoods
  in full: the act at
  B 27 (B-offset rank
  726, no A counterpart
  or key); the act at
  B 271 (B-offset rank
  29, no A counterpart
  or key); and the act
  at B 671 (B-offset
  rank 689, no exact A
  counterpart but its
  key held on the A
  side by A 670 on
  channel 1); then
  broad ordinary
  UNMODIFIED
  source-model support100%.
- [x] Slice4.183 the
  two other acts of
  B 27's offset triplet
  in full (B 1 rank 724;
  B 0 rank 725); the
  two further A-only
  acts inside A 670's
  A-index neighbourhood
  in full (A 673 rank
  710; A 675 rank 712);
  and the shared run-93
  act following both
  B 671 and A 670 in
  offset order in full
  ((791154688, 18448, 2)
  at A 671 / B 280);
  then broad ordinary
  UNMODIFIED
  source-model support100%.
- [x] Slice4.184 the
  B-only act at B 392
  in full ((791266816,
  32784, 2), B-offset
  rank 693, its key
  held on the A side
  by A 675 on channel
  1); the two B-only
  acts at B 5 (rank
  728) and B 6 (rank
  729) in full; and
  the shared run-94
  act following the
  run-93 act in both
  offset orders in
  full ((791173632,
  32784, 0) at A 672 /
  B 673); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.185 the
  B-only act at B 750
  in full ((973679616,
  24, 0), B-offset
  rank 727); the
  B-only act at B 8
  in full ((1196183040,
  32784, 1), rank 730,
  completing the
  +512/+512 triplet
  at ranks 728-730);
  and the shared
  run-95 act following
  the run-94 act in
  both offset orders
  in full ((791240192,
  26128, 1) at A 674 /
  B 676); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.186 the
  B-only act at B 10
  in full ((1196216320,
  7800, 2), B-offset
  rank 731); the
  B-only acts at B 11
  in full ((1196224120,
  344, 2), rank 732)
  and B 13 in full
  ((1196224512, 32768,
  1), rank 733); and
  the shared run-96
  act following the
  run-95 act in full
  ((791300096, 26128,
  2) at A 676 /
  B 393); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.187 the
  B-only act at B 14
  in full ((1196257280,
  14416, 1), B-offset
  rank 734); the
  B-only acts at B 15
  in full ((1196271696,
  376, 1), rank 735)
  and B 16 in full
  ((1196272072, 24,
  1), rank 736); and
  the shared run-97
  act following the
  run-96 act in full
  ((791326720, 32784,
  2) at A 677 /
  B 377); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.188 the
  B-only act at B 17
  in full ((1196272096,
  32728, 1), B-offset
  rank 737); the
  B-only acts at B 19
  in full ((1196304896,
  7712, 0), rank 738)
  and B 20 in full
  ((1196312608, 328,
  0), rank 739); and
  the shared run-98
  act following the
  run-97 act in full
  ((791360000, 26128,
  2) at A 678 /
  B 223); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.189 the
  B-only act at B 22
  in full ((1196313088,
  24848, 1), B-offset
  rank 740); the
  B-only acts at B 23
  in full ((1196337936,
  264, 1), rank 741)
  and B 25 in full
  ((1196338688, 30008,
  2), rank 742); and
  the shared run-99
  act following the
  run-98 act in full
  ((791386624, 32784,
  2) at A 679 /
  B 401); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.190 the
  B-only act at B 26
  in full ((1196368696,
  280, 2), B-offset
  rank 743); the
  B-only acts at B 229
  in full ((1196369408,
  26128, 2), rank 744)
  and B 272 in full
  ((1196396032, 14352,
  1), rank 745); and
  the shared run-100
  act following the
  run-99 act in full
  ((791419904, 32784,
  2) at A 680 /
  B 228); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.191 the
  B-only act at B 674
  in full ((1196410880,
  32784, 2), B-offset
  rank 746); the
  B-only acts at B 735
  in full ((1196444160,
  24, 0), rank 747)
  and B 736 in full
  ((1196444672, 24,
  1), rank 748); and
  the shared run-101
  act following the
  run-100 act in full
  ((3446784, 24,
  2) at A 682 /
  B 675); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.192 the
  B-only act at B 737
  in full ((1196445184,
  24, 2), B-offset
  rank 749); the
  B-only act at B 738
  in full ((1196445696,
  24, 0), rank 750,
  the last rank); and
  the shared run-102
  act following the
  run-101 act in
  A-index order in
  full ((791479296,
  32784, 1) at A 683 /
  B 685); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.193 the
  A-only act at A 681
  in full ((791452688,
  26128, 2), A-offset
  rank 718); the
  shared run-102 act
  at A 684 / B 686 in
  full ((791512080,
  32784, 1), A-offset
  rank 720, B-offset
  rank 700); and the
  shared run-102 act
  at A 685 / B 687 in
  full ((791544864,
  26128, 1), A-offset
  rank 721, B-offset
  rank 701); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.194 the
  shared run-102 act
  at A 686 / B 688 in
  full ((791570992,
  32784, 1), A-offset
  rank 722, B-offset
  rank 702); the
  shared run-102 act
  at A 687 / B 689 in
  full ((791603776,
  26128, 1), A-offset
  rank 723, B-offset
  rank 703); and the
  shared run-102 act
  at A 688 / B 690 in
  full ((791629904,
  32784, 1), A-offset
  rank 724, B-offset
  rank 704); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.195 the
  shared run-102 act
  at A 689 / B 691 in
  full ((791662688,
  26128, 1), A-offset
  rank 725, B-offset
  rank 705); the
  shared run-102 act
  at A 690 / B 692 in
  full ((791688816,
  32784, 1), A-offset
  rank 726, B-offset
  rank 706); and the
  shared run-102 act
  at A 691 / B 693 in
  full ((791721600,
  32784, 1), A-offset
  rank 727, B-offset
  rank 707); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.196 the
  shared run-102 act
  at A 692 / B 694 in
  full ((791754384,
  18448, 1), A-offset
  rank 728, B-offset
  rank 708); the
  shared run-102 act
  at A 693 / B 695 in
  full ((3415040,
  24, 1), A-offset
  rank 27, B-offset
  rank 27); and the
  shared run-102 act
  at A 694 / B 696 in
  full ((262144,
  376, 0), A-offset
  rank 0, B-offset
  rank 0); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.197 the
  shared run-102 act
  at A 695 / B 697 in
  full ((262656,
  24, 0), A-offset
  rank 1, B-offset
  rank 1); the
  shared run-102 act
  at A 696 / B 698 in
  full ((262680,
  24, 0), A-offset
  rank 2, B-offset
  rank 2); and the
  shared run-102 act
  at A 697 / B 699 in
  full ((262704,
  72, 0), A-offset
  rank 3, B-offset
  rank 3); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.198 the
  shared run-102 act
  at A 698 / B 700 in
  full ((262776,
  24, 0), A-offset
  rank 4, B-offset
  rank 4); the
  shared run-102 act
  at A 699 / B 701 in
  full ((791773184,
  248, 0), A-offset
  rank 729, B-offset
  rank 709); and the
  shared run-102 act
  at A 700 / B 702 in
  full ((791773432,
  176, 0), A-offset
  rank 730, B-offset
  rank 710); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.199 the
  shared run-102 act
  at A 701 / B 703 in
  full ((263680,
  816, 0), A-offset
  rank 5, B-offset
  rank 5); the
  shared run-102 act
  at A 702 / B 704 in
  full ((264496,
  24, 0), A-offset
  rank 6, B-offset
  rank 6); and the
  shared run-102 act
  at A 703 / B 705 in
  full ((264520,
  24, 0), A-offset
  rank 7, B-offset
  rank 7); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.200 the
  shared run-102 act
  at A 704 / B 706 in
  full ((264544,
  416, 0), A-offset
  rank 8, B-offset
  rank 8); the
  shared run-102 act
  at A 705 / B 707 in
  full ((264960,
  96, 0), A-offset
  rank 9, B-offset
  rank 9); and the
  shared run-102 act
  at A 706 / B 708 in
  full ((265056,
  24, 0), A-offset
  rank 10, B-offset
  rank 10); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.201 the
  shared run-102 act
  at A 707 / B 709 in
  full ((265080,
  24, 0), A-offset
  rank 11, B-offset
  rank 11); the
  shared run-102 act
  at A 708 / B 710 in
  full ((791773696,
  256, 0), A-offset
  rank 731, B-offset
  rank 711); and the
  shared run-102 act
  at A 709 / B 711 in
  full ((791773952,
  176, 0), A-offset
  rank 732, B-offset
  rank 712); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.202 the
  shared run-102 act
  at A 710 / B 712 in
  full ((265728,
  176, 0), A-offset
  rank 12, B-offset
  rank 12); the
  shared run-102 act
  at A 711 / B 713 in
  full ((265904,
  344, 0), A-offset
  rank 13, B-offset
  rank 13); and the
  shared run-102 act
  at A 712 / B 714 in
  full ((266248,
  584, 0), A-offset
  rank 14, B-offset
  rank 14); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.203 the
  shared run-102 act
  at A 713 / B 715 in
  full ((266832,
  824, 0), A-offset
  rank 15, B-offset
  rank 15); the
  shared run-102 act
  at A 714 / B 716 in
  full ((267656,
  24, 0), A-offset
  rank 16, B-offset
  rank 16); and the
  shared run-102 act
  at A 715 / B 717 in
  full ((267680,
  24, 0), A-offset
  rank 17, B-offset
  rank 17); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.204 the
  shared run-102 act
  at A 716 / B 718 in
  full ((267704,
  96, 0), A-offset
  rank 18, B-offset
  rank 18); the
  shared run-102 act
  at A 717 / B 719 in
  full ((267800,
  176, 0), A-offset
  rank 19, B-offset
  rank 19); and the
  shared run-102 act
  at A 718 / B 720 in
  full ((267976,
  672, 0), A-offset
  rank 20, B-offset
  rank 20); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.205 the
  shared run-102 act
  at A 719 / B 721 in
  full ((268648,
  24, 0), A-offset
  rank 21, B-offset
  rank 21); the
  shared run-102 act
  at A 720 / B 722 in
  full ((268672,
  120, 0), A-offset
  rank 22, B-offset
  rank 22); and the
  shared run-102 act
  at A 721 / B 723 in
  full ((268792,
  24, 0), A-offset
  rank 23, B-offset
  rank 23); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.206 the
  shared run-102 act
  at A 722 / B 724 in
  full ((268816,
  64, 0), A-offset
  rank 24, B-offset
  rank 24); the
  shared run-102 act
  at A 723 / B 725 in
  full ((268880,
  24, 0), A-offset
  rank 25, B-offset
  rank 25); and the
  shared run-102 act
  at A 724 / B 726 in
  full ((268904,
  216, 0), A-offset
  rank 26, B-offset
  rank 26); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.207 the
  shared run-102 act
  at A 725 / B 727 in
  full ((791774208,
  328, 0), A-offset
  rank 733, B-offset
  rank 713); the
  shared run-102 act
  at A 726 / B 728 in
  full ((791774536,
  328, 0), A-offset
  rank 734, B-offset
  rank 714); and the
  shared run-102 act
  at A 727 / B 729 in
  full ((791774864,
  328, 0), A-offset
  rank 735, B-offset
  rank 715); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.208 the
  shared run-102 act
  at A 728 / B 730 in
  full ((3418112,
  24, 0), A-offset
  rank 28, B-offset
  rank 28); the
  shared run-102 act
  at A 729 / B 731 in
  full ((791775232,
  24, 0), A-offset
  rank 736, B-offset
  rank 716); and the
  shared run-102 act
  at A 730 / B 732 in
  full ((791775744,
  24, 1), A-offset
  rank 737, B-offset
  rank 717); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.209 the
  shared run-102 act
  at A 731 / B 733 in
  full ((791776256,
  24, 2), A-offset
  rank 738, B-offset
  rank 718); the
  shared run-102 act
  at A 732 / B 734 in
  full ((791776768,
  24, 0), A-offset
  rank 739, B-offset
  rank 719); and the
  index-order divergence
  at A 733 ((791776792,
  24, 0), A-only,
  A-offset rank 740)
  and B 735
  ((1196444160, 24, 0),
  B-only, B-offset
  rank 747) in full;
  then broad ordinary
  UNMODIFIED
  source-model support100%.
- [x] Slice4.210 the
  A-only run-102 act
  at A 734 in
  full ((791777280,
  24, 1), A-offset
  rank 741); the
  B-only run-102 act
  at B 736 in
  full ((1196444672,
  24, 1), B-offset
  rank 748); and the
  shared resync act
  at A 737 / B 739 in
  full ((768609280,
  24, 0), A-offset
  rank 33, B-offset
  rank 34); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.211 the
  act at A 745 in
  full ((791779328,
  24, 0)); the
  act at B 747 in
  full ((791781888,
  24, 0)); and the
  tail ends
  A 746-748 /
  B 748-750 in
  full; then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.212 the
  B-offset-order
  successors of the
  B tail in full:
  the act at B 1
  ((873198592, 24, 0),
  B-offset rank 724);
  the act at B 0
  ((873199104, 24, 1),
  B-offset rank 725);
  and the acts at
  B 27 ((873199616,
  24, 2), rank 726)
  and B 5
  ((1196182016, 24, 2),
  rank 728), with the
  B-offset-order run
  of ranks 721-728 in
  full; then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.213 the
  act at B 6 in
  full ((1196182528,
  24, 0), B-offset
  rank 729); the
  act at B 8 in
  full ((1196183040,
  32784, 1), B-offset
  rank 730); and the
  act at B 10 in
  full ((1196216320,
  7800, 2), B-offset
  rank 731), with the
  B-offset-order run
  of ranks 729-736 in
  full; then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.214 the
  act at B 17 in
  full ((1196272096,
  32728, 1), B-offset
  rank 737); the
  act at B 19 in
  full ((1196304896,
  7712, 0), B-offset
  rank 738); and the
  act at B 20 in
  full ((1196312608,
  328, 0), B-offset
  rank 739), with the
  B-offset-order run
  of ranks 737-744 in
  full; then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.215 the
  act at B 272 in
  full ((1196396032,
  14352, 1), B-offset
  rank 745); the
  act at B 674 in
  full ((1196410880,
  32784, 2), B-offset
  rank 746); and the
  act at B 735 in
  full ((1196444160,
  24, 0), B-offset
  rank 747), with the
  B-offset-order run
  of ranks 745-750 in
  full; then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.216 the
  act at B 736 in
  full ((1196444672,
  24, 1), B-offset
  rank 748); the
  act at B 737 in
  full ((1196445184,
  24, 2), B-offset
  rank 749); and the
  act at B 738 in
  full ((1196445696,
  24, 0), B-offset
  rank 750), with the
  B-offset-order
  closure in full;
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.217 the
  act at A 746 in
  full ((791779840,
  24, 1), A-offset
  rank 746); the
  act at A 747 in
  full ((791780352,
  24, 2), A-offset
  rank 747); and the
  act at A 748 in
  full ((791780864,
  24, 0), A-offset
  rank 748), with the
  A-offset-order
  closure in full;
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.218 the
  act at B 748 in
  full ((791781376,
  24, 1), B-offset
  rank 721); the
  act at B 749 in
  full ((800053760,
  24, 2), B-offset
  rank 723); and the
  act at B 750 in
  full ((973679616,
  24, 0), B-offset
  rank 727), with the
  B-index-order
  closure in full;
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.219 the
  act at B 747 in
  full ((791781888,
  24, 0), B-offset
  rank 722); the
  act at B 1 in
  full ((873198592,
  24, 0), B-offset
  rank 724); and the
  act at B 0 in
  full ((873199104,
  24, 1), B-offset
  rank 725);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.220 the
  act at B 27 in
  full ((873199616,
  24, 2), B-offset
  rank 726); the
  act at B 5 in
  full ((1196182016,
  24, 2), B-offset
  rank 728); and the
  act at B 6 in
  full ((1196182528,
  24, 0), B-offset
  rank 729);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.221 the
  act at B 8 in
  full ((1196183040,
  32784, 1), B-offset
  rank 730); the
  act at B 10 in
  full ((1196216320,
  7800, 2), B-offset
  rank 731); and the
  act at B 11 in
  full ((1196224120,
  344, 2), B-offset
  rank 732);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.222 the
  act at B 13 in
  full ((1196224512,
  32768, 1), B-offset
  rank 733); the
  act at B 14 in
  full ((1196257280,
  14416, 1), B-offset
  rank 734); and the
  act at B 15 in
  full ((1196271696,
  376, 1), B-offset
  rank 735);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.223 the
  act at B 16 in
  full ((1196272072,
  24, 1), B-offset
  rank 736); the
  act at B 17 in
  full ((1196272096,
  32728, 1), B-offset
  rank 737); and the
  act at B 19 in
  full ((1196304896,
  7712, 0), B-offset
  rank 738);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.224 the
  act at B 20 in
  full ((1196312608,
  328, 0), B-offset
  rank 739); the
  act at B 22 in
  full ((1196313088,
  24848, 1), B-offset
  rank 740); and the
  act at B 23 in
  full ((1196337936,
  264, 1), B-offset
  rank 741);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.225 the
  act at B 25 in
  full ((1196338688,
  30008, 2), B-offset
  rank 742); the
  act at B 26 in
  full ((1196368696,
  280, 2), B-offset
  rank 743); and the
  act at B 229 in
  full ((1196369408,
  26128, 2), B-offset
  rank 744);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.226 the
  act at B 272 in
  full ((1196396032,
  14352, 1), B-offset
  rank 745); the
  act at B 674 in
  full ((1196410880,
  32784, 2), B-offset
  rank 746); and the
  act at B 735 in
  full ((1196444160,
  24, 0), B-offset
  rank 747);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.227 the
  act at B 736 in
  full ((1196444672,
  24, 1), B-offset
  rank 748); the
  act at B 737 in
  full ((1196445184,
  24, 2), B-offset
  rank 749); and the
  act at B 738 in
  full ((1196445696,
  24, 0), B-offset
  rank 750);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.228 the
  B-offset-order
  closure in full
  (ranks 745-750
  and the closing
  run 743-750 on
  closure terms);
  and the full-order
  census over
  B-offset order
  (B acts 751,
  ranks 0-750, first
  and last acts,
  class census over
  all 751 acts in
  that order);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.229 the
  act at B-offset
  rank 0 in full
  ((262144, 376, 0)
  at B 696, rank 0,
  no incoming gap);
  the A-offset-order
  closure in full
  (its last six
  ranks and the
  closing run of
  its last eight
  ranks); and the
  full-order census
  over A-offset
  order (A acts 749,
  first and last
  acts, class census
  over all A acts in
  that order);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.230 the
  act at A-offset
  rank 748 in full
  ((791780864, 24, 0)
  at A 748, last
  measured A rank,
  no outgoing gap);
  the act at A-offset
  rank 744 in full
  ((791778816, 24, 0)
  at A 744, the
  closing run's sole
  shared act and
  run 102's last
  act); and the
  cross-order census
  comparison in full
  (the A-offset and
  B-offset censuses
  side by side);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.231 the
  act at B-offset
  rank 750 in full
  ((1196445696, 24, 0)
  at B 738, last
  measured B rank,
  no outgoing gap);
  the act at B-offset
  rank 743 in full
  ((1196368696, 280, 2)
  at B 26, the B
  closing run's first
  act); and the
  closing-run comparison
  in full (the A
  closing run and the
  B closing run side
  by side);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.232 the
  act at B-offset
  rank 742 in full
  ((1196338688, 30008, 2)
  at B 25, the act
  immediately before
  the B closing run's
  first act); the
  act at A-offset
  rank 741 in full
  ((791777280, 24, 1)
  at A 734, the A
  closing run's first
  act); and the
  closing-run first-act
  comparison in full
  (the two closing
  runs' first acts
  side by side);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.233 the
  act at A-offset
  rank 742 in full
  ((791777792, 24, 2)
  at A 735, the A
  closing run's second
  act); the act at
  B-offset rank 744
  in full
  ((1196369408, 26128, 2)
  at B 229, the B
  closing run's second
  act); and the
  closing-run second-act
  comparison in full
  (the two closing
  runs' second acts
  side by side);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.234 the
  act at A-offset
  rank 743 in full
  ((791778304, 24, 0)
  at A 736, the A
  closing run's third
  act); the act at
  B-offset rank 745
  in full
  ((1196396032, 14352, 1)
  at B 272, the B
  closing run's third
  act); and the
  closing-run third-act
  comparison in full
  (the two closing
  runs' third acts
  side by side);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.235 the
  act at A-offset
  rank 744 in full
  ((791778816, 24, 0)
  at A 744, the A
  closing run's fourth
  act); the act at
  B-offset rank 746
  in full
  ((1196410880, 32784, 2)
  at B 674, the B
  closing run's fourth
  act); and the
  closing-run fourth-act
  comparison in full
  (the two closing
  runs' fourth acts
  side by side);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.236 the
  act at A-offset
  rank 745 in full
  ((791779328, 24, 0)
  at A 745, the A
  closing run's fifth
  act); the act at
  B-offset rank 747
  in full
  ((1196444160, 24, 0)
  at B 735, the B
  closing run's fifth
  act); and the
  closing-run fifth-act
  comparison in full
  (the two closing
  runs' fifth acts
  side by side);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.237 the
  act at A-offset
  rank 746 in full
  ((791779840, 24, 1)
  at A 746, the A
  closing run's sixth
  act); the act at
  B-offset rank 748
  in full
  ((1196444672, 24, 1)
  at B 736, the B
  closing run's sixth
  act); and the
  closing-run sixth-act
  comparison in full
  (the two closing
  runs' sixth acts
  side by side);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.238 the
  act at A-offset
  rank 747 in full
  ((791780352, 24, 2)
  at A 747, the A
  closing run's seventh
  act); the act at
  B-offset rank 749
  in full
  ((1196445184, 24, 2)
  at B 737, the B
  closing run's seventh
  act); and the
  closing-run seventh-act
  comparison in full
  (the two closing
  runs' seventh acts
  side by side);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.239 the
  act at A-offset
  rank 748 in full
  ((791780864, 24, 0)
  at A 748, the A
  closing run's eighth
  and last act,
  terminal in A-offset
  order); the act at
  B-offset rank 750
  in full
  ((1196445696, 24, 0)
  at B 738, the B
  closing run's eighth
  and last act,
  terminal in B-offset
  order); and the
  closing-run eighth-act
  comparison in full
  (the two closing
  runs' eighth acts
  side by side);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.240 the
  A closing run in
  full (all eight acts
  at A-offset ranks
  741-748, gap sequence
  stated exactly); the
  B closing run in
  full (all eight acts
  at B-offset ranks
  743-750, gap sequence
  stated exactly); and
  the closing-run full
  comparison in full
  (the two runs side
  by side, act by act);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.241 the
  A closing run's size
  and channel sequences
  in full; the B closing
  run's size and channel
  sequences in full; and
  the closing-run
  size/channel comparison
  in full (position by
  position, agreement
  counts stated exactly);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.242 the
  A closing run's class
  and run-102 membership
  sequences in full; the
  B closing run's class
  and run-102 membership
  sequences in full; and
  the closing-run
  class/run-102 comparison
  in full (position by
  position, agreement
  counts stated exactly);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.243 the
  A closing run's offset
  and index sequences
  in full; the B closing
  run's offset and index
  sequences in full; and
  the closing-run
  offset/index comparison
  in full (position by
  position, agreement
  counts stated exactly);
  then broad
  ordinary UNMODIFIED
  source-model support100%.
- [x] Slice4.244 the
  A closing run's internal
  gap sequence in full; the
  B closing run's internal
  gap sequence in full; and
  the closing-run gap
  comparison in full
  (position by position,
  agreement count stated
  exactly); then broad
  ordinary UNMODIFIED
  source-model support100%.
- [ ] Slice4.245 the
  A closing run's combined
  sequences in full; the
  B closing run's combined
  sequences in full; and
  the closing-run combined
  comparison in full
  (sequence family by
  sequence family, identity
  and agreement counts
  stated exactly); then
  broad ordinary UNMODIFIED
  source-model support100%.
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
