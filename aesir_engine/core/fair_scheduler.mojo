# core/fair_scheduler.mojo
# A-105: Two-model fairness - two models served concurrently
# share devices without starvation.
#
# A-072 (core/vulkan_batch.mojo) batches sequences WITHIN one
# model: an iteration-level scheduler advances every resident
# sequence of that model together. It says nothing about TWO
# models resident on the same device at once - and the naive
# answer (serve whichever model was admitted first until it
# drains) starves the second model for the whole of the first
# model's prefill. This module is the missing inter-model
# layer: it decides, per scheduler step, how the step's token
# budget is split between exactly two resident models, so
# neither can starve the other.
#
# The discipline, in the open: weighted deficit round robin
# (WDRR) over token budgets.
#   1. A step is one batch-formation tick with a token budget
#      (the A-072 step budget; under A-076 GpuPressureGovernor
#      pressure the budget shrinks - fairness is proven for
#      every budget >= 1, so a governor squeeze tightens the
#      numbers, never the guarantee).
#   2. When both models are backlogged, each accrues deficit
#      credit of base_quantum x its weight per round; a visit
#      may spend at most the accrued deficit, the remaining
#      queue, and the remaining budget. Rounds repeat inside
#      the step until the budget is spent or both queues drain
#      (work-conserving inside the fairness cap). Visit order
#      alternates every step (cursor), so no model holds a
#      fixed first-mover advantage.
#   3. When exactly one model is backlogged it receives the
#      whole budget (work-conserving fast path) and both
#      deficits reset: an idle model banks NO credit, so a
#      returning model cannot burst-starve its peer with
#      hoarded quantum (invariant: queue drained -> deficit 0).
#   4. A step with budget 0 accrues nothing and counts no
#      wait: a fully pressured device is not evidence of
#      starvation by either model.
#
# The guarantees (integer-provable, no wall clock anywhere -
# time in this module is the step counter, advanced only by
# serve_step calls):
#   LATENCY BOUND: a model backlogged at a step with
#   budget >= 1 is served in that step or the next one.
#   wait_bound_steps() == 1: the worst observed wait of a
#   continuously backlogged model is ONE unserved step. Proof
#   sketch: if model X is second in visit order and the first
#   model spends the whole budget, X's wait becomes 1; the
#   cursor flips, so next step X is first, its accrued deficit
#   is >= its quantum >= 1 and its queue is >= 1, so it is
#   served >= 1 token and the wait resets.
#   SHARE BOUND: while both models are continuously
#   backlogged, the weight-normalised service lag obeys
#   |served_a x w_b - served_b x w_a| <= lag_bound_cross()
#   (per-round grants are deficit-capped at each model's
#   quantum; the bound is the two quanta cross-multiplied plus
#   one base quantum of step granularity).
#
# Composition (named, not duplicated): A-100's planner decides
# WHERE a model's work sits and A-102's spillover policy
# decides what capacity pressure pushes to the CPU path; this
# scheduler decides WHOSE tokens fill the device step both of
# them act on - spilled tokens never touch these deficits, so
# spillover cannot be used to bypass a model's quantum.
# Weights arrive from the A-017 device policy at construction
# and are immutable for the scheduler's life (a weight change
# is a new scheduler at a step boundary, never a mid-round
# edit). The resident pair is the A-086 winner-registry pair;
# the struct is deliberately the two-model slice of the
# general N-model discipline.
#
# Every step appends one deterministic line to the fairness
# log; the log's FNV-1a digest (reused from A-102) is the
# reproducibility anchor: same demand script in, byte-
# identical log out.

from core.spillover_policy import fnv1a64

comptime FAIR_BASE_QUANTUM = 256


struct FairStep(Copyable, ImplicitlyCopyable):
    """The split of one step's token budget."""

    var alloc_a: Int
    var alloc_b: Int

    def __init__(out self, alloc_a: Int, alloc_b: Int):
        self.alloc_a = alloc_a
        self.alloc_b = alloc_b


