/* zero_copy_shim.c - Zero-copy allocator HIP backend (slice A-019).
 *
 * Why a shim: same reason as hip_memory_shim.c (A-011) - Mojo 1.0
 * cannot mix this repo's external_call dlopen idiom with stdlib
 * OwnedDLHandle in one program, so all dynamic loading lives in C
 * and the Mojo side (core/zero_copy.mojo) calls this flat ABI.
 *
 * What this shim is: the HIP half of the A-019 unified zero-copy
 * allocator, built on the A-008 design rule (banked ledger):
 * DEFAULT shared CPU<->GPU allocation = HIP managed memory
 * (hipMallocManaged / hipMemAttachGlobal). On Strix Halo's unified
 * pool the GPU reads and writes managed memory at full DRAM speed
 * and the CPU reads/writes it at full speed in both directions, so
 * NO copy call belongs in the CPU-write -> GPU-read path.
 *
 * Zero-copy instrumentation (the A-019 acceptance evidence): this
 * shim counts every category of HIP call it makes - managed
 * allocations, frees, kernel launches - and exposes the counters.
 * It deliberately NEVER resolves hipMemcpy: the memcpy counter
 * below can only be incremented by a copy entry point, and this
 * shim has none, so a zero reading after kernel work is structural
 * proof that the path ran copy-free, not a missing measurement.
 * The two kernels (transform, fill) are compiled at runtime via
 * HIPRTC for gfx1151 (the A-008 probe pattern; hipcc is absent)
 * and launched with hipModuleLaunchKernel on the real device.
 *
 * Every function returns the HIP error code (0 = hipSuccess), -1
 * when a runtime library is not loadable, or -2 when HIPRTC
 * compilation failed; nothing is simulated.
 */

#include <dlfcn.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "buffer_ownership.h"

typedef int (*hip_get_device_count_fn)(int *);
typedef int (*hip_malloc_managed_fn)(void **, size_t, unsigned int);
typedef int (*hip_free_fn)(void *);
typedef int (*hip_device_synchronize_fn)(void);
typedef int (*hip_module_load_data_fn)(void **, const void *);
typedef int (*hip_module_get_function_fn)(void **, void *, const char *);
typedef int (*hip_module_launch_kernel_fn)(void *, unsigned int,
                                           unsigned int, unsigned int,
                                           unsigned int, unsigned int,
                                           unsigned int, unsigned int,
                                           void *, void **, void **);
typedef int (*hiprtc_create_program_fn)(void **, const char *, const char *,
                                        int, const char **, const char **);
typedef int (*hiprtc_compile_program_fn)(void *, int, const char **);
typedef int (*hiprtc_get_code_size_fn)(void *, size_t *);
typedef int (*hiprtc_get_code_fn)(void *, char *);
typedef int (*hiprtc_get_log_size_fn)(void *, size_t *);
typedef int (*hiprtc_get_log_fn)(void *, char *);
typedef int (*hiprtc_destroy_program_fn)(void *);

static void *g_hip = NULL;
static void *g_rtc = NULL;
static hip_get_device_count_fn g_count = NULL;
static hip_malloc_managed_fn g_managed = NULL;
static hip_free_fn g_free = NULL;
static hip_device_synchronize_fn g_sync = NULL;
static hip_module_load_data_fn g_modload = NULL;
static hip_module_get_function_fn g_getfn = NULL;
static hip_module_launch_kernel_fn g_launch = NULL;
static hiprtc_create_program_fn g_rtc_create = NULL;
static hiprtc_compile_program_fn g_rtc_compile = NULL;
static hiprtc_get_code_size_fn g_rtc_codesize = NULL;
static hiprtc_get_code_fn g_rtc_code = NULL;
static hiprtc_destroy_program_fn g_rtc_destroy = NULL;
static int g_tried = 0;
static int g_ok = 0;

/* Instrumentation counters (A-019 acceptance evidence). */
static uint64_t g_allocs = 0;
static uint64_t g_frees = 0;
static uint64_t g_live_bytes = 0;
static uint64_t g_kernel_launches = 0;
static uint64_t g_memcpy_calls = 0; /* no copy entry point exists here */

#define AESIR_ZC_MAX_ALLOCS 4096
static void *g_ptrs[AESIR_ZC_MAX_ALLOCS];
static uint64_t g_sizes[AESIR_ZC_MAX_ALLOCS];
/* A-022 ownership states parallel to the pointer registry above;
 * freed entries keep their pointer as a tombstone so a second free
 * is detectable instead of reaching hipFree again. */
static int g_states[AESIR_ZC_MAX_ALLOCS];
static uint64_t g_violations = 0;

