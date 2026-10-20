# Owned native syscall worker. Parent accesses output only after successful join.
from std.memory import Pointer
from std.origin import MutUntrackedOrigin
from hailbru.errors import herror
from hailbru.syscall import (
    syscall6, errno_now, sc_nr, os_worker_start, os_worker_join, os_fail_closed,
)
from hailbru.soc_abi import soc_zero_bytes, soc_ioctl, soc_channel_masks, SOC_IRQ_SIZE

comptime BLOCKING_HEADER_SIZE = 72


def _load_word(bytes: Pointer[UInt8, MutUntrackedOrigin], offset: Int) -> Int64:
    var value = UInt64(0)
    for index in range(8):
        value |= UInt64(bytes[unsafe_offset=offset + index]) << UInt64(index * 8)
    return Int64(value)


def _store_word(bytes: Pointer[UInt8, MutUntrackedOrigin], offset: Int, value: Int64):
    for index in range(8):
        bytes[unsafe_offset=offset + index] = UInt8((UInt64(value) >> UInt64(index * 8)) & UInt64(255))


def _blocking_entry(argument: Int64) abi("C") -> Int64:
    # No String, allocation, runtime task, exception or parent data access here.
    # Seven immutable syscall words; two result words belong exclusively to us.
    var bytes = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(argument))
    var result = syscall6(_load_word(bytes, 0), _load_word(bytes, 8), _load_word(bytes, 16),
                          _load_word(bytes, 24), _load_word(bytes, 32),
                          _load_word(bytes, 40), _load_word(bytes, 48))
    var error = errno_now() if result < 0 else Int64(0)
    _store_word(bytes, 56, result)
    _store_word(bytes, 64, error)
    return 0


struct BlockingCall(Movable):
    var _storage: List[UInt8]
    var _thread: UInt64
    var active: Bool
    var joined: Bool
    var arch: String

    def __init__(out self):
        self._storage = List[UInt8]()
        self._thread = 0
        self.active = False
        self.joined = False
        self.arch = String("")

    def __deinit__(deinit self):
        if self.active:
            print("HailbruError[LiveWorkerFatal]: unjoined worker; refusing unsafe resource destruction")
            os_fail_closed(self.arch, 123)

    def _start(mut self, arch: String, number: Int64, fd: Int64, second: Int64, third: Int64, payload: List[UInt8], payload_argument: Int) raises:
        if self.active or self.joined or len(self._storage) != 0:
            raise herror("WorkerState", "worker is single-use and already started")
        if fd < 0 or (arch != "aarch64" and arch != "x86_64") or number < 0:
            raise herror("WorkerState", "worker requires a valid fd and admitted architecture/syscall")
        self.arch = arch
        self._storage.reserve(BLOCKING_HEADER_SIZE + len(payload))
        for index in range(BLOCKING_HEADER_SIZE):
            self._storage.append(0)
        for byte in payload:
            self._storage.append(byte)
        var bytes = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(self._storage.unsafe_ptr()))
        _store_word(bytes, 0, number)
        _store_word(bytes, 8, fd)
        _store_word(bytes, 16, second)
        _store_word(bytes, 24, third)
        _store_word(bytes, payload_argument, Int64(Int(bytes)) + BLOCKING_HEADER_SIZE)
        var started = os_worker_start(_blocking_entry, Int64(Int(bytes)))
        if started[0] != 0:
            raise herror("WorkerStartFailed", "pthread_create error " + String(started[0]))
        self._thread = started[1]
        self.active = True

    def start_read(mut self, arch: String, fd: Int64) raises:
        var payload = soc_zero_bytes(1)
        self._start(arch, sc_nr(arch, "read"), fd, 0, 1, payload, 16)

    def start_interrupts(mut self, arch: String, fd: Int64, mask: UInt64) raises:
        # PCIe profile is engine zero, at most 32 channel bits. Owner supplies
        # its assigned channels; this primitive never infers their ownership.
        if mask == 0 or mask > UInt64(4294967295):
            raise herror("WorkerState", "empty or out-of-profile interrupt mask")
        var payload = soc_zero_bytes(SOC_IRQ_SIZE)
        var masks = soc_channel_masks(mask, 0, 0)
        for index in range(len(masks)):
            payload[index] = masks[index]
        self._start(arch, sc_nr(arch, "ioctl"), fd, Int64(soc_ioctl("interrupts")), 0, payload, 24)

    def join(mut self, timeout_ms: Int64) raises -> Bool:
        if not self.active:
            raise herror("WorkerState", "join requires an active worker")
        var result = os_worker_join(self.arch, self._thread, timeout_ms)
        if result == 110:  # ETIMEDOUT: thread and storage remain owned.
            return False
        if result != 0:
            raise herror("WorkerJoinFailed", "pthread_clockjoin_np error " + String(result))
        self.active = False
        self.joined = True
        return True

    def result(self) raises -> Tuple[Int64, Int64]:
        if self.active or not self.joined:
            raise herror("WorkerState", "result requires successful join")
        var bytes = Pointer[UInt8, MutUntrackedOrigin](unsafe_from_address=Int(self._storage.unsafe_ptr()))
        return (_load_word(bytes, 56), _load_word(bytes, 64))

    def payload(self) raises -> List[UInt8]:
        if self.active or not self.joined:
            raise herror("WorkerState", "payload requires successful join")
        var data = List[UInt8]()
        data.reserve(len(self._storage) - BLOCKING_HEADER_SIZE)
        for index in range(BLOCKING_HEADER_SIZE, len(self._storage)):
            data.append(self._storage[index])
        return data^
