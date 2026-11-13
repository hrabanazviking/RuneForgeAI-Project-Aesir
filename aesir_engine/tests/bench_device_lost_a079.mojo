"""A-079 harness: device-lost scenarios under an EXTERNAL
watchdog. Run by hidden_files/run_a079_harness.sh under
`timeout 60`: if any scenario hung, the timeout kills the
process and the harness log shows a non-zero exit - the
no-hang evidence is the completed log with HARNESS_EXIT=0,
not this program's own claim. Each scenario prints one line
with outcome, iterations vs budget, and the byte-for-byte
verdicts read off the coordinator report.
"""
from core.device_lost import (
    DeviceLostRecovery,
    RecoveryConfig,
    outcome_name,
)


def _prompt() -> List[Int]:
    var p = List[Int]()
    p.append(11)
    p.append(4)
    p.append(23)
    p.append(7)
    return p^


def _loss(step: Int) -> List[Int]:
    var l = List[Int]()
    l.append(step)
    return l^


def _scenario(
    name: String, failover: Bool, budget: Int, steps: Int,
    loss: List[Int],
):
    var rec = DeviceLostRecovery(RecoveryConfig(failover, 64, 4, budget, False))
    var r = rec.run(5, _prompt(), steps, loss)
    print(
        String("SCENARIO ") + name
        + String(" outcome=") + outcome_name(r.outcome)
        + String(" losses=") + String(r.losses)
        + String(" discarded=") + String(r.discarded)
        + String(" committed=") + String(r.committed_count)
        + String(" iterations=") + String(r.iterations)
        + String("/") + String(r.budget)
        + String(" state_intact=") + String(r.state_intact)
        + String(" control_match=") + String(r.control_match)
        + String(" final_bytes=") + String(len(r.final_state))
        + String(" error=") + r.error
    )


def main() raises:
    print("A-079 device-lost harness (watchdog: external timeout 60)")
    _scenario("control_no_loss", True, 1000, 32, List[Int]())
    _scenario("failover_step0", True, 1000, 32, _loss(0))
    _scenario("failover_midrun", True, 1000, 32, _loss(16))
    _scenario("failover_last_step", True, 1000, 32, _loss(31))
    _scenario("fail_closed_midrun", False, 1000, 32, _loss(16))
    var storm = List[Int]()
    for s in range(32):
        storm.append(s)
    _scenario("loss_storm_failover", True, 1000, 32, storm^)
    _scenario("watchdog_budget", True, 8, 32, List[Int]())
    print("HARNESS_COMPLETE")
