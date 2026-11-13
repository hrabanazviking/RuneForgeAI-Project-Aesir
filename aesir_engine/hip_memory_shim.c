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
#include "buffer_ownership.h"

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

/* --- A-022 buffer ownership registry --------------------------------
 * One registry for every allocation this shim makes (device, managed,
 * pinned host) plus stream/event handle tables. Validation always
 * precedes the driver call; a refusal returns a named AESIR_OWN_*
 * code, bumps g_own_violations, and changes nothing else. Freed
 * entries stay as tombstones so a double-free is detectable; a
 * tombstone slot is recycled only for a fresh allocation of the same
 * pointer or when no empty slot remains. */
#define AESIR_HIP_MAX_OWN 8192
#define AESIR_HIP_MAX_HANDLES 4096
#define AESIR_HIP_KIND_DEVICE 1
#define AESIR_HIP_KIND_MANAGED 2
#define AESIR_HIP_KIND_HOST 3

typedef struct {
    void *ptr;
    uint64_t size;
    int kind;
    int state;
} AesirHipOwn;

static AesirHipOwn g_own[AESIR_HIP_MAX_OWN];
static uint64_t g_own_live_bytes = 0;
static uint64_t g_own_live_count = 0;
static uint64_t g_own_allocs = 0;
static uint64_t g_own_frees = 0;
static uint64_t g_own_violations = 0;

typedef struct {
    uint64_t handle;
    int state;
} AesirHipHandleRec;

static AesirHipHandleRec g_stream_recs[AESIR_HIP_MAX_HANDLES];
static AesirHipHandleRec g_event_recs[AESIR_HIP_MAX_HANDLES];

static AesirHipOwn *hip_own_find(void *ptr) {
    for (int i = 0; i < AESIR_HIP_MAX_OWN; i++) {
        if (g_own[i].state != AESIR_OWN_STATE_EMPTY &&
            g_own[i].ptr == ptr) {
            return &g_own[i];
        }
    }
    return NULL;
}


/* A-022 cross-shim live-ownership query (exported): the allocation
 * kind (>0) when ptr is a LIVE or HANDED_OFF allocation of THIS
 * shim, else 0. Pure lookup: no counters, no state change. The
 * zero-copy shim queries this through the process-global symbol
 * table so a pointer currently live in this shim is refused there
 * as MEM-013 even when its address coincides with a stale
 * zero-copy tombstone: the unified pool reuses a freed 4096-byte
 * managed address for the very next managed allocation, so a
 * tombstone-only check misreports cross-shim frees as MEM-005
 * double-frees (proven on purpleraider, A-022 debug probe). */
int aesir_hip_own_live_kind(void *ptr) {
    AesirHipOwn *e = hip_own_find(ptr);
    if (e == NULL) {
        return 0;
    }
    if (e->state == AESIR_OWN_STATE_LIVE ||
        e->state == AESIR_OWN_STATE_HANDED_OFF) {
        return e->kind;
    }
    return 0;
}

typedef int (*aesir_zc_own_live_fn)(void *);

static int hip_zc_own_live(void *ptr) {
    static aesir_zc_own_live_fn fn = NULL;
    static int tried = 0;
    if (!tried) {
        tried = 1;
        void *global = dlopen(NULL, RTLD_NOW);
        if (global != NULL) {
            fn = (aesir_zc_own_live_fn)dlsym(global,
                                             "aesir_zc_own_live");
        }
    }
    if (fn == NULL) {
        return 0;
    }
    return fn(ptr);
}

static int hip_own_register(void *ptr, uint64_t size, int kind) {
    AesirHipOwn *e = hip_own_find(ptr);
    if (e != NULL) {
        if (e->state == AESIR_OWN_STATE_LIVE ||
            e->state == AESIR_OWN_STATE_HANDED_OFF) {
            return AESIR_OWN_INVALID;
        }
        e->size = size;
        e->kind = kind;
        e->state = AESIR_OWN_STATE_LIVE;
        g_own_allocs += 1;
        g_own_live_count += 1;
        g_own_live_bytes += size;
        return 0;
    }
    AesirHipOwn *slot = NULL;
    AesirHipOwn *tomb = NULL;
    for (int i = 0; i < AESIR_HIP_MAX_OWN; i++) {
        if (g_own[i].state == AESIR_OWN_STATE_EMPTY) {
            slot = &g_own[i];
            break;
        }
        if (tomb == NULL && g_own[i].state == AESIR_OWN_STATE_FREED) {
            tomb = &g_own[i];
        }
    }
    if (slot == NULL) {
        slot = tomb;
    }
    if (slot == NULL) {
        return AESIR_OWN_INVALID;
    }
    slot->ptr = ptr;
    slot->size = size;
    slot->kind = kind;
    slot->state = AESIR_OWN_STATE_LIVE;
    g_own_allocs += 1;
    g_own_live_count += 1;
    g_own_live_bytes += size;
    return 0;
}

