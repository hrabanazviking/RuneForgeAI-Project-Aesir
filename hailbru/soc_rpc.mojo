# Independent native integrated RPC transport. No vendor runtime or inference.
from hailbru.errors import herror
from hailbru.soc_session import SocSession, open_soc_session, SOC_SESSION_DESC_COUNT
from hailbru.soc_storage import SOC_RPC_STORAGE_SIZE
from hailbru.soc_progress import SocRpcProgress, rpc_descriptor_count
from hailbru.soc_abi import soc_transfer
from hailbru.hrpc_frame import HrpcFrame, encode_hrpc_frame, decode_hrpc_frame
from hailbru.syscall import os_clock_ms


struct SocRpcClient(Movable):
    var session: SocSession
    var exchanges: UInt64
    var input_completions: UInt64
    var output_completions: UInt64
    var irq_snapshots: UInt64
    var last_input_descriptors: Int64
    var last_output_descriptors: Int64

    def __init__(out self):
        self.session = SocSession()
        self.exchanges = 0
        self.input_completions = 0
        self.output_completions = 0
        self.irq_snapshots = 0
        self.last_input_descriptors = 0
        self.last_output_descriptors = 0

    def close(mut self) raises:
        self.session.close()

    def exchange(mut self, frame: HrpcFrame, timeout_ms: Int64) raises -> HrpcFrame:
        self.session.require_open()
        if timeout_ms < 1 or timeout_ms > 60000:
            raise herror("BadDeadline", "RPC timeout must be in [1,60000]ms")
        if frame.remote_status != 1:
            raise herror("BadRpcRequest", "outgoing RPC requires the established request status")
        var packet = encode_hrpc_frame(frame)
        var expected = rpc_descriptor_count(self.session.input_storage.address, self.session.page_size, SOC_SESSION_DESC_COUNT)
        if rpc_descriptor_count(self.session.output_storage.address, self.session.page_size, SOC_SESSION_DESC_COUNT) != expected:
            raise herror("SocTransferBounds", "directional storage has inconsistent descriptor extents")
        var progress = SocRpcProgress(self.session.input_channel, self.session.output_channel, expected)
        try:
            var start = os_clock_ms(self.session.driver.arch)
            if start < 0 or start > Int64(9223372036854715807):
                raise herror("SocClockFailed", "cannot establish RPC monotonic deadline")
            var deadline = start + timeout_ms
            self.session.input_storage.sync(self.session.driver, False)
            self.session.input_storage.write_message(packet)
            self.session.input_storage.sync(self.session.driver, True)
            self.session.output_storage.sync(self.session.driver, True)
            # Interrupts must be enabled before hardware can finish either side.
            self.session.enable_interrupts()
            var receive = soc_transfer(UInt64(self.session.output_channel), self.session.output_handle,
                                       self.session.output_storage.address, SOC_RPC_STORAGE_SIZE, False)
            self.session.output_storage.begin_transfer()
            var output_count = self.session.driver.request("transfer", receive)
            progress.launched(self.session.output_channel, output_count)
            self.last_output_descriptors = output_count
            var send = soc_transfer(UInt64(self.session.input_channel), self.session.input_handle,
                                    self.session.input_storage.address, SOC_RPC_STORAGE_SIZE, False)
            self.session.input_storage.begin_transfer()
            var input_count = self.session.driver.request("transfer", send)
            progress.launched(self.session.input_channel, input_count)
            self.last_input_descriptors = input_count
            # Limit zero-progress wakeups in addition to the absolute deadline.
            for snapshot in range(32):
                var now = os_clock_ms(self.session.driver.arch)
                if now < 0 or now < start:
                    raise herror("SocClockFailed", "invalid RPC monotonic clock")
                var remaining = deadline - now
                if remaining < 1:
                    raise herror("SocWaitTimeout", "RPC exchange exceeded its total deadline")
                var irqs = self.session.wait_interrupts(remaining)
                self.irq_snapshots += 1
                progress.consume(irqs)
                if progress.input_done and self.session.input_storage.transfer_pending:
                    self.session.input_storage.transfer_finished()
                    self.input_completions += 1
                if progress.output_done and self.session.output_storage.transfer_pending:
                    self.session.output_storage.transfer_finished()
                    self.output_completions += 1
                if progress.complete():
                    break
            if not progress.complete():
                raise herror("SocWaitTimeout", "RPC exchange exhausted its bounded IRQ wake budget")
            self.session.output_storage.sync(self.session.driver, False)
            var received = self.session.output_storage.read_bytes(Int(SOC_RPC_STORAGE_SIZE))
            var reply = decode_hrpc_frame(received, True)
            if reply.message_id != frame.message_id or reply.action_id != frame.action_id:
                raise herror("RpcReplyMismatch", "received frame does not correlate with this exchange")
            if reply.remote_status != 0:
                raise herror("RpcRemoteFailure", "device returned status " + String(reply.remote_status))
            self.exchanges += 1
            return reply^
        except error:
            var original = String(error)
            try:
                # Stop/join, quiesce channels, finalize mappings, then host memory.
                self.session.close()
            except cleanup:
                raise herror("SocCleanupFailed", original + "; " + String(cleanup))
            raise Error(original)


def open_soc_rpc(sysfs_root: String, dev_root: String) raises -> SocRpcClient:
    var client = SocRpcClient()
    client.session = open_soc_session(sysfs_root, dev_root)
    client.session.allocate_rpc_storage()
    return client^
