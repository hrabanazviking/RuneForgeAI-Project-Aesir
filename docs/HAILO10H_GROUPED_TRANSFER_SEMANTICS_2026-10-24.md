# Grouped transfer semantics — extracted from Campaign 1 evidence (2026-10-24)

Roadmap Campaign 2, slice 2.1. **Specification only — no code, no physical
run.** Every statement below is traced to Campaign 1 evidence
(AES-CONTROL-015 host qualification; AES-CONTROL-016 and AES-CONTROL-018
physical attempts on the real Hailo-10H; AES-CONTROL-017 aligned backing)
or to the grouped owner sources named. Where the evidence does not decide
a question, the spec says so — Campaign 2's primitive (slice 2.2) is to be
built on these facts only.

## S1 — How grouped input spans are described

- A grouped launch is a value, `SocUserptrGroup`: one channel (input
  channels are < 16; output channels are 16–31), one descriptor-list
  handle, and **1–8 spans**. Each span is `(address, size)`: address
  nonzero, size a positive UInt32, `address + size` must not overflow.
- The launch encoding is a fixed packed record: channel at byte 0,
  descriptor handle at bytes 1–8, span count at byte 9, then per span at
  `14 + 16·i`: address (8 bytes) and size (4 bytes). Type, unused slots,
  debug, engine and cyclic fields are canonical zero.
- The grouped RPC input group is exactly two spans over one mapping:
  the 20-byte header at the storage address, and the 2048-byte body at
  `storage address + body_offset`. Legacy backing: body_offset 20,
  extent 2068. Aligned backing: body_offset = descriptor page (512
  observed), extent page + 2048 (2560). The output side is **not**
  grouped: one scalar transfer of the full 2068 bytes.
- **Physical admission rule (proven twice, once negatively):** a USERPTR
  span's map-relative offset must be divisible by the descriptor page.
  Offset 20 → launch EINVAL (-016); offsets 0 and 512 → admitted
  (-018). This is a property of the span's offset within its mapping,
  not of its size.

## S2 — What the positive launch return means in practice

- The launch call returns the **actual descriptor count programmed**
  for that launch. It is not a byte count and not a transfer count.
- The grouped owner runs the *observed-return policy*: no exact count
  is predicted (`expected_descriptors = 0` in the capacity constructor —
  "zero selects observed-return policy; it is never a launch count").
  A return is admitted iff `1 ≤ returned < allocated ring capacity`
  (capacity 65536 in the qualified session); anything else poisons the
  exchange (`SocTransferCount`).
- Observed arithmetic, one profile (page 512): a contiguous 2068-byte
  extent programs `ceil(2068 / 512) = 5` descriptors (the
  `rpc_descriptor_count` formula). The grouped input (20-byte span +
  2048-byte span) also returned **5** — consistent with a per-span sum
  `ceil(20/512) + ceil(2048/512) = 1 + 4`. All four physical launches in
  -018 (scalar + grouped, create + identify) returned exactly 5.
- Launch order is law: the D2H (output) launch is posted **first**, then
  the H2D (input) launch. A launch out of order, duplicated, or on an
  unowned channel is a state error, before any completion is polled.

## S3 — Which completion evidence corresponds to each direction

- Completion evidence is the interrupt-wait result: a channels bitmap
  that must equal **exactly** this exchange's owned mask (input bit |
  output bit, all other engines zero), a record count, and per-record
  triples `(engine_index, channel_index, data)` from the pinned UAPI
  struct `hailo_vdma_interrupts_channel_data`.
- `data` semantics (UAPI defines, header-verified): **1** = that
  channel's one outstanding transfer completed; **0** = no completion
  yet; **0xFE** = channel with error; **0xFF** = channel not active.
  0xFE/0xFF are failure indications, **never** completion counts, and
  `data > 1` is impossible under the one-outstanding law (count error).
- A snapshot is validated **atomically before any progress commits**:
  foreign engine/channel, duplicate completion for a direction, a
  completion for a direction never submitted, or a mask mismatch all
  poison the exchange. Progress is monotonic: once a direction is done
  it cannot un-complete within the exchange.
- An exchange is complete ⇔ both directions were submitted **and**
  both directions have an observed `data == 1` record. Physical shape
  (-018, create): three waits — first a no-completion record, then the
  input completion, then both directions done.
