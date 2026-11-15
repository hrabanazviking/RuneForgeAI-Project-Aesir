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

/* A-041 config cache state (see aesir_par_cpu_count and
   aesir_par_config_refresh below). */
static long aesir_sysconf_probes_count = 0;
static long aesir_env_reads_count = 0;
static long aesir_cached_threads_env = 0;
static long aesir_cached_min_work_env = 0;
static int aesir_config_loaded = 0;

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

/* QS-1.3: persistent worker pool behind the same aesir_par_for
 * contract. The create-per-call body above measured ~210 us of
 * pthread_create+join per dispatch (bench_qs1_gemm QS1SPAWN);
 * the qwen35 decode path dispatches ~450 GEMMs per token, so
 * spawn churn alone cost ~95 ms/token. The pool spawns each
 * worker once (grow-only, up to the largest chunk count ever
 * requested), dispatches by generation counter, and keeps the
 * exact contract: chunk 0 on the calling thread, identical
 * contiguous partitioning, a chunk whose worker could not be
 * spawned runs on the calling thread, and any pool failure
 * degrades to the original create-per-call body below
 * (aesir_par_for_spawn), never to lost work. Dispatches are
 * serialized by a mutex; a pool worker that itself calls
 * aesir_par_for runs its range serially (no nested dispatch,
 * no deadlock). Workers block on a condition variable between
 * dispatches and live for the process lifetime. */
#define AESIR_POOL_MAX 255
static pthread_mutex_t pool_mu = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t pool_dispatch_mu = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t pool_work_cond = PTHREAD_COND_INITIALIZER;
static pthread_cond_t pool_done_cond = PTHREAD_COND_INITIALIZER;
static aesir_range_fn pool_fn = NULL;
static void *pool_ctx = NULL;
static long pool_n = 0;
static long pool_want = 0;
static long pool_generation = 0;
static long pool_pending = 0;
static long pool_workers = 0; /* spawned workers; worker i runs chunk i+1 */
static __thread int pool_in_worker = 0;

static void aesir_chunk_bounds(long n, long want, long i, long *start, long *end) {
    long base = n / want, rem = n % want;
    long pos = i * base + (i < rem ? i : rem);
    *start = pos;
    *end = pos + base + (i < rem ? 1 : 0);
}

static void *aesir_pool_worker(void *arg) {
    long idx = (long)(size_t)arg; /* this worker's chunk index minus 1 */
    long seen = 0;
    pool_in_worker = 1;
    pthread_mutex_lock(&pool_mu);
    for (;;) {
        while (pool_generation == seen)
            pthread_cond_wait(&pool_work_cond, &pool_mu);
        seen = pool_generation;
        if (idx + 1 < pool_want) {
            aesir_range_fn fn = pool_fn;
            void *ctx = pool_ctx;
            long start, end;
            aesir_chunk_bounds(pool_n, pool_want, idx + 1, &start, &end);
            pthread_mutex_unlock(&pool_mu);
            fn(ctx, start, end);
            pthread_mutex_lock(&pool_mu);
            if (--pool_pending == 0)
                pthread_cond_signal(&pool_done_cond);
        }
    }
    return NULL;
}

