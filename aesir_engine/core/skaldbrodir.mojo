# core/skaldbrodir.mojo
# SKÁLDBRØÐIR — local repeated-tail detector scaffold

struct SkaldbrodirDetector:
    """
    Local repeated-tail detector. It has no latency benchmark and is not yet
    integrated into the verified generation loop or sampler penalties.
    """
    var enabled: Bool
    var window_size: Int
    var repetition_threshold: Float64
    var min_entropy_threshold: Float64
    var is_annihilated: Bool
    var last_repetition_index: Float64
    var token_history: List[Int]

    def __init__(out self):
        self.enabled = True
        self.window_size = 64
        self.repetition_threshold = 8.5
        self.min_entropy_threshold = 0.15
        self.is_annihilated = False
        self.last_repetition_index = 0.0
        self.token_history = List[Int]()

    def register_token(mut self, token_id: Int):
        """Appends a new token to the sliding window history."""
        self.token_history.append(token_id)
        if len(self.token_history) > self.window_size * 2:
            var new_history = List[Int]()
            var start = len(self.token_history) - self.window_size
            for i in range(start, len(self.token_history)):
                new_history.append(self.token_history[i])
            self.token_history = new_history^

    def compute_repetition_index(self) -> Float64:
        """Calculates sliding window N-gram repetition index R."""
        var n = len(self.token_history)
        if n < 4:
            return 0.0
        var repeat_count = 0
        var total_grams = 0
        
        # Check 1-grams, 2-grams, 3-grams
        for gram_size in range(1, 4):
            if n < gram_size * 2:
                continue
            var last_idx = n - gram_size
            var prev_idx = n - gram_size * 2
            
            var is_match = True
            for k in range(gram_size):
                if self.token_history[prev_idx + k] != self.token_history[last_idx + k]:
                    is_match = False
                    break
            if is_match:
                repeat_count += 1
            total_grams += 1

        if total_grams == 0:
            return 0.0
        
        return (Float64(repeat_count) / Float64(total_grams)) * 10.0

    def evaluate_and_intercept(mut self, token_id: Int) raises -> Int:
        """
        Evaluates local history against deterministic repetition thresholds.
        Returns:
          0: Normal continuation
          1: threshold marker only; no sampler penalty is applied
          2: threshold marker only; no n-gram block is applied
          INF-016: local repeated-tail threshold reached
        """
        if not self.enabled:
            return 0

        self.register_token(token_id)
        var rep_index = self.compute_repetition_index()
        self.last_repetition_index = rep_index

        if rep_index >= self.repetition_threshold:
            self.is_annihilated = True
            raise Error("INF-016: local repeated-tail threshold reached (Repetition Index: " + String(rep_index) + " >= " + String(self.repetition_threshold) + ")")

        if rep_index > 5.0:
            return 2
        elif rep_index > 2.5:
            return 1
        
        return 0
