/* thread_par.c — Aesir parallel-for FFI shim (pthread).
 *
 * The Mojo stdlib in this toolchain exposes `vectorize` but no
 * `parallelize`, and the engine's RuneThreadPool is cooperative
 * bookkeeping rather than OS threads. This shim is the FFI vehicle for
 * real multithreading in the CPU forward path: it splits an index range
 * into contiguous chunks and invokes a caller-supplied Mojo callback
 * once per chunk on genuine POSIX threads.
 *
 * Contract of aesir_par_for(fn, ctx, n, want):
 *   - Every index in [0, n) is covered by exactly one chunk invocation
 *     fn(ctx, start, end); chunks are contiguous and non-overlapping.
 *   - Chunk 0 always runs on the calling thread.
 *   - If a pthread_create fails, that chunk is executed on the calling
 *     thread after all spawned threads have been joined: work is never
 *     lost, never duplicated, and the call never hangs.
 *   - If the job array cannot be allocated, the whole range runs on the
 *     calling thread.
 *   - Returns the number of chunks used (>= 1) once all work is done.
 *     Returns -1, without running any work, only for invalid arguments
 *     (fn == NULL or n <= 0); callers treat any return < 1 as "run the
 *     range serially yourself", so every failure mode degrades to the
 *     single-threaded path instead of crashing.
 *
 * Per-element results are bit-identical to the serial path as long as
 * the callback computes each output element independently with a fixed
 * per-element reduction order (the GEMM kernels in core/compute.mojo
 * partition output columns precisely so this holds).
 *
 * Build (done by scripts/launch.py, mirroring the Hailo stub):
 *   cc -std=c11 -O2 -fPIC -shared thread_par.c -o libaesir_par.so -lpthread
 */
#include <pthread.h>
#include <stdlib.h>
#include <unistd.h>
#include <cpuid.h>

typedef void (*aesir_range_fn)(void *ctx, long start, long end);

typedef struct {
    aesir_range_fn fn;
    void *ctx;
    long start, end;
    int spawned;
    pthread_t tid;
} aesir_job;

static void *aesir_tramp(void *p) {
    aesir_job *j = (aesir_job *)p;
    j->fn(j->ctx, j->start, j->end);
    return NULL;
}

long aesir_par_for(aesir_range_fn fn, void *ctx, long n, long want) {
    if (!fn || n <= 0) return -1;
    if (want < 1) want = 1;
    if (want > 256) want = 256;
    if (want > n) want = n;
    if (want == 1) { fn(ctx, 0, n); return 1; }
    aesir_job *jobs = (aesir_job *)calloc((size_t)want, sizeof(aesir_job));
    if (!jobs) { fn(ctx, 0, n); return 1; }
    long base = n / want, rem = n % want, pos = 0;
    for (long i = 0; i < want; i++) {
        long len = base + (i < rem ? 1 : 0);
        jobs[i].fn = fn; jobs[i].ctx = ctx;
        jobs[i].start = pos; jobs[i].end = pos + len;
        pos += len;
    }
    for (long i = 1; i < want; i++) {
        if (pthread_create(&jobs[i].tid, NULL, aesir_tramp, &jobs[i]) == 0)
            jobs[i].spawned = 1;
    }
    jobs[0].fn(jobs[0].ctx, jobs[0].start, jobs[0].end);
    for (long i = 1; i < want; i++) {
        if (jobs[i].spawned) pthread_join(jobs[i].tid, NULL);
        else jobs[i].fn(jobs[i].ctx, jobs[i].start, jobs[i].end);
    }
    free(jobs);
    return want;
}

long aesir_par_cpu_count(void) {
    long n = sysconf(_SC_NPROCESSORS_ONLN);
    return n > 0 ? n : 1;
}

/* CPU feature probes for the VNNI/BF16 GEMM paths (compute.mojo).
   Raw CPUID so any host cc supports them: leaf 7 subleaf 0 ECX bit 11
   is AVX512VNNI; leaf 7 subleaf 1 EAX bit 5 is AVX512BF16. The OS must
   also have the ZMM state enabled (XCR0 bits 5/6/7); checked via
   xgetbv so a feature is never reported the kernel cannot context-
   switch. Returns 1 when usable, 0 otherwise. */
static int aesir_xcr0_zmm_ok(void) {
    unsigned lo, hi;
    __asm__ volatile("xgetbv" : "=a"(lo), "=d"(hi) : "c"(0));
    return (lo & 0xE0u) == 0xE0u;
}

int aesir_cpu_vnni(void) {
    unsigned a, b, c, d;
    if (!aesir_xcr0_zmm_ok()) return 0;
    __get_cpuid_count(7, 0, &a, &b, &c, &d);
    return (c & (1u << 11)) ? 1 : 0;
}

int aesir_cpu_bf16(void) {
    unsigned a, b, c, d;
    if (!aesir_xcr0_zmm_ok()) return 0;
    __get_cpuid_count(7, 1, &a, &b, &c, &d);
    return (a & (1u << 5)) ? 1 : 0;
}
