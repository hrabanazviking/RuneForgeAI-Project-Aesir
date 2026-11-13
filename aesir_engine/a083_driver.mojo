"""A-083 standalone driver: run only the A-083 E-MASTER cases."""
from tests.test_hip_q4k_gemv_a083 import (
    test_hip_q4k_gemv_oracle,
    test_hip_q4k_gemv_rejection,
    test_hip_q4k_gemv_no_leak,
)


def main() raises:
    test_hip_q4k_gemv_oracle()
    print("A083_CASE oracle: PASS")
    test_hip_q4k_gemv_rejection()
    print("A083_CASE rejection: PASS")
    test_hip_q4k_gemv_no_leak()
    print("A083_CASE no_leak: PASS")
    print("A083_DRIVER: PASS")