/* Validate a pointer presented for use (memcpy endpoints). Foreign
 * pointers (pageable host memory and the like) are not this shim's to
 * police on the use path and pass; pointers this shim issued are
 * checked against their tombstones, hand-off state, and bounds. */
static int hip_own_validate_use(const void *ptr, uint64_t len) {
    if (ptr == NULL) {
        return 0;
    }
    for (int i = 0; i < AESIR_HIP_MAX_OWN; i++) {
        if (g_own[i].state == AESIR_OWN_STATE_EMPTY) {
            continue;
        }
        uintptr_t base = (uintptr_t)g_own[i].ptr;
        uintptr_t p = (uintptr_t)ptr;
        if (p < base || p >= base + g_own[i].size) {
            continue;
        }
        if (g_own[i].state == AESIR_OWN_STATE_FREED) {
            g_own_violations += 1;
            return AESIR_OWN_USE_AFTER_FREE;
        }
        if (g_own[i].state == AESIR_OWN_STATE_HANDED_OFF) {
            g_own_violations += 1;
            return AESIR_OWN_USE_AFTER_HANDOFF;
        }
        if ((p - base) + len > g_own[i].size) {
            g_own_violations += 1;
            return AESIR_OWN_INVALID;
        }
        return 0;
    }
    return 0;
}

static AesirHipHandleRec *hip_handle_find(AesirHipHandleRec *recs,
                                          uint64_t h) {
    for (int i = 0; i < AESIR_HIP_MAX_HANDLES; i++) {
        if (recs[i].state != AESIR_OWN_STATE_EMPTY &&
            recs[i].handle == h) {
            return &recs[i];
        }
    }
    return NULL;
}

static void hip_handle_register(AesirHipHandleRec *recs, uint64_t h) {
    AesirHipHandleRec *e = hip_handle_find(recs, h);
    if (e != NULL) {
        e->state = AESIR_OWN_STATE_LIVE;
        return;
    }
    AesirHipHandleRec *slot = NULL;
    AesirHipHandleRec *tomb = NULL;
    for (int i = 0; i < AESIR_HIP_MAX_HANDLES; i++) {
        if (recs[i].state == AESIR_OWN_STATE_EMPTY) {
            slot = &recs[i];
            break;
        }
        if (tomb == NULL && recs[i].state == AESIR_OWN_STATE_FREED) {
            tomb = &recs[i];
        }
    }
    if (slot == NULL) {
        slot = tomb;
    }
    if (slot == NULL) {
        return;
    }
    slot->handle = h;
    slot->state = AESIR_OWN_STATE_LIVE;
}

static int hip_handle_validate(AesirHipHandleRec *recs, uint64_t h,
                               int for_destroy) {
    if (h == 0) {
        return 0; /* legacy default stream: not shim-owned */
    }
    AesirHipHandleRec *e = hip_handle_find(recs, h);
    if (e == NULL) {
        g_own_violations += 1;
        return AESIR_OWN_NOT_OWNER;
    }
    if (e->state == AESIR_OWN_STATE_FREED) {
        g_own_violations += 1;
        return for_destroy ? AESIR_OWN_DOUBLE_FREE
                           : AESIR_OWN_USE_AFTER_FREE;
    }
    return 0;
}

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
    int rc = g_malloc(out, (size_t)size_bytes);
    if (rc != 0) {
        return rc;
    }
    if (out == NULL || *out == NULL) {
        return AESIR_OWN_INVALID;
    }
    if (hip_own_register(*out, size_bytes, AESIR_HIP_KIND_DEVICE) != 0) {
        g_free(*out);
        *out = NULL;
        return AESIR_OWN_INVALID;
    }
    return 0;
}

int aesir_hip_malloc_managed(void **out, uint64_t size_bytes) {
    aesir_hip_init();
    if (!g_ok) {
        return -1;
    }
    /* hipMemAttachGlobal = 1: accessible from any device and the host. */
    int rc = g_managed(out, (size_t)size_bytes, 1u);
    if (rc != 0) {
        return rc;
    }
    if (out == NULL || *out == NULL) {
        return AESIR_OWN_INVALID;
    }
    if (hip_own_register(*out, size_bytes, AESIR_HIP_KIND_MANAGED) != 0) {
        g_free(*out);
        *out = NULL;
        return AESIR_OWN_INVALID;
    }
    return 0;
}

