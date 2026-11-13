# core/backend_config.mojo
# A-032: Backend config surface.
# One selection vocabulary -- auto / cpu / vulkan / hip / npu -- shared
# by the config file (hardware.acceleration_backend) and the CLI
# (--accel), resolved against the A-009 backend registry under the
# A-017 honesty rules. Resolution is pure and deterministic: same
# selection + same registry in, same resolution (or same named
# error) out, so it is unit-testable with fake registries.
# Fail-closed law (roadmap acceptance): requesting a backend that is
# unavailable raises a clear named error; the requested backend is
# NEVER silently substituted -- in particular an unavailable GPU or
# NPU request never falls back to CPU while being presented as the
# requested backend. Only the explicit `auto` selection substitutes,
# and its resolution records every skip it made.
# Honesty rules: selection is intent, not execution. Resolving `npu`
# requires NPU execution to be proven (the A-017
# npu_execution_proven flag); XRT presence alone never resolves `npu`
# and never lets `auto` land on the NPU. A resolution line always
# says selection only -- execution is claimed only by per-backend
# execution evidence, never by this surface.

from core.backend_registry import (
    BACKEND_DEGRADED,
    BackendCapability,
    BackendRegistry,
)

comptime BACKEND_SELECTION_AUTO = "auto"
comptime BACKEND_SELECTION_CPU = "cpu"
comptime BACKEND_SELECTION_VULKAN = "vulkan"
comptime BACKEND_SELECTION_HIP = "hip"
comptime BACKEND_SELECTION_NPU = "npu"


def backend_selection_values() -> List[String]:
    """The A-032 selection vocabulary, in canonical order."""
    var values = List[String]()
    values.append(String(BACKEND_SELECTION_AUTO))
    values.append(String(BACKEND_SELECTION_CPU))
    values.append(String(BACKEND_SELECTION_VULKAN))
    values.append(String(BACKEND_SELECTION_HIP))
    values.append(String(BACKEND_SELECTION_NPU))
    return values^


def is_backend_selection(value: String) -> Bool:
    """Exact membership in the A-032 vocabulary (no normalization)."""
    return (
        value == BACKEND_SELECTION_AUTO
        or value == BACKEND_SELECTION_CPU
        or value == BACKEND_SELECTION_VULKAN
        or value == BACKEND_SELECTION_HIP
        or value == BACKEND_SELECTION_NPU
    )


def normalize_backend_selection(value: String) raises -> String:
    """Trim + lowercase a raw selection, then validate it.

    Anything outside auto/cpu/vulkan/hip/npu -- including legacy or
    foreign names such as cuda, metal, amd, hailo10h and max, which
    are not Z13 backends on this surface -- raises a named error
    listing the valid set. Case and surrounding whitespace in user
    input are forgiven; the stored selection is the canonical form.
    """
    var normalized = String(value.strip().lower())
    if not is_backend_selection(normalized):
        raise Error(
            "invalid backend selection '"
            + value
            + "': must be one of auto, cpu, vulkan, hip, npu"
        )
    return normalized


def apply_backend_override(
    file_value: String, cli_value: String, cli_was_set: Bool
) raises -> String:
    """Config + CLI precedence for the backend surface.

    An explicitly set CLI selection wins over the config file; the
    file value wins over the built-in default (auto). Only the
    winning value is validated and returned, in canonical form.
    """
    if cli_was_set:
        return normalize_backend_selection(cli_value)
    if file_value != "":
        return normalize_backend_selection(file_value)
    return String(BACKEND_SELECTION_AUTO)


struct BackendResolution(Copyable, ImplicitlyCopyable):
    """One resolved selection with its full reasoning.

    backend is the A-009 registry runtime name (CPU / HIP / Vulkan /
    XRT). This record states selection only; it is never evidence
    that the backend executed anything.
    """

    var requested: String
    var backend: String
    var status_name: String
    var detail: String
    var reason: String

    def __init__(
        out self,
        requested: String,
        backend: String,
        status_name: String,
        detail: String,
        reason: String,
    ):
        self.requested = requested
        self.backend = backend
        self.status_name = status_name
        self.detail = detail
        self.reason = reason

    def line(self) -> String:
        var text = (
            "backend selection: requested '"
            + self.requested
            + "' resolved to "
            + self.backend
            + " ("
            + self.status_name
        )
        if self.detail != "":
            text += "; " + self.detail
        text += ")"
        if self.reason != "":
            text += " -- " + self.reason
        text += " [selection only; execution not claimed]"
        return text


def _resolved(
    requested: String, cap: BackendCapability, reason: String
) -> BackendResolution:
    var detail = cap.detail
    if cap.device != "":
        detail = "device " + cap.device + "; " + cap.detail
    var full_reason = reason
    if cap.status == BACKEND_DEGRADED:
        if full_reason != "":
            full_reason += "; "
        full_reason += "registry record is degraded"
    return BackendResolution(
        requested, cap.runtime, cap.status_name(), detail, full_reason
    )


def _unavailable_error(requested: String, cap: BackendCapability) -> String:
    return (
        "backend '"
        + requested
        + "' unavailable: "
        + cap.runtime
        + " "
        + cap.status_name()
        + " ("
        + cap.detail
        + "); no fallback applied -- the requested backend was not"
        + " substituted"
    )


