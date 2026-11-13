# core/failure_replan.mojo
# A-103: Mid-run device failure re-planning.
#
# Acceptance (roadmap A-103): a device error during generation
# re-plans the remaining work onto the survivors. Injected
# failure drill passes (extends A-079 to the planner level).
#
# A-079 proved device-lost recovery for ONE running decode: a
# per-commit snapshot, a single permitted CPU failover, fail
# closed otherwise. A-103 lifts that contract from the single
# run to the A-100 PLANNER: a generation is a plan (one
# PlannerDecision per step, from the measured tables), and a
# device error mid-generation re-plans every REMAINING step
# through the same planner on a survivor registry -- the
# registry with the failed device removed. The A-079 laws
# carry over, restated at the planner level:
#
#   1. COMMITTED PREFIX IS UNTOUCHED: steps before the failure
#      keep their original decisions and their committed
#      tokens; re-planning starts exactly at the first
#      uncommitted step. The in-flight step of the failure is
#      DISCARDED and re-planned (never counted committed).
#   2. THE FAILED DEVICE GETS NO FURTHER WORK: the survivor
#      registry marks the failed runtime absent (GPU failure
#      removes both HIP and Vulkan; NPU failure removes XRT;
#      CPU failure removes the CPU), so plan_op cannot place
#      on it -- and the re-planner additionally refuses any
#      decision that still names the failed class (defence in
#      depth against a planner regression).
#   3. ONE RE-PLAN PER RUN: a second device failure after a
#      re-plan ends the run FAILED_CLOSED with the committed
#      prefix intact -- the planner-level form of A-079's
#      single-failover law, so a loss storm cannot loop.
#   4. FAIL CLOSED WHEN NO SURVIVOR CAN TAKE A STEP: any
#      remaining step whose survivor decision is DEVICE_NONE
#      ends the re-plan FAILED_CLOSED, naming the step; the
#      caller keeps exactly the committed prefix (A-079 rule:
#      state intact, honest ending, never a truncated run
#      presented as finished).
#   5. FALLBACKS STAY NAMED: NPU decisions made by the
#      re-plan still carry their A-099 CPU fallback in the
#      decision record; an NPU failure itself degrades through
#      the ordinary planner rules on the survivor registry
#      (the A-098 optimum among the survivors wins), which is
#      the A-099 contract applied at plan scope.
#   6. AUDIT IS BOUNDED AND COMPLETE: every re-planned step
#      appends one audit line (old placement -> new placement,
#      error named); the audit is capped at AUDIT_MAX lines
#      with an explicit truncation line, never silently cut.
#
# Requests carry their A-076 governor context in their flags
# (power_capped / overlap_available), so a re-plan under GPU
# pressure re-decides with the same flags the original plan
# used -- no governor state is invented or dropped here.
#
# Honesty: this module decides and re-decides; it does not
# execute on any accelerator. The drill below models the
# execution with the campaign's shared deterministic step
# function (the A-066/A-079 greedy discipline: every device
# path produces the same token for the same committed
# prefix), so the graded claim is the RE-PLANNING arithmetic
# -- final tokens equal to the uninterrupted control,
# byte-for-byte over the token list -- not a new device
# execution. No accelerator claim is made by this slice.

from core.backend_registry import BACKEND_ABSENT, BackendRegistry
from core.device_policy import (
    DEVICE_CPU,
    DEVICE_GPU,
    DEVICE_NONE,
    DEVICE_NPU,
    device_class_name,
)
from core.placement_planner import (
    PlannerContext,
    PlannerDecision,
    PlannerRequest,
    plan_op,
)

comptime REPLAN_OK = 0
comptime REPLAN_NO_REMAINING = 1
comptime REPLAN_FAILED_CLOSED = 2

comptime AUDIT_MAX = 128


def replan_outcome_name(outcome: Int) -> String:
    if outcome == REPLAN_OK:
        return String("REPLANNED")
    if outcome == REPLAN_NO_REMAINING:
        return String("NO_REMAINING_WORK")
    if outcome == REPLAN_FAILED_CLOSED:
        return String("FAILED_CLOSED")
    return String("UNKNOWN")


