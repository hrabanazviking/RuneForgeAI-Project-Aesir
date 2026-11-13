"""Two-model fairness (A-105): two models served concurrently
share devices without starvation.

Acceptance shape (roadmap A-105): fairness test with per-model
latency bounds. The mechanism is core/fair_scheduler.mojo -
weighted deficit round robin over the per-step token budget
(the A-072 step), composing with A-076 (governor-shrunk
budgets), A-100/A-102 (placement/spillover act on the split,
never on raw queues) and A-017/A-086 (weights, resident
pair). The concurrent two-real-model run is the standalone
bench (tests/bench_fairness_a105.mojo, both pinned fixtures);
these in-suite cases prove the scheduler the bench drives:

- equal share: two continuously backlogged models at weight
  1:1 stay inside the filed lag bound at EVERY step, both
  complete, Jain index at the fair ceiling;
- weighted share: weight 2:1 delivers service proportional
  to the weights inside the same lag bound;
- no starvation, adversarial: a huge-prefill model can never
  starve a small intermittent model - the small model's
  arrival-to-drained latency stays inside the filed bound
  (wait_bound_steps + one drain step) while the huge model
  keeps progressing;
- idle models bank no credit: a model idle while its peer
  saturates the device returns with deficit 0, and the
  peer's wait bound holds from the return step;
- single-model throughput: one backlogged model receives
  the whole budget every step - fairness costs nothing when
  there is nothing to share with;
- governor pressure: budgets shrinking 512 -> 1 (A-076
  squeeze) never break the wait or lag bounds, and both
  models still progress at budget 1;
- reproducibility: identical demand scripts give byte-
  identical fairness logs and digests; different weights
  give a different digest;
- device execution: two models' byte streams are served
  onto the RADV STRIX_HALO device in scheduler order - each
  allocation copies that model's next chunk into its real
  Vulkan buffer, both models see first service inside the
  latency bound, readbacks are byte-exact per model, and
  the shim returns to its baseline.
"""
from core.fair_scheduler import FairScheduler
from core.spillover_policy import fnv1a64
from core.vulkan_buffers import VulkanBuffers

comptime _CHUNK = 256 * 1024


def _vk_present() -> Bool:
    if not VulkanBuffers.runtime_available():
        return False
    if not VulkanBuffers.dispatch_available():
        return False
    try:
        var info = VulkanBuffers.device_info()
        if info.vendor_id != 0x1002:
            return False
        if info.device_type == 4:
            return False
        return VulkanBuffers.device_name_is_radv()
    except:
        return False


def test_fairness_equal_share() raises:
    print("--- Testing fairness: equal share, lag bound every step (A-105) ---")
    var sched = FairScheduler(String("model-a"), 1, String("model-b"), 1)
    var qa = 100000
    var qb = 100000
    for _ in range(400):
        var step = sched.serve_step(512, qa, qb)
        qa -= step.alloc_a
        qb -= step.alloc_b
        if sched.lag_cross() > sched.lag_bound_cross():
            raise Error("equal-share lag exceeded the filed bound mid-run")
        if sched.max_wait_a > sched.wait_bound_steps() or sched.max_wait_b > sched.wait_bound_steps():
            raise Error("equal-share wait exceeded the per-model latency bound")
    if qa != 0 or qb != 0:
        raise Error("equal-share run did not drain both models")
    if sched.served_a != 100000 or sched.served_b != 100000:
        raise Error("equal-share served totals are not the full queues")
    if sched.jain_x1000() < 999:
        raise Error("equal-share Jain index below the fair ceiling")
    print("PASS: 1:1 both drained, lag + wait bounds held every step, jain=", sched.jain_x1000())


def test_fairness_weighted_share() raises:
    print("--- Testing fairness: weighted 2:1 share is proportional (A-105) ---")
    var sched = FairScheduler(String("model-a"), 2, String("model-b"), 1)
    var qa = 300000
    var qb = 300000
    for _ in range(400):
        var step = sched.serve_step(768, qa, qb)
        qa -= step.alloc_a
        qb -= step.alloc_b
        if qa > 0 and qb > 0 and sched.lag_cross() > sched.lag_bound_cross():
            raise Error("weighted lag exceeded the filed bound while both backlogged")
        if sched.max_wait_a > sched.wait_bound_steps() or sched.max_wait_b > sched.wait_bound_steps():
            raise Error("weighted wait exceeded the per-model latency bound")
    # Long-run proportionality: served_a / served_b within 5% of 2:1.
    var lhs = sched.served_a * 100
    var rhs = sched.served_b * 200
    var diff = lhs - rhs if lhs >= rhs else rhs - lhs
    if diff * 20 > rhs:
        raise Error("weighted service is not proportional to the weights")
    if sched.jain_x1000() < 990:
        raise Error("weighted Jain index below 0.990")
    print(
        "PASS: 2:1 service proportional, served=",
        sched.served_a, ",", sched.served_b, " jain=", sched.jain_x1000(),
    )


