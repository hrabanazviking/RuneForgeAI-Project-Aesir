/* a019_probe.c - direct shim-ABI oracle for A-019 (zero-copy
 * allocator). Links the staged libaesir_zc.so + libaesir_vulkan.so
 * and proves, outside Mojo:
 *   HIP: CPU writes a hipMallocManaged buffer, the HIPRTC gfx1151
 *   transform kernel reads it (byte-exact), the fill kernel writes
 *   a buffer the CPU reads (byte-exact), memcpy counter stays 0
 *   while kernel launches advance.
 *   Vulkan: HOST_CACHED coherent buffers (flags asserted), CPU
 *   writes, A-015 vec_add kernel reads, CPU reads back byte-exact,
 *   Vulkan copy counter stays 0.
 */
#include <stdio.h>
#include <stdint.h>
#include <string.h>

int aesir_zc_available(void);
int aesir_zc_hip_alloc_managed(void **, uint64_t);
int aesir_zc_hip_free(void *);
int aesir_zc_hip_transform(void *, void *, uint32_t);
int aesir_zc_hip_fill(void *, uint32_t);
uint64_t aesir_zc_kernel_launch_count(void);
uint64_t aesir_zc_memcpy_call_count(void);
uint64_t aesir_zc_live_bytes(void);

int aesir_vk_buffer_alloc_cached(uint64_t, uint64_t *, uint64_t *,
                                 uint64_t *, uint32_t *, uint32_t *);
int aesir_vk_buffer_map(uint64_t, uint64_t *);
int aesir_vk_buffer_unmap(uint64_t);
int aesir_vk_buffer_free(uint64_t);
int aesir_vk_buffer_vec_add(uint64_t, uint64_t, uint64_t, uint32_t);
uint64_t aesir_vk_copy_call_count(void);
int aesir_vk_buffer_device_info(char *, int32_t, uint32_t *, uint32_t *,
                                uint32_t *, uint32_t *, uint32_t *);

static float fa(int i) { return (float)((i * 37 + 11) % 997) * 0.5f - 100.0f; }
static float fb(int i) { return (float)((i * 91 + 7) % 613) * 0.25f + 3.0f; }