static long aesir_par_for_spawn(aesir_range_fn fn, void *ctx, long n, long want) {
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

long aesir_par_for(aesir_range_fn fn, void *ctx, long n, long want) {
    if (!fn || n <= 0) return -1;
    if (want < 1) want = 1;
    if (want > 256) want = 256;
    if (want > n) want = n;
    if (want == 1) { fn(ctx, 0, n); return 1; }
    if (pool_in_worker) { fn(ctx, 0, n); return 1; }
    pthread_mutex_lock(&pool_dispatch_mu);
    pthread_mutex_lock(&pool_mu);
    /* Grow the pool toward want-1 workers; a spawn failure stops
     * growth and the unspawned chunks fall to the caller below. */
    while (pool_workers < want - 1 && pool_workers < AESIR_POOL_MAX) {
        pthread_t tid;
        if (pthread_create(&tid, NULL, aesir_pool_worker,
                           (void *)(size_t)pool_workers) != 0)
            break;
        pthread_detach(tid);
        pool_workers++;
    }
    if (pool_workers == 0) {
        pthread_mutex_unlock(&pool_mu);
        pthread_mutex_unlock(&pool_dispatch_mu);
        return aesir_par_for_spawn(fn, ctx, n, want);
    }
    long covered = pool_workers + 1; /* chunks 0..pool_workers */
    if (covered > want) covered = want;
    pool_fn = fn; pool_ctx = ctx; pool_n = n; pool_want = want;
    pool_pending = covered - 1;
    pool_generation++;
    pthread_cond_broadcast(&pool_work_cond);
    pthread_mutex_unlock(&pool_mu);
    long start, end;
    aesir_chunk_bounds(n, want, 0, &start, &end);
    fn(ctx, start, end);
    for (long i = covered; i < want; i++) {
        aesir_chunk_bounds(n, want, i, &start, &end);
        fn(ctx, start, end);
    }
    pthread_mutex_lock(&pool_mu);
    while (pool_pending != 0)
        pthread_cond_wait(&pool_done_cond, &pool_mu);
    pthread_mutex_unlock(&pool_mu);
    pthread_mutex_unlock(&pool_dispatch_mu);
    return want;
}

long aesir_par_cpu_count(void) {
    /* A-041 (census row C-008): the online count cannot change
       while the process lives, so sysconf runs once and the
       result is cached. Before this fix every par_for dispatch
       re-paid the sysconf -> __get_nprocs -> sysfs open chain
       (9.42% of decode cycles in the A-037 census). */
    static long cached = -1;
    if (cached < 0) {
        long n = sysconf(_SC_NPROCESSORS_ONLN);
        aesir_sysconf_probes_count++;
        cached = n > 0 ? n : 1;
    }
    return cached;
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

/* --- A-041: cached thread/env configuration ---------------------
 * The A-037 census (row C-008) found 12.81% of decode cycles
 * re-reading thread/env config per dispatch: sysfs opens via
 * aesir_par_cpu_count (above, now cached) plus getenv parsing in
 * core::parallel::_env_int. The env half now lives here as a
 * process-lifetime snapshot: AESIR_THREADS and AESIR_PAR_MIN_WORK
 * are parsed once (lazily on first use, or eagerly by an explicit
 * aesir_par_config_refresh) with exactly _env_int's semantics
 * (digits only; unset/empty/any non-digit -> fallback 0; the
 * >100000000 early return preserved). Production processes set
 * env before launch, so a process-start snapshot is the config;
 * the only in-process writers of these knobs -- thread_topology's
 * set_thread_knobs/clear_thread_knobs -- call the refresh through
 * core.parallel.par_refresh_config after every setenv/unsetenv.
 * The counters exist so tests can prove the cache engages:
 * sysconf probes stay at 1 and env reads grow only on refresh. */
static long aesir_env_int_snapshot(const char *name, long fallback) {
    const char *raw = getenv(name);
    long value = 0;
    int seen = 0;
    int i;
    if (!raw) return fallback;
    for (i = 0; i < 24; i++) {
        char c = raw[i];
        if (c == '\0') break;
        if (c < '0' || c > '9') return fallback;
        value = value * 10 + (long)(c - '0');
        seen = 1;
        if (value > 100000000L) return value;
    }
    if (!seen) return fallback;
    return value;
}

void aesir_par_config_refresh(void) {
    aesir_cached_threads_env = aesir_env_int_snapshot("AESIR_THREADS", 0);
    aesir_cached_min_work_env =
        aesir_env_int_snapshot("AESIR_PAR_MIN_WORK", 0);
    aesir_env_reads_count += 2;
    aesir_config_loaded = 1;
    (void)aesir_par_cpu_count();
}

static void aesir_config_ensure(void) {
    if (!aesir_config_loaded) aesir_par_config_refresh();
}

long aesir_par_threads_env(void) {
    aesir_config_ensure();
    return aesir_cached_threads_env;
}

long aesir_par_min_work_env(void) {
    aesir_config_ensure();
    return aesir_cached_min_work_env;
}

long aesir_par_sysconf_probes(void) { return aesir_sysconf_probes_count; }

long aesir_par_env_reads(void) { return aesir_env_reads_count; }
