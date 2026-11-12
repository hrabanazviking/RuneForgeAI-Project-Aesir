/* hip_memory_shim.c — HIP memory C ABI for Project Aesir (slice A-011;
 * extended with streams / async memcpy / pinned host memory / events
 * for slice A-012, HIP transfer + streams).
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
typedef int (*hip_stream_create_fn)(void **, unsigned int);
typedef int (*hip_stream_destroy_fn)(void *);
typedef int (*hip_stream_sync_fn)(void *);
typedef int (*hip_stream_query_fn)(void *);
typedef int (*hip_memcpy_async_fn)(void *, const void *, size_t, int, void *);
typedef int (*hip_host_malloc_fn)(void **, size_t, unsigned int);
typedef int (*hip_host_free_fn)(void *);
typedef int (*hip_event_create_fn)(void **);
typedef int (*hip_event_record_fn)(void *, void *);
typedef int (*hip_event_sync_fn)(void *);
typedef int (*hip_event_elapsed_fn)(float *, void *, void *);
typedef int (*hip_event_destroy_fn)(void *);

static void *g_handle = NULL;
static hip_get_device_count_fn g_count = NULL;
static hip_malloc_fn g_malloc = NULL;
static hip_free_fn g_free = NULL;
static hip_malloc_managed_fn g_managed = NULL;
static hip_memcpy_fn g_memcpy = NULL;
static hip_mem_get_info_fn g_info = NULL;
static hip_device_synchronize_fn g_sync = NULL;
static hip_stream_create_fn g_screate = NULL;
static hip_stream_destroy_fn g_sdestroy = NULL;
static hip_stream_sync_fn g_ssync = NULL;
static hip_stream_query_fn g_squery = NULL;
static hip_memcpy_async_fn g_memcpy_async = NULL;
static hip_host_malloc_fn g_host_malloc = NULL;
static hip_host_free_fn g_host_free = NULL;
static hip_event_create_fn g_ecreate = NULL;
static hip_event_record_fn g_erecord = NULL;
static hip_event_sync_fn g_esync = NULL;
static hip_event_elapsed_fn g_eelapsed = NULL;
static hip_event_destroy_fn g_edestroy = NULL;
typedef int (*hip_host_register_fn)(void *, size_t, unsigned int);
typedef int (*hip_host_unregister_fn)(void *);
typedef int (*hip_host_get_device_pointer_fn)(void **, void *, unsigned int);
static hip_host_register_fn g_hreg = NULL;
static hip_host_unregister_fn g_hunreg = NULL;
static hip_host_get_device_pointer_fn g_hdevptr = NULL;
static int g_reg_ok = 0;
static int g_xfer_ok = 0;
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
    g_screate = (hip_stream_create_fn)dlsym(g_handle,
                                             "hipStreamCreateWithFlags");
    g_sdestroy = (hip_stream_destroy_fn)dlsym(g_handle, "hipStreamDestroy");
    g_ssync = (hip_stream_sync_fn)dlsym(g_handle, "hipStreamSynchronize");
    g_squery = (hip_stream_query_fn)dlsym(g_handle, "hipStreamQuery");
    g_memcpy_async = (hip_memcpy_async_fn)dlsym(g_handle, "hipMemcpyAsync");
    g_host_malloc = (hip_host_malloc_fn)dlsym(g_handle, "hipHostMalloc");
    g_host_free = (hip_host_free_fn)dlsym(g_handle, "hipHostFree");
    g_ecreate = (hip_event_create_fn)dlsym(g_handle, "hipEventCreate");
    g_erecord = (hip_event_record_fn)dlsym(g_handle, "hipEventRecord");
    g_esync = (hip_event_sync_fn)dlsym(g_handle, "hipEventSynchronize");
    g_eelapsed = (hip_event_elapsed_fn)dlsym(g_handle,
                                             "hipEventElapsedTime");
    g_edestroy = (hip_event_destroy_fn)dlsym(g_handle, "hipEventDestroy");
    g_hreg = (hip_host_register_fn)dlsym(g_handle, "hipHostRegister");
    g_hunreg = (hip_host_unregister_fn)dlsym(g_handle, "hipHostUnregister");
    g_hdevptr = (hip_host_get_device_pointer_fn)dlsym(g_handle,
                                                 "hipHostGetDevicePointer");
    g_reg_ok = (g_hreg != NULL && g_hunreg != NULL && g_hdevptr != NULL);
    g_xfer_ok = (g_screate != NULL && g_sdestroy != NULL &&
                 g_ssync != NULL && g_squery != NULL &&
                 g_memcpy_async != NULL && g_host_malloc != NULL &&
                 g_host_free != NULL && g_ecreate != NULL &&
                 g_erecord != NULL && g_esync != NULL &&
                 g_eelapsed != NULL && g_edestroy != NULL);
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

/* --- A-012: streams, async memcpy, pinned host memory, events --------
 * Handles cross the ABI as uint64_t addresses (hipStream_t / hipEvent_t
 * are opaque pointers on this platform). Every function returns the HIP
 * error code verbatim (0 = hipSuccess; hipStreamQuery returns 600 =
 * hipErrorNotReady while work is in flight, proven on purpleraider),
 * or -1 when the runtime / transfer symbols are not loadable. */

