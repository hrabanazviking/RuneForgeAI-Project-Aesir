from tests.test_equivalence_gate_a080 import (
    test_equivalence_classifier_table,
    test_equivalence_battery_aggregation,
    test_equivalence_regression_blocks,
    test_equivalence_gate_script_contract,
    test_equivalence_sampling_parity,
    test_equivalence_real_model_parity,
)


def main() raises:
    test_equivalence_classifier_table()
    test_equivalence_battery_aggregation()
    test_equivalence_regression_blocks()
    test_equivalence_gate_script_contract()
    test_equivalence_sampling_parity()
    test_equivalence_real_model_parity()
    print("A080_DRIVER_ALL_PASS")
