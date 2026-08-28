# tests/test_gguf_fuzzing.mojo
# GGUF Binary Parser Security Fuzzing Harness & Boundary Validation

from loader.gguf import GGUFSeer
from core.mimir_well import MimirWell

def test_corrupt_gguf_header_rejection() raises:
    print("--- Testing GGUF binary parser fuzzing harness ---")
    var well = MimirWell(1024 * 1024)

    # 1. Invalid Magic Byte Stream
    var invalid_magic_bytes = InlineArray[UInt8, 24](fill=0)
    invalid_magic_bytes[0] = 0x42 # 'B'
    invalid_magic_bytes[1] = 0x41 # 'A'
    invalid_magic_bytes[2] = 0x44 # 'D'
    invalid_magic_bytes[3] = 0x21 # '!'

    var seer1 = GGUFSeer(String("fuzz.gguf"))
    var rej1 = False
    try:
        seer1.parse_header_bytes(invalid_magic_bytes.unsafe_ptr(), 24, well)
    except:
        rej1 = True
    if not rej1:
        raise Error("test_corrupt_gguf_header_rejection: failed to reject invalid GGUF magic bytes")

    # 2. Zero-length Buffer Stream
    var seer2 = GGUFSeer(String("fuzz.gguf"))
    var rej2 = False
    try:
        seer2.parse_header_bytes(invalid_magic_bytes.unsafe_ptr(), 0, well)
    except:
        rej2 = True
    if not rej2:
        raise Error("test_corrupt_gguf_header_rejection: failed to reject zero-length GGUF byte buffer")

    print("GGUF binary parser fuzzing harness: PASS")

def main() raises:
    print("=== Testing GGUF Fuzzing & Security Boundary Harness ===")
    test_corrupt_gguf_header_rejection()
    print("=== GGUF FUZZING SUITE CLEAN PASS ===")