int aesir_hip_transfer_available(void) {
    aesir_hip_init();
    return (g_ok && g_xfer_ok) ? 1 : 0;
}

int aesir_hip_stream_create(uint64_t *out_handle) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    void *stream = NULL;
    /* hipStreamNonBlocking = 1: no implicit synchronisation with the
     * legacy default stream, so distinct streams can overlap. */
    int rc = g_screate(&stream, 1u);
    if (rc == 0) {
        *out_handle = (uint64_t)(uintptr_t)stream;
    }
    return rc;
}

int aesir_hip_stream_destroy(uint64_t handle) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    return g_sdestroy((void *)(uintptr_t)handle);
}

int aesir_hip_stream_synchronize(uint64_t handle) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    return g_ssync((void *)(uintptr_t)handle);
}

int aesir_hip_stream_query(uint64_t handle) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    return g_squery((void *)(uintptr_t)handle);
}

int aesir_hip_memcpy_async(void *dst, const void *src, uint64_t size_bytes,
                           int kind, uint64_t stream) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    return g_memcpy_async(dst, src, (size_t)size_bytes, kind,
                          (void *)(uintptr_t)stream);
}

int aesir_hip_host_malloc(void **out, uint64_t size_bytes) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    /* flags 0 = hipHostMallocDefault: portable pinned host memory. */
    return g_host_malloc(out, (size_t)size_bytes, 0u);
}

int aesir_hip_host_free(void *ptr) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    return g_host_free(ptr);
}

int aesir_hip_event_create(uint64_t *out_handle) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    void *event = NULL;
    int rc = g_ecreate(&event);
    if (rc == 0) {
        *out_handle = (uint64_t)(uintptr_t)event;
    }
    return rc;
}

int aesir_hip_event_record(uint64_t event, uint64_t stream) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    return g_erecord((void *)(uintptr_t)event, (void *)(uintptr_t)stream);
}

int aesir_hip_event_synchronize(uint64_t event) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    return g_esync((void *)(uintptr_t)event);
}

int aesir_hip_event_elapsed_ms(uint64_t start, uint64_t end, float *out_ms) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    return g_eelapsed(out_ms, (void *)(uintptr_t)start,
                      (void *)(uintptr_t)end);
}

int aesir_hip_event_destroy(uint64_t event) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    return g_edestroy((void *)(uintptr_t)event);
}

/* A-020 weight residency: HIP host registration of an existing mmap
 * range (the GGUF loader's mapping) plus /proc residency accounting.
 * hipHostRegister with hipHostRegisterMapped (=2) makes the SAME host
 * pages device-visible: hipHostGetDevicePointer returns the host
 * address itself on Strix Halo's unified-memory pool (proven in the
 * A-020 probe), so no duplicate device copy is allocated. The /proc
 * readers report process RSS and the smaps accounting of the single
 * mapping containing a given address, split into resident bytes,
 * file-backed clean bytes, and anonymous dirty bytes - the three
 * numbers single-residency claims must distinguish. Nothing here is
 * simulated: registration returns the real HIP error code, and the
 * /proc readers return -1 when accounting cannot be read. */
