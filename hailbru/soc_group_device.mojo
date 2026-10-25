# Original typed grouped lifecycle. A fresh owner per call; no borrowed handle.
# Host qualified only. File finalization never confirms logical destruction.
from hailbru.errors import herror
from hailbru.soc_group_rpc import SocGroupRpcClient, open_soc_group_rpc, open_soc_group_rpc_aligned
from hailbru.hrpc_device import HrpcDeviceIdentity, device_create_request, device_create_reply, device_identify_request, device_identify_reply, device_destroy_request, device_destroy_reply
from hailbru.syscall import os_clock_ms


struct GroupDeviceDeadline(Movable):
    var deadline: Int64
    var last_time: Int64
    var failed: Bool

    def __init__(out self, start_ms: Int64, timeout_ms: Int64) raises:
        if timeout_ms < 1 or timeout_ms > 60000 or start_ms < 0 or start_ms > Int64(9223372036854775807) - timeout_ms:
            raise herror("BadDeadline", "invalid or overflowing total device lifecycle deadline")
        self.deadline = start_ms + timeout_ms
        self.last_time = start_ms
        self.failed = False

    def remaining_ms(mut self, now_ms: Int64) raises -> Int64:
        if self.failed:
            raise herror("SocTransferState", "failed lifecycle clock cannot admit cleanup")
        if now_ms < 0 or now_ms < self.last_time:
            self.failed = True
            raise herror("SocClockFailed", "lifecycle clock failed or moved backwards")
        if now_ms >= self.deadline:
            self.failed = True
            raise herror("SocWaitTimeout", "total device lifecycle deadline reached")
        self.last_time = now_ms
        return self.deadline - now_ms


struct GroupDeviceResult(Movable):
    var handle_known: Bool
    var handle: UInt32
    var identity_present: Bool
    var identity: HrpcDeviceIdentity
    var destroy_attempted: Bool
    var destroy_confirmed: Bool
    var cleanup_attempted: Bool
    var attempts: Int
    var primary_error: String
    var cleanup_error: String
    var close_error: String
    var transport_poisoned: Bool
    var retained_views: Int
    var finalization_unconfirmed: Bool

    def __init__(out self):
        self.handle_known = False
        self.handle = 0
        self.identity_present = False
        self.identity = HrpcDeviceIdentity()
        self.destroy_attempted = False
        self.destroy_confirmed = False
        self.cleanup_attempted = False
        self.attempts = 0
        self.primary_error = ""
        self.cleanup_error = ""
        self.close_error = ""
        self.transport_poisoned = False
        self.retained_views = 0
        self.finalization_unconfirmed = False

    def success(self) -> Bool:
        return self.primary_error.byte_length() == 0 and self.close_error.byte_length() == 0 and self.identity_present and self.destroy_confirmed


def _group_device_lifecycle(var client: SocGroupRpcClient, timeout_ms: Int64) -> GroupDeviceResult:
    var result = GroupDeviceResult()
    try:
        var clock = GroupDeviceDeadline(os_clock_ms(client.session.driver.arch), timeout_ms)
        try:
            var remaining = clock.remaining_ms(os_clock_ms(client.session.driver.arch))
            var create = device_create_request(0)
            remaining = clock.remaining_ms(os_clock_ms(client.session.driver.arch))
            result.attempts += 1
            var created = client.exchange(create, remaining)
            _ = clock.remaining_ms(os_clock_ms(client.session.driver.arch))
            result.handle = device_create_reply(created, 0)
            result.handle_known = True
            _ = clock.remaining_ms(os_clock_ms(client.session.driver.arch))
            var identify = device_identify_request(1, result.handle)
            remaining = clock.remaining_ms(os_clock_ms(client.session.driver.arch))
            result.attempts += 1
            var identified = client.exchange(identify, remaining)
            _ = clock.remaining_ms(os_clock_ms(client.session.driver.arch))
            result.identity = device_identify_reply(identified, 1)
            _ = clock.remaining_ms(os_clock_ms(client.session.driver.arch))
            result.identity_present = True
            var destroy = device_destroy_request(2, result.handle)
            remaining = clock.remaining_ms(os_clock_ms(client.session.driver.arch))
            result.destroy_attempted = True
            result.attempts += 1
            var destroyed = client.exchange(destroy, remaining)
            _ = clock.remaining_ms(os_clock_ms(client.session.driver.arch))
            device_destroy_reply(destroyed, 2)
            _ = clock.remaining_ms(os_clock_ms(client.session.driver.arch))
            result.destroy_confirmed = True
        except error:
            result.primary_error = String(error)
            if result.handle_known and not result.destroy_attempted and client.available and not client.poisoned:
                try:
                    var remaining = clock.remaining_ms(os_clock_ms(client.session.driver.arch))
                    var cleanup = device_destroy_request(3, result.handle)
                    remaining = clock.remaining_ms(os_clock_ms(client.session.driver.arch))
                    result.destroy_attempted = True
                    result.cleanup_attempted = True
                    result.attempts += 1
                    var destroyed = client.exchange(cleanup, remaining)
                    _ = clock.remaining_ms(os_clock_ms(client.session.driver.arch))
                    device_destroy_reply(destroyed, 3)
                    _ = clock.remaining_ms(os_clock_ms(client.session.driver.arch))
                    result.destroy_confirmed = True
                except cleanup_error:
                    result.cleanup_error = String(cleanup_error)
    except error:
        result.primary_error = String(error)
    # Unconditional local finalization uses the existing stop/join/retention
    # owner, even when no further logical RPC is admissible. Never retry close.
    try:
        client.close()
    except error:
        result.close_error = String(error)
    result.transport_poisoned = client.poisoned
    result.retained_views = Int(client.session.input_storage.address != 0) + Int(client.session.output_storage.address != 0)
    result.finalization_unconfirmed = client.session.finalization_unconfirmed
    return result^


def run_group_device(sysfs_root: String, dev_root: String, timeout_ms: Int64) raises -> GroupDeviceResult:
    # Establishment has its existing owner/unwind behavior. The single lifecycle
    # budget begins only after fresh transport/storage establishment succeeds.
    return _group_device_lifecycle(open_soc_group_rpc(sysfs_root, dev_root), timeout_ms)


def run_group_device_aligned(sysfs_root: String, dev_root: String, timeout_ms: Int64) raises -> GroupDeviceResult:
    # The same typed lifecycle over the explicit aligned grouped backing.
    # Host qualification only until a separate physical contract.
    return _group_device_lifecycle(open_soc_group_rpc_aligned(sysfs_root, dev_root), timeout_ms)
