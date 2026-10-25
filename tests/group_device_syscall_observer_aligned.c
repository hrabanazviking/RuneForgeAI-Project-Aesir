/* Original TEST-ONLY syscall pass-through observer. Packed declarations are
 * independently licensed UAPI inputs. No vendor implementation is included.
 * Fixed memory records while live; no logging I/O until process finalization.
 * The observer never supplies a result, changes errno, retries or adds an ioctl.
 * ALIGNED variant: the input view may be an aligned backing extent
 * (2048 + a power-of-two descriptor page in [64,32768]); the outgoing
 * logical wire is gathered from header@0 and body@(extent-2048).
 * Private wire records must stay local. Logging failure does not affect Mojo. */
#define _GNU_SOURCE
#include <stdbool.h>
#include <limits.h>
#include <stdint.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <dlfcn.h>
#include <pthread.h>
#include <unistd.h>
#include <sys/syscall.h>
#include "hailo_ioctl_common.h"

enum { LIMIT = 512, PARAMS = 2048, WIRE = 2068 };
struct observation {
    long nr, args[6], result, tid;
    int stage, entry_errno, exit_errno;
    size_t params_size, wire_size;
    unsigned char params[PARAMS], wire[WIRE];
};
static struct observation records[LIMIT];
static size_t used, capacity = LIMIT, dropped;
static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_once_t once = PTHREAD_ONCE_INIT;
static long (*forward_syscall)(long, ...);
static const char *target, *destination;
static char binding[PATH_MAX];
static long owner = -1;
static struct { uintptr_t address; size_t size, handle; int cpu_owned; } views[2];

static void initialize(void) {
    int saved = errno;
    forward_syscall = dlsym(RTLD_NEXT, "syscall");
    target = getenv("AESIR_OBSERVER_NODE");
    destination = getenv("AESIR_OBSERVER_LOG");
    const char *cap = getenv("AESIR_OBSERVER_CAPACITY");
    if (cap) { unsigned long n = strtoul(cap, NULL, 10); if (n <= LIMIT) capacity = n; }
    Dl_info info;
    if (forward_syscall && dladdr((void *)forward_syscall, &info) && info.dli_fname)
        snprintf(binding, sizeof(binding), "%s", info.dli_fname);
    errno = saved;
}

static size_t parameter_size(long request) {
    switch (request) {
    case HAILO_QUERY_DRIVER_INFO: case HAILO_QUERY_DEVICE_PROPERTIES:
    case HAILO_DESC_LIST_CREATE: case HAILO_DESC_LIST_RELEASE:
    case HAILO_SOC_CONNECT: case HAILO_SOC_CLOSE:
    case HAILO_VDMA_BUFFER_MAP: case HAILO_VDMA_BUFFER_UNMAP:
    case HAILO_VDMA_BUFFER_SYNC: case HAILO_VDMA_ENABLE_CHANNELS:
    case HAILO_VDMA_DISABLE_CHANNELS: case HAILO_VDMA_INTERRUPTS_WAIT:
    case HAILO_VDMA_LAUNCH_TRANSFER: return _IOC_SIZE(request);
    default: return 0;
    }
}

/* Called with the short bookkeeping lock held, never around the real call. */
static void record(long nr, const long *args, int stage, long result, int entry, int returned,
                   size_t bytes, const void *wire) {
    if (used >= capacity) { dropped++; return; }
    struct observation *r = &records[used++];
    r->nr = nr; memcpy(r->args, args, sizeof(r->args)); r->stage = stage;
    r->result = result; r->entry_errno = entry; r->exit_errno = returned; r->tid = gettid();
    if (bytes && bytes <= PARAMS && args[2]) {
        memcpy(r->params, (const void *)args[2], bytes); r->params_size = bytes;
    }
    if (wire) { memcpy(r->wire, wire, WIRE); r->wire_size = WIRE; }
}

