"""Descriptor ownership transfer and idempotent moved-from cleanup checks."""
from std.collections import InlineArray
from std.ffi import external_call
from core.generation_control import monotonic_milliseconds
from server.local_transport import OwnedFD, listen_local, receive_head, receive_body


def test_owned_fd_transfer_release() raises:
    # A pipe gives us two uniquely owned descriptors without opening a listener.
    var descriptors = InlineArray[Int32, 2](fill=-1)
    if external_call["pipe2", Int32](descriptors.unsafe_ptr(), Int32(526336)) != 0:
        raise Error("Cannot create descriptor ownership fixture")
    var writer = OwnedFD(descriptors[1])
    var reader = OwnedFD(descriptors[0])
    var raw = writer.fd
    # Model PendingClient.detach(): poison the source owner, then adopt once.
    writer.fd = -1
    var moved = OwnedFD(raw)
    if writer.fd != -1 or moved.fd != raw:
        raise Error("Descriptor ownership transfer did not preserve one live owner")
    _ = writer
    var byte = InlineArray[Int8, 1](fill=0)
    if external_call["read", Int64](Int64(reader.fd), byte.unsafe_ptr(), Int64(1)) != -1:
        raise Error("Moved-from destructor closed the transferred descriptor")
    _ = moved
    if external_call["read", Int64](Int64(reader.fd), byte.unsafe_ptr(), Int64(1)) != 0:
        raise Error("Transferred descriptor remained open after its owner ended")
    _ = reader
    print("PASS OwnedFD transfer: moved-from cleanup is inert; destination closes once")


def test_socket_admission_rejection() raises:
    var rejected_negative = False
    var rejected_privileged = False
    var rejected_too_large = False
    try:
        _ = listen_local(-1)
    except:
        rejected_negative = True
    try:
        _ = listen_local(1023)
    except:
        rejected_privileged = True
    try:
        _ = listen_local(65536)
    except:
        rejected_too_large = True
    if not rejected_negative or not rejected_privileged or not rejected_too_large:
        raise Error("Invalid service port reached socket setup")
    var rejected_fd = False
    try:
        _ = OwnedFD(-1)
    except:
        rejected_fd = True
    if not rejected_fd:
        raise Error("Invalid descriptor constructed an owner")
    print("PASS listener/owner admission: invalid ports and negative descriptors reject")


def test_socketpair_request_transport() raises:
    var descriptors = InlineArray[Int32, 2](fill=-1)
    if external_call["socketpair", Int32](Int32(1), Int32(526337), Int32(0), descriptors.unsafe_ptr()) != 0:
        raise Error("Cannot create parser transport socketpair")
    var peer = OwnedFD(descriptors[0])
    var server = OwnedFD(descriptors[1])
    var request = String("POST /v1/generate HTTP/1.1\r\nHost: 127.0.0.1:18434\r\nContent-Length: 4\r\nContent-Type: application/json\r\n\r\n{}{}")
    var bytes = request.as_bytes()
    var wrote = external_call["write", Int64](Int64(peer.fd), bytes.unsafe_ptr().unsafe_bitcast[Int8](), Int64(len(bytes)))
    if wrote != Int64(len(bytes)):
        raise Error("Parser transport fixture write was incomplete")
    var deadline = monotonic_milliseconds() + 1000
    var head = receive_head(server.fd, deadline, -1)
    if not head.endswith("\r\n\r\n") or "Content-Length: 4" not in head:
        raise Error("Transport did not return exactly one complete request head")
    var body = receive_body(server.fd, 4, deadline, -1)
    if body != "{}{}":
        raise Error("Transport body reader lost or consumed adjacent request bytes")
    _ = server
    _ = peer
    print("PASS socketpair request transport: exact head/body framing preserved")


def main() raises:
    test_owned_fd_transfer_release()
    test_socket_admission_rejection()
    test_socketpair_request_transport()
