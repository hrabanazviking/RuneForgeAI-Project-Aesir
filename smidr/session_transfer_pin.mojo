# Original same-file session and sealed two-part mapping owner. No submission.
from hailbru.syscall import os_host_architecture, os_page_size
from hailbru.soc_session import SocSession, open_soc_session
from hailbru.soc_group import SocUserptrGroup, SocUserptrSpan
from smidr.program_payload import ProgramPayloadRequest
from smidr.sealed_transfer_backing import SealedTransferBacking, _actual
from smidr.sealed_transfer_pin import _PinnedPart, _view, _map


struct SessionTransferPin(Movable):
    var session: SocSession
    var backing: SealedTransferBacking
    var metadata: _PinnedPart
    var program: _PinnedPart
    var page_size: Int64
    var context_finalized: Bool
    var finalization_unconfirmed: Bool
    var finalization_errors: String
    var _driver_fd: Int64
    var _input_handle: UInt64
    var _output_handle: UInt64
    var _input_channel: UInt8
    var _output_channel: UInt8
    var _metadata_address: Int64
    var _program_address: Int64
    var _program_bytes: Int64

    def __init__(out self):
        self.session = SocSession()
        self.backing = SealedTransferBacking()
        self.metadata = _PinnedPart()
        self.program = _PinnedPart()
        self.page_size = 0
        self.context_finalized = False
        self.finalization_unconfirmed = False
        self.finalization_errors = String("")
        self._driver_fd = -1
        self._input_handle = 0
        self._output_handle = 0
        self._input_channel = 255
        self._output_channel = 255
        self._metadata_address = 0
        self._program_address = 0
        self._program_bytes = 0

    def __deinit__(deinit self):
        try:
            self.close()
        except error:
            print(String(error))
        if self.finalization_unconfirmed:
            # Keep both actual kernel fds open until process finalization.
            self.backing.metadata_fd = -1
            self.backing.program.fd = -1

    def _poison(mut self, failures: String):
        self.finalization_unconfirmed = True
        self.finalization_errors = failures
        self.metadata.retained = True
        self.program.retained = True

    def _finalize_session(mut self) raises -> String:
        if self.finalization_unconfirmed:
            raise Error("SessionTransferPin: cleanup_unconfirmed; backing retained" + self.finalization_errors)
        var failures = String("")
        try:
            # Existing session owns its waiter, channels, lists and driver fd.
            # Both extra mappings stay attached until whole-file finalization.
            self.session.close()
        except error:
            failures = String(error)
        if self.session.finalization_unconfirmed or self.session.driver.fd >= 0:
            self._poison(failures)
            raise Error("SessionTransferPin: cleanup_unconfirmed; backing retained" + self.finalization_errors)
        self.context_finalized = True
        self.metadata.retained = False
        self.program.retained = False
        # A prior cleanup error does not undo an independently confirmed close.
        return failures

    def finalize_session(mut self) raises:
        var failures = self._finalize_session()
        if failures.byte_length() != 0:
            raise Error("SessionTransferPin: " + failures)

    def close(mut self) raises:
        var failures = self._finalize_session()
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
            raise Error("SessionTransferPin: " + failures)

    def owned_group(self) raises -> SocUserptrGroup:
        if self.finalization_unconfirmed or self.context_finalized:
            raise Error("SessionTransferPin: finalized or poisoned owner has no live group")
        self.session.require_open()
        if self.session.driver.fd != self._driver_fd or self.session.input_handle != self._input_handle or self.session.output_handle != self._output_handle or self.session.input_channel != self._input_channel or self.session.output_channel != self._output_channel:
            raise Error("SessionTransferPin: session identity differs from its owned mapping context")
        if not self.metadata.view_owned or not self.program.view_owned or not self.metadata.mapped or not self.program.mapped or not self.metadata.retained or not self.program.retained:
            raise Error("SessionTransferPin: both owned parts must remain mapped and retained")
        if self.metadata.address != self._metadata_address or self.program.address != self._program_address or self.metadata.logical_bytes != 2068 or self.program.logical_bytes != self._program_bytes:
            raise Error("SessionTransferPin: actual owned mapping tuple was changed")
        var spans = List[SocUserptrSpan]()
        spans.append(SocUserptrSpan(UInt64(self.metadata.address), UInt64(self.metadata.logical_bytes)))
        spans.append(SocUserptrSpan(UInt64(self.program.address), UInt64(self.program.logical_bytes)))
        # Value intent only. The caller gains no DMA/capacity/lifetime authority.
        return SocUserptrGroup(UInt64(self._input_channel), self._input_handle, spans)


def pin_session_transfer(var backing: SealedTransferBacking, expected: ProgramPayloadRequest,
                         byte_bound: Int, allocation_bound: Int64, program_read_bound: Int,
                         metadata_read_bound: Int, sysfs: String, dev: String) raises -> SessionTransferPin:
    if os_host_architecture() != "aarch64" or byte_bound < 2068 or allocation_bound <= 0 or program_read_bound <= 0 or metadata_read_bound <= 0:
        raise Error("SessionTransferPin: qualified host and positive independent bounds required")
    if backing.program.program_bytes > Int64(byte_bound):
        raise Error("SessionTransferPin: program exceeds explicit byte bound")
    if sysfs.byte_length() == 0 or sysfs.byte_length() >= 4096 or "\0" in sysfs or dev.byte_length() == 0 or dev.byte_length() >= 4096 or "\0" in dev:
        raise Error("SessionTransferPin: invalid bounded session roots")
    var snapshot = _actual(backing, expected, program_read_bound, metadata_read_bound)
    var result = SessionTransferPin()
    result.backing = backing^
    result.page_size = os_page_size()
    if result.page_size <= 0:
        raise Error("SessionTransferPin: invalid actual page size")
    try:
        result.metadata = _view(result.backing.metadata_fd, snapshot.metadata, result.page_size, allocation_bound)
        result.program = _view(result.backing.program.fd, snapshot.program, result.page_size, allocation_bound - result.metadata.mapping_bytes)
        # Both full byte views were checked before any session or map request.
        result.session = open_soc_session(sysfs, dev)
        result._driver_fd = result.session.driver.fd
        result._input_handle = result.session.input_handle
        result._output_handle = result.session.output_handle
        result._input_channel = result.session.input_channel
        result._output_channel = result.session.output_channel
        result._metadata_address = result.metadata.address
        result._program_address = result.program.address
        result._program_bytes = result.program.logical_bytes
        _map(result.metadata, result.session.driver)
        _map(result.program, result.session.driver)
    except error:
        var primary = String(error)
        if "driver fd close:" in primary or "unconfirmed finalization; backing retained" in primary:
            # A failed helper may not return its uncertain session to our field.
            result._poison(primary)
        try:
            result.close()
        except cleanup:
            raise Error("SessionTransferPin: " + primary + "; " + String(cleanup))
        raise Error(primary)
    return result^
