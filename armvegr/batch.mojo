# armvegr/batch.mojo
# H137 — F1 static batching on the CPU path (Domain D1 ARMVEGR).
#
# Static batching (B streams, lockstep): B Inference decode states share
# ONE TinyLlama weight set via TinyLlama.shallow_copy (2.2 GiB loaded once,
# not B times). Each step forwards one token per stream. On the
# single-threaded CPU path this is organizational (no parallel speedup is
# claimed — the honest uplift is measured by tests/c7_h137_check.mojo);
# the value is shared weights, one model load, and lockstep scheduling.

from std.memory import Pointer
from std.origin import MutUntrackedOrigin

from armvegr.infer import Inference, TinyLlama
from armvegr.sampler import Sampler


struct BatchInference:
    """B independent decode streams over one shared weight set."""
    var batch_size: Int
    var max_seq: Int
    var model: TinyLlama
    var states: List[Inference]

    def __init__(out self, batch_size: Int, max_seq: Int = 1024):
        self.batch_size = batch_size
        self.max_seq = max_seq
        self.model = TinyLlama()
        self.states = List[Inference]()

    def load(mut self, path: String) raises:
        if self.batch_size <= 0:
            raise Error("batch: batch_size must be >= 1")
        if len(self.states) != 0:
            raise Error("batch: already loaded (free() first)")
        self.model.load(path)
        for _ in range(self.batch_size):
            var st = Inference(self.max_seq)
            st.model = self.model.shallow_copy()
            self.states.append(st^)

    def free(mut self) raises:
        for i in range(len(self.states)):
            self.states[i].free()
        self.states = List[Inference]()
        self.model.free()

    def reset_all(mut self):
        for i in range(len(self.states)):
            self.states[i].reset()

    def generate_batch(
        mut self,
        prompts: List[List[Int]],
        max_new: Int,
        seed: UInt64,
        greedy: Bool,
    ) raises -> List[List[Int]]:
        """Lockstep generate; returns per-stream full id lists (prompt + new).

        greedy=True -> temperature 0 (deterministic). Streams that hit EOS
        stop stepping (their output is final).
        """
        if len(prompts) != self.batch_size:
            raise Error(
                "batch: prompt count " + String(len(prompts))
                + " != batch_size " + String(self.batch_size)
            )
        if max_new <= 0:
            raise Error("batch: max_new must be >= 1")
        var temp = Float32(0.7)
        if greedy:
            temp = Float32(0.0)
        var samplers = List[Sampler]()
        for bi in range(self.batch_size):
            samplers.append(Sampler(seed + UInt64(bi)))
        # Prefill each stream, capturing the last step's logits.
        var last_logits = List[Pointer[Float16, MutUntrackedOrigin]]()
        var out = List[List[Int]]()
        var done = List[Bool]()
        for b in range(self.batch_size):
            if len(prompts[b]) == 0:
                raise Error("batch: empty prompt for stream " + String(b))
            self.states[b].reset()
            var lp = self.states[b].prefill(prompts[b])
            last_logits.append(lp)
            var seq = prompts[b].copy()
            out.append(seq^)
            done.append(False)
        # Lockstep decode.
        for _ in range(max_new):
            var all_done = True
            for b in range(self.batch_size):
                if done[b]:
                    continue
                all_done = False
                var logits = List[Float32]()
                var lp = last_logits[b]
                for i in range(32000):
                    logits.append(Float32(lp.unsafe_offset(i).unsafe_load()))
                var nt = samplers[b].sample(
                    logits, temp, 40, Float32(0.95), out[b], Float32(1.0)
                )
                out[b].append(nt)
                if nt == 2:
                    done[b] = True
                else:
                    last_logits[b] = self.states[b].forward(nt)
            if all_done:
                break
        return out^


def batch_version() -> String:
    return "0.1.0"
