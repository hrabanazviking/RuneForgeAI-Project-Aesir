/* vulkan_context_shim.c — Vulkan context C ABI for Project Aesir
 * (slice A-013).
 *
 * Why a shim: same reason as hip_memory_shim.c (A-011) and the repo's
 * established staging pattern (hailo10h_stub.c, thread_par.c) — all
 * dynamic loading lives in C; the Mojo side (core/vulkan_context.mojo)
 * calls this flat aesir_vk_* ABI through external_call. The shim
 * dlopens libvulkan (unversioned name first, then the versioned
 * soname the distro loader package actually installs) and keeps the
 * handle for the process lifetime.
 *
 * Contract: every fallible function returns the Vulkan VkResult
 * verbatim (0 = VK_SUCCESS), or a shim sentinel:
 *   -1000 AESIR_VK_ABSENT          libvulkan not loadable / an entry
 *                                  point did not resolve
 *   -1001 AESIR_VK_NO_DEVICE       instance enumerated zero physical
 *                                  devices
 *   -1002 AESIR_VK_NO_QUEUE_FAMILY devices exist but none exposes a
 *                                  compute queue family
 * Nothing is simulated: a success return means the driver call
 * succeeded on the real device.
 *
 * Forced-failure hook (for the taxonomy tests): aesir_vk_inject_failure
 * arms a ONE-SHOT failure for a stage (1=create instance,
 * 2=select/enumerate device, 3=create device, 4=create command
 * pool). The next call at that stage returns the injected VkResult
 * without touching the driver, and the injection is consumed. This
 * lets tests prove every failure maps to the repo error taxonomy
 * instead of crashing, on any host, deterministically.
 */

#include <dlfcn.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <vulkan/vulkan.h>

#define AESIR_VK_ABSENT (-1000)
#define AESIR_VK_NO_DEVICE (-1001)
#define AESIR_VK_NO_QUEUE_FAMILY (-1002)

typedef VkResult (*vk_create_instance_fn)(const VkInstanceCreateInfo *,
                                          const VkAllocationCallbacks *,
                                          VkInstance *);
typedef void (*vk_destroy_instance_fn)(VkInstance,
                                       const VkAllocationCallbacks *);
typedef VkResult (*vk_enumerate_physical_devices_fn)(VkInstance, uint32_t *,
                                                     VkPhysicalDevice *);
typedef void (*vk_get_physical_device_properties_fn)(
    VkPhysicalDevice, VkPhysicalDeviceProperties *);
typedef void (*vk_get_physical_device_queue_family_properties_fn)(
    VkPhysicalDevice, uint32_t *, VkQueueFamilyProperties *);
typedef VkResult (*vk_create_device_fn)(VkPhysicalDevice,
                                        const VkDeviceCreateInfo *,
                                        const VkAllocationCallbacks *,
                                        VkDevice *);
typedef void (*vk_destroy_device_fn)(VkDevice, const VkAllocationCallbacks *);
typedef void (*vk_get_device_queue_fn)(VkDevice, uint32_t, uint32_t, VkQueue *);
typedef VkResult (*vk_enumerate_device_extension_properties_fn)(
    VkPhysicalDevice, const char *, uint32_t *, VkExtensionProperties *);
typedef void (*vk_get_physical_device_properties2_fn)(
    VkPhysicalDevice, VkPhysicalDeviceProperties2 *);
typedef VkResult (*vk_create_command_pool_fn)(VkDevice,
                                              const VkCommandPoolCreateInfo *,
                                              const VkAllocationCallbacks *,
                                              VkCommandPool *);
typedef void (*vk_destroy_command_pool_fn)(VkDevice, VkCommandPool,
                                           const VkAllocationCallbacks *);
typedef VkResult (*vk_device_wait_idle_fn)(VkDevice);

