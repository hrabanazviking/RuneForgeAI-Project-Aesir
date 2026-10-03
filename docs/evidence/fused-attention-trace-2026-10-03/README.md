# Owned fused attention and projection evidence — 2026-10-03

Both actual plain/profiled public37/1070 cases pass full original accepted default4
F32 bytes including signed zero, all cache digests, committed IDs/position/sampler,
actual rotary/elementwise/down/fused/original counters and4352 combined guards.
All513024 current logit values are retained. The exact source CSV/report and actual
source binary carry complete independent fixed zero-GPU F32 CPU and accepted3 byte/
cache/ID scope. Control-capable4 is not a source for this trace. No arithmetic,
kernel or workspace changes were made. Final tracing capability defaults False;
trace-capable4 controls/replay remain separately closed.

Complete short/long1869/32215 kernels and resource records validate actual process/
GPU/time/successful launch correlations before589/7449 exact ordered projection
ranges with981/20385 kernels, plus56/1008 interleaved owned fused children with
exactly one actual successful kernel enqueue each. No work is excluded. Selected
projection wrappers/down128 geometry and attention prefix/grid24x4/32x1/block128
agree with actual native source. GPU intervals are retained whole through launch
correlation; they are never clipped to asynchronous child CPU ranges.

| Owned batch32 stage | Kernels | GPU seconds | Share of summed kernels | Registers/thread | Static shared bytes | Grid/block |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| query | 924 | 0.448723 | 7.421% | 255 | 10560 | 48x1 / 128 |
| key | 7392 | 0.308567 | 5.103% | 63 | 0 | 256x1 / 128 |
| value | 7392 | 0.293176 | 4.849% | 63 | 0 | 256x1 / 128 |
| output | 924 | 0.446723 | 7.388% | 255 | 10560 | 48x1 / 128 |
| gate | 924 | 1.102364 | 18.231% | 255 | 10560 | 128x1 / 128 |
| up | 924 | 1.104120 | 18.260% | 255 | 10560 | 128x1 / 128 |
| down | 924 | 1.250297 | 20.678% | 255 | 19008 | 24x1 / 256 |
| fused attention | 924 | 0.787692 | 13.027% | 46 | 16384 | 24x32 / 128 |


Long batch32 FFN gate/up/down sum3.456781s of6.046571s summed GPU kernels
(57.1693%). Fused attention4/32 sums0.814218s
(13.4658%). These profiler durations guide the next experiment
and are not a service speed score, historical cross-capture ratio or provider lead.
Fused records46 registers/thread,16384 static shared bytes,0 dynamic shared and0
per-thread local bytes. Deprecated legacy local total is retained raw; it does not
establish spills, occupancy, a failure cause or uncovered CPU delay. Definitions:
[NVIDIA CUPTI](https://docs.nvidia.com/cupti/api/structCUpti__ActivityKernel8.html).

Nine portable hostile contracts and legacy trace/model/decode/checkpoint/control/
grid gates pass; master190 passes/zero fails/one skip. Seven target/original/bad-
capability/master/normal/check builds finish before serial GPU captures. Seven actual
invalid CLI/capability cases refuse before model/CUDA; CLI also refuses before NVTX/
CSV reservation. Matching installed2023.4 importer recovers split-package profiles;
all raw logs/qdstrm/reports/SQLite/process/build/binary/source hashes remain. Exact
pre/post current/source/code hashes agree, and original model is rehashed. Predicate
review and unit imported-TestCase collection errors were corrected before final
builds and physical capture; initial tool output remains in the chat history.

The authenticated normal f3442a1e service remains active/ready/prefill4/cpuoffload0.
Replay4 d6990ff and controls4 f960564 exact36-step CI have succeeded. This trace
publication and exact-head CI are recorded separately. Next measure reduced per-CTA
token accumulation for the dominant FFN projection, preserving original math and
complete primitive/model bit/oracle/guard/finite paired-sample gates. Broader
contexts/devices/production32/trace-or-control-capable replay/concurrency/soak/
persistence/provider comparison and overall AESIR speed leadership stay open.

[Operation](../../NATIVE_FUSED_ATTENTION_TRACE.md).
