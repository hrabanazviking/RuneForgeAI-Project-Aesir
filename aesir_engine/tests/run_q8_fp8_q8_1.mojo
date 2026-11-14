# Standalone runner for the Q8/FP8 parity module (it has no main of
# its own; the full run_all matrix also invokes these cases).
from tests.test_q8_fp8_quantization import (
    test_fused_q8_0_parity,
    test_fused_q8_1_parity,
    test_fused_fp8_e4m3_parity,
    test_fused_fp8_e5m2_parity,
)


def main() raises:
    test_fused_q8_0_parity()
    test_fused_q8_1_parity()
    test_fused_fp8_e4m3_parity()
    test_fused_fp8_e5m2_parity()
    print("Q8/FP8 parity runner: ALL PASS")