#include <stdio.h>

int aesir_hip_host_register(void *ptr, uint64_t size_bytes) {
    aesir_hip_init();
    if (!g_reg_ok) {
        return -1;
    }
    /* hipHostRegisterMapped = 2. */
    return g_hreg(ptr, (size_t)size_bytes, 2u);
}

int aesir_hip_host_unregister(void *ptr) {
    aesir_hip_init();
    if (!g_reg_ok) {
        return -1;
    }
    return g_hunreg(ptr);
}

int aesir_hip_host_device_pointer(void *host, void **out) {
    aesir_hip_init();
    if (!g_reg_ok) {
        return -1;
    }
    return g_hdevptr(out, host, 0u);
}

int64_t aesir_residency_process_rss_bytes(void) {
    FILE *f = fopen("/proc/self/status", "r");
    if (f == NULL) {
        return -1;
    }
    char line[256];
    int64_t rss = -1;
    while (fgets(line, sizeof(line), f) != NULL) {
        unsigned long kb = 0;
        if (sscanf(line, "VmRSS: %lu kB", &kb) == 1) {
            rss = (int64_t)kb * 1024;
            break;
        }
    }
    fclose(f);
    return rss;
}

int aesir_residency_mapping_bytes(uint64_t addr, uint64_t *rss_out,
                                  uint64_t *file_clean_out,
                                  uint64_t *anon_dirty_out) {
    FILE *f = fopen("/proc/self/smaps", "r");
    if (f == NULL) {
        return -1;
    }
    char line[512];
    int in_target = 0;
    int found = 0;
    int target_is_file = 0;
    uint64_t rss = 0, shared_clean = 0, private_clean = 0, private_dirty = 0;
    uint64_t shared_dirty = 0;
    while (fgets(line, sizeof(line), f) != NULL) {
        unsigned long start = 0, end = 0;
        unsigned long inode = 0;
        if (sscanf(line, "%lx-%lx", &start, &end) == 2 &&
            line[0] >= '0' && line[0] <= '9') {
            in_target = (addr >= (uint64_t)start && addr < (uint64_t)end);
            if (in_target) {
                found = 1;
                /* Header tail: perms offset dev inode [pathname]. A
                 * nonzero inode means file-backed: its dirty pages
                 * are the file's own page cache (one copy), not an
                 * anonymous duplicate. */
                unsigned long ino = 0;
                unsigned long dstart = 0, dend = 0, doff = 0;
                char perms[8] = {0}, devmaj[16] = {0}, devmin[16] = {0};
                if (sscanf(line, "%lx-%lx %7s %lx %15[^:]:%15s %lu",
                           &dstart, &dend, perms, &doff, devmaj, devmin,
                           &ino) >= 7) {
                    inode = ino;
                }
                target_is_file = (inode != 0);
            }
            continue;
        }
        if (!in_target) {
            continue;
        }
        unsigned long kb = 0;
        if (sscanf(line, "Rss: %lu kB", &kb) == 1) {
            rss = (uint64_t)kb * 1024;
        } else if (sscanf(line, "Shared_Clean: %lu kB", &kb) == 1) {
            shared_clean = (uint64_t)kb * 1024;
        } else if (sscanf(line, "Private_Clean: %lu kB", &kb) == 1) {
            private_clean = (uint64_t)kb * 1024;
        } else if (sscanf(line, "Private_Dirty: %lu kB", &kb) == 1) {
            private_dirty = (uint64_t)kb * 1024;
        } else if (sscanf(line, "Shared_Dirty: %lu kB", &kb) == 1) {
            shared_dirty = (uint64_t)kb * 1024;
        }
    }
    fclose(f);
    if (!found) {
        return -1;
    }
    *rss_out = rss;
    if (target_is_file) {
        *file_clean_out = shared_clean + private_clean + shared_dirty +
                          private_dirty;
        *anon_dirty_out = 0;
    } else {
        *file_clean_out = shared_clean + private_clean;
        *anon_dirty_out = private_dirty + shared_dirty;
    }
    return 0;
}
