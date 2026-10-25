# Minimal grouped transfer primitive, extracted from the Campaign 1
# evidence (docs/HAILO10H_GROUPED_TRANSFER_SEMANTICS_2026-10-24.md,
# AES-TRANSFER-001). One outstanding raw exchange over the grouped
# owner: the caller supplies the exact logical packet bytes and owns
# all framing; this module owns spans, launch order and counts,
# completion evidence, cache sync, ownership and quarantine only.
# Not a general arbitrary-RPC API. The HRPC client
# (soc_group_rpc.mojo) is untouched and keeps its own qualification.
from hailbru.errors import herror
from hailbru.soc_session import SocSession, open_soc_session, SOC_SESSION_DESC_COUNT
from hailbru.soc_storage import SOC_RPC_STORAGE_SIZE, SOC_RPC_HEADER_SIZE
from hailbru.soc_exchange_progress import SocExchangeProgress
from hailbru.soc_group import SocUserptrSpan, SocUserptrGroup, encode_soc_group
from hailbru.soc_abi import soc_transfer
from hailbru.syscall import os_clock_ms


struct SocGroupedTransfer(Movable):
    var session: SocSession
    var poisoned: Bool
    var available: Bool
    var busy: Bool
    var owned_fd: Int64
    var input_handle: UInt64
    var output_handle: UInt64
    var input_channel: UInt8
    var output_channel: UInt8
    var input_address: UInt64
    var output_address: UInt64
    var input_mapping: UInt64
    var output_mapping: UInt64
    var input_body_offset: UInt64
    var input_mapped_size: UInt64
    var exchanges: UInt64
    var input_completions: UInt64
    var output_completions: UInt64
    var irq_snapshots: UInt64
    var last_input_descriptors: Int64
    var last_output_descriptors: Int64

    def __init__(out self):
        self.session = SocSession()
        self.poisoned = False
        self.available = False
        self.busy = False
        self.owned_fd = -1
        self.input_handle = 0
        self.output_handle = 0
        self.input_channel = 255
        self.output_channel = 255
        self.input_address = 0
        self.output_address = 0
        self.input_mapping = 0
        self.output_mapping = 0
        self.input_body_offset = SOC_RPC_HEADER_SIZE
        self.input_mapped_size = SOC_RPC_STORAGE_SIZE
        self.exchanges = 0
        self.input_completions = 0
        self.output_completions = 0
        self.irq_snapshots = 0
        self.last_input_descriptors = 0
        self.last_output_descriptors = 0

    def close(mut self) raises:
        self.available = False
        try:
            self.session.close()
        except error:
            self.poisoned = True
            raise error

    def _owned(self) raises:
        self.session.require_open()
        if self.session.driver.fd != self.owned_fd or self.session.input_handle != self.input_handle or self.session.output_handle != self.output_handle or self.session.input_channel != self.input_channel or self.session.output_channel != self.output_channel:
            raise herror("SocTransferOwner", "session assignment differs from its captured owner")
        if self.session.input_storage.address != self.input_address or self.session.output_storage.address != self.output_address or self.session.input_storage.handle != self.input_mapping or self.session.output_storage.handle != self.output_mapping:
            raise herror("SocTransferOwner", "control storage differs from its captured owner")
        if self.session.input_storage.body_offset() != self.input_body_offset or self.session.input_storage.mapped_size() != self.input_mapped_size:
            raise herror("SocTransferOwner", "control storage layout differs from its captured owner")
        if self.input_address == 0 or self.output_address == 0 or not self.session.input_storage.mapped or not self.session.output_storage.mapped or self.session.input_storage.owner_fd != self.owned_fd or self.session.output_storage.owner_fd != self.owned_fd or self.session.input_storage.direction != 1 or self.session.output_storage.direction != 2:
            raise herror("SocTransferOwner", "control storage is not mapped on its owning file")

    def _tick(mut self, mut progress: SocExchangeProgress) raises -> Int64:
        return progress.remaining_ms(os_clock_ms(self.session.driver.arch))

    def input_group(self) raises -> SocUserptrGroup:
        if self.poisoned or not self.available:
            raise herror("SocTransferState", "closed or failed grouped transfer requires a fresh owner")
        self._owned()
        var spans = List[SocUserptrSpan]()
        spans.append(SocUserptrSpan(self.input_address, UInt64(SOC_RPC_HEADER_SIZE)))
        spans.append(SocUserptrSpan(self.input_address + self.input_body_offset, UInt64(SOC_RPC_STORAGE_SIZE - SOC_RPC_HEADER_SIZE)))
        return SocUserptrGroup(UInt64(self.input_channel), self.input_handle, spans)

    def exchange_raw(mut self, packet: List[UInt8], timeout_ms: Int64) raises -> List[UInt8]:
        if self.poisoned or not self.available or self.busy:
            raise herror("SocTransferState", "closed,failed or busy grouped transfer requires a fresh owner")
        # Oversize packets are refused by the storage write inside the
        # exchange (SocStorageBounds), exactly as the RPC client's are:
        # the refusal poisons this owner, never silently reuses it.
        self.busy = True
        try:
            self._owned()
            var start = os_clock_ms(self.session.driver.arch)
            var progress = SocExchangeProgress(self.input_channel,self.output_channel,SOC_SESSION_DESC_COUNT,SOC_SESSION_DESC_COUNT,start,timeout_ms,32)
            var group = self.input_group()
            var send = encode_soc_group(group)
            var receive = soc_transfer(UInt64(self.output_channel),self.output_handle,self.output_address,SOC_RPC_STORAGE_SIZE,False)
            _ = self._tick(progress)
            self.session.input_storage.sync(self.session.driver,False)
            _ = self._tick(progress)
            self.session.input_storage.write_message(packet)
            _ = self._tick(progress)
            self.session.input_storage.sync(self.session.driver,True)
            _ = self._tick(progress)
            self.session.output_storage.sync(self.session.driver,True)
            _ = self._tick(progress)
            self.session.enable_interrupts()
            _ = self._tick(progress)
            self.session.output_storage.begin_transfer()
            self.last_output_descriptors = self.session.driver.request("transfer",receive)
            progress.launched(self.output_channel,self.last_output_descriptors,os_clock_ms(self.session.driver.arch))
            self.session.input_storage.begin_transfer()
            self.last_input_descriptors = self.session.driver.request("transfer",send)
            progress.launched(self.input_channel,self.last_input_descriptors,os_clock_ms(self.session.driver.arch))
            for _ in range(32):
                var remaining = self._tick(progress)
                var irqs = self.session.wait_interrupts(remaining)
                self.irq_snapshots += 1
                progress.consume(irqs,os_clock_ms(self.session.driver.arch))
                if progress.progress.input_done and self.session.input_storage.transfer_pending:
                    self.session.input_storage.transfer_finished()
                    self.input_completions += 1
                if progress.progress.output_done and self.session.output_storage.transfer_pending:
                    self.session.output_storage.transfer_finished()
                    self.output_completions += 1
                if progress.complete():
                    break
            if not progress.complete():
                raise herror("SocWaitTimeout", "grouped transfer exhausted its total snapshot budget")
            _ = self._tick(progress)
            self.session.output_storage.sync(self.session.driver,False)
            _ = self._tick(progress)
            var received = self.session.output_storage.read_bytes(Int(SOC_RPC_STORAGE_SIZE))
            _ = self._tick(progress)
            self.exchanges += 1
            self.busy = False
            return received^
        except error:
            self.poisoned = True
            self.busy = False
            var original = String(error)
            try:
                self.close()
            except cleanup:
                raise herror("SocCleanupFailed", original + "; " + String(cleanup))
            raise Error(original)