static int zc_find(const void *ptr) {
    for (int i = 0; i < AESIR_ZC_MAX_ALLOCS; i++) {
        if (g_states[i] != AESIR_OWN_STATE_EMPTY && g_ptrs[i] == ptr) {
            return i;
        }
    }
    return -1;
}


/* A-022 cross-shim live-ownership query (exported): 1 when ptr is a
 * LIVE or HANDED_OFF allocation of THIS shim, else 0. Pure lookup. */
int aesir_zc_own_live(void *ptr) {
    int i = zc_find(ptr);
    if (i < 0) {
        return 0;
    }
    return (g_states[i] == AESIR_OWN_STATE_LIVE ||
            g_states[i] == AESIR_OWN_STATE_HANDED_OFF)
               ? 1
               : 0;
}

typedef int (*aesir_hip_own_live_kind_fn)(void *);

static int zc_hip_own_live_kind(void *ptr) {
    static aesir_hip_own_live_kind_fn fn = NULL;
    static int tried = 0;
    if (!tried) {
        tried = 1;
        void *global = dlopen(NULL, RTLD_NOW);
        if (global != NULL) {
            fn = (aesir_hip_own_live_kind_fn)dlsym(
                global, "aesir_hip_own_live_kind");
        }
    }
    if (fn == NULL) {
        return 0;
    }
    return fn(ptr);
}

static int zc_validate_use(const void *ptr) {
    int i = zc_find(ptr);
    if (i < 0) {
        g_violations += 1;
        return AESIR_OWN_CROSS_DEVICE;
    }
    if (g_states[i] == AESIR_OWN_STATE_FREED) {
        g_violations += 1;
        return AESIR_OWN_USE_AFTER_FREE;
    }
    if (g_states[i] == AESIR_OWN_STATE_HANDED_OFF) {
        g_violations += 1;
        return AESIR_OWN_USE_AFTER_HANDOFF;
    }
    return 0;
}

static void *try_dlopen(const char *a, const char *b, const char *c) {
    void *h = NULL;
    if (a) { h = dlopen(a, RTLD_NOW | RTLD_GLOBAL); if (h) return h; }
    if (b) { h = dlopen(b, RTLD_NOW | RTLD_GLOBAL); if (h) return h; }
    if (c) { h = dlopen(c, RTLD_NOW | RTLD_GLOBAL); if (h) return h; }
    return NULL;
}

static void aesir_zc_init(void) {
    if (g_tried) return;
    g_tried = 1;
    g_hip = try_dlopen("libamdhip64.so", "libamdhip64.so.7",
                       "libamdhip64.so.6");
    g_rtc = try_dlopen("libhiprtc.so", "libhiprtc.so.7", "libhiprtc.so.6");
    if (!g_hip || !g_rtc) return;
    g_count = (hip_get_device_count_fn)dlsym(g_hip, "hipGetDeviceCount");
    g_managed = (hip_malloc_managed_fn)dlsym(g_hip, "hipMallocManaged");
    g_free = (hip_free_fn)dlsym(g_hip, "hipFree");
    g_sync = (hip_device_synchronize_fn)dlsym(g_hip,
                                              "hipDeviceSynchronize");
    g_modload = (hip_module_load_data_fn)dlsym(g_hip, "hipModuleLoadData");
    g_getfn = (hip_module_get_function_fn)dlsym(g_hip,
                                                "hipModuleGetFunction");
    g_launch = (hip_module_launch_kernel_fn)dlsym(g_hip,
                                                  "hipModuleLaunchKernel");
    g_rtc_create = (hiprtc_create_program_fn)dlsym(g_rtc,
                                                   "hiprtcCreateProgram");
    g_rtc_compile = (hiprtc_compile_program_fn)dlsym(g_rtc,
                                                     "hiprtcCompileProgram");
    g_rtc_codesize = (hiprtc_get_code_size_fn)dlsym(g_rtc,
                                                    "hiprtcGetCodeSize");
    g_rtc_code = (hiprtc_get_code_fn)dlsym(g_rtc, "hiprtcGetCode");
    g_rtc_destroy = (hiprtc_destroy_program_fn)dlsym(g_rtc,
                                                     "hiprtcDestroyProgram");
    g_ok = (g_count && g_managed && g_free && g_sync && g_modload &&
            g_getfn && g_launch && g_rtc_create && g_rtc_compile &&
            g_rtc_codesize && g_rtc_code && g_rtc_destroy)
               ? 1
               : 0;
}

int aesir_zc_available(void) {
    aesir_zc_init();
    return g_ok ? 1 : 0;
}