- Correlation is by **channel + the single-outstanding law**, not by
  timestamp: this UAPI record carries no timestamp field.

## S4 — When cache sync must occur

The exchange's sync sequence, as implemented and physically exercised:

1. Input storage sync **FOR_CPU** — establishes CPU ownership.
2. CPU scatter/write of the logical wire (requires CPU ownership;
   byte access on device-owned or transfer-pending storage is refused).
3. Input storage sync **FOR_DEVICE** over the **whole mapped extent**
   (offset 0, count = mapped size — 2560 aligned / 2068 legacy).
4. Output storage sync **FOR_DEVICE** (2068).
5. Interrupts enabled; output launch; input launch (S2 order).
6. On a direction's validated completion, that storage's
   `transfer_finished` runs; the other direction stays device-owned.
7. Only after **both** directions complete: output sync **FOR_CPU**,
   then the CPU gather/reads the reply. Incoming bytes are never read
   before a successful output CPU-sync (the test observer's capture
   discipline mirrors this exactly).

A failed sync grants **neither** CPU nor DMA ownership
(`cpu_owned = False` until a sync succeeds), and sync is refused while
a transfer is pending.

## S5 — What stays owned until completion

- `begin_transfer` arms `transfer_pending = True` **before** the launch
  ioctl: an uncertain launch can therefore never hand CPU ownership
  back. The storage stays mapped and device-owned until its direction's
  validated completion (`transfer_finished`), a channel stop, or whole
  file-context finalization — only the session owner may call the
  latter two (`channels_quiesced`).
- The client re-verifies its captured ownership (fd, both handles, both
  channels, both addresses, both mappings, body offset, mapped size) at
  the start of every exchange; any drift is an owner error.
- One request/reply pair is outstanding at a time; the client is busy-
  flagged for the exchange's life. **Any** error poisons the client,
  closes the session, and reuse requires a **fresh owner** — a poisoned
  client is never re-driven.
- Uncertainty is accounted, never hidden: an uncertain close can retain
  views (host-proven in the -015 battery), and retained views are a
  reported number, not a silent leak. -018's physical close retained 0.

## S6 — How a late completion is quarantined

- Completions are consumable **only** inside the live exchange's poll
  loop, under one **total** deadline spanning every phase (never reset
  per phase), at most **32 snapshots**, on a monotonic clock (a
  backwards clock poisons). Nothing arriving after the loop — after
  success, poison, or deadline — has a consumer.
- After poison or deadline the owner is closed; its storages are
  quiesced only by assigned-channel stop or whole file-context
  finalization. A late completion can never be credited to a later
  exchange: the next exchange runs under a fresh owner with a fresh
  session, and its first snapshot must still match its own mask and
  one-outstanding law (S3).
- **New physical datum (-018, decoded against the pinned UAPI during
  this extraction):** on identify's second wait, both owned channels
  reported `data = 0xFF` — CHANNEL_NOT_ACTIVE — for channels 0 (input)
  and 16 (output). The client correctly treated this as transfer
  failure and poisoned. Whether identify's transfers had actually
  completed device-side and the channels then went inactive before the
  snapshot, or never activated, is **not established** by the evidence.
  What is established: a post-launch wait can present NOT_ACTIVE for
  both directions at once, and under current law that presentation is
  failure. The 2.2 primitive must specify this case explicitly; it
  must not silently credit it as success, and no future physical
  exploration of it happens without a fresh one-shot contract.

## Not established (the primitive may not assume these)

- A descriptor-count formula for arbitrary span sets beyond the one
  observed profile (S2's per-span sum is consistent with, not proven
  by, the single physical data point).
- Any sync granularity finer than the whole mapped extent.
- More than one outstanding exchange, more than 8 spans, or a grouped
  (multi-span) **output** — none observed or qualified.
- Timestamp/sequence correlation of completions (no such field exists
  in this UAPI record).
- Any numerical configuration, packing, placement, program execution,
  or source-model semantics — this spec is control transport only.

## Next gate

Slice 2.2: implement the minimal transfer primitive in Mojo on S1–S6
only — not a general arbitrary-RPC API. Slice 2.3 host-qualifies it
(deadline accounting, poison-on-uncertainty, ownership lifetimes,
late-completion quarantine including the NOT_ACTIVE presentation).
Slice 2.4 is a separate bounded physical contract; nothing in this
spec authorizes a physical child.
