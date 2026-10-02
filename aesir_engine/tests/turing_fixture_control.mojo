"""Pure cooperative control/abort policy for the optional matrix fixture."""
from core.generation_control import GenerationControl


struct FixtureControl:
    var generation: GenerationControl
    var started: Bool
    var reset_required: Bool
    var reason: String
    var completed_layers: Int

    def __init__(out self) raises:
        self.generation = GenerationControl()
        self.started = False
        self.reset_required = False
        self.reason = ""
        self.completed_layers = 0

    def enabled(self) -> Bool:
        return self.generation.timeout_ms != 0 or self.generation.cancel_fd >= 0

    def configure(mut self,timeout_ms: Int,cancel_fd: Int) raises:
        if self.reset_required: raise Error("Interrupted fixture requires explicit reset")
        var policy = GenerationControl(timeout_ms,cancel_fd)
        self.generation = policy
        self.started = False
        self.completed_layers = 0
        self.reason = ""

    def start(mut self) raises:
        if self.reset_required: raise Error("Interrupted fixture requires explicit reset")
        self.started = False
        self.generation.start()
        self.started = True
        self.completed_layers = 0
        self.reason = ""

    def admit(self) raises:
        if self.reset_required: raise Error("Interrupted fixture requires explicit reset")
        if self.enabled() and not self.started:
            raise Error("Enabled fixture control requires explicit start")

    def stop_reason(self) raises -> String:
        self.admit()
        return self.generation.stop_reason() if self.enabled() else ""

    def aborted(mut self,reason: String) raises:
        if reason != "cancelled" and reason != "timeout" and reason != "control_error":
            raise Error("Unknown fixture control abort reason")
        self.reset_required = True
        self.started = False
        self.reason = reason

    def reset(mut self):
        self.generation.deadline_ms = 0
        self.started = False
        self.reset_required = False
        self.reason = ""
        self.completed_layers = 0