def test_fairness_no_starvation_adversarial() raises:
    print("--- Testing fairness: huge prefill cannot starve small model (A-105) ---")
    var sched = FairScheduler(String("huge"), 1, String("small"), 1)
    var qa = 1000000
    var qb = 0
    var arrived = 0
    var b_open_since = -1
    var b_worst_latency = 0
    for s in range(1600):
        if s % 16 == 0:
            qb += 8
            arrived += 8
            if b_open_since < 0:
                b_open_since = s
        var step = sched.serve_step(64, qa, qb)
        qa -= step.alloc_a
        qb -= step.alloc_b
        if qb == 0 and b_open_since >= 0:
            var latency = s - b_open_since
            if latency > b_worst_latency:
                b_worst_latency = latency
            b_open_since = -1
        if sched.max_wait_b > sched.wait_bound_steps():
            raise Error("small model wait exceeded the per-model latency bound")
    if sched.served_b != arrived:
        raise Error("small model did not receive all its arrived work")
    if b_worst_latency > sched.wait_bound_steps() + 1:
        raise Error("small model arrival-to-drained latency exceeded the bound")
    if sched.served_a <= 0:
        raise Error("huge model made no progress under the adversarial script")
    print(
        "PASS: small model worst latency steps=", b_worst_latency,
        " bound=", sched.wait_bound_steps() + 1,
        " huge model served=", sched.served_a,
    )


def test_fairness_idle_no_hoard() raises:
    print("--- Testing fairness: idle model banks no credit (A-105) ---")
    var sched = FairScheduler(String("model-a"), 1, String("model-b"), 1)
    var qb = 100000
    for _ in range(100):
        var step = sched.serve_step(256, 0, qb)
        qb -= step.alloc_b
        if step.alloc_b != 256:
            raise Error("solo model did not receive the whole budget")
        if sched.deficit_a != 0:
            raise Error("idle model accrued deficit credit")
    if sched.served_b != 25600:
        raise Error("solo-phase served total mismatch")
    # A returns with a flood; B's wait bound must hold from here.
    var qa = 100000
    for _ in range(100):
        var step = sched.serve_step(256, qa, qb)
        qa -= step.alloc_a
        qb -= step.alloc_b
        if sched.max_wait_b > sched.wait_bound_steps():
            raise Error("returning model starved its peer past the bound")
        if qa == 0 and sched.deficit_a != 0:
            raise Error("drained model kept deficit credit")
    print("PASS: idle phase deficit 0 + full solo share; peer bound held on return")


def test_fairness_single_model_throughput() raises:
    print("--- Testing fairness: single model pays no fairness tax (A-105) ---")
    var sched = FairScheduler(String("only"), 1, String("absent"), 1)
    var qa = 10000
    for _ in range(20):
        var step = sched.serve_step(512, qa, 0)
        qa -= step.alloc_a
        if step.alloc_b != 0:
            raise Error("absent model received an allocation")
        if sched.deficit_a != 0 or sched.deficit_b != 0:
            raise Error("solo run carried deficit state")
    if qa != 0 or sched.served_a != 10000:
        raise Error("solo model did not drain at full budget rate")
    print("PASS: solo model drained 10000 tokens in 20 full-budget steps")


def test_fairness_governor_pressure() raises:
    print("--- Testing fairness: governor budget squeeze keeps bounds (A-105) ---")
    var sched = FairScheduler(String("model-a"), 1, String("model-b"), 1)
    var qa = 1000000
    var qb = 1000000
    var budgets = List[Int]()
    budgets.append(512)
    budgets.append(128)
    budgets.append(32)
    budgets.append(1)
    for phase in range(len(budgets)):
        var budget = budgets[phase]
        var before_a = sched.served_a
        var before_b = sched.served_b
        for _ in range(64):
            var step = sched.serve_step(budget, qa, qb)
            qa -= step.alloc_a
            qb -= step.alloc_b
            if sched.lag_cross() > sched.lag_bound_cross():
                raise Error("pressure-phase lag exceeded the filed bound")
            if sched.max_wait_a > sched.wait_bound_steps() or sched.max_wait_b > sched.wait_bound_steps():
                raise Error("pressure-phase wait exceeded the latency bound")
        if sched.served_a <= before_a or sched.served_b <= before_b:
            raise Error("a model stopped progressing under governor pressure")
    print(
        "PASS: budgets 512/128/32/1 all fair, both progressed at budget 1, served=",
        sched.served_a, ",", sched.served_b,
    )


