# J-019 — Disk Reading Discipline, Measured

**Slice:** J-019 (Part II — Models Bigger Than Memory), Project Aesir Janas clean-room road.
**Roadmap text:** "Streaming reads that do not fight the OS (sequential expert reads, readahead where it pays, direct/async I/O as Mojo and the platform allow), measured against plain mmap paging on the same files."
**Built + measured:** 2026-10-31 ~03:57–04:20 EDT. Module compile + unit test on the VM; measurement on **purplelongship** (Ryzen 9 / RTX 2060 laptop line, NVMe, kernel 7.0.0-38-generic). **No Janas material was used or needed** — this slice stands on J-015/J-016/J-017/J-018 evidence; the clean-room law was not engaged.
**Spec stood on:** J-017 §3.3 (offsets/sizes from the tensor directory only), J-017's J-019 contract (miss stream = whole-expert demand at cache-dictated points), J-018 (the cache whose misses this discipline serves).

---

## 1. What was built

`aesir_engine/core/stream_reader.mojo` — a standalone, tested engine module in the tree's own style, plus `aesir_engine/tests/test_stream_reader.mojo`, wired into `aesir_engine/tests/run_all.mojo` as case `io.stream_reader` beside `io` neighbours.

- **Explicit pread slab reads** at directory-true offsets: `read_slab(offset, size, buffer)` loops over partial preads, raises on error or short file — a slab is fully read or the read has failed, never silently partial. Exactly the missed bytes move; nothing depends on the page-fault path's readahead window.
- **Readahead as a request, not a hope:** `advise_willneed(offset, size)` issues `posix_fadvise(POSIX_FADV_WILLNEED)` for a future slab; `advise_sequential()` declares the descriptor's pattern. Advice ranges need no alignment (the kernel rounds), unlike `madvise` over 32-byte-aligned GGUF slabs. Counters (`reads`, `bytes_read`, `advice_calls`, `advised_bytes`) are kept in the J-016/J-018 vocabulary, advice counted separately so streamed-byte totals stay comparable with the expert cache's `bytes_streamed`.
- The `external_call` surface is the one the tree already uses (`open64`/`pread` as in `loader/huggingface.mojo`, `close`/`unlink` as in CLI storage).

**Tests (PROVEN, VM, this run):** `mojo run -I aesir_engine aesir_engine/tests/test_stream_reader.mojo` (via the project's pixi env; only this test target built — VM MemAvailable ≈ 0.6–0.9 GB throughout, no inference):

- `PASS: stream reader slab reads, advice, accounting, EOF refusal`
- `PASS: StreamReader(path=/tmp/aesir_stream_reader_test.bin, reads=2, bytes_read=1691, advice_calls=2, advised_bytes=2048)`

The fixture test covers: an unaligned (480 B) GGUF-shaped slab read byte-exact, advice accepted + counted separately, a second slab at a different offset, a read past EOF refused and **not** counted, a mismatched buffer refused before any syscall. The full `run_all` runner was not executed (same VM memory constraint as J-018; it also carries a pre-existing unrelated segfault on the base tree).

**Integration gap, stated honestly (same as J-018):** Aesir still has no MoE forward/loader path to wire a reader into. The module is standalone and tested, ready for the Part II integration slices to call on a cache miss. Nothing was faked.

## 2. Measurement method

Harness: `j019_disk_bench.py` (filed beside this doc; results in `j019_results.jsonl`, sha256 `040fcc7eeb08d531e72edbb1e7667c20ed4dcadb3321ef58dff2565bd90323da`).

- **File:** OLMoE-1B-7B-0924-Instruct Q4_K_M, 4,213,512,672 B, sha256 `8c310f1435a1222338fd2d3d974975be9cd908180b644bab0c2a94da1ac32f3f` — the J-015 pin, re-verified on-box this run.
- **Demand (never invented):** the J-016 trace (`j016_trace_olmoe.jsonl`, sha256 `85e1d2413cbfcd43516a03d8463c7266d486cf0f0d0a6ed3104d09111facf99a`, re-verified) replayed through a pair-capacity LRU at the harness defaults — first **16 tokens, cap 512 pairs → 2,048 accesses, 914 misses, 2,742 slabs, 3,475,193,856 demand bytes** (mean slab 1,267,388 B). Each miss expands to its expert's 3 slabs at directory-derived offsets/sizes, in file order.
- **Consume proxy:** every byte read is consumed with `zlib.crc32` (dequant must touch every byte anyway). **All 12 demand legs agree on checksum 5887966450294**; the two `seq` legs agree on the whole-file checksum 1024807065271. A disagreement would have invalidated the run.
- **Cold is measured, not hoped:** each cold leg first evicts the file with `POSIX_FADV_DONTNEED` and reports the mincore-resident fraction — **0.0 for all 7 cold legs**. Warm legs run the identical workload immediately after the cold pass of the same strategy.
- **Machine state (stated for every number):** purplelongship otherwise idle **in the gaps of the 204 road's S-088 work** — S-088's `run_all` build was live at 04:10–04:17 and was yielded to; every leg pair ran only after an in-invocation guard confirmed no S-088 / `run_all` / `mojo build` process, with 1-minute loadavg **0.16–0.38** recorded per leg in the results file, MemAvailable ≈ 37.4 GB, GPU idle (1 MiB), Tctl 39.1 °C before the legs, ≤58.8 °C during. Legs ran as separate invocations per strategy pair, guard re-checked each time. These are single-pass walls on an idle machine, not a soak — class **MEASURED** for the comparisons, with warm-leg deltas read as indicative (§4).

Strategies: `seq` = sequential pread of the whole file in 8 MiB chunks (bandwidth ceiling reference); `mmap` = plain mmap paging, exactly as Aesir's current loader exposes weights; `mmap_wn` = mmap + `madvise(MADV_WILLNEED)` for the next slab (page-aligned cover — madvise cannot take the slab's own 32-byte-aligned range); `pread` = explicit `os.pread` of exactly the needed slabs; `pread_ra` = pread + `readahead(2)` for the next slab while the current is consumed, `POSIX_FADV_SEQUENTIAL` at open; `pipe` = pread + a helper thread keeping `posix_fadvise(WILLNEED)` 8 slabs ahead of the reader; `odirect` = O_DIRECT pread of each slab's 4096-aligned cover extent (raw O_DIRECT on a 32-byte-aligned slab is impossible; the cover's over-read is counted).

