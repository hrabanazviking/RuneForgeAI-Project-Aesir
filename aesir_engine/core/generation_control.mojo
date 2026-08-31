"""Linux cooperative cancellation/deadlines checked at native token boundaries.

The caller owns an optional pollable cancellation descriptor for the complete
session use. The core never consumes or closes that descriptor. This is not
preemption of an in-flight GPU operation and is not a hard real-time deadline.
"""
from std.collections import InlineArray
from std.ffi import external_call
from std.memory import Pointer
from core.sampling_config import NativeSamplingConfig


def monotonic_milliseconds() raises -> Int:
    var timestamp = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(1), timestamp.unsafe_ptr()) != 0:
        raise Error("Cannot observe monotonic generation clock")
    if timestamp[0] < 0 or timestamp[0] > 9223372036854775 or timestamp[1] < 0 or timestamp[1] >= 1000000000:
        raise Error("Invalid monotonic generation clock")
    var whole = Int(timestamp[0]) * 1000
    var fraction = Int(timestamp[1]) // 1000000
    if whole > 9223372036854775807 - fraction:
        raise Error("Monotonic clock overflow")
    return whole + fraction


def cancellation_ready(fd: Int) raises -> Bool:
    if fd < 0:
        return False
    # Linux x86-64 pollfd: int32 fd, int16 events, int16 revents.
    var descriptor = InlineArray[UInt64, 1](fill=UInt64(fd) | (UInt64(1) << 32))
    while True:
        var result = external_call["poll", Int32](descriptor.unsafe_ptr(), UInt64(1), Int32(0))
        if result >= 0:
            break
        if external_call["__errno_location", Pointer[Int32, MutUntrackedOrigin]]().unsafe_load() != 4:
            raise Error("Cancellation source poll failed")
    var events = (descriptor[0] >> 48) & 65535
    if events & 32:
        raise Error("Cancellation source was closed by its owner")
    return events & 25 != 0  # readable, error, or peer hangup


struct GenerationControl(Copyable, ImplicitlyCopyable):
    var timeout_ms: Int
    var cancel_fd: Int
    var deadline_ms: Int

    def __init__(out self, timeout_ms: Int = 0, cancel_fd: Int = -1) raises:
        if timeout_ms < 0 or timeout_ms > 3600000 or cancel_fd < -1 or cancel_fd > 2147483647:
            raise Error("Generation timeout must be 0..3600000 ms and cancellation descriptor valid")
        self.timeout_ms = timeout_ms
        self.cancel_fd = cancel_fd
        self.deadline_ms = 0

    def start(mut self) raises:
        self.deadline_ms = 0
        if self.timeout_ms:
            var now = monotonic_milliseconds()
            if now > 9223372036854775807 - self.timeout_ms:
                raise Error("Generation deadline overflow")
            self.deadline_ms = now + self.timeout_ms

    def stop_reason(self) raises -> String:
        if cancellation_ready(self.cancel_fd):
            return "cancelled"
        if self.deadline_ms != 0 and monotonic_milliseconds() >= self.deadline_ms:
            return "timeout"
        return ""


struct NativeGenerationStatus(Copyable, ImplicitlyCopyable):
    var healthy: Bool
    var generating: Bool
    var prompt_tokens: Int
    var generated_tokens: Int
    var position: Int
    var finish_reason: String

    def __init__(out self, healthy: Bool, generating: Bool, prompt_tokens: Int,
                 generated_tokens: Int, position: Int, finish_reason: String):
        self.healthy = healthy
        self.generating = generating
        self.prompt_tokens = prompt_tokens
        self.generated_tokens = generated_tokens
        self.position = position
        self.finish_reason = finish_reason



trait ControlledTextSession(Movable):
    """Serialized session contract; transport cannot inspect or own device memory."""
    def reset(mut self) raises: ...
    def begin_turn(mut self, prompt: String, system: String, max_tokens: Int) raises: ...
    def next_chunk(mut self) raises -> String: ...
    def cancel(mut self, reason: String = "cancelled") raises -> String: ...
    def configure_control(mut self, timeout_ms: Int = 0, cancel_fd: Int = -1) raises: ...
    def configure_sampling(mut self, sampling: NativeSamplingConfig) raises: ...
    def status(self) -> NativeGenerationStatus: ...
