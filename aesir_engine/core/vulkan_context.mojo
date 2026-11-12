# core/vulkan_context.mojo
# VulkanContext: Vulkan instance/device/queue/command-pool wrapper for
# the AMD realm (slice A-013).
#
# Real vkCreateInstance / vkEnumeratePhysicalDevices / vkCreateDevice /
# vkGetDeviceQueue / vkCreateCommandPool calls on libvulkan, reached
# through the flat C ABI in aesir_engine/vulkan_context_shim.c
# (libaesir_vulkan.so, staged and linked exactly like libaesir_hip /
# libaesir_hailo10h / libaesir_par; dynamic loading lives in C for the
# Mojo 1.0 dlopen/dlclose signature reason filed in the A-011 ledger).
#
# Error taxonomy (ERROR_TAXONOMY.md): EVERY failure out of this module
# is raised as an Error whose text carries the taxonomy code + name and
# the raw VkResult, never as a crash or a bare code:
#
#   VkResult / condition                              Taxonomy
#   ------------------------------------------------  ------------------
#   -1  VK_ERROR_OUT_OF_HOST_MEMORY                   MEM-001
#   -2  VK_ERROR_OUT_OF_DEVICE_MEMORY                 MEM-002
#   -12 VK_ERROR_FRAGMENTED_POOL                      MEM-002
#   -10 VK_ERROR_TOO_MANY_OBJECTS                     MEM-003
#   -3  VK_ERROR_INITIALIZATION_FAILED                GPU-001
#   -4  VK_ERROR_DEVICE_LOST (at context bring-up)    GPU-001
#   -1000 shim: libvulkan not loadable                GPU-002
#   -1001 shim: zero physical devices enumerated      GPU-002
#   -1002 shim: no compute queue family on any device GPU-002
#   -6/-7/-8 layer/extension/feature not present,     GPU-006
#   -9  VK_ERROR_INCOMPATIBLE_DRIVER
#   any other VkResult (catch-all, raw code kept)     GPU-001
#
# GPU-001/GPU-002/GPU-006 are the taxonomy's GPU-category init /
# not-found / driver-mismatch entries (named for CUDA in the taxonomy
# text; the category codes are the repo-wide GPU failure codes and are
# what this Vulkan path reports under — see the A-013 ledger).
#
# Fail-closed contract: when libvulkan is not loadable, the shim
# reports unavailable and create() raises GPU-002; nothing is
# simulated and no handle is fabricated. A created VulkanContext owns
# its instance/device/command-pool handles and must be released with
# close() exactly once (close() is idempotent; copies share handles,
# so treat one value as the owner).
#
# Forced failures: inject_failure(stage, vk_result) arms the shim's
# one-shot hook (stages: INJECT_STAGE_INSTANCE / _ENUMERATE /
# _DEVICE / _COMMAND_POOL). The next create() fails at that stage
# with that VkResult, so tests prove the taxonomy mapping on any
# host deterministically. The injection is consumed by the attempt.

from std.ffi import external_call
from std.memory import Pointer

comptime VK_SUCCESS = 0
comptime AESIR_VK_ABSENT = -1000
comptime AESIR_VK_NO_DEVICE = -1001
comptime AESIR_VK_NO_QUEUE_FAMILY = -1002

comptime INJECT_STAGE_INSTANCE = 1
comptime INJECT_STAGE_ENUMERATE = 2
comptime INJECT_STAGE_DEVICE = 3
comptime INJECT_STAGE_COMMAND_POOL = 4


def taxonomy_code_for_vk_result(rc: Int) -> String:
    """The ERROR_TAXONOMY code for a VkResult (or shim sentinel).
    VK_SUCCESS maps to the empty string — success is not an error."""
    if rc == VK_SUCCESS:
        return String("")
    if rc == -1:
        return String("MEM-001")
    if rc == -2 or rc == -12:
        return String("MEM-002")
    if rc == -10:
        return String("MEM-003")
    if rc == AESIR_VK_ABSENT or rc == AESIR_VK_NO_DEVICE or rc == AESIR_VK_NO_QUEUE_FAMILY:
        return String("GPU-002")
    if rc == -6 or rc == -7 or rc == -8 or rc == -9:
        return String("GPU-006")
    # -3, -4, and every unmapped code: context-initialisation failure.
    return String("GPU-001")


