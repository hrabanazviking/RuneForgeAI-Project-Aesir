# CCW word layout — Track R item R1 study (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.5 (AES-NUM-005), Track R
lane D. **Research only — no emitter, no bytes, no physical run,
no invented values.** Question: does any bounded public source
define the layout of a CCW (configuration/control) word — the
fields inside one non-zero word: opcode, address, data, command
— well enough to grade it ESTABLISHED under the AES-NUM-001
field-table discipline?

**Verdict: NOT PROVEN.** No source searched defines the bit
layout of a non-zero CCW word. The CCW-words row of AES-NUM-001
group C stays **OUT** in full. AES-NUM-003 layers 2 and 5 are
therefore **not re-graded** (the state file's condition for
re-grading — "if R1 lands" — is not met), and the 4.4 gate is
not re-run, because no layer changed. Two ancillary facts about
the *container* of words (not their layout) were newly sourced
and are recorded in §3 as IN-grade additions to group C; neither
one describes any field inside a non-zero word.

## 1. Search bounds (what was actually searched)

1. **This repo's own evidence** — every `ccw/CCW` mention in
   docs, TASK contracts, Mojo and tests (full-tree grep,
   2026-10-24). All prior mentions agree: carriers, pointers,
   sections, bursts and padding are described; the word layout
   is everywhere recorded as unresolved (notably
   `HAILO10H_FIRST_PRIMITIVE_SOURCE_FACTS.md`: bounded search of
   the pinned archive's common/include + libhailort/src found
   "the known padding unit, opaque configuration buffers and
   container pointer/section handling. No arithmetic CCW/
   register encoding was established").
2. **Pinned public HailoRT** `d503417f2a0db186a838390fb08690c4ea0f415e`
   (v5.3.0, MIT, interface facts only) — re-read this slice, at
   the pin, the two files that own CCW buffers:
   `core_op/resource_manager/config_buffer.hpp` and
   `config_buffer.cpp`. Also standing: the v5.3→v5.4 public
   delta study (`HAILO10H_PUBLIC_ENCODING_DELTA_2026-10-20.md`,
   pin `f5195903…`), which already recorded that the newer pin
   "does not establish new arithmetic CCW fields, register
   meanings or physical placement."
3. **Lane D — the external experimental compiler**
   `l-nmch/hailo-10h-llm-compiler` (MIT; read at its current
   main, commit `c870419f7d6315e1277e06a9fa5eadd955b8e1af`).
   Its README, pipeline description (s1–s6) and full
   `docs/findings/` index (17 findings) were read.
4. **Open web** — three bounded queries (CCW + Hailo +
   config_buffer/HailoRT; CCW bit layout/opcode/HEF; the lane-D
   repo + CCW). Results were DFC user-guide material, Hailo
   marketing/blog pages, and unrelated projects. None defines a
   CCW word.

Bounded-search caveat, same as AES-NUM-001: this is **not proof
of absence** everywhere — it is the graded result over the
sources the roadmap names (pinned public runtime, lane D,
repo evidence, open web). GitHub code search over the HailoRT
repo requires sign-in and was not used; the two owning files
were read directly at the pin instead.

## 2. What each source does and does not give

**Pinned HailoRT, config_buffer.{hpp,cpp} @pin.** The header
brief is the whole story in one line: the buffer "contains
nn-configurations in a specific hw format (ccw)" — the format
is named, never defined. The code treats CCW data as opaque
`MemoryView` bytes to copy, align, pad and DMA in bursts
(`ccw_dma_transfers`, `ccw_bursts_offsets/sizes`); no code in
either file inspects, constructs, or decodes a non-zero word.
DFC is the only producer in view; HailoRT is a carrier.

**Lane D compiler.** Its pipeline delegates HEF production —
and therefore all CCW generation — to DFC 5.3.0
(`s6_compile_hef.py`, HAR → HEF via the DFC LLM flow). Its 17
findings are graph/cache/tokenizer/SDK-behaviour findings
(RoPE widths, mask broadcast, KV-cache key/layout, lm_head
sharding, tokenizer BOS, …); **none addresses CCW words**, and
the repo contains no CCW encoder of its own. Lane D confirms
the roadmap's standing note: its DFC calls are not Aesir's
backend, and here they also yield no layout evidence.

**Repo evidence.** Consistent and unchanged: pointer/inline
actions carry CCW bytes (group A, IN as carriers only); ID 27
fetches CCW bursts (group B, layout only); the outer program
header counts a CCW section (structure only). No repo source
has ever decoded a word.

## 3. Ancillary facts newly sourced (group C additions, IN)

These describe the word *unit* and the one defined word value.
They do not describe any field of a non-zero word, and no
emitter may be built from them.

| Fact | Source @pin | Grade |
|---|---|---|
| A CCW is consumed as a 64-bit word: the NOP is `uint64_t 0` ("CCW of all zeros (64'h0)… expect CCW in next 64b word") | config_buffer.cpp, `CopiedConfigBuffer::pad_with_nops` comment | **IN** (unit width + NOP value) |
| NOP semantics: the CSM pops a NOP from the channel FIFO **without forwarding any address/data/command**, it does not contribute to CRC calculations, and it returns credits to the peripheral as usual | same comment, same function | **IN** (NOP behaviour only) |
| Header constants: `CCW_BYTES_IN_WORD = 4`; `CCW_DATA_OFFSET = CCW_BYTES_IN_WORD * 2 = 8` | config_buffer.hpp @pin | **IN** (literal constants only) — their *use* was not traced in this slice (code search unavailable, §1), so what the 8-byte data offset indexes is **NOT ESTABLISHED** and must not be read as a header layout |

Note the discipline point: the NOP comment proves a non-zero
word *carries* address/data/command in some form — it does not
say where in the 64 bits any of them sits. Inferring field
positions from that sentence would violate roadmap §2.2 /
"Do not invent unknown CCWs from patent diagrams" by analogy:
a plausible field split is still an unknown field split.

## 4. R1 disposition and what remains

- **R1: NOT PROVEN** (recorded, per the 4.4 gate's terms: each
  Track R item "closes only on IN-grade evidence or is recorded
  NOT PROVEN"). R1 does not close Campaign 4; it closes this
  study pass with a negative result.
- AES-NUM-001 group C: CCW-words row stays OUT; §3's three rows
  are additions *around* it, recorded here and in the ledger.
- AES-NUM-003 layers 2/5: unchanged, INCOMPLETE. No addendum,
  no gate re-run (no changed layers).
- Campaign 4 EXIT still NOT MET; operation UNQUALIFIED;
  Campaign 5 NOT contracted.
- Remaining roads to a layout, in roadmap order, none taken
  this slice: (a) a future public source defining the word
  (Lane A continuous mining — re-check on new HailoRT pins);
  (b) Lane C patents as *question generators only*, each
  needing public-interface or physical corroboration before
  any promotion; (c) Lane E bounded physical observation —
  explicitly NOT spraying candidate CCWs (roadmap lane E's
  bad-question example), so no physical step is proposed by
  this slice.
- Next Track R item: **R2 — SoC session readiness protocol**
  (plus the 4.4 finding-F1 program-result readback question),
  slice 4.6, research/host-side only until its own contract
  says otherwise.

## 5. Audit

Research only. No code, no emitter, no bytes constructed, no
physical child, no device contact. Sources: pinned HailoRT
files read at `d503417f…` via their public GitHub URLs;
lane-D repo read at `c870419f…`; repo grep as in §1.
