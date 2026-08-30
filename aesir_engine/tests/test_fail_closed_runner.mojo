# tests/test_fail_closed_runner.mojo
# CI negative control: this program must terminate with a non-zero status.

from tests.test_ledger import TestLedger, run_case


def intentional_failure() raises:
    raise Error("intentional CI negative-control failure")


def main() raises:
    var ledger = TestLedger()
    run_case(ledger, "negative_control.intentional_failure", intentional_failure)
    ledger.finish(1)
