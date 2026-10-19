// Test-only observer of a private installed-runtime identify process.
// Interface declarations come from the operator's installed UAPI header.
// No vendor implementation, model payload, or production bridge is included.
#define _GNU_SOURCE
#include <stdbool.h>
#include <limits.h>
#include <stdint.h>
#include <inttypes.h>
#include <stddef.h>
#include <stdarg.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <dlfcn.h>
#include <pthread.h>
#include <time.h>
#include "hailo_ioctl_common.h"

static pthread_once_t once = PTHREAD_ONCE_INIT;
static int (*next_ioctl)(int, unsigned long, ...);
static FILE *trace_file;
static _Atomic uint64_t sequence;

static void initialize(void) {
    next_ioctl = (int (*)(int, unsigned long, ...))dlsym(RTLD_NEXT, "ioctl");
    const char *path = getenv("AESIR_DMA_TRACE");
    if (!next_ioctl || !path || !*path || !(trace_file = fopen(path, "wx"))) {
        fputs("Aesir test observer requires a new AESIR_DMA_TRACE path and ioctl binding\n", stderr);
        _exit(126);
    }
    fprintf(trace_file, "{\"kind\":\"observer\",\"page_size\":%ld,\"pointer_bytes\":%zu,\"launch_bytes\":%zu}\n",
            sysconf(_SC_PAGESIZE), sizeof(uintptr_t), sizeof(struct hailo_vdma_launch_transfer_params));
    fflush(trace_file);
}

static uint64_t now_ns(void) {
    struct timespec time;
    if (clock_gettime(CLOCK_MONOTONIC, &time)) _exit(126);
    return (uint64_t)time.tv_sec * UINT64_C(1000000000) + (uint64_t)time.tv_nsec;
}

static const char *operation(unsigned long code) {
    switch (code) {
    case HAILO_QUERY_DRIVER_INFO: return "driver-info";
    case HAILO_QUERY_DEVICE_PROPERTIES: return "properties";
    case HAILO_DESC_LIST_CREATE: return "desc-create";
    case HAILO_DESC_LIST_RELEASE: return "desc-release";
    case HAILO_SOC_CONNECT: return "connect";
    case HAILO_SOC_CLOSE: return "close";
    case HAILO_VDMA_ENABLE_CHANNELS: return "enable-channels";
    case HAILO_VDMA_DISABLE_CHANNELS: return "disable-channels";
    case HAILO_VDMA_INTERRUPTS_WAIT: return "interrupts";
    case HAILO_VDMA_LAUNCH_TRANSFER: return "transfer";
    case HAILO_VDMA_PREPARE_TRANSFER: return "prepare-transfer";
    case HAILO_VDMA_CANCEL_PREPARED_TRANSFER: return "cancel-prepared";
    case HAILO_VDMA_BUFFER_MAP: return "buffer-map";
    case HAILO_VDMA_BUFFER_UNMAP: return "buffer-unmap";
    case HAILO_VDMA_BUFFER_SYNC: return "buffer-sync";
    default: return "other";
    }
}

static void masks(const uint64_t *values) {
    // Packed fields can be unaligned: callers copy them to aligned storage.
    fprintf(trace_file, ",\"masks\":[%" PRIu64 ",%" PRIu64 ",%" PRIu64 "]", values[0], values[1], values[2]);
}

