# tests/test_gpu_winner_a086.mojo
# A-086: Winner integration (preparatory). The A-085 bake-off
# verdict is NOT banked yet, so these cases prove the scaffolding
# in every state it must hold: pending (no winner declared, legacy
# HIP -> Vulkan behaviour unchanged), HIP wins, Vulkan wins,
# invalid verdicts fail closed, and a probe-only loser is never
# placed or selected. Fake registries throughout; nothing here
# declares a real winner.

from core.backend_registry import (
    GPU_ROLE_FIRST_CLASS,
    GPU_ROLE_PROBE_ONLY,
    GPU_ROLE_UNDECIDED,
    BackendRegistry,
    RawBackendProbe,
    build_backend_registry,
    gpu_first_class_runtime,
    gpu_probe_only_runtime,
)
from core.gpu_winner import (
    apply_bakeoff_verdict,
    bakeoff_verdict_decided,
    bakeoff_verdict_from_registry,
    bakeoff_verdict_pending,
    gpu_winner_lines,
    preferred_gpu_runtime,
    validate_gpu_roles,
)
from core.device_policy import (
    DEVICE_CPU,
    DEVICE_GPU,
    OP_MATMUL,
    default_placement_policy,
)
from core.backend_config import resolve_backend_selection


def _fake(found: Bool, device: String) -> RawBackendProbe:
    return RawBackendProbe(found, False, "1", device, "fake probe")


def _all_present() -> BackendRegistry:
    return build_backend_registry(
        _fake(True, "hip-dev"),
        _fake(True, "vk-dev"),
        _fake(True, "xrt-dev"),
        _fake(True, "cpu-dev"),
    )


def _raises_decided(winner: String, source: String) -> Bool:
    try:
        _ = bakeoff_verdict_decided(winner, source)
        return False
    except:
        return True


def test_gpu_winner_pending_state() raises:
    var reg = _all_present()
    var verdict = bakeoff_verdict_pending()
    if not verdict.is_pending() or verdict.is_decided():
        raise Error("pending verdict mis-states its state")
    if verdict.winner != "" or verdict.loser != "":
        raise Error("pending verdict names a winner or loser")
    validate_gpu_roles(reg)
    if gpu_first_class_runtime(reg) != "" or gpu_probe_only_runtime(reg) != "":
        raise Error("pending registry already carries a GPU role")
    if reg.hip.gpu_role != GPU_ROLE_UNDECIDED:
        raise Error("pending HIP role is not undecided")
    # Legacy behaviour is unchanged while pending.
    if preferred_gpu_runtime(reg, verdict) != "HIP":
        raise Error("pending preference lost the standing HIP order")
    var decision = default_placement_policy().decide(reg, String(OP_MATMUL))
    if decision.device_class != DEVICE_GPU or decision.backend != "HIP":
        raise Error("pending placement changed: " + decision.line())
    var auto = resolve_backend_selection("auto", reg, False)
    if auto.backend != "HIP" or "bake-off" in auto.reason:
        raise Error("pending auto resolution changed: " + auto.line())
    var lines = gpu_winner_lines(reg, verdict)
    if len(lines) != 3 or "pending" not in lines[0]:
        raise Error("pending doctor lines do not state pending")
    if "no A-085 verdict banked" not in verdict.line():
        raise Error("pending line does not name the missing verdict")
    var derived = bakeoff_verdict_from_registry(reg)
    if not derived.is_pending():
        raise Error("undecided registry derived a decided verdict")


