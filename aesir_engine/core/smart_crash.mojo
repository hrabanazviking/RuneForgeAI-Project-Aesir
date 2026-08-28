# core/smart_crash.mojo
# Smart Crashing & Self-Healing Crash Reporter for Project A.E.S.I.R.

struct SmartCrashReporter:
    """
    SmartCrashReporter — Intercepts execution crashes, generates detailed technical diagnostic logs,
    executes failsafe recovery loops, and provides AI-driven code hardening recommendations.
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
        Intercepts crash, increments crash counters, checks failsafe thresholds,
        and generates crash report output with code hardening suggestions.
        """
        self.consecutive_crashes += 1
        self.last_error_message = error_msg

        var report = String("═══════════════════════════════════════════════════════════════════════════════\n")
        report += "  🚨 SMART CRASH INTERCEPTOR & DIAGNOSTIC REPORT 🚨\n"
        report += "═══════════════════════════════════════════════════════════════════════════════\n"
        report += "Subsystem:           " + subsystem + "\n"
        report += "Error Message:       " + error_msg + "\n"
        report += "Consecutive Crashes: " + String(self.consecutive_crashes) + " / " + String(self.max_retries) + "\n\n"

        if self.consecutive_crashes >= self.max_retries:
            self.failsafe_mode_active = True
            report += "⚠️ FAILSAFE MODE ACTIVATED: Maximum retries reached. Switching hardware acceleration to CPU reference path.\n\n"

        report += "💡 AI CODE HARDENING RECOMMENDATION:\n"
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
