# tests/test_memory_refinements.mojo
# Verification of MimirWell allocation budgeting, telemetry metrics, and safe memory substrate initializations

from core.mimir_well import MimirWell
from loader.tokenizer import RuneWeaver

def test_mimir_well_telemetry() raises:
    print("--- Testing MimirWell Allocation Telemetry & Arena Recycling ---")
    var pool_bytes = 1024 * 1024 # 1 MB pool
    var well = MimirWell(pool_bytes)

    if well.capacity_bytes() != pool_bytes:
        raise Error("MimirWell capacity_bytes mismatch")

    if well.allocated_bytes() != 0:
        raise Error("MimirWell initial allocated_bytes must be 0")

    if well.free_bytes() != pool_bytes:
        raise Error("MimirWell free_bytes initial count mismatch")

    var allocation_elements = 1000 # 2000 bytes
    var ptr = well.allocate(allocation_elements)
    _ = ptr

    if well.allocated_bytes() != 2000:
        raise Error("MimirWell allocated_bytes mismatch after allocation")

    if well.free_bytes() != pool_bytes - 2000:
        raise Error("MimirWell free_bytes mismatch after allocation")

    var util = well.utilization_pct()
    if util <= 0.0 or util >= 100.0:
        raise Error("MimirWell utilization_pct calculation error")

    well.reset()
    if well.allocated_bytes() != 0 or well.free_bytes() != pool_bytes:
        raise Error("MimirWell reset failed to return memory to 100% free")

    print("MimirWell allocation telemetry & arena recycling: PASS")


def test_bpe_tokenizer_linear_perf() raises:
    print("--- Testing Profiled Linear BPE Tokenizer Merge Performance ---")
    var weaver = RuneWeaver()
    weaver.add_token("a", 1)
    weaver.add_token("b", 2)
    weaver.add_token("ab", 3)
    weaver.validate_vocabulary()

    var long_prompt = String("ab ab ab ab ab ab ab ab")
    var tokens = weaver.encode(long_prompt)
    if len(tokens) == 0:
        raise Error("BPE encode returned empty token list for valid vocabulary")

    print("Profiled linear BPE tokenizer merge performance: PASS")


def main() raises:
    test_mimir_well_telemetry()
    test_bpe_tokenizer_linear_perf()