static void *g_handle = NULL;
static vk_create_instance_fn g_create_instance = NULL;
static vk_destroy_instance_fn g_destroy_instance = NULL;
static vk_enumerate_physical_devices_fn g_enumerate = NULL;
static vk_get_physical_device_properties_fn g_props = NULL;
static vk_get_physical_device_queue_family_properties_fn g_qf_props = NULL;
static vk_create_device_fn g_create_device = NULL;
static vk_destroy_device_fn g_destroy_device = NULL;
static vk_get_device_queue_fn g_get_queue = NULL;
static vk_create_command_pool_fn g_create_pool = NULL;
static vk_destroy_command_pool_fn g_destroy_pool = NULL;
static vk_device_wait_idle_fn g_wait_idle = NULL;
static vk_enumerate_device_extension_properties_fn g_enum_ext = NULL;
static vk_get_physical_device_properties2_fn g_props2 = NULL;
static int g_subgroup_size_control = 0;
static int g_tried = 0;
static int g_ok = 0;

static int32_t g_inject_stage = 0;
static int32_t g_inject_result = 0;

static void aesir_vk_init(void) {
    if (g_tried) {
        return;
    }
    g_tried = 1;
    const char *names[] = {"libvulkan.so", "libvulkan.so.1", NULL};
    for (int i = 0; names[i] != NULL; i++) {
        g_handle = dlopen(names[i], RTLD_NOW);
        if (g_handle != NULL) {
            break;
        }
    }
    if (g_handle == NULL) {
        return;
    }
    g_create_instance =
        (vk_create_instance_fn)dlsym(g_handle, "vkCreateInstance");
    g_destroy_instance =
        (vk_destroy_instance_fn)dlsym(g_handle, "vkDestroyInstance");
    g_enumerate = (vk_enumerate_physical_devices_fn)dlsym(
        g_handle, "vkEnumeratePhysicalDevices");
    g_props = (vk_get_physical_device_properties_fn)dlsym(
        g_handle, "vkGetPhysicalDeviceProperties");
    g_qf_props = (vk_get_physical_device_queue_family_properties_fn)dlsym(
        g_handle, "vkGetPhysicalDeviceQueueFamilyProperties");
    g_create_device = (vk_create_device_fn)dlsym(g_handle, "vkCreateDevice");
    g_destroy_device =
        (vk_destroy_device_fn)dlsym(g_handle, "vkDestroyDevice");
    g_get_queue = (vk_get_device_queue_fn)dlsym(g_handle, "vkGetDeviceQueue");
    g_create_pool =
        (vk_create_command_pool_fn)dlsym(g_handle, "vkCreateCommandPool");
    g_destroy_pool = (vk_destroy_command_pool_fn)dlsym(
        g_handle, "vkDestroyCommandPool");
    g_wait_idle = (vk_device_wait_idle_fn)dlsym(g_handle, "vkDeviceWaitIdle");
    /* A-074: optional entry points (not part of g_ok): device
     * extension enumeration for VK_EXT_subgroup_size_control and
     * the Vulkan 1.1 core Properties2 query for subgroup facts. */
    g_enum_ext = (vk_enumerate_device_extension_properties_fn)dlsym(
        g_handle, "vkEnumerateDeviceExtensionProperties");
    g_props2 = (vk_get_physical_device_properties2_fn)dlsym(
        g_handle, "vkGetPhysicalDeviceProperties2");
    if (g_props2 == NULL) {
        g_props2 = (vk_get_physical_device_properties2_fn)dlsym(
            g_handle, "vkGetPhysicalDeviceProperties2KHR");
    }
    g_ok = (g_create_instance != NULL && g_destroy_instance != NULL &&
            g_enumerate != NULL && g_props != NULL && g_qf_props != NULL &&
            g_create_device != NULL && g_destroy_device != NULL &&
            g_get_queue != NULL && g_create_pool != NULL &&
            g_destroy_pool != NULL && g_wait_idle != NULL);
}

static int take_injection(int32_t stage, int32_t *out_result) {
    if (g_inject_stage == stage) {
        *out_result = g_inject_result;
        g_inject_stage = 0;
        g_inject_result = 0;
        return 1;
    }
    return 0;
}