## 3. Results (purplelongship, 2026-10-31 04:18–04:20 EDT)

Demand legs move 3,475,193,856 B in 2,742 slabs; `seq` moves the whole file (4,213,512,672 B).

| Strategy | Cold wall (s) | Cold GB/s | Warm wall (s) | Warm GB/s | Slab mean cold (ms) | Slab p50 cold (ms) | Slab p95 cold (ms) |
|---|---:|---:|---:|---:|---:|---:|---:|
| seq (ceiling ref) | 2.732 | 1.542 | 1.542 | 2.732 | — | — | — |
| mmap | 2.874 | 1.209 | 1.002 | 3.469 | 1.045 | 1.113 | 1.673 |
| mmap_wn | 2.792 | 1.245 | 1.018 | 3.414 | 1.016 | 1.089 | 1.573 |
| pread | 2.529 | 1.374 | 1.085 | 3.203 | 0.920 | 0.974 | 1.374 |
| **pread_ra** | **2.364** | **1.470** | 1.111 | 3.127 | 0.860 | 0.918 | 1.355 |
| pipe | 2.486 | 1.398 | 1.094 | 3.176 | 0.904 | 0.935 | 1.364 |
| odirect | 2.363 | 1.471 | 2.338 | 1.486 | 0.860 | 0.793 | 1.177 |

Warm slab means: mmap 0.363 ms, mmap_wn 0.369, pread 0.394, pread_ra 0.404, pipe 0.397, odirect 0.850. O_DIRECT over-read: **11,231,232 B** (0.32 % of demand) in both its legs.

## 4. Reading the table

