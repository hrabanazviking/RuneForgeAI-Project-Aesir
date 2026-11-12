/* hip_memory_shim.c — HIP memory C ABI for Project Aesir (slice A-011).
 *
 * Why a shim: Mojo 1.0 cannot mix the repo's external_call dlopen/dlclose
 * idiom (core/amd_gate.mojo) with stdlib OwnedDLHandle in one program —
 * the two declare dlclose with conflicting erased signatures and the
 * module fails to lower (proven on purpleraider, filed in the A-011
 * ledger). This shim keeps all dynamic loading in C, following the
 * repo's established staging pattern (hailo10h_stub.c, thread_par.c):
 * scripts compile it to libaesir_hip.so and the Mojo side calls the
 * flat aesir_hip_* functions through external_call.
 *
 * The shim dlopens libamdhip64 once (unversioned name first, then the
 * versioned sonames distro runtime packages actually install) and keeps
 * the handle for the process lifetime, so the HIP runtime can never be
 * unloaded beneath a live device allocation. Every function returns the
 * HIP error code (0 = hipSuccess), or -1 when the HIP runtime is not
 * loadable on this host; nothing is simulated.
 */

#include <dlfcn.h>
#include <stddef.h>
#include <stdint.h>

typedef int (*hip_get_device_count_fn)(int *);
typedef int (*hip_malloc_fn)(void **, size_t);
typedef int (*hip_free_fn)(void *);
typedef int (*hip_malloc_managed_fn)(void **, size_t, unsigned int);
typedef int (*hip_memcpy_fn)(void *, const void *, size_t, int);
typedef int (*hip_mem_get_info_fn)(size_t *, size_t *);
typedef int (*hip_device_synchronize_fn)(void);

static void *g_handle = NULL;
static hip_get_device_count_fn g_count = NULL;
static hip_malloc_fn g_malloc = NULL;
static hip_free_fn g_free = NULL;
static hip_malloc_managed_fn g_managed = NULL;
static hip_memcpy_fn g_memcpy = NULL;
static hip_mem_get_info_fn g_info = NULL;
static hip_device_synchronize_fn g_sync = NULL;
static int g_tried = 0;
static int g_ok = 0;

static void aesir_hip_init(void) {
    if (g_tried) {
        return;
    }
    g_tried = 1;
    const char *names[] = {"libamdhip64.so", "libamdhip64.so.7",
                           "libamdhip64.so.6", "libamdhip64.so.5", NULL};
    for (int i = 0; names[i] != NULL; i++) {
        g_handle = dlopen(names[i], RTLD_NOW);
        if (g_handle != NULL) {
            break;
        }
    }
    if (g_handle == NULL) {
        return;
    }
    g_count = (hip_get_device_count_fn)dlsym(g_handle, "hipGetDeviceCount");
    g_malloc = (hip_malloc_fn)dlsym(g_handle, "hipMalloc");
    g_free = (hip_free_fn)dlsym(g_handle, "hipFree");
    g_managed = (hip_malloc_managed_fn)dlsym(g_handle, "hipMallocManaged");
    g_memcpy = (hip_memcpy_fn)dlsym(g_handle, "hipMemcpy");
    g_info = (hip_mem_get_info_fn)dlsym(g_handle, "hipMemGetInfo");
    g_sync = (hip_device_synchronize_fn)dlsym(g_handle,
                                               "hipDeviceSynchronize");
    g_ok = (g_count != NULL && g_malloc != NULL && g_free != NULL &&
            g_managed != NULL && g_memcpy != NULL && g_info != NULL &&
            g_sync != NULL);
}

int aesir_hip_available(void) {
    aesir_hip_init();
    return g_ok ? 1 : 0;
}

int aesir_hip_device_count(int *out) {
    aesir_hip_init();
    if (!g_ok) {
        return -1;
    }
    return g_count(out);
}

int aesir_hip_mem_get_info(uint64_t *free_out, uint64_t *total_out) {
    aesir_hip_init();
    if (!g_ok) {
        return -1;
    }
    size_t free_b = 0;
    size_t total_b = 0;
    int rc = g_info(&free_b, &total_b);
    if (rc == 0) {
        *free_out = (uint64_t)free_b;
        *total_out = (uint64_t)total_b;
    }
    return rc;
}

int aesir_hip_malloc(void **out, uint64_t size_bytes) {
    aesir_hip_init();
    if (!g_ok) {
        return -1;
    }
    return g_malloc(out, (size_t)size_bytes);
}

int aesir_hip_malloc_managed(void **out, uint64_t size_bytes) {
    aesir_hip_init();
    if (!g_ok) {
        return -1;
    }
    /* hipMemAttachGlobal = 1: accessible from any device and the host. */
    return g_managed(out, (size_t)size_bytes, 1u);
}

int aesir_hip_free(void *ptr) {
    aesir_hip_init();
    if (!g_ok) {
        return -1;
    }
    return g_free(ptr);
}

int aesir_hip_memcpy(void *dst, const void *src, uint64_t size_bytes,
                     int kind) {
    aesir_hip_init();
    if (!g_ok) {
        return -1;
    }
    return g_memcpy(dst, src, (size_t)size_bytes, kind);
}

int aesir_hip_device_synchronize(void) {
    aesir_hip_init();
    if (!g_ok) {
        return -1;
    }
    return g_sync();
}
