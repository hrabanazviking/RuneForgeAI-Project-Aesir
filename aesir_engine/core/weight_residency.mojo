# core/weight_residency.mojo
# Weight residency (slice A-020): GGUF mmap weights become GPU-visible
# without a duplicate resident copy.
#
# What the loader already does (loader/gguf.mojo, _map_tensor): F16 and
# quantized tensors are RuneTensor views whose data pointer aliases the
# single read-only mmap of the file (zero-copy); only F32 and BF16
# tensors are converted element-by-element into the MimirWell pool as
# f16, because the engine consumes f16 views. This module makes that
# residency measurable and makes the mapping device-visible:
#
# - ResidencyAccounting splits a loaded model's bytes into the mmap
#   header/metadata region, zero-copy tensor payload (aliased into the
#   mmap), converted tensor source bytes, and the converted pool bytes
#   those sources produce. The duplicate resident bytes are exactly
#   the converted sources: conversion reads them (faulting their mmap
#   pages in) and ALSO keeps a pool copy, so those bytes - and only
#   those bytes - are resident twice. For the stories260K fixture the
#   converted set is the small F32 norm tensors; everything else is
#   single-residency. The accounting never hides the split.
# - register_mapping() host-registers the loader's mmap range with
#   HIP (hipHostRegisterMapped, through the A-011 shim). On Strix
#   Halo's unified-memory pool hipHostGetDevicePointer returns the
#   host address itself: the same pages are device-visible and no
#   second copy is allocated. hipMemGetInfo does charge the range
#   against the device-visible pool (accounting, measured in the
#   A-020 ledger) - the no-copy evidence is pointer identity plus
#   RSS / anonymous-dirty invariance, not the pool charge.
# - process/mapping accounting reads real /proc data through the
#   shim: process VmRSS, and the smaps entry of the mapping holding
#   the weights (resident bytes, file-backed clean bytes, anonymous
#   dirty bytes). RSS, file-backed pages, and device-visible bytes
#   are reported as three distinct numbers, never conflated.
#
# Fail-closed contract (house style of A-011/A-014): when the HIP
# runtime is not loadable, registration raises; when /proc accounting
# cannot be read, the accounting calls raise. Nothing is simulated.

from std.ffi import external_call
from std.memory import Pointer

from loader.gguf import GGMLType, GGUFSeer

comptime _RESIDENCY_ABSENT = -1


struct ResidencyAccounting(Copyable, ImplicitlyCopyable):
    """Byte split of one loaded GGUF model (see file header)."""

    var file_bytes: Int
    var data_offset_bytes: Int
    var tensor_payload_bytes: Int
    var zero_copy_bytes: Int
    var converted_source_bytes: Int
    var converted_pool_bytes: Int
    var tensor_count: Int
    var zero_copy_count: Int
    var converted_count: Int

    def __init__(
        out self,
        file_bytes: Int,
        data_offset_bytes: Int,
        tensor_payload_bytes: Int,
        zero_copy_bytes: Int,
        converted_source_bytes: Int,
        converted_pool_bytes: Int,
        tensor_count: Int,
        zero_copy_count: Int,
        converted_count: Int,
    ):
        self.file_bytes = file_bytes
        self.data_offset_bytes = data_offset_bytes
        self.tensor_payload_bytes = tensor_payload_bytes
        self.zero_copy_bytes = zero_copy_bytes
        self.converted_source_bytes = converted_source_bytes
        self.converted_pool_bytes = converted_pool_bytes
        self.tensor_count = tensor_count
        self.zero_copy_count = zero_copy_count
        self.converted_count = converted_count

    def duplicate_resident_bytes(self) -> Int:
        """Bytes resident twice: a converted tensor's mmap source
        pages (read during conversion) plus its pool copy. Zero-copy
        tensors contribute nothing here."""
        return self.converted_source_bytes

    def bulk_single_residency(self) -> Bool:
        """True iff every non-converted tensor byte is zero-copy and
        the payload split is complete (no unaccounted bytes)."""
        return (
            self.zero_copy_bytes + self.converted_source_bytes
            == self.tensor_payload_bytes
            and self.zero_copy_count + self.converted_count
            == self.tensor_count
        )


struct MappingAccounting(Copyable, ImplicitlyCopyable):
    """smaps accounting of the one mapping holding an address."""

    var resident_bytes: Int
    var file_clean_bytes: Int
    var anon_dirty_bytes: Int

    def __init__(
        out self, resident_bytes: Int, file_clean_bytes: Int, anon_dirty_bytes: Int
    ):
        self.resident_bytes = resident_bytes
        self.file_clean_bytes = file_clean_bytes
        self.anon_dirty_bytes = anon_dirty_bytes


