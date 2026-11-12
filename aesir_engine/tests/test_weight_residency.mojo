"""Weight residency (A-020): single-residency accounting rules, HIP
host-registration GPU visibility of a file mmap, and /proc residency
accounting.

Present/absent discipline matches the house style of the A-011 HIP
and A-014 Vulkan cases: on a HIP host every device case verifies real
device visibility; on a host without a usable HIP device every device
case asserts fail-closed behaviour and passes as honest-absent. The
accounting cases are device-independent: they run everywhere. No case
ever claims a residency it did not measure.
"""
from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import alloc

from core.hip_memory import HipMemory
from core.weight_residency import WeightResidency


def _hip_present() -> Bool:
    if not HipMemory.runtime_available():
        return False
    try:
        return HipMemory.device_count() > 0
    except:
        return False


def _pattern(i: Int) -> UInt8:
    return UInt8((i * 31 + 7) % 251)


def _make_pattern_file(size_bytes: Int) raises -> String:
    # The fixture file must live on the repo filesystem, not tmpfs:
    # tmpfs (shmem) pages account as dirty in smaps, while pages of a
    # file on a real filesystem account as file-backed clean - the
    # distinction the residency accounting exists to measure.
    var template = List[Int8]()
    for byte in String("aesir-residency-XXXXXX").as_bytes():
        template.append(Int8(byte))
    template.append(0)
    var fd = external_call["mkstemp", Int32](template.unsafe_ptr())
    if fd < 0:
        raise Error("failed to create residency fixture file")
    var bytes = List[UInt8]()
    bytes.reserve(size_bytes)
    for i in range(size_bytes):
        bytes.append(_pattern(i))
    var offset = 0
    while offset < len(bytes):
        var wrote = external_call["write", Int](
            Int(fd), bytes.unsafe_ptr().unsafe_offset(offset), len(bytes) - offset
        )
        if wrote <= 0:
            _ = external_call["close", Int32](fd)
            raise Error("failed to write residency fixture file")
        offset += wrote
    if external_call["close", Int32](fd) != 0:
        raise Error("failed to close residency fixture file")
    return String(unsafe_from_utf8_ptr=template.unsafe_ptr())


def _unlink(path: String):
    var bytes = List[Int8]()
    for byte in path.as_bytes():
        bytes.append(Int8(byte))
    bytes.append(0)
    _ = external_call["unlink", Int32](bytes.unsafe_ptr())


def _mmap_file(path: String, size_bytes: Int) raises -> Pointer[
    UInt8, MutUntrackedOrigin
]:
    var path_bytes = List[Int8]()
    for byte in path.as_bytes():
        path_bytes.append(Int8(byte))
    path_bytes.append(0)
    var fd = external_call["open64", Int32](path_bytes.unsafe_ptr(), Int32(0), Int32(0))
    if fd < 0:
        raise Error("failed to open residency fixture file")
    var addr = external_call["mmap", Int](
        Int(0), size_bytes, Int32(1), Int32(1), fd, Int64(0)
    )
    _ = external_call["close", Int32](fd)
    if addr == -1 or addr == 0:
        raise Error("failed to mmap residency fixture file")
    return Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=addr)


def test_weight_residency_accounting_rules() raises:
    print("--- Testing weight residency accounting rules (A-020) ---")
    # Device-independent rejection discipline: invalid registrations
    # and accounting on a null base must fail closed, never fabricate.
    var zero_rejected = False
    try:
        WeightResidency.register_mapping(
            Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=4096), 0
        )
    except:
        zero_rejected = True
    if not zero_rejected:
        raise Error("register_mapping accepted a zero-size range")
    var unmapped: Int = 268435456
    var unmapped_rejected = False
    try:
        _ = WeightResidency.mapping_accounting(
            Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=unmapped)
        )
    except:
        unmapped_rejected = True
    if not unmapped_rejected:
        raise Error("mapping_accounting accepted an unmapped address")
    # Process RSS accounting is real /proc data on every host.
    var rss = WeightResidency.process_rss_bytes()
    if rss <= 0:
        raise Error("process RSS accounting returned a non-positive value")
    print("Weight residency rejection + RSS accounting: PASS, VmRSS bytes:", rss)


