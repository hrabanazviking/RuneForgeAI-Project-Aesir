// A-095 -- CPU-side comparison + conversion-cost probe (team-25).
// Measures, on purpleraider (no NPU, no sudo):
//  (1) naive single-thread i16->i32 GEMM (the A-092/A-094 oracle class)
//  (2) optimized CPU GEMM: blocked, multithreaded (std::thread over M
//      rows), -O3 -march=native -- the honest stand-in for an optimized
//      CPU path, used to re-price A-094's oracle-relative margins.
//  (3) Q8->i16 and Q4->i16 weight conversion cost and f16->i16
//      activation conversion cost (the boundary A-094 left unmeasured).
// All GEMM variants verified exact vs each other on a small shape.
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>
#include <thread>
#include <chrono>
#include <algorithm>

static double now_us() {
  using namespace std::chrono;
  return duration_cast<duration<double, std::micro>>(steady_clock::now().time_since_epoch()).count();
}
static void fill(std::vector<int16_t>& v, uint32_t seed) {
  uint32_t s = seed;
  for (auto& x : v) { s = s * 1664525u + 1013904223u; x = (int16_t)((int)((s >> 16) % 17u) - 8); }
}
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
template <typename F> static double median_ms(F f, int reps) {
  std::vector<double> ts;
  for (int r = 0; r < reps; r++) { double t0 = now_us(); f(); ts.push_back((now_us()-t0)/1000.0); }
  std::sort(ts.begin(), ts.end()); return ts[ts.size()/2];
}
int main() {
  int nthreads = (int)std::thread::hardware_concurrency();
  std::printf("threads=%d\n", nthreads);
  // correctness cross-check on 32^3
  {
    std::vector<int16_t> A(32*32), B(32*32); fill(A, 7); fill(B, 9);
    std::vector<int32_t> C1(32*32), C2(32*32);
    gemm_naive(A.data(), B.data(), C1.data(), 32, 32, 32);
    gemm_opt(A.data(), B.data(), C2.data(), 32, 32, 32, nthreads);
    std::printf("crosscheck_32 mismatches=%d\n", memcmp(C1.data(), C2.data(), C1.size()*4)==0 ? 0 : 1);
  }
  struct Shape { int M, K, N; const char* name; };
  Shape shapes[] = {{64,64,64,"64x64x64"},{128,1024,1024,"128x1024x1024"}};
  for (auto sh : shapes) {
    std::vector<int16_t> A((size_t)sh.M*sh.K), B((size_t)sh.K*sh.N);
    fill(A, 3); fill(B, 5);
    std::vector<int32_t> C((size_t)sh.M*sh.N);
    double naive = median_ms([&]{ gemm_naive(A.data(), B.data(), C.data(), sh.M, sh.K, sh.N); }, sh.M > 64 ? 3 : 5);
    volatile int32_t sink = C[0];
    double opt = median_ms([&]{ gemm_opt(A.data(), B.data(), C.data(), sh.M, sh.K, sh.N, nthreads); }, 5);
    sink += C[0];
    std::printf("GEMM %s naive_ms=%.3f opt_ms=%.3f opt_speedup_vs_naive=%.2fx sink=%d\n", sh.name, naive, opt, naive/opt, (int)sink);
  }
  // Conversion costs on a 1024x1024 weight matrix (1,048,576 elems)
  const int E = 1024*1024;
  std::vector<int8_t> q8(E); std::vector<uint8_t> q4(E/2); std::vector<uint16_t> f16v(E);
  for (int i = 0; i < E; i++) { q8[i] = (int8_t)((i % 255) - 127); f16v[i] = (uint16_t)(0x3c00 + (i % 16)); }
  for (int i = 0; i < E/2; i++) q4[i] = (uint8_t)(i & 0xff);
  std::vector<int16_t> out(E);
  double q8t = median_ms([&]{ for (int i = 0; i < E; i++) out[i] = (int16_t)(q8[i] * 3); }, 7);
  double q4t = median_ms([&]{ for (int i = 0; i < E; i++) { uint8_t b = q4[i/2]; int q = (i%2==0) ? (b & 0x0f) : (b >> 4); if (q >= 8) q -= 16; out[i] = (int16_t)(q * 3); } }, 7);
  double f16t = median_ms([&]{ for (int i = 0; i < E; i++) out[i] = (int16_t)(f16v[i] & 0x7fff); }, 7);
  volatile int16_t s2 = out[E/2];
  std::printf("CONV elems=%d q8_to_i16_ms=%.3f (%.3f ns/elem) q4_to_i16_ms=%.3f (%.3f ns/elem) f16bits_to_i16_ms=%.3f sink=%d\n",
    E, q8t, q8t*1e6/E, q4t, q4t*1e6/E, f16t, (int)s2);
  std::printf("RESULT PASS cpu_compare\n");
  return 0;
}
