# Owned descriptor/connection lifecycle and optional RPC storage; no launch yet.
from hailbru.errors import herror
from hailbru.soc_storage import SocRpcStorage
from hailbru.blocking_call import BlockingCall
from hailbru.syscall import os_fail_closed
from hailbru.soc_driver import _checked_ioctl_result
from hailbru.soc_driver import SocDriver, open_soc_driver
from hailbru.soc_abi import (
    soc_desc_create, soc_desc_reply, soc_desc_release, soc_connect,
    soc_connect_reply, soc_close, soc_channel_masks, soc_interrupts_json, SOC_INVALID_HANDLE, _get,
)

comptime SOC_RPC_PORT = UInt64(12133)
comptime SOC_SESSION_DESC_COUNT = UInt64(65536)


struct SocSession(Movable):
    var waiter: BlockingCall
    var interrupts_enabled: Bool
    var wait_failed: Bool
    var cancel_attempts: Int
    var cancel_errors: String
    var input_storage: SocRpcStorage
    var output_storage: SocRpcStorage
    var driver: SocDriver
    var input_handle: UInt64
    var output_handle: UInt64
    var input_channel: UInt8
    var output_channel: UInt8
    var connect_attempted: Bool
    var connected: Bool
    var page_size: UInt64

    def __init__(out self):
        self.waiter = BlockingCall()
        self.interrupts_enabled = False
        self.wait_failed = False
        self.cancel_attempts = 0
        self.cancel_errors = String("")
        self.input_storage = SocRpcStorage()
        self.output_storage = SocRpcStorage()
        self.driver = SocDriver()
        self.input_handle = SOC_INVALID_HANDLE
        self.output_handle = SOC_INVALID_HANDLE
        self.input_channel = 255
        self.output_channel = 255
        self.connect_attempted = False
        self.connected = False
        self.page_size = 0

    def __deinit__(deinit self):
        try:
            self.close()
        except error:
            print(String(error))

    def require_open(self) raises:
        if not self.connected or self.driver.fd < 0:
            raise herror("SocSessionClosed", "assigned PCIe connection is closed")
        if self.wait_failed:
            raise herror("SocSessionCancelled", "failed wait requires connection close")

    def allocate_rpc_storage(mut self) raises:
        self.require_open()
        if self.input_storage.address != 0 or self.output_storage.address != 0:
            raise herror("SocStorageState", "RPC storage already allocated")
        # Every partial allocation/map remains attached to this session for cleanup.
        self.input_storage.allocate(self.driver.arch, 1)
        self.input_storage.map(self.driver)
        self.output_storage.allocate(self.driver.arch, 2)
        self.output_storage.map(self.driver)

    def _interrupt_mask(self) -> UInt64:
        return (UInt64(1) << UInt64(self.input_channel)) | (UInt64(1) << UInt64(self.output_channel))

    def _disable_interrupts(mut self) raises:
        if self.interrupts_enabled:
            var masks = soc_channel_masks(self._interrupt_mask(), 0, 0)
            _ = self.driver.request("disable-channels", masks)
            self.interrupts_enabled = False

    def _stop_waiter(mut self):
        if not self.waiter.active:
            return
        # No asynchronous cancellation: wake only our assigned channel wait.
        for attempt in range(2):
            self.cancel_attempts += 1
            try:
                self._disable_interrupts()
            except error:
                self.cancel_errors += "; " + String(error)
            try:
                if self.waiter.join(1000):
                    return
            except error:
                self.cancel_errors += "; " + String(error)
        print("HailbruError[SocWaitCancelFatal]: waiter did not join after two bounded cancellation attempts" + self.cancel_errors)
        os_fail_closed(self.driver.arch, 124)

    def enable_interrupts(mut self) raises:
        self.require_open()
        if not self.interrupts_enabled:
            var masks = soc_channel_masks(self._interrupt_mask(), 0, 0)
            # Enable errors can follow side effects. Cleanup stays armed.
            self.interrupts_enabled = True
            _ = self.driver.request("enable-channels", masks)

    def wait_interrupts(mut self, timeout_ms: Int64) raises -> List[UInt8]:
        self.require_open()
        if timeout_ms < 1 or timeout_ms > 60000:
            raise herror("BadDeadline", "interrupt timeout must be in [1,60000]ms")
        if self.waiter.active:
            raise herror("WorkerState", "session already has an active waiter")
        self.waiter = BlockingCall()
        self.cancel_attempts = 0
        self.cancel_errors = String("")
        try:
            self.enable_interrupts()
            self.waiter.start_interrupts(self.driver.arch, self.driver.fd, self._interrupt_mask())
            if not self.waiter.join(timeout_ms):
                self.wait_failed = True
                self._stop_waiter()
                raise herror("SocWaitTimeout", "assigned interrupt wait exceeded " + String(timeout_ms) + "ms; waiter joined after channel disable")
            var result = self.waiter.result()
            _ = _checked_ioctl_result("interrupts", result[0], result[1])
            var data = self.waiter.payload()
            _ = soc_interrupts_json(data)
            for index in range(Int(data[24])):
                var offset = 25 + index * 3
                if data[offset] != 0 or (self._interrupt_mask() & (UInt64(1) << UInt64(data[offset + 1]))) == 0:
                    raise herror("SocDriverMismatch", "interrupt reply contains an unowned engine/channel")
            return data^
        except error:
            self.wait_failed = True
            self._stop_waiter()
            raise error

    def close(mut self) raises:
        self._stop_waiter()
        if self.driver.fd < 0:
            return
        var failures = String("")
        try:
            self._disable_interrupts()
        except error:
            failures = String(error)
        var release_explicitly = not self.connect_attempted
        if self.connected:
            var data = soc_close(UInt64(self.input_channel), UInt64(self.output_channel))
            try:
                # Driver stops the assigned channels before the remote close.
                self.driver.request("close", data)
                self.output_storage.channels_quiesced()
                self.input_storage.channels_quiesced()
                release_explicitly = True
            except error:
                failures += "; " + String(error)
        # An uncertain connect/close must finalize its entire file context.
        # Never release descriptors explicitly while its channels may be active.
        if release_explicitly:
            # The waiter has joined and channels stopped above. Mapping/storage
            # cleanup remains ordered before descriptor release.
            for index in range(2):
                try:
                    if index == 0:
                        if self.output_storage.mapped:
                            self.output_storage.unmap(self.driver)
                    else:
                        if self.input_storage.mapped:
                            self.input_storage.unmap(self.driver)
                except error:
                    failures += "; " + String(error)
            if self.output_handle != SOC_INVALID_HANDLE:
                var data = soc_desc_release(self.output_handle)
                try:
                    self.driver.request("desc-release", data)
                except error:
                    failures += "; " + String(error)
            if self.input_handle != SOC_INVALID_HANDLE:
                var data = soc_desc_release(self.input_handle)
                try:
                    self.driver.request("desc-release", data)
                except error:
                    failures += "; " + String(error)
        try:
            # File-context cleanup finalizes channels before remaining lists.
            self.driver.close()
        except error:
            failures += "; " + String(error)
        self.interrupts_enabled = False
        # File-context finalization is the fallback for uncertain map/unmap.
        # Host memory is retained until after the driver fd has been closed.
        self.output_storage.context_finalized()
        self.input_storage.context_finalized()
        try:
            self.output_storage.release()
        except error:
            failures += "; " + String(error)
        try:
            self.input_storage.release()
        except error:
            failures += "; " + String(error)
        self.connected = False
        self.connect_attempted = False
        self.input_handle = SOC_INVALID_HANDLE
        self.output_handle = SOC_INVALID_HANDLE
        self.input_channel = 255
        self.output_channel = 255
        if failures.byte_length() != 0:
            raise herror("SocCleanupFailed", failures)


