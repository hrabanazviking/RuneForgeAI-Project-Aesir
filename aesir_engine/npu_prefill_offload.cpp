// A-095 -- NPU offload #1 host runner (Project Aesir, team-25).
//
// Implements the A-094 winning candidate -- prefill projection GEMM with
// M >= 64 -- behind the registry, on the real XDNA 2 NPU of purpleraider
// (ASUS ROG Flow Z13, Strix Halo), through system XRT 2.25.
//
// The dispatch decision below mirrors aesir_engine/core/npu_offload.mojo
// EXACTLY (same band, same reasons): flag OFF (the production default,
// the AesirEngine facade's enable_npu) or any non-eligible shape selects
// the CPU fallback (optimized multithreaded i16->i32 GEMM, from the
// team-25 cpu_compare spike); flag ON + eligible shape selects AMD_XDNA
// and executes via the banked A-092 single-core IRON design (tile
// 32x32x32, i16 in, i32 out, one AIE compute tile), with the hw context
// and BOs resident across dispatches (A-094 caveat: cold context cost
// would eat the win, so residency is part of the implementation).
//
// Every NPU claim in the output is device evidence: device_name from
// the live XRT handle, xclbin uuid, ert_cmd_state per run class, output
// pre-filled with a sentinel, exact compare vs the in-program CPU
// oracle (int64 accumulate), checksum on the A-092 polynomial so the
// 64^3 result must reproduce the banked A-092/A-094 checksum.
//
// Usage:
//   npu_prefill_offload M K N on|off E2E_COUNT [xclbin instrs.bin]
// xclbin/instrs are required only when dispatch selects AMD_XDNA.
// Exit: 0 PASS (incl. via A-099 fallback), 1 FAIL, 2 usage.
//
// A-099 fallback contract: any failure AFTER an AMD_XDNA selection --
// device absent, xclbin load failure, instr load failure, kernel run
// failure/timeout, or output mismatch vs the CPU oracle -- degrades to
// the CPU path with a loud FALLBACK line (reason FALLBACK_<NAME>,
// mirroring the NPUFailure taxonomy in core/npu_offload.mojo); the
// fallback output is verified exact vs the CPU oracle before it is
// accepted, so a failure is never a crash and never a silent wrong
// answer. Fault injection for the contract tests: AESIR_A099_FAULT=
// device_absent|xclbin|run|timeout|mismatch forces that mode.

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
#include <thread>
#include <chrono>
#include <algorithm>

// ---- Registry dispatch (mirror of core/npu_offload.mojo) ----
struct Decision { const char* selected; const char* reason; long long macs; };
static Decision dispatch_decision(int M, int K, int N, bool flag_on) {
  long long macs = (long long)M * K * N;
  if (!flag_on) return {"CPU", "FLAG_DISABLED", macs};
  // This runner's registry target is AMD_XDNA (NPUBackendType 7); the
  // BACKEND_NOT_XDNA case is exercised in the Mojo dispatch check.
  if (M < 64) return {"CPU", "BELOW_M_BAND", macs};
  if (macs < 100000) return {"CPU", "BELOW_MAC_FLOOR", macs};
  return {"AMD_XDNA", "OK_XDNA", macs};
}

