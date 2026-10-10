# armvegr/sampler.mojo
# H053-H057 — token sampler in pure Mojo (Domain D1 ARMVEGR).
#
# Greedy, temperature, top-k, top-p (nucleus), and repetition penalty.
# In-module splitmix64 PRNG (no external RNG dependency). All sampling is
# deterministic given the seed.

from std.math import exp


struct Sampler:
    var rng_state: UInt64

    def __init__(out self, seed: UInt64):
        # splitmix64 requires non-zero state; mix the seed in.
        self.rng_state = seed + 0x9E3779B97F4A7C15
        if self.rng_state == 0:
            self.rng_state = 0x243F6A8885A308D3

    def _next_u64(mut self) -> UInt64:
        self.rng_state += 0x9E3779B97F4A7C15
        var z = self.rng_state
        z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) * 0x94D049BB133111EB
        return z ^ (z >> 31)

    def next_f32(mut self) -> Float32:
        """Uniform in [0, 1). Uses 24 bits (Float32 mantissa) to avoid
        rounding up to 1.0."""
        return Float32(self._next_u64() >> 40) / Float32(16777216.0)

    def greedy(self, logits: List[Float32]) -> Int:
        """H053: argmax."""
        var best = 0
        var bv = logits[0]
        for i in range(1, len(logits)):
            if logits[i] > bv:
                bv = logits[i]
                best = i
        return best

    def tempered(self, logits: List[Float32], temp: Float32) -> List[Float32]:
        """H054: scale logits by 1/temp (temp<=0 -> greedy handled by caller)."""
        var out = List[Float32]()
        var inv = Float32(1.0) / temp
        for i in range(len(logits)):
            out.append(logits[i] * inv)
        return out.copy()

    def top_k_mask(self, logits: List[Float32], k: Int) -> List[Float32]:
        """H055: keep top-k logits, set rest to -inf. k<=0 or k>=n -> unchanged."""
        var n = len(logits)
        var out = logits.copy()
        if k <= 0 or k >= n:
            return out.copy()
        # Find k-th largest via selection.
        var vals = logits.copy()
        # Partial selection sort for top k.
        for i in range(k):
            var mx_i = i
            for j in range(i + 1, n):
                if vals[j] > vals[mx_i]:
                    mx_i = j
            var tmp = vals[i]
            vals[i] = vals[mx_i]
            vals[mx_i] = tmp
        var thresh = vals[k - 1]
        # Count how many >= thresh (handle ties by keeping first k).
        # Simpler: mask all < thresh; if ties cause >k, that's acceptable
        # as long as it's deterministic. We keep >= thresh.
        for i in range(n):
            if out[i] < thresh:
                out[i] = Float32(-1e30)
        return out.copy()

    def top_p_mask(self, logits: List[Float32], p: Float32) -> List[Float32]:
        """H056: nucleus mask. Keeps smallest set with cumulative prob >= p."""
        var n = len(logits)
        var probs = softmax(logits)
        # Sort indices by prob descending.
        var idx = List[Int]()
        for i in range(n):
            idx.append(i)
        for i in range(n):
            for j in range(i + 1, n):
                if probs[idx[j]] > probs[idx[i]]:
                    var tmp = idx[i]
                    idx[i] = idx[j]
                    idx[j] = tmp
        var cumsum = Float32(0.0)
        var keep = List[Bool]()
        for _ in range(n):
            keep.append(False)
        for r in range(n):
            var i = idx[r]
            keep[i] = True
            cumsum += probs[i]
            if cumsum >= p:
                break
        var out = List[Float32]()
        for i in range(n):
            if keep[i]:
                out.append(logits[i])
            else:
                out.append(Float32(-1e30))
        return out.copy()

    def repetition_penalty(
        self, logits: List[Float32], history: List[Int], penalty: Float32
    ) -> List[Float32]:
        """H057: HF-style repetition penalty. penalty<=1 -> unchanged."""
        var out = logits.copy()
        if penalty <= Float32(1.0):
            return out.copy()
        for h in range(len(history)):
            var t = history[h]
            if t >= 0 and t < len(out):
                if out[t] > 0:
                    out[t] = out[t] / penalty
                else:
                    out[t] = out[t] * penalty
        return out.copy()

    def sample_categorical(mut self, probs: List[Float32]) -> Int:
        var r = self.next_f32()
        var cumsum = Float32(0.0)
        for i in range(len(probs)):
            cumsum += probs[i]
            if r < cumsum:
                return i
        return len(probs) - 1

    def sample(
        mut self,
        logits: List[Float32],
        temp: Float32,
        top_k: Int,
        top_p: Float32,
        history: List[Int],
        penalty: Float32,
    ) -> Int:
        """Full pipeline: repetition penalty -> temperature -> top-k -> top-p -> sample.
        temp<=0 selects greedy."""
        var l = self.repetition_penalty(logits, history, penalty)
        if temp <= Float32(0.0):
            return self.greedy(l)
        l = self.tempered(l, temp)
        if top_k > 0:
            l = self.top_k_mask(l, top_k)
        if top_p < Float32(1.0) and top_p > Float32(0.0):
            l = self.top_p_mask(l, top_p)
        var probs = softmax(l)
        return self.sample_categorical(probs)


def softmax(logits: List[Float32]) -> List[Float32]:
    var n = len(logits)
    var mx = logits[0]
    for i in range(1, n):
        if logits[i] > mx:
            mx = logits[i]
    var out = List[Float32]()
    var s = Float32(0.0)
    for i in range(n):
        var e = exp(logits[i] - mx)
        out.append(e)
        s += e
    for i in range(n):
        out[i] = out[i] / s
    return out.copy()


def sampler_version() -> String:
    return "0.1.0"
