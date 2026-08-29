# core/smart_crash.mojo
# Local crash-counter and diagnostic formatter for Project A.E.S.I.R.

struct SmartCrashReporter:
    """
    SmartCrashReporter records caller-supplied error text, advances a local
    retry counter, and formats static diagnostic suggestions. It does not
    intercept process crashes, restart the engine, switch backends, or call AI.
    """
    var consecutive_crashes: Int
    var max_retries: Int
    var failsafe_mode_active: Bool
    var last_error_message: String

    def __init__(out self):
        self.consecutive_crashes = 0
        self.max_retries = 3
        self.failsafe_mode_active = False
        self.last_error_message = String("")

    def handle_crash(mut self, error_msg: String, subsystem: String) -> String:
        """
        Records an observed error and formats a local heuristic report.
        """
        self.consecutive_crashes += 1
        self.last_error_message = error_msg

        var report = String("═══════════════════════════════════════════════════════════════════════════════\n")
        report += "  REPORTED ERROR DIAGNOSTIC (NO PROCESS INTERCEPTION)\n"
        report += "═══════════════════════════════════════════════════════════════════════════════\n"
        report += "Subsystem:           " + subsystem + "\n"
        report += "Error Message:       " + error_msg + "\n"
        report += "Consecutive Crashes: " + String(self.consecutive_crashes) + " / " + String(self.max_retries) + "\n\n"

        if self.consecutive_crashes >= self.max_retries:
            self.failsafe_mode_active = True
            report += "⚠️ FAILSAFE REQUESTED: Maximum retries reached. The caller must stop or select a verified backend; no automatic switch occurred.\n\n"

        report += "STATIC HARDENING HEURISTIC (NO AI CALL):\n"
        if "out of memory" in error_msg.lower() or "vram" in error_msg.lower():
            report += "  - Suggestion: Increase KV Cache pool allocation in MimirWell or reduce num_gpu_layers.\n"
        elif "null pointer" in error_msg.lower() or "exhausted" in error_msg.lower():
            report += "  - Suggestion: Check memory pool bounds in mimir_well.mojo allocate_checked().\n"
        else:
            report += "  - Suggestion: Wrap kernel invocation in error_guard.mojo with bounds validation.\n"

        report += "═══════════════════════════════════════════════════════════════════════════════\n"
        return report

    def reset(mut self):
        """Resets crash counters upon successful execution."""
        self.consecutive_crashes = 0
        self.failsafe_mode_active = False
        self.last_error_message = String("")
