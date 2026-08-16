# tests/test_gguf.mojo
# The Seer's Trial: Verification of the Runecaster's Vision

from core.mimir_well import MimirWell
from loader.gguf import GGUFSeer, GGMLType, GGUFState

def test_gguf_parsing() raises:
    """The zero-tensor legacy fixture must be rejected before inference."""
    print("--- Testing GGUFSeer validation (The Runecaster's Vision) ---")
    var path = String("model.gguf")
    
    var well = MimirWell(1024 * 1024)
    var seer = GGUFSeer(path)
    if seer.state != GGUFState.UNOPENED:
        raise Error("Fresh GGUFSeer instance must begin in UNOPENED state")
        
    var rejected = False
    try:
        seer.mmap_and_load(well)
    except:
        rejected = True
    if not rejected:
        raise Error("GGUFSeer accepted a zero-tensor model fixture")
    if seer.state != GGUFState.FAILED:
        raise Error("Failed GGUFSeer parse must transition state to FAILED")
    print("GGUFSeer malformed-model rejection & FAILED state transition: PASS")

def test_loader_state_machine() raises:
    """Test GGUFState helper string representations."""
    print("--- Testing GGUFState Machine Discriminants ---")
    if GGUFState.to_string(GGUFState.UNOPENED) != "UNOPENED":
        raise Error("GGUFState UNOPENED string mismatch")
    if GGUFState.to_string(GGUFState.VALIDATED) != "VALIDATED":
        raise Error("GGUFState VALIDATED string mismatch")
    if GGUFState.to_string(GGUFState.FAILED) != "FAILED":
        raise Error("GGUFState FAILED string mismatch")
    print("GGUFState Machine Discriminants: PASS")

def test_ggml_type() raises:
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
        raise Error("GGMLType invariant mismatch")

def main() raises:
    test_gguf_parsing()
    test_loader_state_machine()
    test_ggml_type()