// ---- CPU paths (from spikes/a095_measure/cpu_compare.cpp, team-25) ----
static void gemm_naive(const int16_t* A, const int16_t* B, int32_t* C, int M, int K, int N) {
  for (int i = 0; i < M; i++) for (int j = 0; j < N; j++) {
    int64_t acc = 0; for (int k = 0; k < K; k++) acc += (int64_t)A[i*K+k] * B[k*N+j];
    C[i*N+j] = (int32_t)acc;
  }
}
static void gemm_opt_range(const int16_t* A, const int16_t* B, int32_t* C, int M, int K, int N, int i0, int i1) {
  for (int i = i0; i < i1; i++) for (int k = 0; k < K; k++) {
    int32_t a = A[i*K+k]; const int16_t* brow = B + k*N; int32_t* crow = C + i*N;
    for (int j = 0; j < N; j++) crow[j] += a * brow[j];
  }
}
static void gemm_opt(const int16_t* A, const int16_t* B, int32_t* C, int M, int K, int N, int nthreads) {
  memset(C, 0, sizeof(int32_t)*M*N);
  std::vector<std::thread> th;
  int chunk = (M + nthreads - 1) / nthreads;
  for (int t = 0; t < nthreads; t++) {
    int i0 = t*chunk, i1 = std::min(M, i0+chunk);
    if (i0 < i1) th.emplace_back(gemm_opt_range, A, B, C, M, K, N, i0, i1);
  }
  for (auto& t : th) t.join();
}
using clk = std::chrono::steady_clock;
static double us_since(clk::time_point t0) {
  return std::chrono::duration<double, std::micro>(clk::now() - t0).count();
}
static double median(std::vector<double> v) {
  std::sort(v.begin(), v.end()); return v[v.size()/2];
}


