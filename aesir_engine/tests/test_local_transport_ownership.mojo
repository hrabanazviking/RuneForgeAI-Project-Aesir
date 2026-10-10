"""Descriptor ownership transfer and idempotent moved-from cleanup checks."""
from std.collections import InlineArray
from std.ffi import external_call
from server.local_transport import OwnedFD, listen_local


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


def main() raises:
    test_owned_fd_transfer_release()
    test_socket_admission_rejection()