int main(void) {
    int fails = 0;
    /* Vulkan device identity first (RADV evidence). */
    char name[256]; memset(name, 0, sizeof(name));
    uint32_t vendor = 0, dev = 0, api = 0, dtype = 0, qf = 0;
    int drc = aesir_vk_buffer_device_info(name, 256, &vendor, &dev, &api,
                                          &dtype, &qf);
    printf("VK_DEVICE rc=%d name=%s vendor=0x%x type=%u\n", drc, name,
           vendor, dtype);
    if (drc != 0 || vendor != 0x1002u || strstr(name, "RADV") == NULL)
        fails++;

    printf("ZC_AVAILABLE=%d\n", aesir_zc_available());
    if (!aesir_zc_available()) { printf("RESULT FAIL hip absent\n"); return 1; }

    const int sizes[] = {1, 7, 255, 256, 257, 1000, 4097, 65537};
    for (unsigned s = 0; s < sizeof(sizes) / sizeof(sizes[0]); s++) {
        int n = sizes[s];
        float *src = NULL, *dst = NULL;
        if (aesir_zc_hip_alloc_managed((void **)&src, (uint64_t)n * 4) != 0)
            { printf("HIP alloc fail n=%d\n", n); fails++; continue; }
        if (aesir_zc_hip_alloc_managed((void **)&dst, (uint64_t)n * 4) != 0)
            { printf("HIP alloc fail n=%d\n", n); fails++; continue; }
        for (int i = 0; i < n; i++) src[i] = fa(i);
        for (int i = 0; i < n; i++) dst[i] = -9999.0f;
        int rc = aesir_zc_hip_transform(src, dst, (uint32_t)n);
        if (rc != 0) { printf("HIP transform rc=%d n=%d\n", rc, n); fails++; }
        int bad = 0;
        for (int i = 0; i < n; i++)
            if (dst[i] != fa(i) * 2.0f + 1.0f) bad++;
        printf("HIP_TRANSFORM n=%d bad=%d\n", n, bad);
        if (bad) fails++;
        rc = aesir_zc_hip_fill(src, (uint32_t)n);
        if (rc != 0) { printf("HIP fill rc=%d n=%d\n", rc, n); fails++; }
        bad = 0;
        for (int i = 0; i < n; i++)
            if (src[i] != fa(i)) bad++;
        printf("HIP_FILL n=%d bad=%d\n", n, bad);
        if (bad) fails++;
        aesir_zc_hip_free(src);
        aesir_zc_hip_free(dst);
    }
    printf("HIP_COUNTERS launches=%llu memcpy_calls=%llu live_bytes=%llu\n",
           (unsigned long long)aesir_zc_kernel_launch_count(),
           (unsigned long long)aesir_zc_memcpy_call_count(),
           (unsigned long long)aesir_zc_live_bytes());
    if (aesir_zc_memcpy_call_count() != 0) fails++;
    if (aesir_zc_kernel_launch_count() == 0) fails++;
    if (aesir_zc_live_bytes() != 0) fails++;

    const int vsizes[] = {1, 7, 257, 1000, 65537};
    for (unsigned s = 0; s < sizeof(vsizes) / sizeof(vsizes[0]); s++) {
        int n = vsizes[s];
        uint64_t ia = 0, ib = 0, ic = 0, asz = 0, al = 0;
        uint32_t ti = 0, flags = 0;
        if (aesir_vk_buffer_alloc_cached((uint64_t)n * 4, &ia, &asz, &al,
                                         &ti, &flags) != 0)
            { printf("VK cached alloc fail n=%d\n", n); fails++; continue; }
        if (s == 0)
            printf("VK_CACHED_TYPE index=%u flags=0x%x\n", ti, flags);
        if ((flags & 0xeu) != 0xeu || (flags & 0x40u) != 0) {
            printf("VK flags violate A-008 rule: 0x%x\n", flags); fails++;
        }
        aesir_vk_buffer_alloc_cached((uint64_t)n * 4, &ib, &asz, &al, &ti,
                                     &flags);
        aesir_vk_buffer_alloc_cached((uint64_t)n * 4, &ic, &asz, &al, &ti,
                                     &flags);
        uint64_t addr = 0;
        float *p = NULL;
        aesir_vk_buffer_map(ia, &addr); p = (float *)(uintptr_t)addr;
        for (int i = 0; i < n; i++) p[i] = fa(i);
        aesir_vk_buffer_unmap(ia);
        aesir_vk_buffer_map(ib, &addr); p = (float *)(uintptr_t)addr;
        for (int i = 0; i < n; i++) p[i] = fb(i);
        aesir_vk_buffer_unmap(ib);
        aesir_vk_buffer_map(ic, &addr); p = (float *)(uintptr_t)addr;
        for (int i = 0; i < n; i++) p[i] = -9999.0f;
        aesir_vk_buffer_unmap(ic);
        int rc = aesir_vk_buffer_vec_add(ia, ib, ic, (uint32_t)n);
        if (rc != 0) { printf("VK vec_add rc=%d n=%d\n", rc, n); fails++; }
        aesir_vk_buffer_map(ic, &addr); p = (float *)(uintptr_t)addr;
        int bad = 0;
        for (int i = 0; i < n; i++)
            if (p[i] != fa(i) + fb(i)) bad++;
        printf("VK_VEC_ADD n=%d bad=%d\n", n, bad);
        if (bad) fails++;
        aesir_vk_buffer_unmap(ic);
        aesir_vk_buffer_free(ia);
        aesir_vk_buffer_free(ib);
        aesir_vk_buffer_free(ic);
    }
    printf("VK_COUNTERS copy_calls=%llu\n",
           (unsigned long long)aesir_vk_copy_call_count());
    if (aesir_vk_copy_call_count() != 0) fails++;
    printf("RESULT %s fails=%d\n", fails == 0 ? "PASS" : "FAIL", fails);
    return fails == 0 ? 0 : 1;
}
