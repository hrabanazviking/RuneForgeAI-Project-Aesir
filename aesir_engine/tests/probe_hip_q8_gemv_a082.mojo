from tests.test_hip_q8_gemv_a082 import (
    test_hip_q8_gemv_oracle_parity,
    test_hip_q8_gemv_known_value,
    test_hip_q8_gemv_engine_crosscheck,
    test_hip_q8_gemv_rejection,
    test_hip_q8_gemv_dispatch_evidence,
)

def main() raises:
    test_hip_q8_gemv_oracle_parity()
    test_hip_q8_gemv_known_value()
    test_hip_q8_gemv_engine_crosscheck()
    test_hip_q8_gemv_rejection()
    test_hip_q8_gemv_dispatch_evidence()
    print("A082_PROBE_ALL_PASS")
