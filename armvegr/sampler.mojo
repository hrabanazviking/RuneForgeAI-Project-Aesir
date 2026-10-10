# armvegr/sampler.mojo
# H053-H057 — token sampler in pure Mojo (Domain D1 ARMVEGR).
#
# Greedy, temperature, top-k, top-p (nucleus), and repetition penalty.
# In-module splitmix64 PRNG (no external RNG dependency). All sampling is
# deterministic given the seed.

from std.math import exp
from std.memory import Pointer
from std.memory.alloc import unsafe_alloc
from std.origin import MutUntrackedOrigin


struct Sampler:
    var rng_state: UInt64
    # H173 fused-path scratch (lazy: allocated on first sample_fast call,
    # reused every step after — zero allocation per decode step).
    var f_n: Int
    var f_logits: Pointer[Float32, MutUntrackedOrigin]
    var f_probs: Pointer[Float32, MutUntrackedOrigin]
    var f_idx: Pointer[Int, MutUntrackedOrigin]
    var f_live: Pointer[Int, MutUntrackedOrigin]

    def __init__(out self, seed: UInt64):
        # splitmix64 requires non-zero state; mix the seed in.
        self.rng_state = seed + 0x9E3779B97F4A7C15
        if self.rng_state == 0:
            self.rng_state = 0x243F6A8885A308D3
        self.f_n = 0
        # Null placeholders; _fused_ensure() allocates on first use.
        # (Never dereferenced while f_n == 0.)
        self.f_logits = Pointer[Float32, MutUntrackedOrigin](unsafe_from_address=0)
        self.f_probs = Pointer[Float32, MutUntrackedOrigin](unsafe_from_address=0)
        self.f_idx = Pointer[Int, MutUntrackedOrigin](unsafe_from_address=0)
        self.f_live = Pointer[Int, MutUntrackedOrigin](unsafe_from_address=0)

    def _fused_ensure(mut self, n: Int):
        # Allocate (or grow) the fused scratch. Called once per size class.
        if self.f_n >= n:
            return
        self.f_logits = unsafe_alloc[Float32](n)
        self.f_probs = unsafe_alloc[Float32](n)
        self.f_idx = unsafe_alloc[Int](n)
        self.f_live = unsafe_alloc[Int](n)
        self.f_n = n

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

    def _fused_scratch_view(self) -> SamplerScratch:
        # View the owned buffers as a SamplerScratch (no copy of data,
        # no allocation).
        var sc = SamplerScratch()
        sc.n = self.f_n
        sc.logits = self.f_logits
        sc.probs = self.f_probs
        sc.idx = self.f_idx
        sc.live = self.f_live
        return sc^

    def sample_fast(
        mut self,
        logits: List[Float32],
        temp: Float32,
        top_k: Int,
        top_p: Float32,
        history: List[Int],
        penalty: Float32,
    ) -> Int:
        """H173 — fused zero-allocation sampling path (List API).

        Bit-identical tokens to sample() for the same inputs and RNG
        state (asserted by tests/c9_h173_sampler.mojo). The scratch is
        allocated on the first call and reused — zero allocation per
        decode step after the first."""
        var n = len(logits)
        self._fused_ensure(n)
        # Stage the input logits + history into contiguous buffers.
        # (Two copies into owned scratch; no allocation.)
        for i in range(n):
            self.f_logits.unsafe_offset(i).unsafe_store(logits[i])
        var hn = len(history)
        for i in range(hn):
            self.f_idx.unsafe_offset(i).unsafe_store(history[i])
        var sc = self._fused_scratch_view()
        return sample_fused(
            self, self.f_logits, n, sc, temp, top_k, top_p,
            self.f_idx, hn, penalty,
        )

    def sample_fast_ptr(
        mut self,
        inp: Pointer[Float32, MutUntrackedOrigin],
        n: Int,
        temp: Float32,
        top_k: Int,
        top_p: Float32,
        hist: Pointer[Int, MutUntrackedOrigin],
        hist_len: Int,
        penalty: Float32,
    ) -> Int:
        """H173 — fused path with pointer inputs (for the harness decode
        loop, which already holds logits in a reused buffer)."""
        self._fused_ensure(n)
        var sc = self._fused_scratch_view()
        return sample_fused(
            self, inp, n, sc, temp, top_k, top_p, hist, hist_len, penalty
        )


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
    return "0.2.0"


