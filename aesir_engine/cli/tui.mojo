# cli/tui.mojo
# Terminal User Interface Dashboard for Project A.E.S.I.R.

struct AesirTUIDashboard:
    """
    AesirTUIDashboard — Terminal telemetry display for live engine metrics.
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
        """Renders ASCII terminal telemetry dashboard frame."""
        var frame = String("┌──────────────────────────────────────────────────────────────────────────────┐\n")
        frame += "│                 🛡️ PROJECT A.E.S.I.R. TELEMETRY DASHBOARD 🛡️                 │\n"
        frame += "├──────────────────────────────────────────────────────────────────────────────┤\n"
        frame += "│ Active Model:     " + self.model_name + "\n"
        frame += "│ Hardware Realm:   " + self.active_backend + "\n"
        frame += "│ Active Sessions:  " + String(self.active_sessions) + "\n"
        frame += "│ Memory Residency: " + String(self.memory_used_mb) + " MB\n"
        frame += "│ Throughput Speed: " + String(self.token_speed_tps) + " tokens/sec\n"
        frame += "└──────────────────────────────────────────────────────────────────────────────┘\n"
        return frame
