# 0x2d80 slot context, corpus datum pool, 0x08xx anatomy (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.19 (AES-NUM-019).
Method: hef19.py (sha256 35ee89b0…) on Mimir over the
AES-NUM-017/018 populations (MiniLM, ollama blob
5ab3537d) for arms 1 and 3, and over the full
7-artifact corpus (MiniLM + all six hailo-ollama
blobs) for arm 2. All counts are over 24-byte
channel-1/2 bursts exactly as in AES-NUM-013..018.

## 1. The 0x2d80 slot: a fixed pair carrying the constants

- MiniLM: the two `0x2d80` bursts sit at champion-
  sequence indices **10 and 11 of 22 in every one of
  the 6 contexts** — an adjacent pair at the exact
  middle of the 22-burst skeleton (fractions
  0.455/0.500). The pair is preceded by a rung
  (`0x10f0` ×4 contexts, `0x14f0` ×2, or its own mate)
  and followed by `0x10f0` (×6) or its mate.
- Blob 5ab3537d: champion-bearing contexts carry the
  pair at indices **10, 11 and again at 32, 33 of
  44** (95 contexts ×4, 29 ×2; fractions
  0.227/0.250/0.727/0.750) — the 22-burst unit
  repeats, and the special pair sits at offset
  10–11 **of each unit**. Next-ladder after a
  special is its mate (×218) or `0x10f0` (×219,
  plus the recorded `0x2a8e` anomaly once).
- **The pair is exactly two distinct bursts in both
  artifacts** (2 distinct of 12 MiniLM, 2 of 438
  blob), never identical within a context: lane-1
  pos 0 is `0x8000` in one and `0x4000` in the
  other; enum is `0x0000` and const `0x0250` in
  both; the channels split 1/2 evenly (6/6 MiniLM,
  219/219 blob).
- **The pair's lane-2 data are precisely the two
  cross-network constants**: `0x56898c` and
  `0x60e517`, one per burst, in both artifacts
  (12/12 MiniLM, 438/438 blob specials carry a
  top-2 datum). The special slot is where the
  skeleton writes its two shared constants.

**Reading:** `0x2d80` is not a seventh rung. It is a
fixed mid-skeleton slot pair (offset 10–11 of the
22-burst unit) whose two bursts differ only in the
flag field and carry, one each, the corpus datum
constants. What the slot *does* is still not named.

## 2. Datum pool at full corpus: a graded shared pool

Champion-burst lane-2 u24 values, all 7 artifacts:

| artifact | contexts (proto) | champion | distinct u24 | top pair repeats |
|---|---|---|---|---|
| MiniLM | 6 | 132 | 62 | 6 / 6 |
| 5ab3537d | 219 | 4,819 | 417 | 219 / 219 |
| 0856a10c | 256 | 5,632 | 738 | 256 / 256 |
| 76c3a8ff | 353 | 7,772 | 617 | 353 / 353 |
| cc9b9d1c | 271 | 5,962 | 760 | 271 / 271 |
| 0a0d378c | (180) | 3,960 | 422 | 180 / 180 |
| 773470cd | (219) | 4,820 | 396 | 219 / 219 |

- **The top pair is universal and exact:** `0x60e517`
  and `0x56898c` lead every artifact, each repeated
  exactly the artifact's (protobuf) context count —
  the §1 pair written once per context, corpus-wide.
  (Repeat counts match AES-NUM-016's context counts
  where published; the two bracketed counts are
  inferred from the repeats themselves.)
- **The pool is shared, graded, and small:** union
  across 7 artifacts is only **1,189 distinct u24**;
  **30 values occur in all seven**; presence
  distribution 1-artifact 225, 2: 357, 3: 245,
  4: 186, 5: 92, 6: 54, 7: 30.
- **MiniLM has zero private values** — all 62 of its
  u24 occur in at least one blob (pairwise
  intersections 38–60 of 62). Blob 773470cd likewise
  has zero private values (396, a near-twin pool of
  5ab3537d: same next pair `0x508c22`/`0x1ac2fa`).
  The most private pool (cc9b9d1c) still shares
  668 of 760.
- Next-tier values repeat at context-count fractions
  (≈ ctx/4: 55 at 219, 51–57 in kin; ctx/2: 175 at
  353) — a repetition hierarchy, not flat data.

**Reading:** the datum vocabulary is a compiler-
emitted pool shared across networks — a small set of
constants written at graded per-context frequencies,
topped by the universal pair of §1. Its identity
(what the constants *are*) remains NOT PROVEN.

## 3. The 0x08xx lane-0 class: a structured minority

Class = lane-0 low u16 high byte `0x08` (champion
class is `0x28`). Populations: MiniLM 15 bursts,
blob 5ab3537d 71 bursts; all non-champion.

- **Lane 0 is itself structured:** every 0x08xx
  lane-0 word in both artifacts carries the constant
  half-word `0xbff8` at bytes 4–5, a low byte of
  `0x01` or `0x03`, and two varying tail bytes
  (blob top words `01080000f8bf1812` ×28,
  `03080000f8bf1a14` ×27 — only 6 distinct lane-0
  words in the blob; MiniLM 11 distinct in 15).
- **No champion anatomy:** pos-2 is never `0x0250`
  (0.0 fraction in both), no ladder values at pos 3
  (0.0 on-ladder fraction) — confirming AES-NUM-018.
- **The lane-2 width law holds even here:** bytes
  19–23 zero in 15/15 MiniLM and 71/71 blob 0x08xx
  bursts; the 24-bit datum field is respected by
  every class measured.
- **The two artifacts differ in kind:** MiniLM's
  0x08xx lanes 1–2 are near-maximal entropy (14
  distinct values per lane-1 byte position, 15/15
  distinct data) — data-like fill. The blob's are
  **low-entropy and repetitive** (2–3 distinct per
  byte, 8 distinct data in 71 bursts, two lane-1
  families) — a structured minority form, present
  in 34 contexts, channel-skewed (56 ch1 / 15 ch2).

**Reading:** 0x08xx is a second burst kind with its
own lane-0 header structure (constant `0xbff8`
marker), obeying the same lane-2 width law; whether
its lanes carry data or operands differs by
artifact. No field is semantically named.

## Evidence boundary

Exact counts over the stated populations. Context
counts for arms 1–2 are champion-bearing contexts
as walked (blob 5ab3537d: 124) except where the
protobuf context count is named (219 etc., from
AES-NUM-016 and the datum repeats). The single
`0x2a8e` next-ladder occurrence is recorded, not
smoothed. No field is semantically named; the
datum identity and the 0x2d80 slot's function stay
open. Next (4.20): the 22-burst skeleton unit as a
whole — full per-position lane anatomy across the
unit in MiniLM + one blob; the 0x28xx non-champion
families' alternating lane-1 pattern; datum-pool
identity test against the artifacts' own tensor
data (scale/zero-point candidates).