int ioctl(int fd, unsigned long code, ...) {
    int entry_errno = errno;
    va_list arguments;
    va_start(arguments, code);
    void *params = va_arg(arguments, void *);
    va_end(arguments);
    if (pthread_once(&once, initialize)) _exit(126);
    char fd_path[64], node[256];
    snprintf(fd_path, sizeof(fd_path), "/proc/self/fd/%d", fd);
    ssize_t length = readlink(fd_path, node, sizeof(node) - 1);
    if (length < 0) { errno = entry_errno; return next_ioctl(fd, code, params); }
    node[length] = 0;
    if (strncmp(node, "/dev/h1x-", 9)) { errno = entry_errno; return next_ioctl(fd, code, params); }

    uint64_t id = atomic_fetch_add(&sequence, 1);
    uint64_t start = now_ns();
    flockfile(trace_file);
    fprintf(trace_file, "{\"kind\":\"enter\",\"id\":%" PRIu64 ",\"time_ns\":%" PRIu64 ",\"fd\":%d,\"request\":%lu,\"abi_bytes\":%lu,\"operation\":\"%s\"",
            id, start, fd, code, (unsigned long)_IOC_SIZE(code), operation(code));
    if (params && code == HAILO_DESC_LIST_CREATE) {
        const struct hailo_desc_list_create_params *p = params;
        fprintf(trace_file, ",\"count\":%zu,\"page_size\":%u,\"circular\":%s", p->desc_count, p->desc_page_size, p->is_circular ? "true" : "false");
    } else if (params && code == HAILO_SOC_CONNECT) {
        const struct hailo_soc_connect_params *p = params;
        fprintf(trace_file, ",\"port\":%u,\"input_handle\":%" PRIuPTR ",\"output_handle\":%" PRIuPTR, p->port_number, p->input_desc_handle, p->output_desc_handle);
    } else if (params && code == HAILO_SOC_CLOSE) {
        const struct hailo_soc_close_params *p = params;
        fprintf(trace_file, ",\"input_channel\":%u,\"output_channel\":%u", p->input_channel_index, p->output_channel_index);
    } else if (params && code == HAILO_DESC_LIST_RELEASE) {
        const struct hailo_desc_list_release_params *p = params;
        fprintf(trace_file, ",\"handle\":%" PRIuPTR, p->desc_handle);
    } else if (params && (code == HAILO_VDMA_ENABLE_CHANNELS || code == HAILO_VDMA_DISABLE_CHANNELS || code == HAILO_VDMA_INTERRUPTS_WAIT)) {
        uint64_t aligned[3];
        memcpy(aligned, params, sizeof(aligned)); masks(aligned);
    } else if (params && code == HAILO_VDMA_LAUNCH_TRANSFER) {
        const struct hailo_vdma_launch_transfer_params *p = params;
        const struct hailo_vdma_prepare_transfer_params *transfer = &p->prepare_transfer_params;
        fprintf(trace_file, ",\"engine\":%u,\"channel\":%u,\"handle\":%" PRIuPTR ",\"cyclic\":%s,\"buffers\":[", p->engine_index, transfer->channel_index, transfer->desc_handle, p->is_cyclic ? "true" : "false");
        unsigned count = transfer->buffers_count;
        if (count > HAILO_MAX_BUFFERS_PER_SINGLE_TRANSFER) _exit(126);
        for (unsigned i = 0; i < count; ++i) {
            const struct hailo_vdma_transfer_buffer *buffer = &transfer->buffers[i];
            if (i) fputc(',', trace_file);
            fprintf(trace_file, "{\"type\":%d,\"address_or_fd\":%" PRIuPTR ",\"bytes\":%u", buffer->buffer_type, buffer->addr_or_fd, buffer->size);
            // Snapshot only the fixed outgoing header, before kernel submission.
            // D2H storage is not read while its contents may still be undefined.
            if (transfer->channel_index < 16 && buffer->buffer_type == HAILO_DMA_USER_PTR_BUFFER && buffer->size >= 20) {
                unsigned char header[20];
                memcpy(header, (const void *)buffer->addr_or_fd, sizeof(header));
                uint32_t magic;
                memcpy(&magic, header, sizeof(magic));
                if (magic == UINT32_C(0x8A554432)) {
                    fputs(",\"header_hex\":\"", trace_file);
                    for (unsigned b = 0; b < sizeof(header); ++b) fprintf(trace_file, "%02x", header[b]);
                    fputc('"', trace_file);
                }
            }
            fputc('}', trace_file);
        }
        fputc(']', trace_file);
    } else if (params && (code == HAILO_VDMA_BUFFER_MAP || code == HAILO_VDMA_BUFFER_UNMAP)) {
        const struct hailo_vdma_buffer_params *p = params;
        fprintf(trace_file, ",\"address_or_fd\":%" PRIuPTR ",\"bytes\":%zu,\"direction\":%d,\"buffer_type\":%d", p->addr_or_fd, p->size, p->direction, p->type);
    } else if (params && code == HAILO_VDMA_BUFFER_SYNC) {
        const struct hailo_vdma_buffer_sync_params *p = params;
        fprintf(trace_file, ",\"handle\":%zu,\"sync_type\":%d,\"offset\":%zu,\"bytes\":%zu", p->handle, p->sync_type, p->offset, p->count);
    }
    fputs("}\n", trace_file); fflush(trace_file); funlockfile(trace_file);

    errno = entry_errno;
    int result = next_ioctl(fd, code, params);
    int saved_errno = errno;
    uint64_t end = now_ns();
    flockfile(trace_file);
    fprintf(trace_file, "{\"kind\":\"return\",\"id\":%" PRIu64 ",\"time_ns\":%" PRIu64 ",\"result\":%d,\"errno\":%d", id, end, result, result < 0 ? saved_errno : 0);
    if (result >= 0 && params && code == HAILO_SOC_CONNECT) {
        const struct hailo_soc_connect_params *p = params;
        fprintf(trace_file, ",\"input_channel\":%u,\"output_channel\":%u", p->input_channel_index, p->output_channel_index);
    } else if (result >= 0 && params && code == HAILO_DESC_LIST_CREATE) {
        const struct hailo_desc_list_create_params *p = params;
        fprintf(trace_file, ",\"handle\":%" PRIuPTR, p->desc_handle);
    } else if (result >= 0 && params && code == HAILO_VDMA_BUFFER_MAP) {
        const struct hailo_vdma_buffer_params *p = params;
        fprintf(trace_file, ",\"mapped_handle\":%zu", p->mapped_handle);
    } else if (result >= 0 && params && code == HAILO_VDMA_INTERRUPTS_WAIT) {
        const struct hailo_vdma_interrupts_wait_params *p = params;
        unsigned count = p->channels_count;
        if (count > MAX_VDMA_CHANNELS_PER_ENGINE * MAX_VDMA_ENGINES) _exit(126);
        fputs(",\"interrupts\":[", trace_file);
        for (unsigned i = 0; i < count; ++i) {
            if (i) fputc(',', trace_file);
            fprintf(trace_file, "{\"engine\":%u,\"channel\":%u,\"data\":%u}", p->irq_data[i].engine_index, p->irq_data[i].channel_index, p->irq_data[i].data);
        }
        fputc(']', trace_file);
    }
    fputs("}\n", trace_file); fflush(trace_file); funlockfile(trace_file);
    errno = saved_errno;
    return result;
}

// Every record is flushed. Process exit closes the private trace descriptor;
// no destructor order dependency is introduced into the observed runtime.
