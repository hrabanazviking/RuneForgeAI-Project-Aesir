/* vulkan_buffer_shim.c - Vulkan buffer C ABI for Project Aesir (slice A-014).
 *
 * Why a shim: the same reason as aesir_engine/hip_memory_shim.c (A-011).
 * Mojo 1.0 cannot mix this repo's external_call dlopen/dlclose idiom with
 * stdlib OwnedDLHandle in one program (conflicting erased dlclose
 * signatures, proven on purpleraider and filed in the A-011 ledger), and
 * Vulkan's struct-heavy API (VkBufferCreateInfo, VkMemoryRequirements,
 * VkPhysicalDeviceProperties, ...) marshals far more safely in C. This
 * shim keeps all Vulkan structure handling and dynamic loading in C,
 * following the repo's established staging pattern (hailo10h_stub.c,
 * thread_par.c, hip_memory_shim.c): scripts compile it to
 * libaesir_vulkan.so and the Mojo side calls the flat aesir_vk_*
 * functions through external_call.
 *
 * Scope: the MINIMAL Vulkan context A-014 needs (A-013, the full Vulkan
 * context wrapper, is team-04's slice and had not landed when A-014 was
 * built; the keeper reconciles the two at banking). The shim creates one
 * process-lifetime context: instance, one physical device, one logical
 * device, one compute-capable queue. Device selection prefers the AMD
 * RADV device (vendor 0x1002, non-CPU type; on purpleraider the Radeon
 * 8060S Graphics, gfx1151) and skips software devices (llvmpipe) unless
 * no hardware device exists.
 *
 * Buffers: every allocation requests HOST_VISIBLE | HOST_COHERENT memory
 * (preferring a DEVICE_LOCAL type among the candidates the buffer's
 * memory-type bits allow - on Strix Halo that is the unified type), so a
 * mapped pointer needs no flush/invalidate calls. If no host-visible
 * coherent type satisfies a buffer's requirements the allocation fails
 * closed with the Vulkan result code; no fallback copy is fabricated.
 *
 * Returns: 0 on success, the (negative) VkResult on Vulkan failure, or
 * AESIR_VK_ABSENT when libvulkan is not loadable / its symbols are
 * missing, or AESIR_VK_INVALID for an unknown buffer id. Nothing is
 * simulated. Single-threaded use; the Mojo gateway is used from test and
 * engine main threads only.
 */

#include <dlfcn.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include "buffer_ownership.h"

/* Vulkan core types (subset; ABI-stable, from vulkan_core.h 1.4). */
typedef int32_t VkResult_t;
typedef uint32_t VkFlags_t;
typedef uint64_t VkDeviceSize_t;
typedef void *VkInstance_t;
typedef void *VkPhysicalDevice_t;
typedef void *VkDevice_t;
typedef void *VkQueue_t;
typedef void *VkBuffer_t;
typedef void *VkDeviceMemory_t;

#define AESIR_VK_ABSENT (-1000000)
#define AESIR_VK_INVALID (-1000001)
#define AESIR_VK_MAX_BUFFERS 128

#define VK_QUEUE_COMPUTE_BIT 0x00000002u
#define VK_QUEUE_GRAPHICS_BIT 0x00000001u
#define VK_BUFFER_USAGE_TRANSFER_SRC_BIT 0x00000001u
#define VK_BUFFER_USAGE_TRANSFER_DST_BIT 0x00000002u
#define VK_BUFFER_USAGE_STORAGE_BUFFER_BIT 0x00000020u
#define VK_SHARING_MODE_EXCLUSIVE 0
#define VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT 0x00000001u
#define VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT 0x00000002u
#define VK_MEMORY_PROPERTY_HOST_COHERENT_BIT 0x00000004u

typedef struct {
    uint32_t sType;
    const void *pNext;
    const char *pApplicationName;
    uint32_t applicationVersion;
    const char *pEngineName;
    uint32_t engineVersion;
    uint32_t apiVersion;
} AesirVkApplicationInfo;

typedef struct {
    uint32_t sType;
    const void *pNext;
    VkFlags_t flags;
    const AesirVkApplicationInfo *pApplicationInfo;
    uint32_t enabledLayerCount;
    const char *const *ppEnabledLayerNames;
    uint32_t enabledExtensionCount;
    const char *const *ppEnabledExtensionNames;
} AesirVkInstanceCreateInfo;

/* The properties mirror below reproduces the vulkan_core.h field order
 * and types exactly for the prefix A-014 reads (identity + limits). The
 * layout was verified on purpleraider against the installed Vulkan 1.4
 * headers (sizeof/offsetof probe filed in the A-014 evidence): the
 * driver fills a real VkPhysicalDeviceProperties, so every receive
 * buffer is an AesirVkPropertiesStorage whose tail absorbs any size
 * difference between the mirror and the real struct. */

typedef struct {
    uint32_t maxImageDimension1D;
    uint32_t maxImageDimension2D;
    uint32_t maxImageDimension3D;
    uint32_t maxImageDimensionCube;
    uint32_t maxImageArrayLayers;
    uint32_t maxTexelBufferElements;
    uint32_t maxUniformBufferRange;
    uint32_t maxStorageBufferRange;
    uint32_t maxPushConstantsSize;
    uint32_t maxMemoryAllocationCount;
    uint32_t maxSamplerAllocationCount;
    VkDeviceSize_t bufferImageGranularity;
    VkDeviceSize_t sparseAddressSpaceSize;
    uint32_t maxBoundDescriptorSets;
    uint32_t maxPerStageDescriptorSamplers;
    uint32_t maxPerStageDescriptorUniformBuffers;
    uint32_t maxPerStageDescriptorStorageBuffers;
    uint32_t maxPerStageDescriptorSampledImages;
    uint32_t maxPerStageDescriptorStorageImages;
    uint32_t maxPerStageDescriptorInputAttachments;
    uint32_t maxPerStageResources;
    uint32_t maxDescriptorSetSamplers;
    uint32_t maxDescriptorSetUniformBuffers;
    uint32_t maxDescriptorSetUniformBuffersDynamic;
    uint32_t maxDescriptorSetStorageBuffers;
    uint32_t maxDescriptorSetStorageBuffersDynamic;
    uint32_t maxDescriptorSetSampledImages;
    uint32_t maxDescriptorSetStorageImages;
    uint32_t maxDescriptorSetInputAttachments;
    uint32_t maxVertexInputAttributes;
    uint32_t maxVertexInputBindings;
    uint32_t maxVertexInputAttributeOffset;
    uint32_t maxVertexInputBindingStride;
    uint32_t maxVertexOutputComponents;
    uint32_t maxTessellationGenerationLevel;
    uint32_t maxTessellationPatchSize;
    uint32_t maxTessellationControlPerVertexInputComponents;
    uint32_t maxTessellationControlPerVertexOutputComponents;
    uint32_t maxTessellationControlPerPatchOutputComponents;
    uint32_t maxTessellationControlTotalOutputComponents;
    uint32_t maxTessellationEvaluationInputComponents;
    uint32_t maxTessellationEvaluationOutputComponents;
    uint32_t maxGeometryShaderInvocations;
    uint32_t maxGeometryInputComponents;
    uint32_t maxGeometryOutputComponents;
    uint32_t maxGeometryOutputVertices;
    uint32_t maxGeometryTotalOutputComponents;
    uint32_t maxFragmentInputComponents;
    uint32_t maxFragmentOutputAttachments;
    uint32_t maxFragmentDualSrcAttachments;
    uint32_t maxFragmentCombinedOutputResources;
    uint32_t maxComputeSharedMemorySize;
    uint32_t maxComputeWorkGroupCount[3];
    uint32_t maxComputeWorkGroupInvocations;
    uint32_t maxComputeWorkGroupSize[3];
    uint32_t subPixelPrecisionBits;
    uint32_t subTexelPrecisionBits;
    uint32_t mipmapPrecisionBits;
    uint32_t maxDrawIndexedIndexValue;
    uint32_t maxDrawIndirectCount;
    float maxSamplerLodBias;
    float maxSamplerAnisotropy;
    uint32_t maxViewports;
    uint32_t maxViewportDimensions[2];
    float viewportBoundsRange[2];
    uint32_t viewportSubPixelBits;
    VkDeviceSize_t minMemoryMapAlignment;
    VkDeviceSize_t minTexelBufferOffsetAlignment;
    VkDeviceSize_t minUniformBufferOffsetAlignment;
    VkDeviceSize_t minStorageBufferOffsetAlignment;
    int32_t minTexelOffset;
    uint32_t maxTexelOffset;
    int32_t minTexelGatherOffset;
    uint32_t maxTexelGatherOffset;
    float minInterpolationOffset;
    float maxInterpolationOffset;
    uint32_t subPixelInterpolationOffsetBits;
    uint32_t maxFramebufferWidth;
    uint32_t maxFramebufferHeight;
    uint32_t maxFramebufferLayers;
    VkFlags_t framebufferColorSampleCounts;
    VkFlags_t framebufferDepthSampleCounts;
    VkFlags_t framebufferStencilSampleCounts;
    VkFlags_t framebufferNoAttachmentsSampleCounts;
    uint32_t maxColorAttachments;
    VkFlags_t sampledImageColorSampleCounts;
    VkFlags_t sampledImageIntegerSampleCounts;
    VkFlags_t sampledImageDepthSampleCounts;
    VkFlags_t sampledImageStencilSampleCounts;
    VkFlags_t storageImageSampleCounts;
    uint32_t maxSampleMaskWords;
    int32_t timestampComputeAndGraphics;
    float timestampPeriod;
    uint32_t maxClipDistances;
    uint32_t maxCullDistances;
    uint32_t maxCombinedClipAndCullDistances;
    uint32_t discreteQueuePriorities;
    float pointSizeRange[2];
    float lineWidthRange[2];
    float pointSizeGranularity;
    float lineWidthGranularity;
    int32_t strictLines;
    int32_t standardSampleLocations;
    VkDeviceSize_t optimalBufferCopyOffsetAlignment;
    VkDeviceSize_t optimalBufferCopyRowPitchAlignment;
    VkDeviceSize_t nonCoherentAtomSize;
} AesirVkLimitsMirror;

typedef struct {
    uint32_t apiVersion;
    uint32_t driverVersion;
    uint32_t vendorID;
    uint32_t deviceID;
    uint32_t deviceType;
    char deviceName[256];
    uint8_t pipelineCacheUUID[16];
    AesirVkLimitsMirror limits;
    /* sparseProperties (5 x VkBool32) follows; not read. */
    uint32_t sparse_pad[5];
} AesirVkPropertiesMirror;

/* Receive storage for driver-filled properties: the mirror prefix plus
 * a tail that absorbs any size difference vs the real struct. */
typedef struct {
    AesirVkPropertiesMirror m;
    uint8_t tail[1024];
} AesirVkPropertiesStorage;

typedef struct {
    VkDeviceSize_t size;
    VkDeviceSize_t alignment;
    uint32_t memoryTypeBits;
} AesirVkMemoryRequirements;

typedef struct {
    VkFlags_t propertyFlags;
    uint32_t heapIndex;
} AesirVkMemoryType;

typedef struct {
    VkDeviceSize_t size;
    VkFlags_t flags;
} AesirVkMemoryHeap;

typedef struct {
    uint32_t memoryTypeCount;
    AesirVkMemoryType memoryTypes[32];
    uint32_t memoryHeapCount;
    AesirVkMemoryHeap memoryHeaps[16];
} AesirVkMemoryProperties;

/* VkQueueFamilyProperties real layout:
 * { VkQueueFlags queueFlags; uint32 queueCount; uint32 timestampValidBits;
 *   VkExtent3D minImageTransferGranularity {u32,u32,u32} } = 24 bytes. */
typedef struct {
    VkFlags_t queueFlags;
    uint32_t queueCount;
    uint32_t timestampValidBits;
    uint32_t granularity[3];
} AesirVkQueueFamilyProperties;

typedef struct {
    uint32_t sType;
    const void *pNext;
    VkFlags_t flags;
    uint32_t queueFamilyIndex;
    uint32_t queueCount;
    const float *pQueuePriorities;
} AesirVkDeviceQueueCreateInfo;

typedef struct {
    uint32_t sType;
    const void *pNext;
    VkFlags_t flags;
    uint32_t queueCreateInfoCount;
    const void *pQueueCreateInfos;
    uint32_t enabledLayerCount;
    const char *const *ppEnabledLayerNames;
    uint32_t enabledExtensionCount;
    const char *const *ppEnabledExtensionNames;
    const void *pEnabledFeatures;
} AesirVkDeviceCreateInfo;

typedef struct {
    uint32_t sType;
    const void *pNext;
    VkFlags_t flags;
    VkDeviceSize_t size;
    VkFlags_t usage;
    uint32_t sharingMode;
    uint32_t queueFamilyIndexCount;
    const uint32_t *pQueueFamilyIndices;
} AesirVkBufferCreateInfo;

typedef struct {
    uint32_t sType;
    const void *pNext;
    VkDeviceSize_t allocationSize;
    uint32_t memoryTypeIndex;
} AesirVkMemoryAllocateInfo;

/* Function pointer types. */
typedef VkResult_t (*vk_create_instance_fn)(const void *, const void *,
                                            VkInstance_t *);
typedef void (*vk_destroy_instance_fn)(VkInstance_t, const void *);
typedef VkResult_t (*vk_enumerate_physical_devices_fn)(VkInstance_t,
                                                       uint32_t *,
                                                       VkPhysicalDevice_t *);
typedef void (*vk_get_physical_device_properties_fn)(
    VkPhysicalDevice_t, AesirVkPropertiesMirror *);
typedef void (*vk_get_physical_device_memory_properties_fn)(
    VkPhysicalDevice_t, AesirVkMemoryProperties *);
typedef void (*vk_get_physical_device_queue_family_properties_fn)(
    VkPhysicalDevice_t, uint32_t *, AesirVkQueueFamilyProperties *);
typedef VkResult_t (*vk_create_device_fn)(VkPhysicalDevice_t, const void *,
                                          const void *, VkDevice_t *);
typedef void (*vk_destroy_device_fn)(VkDevice_t, const void *);
typedef void (*vk_get_device_queue_fn)(VkDevice_t, uint32_t, uint32_t,
                                       VkQueue_t *);
typedef VkResult_t (*vk_create_buffer_fn)(VkDevice_t, const void *,
                                          const void *, VkBuffer_t *);
typedef void (*vk_destroy_buffer_fn)(VkDevice_t, VkBuffer_t, const void *);
typedef void (*vk_get_buffer_memory_requirements_fn)(
    VkDevice_t, VkBuffer_t, AesirVkMemoryRequirements *);
typedef VkResult_t (*vk_allocate_memory_fn)(VkDevice_t, const void *,
                                            const void *, VkDeviceMemory_t *);
typedef void (*vk_free_memory_fn)(VkDevice_t, VkDeviceMemory_t,
                                  const void *);
typedef VkResult_t (*vk_bind_buffer_memory_fn)(VkDevice_t, VkBuffer_t,
                                               VkDeviceMemory_t,
                                               VkDeviceSize_t);
typedef VkResult_t (*vk_map_memory_fn)(VkDevice_t, VkDeviceMemory_t,
                                       VkDeviceSize_t, VkDeviceSize_t,
                                       VkFlags_t, void **);
typedef void (*vk_unmap_memory_fn)(VkDevice_t, VkDeviceMemory_t);

static void *g_lib = NULL;
static int g_lib_tried = 0;
static int g_lib_ok = 0;
static vk_create_instance_fn p_create_instance = NULL;
static vk_destroy_instance_fn p_destroy_instance = NULL;
static vk_enumerate_physical_devices_fn p_enum_devices = NULL;
static vk_get_physical_device_properties_fn p_dev_props = NULL;
static vk_get_physical_device_memory_properties_fn p_mem_props = NULL;
static vk_get_physical_device_queue_family_properties_fn p_qfam_props =
    NULL;
static vk_create_device_fn p_create_device = NULL;
static vk_destroy_device_fn p_destroy_device = NULL;
static vk_get_device_queue_fn p_get_queue = NULL;
static vk_create_buffer_fn p_create_buffer = NULL;
static vk_destroy_buffer_fn p_destroy_buffer = NULL;
static vk_get_buffer_memory_requirements_fn p_buf_reqs = NULL;
static vk_allocate_memory_fn p_alloc_mem = NULL;
static vk_free_memory_fn p_free_mem = NULL;
static vk_bind_buffer_memory_fn p_bind_mem = NULL;
static vk_map_memory_fn p_map_mem = NULL;
static vk_unmap_memory_fn p_unmap_mem = NULL;

static VkInstance_t g_instance = NULL;
static VkPhysicalDevice_t g_physical = NULL;
static VkDevice_t g_device = NULL;
static VkQueue_t g_queue = NULL;
static uint32_t g_queue_family = 0;
static AesirVkPropertiesStorage g_props_store;
#define g_props (g_props_store.m)
static AesirVkMemoryProperties g_memprops;
static int g_ctx_tried = 0;
static int g_ctx_rc = AESIR_VK_ABSENT;

typedef struct {
    int in_use;
    int mapped;
    VkBuffer_t buffer;
    VkDeviceMemory_t memory;
    uint64_t alloc_size;
    uint64_t requested_size;
    uint32_t memory_type_index;
    /* A-022: generation-tagged ids + ownership state. The caller-
     * visible id is (generation << 32) | (slot + 1); generation bumps
     * on every slot reuse and on hand-off, so a stale id can never
     * alias a later buffer in the same slot (the pre-A-022 ABA hole:
     * ids were bare slot indices). */
    uint32_t generation;
    int state;
} AesirVkBufferSlot;

static AesirVkBufferSlot g_slots[AESIR_VK_MAX_BUFFERS];
static uint64_t g_live_bytes = 0;
static int g_live_count = 0;

/* --- A-022 Vulkan buffer ownership (generation-tagged ids) -------- */
static uint64_t g_own_violations = 0;

int aesir_vk_init(void);

static uint64_t vk_encode_id(int slot, uint32_t generation) {
    return ((uint64_t)generation << 32) | (uint64_t)(slot + 1);
}

/* Validate a caller-presented id BEFORE any driver call. Returns 0
 * plus the live slot on success; every refusal is a named code,
 * bumps g_own_violations, and touches nothing. */
static int vk_own_validate(uint64_t id, int for_free,
                           AesirVkBufferSlot **out) {
    if (id == 0) {
        return AESIR_VK_INVALID;
    }
    uint64_t idx = id & 0xffffffffULL;
    uint32_t gen = (uint32_t)(id >> 32);
    if (idx == 0 || idx > AESIR_VK_MAX_BUFFERS) {
        return AESIR_VK_INVALID;
    }
    AesirVkBufferSlot *s = &g_slots[idx - 1];
    if (s->state == AESIR_OWN_STATE_EMPTY) {
        return AESIR_VK_INVALID;
    }
    if (gen > s->generation) {
        return AESIR_VK_INVALID;
    }
    if (s->state == AESIR_OWN_STATE_HANDED_OFF) {
        g_own_violations += 1;
        return AESIR_OWN_USE_AFTER_HANDOFF;
    }
    if (gen < s->generation) {
        g_own_violations += 1;
        return AESIR_OWN_STALE_HANDLE;
    }
    if (s->state == AESIR_OWN_STATE_FREED) {
        g_own_violations += 1;
        return for_free ? AESIR_OWN_DOUBLE_FREE
                        : AESIR_OWN_USE_AFTER_FREE;
    }
    *out = s;
    return 0;
}

uint64_t aesir_vk_ownership_violation_count(void) {
    return g_own_violations;
}

int aesir_vk_buffer_handoff(uint64_t id, uint64_t *out_new_id) {
    int rc = aesir_vk_init();
    if (rc != 0) {
        return rc;
    }
    if (out_new_id == NULL) {
        return AESIR_VK_INVALID;
    }
    AesirVkBufferSlot *s = NULL;
    rc = vk_own_validate(id, 0, &s);
    if (rc != 0) {
        return rc;
    }
    s->state = AESIR_OWN_STATE_HANDED_OFF;
    s->in_use = 0;
    s->generation += 1;
    *out_new_id = vk_encode_id((int)(s - g_slots), s->generation);
    return 0;
}

int aesir_vk_buffer_claim(uint64_t id) {
    int rc = aesir_vk_init();
    if (rc != 0) {
        return rc;
    }
    if (id == 0) {
        return AESIR_VK_INVALID;
    }
    uint64_t idx = id & 0xffffffffULL;
    uint32_t gen = (uint32_t)(id >> 32);
    if (idx == 0 || idx > AESIR_VK_MAX_BUFFERS) {
        return AESIR_VK_INVALID;
    }
    AesirVkBufferSlot *s = &g_slots[idx - 1];
    if (s->state != AESIR_OWN_STATE_HANDED_OFF ||
        gen != s->generation) {
        g_own_violations += 1;
        return AESIR_OWN_USE_AFTER_HANDOFF;
    }
    s->state = AESIR_OWN_STATE_LIVE;
    s->in_use = 1;
    return 0;
}

static void aesir_vk_load(void) {
    if (g_lib_tried) {
        return;
    }
    g_lib_tried = 1;
    const char *names[] = {"libvulkan.so.1", "libvulkan.so", NULL};
    for (int i = 0; names[i] != NULL; i++) {
        g_lib = dlopen(names[i], RTLD_NOW);
        if (g_lib != NULL) {
            break;
        }
    }
    if (g_lib == NULL) {
        return;
    }
    p_create_instance =
        (vk_create_instance_fn)dlsym(g_lib, "vkCreateInstance");
    p_destroy_instance =
        (vk_destroy_instance_fn)dlsym(g_lib, "vkDestroyInstance");
    p_enum_devices = (vk_enumerate_physical_devices_fn)dlsym(
        g_lib, "vkEnumeratePhysicalDevices");
    p_dev_props = (vk_get_physical_device_properties_fn)dlsym(
        g_lib, "vkGetPhysicalDeviceProperties");
    p_mem_props = (vk_get_physical_device_memory_properties_fn)dlsym(
        g_lib, "vkGetPhysicalDeviceMemoryProperties");
    p_qfam_props =
        (vk_get_physical_device_queue_family_properties_fn)dlsym(
            g_lib, "vkGetPhysicalDeviceQueueFamilyProperties");
    p_create_device = (vk_create_device_fn)dlsym(g_lib, "vkCreateDevice");
    p_destroy_device =
        (vk_destroy_device_fn)dlsym(g_lib, "vkDestroyDevice");
    p_get_queue = (vk_get_device_queue_fn)dlsym(g_lib, "vkGetDeviceQueue");
    p_create_buffer = (vk_create_buffer_fn)dlsym(g_lib, "vkCreateBuffer");
    p_destroy_buffer =
        (vk_destroy_buffer_fn)dlsym(g_lib, "vkDestroyBuffer");
    p_buf_reqs = (vk_get_buffer_memory_requirements_fn)dlsym(
        g_lib, "vkGetBufferMemoryRequirements");
    p_alloc_mem = (vk_allocate_memory_fn)dlsym(g_lib, "vkAllocateMemory");
    p_free_mem = (vk_free_memory_fn)dlsym(g_lib, "vkFreeMemory");
    p_bind_mem = (vk_bind_buffer_memory_fn)dlsym(g_lib,
                                                 "vkBindBufferMemory");
    p_map_mem = (vk_map_memory_fn)dlsym(g_lib, "vkMapMemory");
    p_unmap_mem = (vk_unmap_memory_fn)dlsym(g_lib, "vkUnmapMemory");
    g_lib_ok = (p_create_instance && p_destroy_instance && p_enum_devices &&
                p_dev_props && p_mem_props && p_qfam_props &&
                p_create_device && p_destroy_device && p_get_queue &&
                p_create_buffer && p_destroy_buffer && p_buf_reqs &&
                p_alloc_mem && p_free_mem && p_bind_mem && p_map_mem &&
                p_unmap_mem)
                   ? 1
                   : 0;
}

int aesir_vk_buffer_available(void) {
    aesir_vk_load();
    return g_lib_ok ? 1 : 0;
}

static int device_score(const AesirVkPropertiesMirror *p) {
    /* Higher is better. Software/CPU devices score lowest; AMD hardware
     * is preferred on this campaign's machine. */
    int score = 0;
    if (p->deviceType == 4 /* CPU */) {
        score -= 1000;
    }
    if (p->deviceType == 2 /* DISCRETE_GPU */) {
        score += 40;
    }
    if (p->deviceType == 1 /* INTEGRATED_GPU */) {
        score += 30;
    }
    if (p->deviceType == 3 /* VIRTUAL_GPU */) {
        score += 10;
    }
    if (p->vendorID == 0x1002u) {
        score += 100;
    }
    if (strstr(p->deviceName, "RADV") != NULL) {
        score += 50;
    }
    if (strstr(p->deviceName, "llvmpipe") != NULL) {
        score -= 1000;
    }
    return score;
}

int aesir_vk_init(void) {
    aesir_vk_load();
    if (!g_lib_ok) {
        return AESIR_VK_ABSENT;
    }
    if (g_ctx_tried) {
        return g_ctx_rc;
    }
    g_ctx_tried = 1;
    AesirVkApplicationInfo app;
    memset(&app, 0, sizeof(app));
    app.sType = 0; /* VK_STRUCTURE_TYPE_APPLICATION_INFO */
    app.pApplicationName = "aesir-a014";
    app.applicationVersion = 1;
    app.pEngineName = "aesir";
    app.engineVersion = 1;
    app.apiVersion = (1u << 22); /* VK_API_VERSION_1_0 */
    AesirVkInstanceCreateInfo ici;
    memset(&ici, 0, sizeof(ici));
    ici.sType = 1; /* VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO */
    ici.pApplicationInfo = &app;
    VkResult_t rc = p_create_instance(&ici, NULL, &g_instance);
    if (rc != 0) {
        g_ctx_rc = (int)rc;
        return g_ctx_rc;
    }
    uint32_t count = 0;
    rc = p_enum_devices(g_instance, &count, NULL);
    if (rc != 0 || count == 0) {
        g_ctx_rc = (rc != 0) ? (int)rc : -3;
        return g_ctx_rc;
    }
    if (count > 16) {
        count = 16;
    }
    VkPhysicalDevice_t devs[16];
    rc = p_enum_devices(g_instance, &count, devs);
    if (rc != 0) {
        g_ctx_rc = (int)rc;
        return g_ctx_rc;
    }
    int best = -1;
    int best_score = -2000000;
    AesirVkPropertiesStorage best_props;
    memset(&best_props, 0, sizeof(best_props));
    for (uint32_t i = 0; i < count; i++) {
        AesirVkPropertiesStorage p;
        memset(&p, 0, sizeof(p));
        p_dev_props(devs[i], &p.m);
        int s = device_score(&p.m);
        if (s > best_score) {
            best_score = s;
            best = (int)i;
            best_props = p;
        }
    }
    if (best < 0) {
        g_ctx_rc = -3;
        return g_ctx_rc;
    }
    g_physical = devs[best];
    g_props_store = best_props;
    p_mem_props(g_physical, &g_memprops);
    /* Queue family: first with COMPUTE, else first with GRAPHICS. */
    uint32_t qcount = 0;
    p_qfam_props(g_physical, &qcount, NULL);
    if (qcount == 0 || qcount > 64) {
        g_ctx_rc = -3;
        return g_ctx_rc;
    }
    AesirVkQueueFamilyProperties qf[64];
    memset(qf, 0, sizeof(qf));
    p_qfam_props(g_physical, &qcount, qf);
    int qsel = -1;
    int gsel = -1;
    for (uint32_t i = 0; i < qcount; i++) {
        if (qsel < 0 && (qf[i].queueFlags & VK_QUEUE_COMPUTE_BIT)) {
            qsel = (int)i;
        }
        if (gsel < 0 && (qf[i].queueFlags & VK_QUEUE_GRAPHICS_BIT)) {
            gsel = (int)i;
        }
    }
    if (qsel < 0) {
        qsel = gsel;
    }
    if (qsel < 0) {
        g_ctx_rc = -3;
        return g_ctx_rc;
    }
    g_queue_family = (uint32_t)qsel;
    float prio = 1.0f;
    AesirVkDeviceQueueCreateInfo qci;
    memset(&qci, 0, sizeof(qci));
    qci.sType = 2; /* VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO */
    qci.queueFamilyIndex = g_queue_family;
    qci.queueCount = 1;
    qci.pQueuePriorities = &prio;
    AesirVkDeviceCreateInfo dci;
    memset(&dci, 0, sizeof(dci));
    dci.sType = 3; /* VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO */
    dci.queueCreateInfoCount = 1;
    dci.pQueueCreateInfos = &qci;
    rc = p_create_device(g_physical, &dci, NULL, &g_device);
    if (rc != 0) {
        g_ctx_rc = (int)rc;
        return g_ctx_rc;
    }
    p_get_queue(g_device, g_queue_family, 0, &g_queue);
    g_ctx_rc = 0;
    return 0;
}

