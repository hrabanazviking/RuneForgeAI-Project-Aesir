# tests/test_exl2.mojo
# Verification of EXL2 variable-bit sub-block parser & CUDA contract validator

from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from loader.exl2 import EXL2ModelSeer, validate_exl2_format_contract

def test_exl2_cuda_contract_validation() raises:
    print("--- Testing EXL2 CUDA Execution Contract Validation ---")
    
    # Assert missing physical CUDA evidence raises explicit Error
    var rejected = False
    try:
        validate_exl2_format_contract(True)
    except:
        rejected = True
    if not rejected:
        raise Error("validate_exl2_format_contract failed to reject execution without CUDA hardware")

    print("EXL2 CUDA contract validation: PASS")


def test_exl2_model_seer() raises:
    print("--- Testing EXL2ModelSeer Variable-Bit Parser ---")
    var seer = EXL2ModelSeer("models/test.exl2")
    
    var bytes_ptr = alloc(Layout[Scalar[DType.uint8]](count=16)).unsafe_leak()
    bytes_ptr.unsafe_store(0, 0x45) # 'E'
    bytes_ptr.unsafe_store(1, 0x58) # 'X'
    bytes_ptr.unsafe_store(2, 0x4C) # 'L'
    bytes_ptr.unsafe_store(3, 0x32) # '2'

    var ok = seer.parse_exl2_header_bytes(bytes_ptr, 16)
    if not ok:
        raise Error("EXL2ModelSeer failed to parse header bytes")

    seer.add_sub_block(3.5, 256)
    seer.add_sub_block(4.25, 256)
    seer.add_sub_block(6.0, 256)

    if len(seer.sub_blocks) != 3:
        raise Error("EXL2ModelSeer sub-block count mismatch")
    if seer.total_weights != 768:
        raise Error("EXL2ModelSeer total_weights mismatch")

    bytes_ptr.unsafe_free()
    print("EXL2ModelSeer variable-bit parser: PASS")


def main() raises:
    test_exl2_cuda_contract_validation()
    test_exl2_model_seer()
