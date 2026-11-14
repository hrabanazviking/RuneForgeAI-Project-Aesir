from tests.test_hip_serve_admission import test_hip_config_gate
from tests.test_resilience import test_state_vault_rejects_growth

def main() raises:
    test_hip_config_gate()
    print("CASE hardware.hip_config_gate: PASS")
    test_state_vault_rejects_growth()
    print("CASE resilience.state_vault_rejects_growth: PASS")
