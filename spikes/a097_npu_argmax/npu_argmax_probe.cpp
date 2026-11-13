// A-097 -- NPU sampler experiment host runner (Project Aesir, team-27).
//
// Loads an IRON/mlir-aie-built xclbin + AIE instruction stream for the
// single-core argmax design (spikes/a097_npu_argmax/design_argmax.py)
// through the system XRT C++ API, executes a REAL argmax over a bf16
// logits row on the XDNA 2 NPU, and verifies the merged result exactly
// against an in-program CPU oracle. Derived from the A-094 timing
// runner (spikes/a094_npu_timing/npu_timing_probe.cpp), which derives
// from the A-092 runner (aesir_engine/npu_matmul_probe.cpp).
//
// The design emits one 2-word record per tile of T logits:
// (winning value, bf16 widened to float and bit-cast to int32;
//  index within the tile). This host merges records in tile order --
// ties go to the lowest global index, matching numpy.argmax -- and
// compares (index, value bits) against the CPU oracle exactly.
// The logits contain a planted three-way tie for the maximum across
// three different tiles, so tie-breaking is exercised, not assumed.
// The output buffer is sentinel-prefilled; a kernel that never wrote
// cannot pass. Device identity comes from the live XRT handle and
// completion from run.wait()'s ERT command state.
//
// Timing: 21 warm NPU reps (fresh run object, BOs + hw_context
// resident, A-094 method), medians of run-only and run+sync. CPU
// baselines timed in-program on the same data: scalar bf16 argmax
// scan, an fp32 argmax scan over the widened row, and a top-k +
// softmax pass (the stochastic sampler's CPU shape) for pricing.

#include "xrt/xrt_bo.h"
#include "xrt/xrt_device.h"
#include "xrt/xrt_kernel.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <string>
#include <vector>

static inline float bf16_to_f32(uint16_t h) {
  uint32_t u = (uint32_t)h << 16;
  float f;
  std::memcpy(&f, &u, 4);
  return f;
}
static inline uint16_t f32_to_bf16(float f) {
  uint32_t u;
  std::memcpy(&u, &f, 4);
  uint32_t lsb = (u >> 16) & 1u;
  u += 0x7fffu + lsb;
  return (uint16_t)(u >> 16);
}

