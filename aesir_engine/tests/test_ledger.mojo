# tests/test_ledger.mojo
# Counted result ledger for the Grand Proving master test runner.


struct TestLedger:
    """Owns master-suite pass, failure, skip, and ordered failure-detail state.
    """

    var passed: Int
    var failed: Int
    var skipped: Int
    var failure_details: List[String]

    def __init__(out self):
        self.passed = 0
        self.failed = 0
        self.skipped = 0
        self.failure_details = List[String]()

    def record_pass(mut self, name: String):
        self.passed += 1
        print("[CASE PASS]", name)

    def record_failure(mut self, name: String, message: String):
        self.failed += 1
        self.failure_details.append(name + " :: " + message)
        print("[CASE FAIL]", name, "::", message)

    def record_skip(mut self, name: String, reason: String):
        self.skipped += 1
        print("[CASE SKIP]", name, "::", reason)

    def total(self) -> Int:
        return self.passed + self.failed + self.skipped

    def finish(self, expected_total: Int) raises:
        print("")
        print("==============================================")
        print("  Grand Proving Counted Summary")
        print("==============================================")

        if self.failed > 0:
            print("Failure details:")
            for i in range(len(self.failure_details)):
                print(" -", self.failure_details[i])

        print("[SUMMARY] Passed:", self.passed)
        print("[SUMMARY] Failed:", self.failed)
        print("[SUMMARY] Skipped:", self.skipped)
        print("[SUMMARY] Total:", self.total())

        if self.total() != expected_total:
            print("[SUMMARY] Status: FAIL")
            raise Error("Grand Proving counted an unexpected number of cases")

        if self.failed > 0:
            print("[SUMMARY] Status: FAIL")
            raise Error("Grand Proving recorded one or more failed cases")

        print("[SUMMARY] Status: PASS")
        print("Scaffold checks are not external capability proof.")
        print("==============================================")


def run_case(
    mut ledger: TestLedger,
    name: String,
    test: def() thin raises,
):
    """Run one named case, recording exactly one pass or failure outcome."""
    try:
        test()
    except error:
        ledger.record_failure(name, String(error))
    else:
        ledger.record_pass(name)


def record_skip(mut ledger: TestLedger, name: String, reason: String):
    """Record one intentionally unexecuted case as skipped, never passed."""
    ledger.record_skip(name, reason)