def taxonomy_name_for_code(code: String) -> String:
    """The ERROR_TAXONOMY name for a code this module can emit."""
    if code == String("MEM-001"):
        return String("HOST_MALLOC_FAILED")
    if code == String("MEM-002"):
        return String("DEVICE_ALLOC_FAILED")
    if code == String("MEM-003"):
        return String("OUT_OF_MEMORY")
    if code == String("GPU-001"):
        return String("GPU_INIT_FAILED")
    if code == String("GPU-002"):
        return String("DEVICE_NOT_FOUND")
    if code == String("GPU-006"):
        return String("DRIVER_VERSION_MISMATCH")
    return String("UNKNOWN")


struct VulkanDeviceInfo(Copyable, ImplicitlyCopyable):
    """The physical device a context was created on."""

    var device_name: String
    var vendor_id: Int
    var device_id: Int
    var api_version: Int
    var device_type: Int
    var device_index: Int
    var queue_family_index: Int
    var queue_family_count: Int

    def __init__(
        out self,
        device_name: String,
        vendor_id: Int,
        device_id: Int,
        api_version: Int,
        device_type: Int,
        device_index: Int,
        queue_family_index: Int,
        queue_family_count: Int,
    ):
        self.device_name = device_name
        self.vendor_id = vendor_id
        self.device_id = device_id
        self.api_version = api_version
        self.device_type = device_type
        self.device_index = device_index
        self.queue_family_index = queue_family_index
        self.queue_family_count = queue_family_count


