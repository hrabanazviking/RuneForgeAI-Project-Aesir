/* a006_vk_probe.c - A-006 Vulkan compute readiness probe (team-06).
 * System-level RADV proof, independent of the engine wrappers:
 * enumerates physical devices, prints properties + queue families,
 * selects ONLY the AMD RADV gfx1151 device (vendor 0x1002, device
 * 0x1586, name contains "8060S"/"RADV"); a run that finds only
 * llvmpipe FAILS (exit 10) - a CPU fallback is never accepted.
 * Creates instance/logical device/queue/command pool on the RADV
 * device, then loads the SPIR-V module named by argv[1] (compiled
 * by glslangValidator from a006_trivial.comp) and creates a shader
 * module on that device. Prints A006_PROBE_PASS on success. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <vulkan/vulkan.h>

static void flag_names(VkQueueFlags f, char *buf, size_t n) {
    buf[0] = 0;
    if (f & VK_QUEUE_GRAPHICS_BIT) strncat(buf, "GRAPHICS ", n - strlen(buf) - 1);
    if (f & VK_QUEUE_COMPUTE_BIT) strncat(buf, "COMPUTE ", n - strlen(buf) - 1);
    if (f & VK_QUEUE_TRANSFER_BIT) strncat(buf, "TRANSFER ", n - strlen(buf) - 1);
    if (f & VK_QUEUE_SPARSE_BINDING_BIT) strncat(buf, "SPARSE ", n - strlen(buf) - 1);
    if (f & VK_QUEUE_PROTECTED_BIT) strncat(buf, "PROTECTED ", n - strlen(buf) - 1);
    if (f & VK_QUEUE_VIDEO_DECODE_BIT_KHR) strncat(buf, "VIDDEC ", n - strlen(buf) - 1);
    if (f & VK_QUEUE_VIDEO_ENCODE_BIT_KHR) strncat(buf, "VIDENC ", n - strlen(buf) - 1);
}

int main(int argc, char **argv) {
    if (argc < 2) { printf("usage: a006_vk_probe <module.spv>\n"); return 64; }
    VkApplicationInfo app; memset(&app, 0, sizeof(app));
    app.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    app.pApplicationName = "A-006 readiness probe";
    app.apiVersion = VK_API_VERSION_1_2;
    VkInstanceCreateInfo ci; memset(&ci, 0, sizeof(ci));
    ci.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    ci.pApplicationInfo = &app;
    VkInstance inst = NULL;
    VkResult rc = vkCreateInstance(&ci, NULL, &inst);
    printf("vkCreateInstance rc=%d\n", (int)rc);
    if (rc != VK_SUCCESS) return 1;
    uint32_t ver = 0;
    rc = vkEnumerateInstanceVersion(&ver);
    printf("vkEnumerateInstanceVersion rc=%d version=%u.%u.%u\n", (int)rc,
           VK_VERSION_MAJOR(ver), VK_VERSION_MINOR(ver), VK_VERSION_PATCH(ver));
    uint32_t count = 0;
    rc = vkEnumeratePhysicalDevices(inst, &count, NULL);
    printf("vkEnumeratePhysicalDevices rc=%d count=%u\n", (int)rc, count);
    if (rc != VK_SUCCESS || count == 0) return 2;
    VkPhysicalDevice devs[16];
    if (count > 16) count = 16;
    rc = vkEnumeratePhysicalDevices(inst, &count, devs);
    if (rc != VK_SUCCESS) return 3;
    int chosen = -1, chosen_qf = -1;
    for (uint32_t d = 0; d < count; d++) {
        VkPhysicalDeviceDriverProperties drv; memset(&drv, 0, sizeof(drv));
        drv.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_DRIVER_PROPERTIES;
        VkPhysicalDeviceProperties2 p2; memset(&p2, 0, sizeof(p2));
        p2.sType = VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2;
        p2.pNext = &drv;
        vkGetPhysicalDeviceProperties2(devs[d], &p2);
        VkPhysicalDeviceProperties *p = &p2.properties;
        printf("DEVICE %u name=%s vendor=0x%04x device_id=0x%04x api=%u.%u.%u type=%d\n",
               d, p->deviceName, p->vendorID, p->deviceID,
               VK_VERSION_MAJOR(p->apiVersion), VK_VERSION_MINOR(p->apiVersion),
               VK_VERSION_PATCH(p->apiVersion), (int)p->deviceType);
        printf("  driver_id=%d driver_name=%s driver_info=%s driver_version=0x%08x conformance=%d.%d.%d.%d\n",
               (int)drv.driverID, drv.driverName, drv.driverInfo, p->driverVersion,
               drv.conformanceVersion.major, drv.conformanceVersion.minor,
               drv.conformanceVersion.subminor, drv.conformanceVersion.patch);
        printf("  limits maxComputeWorkGroupInvocations=%u maxComputeWorkGroupSize=[%u,%u,%u] maxComputeWorkGroupCount=[%u,%u,%u] maxStorageBufferRange=%u maxPushConstantsSize=%u maxMemoryAllocationCount=%u\n",
               p->limits.maxComputeWorkGroupInvocations,
               p->limits.maxComputeWorkGroupSize[0], p->limits.maxComputeWorkGroupSize[1], p->limits.maxComputeWorkGroupSize[2],
               p->limits.maxComputeWorkGroupCount[0], p->limits.maxComputeWorkGroupCount[1], p->limits.maxComputeWorkGroupCount[2],
               p->limits.maxStorageBufferRange, p->limits.maxPushConstantsSize, p->limits.maxMemoryAllocationCount);
        printf("  limits maxComputeSharedMemorySize=%u timestampPeriod=%.3f minMemoryMapAlignment=%zu nonCoherentAtomSize=%llu\n",
               p->limits.maxComputeSharedMemorySize, p->limits.timestampPeriod,
               p->limits.minMemoryMapAlignment, (unsigned long long)p->limits.nonCoherentAtomSize);
        uint32_t qfc = 0;
        vkGetPhysicalDeviceQueueFamilyProperties(devs[d], &qfc, NULL);
        VkQueueFamilyProperties qfs[64];
        if (qfc > 64) qfc = 64;
        vkGetPhysicalDeviceQueueFamilyProperties(devs[d], &qfc, qfs);
        int dev_qf = -1;
        for (uint32_t q = 0; q < qfc; q++) {
            char names[160]; flag_names(qfs[q].queueFlags, names, sizeof(names));
            printf("  QF %u flags=0x%x (%s) count=%u timestampValidBits=%u\n",
                   q, qfs[q].queueFlags, names, qfs[q].queueCount, qfs[q].timestampValidBits);
            if (dev_qf < 0 && (qfs[q].queueFlags & VK_QUEUE_COMPUTE_BIT)) dev_qf = (int)q;
        }
        int is_radv = (p->vendorID == 0x1002) && (p->deviceID == 0x1586)
                      && (strstr(p->deviceName, "8060S") != NULL);
        printf("  is_radv_gfx1151=%d compute_qf=%d\n", is_radv, dev_qf);
        if (chosen < 0 && is_radv && dev_qf >= 0) { chosen = (int)d; chosen_qf = dev_qf; }
    }
    if (chosen < 0) {
        printf("A006_PROBE_FAIL no RADV gfx1151 device with a compute queue (llvmpipe-only or absent is NOT accepted)\n");
        vkDestroyInstance(inst, NULL);
        return 10;
    }
    printf("SELECTED device=%d queue_family=%d (RADV gfx1151, compute-capable)\n", chosen, chosen_qf);
    float prio = 1.0f;
    VkDeviceQueueCreateInfo qci; memset(&qci, 0, sizeof(qci));
    qci.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    qci.queueFamilyIndex = (uint32_t)chosen_qf; qci.queueCount = 1; qci.pQueuePriorities = &prio;
    VkDeviceCreateInfo dci; memset(&dci, 0, sizeof(dci));
    dci.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    dci.queueCreateInfoCount = 1; dci.pQueueCreateInfos = &qci;
    VkDevice dev = NULL;
    rc = vkCreateDevice(devs[chosen], &dci, NULL, &dev);
    printf("vkCreateDevice rc=%d\n", (int)rc);
    if (rc != VK_SUCCESS) return 5;
    VkQueue queue = NULL;
    vkGetDeviceQueue(dev, (uint32_t)chosen_qf, 0, &queue);
    printf("vkGetDeviceQueue queue=%p\n", (void *)queue);
    VkCommandPoolCreateInfo pci; memset(&pci, 0, sizeof(pci));
    pci.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO;
    pci.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    pci.queueFamilyIndex = (uint32_t)chosen_qf;
    VkCommandPool pool = NULL;
    rc = vkCreateCommandPool(dev, &pci, NULL, &pool);
    printf("vkCreateCommandPool rc=%d pool=%p\n", (int)rc, (void *)pool);
    if (rc != VK_SUCCESS) return 6;
    /* SPIR-V module on the RADV device */
    FILE *f = fopen(argv[1], "rb");
    if (!f) { printf("A006_PROBE_FAIL cannot open %s\n", argv[1]); return 7; }
    fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET);
    if (sz <= 0 || (sz % 4) != 0) { printf("A006_PROBE_FAIL bad spv size %ld\n", sz); fclose(f); return 7; }
    uint32_t *code = (uint32_t *)malloc((size_t)sz);
    if (fread(code, 1, (size_t)sz, f) != (size_t)sz) { printf("A006_PROBE_FAIL short read\n"); fclose(f); return 7; }
    fclose(f);
    printf("SPV size=%ld magic=0x%08x version_word=0x%08x generator=0x%08x\n",
           sz, code[0], code[1], code[3]);
    if (code[0] != 0x07230203u) { printf("A006_PROBE_FAIL bad SPIR-V magic\n"); return 8; }
    VkShaderModuleCreateInfo sci; memset(&sci, 0, sizeof(sci));
    sci.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO;
    sci.codeSize = (size_t)sz; sci.pCode = code;
    VkShaderModule mod = NULL;
    rc = vkCreateShaderModule(dev, &sci, NULL, &mod);
    printf("vkCreateShaderModule rc=%d module=%p (on RADV device %d)\n", (int)rc, (void *)mod, chosen);
    if (rc != VK_SUCCESS) return 9;
    vkDestroyShaderModule(dev, mod, NULL);
    free(code);
    rc = vkDeviceWaitIdle(dev);
    printf("vkDeviceWaitIdle rc=%d\n", (int)rc);
    vkDestroyCommandPool(dev, pool, NULL);
    vkDestroyDevice(dev, NULL);
    vkDestroyInstance(inst, NULL);
    printf("VERDICT DEVICE_IS_RADV_GFX1151=YES COMPUTE_QUEUE_OK=YES SPIRV_MODULE_CREATED_ON_DEVICE=YES\n");
    printf("A006_PROBE_PASS\n");
    return 0;
}
