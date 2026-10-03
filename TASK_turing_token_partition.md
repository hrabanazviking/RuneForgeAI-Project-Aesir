# SPD-01/04 — bounded per-CTA token partition experiment

Established 2026-10-03 before code, under Volmarr's standing next-slice/push/repeat
authorization. Fused trace12dc782 passes full physical source/vector/cache/ID/state/
guard/resource/correlation gates and is pushed; exact CI pending. Replay d6990ff
and controls f960564 exact36-step CI pass. Long fused4 trace attributes57.1693%
of summed kernel durations to batch32 gate/up/down; actual selected staged64 and
down128 record255 registers/thread. Resource values do not prove an occupancy or
spill cause. Retained narrower staging, bounded loops and paired gate/up experiments
did not improve the selected path. Hypothesis: fewer simultaneous token MMA
accumulators per CTA could reduce live state, with repeated weight decoding cost.

Create separate native Mojo packed_turing_partition module, preserving all original
kernel definitions and runtime/model/control/trace selections. Logical batch4/8/16/32
uses compile-time token tiles8/16 and row tiles64/128; one two-dimensional enqueue
partitions token ownership through gridY=ceil(actual tokens/token_tile). Each CTA
owns disjoint global token rows, original32-column packed decoding/high+residual
weights/original F16 inputs and original chronological two-MMA F32 accumulation.
All lanes initialize shared cells and reach both barriers, including row/token tails.
No global workspace, columns split/reduction, new precision, dependency/toolchain
upgrade or runtime fallback. Original resource admission and pinned public PTX65
target remain. Pure complete borrowed-span admission precedes enqueue; reject bad
format/shape/offset/overlap/allocation/token geometry before launch.

Add explicit optional final partition row/token template parameters to primitive
harness without changing legacy defaults/schema/dispatch. New source mode and CLI
require row64/128, token8/16 and original width32; unknown flags refuse before model.
Three current-session owners: native four-reference, partition candidate and actual
selected original (down128 only for canonical down batch32; staged64 otherwise).
Record selected-original marker and case dispatch geometry/counters. Native owner
full outputs, actual candidate-vs-selected UInt32 bits including signed zero, complete
guard/input/tail checks, independent NumPy2.4.4/gguf0.19.0 Float64 real-weight dots
and unchanged .002 scaled/.0002 normalized RMS budgets are mandatory.

For each of four row/token variants retain144 synthetic format12/13/14/tail cases,
12 hostile span refusals,28 actual first-layer projection/batch cases with all
1,658,880 values per owner,2100 selected independent dots, all guards and840
ordered rotated/warmed host-monotonic launch+synchronize records. Native/selected/
candidate timing medians/ratios score only after every complete numeric/bit/oracle/
guard/hash/finite-positive sample gate; any failure retains complete metrics and
atomically withholds all ratios. Explicit partition parser/CLI remains closed by
default, binds actual binary before/after, rehashes original model/current CSV and
source/code/binary around collection/CPU validation. Exclusive JSON retains failures
and interrupts; retries use fresh artifacts. Portable hostile mode/geometry/order/
counts/F32/numeric/timing underflow-overflow/source/binary/hash/interruption/output
tests join CI. Preserve every failed build/capture/export.

Finish current sm75/sm89, original staged, existing down128, master and normal
build/check before serial four GPU runs, then serial CPU validators. No source
changes/compilation during physical capture. Master/legacy primitive/model/decode/
replay/control/trace gates remain. Observe authenticated unchanged normal prefill4
readiness. Publish detailed operator MD, owners, complete evidence, TODO/roadmap/
ledger/devlog, commit/push and verify exact-head CI. No selected/model/runtime change
from a primitive ratio alone. If an actual canonical batch32 FFN candidate beats
both current owners, next earn non-dyadic captured activation/full-model acceptance;
otherwise retain rejection and choose the next measured experiment. General
context/device/concurrency/soak/provider speed leadership remains open.