def test_gpu_winner_hip_wins() raises:
    var verdict = bakeoff_verdict_decided(
        "HIP", "A-085 verdict doc (test fixture)"
    )
    var reg = apply_bakeoff_verdict(_all_present(), verdict)
    validate_gpu_roles(reg)
    if reg.hip.gpu_role != GPU_ROLE_FIRST_CLASS:
        raise Error("HIP winner was not made first-class")
    if reg.vulkan.gpu_role != GPU_ROLE_PROBE_ONLY:
        raise Error("Vulkan loser was not made probe-only")
    if reg.xrt.gpu_role != GPU_ROLE_UNDECIDED or reg.cpu.gpu_role != GPU_ROLE_UNDECIDED:
        raise Error("verdict leaked a GPU role onto XRT/CPU")
    if "gpu role: first-class" not in reg.hip.line():
        raise Error("registry line does not show HIP first-class")
    if "gpu role: probe-only" not in reg.vulkan.line():
        raise Error("registry line does not show Vulkan probe-only")
    if preferred_gpu_runtime(reg, verdict) != "HIP":
        raise Error("HIP-wins preference is not HIP")
    var decision = default_placement_policy().decide(reg, String(OP_MATMUL))
    if decision.backend != "HIP" or "first-class" not in decision.reason:
        raise Error("HIP-wins placement wrong: " + decision.line())
    var auto = resolve_backend_selection("auto", reg, False)
    if auto.backend != "HIP" or "first-class" not in auto.reason:
        raise Error("HIP-wins auto wrong: " + auto.line())
    var hip = resolve_backend_selection("hip", reg, False)
    if hip.backend != "HIP":
        raise Error("explicit hip did not resolve to the winner")
    var vk_blocked = False
    try:
        _ = resolve_backend_selection("vulkan", reg, False)
    except error:
        vk_blocked = True
        if "probe-only" not in String(error):
            raise Error("explicit vulkan error lost probe-only: " + String(error))
    if not vk_blocked:
        raise Error("explicit vulkan resolved to the probe-only loser")
    var derived = bakeoff_verdict_from_registry(reg)
    if derived.winner != "HIP" or derived.loser != "Vulkan":
        raise Error("HIP-wins registry did not round-trip its verdict")
    var lines = gpu_winner_lines(reg, verdict)
    if "first-class" not in lines[1] or "probe-only" not in lines[2]:
        raise Error("HIP-wins doctor lines lost a role")


def test_gpu_winner_vulkan_wins() raises:
    var verdict = bakeoff_verdict_decided(
        "Vulkan", "A-085 verdict doc (test fixture)"
    )
    var reg = apply_bakeoff_verdict(_all_present(), verdict)
    validate_gpu_roles(reg)
    if reg.vulkan.gpu_role != GPU_ROLE_FIRST_CLASS:
        raise Error("Vulkan winner was not made first-class")
    if reg.hip.gpu_role != GPU_ROLE_PROBE_ONLY:
        raise Error("HIP loser was not made probe-only")
    if preferred_gpu_runtime(reg, verdict) != "Vulkan":
        raise Error("Vulkan-wins preference is not Vulkan")
    # The standing HIP preference is overridden by the verdict.
    var decision = default_placement_policy().decide(reg, String(OP_MATMUL))
    if decision.backend != "Vulkan" or "first-class" not in decision.reason:
        raise Error("Vulkan-wins placement wrong: " + decision.line())
    var auto = resolve_backend_selection("auto", reg, False)
    if auto.backend != "Vulkan" or "first-class" not in auto.reason:
        raise Error("Vulkan-wins auto wrong: " + auto.line())
    var vk = resolve_backend_selection("vulkan", reg, False)
    if vk.backend != "Vulkan":
        raise Error("explicit vulkan did not resolve to the winner")
    var hip_blocked = False
    try:
        _ = resolve_backend_selection("hip", reg, False)
    except error:
        hip_blocked = True
        if "probe-only" not in String(error):
            raise Error("explicit hip error lost probe-only: " + String(error))
    if not hip_blocked:
        raise Error("explicit hip resolved to the probe-only loser")
    var derived = bakeoff_verdict_from_registry(reg)
    if derived.winner != "Vulkan" or derived.loser != "HIP":
        raise Error("Vulkan-wins registry did not round-trip")
    var lines = gpu_winner_lines(reg, verdict)
    if "Vulkan: first-class" not in lines[1] or "HIP: probe-only" not in lines[2]:
        raise Error("Vulkan-wins doctor lines lost a role")


