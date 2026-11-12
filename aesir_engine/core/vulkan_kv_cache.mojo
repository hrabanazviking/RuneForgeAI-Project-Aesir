# core/vulkan_kv_cache.mojo
# VulkanKvCache + VulkanEmbed: data-movement gateways (A-066).
#
# VulkanKvCache.append closes the A-065 KV-APPEND GAP: the
# A-065 layer is a single-position decode layer because no
# Wave 7 kernel could insert a step's k/v projection row into
# a multi-position KV cache. The kv_append compute kernel
# (aesir_engine/shaders/kv_append.comp, A-055 pipeline, SPIR-V
# via the generated header) copies src [kv_heads][head_dim]
# into cache [kv_heads][max_len][head_dim] at slot `position` -
# exactly the layout the A-062 decode-attention kernel reads.
# It is a compute dispatch, not a host copy and not
# vkCmdCopyBuffer (the A-019 zero-copy counter still cannot
# increment). VulkanEmbed.gather copies embedding row `token`
# of the Float32 table [vocab][dim] into the step input row.
#
# Fail-closed contract (matches A-056..A-065): every shape and
# buffer is validated BEFORE any dispatch; when the Vulkan
# runtime or the RADV device is unavailable the shim raises -
# no host fallback is fabricated. dispatch_count() reads the
# shim counters that increment only after a submit +
# queue-wait-idle completed on the device (law 6 evidence).

from std.ffi import external_call
from core.vulkan_buffers import VulkanBuffers, VulkanAllocation

comptime _VK_ABSENT = -1000000
comptime _VK_INVALID = -1000001


def _raise_for_rc(what: String, rc: Int32) raises:
    if Int(rc) == _VK_ABSENT:
        raise Error(
            "GPU-002 DEVICE_NOT_FOUND: " + what + ": Vulkan loader or dispatch"
            " entry points are not loadable on this host"
            " (honest-absent)"
        )
    if Int(rc) == _VK_INVALID:
        raise Error(
            "VAL-003 VALUE_OUT_OF_RANGE: " + what + ": invalid buffer id or"
            " argument for the Vulkan shim"
        )
    raise Error(
        "GPU-001 CUDA_INIT_FAILED: " + what + ": Vulkan call failed, VkResult "
        + String(Int(rc))
    )


struct VulkanKvCache:
    """Static KV-append gateway (A-066)."""

    @staticmethod
    def append(
        src: VulkanAllocation,
        cache: VulkanAllocation,
        head_dim: Int,
        max_len: Int,
        position: Int,
        kv_heads: Int,
    ) raises:
        """Insert src [kv_heads][head_dim] into cache
        [kv_heads][max_len][head_dim] at slot position, on the
        GPU. Raises (fail-closed) on any shape or buffer
        violation or Vulkan failure - nothing is copied on the
        host instead."""
        if head_dim <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanKvCache.append: head_dim must be positive")
        if max_len <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanKvCache.append: max_len must be positive")
        if kv_heads <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanKvCache.append: kv_heads must be positive")
        if position < 0 or position >= max_len:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanKvCache.append: position must lie in [0, max_len)")
        if src.requested_size < kv_heads * head_dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanKvCache.append: src buffer is smaller than the projection row")
        if cache.requested_size < kv_heads * max_len * head_dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanKvCache.append: cache buffer is smaller than the KV cache")
        var rc = external_call["aesir_vk_buffer_kv_append", Int32](
            UInt64(src.id), UInt64(cache.id),
            UInt32(head_dim), UInt32(max_len), UInt32(position), UInt32(kv_heads),
        )
        if rc != 0:
            _raise_for_rc("VulkanKvCache.append", rc)

    @staticmethod
    def dispatch_count() -> Int:
        """Completed A-066 KV-append dispatches on the device
        so far (shim counter; increments only after submit +
        wait-idle)."""
        return Int(external_call["aesir_vk_kv_append_dispatch_count", UInt64]())


struct VulkanEmbed:
    """Static token-embedding gather gateway (A-066)."""

    @staticmethod
    def gather(
        table: VulkanAllocation,
        dst: VulkanAllocation,
        dim: Int,
        token: Int,
        vocab: Int,
    ) raises:
        """Copy embedding row `token` of table [vocab][dim]
        into dst [dim], on the GPU. Raises (fail-closed) on
        any shape or buffer violation or Vulkan failure."""
        if dim <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanEmbed.gather: dim must be positive")
        if vocab <= 0:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanEmbed.gather: vocab must be positive")
        if token < 0 or token >= vocab:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanEmbed.gather: token must lie in [0, vocab)")
        if table.requested_size < vocab * dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanEmbed.gather: table buffer is smaller than the embedding table")
        if dst.requested_size < dim * 4:
            raise Error("VAL-003 VALUE_OUT_OF_RANGE: VulkanEmbed.gather: dst buffer is smaller than dim Float32")
        var rc = external_call["aesir_vk_buffer_embed_gather", Int32](
            UInt64(table.id), UInt64(dst.id),
            UInt32(dim), UInt32(token), UInt32(vocab),
        )
        if rc != 0:
            _raise_for_rc("VulkanEmbed.gather", rc)

    @staticmethod
    def dispatch_count() -> Int:
        """Completed A-066 embedding-gather dispatches on the
        device so far (shim counter)."""
        return Int(external_call["aesir_vk_embed_gather_dispatch_count", UInt64]())