struct FairScheduler(Copyable):
    """Weighted deficit round robin between two resident
    models. State is plain counters; serve_step is the only
    mutator, so a run is a pure function of its demand script
    (budget + queued tokens per step)."""

    var name_a: String
    var name_b: String
    var weight_a: Int
    var weight_b: Int
    var base_quantum: Int
    var deficit_a: Int
    var deficit_b: Int
    var served_a: Int
    var served_b: Int
    var wait_a: Int
    var wait_b: Int
    var max_wait_a: Int
    var max_wait_b: Int
    var steps: Int
    var cursor: Int
    var entries: List[String]

    def __init__(
        out self,
        name_a: String,
        weight_a: Int,
        name_b: String,
        weight_b: Int,
        base_quantum: Int = FAIR_BASE_QUANTUM,
    ):
        self.name_a = name_a
        self.name_b = name_b
        self.weight_a = weight_a if weight_a >= 1 else 1
        self.weight_b = weight_b if weight_b >= 1 else 1
        self.base_quantum = base_quantum if base_quantum >= 1 else 1
        self.deficit_a = 0
        self.deficit_b = 0
        self.served_a = 0
        self.served_b = 0
        self.wait_a = 0
        self.wait_b = 0
        self.max_wait_a = 0
        self.max_wait_b = 0
        self.steps = 0
        self.cursor = 0
        self.entries = List[String]()
        self.entries.append(
            String("fairness v1 model_a=") + self.name_a
            + String(" weight_a=") + String(self.weight_a)
            + String(" model_b=") + self.name_b
            + String(" weight_b=") + String(self.weight_b)
            + String(" base_quantum=") + String(self.base_quantum)
        )

    def quantum_a(self) -> Int:
        return self.base_quantum * self.weight_a

    def quantum_b(self) -> Int:
        return self.base_quantum * self.weight_b

    def wait_bound_steps(self) -> Int:
        """Per-model latency bound, in steps: a continuously
        backlogged model (budget >= 1 throughout) is never
        left unserved for more than this many consecutive
        steps. See the header proof sketch."""
        return 1

    def lag_bound_cross(self) -> Int:
        """Bound on |served_a x w_b - served_b x w_a| while
        both models are continuously backlogged."""
        return (
            self.quantum_a() * self.weight_b
            + self.quantum_b() * self.weight_a
            + self.base_quantum
            * (self.weight_a if self.weight_a >= self.weight_b else self.weight_b)
        )

    def lag_cross(self) -> Int:
        """Current weight-normalised service lag, cross-
        multiplied to stay in integers."""
        var lag = self.served_a * self.weight_b - self.served_b * self.weight_a
        return lag if lag >= 0 else -lag

    def jain_x1000(self) -> Int:
        """Jain fairness index over weight-normalised service,
        scaled x1000 (1000 = perfectly fair)."""
        var xa = self.served_a * self.weight_b
        var xb = self.served_b * self.weight_a
        if xa + xb == 0:
            return 1000
        var num = (xa + xb) * (xa + xb)
        var den = 2 * (xa * xa + xb * xb)
        return num * 1000 // den

    def serve_step(
        mut self, budget: Int, queued_a: Int, queued_b: Int
    ) -> FairStep:
        """Split one step's token budget between the models.

        budget: tokens the device step may dispatch (A-072
        step budget, possibly governor-shrunk by A-076).
        queued_a / queued_b: tokens each model has waiting at
        the start of the step. Returns the per-model grants;
        grants never exceed budget or the queues."""
        self.steps += 1
        var alloc_a = 0
        var alloc_b = 0
        var back_a = queued_a > 0
        var back_b = queued_b > 0
        if budget > 0 and (back_a or back_b):
            if back_a and back_b:
                var left = budget
                var guard = 0
                while left > 0 and guard < 1000000:
                    guard += 1
                    self.deficit_a += self.quantum_a()
                    self.deficit_b += self.quantum_b()
                    var progressed = False
                    for k in range(2):
                        if left <= 0:
                            break
                        var idx = (self.cursor + k) % 2
                        if idx == 0:
                            var g = self.deficit_a
                            var rem_a = queued_a - alloc_a
                            if rem_a < g:
                                g = rem_a
                            if left < g:
                                g = left
                            if g > 0:
                                alloc_a += g
                                self.deficit_a -= g
                                left -= g
                                progressed = True
                        else:
                            var g = self.deficit_b
                            var rem_b = queued_b - alloc_b
                            if rem_b < g:
                                g = rem_b
                            if left < g:
                                g = left
                            if g > 0:
                                alloc_b += g
                                self.deficit_b -= g
                                left -= g
                                progressed = True
                    if not progressed:
                        break
                    if alloc_a >= queued_a and alloc_b >= queued_b:
                        break
                self.cursor = 1 - self.cursor
            elif back_a:
                alloc_a = queued_a if queued_a < budget else budget
                self.deficit_a = 0
                self.deficit_b = 0
            else:
                alloc_b = queued_b if queued_b < budget else budget
                self.deficit_a = 0
                self.deficit_b = 0
        # A drained queue banks no credit (no idle hoarding).
        if alloc_a >= queued_a:
            self.deficit_a = 0
        if alloc_b >= queued_b:
            self.deficit_b = 0
        self.served_a += alloc_a
        self.served_b += alloc_b
        # Wait accounting: only a step that could have served
        # (budget >= 1) is starvation evidence.
        if budget > 0:
            if back_a and alloc_a == 0:
                self.wait_a += 1
                if self.wait_a > self.max_wait_a:
                    self.max_wait_a = self.wait_a
            elif alloc_a > 0 or not back_a:
                self.wait_a = 0
            if back_b and alloc_b == 0:
                self.wait_b += 1
                if self.wait_b > self.max_wait_b:
                    self.max_wait_b = self.wait_b
            elif alloc_b > 0 or not back_b:
                self.wait_b = 0
        self.entries.append(
            String("step ") + String(self.steps)
            + String(" budget=") + String(budget)
            + String(" queued=") + String(queued_a) + String(",")
            + String(queued_b)
            + String(" alloc=") + String(alloc_a) + String(",")
            + String(alloc_b)
            + String(" served=") + String(self.served_a) + String(",")
            + String(self.served_b)
            + String(" wait=") + String(self.wait_a) + String(",")
            + String(self.wait_b)
            + String(" deficit=") + String(self.deficit_a) + String(",")
            + String(self.deficit_b)
        )
        return FairStep(alloc_a, alloc_b)

    def log_text(self) -> String:
        var text = String("")
        for i in range(len(self.entries)):
            text += self.entries[i] + String("\n")
        return text

    def digest(self) -> UInt64:
        return fnv1a64(self.log_text())

    def summary_line(self) -> String:
        return (
            String("fairness-summary steps=") + String(self.steps)
            + String(" served=") + String(self.served_a) + String(",")
            + String(self.served_b)
            + String(" max_wait=") + String(self.max_wait_a) + String(",")
            + String(self.max_wait_b)
            + String(" wait_bound=") + String(self.wait_bound_steps())
            + String(" lag_cross=") + String(self.lag_cross())
            + String(" lag_bound_cross=") + String(self.lag_bound_cross())
            + String(" jain_x1000=") + String(self.jain_x1000())
        )
