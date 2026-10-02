# SPD-04 — admitted batched normalization/residual/SiLU in the optional fixture

Established2026-10-02 before code. Volmarr authorizes repeated scoped slices and
pushes. Follow accepted exact-state rotary/cache evidence with independent
per-token elementwise launch reduction. Production policy remains one/four.

## Owned design

Add a separate explicit dense_norm_strided_kernel[width,token_stride] beside
the unchanged fixed dense_norm_kernel reference/entry. Compile-time admission
requires positive stride>=width; group*stride uses identical per-lane
chronological sums/warp reduction/F32 weight/output operations. Existing normal
runtime definitions, instantiations and entry ABI stay intact. The strict fixture queues both per-layer3072-wide
norms across admitted1/four/32 rows, four warp groups per block. Inactive groups
never read/write or participate in another warp's reduction.

Expose public always-inline residual-cell and SiLU-cell device operations while
preserving current entry bodies. Test-owned grid-y wrappers reuse those original
F32 arithmetic operations with checked33824 token stride. Queue attention
residual, FFN norm, SiLU and final residual as separate dependent operations;
no arithmetic fusion/reordering within a token. Projection/attention dependencies
remain original owning-stream order, scalar paths use old entries. No added
global device buffers/weights/host inference or installed-library changes.

Default elementwise flag false. Explicit elementwise requires original precision0
and accepted batched rotary/cache flag. Bind replay execution strategy2 to actual
flags before reset; native owner stays0 and legacy0/1 remain unchanged. Preflight
every existing actual layout/length/profile/control gate before queueing.

## Fixed admission and evidence

Use a new explicit ATTENTION,rope_cache_elementwise_grid,1,32 marker; older
unknown rotary/cache mode2 remains unsupported. Shared parsers return internal
strategy2 only for this exact new marker, before META; all unknown/duplicate/
late/mixed metadata refuse. Model capture includes actual successful elementwise
host enqueue calls: original5 per token per28 layers plus one final norm; new
five per admitted tile per28 layers plus one final norm. Actual counts are host
calls, not profiler GPU-kernel counts. Reset counters on each fresh fixture run.

Measure the original four public30/37/31/1070-ID cases, all513024 logits per owner,
eight invalid tiles/4352 guards, full guarded-F16-cache SHA and32 warm/alternating
fresh timings. New2 must equal the just-accepted explicit1 complete vector bytes/
IDs/cache hashes under unchanged .05/.005/argmax CPU/native budgets. Require
accepted source model/CSV/report/scope/hash identity before any score; rehash
input/models/references after the CPU oracle. All quality/state/count/cache/byte
failures retain raw/complete reports and withhold every ratio. Report fresh
native-to-fixture exploratory ratios only, not cross-session/provider scores.

Repeat full96-frame greedy32/seeded16 decode/own-replay and bounded eight-frame
same-context checkpoint continuation with explicit strategy2. Every original
source/sample/state/bit/guard/independent budget remains. Add portable metadata/
counts/reference chaining/strategy refusal contracts, preserve legacy0/1 admission.
No alternative precision modes can evade previously failed stricter gates.

Finish sm75/sm89/master/normal builds before serialized owned GPU captures;
CPU-only numerical reference afterward. Preserve failed attempts/sources/logs,
normal binary/readiness and current runtime. Update owner interfaces/manuals,
evidence/ledger/TODO/roadmap/devlog, push then exact successful CI. Only original
strict3B/context1536/F16KV/sm75 earns physical acceptance. Broader kernel widths/
strides/models/devices, runtime32, persisted/context recreation, concurrency/soak,
fused attention and refreshed Ollama lead remain separate gates.