struct PlannedStep(Copyable, ImplicitlyCopyable):
    """One step of a generation plan: its index, the request
    that was placed, and the decision the planner made."""

    var index: Int
    var request: PlannerRequest
    var decision: PlannerDecision

    def __init__(
        out self,
        index: Int,
        request: PlannerRequest,
        decision: PlannerDecision,
    ):
        self.index = index
        self.request = request
        self.decision = decision


struct GenerationPlan(Copyable):
    """A whole generation as a plan: one PlannedStep per
    step, in execution order."""

    var steps: List[PlannedStep]

    def __init__(out self, steps: List[PlannedStep]):
        self.steps = steps.copy()


def build_generation_plan(
    registry: BackendRegistry,
    context: PlannerContext,
    requests: List[PlannerRequest],
) -> GenerationPlan:
    """Place every request through the A-100 planner, in
    order. Pure: same registry/context/requests, same plan."""
    var steps = List[PlannedStep]()
    for i in range(len(requests)):
        var decision = plan_op(registry, context, requests[i])
        steps.append(PlannedStep(i, requests[i], decision))
    return GenerationPlan(steps^)


def survivor_registry(
    registry: BackendRegistry, failed_device_class: Int
) -> BackendRegistry:
    """The registry the re-plan runs on: the failed device
    removed, everything else exactly as it was (GPU roles
    included -- a surviving GPU backend keeps its A-086
    role; only absence changes)."""
    var hip = registry.hip
    var vulkan = registry.vulkan
    var xrt = registry.xrt
    var cpu = registry.cpu
    if failed_device_class == DEVICE_GPU:
        hip.status = BACKEND_ABSENT
        vulkan.status = BACKEND_ABSENT
    elif failed_device_class == DEVICE_NPU:
        xrt.status = BACKEND_ABSENT
    elif failed_device_class == DEVICE_CPU:
        cpu.status = BACKEND_ABSENT
    return BackendRegistry(hip, vulkan, xrt, cpu)


struct ReplanResult(Copyable):
    """The re-plan verdict: outcome, the re-planned remaining
    steps (empty on FAILED_CLOSED), how many steps moved
    device, the bounded audit, and the named reason."""

    var outcome: Int
    var completed_count: Int
    var remaining_count: Int
    var moved_count: Int
    var steps: List[PlannedStep]
    var audit: List[String]
    var reason: String

    def __init__(
        out self,
        outcome: Int,
        completed_count: Int,
        remaining_count: Int,
        moved_count: Int,
        steps: List[PlannedStep],
        audit: List[String],
        reason: String,
    ):
        self.outcome = outcome
        self.completed_count = completed_count
        self.remaining_count = remaining_count
        self.moved_count = moved_count
        self.steps = steps.copy()
        self.audit = audit.copy()
        self.reason = reason


def _audit_line(
    step: PlannedStep, new_decision: PlannerDecision, error_name: String
) -> String:
    return (
        "step "
        + String(step.index)
        + ": "
        + device_class_name(step.decision.device_class)
        + "("
        + step.decision.backend
        + ") -> "
        + device_class_name(new_decision.device_class)
        + "("
        + new_decision.backend
        + ") ["
        + error_name
        + "; A-103 re-plan]"
    )


