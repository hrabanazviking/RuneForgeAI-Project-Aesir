# tests/test_vulkan_context.mojo
# Vulkan context wrapper (A-013): real instance/device/queue/
# command-pool creation on the host's Vulkan device (on purpleraider:
# the Radeon 8060S, gfx1151, via Mesa RADV), the pure VkResult ->
# ERROR_TAXONOMY mapping, and forced-failure tests proving every
# bring-up stage maps to a taxonomy entry instead of crashing.
# Hosts without libvulkan take the honest-absent branch: create()
# must fail closed with GPU-002, never simulate a context.

from core.vulkan_context import (
    INJECT_STAGE_COMMAND_POOL,
    INJECT_STAGE_DEVICE,
    INJECT_STAGE_ENUMERATE,
    INJECT_STAGE_INSTANCE,
    VulkanContext,
    taxonomy_code_for_vk_result,
    taxonomy_name_for_code,
)


def expect_code(rc: Int, expected: String, what: String) raises:
    var got = taxonomy_code_for_vk_result(rc)
    if got != expected:
        raise Error(
            "VulkanContext taxonomy " + what + ": expected " + expected
            + ", got " + got
        )


def expect_create_fails_with(expected_code: String, what: String) raises:
    var raised = False
    try:
        var ctx = VulkanContext.create()
        ctx.close()
    except error:
        raised = True
        if expected_code not in String(error):
            raise Error(
                "VulkanContext forced failure " + what + ": expected "
                + "taxonomy code " + expected_code + " in error, got: "
                + String(error)
            )
    if not raised:
        raise Error(
            "VulkanContext forced failure " + what
            + ": create() succeeded despite the injected failure"
        )


def test_vulkan_context_create() raises:
    print("--- Testing Vulkan context creation (A-013) ---")
    if not VulkanContext.runtime_available():
        expect_create_fails_with(
            String("GPU-002"), "honest-absent create"
        )
        print("Vulkan: libvulkan UNAVAILABLE on this host; create() "
              "failed closed with GPU-002 (honest-absent): PASS")
        return
    var ctx = VulkanContext.create()
    print("Vulkan device: " + ctx.info.device_name)
    print(
        "vendor_id=" + String(ctx.info.vendor_id)
        + " device_id=" + String(ctx.info.device_id)
        + " api_version=" + String(ctx.info.api_version)
        + " queue_family=" + String(ctx.info.queue_family_index)
        + " queue_count=" + String(ctx.info.queue_family_count)
    )
    if ctx.info.vendor_id != 0x1002:
        ctx.close()
        raise Error("VulkanContext: expected AMD vendor 0x1002 on Z13")
    if String("RADV") not in ctx.info.device_name and String(
        "8060S"
    ) not in ctx.info.device_name:
        ctx.close()
        raise Error(
            "VulkanContext: device is not the RADV 8060S: "
            + ctx.info.device_name
        )
    if ctx.info.queue_family_index < 0 or ctx.info.queue_family_count < 1:
        ctx.close()
        raise Error("VulkanContext: no compute queue family recorded")
    if ctx.queue_handle() == 0 or ctx.command_pool_handle() == 0:
        ctx.close()
        raise Error("VulkanContext: null queue or command pool handle")
    if not ctx.is_open():
        ctx.close()
        raise Error("VulkanContext: context not open after create")
    ctx.close()
    if ctx.is_open():
        raise Error("VulkanContext: context still open after close")
    ctx.close()  # idempotent: second close must be a no-op, not a crash
    print("Vulkan context create on gfx1151 (RADV): PASS")


def test_vulkan_taxonomy_mapping() raises:
    print("--- Testing Vulkan VkResult -> taxonomy mapping ---")
    expect_code(0, String(""), "VK_SUCCESS is not an error")
    expect_code(-1, String("MEM-001"), "OUT_OF_HOST_MEMORY")
    expect_code(-2, String("MEM-002"), "OUT_OF_DEVICE_MEMORY")
    expect_code(-12, String("MEM-002"), "FRAGMENTED_POOL")
    expect_code(-10, String("MEM-003"), "TOO_MANY_OBJECTS")
    expect_code(-3, String("GPU-001"), "INITIALIZATION_FAILED")
    expect_code(-4, String("GPU-001"), "DEVICE_LOST at bring-up")
    expect_code(-9, String("GPU-006"), "INCOMPATIBLE_DRIVER")
    expect_code(-7, String("GPU-006"), "EXTENSION_NOT_PRESENT")
    expect_code(-1000, String("GPU-002"), "shim absent")
    expect_code(-1001, String("GPU-002"), "shim no device")
    expect_code(-1002, String("GPU-002"), "shim no queue family")
    expect_code(-999, String("GPU-001"), "unmapped code catch-all")
    if taxonomy_name_for_code(String("GPU-002")) != String(
        "DEVICE_NOT_FOUND"
    ):
        raise Error("VulkanContext: GPU-002 taxonomy name drifted")
    if taxonomy_name_for_code(String("MEM-002")) != String(
        "DEVICE_ALLOC_FAILED"
    ):
        raise Error("VulkanContext: MEM-002 taxonomy name drifted")
    print("Vulkan taxonomy mapping (13 codes): PASS")


def test_vulkan_forced_failure_taxonomy() raises:
    print("--- Testing Vulkan forced failures map to taxonomy ---")
    if not VulkanContext.runtime_available():
        print("Vulkan: runtime unavailable; forced-failure battery "
              "not applicable (honest-absent): PASS")
        return
    VulkanContext.inject_failure(INJECT_STAGE_INSTANCE, -9)
    expect_create_fails_with(String("GPU-006"), "instance INCOMPATIBLE_DRIVER")
    VulkanContext.inject_failure(INJECT_STAGE_ENUMERATE, -3)
    expect_create_fails_with(String("GPU-001"), "enumerate INITIALIZATION_FAILED")
    VulkanContext.inject_failure(INJECT_STAGE_DEVICE, -2)
    expect_create_fails_with(String("MEM-002"), "device OUT_OF_DEVICE_MEMORY")
    VulkanContext.inject_failure(INJECT_STAGE_COMMAND_POOL, -1)
    expect_create_fails_with(String("MEM-001"), "pool OUT_OF_HOST_MEMORY")
    # Injections are one-shot and cleanup is complete: a clean
    # create must succeed immediately after the forced failures.
    var ctx = VulkanContext.create()
    ctx.close()
    print("Vulkan forced failures (4 stages) -> taxonomy, no crash: PASS")


def test_vulkan_context_rejection() raises:
    print("--- Testing Vulkan local rejection paths ---")
    var rejected = False
    try:
        _ = VulkanContext.require_valid_queue_family(-1)
    except error:
        rejected = True
        if String("GPU-002") not in String(error):
            raise Error(
                "VulkanContext: negative queue family error lacks "
                "GPU-002: " + String(error)
            )
    if not rejected:
        raise Error("VulkanContext: negative queue family was admitted")
    if VulkanContext.require_valid_queue_family(0) != 0:
        raise Error("VulkanContext: queue family 0 was not admitted")
    print("Vulkan local rejection (negative queue family): PASS")


def main() raises:
    test_vulkan_context_create()
    test_vulkan_taxonomy_mapping()
    test_vulkan_forced_failure_taxonomy()
    test_vulkan_context_rejection()
    print("ALL PASS: vulkan context wrapper (4 groups)")
