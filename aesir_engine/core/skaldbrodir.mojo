# core/skaldbrodir.mojo
# SKÁLDBRØÐIR — The Doom Loop Annihilation Protocol (AES-DOOM-001)

from std.math import isfinite

struct SkaldbrodirDetector:
    """
    Bounded exact-period repetition detector for generated token IDs.

    Returned tiers are intervention signals.  This component does not alter
    logits or stop a generation loop unless its caller handles the signal/error.
    """
    var enabled: Bool
    var window_size: Int
    var repetition_threshold: Float64
    var soft_threshold: Float64
    var hard_threshold: Float64
    var minimum_history: Int
    var max_pattern_length: Int
    var consecutive_terminal_observations: Int
    var is_annihilated: Bool
    var last_repetition_index: Float64
    var token_history: List[Int]

    def __init__(out self):
        self.enabled = True
        self.window_size = 64
        self.repetition_threshold = 9.0
        self.soft_threshold = 4.0
        self.hard_threshold = 7.0
        self.minimum_history = 8
        self.max_pattern_length = 16
        self.consecutive_terminal_observations = 0
        self.is_annihilated = False
        self.last_repetition_index = 0.0
        self.token_history = List[Int]()

    def _validate_configuration(self) raises:
        if self.window_size < 8 or self.window_size > 4096:
            raise Error("repetition window size must be between 8 and 4096")
        if self.minimum_history < 4 or self.minimum_history > self.window_size:
            raise Error("minimum repetition history must be within the configured window")
        if self.max_pattern_length < 1 or self.max_pattern_length > self.window_size // 2:
            raise Error("maximum repetition period must be within half the configured window")
        if (
            not isfinite(self.soft_threshold)
            or not isfinite(self.hard_threshold)
            or not isfinite(self.repetition_threshold)
            or self.soft_threshold < 0.0
            or self.soft_threshold >= self.hard_threshold
            or self.hard_threshold >= self.repetition_threshold
            or self.repetition_threshold > 10.0
        ):
            raise Error("repetition thresholds must be ordered within the 0..10 score range")

    def reset(mut self):
        """Clears all session-owned detector state while retaining policy."""
        self.consecutive_terminal_observations = 0
        self.is_annihilated = False
        self.last_repetition_index = 0.0
        self.token_history = List[Int]()

    def register_token(mut self, token_id: Int) raises:
        """Appends a new token to the sliding window history."""
        self._validate_configuration()
        if token_id < 0:
            raise Error("generated token ID must be non-negative")
        self.token_history.append(token_id)
        if len(self.token_history) > self.window_size:
            var new_history = List[Int]()
            var start = len(self.token_history) - self.window_size
            for i in range(start, len(self.token_history)):
                new_history.append(self.token_history[i])
            self.token_history = new_history^

    def compute_repetition_index(self) raises -> Float64:
        """Returns the strongest exact periodicity score in the bounded suffix."""
        self._validate_configuration()
        var n = len(self.token_history)
        if n < self.minimum_history:
            return 0.0

        var span = n
        if span > self.window_size:
            span = self.window_size
        var start = n - span
        var period_limit = self.max_pattern_length
        if period_limit > span // 2:
            period_limit = span // 2
        var strongest = 0.0
        for period in range(1, period_limit + 1):
            var matches = 0
            var comparisons = span - period
            for offset in range(period, span):
                if self.token_history[start + offset] == self.token_history[start + offset - period]:
                    matches += 1
            var score = (Float64(matches) / Float64(comparisons)) * 10.0
            if score > strongest:
                strongest = score
        return strongest

    def evaluate_and_intercept(mut self, token_id: Int) raises -> Int:
        """
        Evaluates current sequence state against SKÁLDBRØÐIR thresholds.
        Returns:
          0: Normal continuation
          1: soft intervention signal
          2: hard intervention signal
          terminal repetition: raises INF-016
        """
        if not self.enabled:
            return 0
        if self.is_annihilated:
            raise Error("INF-016: repetition detector is terminal; reset the session before reuse")

        self.register_token(token_id)
        var rep_index = self.compute_repetition_index()
        self.last_repetition_index = rep_index

        if rep_index >= self.repetition_threshold:
            self.consecutive_terminal_observations += 1
            if self.consecutive_terminal_observations >= 2:
                self.is_annihilated = True
                raise Error("INF-016: repeated token period exceeded the configured terminal threshold (repetition index " + String(rep_index) + ")")
        else:
            self.consecutive_terminal_observations = 0

        if rep_index >= self.hard_threshold:
            return 2
        elif rep_index >= self.soft_threshold:
            return 1
        
        return 0
