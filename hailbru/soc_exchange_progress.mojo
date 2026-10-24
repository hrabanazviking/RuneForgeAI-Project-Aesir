# Original host event accounting. No clock, device call or lifetime authority.
from hailbru.errors import herror
from hailbru.soc_progress import SocRpcProgress


struct SocExchangeProgress(Movable):
    var progress: SocRpcProgress
    var deadline: Int64
    var last_time: Int64
    var snapshot_budget: Int
    var snapshots: Int
    var poisoned: Bool

    def __init__(out self, input_channel: UInt8, output_channel: UInt8,
                 input_capacity: UInt64, output_capacity: UInt64,
                 start_ms: Int64, timeout_ms: Int64, snapshot_budget: Int) raises:
        if timeout_ms < 1 or timeout_ms > 60000 or start_ms < 0 or start_ms > Int64(9223372036854775807) - timeout_ms:
            raise herror("BadDeadline", "invalid or overflowing total exchange deadline")
        if snapshot_budget < 1 or snapshot_budget > 32:
            raise herror("SocTransferBounds", "snapshot budget must be in [1,32]")
        self.progress = SocRpcProgress(input_channel, output_channel, input_capacity, output_capacity)
        self.deadline = start_ms + timeout_ms
        self.last_time = start_ms
        self.snapshot_budget = snapshot_budget
        self.snapshots = 0
        self.poisoned = False

    def _time(mut self, now_ms: Int64) raises -> Int64:
        if self.poisoned:
            raise herror("SocTransferState", "failed exchange requires a fresh owner")
        if now_ms < self.last_time:
            self.poisoned = True
            raise herror("SocClockFailed", "exchange clock moved backwards")
        if now_ms >= self.deadline:
            self.poisoned = True
            raise herror("SocWaitTimeout", "event reached the total exchange deadline")
        self.last_time = now_ms
        return self.deadline - now_ms

    def remaining_ms(mut self, now_ms: Int64) raises -> Int64:
        return self._time(now_ms)

    def launched(mut self, channel: UInt8, actual_descriptors: Int64, now_ms: Int64) raises:
        _ = self._time(now_ms)
        try:
            self.progress.launched(channel, actual_descriptors)
        except error:
            self.poisoned = True
            raise error

    def consume(mut self, data: List[UInt8], now_ms: Int64) raises:
        _ = self._time(now_ms)
        if self.snapshots >= self.snapshot_budget:
            self.poisoned = True
            raise herror("SocWaitTimeout", "exchange exhausted its IRQ snapshot budget")
        self.snapshots += 1
        try:
            self.progress.consume(data)
        except error:
            self.poisoned = True
            raise error

    def complete(self) -> Bool:
        return not self.poisoned and self.progress.complete()
