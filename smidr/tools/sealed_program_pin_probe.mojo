# Bounded original diagnostic. Map/unmap only; never launches DMA or a program.
from std.sys import argv
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from hailbru.syscall import os_host_architecture, os_page_size, os_mmap, os_munmap, PROT_READ, PROT_WRITE, MAP_PRIVATE, MAP_ANONYMOUS
from hailbru.soc_driver import SocDriver, open_soc_driver
from hailbru.soc_abi import soc_buffer, soc_buffer_reply, soc_driver_info_json, soc_properties_json
from smidr.program_envelope import build_program_envelope
from smidr.program_payload import ProgramPayloadRequest, stage_program_payload
from smidr.sealed_program_payload import SealedProgramPayload, seal_program_payload, sealed_program_window
from smidr.tools.hrpc_frame import _to_hex
from smidr.tools.program_integrity import _integer


def _request() -> ProgramPayloadRequest:
    return ProgramPayloadRequest(17, 0, "pin-probe", 32768)


def _equal(a: List[UInt8], b: List[UInt8]) raises:
    if len(a) != len(b):
        raise Error("PinProbe: byte extents differ")
    for i in range(len(a)):
        if a[i] != b[i]:
            raise Error("PinProbe: logical/backing bytes changed")


def _error_hex(text: String) -> String:
    var bytes = List[UInt8]()
    for byte in text.as_bytes():
        bytes.append(byte)
    return _to_hex(bytes)


struct _PinResources(Movable):
    var arch: String
    var sealed: SealedProgramPayload
    var driver: SocDriver
    var expected: List[UInt8]
    var address: Int64
    var allocation_bytes: Int64
    var page_size: Int64
    var view_owned: Bool
    var armed: Bool

    def __init__(out self):
        self.arch = String("")
        self.sealed = SealedProgramPayload()
        self.driver = SocDriver()
        self.expected = List[UInt8]()
        self.address = 0
        self.allocation_bytes = 0
        self.page_size = 0
        self.view_owned = False
        self.armed = False

    def __deinit__(deinit self):
        if self.view_owned:
            if self.armed:
                # Retain both backing references until process finalization.
                self.sealed.fd = -1
                print("PinProbe: cleanup_unconfirmed; retaining backing until exit")
            elif os_munmap(self.arch, self.address, self.allocation_bytes) != 0:
                print("PinProbe: implicit host munmap unconfirmed")

    def read_view(self) raises -> List[UInt8]:
        if not self.view_owned or self.armed or self.address <= 0 or self.address % self.page_size != 0:
            raise Error("PinProbe: CPU access requires owned unarmed aligned view")
        var pointer = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(self.address))
        var result = List[UInt8]()
        result.reserve(len(self.expected))
        for i in range(len(self.expected)):
            result.append(pointer[unsafe_offset=i])
        return result^

    def finalize_driver(mut self) raises:
        try:
            self.driver.close()
        except e:
            # close invalidated its fd;never guess whether finalization occurred.
            self.armed = True
            self.sealed.fd = -1
            raise Error("PinProbe: cleanup_unconfirmed; " + String(e))
        self.armed = False

    def release_host(mut self) raises:
        if self.armed:
            raise Error("PinProbe: backing retained for uncertain file context")
        if self.view_owned:
            var address = self.address
            var extent = self.allocation_bytes
            self.view_owned = False
            self.address = 0
            # Never retry an uncertain post-effect munmap on a reused address.
            if os_munmap(self.arch, address, extent) != 0:
                raise Error("PinProbe: host_release_unconfirmed")
        self.sealed.close()


def _allocate(profile: String, count: Int) raises -> _PinResources:
    var owner = _PinResources()
    owner.arch = os_host_architecture()
    if owner.arch != "aarch64":
        raise Error("PinProbe: qualified ARM64 host required")
    if profile == "anon-rw":
        owner.expected = List[UInt8](length=count, fill=0)
    else:
        var pb = List[UInt8]()
        pb.reserve(count - 56)
        for i in range(count - 56):
            pb.append(UInt8((i * 37 + 11) % 256))
        var empty = List[UInt8]()
        var program = build_program_envelope(pb, empty, empty, 0, False, UInt64(count))
        var staged = stage_program_payload(program, _request())
        owner.sealed = seal_program_payload(staged, _request(), owner.arch, 16, 16)
        owner.expected = sealed_program_window(owner.sealed, _request(), 1, 0, count, count, 16)
    owner.page_size = os_page_size()
    if count <= 0 or count > 32768 or Int64(count) > 9223372036854775807 - owner.page_size + 1:
        raise Error("PinProbe: invalid bounded allocation extent")
    owner.allocation_bytes = ((Int64(count) + owner.page_size - 1) // owner.page_size) * owner.page_size
    if owner.allocation_bytes < Int64(count) or owner.allocation_bytes > 1048576:
        raise Error("PinProbe: rounded allocation exceeds explicit work bound")
    var protection = PROT_READ() if profile == "sealed-ro" else PROT_READ() | PROT_WRITE()
    var flags = MAP_PRIVATE() | MAP_ANONYMOUS() if profile == "anon-rw" else MAP_PRIVATE()
    var fd = Int64(-1) if profile == "anon-rw" else owner.sealed.fd
    var address = os_mmap(owner.arch, owner.allocation_bytes, protection, flags, fd, 0)
    if address == -1:
        raise Error("PinProbe: host view mmap failed")
    owner.address = address
    owner.view_owned = True
    if address <= 0 or address % owner.page_size != 0:
        raise Error("PinProbe: mmap did not return a nonzero aligned owned view")
    var pointer = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(address))
    if profile == "anon-rw":
        for i in range(Int(owner.allocation_bytes)):
            pointer[unsafe_offset=i] = 0
    _equal(owner.read_view(), owner.expected)
    if profile == "sealed-cow":
        pointer[unsafe_offset=0] ^= 1
        _equal(sealed_program_window(owner.sealed, _request(), 1, 0, count, count, 16), owner.expected)
        pointer[unsafe_offset=0] ^= 1
        _equal(owner.read_view(), owner.expected)
    return owner^


