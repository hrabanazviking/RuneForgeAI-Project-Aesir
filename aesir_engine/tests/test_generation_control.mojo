"""Native deadline and pollable cancellation checks without a model/GPU."""
from std.collections import InlineArray
from std.ffi import external_call
from core.generation_control import GenerationControl, monotonic_milliseconds
from cli.interrupts import ChatInterrupts, consume_interrupts


def test_generation_deadline() raises:
    var control = GenerationControl()
    control.start()
    if control.stop_reason() != "" or control.deadline_ms != 0:
        raise Error("Disabled deadline stopped generation")
    control = GenerationControl(10000)
    control.start()
    if control.stop_reason() != "":
        raise Error("Fresh deadline expired prematurely")
    control.deadline_ms = monotonic_milliseconds() - 1
    if control.stop_reason() != "timeout":
        raise Error("Expired monotonic deadline ignored")


def test_generation_control_rejection() raises:
    for choice in range(4):
        var rejected = False
        try:
            if choice == 0:
                _ = GenerationControl(-1)
            elif choice == 1:
                _ = GenerationControl(3600001)
            elif choice == 2:
                _ = GenerationControl(0, -2)
            else:
                _ = GenerationControl(0, 2147483648)
        except:
            rejected = True
        if not rejected:
            raise Error("Invalid native generation control accepted")


def exercise_generation_sigint() raises:
    var interrupts = ChatInterrupts()
    var control = GenerationControl(0, interrupts.fd)
    if control.stop_reason() != "":
        raise Error("Fresh signal source appears cancelled")
    # Unit coverage targets this owner thread; the opt-in public-CLI test
    # delivers process-wide SIGINT with the actual MAX/CUDA worker threads.
    var thread = external_call["pthread_self", UInt64]()
    if external_call["pthread_kill", Int32](thread, Int32(2)) != 0:
        raise Error("Cannot deliver SIGINT to the test process")
    if control.stop_reason() != "cancelled" or not consume_interrupts(interrupts.fd):
        raise Error("SIGINT did not reach native cancellation")
    if control.stop_reason() != "":
        raise Error("Consumed SIGINT still cancels generation")
    _ = interrupts


def test_generation_sigint() raises:
    var before = InlineArray[UInt64, 16](fill=0)
    var after = InlineArray[UInt64, 16](fill=0)
    if external_call["pthread_sigmask", Int32](Int32(0), Int(0), Int(before.unsafe_ptr())) != 0:
        raise Error("Cannot query original signal mask")
    exercise_generation_sigint()
    if external_call["pthread_sigmask", Int32](Int32(0), Int(0), Int(after.unsafe_ptr())) != 0:
        raise Error("Cannot query restored signal mask")
    if before[0] != after[0]:
        raise Error("Native cancellation leaked its SIGINT mask")


def main() raises:
    test_generation_deadline()
    test_generation_control_rejection()
    test_generation_sigint()
    print("PASS native deadlines, invalid controls and real SIGINT cancellation")
