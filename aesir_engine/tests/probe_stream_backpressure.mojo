"""Independent no-reader socket probe for the bounded service send loop."""
from std.collections import InlineArray
from std.ffi import external_call
from core.generation_control import monotonic_milliseconds
from server.local_transport import OwnedFD, send_local


def main() raises:
    var descriptors = InlineArray[Int32, 2](fill=-1)
    # AF_UNIX, SOCK_STREAM | SOCK_NONBLOCK, protocol 0.
    if external_call["socketpair", Int32](Int32(1), Int32(2049), Int32(0), descriptors.unsafe_ptr()) != 0:
        raise Error("Cannot create no-reader transport probe")
    var writer = OwnedFD(descriptors[0])
    var reader = OwnedFD(descriptors[1])
    var small_buffer = InlineArray[Int32, 1](fill=2048)
    if external_call["setsockopt", Int32](writer.fd, Int32(1), Int32(7),
            small_buffer.unsafe_ptr(), Int32(4)) != 0:
        raise Error("Cannot bound no-reader send buffer")
    var payload = String("x")
    for _ in range(20):
        var doubled = String(payload)
        payload += doubled
    var started = monotonic_milliseconds()
    var rejected = False
    try:
        send_local(writer.fd, payload, 300, -1)
    except:
        rejected = True
    var elapsed = monotonic_milliseconds() - started
    if not rejected or elapsed < 250 or elapsed > 2000:
        raise Error("No-reader send did not respect the bounded I/O deadline")
    print("PASS no-reader transport: 1 MiB write bounded at " + String(elapsed) + " ms")
    _ = reader
    _ = writer