/* Fills name_out (cap bytes, NUL-terminated, truncated if needed) and
 * the scalar identity fields. Returns 0 / VkResult / ABSENT. */
int aesir_vk_buffer_device_info(char *name_out, int cap, uint32_t *vendor,
                         uint32_t *device_id, uint32_t *api_version,
                         uint32_t *device_type, uint32_t *queue_family) {
    int rc = aesir_vk_init();
    if (rc != 0) {
        return rc;
    }
    if (name_out != NULL && cap > 0) {
        strncpy(name_out, g_props.deviceName, (size_t)cap - 1);
        name_out[cap - 1] = '\0';
    }
    if (vendor) {
        *vendor = g_props.vendorID;
    }
    if (device_id) {
        *device_id = g_props.deviceID;
    }
    if (api_version) {
        *api_version = g_props.apiVersion;
    }
    if (device_type) {
        *device_type = g_props.deviceType;
    }
    if (queue_family) {
        *queue_family = g_queue_family;
    }
    return 0;
}

/* Indexed device limits (all widened to uint64). Index map:
 *  0 minMemoryMapAlignment        1 minStorageBufferOffsetAlignment
 *  2 minUniformBufferOffsetAlignment
 *  3 minTexelBufferOffsetAlignment
 *  4 nonCoherentAtomSize          5 bufferImageGranularity
 *  6 optimalBufferCopyOffsetAlignment
 *  7 maxMemoryAllocationCount     8 maxStorageBufferRange
 *  9 maxPushConstantsSize        10 preferred host-coherent memory
 *    type index (or -1 in int64 terms, stored as uint64 wrap; callers
 *    read it as Int and treat <0 as none - see buffer_alloc which
 *    fails closed before this matters)
 * 11 preferred heap index        12 preferred heap size bytes
 * 13 preferred memory type property flags
 * 14 memory type count           15 memory heap count            */
static int find_host_coherent_type(uint32_t type_bits, uint32_t *out_index,
                                   int prefer_device_local) {
    int fallback = -1;
    for (uint32_t i = 0; i < g_memprops.memoryTypeCount && i < 32; i++) {
        if ((type_bits & (1u << i)) == 0) {
            continue;
        }
        uint32_t f = g_memprops.memoryTypes[i].propertyFlags;
        int visible = (f & VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT) != 0;
        int coherent = (f & VK_MEMORY_PROPERTY_HOST_COHERENT_BIT) != 0;
        if (!visible || !coherent) {
            continue;
        }
        int local = (f & VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT) != 0;
        if (prefer_device_local && local) {
            *out_index = i;
            return 0;
        }
        if (fallback < 0) {
            fallback = (int)i;
        }
        if (!prefer_device_local) {
            *out_index = i;
            return 0;
        }
    }
    if (fallback >= 0) {
        *out_index = (uint32_t)fallback;
        return 0;
    }
    return -1;
}

int aesir_vk_limits(uint64_t *out, int cap) {
    int rc = aesir_vk_init();
    if (rc != 0) {
        return rc;
    }
    if (out == NULL || cap < 16) {
        return AESIR_VK_INVALID;
    }
    const AesirVkLimitsMirror *L = &g_props.limits;
    out[0] = (uint64_t)L->minMemoryMapAlignment;
    out[1] = (uint64_t)L->minStorageBufferOffsetAlignment;
    out[2] = (uint64_t)L->minUniformBufferOffsetAlignment;
    out[3] = (uint64_t)L->minTexelBufferOffsetAlignment;
    out[4] = (uint64_t)L->nonCoherentAtomSize;
    out[5] = (uint64_t)L->bufferImageGranularity;
    out[6] = (uint64_t)L->optimalBufferCopyOffsetAlignment;
    out[7] = (uint64_t)L->maxMemoryAllocationCount;
    out[8] = (uint64_t)L->maxStorageBufferRange;
    out[9] = (uint64_t)L->maxPushConstantsSize;
    uint32_t tindex = 0;
    if (find_host_coherent_type(0xFFFFFFFFu, &tindex, 1) == 0) {
        out[10] = (uint64_t)tindex;
        uint32_t heap = g_memprops.memoryTypes[tindex].heapIndex;
        out[11] = (uint64_t)heap;
        out[12] = (uint64_t)g_memprops.memoryHeaps[heap].size;
        out[13] = (uint64_t)g_memprops.memoryTypes[tindex].propertyFlags;
    } else {
        out[10] = (uint64_t)(int64_t)-1;
        out[11] = 0;
        out[12] = 0;
        out[13] = 0;
    }
    out[14] = (uint64_t)g_memprops.memoryTypeCount;
    out[15] = (uint64_t)g_memprops.memoryHeapCount;
    return 0;
}

static int make_buffer(uint64_t size, VkBuffer_t *out_buffer,
                       AesirVkMemoryRequirements *out_reqs) {
    AesirVkBufferCreateInfo bci;
    memset(&bci, 0, sizeof(bci));
    bci.sType = 12; /* VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO */
    bci.size = size;
    bci.usage = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT |
                VK_BUFFER_USAGE_TRANSFER_SRC_BIT |
                VK_BUFFER_USAGE_TRANSFER_DST_BIT;
    bci.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
    VkResult_t rc = p_create_buffer(g_device, &bci, NULL, out_buffer);
    if (rc != 0) {
        return (int)rc;
    }
    p_buf_reqs(g_device, *out_buffer, out_reqs);
    return 0;
}

int aesir_vk_buffer_requirements(uint64_t size, uint64_t *out_size,
                                 uint64_t *out_alignment,
                                 uint32_t *out_type_bits) {
    int rc = aesir_vk_init();
    if (rc != 0) {
        return rc;
    }
    if (size == 0) {
        return AESIR_VK_INVALID;
    }
    VkBuffer_t buf = NULL;
    AesirVkMemoryRequirements reqs;
    memset(&reqs, 0, sizeof(reqs));
    rc = make_buffer(size, &buf, &reqs);
    if (rc != 0) {
        return rc;
    }
    if (out_size) {
        *out_size = (uint64_t)reqs.size;
    }
    if (out_alignment) {
        *out_alignment = (uint64_t)reqs.alignment;
    }
    if (out_type_bits) {
        *out_type_bits = reqs.memoryTypeBits;
    }
    p_destroy_buffer(g_device, buf, NULL);
    return 0;
}

/* A-019: find a HOST_CACHED host-coherent memory type for the
 * buffer's type bits. Per the A-008 zero-copy rule this is the ONLY
 * Vulkan flavour the unified allocator may hand the CPU: the
 * DEVICE_LOCAL coherent type carrying DEVICE_UNCACHED_AMD (0x40)
 * reads back on the CPU at 0.11 GB/s and is refused outright.
 * Prefers a non-DEVICE_LOCAL cached type (the A-008 flags 0xe
 * flavour); falls back to any cached coherent type without the
 * uncached bit. Returns -1 when none qualifies (fail closed). */
static int find_host_cached_coherent_type(uint32_t type_bits,
                                          uint32_t *out_index) {
    int fallback = -1;
    for (uint32_t i = 0; i < g_memprops.memoryTypeCount && i < 32; i++) {
        if ((type_bits & (1u << i)) == 0) {
            continue;
        }
        uint32_t f = g_memprops.memoryTypes[i].propertyFlags;
        int visible = (f & VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT) != 0;
        int coherent = (f & VK_MEMORY_PROPERTY_HOST_COHERENT_BIT) != 0;
        int cached = (f & 0x00000008u) != 0; /* HOST_CACHED */
        int uncached_amd = (f & 0x00000040u) != 0; /* DEVICE_UNCACHED_AMD */
        if (!visible || !coherent || !cached || uncached_amd) {
            continue;
        }
        int local = (f & VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT) != 0;
        if (!local) {
            *out_index = i;
            return 0;
        }
        if (fallback < 0) {
            fallback = (int)i;
        }
    }
    if (fallback >= 0) {
        *out_index = (uint32_t)fallback;
        return 0;
    }
    return -1;
}

static int buffer_alloc_impl(uint64_t size, int cached_only,
                             uint64_t *out_id, uint64_t *out_alloc_size,
                             uint64_t *out_alignment,
                             uint32_t *out_type_index,
                             uint32_t *out_type_flags) {
    int rc = aesir_vk_init();
    if (rc != 0) {
        return rc;
    }
    if (size == 0) {
        return AESIR_VK_INVALID;
    }
    int slot = -1;
    for (int i = 0; i < AESIR_VK_MAX_BUFFERS; i++) {
        /* A-022: live and handed-off slots are owned; only empty or
         * tombstoned (freed) slots may be recycled. */
        if (g_slots[i].state == AESIR_OWN_STATE_EMPTY ||
            g_slots[i].state == AESIR_OWN_STATE_FREED) {
            slot = i;
            break;
        }
    }
    if (slot < 0) {
        return AESIR_VK_INVALID;
    }
    VkBuffer_t buf = NULL;
    AesirVkMemoryRequirements reqs;
    memset(&reqs, 0, sizeof(reqs));
    rc = make_buffer(size, &buf, &reqs);
    if (rc != 0) {
        return rc;
    }
    uint32_t tindex = 0;
    int found = cached_only
                    ? find_host_cached_coherent_type(reqs.memoryTypeBits,
                                                     &tindex)
                    : find_host_coherent_type(reqs.memoryTypeBits, &tindex,
                                              1);
    if (found != 0) {
        p_destroy_buffer(g_device, buf, NULL);
        /* No qualifying host-coherent type for this buffer: fail
         * closed. (VK_ERROR_FEATURE_NOT_PRESENT = -8 is the closest
         * VkResult; the Mojo side reports the message text.) */
        return -8;
    }
    AesirVkMemoryAllocateInfo mai;
    memset(&mai, 0, sizeof(mai));
    mai.sType = 5; /* VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO */
    mai.allocationSize = reqs.size;
    mai.memoryTypeIndex = tindex;
    VkDeviceMemory_t mem = NULL;
    rc = (int)p_alloc_mem(g_device, &mai, NULL, &mem);
    if (rc != 0) {
        p_destroy_buffer(g_device, buf, NULL);
        return rc;
    }
    rc = (int)p_bind_mem(g_device, buf, mem, 0);
    if (rc != 0) {
        p_free_mem(g_device, mem, NULL);
        p_destroy_buffer(g_device, buf, NULL);
        return rc;
    }
    g_slots[slot].in_use = 1;
    g_slots[slot].mapped = 0;
    g_slots[slot].buffer = buf;
    g_slots[slot].memory = mem;
    g_slots[slot].alloc_size = (uint64_t)reqs.size;
    g_slots[slot].requested_size = size;
    g_slots[slot].memory_type_index = tindex;
    g_slots[slot].generation += 1;
    g_slots[slot].state = AESIR_OWN_STATE_LIVE;
    g_live_bytes += (uint64_t)reqs.size;
    g_live_count += 1;
    if (out_id) {
        *out_id = vk_encode_id(slot, g_slots[slot].generation);
    }
    if (out_alloc_size) {
        *out_alloc_size = (uint64_t)reqs.size;
    }
    if (out_alignment) {
        *out_alignment = (uint64_t)reqs.alignment;
    }
    if (out_type_index) {
        *out_type_index = tindex;
    }
    if (out_type_flags) {
        *out_type_flags = g_memprops.memoryTypes[tindex].propertyFlags;
    }
    return 0;
}

int aesir_vk_buffer_alloc(uint64_t size, uint64_t *out_id,
                          uint64_t *out_alloc_size,
                          uint64_t *out_alignment,
                          uint32_t *out_type_index) {
    return buffer_alloc_impl(size, 0, out_id, out_alloc_size,
                             out_alignment, out_type_index, NULL);
}

/* A-019: allocate on a HOST_CACHED host-coherent memory type only
 * (the A-008 zero-copy rule); also reports the chosen type's
 * property flags so callers can assert the rule from evidence. */
int aesir_vk_buffer_alloc_cached(uint64_t size, uint64_t *out_id,
                                 uint64_t *out_alloc_size,
                                 uint64_t *out_alignment,
                                 uint32_t *out_type_index,
                                 uint32_t *out_type_flags) {
    return buffer_alloc_impl(size, 1, out_id, out_alloc_size,
                             out_alignment, out_type_index,
                             out_type_flags);
}

static AesirVkBufferSlot *slot_for(uint64_t id) {
    AesirVkBufferSlot *s = NULL;
    if (vk_own_validate(id, 0, &s) != 0) {
        return NULL;
    }
    return s;
}

int aesir_vk_buffer_map(uint64_t id, uint64_t *out_addr) {
    int rc = aesir_vk_init();
    if (rc != 0) {
        return rc;
    }
    AesirVkBufferSlot *s = NULL;
    int vrc = vk_own_validate(id, 0, &s);
    if (vrc != 0) {
        return vrc;
    }
    if (s->mapped) {
        return AESIR_VK_INVALID;
    }
    void *ptr = NULL;
    rc = (int)p_map_mem(g_device, s->memory, 0, s->alloc_size, 0, &ptr);
    if (rc != 0) {
        return rc;
    }
    if (ptr == NULL) {
        return -3;
    }
    s->mapped = 1;
    if (out_addr) {
        *out_addr = (uint64_t)(uintptr_t)ptr;
    }
    return 0;
}

int aesir_vk_buffer_unmap(uint64_t id) {
    int rc = aesir_vk_init();
    if (rc != 0) {
        return rc;
    }
    AesirVkBufferSlot *s = NULL;
    int vrc = vk_own_validate(id, 0, &s);
    if (vrc != 0) {
        return vrc;
    }
    if (!s->mapped) {
        return AESIR_VK_INVALID;
    }
    p_unmap_mem(g_device, s->memory);
    s->mapped = 0;
    return 0;
}

int aesir_vk_buffer_free(uint64_t id) {
    int rc = aesir_vk_init();
    if (rc != 0) {
        return rc;
    }
    AesirVkBufferSlot *s = NULL;
    rc = vk_own_validate(id, 1, &s);
    if (rc != 0) {
        return rc;
    }
    if (s->mapped) {
        p_unmap_mem(g_device, s->memory);
        s->mapped = 0;
    }
    p_destroy_buffer(g_device, s->buffer, NULL);
    p_free_mem(g_device, s->memory, NULL);
    g_live_bytes -= s->alloc_size;
    g_live_count -= 1;
    /* A-022 tombstone: keep generation + state so the second free
     * is a detectable MEM-005 instead of a silent double destroy
     * (the pre-A-022 memset erased exactly this evidence). */
    s->buffer = NULL;
    s->memory = NULL;
    s->alloc_size = 0;
    s->requested_size = 0;
    s->in_use = 0;
    s->state = AESIR_OWN_STATE_FREED;
    return 0;
}

uint64_t aesir_vk_live_bytes(void) {
    return g_live_bytes;
}

int aesir_vk_live_count(void) {
    return g_live_count;
}

/* ---- A-015: Vulkan compute dispatch smoke (vector add) ----
 *
 * One trivial SPIR-V kernel (aesir_engine/shaders/vec_add.comp,
 * c[i] = a[i] + b[i], local_size_x 256, element count passed as a
 * push constant so non-multiple sizes are exact) dispatched on the
 * A-014 context above: same instance, physical device, logical
 * device and compute queue, operating directly on A-014 buffer
 * slots (which are created with STORAGE_BUFFER usage). No second
 * context is created. The SPIR-V words are the verbatim
 * glslangValidator output for vec_add.comp (SPIR-V 1.0, 1608 bytes,
 * sha256 b228710b1f464b3aa810a4d4cb73e67f2325fdf1eabaa2ceb6b2cf73309ce15b),
 * since A-055 generated at build time by scripts/build_shaders.py
 * and included from shaders/generated/aesir_shaders_spv.h (hashes
 * recorded in shaders/SHADER_MANIFEST.json).
 * Pipeline objects are created per dispatch and destroyed before
 * return - this is a smoke path, not a cached-pipeline engine path.
 * Returns 0 on success (after vkQueueWaitIdle, so mapped reads of
 * the output buffer observe the completed dispatch), the negative
 * VkResult on Vulkan failure, AESIR_VK_ABSENT when a dispatch entry
 * point is missing, AESIR_VK_INVALID for bad ids / sizes. */

typedef void *VkShaderModule_t;
typedef void *VkDescriptorSetLayout_t;
typedef void *VkPipelineLayout_t;
typedef void *VkPipeline_t;
typedef void *VkDescriptorPool_t;
typedef void *VkDescriptorSet_t;
typedef void *VkCommandPool_t;
typedef void *VkCommandBuffer_t;

typedef struct { uint32_t sType; const void *pNext; VkFlags_t flags; size_t codeSize; const uint32_t *pCode; } AesirVkShaderModuleCreateInfo;
typedef struct { uint32_t binding; uint32_t descriptorType; uint32_t descriptorCount; uint32_t stageFlags; const void *pImmutableSamplers; } AesirVkDescriptorSetLayoutBinding;
typedef struct { uint32_t sType; const void *pNext; VkFlags_t flags; uint32_t bindingCount; const AesirVkDescriptorSetLayoutBinding *pBindings; } AesirVkDescriptorSetLayoutCreateInfo;
typedef struct { uint32_t stageFlags; uint32_t offset; uint32_t size; } AesirVkPushConstantRange;
typedef struct { uint32_t sType; const void *pNext; VkFlags_t flags; uint32_t setLayoutCount; const VkDescriptorSetLayout_t *pSetLayouts; uint32_t pushConstantRangeCount; const AesirVkPushConstantRange *pPushConstantRanges; } AesirVkPipelineLayoutCreateInfo;
typedef struct { uint32_t type; uint32_t descriptorCount; } AesirVkDescriptorPoolSize;
typedef struct { uint32_t sType; const void *pNext; VkFlags_t flags; uint32_t maxSets; uint32_t poolSizeCount; const AesirVkDescriptorPoolSize *pPoolSizes; } AesirVkDescriptorPoolCreateInfo;
typedef struct { uint32_t sType; const void *pNext; VkDescriptorPool_t descriptorPool; uint32_t descriptorSetCount; const VkDescriptorSetLayout_t *pSetLayouts; } AesirVkDescriptorSetAllocateInfo;
typedef struct { VkBuffer_t buffer; uint64_t offset; uint64_t range; } AesirVkDescriptorBufferInfo;
typedef struct { uint32_t sType; const void *pNext; VkDescriptorSet_t dstSet; uint32_t dstBinding; uint32_t dstArrayElement; uint32_t descriptorCount; uint32_t descriptorType; const void *pImageInfo; const AesirVkDescriptorBufferInfo *pBufferInfo; const void *pTexelBufferView; } AesirVkWriteDescriptorSet;
typedef struct { uint32_t sType; const void *pNext; VkFlags_t flags; uint32_t stage; VkShaderModule_t module; const char *pName; const void *pSpecializationInfo; } AesirVkPipelineShaderStageCreateInfo;
typedef struct { uint32_t sType; const void *pNext; VkFlags_t flags; AesirVkPipelineShaderStageCreateInfo stage; VkPipelineLayout_t layout; VkPipeline_t basePipelineHandle; int32_t basePipelineIndex; } AesirVkComputePipelineCreateInfo;
typedef struct { uint32_t sType; const void *pNext; VkFlags_t flags; uint32_t queueFamilyIndex; } AesirVkCommandPoolCreateInfo;
typedef struct { uint32_t sType; const void *pNext; VkCommandPool_t commandPool; uint32_t level; uint32_t commandBufferCount; } AesirVkCommandBufferAllocateInfo;
typedef struct { uint32_t sType; const void *pNext; VkFlags_t flags; const void *pInheritanceInfo; } AesirVkCommandBufferBeginInfo;
typedef struct { uint32_t sType; const void *pNext; uint32_t waitSemaphoreCount; const void *pWaitSemaphores; const uint32_t *pWaitDstStageMask; uint32_t commandBufferCount; const VkCommandBuffer_t *pCommandBuffers; uint32_t signalSemaphoreCount; const void *pSignalSemaphores; } AesirVkSubmitInfo;

typedef VkResult_t (*vk_create_shader_module_fn)(VkDevice_t, const AesirVkShaderModuleCreateInfo *, const void *, VkShaderModule_t *);
typedef void (*vk_destroy_shader_module_fn)(VkDevice_t, VkShaderModule_t, const void *);
typedef VkResult_t (*vk_create_descriptor_set_layout_fn)(VkDevice_t, const AesirVkDescriptorSetLayoutCreateInfo *, const void *, VkDescriptorSetLayout_t *);
typedef void (*vk_destroy_descriptor_set_layout_fn)(VkDevice_t, VkDescriptorSetLayout_t, const void *);
typedef VkResult_t (*vk_create_pipeline_layout_fn)(VkDevice_t, const AesirVkPipelineLayoutCreateInfo *, const void *, VkPipelineLayout_t *);
typedef void (*vk_destroy_pipeline_layout_fn)(VkDevice_t, VkPipelineLayout_t, const void *);
typedef VkResult_t (*vk_create_compute_pipelines_fn)(VkDevice_t, void *, uint32_t, const AesirVkComputePipelineCreateInfo *, const void *, VkPipeline_t *);
typedef void (*vk_destroy_pipeline_fn)(VkDevice_t, VkPipeline_t, const void *);
typedef VkResult_t (*vk_create_descriptor_pool_fn)(VkDevice_t, const AesirVkDescriptorPoolCreateInfo *, const void *, VkDescriptorPool_t *);
typedef void (*vk_destroy_descriptor_pool_fn)(VkDevice_t, VkDescriptorPool_t, const void *);
typedef VkResult_t (*vk_allocate_descriptor_sets_fn)(VkDevice_t, const AesirVkDescriptorSetAllocateInfo *, VkDescriptorSet_t *);
typedef void (*vk_update_descriptor_sets_fn)(VkDevice_t, uint32_t, const AesirVkWriteDescriptorSet *, uint32_t, const void *);
typedef VkResult_t (*vk_create_command_pool_fn)(VkDevice_t, const AesirVkCommandPoolCreateInfo *, const void *, VkCommandPool_t *);
typedef void (*vk_destroy_command_pool_fn)(VkDevice_t, VkCommandPool_t, const void *);
typedef VkResult_t (*vk_allocate_command_buffers_fn)(VkDevice_t, const AesirVkCommandBufferAllocateInfo *, VkCommandBuffer_t *);
typedef VkResult_t (*vk_begin_command_buffer_fn)(VkCommandBuffer_t, const AesirVkCommandBufferBeginInfo *);
typedef VkResult_t (*vk_end_command_buffer_fn)(VkCommandBuffer_t);
typedef void (*vk_cmd_bind_pipeline_fn)(VkCommandBuffer_t, uint32_t, VkPipeline_t);
typedef void (*vk_cmd_bind_descriptor_sets_fn)(VkCommandBuffer_t, uint32_t, VkPipelineLayout_t, uint32_t, uint32_t, const VkDescriptorSet_t *, uint32_t, const uint32_t *);
typedef void (*vk_cmd_push_constants_fn)(VkCommandBuffer_t, VkPipelineLayout_t, uint32_t, uint32_t, uint32_t, const void *);
typedef void (*vk_cmd_dispatch_fn)(VkCommandBuffer_t, uint32_t, uint32_t, uint32_t);
typedef VkResult_t (*vk_queue_submit_fn)(VkQueue_t, uint32_t, const AesirVkSubmitInfo *, void *);
typedef VkResult_t (*vk_queue_wait_idle_fn)(VkQueue_t);

static vk_create_shader_module_fn d_create_shader_module = NULL;
static vk_destroy_shader_module_fn d_destroy_shader_module = NULL;
static vk_create_descriptor_set_layout_fn d_create_dsl = NULL;
static vk_destroy_descriptor_set_layout_fn d_destroy_dsl = NULL;
static vk_create_pipeline_layout_fn d_create_pl = NULL;
static vk_destroy_pipeline_layout_fn d_destroy_pl = NULL;
static vk_create_compute_pipelines_fn d_create_cp = NULL;
static vk_destroy_pipeline_fn d_destroy_pipeline = NULL;
static vk_create_descriptor_pool_fn d_create_dpool = NULL;
static vk_destroy_descriptor_pool_fn d_destroy_dpool = NULL;
static vk_allocate_descriptor_sets_fn d_alloc_dsets = NULL;
static vk_update_descriptor_sets_fn d_update_dsets = NULL;
static vk_create_command_pool_fn d_create_cpool = NULL;
static vk_destroy_command_pool_fn d_destroy_cpool = NULL;
static vk_allocate_command_buffers_fn d_alloc_cbufs = NULL;
static vk_begin_command_buffer_fn d_begin_cbuf = NULL;
static vk_end_command_buffer_fn d_end_cbuf = NULL;
static vk_cmd_bind_pipeline_fn d_cmd_bind_pipeline = NULL;
static vk_cmd_bind_descriptor_sets_fn d_cmd_bind_dsets = NULL;
static vk_cmd_push_constants_fn d_cmd_push = NULL;
static vk_cmd_dispatch_fn d_cmd_dispatch = NULL;
static vk_queue_submit_fn d_queue_submit = NULL;
static vk_queue_wait_idle_fn d_queue_wait_idle = NULL;
static int g_dispatch_tried = 0;
static int g_dispatch_ok = 0;