def replan_remaining(
    registry: BackendRegistry,
    context: PlannerContext,
    plan: GenerationPlan,
    completed_count: Int,
    failed_device_class: Int,
    error_name: String,
) -> ReplanResult:
    """Re-plan the uncommitted tail of `plan` onto the
    survivors of `failed_device_class`.

    The committed prefix (steps [0, completed_count)) is not
    consulted and never altered. Every remaining step is
    re-decided by plan_op on the survivor registry; a step
    that lands on DEVICE_NONE or back on the failed class
    fails the whole re-plan closed."""
    var total = len(plan.steps)
    var audit = List[String]()
    var empty = List[PlannedStep]()
    if completed_count < 0 or completed_count > total:
        return ReplanResult(
            REPLAN_FAILED_CLOSED,
            completed_count,
            0,
            0,
            empty^,
            audit^,
            String("invalid completed count ")
            + String(completed_count)
            + String(" for a plan of ")
            + String(total),
        )
    var remaining = total - completed_count
    if remaining == 0:
        return ReplanResult(
            REPLAN_NO_REMAINING,
            completed_count,
            0,
            0,
            empty^,
            audit^,
            String("failure arrived after the final commit; ")
            + String("nothing to re-plan"),
        )
    var survivors = survivor_registry(registry, failed_device_class)
    var steps = List[PlannedStep]()
    var moved = 0
    for i in range(completed_count, total):
        var step = plan.steps[i]
        var nd = plan_op(survivors, context, step.request)
        if nd.device_class == DEVICE_NONE:
            return ReplanResult(
                REPLAN_FAILED_CLOSED,
                completed_count,
                remaining,
                moved,
                List[PlannedStep](),
                audit^,
                String("no survivor can take step ")
                + String(step.index)
                + String(" (")
                + step.request.op_kind
                + String(") after ")
                + error_name
                + String(" on ")
                + device_class_name(failed_device_class),
            )
        if nd.device_class == failed_device_class:
            return ReplanResult(
                REPLAN_FAILED_CLOSED,
                completed_count,
                remaining,
                moved,
                List[PlannedStep](),
                audit^,
                String("survivor planner returned the failed ")
                + String("device for step ")
                + String(step.index)
                + String("; refusing (A-103 law 2)"),
            )
        if (
            nd.device_class != step.decision.device_class
            or nd.backend != step.decision.backend
        ):
            moved += 1
        if len(audit) < AUDIT_MAX:
            audit.append(_audit_line(step, nd, error_name))
        elif len(audit) == AUDIT_MAX:
            audit.append(
                String("audit truncated at ")
                + String(AUDIT_MAX)
                + String(" lines (A-103 law 6)")
            )
        steps.append(PlannedStep(step.index, step.request, nd))
    return ReplanResult(
        REPLAN_OK,
        completed_count,
        remaining,
        moved,
        steps^,
        audit^,
        String("remaining work re-planned onto survivors of ")
        + device_class_name(failed_device_class)
        + String(" after ")
        + error_name,
    )


def _step_token(seed: Int, committed: List[Int]) -> Int:
    """The shared deterministic step function (A-066/A-079
    greedy discipline modelled exactly): the token for a
    committed prefix is a pure function of the seed and the
    prefix bytes, identical on every device path."""
    var h = seed
    for i in range(len(committed)):
        h = (h * 31 + committed[i] + 7) % 1000003
    return (h + len(committed) * 17) % 32000


def control_tokens(seed: Int, count: Int) -> List[Int]:
    """The uninterrupted control run: `count` steps of the
    shared step function with no failure. The drill's final
    tokens must equal this list exactly."""
    var tokens = List[Int]()
    for _ in range(count):
        tokens.append(_step_token(seed, tokens))
    return tokens^


struct DrillResult(Copyable):
    """The injected-failure drill verdict: final tokens, the
    control tokens, whether they match exactly, the re-plan
    outcome, steps (wrongly) executed on the failed device
    after the failure, and the re-plan audit."""

    var outcome: Int
    var tokens: List[Int]
    var control: List[Int]
    var tokens_match_control: Bool
    var moved_count: Int
    var steps_on_failed_after_failure: Int
    var audit: List[String]
    var reason: String

    def __init__(
        out self,
        outcome: Int,
        tokens: List[Int],
        control: List[Int],
        tokens_match_control: Bool,
        moved_count: Int,
        steps_on_failed_after_failure: Int,
        audit: List[String],
        reason: String,
    ):
        self.outcome = outcome
        self.tokens = tokens.copy()
        self.control = control.copy()
        self.tokens_match_control = tokens_match_control
        self.moved_count = moved_count
        self.steps_on_failed_after_failure = (
            steps_on_failed_after_failure
        )
        self.audit = audit.copy()
        self.reason = reason


