# Direct byte/value guards and lifetimes. No model/transport execution.
from smidr.program_payload import ProgramPayloadRequest, ProgramPayloadSnapshot, stage_program_payload, validate_program_payload, program_payload_window
from smidr.program_envelope import build_program_envelope
from smidr.tools.hrpc_frame import _to_hex


def _program() raises -> List[UInt8]:
    var pb: List[UInt8] = [1, 2, 3]
    var ccw: List[UInt8] = [4, 5, 6, 7]
    var info: List[UInt8] = [8, 9]
    return build_program_envelope(pb, ccw, info, 5, False, 75)


def _request() -> ProgramPayloadRequest:
    return ProgramPayloadRequest(17, 0, "synthetic", 4096)


def _equal(a: List[UInt8], b: List[UInt8]) raises:
    if len(a) != len(b):
        raise Error("payload ownership extent changed")
    for i in range(len(a)):
        if a[i] != b[i]:
            raise Error("payload ownership bytes changed")


def _reject(snapshot: ProgramPayloadSnapshot, expected: ProgramPayloadRequest) raises:
    var accepted = False
    try:
        _ = program_payload_window(snapshot, expected, 1, 0, 0, 0)
        accepted = True
    except:
        pass
    if accepted:
        raise Error("invalid mutable payload snapshot consumed")
    var fresh = stage_program_payload(_program(), _request())
    _equal(program_payload_window(fresh, _request(), 1, 0, len(fresh.program), 75), fresh.program)


def _escaping_window() raises -> List[UInt8]:
    var snapshot = stage_program_payload(_program(), _request())
    return program_payload_window(snapshot, _request(), 1, 0, len(snapshot.program), 75)


def main() raises:
    var program = _program()
    var saved = program.copy()
    var request = _request()
    var expected = request.copy()
    var snapshot = stage_program_payload(program, request)
    var metadata = snapshot.metadata.copy()
    for i in range(len(program)):
        program[i] = 0
    request.name = "changed"
    request.host_program_bound = 0
    _equal(snapshot.program, saved)
    validate_program_payload(snapshot, expected)
    var window = program_payload_window(snapshot, expected, 1, 0, len(saved), len(saved))
    for i in range(len(window)):
        window[i] = 0
    _equal(snapshot.program, saved)
    _equal(_escaping_window(), saved)
    var moved = snapshot^
    _equal(program_payload_window(moved, expected, 0, 0, len(metadata), len(metadata)), metadata)
    var refusals = 0
    for i in range(len(metadata)):
        moved.metadata[i] ^= 1
        _reject(moved, expected)
        moved.metadata[i] ^= 1
        refusals += 1
    for i in range(56, len(saved)):
        moved.program[i] ^= 1
        _reject(moved, expected)
        moved.program[i] ^= 1
        refusals += 1
    for field in range(4):
        var other = expected.copy()
        if field == 0:
            other.message_id += 1
        elif field == 1:
            other.vdevice_handle += 1
        elif field == 2:
            other.name = "different"
        else:
            other.host_program_bound += 1
        _reject(moved, other)
        var retained = moved.request.copy()
        moved.request = other.copy()
        _reject(moved, expected)
        moved.request = retained^
        refusals += 2
    moved.metadata.append(0)
    _reject(moved, expected)
    _ = moved.metadata.pop()
    moved.program.append(0)
    _reject(moved, expected)
    _ = moved.program.pop()
    refusals += 2
    # Valid new content with a fresh checksum is new wire intent, not an
    # immutable/executable identity proof. Preserve and test this limitation.
    var pb: List[UInt8] = [1, 2, 3]
    var ccw: List[UInt8] = [4, 5, 6, 99]
    var info: List[UInt8] = [8, 9]
    moved.program = build_program_envelope(pb, ccw, info, 5, False, 75)
    validate_program_payload(moved, expected)
    if moved.program[67] != 99:
        raise Error("rehashed new wire intent was not preserved")
    _equal(moved.metadata, metadata)
    var nul_request = _request()
    nul_request.name = "a\x00b"
    var nul_snapshot = stage_program_payload(_program(), nul_request)
    print("nul_metadata_hex=" + _to_hex(nul_snapshot.metadata))
    print("owned-program-payload-pass;" + String(refusals) + "-refusal-and-fresh-success-cycles;rehashed-replacement-is-new-wire-intent")
