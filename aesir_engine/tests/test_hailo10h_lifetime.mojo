"""Hardware check: a Mojo exception must release its native Hailo session."""
from std.ffi import external_call
from std.sys import argv
from hailo10h_direct import Hailo10HSession


def _request_failure(path: String, mut observed_handle: UInt64) raises:
    var session = Hailo10HSession(path)
    observed_handle = session.handle
    # A known-invalid request exercises unwinding after model acquisition,
    # without executing any LLM computation.
    _ = session.generate("cleanup boundary", 0)


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("provide the explicit Hailo model artifact path")
    var observed: UInt64 = 0
    var rejected = False
    try:
        _request_failure(args[1], observed)
    except:
        rejected = True
    if not rejected or observed == 0:
        raise Error("the session was not opened before the request rejection")
    var output = List[Int8]()
    output.resize(8192, 0)
    var error = List[Int8]()
    error.resize(2048, 0)
    var status = external_call["aesir_hailo10h_describe", Int32](
        observed, output.unsafe_ptr(), UInt(8192), error.unsafe_ptr(), UInt(2048)
    )
    if status == 0:
        raise Error("the native session survived Mojo exception unwinding")
    if external_call["aesir_hailo10h_close", Int32](observed) != 0:
        raise Error("repeat close was not idempotent")
    print("Mojo exception cleanup and repeat close verified")