def _probe_only_error(requested: String, cap: BackendCapability) -> String:
    return (
        "backend '"
        + requested
        + "' unavailable: "
        + cap.runtime
        + " "
        + cap.status_name()
        + " but probe-only (bake-off loser, A-086) -- probe-only"
        + " backends are probed, not selected for execution; no"
        + " fallback applied -- the requested backend was not"
        + " substituted"
    )


def resolve_backend_selection(
    selection: String,
    registry: BackendRegistry,
    npu_execution_proven: Bool,
) raises -> BackendResolution:
    """Resolve one selection against the A-009 registry, fail-closed.

    Explicit cpu/vulkan/hip resolve only to that backend, and only
    when its registry record is present or degraded; absent raises
    the named unavailable error. Explicit npu additionally requires
    npu_execution_proven: XRT presence without proven execution
    raises the honesty error, never a resolution. `auto` follows the
    A-017 accelerator-first order (NPU, then HIP, then Vulkan, then
    CPU), skipping the NPU while execution is unproven and recording
    every skip in the resolution reason; it raises only when no
    backend at all is available.
    """
    var requested = normalize_backend_selection(selection)
    if requested == BACKEND_SELECTION_CPU:
        if not registry.cpu.is_available():
            raise Error(_unavailable_error(requested, registry.cpu))
        return _resolved(requested, registry.cpu, String("explicit cpu selection"))
    if requested == BACKEND_SELECTION_VULKAN:
        if not registry.vulkan.is_available():
            raise Error(_unavailable_error(requested, registry.vulkan))
        if registry.vulkan.is_probe_only_gpu():
            raise Error(_probe_only_error(requested, registry.vulkan))
        return _resolved(
            requested, registry.vulkan, String("explicit vulkan selection")
        )
    if requested == BACKEND_SELECTION_HIP:
        if not registry.hip.is_available():
            raise Error(_unavailable_error(requested, registry.hip))
        if registry.hip.is_probe_only_gpu():
            raise Error(_probe_only_error(requested, registry.hip))
        return _resolved(requested, registry.hip, String("explicit hip selection"))
    if requested == BACKEND_SELECTION_NPU:
        if not registry.xrt.is_available():
            raise Error(_unavailable_error(requested, registry.xrt))
        if not npu_execution_proven:
            raise Error(
                "backend 'npu' unavailable: XRT "
                + registry.xrt.status_name()
                + " ("
                + registry.xrt.detail
                + ") but NPU execution is not proven -- XRT presence"
                + " only, no NPU execution is claimed; no fallback"
                + " applied -- the requested backend was not substituted"
            )
        return _resolved(
            requested,
            registry.xrt,
            String("explicit npu selection; NPU execution proven"),
        )
    # auto: accelerator-first, NPU -> HIP -> Vulkan -> CPU (A-017 order
    # with the GPU class preferring HIP, as in the placement policy).
    var notes = String("")
    if registry.xrt.is_available() and npu_execution_proven:
        return _resolved(
            requested,
            registry.xrt,
            notes + String("auto: NPU execution proven"),
        )
    if registry.xrt.is_available():
        notes += (
            "skip NPU (XRT "
            + registry.xrt.status_name()
            + " but NPU execution not proven -- presence only). "
        )
    else:
        notes += "skip NPU (XRT " + registry.xrt.status_name() + "). "
    # A-086: a decided bake-off verdict governs the GPU class --
    # auto resolves only to the first-class winner; the probe-only
    # loser is skipped with its reason logged, never resolved.
    if registry.hip.is_first_class_gpu() or registry.vulkan.is_first_class_gpu():
        if registry.hip.is_first_class_gpu():
            if registry.hip.is_available():
                return _resolved(requested, registry.hip, notes + String("auto: HIP GPU backend available (bake-off winner, first-class)"))
            notes += "skip HIP (" + registry.hip.status_name() + ", bake-off winner unavailable). "
            notes += "skip Vulkan (probe-only, bake-off loser). "
        else:
            if registry.vulkan.is_available():
                return _resolved(requested, registry.vulkan, notes + String("auto: Vulkan GPU backend available (bake-off winner, first-class)"))
            notes += "skip Vulkan (" + registry.vulkan.status_name() + ", bake-off winner unavailable). "
            notes += "skip HIP (probe-only, bake-off loser). "
    elif registry.hip.is_available():
        return _resolved(requested, registry.hip, notes + String("auto: HIP GPU backend available"))
    else:
        notes += "skip HIP (" + registry.hip.status_name() + "). "
        if registry.vulkan.is_available():
            return _resolved(
                requested,
                registry.vulkan,
                notes + String("auto: Vulkan GPU backend available"),
            )
        notes += "skip Vulkan (" + registry.vulkan.status_name() + "). "
    if registry.cpu.is_available():
        return _resolved(
            requested,
            registry.cpu,
            notes + String("auto: CPU spillover -- no accelerator could take this run"),
        )
    raise Error(
        "backend 'auto' could not resolve: no backend available (HIP "
        + registry.hip.status_name()
        + ", Vulkan "
        + registry.vulkan.status_name()
        + ", XRT "
        + registry.xrt.status_name()
        + ", CPU "
        + registry.cpu.status_name()
        + "); no fallback applied"
    )