def test_weight_residency_mapping_accounting() raises:
    print("--- Testing weight residency mapping accounting (A-020) ---")
    var size = 16384
    var path = _make_pattern_file(size)
    var base = _mmap_file(path, size)
    # Fault every page in with the pattern oracle, so residency is
    # measured, not assumed.
    for i in range(size):
        if base.unsafe_load(i) != _pattern(i):
            _unlink(path)
            raise Error("mmap pattern oracle mismatch before accounting")
    var acct = WeightResidency.mapping_accounting(base)
    _unlink(path)
    print(
        "mapping resident:", acct.resident_bytes,
        "file_clean:", acct.file_clean_bytes,
        "anon_dirty:", acct.anon_dirty_bytes,
    )
    if acct.resident_bytes < size:
        raise Error("mapping resident bytes below the faulted file size")
    if acct.file_clean_bytes < size:
        raise Error("faulted file pages are not accounted file-backed clean")
    if acct.anon_dirty_bytes != 0:
        raise Error("read-only file mapping reports anonymous dirty bytes")
    print("Weight residency mapping accounting: PASS")


def test_weight_residency_gpu_visibility() raises:
    print("--- Testing weight residency GPU visibility (A-020) ---")
    if not _hip_present():
        # Honest-absent: registration must fail closed, never fabricate
        # a device pointer.
        var rejected = False
        try:
            WeightResidency.register_mapping(
                Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=4096),
                4096,
            )
        except:
            rejected = True
        if not rejected:
            raise Error("HIP unavailable but register_mapping succeeded")
        print("HIP UNAVAILABLE: fail-closed PASS (honest-absent)")
        return
    var size = 16384
    var path = _make_pattern_file(size)
    var base = _mmap_file(path, size)
    WeightResidency.register_mapping(base, size)
    var dev = WeightResidency.device_pointer(base)
    if Int(dev) != Int(base):
        WeightResidency.unregister_mapping(base)
        _unlink(path)
        raise Error("device pointer differs from host mmap pointer (copy made)")
    # Device-side read of the same pages: hipMemcpy device->host from
    # the device pointer must return the file pattern byte-exactly.
    var host_copy = alloc[UInt8](size)
    for i in range(size):
        host_copy.unsafe_store(i, UInt8(0))
    HipMemory.memcpy_device_to_host(host_copy, dev, size)
    var exact = True
    for i in range(size):
        if host_copy.unsafe_load(i) != _pattern(i):
            exact = False
            break
    host_copy.unsafe_free()
    WeightResidency.unregister_mapping(base)
    _unlink(path)
    if not exact:
        raise Error("device-visible bytes differ from the mmap pattern")
    print("Weight residency GPU visibility (device ptr == mmap ptr): PASS")


def test_weight_residency_no_device_copy() raises:
    print("--- Testing weight residency no device copy (A-020) ---")
    if not _hip_present():
        print("HIP UNAVAILABLE: device-copy accounting not run (honest-absent)")
        return
    # Warm up first (A-011 leak-accounting contract): the HIP runtime
    # reserves a one-time context block on first use.
    var warm = HipMemory.allocate_managed(4096)
    HipMemory.free(warm)
    var before = HipMemory.mem_info()
    var rss_before = WeightResidency.process_rss_bytes()
    var size = 16384
    var path = _make_pattern_file(size)
    var base = _mmap_file(path, size)
    for i in range(size):
        if base.unsafe_load(i) != _pattern(i):
            _unlink(path)
            raise Error("pattern oracle mismatch in device-accounting case")
    WeightResidency.register_mapping(base, size)
    _ = WeightResidency.device_pointer(base)
    var during = HipMemory.mem_info()
    var rss_during = WeightResidency.process_rss_bytes()
    var acct = WeightResidency.mapping_accounting(base)
    WeightResidency.unregister_mapping(base)
    _unlink(path)
    print(
        "hip free before:", before.free_bytes,
        "during registration:", during.free_bytes,
        "rss before:", rss_before, "during:", rss_during,
    )
    # The HIP pool charges the registered range as device-visible
    # (bounded by the range + slack); a duplicate copy would appear
    # as anonymous dirty bytes in the mapping and as new RSS. Neither
    # may appear.
    var charge = before.free_bytes - during.free_bytes
    if charge < 0 or charge > size + 65536:
        raise Error("device-visible charge exceeds the registered range")
    if acct.anon_dirty_bytes != 0:
        raise Error("registration created anonymous dirty bytes (copy)")
    if rss_during - rss_before > 67108864:
        raise Error("registration grew RSS beyond HIP runtime overhead")
    print("Weight residency no-device-copy accounting: PASS")