static void aesir_vk_load_dispatch(void) {
    if (g_dispatch_tried) { return; }
    g_dispatch_tried = 1;
    aesir_vk_load();
    if (g_lib == NULL) { return; }
    d_create_shader_module = (vk_create_shader_module_fn)dlsym(g_lib, "vkCreateShaderModule");
    d_destroy_shader_module = (vk_destroy_shader_module_fn)dlsym(g_lib, "vkDestroyShaderModule");
    d_create_dsl = (vk_create_descriptor_set_layout_fn)dlsym(g_lib, "vkCreateDescriptorSetLayout");
    d_destroy_dsl = (vk_destroy_descriptor_set_layout_fn)dlsym(g_lib, "vkDestroyDescriptorSetLayout");
    d_create_pl = (vk_create_pipeline_layout_fn)dlsym(g_lib, "vkCreatePipelineLayout");
    d_destroy_pl = (vk_destroy_pipeline_layout_fn)dlsym(g_lib, "vkDestroyPipelineLayout");
    d_create_cp = (vk_create_compute_pipelines_fn)dlsym(g_lib, "vkCreateComputePipelines");
    d_destroy_pipeline = (vk_destroy_pipeline_fn)dlsym(g_lib, "vkDestroyPipeline");
    d_create_dpool = (vk_create_descriptor_pool_fn)dlsym(g_lib, "vkCreateDescriptorPool");
    d_destroy_dpool = (vk_destroy_descriptor_pool_fn)dlsym(g_lib, "vkDestroyDescriptorPool");
    d_alloc_dsets = (vk_allocate_descriptor_sets_fn)dlsym(g_lib, "vkAllocateDescriptorSets");
    d_update_dsets = (vk_update_descriptor_sets_fn)dlsym(g_lib, "vkUpdateDescriptorSets");
    d_create_cpool = (vk_create_command_pool_fn)dlsym(g_lib, "vkCreateCommandPool");
    d_destroy_cpool = (vk_destroy_command_pool_fn)dlsym(g_lib, "vkDestroyCommandPool");
    d_alloc_cbufs = (vk_allocate_command_buffers_fn)dlsym(g_lib, "vkAllocateCommandBuffers");
    d_begin_cbuf = (vk_begin_command_buffer_fn)dlsym(g_lib, "vkBeginCommandBuffer");
    d_end_cbuf = (vk_end_command_buffer_fn)dlsym(g_lib, "vkEndCommandBuffer");
    d_cmd_bind_pipeline = (vk_cmd_bind_pipeline_fn)dlsym(g_lib, "vkCmdBindPipeline");
    d_cmd_bind_dsets = (vk_cmd_bind_descriptor_sets_fn)dlsym(g_lib, "vkCmdBindDescriptorSets");
    d_cmd_push = (vk_cmd_push_constants_fn)dlsym(g_lib, "vkCmdPushConstants");
    d_cmd_dispatch = (vk_cmd_dispatch_fn)dlsym(g_lib, "vkCmdDispatch");
    d_queue_submit = (vk_queue_submit_fn)dlsym(g_lib, "vkQueueSubmit");
    d_queue_wait_idle = (vk_queue_wait_idle_fn)dlsym(g_lib, "vkQueueWaitIdle");
    g_dispatch_ok = (d_create_shader_module && d_destroy_shader_module && d_create_dsl && d_destroy_dsl && d_create_pl && d_destroy_pl && d_create_cp && d_destroy_pipeline && d_create_dpool && d_destroy_dpool && d_alloc_dsets && d_update_dsets && d_create_cpool && d_destroy_cpool && d_alloc_cbufs && d_begin_cbuf && d_end_cbuf && d_cmd_bind_pipeline && d_cmd_bind_dsets && d_cmd_push && d_cmd_dispatch && d_queue_submit && d_queue_wait_idle) ? 1 : 0;
}

int aesir_vk_dispatch_available(void) {
    aesir_vk_load_dispatch();
    return g_dispatch_ok ? 1 : 0;
}
/* A-055: the SPIR-V words are no longer hand-pasted here. They are
 * generated at build time by scripts/build_shaders.py from
 * aesir_engine/shaders/vec_add.comp and embedded via the versioned
 * generated header below (kVecAddSpv / kVecAddSpvBytes, sha256
 * recorded in aesir_engine/shaders/SHADER_MANIFEST.json). The
 * generated vec_add module is byte-identical to the A-015
 * hand-embedded array it replaces (sha256 b228710b...). */
#include "shaders/generated/aesir_shaders_spv.h"

