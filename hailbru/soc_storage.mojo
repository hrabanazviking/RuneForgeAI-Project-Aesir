# Original owned host storage for integrated RPC. No DMA submission here.
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from hailbru.errors import herror
from hailbru.syscall import (
    os_page_size, os_mmap, os_munmap, errno_now, errno_name,
    PROT_READ, PROT_WRITE, MAP_PRIVATE, MAP_ANONYMOUS,
)
from hailbru.soc_driver import SocDriver
from hailbru.soc_abi import soc_buffer, soc_buffer_reply, soc_buffer_sync, SOC_INVALID_HANDLE

comptime SOC_RPC_STORAGE_SIZE = UInt64(2068)
comptime SOC_RPC_HEADER_SIZE = UInt64(20)
comptime SOC_RPC_BODY_SIZE = SOC_RPC_STORAGE_SIZE - SOC_RPC_HEADER_SIZE


@fieldwise_init
struct SocRpcLayout(Copyable, Movable):
    # descriptor_page zero selects the legacy contiguous layout: the body
    # span directly follows the 20-byte header and the mapped extent is the
    # logical 2068 bytes. An aligned layout instead places the body span one
    # descriptor page into the mapping, so every span offset is divisible by
    # the descriptor page policy the driver enforces for USERPTR launches.
    var descriptor_page: UInt64
    var body_offset: UInt64
    var mapped_size: UInt64

    def is_aligned(self) -> Bool:
        return self.descriptor_page != 0


def soc_rpc_layout_legacy() -> SocRpcLayout:
    return SocRpcLayout(0, SOC_RPC_HEADER_SIZE, SOC_RPC_STORAGE_SIZE)


def soc_rpc_layout_aligned(descriptor_page: UInt64) raises -> SocRpcLayout:
    # The descriptor page must be a representable power of two, matching the
    # admitted soc_desc_create policy range. The header occupies [0,20) and
    # the body span [page,page+2048); page >= 64 keeps the spans disjoint.
    if descriptor_page < 64 or descriptor_page > 32768 or (descriptor_page & (descriptor_page - 1)) != 0:
        raise herror("BadSocLayout", "descriptor page must be a representable power of two in [64,32768]")
    if descriptor_page > UInt64(18446744073709551615) - SOC_RPC_BODY_SIZE:
        raise herror("BadSocLayout", "aligned mapped extent overflows UInt64")
    return SocRpcLayout(descriptor_page, descriptor_page, descriptor_page + SOC_RPC_BODY_SIZE)