# ---------------------------------------------------------------------------
# H173 — fused zero-allocation sampling path (decode-latency optimization).
#
# The classic sample() path allocates ~6 List[Float32](32000) per decode
# step and top_p_mask bubble-sorts all 32000 indices O(n^2) (~5e8
# comparisons). The fused path below:
#   * reuses caller-owned scratch buffers (zero allocation after the first
#     call — verified by the RSS-flat test in bench/run_bench),
#   * replaces the full O(n^2) selection sort with a PARTIAL selection
#     over the live (prob > 0) candidates, stopping the moment cumulative
#     probability reaches top_p. Selection sort's prefix after r iterations
#     is identical to the full sort's prefix, and ties keep index order
#     (strict > comparison, same as the original), so the kept SET is
#     bit-identical to top_p_mask's — same masked logits, same softmax,
#     same RNG draw -> bit-identical tokens (asserted by test).
#   * fuses repetition penalty -> temper -> top-k -> top-p -> softmax ->
#     categorical into a single pass over preallocated buffers.


struct SamplerScratch:
    """Preallocated working buffers for sample_fused (H173).

    Owned by the caller (decode loop); allocated once, reused every step.
    logits/probs/idx/live are each length n.
    """
    var n: Int
    var logits: Pointer[Float32, MutUntrackedOrigin]
    var probs: Pointer[Float32, MutUntrackedOrigin]
    var idx: Pointer[Int, MutUntrackedOrigin]
    var live: Pointer[Int, MutUntrackedOrigin]

    def __init__(out self, n: Int):
        self.n = n
        self.logits = unsafe_alloc[Float32](n)
        self.probs = unsafe_alloc[Float32](n)
        self.idx = unsafe_alloc[Int](n)
        self.live = unsafe_alloc[Int](n)

    def __init__(out self):
        # Non-allocating view constructor (for _fused_scratch_view).
        self.n = 0
        self.logits = Pointer[Float32, MutUntrackedOrigin](unsafe_from_address=0)
        self.probs = Pointer[Float32, MutUntrackedOrigin](unsafe_from_address=0)
        self.idx = Pointer[Int, MutUntrackedOrigin](unsafe_from_address=0)
        self.live = Pointer[Int, MutUntrackedOrigin](unsafe_from_address=0)

    def free(mut self):
        self.logits.unsafe_free()
        self.probs.unsafe_free()
        self.idx.unsafe_free()
        self.live.unsafe_free()
        self.n = 0


def _fused_softmax(
    logits: Pointer[Float32, MutUntrackedOrigin],
    probs: Pointer[Float32, MutUntrackedOrigin],
    n: Int,
):
    var mx = logits.unsafe_offset(0).unsafe_load()
    for i in range(1, n):
        var v = logits.unsafe_offset(i).unsafe_load()
        if v > mx:
            mx = v
    var s = Float32(0.0)
    for i in range(n):
        var e = exp(logits.unsafe_offset(i).unsafe_load() - mx)
        probs.unsafe_offset(i).unsafe_store(e)
        s += e
    for i in range(n):
        probs.unsafe_offset(i).unsafe_store(
            probs.unsafe_offset(i).unsafe_load() / s
        )