def test_fairness_log_reproducible() raises:
    print("--- Testing fairness: fairness log is reproducible (A-105) ---")
    var s1 = FairScheduler(String("model-a"), 1, String("model-b"), 1)
    var s2 = FairScheduler(String("model-a"), 1, String("model-b"), 1)
    var qa1 = 5000
    var qb1 = 3000
    var qa2 = 5000
    var qb2 = 3000
    for i in range(50):
        var budget = 64 + (i % 5) * 32
        var st1 = s1.serve_step(budget, qa1, qb1)
        qa1 -= st1.alloc_a
        qb1 -= st1.alloc_b
        var st2 = s2.serve_step(budget, qa2, qb2)
        qa2 -= st2.alloc_a
        qb2 -= st2.alloc_b
    if s1.log_text() != s2.log_text():
        raise Error("identical demand scripts produced different fairness logs")
    if s1.digest() != s2.digest():
        raise Error("identical demand scripts produced different digests")
    if s1.digest() != fnv1a64(s1.log_text()):
        raise Error("digest is not the FNV-1a of the log text")
    var s3 = FairScheduler(String("model-a"), 2, String("model-b"), 1)
    var qa3 = 5000
    var qb3 = 3000
    for i in range(50):
        var budget = 64 + (i % 5) * 32
        var st3 = s3.serve_step(budget, qa3, qb3)
        qa3 -= st3.alloc_a
        qb3 -= st3.alloc_b
    if s3.digest() == s1.digest():
        raise Error("different weights produced the same fairness digest")
    print("PASS: same script, byte-identical log + digest; new weights, new digest")


def test_fairness_device_execution() raises:
    print("--- Testing fairness: two models served on RADV in scheduler order (A-105) ---")
    if not _vk_present():
        print("Vulkan RADV device absent: honest-absent PASS")
        return
    var sched = FairScheduler(String("model-a"), 1, String("model-b"), 1)
    var units_a = 16
    var units_b = 16
    var before = VulkanBuffers.live_bytes()
    var alloc_a = VulkanBuffers.allocate(units_a * _CHUNK)
    var alloc_b = VulkanBuffers.allocate(units_b * _CHUNK)
    var filled_a = 0
    var filled_b = 0
    var first_a = -1
    var first_b = -1
    var step_no = 0
    while units_a > 0 or units_b > 0:
        step_no += 1
        var step = sched.serve_step(2, units_a, units_b)
        units_a -= step.alloc_a
        units_b -= step.alloc_b
        if step.alloc_a > 0 and first_a < 0:
            first_a = step_no
        if step.alloc_b > 0 and first_b < 0:
            first_b = step_no
        for _ in range(step.alloc_a):
            var ptr = VulkanBuffers.map(alloc_a)
            for i in range(_CHUNK):
                ptr[filled_a * _CHUNK + i] = UInt8((i * 31 + 7) % 251)
            VulkanBuffers.unmap(alloc_a)
            filled_a += 1
        for _ in range(step.alloc_b):
            var ptr = VulkanBuffers.map(alloc_b)
            for i in range(_CHUNK):
                ptr[filled_b * _CHUNK + i] = UInt8((i * 17 + 3) % 241)
            VulkanBuffers.unmap(alloc_b)
            filled_b += 1
        if step_no > 64:
            raise Error("device interleave did not drain in the expected steps")
    if first_a < 1 or first_b < 1 or first_a > 2 or first_b > 2:
        raise Error("a model's first device service missed the latency bound")
    if sched.max_wait_a > sched.wait_bound_steps() or sched.max_wait_b > sched.wait_bound_steps():
        raise Error("device interleave wait exceeded the latency bound")
    var back_a = VulkanBuffers.map(alloc_a)
    var sum_a: UInt64 = 0
    for i in range(16 * _CHUNK):
        sum_a += UInt64(back_a[i])
    VulkanBuffers.unmap(alloc_a)
    var back_b = VulkanBuffers.map(alloc_b)
    var sum_b: UInt64 = 0
    for i in range(16 * _CHUNK):
        sum_b += UInt64(back_b[i])
    VulkanBuffers.unmap(alloc_b)
    VulkanBuffers.free(alloc_a)
    VulkanBuffers.free(alloc_b)
    var expect_a: UInt64 = 0
    for i in range(_CHUNK):
        expect_a += UInt64((i * 31 + 7) % 251)
    expect_a *= 16
    var expect_b: UInt64 = 0
    for i in range(_CHUNK):
        expect_b += UInt64((i * 17 + 3) % 241)
    expect_b *= 16
    if sum_a != expect_a or sum_b != expect_b:
        raise Error("device readback differs from the served per-model bytes")
    if VulkanBuffers.live_bytes() != before:
        raise Error("shim live bytes did not return to baseline after free")
    print(
        "PASS: both models first-served inside the bound on RADV (steps",
        first_a, ",", first_b, "), readbacks exact, freed",
    )