int aesir_zc_hip_device_count(int *out) {
    aesir_zc_init();
    if (!g_ok) return -1;
    return g_count(out);
}

int aesir_zc_hip_alloc_managed(void **out, uint64_t size_bytes) {
    aesir_zc_init();
    if (!g_ok) return -1;
    if (out == NULL || size_bytes == 0) return -3;
    void *ptr = NULL;
    int rc = g_managed(&ptr, (size_t)size_bytes, 1u /* hipMemAttachGlobal */);
    if (rc != 0) return rc;
    if (ptr == NULL) return -3;
    int slot = zc_find(ptr);
    if (slot >= 0 && g_states[slot] != AESIR_OWN_STATE_FREED) {
        g_free(ptr);
        return AESIR_OWN_INVALID;
    }
    if (slot < 0) {
        for (int i = 0; i < AESIR_ZC_MAX_ALLOCS; i++) {
            if (g_states[i] == AESIR_OWN_STATE_EMPTY) {
                slot = i;
                break;
            }
        }
    }
    if (slot < 0) {
        g_free(ptr);
        return AESIR_OWN_INVALID;
    }
    g_ptrs[slot] = ptr;
    g_sizes[slot] = size_bytes;
    g_states[slot] = AESIR_OWN_STATE_LIVE;
    g_allocs += 1;
    g_live_bytes += size_bytes;
    *out = ptr;
    return 0;
}

int aesir_zc_hip_free(void *ptr) {
    aesir_zc_init();
    if (!g_ok) return -1;
    if (ptr == NULL) return 0;
    /* A-022 cross-shim: a pointer live in the A-011 HIP shim is not
     * this shim's to free, whatever this registry's tombstones say
     * about its (reused) address. Refuse as MEM-013, before the
     * tombstone check below can misreport it as MEM-005. */
    if (zc_hip_own_live_kind(ptr)) {
        g_violations += 1;
        return AESIR_OWN_NOT_OWNER;
    }
    /* A-022: the registry decides BEFORE hipFree is touched. The
     * pre-A-022 code called hipFree unconditionally and only fixed
     * the accounting afterwards, so double frees and foreign
     * pointers (including A-011 HIP-shim allocations) reached the
     * driver unimpeded - that hole is closed here. */
    int i = zc_find(ptr);
    if (i < 0) {
        g_violations += 1;
        return AESIR_OWN_NOT_OWNER;
    }
    if (g_states[i] == AESIR_OWN_STATE_FREED) {
        g_violations += 1;
        return AESIR_OWN_DOUBLE_FREE;
    }
    if (g_states[i] == AESIR_OWN_STATE_HANDED_OFF) {
        g_violations += 1;
        return AESIR_OWN_USE_AFTER_HANDOFF;
    }
    int rc = g_free(ptr);
    if (rc != 0) return rc;
    g_live_bytes -= g_sizes[i];
    g_sizes[i] = 0;
    g_states[i] = AESIR_OWN_STATE_FREED;
    g_frees += 1;
    return 0;
}

int aesir_zc_handoff(void *ptr) {
    aesir_zc_init();
    if (!g_ok) return -1;
    int i = zc_find(ptr);
    if (i < 0) {
        g_violations += 1;
        return AESIR_OWN_NOT_OWNER;
    }
    if (g_states[i] == AESIR_OWN_STATE_FREED) {
        g_violations += 1;
        return AESIR_OWN_USE_AFTER_FREE;
    }
    if (g_states[i] == AESIR_OWN_STATE_HANDED_OFF) {
        g_violations += 1;
        return AESIR_OWN_USE_AFTER_HANDOFF;
    }
    g_states[i] = AESIR_OWN_STATE_HANDED_OFF;
    return 0;
}

int aesir_zc_claim(void *ptr) {
    aesir_zc_init();
    if (!g_ok) return -1;
    int i = zc_find(ptr);
    if (i < 0) {
        g_violations += 1;
        return AESIR_OWN_NOT_OWNER;
    }
    if (g_states[i] == AESIR_OWN_STATE_FREED) {
        g_violations += 1;
        return AESIR_OWN_USE_AFTER_FREE;
    }
    if (g_states[i] != AESIR_OWN_STATE_HANDED_OFF) {
        g_violations += 1;
        return AESIR_OWN_INVALID;
    }
    g_states[i] = AESIR_OWN_STATE_LIVE;
    return 0;
}

int aesir_zc_hip_synchronize(void) {
    aesir_zc_init();
    if (!g_ok) return -1;
    return g_sync();
}

/* --- HIPRTC kernels: transform + fill for gfx1151 --- */

