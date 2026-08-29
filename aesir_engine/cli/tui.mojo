# cli/tui.mojo
# Caller-populated terminal status frame for Project A.E.S.I.R.

struct AesirTUIDashboard:
    """
    AesirTUIDashboard renders caller-supplied status values. It does not collect
    live CPU, device-memory, throughput, or session telemetry.
    """
    var model_name: String
    var active_backend: String
    var memory_used_mb: Float64
    var token_speed_tps: Float64
    var active_sessions: Int

    def __init__(out self):
        self.model_name = String("None")
        self.active_backend = String("CPU")
        self.memory_used_mb = 0.0
        self.token_speed_tps = 0.0
        self.active_sessions = 0

    def render_frame(self) -> String:
        """Renders an ASCII frame from explicitly supplied values."""
        var frame = String("┌──────────────────────────────────────────────────────────────────────────────┐\n")
        frame += "│                   PROJECT A.E.S.I.R. STATUS FRAME                            │\n"
        frame += "├──────────────────────────────────────────────────────────────────────────────┤\n"
        frame += "│ Active Model:     " + self.model_name + "\n"
        frame += "│ Reported Backend: " + self.active_backend + "\n"
        frame += "│ Active Sessions:  " + String(self.active_sessions) + "\n"
        frame += "│ Reported Memory:  " + String(self.memory_used_mb) + " MB\n"
        frame += "│ Reported Speed:   " + String(self.token_speed_tps) + " tokens/sec\n"
        frame += "└──────────────────────────────────────────────────────────────────────────────┘\n"
        return frame
