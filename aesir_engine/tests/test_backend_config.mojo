# tests/test_backend_config.mojo
# A-032: backend config surface -- the auto/cpu/vulkan/hip/npu
# selection vocabulary, config+CLI precedence, and fail-closed
# resolution against fake A-009 registries (nothing is uninstalled).
# Honesty core: XRT presence alone never resolves `npu`, and an
# unavailable explicit request never silently becomes CPU.

from core.backend_config import (
    apply_backend_override,
    backend_selection_values,
    is_backend_selection,
    normalize_backend_selection,
    resolve_backend_selection,
)
from core.backend_registry import (
    RawBackendProbe,
    BackendRegistry,
    build_backend_registry,
)
from config import parse_config_json
from cli.options import parse_cli_options


def _fake(found: Bool, device: String) -> RawBackendProbe:
    return RawBackendProbe(found, False, "1", device, "fake probe")


def _fake_degraded(device: String) -> RawBackendProbe:
    return RawBackendProbe(True, True, "1", device, "fake degraded probe")


def _all_present() -> BackendRegistry:
    return build_backend_registry(
        _fake(True, "hip-dev"),
        _fake(True, "vk-dev"),
        _fake(True, "xrt-dev"),
        _fake(True, "cpu-dev"),
    )


def _none_present() -> BackendRegistry:
    return build_backend_registry(
        _fake(False, ""), _fake(False, ""), _fake(False, ""), _fake(False, "")
    )


def _expect_error(requested: String, registry: BackendRegistry, proven: Bool) -> String:
    try:
        var resolution = resolve_backend_selection(requested, registry, proven)
        return String("NO-ERROR: resolved to ") + resolution.backend
    except error:
        return String(error)


def test_backend_config_vocabulary() raises:
    var values = backend_selection_values()
    if len(values) != 5:
        raise Error("backend selection vocabulary does not have 5 values")
    for expected in ["auto", "cpu", "vulkan", "hip", "npu"]:
        if not is_backend_selection(expected):
            raise Error("vocabulary lost selection: " + expected)
        if normalize_backend_selection(expected) != expected:
            raise Error("canonical selection did not normalize to itself")
    if normalize_backend_selection(" HIP ") != "hip":
        raise Error("selection normalization did not trim/lowercase")
    if normalize_backend_selection("Vulkan") != "vulkan":
        raise Error("selection normalization is not case-insensitive")
    for rejected in ["cuda", "metal", "amd", "hailo10h", "max", "gpu", "xrt", ""]:
        if is_backend_selection(rejected):
            raise Error("non-Z13 name accepted as a selection: " + rejected)
        var raised = False
        try:
            _ = normalize_backend_selection(rejected)
        except error:
            raised = True
            if "must be one of auto, cpu, vulkan, hip, npu" not in String(error):
                raise Error("invalid-selection error did not list the valid set")
        if not raised:
            raise Error("invalid selection was not rejected: " + rejected)


def test_backend_config_file_and_cli_surface() raises:
    # Config file: each Z13 selection parses; foreign names rejected.
    for value in ["auto", "cpu", "vulkan", "hip", "npu"]:
        var config = parse_config_json(
            String('{\"hardware\": {\"acceleration_backend\": \"')
            + value
            + String('\"}}')
        )
        if config.acceleration_backend != value:
            raise Error("config file lost backend selection: " + value)
    var rejected = False
    try:
        _ = parse_config_json(
            String('{\"hardware\": {\"acceleration_backend\": \"tpu\"}}')
        )
    except error:
        rejected = True
        if "invalid acceleration_backend: tpu" not in String(error):
            raise Error("config rejection did not name the bad value")
    if not rejected:
        raise Error("config file accepted a foreign backend name")
    # CLI: --accel carries the same vocabulary through parse_cli_options.
    var cli = parse_cli_options([String("--accel"), String("vulkan")])
    if not cli.accel_was_set or cli.accel_backend != "vulkan":
        raise Error("CLI --accel did not carry the vulkan selection")
    var cli_rejected = False
    try:
        _ = parse_cli_options([String("--accel"), String("tpu")])
    except error:
        cli_rejected = True
        if "vulkan" not in String(error) or "hip" not in String(error):
            raise Error("CLI rejection did not list the Z13 selections")
    if not cli_rejected:
        raise Error("CLI accepted a foreign backend name")
    # Precedence: explicit CLI > config file > built-in auto default.
    if apply_backend_override("cpu", "hip", True) != "hip":
        raise Error("CLI selection did not override the config file")
    if apply_backend_override("vulkan", "", False) != "vulkan":
        raise Error("config file selection was not honoured")
    if apply_backend_override("", "", False) != "auto":
        raise Error("empty surface did not default to auto")