struct WeightResidency:
    """Static weight-residency gateway (A-020). See file header."""

    @staticmethod
    def _raise_for_rc(what: String, rc: Int32) raises:
        if Int(rc) == _RESIDENCY_ABSENT:
            raise Error(
                "WeightResidency." + what + ": HIP runtime is not"
                " loadable on this host (honest-absent)"
            )
        raise Error(
            "WeightResidency." + what + ": HIP call failed, code "
            + String(Int(rc))
        )

    @staticmethod
    def account(seer: GGUFSeer) raises -> ResidencyAccounting:
        """Split a loaded seer's bytes by residency class. Tensor byte
        sizes come from the loader's own _tensor_byte_size so the
        accounting can never drift from the mapping's admission math.
        Converted pool bytes are elements * 2 (the pool holds f16)."""
        if not seer.is_loaded:
            raise Error("WeightResidency.account: seer is not loaded")
        var payload = 0
        var zero_copy = 0
        var conv_src = 0
        var conv_pool = 0
        var count = 0
        var zc_count = 0
        var conv_count = 0
        for name in seer.tensors.keys():
            var tensor = seer.tensors[name].copy()
            var tensor_type = seer.tensor_types[name]
            var elements = tensor.rows * tensor.cols
            var byte_size = seer._tensor_byte_size(elements, tensor_type)
            payload += byte_size
            count += 1
            if tensor_type == GGMLType.F32 or tensor_type == GGMLType.BF16:
                conv_src += byte_size
                conv_pool += elements * 2
                conv_count += 1
            else:
                zero_copy += byte_size
                zc_count += 1
        return ResidencyAccounting(
            Int(seer.file_size),
            seer.data_offset,
            payload,
            zero_copy,
            conv_src,
            conv_pool,
            count,
            zc_count,
            conv_count,
        )

    @staticmethod
    def verify_zero_copy_aliases(seer: GGUFSeer) raises -> Int:
        """Count zero-copy-class tensors whose data pointer is exactly
        mmap_base + file offset (the alias the loader promises), and
        raise on the first tensor that was silently copied instead.
        Converted (F32/BF16) tensors are excluded by class: their pool
        pointers are the documented exception, counted in account()."""
        if not seer.is_loaded:
            raise Error("WeightResidency.verify: seer is not loaded")
        var verified = 0
        for name in seer.tensors.keys():
            var tensor_type = seer.tensor_types[name]
            if tensor_type == GGMLType.F32 or tensor_type == GGMLType.BF16:
                continue
            var tensor = seer.tensors[name].copy()
            var expected = Int(seer.mmap_ptr) + seer.tensor_file_offsets[name]
            if Int(tensor.data) != expected:
                raise Error(
                    "WeightResidency.verify: tensor " + name
                    + " does not alias the mmap (copied instead)"
                )
            verified += 1
        return verified

    @staticmethod
    def register_mapping(
        base: Pointer[UInt8, MutUntrackedOrigin], size_bytes: Int
    ) raises:
        """hipHostRegister(hipHostRegisterMapped) over an existing
        host range: makes those same pages device-visible."""
        if size_bytes <= 0:
            raise Error("WeightResidency.register_mapping: size must be positive")
        if Int(base) == 0:
            raise Error("WeightResidency.register_mapping: null base")
        var rc = external_call["aesir_hip_host_register", Int32](
            base, UInt64(size_bytes)
        )
        if rc != 0:
            Self._raise_for_rc("register_mapping", rc)

    @staticmethod
    def unregister_mapping(
        base: Pointer[UInt8, MutUntrackedOrigin],
    ) raises:
        if Int(base) == 0:
            raise Error("WeightResidency.unregister_mapping: null base")
        var rc = external_call["aesir_hip_host_unregister", Int32](base)
        if rc != 0:
            Self._raise_for_rc("unregister_mapping", rc)

    @staticmethod
    def device_pointer(
        base: Pointer[UInt8, MutUntrackedOrigin],
    ) raises -> Pointer[UInt8, MutUntrackedOrigin]:
        """hipHostGetDevicePointer for a registered host range."""
        var addr: Int = 0
        var rc = external_call["aesir_hip_host_device_pointer", Int32](
            base, Pointer(to=addr)
        )
        if rc != 0:
            Self._raise_for_rc("device_pointer", rc)
        if addr == 0:
            raise Error("WeightResidency.device_pointer: null device pointer")
        return Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=addr)

    @staticmethod
    def process_rss_bytes() raises -> Int:
        """Process VmRSS from /proc/self/status, in bytes."""
        var rss = external_call["aesir_residency_process_rss_bytes", Int64]()
        if rss < 0:
            raise Error("WeightResidency.process_rss_bytes: /proc unreadable")
        return Int(rss)

    @staticmethod
    def mapping_accounting(
        base: Pointer[UInt8, MutUntrackedOrigin],
    ) raises -> MappingAccounting:
        """smaps accounting of the mapping containing base."""
        var rss: UInt64 = 0
        var file_clean: UInt64 = 0
        var anon_dirty: UInt64 = 0
        var rc = external_call["aesir_residency_mapping_bytes", Int32](
            UInt64(Int(base)),
            Pointer(to=rss),
            Pointer(to=file_clean),
            Pointer(to=anon_dirty),
        )
        if rc != 0:
            raise Error(
                "WeightResidency.mapping_accounting: address not in any"
                " readable mapping"
            )
        return MappingAccounting(Int(rss), Int(file_clean), Int(anon_dirty))
