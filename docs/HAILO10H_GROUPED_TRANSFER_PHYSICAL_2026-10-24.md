# Grouped transfer primitive — one bounded physical exchange (2026-10-24)

Contract: `TASK_hailo10h_grouped_transfer_physical.md` (published at
55a4b9ba before code). Branch: `yrsa/finish-line-roadmap`. Roadmap
Campaign 2 slice 2.4. Exactly ONE physical child ran, on Mimir
(Raspberry Pi 5) against the real Hailo-10H, through the minimal
transfer primitive (`hailbru/soc_transfer.mojo`, AES-TRANSFER-002/003).
**Result: ACCEPTED — the exchange completed physically.**

## Host gates on the Pi (all green before the child)

- Diagnostic `smidr/tools/group_transfer_probe.mojo` (at c88b2753):
  one CREATE exchange through `exchange_raw`, consumer-layer reply
  validation as qualified under AES-TRANSFER-003.
- `tests/test_hailo_group_transfer_probe.py` on the Pi (derived from
  the AES-CONTROL-018 probe suite; same device oracle, aligned
  observer, passthrough): **7 tests OK** (5.2 s) — single-exchange
  completion with exact observer wires and maps [(0,2560), (1,2068)];
  sync/launch faults poison; reply/IRQ/count refusals; close faults
  retain exactly 2 views with finalization unconfirmed; observer
  logging failure/overflow inert; errno passthrough; argument
  refusals with no owner.
- Read-only profile gates, re-checked immediately before the run:
  kernel `6.12.112-v8-16k-hailo+`, host page 16384, PCIe vendor
  `0x1e60` / device `0x45c4`, `/dev/h1x-0` present. The session's
  driver owner query validated driver 5.3.0, HAILO10H, one DMA
  engine and firmware-loaded before allocation, as in -016/-018.

## The one physical child

`group_transfer_probe physical-once`, fresh context, under `setsid`
with an independent `timeout -k 5 20` process-group watchdog and the
aligned observer preloaded (capacity 512). Returned **rc=0**.
Sanitized probe result (no handle, wire, serial or identity-bearing
value is printed):

```json
{"accepted":true,"physical_mode":true,"exchange_completed":true,
 "handle_known":true,"poisoned":false,"primary_error":false,
 "close_error":false,"retained_views":0,
 "finalization_unconfirmed":false,"input_descriptors":5,
 "output_descriptors":5,"snapshots":3,"input_completions":1,
 "output_completions":1}
```

Observer record: 54 calls used, 0 dropped, `owner_at_exit` −1
(device fd closed). Evidence hashes (raw records stay local on the
Pi under `~/aesir-build/physical-transfer-2026-10-24/`): probe
stdout sha256
`1c69055a8db32901806d9a98e6ed6bd1add3f2f4ac24de31805179cd5a5dba45`;
observer log sha256
`c258dcfcdbf91b07120498d08c217a2e3d2ce467cdbdac402256743832b3bc89`.

## PROVEN

- PHYSICALLY VERIFIED: one complete grouped exchange through the
  extracted primitive on the real Hailo-10H — aligned scatter,
  D2H-before-H2D launches returning exactly the predicted descriptor
  counts (5/5, per spec S2), distinct directional completions across
  3 interrupt snapshots, output CPU-sync gather, and a typed CREATE
  reply validated at the consumer layer (exact id/action, status 0,
  device handle present).
- PHYSICALLY VERIFIED: the Campaign 2 semantics (S1–S6) hold on the
  real profile — span description, observed-return admission,
  per-direction completion evidence, cache-sync points, ownership
  until completion, and clean finalization with zero retained views.
- **Campaign 2 exit condition is met:** returned-count, completion,
  cache-sync, and lifetime semantics have been observed physically
  and are embodied in a tested primitive.

## NOT PROVEN

- The full grouped lifecycle: this contract admitted one exchange
  only. IDENTIFY completion and DESTROY remain unproven (see
  AES-CONTROL-018); the handle created by this exchange was **not**
  logically destroyed — the residue stated in the contract before
  the run. Campaign 1's exit condition remains unmet, and nothing
  here changes that record.
- Nothing here establishes numerical configuration, packing,
  placement, program transfer/activation, program execution, or
  source-model support.

## Next gate

Campaign 3 (program resource lifecycle), starting with slice 3.1
interface qualification from qualified public interfaces and the
Campaign 2 primitive. Any further physical lifecycle attempt still
requires its own new one-shot contract.
