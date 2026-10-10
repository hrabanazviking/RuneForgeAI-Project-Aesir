"""Current admission matrix across GGUF mapped-file and raw-byte paths."""

from std.ffi import external_call
from loader.gguf import GGUFSeer
from loader.tokenizer import RuneWeaver
from core.mimir_well import MimirWell


def make_header(version: UInt32) -> List[UInt8]:
    var bytes = List[UInt8]()
    bytes.append(0x47)
    bytes.append(0x47)
    bytes.append(0x55)
    bytes.append(0x46)
    bytes.append(UInt8(version & 0xff))
    bytes.append(UInt8((version >> 8) & 0xff))
    bytes.append(UInt8((version >> 16) & 0xff))
    bytes.append(UInt8((version >> 24) & 0xff))
    for _ in range(16):
        bytes.append(0)
    return bytes^ 


def write_header(version: UInt32) raises -> String:
    var template = List[Int8]()
    for byte in String("/tmp/aesir-gguf-version-XXXXXX").as_bytes():
        template.append(Int8(byte))
    template.append(0)
    var fd = external_call["mkstemp", Int32](template.unsafe_ptr())
    if fd < 0:
        raise Error("failed to create GGUF version fixture")
    var bytes = make_header(version)
    var offset = 0
    while offset < len(bytes):
        var wrote = external_call["write", Int](Int(fd), bytes.unsafe_ptr().unsafe_offset(offset), len(bytes) - offset)
        if wrote <= 0:
            _ = external_call["close", Int32](fd)
            raise Error("failed to write GGUF version fixture")
        offset += wrote
    if external_call["close", Int32](fd) != 0:
        raise Error("failed to close GGUF version fixture")
    return String(unsafe_from_utf8_ptr=template.unsafe_ptr())


def unlink_path(path: String):
    var bytes = List[Int8]()
    for byte in path.as_bytes():
        bytes.append(Int8(byte))
    bytes.append(0)
    _ = external_call["unlink", Int32](bytes.unsafe_ptr())


def test_gguf_version_interface() raises:
    var well = MimirWell(1024)
    var versions = List[UInt32]()
    versions.append(0)
    versions.append(2)
    versions.append(3)
    versions.append(4)
    versions.append(UInt32(4294967295))
    for version in versions:
        var raw = make_header(version)
        var raw_seer = GGUFSeer("raw-version-probe.gguf")
        var raw_accepted = True
        var raw_error = String("")
        try:
            raw_seer.parse_header_bytes(raw.unsafe_ptr(), len(raw), well)
        except error:
            raw_accepted = False
            raw_error = String(error)
        if version == 3:
            if not raw_accepted:
                raise Error("raw-byte helper rejected supported version 3")
        elif raw_accepted or "Only GGUF version 3" not in raw_error:
            raise Error("raw-byte helper did not enforce the mapped-path version gate")

        var path = write_header(version)
        var file_seer = GGUFSeer(path)
        var tokenizer = RuneWeaver()
        var file_error = String("")
        try:
            file_seer.inspect_metadata(tokenizer)
        except error:
            file_error = String(error)
        unlink_path(path)
        if version == 3:
            if "Only GGUF version 3" in file_error:
                raise Error("mapped file rejected supported version 3")
        elif "Only GGUF version 3" not in file_error:
            raise Error("mapped file did not reject unsupported GGUF version")
    print("PASS: GGUF version 3 admission is consistent across file and byte paths")


def test_gguf_version_reference() raises:
    var well = MimirWell(1024)
    var valid = make_header(3)
    var seer = GGUFSeer("unit-version-probe.gguf")
    seer.parse_header_bytes(valid.unsafe_ptr(), 24, well)
    if valid[4] != 3 or valid[5] != 0 or valid[6] != 0 or valid[7] != 0:
        raise Error("GGUF version-3 little-endian fixture bytes changed")

    var short = GGUFSeer("short-version-probe.gguf")
    var short_rejected = False
    try:
        short.parse_header_bytes(valid.unsafe_ptr(), 23, well)
    except error:
        short_rejected = "at least 24 bytes" in String(error)
    if not short_rejected:
        raise Error("GGUF header helper admitted a 23-byte buffer")

    var bad_magic = make_header(3)
    bad_magic[0] = 0
    var magic_seer = GGUFSeer("bad-magic-version-probe.gguf")
    var magic_rejected = False
    try:
        magic_seer.parse_header_bytes(bad_magic.unsafe_ptr(), 24, well)
    except error:
        magic_rejected = "magic bytes are invalid" in String(error)
    if not magic_rejected or bad_magic[0] != 0:
        raise Error("GGUF invalid-magic rejection changed input or used wrong error")

    var unsupported = make_header(4)
    var version_seer = GGUFSeer("unsupported-version-probe.gguf")
    var version_rejected = False
    try:
        version_seer.parse_header_bytes(unsupported.unsafe_ptr(), 24, well)
    except error:
        version_rejected = "Only GGUF version 3" in String(error)
    if not version_rejected or unsupported[4] != 4:
        raise Error("GGUF unsupported-version rejection changed bytes or error")
    print("PASS: GGUF version header byte-length, endian, magic, and boundary cases")


def test_gguf_version_integration() raises:
    var v3_path = write_header(3)
    var v3 = GGUFSeer(v3_path)
    var tokenizer = RuneWeaver()
    var v3_error = String("")
    try:
        v3.inspect_metadata(tokenizer)
    except error:
        v3_error = String(error)
    unlink_path(v3_path)
    if v3.version != 3 or "Only GGUF version 3" in v3_error:
        raise Error("v3 mapped header did not pass the version gate")
    if v3.state != 4 or v3.is_mapped:
        raise Error("v3 incomplete fixture did not fail and clean up later-stage state")

    var v4_path = write_header(4)
    var v4 = GGUFSeer(v4_path)
    var v4_tokenizer = RuneWeaver()
    var v4_error = String("")
    try:
        v4.inspect_metadata(v4_tokenizer)
    except error:
        v4_error = String(error)
    unlink_path(v4_path)
    if "Only GGUF version 3" not in v4_error:
        raise Error("v4 mapped header did not stop at the version gate")
    if v4.version != 4 or v4.state != 4 or v4.is_mapped:
        raise Error("v4 version rejection did not preserve state/cleanup invariants")
    print("PASS: GGUF version gate integrates with loader state and mmap cleanup")


def main() raises:
    test_gguf_version_interface()
    test_gguf_version_reference()
    test_gguf_version_integration()