def open_soc_session(sysfs_root: String, dev_root: String) raises -> SocSession:
    var session = SocSession()
    session.driver = open_soc_driver(sysfs_root, dev_root)
    try:
        var maximum = _get(session.driver.properties, 0, 2)
        session.page_size = UInt64(512) if maximum >= 512 else maximum
        var input = soc_desc_create(SOC_SESSION_DESC_COUNT, session.page_size, True)
        session.driver.request("desc-create", input)
        session.input_handle = soc_desc_reply(input)[0]
        var output = soc_desc_create(SOC_SESSION_DESC_COUNT, session.page_size, True)
        session.driver.request("desc-create", output)
        session.output_handle = soc_desc_reply(output)[0]
        var connect = soc_connect(SOC_RPC_PORT, session.input_handle, session.output_handle)
        session.connect_attempted = True
        session.driver.request("connect", connect)
        var channels = soc_connect_reply(connect)
        # Installed PCIe profile has source bits 0..15, destination bits 16..31.
        if channels[0] >= 16 or channels[1] < 16 or channels[1] >= 32:
            raise herror("SocDriverMismatch", "assigned channels contradict the qualified PCIe direction profile")
        session.input_channel = channels[0]
        session.output_channel = channels[1]
        session.connected = True
    except error:
        var original = String(error)
        try:
            session.close()
        except cleanup:
            raise herror("SocCleanupFailed", original + "; " + String(cleanup))
        raise Error(original)
    return session^