def _open_grouped_transfer(sysfs_root: String, dev_root: String, aligned: Bool) raises -> SocGroupedTransfer:
    var transfer = SocGroupedTransfer()
    transfer.session = open_soc_session(sysfs_root,dev_root)
    try:
        if aligned:
            transfer.session.allocate_rpc_storage_aligned()
        else:
            transfer.session.allocate_rpc_storage()
        transfer.owned_fd = transfer.session.driver.fd
        transfer.input_handle = transfer.session.input_handle
        transfer.output_handle = transfer.session.output_handle
        transfer.input_channel = transfer.session.input_channel
        transfer.output_channel = transfer.session.output_channel
        transfer.input_address = transfer.session.input_storage.address
        transfer.output_address = transfer.session.output_storage.address
        transfer.input_mapping = transfer.session.input_storage.handle
        transfer.output_mapping = transfer.session.output_storage.handle
        transfer.input_body_offset = transfer.session.input_storage.body_offset()
        transfer.input_mapped_size = transfer.session.input_storage.mapped_size()
        transfer.available = True
        transfer._owned()
    except error:
        var original = String(error)
        try:
            transfer.close()
        except cleanup:
            raise herror("SocCleanupFailed", original + "; " + String(cleanup))
        raise Error(original)
    return transfer^


def open_grouped_transfer(sysfs_root: String, dev_root: String) raises -> SocGroupedTransfer:
    return _open_grouped_transfer(sysfs_root, dev_root, False)


def open_grouped_transfer_aligned(sysfs_root: String, dev_root: String) raises -> SocGroupedTransfer:
    # Explicit aligned backing (AES-CONTROL-017 layout): the grouped
    # input spans sit at descriptor-page aligned offsets inside one
    # larger mapping. Host qualification is slice 2.3; no physical
    # child is admitted by this module.
    return _open_grouped_transfer(sysfs_root, dev_root, True)
