# Lane-1 structure hunt — the burst, anatomized (2026-10-24)

Roadmap Campaign 4 iteration, slice 4.17 (AES-NUM-017).
Population: every champion-headed 24-byte burst
(lane 0 = `0528000000000000`) in two artifacts — MiniLM
(132 bursts) and ollama blob 5ab3537d (4,819 bursts) —
byte- and u16-level anatomy of lanes 1 and 2.

## Lane 1 (bytes 8–15): a four-field operand word

The same anatomy in both artifacts:

- **u16 pos 2 (bytes 12–13) = constant `0x0250`** —
  132/132 in MiniLM, 4,818/4,819 in the blob (a single
  `0x02c8` exception). A fixed tag-class field.
- **u16 pos 1 (bytes 10–11) = a tiny enumeration** —
  only `0x0000`, `0x1000`, `0x2000` (MiniLM) plus `0x2001`
  (blob, 514×). Two-bit-class values in the high nibble.
- **u16 pos 3 (bytes 14–15) = an arithmetic ladder** —
  values …, `0x12f0`, `0x14f0`, `0x16f0`, `0x18f0`, … with
  **stride `0x200` = 512** (the descriptor page of the
  transfer law). In MiniLM the top rungs repeat exactly
  24× each; in the blob 876× each. An address/offset-class
  field walking fixed slots.
- **u16 pos 0 (bytes 8–9) = a flag/select field** — byte 8
  almost constant; values are power-of-two-flavoured
  (`0x0000`, `0x0400`, `0x0c00` in MiniLM; `0x8000`,
  `0x4000`, `0x0000` leading the blob).

## Lane 2 (bytes 16–23): a 24-bit datum + five zero bytes

- Bytes 19–23 are zero in **every** burst (the corpus law
  of AES-NUM-016 at byte resolution). The datum is bytes
  16–18: byte 16–17 high-entropy, byte 18 small-valued
  (top u16-pos-1 values `0x60`, `0x56`, `0x50`, `0x31`).
- **The same datum values recur across artifacts, once per
  context:** the blob's leading lane-2 values `0xe517` and
  `0x898c` each appear **219× = its context count**;
  MiniLM's leading values are the *same two words*
  (`0x898c`, `0xe517`), each **6× = its context count**.
  A per-network constant (or constant pair) written once
  into every context — data-class, network-scoped.

## The burst, as it now stands (behavioural anatomy)

```
word0  header/opcode     champion 0x0000000000002805 dominant corpus-wide
word1  [flags u16][enum u16 in {0,0x1000,0x2000,0x2001}]
       [const 0x0250][address ladder u16, stride 0x200]
word2  [24-bit datum][5 zero bytes]
```

No field is *named* beyond its behaviour — but the burst is
no longer opaque: it is a fixed header, a packed operand
word with one constant, one enum, one flag field and one
striding address, and a 24-bit data word. What remains for
full authorship: the ladder's origin/range (does it walk a
known region?), the enum's and flags' meanings (needs a
one-parameter differential), the datum's identity
(compare against the networks' known constants), and the
non-champion lane-0 families' anatomy. Those are the
queued cuts — each is now a *specific* question, not a
search.

## Evidence boundary

Statistics are exact counts over the stated populations.
The one `0x02c8` exception is recorded, not smoothed. The
stride/constant/enum readings are behavioural
classifications; semantic naming awaits the differential.