int aesir_hip_free(void *ptr) {
    aesir_hip_init();
    if (!g_ok) {
        return -1;
    }
    if (ptr == NULL) {
        return 0;
    }
    /* A-022 cross-shim: a pointer live in the zero-copy shim is not
     * this shim's to free, whatever this registry's tombstones say
     * about its (reused) address. Refuse as MEM-013. */
    if (hip_zc_own_live(ptr)) {
        g_own_violations += 1;
        return AESIR_OWN_NOT_OWNER;
    }
    AesirHipOwn *e = hip_own_find(ptr);
    if (e == NULL) {
        g_own_violations += 1;
        return AESIR_OWN_NOT_OWNER;
    }
    if (e->state == AESIR_OWN_STATE_FREED) {
        g_own_violations += 1;
        return AESIR_OWN_DOUBLE_FREE;
    }
    if (e->state == AESIR_OWN_STATE_HANDED_OFF) {
        g_own_violations += 1;
        return AESIR_OWN_USE_AFTER_HANDOFF;
    }
    if (e->kind == AESIR_HIP_KIND_HOST) {
        g_own_violations += 1;
        return AESIR_OWN_CROSS_DEVICE;
    }
    int rc = g_free(ptr);
    if (rc == 0) {
        e->state = AESIR_OWN_STATE_FREED;
        g_own_live_bytes -= e->size;
        g_own_live_count -= 1;
        g_own_frees += 1;
    }
    return rc;
}

/* A-022 hand-off: the sender's ownership tombstones; every further
 * sender-side use/free is refused until the receiver claims. */
int aesir_hip_handoff(void *ptr) {
    aesir_hip_init();
    if (!g_ok) {
        return -1;
    }
    AesirHipOwn *e = hip_own_find(ptr);
    if (e == NULL) {
        g_own_violations += 1;
        return AESIR_OWN_NOT_OWNER;
    }
    if (e->state == AESIR_OWN_STATE_FREED) {
        g_own_violations += 1;
        return AESIR_OWN_USE_AFTER_FREE;
    }
    if (e->state == AESIR_OWN_STATE_HANDED_OFF) {
        g_own_violations += 1;
        return AESIR_OWN_USE_AFTER_HANDOFF;
    }
    e->state = AESIR_OWN_STATE_HANDED_OFF;
    return 0;
}

int aesir_hip_claim(void *ptr) {
    aesir_hip_init();
    if (!g_ok) {
        return -1;
    }
    AesirHipOwn *e = hip_own_find(ptr);
    if (e == NULL) {
        g_own_violations += 1;
        return AESIR_OWN_NOT_OWNER;
    }
    if (e->state == AESIR_OWN_STATE_FREED) {
        g_own_violations += 1;
        return AESIR_OWN_USE_AFTER_FREE;
    }
    if (e->state != AESIR_OWN_STATE_HANDED_OFF) {
        g_own_violations += 1;
        return AESIR_OWN_INVALID;
    }
    e->state = AESIR_OWN_STATE_LIVE;
    return 0;
}

uint64_t aesir_hip_live_bytes(void) { return g_own_live_bytes; }
uint64_t aesir_hip_live_count(void) { return g_own_live_count; }
uint64_t aesir_hip_alloc_count(void) { return g_own_allocs; }
uint64_t aesir_hip_free_count(void) { return g_own_frees; }
uint64_t aesir_hip_ownership_violation_count(void) {
    return g_own_violations;
}

int aesir_hip_memcpy(void *dst, const void *src, uint64_t size_bytes,
                     int kind) {
    aesir_hip_init();
    if (!g_ok) {
        return -1;
    }
    int v = hip_own_validate_use(dst, size_bytes);
    if (v != 0) {
        return v;
    }
    v = hip_own_validate_use(src, size_bytes);
    if (v != 0) {
        return v;
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
        hip_handle_register(g_stream_recs,
                            (uint64_t)(uintptr_t)stream);
        *out_handle = (uint64_t)(uintptr_t)stream;
    }
    return rc;
}

int aesir_hip_stream_destroy(uint64_t handle) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    int v = hip_handle_validate(g_stream_recs, handle, 1);
    if (v != 0) {
        return v;
    }
    int rc = g_sdestroy((void *)(uintptr_t)handle);
    if (rc == 0) {
        AesirHipHandleRec *e = hip_handle_find(g_stream_recs, handle);
        if (e != NULL) {
            e->state = AESIR_OWN_STATE_FREED;
        }
    }
    return rc;
}

int aesir_hip_stream_synchronize(uint64_t handle) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    int v = hip_handle_validate(g_stream_recs, handle, 0);
    if (v != 0) {
        return v;
    }
    return g_ssync((void *)(uintptr_t)handle);
}

int aesir_hip_stream_query(uint64_t handle) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    int v = hip_handle_validate(g_stream_recs, handle, 0);
    if (v != 0) {
        return v;
    }
    return g_squery((void *)(uintptr_t)handle);
}