def _tokens_equal(a: List[Int], b: List[Int]) -> Bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True


def run_failure_drill(
    registry: BackendRegistry,
    context: PlannerContext,
    requests: List[PlannerRequest],
    seed: Int,
    fail_step: Int,
    failed_device_class: Int,
    error_name: String,
    second_fail_step: Int = -1,
    second_failed_device_class: Int = -1,
    second_error_name: String = "",
) -> DrillResult:
    """Execute the plan under an injected device failure.

    Steps execute in plan order through the shared step
    function. At `fail_step` the named device errors BEFORE
    the step commits: the in-flight step is discarded, the
    remaining tail (starting at fail_step) is re-planned onto
    the survivors, and execution resumes on the new plan. A
    second injected failure (second_fail_step >= 0) after the
    re-plan ends the run FAILED_CLOSED with the committed
    prefix intact (A-103 law 3). The drill is mis-targeted --
    and fails closed -- if the step at fail_step was not
    placed on the named device."""
    var control = control_tokens(seed, len(requests))
    var plan = build_generation_plan(registry, context, requests)
    var current = plan.steps.copy()
    var tokens = List[Int]()
    var audit = List[String]()
    var moved = 0
    var on_failed_after = 0
    var replanned = False
    var i = 0
    var total = len(requests)
    while i < total:
        var is_first_failure = (i == fail_step) and not replanned
        var is_second_failure = (
            replanned
            and second_fail_step >= 0
            and i == second_fail_step
        )
        if is_second_failure:
            return DrillResult(
                REPLAN_FAILED_CLOSED,
                tokens^,
                control^,
                False,
                moved,
                on_failed_after,
                audit^,
                String("second device failure (")
                + second_error_name
                + String(" on ")
                + device_class_name(second_failed_device_class)
                + String(") after the A-103 re-plan; run ends ")
                + String("FAILED_CLOSED with the committed ")
                + String("prefix intact (law 3)"),
            )
        if is_first_failure:
            if current[i].decision.device_class != failed_device_class:
                return DrillResult(
                    REPLAN_FAILED_CLOSED,
                    tokens^,
                    control^,
                    False,
                    moved,
                    on_failed_after,
                    audit^,
                    String("drill mis-targeted: step ")
                    + String(i)
                    + String(" was not placed on ")
                    + device_class_name(failed_device_class),
                )
            var rr = replan_remaining(
                registry,
                context,
                GenerationPlan(current),
                i,
                failed_device_class,
                error_name,
            )
            moved = rr.moved_count
            for line in rr.audit:
                audit.append(line)
            if rr.outcome != REPLAN_OK:
                return DrillResult(
                    rr.outcome,
                    tokens^,
                    control^,
                    False,
                    moved,
                    on_failed_after,
                    audit^,
                    rr.reason,
                )
            var next_steps = List[PlannedStep]()
            for j in range(i):
                next_steps.append(current[j])
            for step in rr.steps:
                next_steps.append(step)
            current = next_steps^
            replanned = True
            continue
        if replanned and current[i].decision.device_class == failed_device_class:
            on_failed_after += 1
        tokens.append(_step_token(seed, tokens))
        i += 1
    var matched = _tokens_equal(tokens, control)
    var final_outcome = REPLAN_OK
    var match_word = String("match")
    if not matched:
        final_outcome = REPLAN_FAILED_CLOSED
        match_word = String("DO NOT match")
    return DrillResult(
        final_outcome,
        tokens^,
        control^,
        matched,
        moved,
        on_failed_after,
        audit^,
        String("drill completed on the re-planned survivors; ")
        + String("final tokens ")
        + match_word
        + String(" the uninterrupted control exactly"),
    )


def replan_summary() -> String:
    """One-line re-planner summary (doctor-style rendering)."""
    return String(
        "A-103 mid-run device failure re-planning: remaining"
        " work re-planned onto survivors through the A-100"
        " planner on a survivor registry; committed prefix"
        " untouched, one re-plan per run, fail closed with"
        " state intact (extends A-079 to the planner level)"
    )