struct VulkanContext(Copyable, ImplicitlyCopyable):
    """A live Vulkan context: instance + physical device + logical
    device + compute queue + command pool (A-013). See file header."""

    var _instance: Int
    var _physical_device: Int
    var _device: Int
    var _queue: Int
    var _command_pool: Int
    var _closed: Bool
    var info: VulkanDeviceInfo

    def __init__(
        out self,
        instance: Int,
        physical_device: Int,
        device: Int,
        queue: Int,
        command_pool: Int,
        info: VulkanDeviceInfo,
    ):
        self._instance = instance
        self._physical_device = physical_device
        self._device = device
        self._queue = queue
        self._command_pool = command_pool
        self._closed = False
        self.info = info

    @staticmethod
    def runtime_available() -> Bool:
        """True iff the shim loaded libvulkan and resolved every entry
        point. Library-level probe; device presence is create()'s job."""
        return external_call["aesir_vk_available", Int32]() == Int32(1)

    @staticmethod
    def _raise_for_rc(what: String, rc: Int32) raises:
        var code = taxonomy_code_for_vk_result(Int(rc))
        raise Error(
            "VulkanContext." + what + ": " + code + " "
            + taxonomy_name_for_code(code) + " (VkResult "
            + String(Int(rc)) + ")"
        )

    @staticmethod
    def require_valid_queue_family(index: Int) raises -> Int:
        """Local admission: a negative queue-family index is rejected
        before any driver call."""
        if index < 0:
            raise Error(
                "VulkanContext.require_valid_queue_family: GPU-002 "
                "DEVICE_NOT_FOUND (negative queue family index "
                + String(index) + ")"
            )
        return index

    @staticmethod
    def inject_failure(stage: Int, vk_result: Int):
        """Arm the shim's one-shot forced failure for the next
        create() at `stage` (INJECT_STAGE_*), returning `vk_result`."""
        external_call["aesir_vk_inject_failure", NoneType](
            Int32(stage), Int32(vk_result)
        )

    @staticmethod
    def clear_injection():
        external_call["aesir_vk_clear_injection", NoneType]()

    @staticmethod
    def create() raises -> VulkanContext:
        """Full context bring-up on the first physical device with a
        compute queue family: instance -> select device -> device
        properties -> logical device -> queue -> command pool ->
        device-wait-idle proof. Every failure raises a taxonomy
        error and tears down whatever was already created."""
        if not Self.runtime_available():
            raise Error(
                "VulkanContext.create: GPU-002 DEVICE_NOT_FOUND "
                "(libvulkan is not loadable on this host; honest-absent)"
            )
        var instance: Int = 0
        var rc = external_call["aesir_vk_create_instance", Int32](
            Pointer(to=instance)
        )
        if rc != VK_SUCCESS:
            Self._raise_for_rc("create_instance", rc)
        var physical: Int = 0
        var qf: Int32 = -1
        var qf_count: Int32 = 0
        var dev_index: Int32 = -1
        rc = external_call["aesir_vk_select_device", Int32](
            instance, Pointer(to=physical), Pointer(to=qf),
            Pointer(to=qf_count), Pointer(to=dev_index),
        )
        if rc != VK_SUCCESS:
            external_call["aesir_vk_destroy_instance", NoneType](instance)
            Self._raise_for_rc("select_device", rc)
        var qf_index = Self.require_valid_queue_family(Int(qf))
        var name_buf = InlineArray[UInt8, 256](fill=0)
        var vendor: UInt32 = 0
        var device_id: UInt32 = 0
        var api_version: UInt32 = 0
        var device_type: Int32 = 0
        rc = external_call["aesir_vk_device_info", Int32](
            physical, name_buf.unsafe_ptr(), Pointer(to=vendor),
            Pointer(to=device_id), Pointer(to=api_version),
            Pointer(to=device_type),
        )
        if rc != VK_SUCCESS:
            external_call["aesir_vk_destroy_instance", NoneType](instance)
            Self._raise_for_rc("device_info", rc)
        var info = VulkanDeviceInfo(
            String(unsafe_from_utf8_ptr=name_buf.unsafe_ptr()),
            Int(vendor), Int(device_id), Int(api_version),
            Int(device_type), Int(dev_index), qf_index, Int(qf_count),
        )
        var device: Int = 0
        rc = external_call["aesir_vk_create_device", Int32](
            physical, Int32(qf_index), Pointer(to=device)
        )
        if rc != VK_SUCCESS:
            external_call["aesir_vk_destroy_instance", NoneType](instance)
            Self._raise_for_rc("create_device", rc)
        var queue: Int = 0
        rc = external_call["aesir_vk_get_queue", Int32](
            device, Int32(qf_index), Pointer(to=queue)
        )
        if rc != VK_SUCCESS:
            external_call["aesir_vk_destroy_device", NoneType](device)
            external_call["aesir_vk_destroy_instance", NoneType](instance)
            Self._raise_for_rc("get_queue", rc)
        var pool: Int = 0
        rc = external_call["aesir_vk_create_command_pool", Int32](
            device, Int32(qf_index), Pointer(to=pool)
        )
        if rc != VK_SUCCESS:
            external_call["aesir_vk_destroy_device", NoneType](device)
            external_call["aesir_vk_destroy_instance", NoneType](instance)
            Self._raise_for_rc("create_command_pool", rc)
        rc = external_call["aesir_vk_device_wait_idle", Int32](device)
        if rc != VK_SUCCESS:
            external_call["aesir_vk_destroy_command_pool", NoneType](
                device, pool
            )
            external_call["aesir_vk_destroy_device", NoneType](device)
            external_call["aesir_vk_destroy_instance", NoneType](instance)
            Self._raise_for_rc("device_wait_idle", rc)
        return VulkanContext(instance, physical, device, queue, pool, info)

    def is_open(self) -> Bool:
        return not self._closed

    def queue_handle(self) -> Int:
        return self._queue

    def command_pool_handle(self) -> Int:
        return self._command_pool

    def close(mut self):
        """Destroy pool -> device -> instance, in reverse creation
        order. Idempotent: a second close() is a no-op."""
        if self._closed:
            return
        self._closed = True
        if self._command_pool != 0:
            external_call["aesir_vk_destroy_command_pool", NoneType](
                self._device, self._command_pool
            )
            self._command_pool = 0
        if self._device != 0:
            external_call["aesir_vk_destroy_device", NoneType](self._device)
            self._device = 0
        if self._instance != 0:
            external_call["aesir_vk_destroy_instance", NoneType](
                self._instance
            )
            self._instance = 0
        self._queue = 0
