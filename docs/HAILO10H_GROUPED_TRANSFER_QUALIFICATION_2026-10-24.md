# Grouped transfer primitive — host qualification (2026-10-24)

Roadmap Campaign 2, slice 2.3. Subject: `hailbru/soc_transfer.mojo`
(AES-TRANSFER-002) against the specification
`docs/HAILO10H_GROUPED_TRANSFER_SEMANTICS_2026-10-24.md` (AES-TRANSFER-001).
**Result: HOST-QUALIFIED.** Host mocks only; no physical child was built
or run.

## The battery

`tests/test_hailo_group_transfer_aligned.py` — derived from the
AES-CONTROL-017 aligned control suite, driving the same qualified
device oracle and fault library
(`tests/group_control_rpc_aligned_faults.c`, unchanged): the aligned
oracle gathers the canonical 2068-byte wire from spans at offsets
0/512 in a 2560-byte input map, asserts the gap zero, and keeps the
output scalar at 2068. New for this slice:
`tests/hailo_group_transfer_aligned_api.mojo`, a direct consumer of
the primitive mirroring the RPC client's API consumer (lifetime,
poison, preflight modes), and the primitive's own diagnostic
(`group_transfer_mock`) as the probe role. **574 recorded runs**
(374 probe, 194 API, 6 cross-check), every run compared current vs
frozen (same binaries, hash-pinned manifest) for byte-identical
stdout/stderr/exit and oracle-event equality; 11 tests, all OK
(388 s, this VM, Mojo 1.0.0).

Coverage, mapped to the spec:

- **S1/S2 shapes and counts (test_01, test_02, test_11):** payload
  sizes {0, 1, 19, 20, 21, 2047, 2048} × exchange counts {1, 3};
  oracle-observed descriptor returns at the boundaries
  {(1,1), (1,65535), (65535,1), (65535,65535), (7,5)} admitted and
  {−1, 0, 65536, 2³¹−1} poisoning for each direction, with fresh
  recovery after every poison. Exact wire bytes, map extents
  [(0,2560), (1,2068)] and launch effects asserted per exchange.
  **Test_11 cross-check:** on identical scenarios the primitive's
  diagnostic output is byte-identical to the qualified RPC client's
  diagnostic (`group_rpc_aligned`) — the extraction changed no
  observable behavior.
- **Faults (test_03):** every sync stage (before/after ×4), launch
  (before/after ×2), interrupt enable and wait (before/after), and
  reply faults (magic, size, id, action, status) poison the owner;
  a good exchange recovers on a fresh owner after each.
- **IRQ law (test_04):** partial completions across 3 exchanges;
  duplicate, empty, foreign-channel, count, error (0xFE/0xFF class),
  mask and engine faults all poison — atomic snapshot validation and
  the one-outstanding correlation hold for the primitive exactly as
  specified in S3/S6.
- **Deadline (test_05):** the total deadline is faulted at *every*
  observed clock stage (late, backwards, and clock-error at each of
  the >12 stages), plus 0/−1/60001 admissions refused and wait-stall
  — one budget across all phases, never reset (S6).
- **Construction and cleanup (test_06, test_07):** partial-construction
  faults across open/identity/descriptor/connect/allocate/map stages
  refuse cleanly; channel/unmap/release/munmap/close faults account
  exactly; effectful failures with uncertain close retain exactly 2
  views, attempt file close exactly once, and never release
  descriptors blindly (S5).
- **Ownership (test_08, test_09):** 12 guard refusals — empty owner,
  8 captured-field mutations, 2 layout mutations, exchange after
  close — plus scoped-exit closure and fresh recovery; 6 preflight
  poisons at the primitive layer (2069-byte raw packet, timeout
  0/−1/60001, handle mutation, mapped-size mutation), each poisoning
  and closing, each followed by a fresh recovery.
- **Arguments (test_10):** malformed diagnostic invocations refuse
  with zero oracle effects.

## Qualification history (failures retained)

Two battery iterations preceded the green run, both failing only on
**reply-framing** scenarios (`reply_magic`, then `reply_id`, in
test_03/test_07): the primitive is framing-free by design, so a
corrupted reply completed the transport cleanly and nothing poisoned
the owner — where the RPC client poisons inside its own exchange.
Resolution, now part of the qualified consumer contract: the
**consumer layer** validates the reply (frame decode, message-id,
action, status) and poisons + closes the owner on any framing
failure, composing cleanup failure exactly as the RPC client's
exchange does. The primitive's sources were not weakened to pass:
the only change to `soc_transfer.mojo` during qualification was
removing a redundant pre-check so oversize packets refuse (and
poison) at the storage write, at the same point as the client's.
Runs: 538 (run 1), 558 (run 2), 574 (run 3, green); all evidence
retained locally under the slice's evidence directories.

## PROVEN

- HOST-VERIFIED: the minimal grouped transfer primitive behaves
  identically to the qualified RPC client across the full aligned
  fault/deadline/IRQ/ownership battery, including the S6 quarantine
  law and the 0xFE/0xFF failure presentations.
- HOST-VERIFIED: framing failures are a consumer-layer poison, with
  the layering boundary exercised and recorded — transport success
  never masquerades as reply validity.

## NOT PROVEN

- No physical exchange through the primitive: slice 2.4 is a
  separately published bounded physical contract (one control-class
  exchange), and nothing here authorizes it.
- Campaign 2's exit also requires 2.4's physical confirmation.
- Nothing here establishes numerical configuration, packing,
  placement, program execution, or source-model support.