struct SocRpcStorage(Movable):
    var arch: String
    var address: UInt64
    var allocated_size: Int64
    var page_size: Int64
    var direction: UInt64
    var owner_fd: Int64
    var handle: UInt64
    var mapping_attempted: Bool
    var mapped: Bool
    var cpu_owned: Bool
    var transfer_pending: Bool
    var layout: SocRpcLayout

    def __init__(out self):
        self.arch = String("")
        self.address = 0
        self.allocated_size = 0
        self.page_size = 0
        self.direction = 0
        self.owner_fd = -1
        self.handle = SOC_INVALID_HANDLE
        self.mapping_attempted = False
        self.mapped = False
        self.cpu_owned = False
        self.transfer_pending = False
        self.layout = soc_rpc_layout_legacy()

    def __deinit__(deinit self):
        if self.address != 0:
            if self.mapping_attempted:
                # Fail closed: an owner misuse must not free a live DMA mapping.
                print("HailbruError[SocCleanupFailed]: retaining storage with unresolved driver mapping")
            elif os_munmap(self.arch, Int64(self.address), self.allocated_size) != 0:
                print("HailbruError[SocCleanupFailed]: implicit RPC storage munmap failed")

    def body_offset(self) -> UInt64:
        return self.layout.body_offset

    def mapped_size(self) -> UInt64:
        return self.layout.mapped_size

    def descriptor_page(self) -> UInt64:
        return self.layout.descriptor_page

    def allocate(mut self, arch: String, direction: UInt64) raises:
        if self.address != 0 or (direction != 1 and direction != 2):
            raise herror("SocStorageState", "allocation requires empty storage and explicit direction")
        self.layout = soc_rpc_layout_legacy()
        self._allocate(arch, direction)

    def allocate_aligned(mut self, arch: String, direction: UInt64, descriptor_page: UInt64) raises:
        if self.address != 0 or (direction != 1 and direction != 2):
            raise herror("SocStorageState", "allocation requires empty storage and explicit direction")
        # Layout admission happens before any allocation effect: a refused
        # page policy leaves the storage empty and legacy-unmodified.
        self.layout = soc_rpc_layout_aligned(descriptor_page)
        self._allocate(arch, direction)

    def _allocate(mut self, arch: String, direction: UInt64) raises:
        if self.address != 0 or (direction != 1 and direction != 2):
            raise herror("SocStorageState", "allocation requires empty storage and explicit direction")
        self.arch = arch
        self.page_size = os_page_size()
        self.allocated_size = ((Int64(self.layout.mapped_size) + self.page_size - 1) // self.page_size) * self.page_size
        var address = os_mmap(arch, self.allocated_size, PROT_READ() | PROT_WRITE(), MAP_PRIVATE() | MAP_ANONYMOUS(), -1, 0)
        if address == -1:
            raise herror("SocStorageFailed", "mmap: " + errno_name(errno_now()))
        self.address = UInt64(address)
        self.direction = direction
        self.cpu_owned = True
        if self.address == 0 or self.address % UInt64(self.page_size) != 0:
            # mmap returned storage we own even if its address is unusable.
            _ = os_munmap(arch, address, self.allocated_size)
            self.address = 0
            raise herror("SocStorageFailed", "mmap did not return a nonzero page-aligned address")
        var bytes = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(self.address))
        # Materialize/initialize all pages before pinning them through the driver.
        for index in range(Int(self.allocated_size)):
            bytes[unsafe_offset=index] = 0

    def map(mut self, mut driver: SocDriver) raises:
        if self.address == 0 or self.mapping_attempted or self.arch != driver.arch or driver.fd < 0:
            raise herror("SocStorageState", "map requires allocated, unmapped storage on its owning architecture")
        var data = soc_buffer(self.address, self.layout.mapped_size, self.direction)
        # An ioctl failure may follow kernel-side effects; keep storage alive.
        self.owner_fd = driver.fd
        self.mapping_attempted = True
        self.cpu_owned = False
        _ = driver.request("buffer-map", data)
        self.handle = soc_buffer_reply(data, self.address, self.layout.mapped_size, self.direction)
        self.mapped = True

    def sync(mut self, mut driver: SocDriver, for_device: Bool) raises:
        if self.transfer_pending or not self.mapped or driver.fd < 0 or driver.fd != self.owner_fd or self.arch != driver.arch:
            raise herror("SocStorageState", "cache sync requires a live owned mapping")
        var data = soc_buffer_sync(self.handle, for_device, 0, self.layout.mapped_size, self.layout.mapped_size)
        # A failed sync cannot grant either CPU or DMA access.
        self.cpu_owned = False
        _ = driver.request("buffer-sync", data)
        self.cpu_owned = not for_device

    def _require_cpu(self) raises:
        if self.transfer_pending or self.address == 0 or not self.cpu_owned:
            raise herror("SocStorageState", "CPU byte access requires explicitly CPU-owned storage")

    def write_message(mut self, data: List[UInt8]) raises:
        self._require_cpu()
        if len(data) > Int(SOC_RPC_STORAGE_SIZE):
            raise herror("SocStorageBounds", "message exceeds the owned 2068-byte logical extent")
        var bytes = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(self.address))
        if not self.layout.is_aligned():
            # Clear the whole logical message, including bytes from prior messages.
            for index in range(Int(SOC_RPC_STORAGE_SIZE)):
                bytes[unsafe_offset=index] = data[index] if index < len(data) else UInt8(0)
            return
        # Aligned scatter: clear the whole mapped extent first so the gap
        # between header and body is deterministically zero, then write the
        # header at offset zero and the body one descriptor page in. No gap
        # byte ever becomes a protocol field or wire payload.
        for index in range(Int(self.layout.mapped_size)):
            bytes[unsafe_offset=index] = UInt8(0)
        for index in range(Int(SOC_RPC_HEADER_SIZE)):
            bytes[unsafe_offset=index] = data[index] if index < len(data) else UInt8(0)
        for index in range(Int(SOC_RPC_BODY_SIZE)):
            var source = Int(SOC_RPC_HEADER_SIZE) + index
            bytes[unsafe_offset=Int(self.layout.body_offset) + index] = data[source] if source < len(data) else UInt8(0)

    def read_bytes(self, count: Int) raises -> List[UInt8]:
        self._require_cpu()
        if count < 0 or count > Int(SOC_RPC_STORAGE_SIZE):
            raise herror("SocStorageBounds", "read exceeds the owned logical message extent")
        var bytes = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(self.address))
        var result = List[UInt8]()
        result.reserve(count)
        # Gather: logical byte i lives at its layout offset, so an aligned
        # storage reconstructs exactly the canonical 2068-byte frame.
        for index in range(count):
            var source = index if index < Int(SOC_RPC_HEADER_SIZE) else Int(self.layout.body_offset) + (index - Int(SOC_RPC_HEADER_SIZE))
            result.append(bytes[unsafe_offset=source])
        # Owned copy: no reference into mapped storage escapes this accessor.
        return result^

    def read_message(self) raises -> List[UInt8]:
        return self.read_bytes(Int(SOC_RPC_STORAGE_SIZE))

    def zeroed(self) raises -> Bool:
        if self.transfer_pending or self.address == 0 or not self.cpu_owned:
            raise herror("SocStorageState", "CPU read requires explicitly CPU-owned storage")
        var bytes = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(self.address))
        for index in range(Int(self.layout.mapped_size)):
            if bytes[unsafe_offset=index] != 0:
                return False
        return True

    def unmap(mut self, mut driver: SocDriver) raises:
        if not self.mapping_attempted:
            return
        if self.transfer_pending or not self.mapped or driver.fd < 0 or driver.fd != self.owner_fd or self.arch != driver.arch:
            raise herror("SocStorageState", "uncertain map requires owning file-context finalization")
        var data = soc_buffer(self.address, self.layout.mapped_size, self.direction)
        _ = driver.request("buffer-unmap", data)
        self.context_finalized()

    def begin_transfer(mut self) raises:
        if not self.mapped or self.cpu_owned or self.transfer_pending:
            raise herror("SocStorageState", "launch requires mapped device-owned idle storage")
        # Armed before ioctl: an uncertain launch cannot return CPU ownership.
        self.transfer_pending = True

    def transfer_finished(mut self) raises:
        if not self.transfer_pending:
            raise herror("SocStorageState", "no pending transfer can be completed")
        # Only the session completion owner calls this for a validated IRQ.
        self.transfer_pending = False

    def channels_quiesced(mut self):
        # Only after assigned-channel stop or entire file-context finalization.
        self.transfer_pending = False

    def context_finalized(mut self):
        # Only the session owner calls this after unmap or actual fd finalization.
        self.mapping_attempted = False
        self.mapped = False
        self.transfer_pending = False
        self.owner_fd = -1
        self.handle = SOC_INVALID_HANDLE
        self.cpu_owned = True

    def release(mut self) raises:
        if self.mapping_attempted:
            raise herror("SocStorageState", "cannot release storage before mapping finalization")
        if self.address == 0:
            return
        if os_munmap(self.arch, Int64(self.address), self.allocated_size) != 0:
            raise herror("SocCleanupFailed", "RPC storage munmap: " + errno_name(errno_now()))
        self.address = 0
        self.allocated_size = 0
        self.cpu_owned = False