def test_backend_config_explicit_resolution() raises:
    var reg = _all_present()
    var cpu = resolve_backend_selection("cpu", reg, False)
    if cpu.backend != "CPU" or cpu.requested != "cpu":
        raise Error("explicit cpu did not resolve to CPU")
    var vulkan = resolve_backend_selection("vulkan", reg, False)
    if vulkan.backend != "Vulkan":
        raise Error("explicit vulkan did not resolve to Vulkan")
    var hip = resolve_backend_selection("hip", reg, False)
    if hip.backend != "HIP" or "selection only" not in hip.line():
        raise Error("explicit hip resolution lost its honesty marker")
    if "hip-dev" not in hip.line():
        raise Error("explicit hip resolution lost the device identity")
    # Degraded records still resolve, and the line says degraded.
    var degraded_reg = build_backend_registry(
        _fake_degraded("hip-dev"),
        _fake(True, "vk-dev"),
        _fake(True, "xrt-dev"),
        _fake(True, "cpu-dev"),
    )
    var degraded = resolve_backend_selection("hip", degraded_reg, False)
    if degraded.backend != "HIP" or degraded.status_name != "degraded":
        raise Error("degraded HIP did not resolve as degraded")
    if "degraded" not in degraded.line():
        raise Error("degraded resolution line did not disclose degraded")


def test_backend_config_absent_fail_closed() raises:
    # Each explicit accelerator request against an all-absent registry
    # raises a named error; nothing resolves, nothing substitutes CPU.
    var reg = _none_present()
    for requested in ["vulkan", "hip", "npu"]:
        var message = _expect_error(requested, reg, False)
        if not message.startswith("backend '"):
            raise Error("absent request did not fail closed: " + message)
        if requested not in message or "unavailable" not in message:
            raise Error("absent error did not name request + unavailable")
        if "no fallback applied" not in message:
            raise Error("absent error did not state no-fallback")
        if "absent" not in message or "fake probe" not in message:
            raise Error("absent error lost the registry status/detail")
    var cpu_message = _expect_error("cpu", reg, False)
    if "backend 'cpu' unavailable" not in cpu_message:
        raise Error("absent cpu did not fail closed by name")
    var auto_message = _expect_error("auto", reg, False)
    if "could not resolve" not in auto_message:
        raise Error("auto with no backends did not fail closed")
    # Software-only Vulkan (llvmpipe) is absent as a GPU: fail closed.
    var software_reg = build_backend_registry(
        _fake(False, ""),
        _fake(True, "llvmpipe (LLVM 22.1.8, 256 bits)"),
        _fake(False, ""),
        _fake(True, "cpu-dev"),
    )
    var vk_message = _expect_error("vulkan", software_reg, False)
    if "backend 'vulkan' unavailable" not in vk_message:
        raise Error("software-only Vulkan did not fail closed")
    if "software" not in vk_message:
        raise Error("software-only Vulkan error lost the software reason")


def test_backend_config_npu_honesty_gate() raises:
    # XRT present + execution unproven: explicit npu raises the honesty
    # error (presence is not execution); auto skips the NPU entirely.
    var reg = _all_present()
    var message = _expect_error("npu", reg, False)
    if "NPU execution is not proven" not in message:
        raise Error("unproven npu request did not raise the honesty error")
    if "no NPU execution is claimed" not in message:
        raise Error("honesty error did not disclaim NPU execution")
    if "no fallback applied" not in message:
        raise Error("honesty error did not state no-fallback")
    var auto = resolve_backend_selection("auto", reg, False)
    if auto.backend == "XRT":
        raise Error("auto landed on the NPU from XRT presence alone")
    if "skip NPU" not in auto.reason or "presence only" not in auto.reason:
        raise Error("auto did not log the presence-only NPU skip")
    # With execution proven (flag set by an execution slice), npu and
    # auto both resolve to XRT and say why.
    var proven = resolve_backend_selection("npu", reg, True)
    if proven.backend != "XRT" or "execution proven" not in proven.line():
        raise Error("proven npu did not resolve to XRT with its reason")
    var auto_proven = resolve_backend_selection("auto", reg, True)
    if auto_proven.backend != "XRT":
        raise Error("proven auto did not take the accelerator-first NPU")


def test_backend_config_auto_order() raises:
    # HIP preferred over Vulkan (the A-017 GPU-class preference).
    var both_gpu = build_backend_registry(
        _fake(True, "hip-dev"),
        _fake(True, "vk-dev"),
        _fake(False, ""),
        _fake(True, "cpu-dev"),
    )
    if resolve_backend_selection("auto", both_gpu, False).backend != "HIP":
        raise Error("auto did not prefer HIP over Vulkan")
    # Vulkan when HIP is absent; the skip is recorded.
    var vk_only = build_backend_registry(
        _fake(False, ""),
        _fake(True, "vk-dev"),
        _fake(False, ""),
        _fake(True, "cpu-dev"),
    )
    var vk = resolve_backend_selection("auto", vk_only, False)
    if vk.backend != "Vulkan" or "skip HIP" not in vk.reason:
        raise Error("auto did not fall to Vulkan with the HIP skip logged")
    # CPU only as spillover, and the line says spillover.
    var cpu_only = build_backend_registry(
        _fake(False, ""),
        _fake(False, ""),
        _fake(False, ""),
        _fake(True, "cpu-dev"),
    )
    var cpu = resolve_backend_selection("auto", cpu_only, False)
    if cpu.backend != "CPU" or "spillover" not in cpu.reason:
        raise Error("auto CPU resolution did not disclose spillover")
    # Determinism: identical inputs give an identical resolution line.
    var again = resolve_backend_selection("auto", cpu_only, False)
    if again.line() != cpu.line():
        raise Error("auto resolution is not deterministic")
