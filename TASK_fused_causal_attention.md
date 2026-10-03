# SPD-03 — bounded shared-score causal GQA primitive

Established 2026-10-03 before implementation. Paired FFN implementation ab25283
and CI correction 730f898 are pushed; exact final CI remains pending. All four
paired shapes fail to beat both available owners. The accepted long model trace
identifies attention as a remaining measured bottleneck. Volmarr authorizes the
next scoped implementation/push/repeat through Mythic Engineering.

First preserve arithmetic rather than introduce online-softmax reductions.
Separate optional native module uses one 128-thread CTA per query head/token.
Four warps compute scores in the original lane-stride F32 dot / warp sum order,
warp0 normalizes with original maximum and lane-stride sum, and 128 lanes consume
normalized shared scores with original chronological four-value accumulation.
All warps execute the stage barriers. Shared scores are fixed 4096 F32 cells
(16 KiB per CTA), no global score workspace/new production import/selection.
Explicit strict3B GQA geometry24 query heads/8 KV heads/head128; adjacent causal
counts prefix+token+1, grouped-head mapping head*8//24. Batch1/4/32, partial token
tails, capacity1..4096 only. The original three kernels stay verbatim.

Pure admission checks shape, capacity, prefix/tokens, bounded stride and every
F32 query/output and F16 full K/V span, plus query/output alias fences before
GPU enqueue. Reject hostile metadata before constructing CUDA context. Nonfinite
payloads do not earn acceptance; physical collector and independent validator
require finite full outputs and immutable input/canary ownership. No host copy in
production wrapper. Explicit current supported scope, no general attention claim.

Probe deterministic, exactly representable query/F16 K/V patterns, zeros and
large stable-softmax logits. Cover first/31/32/33/37/255/256/257/1070/1535/1536/
4095/4096 causal endpoints, partial query batches and GQA heads. Original uses
scores -> softmax -> tiled values per query, fused emits one batched launch.
Export every native/candidate F32 result as exact Float64 text, require UInt32
identity including signed zero, immutable complete query/K/V cells and unowned
guards. Independent pinned NumPy Float64 computes all causal score/softmax/value
outputs from natively checked deterministic inputs. Fixed budgets established now:
0.002 maximum scaled error /0.0002 normalized RMS against independent reference.
No changing tolerances or scoring partial output after seeing physical results.

Ten rotated samples per case, three actual attention calls per owner plus sync;
all samples retained. Allocation/export/input generation/oracle/process/build
unscored. Strict bounded no-follow ordered CSV schema owns complete case/input
identity/counts/guards/timings. Source binary/CSV hashes before/after, exclusive
failed JSON, finite atomic ratios only after full bits/math/input/guard gates.
Portable malformed/duplicate/order/signed-zero/nonfinite/underflow/overflow/
special-file/hash/interrupt contracts and native opt-in compile join existing CI.

Finish sm75/sm89/original/master/normal/check builds before serialized GPU capture,
then independent CPU oracle. Preserve all failures and source/artifact/UTC hashes;
verify unchanged authenticated active normal prefill4. Publish complete evidence,
operator/AI MD and owning interfaces, ledger/TODO/roadmap/devlog; push and verify
exact CI. Winning primitives still need actual model Q/K/V, complete logits/cache/
IDs/causal state/generation/replay/control/context/device/concurrency/soak/runtime/
provider gates. Shared-score fusion is distinct from future online-softmax work.
