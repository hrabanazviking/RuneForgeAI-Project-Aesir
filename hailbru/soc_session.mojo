# Owned descriptor/connection lifecycle and optional RPC storage; no launch yet.
from hailbru.errors import herror
from hailbru.soc_storage import SocRpcStorage
from hailbru.soc_driver import SocDriver, open_soc_driver
from hailbru.soc_abi import (
    soc_desc_create, soc_desc_reply, soc_desc_release, soc_connect,
    soc_connect_reply, soc_close, SOC_INVALID_HANDLE, _get,
)

comptime SOC_RPC_PORT = UInt64(12133)
comptime SOC_SESSION_DESC_COUNT = UInt64(65536)


struct SocSession(Movable):
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

    def allocate_rpc_storage(mut self) raises:
        self.require_open()
        if self.input_storage.address != 0 or self.output_storage.address != 0:
            raise herror("SocStorageState", "RPC storage already allocated")
        # Every partial allocation/map remains attached to this session for cleanup.
        self.input_storage.allocate(self.driver.arch, 1)
        self.input_storage.map(self.driver)
        self.output_storage.allocate(self.driver.arch, 2)
        self.output_storage.map(self.driver)

    def close(mut self) raises:
        if self.driver.fd < 0:
            return
        var failures = String("")
        var release_explicitly = not self.connect_attempted
        if self.connected:
            var data = soc_close(UInt64(self.input_channel), UInt64(self.output_channel))
            try:
                # Driver stops the assigned channels before the remote close.
                self.driver.request("close", data)
                release_explicitly = True
            except error:
                failures = String(error)
        # An uncertain connect/close must finalize its entire file context.
        # Never release descriptors explicitly while its channels may be active.
        if release_explicitly:
            # No waiter or launch exists in this storage-only slice. Channels have
            # stopped above; mapping/storage cleanup remains ordered before lists.
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