int main(int argc, char **argv) {
  if (argc < 5) {
    std::printf("usage: %s <xclbin> <insts.bin> <V> <T>\n", argv[0]);
    return 2;
  }
  const int V = atoi(argv[3]);
  const int T = atoi(argv[4]);
  const int tiles = V / T;
  const int32_t SENTINEL = 0x7fffffff;

  std::ifstream fi(argv[2], std::ios::binary);
  if (!fi) { std::printf("FAIL cannot open insts %s\n", argv[2]); return 2; }
  std::vector<char> ibytes((std::istreambuf_iterator<char>(fi)),
                           std::istreambuf_iterator<char>());
  if (ibytes.empty() || (ibytes.size() % 4) != 0) {
    std::printf("FAIL insts size %zu not a whole word count\n", ibytes.size());
    return 2;
  }
  const size_t ninstr = ibytes.size() / 4;
  std::printf("insts_bytes=%zu ninstr_words=%zu V=%d T=%d tiles=%d\n",
              ibytes.size(), ninstr, V, T, tiles);

  // Deterministic bf16 logits in [-2, 2) at 1/256 granularity, plus a
  // planted three-way tie for the max (3.5) in three different tiles.
  std::vector<uint16_t> logits(V);
  uint32_t s = 0xA097u;
  for (int i = 0; i < V; i++) {
    s = s * 1664525u + 1013904223u;
    float v = (float)((s >> 16) % 1024u) / 256.0f - 2.0f;
    logits[i] = f32_to_bf16(v);
  }
  const int tie_pos[3] = {100, T + 37, V - 123};
  for (int p : tie_pos) logits[p] = f32_to_bf16(3.5f);

  // CPU oracle: first-index argmax over widened values (NaN-free data).
  int oracle_idx = 0;
  float oracle_val = bf16_to_f32(logits[0]);
  for (int i = 1; i < V; i++) {
    float v = bf16_to_f32(logits[i]);
    if (v > oracle_val) { oracle_val = v; oracle_idx = i; }
  }
  std::printf("cpu_oracle idx=%d val=%.4f\n", oracle_idx, oracle_val);

  try {
    xrt::device device(0);
    std::string name = device.get_info<xrt::info::device::name>();
    std::printf("device_name=%s\n", name.c_str());
    xrt::xclbin xclbin{std::string(argv[1])};
    std::printf("xclbin_uuid=%s\n", xclbin.get_uuid().to_string().c_str());
    device.register_xclbin(xclbin);
    xrt::hw_context context(device, xclbin.get_uuid());
    xrt::kernel kernel(context, "MLIR_AIE");

    auto bo_instr = xrt::bo(device, ibytes.size(), XCL_BO_FLAGS_CACHEABLE,
                            kernel.group_id(1));
    auto bo_a = xrt::bo(device, logits.size() * sizeof(uint16_t),
                        XRT_BO_FLAGS_HOST_ONLY, kernel.group_id(3));
    auto bo_c = xrt::bo(device, (size_t)2 * tiles * sizeof(int32_t),
                        XRT_BO_FLAGS_HOST_ONLY, kernel.group_id(4));

    std::memcpy(bo_instr.map<void *>(), ibytes.data(), ibytes.size());
    std::memcpy(bo_a.map<uint16_t *>(), logits.data(),
                logits.size() * sizeof(uint16_t));
    int32_t *cmap = bo_c.map<int32_t *>();
    for (int i = 0; i < 2 * tiles; i++) cmap[i] = SENTINEL;

    bo_instr.sync(XCL_BO_SYNC_BO_TO_DEVICE);
    bo_a.sync(XCL_BO_SYNC_BO_TO_DEVICE);
    bo_c.sync(XCL_BO_SYNC_BO_TO_DEVICE);

    auto run = xrt::run(kernel);
    run.set_arg(0, 3u); // opcode 3: configure + run the AIE sequence
    run.set_arg(1, bo_instr);
    run.set_arg(2, ninstr);
    run.set_arg(3, bo_a);
    run.set_arg(4, bo_c);
    run.start();
    ert_cmd_state state = run.wait();
    std::printf("ert_cmd_state=%d (COMPLETED=%d)\n", (int)state,
                (int)ERT_CMD_STATE_COMPLETED);
    if (state != ERT_CMD_STATE_COMPLETED) {
      std::printf("RESULT FAIL kernel did not complete\n");
      return 1;
    }
    bo_c.sync(XCL_BO_SYNC_BO_FROM_DEVICE);

    long sentinels = 0;
    for (int i = 0; i < 2 * tiles; i++)
      if (cmap[i] == SENTINEL) sentinels++;
    // Merge records in tile order; ties keep the earlier (lower) index.
    int best_idx = -1;
    float best_val = 0.0f;
    uint32_t best_bits = 0;
    for (int t = 0; t < tiles; t++) {
      uint32_t bits = (uint32_t)cmap[2 * t];
      float v;
      std::memcpy(&v, &bits, 4);
      int gi = t * T + cmap[2 * t + 1];
      std::printf("record tile=%d val=%.4f local_idx=%d global_idx=%d\n",
                  t, v, cmap[2 * t + 1], gi);
      if (best_idx < 0 || v > best_val) {
        best_val = v; best_idx = gi; best_bits = bits;
      }
    }
    uint32_t oracle_bits;
    { float v = oracle_val; std::memcpy(&oracle_bits, &v, 4); }
    std::printf("merged idx=%d val=%.4f oracle_idx=%d sentinel_remaining=%ld\n",
                best_idx, best_val, oracle_idx, sentinels);
    if (sentinels != 0 || best_idx != oracle_idx || best_bits != oracle_bits) {
      std::printf("RESULT FAIL argmax mismatch vs CPU oracle\n");
      return 1;
    }

    using clk = std::chrono::steady_clock;
    auto us = [](clk::duration d) {
      return std::chrono::duration<double, std::micro>(d).count();
    };
    // CPU baselines, 21 reps on the same data.
    std::vector<float> wide(V);
    for (int i = 0; i < V; i++) wide[i] = bf16_to_f32(logits[i]);
    std::vector<double> cpu_bf16, cpu_f32, cpu_topk;
    volatile int sink = 0;
    for (int r = 0; r < 21; r++) {
      auto t0 = clk::now();
      int bi = 0; float bv = bf16_to_f32(logits[0]);
      for (int i = 1; i < V; i++) {
        float v = bf16_to_f32(logits[i]);
        if (v > bv) { bv = v; bi = i; }
      }
      cpu_bf16.push_back(us(clk::now() - t0)); sink = bi;
      t0 = clk::now();
      bi = 0; bv = wide[0];
      for (int i = 1; i < V; i++)
        if (wide[i] > bv) { bv = wide[i]; bi = i; }
      cpu_f32.push_back(us(clk::now() - t0)); sink = bi;
      // Stochastic-sampler CPU shape: top-40 by nth_element over the
      // widened row, then softmax over the full row (T=1 weights).
      std::vector<float> w = wide;
      t0 = clk::now();
      std::nth_element(w.begin(), w.begin() + 40, w.end(),
                       [](float a, float b) { return a > b; });
      double sum = 0.0;
      for (int i = 0; i < V; i++) sum += std::exp((double)wide[i] - oracle_val);
      cpu_topk.push_back(us(clk::now() - t0)); sink = (int)sum;
    }
    auto med = [](std::vector<double> v) {
      std::sort(v.begin(), v.end());
      return v[v.size() / 2];
    };
    std::printf("TIMING cpu_bf16_argmax_us median=%.1f cpu_f32_argmax_us "
                "median=%.1f cpu_topk40_softmax_us median=%.1f sink=%d\n",
                med(cpu_bf16), med(cpu_f32), med(cpu_topk), (int)sink);

    // NPU warm timing: 21 reps, fresh run object, args re-set each rep.
    std::vector<double> npu_us, npu_sync_us;
    for (int r = 0; r < 21; r++) {
      auto t0 = clk::now();
      auto run2 = xrt::run(kernel);
      run2.set_arg(0, 3u); run2.set_arg(1, bo_instr); run2.set_arg(2, ninstr);
      run2.set_arg(3, bo_a); run2.set_arg(4, bo_c);
      run2.start();
      ert_cmd_state st2 = run2.wait();
      auto t1 = clk::now();
      bo_c.sync(XCL_BO_SYNC_BO_FROM_DEVICE);
      auto t2 = clk::now();
      if (st2 != ERT_CMD_STATE_COMPLETED) {
        std::printf("FAIL warm run state %d\n", (int)st2);
        return 1;
      }
      npu_us.push_back(us(t1 - t0));
      npu_sync_us.push_back(us(t2 - t0));
    }
    std::sort(npu_us.begin(), npu_us.end());
    std::sort(npu_sync_us.begin(), npu_sync_us.end());
    std::printf("TIMING npu_run_us min=%.1f median=%.1f npu_run_sync_us "
                "min=%.1f median=%.1f reps=%zu V=%d\n",
                npu_us.front(), npu_us[npu_us.size() / 2],
                npu_sync_us.front(), npu_sync_us[npu_sync_us.size() / 2],
                npu_us.size(), V);
    std::printf("RESULT PASS argmax bf16 exact vs CPU oracle on NPU "
                "(incl. planted 3-way tie -> lowest index)\n");
    return 0;
  } catch (const std::exception &e) {
    std::printf("FAIL exception: %s\n", e.what());
    return 1;
  }
}
