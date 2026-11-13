// A-092 -- NPU hello-compute host runner (Project Aesir, team-22).
//
// Loads an IRON/mlir-aie-built xclbin + AIE instruction stream for a
// single-core matmul (MLIR_AIE DPU kernel) through the system XRT
// C++ API, executes ONE real matmul on the XDNA 2 NPU, and verifies
// every output element against an in-program CPU oracle.
// Shapes/dtypes are fixed for this hello-compute: M=K=N=64,
// int16 inputs, int32 output (exact integer compare, no tolerance).
// Inputs are deterministic (fixed-seed LCG, values in [-8, 8]), so
// the oracle is exact and reproducible. The output buffer is
// pre-filled with a sentinel so a kernel that never wrote cannot
// pass by accident. Device identity is printed from the live XRT
// device handle; kernel completion is the ERT command state
// returned by run.wait(). No NPU execution is claimed anywhere
// except from this program completing with PASS.

#include "xrt/xrt_bo.h"
#include "xrt/xrt_device.h"
#include "xrt/xrt_kernel.h"

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <fstream>
#include <string>
#include <vector>
#include <chrono>
#include <algorithm>

int main(int argc, char **argv) {
  if (argc < 3) {
    std::printf("usage: %s <xclbin> <insts.bin>\n", argv[0]);
    return 2;
  }
  int M = 64, K = 64, N = 64;
  if (argc > 5) { M = atoi(argv[3]); K = atoi(argv[4]); N = atoi(argv[5]); }
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
  std::printf("insts_bytes=%zu ninstr_words=%zu\n", ibytes.size(), ninstr);

  // Deterministic inputs.
  std::vector<int16_t> A(M * K), B(K * N);
  uint32_t s = 0xA092u;
  auto nextv = [&s]() {
    s = s * 1664525u + 1013904223u;
    return (int16_t)((int)((s >> 16) % 17u) - 8);
  };
  for (auto &v : A) v = nextv();
  for (auto &v : B) v = nextv();

  // CPU oracle (int64 accumulate, exact).
  std::vector<int32_t> oracle(M * N, 0);
  for (int i = 0; i < M; i++)
    for (int j = 0; j < N; j++) {
      int64_t acc = 0;
      for (int k = 0; k < K; k++) acc += (int64_t)A[i * K + k] * B[k * N + j];
      oracle[i * N + j] = (int32_t)acc;
    }

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
    auto bo_a = xrt::bo(device, A.size() * sizeof(int16_t),
                        XRT_BO_FLAGS_HOST_ONLY, kernel.group_id(3));
    auto bo_b = xrt::bo(device, B.size() * sizeof(int16_t),
                        XRT_BO_FLAGS_HOST_ONLY, kernel.group_id(4));
    auto bo_c = xrt::bo(device, oracle.size() * sizeof(int32_t),
                        XRT_BO_FLAGS_HOST_ONLY, kernel.group_id(5));

    std::memcpy(bo_instr.map<void *>(), ibytes.data(), ibytes.size());
    std::memcpy(bo_a.map<int16_t *>(), A.data(), A.size() * sizeof(int16_t));
    std::memcpy(bo_b.map<int16_t *>(), B.data(), B.size() * sizeof(int16_t));
    int32_t *cmap = bo_c.map<int32_t *>();
    for (size_t i = 0; i < oracle.size(); i++) cmap[i] = SENTINEL;

    bo_instr.sync(XCL_BO_SYNC_BO_TO_DEVICE);
    bo_a.sync(XCL_BO_SYNC_BO_TO_DEVICE);
    bo_b.sync(XCL_BO_SYNC_BO_TO_DEVICE);
    bo_c.sync(XCL_BO_SYNC_BO_TO_DEVICE);

    auto run = xrt::run(kernel);
    run.set_arg(0, 3u); // opcode 3: configure + run the AIE sequence
    run.set_arg(1, bo_instr);
    run.set_arg(2, ninstr);
    run.set_arg(3, bo_a);
    run.set_arg(4, bo_b);
    run.set_arg(5, bo_c);
    run.start();
    ert_cmd_state state = run.wait();
    std::printf("ert_cmd_state=%d (COMPLETED=%d)\n", (int)state,
                (int)ERT_CMD_STATE_COMPLETED);
    if (state != ERT_CMD_STATE_COMPLETED) {
      std::printf("FAIL kernel did not complete\n");
      return 1;
    }
    bo_c.sync(XCL_BO_SYNC_BO_FROM_DEVICE);

    long mismatches = 0, sentinels = 0;
    int fi_i = -1, fi_j = -1;
    int32_t fi_got = 0, fi_want = 0;
    uint64_t checksum = 0;
    for (int i = 0; i < M; i++)
      for (int j = 0; j < N; j++) {
        int32_t got = cmap[i * N + j];
        checksum = checksum * 1099511628211ULL + (uint64_t)(uint32_t)got;
        if (got == SENTINEL) sentinels++;
        if (got != oracle[i * N + j]) {
          if (mismatches == 0) { fi_i = i; fi_j = j; fi_got = got; fi_want = oracle[i * N + j]; }
          mismatches++;
        }
      }
    std::printf("elements=%d mismatches=%ld sentinel_remaining=%ld checksum=%llu\n",
                M * N, mismatches, sentinels,
                (unsigned long long)checksum);
    if (mismatches) {
      std::printf("first_mismatch at (%d,%d) got=%d want=%d\n", fi_i, fi_j,
                  fi_got, fi_want);
      std::printf("RESULT FAIL\n");
      return 1;
    }
    using clk = std::chrono::steady_clock;
    auto us = [](clk::duration d){ return std::chrono::duration<double, std::micro>(d).count(); };
    // CPU oracle timing: 5 reps of the exact oracle loops above.
    std::vector<double> cpu_us;
    volatile int64_t sink = 0;
    for (int r = 0; r < 5; r++) {
      auto t0 = clk::now();
      int64_t tot = 0;
      for (int i = 0; i < M; i++) for (int j = 0; j < N; j++) { int64_t acc = 0; for (int k = 0; k < K; k++) acc += (int64_t)A[i*K+k]*B[k*N+j]; tot += acc; }
      cpu_us.push_back(us(clk::now()-t0)); sink = tot;
    }
    std::sort(cpu_us.begin(), cpu_us.end());
    std::printf("TIMING cpu_oracle_us min=%.1f median=%.1f sink=%lld\n", cpu_us.front(), cpu_us[cpu_us.size()/2], (long long)sink);
    // NPU warm timing: 21 reps, fresh run object, args re-set each rep.
    std::vector<double> npu_us, npu_sync_us;
    for (int r = 0; r < 21; r++) {
      auto t0 = clk::now();
      auto run2 = xrt::run(kernel);
      run2.set_arg(0, 3u); run2.set_arg(1, bo_instr); run2.set_arg(2, ninstr);
      run2.set_arg(3, bo_a); run2.set_arg(4, bo_b); run2.set_arg(5, bo_c);
      run2.start();
      ert_cmd_state st2 = run2.wait();
      auto t1 = clk::now();
      bo_c.sync(XCL_BO_SYNC_BO_FROM_DEVICE);
      auto t2 = clk::now();
      if (st2 != ERT_CMD_STATE_COMPLETED) { std::printf("FAIL warm run state %d\n", (int)st2); return 1; }
      npu_us.push_back(us(t1-t0)); npu_sync_us.push_back(us(t2-t0));
    }
    std::sort(npu_us.begin(), npu_us.end()); std::sort(npu_sync_us.begin(), npu_sync_us.end());
    std::printf("TIMING npu_run_us min=%.1f median=%.1f npu_run_sync_us min=%.1f median=%.1f reps=%zu shape=%dx%dx%d\n", npu_us.front(), npu_us[npu_us.size()/2], npu_sync_us.front(), npu_sync_us[npu_sync_us.size()/2], npu_us.size(), M, K, N);
    std::printf("RESULT PASS matmul i16->i32 exact vs CPU oracle on NPU\n");
    return 0;
  } catch (const std::exception &e) {
    std::printf("FAIL exception: %s\n", e.what());
    return 1;
  }
}
