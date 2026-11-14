# A-113 solo re-run driver: resilience.state_vault_rejects_growth
# (named pre-existing intermittent; timing-race TOCTOU test).
from tests.test_resilience import test_state_vault_rejects_growth


def main() raises:
    test_state_vault_rejects_growth()
    print("SOLO_RESULT: resilience.state_vault_rejects_growth PASS")