def _observe(mut owner: _PinResources, mode: String, profile: String,
             sysfs: String, dev: String) raises:
    var attempted = False
    var accepted = False
    var unmapped = False
    var opened = False
    var primary = String("")
    var info = String("{}")
    var properties = String("{}")
    try:
        if mode == "device":
            owner.driver = open_soc_driver(sysfs, dev)
            opened = True
            info = soc_driver_info_json(owner.driver.driver_info)
            properties = soc_properties_json(owner.driver.properties)
            var data = soc_buffer(UInt64(owner.address), UInt64(len(owner.expected)), 1)
            attempted = True
            owner.armed = True
            _ = owner.driver.request("buffer-map", data)
            _ = soc_buffer_reply(data, UInt64(owner.address), UInt64(len(owner.expected)), 1)
            accepted = True
            var unmap = soc_buffer(UInt64(owner.address), UInt64(len(owner.expected)), 1)
            _ = owner.driver.request("buffer-unmap", unmap)
            unmapped = True
    except e:
        primary = String(e)
    try:
        owner.finalize_driver()
    except cleanup:
        raise Error("PinProbe: " + primary + "; " + String(cleanup))
    # Open/identity failure is not a completed mapping observation.
    if mode == "device" and not opened:
        owner.release_host()
        raise Error(primary)
    var bytes = owner.read_view()
    _equal(bytes, owner.expected)
    if profile != "anon-rw":
        _equal(sealed_program_window(owner.sealed, _request(), 1, 0, len(owner.expected), len(owner.expected), 16), owner.expected)
    var page = owner.page_size
    var allocation = owner.allocation_bytes
    owner.release_host()
    owner.release_host()
    print("{\"mode\":\"" + mode + "\",\"profile\":\"" + profile
          + "\",\"logical_bytes\":" + String(len(owner.expected))
          + ",\"page_size\":" + String(page) + ",\"mapping_bytes\":" + String(allocation)
          + ",\"device_context_opened\":" + (String("true") if opened else String("false"))
          + ",\"map_attempted\":" + (String("true") if attempted else String("false"))
          + ",\"map_accepted\":" + (String("true") if accepted else String("false"))
          + ",\"unmap_confirmed\":" + (String("true") if unmapped else String("false"))
          + ",\"context_finalized\":true,\"host_released\":true,\"bytes_verified\":true"
          + ",\"sealed_backing_unchanged\":" + (String("false") if profile == "anon-rw" else String("true"))
          + ",\"bytes_hex\":\"" + _to_hex(bytes) + "\",\"error_hex\":\"" + _error_hex(primary)
          + "\",\"driver_info\":" + info + ",\"properties\":" + properties
          + ",\"dma_submitted\":false,\"program_submitted\":false,\"execution_tested\":false}")


def main() raises:
    var args = argv()
    if len(args) != 6:
        raise Error("usage: sealed_program_pin_probe host|device anon-rw|sealed-ro|sealed-cow size sysfs-root dev-root")
    var mode = args[1]
    var profile = args[2]
    if mode != "host" and mode != "device":
        raise Error("PinProbe: unknown mode")
    if profile != "anon-rw" and profile != "sealed-ro" and profile != "sealed-cow":
        raise Error("PinProbe: unknown enumerated profile")
    if args[3].byte_length() > 5:
        raise Error("PinProbe: numeric work bound exceeded")
    var count = _integer(args[3])
    if (profile == "anon-rw" and count != 2068) or (profile != "anon-rw" and count != 70 and count != 4097 and count != 16385):
        raise Error("PinProbe: size is outside the bounded fixture batch")
    for i in range(4, 6):
        if args[i].byte_length() == 0 or args[i].byte_length() >= 4096 or "\0" in args[i]:
            raise Error("PinProbe: invalid bounded root")
    if mode == "host" and (args[4] != "-" or args[5] != "-"):
        raise Error("PinProbe: host mode has no device roots")
    var original = _allocate(profile, count)
    var moved = original^
    _observe(moved, mode, profile, args[4], args[5])
