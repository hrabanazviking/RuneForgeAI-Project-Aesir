# tests/test_exl2.mojo
# Verification of EXL2 variable-bit sub-block parser & CUDA contract validator

from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from core.mimir_well import MimirWell
from loader.exl2 import EXL2ModelSeer, validate_exl2_format_contract

def test_exl2_cuda_contract_validation() raises:
    print("--- Testing unavailable EXL2 execution contract ---")
    for bypass in [False, True]:
        var rejected = False
        try:
            validate_exl2_format_contract(bypass)
        except error:
            rejected = "not implemented" in String(error)
        if not rejected:
            raise Error("EXL2 contract allowed an execution-evidence bypass")
    print("unavailable EXL2 execution contract: PASS")


def test_exl2_model_seer() raises:
    print("--- Testing honest EXL2 descriptor boundary ---")
    var seer = EXL2ModelSeer("models/test.exl2")
    if seer.avg_bitrate != 0.0 or seer.total_weights != 0:
        raise Error("EXL2 descriptor invented model metadata at construction")
    var bytes_ptr = alloc(Layout[Scalar[DType.uint8]](count=16)).unsafe_leak()
    bytes_ptr.unsafe_store(0, 0x45) # 'E'
    bytes_ptr.unsafe_store(1, 0x58) # 'X'
    bytes_ptr.unsafe_store(2, 0x4C) # 'L'
    bytes_ptr.unsafe_store(3, 0x32) # '2'

    var rejected = False
    try:
        _ = seer.parse_exl2_header_bytes(bytes_ptr, 16)
    except error:
        rejected = "not implemented" in String(error)
    if not rejected:
        raise Error("EXL2ModelSeer accepted an invented EXL2 magic header")

    seer.add_sub_block(3.5, 256)
    seer.add_sub_block(4.25, 256)
    seer.add_sub_block(6.0, 256)

    if len(seer.sub_blocks) != 3:
        raise Error("EXL2ModelSeer sub-block count mismatch")
    if seer.total_weights != 768:
        raise Error("EXL2ModelSeer total_weights mismatch")
    if seer.avg_bitrate != Float32((3.5 + 4.25 + 6.0) / 3.0):
        raise Error("EXL2ModelSeer weighted average bitrate mismatch")

    rejected = False
    try:
        seer.add_sub_block(9.0, 256)
    except:
        rejected = True
    if not rejected or len(seer.sub_blocks) != 3:
        raise Error("EXL2 descriptor accepted invalid caller metadata")
    var well = MimirWell(1024)
    rejected = False
    try:
        _ = seer.map_to_well(well)
    except error:
        rejected = "not implemented" in String(error)
    if not rejected:
        raise Error("EXL2 descriptor reported tensor mapping success")

    bytes_ptr.unsafe_free()
    print("honest EXL2 descriptor boundary: PASS")


def main() raises:
    test_exl2_cuda_contract_validation()
    test_exl2_model_seer()