// ---- A-099 fallback contract (mirror of core/npu_offload.mojo) ----
static const char* g_fault = nullptr;  // AESIR_A099_FAULT injection
static bool fault_is(const char* name) {
  return g_fault && std::string(g_fault) == name;
}
static int fallback_to_cpu(const char* reason, const char* detail,
                           const int16_t* A, const int16_t* B,
                           const std::vector<int32_t>& oracle,
                           int M, int K, int N, int nthreads) {
  std::printf("FALLBACK op=prefill_projection failure=%s selected=CPU reason=FALLBACK_%s detail=%s\n", reason, reason, detail);
  std::vector<int32_t> C((size_t)M * N, 0);
  gemm_opt(A, B, C.data(), M, K, N, nthreads);
  if (std::memcmp(C.data(), oracle.data(),
                  oracle.size() * sizeof(int32_t)) != 0) {
    std::printf("RESULT FAIL fallback output mismatch vs oracle (fail-closed, no answer returned)\n");
    return 1;
  }
  std::printf("RESULT PASS via fallback (selected=CPU reason=FALLBACK_%s) exact vs oracle\n", reason);
  return 0;
}
int main(int argc, char** argv) {
  if (argc < 6) {
    std::printf("usage: %s M K N on|off E2E_COUNT [xclbin instrs.bin]\n", argv[0]);
    return 2;
  }
  const int M = atoi(argv[1]), K = atoi(argv[2]), N = atoi(argv[3]);
  const bool flag_on = std::string(argv[4]) == "on";
  const int e2e_count = atoi(argv[5]);
  const int nthreads = (int)std::thread::hardware_concurrency();
  g_fault = std::getenv("AESIR_A099_FAULT");
  if (g_fault) std::printf("A099_FAULT_INJECTION mode=%s\n", g_fault);
  Decision d = dispatch_decision(M, K, N, flag_on);
  std::printf("DISPATCH op=prefill_projection shape=%dx%dx%d selected=%s reason=%s flag=%s macs=%lld backend=AMD_XDNA\n",
              M, K, N, d.selected, d.reason, flag_on ? "on" : "off", d.macs);

  // Deterministic inputs + exact CPU oracle (int64 accumulate).
  std::vector<int16_t> A((size_t)M*K), B((size_t)K*N);
  // The A-092/A-094 probes fill A then B from ONE LCG stream; replicate:
  {
    uint32_t s = 0xA092u;
    auto nxt = [&s]() { s = s * 1664525u + 1013904223u; return (int16_t)((int)((s >> 16) % 17u) - 8); };
    for (auto& v : A) v = nxt();
    for (auto& v : B) v = nxt();
  }
  std::vector<int32_t> oracle((size_t)M*N, 0);
  auto t_or = clk::now();
  gemm_naive(A.data(), B.data(), oracle.data(), M, K, N);
  double oracle_us = us_since(t_or);

  // Weight-boundary conversion price (A-094 named, A-095 prices it):
  // Q4 -> i16 dequant for the K*N weight elements, median of 5.
  {
    const size_t E = (size_t)K * N;
    std::vector<uint8_t> q4(E/2); std::vector<int16_t> out(E);
    for (size_t i = 0; i < E/2; i++) q4[i] = (uint8_t)(i & 0xff);
    std::vector<double> ts;
    for (int r = 0; r < 5; r++) {
      auto t0 = clk::now();
      for (size_t i = 0; i < E; i++) {
        uint8_t b = q4[i/2]; int q = (i%2==0) ? (b & 0x0f) : (b >> 4);
        if (q >= 8) q -= 16; out[i] = (int16_t)(q * 3);
      }
      ts.push_back(us_since(t0));
    }
    volatile int16_t sink = out[E/2];
    std::printf("CONV q4_to_i16 elems=%zu median_us=%.1f sink=%d (weights-side, once per layer load)\n",
                E, median(ts), (int)sink);
  }

  if (std::string(d.selected) == "CPU") {
    // Fallback path: optimized CPU GEMM, verified exact vs oracle.
    std::vector<int32_t> C((size_t)M*N, 0);
    gemm_opt(A.data(), B.data(), C.data(), M, K, N, nthreads);
    if (std::memcmp(C.data(), oracle.data(), oracle.size()*sizeof(int32_t)) != 0) {
      std::printf("RESULT FAIL cpu fallback mismatch vs oracle\n");
      return 1;
    }
    std::vector<double> ts;
    for (int r = 0; r < 5; r++) {
      auto t0 = clk::now();
      gemm_opt(A.data(), B.data(), C.data(), M, K, N, nthreads);
      ts.push_back(us_since(t0));
    }
    double per = median(ts);
    auto t0 = clk::now();
    for (int i = 0; i < e2e_count; i++)
      gemm_opt(A.data(), B.data(), C.data(), M, K, N, nthreads);
    double e2e_us = us_since(t0);
    volatile int32_t sink = C[0];
    std::printf("TIMING cpu_opt_us min=%.1f median=%.1f reps=5 threads=%d oracle_naive_us=%.1f sink=%d\n",
                *std::min_element(ts.begin(), ts.end()), per, nthreads, oracle_us, (int)sink);
    std::printf("E2E path=CPU dispatches=%d total_us=%.1f per_dispatch_us=%.1f\n",
                e2e_count, e2e_us, e2e_us / e2e_count);
    std::printf("RESULT PASS cpu fallback exact vs oracle (selected=CPU reason=%s)\n", d.reason);
    return 0;
  }

  // AMD_XDNA path: real device execution via XRT.
  if (argc < 8) {
    return fallback_to_cpu("XCLBIN_LOAD_FAILED",
                           "dispatch selected AMD_XDNA but no xclbin/instrs given",
                           A.data(), B.data(), oracle, M, K, N, nthreads);
  }
  const int32_t SENTINEL = 0x7fffffff;
  std::ifstream fi(argv[7], std::ios::binary);
  if (!fi) {
    return fallback_to_cpu("INSTR_LOAD_FAILED", "cannot open instrs file",
                           A.data(), B.data(), oracle, M, K, N, nthreads);
  }
  std::vector<char> ibytes((std::istreambuf_iterator<char>(fi)), std::istreambuf_iterator<char>());
  if (ibytes.empty() || (ibytes.size() % 4) != 0) {
    std::printf("instrs_size=%zu invalid\n", ibytes.size());
    return fallback_to_cpu("INSTR_LOAD_FAILED", "instrs not a whole word count",
                           A.data(), B.data(), oracle, M, K, N, nthreads);
  }
  const size_t ninstr = ibytes.size() / 4;
  std::printf("insts_bytes=%zu ninstr_words=%zu\n", ibytes.size(), ninstr);
  const char* stage = "DEVICE_ABSENT";
  try {
    xrt::device device(fault_is("device_absent") ? 99 : 0);
    std::string name = device.get_info<xrt::info::device::name>();
    std::printf("device_name=%s\n", name.c_str());
    stage = "XCLBIN_LOAD_FAILED";
    xrt::xclbin xclbin{std::string(
        fault_is("xclbin") ? "/nonexistent/a099_injected_bad.xclbin" : argv[6])};
    std::printf("xclbin_uuid=%s\n", xclbin.get_uuid().to_string().c_str());
    device.register_xclbin(xclbin);
    xrt::hw_context context(device, xclbin.get_uuid());
    xrt::kernel kernel(context, "MLIR_AIE");
    stage = "KERNEL_RUN_FAILED";
    // Resident BOs: created once, reused by every dispatch below.
    auto bo_instr = xrt::bo(device, ibytes.size(), XCL_BO_FLAGS_CACHEABLE, kernel.group_id(1));
    auto bo_a = xrt::bo(device, A.size() * sizeof(int16_t), XRT_BO_FLAGS_HOST_ONLY, kernel.group_id(3));
    auto bo_b = xrt::bo(device, B.size() * sizeof(int16_t), XRT_BO_FLAGS_HOST_ONLY, kernel.group_id(4));
    auto bo_c = xrt::bo(device, oracle.size() * sizeof(int32_t), XRT_BO_FLAGS_HOST_ONLY, kernel.group_id(5));
    std::memcpy(bo_instr.map<void*>(), ibytes.data(), ibytes.size());
    std::memcpy(bo_a.map<int16_t*>(), A.data(), A.size() * sizeof(int16_t));
    std::memcpy(bo_b.map<int16_t*>(), B.data(), B.size() * sizeof(int16_t));
    int32_t* cmap = bo_c.map<int32_t*>();
    for (size_t i = 0; i < oracle.size(); i++) cmap[i] = SENTINEL;
    bo_instr.sync(XCL_BO_SYNC_BO_TO_DEVICE);
    bo_a.sync(XCL_BO_SYNC_BO_TO_DEVICE);
    bo_b.sync(XCL_BO_SYNC_BO_TO_DEVICE);
    bo_c.sync(XCL_BO_SYNC_BO_TO_DEVICE);
    auto do_run = [&]() {
      auto run = xrt::run(kernel);
      run.set_arg(0, 3u);  // opcode 3: configure + run the AIE sequence
      run.set_arg(1, bo_instr);
      run.set_arg(2, (unsigned)ninstr);
      run.set_arg(3, bo_a);
      run.set_arg(4, bo_b);
      run.set_arg(5, bo_c);
      run.start();
      return run;
    };
    // Dispatch #1: verify exact vs oracle + ert state + checksum.
    if (fault_is("run"))
      return fallback_to_cpu("KERNEL_RUN_FAILED", "A099 fault injection: run",
                             A.data(), B.data(), oracle, M, K, N, nthreads);
    if (fault_is("timeout"))
      return fallback_to_cpu("KERNEL_TIMEOUT", "A099 fault injection: timeout",
                             A.data(), B.data(), oracle, M, K, N, nthreads);
    auto run0 = do_run();
    ert_cmd_state st0 = run0.wait();
    std::printf("ert_cmd_state=%d (COMPLETED=%d)\n", (int)st0, (int)ERT_CMD_STATE_COMPLETED);
    if (st0 != ERT_CMD_STATE_COMPLETED) {
      std::printf("ert_state=%d not COMPLETED\n", (int)st0);
      return fallback_to_cpu("KERNEL_RUN_FAILED", "kernel did not complete",
                             A.data(), B.data(), oracle, M, K, N, nthreads);
    }
    bo_c.sync(XCL_BO_SYNC_BO_FROM_DEVICE);
    if (fault_is("mismatch")) cmap[0] += 1;  // A099 injection: corrupt 1 elem
    long mismatches = 0, sentinels = 0; uint64_t checksum = 0;
    for (int i = 0; i < M; i++) for (int j = 0; j < N; j++) {
      int32_t got = cmap[i*N+j];
      checksum = checksum * 1099511628211ULL + (uint64_t)(uint32_t)got;
      if (got == SENTINEL) sentinels++;
      if (got != oracle[i*N+j]) mismatches++;
    }
    std::printf("elements=%d mismatches=%ld sentinel_remaining=%ld checksum=%llu\n",
                M*N, mismatches, sentinels, (unsigned long long)checksum);
    if (mismatches) {
      std::printf("mismatches=%ld sentinel_remaining=%ld\n", mismatches, sentinels);
      return fallback_to_cpu("OUTPUT_MISMATCH", "npu output != cpu oracle",
                             A.data(), B.data(), oracle, M, K, N, nthreads);
    }
    long submitted = 1;
    // Warm timing: 21 reps, fresh run objects, resident context + BOs.
    std::vector<double> npu_us, npu_sync_us;
    for (int r = 0; r < 21; r++) {
      auto t0 = clk::now();
      auto run = do_run(); submitted++;
      ert_cmd_state st = run.wait();
      auto t1 = clk::now();
      bo_c.sync(XCL_BO_SYNC_BO_FROM_DEVICE);
      auto t2 = clk::now();
      if (st != ERT_CMD_STATE_COMPLETED) {
        std::printf("warm run state %d not COMPLETED\n", (int)st);
        return fallback_to_cpu("KERNEL_RUN_FAILED", "warm run failed",
                               A.data(), B.data(), oracle, M, K, N, nthreads);
      }
      npu_us.push_back(std::chrono::duration<double, std::micro>(t1-t0).count());
      npu_sync_us.push_back(std::chrono::duration<double, std::micro>(t2-t0).count());
    }
    std::printf("TIMING npu_run_us min=%.1f median=%.1f npu_run_sync_us min=%.1f median=%.1f reps=21 shape=%dx%dx%d oracle_naive_us=%.1f\n",
                *std::min_element(npu_us.begin(), npu_us.end()), median(npu_us),
                *std::min_element(npu_sync_us.begin(), npu_sync_us.end()), median(npu_sync_us),
                M, K, N, oracle_us);
    // End-to-end: E2E_COUNT consecutive projection dispatches, resident.
    auto t0 = clk::now();
    for (int i = 0; i < e2e_count; i++) {
      auto run = do_run(); submitted++;
      ert_cmd_state st = run.wait();
      if (st != ERT_CMD_STATE_COMPLETED) {
        std::printf("e2e run %d state %d not COMPLETED\n", i, (int)st);
        return fallback_to_cpu("KERNEL_RUN_FAILED", "e2e run failed",
                               A.data(), B.data(), oracle, M, K, N, nthreads);
      }
    }
    double e2e_us = us_since(t0);
    bo_c.sync(XCL_BO_SYNC_BO_FROM_DEVICE);
    long mism2 = 0; uint64_t checksum2 = 0;
    for (int i = 0; i < M; i++) for (int j = 0; j < N; j++) {
      int32_t got = cmap[i*N+j];
      checksum2 = checksum2 * 1099511628211ULL + (uint64_t)(uint32_t)got;
      if (got != oracle[i*N+j]) mism2++;
    }
    std::printf("E2E path=AMD_XDNA dispatches=%d total_us=%.1f per_dispatch_us=%.1f final_mismatches=%ld final_checksum=%llu submitted_total=%ld\n",
                e2e_count, e2e_us, e2e_us / e2e_count, mism2,
                (unsigned long long)checksum2, submitted);
    if (mism2) {
      return fallback_to_cpu("OUTPUT_MISMATCH", "e2e final output != oracle",
                             A.data(), B.data(), oracle, M, K, N, nthreads);
    }
    std::printf("RESULT PASS matmul i16->i32 exact vs CPU oracle on NPU (resident context, %ld dispatches)\n", submitted);
    return 0;
  } catch (const std::exception& e) {
    std::printf("exception at stage=%s: %s\n", stage, e.what());
    return fallback_to_cpu(stage, e.what(), A.data(), B.data(), oracle,
                           M, K, N, nthreads);
  }
}