int aesir_hip_memcpy_async(void *dst, const void *src, uint64_t size_bytes,
                           int kind, uint64_t stream) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    int v = hip_handle_validate(g_stream_recs, stream, 0);
    if (v != 0) {
        return v;
    }
    v = hip_own_validate_use(dst, size_bytes);
    if (v != 0) {
        return v;
    }
    v = hip_own_validate_use(src, size_bytes);
    if (v != 0) {
        return v;
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
    int rc = g_host_malloc(out, (size_t)size_bytes, 0u);
    if (rc != 0) {
        return rc;
    }
    if (out == NULL || *out == NULL) {
        return AESIR_OWN_INVALID;
    }
    if (hip_own_register(*out, size_bytes, AESIR_HIP_KIND_HOST) != 0) {
        g_host_free(*out);
        *out = NULL;
        return AESIR_OWN_INVALID;
    }
    return 0;
}

int aesir_hip_host_free(void *ptr) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    if (ptr == NULL) {
        return 0;
    }
    if (hip_zc_own_live(ptr)) {
        g_own_violations += 1;
        return AESIR_OWN_NOT_OWNER;
    }
    AesirHipOwn *e = hip_own_find(ptr);
    if (e == NULL) {
        g_own_violations += 1;
        return AESIR_OWN_NOT_OWNER;
    }
    if (e->state == AESIR_OWN_STATE_FREED) {
        g_own_violations += 1;
        return AESIR_OWN_DOUBLE_FREE;
    }
    if (e->state == AESIR_OWN_STATE_HANDED_OFF) {
        g_own_violations += 1;
        return AESIR_OWN_USE_AFTER_HANDOFF;
    }
    if (e->kind != AESIR_HIP_KIND_HOST) {
        g_own_violations += 1;
        return AESIR_OWN_CROSS_DEVICE;
    }
    int rc = g_host_free(ptr);
    if (rc == 0) {
        e->state = AESIR_OWN_STATE_FREED;
        g_own_live_bytes -= e->size;
        g_own_live_count -= 1;
        g_own_frees += 1;
    }
    return rc;
}

int aesir_hip_event_create(uint64_t *out_handle) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    void *event = NULL;
    int rc = g_ecreate(&event);
    if (rc == 0) {
        hip_handle_register(g_event_recs, (uint64_t)(uintptr_t)event);
        *out_handle = (uint64_t)(uintptr_t)event;
    }
    return rc;
}

int aesir_hip_event_record(uint64_t event, uint64_t stream) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    int v = hip_handle_validate(g_event_recs, event, 0);
    if (v != 0) {
        return v;
    }
    v = hip_handle_validate(g_stream_recs, stream, 0);
    if (v != 0) {
        return v;
    }
    return g_erecord((void *)(uintptr_t)event, (void *)(uintptr_t)stream);
}

int aesir_hip_event_synchronize(uint64_t event) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    int v = hip_handle_validate(g_event_recs, event, 0);
    if (v != 0) {
        return v;
    }
    return g_esync((void *)(uintptr_t)event);
}

int aesir_hip_event_elapsed_ms(uint64_t start, uint64_t end, float *out_ms) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    int v = hip_handle_validate(g_event_recs, start, 0);
    if (v != 0) {
        return v;
    }
    v = hip_handle_validate(g_event_recs, end, 0);
    if (v != 0) {
        return v;
    }
    return g_eelapsed(out_ms, (void *)(uintptr_t)start,
                      (void *)(uintptr_t)end);
}

int aesir_hip_event_destroy(uint64_t event) {
    aesir_hip_init();
    if (!g_xfer_ok) {
        return -1;
    }
    int v = hip_handle_validate(g_event_recs, event, 1);
    if (v != 0) {
        return v;
    }
    int rc = g_edestroy((void *)(uintptr_t)event);
    if (rc == 0) {
        AesirHipHandleRec *e = hip_handle_find(g_event_recs, event);
        if (e != NULL) {
            e->state = AESIR_OWN_STATE_FREED;
        }
    }
    return rc;
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

/* --- A-082: HIP Q8_0 GEMV dispatch evidence counter -------------
 * The Mojo-native HIP kernel (core/hip_gemv.mojo) launches through
 * MAX DeviceContext, not through this shim, so the shim cannot see
 * the launch itself. The gateway calls aesir_hip_note_q8_gemv_
 * dispatch() only after enqueue_function + enqueue_copy back +
 * ctx.synchronize() have all completed without raising, so the
 * counter counts exactly the GEMV dispatches that completed on
 * the device - the A-082 device-execution evidence (law 6). */
static uint64_t g_q8_gemv_dispatches = 0;

void aesir_hip_note_q8_gemv_dispatch(void) {
    g_q8_gemv_dispatches += 1;
}

uint64_t aesir_hip_q8_gemv_dispatch_count(void) {
    return g_q8_gemv_dispatches;
}
