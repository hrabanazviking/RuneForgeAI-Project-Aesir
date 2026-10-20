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

    def __deinit__(deinit self):
        if self.address != 0:
            if self.mapping_attempted:
                # Fail closed: an owner misuse must not free a live DMA mapping.
                print("HailbruError[SocCleanupFailed]: retaining storage with unresolved driver mapping")
            elif os_munmap(self.arch, Int64(self.address), self.allocated_size) != 0:
                print("HailbruError[SocCleanupFailed]: implicit RPC storage munmap failed")

    def allocate(mut self, arch: String, direction: UInt64) raises:
        if self.address != 0 or (direction != 1 and direction != 2):
            raise herror("SocStorageState", "allocation requires empty storage and explicit direction")
        self.arch = arch
        self.page_size = os_page_size()
        self.allocated_size = ((Int64(SOC_RPC_STORAGE_SIZE) + self.page_size - 1) // self.page_size) * self.page_size
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
        var data = soc_buffer(self.address, SOC_RPC_STORAGE_SIZE, self.direction)
        # An ioctl failure may follow kernel-side effects; keep storage alive.
        self.owner_fd = driver.fd
        self.mapping_attempted = True
        self.cpu_owned = False
        _ = driver.request("buffer-map", data)
        self.handle = soc_buffer_reply(data, self.address, SOC_RPC_STORAGE_SIZE, self.direction)
        self.mapped = True

    def sync(mut self, mut driver: SocDriver, for_device: Bool) raises:
        if not self.mapped or driver.fd < 0 or driver.fd != self.owner_fd or self.arch != driver.arch:
            raise herror("SocStorageState", "cache sync requires a live owned mapping")
        var data = soc_buffer_sync(self.handle, for_device, 0, SOC_RPC_STORAGE_SIZE, SOC_RPC_STORAGE_SIZE)
        # A failed sync cannot grant either CPU or DMA access.
        self.cpu_owned = False
        _ = driver.request("buffer-sync", data)
        self.cpu_owned = not for_device

    def zeroed(self) raises -> Bool:
        if self.address == 0 or not self.cpu_owned:
            raise herror("SocStorageState", "CPU read requires explicitly CPU-owned storage")
        var bytes = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(self.address))
        for index in range(Int(SOC_RPC_STORAGE_SIZE)):
            if bytes[unsafe_offset=index] != 0:
                return False
        return True

    def unmap(mut self, mut driver: SocDriver) raises:
        if not self.mapping_attempted:
            return
        if not self.mapped or driver.fd < 0 or driver.fd != self.owner_fd or self.arch != driver.arch:
            raise herror("SocStorageState", "uncertain map requires owning file-context finalization")
        var data = soc_buffer(self.address, SOC_RPC_STORAGE_SIZE, self.direction)
        _ = driver.request("buffer-unmap", data)
        self.context_finalized()

    def context_finalized(mut self):
        # Only the session owner calls this after unmap or actual fd finalization.
        self.mapping_attempted = False
        self.mapped = False
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
