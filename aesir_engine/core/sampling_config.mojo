"""Validated native sampling policy, independent of hardware and CLI syntax."""
from std.math import isfinite


struct NativeSamplingConfig(Copyable, ImplicitlyCopyable):
    var temperature: Float32
    var top_k: Int
    var top_p: Float32
    var min_p: Float32
    var repetition_penalty: Float32
    var repeat_last_n: Int
    var seed: UInt64

    def __init__(out self, temperature: Float32 = 0, top_k: Int = 40,
                 top_p: Float32 = 0.95, min_p: Float32 = 0,
                 repetition_penalty: Float32 = 1, repeat_last_n: Int = 64,
                 seed: UInt64 = 42):
        self.temperature = temperature
        self.top_k = top_k
        self.top_p = top_p
        self.min_p = min_p
        self.repetition_penalty = repetition_penalty
        self.repeat_last_n = repeat_last_n
        self.seed = seed

    def validate(self) raises:
        if not isfinite(self.temperature) or self.temperature < 0:
            raise Error("Sampling temperature must be finite and nonnegative")
        if self.top_k < 1 or self.top_k > 256:
            raise Error("Native CUDA top-k must be within 1..256")
        if not isfinite(self.top_p) or self.top_p <= 0 or self.top_p > 1:
            raise Error("Sampling top-p must be within (0, 1]")
        if not isfinite(self.min_p) or self.min_p < 0 or self.min_p > 1:
            raise Error("Sampling min-p must be within [0, 1]")
        if not isfinite(self.repetition_penalty) or self.repetition_penalty <= 0:
            raise Error("Repetition penalty must be positive and finite")
        if self.repeat_last_n < 1 or self.repeat_last_n > 8192:
            raise Error("Repetition history window must be within 1..8192")

    def plain_greedy(self) -> Bool:
        return self.temperature == 0 and self.repetition_penalty == 1

    def description(self) -> String:
        var mode = String("greedy") if self.plain_greedy() else String("cuda")
        return mode + "; temperature=" + String(self.temperature) + "; top_k=" + String(self.top_k) + "; top_p=" + String(self.top_p) + "; min_p=" + String(self.min_p) + "; repetition_penalty=" + String(self.repetition_penalty) + "; repeat_last_n=" + String(self.repeat_last_n) + "; seed=" + String(self.seed)


def sampling_device_bytes(vocab_size: Int) raises -> Int:
    if vocab_size < 1 or vocab_size > 1048576:
        raise Error("Sampling vocabulary size outside supported bounds")
    # Histogram, ring, 128 per-partition top-256 lists, final list and flags.
    return (vocab_size + 8192 + 2 * (128 * 256 + 256) + 128) * 4