int aesir_vk_available(void) {
    aesir_vk_init();
    return g_ok ? 1 : 0;
}

void aesir_vk_inject_failure(int32_t stage, int32_t result) {
    g_inject_stage = stage;
    g_inject_result = result;
}

void aesir_vk_clear_injection(void) {
    g_inject_stage = 0;
    g_inject_result = 0;
}

int aesir_vk_create_instance(uint64_t *out) {
    aesir_vk_init();
    if (!g_ok) {
        return AESIR_VK_ABSENT;
    }
    int32_t injected = 0;
    if (take_injection(1, &injected)) {
        return injected;
    }
    VkApplicationInfo app;
    memset(&app, 0, sizeof(app));
    app.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    app.pApplicationName = "Project Aesir (A-013)";
    app.applicationVersion = VK_MAKE_VERSION(0, 1, 0);
    app.pEngineName = "Aesir";
    app.engineVersion = VK_MAKE_VERSION(0, 1, 0);
    /* A-074 migration: the instance is created at Vulkan 1.1 so
     * SPIR-V 1.3 modules (subgroup arithmetic, compiled per-kernel
     * at --target-env vulkan1.1 by scripts/build_shaders.py) are
     * inside the declared level. All pre-A-074 kernels remain
     * SPIR-V 1.0 modules and run unchanged under 1.1. */
    app.apiVersion = VK_API_VERSION_1_1;
    VkInstanceCreateInfo ci;
    memset(&ci, 0, sizeof(ci));
    ci.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    ci.pApplicationInfo = &app;
    VkInstance inst = NULL;
    VkResult rc = g_create_instance(&ci, NULL, &inst);
    if (rc == VK_SUCCESS) {
        *out = (uint64_t)(uintptr_t)inst;
    }
    return (int)rc;
}

int aesir_vk_select_device(uint64_t inst, uint64_t *dev_out,
                           int32_t *qf_out, int32_t *qf_count_out,
                           int32_t *dev_index_out) {
    aesir_vk_init();
    if (!g_ok) {
        return AESIR_VK_ABSENT;
    }
    int32_t injected = 0;
    if (take_injection(2, &injected)) {
        return injected;
    }
    VkInstance vk_inst = (VkInstance)(uintptr_t)inst;
    uint32_t count = 0;
    VkResult rc = g_enumerate(vk_inst, &count, NULL);
    if (rc != VK_SUCCESS) {
        return (int)rc;
    }
    if (count == 0) {
        return AESIR_VK_NO_DEVICE;
    }
    if (count > 16) {
        count = 16;
    }
    VkPhysicalDevice devices[16];
    rc = g_enumerate(vk_inst, &count, devices);
    if (rc != VK_SUCCESS) {
        return (int)rc;
    }
    for (uint32_t d = 0; d < count; d++) {
        uint32_t qf_count = 0;
        g_qf_props(devices[d], &qf_count, NULL);
        if (qf_count == 0 || qf_count > 64) {
            continue;
        }
        VkQueueFamilyProperties qfs[64];
        g_qf_props(devices[d], &qf_count, qfs);
        for (uint32_t q = 0; q < qf_count; q++) {
            if (qfs[q].queueFlags & VK_QUEUE_COMPUTE_BIT) {
                *dev_out = (uint64_t)(uintptr_t)devices[d];
                *qf_out = (int32_t)q;
                *qf_count_out = (int32_t)qfs[q].queueCount;
                *dev_index_out = (int32_t)d;
                return VK_SUCCESS;
            }
        }
    }
    return AESIR_VK_NO_QUEUE_FAMILY;
}

int aesir_vk_device_info(uint64_t dev, char *name_out, uint32_t *vendor_out,
                         uint32_t *device_id_out, uint32_t *api_out,
                         int32_t *type_out) {
    aesir_vk_init();
    if (!g_ok) {
        return AESIR_VK_ABSENT;
    }
    VkPhysicalDeviceProperties props;
    g_props((VkPhysicalDevice)(uintptr_t)dev, &props);
    memset(name_out, 0, 256);
    strncpy(name_out, props.deviceName, 255);
    *vendor_out = props.vendorID;
    *device_id_out = props.deviceID;
    *api_out = props.apiVersion;
    *type_out = (int32_t)props.deviceType;
    return VK_SUCCESS;
}