- **Cold, the case that matters** (a bigger-than-RAM model lives cold): explicit pread beats plain mmap by 12.0 % of wall (2.529 s vs 2.874 s); adding next-slab readahead (`pread_ra`) beats mmap by 17.7 % (2.364 s) and plain pread by 6.5 %. The pipelined-advice form (`pipe`, the threaded twin of the module's `advise_willneed`) also beats plain pread (2.486 s) but not the inline `readahead(2)` form on this device. `madvise` on the mmap path buys almost nothing (+2.9 %) — the fault path, not the advice, is mmap's cost.
- **Warm legs are consume-bound in this harness:** all page-cache strategies land in a 3.13–3.47 GB/s band (~±5 %), because the crc32 consume dominates once no disk wait remains. mmap's nominal warm lead (3.469 GB/s) is an artefact of skipping a copy the real engine cannot skip — a cache miss must land bytes in a cache-owned buffer, which is exactly what pread does. Warm deltas are therefore **MEASURED-INDICATIVE**, not a ranking.
- **O_DIRECT is rejected on evidence:** its cold wall ties `pread_ra` (2.363 s vs 2.364 s) but it has no warm state at all (2.338 s "warm" ≈ its cold wall — it bypasses the page cache by design, so any slab re-read pays full disk price), it over-reads 11,231,232 B, and it needs aligned-cover machinery around 32-byte-aligned slabs. No measured gain, real costs.
- **`seq` is a ceiling, not a candidate:** reading the whole file sequentially (1.542 GB/s cold) is faster per byte than any demand pattern — and reads 738 MB the router never asked for in this workload alone. Demand discipline wins on bytes; readahead closes most of the per-byte gap.

## 5. Verdict (DECIDED for J-019)

**Aesir's streaming path reads cache misses as explicit pread of exactly the missed slabs, with readahead advice issued for the next slab while the current slab is consumed** — the discipline `stream_reader.mojo` is built to: `read_slab` (pread, exact bytes, directory-true offsets) + `advise_willneed` (`posix_fadvise(WILLNEED)`, unaligned-safe) with `readahead(2)` as the inline equivalent where a caller prefers it. Plain mmap paging — the current loader's shape — is the slowest cold discipline measured and is not the streaming path. O_DIRECT is not offered (§4). The integration slices (MoE core, later Part II) call this reader on a J-018 cache miss; J-020 owns cold/warm behaviour of the assembled path, and J-029 owns the final NVMe-vs-page-cache verdict at full scale.

## 6. Async I/O and O_DIRECT honesty

- **Async I/O: NOT PROVEN.** True async submission (io_uring, POSIX AIO) has no binding in this tree and no stdlib surface in Mojo 1.0. The module deliberately does not fake an async interface. What the measurement shows is that the overlap async would buy is largely available synchronously on this device: advice issued one slab ahead (`pread_ra`/`pipe`) captures the win (cold 1.398–1.470 GB/s vs 1.374 plain pread, 1.209 mmap). An async binding remains a legitimate future spike; it is not this slice's claim.
- **O_DIRECT: measured, rejected (§4)** — not unmeasured-dismissed: cold tie, warm collapse, +11,231,232 B over-read, alignment machinery. The module header records this so no later slice re-litigates it without new evidence.

## 7. Defects and incidents in scope

- No defect was found in the inherited module/test/harness: the test passed as written and all 14 bench legs completed with checksum agreement. (Verified, not assumed — the test was compiled and run this session; the harness's workload line, resident fractions and checksums were read from its own output.)
- Transfer incident (recorded, no evidence harmed): the first attempt to move the harness to purplelongship by chunked base64 `file.write` corrupted one chunk in re-emission and wedged the write session (byte-count + sha guards caught it; the partial staging file was never committed as the target). The harness was instead banked to the slice branch first and fetched on-box by git sparse checkout; on-box sha256 `f78afe47…` matched the local file exactly before any leg ran.
- One field of the returned results file (pipe:warm slab p50/p95) was corrupted in this worker's return transcription and was repaired against the on-box console output of the same run before banking; every other field was cross-checked against that output. The on-box original remains at `~/j019/results.jsonl` on purplelongship.

## 8. NOT PROVEN / carried forward

- **Live streaming run:** no Aesir run streams an expert yet (no MoE forward path) — the reader + cache pair is proven as units and by trace-shaped measurement, not assembled. J-020/J-022 own the assembled proof.
- **Full-scale / soak behaviour:** 16 tokens × 914 misses is the J-016 demand shape at bench scale; J-029 re-takes NVMe-vs-page-cache at full scale and J-033 soaks it.
- **Other files/families:** Granite and `qwen2moe` slab geometry differs (J-015: split runs, different slab sizes); the discipline is offset-agnostic by construction, but its numbers here are OLMoE-on-this-NVMe numbers.
- **Async I/O** (§6): NOT PROVEN, no binding exists to measure through the engine; the harness's `pipe` leg is a Python-thread measurement of advice pipelining, not an engine async claim.
- **Decode-phase demand:** the J-016 trace is prompt-phase with 4 generation tokens; steady-state decode demand may favour different lookahead depths (J-020/J-025 measure prefetch on the assembled path).

**Evidence files.** Repo `docs/janas/`: this document + `j019_disk_bench.py` + `j019_results.jsonl`. Campaign records `~/workspace/model-tests/janas/`: this document, `j019_disk_bench.py`, `j019_results.jsonl`. Engine: `aesir_engine/core/stream_reader.mojo`, `aesir_engine/tests/test_stream_reader.mojo`, `run_all.mojo` registration. On purplelongship: `~/j019/` (harness, results, sparse tree). No README touched anywhere.
