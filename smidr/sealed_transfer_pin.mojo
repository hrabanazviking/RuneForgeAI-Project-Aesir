# Original two-part sealed USERPTR ownership. No DMA, channels or program submit.
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from hailbru.syscall import os_host_architecture, os_page_size, os_mmap, os_munmap, PROT_READ, MAP_PRIVATE
from hailbru.soc_driver import SocDriver, open_soc_driver
from hailbru.soc_abi import soc_buffer, soc_buffer_reply
from smidr.program_payload import ProgramPayloadRequest, ProgramPayloadSnapshot
from smidr.sealed_transfer_backing import SealedTransferBacking, _actual


struct _PinnedPart(Movable):
    var address: Int64
    var view_owned: Bool
    var mapping_bytes: Int64
    var logical_bytes: Int64
    var attempted: Bool
    var mapped: Bool
    var retained: Bool

    def __init__(out self):
        self.address = 0
        self.view_owned = False
        self.mapping_bytes = 0
        self.logical_bytes = 0
        self.attempted = False
        self.mapped = False
        self.retained = False

    def __deinit__(deinit self):
        if self.view_owned:
            if self.retained:
                print("SealedTransferPin: retaining view until process finalization")
            elif os_munmap("aarch64", self.address, self.mapping_bytes) != 0:
                print("SealedTransferPin: implicit view release unconfirmed")

    def release(mut self) raises:
        if self.retained:
            raise Error("SealedTransferPin: view retained for uncertain file context")
        if not self.view_owned:
            return
        var address = self.address
        var extent = self.mapping_bytes
        self.address = 0
        self.view_owned = False
        self.mapping_bytes = 0
        # Never retry a possibly completed munmap at a reused address.
        if os_munmap("aarch64", address, extent) != 0:
            raise Error("SealedTransferPin: view release unconfirmed")


def _view(fd: Int64, bytes: List[UInt8], page: Int64, allocation_bound: Int64) raises -> _PinnedPart:
    var logical = Int64(len(bytes))
    if logical <= 0 or page <= 0 or logical > 9223372036854775807 - page + 1:
        raise Error("SealedTransferPin: invalid checked page rounding")
    var extent = ((logical + page - 1) // page) * page
    if extent < logical or extent > allocation_bound:
        raise Error("SealedTransferPin: rounded view exceeds allocation bound")
    var result = _PinnedPart()
    var address = os_mmap("aarch64", extent, PROT_READ(), MAP_PRIVATE(), fd, 0)
    if address == -1:
        raise Error("SealedTransferPin: view mmap failed")
    result.address = address
    result.view_owned = True
    result.mapping_bytes = extent
    result.logical_bytes = logical
    if address <= 0 or address % page != 0:
        raise Error("SealedTransferPin: actual mmap address is not positive aligned storage")
    # Sole CPU dereference scope: the actual local mmap result before any pin.
    var pointer = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(address))
    for i in range(len(bytes)):
        if pointer[unsafe_offset=i] != bytes[i]:
            raise Error("SealedTransferPin: actual view differs from validated sealed bytes")
    return result^


def _map(mut part: _PinnedPart, mut driver: SocDriver) raises:
    var data = soc_buffer(UInt64(part.address), UInt64(part.logical_bytes), 1)
    part.attempted = True
    part.retained = True
    _ = driver.request("buffer-map", data)
    _ = soc_buffer_reply(data, UInt64(part.address), UInt64(part.logical_bytes), 1)
    part.mapped = True


def _unmap(mut part: _PinnedPart, mut driver: SocDriver) raises:
    if part.mapped:
        var data = soc_buffer(UInt64(part.address), UInt64(part.logical_bytes), 1)
        # An uncertain reply is never retried even if close reports failure.
        part.mapped = False
        _ = driver.request("buffer-unmap", data)