int aesir_vk_create_device(uint64_t phys, int32_t qf, uint64_t *out) {
    aesir_vk_init();
    if (!g_ok) {
        return AESIR_VK_ABSENT;
    }
    int32_t injected = 0;
    if (take_injection(3, &injected)) {
        return injected;
    }
    float priority = 1.0f;
    VkDeviceQueueCreateInfo qci;
    memset(&qci, 0, sizeof(qci));
    qci.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    qci.queueFamilyIndex = (uint32_t)qf;
    qci.queueCount = 1;
    qci.pQueuePriorities = &priority;
    VkDeviceCreateInfo ci;
    memset(&ci, 0, sizeof(ci));
    ci.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    ci.queueCreateInfoCount = 1;
    ci.pQueueCreateInfos = &qci;
    /* A-074: enable VK_EXT_subgroup_size_control when the device
     * offers it, so pipelines may pin requiredSubgroupSize (the
     * buffer shim's dispatch device enables it too (A-074, in
     * vulkan_buffer_shim.c, with the requiredSubgroupSize pin).
     * Additive only:
     * no existing behaviour changes when it is absent. */
    VkPhysicalDeviceSubgroupSizeControlFeatures sg_features;
    memset(&sg_features, 0, sizeof(sg_features));
    sg_features.sType =
        VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_SIZE_CONTROL_FEATURES;
    sg_features.subgroupSizeControl = VK_TRUE;
    const char *sg_ext_name = VK_EXT_SUBGROUP_SIZE_CONTROL_EXTENSION_NAME;
    g_subgroup_size_control = 0;
    if (g_enum_ext != NULL) {
        uint32_t ext_count = 0;
        if (g_enum_ext((VkPhysicalDevice)(uintptr_t)phys, NULL,
                       &ext_count, NULL) == VK_SUCCESS &&
            ext_count > 0 && ext_count <= 1024) {
            VkExtensionProperties exts[1024];
            if (g_enum_ext((VkPhysicalDevice)(uintptr_t)phys, NULL,
                           &ext_count, exts) == VK_SUCCESS) {
                for (uint32_t i = 0; i < ext_count; i++) {
                    if (strcmp(exts[i].extensionName, sg_ext_name) == 0) {
                        g_subgroup_size_control = 1;
                        break;
                    }
                }
            }
        }
    }
    if (g_subgroup_size_control) {
        ci.enabledExtensionCount = 1;
        ci.ppEnabledExtensionNames = &sg_ext_name;
        ci.pNext = &sg_features;
    }
    VkDevice dev = NULL;
    VkResult rc = g_create_device((VkPhysicalDevice)(uintptr_t)phys, &ci,
                                  NULL, &dev);
    if (rc != VK_SUCCESS && g_subgroup_size_control) {
        /* A-074 fallback: additive only - retry exactly as
         * pre-A-074 if the driver refuses the extension. */
        g_subgroup_size_control = 0;
        ci.enabledExtensionCount = 0;
        ci.ppEnabledExtensionNames = NULL;
        ci.pNext = NULL;
        rc = g_create_device((VkPhysicalDevice)(uintptr_t)phys, &ci,
                             NULL, &dev);
    }
    if (rc == VK_SUCCESS) {
        *out = (uint64_t)(uintptr_t)dev;
    }
    return (int)rc;
}

int aesir_vk_get_queue(uint64_t dev, int32_t qf, uint64_t *out) {
    aesir_vk_init();
    if (!g_ok) {
        return AESIR_VK_ABSENT;
    }
    VkQueue queue = NULL;
    g_get_queue((VkDevice)(uintptr_t)dev, (uint32_t)qf, 0, &queue);
    if (queue == NULL) {
        return VK_ERROR_INITIALIZATION_FAILED;
    }
    *out = (uint64_t)(uintptr_t)queue;
    return VK_SUCCESS;
}