def test_gpu_winner_invalid_verdicts_fail_closed() raises:
    if not _raises_decided("CPU", "some doc"):
        raise Error("CPU was accepted as a bake-off winner")
    if not _raises_decided("XRT", "some doc"):
        raise Error("XRT was accepted as a bake-off winner")
    if not _raises_decided("hip", "some doc"):
        raise Error("lowercase hip was accepted as a winner name")
    if not _raises_decided("", "some doc"):
        raise Error("empty winner was accepted")
    if not _raises_decided("HIP", ""):
        raise Error("sourceless HIP verdict was accepted")
    # Inconsistent hand-set roles are refused by validation.
    var both_first = _all_present()
    both_first.hip.gpu_role = GPU_ROLE_FIRST_CLASS
    both_first.vulkan.gpu_role = GPU_ROLE_FIRST_CLASS
    var raised = False
    try:
        validate_gpu_roles(both_first)
    except:
        raised = True
    if not raised:
        raise Error("two first-class GPU backends validated")
    var orphan_probe = _all_present()
    orphan_probe.vulkan.gpu_role = GPU_ROLE_PROBE_ONLY
    raised = False
    try:
        validate_gpu_roles(orphan_probe)
    except:
        raised = True
    if not raised:
        raise Error("probe-only without a winner validated")
    var npu_role = _all_present()
    npu_role.xrt.gpu_role = GPU_ROLE_FIRST_CLASS
    raised = False
    try:
        validate_gpu_roles(npu_role)
    except:
        raised = True
    if not raised:
        raise Error("a GPU role on XRT validated")


def test_gpu_winner_probe_only_never_placed() raises:
    # Vulkan wins but is absent; HIP is present but probe-only.
    var reg = apply_bakeoff_verdict(
        build_backend_registry(
            _fake(True, "hip-dev"),
            _fake(False, ""),
            _fake(True, "xrt-dev"),
            _fake(True, "cpu-dev"),
        ),
        bakeoff_verdict_decided("Vulkan", "A-085 verdict doc (test fixture)"),
    )
    var verdict = bakeoff_verdict_from_registry(reg)
    if preferred_gpu_runtime(reg, verdict) != "":
        raise Error("probe-only loser was preferred for execution")
    var decision = default_placement_policy().decide(reg, String(OP_MATMUL))
    if decision.device_class != DEVICE_CPU or decision.backend != "CPU":
        raise Error("probe-only loser was placed: " + decision.line())
    if "probe-only" not in decision.reason:
        raise Error("spillover reason lost the probe-only skip")
    var auto = resolve_backend_selection("auto", reg, False)
    if auto.backend != "CPU" or "probe-only" not in auto.reason:
        raise Error("auto resolved to the probe-only loser: " + auto.line())
    var hip_blocked = False
    try:
        _ = resolve_backend_selection("hip", reg, False)
    except error:
        hip_blocked = True
        if "probe-only" not in String(error):
            raise Error("explicit hip error lost probe-only")
    if not hip_blocked:
        raise Error("explicit hip resolved despite probe-only role")


def test_gpu_winner_determinism_and_clear() raises:
    var verdict = bakeoff_verdict_decided(
        "HIP", "A-085 verdict doc (test fixture)"
    )
    var first = apply_bakeoff_verdict(_all_present(), verdict)
    var second = apply_bakeoff_verdict(_all_present(), verdict)
    var first_lines = gpu_winner_lines(first, verdict)
    var second_lines = gpu_winner_lines(second, verdict)
    if len(first_lines) != len(second_lines):
        raise Error("winner lines are not deterministic in count")
    for i in range(len(first_lines)):
        if first_lines[i] != second_lines[i]:
            raise Error("winner lines are not deterministic")
    var cleared = apply_bakeoff_verdict(first, bakeoff_verdict_pending())
    if gpu_first_class_runtime(cleared) != "":
        raise Error("pending application did not clear the winner")
    if gpu_probe_only_runtime(cleared) != "":
        raise Error("pending application did not clear probe-only")
    if not bakeoff_verdict_from_registry(cleared).is_pending():
        raise Error("cleared registry did not derive pending")
