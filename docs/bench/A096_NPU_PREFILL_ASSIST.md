# A-096 -- NPU prefill-assist experiment

Slice A-096 (Wave 11, NPU first light). Question: when the NPU
computes a prefill chunk while the GPU decodes the previous
token, is the overlap benefit real and measurable on this Z13,
or does dispatch/sync overhead eat it?

## Verdict: POSITIVE, measured (3 runs, 21 reps each)

Overlap wall tracks the longer pole (GPU decode) instead of
the serial sum: the whole NPU prefill is hidden, plus the
serial mode's back-to-back penalty. Median benefit over
serial: 4,198 / 4,289 / 3,819 us across the three runs.

## Workload (mixed, concurrent)

- Prefill (NPU): projection GEMM 128x1024x1024 i16->i32, the
  A-094 FIT shape, banked A-092/A-094 xclbin (uuid
  184c0a55-97ee-d107-bad0-060c59a9a278), XRT 2.25, sudo.
- Decode (GPU): GEMV 1024x1024 fp32 x 64 reps in one Vulkan
  compute dispatch on AMD Radeon 8060S (RADV STRIX_HALO,
  gfx1151) -- decode-shaped (M=1 per rep), previous-token work.
- Modes per rep: NPU alone, GPU alone, serial (NPU wait, then
  GPU), overlap (NPU start; GPU submit+wait; NPU wait+sync).

## Results (medians of 21 reps, us)

| Run | NPU alone | GPU alone | Serial | Overlap | Benefit |
|---|---|---|---|---|---|
| 1 | 2,597.9 | 4,421.4 | 8,309.5 | 4,111.1 | 4,198.3 |
| 2 | 2,645.3 | 4,453.7 | 8,289.2 | 4,000.2 | 4,289.0 |
| 3 | 2,237.2 | 4,056.7 | 7,915.5 | 4,096.4 | 3,819.0 |

Notes: serial exceeds the sum of alone-medians by ~1.2-1.6 ms
every run (sequential dispatch/sync penalty on unified
memory); overlap sits within +/-5% of GPU-alone, i.e. the
~2.2-2.6 ms NPU prefill contributes ~0 to the overlapped
wall. Logs: hidden_files/a096/a096_run{1,2,3}.log.

## Correctness (device-execution evidence, every run)

- NPU: device_name=NPU Strix Halo from the live XRT handle,
  ert_cmd_state=4 (COMPLETED), 131,072 elements exact vs the
  in-program CPU oracle, 0 mismatches, 0 sentinels, checksum
  2848816214485251074 -- identical to team-25's independent
  A-095 p128 run of the same shape/design.
- GPU: device AMD Radeon 8060S Graphics (RADV STRIX_HALO)
  from VkPhysicalDevice properties; GEMV max abs err 0.000035
  vs the CPU oracle (fp32 tolerance).

## Dependency on A-095 (honest status)

A-095 (team-25, registry offload implementation) had NOT
committed or banked when A-096 ran: team-25 was still on its
92-base with prep + live measurements in flight (its p128
NPU median 2,518 us corroborates this slice's NPU-alone
2,237-2,645 us). A-096 therefore did not duplicate the
registry offload; it measured the concurrency premise that
offload relies on, directly on banked A-092/A-094 artifacts.
When A-095 lands, its end-to-end effect should be re-checked
against these overlap numbers.

## Harness

spikes/a096_prefill_assist/overlap_probe.cpp (+ gemv.comp);
build/run recipe in hidden_files/A096_LEDGER.md.
