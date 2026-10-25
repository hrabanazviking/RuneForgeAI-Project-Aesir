# Minimal grouped transfer primitive (2026-10-24)

Roadmap Campaign 2, slice 2.2. Implements the slice 2.1 specification
(`docs/HAILO10H_GROUPED_TRANSFER_SEMANTICS_2026-10-24.md`, AES-TRANSFER-001)
in Mojo. **Host build only** — full host qualification is slice 2.3, and
no physical child is admitted by this work.

## What was built

`hailbru/soc_transfer.mojo` — `SocGroupedTransfer`, a session-owning
primitive for **one outstanding raw grouped exchange**:

- `exchange_raw(packet, timeout_ms)` takes the caller's exact logical
  packet bytes (≤ 2068; framing is the caller's) and returns the raw
  2068-byte reply extent. No action IDs, no status interpretation, no
  payload semantics — S1–S6 transport facts only.
- S1 spans: `input_group()` builds the two-span group (20-byte header at
  the storage address, 2048-byte body at `address + body_offset`) over
  the legacy or aligned layout; openers `open_grouped_transfer` /
  `open_grouped_transfer_aligned` mirror the RPC client's.
- S2 launch law: D2H (output) launch posted before H2D (input);
  descriptor counts recorded and admitted only under the
  observed-return policy via the shared `SocExchangeProgress`.
- S3 completion: the shared progress consumer — atomic snapshot
  validation, mask equality, one-outstanding correlation by channel;
  0xFE/0xFF records are transfer failure, never completions (the
  NOT_ACTIVE presentation decoded from -018 is therefore a specified
  poison path here, never a silent success).
- S4 sync sequence: input FOR_CPU → write → input FOR_DEVICE (whole
  mapped extent) → output FOR_DEVICE → enable interrupts → launches →
  per-direction `transfer_finished` on validated completion → output
  FOR_CPU → gather.
- S5 ownership: captured owner state re-verified at every exchange
  (`SocTransferOwner`); busy flag; **any** error poisons the owner,
  closes the session, and reuse requires a fresh owner.
- S6 quarantine: one total deadline across all phases (never reset),
  ≤ 32 snapshots, monotonic clock — all inherited from the shared
  `SocExchangeProgress`, unchanged.

`smidr/tools/group_transfer_mock.mojo` — host-mock-aligned diagnostic
in the established shape of `group_rpc_aligned.mojo`: refuses real
`/sys`/`/dev` roots and unbounded arguments; framing (HRPC encode /
decode / reply checks) lives in the diagnostic, not the primitive;
prints the same sanitized counters (exchanges, input/output descriptor
counts, IRQ snapshots, descriptor page, body offset, mapped size,
`physical_calls: false`) and proves a closed owner refuses reuse.

## Deliberately untouched

`hailbru/soc_group_rpc.mojo` and `hailbru/soc_group_device.mojo` are
**not** modified: the AES-CONTROL-015/-017 host qualification and the
-018 physical evidence stand on those exact sources. The primitive
shares every lower owner with them (`SocSession`, `SocStorage`,
`SocExchangeProgress`/`SocRpcProgress`, `encode_soc_group`,
`soc_transfer`) — the extraction is at the exchange-core level, and
migrating the RPC client onto the primitive is future work only if a
later slice contracts it.

## Build evidence

- `mojo build -I . smidr/tools/group_transfer_mock.mojo` on this VM
  (Mojo 1.0.0 ed45d567): **builds clean**; the single warning shown is
  pre-existing in `soc_session.mojo` (unused loop variable), not from
  the new sources.
- Refusal smoke: physical roots (`/sys`, `/dev`) and missing arguments
  are both refused with the diagnostic's usage error before any owner
  exists (rc=1).

## NOT PROVEN

- No host-mock exchange has run against the device oracle yet: the
  full qualification battery (deadline accounting across phases,
  poison-on-uncertainty, ownership lifetimes, late-completion
  quarantine including the NOT_ACTIVE presentation, byte-identical
  comparison against the RPC client's behavior) is **slice 2.3**.
- No physical run: slice 2.4 is a separate bounded contract.
- Nothing here touches numerical configuration, packing, placement,
  program execution, or source-model support.