int aesir_vk_buffer_vec_add(uint64_t id_a, uint64_t id_b, uint64_t id_c, uint32_t n) {
    int rc = aesir_vk_init();
    if (rc != 0) { return rc; }
    aesir_vk_load_dispatch();
    if (!g_dispatch_ok) { return AESIR_VK_ABSENT; }
    AesirVkBufferSlot *sa = NULL;
    AesirVkBufferSlot *sb = NULL;
    AesirVkBufferSlot *sc = NULL;
    int vrc = vk_own_validate(id_a, 0, &sa);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_b, 0, &sb);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_c, 0, &sc);
    if (vrc != 0) { return vrc; }
    if (n == 0) { return AESIR_VK_INVALID; }
    uint64_t need = (uint64_t)n * 4u;
    if (sa->requested_size < need || sb->requested_size < need || sc->requested_size < need) { return AESIR_VK_INVALID; }
    VkShaderModule_t shader = NULL;
    VkDescriptorSetLayout_t dsl = NULL;
    VkPipelineLayout_t pl = NULL;
    VkPipeline_t pipe = NULL;
    VkDescriptorPool_t dpool = NULL;
    VkDescriptorSet_t dset = NULL;
    VkCommandPool_t cpool = NULL;
    VkCommandBuffer_t cbuf = NULL;
    int out_rc = 0;
    AesirVkShaderModuleCreateInfo smci; memset(&smci, 0, sizeof(smci));
    smci.sType = 16; /* VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO */ smci.codeSize = kVecAddSpvBytes; smci.pCode = kVecAddSpv;
    rc = (int)d_create_shader_module(g_device, &smci, NULL, &shader);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetLayoutBinding binds[3]; memset(binds, 0, sizeof(binds));
    for (int i = 0; i < 3; i++) { binds[i].binding = (uint32_t)i; binds[i].descriptorType = 6; binds[i].descriptorCount = 1; binds[i].stageFlags = 0x20u; }
    AesirVkDescriptorSetLayoutCreateInfo dslci; memset(&dslci, 0, sizeof(dslci));
    dslci.sType = 32; dslci.bindingCount = 3; dslci.pBindings = binds;
    rc = (int)d_create_dsl(g_device, &dslci, NULL, &dsl);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkPushConstantRange pcr; memset(&pcr, 0, sizeof(pcr));
    pcr.stageFlags = 0x20u; pcr.offset = 0; pcr.size = 4;
    AesirVkPipelineLayoutCreateInfo plci; memset(&plci, 0, sizeof(plci));
    plci.sType = 30; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
    rc = (int)d_create_pl(g_device, &plci, NULL, &pl);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkComputePipelineCreateInfo cpci; memset(&cpci, 0, sizeof(cpci));
    cpci.sType = 29; cpci.stage.sType = 18; cpci.stage.stage = 0x20u; cpci.stage.module = shader; cpci.stage.pName = "main"; cpci.layout = pl; cpci.basePipelineIndex = -1;
    rc = (int)d_create_cp(g_device, NULL, 1, &cpci, NULL, &pipe);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorPoolSize psz; memset(&psz, 0, sizeof(psz));
    psz.type = 6; psz.descriptorCount = 3;
    AesirVkDescriptorPoolCreateInfo dpci; memset(&dpci, 0, sizeof(dpci));
    dpci.sType = 33; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &psz;
    rc = (int)d_create_dpool(g_device, &dpci, NULL, &dpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetAllocateInfo dsai; memset(&dsai, 0, sizeof(dsai));
    dsai.sType = 34; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
    rc = (int)d_alloc_dsets(g_device, &dsai, &dset);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorBufferInfo dbi[3]; memset(dbi, 0, sizeof(dbi));
    dbi[0].buffer = sa->buffer; dbi[0].range = need;
    dbi[1].buffer = sb->buffer; dbi[1].range = need;
    dbi[2].buffer = sc->buffer; dbi[2].range = need;
    AesirVkWriteDescriptorSet writes[3]; memset(writes, 0, sizeof(writes));
    for (int i = 0; i < 3; i++) { writes[i].sType = 35; writes[i].dstSet = dset; writes[i].dstBinding = (uint32_t)i; writes[i].descriptorCount = 1; writes[i].descriptorType = 6; writes[i].pBufferInfo = &dbi[i]; }
    d_update_dsets(g_device, 3, writes, 0, NULL);
    AesirVkCommandPoolCreateInfo cpi; memset(&cpi, 0, sizeof(cpi));
    cpi.sType = 39; cpi.queueFamilyIndex = g_queue_family;
    rc = (int)d_create_cpool(g_device, &cpi, NULL, &cpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferAllocateInfo cbai; memset(&cbai, 0, sizeof(cbai));
    cbai.sType = 40; cbai.commandPool = cpool; cbai.level = 0; cbai.commandBufferCount = 1;
    rc = (int)d_alloc_cbufs(g_device, &cbai, &cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferBeginInfo cbbi; memset(&cbbi, 0, sizeof(cbbi));
    cbbi.sType = 42;
    rc = (int)d_begin_cbuf(cbuf, &cbbi);
    if (rc != 0) { out_rc = rc; goto done; }
    d_cmd_bind_pipeline(cbuf, 1, pipe); /* VK_PIPELINE_BIND_POINT_COMPUTE */
    d_cmd_bind_dsets(cbuf, 1, pl, 0, 1, &dset, 0, NULL); /* COMPUTE bind point */
    d_cmd_push(cbuf, pl, 0x20u, 0, 4, &n);
    d_cmd_dispatch(cbuf, (n + 255u) / 256u, 1, 1);
    rc = (int)d_end_cbuf(cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkSubmitInfo si; memset(&si, 0, sizeof(si));
    si.sType = 4; si.commandBufferCount = 1; si.pCommandBuffers = &cbuf;
    rc = (int)d_queue_submit(g_queue, 1, &si, NULL);
    if (rc != 0) { out_rc = rc; goto done; }
    rc = (int)d_queue_wait_idle(g_queue);
    if (rc != 0) { out_rc = rc; goto done; }
    out_rc = 0;
done:
    if (cpool != NULL) { d_destroy_cpool(g_device, cpool, NULL); }
    if (dpool != NULL) { d_destroy_dpool(g_device, dpool, NULL); }
    if (pipe != NULL) { d_destroy_pipeline(g_device, pipe, NULL); }
    if (pl != NULL) { d_destroy_pl(g_device, pl, NULL); }
    if (dsl != NULL) { d_destroy_dsl(g_device, dsl, NULL); }
    if (shader != NULL) { d_destroy_shader_module(g_device, shader, NULL); }
    return out_rc;
}

/* --- A-019 zero-copy instrumentation + type evidence --- */

/* Copy-call counter for the A-019 acceptance: this shim resolves
 * NO copy entry point at all (there is no vkCmdCopyBuffer /
 * vkCmdCopyImage dlsym anywhere in this file), so no code path can
 * increment this counter; a zero reading after dispatch work is
 * structural proof the Vulkan zero-copy path ran copy-free. */
static uint64_t g_vk_copy_calls = 0;

uint64_t aesir_vk_copy_call_count(void) { return g_vk_copy_calls; }

int aesir_vk_buffer_type_flags(uint64_t id, uint32_t *out_flags) {
    int rc = aesir_vk_init();
    if (rc != 0) {
        return rc;
    }
    AesirVkBufferSlot *s = NULL;
    int vrc = vk_own_validate(id, 0, &s);
    if (vrc != 0 || out_flags == NULL) {
        return vrc != 0 ? vrc : AESIR_VK_INVALID;
    }
    *out_flags =
        g_memprops.memoryTypes[s->memory_type_index].propertyFlags;
    return 0;
}

/* ---- A-056: Vulkan Q8_0 GEMV ----
 *
 * Dequant + single-row GEMV on the GPU: y[row] = sum_k
 * dequant(W[row,k]) * x[k], W in the raw GGUF Q8_0 byte layout
 * (34-byte blocks: fp16 scale + 32 int8) that the CPU oracle
 * (_gemm_q8_0_range) consumes. Shader source of record:
 * aesir_engine/shaders/q8_0_gemv.comp, compiled on purpleraider
 * with glslangValidator (SPIR-V 1.0, 6076 bytes, sha256
 * af3a2f037eff04e192cb9477debbcab14bcebb9354874dcec8e8b337b47ce302
 * at build time; the A-056 ledger records the regeneration
 * command). One workgroup of 256 invocations per output row;
 * cols/rows travel as push constants. Same context, device,
 * queue and A-014 buffer slots as the A-015 vec_add dispatch;
 * pipeline objects are created per dispatch and destroyed
 * before return; returns after vkQueueWaitIdle so mapped reads
 * observe the completed dispatch. The dispatch counter below
 * is the filed device-execution evidence (roadmap law 6): it
 * increments only after a submit + wait-idle completed on the
 * device. Returns 0 on success, the negative VkResult on
 * Vulkan failure, AESIR_VK_ABSENT when a dispatch entry point
 * is missing, AESIR_VK_INVALID for bad ids / sizes / a column
 * count that is not a multiple of the 32-wide Q8_0 block. */
/* A-062: kQ8GemvSpv-SPIR-V no longer hand-embedded here; consumed from the generated header (shaders/generated/aesir_shaders_spv.h: kQ80GemvSpv, byte-identical words verified). */
static uint64_t g_q8_gemv_dispatches = 0;
uint64_t aesir_vk_q8_gemv_dispatch_count(void) { return g_q8_gemv_dispatches; }
int aesir_vk_buffer_q8_gemv(uint64_t id_w, uint64_t id_x, uint64_t id_y, uint32_t rows, uint32_t cols) {
    int rc = aesir_vk_init();
    if (rc != 0) { return rc; }
    aesir_vk_load_dispatch();
    if (!g_dispatch_ok) { return AESIR_VK_ABSENT; }
    AesirVkBufferSlot *sw = NULL;
    AesirVkBufferSlot *sx = NULL;
    AesirVkBufferSlot *sy = NULL;
    int vrc = vk_own_validate(id_w, 0, &sw);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_x, 0, &sx);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_y, 0, &sy);
    if (vrc != 0) { return vrc; }
    if (rows == 0 || cols == 0 || (cols % 32u) != 0) { return AESIR_VK_INVALID; }
    uint64_t need_w = (uint64_t)rows * (uint64_t)(cols / 32u) * 34u;
    uint64_t need_x = (uint64_t)cols * 4u;
    uint64_t need_y = (uint64_t)rows * 4u;
    if (sw->requested_size < need_w || sx->requested_size < need_x || sy->requested_size < need_y) { return AESIR_VK_INVALID; }
    VkShaderModule_t shader = NULL;
    VkDescriptorSetLayout_t dsl = NULL;
    VkPipelineLayout_t pl = NULL;
    VkPipeline_t pipe = NULL;
    VkDescriptorPool_t dpool = NULL;
    VkDescriptorSet_t dset = NULL;
    VkCommandPool_t cpool = NULL;
    VkCommandBuffer_t cbuf = NULL;
    int out_rc = 0;
    AesirVkShaderModuleCreateInfo smci; memset(&smci, 0, sizeof(smci));
    smci.sType = 16; smci.codeSize = kQ80GemvSpvBytes; smci.pCode = kQ80GemvSpv;
    rc = (int)d_create_shader_module(g_device, &smci, NULL, &shader);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetLayoutBinding binds[3]; memset(binds, 0, sizeof(binds));
    for (int i = 0; i < 3; i++) { binds[i].binding = (uint32_t)i; binds[i].descriptorType = 6; binds[i].descriptorCount = 1; binds[i].stageFlags = 0x20u; }
    AesirVkDescriptorSetLayoutCreateInfo dslci; memset(&dslci, 0, sizeof(dslci));
    dslci.sType = 32; dslci.bindingCount = 3; dslci.pBindings = binds;
    rc = (int)d_create_dsl(g_device, &dslci, NULL, &dsl);
    if (rc != 0) { out_rc = rc; goto done; }
    struct { uint32_t cols; uint32_t rows; } push;
    push.cols = cols; push.rows = rows;
    AesirVkPushConstantRange pcr; memset(&pcr, 0, sizeof(pcr));
    pcr.stageFlags = 0x20u; pcr.offset = 0; pcr.size = 8;
    AesirVkPipelineLayoutCreateInfo plci; memset(&plci, 0, sizeof(plci));
    plci.sType = 30; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
    rc = (int)d_create_pl(g_device, &plci, NULL, &pl);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkComputePipelineCreateInfo cpci; memset(&cpci, 0, sizeof(cpci));
    cpci.sType = 29; cpci.stage.sType = 18; cpci.stage.stage = 0x20u; cpci.stage.module = shader; cpci.stage.pName = "main"; cpci.layout = pl; cpci.basePipelineIndex = -1;
    rc = (int)d_create_cp(g_device, NULL, 1, &cpci, NULL, &pipe);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorPoolSize psz; memset(&psz, 0, sizeof(psz));
    psz.type = 6; psz.descriptorCount = 3;
    AesirVkDescriptorPoolCreateInfo dpci; memset(&dpci, 0, sizeof(dpci));
    dpci.sType = 33; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &psz;
    rc = (int)d_create_dpool(g_device, &dpci, NULL, &dpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetAllocateInfo dsai; memset(&dsai, 0, sizeof(dsai));
    dsai.sType = 34; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
    rc = (int)d_alloc_dsets(g_device, &dsai, &dset);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorBufferInfo dbi[3]; memset(dbi, 0, sizeof(dbi));
    dbi[0].buffer = sw->buffer; dbi[0].range = need_w;
    dbi[1].buffer = sx->buffer; dbi[1].range = need_x;
    dbi[2].buffer = sy->buffer; dbi[2].range = need_y;
    AesirVkWriteDescriptorSet writes[3]; memset(writes, 0, sizeof(writes));
    for (int i = 0; i < 3; i++) { writes[i].sType = 35; writes[i].dstSet = dset; writes[i].dstBinding = (uint32_t)i; writes[i].descriptorCount = 1; writes[i].descriptorType = 6; writes[i].pBufferInfo = &dbi[i]; }
    d_update_dsets(g_device, 3, writes, 0, NULL);
    AesirVkCommandPoolCreateInfo cpi; memset(&cpi, 0, sizeof(cpi));
    cpi.sType = 39; cpi.queueFamilyIndex = g_queue_family;
    rc = (int)d_create_cpool(g_device, &cpi, NULL, &cpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferAllocateInfo cbai; memset(&cbai, 0, sizeof(cbai));
    cbai.sType = 40; cbai.commandPool = cpool; cbai.level = 0; cbai.commandBufferCount = 1;
    rc = (int)d_alloc_cbufs(g_device, &cbai, &cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferBeginInfo cbbi; memset(&cbbi, 0, sizeof(cbbi));
    cbbi.sType = 42;
    rc = (int)d_begin_cbuf(cbuf, &cbbi);
    if (rc != 0) { out_rc = rc; goto done; }
    d_cmd_bind_pipeline(cbuf, 1, pipe);
    d_cmd_bind_dsets(cbuf, 1, pl, 0, 1, &dset, 0, NULL);
    d_cmd_push(cbuf, pl, 0x20u, 0, 8, &push);
    d_cmd_dispatch(cbuf, rows, 1, 1);
    rc = (int)d_end_cbuf(cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkSubmitInfo si; memset(&si, 0, sizeof(si));
    si.sType = 4; si.commandBufferCount = 1; si.pCommandBuffers = &cbuf;
    rc = (int)d_queue_submit(g_queue, 1, &si, NULL);
    if (rc != 0) { out_rc = rc; goto done; }
    rc = (int)d_queue_wait_idle(g_queue);
    if (rc != 0) { out_rc = rc; goto done; }
    g_q8_gemv_dispatches += 1;
    out_rc = 0;
done:
    if (cpool != NULL) { d_destroy_cpool(g_device, cpool, NULL); }
    if (dpool != NULL) { d_destroy_dpool(g_device, dpool, NULL); }
    if (pipe != NULL) { d_destroy_pipeline(g_device, pipe, NULL); }
    if (pl != NULL) { d_destroy_pl(g_device, pl, NULL); }
    if (dsl != NULL) { d_destroy_dsl(g_device, dsl, NULL); }
    if (shader != NULL) { d_destroy_shader_module(g_device, shader, NULL); }
    return out_rc;
}

/* ---- A-057: Vulkan Q4_K GEMV (dequant + single-row GEMV) ----
 *
 * One SPIR-V kernel (aesir_engine/shaders/q4k_gemv.comp, y[row] =
 * sum_e dequant_q4k(W[row])[e] * x[e]) dispatched on the A-014
 * context: same instance, physical device, logical device and
 * compute queue, operating directly on A-014 buffer slots (created
 * with STORAGE_BUFFER usage). The SPIR-V words are the verbatim
 * glslangValidator output for q4k_gemv.comp (SPIR-V 1.0, 6916 bytes,
 * sha256 8241989c5994d480bce24b3475ad888be340b937f0daa776b1bb6c002e7bfe93
 * at build time; the A-057 ledger records the regeneration command).
 * The decode mirrors the banked CPU oracle (_dequantize_ggml_k_simd,
 * ggml_type 12) in f32; the CPU oracle rounds weights to f16 before
 * its dot, so parity is judged at the filed f16-rounding tolerance
 * in the A-057 tests, never bit-exactness.
 * Push constants carry (k_elems, n_rows); dispatch is one 256-wide
 * workgroup per output row. Pipeline objects are created per
 * dispatch and destroyed before return, exactly like the A-015
 * smoke path. Returns 0 on success (after vkQueueWaitIdle, so
 * mapped reads of the output observe the completed dispatch), the
 * negative VkResult on Vulkan failure, AESIR_VK_ABSENT when a
 * dispatch entry point is missing, AESIR_VK_INVALID for bad ids /
 * shapes. The dispatch counter below is device-execution evidence:
 * it increments only after a submitted dispatch completes. */

/* A-062: kQ4kGemvSpv SPIR-V no longer hand-embedded here; consumed from the generated header (shaders/generated/aesir_shaders_spv.h: kQ4kGemvSpv, byte-identical words verified). */

static uint64_t g_q4k_gemv_dispatches = 0;

uint64_t aesir_vk_q4k_gemv_dispatch_count(void) {
    return g_q4k_gemv_dispatches;
}

struct AesirQ4kPush { uint32_t k_elems; uint32_t n_rows; };

int aesir_vk_buffer_q4k_gemv(uint64_t id_w, uint64_t id_x, uint64_t id_y, uint32_t k_elems, uint32_t n_rows) {
    int rc = aesir_vk_init();
    if (rc != 0) { return rc; }
    aesir_vk_load_dispatch();
    if (!g_dispatch_ok) { return AESIR_VK_ABSENT; }
    AesirVkBufferSlot *sw = NULL;
    AesirVkBufferSlot *sx = NULL;
    AesirVkBufferSlot *sy = NULL;
    int vrc = vk_own_validate(id_w, 0, &sw);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_x, 0, &sx);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_y, 0, &sy);
    if (vrc != 0) { return vrc; }
    if (k_elems == 0 || (k_elems % 256u) != 0 || n_rows == 0) { return AESIR_VK_INVALID; }
    uint64_t need_w = (uint64_t)n_rows * (uint64_t)(k_elems / 256u) * 144u;
    uint64_t need_x = (uint64_t)k_elems * 4u;
    uint64_t need_y = (uint64_t)n_rows * 4u;
    if (sw->requested_size < need_w || sx->requested_size < need_x || sy->requested_size < need_y) { return AESIR_VK_INVALID; }
    VkShaderModule_t shader = NULL;
    VkDescriptorSetLayout_t dsl = NULL;
    VkPipelineLayout_t pl = NULL;
    VkPipeline_t pipe = NULL;
    VkDescriptorPool_t dpool = NULL;
    VkDescriptorSet_t dset = NULL;
    VkCommandPool_t cpool = NULL;
    VkCommandBuffer_t cbuf = NULL;
    int out_rc = 0;
    AesirVkShaderModuleCreateInfo smci; memset(&smci, 0, sizeof(smci));
    smci.sType = 16; smci.codeSize = kQ4kGemvSpvBytes; smci.pCode = kQ4kGemvSpv;
    rc = (int)d_create_shader_module(g_device, &smci, NULL, &shader);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetLayoutBinding binds[3]; memset(binds, 0, sizeof(binds));
    for (int i = 0; i < 3; i++) { binds[i].binding = (uint32_t)i; binds[i].descriptorType = 6; binds[i].descriptorCount = 1; binds[i].stageFlags = 0x20u; }
    AesirVkDescriptorSetLayoutCreateInfo dslci; memset(&dslci, 0, sizeof(dslci));
    dslci.sType = 32; dslci.bindingCount = 3; dslci.pBindings = binds;
    rc = (int)d_create_dsl(g_device, &dslci, NULL, &dsl);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkPushConstantRange pcr; memset(&pcr, 0, sizeof(pcr));
    pcr.stageFlags = 0x20u; pcr.offset = 0; pcr.size = 8;
    AesirVkPipelineLayoutCreateInfo plci; memset(&plci, 0, sizeof(plci));
    plci.sType = 30; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
    rc = (int)d_create_pl(g_device, &plci, NULL, &pl);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkComputePipelineCreateInfo cpci; memset(&cpci, 0, sizeof(cpci));
    cpci.sType = 29; cpci.stage.sType = 18; cpci.stage.stage = 0x20u; cpci.stage.module = shader; cpci.stage.pName = "main"; cpci.layout = pl; cpci.basePipelineIndex = -1;
    rc = (int)d_create_cp(g_device, NULL, 1, &cpci, NULL, &pipe);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorPoolSize psz; memset(&psz, 0, sizeof(psz));
    psz.type = 6; psz.descriptorCount = 3;
    AesirVkDescriptorPoolCreateInfo dpci; memset(&dpci, 0, sizeof(dpci));
    dpci.sType = 33; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &psz;
    rc = (int)d_create_dpool(g_device, &dpci, NULL, &dpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetAllocateInfo dsai; memset(&dsai, 0, sizeof(dsai));
    dsai.sType = 34; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
    rc = (int)d_alloc_dsets(g_device, &dsai, &dset);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorBufferInfo dbi[3]; memset(dbi, 0, sizeof(dbi));
    dbi[0].buffer = sw->buffer; dbi[0].range = need_w;
    dbi[1].buffer = sx->buffer; dbi[1].range = need_x;
    dbi[2].buffer = sy->buffer; dbi[2].range = need_y;
    AesirVkWriteDescriptorSet writes[3]; memset(writes, 0, sizeof(writes));
    for (int i = 0; i < 3; i++) { writes[i].sType = 35; writes[i].dstSet = dset; writes[i].dstBinding = (uint32_t)i; writes[i].descriptorCount = 1; writes[i].descriptorType = 6; writes[i].pBufferInfo = &dbi[i]; }
    d_update_dsets(g_device, 3, writes, 0, NULL);
    AesirVkCommandPoolCreateInfo cpi; memset(&cpi, 0, sizeof(cpi));
    cpi.sType = 39; cpi.queueFamilyIndex = g_queue_family;
    rc = (int)d_create_cpool(g_device, &cpi, NULL, &cpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferAllocateInfo cbai; memset(&cbai, 0, sizeof(cbai));
    cbai.sType = 40; cbai.commandPool = cpool; cbai.level = 0; cbai.commandBufferCount = 1;
    rc = (int)d_alloc_cbufs(g_device, &cbai, &cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferBeginInfo cbbi; memset(&cbbi, 0, sizeof(cbbi));
    cbbi.sType = 42;
    rc = (int)d_begin_cbuf(cbuf, &cbbi);
    if (rc != 0) { out_rc = rc; goto done; }
    d_cmd_bind_pipeline(cbuf, 1, pipe);
    d_cmd_bind_dsets(cbuf, 1, pl, 0, 1, &dset, 0, NULL);
    struct AesirQ4kPush push; push.k_elems = k_elems; push.n_rows = n_rows;
    d_cmd_push(cbuf, pl, 0x20u, 0, 8, &push);
    d_cmd_dispatch(cbuf, n_rows, 1, 1);
    rc = (int)d_end_cbuf(cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkSubmitInfo si; memset(&si, 0, sizeof(si));
    si.sType = 4; si.commandBufferCount = 1; si.pCommandBuffers = &cbuf;
    rc = (int)d_queue_submit(g_queue, 1, &si, NULL);
    if (rc != 0) { out_rc = rc; goto done; }
    rc = (int)d_queue_wait_idle(g_queue);
    if (rc != 0) { out_rc = rc; goto done; }
    g_q4k_gemv_dispatches += 1;
    out_rc = 0;
done:
    if (cpool != NULL) { d_destroy_cpool(g_device, cpool, NULL); }
    if (dpool != NULL) { d_destroy_dpool(g_device, dpool, NULL); }
    if (pipe != NULL) { d_destroy_pipeline(g_device, pipe, NULL); }
    if (pl != NULL) { d_destroy_pl(g_device, pl, NULL); }
    if (dsl != NULL) { d_destroy_dsl(g_device, dsl, NULL); }
    if (shader != NULL) { d_destroy_shader_module(g_device, shader, NULL); }
    return out_rc;
}
// A-058 embedded SPIR-V: compiled on purpleraider with glslangValidator 16.4.0
// from aesir_engine/shaders/q6_k_gemv.comp and q5_k_gemv.comp (hashes in A058 ledger).
/* A-062: kQ6GemvSpv-SPIR-V no longer hand-embedded here; consumed from the generated header (shaders/generated/aesir_shaders_spv.h: kQ6KGemvSpv, byte-identical words verified). */
/* A-062: kQ5GemvSpv-SPIR-V no longer hand-embedded here; consumed from the generated header (shaders/generated/aesir_shaders_spv.h: kQ5KGemvSpv, byte-identical words verified). */
// A-058: shared K-quant GEMV dispatch (Q6_K: 256 values / 210-byte
// blocks; Q5_K: 256 values / 176-byte blocks). Body mirrors the
// A-056 Q8_0 dispatch exactly, parameterized by SPIR-V, block
// geometry, and counter; the Q8_0 entry point above is untouched.
static int vk_kquant_gemv(const uint32_t *spv, size_t spv_bytes, uint64_t id_w, uint64_t id_x, uint64_t id_y, uint32_t rows, uint32_t cols, uint32_t block_elems, uint32_t block_bytes, uint64_t *counter) {
    int rc = aesir_vk_init();
    if (rc != 0) { return rc; }
    aesir_vk_load_dispatch();
    if (!g_dispatch_ok) { return AESIR_VK_ABSENT; }
    AesirVkBufferSlot *sw = NULL;
    AesirVkBufferSlot *sx = NULL;
    AesirVkBufferSlot *sy = NULL;
    int vrc = vk_own_validate(id_w, 0, &sw);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_x, 0, &sx);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_y, 0, &sy);
    if (vrc != 0) { return vrc; }
    if (rows == 0 || cols == 0 || (cols % block_elems) != 0) { return AESIR_VK_INVALID; }
    uint64_t need_w = (uint64_t)rows * (uint64_t)(cols / block_elems) * (uint64_t)block_bytes;
    uint64_t need_x = (uint64_t)cols * 4u;
    uint64_t need_y = (uint64_t)rows * 4u;
    if (sw->requested_size < need_w || sx->requested_size < need_x || sy->requested_size < need_y) { return AESIR_VK_INVALID; }
    VkShaderModule_t shader = NULL;
    VkDescriptorSetLayout_t dsl = NULL;
    VkPipelineLayout_t pl = NULL;
    VkPipeline_t pipe = NULL;
    VkDescriptorPool_t dpool = NULL;
    VkDescriptorSet_t dset = NULL;
    VkCommandPool_t cpool = NULL;
    VkCommandBuffer_t cbuf = NULL;
    int out_rc = 0;
    AesirVkShaderModuleCreateInfo smci; memset(&smci, 0, sizeof(smci));
    smci.sType = 16; smci.codeSize = spv_bytes; smci.pCode = spv;
    rc = (int)d_create_shader_module(g_device, &smci, NULL, &shader);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetLayoutBinding binds[3]; memset(binds, 0, sizeof(binds));
    for (int i = 0; i < 3; i++) { binds[i].binding = (uint32_t)i; binds[i].descriptorType = 6; binds[i].descriptorCount = 1; binds[i].stageFlags = 0x20u; }
    AesirVkDescriptorSetLayoutCreateInfo dslci; memset(&dslci, 0, sizeof(dslci));
    dslci.sType = 32; dslci.bindingCount = 3; dslci.pBindings = binds;
    rc = (int)d_create_dsl(g_device, &dslci, NULL, &dsl);
    if (rc != 0) { out_rc = rc; goto done; }
    struct { uint32_t cols; uint32_t rows; } push;
    push.cols = cols; push.rows = rows;
    AesirVkPushConstantRange pcr; memset(&pcr, 0, sizeof(pcr));
    pcr.stageFlags = 0x20u; pcr.offset = 0; pcr.size = 8;
    AesirVkPipelineLayoutCreateInfo plci; memset(&plci, 0, sizeof(plci));
    plci.sType = 30; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
    rc = (int)d_create_pl(g_device, &plci, NULL, &pl);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkComputePipelineCreateInfo cpci; memset(&cpci, 0, sizeof(cpci));
    cpci.sType = 29; cpci.stage.sType = 18; cpci.stage.stage = 0x20u; cpci.stage.module = shader; cpci.stage.pName = "main"; cpci.layout = pl; cpci.basePipelineIndex = -1;
    rc = (int)d_create_cp(g_device, NULL, 1, &cpci, NULL, &pipe);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorPoolSize psz; memset(&psz, 0, sizeof(psz));
    psz.type = 6; psz.descriptorCount = 3;
    AesirVkDescriptorPoolCreateInfo dpci; memset(&dpci, 0, sizeof(dpci));
    dpci.sType = 33; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &psz;
    rc = (int)d_create_dpool(g_device, &dpci, NULL, &dpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetAllocateInfo dsai; memset(&dsai, 0, sizeof(dsai));
    dsai.sType = 34; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
    rc = (int)d_alloc_dsets(g_device, &dsai, &dset);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorBufferInfo dbi[3]; memset(dbi, 0, sizeof(dbi));
    dbi[0].buffer = sw->buffer; dbi[0].range = need_w;
    dbi[1].buffer = sx->buffer; dbi[1].range = need_x;
    dbi[2].buffer = sy->buffer; dbi[2].range = need_y;
    AesirVkWriteDescriptorSet writes[3]; memset(writes, 0, sizeof(writes));
    for (int i = 0; i < 3; i++) { writes[i].sType = 35; writes[i].dstSet = dset; writes[i].dstBinding = (uint32_t)i; writes[i].descriptorCount = 1; writes[i].descriptorType = 6; writes[i].pBufferInfo = &dbi[i]; }
    d_update_dsets(g_device, 3, writes, 0, NULL);
    AesirVkCommandPoolCreateInfo cpi; memset(&cpi, 0, sizeof(cpi));
    cpi.sType = 39; cpi.queueFamilyIndex = g_queue_family;
    rc = (int)d_create_cpool(g_device, &cpi, NULL, &cpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferAllocateInfo cbai; memset(&cbai, 0, sizeof(cbai));
    cbai.sType = 40; cbai.commandPool = cpool; cbai.level = 0; cbai.commandBufferCount = 1;
    rc = (int)d_alloc_cbufs(g_device, &cbai, &cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferBeginInfo cbbi; memset(&cbbi, 0, sizeof(cbbi));
    cbbi.sType = 42;
    rc = (int)d_begin_cbuf(cbuf, &cbbi);
    if (rc != 0) { out_rc = rc; goto done; }
    d_cmd_bind_pipeline(cbuf, 1, pipe);
    d_cmd_bind_dsets(cbuf, 1, pl, 0, 1, &dset, 0, NULL);
    d_cmd_push(cbuf, pl, 0x20u, 0, 8, &push);
    d_cmd_dispatch(cbuf, rows, 1, 1);
    rc = (int)d_end_cbuf(cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkSubmitInfo si; memset(&si, 0, sizeof(si));
    si.sType = 4; si.commandBufferCount = 1; si.pCommandBuffers = &cbuf;
    rc = (int)d_queue_submit(g_queue, 1, &si, NULL);
    if (rc != 0) { out_rc = rc; goto done; }
    rc = (int)d_queue_wait_idle(g_queue);
    if (rc != 0) { out_rc = rc; goto done; }
    *counter += 1;
    out_rc = 0;
done:
    if (cpool != NULL) { d_destroy_cpool(g_device, cpool, NULL); }
    if (dpool != NULL) { d_destroy_dpool(g_device, dpool, NULL); }
    if (pipe != NULL) { d_destroy_pipeline(g_device, pipe, NULL); }
    if (pl != NULL) { d_destroy_pl(g_device, pl, NULL); }
    if (dsl != NULL) { d_destroy_dsl(g_device, dsl, NULL); }
    if (shader != NULL) { d_destroy_shader_module(g_device, shader, NULL); }
    return out_rc;
}
static uint64_t g_q6_gemv_dispatches = 0;
uint64_t aesir_vk_q6_gemv_dispatch_count(void) { return g_q6_gemv_dispatches; }
int aesir_vk_buffer_q6_gemv(uint64_t id_w, uint64_t id_x, uint64_t id_y, uint32_t rows, uint32_t cols) {
    return vk_kquant_gemv(kQ6KGemvSpv, sizeof(kQ6KGemvSpv), id_w, id_x, id_y, rows, cols, 256u, 210u, &g_q6_gemv_dispatches);
}
static uint64_t g_q5_gemv_dispatches = 0;
uint64_t aesir_vk_q5_gemv_dispatch_count(void) { return g_q5_gemv_dispatches; }
int aesir_vk_buffer_q5_gemv(uint64_t id_w, uint64_t id_x, uint64_t id_y, uint32_t rows, uint32_t cols) {
    return vk_kquant_gemv(kQ5KGemvSpv, sizeof(kQ5KGemvSpv), id_w, id_x, id_y, rows, cols, 256u, 176u, &g_q5_gemv_dispatches);
}

/* ---- A-062: Vulkan decode attention ----
 * Single-query attention over a unified KV cache, kernel
 * aesir_engine/shaders/attention_decode.comp (A-055 foundation,
 * SPIR-V via shaders/generated/aesir_shaders_spv.h:
 * kAttentionDecodeSpv). Layout: q is [num_heads][head_dim],
 * k/v are [num_kv_heads][kv_len][head_dim] with
 * num_kv_heads = num_heads / kv_per_query, o is
 * [num_heads][head_dim]. One workgroup of 64 per 64 output
 * elements. Same per-dispatch pipeline discipline as A-056. */
static uint64_t g_attn_decode_dispatches = 0;
uint64_t aesir_vk_attn_decode_dispatch_count(void) { return g_attn_decode_dispatches; }
int aesir_vk_buffer_attn_decode(uint64_t id_q, uint64_t id_k, uint64_t id_v, uint64_t id_o, uint32_t head_dim, uint32_t kv_len, uint32_t num_heads, uint32_t kv_per_query) {
    int rc = aesir_vk_init();
    if (rc != 0) { return rc; }
    aesir_vk_load_dispatch();
    if (!g_dispatch_ok) { return AESIR_VK_ABSENT; }
    AesirVkBufferSlot *sq = NULL;
    AesirVkBufferSlot *sk = NULL;
    AesirVkBufferSlot *sv = NULL;
    AesirVkBufferSlot *so = NULL;
    int vrc = vk_own_validate(id_q, 0, &sq);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_k, 0, &sk);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_v, 0, &sv);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_o, 0, &so);
    if (vrc != 0) { return vrc; }
    if (head_dim == 0 || kv_len == 0 || num_heads == 0 || kv_per_query == 0) { return AESIR_VK_INVALID; }
    if ((num_heads % kv_per_query) != 0) { return AESIR_VK_INVALID; }
    uint32_t num_kv_heads = num_heads / kv_per_query;
    uint64_t need_q = (uint64_t)num_heads * (uint64_t)head_dim * 4u;
    uint64_t need_kv = (uint64_t)num_kv_heads * (uint64_t)kv_len * (uint64_t)head_dim * 4u;
    if (sq->requested_size < need_q || sk->requested_size < need_kv || sv->requested_size < need_kv || so->requested_size < need_q) { return AESIR_VK_INVALID; }
    VkShaderModule_t shader = NULL;
    VkDescriptorSetLayout_t dsl = NULL;
    VkPipelineLayout_t pl = NULL;
    VkPipeline_t pipe = NULL;
    VkDescriptorPool_t dpool = NULL;
    VkDescriptorSet_t dset = NULL;
    VkCommandPool_t cpool = NULL;
    VkCommandBuffer_t cbuf = NULL;
    int out_rc = 0;
    AesirVkShaderModuleCreateInfo smci; memset(&smci, 0, sizeof(smci));
    smci.sType = 16; smci.codeSize = kAttentionDecodeSpvBytes; smci.pCode = kAttentionDecodeSpv;
    rc = (int)d_create_shader_module(g_device, &smci, NULL, &shader);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetLayoutBinding binds[4]; memset(binds, 0, sizeof(binds));
    for (int i = 0; i < 4; i++) { binds[i].binding = (uint32_t)i; binds[i].descriptorType = 6; binds[i].descriptorCount = 1; binds[i].stageFlags = 0x20u; }
    AesirVkDescriptorSetLayoutCreateInfo dslci; memset(&dslci, 0, sizeof(dslci));
    dslci.sType = 32; dslci.bindingCount = 4; dslci.pBindings = binds;
    rc = (int)d_create_dsl(g_device, &dslci, NULL, &dsl);
    if (rc != 0) { out_rc = rc; goto done; }
    struct { uint32_t head_dim; uint32_t kv_len; uint32_t num_heads; uint32_t kv_per_query; } push;
    push.head_dim = head_dim; push.kv_len = kv_len; push.num_heads = num_heads; push.kv_per_query = kv_per_query;
    AesirVkPushConstantRange pcr; memset(&pcr, 0, sizeof(pcr));
    pcr.stageFlags = 0x20u; pcr.offset = 0; pcr.size = 16;
    AesirVkPipelineLayoutCreateInfo plci; memset(&plci, 0, sizeof(plci));
    plci.sType = 30; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
    rc = (int)d_create_pl(g_device, &plci, NULL, &pl);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkComputePipelineCreateInfo cpci; memset(&cpci, 0, sizeof(cpci));
    cpci.sType = 29; cpci.stage.sType = 18; cpci.stage.stage = 0x20u; cpci.stage.module = shader; cpci.stage.pName = "main"; cpci.layout = pl; cpci.basePipelineIndex = -1;
    rc = (int)d_create_cp(g_device, NULL, 1, &cpci, NULL, &pipe);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorPoolSize psz; memset(&psz, 0, sizeof(psz));
    psz.type = 6; psz.descriptorCount = 4;
    AesirVkDescriptorPoolCreateInfo dpci; memset(&dpci, 0, sizeof(dpci));
    dpci.sType = 33; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &psz;
    rc = (int)d_create_dpool(g_device, &dpci, NULL, &dpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetAllocateInfo dsai; memset(&dsai, 0, sizeof(dsai));
    dsai.sType = 34; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
    rc = (int)d_alloc_dsets(g_device, &dsai, &dset);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorBufferInfo dbi[4]; memset(dbi, 0, sizeof(dbi));
    dbi[0].buffer = sq->buffer; dbi[0].range = need_q;
    dbi[1].buffer = sk->buffer; dbi[1].range = need_kv;
    dbi[2].buffer = sv->buffer; dbi[2].range = need_kv;
    dbi[3].buffer = so->buffer; dbi[3].range = need_q;
    AesirVkWriteDescriptorSet writes[4]; memset(writes, 0, sizeof(writes));
    for (int i = 0; i < 4; i++) { writes[i].sType = 35; writes[i].dstSet = dset; writes[i].dstBinding = (uint32_t)i; writes[i].descriptorCount = 1; writes[i].descriptorType = 6; writes[i].pBufferInfo = &dbi[i]; }
    d_update_dsets(g_device, 4, writes, 0, NULL);
    AesirVkCommandPoolCreateInfo cpi; memset(&cpi, 0, sizeof(cpi));
    cpi.sType = 39; cpi.queueFamilyIndex = g_queue_family;
    rc = (int)d_create_cpool(g_device, &cpi, NULL, &cpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferAllocateInfo cbai; memset(&cbai, 0, sizeof(cbai));
    cbai.sType = 40; cbai.commandPool = cpool; cbai.level = 0; cbai.commandBufferCount = 1;
    rc = (int)d_alloc_cbufs(g_device, &cbai, &cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferBeginInfo cbbi; memset(&cbbi, 0, sizeof(cbbi));
    cbbi.sType = 42;
    rc = (int)d_begin_cbuf(cbuf, &cbbi);
    if (rc != 0) { out_rc = rc; goto done; }
    d_cmd_bind_pipeline(cbuf, 1, pipe);
    d_cmd_bind_dsets(cbuf, 1, pl, 0, 1, &dset, 0, NULL);
    d_cmd_push(cbuf, pl, 0x20u, 0, 16, &push);
    uint32_t groups = (num_heads * head_dim + 63u) / 64u;
    d_cmd_dispatch(cbuf, groups, 1, 1);
    rc = (int)d_end_cbuf(cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkSubmitInfo si; memset(&si, 0, sizeof(si));
    si.sType = 4; si.commandBufferCount = 1; si.pCommandBuffers = &cbuf;
    rc = (int)d_queue_submit(g_queue, 1, &si, NULL);
    if (rc != 0) { out_rc = rc; goto done; }
    rc = (int)d_queue_wait_idle(g_queue);
    if (rc != 0) { out_rc = rc; goto done; }
    g_attn_decode_dispatches += 1;
    out_rc = 0;
done:
    if (cpool != NULL) { d_destroy_cpool(g_device, cpool, NULL); }
    if (dpool != NULL) { d_destroy_dpool(g_device, dpool, NULL); }
    if (pipe != NULL) { d_destroy_pipeline(g_device, pipe, NULL); }
    if (pl != NULL) { d_destroy_pl(g_device, pl, NULL); }
    if (dsl != NULL) { d_destroy_dsl(g_device, dsl, NULL); }
    if (shader != NULL) { d_destroy_shader_module(g_device, shader, NULL); }
    return out_rc;
}
/* A-066 strided decode attention: same body as A-062 with a
 * separate cache stride (max_len) push field and max_len-deep
 * cache validation; SPIR-V kAttentionDecodeStridedSpv. Its
 * counter is filed separately so A-062 counts stay exact. */
static uint64_t g_attn_decode_strided_dispatches = 0;
uint64_t aesir_vk_attn_decode_strided_dispatch_count(void) { return g_attn_decode_strided_dispatches; }
int aesir_vk_buffer_attn_decode_strided(uint64_t id_q, uint64_t id_k, uint64_t id_v, uint64_t id_o, uint32_t head_dim, uint32_t kv_len, uint32_t num_heads, uint32_t kv_per_query, uint32_t max_len) {
    int rc = aesir_vk_init();
    if (rc != 0) { return rc; }
    aesir_vk_load_dispatch();
    if (!g_dispatch_ok) { return AESIR_VK_ABSENT; }
    AesirVkBufferSlot *sq = NULL;
    AesirVkBufferSlot *sk = NULL;
    AesirVkBufferSlot *sv = NULL;
    AesirVkBufferSlot *so = NULL;
    int vrc = vk_own_validate(id_q, 0, &sq);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_k, 0, &sk);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_v, 0, &sv);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_o, 0, &so);
    if (vrc != 0) { return vrc; }
    if (head_dim == 0 || kv_len == 0 || num_heads == 0 || kv_per_query == 0 || max_len < kv_len) { return AESIR_VK_INVALID; }
    if ((num_heads % kv_per_query) != 0) { return AESIR_VK_INVALID; }
    uint32_t num_kv_heads = num_heads / kv_per_query;
    uint64_t need_q = (uint64_t)num_heads * (uint64_t)head_dim * 4u;
    uint64_t need_kv = (uint64_t)num_kv_heads * (uint64_t)max_len * (uint64_t)head_dim * 4u;
    if (sq->requested_size < need_q || sk->requested_size < need_kv || sv->requested_size < need_kv || so->requested_size < need_q) { return AESIR_VK_INVALID; }
    VkShaderModule_t shader = NULL;
    VkDescriptorSetLayout_t dsl = NULL;
    VkPipelineLayout_t pl = NULL;
    VkPipeline_t pipe = NULL;
    VkDescriptorPool_t dpool = NULL;
    VkDescriptorSet_t dset = NULL;
    VkCommandPool_t cpool = NULL;
    VkCommandBuffer_t cbuf = NULL;
    int out_rc = 0;
    AesirVkShaderModuleCreateInfo smci; memset(&smci, 0, sizeof(smci));
    smci.sType = 16; smci.codeSize = kAttentionDecodeStridedSpvBytes; smci.pCode = kAttentionDecodeStridedSpv;
    rc = (int)d_create_shader_module(g_device, &smci, NULL, &shader);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetLayoutBinding binds[4]; memset(binds, 0, sizeof(binds));
    for (int i = 0; i < 4; i++) { binds[i].binding = (uint32_t)i; binds[i].descriptorType = 6; binds[i].descriptorCount = 1; binds[i].stageFlags = 0x20u; }
    AesirVkDescriptorSetLayoutCreateInfo dslci; memset(&dslci, 0, sizeof(dslci));
    dslci.sType = 32; dslci.bindingCount = 4; dslci.pBindings = binds;
    rc = (int)d_create_dsl(g_device, &dslci, NULL, &dsl);
    if (rc != 0) { out_rc = rc; goto done; }
    struct { uint32_t head_dim; uint32_t kv_len; uint32_t num_heads; uint32_t kv_per_query; uint32_t max_len; } push;
    push.head_dim = head_dim; push.kv_len = kv_len; push.num_heads = num_heads; push.kv_per_query = kv_per_query; push.max_len = max_len;
    AesirVkPushConstantRange pcr; memset(&pcr, 0, sizeof(pcr));
    pcr.stageFlags = 0x20u; pcr.offset = 0; pcr.size = 20;
    AesirVkPipelineLayoutCreateInfo plci; memset(&plci, 0, sizeof(plci));
    plci.sType = 30; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
    rc = (int)d_create_pl(g_device, &plci, NULL, &pl);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkComputePipelineCreateInfo cpci; memset(&cpci, 0, sizeof(cpci));
    cpci.sType = 29; cpci.stage.sType = 18; cpci.stage.stage = 0x20u; cpci.stage.module = shader; cpci.stage.pName = "main"; cpci.layout = pl; cpci.basePipelineIndex = -1;
    rc = (int)d_create_cp(g_device, NULL, 1, &cpci, NULL, &pipe);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorPoolSize psz; memset(&psz, 0, sizeof(psz));
    psz.type = 6; psz.descriptorCount = 4;
    AesirVkDescriptorPoolCreateInfo dpci; memset(&dpci, 0, sizeof(dpci));
    dpci.sType = 33; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &psz;
    rc = (int)d_create_dpool(g_device, &dpci, NULL, &dpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetAllocateInfo dsai; memset(&dsai, 0, sizeof(dsai));
    dsai.sType = 34; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
    rc = (int)d_alloc_dsets(g_device, &dsai, &dset);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorBufferInfo dbi[4]; memset(dbi, 0, sizeof(dbi));
    dbi[0].buffer = sq->buffer; dbi[0].range = need_q;
    dbi[1].buffer = sk->buffer; dbi[1].range = need_kv;
    dbi[2].buffer = sv->buffer; dbi[2].range = need_kv;
    dbi[3].buffer = so->buffer; dbi[3].range = need_q;
    AesirVkWriteDescriptorSet writes[4]; memset(writes, 0, sizeof(writes));
    for (int i = 0; i < 4; i++) { writes[i].sType = 35; writes[i].dstSet = dset; writes[i].dstBinding = (uint32_t)i; writes[i].descriptorCount = 1; writes[i].descriptorType = 6; writes[i].pBufferInfo = &dbi[i]; }
    d_update_dsets(g_device, 4, writes, 0, NULL);
    AesirVkCommandPoolCreateInfo cpi; memset(&cpi, 0, sizeof(cpi));
    cpi.sType = 39; cpi.queueFamilyIndex = g_queue_family;
    rc = (int)d_create_cpool(g_device, &cpi, NULL, &cpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferAllocateInfo cbai; memset(&cbai, 0, sizeof(cbai));
    cbai.sType = 40; cbai.commandPool = cpool; cbai.level = 0; cbai.commandBufferCount = 1;
    rc = (int)d_alloc_cbufs(g_device, &cbai, &cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferBeginInfo cbbi; memset(&cbbi, 0, sizeof(cbbi));
    cbbi.sType = 42;
    rc = (int)d_begin_cbuf(cbuf, &cbbi);
    if (rc != 0) { out_rc = rc; goto done; }
    d_cmd_bind_pipeline(cbuf, 1, pipe);
    d_cmd_bind_dsets(cbuf, 1, pl, 0, 1, &dset, 0, NULL);
    d_cmd_push(cbuf, pl, 0x20u, 0, 20, &push);
    uint32_t groups = (num_heads * head_dim + 63u) / 64u;
    d_cmd_dispatch(cbuf, groups, 1, 1);
    rc = (int)d_end_cbuf(cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkSubmitInfo si; memset(&si, 0, sizeof(si));
    si.sType = 4; si.commandBufferCount = 1; si.pCommandBuffers = &cbuf;
    rc = (int)d_queue_submit(g_queue, 1, &si, NULL);
    if (rc != 0) { out_rc = rc; goto done; }
    rc = (int)d_queue_wait_idle(g_queue);
    if (rc != 0) { out_rc = rc; goto done; }
    g_attn_decode_strided_dispatches += 1;
    out_rc = 0;
done:
    if (cpool != NULL) { d_destroy_cpool(g_device, cpool, NULL); }
    if (dpool != NULL) { d_destroy_dpool(g_device, dpool, NULL); }
    if (pipe != NULL) { d_destroy_pipeline(g_device, pipe, NULL); }
    if (pl != NULL) { d_destroy_pl(g_device, pl, NULL); }
    if (dsl != NULL) { d_destroy_dsl(g_device, dsl, NULL); }
    if (shader != NULL) { d_destroy_shader_module(g_device, shader, NULL); }
    return out_rc;
}
/* ---- A-063: Vulkan sampling (greedy + temperature/top-k) ----
 * Greedy kernel aesir_engine/shaders/sampling_greedy.comp (A-055
 * foundation, SPIR-V via shaders/generated/aesir_shaders_spv.h:
 * kSamplingGreedySpv): one workgroup reduces (value, index)
 * argmax pairs over a Float32 logits row, ties to the lowest
 * index, and writes the winning token id as a uint.
 * Temperature/top-k kernel sampling_sample.comp (A-063, SPIR-V
 * via the same generated header: kSamplingSampleSpv): draws one
 * token from the temperature-scaled, top-k-truncated softmax
 * for a caller-supplied uniform u in [0, 1) (see the .comp
 * header for the exact CPU-oracle draw semantics).
 * Same per-dispatch pipeline discipline as A-056/A-062; each
 * counter increments only after submit + queue-wait-idle. */
static int vk_sampling_dispatch(const uint32_t *spv, size_t spv_bytes, uint64_t id_logits, uint64_t id_out, uint32_t n, const void *push, uint32_t push_size, uint64_t *counter) {
    int rc = aesir_vk_init();
    if (rc != 0) { return rc; }
    aesir_vk_load_dispatch();
    if (!g_dispatch_ok) { return AESIR_VK_ABSENT; }
    AesirVkBufferSlot *sl = NULL;
    AesirVkBufferSlot *so = NULL;
    int vrc = vk_own_validate(id_logits, 0, &sl);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_out, 0, &so);
    if (vrc != 0) { return vrc; }
    if (n == 0) { return AESIR_VK_INVALID; }
    uint64_t need_logits = (uint64_t)n * 4u;
    if (sl->requested_size < need_logits || so->requested_size < 4u) { return AESIR_VK_INVALID; }
    VkShaderModule_t shader = NULL;
    VkDescriptorSetLayout_t dsl = NULL;
    VkPipelineLayout_t pl = NULL;
    VkPipeline_t pipe = NULL;
    VkDescriptorPool_t dpool = NULL;
    VkDescriptorSet_t dset = NULL;
    VkCommandPool_t cpool = NULL;
    VkCommandBuffer_t cbuf = NULL;
    int out_rc = 0;
    AesirVkShaderModuleCreateInfo smci; memset(&smci, 0, sizeof(smci));
    smci.sType = 16; smci.codeSize = spv_bytes; smci.pCode = spv;
    rc = (int)d_create_shader_module(g_device, &smci, NULL, &shader);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetLayoutBinding binds[2]; memset(binds, 0, sizeof(binds));
    for (int i = 0; i < 2; i++) { binds[i].binding = (uint32_t)i; binds[i].descriptorType = 6; binds[i].descriptorCount = 1; binds[i].stageFlags = 0x20u; }
    AesirVkDescriptorSetLayoutCreateInfo dslci; memset(&dslci, 0, sizeof(dslci));
    dslci.sType = 32; dslci.bindingCount = 2; dslci.pBindings = binds;
    rc = (int)d_create_dsl(g_device, &dslci, NULL, &dsl);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkPushConstantRange pcr; memset(&pcr, 0, sizeof(pcr));
    pcr.stageFlags = 0x20u; pcr.offset = 0; pcr.size = push_size;
    AesirVkPipelineLayoutCreateInfo plci; memset(&plci, 0, sizeof(plci));
    plci.sType = 30; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
    rc = (int)d_create_pl(g_device, &plci, NULL, &pl);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkComputePipelineCreateInfo cpci; memset(&cpci, 0, sizeof(cpci));
    cpci.sType = 29; cpci.stage.sType = 18; cpci.stage.stage = 0x20u; cpci.stage.module = shader; cpci.stage.pName = "main"; cpci.layout = pl; cpci.basePipelineIndex = -1;
    rc = (int)d_create_cp(g_device, NULL, 1, &cpci, NULL, &pipe);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorPoolSize psz; memset(&psz, 0, sizeof(psz));
    psz.type = 6; psz.descriptorCount = 2;
    AesirVkDescriptorPoolCreateInfo dpci; memset(&dpci, 0, sizeof(dpci));
    dpci.sType = 33; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &psz;
    rc = (int)d_create_dpool(g_device, &dpci, NULL, &dpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetAllocateInfo dsai; memset(&dsai, 0, sizeof(dsai));
    dsai.sType = 34; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
    rc = (int)d_alloc_dsets(g_device, &dsai, &dset);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorBufferInfo dbi[2]; memset(dbi, 0, sizeof(dbi));
    dbi[0].buffer = sl->buffer; dbi[0].range = need_logits;
    dbi[1].buffer = so->buffer; dbi[1].range = 4u;
    AesirVkWriteDescriptorSet writes[2]; memset(writes, 0, sizeof(writes));
    for (int i = 0; i < 2; i++) { writes[i].sType = 35; writes[i].dstSet = dset; writes[i].dstBinding = (uint32_t)i; writes[i].descriptorCount = 1; writes[i].descriptorType = 6; writes[i].pBufferInfo = &dbi[i]; }
    d_update_dsets(g_device, 2, writes, 0, NULL);
    AesirVkCommandPoolCreateInfo cpi; memset(&cpi, 0, sizeof(cpi));
    cpi.sType = 39; cpi.queueFamilyIndex = g_queue_family;
    rc = (int)d_create_cpool(g_device, &cpi, NULL, &cpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferAllocateInfo cbai; memset(&cbai, 0, sizeof(cbai));
    cbai.sType = 40; cbai.commandPool = cpool; cbai.level = 0; cbai.commandBufferCount = 1;
    rc = (int)d_alloc_cbufs(g_device, &cbai, &cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferBeginInfo cbbi; memset(&cbbi, 0, sizeof(cbbi));
    cbbi.sType = 42;
    rc = (int)d_begin_cbuf(cbuf, &cbbi);
    if (rc != 0) { out_rc = rc; goto done; }
    d_cmd_bind_pipeline(cbuf, 1, pipe);
    d_cmd_bind_dsets(cbuf, 1, pl, 0, 1, &dset, 0, NULL);
    d_cmd_push(cbuf, pl, 0x20u, 0, push_size, push);
    d_cmd_dispatch(cbuf, 1, 1, 1);
    rc = (int)d_end_cbuf(cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkSubmitInfo si; memset(&si, 0, sizeof(si));
    si.sType = 4; si.commandBufferCount = 1; si.pCommandBuffers = &cbuf;
    rc = (int)d_queue_submit(g_queue, 1, &si, NULL);
    if (rc != 0) { out_rc = rc; goto done; }
    rc = (int)d_queue_wait_idle(g_queue);
    if (rc != 0) { out_rc = rc; goto done; }
    *counter += 1;
    out_rc = 0;
done:
    if (cpool != NULL) { d_destroy_cpool(g_device, cpool, NULL); }
    if (dpool != NULL) { d_destroy_dpool(g_device, dpool, NULL); }
    if (pipe != NULL) { d_destroy_pipeline(g_device, pipe, NULL); }
    if (pl != NULL) { d_destroy_pl(g_device, pl, NULL); }
    if (dsl != NULL) { d_destroy_dsl(g_device, dsl, NULL); }
    if (shader != NULL) { d_destroy_shader_module(g_device, shader, NULL); }
    return out_rc;
}
static uint64_t g_sampling_greedy_dispatches = 0;
uint64_t aesir_vk_sampling_greedy_dispatch_count(void) { return g_sampling_greedy_dispatches; }
int aesir_vk_buffer_sampling_greedy(uint64_t id_logits, uint64_t id_out, uint32_t n) {
    struct { uint32_t n; } push;
    push.n = n;
    return vk_sampling_dispatch(kSamplingGreedySpv, kSamplingGreedySpvBytes, id_logits, id_out, n, &push, 4u, &g_sampling_greedy_dispatches);
}
static uint64_t g_sampling_sample_dispatches = 0;
uint64_t aesir_vk_sampling_sample_dispatch_count(void) { return g_sampling_sample_dispatches; }
int aesir_vk_buffer_sampling_sample(uint64_t id_logits, uint64_t id_out, uint32_t n, uint32_t top_k, float temperature, float u) {
    if (!(temperature > 0.0f) || u < 0.0f || u >= 1.0f) { return AESIR_VK_INVALID; }
    struct { uint32_t n; uint32_t top_k; float temperature; float u; } push;
    push.n = n; push.top_k = top_k; push.temperature = temperature; push.u = u;
    return vk_sampling_dispatch(kSamplingSampleSpv, kSamplingSampleSpvBytes, id_logits, id_out, n, &push, 16u, &g_sampling_sample_dispatches);
}
/* ---- A-059: Vulkan IQ2XXS GEMV (dequant + single-row GEMV) ----
 * SPIR-V below is the verbatim glslangValidator output for
 * aesir_engine/shaders/iq2xxs_gemv.comp (SPIR-V 1.0, 9356 bytes),
 * embedded exactly as A-056 embedded the Q8_0 kernel. The
 * dispatch body mirrors A-056 (same context, slots, submit +
 * wait-idle, counter after completion). */
static uint64_t g_iq2xxs_dispatches = 0;
uint64_t aesir_vk_iq2xxs_dispatch_count(void) { return g_iq2xxs_dispatches; }
int aesir_vk_buffer_iq2xxs_gemv(uint64_t id_w, uint64_t id_x, uint64_t id_y, uint64_t id_g, uint32_t rows, uint32_t cols) {
    int rc = aesir_vk_init();
    if (rc != 0) { return rc; }
    aesir_vk_load_dispatch();
    if (!g_dispatch_ok) { return AESIR_VK_ABSENT; }
    AesirVkBufferSlot *sw = NULL;
    AesirVkBufferSlot *sx = NULL;
    AesirVkBufferSlot *sy = NULL;
    AesirVkBufferSlot *sg = NULL;
    int vrc = vk_own_validate(id_w, 0, &sw);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_x, 0, &sx);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_y, 0, &sy);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_g, 0, &sg);
    if (vrc != 0) { return vrc; }
    if (rows == 0 || cols == 0 || (cols % 256u) != 0) { return AESIR_VK_INVALID; }
    uint64_t need_w = (uint64_t)rows * (uint64_t)(cols / 256u) * 66u;
    uint64_t need_x = (uint64_t)cols * 4u;
    uint64_t need_y = (uint64_t)rows * 4u;
    if (sw->requested_size < need_w || sx->requested_size < need_x || sy->requested_size < need_y) { return AESIR_VK_INVALID; }
    VkShaderModule_t shader = NULL;
    VkDescriptorSetLayout_t dsl = NULL;
    VkPipelineLayout_t pl = NULL;
    VkPipeline_t pipe = NULL;
    VkDescriptorPool_t dpool = NULL;
    VkDescriptorSet_t dset = NULL;
    VkCommandPool_t cpool = NULL;
    VkCommandBuffer_t cbuf = NULL;
    int out_rc = 0;
    AesirVkShaderModuleCreateInfo smci; memset(&smci, 0, sizeof(smci));
    smci.sType = 16; smci.codeSize = kIq2XxsGemvSpvBytes; smci.pCode = kIq2XxsGemvSpv;
    rc = (int)d_create_shader_module(g_device, &smci, NULL, &shader);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetLayoutBinding binds[4]; memset(binds, 0, sizeof(binds));
    for (int i = 0; i < 4; i++) { binds[i].binding = (uint32_t)i; binds[i].descriptorType = 6; binds[i].descriptorCount = 1; binds[i].stageFlags = 0x20u; }
    AesirVkDescriptorSetLayoutCreateInfo dslci; memset(&dslci, 0, sizeof(dslci));
    dslci.sType = 32; dslci.bindingCount = 4; dslci.pBindings = binds;
    rc = (int)d_create_dsl(g_device, &dslci, NULL, &dsl);
    if (rc != 0) { out_rc = rc; goto done; }
    struct { uint32_t cols; uint32_t rows; } push;
    push.cols = cols; push.rows = rows;
    AesirVkPushConstantRange pcr; memset(&pcr, 0, sizeof(pcr));
    pcr.stageFlags = 0x20u; pcr.offset = 0; pcr.size = 8;
    AesirVkPipelineLayoutCreateInfo plci; memset(&plci, 0, sizeof(plci));
    plci.sType = 30; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
    rc = (int)d_create_pl(g_device, &plci, NULL, &pl);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkComputePipelineCreateInfo cpci; memset(&cpci, 0, sizeof(cpci));
    cpci.sType = 29; cpci.stage.sType = 18; cpci.stage.stage = 0x20u; cpci.stage.module = shader; cpci.stage.pName = "main"; cpci.layout = pl; cpci.basePipelineIndex = -1;
    rc = (int)d_create_cp(g_device, NULL, 1, &cpci, NULL, &pipe);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorPoolSize psz; memset(&psz, 0, sizeof(psz));
    psz.type = 6; psz.descriptorCount = 4;
    AesirVkDescriptorPoolCreateInfo dpci; memset(&dpci, 0, sizeof(dpci));
    dpci.sType = 33; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &psz;
    rc = (int)d_create_dpool(g_device, &dpci, NULL, &dpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetAllocateInfo dsai; memset(&dsai, 0, sizeof(dsai));
    dsai.sType = 34; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
    rc = (int)d_alloc_dsets(g_device, &dsai, &dset);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorBufferInfo dbi[4]; memset(dbi, 0, sizeof(dbi));
    dbi[0].buffer = sw->buffer; dbi[0].range = need_w;
    dbi[1].buffer = sx->buffer; dbi[1].range = need_x;
    dbi[2].buffer = sy->buffer; dbi[2].range = need_y;
    dbi[3].buffer = sg->buffer; dbi[3].range = sg->requested_size;
    AesirVkWriteDescriptorSet writes[4]; memset(writes, 0, sizeof(writes));
    for (int i = 0; i < 4; i++) { writes[i].sType = 35; writes[i].dstSet = dset; writes[i].dstBinding = (uint32_t)i; writes[i].descriptorCount = 1; writes[i].descriptorType = 6; writes[i].pBufferInfo = &dbi[i]; }
    d_update_dsets(g_device, 4, writes, 0, NULL);
    AesirVkCommandPoolCreateInfo cpi; memset(&cpi, 0, sizeof(cpi));
    cpi.sType = 39; cpi.queueFamilyIndex = g_queue_family;
    rc = (int)d_create_cpool(g_device, &cpi, NULL, &cpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferAllocateInfo cbai; memset(&cbai, 0, sizeof(cbai));
    cbai.sType = 40; cbai.commandPool = cpool; cbai.level = 0; cbai.commandBufferCount = 1;
    rc = (int)d_alloc_cbufs(g_device, &cbai, &cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferBeginInfo cbbi; memset(&cbbi, 0, sizeof(cbbi));
    cbbi.sType = 42;
    rc = (int)d_begin_cbuf(cbuf, &cbbi);
    if (rc != 0) { out_rc = rc; goto done; }
    d_cmd_bind_pipeline(cbuf, 1, pipe);
    d_cmd_bind_dsets(cbuf, 1, pl, 0, 1, &dset, 0, NULL);
    d_cmd_push(cbuf, pl, 0x20u, 0, 8, &push);
    d_cmd_dispatch(cbuf, rows, 1, 1);
    rc = (int)d_end_cbuf(cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkSubmitInfo si; memset(&si, 0, sizeof(si));
    si.sType = 4; si.commandBufferCount = 1; si.pCommandBuffers = &cbuf;
    rc = (int)d_queue_submit(g_queue, 1, &si, NULL);
    if (rc != 0) { out_rc = rc; goto done; }
    rc = (int)d_queue_wait_idle(g_queue);
    if (rc != 0) { out_rc = rc; goto done; }
    g_iq2xxs_dispatches += 1;
    out_rc = 0;
done:
    if (cpool != NULL) { d_destroy_cpool(g_device, cpool, NULL); }
    if (dpool != NULL) { d_destroy_dpool(g_device, dpool, NULL); }
    if (pipe != NULL) { d_destroy_pipeline(g_device, pipe, NULL); }
    if (pl != NULL) { d_destroy_pl(g_device, pl, NULL); }
    if (dsl != NULL) { d_destroy_dsl(g_device, dsl, NULL); }
    if (shader != NULL) { d_destroy_shader_module(g_device, shader, NULL); }
    return out_rc;
}

/* ---- A-059: Vulkan IQ1S GEMV (dequant + single-row GEMV) ----
 * SPIR-V below is the verbatim glslangValidator output for
 * aesir_engine/shaders/iq1s_gemv.comp (SPIR-V 1.0, 8216 bytes),
 * embedded exactly as A-056 embedded the Q8_0 kernel. The
 * dispatch body mirrors A-056 (same context, slots, submit +
 * wait-idle, counter after completion). */
static uint64_t g_iq1s_dispatches = 0;
uint64_t aesir_vk_iq1s_dispatch_count(void) { return g_iq1s_dispatches; }
int aesir_vk_buffer_iq1s_gemv(uint64_t id_w, uint64_t id_x, uint64_t id_y, uint64_t id_g, uint32_t rows, uint32_t cols) {
    int rc = aesir_vk_init();
    if (rc != 0) { return rc; }
    aesir_vk_load_dispatch();
    if (!g_dispatch_ok) { return AESIR_VK_ABSENT; }
    AesirVkBufferSlot *sw = NULL;
    AesirVkBufferSlot *sx = NULL;
    AesirVkBufferSlot *sy = NULL;
    AesirVkBufferSlot *sg = NULL;
    int vrc = vk_own_validate(id_w, 0, &sw);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_x, 0, &sx);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_y, 0, &sy);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_g, 0, &sg);
    if (vrc != 0) { return vrc; }
    if (rows == 0 || cols == 0 || (cols % 256u) != 0) { return AESIR_VK_INVALID; }
    uint64_t need_w = (uint64_t)rows * (uint64_t)(cols / 256u) * 50u;
    uint64_t need_x = (uint64_t)cols * 4u;
    uint64_t need_y = (uint64_t)rows * 4u;
    if (sw->requested_size < need_w || sx->requested_size < need_x || sy->requested_size < need_y) { return AESIR_VK_INVALID; }
    VkShaderModule_t shader = NULL;
    VkDescriptorSetLayout_t dsl = NULL;
    VkPipelineLayout_t pl = NULL;
    VkPipeline_t pipe = NULL;
    VkDescriptorPool_t dpool = NULL;
    VkDescriptorSet_t dset = NULL;
    VkCommandPool_t cpool = NULL;
    VkCommandBuffer_t cbuf = NULL;
    int out_rc = 0;
    AesirVkShaderModuleCreateInfo smci; memset(&smci, 0, sizeof(smci));
    smci.sType = 16; smci.codeSize = kIq1SGemvSpvBytes; smci.pCode = kIq1SGemvSpv;
    rc = (int)d_create_shader_module(g_device, &smci, NULL, &shader);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetLayoutBinding binds[4]; memset(binds, 0, sizeof(binds));
    for (int i = 0; i < 4; i++) { binds[i].binding = (uint32_t)i; binds[i].descriptorType = 6; binds[i].descriptorCount = 1; binds[i].stageFlags = 0x20u; }
    AesirVkDescriptorSetLayoutCreateInfo dslci; memset(&dslci, 0, sizeof(dslci));
    dslci.sType = 32; dslci.bindingCount = 4; dslci.pBindings = binds;
    rc = (int)d_create_dsl(g_device, &dslci, NULL, &dsl);
    if (rc != 0) { out_rc = rc; goto done; }
    struct { uint32_t cols; uint32_t rows; } push;
    push.cols = cols; push.rows = rows;
    AesirVkPushConstantRange pcr; memset(&pcr, 0, sizeof(pcr));
    pcr.stageFlags = 0x20u; pcr.offset = 0; pcr.size = 8;
    AesirVkPipelineLayoutCreateInfo plci; memset(&plci, 0, sizeof(plci));
    plci.sType = 30; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
    rc = (int)d_create_pl(g_device, &plci, NULL, &pl);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkComputePipelineCreateInfo cpci; memset(&cpci, 0, sizeof(cpci));
    cpci.sType = 29; cpci.stage.sType = 18; cpci.stage.stage = 0x20u; cpci.stage.module = shader; cpci.stage.pName = "main"; cpci.layout = pl; cpci.basePipelineIndex = -1;
    rc = (int)d_create_cp(g_device, NULL, 1, &cpci, NULL, &pipe);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorPoolSize psz; memset(&psz, 0, sizeof(psz));
    psz.type = 6; psz.descriptorCount = 4;
    AesirVkDescriptorPoolCreateInfo dpci; memset(&dpci, 0, sizeof(dpci));
    dpci.sType = 33; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &psz;
    rc = (int)d_create_dpool(g_device, &dpci, NULL, &dpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetAllocateInfo dsai; memset(&dsai, 0, sizeof(dsai));
    dsai.sType = 34; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
    rc = (int)d_alloc_dsets(g_device, &dsai, &dset);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorBufferInfo dbi[4]; memset(dbi, 0, sizeof(dbi));
    dbi[0].buffer = sw->buffer; dbi[0].range = need_w;
    dbi[1].buffer = sx->buffer; dbi[1].range = need_x;
    dbi[2].buffer = sy->buffer; dbi[2].range = need_y;
    dbi[3].buffer = sg->buffer; dbi[3].range = sg->requested_size;
    AesirVkWriteDescriptorSet writes[4]; memset(writes, 0, sizeof(writes));
    for (int i = 0; i < 4; i++) { writes[i].sType = 35; writes[i].dstSet = dset; writes[i].dstBinding = (uint32_t)i; writes[i].descriptorCount = 1; writes[i].descriptorType = 6; writes[i].pBufferInfo = &dbi[i]; }
    d_update_dsets(g_device, 4, writes, 0, NULL);
    AesirVkCommandPoolCreateInfo cpi; memset(&cpi, 0, sizeof(cpi));
    cpi.sType = 39; cpi.queueFamilyIndex = g_queue_family;
    rc = (int)d_create_cpool(g_device, &cpi, NULL, &cpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferAllocateInfo cbai; memset(&cbai, 0, sizeof(cbai));
    cbai.sType = 40; cbai.commandPool = cpool; cbai.level = 0; cbai.commandBufferCount = 1;
    rc = (int)d_alloc_cbufs(g_device, &cbai, &cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferBeginInfo cbbi; memset(&cbbi, 0, sizeof(cbbi));
    cbbi.sType = 42;
    rc = (int)d_begin_cbuf(cbuf, &cbbi);
    if (rc != 0) { out_rc = rc; goto done; }
    d_cmd_bind_pipeline(cbuf, 1, pipe);
    d_cmd_bind_dsets(cbuf, 1, pl, 0, 1, &dset, 0, NULL);
    d_cmd_push(cbuf, pl, 0x20u, 0, 8, &push);
    d_cmd_dispatch(cbuf, rows, 1, 1);
    rc = (int)d_end_cbuf(cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkSubmitInfo si; memset(&si, 0, sizeof(si));
    si.sType = 4; si.commandBufferCount = 1; si.pCommandBuffers = &cbuf;
    rc = (int)d_queue_submit(g_queue, 1, &si, NULL);
    if (rc != 0) { out_rc = rc; goto done; }
    rc = (int)d_queue_wait_idle(g_queue);
    if (rc != 0) { out_rc = rc; goto done; }
    g_iq1s_dispatches += 1;
    out_rc = 0;
done:
    if (cpool != NULL) { d_destroy_cpool(g_device, cpool, NULL); }
    if (dpool != NULL) { d_destroy_dpool(g_device, dpool, NULL); }
    if (pipe != NULL) { d_destroy_pipeline(g_device, pipe, NULL); }
    if (pl != NULL) { d_destroy_pl(g_device, pl, NULL); }
    if (dsl != NULL) { d_destroy_dsl(g_device, dsl, NULL); }
    if (shader != NULL) { d_destroy_shader_module(g_device, shader, NULL); }
    return out_rc;
}

/* ---- A-059: Vulkan IQ3XXS GEMV (dequant + single-row GEMV) ----
 * SPIR-V below is the verbatim glslangValidator output for
 * aesir_engine/shaders/iq3xxs_gemv.comp (SPIR-V 1.0, 9544 bytes),
 * embedded exactly as A-056 embedded the Q8_0 kernel. The
 * dispatch body mirrors A-056 (same context, slots, submit +
 * wait-idle, counter after completion). */
static uint64_t g_iq3xxs_dispatches = 0;
uint64_t aesir_vk_iq3xxs_dispatch_count(void) { return g_iq3xxs_dispatches; }
int aesir_vk_buffer_iq3xxs_gemv(uint64_t id_w, uint64_t id_x, uint64_t id_y, uint64_t id_g, uint32_t rows, uint32_t cols) {
    int rc = aesir_vk_init();
    if (rc != 0) { return rc; }
    aesir_vk_load_dispatch();
    if (!g_dispatch_ok) { return AESIR_VK_ABSENT; }
    AesirVkBufferSlot *sw = NULL;
    AesirVkBufferSlot *sx = NULL;
    AesirVkBufferSlot *sy = NULL;
    AesirVkBufferSlot *sg = NULL;
    int vrc = vk_own_validate(id_w, 0, &sw);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_x, 0, &sx);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_y, 0, &sy);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_g, 0, &sg);
    if (vrc != 0) { return vrc; }
    if (rows == 0 || cols == 0 || (cols % 256u) != 0) { return AESIR_VK_INVALID; }
    uint64_t need_w = (uint64_t)rows * (uint64_t)(cols / 256u) * 98u;
    uint64_t need_x = (uint64_t)cols * 4u;
    uint64_t need_y = (uint64_t)rows * 4u;
    if (sw->requested_size < need_w || sx->requested_size < need_x || sy->requested_size < need_y) { return AESIR_VK_INVALID; }
    VkShaderModule_t shader = NULL;
    VkDescriptorSetLayout_t dsl = NULL;
    VkPipelineLayout_t pl = NULL;
    VkPipeline_t pipe = NULL;
    VkDescriptorPool_t dpool = NULL;
    VkDescriptorSet_t dset = NULL;
    VkCommandPool_t cpool = NULL;
    VkCommandBuffer_t cbuf = NULL;
    int out_rc = 0;
    AesirVkShaderModuleCreateInfo smci; memset(&smci, 0, sizeof(smci));
    smci.sType = 16; smci.codeSize = kIq3XxsGemvSpvBytes; smci.pCode = kIq3XxsGemvSpv;
    rc = (int)d_create_shader_module(g_device, &smci, NULL, &shader);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetLayoutBinding binds[4]; memset(binds, 0, sizeof(binds));
    for (int i = 0; i < 4; i++) { binds[i].binding = (uint32_t)i; binds[i].descriptorType = 6; binds[i].descriptorCount = 1; binds[i].stageFlags = 0x20u; }
    AesirVkDescriptorSetLayoutCreateInfo dslci; memset(&dslci, 0, sizeof(dslci));
    dslci.sType = 32; dslci.bindingCount = 4; dslci.pBindings = binds;
    rc = (int)d_create_dsl(g_device, &dslci, NULL, &dsl);
    if (rc != 0) { out_rc = rc; goto done; }
    struct { uint32_t cols; uint32_t rows; } push;
    push.cols = cols; push.rows = rows;
    AesirVkPushConstantRange pcr; memset(&pcr, 0, sizeof(pcr));
    pcr.stageFlags = 0x20u; pcr.offset = 0; pcr.size = 8;
    AesirVkPipelineLayoutCreateInfo plci; memset(&plci, 0, sizeof(plci));
    plci.sType = 30; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
    rc = (int)d_create_pl(g_device, &plci, NULL, &pl);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkComputePipelineCreateInfo cpci; memset(&cpci, 0, sizeof(cpci));
    cpci.sType = 29; cpci.stage.sType = 18; cpci.stage.stage = 0x20u; cpci.stage.module = shader; cpci.stage.pName = "main"; cpci.layout = pl; cpci.basePipelineIndex = -1;
    rc = (int)d_create_cp(g_device, NULL, 1, &cpci, NULL, &pipe);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorPoolSize psz; memset(&psz, 0, sizeof(psz));
    psz.type = 6; psz.descriptorCount = 4;
    AesirVkDescriptorPoolCreateInfo dpci; memset(&dpci, 0, sizeof(dpci));
    dpci.sType = 33; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &psz;
    rc = (int)d_create_dpool(g_device, &dpci, NULL, &dpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetAllocateInfo dsai; memset(&dsai, 0, sizeof(dsai));
    dsai.sType = 34; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
    rc = (int)d_alloc_dsets(g_device, &dsai, &dset);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorBufferInfo dbi[4]; memset(dbi, 0, sizeof(dbi));
    dbi[0].buffer = sw->buffer; dbi[0].range = need_w;
    dbi[1].buffer = sx->buffer; dbi[1].range = need_x;
    dbi[2].buffer = sy->buffer; dbi[2].range = need_y;
    dbi[3].buffer = sg->buffer; dbi[3].range = sg->requested_size;
    AesirVkWriteDescriptorSet writes[4]; memset(writes, 0, sizeof(writes));
    for (int i = 0; i < 4; i++) { writes[i].sType = 35; writes[i].dstSet = dset; writes[i].dstBinding = (uint32_t)i; writes[i].descriptorCount = 1; writes[i].descriptorType = 6; writes[i].pBufferInfo = &dbi[i]; }
    d_update_dsets(g_device, 4, writes, 0, NULL);
    AesirVkCommandPoolCreateInfo cpi; memset(&cpi, 0, sizeof(cpi));
    cpi.sType = 39; cpi.queueFamilyIndex = g_queue_family;
    rc = (int)d_create_cpool(g_device, &cpi, NULL, &cpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferAllocateInfo cbai; memset(&cbai, 0, sizeof(cbai));
    cbai.sType = 40; cbai.commandPool = cpool; cbai.level = 0; cbai.commandBufferCount = 1;
    rc = (int)d_alloc_cbufs(g_device, &cbai, &cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferBeginInfo cbbi; memset(&cbbi, 0, sizeof(cbbi));
    cbbi.sType = 42;
    rc = (int)d_begin_cbuf(cbuf, &cbbi);
    if (rc != 0) { out_rc = rc; goto done; }
    d_cmd_bind_pipeline(cbuf, 1, pipe);
    d_cmd_bind_dsets(cbuf, 1, pl, 0, 1, &dset, 0, NULL);
    d_cmd_push(cbuf, pl, 0x20u, 0, 8, &push);
    d_cmd_dispatch(cbuf, rows, 1, 1);
    rc = (int)d_end_cbuf(cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkSubmitInfo si; memset(&si, 0, sizeof(si));
    si.sType = 4; si.commandBufferCount = 1; si.pCommandBuffers = &cbuf;
    rc = (int)d_queue_submit(g_queue, 1, &si, NULL);
    if (rc != 0) { out_rc = rc; goto done; }
    rc = (int)d_queue_wait_idle(g_queue);
    if (rc != 0) { out_rc = rc; goto done; }
    g_iq3xxs_dispatches += 1;
    out_rc = 0;
done:
    if (cpool != NULL) { d_destroy_cpool(g_device, cpool, NULL); }
    if (dpool != NULL) { d_destroy_dpool(g_device, dpool, NULL); }
    if (pipe != NULL) { d_destroy_pipeline(g_device, pipe, NULL); }
    if (pl != NULL) { d_destroy_pl(g_device, pl, NULL); }
    if (dsl != NULL) { d_destroy_dsl(g_device, dsl, NULL); }
    if (shader != NULL) { d_destroy_shader_module(g_device, shader, NULL); }
    return out_rc;
}

/* ---- A-059: Vulkan IQ4NL GEMV (dequant + single-row GEMV) ----
 * SPIR-V below is the verbatim glslangValidator output for
 * aesir_engine/shaders/iq4nl_gemv.comp (SPIR-V 1.0, 7864 bytes),
 * embedded exactly as A-056 embedded the Q8_0 kernel. The
 * dispatch body mirrors A-056 (same context, slots, submit +
 * wait-idle, counter after completion). */
static uint64_t g_iq4nl_dispatches = 0;
uint64_t aesir_vk_iq4nl_dispatch_count(void) { return g_iq4nl_dispatches; }
int aesir_vk_buffer_iq4nl_gemv(uint64_t id_w, uint64_t id_x, uint64_t id_y, uint32_t rows, uint32_t cols) {
    int rc = aesir_vk_init();
    if (rc != 0) { return rc; }
    aesir_vk_load_dispatch();
    if (!g_dispatch_ok) { return AESIR_VK_ABSENT; }
    AesirVkBufferSlot *sw = NULL;
    AesirVkBufferSlot *sx = NULL;
    AesirVkBufferSlot *sy = NULL;
    int vrc = vk_own_validate(id_w, 0, &sw);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_x, 0, &sx);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_y, 0, &sy);
    if (vrc != 0) { return vrc; }
    if (rows == 0 || cols == 0 || (cols % 32u) != 0) { return AESIR_VK_INVALID; }
    uint64_t need_w = (uint64_t)rows * (uint64_t)(cols / 32u) * 18u;
    uint64_t need_x = (uint64_t)cols * 4u;
    uint64_t need_y = (uint64_t)rows * 4u;
    if (sw->requested_size < need_w || sx->requested_size < need_x || sy->requested_size < need_y) { return AESIR_VK_INVALID; }
    VkShaderModule_t shader = NULL;
    VkDescriptorSetLayout_t dsl = NULL;
    VkPipelineLayout_t pl = NULL;
    VkPipeline_t pipe = NULL;
    VkDescriptorPool_t dpool = NULL;
    VkDescriptorSet_t dset = NULL;
    VkCommandPool_t cpool = NULL;
    VkCommandBuffer_t cbuf = NULL;
    int out_rc = 0;
    AesirVkShaderModuleCreateInfo smci; memset(&smci, 0, sizeof(smci));
    smci.sType = 16; smci.codeSize = kIq4NlGemvSpvBytes; smci.pCode = kIq4NlGemvSpv;
    rc = (int)d_create_shader_module(g_device, &smci, NULL, &shader);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetLayoutBinding binds[3]; memset(binds, 0, sizeof(binds));
    for (int i = 0; i < 3; i++) { binds[i].binding = (uint32_t)i; binds[i].descriptorType = 6; binds[i].descriptorCount = 1; binds[i].stageFlags = 0x20u; }
    AesirVkDescriptorSetLayoutCreateInfo dslci; memset(&dslci, 0, sizeof(dslci));
    dslci.sType = 32; dslci.bindingCount = 3; dslci.pBindings = binds;
    rc = (int)d_create_dsl(g_device, &dslci, NULL, &dsl);
    if (rc != 0) { out_rc = rc; goto done; }
    struct { uint32_t cols; uint32_t rows; } push;
    push.cols = cols; push.rows = rows;
    AesirVkPushConstantRange pcr; memset(&pcr, 0, sizeof(pcr));
    pcr.stageFlags = 0x20u; pcr.offset = 0; pcr.size = 8;
    AesirVkPipelineLayoutCreateInfo plci; memset(&plci, 0, sizeof(plci));
    plci.sType = 30; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
    rc = (int)d_create_pl(g_device, &plci, NULL, &pl);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkComputePipelineCreateInfo cpci; memset(&cpci, 0, sizeof(cpci));
    cpci.sType = 29; cpci.stage.sType = 18; cpci.stage.stage = 0x20u; cpci.stage.module = shader; cpci.stage.pName = "main"; cpci.layout = pl; cpci.basePipelineIndex = -1;
    rc = (int)d_create_cp(g_device, NULL, 1, &cpci, NULL, &pipe);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorPoolSize psz; memset(&psz, 0, sizeof(psz));
    psz.type = 6; psz.descriptorCount = 3;
    AesirVkDescriptorPoolCreateInfo dpci; memset(&dpci, 0, sizeof(dpci));
    dpci.sType = 33; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &psz;
    rc = (int)d_create_dpool(g_device, &dpci, NULL, &dpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetAllocateInfo dsai; memset(&dsai, 0, sizeof(dsai));
    dsai.sType = 34; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
    rc = (int)d_alloc_dsets(g_device, &dsai, &dset);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorBufferInfo dbi[3]; memset(dbi, 0, sizeof(dbi));
    dbi[0].buffer = sw->buffer; dbi[0].range = need_w;
    dbi[1].buffer = sx->buffer; dbi[1].range = need_x;
    dbi[2].buffer = sy->buffer; dbi[2].range = need_y;
    AesirVkWriteDescriptorSet writes[3]; memset(writes, 0, sizeof(writes));
    for (int i = 0; i < 3; i++) { writes[i].sType = 35; writes[i].dstSet = dset; writes[i].dstBinding = (uint32_t)i; writes[i].descriptorCount = 1; writes[i].descriptorType = 6; writes[i].pBufferInfo = &dbi[i]; }
    d_update_dsets(g_device, 3, writes, 0, NULL);
    AesirVkCommandPoolCreateInfo cpi; memset(&cpi, 0, sizeof(cpi));
    cpi.sType = 39; cpi.queueFamilyIndex = g_queue_family;
    rc = (int)d_create_cpool(g_device, &cpi, NULL, &cpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferAllocateInfo cbai; memset(&cbai, 0, sizeof(cbai));
    cbai.sType = 40; cbai.commandPool = cpool; cbai.level = 0; cbai.commandBufferCount = 1;
    rc = (int)d_alloc_cbufs(g_device, &cbai, &cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferBeginInfo cbbi; memset(&cbbi, 0, sizeof(cbbi));
    cbbi.sType = 42;
    rc = (int)d_begin_cbuf(cbuf, &cbbi);
    if (rc != 0) { out_rc = rc; goto done; }
    d_cmd_bind_pipeline(cbuf, 1, pipe);
    d_cmd_bind_dsets(cbuf, 1, pl, 0, 1, &dset, 0, NULL);
    d_cmd_push(cbuf, pl, 0x20u, 0, 8, &push);
    d_cmd_dispatch(cbuf, rows, 1, 1);
    rc = (int)d_end_cbuf(cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkSubmitInfo si; memset(&si, 0, sizeof(si));
    si.sType = 4; si.commandBufferCount = 1; si.pCommandBuffers = &cbuf;
    rc = (int)d_queue_submit(g_queue, 1, &si, NULL);
    if (rc != 0) { out_rc = rc; goto done; }
    rc = (int)d_queue_wait_idle(g_queue);
    if (rc != 0) { out_rc = rc; goto done; }
    g_iq4nl_dispatches += 1;
    out_rc = 0;
done:
    if (cpool != NULL) { d_destroy_cpool(g_device, cpool, NULL); }
    if (dpool != NULL) { d_destroy_dpool(g_device, dpool, NULL); }
    if (pipe != NULL) { d_destroy_pipeline(g_device, pipe, NULL); }
    if (pl != NULL) { d_destroy_pl(g_device, pl, NULL); }
    if (dsl != NULL) { d_destroy_dsl(g_device, dsl, NULL); }
    if (shader != NULL) { d_destroy_shader_module(g_device, shader, NULL); }
    return out_rc;
}


/* ---- A-060: Vulkan RMSNorm + RoPE ----
 *
 * Two SPIR-V kernels from the A-055 build pipeline (sources
 * aesir_engine/shaders/rmsnorm.comp and rope.comp; words taken
 * from the generated header shaders/generated/aesir_shaders_spv.h
 * included above - kRmsnormSpv / kRopeSpv, hashes recorded in
 * aesir_engine/shaders/SHADER_MANIFEST.json). No hand-embedded
 * words, no runtime fetch.
 *
 * RMSNorm: y[row, i] = x[row, i] * rsqrt(mean_i(x[row, i]^2) + eps)
 * * g[i]; one workgroup of 256 invocations per row; push constants
 * {n, rows, eps}. Buffers: x (rows*n f32, read), g (n f32, read),
 * y (rows*n f32, write).
 *
 * RoPE (rotate-half pairing, matching the shader of record and
 * the engine CPU apply_rope neox layout): in place over rows of
 * head_dim f32; pair (i, i + head_dim/2) rotates by
 * position * base^(-2i/head_dim); push constants
 * {head_dim, rows, position, base}; one invocation per pair.
 *
 * Float arguments cross the FFI as IEEE-754 bit patterns
 * (eps_bits / base_bits) so the Mojo side needs no float FFI.
 * Pipeline objects are created per dispatch and destroyed before
 * return, exactly as the A-015/A-056 paths. Each counter
 * increments only after submit + queue-wait-idle completed on
 * the device - the filed device-execution evidence (law 6).
 * Returns 0 on success, the negative VkResult on Vulkan failure,
 * AESIR_VK_ABSENT when a dispatch entry point is missing,
 * AESIR_VK_INVALID for bad ids / sizes. */

static uint64_t g_rmsnorm_dispatches = 0;
uint64_t aesir_vk_rmsnorm_dispatch_count(void) { return g_rmsnorm_dispatches; }
int aesir_vk_buffer_rmsnorm(uint64_t id_x, uint64_t id_g, uint64_t id_y, uint32_t n, uint32_t rows, uint32_t eps_bits) {
    int rc = aesir_vk_init();
    if (rc != 0) { return rc; }
    aesir_vk_load_dispatch();
    if (!g_dispatch_ok) { return AESIR_VK_ABSENT; }
    AesirVkBufferSlot *sx = NULL;
    AesirVkBufferSlot *sg = NULL;
    AesirVkBufferSlot *sy = NULL;
    int vrc = vk_own_validate(id_x, 0, &sx);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_g, 0, &sg);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_y, 0, &sy);
    if (vrc != 0) { return vrc; }
    if (n == 0 || rows == 0) { return AESIR_VK_INVALID; }
    uint64_t need_x = (uint64_t)rows * (uint64_t)n * 4u;
    uint64_t need_g = (uint64_t)n * 4u;
    uint64_t need_y = (uint64_t)rows * (uint64_t)n * 4u;
    if (sx->requested_size < need_x || sg->requested_size < need_g || sy->requested_size < need_y) { return AESIR_VK_INVALID; }
    VkShaderModule_t shader = NULL;
    VkDescriptorSetLayout_t dsl = NULL;
    VkPipelineLayout_t pl = NULL;
    VkPipeline_t pipe = NULL;
    VkDescriptorPool_t dpool = NULL;
    VkDescriptorSet_t dset = NULL;
    VkCommandPool_t cpool = NULL;
    VkCommandBuffer_t cbuf = NULL;
    int out_rc = 0;
    AesirVkShaderModuleCreateInfo smci; memset(&smci, 0, sizeof(smci));
    smci.sType = 16; smci.codeSize = kRmsnormSpvBytes; smci.pCode = kRmsnormSpv;
    rc = (int)d_create_shader_module(g_device, &smci, NULL, &shader);
    if (rc != 0) { out_rc = rc; goto done_rn; }
    AesirVkDescriptorSetLayoutBinding binds[3]; memset(binds, 0, sizeof(binds));
    for (int i = 0; i < 3; i++) { binds[i].binding = (uint32_t)i; binds[i].descriptorType = 6; binds[i].descriptorCount = 1; binds[i].stageFlags = 0x20u; }
    AesirVkDescriptorSetLayoutCreateInfo dslci; memset(&dslci, 0, sizeof(dslci));
    dslci.sType = 32; dslci.bindingCount = 3; dslci.pBindings = binds;
    rc = (int)d_create_dsl(g_device, &dslci, NULL, &dsl);
    if (rc != 0) { out_rc = rc; goto done_rn; }
    struct { uint32_t n; uint32_t rows; float eps; } push;
    push.n = n; push.rows = rows;
    { float e; uint32_t b = eps_bits; memcpy(&e, &b, 4); push.eps = e; }
    AesirVkPushConstantRange pcr; memset(&pcr, 0, sizeof(pcr));
    pcr.stageFlags = 0x20u; pcr.offset = 0; pcr.size = 12;
    AesirVkPipelineLayoutCreateInfo plci; memset(&plci, 0, sizeof(plci));
    plci.sType = 30; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
    rc = (int)d_create_pl(g_device, &plci, NULL, &pl);
    if (rc != 0) { out_rc = rc; goto done_rn; }
    AesirVkComputePipelineCreateInfo cpci; memset(&cpci, 0, sizeof(cpci));
    cpci.sType = 29; cpci.stage.sType = 18; cpci.stage.stage = 0x20u; cpci.stage.module = shader; cpci.stage.pName = "main"; cpci.layout = pl; cpci.basePipelineIndex = -1;
    rc = (int)d_create_cp(g_device, NULL, 1, &cpci, NULL, &pipe);
    if (rc != 0) { out_rc = rc; goto done_rn; }
    AesirVkDescriptorPoolSize psz; memset(&psz, 0, sizeof(psz));
    psz.type = 6; psz.descriptorCount = 3;
    AesirVkDescriptorPoolCreateInfo dpci; memset(&dpci, 0, sizeof(dpci));
    dpci.sType = 33; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &psz;
    rc = (int)d_create_dpool(g_device, &dpci, NULL, &dpool);
    if (rc != 0) { out_rc = rc; goto done_rn; }
    AesirVkDescriptorSetAllocateInfo dsai; memset(&dsai, 0, sizeof(dsai));
    dsai.sType = 34; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
    rc = (int)d_alloc_dsets(g_device, &dsai, &dset);
    if (rc != 0) { out_rc = rc; goto done_rn; }
    AesirVkDescriptorBufferInfo dbi[3]; memset(dbi, 0, sizeof(dbi));
    dbi[0].buffer = sx->buffer; dbi[0].range = need_x;
    dbi[1].buffer = sg->buffer; dbi[1].range = need_g;
    dbi[2].buffer = sy->buffer; dbi[2].range = need_y;
    AesirVkWriteDescriptorSet writes[3]; memset(writes, 0, sizeof(writes));
    for (int i = 0; i < 3; i++) { writes[i].sType = 35; writes[i].dstSet = dset; writes[i].dstBinding = (uint32_t)i; writes[i].descriptorCount = 1; writes[i].descriptorType = 6; writes[i].pBufferInfo = &dbi[i]; }
    d_update_dsets(g_device, 3, writes, 0, NULL);
    AesirVkCommandPoolCreateInfo cpi; memset(&cpi, 0, sizeof(cpi));
    cpi.sType = 39; cpi.queueFamilyIndex = g_queue_family;
    rc = (int)d_create_cpool(g_device, &cpi, NULL, &cpool);
    if (rc != 0) { out_rc = rc; goto done_rn; }
    AesirVkCommandBufferAllocateInfo cbai; memset(&cbai, 0, sizeof(cbai));
    cbai.sType = 40; cbai.commandPool = cpool; cbai.level = 0; cbai.commandBufferCount = 1;
    rc = (int)d_alloc_cbufs(g_device, &cbai, &cbuf);
    if (rc != 0) { out_rc = rc; goto done_rn; }
    AesirVkCommandBufferBeginInfo cbbi; memset(&cbbi, 0, sizeof(cbbi));
    cbbi.sType = 42;
    rc = (int)d_begin_cbuf(cbuf, &cbbi);
    if (rc != 0) { out_rc = rc; goto done_rn; }
    d_cmd_bind_pipeline(cbuf, 1, pipe);
    d_cmd_bind_dsets(cbuf, 1, pl, 0, 1, &dset, 0, NULL);
    d_cmd_push(cbuf, pl, 0x20u, 0, 12, &push);
    d_cmd_dispatch(cbuf, rows, 1, 1);
    rc = (int)d_end_cbuf(cbuf);
    if (rc != 0) { out_rc = rc; goto done_rn; }
    AesirVkSubmitInfo si; memset(&si, 0, sizeof(si));
    si.sType = 4; si.commandBufferCount = 1; si.pCommandBuffers = &cbuf;
    rc = (int)d_queue_submit(g_queue, 1, &si, NULL);
    if (rc != 0) { out_rc = rc; goto done_rn; }
    rc = (int)d_queue_wait_idle(g_queue);
    if (rc != 0) { out_rc = rc; goto done_rn; }
    g_rmsnorm_dispatches += 1;
    out_rc = 0;
done_rn:
    if (cpool != NULL) { d_destroy_cpool(g_device, cpool, NULL); }
    if (dpool != NULL) { d_destroy_dpool(g_device, dpool, NULL); }
    if (pipe != NULL) { d_destroy_pipeline(g_device, pipe, NULL); }
    if (pl != NULL) { d_destroy_pl(g_device, pl, NULL); }
    if (dsl != NULL) { d_destroy_dsl(g_device, dsl, NULL); }
    if (shader != NULL) { d_destroy_shader_module(g_device, shader, NULL); }
    return out_rc;
}

static uint64_t g_rope_dispatches = 0;
uint64_t aesir_vk_rope_dispatch_count(void) { return g_rope_dispatches; }
int aesir_vk_buffer_rope(uint64_t id_x, uint32_t head_dim, uint32_t rows, uint32_t position, uint32_t base_bits) {
    int rc = aesir_vk_init();
    if (rc != 0) { return rc; }
    aesir_vk_load_dispatch();
    if (!g_dispatch_ok) { return AESIR_VK_ABSENT; }
    AesirVkBufferSlot *sx = NULL;
    int vrc = vk_own_validate(id_x, 0, &sx);
    if (vrc != 0) { return vrc; }
    if (head_dim == 0 || (head_dim % 2u) != 0 || rows == 0) { return AESIR_VK_INVALID; }
    uint64_t need_x = (uint64_t)rows * (uint64_t)head_dim * 4u;
    if (sx->requested_size < need_x) { return AESIR_VK_INVALID; }
    VkShaderModule_t shader = NULL;
    VkDescriptorSetLayout_t dsl = NULL;
    VkPipelineLayout_t pl = NULL;
    VkPipeline_t pipe = NULL;
    VkDescriptorPool_t dpool = NULL;
    VkDescriptorSet_t dset = NULL;
    VkCommandPool_t cpool = NULL;
    VkCommandBuffer_t cbuf = NULL;
    int out_rc = 0;
    AesirVkShaderModuleCreateInfo smci; memset(&smci, 0, sizeof(smci));
    smci.sType = 16; smci.codeSize = kRopeSpvBytes; smci.pCode = kRopeSpv;
    rc = (int)d_create_shader_module(g_device, &smci, NULL, &shader);
    if (rc != 0) { out_rc = rc; goto done_rp; }
    AesirVkDescriptorSetLayoutBinding binds[1]; memset(binds, 0, sizeof(binds));
    binds[0].binding = 0; binds[0].descriptorType = 6; binds[0].descriptorCount = 1; binds[0].stageFlags = 0x20u;
    AesirVkDescriptorSetLayoutCreateInfo dslci; memset(&dslci, 0, sizeof(dslci));
    dslci.sType = 32; dslci.bindingCount = 1; dslci.pBindings = binds;
    rc = (int)d_create_dsl(g_device, &dslci, NULL, &dsl);
    if (rc != 0) { out_rc = rc; goto done_rp; }
    struct { uint32_t head_dim; uint32_t rows; uint32_t position; float base; } push;
    push.head_dim = head_dim; push.rows = rows; push.position = position;
    { float b; uint32_t bits = base_bits; memcpy(&b, &bits, 4); push.base = b; }
    AesirVkPushConstantRange pcr; memset(&pcr, 0, sizeof(pcr));
    pcr.stageFlags = 0x20u; pcr.offset = 0; pcr.size = 16;
    AesirVkPipelineLayoutCreateInfo plci; memset(&plci, 0, sizeof(plci));
    plci.sType = 30; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
    rc = (int)d_create_pl(g_device, &plci, NULL, &pl);
    if (rc != 0) { out_rc = rc; goto done_rp; }
    AesirVkComputePipelineCreateInfo cpci; memset(&cpci, 0, sizeof(cpci));
    cpci.sType = 29; cpci.stage.sType = 18; cpci.stage.stage = 0x20u; cpci.stage.module = shader; cpci.stage.pName = "main"; cpci.layout = pl; cpci.basePipelineIndex = -1;
    rc = (int)d_create_cp(g_device, NULL, 1, &cpci, NULL, &pipe);
    if (rc != 0) { out_rc = rc; goto done_rp; }
    AesirVkDescriptorPoolSize psz; memset(&psz, 0, sizeof(psz));
    psz.type = 6; psz.descriptorCount = 1;
    AesirVkDescriptorPoolCreateInfo dpci; memset(&dpci, 0, sizeof(dpci));
    dpci.sType = 33; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &psz;
    rc = (int)d_create_dpool(g_device, &dpci, NULL, &dpool);
    if (rc != 0) { out_rc = rc; goto done_rp; }
    AesirVkDescriptorSetAllocateInfo dsai; memset(&dsai, 0, sizeof(dsai));
    dsai.sType = 34; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
    rc = (int)d_alloc_dsets(g_device, &dsai, &dset);
    if (rc != 0) { out_rc = rc; goto done_rp; }
    AesirVkDescriptorBufferInfo dbi[1]; memset(dbi, 0, sizeof(dbi));
    dbi[0].buffer = sx->buffer; dbi[0].range = need_x;
    AesirVkWriteDescriptorSet writes[1]; memset(writes, 0, sizeof(writes));
    writes[0].sType = 35; writes[0].dstSet = dset; writes[0].dstBinding = 0; writes[0].descriptorCount = 1; writes[0].descriptorType = 6; writes[0].pBufferInfo = &dbi[0];
    d_update_dsets(g_device, 1, writes, 0, NULL);
    AesirVkCommandPoolCreateInfo cpi; memset(&cpi, 0, sizeof(cpi));
    cpi.sType = 39; cpi.queueFamilyIndex = g_queue_family;
    rc = (int)d_create_cpool(g_device, &cpi, NULL, &cpool);
    if (rc != 0) { out_rc = rc; goto done_rp; }
    AesirVkCommandBufferAllocateInfo cbai; memset(&cbai, 0, sizeof(cbai));
    cbai.sType = 40; cbai.commandPool = cpool; cbai.level = 0; cbai.commandBufferCount = 1;
    rc = (int)d_alloc_cbufs(g_device, &cbai, &cbuf);
    if (rc != 0) { out_rc = rc; goto done_rp; }
    AesirVkCommandBufferBeginInfo cbbi; memset(&cbbi, 0, sizeof(cbbi));
    cbbi.sType = 42;
    rc = (int)d_begin_cbuf(cbuf, &cbbi);
    if (rc != 0) { out_rc = rc; goto done_rp; }
    d_cmd_bind_pipeline(cbuf, 1, pipe);
    d_cmd_bind_dsets(cbuf, 1, pl, 0, 1, &dset, 0, NULL);
    d_cmd_push(cbuf, pl, 0x20u, 0, 16, &push);
    { uint32_t total = rows * (head_dim / 2u); uint32_t groups = (total + 255u) / 256u; d_cmd_dispatch(cbuf, groups, 1, 1); }
    rc = (int)d_end_cbuf(cbuf);
    if (rc != 0) { out_rc = rc; goto done_rp; }
    AesirVkSubmitInfo si; memset(&si, 0, sizeof(si));
    si.sType = 4; si.commandBufferCount = 1; si.pCommandBuffers = &cbuf;
    rc = (int)d_queue_submit(g_queue, 1, &si, NULL);
    if (rc != 0) { out_rc = rc; goto done_rp; }
    rc = (int)d_queue_wait_idle(g_queue);
    if (rc != 0) { out_rc = rc; goto done_rp; }
    g_rope_dispatches += 1;
    out_rc = 0;
done_rp:
    if (cpool != NULL) { d_destroy_cpool(g_device, cpool, NULL); }
    if (dpool != NULL) { d_destroy_dpool(g_device, dpool, NULL); }
    if (pipe != NULL) { d_destroy_pipeline(g_device, pipe, NULL); }
    if (pl != NULL) { d_destroy_pl(g_device, pl, NULL); }
    if (dsl != NULL) { d_destroy_dsl(g_device, dsl, NULL); }
    if (shader != NULL) { d_destroy_shader_module(g_device, shader, NULL); }
    return out_rc;
}

/* ---- A-061: Vulkan elementwise + softmax ----
 *
 * Two SPIR-V kernels from the A-055 build pipeline (sources
 * aesir_engine/shaders/elementwise.comp and softmax.comp; words
 * taken from the generated header
 * shaders/generated/aesir_shaders_spv.h included above -
 * kElementwiseSpv / kSoftmaxSpv, hashes recorded in
 * aesir_engine/shaders/SHADER_MANIFEST.json). No hand-embedded
 * words, no runtime fetch.
 *
 * Elementwise: y[i] = f(a[i], b[i]) selected by push-constant
 * mode: 0 silu(a), 1 a*b, 2 a+b (residual), 3 silu(a)*b
 * (gated SiLU). Push constants {n, mode}; one invocation per
 * element, dispatch groups = ceil(n/256). Buffers: a (n f32,
 * read), b (n f32, read; bound but unread in mode 0), y (n f32,
 * write).
 *
 * Softmax: in place over rows of n f32; the kernel subtracts
 * the row maximum before exponentiation and normalises by the
 * exponent sum. Push constants {n, rows}; one workgroup of
 * 256 invocations per row.
 *
 * Pipeline objects are created per dispatch and destroyed
 * before return, exactly as the A-015/A-056/A-060 paths. Each
 * counter increments only after submit + queue-wait-idle
 * completed on the device - the filed device-execution
 * evidence (law 6). Returns 0 on success, the negative
 * VkResult on Vulkan failure, AESIR_VK_ABSENT when a dispatch
 * entry point is missing, AESIR_VK_INVALID for bad ids /
 * sizes / modes. */

static uint64_t g_elementwise_dispatches = 0;
uint64_t aesir_vk_elementwise_dispatch_count(void) { return g_elementwise_dispatches; }
int aesir_vk_buffer_elementwise(uint64_t id_a, uint64_t id_b, uint64_t id_y, uint32_t n, uint32_t mode) {
    int rc = aesir_vk_init();
    if (rc != 0) { return rc; }
    aesir_vk_load_dispatch();
    if (!g_dispatch_ok) { return AESIR_VK_ABSENT; }
    AesirVkBufferSlot *sa = NULL;
    AesirVkBufferSlot *sb = NULL;
    AesirVkBufferSlot *sy = NULL;
    int vrc = vk_own_validate(id_a, 0, &sa);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_b, 0, &sb);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_y, 0, &sy);
    if (vrc != 0) { return vrc; }
    if (n == 0 || mode > 3u) { return AESIR_VK_INVALID; }
    uint64_t need = (uint64_t)n * 4u;
    if (sa->requested_size < need || sb->requested_size < need || sy->requested_size < need) { return AESIR_VK_INVALID; }
    VkShaderModule_t shader = NULL;
    VkDescriptorSetLayout_t dsl = NULL;
    VkPipelineLayout_t pl = NULL;
    VkPipeline_t pipe = NULL;
    VkDescriptorPool_t dpool = NULL;
    VkDescriptorSet_t dset = NULL;
    VkCommandPool_t cpool = NULL;
    VkCommandBuffer_t cbuf = NULL;
    int out_rc = 0;
    AesirVkShaderModuleCreateInfo smci; memset(&smci, 0, sizeof(smci));
    smci.sType = 16; smci.codeSize = kElementwiseSpvBytes; smci.pCode = kElementwiseSpv;
    rc = (int)d_create_shader_module(g_device, &smci, NULL, &shader);
    if (rc != 0) { out_rc = rc; goto done_ew; }
    AesirVkDescriptorSetLayoutBinding binds[3]; memset(binds, 0, sizeof(binds));
    for (int i = 0; i < 3; i++) { binds[i].binding = (uint32_t)i; binds[i].descriptorType = 6; binds[i].descriptorCount = 1; binds[i].stageFlags = 0x20u; }
    AesirVkDescriptorSetLayoutCreateInfo dslci; memset(&dslci, 0, sizeof(dslci));
    dslci.sType = 32; dslci.bindingCount = 3; dslci.pBindings = binds;
    rc = (int)d_create_dsl(g_device, &dslci, NULL, &dsl);
    if (rc != 0) { out_rc = rc; goto done_ew; }
    struct { uint32_t n; uint32_t mode; } push;
    push.n = n; push.mode = mode;
    AesirVkPushConstantRange pcr; memset(&pcr, 0, sizeof(pcr));
    pcr.stageFlags = 0x20u; pcr.offset = 0; pcr.size = 8;
    AesirVkPipelineLayoutCreateInfo plci; memset(&plci, 0, sizeof(plci));
    plci.sType = 30; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
    rc = (int)d_create_pl(g_device, &plci, NULL, &pl);
    if (rc != 0) { out_rc = rc; goto done_ew; }
    AesirVkComputePipelineCreateInfo cpci; memset(&cpci, 0, sizeof(cpci));
    cpci.sType = 29; cpci.stage.sType = 18; cpci.stage.stage = 0x20u; cpci.stage.module = shader; cpci.stage.pName = "main"; cpci.layout = pl; cpci.basePipelineIndex = -1;
    rc = (int)d_create_cp(g_device, NULL, 1, &cpci, NULL, &pipe);
    if (rc != 0) { out_rc = rc; goto done_ew; }
    AesirVkDescriptorPoolSize psz; memset(&psz, 0, sizeof(psz));
    psz.type = 6; psz.descriptorCount = 3;
    AesirVkDescriptorPoolCreateInfo dpci; memset(&dpci, 0, sizeof(dpci));
    dpci.sType = 33; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &psz;
    rc = (int)d_create_dpool(g_device, &dpci, NULL, &dpool);
    if (rc != 0) { out_rc = rc; goto done_ew; }
    AesirVkDescriptorSetAllocateInfo dsai; memset(&dsai, 0, sizeof(dsai));
    dsai.sType = 34; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
    rc = (int)d_alloc_dsets(g_device, &dsai, &dset);
    if (rc != 0) { out_rc = rc; goto done_ew; }
    AesirVkDescriptorBufferInfo dbi[3]; memset(dbi, 0, sizeof(dbi));
    dbi[0].buffer = sa->buffer; dbi[0].range = need;
    dbi[1].buffer = sb->buffer; dbi[1].range = need;
    dbi[2].buffer = sy->buffer; dbi[2].range = need;
    AesirVkWriteDescriptorSet writes[3]; memset(writes, 0, sizeof(writes));
    for (int i = 0; i < 3; i++) { writes[i].sType = 35; writes[i].dstSet = dset; writes[i].dstBinding = (uint32_t)i; writes[i].descriptorCount = 1; writes[i].descriptorType = 6; writes[i].pBufferInfo = &dbi[i]; }
    d_update_dsets(g_device, 3, writes, 0, NULL);
    AesirVkCommandPoolCreateInfo cpi; memset(&cpi, 0, sizeof(cpi));
    cpi.sType = 39; cpi.queueFamilyIndex = g_queue_family;
    rc = (int)d_create_cpool(g_device, &cpi, NULL, &cpool);
    if (rc != 0) { out_rc = rc; goto done_ew; }
    AesirVkCommandBufferAllocateInfo cbai; memset(&cbai, 0, sizeof(cbai));
    cbai.sType = 40; cbai.commandPool = cpool; cbai.level = 0; cbai.commandBufferCount = 1;
    rc = (int)d_alloc_cbufs(g_device, &cbai, &cbuf);
    if (rc != 0) { out_rc = rc; goto done_ew; }
    AesirVkCommandBufferBeginInfo cbbi; memset(&cbbi, 0, sizeof(cbbi));
    cbbi.sType = 42;
    rc = (int)d_begin_cbuf(cbuf, &cbbi);
    if (rc != 0) { out_rc = rc; goto done_ew; }
    d_cmd_bind_pipeline(cbuf, 1, pipe);
    d_cmd_bind_dsets(cbuf, 1, pl, 0, 1, &dset, 0, NULL);
    d_cmd_push(cbuf, pl, 0x20u, 0, 8, &push);
    d_cmd_dispatch(cbuf, (n + 255u) / 256u, 1, 1);
    rc = (int)d_end_cbuf(cbuf);
    if (rc != 0) { out_rc = rc; goto done_ew; }
    AesirVkSubmitInfo si; memset(&si, 0, sizeof(si));
    si.sType = 4; si.commandBufferCount = 1; si.pCommandBuffers = &cbuf;
    rc = (int)d_queue_submit(g_queue, 1, &si, NULL);
    if (rc != 0) { out_rc = rc; goto done_ew; }
    rc = (int)d_queue_wait_idle(g_queue);
    if (rc != 0) { out_rc = rc; goto done_ew; }
    g_elementwise_dispatches += 1;
    out_rc = 0;
done_ew:
    if (cpool != NULL) { d_destroy_cpool(g_device, cpool, NULL); }
    if (dpool != NULL) { d_destroy_dpool(g_device, dpool, NULL); }
    if (pipe != NULL) { d_destroy_pipeline(g_device, pipe, NULL); }
    if (pl != NULL) { d_destroy_pl(g_device, pl, NULL); }
    if (dsl != NULL) { d_destroy_dsl(g_device, dsl, NULL); }
    if (shader != NULL) { d_destroy_shader_module(g_device, shader, NULL); }
    return out_rc;
}

static uint64_t g_softmax_dispatches = 0;
uint64_t aesir_vk_softmax_dispatch_count(void) { return g_softmax_dispatches; }
int aesir_vk_buffer_softmax(uint64_t id_x, uint32_t n, uint32_t rows) {
    int rc = aesir_vk_init();
    if (rc != 0) { return rc; }
    aesir_vk_load_dispatch();
    if (!g_dispatch_ok) { return AESIR_VK_ABSENT; }
    AesirVkBufferSlot *sx = NULL;
    int vrc = vk_own_validate(id_x, 0, &sx);
    if (vrc != 0) { return vrc; }
    if (n == 0 || rows == 0) { return AESIR_VK_INVALID; }
    uint64_t need = (uint64_t)rows * (uint64_t)n * 4u;
    if (sx->requested_size < need) { return AESIR_VK_INVALID; }
    VkShaderModule_t shader = NULL;
    VkDescriptorSetLayout_t dsl = NULL;
    VkPipelineLayout_t pl = NULL;
    VkPipeline_t pipe = NULL;
    VkDescriptorPool_t dpool = NULL;
    VkDescriptorSet_t dset = NULL;
    VkCommandPool_t cpool = NULL;
    VkCommandBuffer_t cbuf = NULL;
    int out_rc = 0;
    AesirVkShaderModuleCreateInfo smci; memset(&smci, 0, sizeof(smci));
    smci.sType = 16; smci.codeSize = kSoftmaxSpvBytes; smci.pCode = kSoftmaxSpv;
    rc = (int)d_create_shader_module(g_device, &smci, NULL, &shader);
    if (rc != 0) { out_rc = rc; goto done_sm; }
    AesirVkDescriptorSetLayoutBinding binds[1]; memset(binds, 0, sizeof(binds));
    binds[0].binding = 0; binds[0].descriptorType = 6; binds[0].descriptorCount = 1; binds[0].stageFlags = 0x20u;
    AesirVkDescriptorSetLayoutCreateInfo dslci; memset(&dslci, 0, sizeof(dslci));
    dslci.sType = 32; dslci.bindingCount = 1; dslci.pBindings = binds;
    rc = (int)d_create_dsl(g_device, &dslci, NULL, &dsl);
    if (rc != 0) { out_rc = rc; goto done_sm; }
    struct { uint32_t n; uint32_t rows; } push;
    push.n = n; push.rows = rows;
    AesirVkPushConstantRange pcr; memset(&pcr, 0, sizeof(pcr));
    pcr.stageFlags = 0x20u; pcr.offset = 0; pcr.size = 8;
    AesirVkPipelineLayoutCreateInfo plci; memset(&plci, 0, sizeof(plci));
    plci.sType = 30; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
    rc = (int)d_create_pl(g_device, &plci, NULL, &pl);
    if (rc != 0) { out_rc = rc; goto done_sm; }
    AesirVkComputePipelineCreateInfo cpci; memset(&cpci, 0, sizeof(cpci));
    cpci.sType = 29; cpci.stage.sType = 18; cpci.stage.stage = 0x20u; cpci.stage.module = shader; cpci.stage.pName = "main"; cpci.layout = pl; cpci.basePipelineIndex = -1;
    rc = (int)d_create_cp(g_device, NULL, 1, &cpci, NULL, &pipe);
    if (rc != 0) { out_rc = rc; goto done_sm; }
    AesirVkDescriptorPoolSize psz; memset(&psz, 0, sizeof(psz));
    psz.type = 6; psz.descriptorCount = 1;
    AesirVkDescriptorPoolCreateInfo dpci; memset(&dpci, 0, sizeof(dpci));
    dpci.sType = 33; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &psz;
    rc = (int)d_create_dpool(g_device, &dpci, NULL, &dpool);
    if (rc != 0) { out_rc = rc; goto done_sm; }
    AesirVkDescriptorSetAllocateInfo dsai; memset(&dsai, 0, sizeof(dsai));
    dsai.sType = 34; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
    rc = (int)d_alloc_dsets(g_device, &dsai, &dset);
    if (rc != 0) { out_rc = rc; goto done_sm; }
    AesirVkDescriptorBufferInfo dbi[1]; memset(dbi, 0, sizeof(dbi));
    dbi[0].buffer = sx->buffer; dbi[0].range = need;
    AesirVkWriteDescriptorSet writes[1]; memset(writes, 0, sizeof(writes));
    writes[0].sType = 35; writes[0].dstSet = dset; writes[0].dstBinding = 0; writes[0].descriptorCount = 1; writes[0].descriptorType = 6; writes[0].pBufferInfo = &dbi[0];
    d_update_dsets(g_device, 1, writes, 0, NULL);
    AesirVkCommandPoolCreateInfo cpi; memset(&cpi, 0, sizeof(cpi));
    cpi.sType = 39; cpi.queueFamilyIndex = g_queue_family;
    rc = (int)d_create_cpool(g_device, &cpi, NULL, &cpool);
    if (rc != 0) { out_rc = rc; goto done_sm; }
    AesirVkCommandBufferAllocateInfo cbai; memset(&cbai, 0, sizeof(cbai));
    cbai.sType = 40; cbai.commandPool = cpool; cbai.level = 0; cbai.commandBufferCount = 1;
    rc = (int)d_alloc_cbufs(g_device, &cbai, &cbuf);
    if (rc != 0) { out_rc = rc; goto done_sm; }
    AesirVkCommandBufferBeginInfo cbbi; memset(&cbbi, 0, sizeof(cbbi));
    cbbi.sType = 42;
    rc = (int)d_begin_cbuf(cbuf, &cbbi);
    if (rc != 0) { out_rc = rc; goto done_sm; }
    d_cmd_bind_pipeline(cbuf, 1, pipe);
    d_cmd_bind_dsets(cbuf, 1, pl, 0, 1, &dset, 0, NULL);
    d_cmd_push(cbuf, pl, 0x20u, 0, 8, &push);
    d_cmd_dispatch(cbuf, rows, 1, 1);
    rc = (int)d_end_cbuf(cbuf);
    if (rc != 0) { out_rc = rc; goto done_sm; }
    AesirVkSubmitInfo si; memset(&si, 0, sizeof(si));
    si.sType = 4; si.commandBufferCount = 1; si.pCommandBuffers = &cbuf;
    rc = (int)d_queue_submit(g_queue, 1, &si, NULL);
    if (rc != 0) { out_rc = rc; goto done_sm; }
    rc = (int)d_queue_wait_idle(g_queue);
    if (rc != 0) { out_rc = rc; goto done_sm; }
    g_softmax_dispatches += 1;
    out_rc = 0;
done_sm:
    if (cpool != NULL) { d_destroy_cpool(g_device, cpool, NULL); }
    if (dpool != NULL) { d_destroy_dpool(g_device, dpool, NULL); }
    if (pipe != NULL) { d_destroy_pipeline(g_device, pipe, NULL); }
    if (pl != NULL) { d_destroy_pl(g_device, pl, NULL); }
    if (dsl != NULL) { d_destroy_dsl(g_device, dsl, NULL); }
    if (shader != NULL) { d_destroy_shader_module(g_device, shader, NULL); }
    return out_rc;
}

/* ---- A-066: KV-append + embedding gather ----
 * Two pure data-movement compute kernels through the A-055
 * pipeline (SPIR-V via shaders/generated/aesir_shaders_spv.h:
 * kKvAppendSpv / kEmbedGatherSpv). The KV-append kernel closes
 * the A-065 KV-APPEND GAP: it inserts one decode step's k/v
 * projection row [kv_heads][head_dim] into the cache layout
 * [kv_heads][max_len][head_dim] the A-062 attention kernel
 * consumes, at slot `position`. The embedding gather copies
 * row `token` of the Float32 embedding table into the step
 * input. Both are compute dispatches, NOT vkCmdCopyBuffer:
 * this file still resolves no copy entry point, so the A-019
 * zero-copy counter above still cannot increment. Same
 * per-dispatch pipeline discipline as A-056/A-062/A-063; each
 * counter increments only after submit + queue-wait-idle. */
static int vk_move2_dispatch(const uint32_t *spv, size_t spv_bytes, uint64_t id_a, uint64_t id_b, uint64_t range_a, uint64_t range_b, const void *push, uint32_t push_size, uint32_t groups, uint64_t *counter) {
    int rc = aesir_vk_init();
    if (rc != 0) { return rc; }
    aesir_vk_load_dispatch();
    if (!g_dispatch_ok) { return AESIR_VK_ABSENT; }
    AesirVkBufferSlot *sa = NULL;
    AesirVkBufferSlot *sb = NULL;
    int vrc = vk_own_validate(id_a, 0, &sa);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_b, 0, &sb);
    if (vrc != 0) { return vrc; }
    if (sa->requested_size < range_a || sb->requested_size < range_b) { return AESIR_VK_INVALID; }
    VkShaderModule_t shader = NULL;
    VkDescriptorSetLayout_t dsl = NULL;
    VkPipelineLayout_t pl = NULL;
    VkPipeline_t pipe = NULL;
    VkDescriptorPool_t dpool = NULL;
    VkDescriptorSet_t dset = NULL;
    VkCommandPool_t cpool = NULL;
    VkCommandBuffer_t cbuf = NULL;
    int out_rc = 0;
    AesirVkShaderModuleCreateInfo smci; memset(&smci, 0, sizeof(smci));
    smci.sType = 16; smci.codeSize = spv_bytes; smci.pCode = spv;
    rc = (int)d_create_shader_module(g_device, &smci, NULL, &shader);
    if (rc != 0) { out_rc = rc; goto done_mv; }
    AesirVkDescriptorSetLayoutBinding binds[2]; memset(binds, 0, sizeof(binds));
    for (int i = 0; i < 2; i++) { binds[i].binding = (uint32_t)i; binds[i].descriptorType = 6; binds[i].descriptorCount = 1; binds[i].stageFlags = 0x20u; }
    AesirVkDescriptorSetLayoutCreateInfo dslci; memset(&dslci, 0, sizeof(dslci));
    dslci.sType = 32; dslci.bindingCount = 2; dslci.pBindings = binds;
    rc = (int)d_create_dsl(g_device, &dslci, NULL, &dsl);
    if (rc != 0) { out_rc = rc; goto done_mv; }
    AesirVkPushConstantRange pcr; memset(&pcr, 0, sizeof(pcr));
    pcr.stageFlags = 0x20u; pcr.offset = 0; pcr.size = push_size;
    AesirVkPipelineLayoutCreateInfo plci; memset(&plci, 0, sizeof(plci));
    plci.sType = 30; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
    rc = (int)d_create_pl(g_device, &plci, NULL, &pl);
    if (rc != 0) { out_rc = rc; goto done_mv; }
    AesirVkComputePipelineCreateInfo cpci; memset(&cpci, 0, sizeof(cpci));
    cpci.sType = 29; cpci.stage.sType = 18; cpci.stage.stage = 0x20u; cpci.stage.module = shader; cpci.stage.pName = "main"; cpci.layout = pl; cpci.basePipelineIndex = -1;
    rc = (int)d_create_cp(g_device, NULL, 1, &cpci, NULL, &pipe);
    if (rc != 0) { out_rc = rc; goto done_mv; }
    AesirVkDescriptorPoolSize psz; memset(&psz, 0, sizeof(psz));
    psz.type = 6; psz.descriptorCount = 2;
    AesirVkDescriptorPoolCreateInfo dpci; memset(&dpci, 0, sizeof(dpci));
    dpci.sType = 33; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &psz;
    rc = (int)d_create_dpool(g_device, &dpci, NULL, &dpool);
    if (rc != 0) { out_rc = rc; goto done_mv; }
    AesirVkDescriptorSetAllocateInfo dsai; memset(&dsai, 0, sizeof(dsai));
    dsai.sType = 34; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
    rc = (int)d_alloc_dsets(g_device, &dsai, &dset);
    if (rc != 0) { out_rc = rc; goto done_mv; }
    AesirVkDescriptorBufferInfo dbi[2]; memset(dbi, 0, sizeof(dbi));
    dbi[0].buffer = sa->buffer; dbi[0].range = range_a;
    dbi[1].buffer = sb->buffer; dbi[1].range = range_b;
    AesirVkWriteDescriptorSet writes[2]; memset(writes, 0, sizeof(writes));
    for (int i = 0; i < 2; i++) { writes[i].sType = 35; writes[i].dstSet = dset; writes[i].dstBinding = (uint32_t)i; writes[i].descriptorCount = 1; writes[i].descriptorType = 6; writes[i].pBufferInfo = &dbi[i]; }
    d_update_dsets(g_device, 2, writes, 0, NULL);
    AesirVkCommandPoolCreateInfo cpi; memset(&cpi, 0, sizeof(cpi));
    cpi.sType = 39; cpi.queueFamilyIndex = g_queue_family;
    rc = (int)d_create_cpool(g_device, &cpi, NULL, &cpool);
    if (rc != 0) { out_rc = rc; goto done_mv; }
    AesirVkCommandBufferAllocateInfo cbai; memset(&cbai, 0, sizeof(cbai));
    cbai.sType = 40; cbai.commandPool = cpool; cbai.level = 0; cbai.commandBufferCount = 1;
    rc = (int)d_alloc_cbufs(g_device, &cbai, &cbuf);
    if (rc != 0) { out_rc = rc; goto done_mv; }
    AesirVkCommandBufferBeginInfo cbbi; memset(&cbbi, 0, sizeof(cbbi));
    cbbi.sType = 42;
    rc = (int)d_begin_cbuf(cbuf, &cbbi);
    if (rc != 0) { out_rc = rc; goto done_mv; }
    d_cmd_bind_pipeline(cbuf, 1, pipe);
    d_cmd_bind_dsets(cbuf, 1, pl, 0, 1, &dset, 0, NULL);
    d_cmd_push(cbuf, pl, 0x20u, 0, push_size, push);
    d_cmd_dispatch(cbuf, groups, 1, 1);
    rc = (int)d_end_cbuf(cbuf);
    if (rc != 0) { out_rc = rc; goto done_mv; }
    AesirVkSubmitInfo si; memset(&si, 0, sizeof(si));
    si.sType = 4; si.commandBufferCount = 1; si.pCommandBuffers = &cbuf;
    rc = (int)d_queue_submit(g_queue, 1, &si, NULL);
    if (rc != 0) { out_rc = rc; goto done_mv; }
    rc = (int)d_queue_wait_idle(g_queue);
    if (rc != 0) { out_rc = rc; goto done_mv; }
    *counter += 1;
    out_rc = 0;
done_mv:
    if (cpool != NULL) { d_destroy_cpool(g_device, cpool, NULL); }
    if (dpool != NULL) { d_destroy_dpool(g_device, dpool, NULL); }
    if (pipe != NULL) { d_destroy_pipeline(g_device, pipe, NULL); }
    if (pl != NULL) { d_destroy_pl(g_device, pl, NULL); }
    if (dsl != NULL) { d_destroy_dsl(g_device, dsl, NULL); }
    if (shader != NULL) { d_destroy_shader_module(g_device, shader, NULL); }
    return out_rc;
}
static uint64_t g_kv_append_dispatches = 0;
uint64_t aesir_vk_kv_append_dispatch_count(void) { return g_kv_append_dispatches; }
int aesir_vk_buffer_kv_append(uint64_t id_src, uint64_t id_cache, uint32_t head_dim, uint32_t max_len, uint32_t position, uint32_t kv_heads) {
    if (head_dim == 0 || max_len == 0 || kv_heads == 0 || position >= max_len) { return AESIR_VK_INVALID; }
    struct { uint32_t head_dim; uint32_t max_len; uint32_t position; uint32_t kv_heads; } push;
    push.head_dim = head_dim; push.max_len = max_len; push.position = position; push.kv_heads = kv_heads;
    uint64_t range_src = (uint64_t)kv_heads * (uint64_t)head_dim * 4u;
    uint64_t range_cache = (uint64_t)kv_heads * (uint64_t)max_len * (uint64_t)head_dim * 4u;
    uint32_t groups = (kv_heads * head_dim + 63u) / 64u;
    return vk_move2_dispatch(kKvAppendSpv, kKvAppendSpvBytes, id_src, id_cache, range_src, range_cache, &push, 16, groups, &g_kv_append_dispatches);
}
static uint64_t g_embed_gather_dispatches = 0;
uint64_t aesir_vk_embed_gather_dispatch_count(void) { return g_embed_gather_dispatches; }
int aesir_vk_buffer_embed_gather(uint64_t id_emb, uint64_t id_out, uint32_t dim, uint32_t token, uint32_t vocab) {
    if (dim == 0 || vocab == 0 || token >= vocab) { return AESIR_VK_INVALID; }
    struct { uint32_t dim; uint32_t token; } push;
    push.dim = dim; push.token = token;
    uint64_t range_emb = (uint64_t)vocab * (uint64_t)dim * 4u;
    uint64_t range_out = (uint64_t)dim * 4u;
    uint32_t groups = (dim + 63u) / 64u;
    return vk_move2_dispatch(kEmbedGatherSpv, kEmbedGatherSpvBytes, id_emb, id_out, range_emb, range_out, &push, 8, groups, &g_embed_gather_dispatches);
}
/* ---- A-068: Vulkan batched GEMM (prefill) ----
 *
 * Batched matrix kernels for prompt processing, generalising the
 * A-056 Q8_0 GEMV and the A-055 dense F32 GEMV to a token batch:
 *   q8_0_gemm: Y[t, r] = sum_k dequant(W[r, k]) * X[t, k], W in
 *     the raw GGUF Q8_0 byte layout (34-byte blocks), X row-major
 *     [tokens][cols], Y row-major [tokens][rows]. Shader:
 *     aesir_engine/shaders/q8_0_gemm.comp (kQ80GemmSpv from the
 *     A-055 generated header).
 *   f32_gemm: Y[t, r] = sum_k W[r * cols + k] * X[t, k], dense
 *     Float32 W. Shader: aesir_engine/shaders/gemm_f32.comp
 *     (kGemmF32Spv from the generated header).
 * Both dispatch one 256-wide workgroup per (row, token) pair as
 * (rows, tokens, 1) with push constants (cols, rows, tokens).
 * Same context, device, queue and A-014 buffer slots as every
 * Wave 7 gateway; pipeline objects are created per dispatch and
 * destroyed before return; returns after vkQueueWaitIdle so
 * mapped reads observe the completed dispatch. The dispatch
 * counters are the filed device-execution evidence (roadmap
 * law 6): each increments only after a submit + wait-idle
 * completed on the device. Returns 0 on success, the negative
 * VkResult on Vulkan failure, AESIR_VK_ABSENT when a dispatch
 * entry point is missing, AESIR_VK_INVALID for bad ids / sizes /
 * shape violations (validated in the entry points and in the
 * Mojo gateway before any dispatch). No host fallback exists:
 * nothing here computes a product on the CPU. */
static int aesir_vk_gemm_dispatch(const uint32_t *spv, size_t spv_bytes,
    uint64_t id_w, uint64_t id_x, uint64_t id_y,
    uint64_t need_w, uint64_t need_x, uint64_t need_y,
    const void *push, uint32_t push_size,
    uint32_t gx, uint32_t gy, uint64_t *counter) {
    int rc = aesir_vk_init();
    if (rc != 0) { return rc; }
    aesir_vk_load_dispatch();
    if (!g_dispatch_ok) { return AESIR_VK_ABSENT; }
    AesirVkBufferSlot *sw = NULL;
    AesirVkBufferSlot *sx = NULL;
    AesirVkBufferSlot *sy = NULL;
    int vrc = vk_own_validate(id_w, 0, &sw);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_x, 0, &sx);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_y, 0, &sy);
    if (vrc != 0) { return vrc; }
    if (sw->requested_size < need_w || sx->requested_size < need_x || sy->requested_size < need_y) { return AESIR_VK_INVALID; }
    VkShaderModule_t shader = NULL;
    VkDescriptorSetLayout_t dsl = NULL;
    VkPipelineLayout_t pl = NULL;
    VkPipeline_t pipe = NULL;
    VkDescriptorPool_t dpool = NULL;
    VkDescriptorSet_t dset = NULL;
    VkCommandPool_t cpool = NULL;
    VkCommandBuffer_t cbuf = NULL;
    int out_rc = 0;
    AesirVkShaderModuleCreateInfo smci; memset(&smci, 0, sizeof(smci));
    smci.sType = 16; smci.codeSize = spv_bytes; smci.pCode = spv;
    rc = (int)d_create_shader_module(g_device, &smci, NULL, &shader);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetLayoutBinding binds[3]; memset(binds, 0, sizeof(binds));
    for (int i = 0; i < 3; i++) { binds[i].binding = (uint32_t)i; binds[i].descriptorType = 6; binds[i].descriptorCount = 1; binds[i].stageFlags = 0x20u; }
    AesirVkDescriptorSetLayoutCreateInfo dslci; memset(&dslci, 0, sizeof(dslci));
    dslci.sType = 32; dslci.bindingCount = 3; dslci.pBindings = binds;
    rc = (int)d_create_dsl(g_device, &dslci, NULL, &dsl);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkPushConstantRange pcr; memset(&pcr, 0, sizeof(pcr));
    pcr.stageFlags = 0x20u; pcr.offset = 0; pcr.size = push_size;
    AesirVkPipelineLayoutCreateInfo plci; memset(&plci, 0, sizeof(plci));
    plci.sType = 30; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
    rc = (int)d_create_pl(g_device, &plci, NULL, &pl);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkComputePipelineCreateInfo cpci; memset(&cpci, 0, sizeof(cpci));
    cpci.sType = 29; cpci.stage.sType = 18; cpci.stage.stage = 0x20u; cpci.stage.module = shader; cpci.stage.pName = "main"; cpci.layout = pl; cpci.basePipelineIndex = -1;
    rc = (int)d_create_cp(g_device, NULL, 1, &cpci, NULL, &pipe);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorPoolSize psz; memset(&psz, 0, sizeof(psz));
    psz.type = 6; psz.descriptorCount = 3;
    AesirVkDescriptorPoolCreateInfo dpci; memset(&dpci, 0, sizeof(dpci));
    dpci.sType = 33; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &psz;
    rc = (int)d_create_dpool(g_device, &dpci, NULL, &dpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetAllocateInfo dsai; memset(&dsai, 0, sizeof(dsai));
    dsai.sType = 34; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
    rc = (int)d_alloc_dsets(g_device, &dsai, &dset);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorBufferInfo dbi[3]; memset(dbi, 0, sizeof(dbi));
    dbi[0].buffer = sw->buffer; dbi[0].range = need_w;
    dbi[1].buffer = sx->buffer; dbi[1].range = need_x;
    dbi[2].buffer = sy->buffer; dbi[2].range = need_y;
    AesirVkWriteDescriptorSet writes[3]; memset(writes, 0, sizeof(writes));
    for (int i = 0; i < 3; i++) { writes[i].sType = 35; writes[i].dstSet = dset; writes[i].dstBinding = (uint32_t)i; writes[i].descriptorCount = 1; writes[i].descriptorType = 6; writes[i].pBufferInfo = &dbi[i]; }
    d_update_dsets(g_device, 3, writes, 0, NULL);
    AesirVkCommandPoolCreateInfo cpi; memset(&cpi, 0, sizeof(cpi));
    cpi.sType = 39; cpi.queueFamilyIndex = g_queue_family;
    rc = (int)d_create_cpool(g_device, &cpi, NULL, &cpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferAllocateInfo cbai; memset(&cbai, 0, sizeof(cbai));
    cbai.sType = 40; cbai.commandPool = cpool; cbai.level = 0; cbai.commandBufferCount = 1;
    rc = (int)d_alloc_cbufs(g_device, &cbai, &cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferBeginInfo cbbi; memset(&cbbi, 0, sizeof(cbbi));
    cbbi.sType = 42;
    rc = (int)d_begin_cbuf(cbuf, &cbbi);
    if (rc != 0) { out_rc = rc; goto done; }
    d_cmd_bind_pipeline(cbuf, 1, pipe);
    d_cmd_bind_dsets(cbuf, 1, pl, 0, 1, &dset, 0, NULL);
    d_cmd_push(cbuf, pl, 0x20u, 0, push_size, push);
    d_cmd_dispatch(cbuf, gx, gy, 1);
    rc = (int)d_end_cbuf(cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkSubmitInfo si; memset(&si, 0, sizeof(si));
    si.sType = 4; si.commandBufferCount = 1; si.pCommandBuffers = &cbuf;
    rc = (int)d_queue_submit(g_queue, 1, &si, NULL);
    if (rc != 0) { out_rc = rc; goto done; }
    rc = (int)d_queue_wait_idle(g_queue);
    if (rc != 0) { out_rc = rc; goto done; }
    *counter += 1;
    out_rc = 0;
done:
    if (cpool != NULL) { d_destroy_cpool(g_device, cpool, NULL); }
    if (dpool != NULL) { d_destroy_dpool(g_device, dpool, NULL); }
    if (pipe != NULL) { d_destroy_pipeline(g_device, pipe, NULL); }
    if (pl != NULL) { d_destroy_pl(g_device, pl, NULL); }
    if (dsl != NULL) { d_destroy_dsl(g_device, dsl, NULL); }
    if (shader != NULL) { d_destroy_shader_module(g_device, shader, NULL); }
    return out_rc;
}

static uint64_t g_q8_gemm_dispatches = 0;
uint64_t aesir_vk_q8_gemm_dispatch_count(void) { return g_q8_gemm_dispatches; }
int aesir_vk_buffer_q8_gemm(uint64_t id_w, uint64_t id_x, uint64_t id_y, uint32_t rows, uint32_t cols, uint32_t tokens) {
    if (rows == 0 || cols == 0 || tokens == 0 || (cols % 32u) != 0) { return AESIR_VK_INVALID; }
    uint64_t need_w = (uint64_t)rows * (uint64_t)(cols / 32u) * 34u;
    uint64_t need_x = (uint64_t)tokens * (uint64_t)cols * 4u;
    uint64_t need_y = (uint64_t)tokens * (uint64_t)rows * 4u;
    struct { uint32_t cols; uint32_t rows; uint32_t tokens; } push;
    push.cols = cols; push.rows = rows; push.tokens = tokens;
    return aesir_vk_gemm_dispatch(kQ80GemmSpv, kQ80GemmSpvBytes, id_w, id_x, id_y, need_w, need_x, need_y, &push, 12, rows, tokens, &g_q8_gemm_dispatches);
}

static uint64_t g_f32_gemm_dispatches = 0;
uint64_t aesir_vk_f32_gemm_dispatch_count(void) { return g_f32_gemm_dispatches; }
int aesir_vk_buffer_f32_gemm(uint64_t id_w, uint64_t id_x, uint64_t id_y, uint32_t rows, uint32_t cols, uint32_t tokens) {
    if (rows == 0 || cols == 0 || tokens == 0) { return AESIR_VK_INVALID; }
    uint64_t need_w = (uint64_t)rows * (uint64_t)cols * 4u;
    uint64_t need_x = (uint64_t)tokens * (uint64_t)cols * 4u;
    uint64_t need_y = (uint64_t)tokens * (uint64_t)rows * 4u;
    struct { uint32_t cols; uint32_t rows; uint32_t tokens; } push;
    push.cols = cols; push.rows = rows; push.tokens = tokens;
    return aesir_vk_gemm_dispatch(kGemmF32Spv, kGemmF32SpvBytes, id_w, id_x, id_y, need_w, need_x, need_y, &push, 12, rows, tokens, &g_f32_gemm_dispatches);
}

/* ---- A-069: chunked prefill kernels ----
 * Three SPIR-V kernels from the A-055 build pipeline (sources
 * aesir_engine/shaders/rope_batched.comp, kv_append_chunk.comp,
 * attention_prefill.comp; words from the generated header
 * shaders/generated/aesir_shaders_spv.h - kRopeBatchedSpv /
 * kKvAppendChunkSpv / kAttentionPrefillSpv, hashes in
 * SHADER_MANIFEST.json, kernel_count 22 -> 25; all 22 prior
 * hashes byte-identical after regeneration).
 * Same per-dispatch pipeline discipline as A-056..A-068; each
 * counter increments only after submit + queue-wait-idle.
 * No host fallback: nothing here computes on the CPU. */
static uint64_t g_kv_append_chunk_dispatches = 0;
uint64_t aesir_vk_kv_append_chunk_dispatch_count(void) { return g_kv_append_chunk_dispatches; }
int aesir_vk_buffer_kv_append_chunk(uint64_t id_src, uint64_t id_cache, uint32_t head_dim, uint32_t max_len, uint32_t chunk_start, uint32_t kv_heads, uint32_t tokens) {
    if (head_dim == 0 || max_len == 0 || kv_heads == 0 || tokens == 0) { return AESIR_VK_INVALID; }
    if (chunk_start >= max_len || tokens > max_len - chunk_start) { return AESIR_VK_INVALID; }
    struct { uint32_t head_dim; uint32_t max_len; uint32_t chunk_start; uint32_t kv_heads; uint32_t tokens; } push;
    push.head_dim = head_dim; push.max_len = max_len; push.chunk_start = chunk_start; push.kv_heads = kv_heads; push.tokens = tokens;
    uint64_t range_src = (uint64_t)tokens * (uint64_t)kv_heads * (uint64_t)head_dim * 4u;
    uint64_t range_cache = (uint64_t)kv_heads * (uint64_t)max_len * (uint64_t)head_dim * 4u;
    uint32_t groups = (uint32_t)((range_src / 4u + 63u) / 64u);
    return vk_move2_dispatch(kKvAppendChunkSpv, kKvAppendChunkSpvBytes, id_src, id_cache, range_src, range_cache, &push, 20, groups, &g_kv_append_chunk_dispatches);
}
static uint64_t g_rope_batched_dispatches = 0;
uint64_t aesir_vk_rope_batched_dispatch_count(void) { return g_rope_batched_dispatches; }
int aesir_vk_buffer_rope_batched(uint64_t id_x, uint32_t head_dim, uint32_t rows, uint32_t rows_per_token, uint32_t base_position, uint32_t base_bits) {
    int rc = aesir_vk_init();
    if (rc != 0) { return rc; }
    aesir_vk_load_dispatch();
    if (!g_dispatch_ok) { return AESIR_VK_ABSENT; }
    AesirVkBufferSlot *sx = NULL;
    int vrc = vk_own_validate(id_x, 0, &sx);
    if (vrc != 0) { return vrc; }
    if (head_dim == 0 || (head_dim % 2u) != 0 || rows == 0 || rows_per_token == 0 || (rows % rows_per_token) != 0) { return AESIR_VK_INVALID; }
    uint64_t need_x = (uint64_t)rows * (uint64_t)head_dim * 4u;
    if (sx->requested_size < need_x) { return AESIR_VK_INVALID; }
    VkShaderModule_t shader = NULL;
    VkDescriptorSetLayout_t dsl = NULL;
    VkPipelineLayout_t pl = NULL;
    VkPipeline_t pipe = NULL;
    VkDescriptorPool_t dpool = NULL;
    VkDescriptorSet_t dset = NULL;
    VkCommandPool_t cpool = NULL;
    VkCommandBuffer_t cbuf = NULL;
    int out_rc = 0;
    AesirVkShaderModuleCreateInfo smci; memset(&smci, 0, sizeof(smci));
    smci.sType = 16; smci.codeSize = kRopeBatchedSpvBytes; smci.pCode = kRopeBatchedSpv;
    rc = (int)d_create_shader_module(g_device, &smci, NULL, &shader);
    if (rc != 0) { out_rc = rc; goto done_rb; }
    AesirVkDescriptorSetLayoutBinding binds[1]; memset(binds, 0, sizeof(binds));
    binds[0].binding = 0; binds[0].descriptorType = 6; binds[0].descriptorCount = 1; binds[0].stageFlags = 0x20u;
    AesirVkDescriptorSetLayoutCreateInfo dslci; memset(&dslci, 0, sizeof(dslci));
    dslci.sType = 32; dslci.bindingCount = 1; dslci.pBindings = binds;
    rc = (int)d_create_dsl(g_device, &dslci, NULL, &dsl);
    if (rc != 0) { out_rc = rc; goto done_rb; }
    struct { uint32_t head_dim; uint32_t rows; uint32_t rows_per_token; uint32_t base_position; float base; } push;
    push.head_dim = head_dim; push.rows = rows; push.rows_per_token = rows_per_token; push.base_position = base_position;
    { float b; uint32_t bits = base_bits; memcpy(&b, &bits, 4); push.base = b; }
    AesirVkPushConstantRange pcr; memset(&pcr, 0, sizeof(pcr));
    pcr.stageFlags = 0x20u; pcr.offset = 0; pcr.size = 20;
    AesirVkPipelineLayoutCreateInfo plci; memset(&plci, 0, sizeof(plci));
    plci.sType = 30; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
    rc = (int)d_create_pl(g_device, &plci, NULL, &pl);
    if (rc != 0) { out_rc = rc; goto done_rb; }
    AesirVkComputePipelineCreateInfo cpci; memset(&cpci, 0, sizeof(cpci));
    cpci.sType = 29; cpci.stage.sType = 18; cpci.stage.stage = 0x20u; cpci.stage.module = shader; cpci.stage.pName = "main"; cpci.layout = pl; cpci.basePipelineIndex = -1;
    rc = (int)d_create_cp(g_device, NULL, 1, &cpci, NULL, &pipe);
    if (rc != 0) { out_rc = rc; goto done_rb; }
    AesirVkDescriptorPoolSize psz; memset(&psz, 0, sizeof(psz));
    psz.type = 6; psz.descriptorCount = 1;
    AesirVkDescriptorPoolCreateInfo dpci; memset(&dpci, 0, sizeof(dpci));
    dpci.sType = 33; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &psz;
    rc = (int)d_create_dpool(g_device, &dpci, NULL, &dpool);
    if (rc != 0) { out_rc = rc; goto done_rb; }
    AesirVkDescriptorSetAllocateInfo dsai; memset(&dsai, 0, sizeof(dsai));
    dsai.sType = 34; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
    rc = (int)d_alloc_dsets(g_device, &dsai, &dset);
    if (rc != 0) { out_rc = rc; goto done_rb; }
    AesirVkDescriptorBufferInfo dbi[1]; memset(dbi, 0, sizeof(dbi));
    dbi[0].buffer = sx->buffer; dbi[0].range = need_x;
    AesirVkWriteDescriptorSet writes[1]; memset(writes, 0, sizeof(writes));
    writes[0].sType = 35; writes[0].dstSet = dset; writes[0].dstBinding = 0; writes[0].descriptorCount = 1; writes[0].descriptorType = 6; writes[0].pBufferInfo = &dbi[0];
    d_update_dsets(g_device, 1, writes, 0, NULL);
    AesirVkCommandPoolCreateInfo cpi; memset(&cpi, 0, sizeof(cpi));
    cpi.sType = 39; cpi.queueFamilyIndex = g_queue_family;
    rc = (int)d_create_cpool(g_device, &cpi, NULL, &cpool);
    if (rc != 0) { out_rc = rc; goto done_rb; }
    AesirVkCommandBufferAllocateInfo cbai; memset(&cbai, 0, sizeof(cbai));
    cbai.sType = 40; cbai.commandPool = cpool; cbai.level = 0; cbai.commandBufferCount = 1;
    rc = (int)d_alloc_cbufs(g_device, &cbai, &cbuf);
    if (rc != 0) { out_rc = rc; goto done_rb; }
    AesirVkCommandBufferBeginInfo cbbi; memset(&cbbi, 0, sizeof(cbbi));
    cbbi.sType = 42;
    rc = (int)d_begin_cbuf(cbuf, &cbbi);
    if (rc != 0) { out_rc = rc; goto done_rb; }
    d_cmd_bind_pipeline(cbuf, 1, pipe);
    d_cmd_bind_dsets(cbuf, 1, pl, 0, 1, &dset, 0, NULL);
    d_cmd_push(cbuf, pl, 0x20u, 0, 20, &push);
    { uint32_t total = rows * (head_dim / 2u); uint32_t groups = (total + 255u) / 256u; d_cmd_dispatch(cbuf, groups, 1, 1); }
    rc = (int)d_end_cbuf(cbuf);
    if (rc != 0) { out_rc = rc; goto done_rb; }
    AesirVkSubmitInfo si; memset(&si, 0, sizeof(si));
    si.sType = 4; si.commandBufferCount = 1; si.pCommandBuffers = &cbuf;
    rc = (int)d_queue_submit(g_queue, 1, &si, NULL);
    if (rc != 0) { out_rc = rc; goto done_rb; }
    rc = (int)d_queue_wait_idle(g_queue);
    if (rc != 0) { out_rc = rc; goto done_rb; }
    g_rope_batched_dispatches += 1;
    out_rc = 0;
done_rb:
    if (cpool != NULL) { d_destroy_cpool(g_device, cpool, NULL); }
    if (dpool != NULL) { d_destroy_dpool(g_device, dpool, NULL); }
    if (pipe != NULL) { d_destroy_pipeline(g_device, pipe, NULL); }
    if (pl != NULL) { d_destroy_pl(g_device, pl, NULL); }
    if (dsl != NULL) { d_destroy_dsl(g_device, dsl, NULL); }
    if (shader != NULL) { d_destroy_shader_module(g_device, shader, NULL); }
    return out_rc;
}

static uint64_t g_prefill_attn_dispatches = 0;
uint64_t aesir_vk_attn_prefill_chunk_dispatch_count(void) { return g_prefill_attn_dispatches; }
int aesir_vk_buffer_attn_prefill_chunk(uint64_t id_q, uint64_t id_k, uint64_t id_v, uint64_t id_o, uint32_t head_dim, uint32_t max_len, uint32_t chunk_start, uint32_t tokens, uint32_t num_heads, uint32_t kv_per_query) {
    int rc = aesir_vk_init();
    if (rc != 0) { return rc; }
    aesir_vk_load_dispatch();
    if (!g_dispatch_ok) { return AESIR_VK_ABSENT; }
    AesirVkBufferSlot *sq = NULL;
    AesirVkBufferSlot *sk = NULL;
    AesirVkBufferSlot *sv = NULL;
    AesirVkBufferSlot *so = NULL;
    int vrc = vk_own_validate(id_q, 0, &sq);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_k, 0, &sk);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_v, 0, &sv);
    if (vrc != 0) { return vrc; }
    vrc = vk_own_validate(id_o, 0, &so);
    if (vrc != 0) { return vrc; }
    if (head_dim == 0 || head_dim > 64 || max_len == 0 || tokens == 0 || chunk_start >= max_len || tokens > max_len - chunk_start || num_heads == 0 || kv_per_query == 0) { return AESIR_VK_INVALID; }
    if ((num_heads % kv_per_query) != 0) { return AESIR_VK_INVALID; }
    uint32_t num_kv_heads = num_heads / kv_per_query;
    uint64_t need_q = (uint64_t)tokens * (uint64_t)num_heads * (uint64_t)head_dim * 4u;
    uint64_t need_kv = (uint64_t)num_kv_heads * (uint64_t)max_len * (uint64_t)head_dim * 4u;
    if (sq->requested_size < need_q || sk->requested_size < need_kv || sv->requested_size < need_kv || so->requested_size < need_q) { return AESIR_VK_INVALID; }
    VkShaderModule_t shader = NULL;
    VkDescriptorSetLayout_t dsl = NULL;
    VkPipelineLayout_t pl = NULL;
    VkPipeline_t pipe = NULL;
    VkDescriptorPool_t dpool = NULL;
    VkDescriptorSet_t dset = NULL;
    VkCommandPool_t cpool = NULL;
    VkCommandBuffer_t cbuf = NULL;
    int out_rc = 0;
    AesirVkShaderModuleCreateInfo smci; memset(&smci, 0, sizeof(smci));
    smci.sType = 16; smci.codeSize = kAttentionPrefillSpvBytes; smci.pCode = kAttentionPrefillSpv;
    rc = (int)d_create_shader_module(g_device, &smci, NULL, &shader);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetLayoutBinding binds[4]; memset(binds, 0, sizeof(binds));
    for (int i = 0; i < 4; i++) { binds[i].binding = (uint32_t)i; binds[i].descriptorType = 6; binds[i].descriptorCount = 1; binds[i].stageFlags = 0x20u; }
    AesirVkDescriptorSetLayoutCreateInfo dslci; memset(&dslci, 0, sizeof(dslci));
    dslci.sType = 32; dslci.bindingCount = 4; dslci.pBindings = binds;
    rc = (int)d_create_dsl(g_device, &dslci, NULL, &dsl);
    if (rc != 0) { out_rc = rc; goto done; }
    struct { uint32_t head_dim; uint32_t max_len; uint32_t chunk_start; uint32_t tokens; uint32_t num_heads; uint32_t kv_per_query; } push;
    push.head_dim = head_dim; push.max_len = max_len; push.chunk_start = chunk_start; push.tokens = tokens; push.num_heads = num_heads; push.kv_per_query = kv_per_query;
    AesirVkPushConstantRange pcr; memset(&pcr, 0, sizeof(pcr));
    pcr.stageFlags = 0x20u; pcr.offset = 0; pcr.size = 24;
    AesirVkPipelineLayoutCreateInfo plci; memset(&plci, 0, sizeof(plci));
    plci.sType = 30; plci.setLayoutCount = 1; plci.pSetLayouts = &dsl; plci.pushConstantRangeCount = 1; plci.pPushConstantRanges = &pcr;
    rc = (int)d_create_pl(g_device, &plci, NULL, &pl);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkComputePipelineCreateInfo cpci; memset(&cpci, 0, sizeof(cpci));
    cpci.sType = 29; cpci.stage.sType = 18; cpci.stage.stage = 0x20u; cpci.stage.module = shader; cpci.stage.pName = "main"; cpci.layout = pl; cpci.basePipelineIndex = -1;
    rc = (int)d_create_cp(g_device, NULL, 1, &cpci, NULL, &pipe);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorPoolSize psz; memset(&psz, 0, sizeof(psz));
    psz.type = 6; psz.descriptorCount = 4;
    AesirVkDescriptorPoolCreateInfo dpci; memset(&dpci, 0, sizeof(dpci));
    dpci.sType = 33; dpci.maxSets = 1; dpci.poolSizeCount = 1; dpci.pPoolSizes = &psz;
    rc = (int)d_create_dpool(g_device, &dpci, NULL, &dpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorSetAllocateInfo dsai; memset(&dsai, 0, sizeof(dsai));
    dsai.sType = 34; dsai.descriptorPool = dpool; dsai.descriptorSetCount = 1; dsai.pSetLayouts = &dsl;
    rc = (int)d_alloc_dsets(g_device, &dsai, &dset);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkDescriptorBufferInfo dbi[4]; memset(dbi, 0, sizeof(dbi));
    dbi[0].buffer = sq->buffer; dbi[0].range = need_q;
    dbi[1].buffer = sk->buffer; dbi[1].range = need_kv;
    dbi[2].buffer = sv->buffer; dbi[2].range = need_kv;
    dbi[3].buffer = so->buffer; dbi[3].range = need_q;
    AesirVkWriteDescriptorSet writes[4]; memset(writes, 0, sizeof(writes));
    for (int i = 0; i < 4; i++) { writes[i].sType = 35; writes[i].dstSet = dset; writes[i].dstBinding = (uint32_t)i; writes[i].descriptorCount = 1; writes[i].descriptorType = 6; writes[i].pBufferInfo = &dbi[i]; }
    d_update_dsets(g_device, 4, writes, 0, NULL);
    AesirVkCommandPoolCreateInfo cpi; memset(&cpi, 0, sizeof(cpi));
    cpi.sType = 39; cpi.queueFamilyIndex = g_queue_family;
    rc = (int)d_create_cpool(g_device, &cpi, NULL, &cpool);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferAllocateInfo cbai; memset(&cbai, 0, sizeof(cbai));
    cbai.sType = 40; cbai.commandPool = cpool; cbai.level = 0; cbai.commandBufferCount = 1;
    rc = (int)d_alloc_cbufs(g_device, &cbai, &cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkCommandBufferBeginInfo cbbi; memset(&cbbi, 0, sizeof(cbbi));
    cbbi.sType = 42;
    rc = (int)d_begin_cbuf(cbuf, &cbbi);
    if (rc != 0) { out_rc = rc; goto done; }
    d_cmd_bind_pipeline(cbuf, 1, pipe);
    d_cmd_bind_dsets(cbuf, 1, pl, 0, 1, &dset, 0, NULL);
    d_cmd_push(cbuf, pl, 0x20u, 0, 24, &push);
    uint32_t groups = (tokens * num_heads + 31u) / 32u;
    d_cmd_dispatch(cbuf, groups, 1, 1);
    rc = (int)d_end_cbuf(cbuf);
    if (rc != 0) { out_rc = rc; goto done; }
    AesirVkSubmitInfo si; memset(&si, 0, sizeof(si));
    si.sType = 4; si.commandBufferCount = 1; si.pCommandBuffers = &cbuf;
    rc = (int)d_queue_submit(g_queue, 1, &si, NULL);
    if (rc != 0) { out_rc = rc; goto done; }
    rc = (int)d_queue_wait_idle(g_queue);
    if (rc != 0) { out_rc = rc; goto done; }
    g_prefill_attn_dispatches += 1;
    out_rc = 0;
done:
    if (cpool != NULL) { d_destroy_cpool(g_device, cpool, NULL); }
    if (dpool != NULL) { d_destroy_dpool(g_device, dpool, NULL); }
    if (pipe != NULL) { d_destroy_pipeline(g_device, pipe, NULL); }
    if (pl != NULL) { d_destroy_pl(g_device, pl, NULL); }
    if (dsl != NULL) { d_destroy_dsl(g_device, dsl, NULL); }
    if (shader != NULL) { d_destroy_shader_module(g_device, shader, NULL); }
    return out_rc;
}
