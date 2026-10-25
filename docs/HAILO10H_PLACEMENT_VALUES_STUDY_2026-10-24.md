# Placement counts and safe assignment values — Track R item R3 study (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.7 (AES-NUM-007), Track R.
**Research only — no emitter, no bytes, no physical run, no
invented values.** Question, left open by AES-NUM-001 group E
and blocking AES-NUM-003 layer 3: do any bounded public sources
establish, for this target (Hailo-10H),

- **R3a** the physical counts — clusters, subclusters, APUs /
  compute units, input aligners, local-memory banks; and
- **R3b** which assignment values (a cluster index, a packed
  LCU id, an `active_*` bitmap pattern, an L2/L3 offset), if
  any, are publicly established as *safe* — legal for a real
  program to claim?

**Verdict: NOT PROVEN on both parts.** Every public source
searched gives field *widths* and *layouts* — encoding
capacity — and none gives a resource census for this target or
a single safe assignment value. AES-NUM-001 group E's two
placement rows stay **OUT** in full. AES-NUM-003 layer 3 is
therefore **not re-graded** (the condition for re-grading —
"if R3 lands" — is not met), and the 4.4 gate is not re-run,
because no layer changed. The width facts themselves were
re-read at the pin this slice and are recorded in §3 as
confirmations of group B (plus two ancillary literals); none
of them is a count, and reading any of them as a count is the
exact inference the roadmap's Do Not Infer table forbids.

## 1. Search bounds (what was actually searched)

1. **Pinned public HailoRT** `d503417f2a0db186a838390fb08690c4ea0f415e`
   (v5.3.0, MIT, interface facts only) — read this slice, at
   the pin, in full: `common/include/context_switch_defs.h`
   (862 lines; the one header that owns every placement-
   bearing record: packed LCU id, trigger-sequencer /
   sequencer config, boundary and NMS records). Full-text
   searches of that file for `CLUSTER` and `MAX` return only
   the packed-id shift/mask macros and one unrelated
   write-size constant — **the header contains no count
   define of any kind**. Standing from prior slices at the
   same pin: `hef.proto` (audited 2026-10-22: its only
   placement-adjacent field is `partial_clusters_layout_bitmap`,
   field 1, a u32 whose bits' meanings are unestablished, and
   whose multi-layout branch does not apply to this target —
   AES-NUM-001 group A graded it OUT for H10H).
2. **This repo's own evidence** — the LCU boundary study
   (2026-10-22), the sequencer interface record (2026-10-23),
   the finish-line codex, and the AES-NUM-001/003/004 line.
   All agree, in the codex's words: the packed-LCU bit packing
   "must not be turned into a claim that the hardware contains
   exactly 16 usable units per cluster or 8 safe clusters.
   Bit width is encoding capacity, not resource census."
