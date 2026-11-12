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
} AesirVkBufferSlot;

static AesirVkBufferSlot g_slots[AESIR_VK_MAX_BUFFERS];
static uint64_t g_live_bytes = 0;
static int g_live_count = 0;

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

int aesir_vk_buffer_alloc(uint64_t size, uint64_t *out_id,
                          uint64_t *out_alloc_size,
                          uint64_t *out_alignment,
                          uint32_t *out_type_index) {
    int rc = aesir_vk_init();
    if (rc != 0) {
        return rc;
    }
    if (size == 0) {
        return AESIR_VK_INVALID;
    }
    int slot = -1;
    for (int i = 0; i < AESIR_VK_MAX_BUFFERS; i++) {
        if (!g_slots[i].in_use) {
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
    if (find_host_coherent_type(reqs.memoryTypeBits, &tindex, 1) != 0) {
        p_destroy_buffer(g_device, buf, NULL);
        /* No host-visible coherent type for this buffer: fail closed.
         * (VK_ERROR_FEATURE_NOT_PRESENT = -8 is the closest VkResult;
         * the Mojo side reports the message text, not just the code.) */
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
    g_live_bytes += (uint64_t)reqs.size;
    g_live_count += 1;
    if (out_id) {
        *out_id = (uint64_t)(slot + 1);
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
    return 0;
}

static AesirVkBufferSlot *slot_for(uint64_t id) {
    if (id == 0 || id > AESIR_VK_MAX_BUFFERS) {
        return NULL;
    }
    AesirVkBufferSlot *s = &g_slots[id - 1];
    return s->in_use ? s : NULL;
}

int aesir_vk_buffer_map(uint64_t id, uint64_t *out_addr) {
    int rc = aesir_vk_init();
    if (rc != 0) {
        return rc;
    }
    AesirVkBufferSlot *s = slot_for(id);
    if (s == NULL) {
        return AESIR_VK_INVALID;
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
    AesirVkBufferSlot *s = slot_for(id);
    if (s == NULL) {
        return AESIR_VK_INVALID;
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
    AesirVkBufferSlot *s = slot_for(id);
    if (s == NULL) {
        return AESIR_VK_INVALID;
    }
    if (s->mapped) {
        p_unmap_mem(g_device, s->memory);
        s->mapped = 0;
    }
    p_destroy_buffer(g_device, s->buffer, NULL);
    p_free_mem(g_device, s->memory, NULL);
    g_live_bytes -= s->alloc_size;
    g_live_count -= 1;
    memset(s, 0, sizeof(*s));
    return 0;
}

uint64_t aesir_vk_live_bytes(void) {
    return g_live_bytes;
}

int aesir_vk_live_count(void) {
    return g_live_count;
}