struct SealedTransferPin(Movable):
    var backing: SealedTransferBacking
    var driver: SocDriver
    var metadata: _PinnedPart
    var program: _PinnedPart
    var page_size: Int64
    var finalization_unconfirmed: Bool
    var finalization_errors: String

    def __init__(out self):
        self.backing = SealedTransferBacking()
        self.driver = SocDriver()
        self.metadata = _PinnedPart()
        self.program = _PinnedPart()
        self.page_size = 0
        self.finalization_unconfirmed = False
        self.finalization_errors = String("")

    def __deinit__(deinit self):
        try:
            self.close()
        except error:
            print(String(error))
        if self.finalization_unconfirmed:
            # Underlying field destructors must not drop either retained fd.
            self.backing.metadata_fd = -1
            self.backing.program.fd = -1

    def _finalize_driver(mut self) raises -> String:
        if self.finalization_unconfirmed:
            raise Error("SealedTransferPin: cleanup_unconfirmed; backing retained" + self.finalization_errors)
        var failures = String("")
        if self.driver.fd >= 0:
            try:
                _unmap(self.program, self.driver)
            except error:
                failures += "; " + String(error)
            try:
                _unmap(self.metadata, self.driver)
            except error:
                failures += "; " + String(error)
            try:
                self.driver.close()
            except error:
                self.finalization_unconfirmed = True
                self.finalization_errors = failures + "; " + String(error)
                self.metadata.retained = True
                self.program.retained = True
                raise Error("SealedTransferPin: cleanup_unconfirmed; backing retained" + self.finalization_errors)
        self.metadata.retained = False
        self.program.retained = False
        return failures

    def finalize_driver(mut self) raises:
        var failures = self._finalize_driver()
        if failures.byte_length() != 0:
            raise Error("SealedTransferPin: " + failures)

    def close(mut self) raises:
        # Unconfirmed finalization raises before any host resource release.
        var failures = self._finalize_driver()
        try:
            self.program.release()
        except error:
            failures += "; " + String(error)
        try:
            self.metadata.release()
        except error:
            failures += "; " + String(error)
        try:
            self.backing.close()
        except error:
            failures += "; " + String(error)
        if failures.byte_length() != 0:
            raise Error("SealedTransferPin: " + failures)


def _construct(var backing: SealedTransferBacking, expected: ProgramPayloadRequest,
               byte_bound: Int, allocation_bound: Int64, program_read_bound: Int,
               metadata_read_bound: Int, device: Bool, sysfs: String, dev: String) raises -> SealedTransferPin:
    if os_host_architecture() != "aarch64" or byte_bound <= 0 or allocation_bound <= 0 or program_read_bound <= 0 or metadata_read_bound <= 0:
        raise Error("SealedTransferPin: qualified host and positive independent bounds required")
    if backing.program.program_bytes > Int64(byte_bound) or byte_bound < 2068:
        raise Error("SealedTransferPin: logical parts exceed explicit byte bound")
    if device:
        if sysfs.byte_length() == 0 or sysfs.byte_length() >= 4096 or "\0" in sysfs or dev.byte_length() == 0 or dev.byte_length() >= 4096 or "\0" in dev:
            raise Error("SealedTransferPin: invalid bounded device roots")
    elif sysfs != "-" or dev != "-":
        raise Error("SealedTransferPin: host views have no device roots")
    var snapshot = _actual(backing, expected, program_read_bound, metadata_read_bound)
    var result = SealedTransferPin()
    result.backing = backing^
    result.page_size = os_page_size()
    if result.page_size <= 0:
        raise Error("SealedTransferPin: invalid actual page size")
    try:
        result.metadata = _view(result.backing.metadata_fd, snapshot.metadata, result.page_size, allocation_bound)
        var remaining = allocation_bound - result.metadata.mapping_bytes
        result.program = _view(result.backing.program.fd, snapshot.program, result.page_size, remaining)
        if device:
            result.driver = open_soc_driver(sysfs, dev)
            _map(result.metadata, result.driver)
            _map(result.program, result.driver)
    except error:
        var primary = String(error)
        if "HailbruError[SocCleanupFailed]" in primary:
            # open_soc_driver can report an identity failure plus failed close
            # before returning its owner. No mapping exists, but retain both
            # views/backings consistently with uncertain file finalization.
            result.finalization_unconfirmed = True
            result.finalization_errors = primary
            result.metadata.retained = True
            result.program.retained = True
        try:
            result.close()
        except cleanup:
            raise Error("SealedTransferPin: " + primary + "; " + String(cleanup))
        raise Error(primary)
    return result^


def pin_sealed_transfer(var backing: SealedTransferBacking, expected: ProgramPayloadRequest,
                        byte_bound: Int, allocation_bound: Int64, program_read_bound: Int,
                        metadata_read_bound: Int, sysfs: String, dev: String) raises -> SealedTransferPin:
    return _construct(backing^, expected, byte_bound, allocation_bound, program_read_bound, metadata_read_bound, True, sysfs, dev)


def view_sealed_transfer(var backing: SealedTransferBacking, expected: ProgramPayloadRequest,
                         byte_bound: Int, allocation_bound: Int64, program_read_bound: Int,
                         metadata_read_bound: Int) raises -> SealedTransferPin:
    return _construct(backing^, expected, byte_bound, allocation_bound, program_read_bound, metadata_read_bound, False, "-", "-")
