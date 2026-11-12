# A-049 Ledger — Oversized-model streaming

**Slice:** A-049 (Oversized-model streaming), team-08 worktree
`/home/volmarr/aesir-team-08`, branch `yrsa/aesir-team-08`,
base `0cacfc61`. Lead completed 2026-11-12 (previous lead stalled
mid-build; its fixture, builder and design partial were inspected
and carried forward — the partial module was completed, not shipped
as found).

**Roadmap acceptance:** "Oversized-model streaming: residency runs
via mmap streaming on unified memory (fixture: largest obtainable,
sha-pinned; synthetic oversized fixture acceptable if built from
real tensors). Acceptance: coherent short generation + memory
accounting showing streaming, not full residency."

## Files

| File | Role |
|---|---|
| `aesir_engine/core/oversized_streaming.mojo` | New module: `OversizedStreaming.sweep_region` (WILLNEED prefetch + checksum touch + DONTNEED hand-back, per-window accounting), `touch_region` (no-drop control), `drop_region`, `StreamAccounting`. |
| `aesir_engine/tests/bench_oversized_streaming_a049.mojo` | Standalone proof harness (3 legs). |
| `docs/bench/A049_OVERSIZED_STREAMING.md` | Bench doc with the measured results. |
| `hidden_files/build_a049_fixture.py` | Fixture builder (from the previous lead, verified). |
| `hidden_files/run_a049_bench.sh` / `run_a049_suite.sh` | Staging runners (6 shim libs, gfx1151), sha-pin fixture before/after. |
| `hidden_files/a049_bench.log` / `hidden_files/a049_run_all.log` | Raw evidence logs, committed with the slice. |
| `hidden_files/fixtures/oversized_a049.gguf` | 43 GB evidence fixture. Git-ignored; regenerable byte-for-byte via the builder. NOT committed, NOT deleted. |

**E-MASTER cases: +0** (standalone harness, A-046/A-048 pattern).
Rationale: the proof requires a 43 GB fixture, smaps residency
sampling, and two full 40 GiB passes (~17 s); the in-suite harness
has no fixture path and runs seconds-scale cases. Suite impact is
therefore zero by construction, and the suite confirms it below.

## Fixture (verified)

- Oversized: 42,950,284,128 bytes, sha256
  `32a244be1954a5fbbe8812ca7eee5e1e64a9be7ad9fe4ed1e70ebb24866da4e1`
- Source: `stories260K.F16.gguf`, 601,248 bytes, sha256
  `57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3`
  = the A-004 pinned oracle hash.
- 208 tensors: 48 real (byte-identical) + 160 pad tensors
  `stream.pad.NNNN.weight`, F16 [16384 x 8192] (256 MiB each),
  payload = repeated real `token_embd.weight` bytes.
  Pad region: offset 611,168, length 42,949,672,960.
- Bench runner re-hashed both fixtures before and after the run:
  identical. Nothing else on disk was touched.

## Bench result (live, 2026-11-12, `A049_OVERSIZED_STREAMING: PASS`)

Leg 1 — generation over the oversized file (ordinary engine,
canonical prompt "One day, Timmy went to", 32 greedy tokens):
**EXACT match with the pinned A-004/A-020 oracle, 32/32**, decoding
to "the park with his mom. They saw a big box with a big box. The
box was very small and ...". Baseline mapping resident before the
passes: 589,824 bytes.

Leg 2 — streaming sweep over the 40 GiB pad region, 160 windows of
256 MiB (`OversizedStreaming.sweep_region`):

- bytes streamed: 42,949,672,960 (whole region)
- bytes handed back: 42,949,017,600 = 9,999 bp (the 655,360-byte
  shortfall is exactly one page per window: drop ranges are
  page-rounded inward so hand-back is never overstated)
- peak mapping resident: 269,869,056 (~1.005 windows; 0.63% of region)
- final mapping resident: 1,269,760
- peak process RSS: 324,911,104; final RSS: 56,311,808
- sweep checksum: 10358989207356497221

Leg 3 — control (`touch_region`, identical walk, no madvise):
checksum bit-identical (10358989207356497221); peak = final mapping
resident 42,950,287,360; process RSS 43,005,329,408 — full
residency. Post-control cleanup dropped 42,949,668,864 bytes;
mapping resident returned to 618,496 and RSS to 55,660,544.
Bench wall time ~17 s for both 40 GiB legs + generation.

## Suite result (live, 2026-11-12)

`hidden_files/run_a049_suite.sh` → `hidden_files/a049_run_all.log`:
**421 passed / 1 failed / 2 skipped / 424 total** — exactly the
base-line at 0cacfc61, +0 new cases by design. Sole failure:
`gguf.tensor_directory_interface` (pre-existing J-022 drift,
tolerated per the campaign brief). Skips: the 2 pre-declared.

## Bugs found and fixed in-slice

1. **madvise EINVAL on unaligned prefetch range** (found by the
   bench's first full run: generation leg green, sweep raised
   "OversizedStreaming: madvise failed"). The pad region starts at
   file offset 611,168 — not page-aligned — and `madvise` requires a
   page-aligned start. `drop_region` already rounded inward; the
   WILLNEED prefetch in `sweep_region` passed the raw range. Fix:
   prefetch range is page-rounded OUTWARD (advisory only; the drop
   path keeps inward rounding so accounting stays honest). Re-run:
   PASS with the numbers above.

2. **GGUFSeer lifetime footgun** (found during bench diagnosis;
   root cause of the bench's first failure). Mojo destroys a
   variable at its last use, and `GGUFSeer.__deinit__` munmaps the
   file — so any code holding only the raw `mmap_ptr` (e.g.
   `WeightResidency.mapping_accounting(base)`, or this slice's
   streaming calls) can find the mapping gone if the compiler ends
   the seer's lifetime before the raw-pointer call. Evidence:
   strace showed the single full-extent `munmap` of the fixture
   landing exactly at the seer's last source-level use;
   `test_weight_residency_real` (A-020) passes only because it
   happens to use its seer again after its accounting call. Fix
   in-slice: the bench carries a documented lifetime anchor (a seer
   use after the final accounting call). **Recorded follow-up
   (next work, not this slice):** consider hardening the A-020
   accounting API to take the seer rather than a raw pointer, so
   the lifetime is carried by the type.

## Notes

- The previous lead's incomplete draft
  `aesir_engine/core/.oversized_streaming.mojo.musegadget-partial`
  was removed once its design had been completed into
  `oversized_streaming.mojo` (design kept: window sweep, FNV-1a
  checksum, StreamAccounting shape, fail-closed madvise).
- Disk watch: fixture is 42,950,284,128 bytes on a 1.7 TB home
  volume (153 GB used at bench time); no large files were built
  beyond it.
- No README.md touched. No merge, no push — commit only, for the
  keeper to cherry-pick in roadmap order.
