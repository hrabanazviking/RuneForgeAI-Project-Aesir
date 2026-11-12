# A-049 — Oversized-model streaming

Roadmap acceptance: *coherent short generation + memory accounting
showing streaming, not full residency*, for a model too large for
comfortable residency, consumed via mmap streaming on unified memory.

Verdict: **PASS** on all three legs of the standalone proof
(`aesir_engine/tests/bench_oversized_streaming_a049.mojo`, run by
`hidden_files/run_a049_bench.sh`; full output in
`hidden_files/a049_bench.log`). Standalone harness (+0 E-MASTER
cases) follows the A-046/A-048 pattern: the proof needs a 43 GB
fixture and OS residency sampling over a full 40 GiB pass, which the
in-suite harness (no fixture path, seconds-scale) cannot host. The
E-MASTER suite itself is unchanged and green at baseline (see the
ledger).

## Fixture

`hidden_files/fixtures/oversized_a049.gguf` — synthetic oversized
fixture built from real tensors, as the roadmap permits. Builder:
`hidden_files/build_a049_fixture.py`. It takes the pinned
stories260K F16 GGUF (601,248 bytes, sha256
`57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3`,
the A-004 Capability Ledger pin) and emits a valid GGUF v3 whose
tensor directory is the original 48 tensors byte-identical plus 160
pad tensors `stream.pad.0000..0159.weight`, each F16
[16384 x 8192] = 256 MiB of payload built by repeating the real
`token_embd.weight` bytes. The embedded model is therefore
bit-identical to the pinned fixture and must generate identically;
the pads make the file oversized.

- File bytes: 42,950,284,128 (40.0 GiB)
- File sha256: `32a244be1954a5fbbe8812ca7eee5e1e64a9be7ad9fe4ed1e70ebb24866da4e1`
  (pinned by the bench runner before AND after the run; unchanged)
- Tensors: 208 (48 real + 160 pad); pad payload 42,949,672,960 bytes
  starting at file offset 611,168
- The fixture is git-ignored (43 GB); it is regenerable byte-for-byte
  from the committed builder + the pinned source fixture.

Loader residency split (A-020 `WeightResidency.account`, live):
tensor payload 42,950,259,968 bytes, of which zero-copy (aliased
into the mmap) 42,950,257,152 and converted-source 2,816 — duplicate
resident bytes are exactly the 2,816 converted-source bytes. Mapping
resident before any pass: 589,824 bytes.

## Leg 1 — coherent generation over the oversized file

The ordinary engine (`AesirEngine`) generates 32 greedy tokens from
the canonical prompt "One day, Timmy went to" over the oversized
file's mmap. Result: **exact match with the pinned A-004/A-020
oracle, 32/32 tokens** —
`265 282 295 433 335 345 357 426 342 394 261 370 268 414 444 335
261 370 268 414 444 426 291 268 414 444 286 399 262 423 388 269`,
decoding to the coherent TinyStories text "the park with his mom.
They saw a big box with a big box. The box was very small and ...".
Generation touches only the 0.6 MB embedded model; the 40 GiB of pad
payload is never faulted by the forward path.

## Leg 2 — streaming sweep (the new module)

`aesir_engine/core/oversized_streaming.mojo` adds the discipline and
the accounting the loader lacked: `OversizedStreaming.sweep_region`
walks a mapped region in fixed windows, checksumming each window
(the read is the touch), prefetches the next window with
`madvise(MADV_WILLNEED)`, and hands each consumed window back with
`madvise(MADV_DONTNEED)`. Per the A-008/A-020 zero-copy rule there
are no staged copies: the only memory in play is the file's own mmap
pages on the unified-memory host. Residency is measured, not
asserted — process VmRSS and the mapping's smaps resident bytes via
the A-020 /proc-backed accounting, sampled after every window.

Over the 40 GiB pad region with a 256 MiB window (160 windows):

| measure | bytes |
|---|---|
| bytes streamed (touched) | 42,949,672,960 (all of the region) |
| bytes handed back (DONTNEED) | 42,949,017,600 (9,999 bp) |
| peak mapping resident | 269,869,056 |
| final mapping resident | 1,269,760 |
| peak process RSS during sweep | 324,911,104 |

Peak resident is ~1.005 windows — 0.63% of the region — instead of
growing with the region. The 655,360 un-dropped bytes are exactly
one page per window: the drop range is page-rounded *inward*, so
the accounting never overstates what was handed back (the pad
region starts at the unaligned offset 611,168).

## Leg 3 — control: same walk, no dropping

`touch_region` repeats the identical checksum walk with no madvise.
Its checksum is bit-identical to the sweep's (10,358,989,207,356,497,221
— both legs read the same bytes), and its mapping resident grows to
42,950,287,360 bytes with process RSS 43,005,329,408: **full
residency**. The contrast is the acceptance evidence — same file,
same bytes read; the sweep's residency is bounded by the window,
the naive pass's by the file size. After the control, the bench
hands the pad region back (42,949,668,864 bytes dropped; mapping
resident returns to 618,496), leaving the host as found. Total
bench wall time for both 40 GiB legs plus generation: ~17 s.

## Honest limits

- madvise is advisory: MADV_DONTNEED on clean file-backed pages
  discards them (a later touch re-faults from disk), which is
  exactly the residency bound claimed — no promise is made about
  kernel readahead beyond the measured peak above.
- The streamed region here is pad payload, not live weights: the
  roadmap's fixture clause accepts a synthetic oversized fixture
  built from real tensors, and the generation leg runs on the real
  embedded model in the same file. A model whose *weights alone*
  exceed the pool is A-104's separate acceptance.
- CPU mmap path only; no accelerator claim is made for this slice.