3. **Open web** — three bounded queries (Hailo-10H cluster /
   subcluster / APU counts and architecture; the packed-LCU
   terms against HailoRT; a Hailo-10H datasheet / LCU / memory-
   bank query). Results were the official product brief and
   product page (TOPS, on-module LPDDR size, form factor,
   power — **no compute geometry of any kind**), community
   threads (a Hailo staffer's Hailo-8 answer speaks of "compute
   elements" with no number; nothing for the 10H), and the
   DFC v3.29 user guide (see §2, DFC note). None states a
   cluster, subcluster, APU, aligner, or bank count for the
   Hailo-10H, and none names a safe assignment value.

Bounded-search caveat, same as AES-NUM-001/005/006: graded
results over the sources named, not proof of absence
everywhere. GitHub code search requires sign-in and was not
used; the owning header was read directly and completely at
the pin instead. DFC's internal allocator geometry, if
documented anywhere, is not in a public source searched.

## 2. What each source does and does not give

**Pinned `context_switch_defs.h` @pin, read in full.** It
defines every placement-bearing field's *shape*:

- the packed LCU id macros (§3) — 4 bits of unit index, 3 bits
  of cluster index, bit 7 outside both masks;
- `trigger_sequencer_action_data_t` — a **separate, full u8**
  `cluster_index` field, inconsistent in width with the packed
  id's 3 cluster bits (two encodings, neither a census);
- `sequencer_config_t` — the `active_*` bitmaps and L2/L3
  offset fields (§3);
- `wait_nms_data_t` — `pred_cluster_ob_index` /
  `pred_cluster_ob_cluster_index` as bare u8s, names only.

It defines **no** `MAX_*` / count constant for clusters,
LCUs, APUs, subclusters, aligners, or banks, **no** statement
of which values any program may claim, and **no** meaning for
any `active_*` bitmap bit. The receiver and DFC own those
facts; the public header is a carrier of layouts, exactly as
the config-buffer code was a carrier of CCW bytes in
AES-NUM-005.

**Repo evidence.** The host-qualified LCU codec
(`HAILO10H_MOJO_LCU_ACTIONS.md`) exercises **all 128**
packed-id combinations — that is a qualification of the
*encoding* (every encodable value round-trips), recorded at
the time with the explicit warning that host wire-control
values "do not establish physical addresses, actual LCU
counts" (evidence README, 2026-10-22). A value that encodes
is not a value that exists, and a value that exists is not a
value that is safe for an Aesir program to claim. The
sequencer record (2026-10-23) likewise carries the standing
line: "No source operation is assigned a physical cluster,
L3 cut, APU, input aligner, subcluster or L2 address."

**DFC note (a near-miss, recorded so it is not mistaken for
evidence).** The DFC v3.29 user guide documents a model-script
command `place(cluster_number, layers)` — "This points the
allocator to place layers in a specific cluster_number", with
the example `place(2, [layer, layer2])`. Three reasons it
grades nothing here: (a) it is the **DFC 3.x / Hailo-8-era**
guide, not a Hailo-10H (DFC 5.x) source — cross-target
inference is forbidden; (b) it proves only that DFC's
allocator *accepts* a cluster number as a hint — it states no
count, no legal range, and no safety property; (c) DFC is not
Aesir's backend (roadmap standing note, AES-NUM-005 §2). It
generates one future question (§5), nothing more.

**Product sources.** Hailo's own Hailo-10H product brief and
product page publish performance (40 TOPS INT4 / 20 INT8),
on-module memory (4/8 GB LPDDR4/4X), interface and power.
They publish no cluster geometry — marketing specifications
are not a resource census, and TOPS cannot be divided back
into unit counts without exactly the invented arithmetic this
campaign forbids.

## 3. Width facts confirmed at the pin (group B confirmations)

Recorded literally, as widths only. **No row is a count; no
row licenses an assignment value.**

| Fact | Source @pin | Grade |
|---|---|---|
| Packed LCU id: LCU index shift 0, width 4, mask `0x0f`; cluster index shift 4, mask `0x70` (3 bits); bit 7 in neither mask | `context_switch_defs.h`, `PACKED_LCU_ID_*` macros | **IN** (encoding capacity only: 16 unit values × 8 cluster values = 128 encodable combinations — a property of the byte, not of the silicon) |
| Trigger-sequencer body carries its own `cluster_index` as a full u8, distinct from the packed id's 3 cluster bits | same header, `trigger_sequencer_action_data_t` | **IN** (layout; the width inconsistency itself forbids reading either as a census) |
| `sequencer_config_t` fields: `initial_l3_cut` u8, `initial_l3_offset` u16, `active_apu` u32, `active_ia` u32, `active_sc` u64, `active_l2` u64, `l2_offset_0/1` u64 | same header; offsets/extents already in the repo's 2026-10-23 sequencer record | **IN** (layout/widths only — each `active_*` width is a bitmap's capacity; which resources exist, and what any bit means, remain unestablished; the abbreviations are recorded as field names, not expanded into resource claims) |
| Ancillary literal: `ENABLE_LCU_DEFAULT_KERNEL_ADDRESS (1)` and `ENABLE_LCU_DEFAULT_KERNEL_COUNT (2)` — the default LCU-enable record's kernel-done address/count defaults | same header, defines; struct comment at `enable_lcu_action_default_data_t` | **IN** (literal constants only) — a completion-reporting fact, not a placement value; its consumer-side meaning belongs to R4, and it is recorded here only because this slice read the header in full |

Note the discipline point, parallel to AES-NUM-005 §3: the
widths prove a non-zero assignment *can be expressed* in
these fields — they do not say which expression names a real
resource on this chip. Inferring "8 clusters, 16 LCUs, 32
APUs, 64 subclusters" from the masks and bitmap widths would
violate roadmap §2.2 ("an `active_l2` bitmap's bits do not
have known physical meanings or a known legal H10H resource
count") by direct analogy on every row.

## 4. R3 disposition and what remains

- **R3a (counts): NOT PROVEN.** No searched source states the
  Hailo-10H's cluster, subcluster, APU/compute-unit, input-
  aligner, or local-memory bank counts.
- **R3b (safe assignment values): NOT PROVEN.** No searched
  source establishes any cluster index, packed LCU id,
  `active_*` bitmap pattern, or L2/L3 offset as safe/legal
  for a real program on this target. R3 closes this study
  pass with a negative result, per the 4.4 gate's terms (each
  Track R item closes only on IN-grade evidence or recorded
  NOT PROVEN).
- AES-NUM-001 group E: both placement rows stay OUT.
  AES-NUM-003 layer 3: unchanged, INCOMPLETE. No addendum,
  no gate re-run (no changed layers).
- Campaign 4 EXIT still NOT MET; operation UNQUALIFIED;
  Campaign 5 NOT contracted.
- Remaining roads to a census, in roadmap order, none taken
  this slice: (a) a future public source stating the geometry
  (Lane A continuous mining — re-check on new HailoRT pins
  and any DFC 5.x guide that becomes public); (b) Lane C
  patents as *question generators only*, needing public-
  interface or physical corroboration before any promotion;
  (c) the DFC `place()` question above, re-asked only against
  a Hailo-10H-era DFC source if one becomes public. No
  physical step is proposed by this slice: probing candidate
  placements on the device to see which ones fault would be
  spraying unknown values at the hardware, the lane-E
  bad-question pattern AES-NUM-005 already refused for CCWs.
- Next Track R item: **R4 — action sequencing** (slice 4.8),
  which also inherits the F1 result-path qualification
  question (AES-NUM-006 §5) and the §3 ancillary completion
  defaults. R5 (partial-state teardown) follows.

## 5. Audit

Research only. No code, no emitter, no bytes constructed, no
physical child, no device contact. Sources: pinned HailoRT
header read in full at `d503417f…` via its public GitHub URL;
repo evidence as in §1–§2; three bounded web queries as in §1.
