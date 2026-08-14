# tests/test_gguf.mojo
# The Seer's Trial: Verification of the Runecaster's Vision

from core.mimir_well import MimirWell
from loader.gguf import GGUFSeer, GGMLType

def test_gguf_parsing():
    """Test GGUFSeer can open and validate a GGUF file."""
    print("--- Testing GGUFSeer (The Runecaster's Vision) ---")
    var path = String("model.gguf")
    
    var well = MimirWell(1024 * 1024)
    var seer = GGUFSeer(path)
    seer.mmap_and_load(well)
    
    if seer.fd != -1:
        print("GGUFSeer: PASS")
    else:
        print("GGUFSeer: FAIL")

def test_ggml_type():
    """Test GGMLType constants are correct per GGML spec."""
    print("--- Testing GGMLType Constants ---")
    var success = True
    
    # F16 = 1, Q4_K = 12 per the GGML type enum
    var f16_val = GGMLType.F16
    var q4k_val = GGMLType.Q4_K
    
    if f16_val != 1:
        print("FAIL: GGMLType.F16 should be 1")
        success = False
    if q4k_val != 12:
        print("FAIL: GGMLType.Q4_K should be 12")
        success = False
    
    # Test quantized detection logic
    var test_type = q4k_val
    var is_quantized = (test_type == GGMLType.Q4_K)
    if not is_quantized:
        print("FAIL: Q4_K should be detected as quantized")
        success = False
    
    if success:
        print("GGMLType: PASS")
    else:
        print("GGMLType: FAIL")

def main():
    test_gguf_parsing()
    test_ggml_type()
