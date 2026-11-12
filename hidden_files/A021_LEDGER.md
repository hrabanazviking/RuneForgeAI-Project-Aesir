# A-021 Ledger - KV cache in unified memory (team-07)

Slice: A-021 - KV layout allocated from the unified (A-019)
allocator, usable by both CPU and GPU kernels. Machine:
purpleraider (ASUS ROG Flow Z13, Strix Halo, Radeon 8060S
gfx1151 / RADV STRIX_HALO). Base: seat main 36d2c240 (A-019,
19 of 216 banked, ls-remote verified 36d2c2405be8...); A-007
confirmed banked in seat main by subject (2c1c8411) before the
branch reset --hard onto 36d2c240.

## Acceptance verdict: PASS with real device execution

## Layout spec

- Module: aesir_engine/core/kv_unified.mojo - KVLayout +
  UnifiedKVCache + kv_cpu_decode_step. NO second allocator:
  allocation/mapping/GPU dispatch/counters are core/zero_copy
  (A-019) exactly; HIP managed is the default backend, Vulkan
  is the HOST_CACHED coherent type only.
- Geometry: layers x kind(K=0,V=1) x seq<max_seq x heads x
  head_dim, contiguous Float32. offset =
  (((layer*2+kind)*max_seq+seq)*num_heads+head)*head_dim+dim.
  Token vector = num_heads*head_dim contiguous elements at
  token_offset(); K/V separation = max_seq*elems_per_token.
- Fail-closed: constructor rejects non-positive dims and any
  size overflow via checked multiplication (never wraps - the
  docs/bugs/0026 silent-wrap class); every coordinate checked
  explicitly AND through ZeroCopy.checked_f32_span before any
  pointer arithmetic. seq == max_seq, negative seq, bad kind/
  head/dim/layer, malformed append vectors, decode seq_len
  beyond capacity all raise.
- Map discipline (bug found in-slice, fixed): the Vulkan shim
  refuses double-mapping, so every CPU accessor maps, touches,
  and releases inside the call (release is a no-op on HIP).
  First suite build also exposed KVDecodeResult needing
  Copyable-only conformance (List field); fixed in-slice.

## Evidence (read from hidden_files/a021_run_all.log,
## sha256 d606acde9c859dab0157f694ac371a659cadce649554c65cdc251a296cc881a0)

All six new cases [CASE PASS]:
- gpu.kv_unified_layout: hand-computed offsets, K/V separation,
  token-base alignment, last coordinate == total-1.
- gpu.kv_unified_bounds: 9 bad coordinates + 7 bad geometries
  (zero dims, negative max_seq, two overflow shapes) rejected.
- gpu.kv_unified_gpu_write_cpu_read: HIP fill kernel wrote the
  whole cache (3 layers x 2 kinds x 64 seq x 4 heads x 16 dim =
  24576 elems); CPU read EVERY element through layout
  coordinates byte-exact vs the pattern formula; kernel-launch
  counter advanced, memcpy counter stayed 0. CPU decode step
  (layer 1, head 2, query.K scores + argmax + score-weighted V
  sum) matched an independent formula oracle bit-exactly
  (argmax seq 62).
- gpu.kv_unified_cpu_write_gpu_read (reverse): CPU wrote 2048
  elems through coordinates; HIP transform kernel read them
  (dst = src*2+1) byte-exact on CPU verify; memcpy = 0.
- gpu.kv_unified_append_roundtrip: append/read_token byte-exact
  at capacity edges; append at seq==max_seq, short vector,
  decode seq_len overflow, bad query length all rejected.
- gpu.kv_unified_vulkan_shared: Vulkan KV buffers assert type
  flags exactly 0xe (HOST_CACHED coherent, no 0x40 uncached);
  CPU coordinate writes -> A-015 vec_add GPU dispatch -> CPU
  read byte-exact (1024 elems); vk copy counter stayed 0.
  Device identity via the A-019 presence check: RADV
  STRIX_HALO, vendor 0x1002, non-software type; llvmpipe is
  refused by that check, never accepted.

## Suite (canonical shape, hidden_files/run_a021.sh - the seat
gate a019 script re-pointed at this worktree)

331 passed / 1 failed / 2 skipped / 334 total. Baseline at
36d2c240 (seat gate A-019): 325 / 1 / 2 / 328 - delta is exactly
the 6 new A-021 cases, zero regressions. Sole failure =
gguf.tensor_directory_interface, the pre-existing J-022 drift
(roads A-165 / A-121), unchanged. Skips = same 2 pre-declared.
MOJO_EXIT=1 is by suite design. run_all pin re-set 328 -> 334
with a house-style comment.

## Files in this slice

- aesir_engine/core/kv_unified.mojo (new)
- aesir_engine/tests/test_kv_unified.mojo (new): 6 cases above.
- aesir_engine/tests/run_all.mojo: +6 registrations, pin 334.
- hidden_files/run_a021.sh, hidden_files/A021_LEDGER.md
  (tracked, per house precedent); run logs stay on-device.
