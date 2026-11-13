# spikes/a100_planner/rerun_state_vault.mojo
# A-100 gate: solo re-run of the named intermittent
# resilience.state_vault_rejects_growth, which fired once
# in the full suite (pre-existing intermittent class).

from tests.test_resilience import test_state_vault_rejects_growth


def main():
    try:
        test_state_vault_rejects_growth()
        print("RERUN_PASS resilience.state_vault_rejects_growth")
    except e:
        print("RERUN_FAIL resilience.state_vault_rejects_growth: " + String(e))