long syscall(long nr, ...) {
    int entry = errno;
    /* The Mojo runtime can reach syscall from an earlier DSO constructor.
     * Resolve before the first call, independently of constructor ordering. */
    (void)pthread_once(&once, initialize);
    va_list ap; va_start(ap, nr); long args[6];
    for (int i = 0; i < 6; i++) args[i] = va_arg(ap, long);
    va_end(ap);
    /* Mojo's gateway always supplies six arguments. The independent harness
     * does too; this interposer is not a generic variadic libc replacement. */
    int opening = nr == SYS_openat && target && args[1] && !strcmp((const char *)args[1], target);
    pthread_mutex_lock(&mutex);
    int selected = opening || (owner >= 0 && args[0] == owner && (nr == SYS_ioctl || nr == SYS_close));
    if (nr == SYS_munmap)
        for (int i = 0; i < 2; i++) if ((uintptr_t)args[0] == views[i].address && views[i].address) selected = 1;
    size_t bytes = selected && nr == SYS_ioctl ? parameter_size(args[1]) : 0;
    const void *outgoing = NULL;
    static unsigned char gathered[WIRE];
    if (selected && nr == SYS_ioctl && args[1] == (long)HAILO_VDMA_BUFFER_SYNC && args[2]) {
        struct hailo_vdma_buffer_sync_params p; memcpy(&p, (void *)args[2], sizeof(p));
        if (views[0].address && views[0].cpu_owned && p.handle == views[0].handle &&
            p.sync_type == HAILO_SYNC_FOR_DEVICE && p.offset == 0 && p.count == views[0].size) {
            if (views[0].size == WIRE) outgoing = (void *)views[0].address;
            else { /* Aligned extent: header 20 at 0, body 2048 at extent-2048. */
                memcpy(gathered, (void *)views[0].address, 20);
                memcpy(gathered + 20, (void *)(views[0].address + (views[0].size - 2048)), 2048);
                outgoing = gathered;
            }
        }
    }
    if (selected) record(nr, args, 0, 0, entry, entry, bytes, outgoing);
    pthread_mutex_unlock(&mutex);
    errno = entry;
    long result = forward_syscall(nr, args[0], args[1], args[2], args[3], args[4], args[5]);
    int returned = errno;
    pthread_mutex_lock(&mutex);
    if (opening && result >= 0) owner = result;
    if (selected && nr == SYS_ioctl && result == 0 && args[1] == (long)HAILO_VDMA_BUFFER_MAP) {
        struct hailo_vdma_buffer_params p; memcpy(&p, (void *)args[2], sizeof(p));
        int i = (int)p.direction - 1;
        int size_ok = p.size == WIRE;
        if (i == 0 && p.size > WIRE) { /* Aligned input extent: 2048 + page, page a power of two in [64,32768]. */
            size_t page = p.size - 2048;
            size_ok = page >= 64 && page <= 32768 && (page & (page - 1)) == 0;
        }
        if (i >= 0 && i < 2 && p.type == HAILO_DMA_USER_PTR_BUFFER && size_ok) {
            views[i].address = p.addr_or_fd; views[i].size = p.size;
            views[i].handle = p.mapped_handle; views[i].cpu_owned = 1;
        }
    }
    const void *incoming = NULL;
    if (selected && nr == SYS_ioctl && args[1] == (long)HAILO_VDMA_BUFFER_SYNC && args[2]) {
        struct hailo_vdma_buffer_sync_params p; memcpy(&p, (void *)args[2], sizeof(p));
        for (int i = 0; i < 2; i++) if (views[i].address && p.handle == views[i].handle) {
            if (result == 0) views[i].cpu_owned = p.sync_type == HAILO_SYNC_FOR_CPU;
            else views[i].cpu_owned = 0; /* An error leaves ownership uncertain. */
            if (i == 1 && result == 0 && views[i].cpu_owned && p.offset == 0 &&
                p.count == WIRE && views[i].size == WIRE) incoming = (void *)views[i].address;
        }
    }
    if (selected) record(nr, args, 1, result, entry, returned, bytes, incoming);
    if (selected && nr == SYS_close) owner = -1; /* Never retry or assume failure retained the fd. */
    if (selected && nr == SYS_munmap && result == 0)
        for (int i = 0; i < 2; i++) if ((uintptr_t)args[0] == views[i].address) memset(&views[i], 0, sizeof(views[i]));
    pthread_mutex_unlock(&mutex);
    errno = returned;
    return result;
}

static void hex(FILE *f, const unsigned char *p, size_t n) {
    for (size_t i = 0; i < n; i++) fprintf(f, "%02x", p[i]);
}
static void finish(void) __attribute__((destructor));
static void finish(void) {
    int saved = errno;
    /* Exclusive new file, after Mojo's own cleanup. Failure is evidence loss,
     * not authority to interrupt or change the device lifecycle/result. */
    FILE *f = destination ? fopen(destination, "wx") : NULL;
    if (f) {
        fprintf(f, "{\"kind\":\"binding\",\"forward\":\"");
        hex(f, (unsigned char *)binding, strlen(binding));
        fprintf(f, "\",\"pid\":%d,\"used\":%zu,\"dropped\":%zu,\"owner_at_exit\":%ld}\n", getpid(), used, dropped, owner);
        for (size_t i = 0; i < used; i++) {
            struct observation *r = &records[i];
            fprintf(f, "{\"kind\":\"call\",\"sequence\":%zu,\"pid\":%d,\"tid\":%ld,\"nr\":%ld,\"stage\":%d,\"args\":[", i, getpid(), r->tid, r->nr, r->stage);
            for (int j = 0; j < 6; j++) fprintf(f, "%s%ld", j ? "," : "", r->args[j]);
            fprintf(f, "],\"result\":%ld,\"entry_errno\":%d,\"exit_errno\":%d,\"params\":\"", r->result, r->entry_errno, r->exit_errno);
            hex(f, r->params, r->params_size); fprintf(f, "\",\"wire\":\""); hex(f, r->wire, r->wire_size); fprintf(f, "\"}\n");
        }
        (void)fclose(f);
    }
    errno = saved;
}
