# A-037 — Decode hotspot census (Z13, purpleraider)

Slice A-037, team-04, branch yrsa/aesir-team-04, base d98da7fb
(A-033 banked, 33 of 216). Wave 5 opener. Roadmap:
"Profile CPU decode on the Z13; top-5 kernels by self-time.
Acceptance: census table filed from profiler logs; every later
slice in this wave names its census row."

## Fixture and method
- Fixture: stories260K.F16.gguf, sha256
  57a81ed1c8b032ba29319eae80c3e568dbb5a16ce665a09da1a0efe2e4eb69e3
  (exact pin match, verified before the run in this worktree).
- Driver: aesir_engine/tests/bench_decode_census_a037.mojo,
  sha256 d2617dba684739b062b146ab07dd3edc7388f7b52e69632859276c50bc284659.
  Standalone (not in run_all). Per repetition: 8-token canonical
  prefill + 32 greedy decode steps through forward_pass (the
  single-token decode path), KV arena recycled per repetition via
  MimirWell.reset_kv_cache(mark) — the A-030 arena discipline.
  1,200 repetitions = 38,400 decode tokens, every repetition's 32
  greedy IDs checked exact vs the pinned llama.cpp oracle (A-004
  pattern, raw-oracle discipline, CPU vs CPU).
- Profiler: perf 7.3.0 (native). perf_event_paranoid=4 blocks
  unprivileged hardware events, so record/stat ran via sudo -n
  (the machine's standing sudo road, cf. A-007 xrt-smi note):
  perf record -F 997 -g, event cpu/cycles, 4,984 samples,
  event count approx. 24,099,455,746 cycles, 0 lost samples.
  perf.data sha256 3060ec2b64b09bbd46fcc1ce17dec84ca551c6036511c441547222e08a114e92.
- Runs (all PASS, oracle-exact): plain 8,141.9 tok/s aggregate,
  perf-stat run 8,142.8, perf-record run 8,135.1 — aggregate here
  counts only the 32 decode tokens per repetition while the
  elapsed span also contains the 8-token prefill and arena reset,
  so it sits below the A-030 pure decode median 8,745.9 tok/s as
  expected. perf stat (record run's sibling): 24,322,411,567
  cycles, 62,741,844,297 instructions, 9,507,209 cache-misses,
  4.746 s elapsed.
- Machine conditions: purpleraider, kernel 7.3.0-10-generic,
  2026-11-12T06:33-06:34 EST, load average 0.68/1.08/1.24 at
  start, 0.98/1.12/1.25 at end; no other crew's install logs
  active (/tmp/toolstage*.log, /tmp/pkginstall.log absent).
- Execution: CPU path only. No accelerator execution is claimed;
  this is a CPU census of an F16 fixture, so quantized dequant
  paths (Q8_0/IQ/K-quant) are NOT exercised — A-038/A-039/A-040
  must profile their own quant fixtures and cite row C-001 as
  the GEMV-family row they extend, not as a measurement of
  their quant kernels.
- Evidence: team-04 hidden_files/a037_perf_report_n.txt
  (sha256 44437058c2d45d0737fae098f6d8765d22a91419d0c6b354896eda3cc1325cd7),
  hidden_files/a037_perf_report_nochildren.txt
  (sha256 f21775cf135a018b0ce38a74fbbbd95e1c5c76b611a990156c97972fc65a1c23),
  hidden_files/a037_perf_stat.log, hidden_files/a037_perf.log,
  hidden_files/a037_bench_record.log. Every number below is
  read from those logs; nothing is estimated.

## Census table — top-5 by self-time (perf --no-children)

| Rank | Census row | Kernel / function (exact perf symbol) | Self-time % | Samples | Evidence |
|---|---|---|---|---|---|
| 1 | A-037:C-001 | core::compute::_gemm_f16_dense_range | 22.21% | 1050 | a037_perf_report_n.txt row 1 |
| 2 | A-037:C-002 | core::compute::flash_attention_gqa | 17.93% | 843 | a037_perf_report_n.txt row 2 |
| 3 | A-037:C-003 | core::inference::TransformerBlock::forward (self, non-inlined remainder) | 4.39% | 208 | a037_perf_report_n.txt row 3 |
| 4 | A-037:C-004 | [k] kernfs_iop_permission (kernel, sysfs path of the cpu-count lookup — see cluster note) | 3.49% | 164 | a037_perf_report_n.txt row 4 |
| 5 | A-037:C-005 | [k] kernfs_dop_revalidate (kernel, same sysfs lookup) | 2.94% | 139 | a037_perf_report_n.txt row 5 |

Top-5 total: 50.96% of sampled cycles. Remainder is a long tail
(no other single symbol above 2.56%).

## Extended rows (next engine symbols + grouped overhead)

| Census row | Symbol / group | Self-time % | Samples | Note |
|---|---|---|---|---|
| A-037:C-006 | core::sampler::sample_token_from_logits | 2.56% | 121 | A-044's row: sampling is small but not <1% at this model scale |
| A-037:C-007 | core::compute::apply_rope | 1.05% | 49 | RoPE per token per layer |
| A-037:C-008 | GROUPED: per-dispatch config lookup — kernfs_iop_permission 3.49 + kernfs_dop_revalidate 2.94 + sysfs_kf_seq_show 1.04 + kernfs_fop_open 0.51 + link_path_walk 0.49 + __read_nocancel 0.48 + read_sysfs_file 0.47 (kernel subtotal 9.42%) plus core::parallel::_env_int 1.44 + getenv 1.38 + __strtoull 0.57 (user subtotal 3.39%) | 12.81% grouped | — | Call chains in a037_perf_report_nochildren.txt: sysfs opens via __get_nprocs <- aesir_par_cpu_count (thread_par.c) and getenv parsing via core::parallel::_env_int (parallel.mojo) — i.e. thread-count/env config is re-read through syscalls during decode dispatch instead of being cached once. C-004 and C-005 are members of this group; do not double-count. |

## What this explains about the A-030 baseline
- The dense F16 GEMV family (C-001) + attention (C-002) together
  are 40.14% of decode cycles — the compute core of the token
  loop, and the Wave 5 attack surface: A-038/A-039/A-040 cite
  C-001, A-043 cites C-002, A-044 cites C-006, A-041 cites C-008.
- Roughly 1 cycle in 8 (C-008, 12.81% grouped) is neither GEMM,
  attention, nor sampling: it is per-dispatch thread/env
  configuration re-read through sysfs and getenv. That is a
  discovered inefficiency, recorded as immediate next work in
  team-04 CAMPAIGN_STATE.md (cache the thread/env config once;
  natural home A-041 thread scaling law). Not fixed inside this
  census slice: the slice is measurement-only by roadmap design
  and the fix touches the shared parallel dispatch used by every
  backend path.
- Verdict: A037_CENSUS: PASS — table filed from profiler logs,
  all runs oracle-exact.