def sample_fused(
    mut sampler: Sampler,
    inp: Pointer[Float32, MutUntrackedOrigin],
    n: Int,
    scratch: SamplerScratch,
    temp: Float32,
    top_k: Int,
    top_p: Float32,
    hist: Pointer[Int, MutUntrackedOrigin],
    hist_len: Int,
    penalty: Float32,
) -> Int:
    """H173 fused sampling on preallocated buffers. Bit-identical tokens to
    Sampler.sample() for the same inputs and RNG state (test-asserted)."""
    var lg = scratch.logits
    var pr = scratch.probs
    # 1. copy + repetition penalty (HF-style, same as repetition_penalty()).
    for i in range(n):
        lg.unsafe_offset(i).unsafe_store(inp.unsafe_offset(i).unsafe_load())
    if penalty > Float32(1.0):
        for h in range(hist_len):
            var t = hist.unsafe_offset(h).unsafe_load()
            if t >= 0 and t < n:
                var v = lg.unsafe_offset(t).unsafe_load()
                if v > Float32(0.0):
                    lg.unsafe_offset(t).unsafe_store(v / penalty)
                else:
                    lg.unsafe_offset(t).unsafe_store(v * penalty)
    # 2. greedy shortcut (same as sample()).
    if temp <= Float32(0.0):
        var best = 0
        var bv = lg.unsafe_offset(0).unsafe_load()
        for i in range(1, n):
            var v = lg.unsafe_offset(i).unsafe_load()
            if v > bv:
                bv = v
                best = i
        return best
    # 3. temperature (same as tempered(), in place).
    var inv = Float32(1.0) / temp
    for i in range(n):
        lg.unsafe_offset(i).unsafe_store(lg.unsafe_offset(i).unsafe_load() * inv)
    # 4. top-k (same algorithm as top_k_mask(): partial selection for the
    #    k-th largest, keep >= threshold).
    if top_k > 0 and top_k < n:
        for i in range(n):
            pr.unsafe_offset(i).unsafe_store(lg.unsafe_offset(i).unsafe_load())
        for i in range(top_k):
            var mx_i = i
            for jj in range(i + 1, n):
                if pr.unsafe_offset(jj).unsafe_load() > pr.unsafe_offset(mx_i).unsafe_load():
                    mx_i = jj
            var tmp = pr.unsafe_offset(i).unsafe_load()
            pr.unsafe_offset(i).unsafe_store(pr.unsafe_offset(mx_i).unsafe_load())
            pr.unsafe_offset(mx_i).unsafe_store(tmp)
        var thresh = pr.unsafe_offset(top_k - 1).unsafe_load()
        var neg = Float32(-1e30)
        for i in range(n):
            if lg.unsafe_offset(i).unsafe_load() < thresh:
                lg.unsafe_offset(i).unsafe_store(neg)
    # 5. top-p (equivalent to top_p_mask(), partial selection over live
    #    candidates only).
    if top_p > Float32(0.0) and top_p < Float32(1.0):
        _fused_softmax(lg, pr, n)
        var lv = scratch.live
        var nl = 0
        for i in range(n):
            if pr.unsafe_offset(i).unsafe_load() > Float32(0.0):
                lv.unsafe_offset(nl).unsafe_store(i)
                nl += 1
        var cumsum = Float32(0.0)
        var nkept = 0
        for r in range(nl):
            var mx_i = r
            for jj in range(r + 1, nl):
                var a = lv.unsafe_offset(jj).unsafe_load()
                var b = lv.unsafe_offset(mx_i).unsafe_load()
                if pr.unsafe_offset(a).unsafe_load() > pr.unsafe_offset(b).unsafe_load():
                    mx_i = jj
            var tmp = lv.unsafe_offset(r).unsafe_load()
            lv.unsafe_offset(r).unsafe_store(lv.unsafe_offset(mx_i).unsafe_load())
            lv.unsafe_offset(mx_i).unsafe_store(tmp)
            var chosen = lv.unsafe_offset(r).unsafe_load()
            cumsum += pr.unsafe_offset(chosen).unsafe_load()
            nkept = r + 1
            if cumsum >= top_p:
                break
        if cumsum >= top_p:
            # Mask everything not in the kept prefix.
            var mk = scratch.idx
            for i in range(n):
                mk.unsafe_offset(i).unsafe_store(0)
            for r in range(nkept):
                mk.unsafe_offset(lv.unsafe_offset(r).unsafe_load()).unsafe_store(1)
            var neg = Float32(-1e30)
            for i in range(n):
                if mk.unsafe_offset(i).unsafe_load() == 0:
                    lg.unsafe_offset(i).unsafe_store(neg)
        # else: cumsum could not reach top_p (only when p ~= 1.0 within
        # fp32 rounding) — the original keeps everything too; mask nothing.
    # 6. final softmax + categorical (same as sample()).
    _fused_softmax(lg, pr, n)
    var r = sampler.next_f32()
    var cs = Float32(0.0)
    for i in range(n):
        cs += pr.unsafe_offset(i).unsafe_load()
        if r < cs:
            return i
    return n - 1


def sampler_fused_version() -> String:
    return "1.0.0"
