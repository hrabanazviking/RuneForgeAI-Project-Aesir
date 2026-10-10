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
        try:
            raw_seer.parse_header_bytes(raw.unsafe_ptr(), len(raw), well)
        except:
            raw_accepted = False
        if not raw_accepted:
            raise Error("raw-byte helper unexpectedly rejected a version in baseline slice")

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
    print("PASS: GGUF version interface exposes raw/file admission mismatch")


def main() raises:
    test_gguf_version_interface()
