# core/smart_crash.mojo
# Validated caller-reported failure diagnostics. This module does not intercept
# crashes, restart processes, change backends, or generate AI recommendations.

struct SmartCrashReporter:
    """Bounded local counter and formatter for caller-reported failures."""

    var consecutive_failures: Int
    var failure_threshold: Int
    var threshold_reached: Bool
    var last_error_message: String
    var last_subsystem: String

    def __init__(out self, failure_threshold: Int = 3):
        self.consecutive_failures = 0
        self.failure_threshold = max(1, failure_threshold)
        self.threshold_reached = False
        self.last_error_message = String("")
        self.last_subsystem = String("")

    def record_failure(mut self, error_msg: String, subsystem: String) raises -> String:
        """Validates, records, classifies, and formats one observed failure."""
        if subsystem.byte_length() == 0 or subsystem.byte_length() > 64:
            raise Error("failure subsystem must be 1..64 bytes")
        if error_msg.byte_length() == 0 or error_msg.byte_length() > 4096:
            raise Error("failure message must be 1..4096 bytes")

        self.consecutive_failures += 1
        self.last_error_message = error_msg
        self.last_subsystem = subsystem
        self.threshold_reached = self.consecutive_failures >= self.failure_threshold

        var category = String("unclassified")
        var operator_check = String("inspect the originating subsystem and its validated inputs")
        var lowered = error_msg.lower()
        if "out of memory" in lowered or "vram" in lowered:
            category = "resource_exhaustion"
            operator_check = "inspect the measured memory budget and reduce admitted context or workload"
        elif "null pointer" in lowered or "sentinel" in lowered:
            category = "memory_safety"
            operator_check = "inspect pointer ownership, span, and allocation provenance"

        var report = String("AESIR CALLER-REPORTED FAILURE\n")
        report += "Subsystem: " + subsystem + "\n"
        report += "Message: " + error_msg + "\n"
        report += "Category: " + category + "\n"
        report += "Consecutive reports: " + String(self.consecutive_failures) + "\n"
        report += "Threshold reached: " + ("true" if self.threshold_reached else "false") + "\n"
        report += "Operator check: " + operator_check + "\n"
        report += "Recovery action: none performed\n"
        return report

    def handle_crash(mut self, error_msg: String, subsystem: String) raises -> String:
        """Compatibility name for record_failure(); no crash interception occurs."""
        return self.record_failure(error_msg, subsystem)

    def reset(mut self):
        """Clears the local observation counter and last report fields."""
        self.consecutive_failures = 0
        self.threshold_reached = False
        self.last_error_message = String("")
        self.last_subsystem = String("")
