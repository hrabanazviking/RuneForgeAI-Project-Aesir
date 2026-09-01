# cli/tui.mojo
# Terminal User Interface Dashboard for Project A.E.S.I.R.

from std.math import isfinite

struct AesirTUIDashboard:
    """
    Validated formatter for an explicitly supplied runtime observation.

    This type does not inspect hardware or measure a running engine.  Callers
    must publish an observation before the frame can contain metric values.
    """
    var model_name: String
    var active_backend: String
    var memory_used_mb: Float64
    var token_speed_tps: Float64
    var active_sessions: Int
    var observation_source: String
    var observed_at_ms: Int
    var has_observation: Bool

    def __init__(out self):
        self.model_name = String("None")
        self.active_backend = String("unobserved")
        self.memory_used_mb = 0.0
        self.token_speed_tps = 0.0
        self.active_sessions = 0
        self.observation_source = String("")
        self.observed_at_ms = 0
        self.has_observation = False

    def update_observation(
        mut self,
        model_name: String,
        active_backend: String,
        memory_used_mb: Float64,
        token_speed_tps: Float64,
        active_sessions: Int,
        observation_source: String,
        observed_at_ms: Int,
    ) raises:
        """Atomically validates and stores caller-observed runtime metrics."""
        if len(model_name.bytes()) == 0:
            raise Error("dashboard model name must not be empty")
        if len(active_backend.bytes()) == 0:
            raise Error("dashboard backend must not be empty")
        if len(observation_source.bytes()) == 0:
            raise Error("dashboard observation source must not be empty")
        if not isfinite(memory_used_mb) or memory_used_mb < 0.0:
            raise Error("dashboard memory observation must be finite and non-negative")
        if not isfinite(token_speed_tps) or token_speed_tps < 0.0:
            raise Error("dashboard throughput observation must be finite and non-negative")
        if active_sessions < 0:
            raise Error("dashboard active session count must be non-negative")
        if observed_at_ms <= 0:
            raise Error("dashboard observation timestamp must be positive")

        self.model_name = model_name
        self.active_backend = active_backend
        self.memory_used_mb = memory_used_mb
        self.token_speed_tps = token_speed_tps
        self.active_sessions = active_sessions
        self.observation_source = observation_source
        self.observed_at_ms = observed_at_ms
        self.has_observation = True

    def clear_observation(mut self):
        """Removes a stale observation without inventing replacement values."""
        self.model_name = String("None")
        self.active_backend = String("unobserved")
        self.memory_used_mb = 0.0
        self.token_speed_tps = 0.0
        self.active_sessions = 0
        self.observation_source = String("")
        self.observed_at_ms = 0
        self.has_observation = False

    def render_frame(self) raises -> String:
        """Renders an ASCII frame from validated caller observations."""
        var frame = String("┌──────────────────────────────────────────────────────────────────────────────┐\n")
        frame += "│                🛡️ PROJECT A.E.S.I.R. OBSERVATION DASHBOARD 🛡️                │\n"
        frame += "├──────────────────────────────────────────────────────────────────────────────┤\n"
        if not self.has_observation:
            frame += "│ Runtime observation: unavailable (no observer has published a snapshot)\n"
            frame += "└──────────────────────────────────────────────────────────────────────────────┘\n"
            return frame

        # Public fields remain readable for simple CLI integration, so validate
        # again at the display boundary in case a caller changed one directly.
        if len(self.model_name.bytes()) == 0 or len(self.active_backend.bytes()) == 0:
            raise Error("dashboard observation contains empty identity fields")
        if len(self.observation_source.bytes()) == 0 or self.observed_at_ms <= 0:
            raise Error("dashboard observation lacks provenance")
        if not isfinite(self.memory_used_mb) or self.memory_used_mb < 0.0:
            raise Error("dashboard memory observation is invalid")
        if not isfinite(self.token_speed_tps) or self.token_speed_tps < 0.0:
            raise Error("dashboard throughput observation is invalid")
        if self.active_sessions < 0:
            raise Error("dashboard active session count is invalid")

        frame += "│ Observation Source: " + self.observation_source + "\n"
        frame += "│ Observed At (ms):   " + String(self.observed_at_ms) + "\n"
        frame += "│ Active Model:     " + self.model_name + "\n"
        frame += "│ Hardware Realm:   " + self.active_backend + "\n"
        frame += "│ Active Sessions:  " + String(self.active_sessions) + "\n"
        frame += "│ Memory Residency: " + String(self.memory_used_mb) + " MB\n"
        frame += "│ Throughput Speed: " + String(self.token_speed_tps) + " tokens/sec\n"
        frame += "└──────────────────────────────────────────────────────────────────────────────┘\n"
        return frame
