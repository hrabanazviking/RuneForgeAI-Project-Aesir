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


def test_request_transport_adversarial() raises:
    # Oversized head without a terminator must fail at the 8 KiB ceiling.
    var head_pair = InlineArray[Int32, 2](fill=-1)
    if external_call["socketpair", Int32](Int32(1), Int32(526337), Int32(0), head_pair.unsafe_ptr()) != 0:
        raise Error("Cannot create oversized-head fixture")
    var head_peer = OwnedFD(head_pair[0])
    var head_server = OwnedFD(head_pair[1])
    var oversized = String("")
    for _ in range(8192):
        oversized += "x"
    var oversized_bytes = oversized.as_bytes()
    if external_call["write", Int64](Int64(head_peer.fd), oversized_bytes.unsafe_ptr().unsafe_bitcast[Int8](), Int64(len(oversized_bytes))) != 8192:
        raise Error("Could not write oversized head fixture")
    var rejected_head = False
    try:
        _ = receive_head(head_server.fd, monotonic_milliseconds() + 1000, -1)
    except:
        rejected_head = True
    if not rejected_head:
        raise Error("Unterminated 8 KiB request head accepted")
    _ = head_server
    _ = head_peer

    # A short body must fail closed when its only peer closes.
    var short_pair = InlineArray[Int32, 2](fill=-1)
    if external_call["socketpair", Int32](Int32(1), Int32(526337), Int32(0), short_pair.unsafe_ptr()) != 0:
        raise Error("Cannot create short-body fixture")
    var short_peer = OwnedFD(short_pair[0])
    var short_server = OwnedFD(short_pair[1])
    var partial = String("{}")
    var partial_bytes = partial.as_bytes()
    if external_call["write", Int64](Int64(short_peer.fd), partial_bytes.unsafe_ptr().unsafe_bitcast[Int8](), Int64(2)) != 2:
        raise Error("Could not write short-body fixture")
    _ = short_peer
    var rejected_short = False
    try:
        _ = receive_body(short_server.fd, 4, monotonic_milliseconds() + 1000, -1)
    except:
        rejected_short = True
    if not rejected_short:
        raise Error("Short request body accepted")
    _ = short_server

    # NUL-containing request bytes are not admitted into Mojo strings.
    var nul_pair = InlineArray[Int32, 2](fill=-1)
    if external_call["socketpair", Int32](Int32(1), Int32(526337), Int32(0), nul_pair.unsafe_ptr()) != 0:
        raise Error("Cannot create NUL-body fixture")
    var nul_peer = OwnedFD(nul_pair[0])
    var nul_server = OwnedFD(nul_pair[1])
    var raw = InlineArray[Int8, 4](fill=0)
    raw[0] = 123
    raw[1] = 0
    raw[2] = 125
    raw[3] = 33
    if external_call["write", Int64](Int64(nul_peer.fd), raw.unsafe_ptr(), Int64(4)) != 4:
        raise Error("Could not write NUL-body fixture")
    var rejected_nul = False
    try:
        _ = receive_body(nul_server.fd, 4, monotonic_milliseconds() + 1000, -1)
    except:
        rejected_nul = True
    if not rejected_nul:
        raise Error("NUL-containing request body accepted")
    _ = nul_server
    _ = nul_peer

    var length_pair = InlineArray[Int32, 2](fill=-1)
    if external_call["socketpair", Int32](Int32(1), Int32(526337), Int32(0), length_pair.unsafe_ptr()) != 0:
        raise Error("Cannot create oversized-length fixture")
    var length_server = OwnedFD(length_pair[1])
    var rejected_length = False
    try:
        _ = receive_body(length_server.fd, 131073, monotonic_milliseconds() + 1000, -1)
    except:
        rejected_length = True
    if not rejected_length:
        raise Error("Oversized body length accepted")
    _ = length_server
    _ = external_call["close", Int32](length_pair[0])
    print("PASS request transport adversarial: header/body bounds, short EOF, NUL reject")


def main() raises:
    test_owned_fd_transfer_release()
    test_socket_admission_rejection()
    test_socketpair_request_transport()
    test_request_transport_adversarial()