int aesir_vk_create_command_pool(uint64_t dev, int32_t qf, uint64_t *out) {
    aesir_vk_init();
    if (!g_ok) {
        return AESIR_VK_ABSENT;
    }
    int32_t injected = 0;
    if (take_injection(4, &injected)) {
        return injected;
    }
    VkCommandPoolCreateInfo ci;
    memset(&ci, 0, sizeof(ci));
    ci.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    ci.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    ci.queueFamilyIndex = (uint32_t)qf;
    VkCommandPool pool = NULL;
    VkResult rc = g_create_pool((VkDevice)(uintptr_t)dev, &ci, NULL, &pool);
    if (rc == VK_SUCCESS) {
        *out = (uint64_t)(uintptr_t)pool;
    }
    return (int)rc;
}

int aesir_vk_device_wait_idle(uint64_t dev) {
    aesir_vk_init();
    if (!g_ok) {
        return AESIR_VK_ABSENT;
    }
    return (int)g_wait_idle((VkDevice)(uintptr_t)dev);
}

void aesir_vk_destroy_command_pool(uint64_t dev, uint64_t pool) {
    aesir_vk_init();
    if (!g_ok || pool == 0) {
        return;
    }
    g_destroy_pool((VkDevice)(uintptr_t)dev,
                   (VkCommandPool)(uintptr_t)pool, NULL);
}

void aesir_vk_destroy_device(uint64_t dev) {
    aesir_vk_init();
    if (!g_ok || dev == 0) {
        return;
    }
    g_destroy_device((VkDevice)(uintptr_t)dev, NULL);
}

/* A-074: subgroup facts for a physical device, via the Vulkan 1.1
 * core Properties2 chain (SubgroupProperties +
 * SubgroupSizeControlProperties). Any out pointer may be NULL.
 * Returns VK_SUCCESS, or AESIR_VK_ABSENT when Properties2 did not
 * resolve. Values are the DRIVER's for this device: on RADV
 * STRIX_HALO size=64, min=32, max=64 (measured, A-073/A-074). */
int aesir_vk_subgroup_info(uint64_t dev, uint32_t *size_out,
                           uint32_t *min_out, uint32_t *max_out,
                           uint32_t *stages_out, uint32_t *ops_out,
                           int32_t *size_control_out) {
    aesir_vk_init();
    if (!g_ok || g_props2 == NULL) {
        return AESIR_VK_ABSENT;
    }
    VkPhysicalDeviceSubgroupSizeControlProperties sg_size;
    memset(&sg_size, 0, sizeof(sg_size));
    sg_size.sType =
        VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_SIZE_CONTROL_PROPERTIES;
    VkPhysicalDeviceSubgroupProperties sg;
    memset(&sg, 0, sizeof(sg));
    sg.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SUBGROUP_PROPERTIES;
    sg.pNext = &sg_size;
    VkPhysicalDeviceProperties2 props2;
    memset(&props2, 0, sizeof(props2));
    props2.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
    props2.pNext = &sg;
    g_props2((VkPhysicalDevice)(uintptr_t)dev, &props2);
    if (size_out) { *size_out = sg.subgroupSize; }
    if (min_out) { *min_out = sg_size.minSubgroupSize; }
    if (max_out) { *max_out = sg_size.maxSubgroupSize; }
    if (stages_out) { *stages_out = (uint32_t)sg.supportedStages; }
    if (ops_out) { *ops_out = (uint32_t)sg.supportedOperations; }
    if (size_control_out) { *size_control_out = g_subgroup_size_control; }
    return VK_SUCCESS;
}

void aesir_vk_destroy_instance(uint64_t inst) {
    aesir_vk_init();
    if (!g_ok || inst == 0) {
        return;
    }
    g_destroy_instance((VkInstance)(uintptr_t)inst, NULL);
}