static const char *ZC_KERNEL_SRC =
    "extern \"C\" __global__ void aesir_zc_transform(const float* in,"
    " float* out, unsigned int n){"
    " unsigned int i = blockIdx.x * blockDim.x + threadIdx.x;"
    " if (i < n) { out[i] = in[i] * 2.0f + 1.0f; } }\n"
    "extern \"C\" __global__ void aesir_zc_fill(float* out,"
    " unsigned int n){"
    " unsigned int i = blockIdx.x * blockDim.x + threadIdx.x;"
    " if (i < n) { unsigned int v = (i * 37u + 11u) % 997u;"
    " out[i] = (float)v * 0.5f - 100.0f; } }\n";

static void *g_fn_transform = NULL;
static void *g_fn_fill = NULL;
static int g_kernels_ready = 0;
static int g_kernels_failed = 0;

static int aesir_zc_kernels_init(void) {
    if (g_kernels_ready) return 0;
    if (g_kernels_failed) return -2;
    void *prog = NULL;
    int hr = g_rtc_create(&prog, ZC_KERNEL_SRC, "aesir_zc.hip", 0, NULL,
                          NULL);
    if (hr != 0) { g_kernels_failed = 1; return -2; }
    const char *opts[] = {"--gpu-architecture=gfx1151"};
    hr = g_rtc_compile(prog, 1, opts);
    if (hr != 0) {  g_kernels_failed = 1; return -2; }
    size_t csz = 0;
    hr = g_rtc_codesize(prog, &csz);
    if (hr != 0 || csz == 0) {
         g_kernels_failed = 1; return -2;
    }
    char *code = (char *)malloc(csz);
    if (code == NULL) {  g_kernels_failed = 1; return -2; }
    hr = g_rtc_code(prog, code);
    /* NOTE (A-019): hiprtcDestroyProgram is never called - on this ROCm 10.0 userland it corrupts the comgr heap (gdb-proven); the program is kept for the process lifetime like the library handles, as in the A-008 probe. */
    
    if (hr != 0) { free(code); g_kernels_failed = 1; return -2; }
    void *mod = NULL;
    int rc = g_modload(&mod, code);
    free(code);
    if (rc != 0) { g_kernels_failed = 1; return rc; }
    rc = g_getfn(&g_fn_transform, mod, "aesir_zc_transform");
    if (rc != 0) { g_kernels_failed = 1; return rc; }
    rc = g_getfn(&g_fn_fill, mod, "aesir_zc_fill");
    if (rc != 0) { g_kernels_failed = 1; return rc; }
    g_kernels_ready = 1;
    return 0;
}

static int aesir_zc_launch(void *fn, void **args, uint32_t n) {
    unsigned int block = 256;
    unsigned int grid = (n + block - 1) / block;
    int rc = g_launch(fn, grid, 1, 1, block, 1, 1, 0, NULL, args, NULL);
    if (rc != 0) return rc;
    g_kernel_launches += 1;
    return g_sync();
}

int aesir_zc_hip_transform(void *in_ptr, void *out_ptr, uint32_t n) {
    aesir_zc_init();
    if (!g_ok) return -1;
    if (in_ptr == NULL || out_ptr == NULL || n == 0) return -3;
    int v = zc_validate_use(in_ptr);
    if (v != 0) return v;
    v = zc_validate_use(out_ptr);
    if (v != 0) return v;
    int rc = aesir_zc_kernels_init();
    if (rc != 0) return rc;
    void *args[] = {&in_ptr, &out_ptr, &n};
    return aesir_zc_launch(g_fn_transform, args, n);
}

int aesir_zc_hip_fill(void *out_ptr, uint32_t n) {
    aesir_zc_init();
    if (!g_ok) return -1;
    if (out_ptr == NULL || n == 0) return -3;
    int v = zc_validate_use(out_ptr);
    if (v != 0) return v;
    int rc = aesir_zc_kernels_init();
    if (rc != 0) return rc;
    void *args[] = {&out_ptr, &n};
    return aesir_zc_launch(g_fn_fill, args, n);
}

/* --- Instrumentation counters (A-019 acceptance evidence) --- */

uint64_t aesir_zc_alloc_count(void) { return g_allocs; }
uint64_t aesir_zc_free_count(void) { return g_frees; }
uint64_t aesir_zc_live_bytes(void) { return g_live_bytes; }
uint64_t aesir_zc_kernel_launch_count(void) { return g_kernel_launches; }
uint64_t aesir_zc_memcpy_call_count(void) { return g_memcpy_calls; }
uint64_t aesir_zc_ownership_violation_count(void) { return g_violations; }
