# core/backend_registry.mojo
# A-009: Backend registry skeleton.
# Turns the amd_gate probe into a typed capability record: one
# BackendCapability per runtime (HIP / Vulkan / XRT / CPU), each with
# a distinct present / absent / degraded status, a version string and
# a device identity, surfaced in `doctor`.
# Honesty rules: a runtime is present only on probe evidence; a
# degraded probe (evidence of presence, incomplete identity) is
# neither present nor absent; llvmpipe is a software rasterizer and
# never counts as a Vulkan GPU device; XRT presence is stated from
# the sysfs accel node when the unprivileged xrt-smi examine is
# blocked (RLIMIT_MEMLOCK) -- presence only, no NPU execution claim.

from core.amd_gate import AMDGate
from core.structured_errors import coded_error_text
from core.native_hardware import observe_cpu_name
from core.posix_process import run_checked_argv

comptime BACKEND_ABSENT = 0
comptime BACKEND_PRESENT = 1
comptime BACKEND_DEGRADED = 2

# A-086: GPU bake-off roles (A-085 HIP vs Vulkan). A GPU record is
# undecided until a banked A-085 verdict is applied; then exactly one
# of HIP / Vulkan is first-class and the other is probe-only (parked,
# never silently dropped, never placed or selected for execution).
comptime GPU_ROLE_UNDECIDED = 0
comptime GPU_ROLE_FIRST_CLASS = 1
comptime GPU_ROLE_PROBE_ONLY = 2


struct RawBackendProbe(Copyable, ImplicitlyCopyable):
    """One injectable probe result; tests build these directly."""

    var found: Bool
    var degraded: Bool
    var version: String
    var device: String
    var detail: String

    def __init__(out self):
        self.found = False
        self.degraded = False
        self.version = String("")
        self.device = String("")
        self.detail = String("")

    def __init__(
        out self,
        found: Bool,
        degraded: Bool,
        version: String,
        device: String,
        detail: String,
    ):
        self.found = found
        self.degraded = degraded
        self.version = version
        self.device = device
        self.detail = detail


struct BackendCapability(Copyable, ImplicitlyCopyable):
    """Typed capability record for one runtime."""

    var runtime: String
    var status: Int
    var version: String
    var device: String
    var detail: String
    var gpu_role: Int

    def __init__(out self, runtime: String):
        self.runtime = runtime
        self.status = BACKEND_ABSENT
        self.gpu_role = GPU_ROLE_UNDECIDED
        self.version = String("")
        self.device = String("")
        self.detail = String("not probed")

    def status_name(self) -> String:
        if self.status == BACKEND_PRESENT:
            return String("present")
        if self.status == BACKEND_DEGRADED:
            return String("degraded")
        return String("absent")

    def is_available(self) -> Bool:
        return self.status != BACKEND_ABSENT

    def gpu_role_name(self) -> String:
        if self.gpu_role == GPU_ROLE_FIRST_CLASS:
            return String("first-class")
        if self.gpu_role == GPU_ROLE_PROBE_ONLY:
            return String("probe-only")
        return String("undecided")

    def is_first_class_gpu(self) -> Bool:
        return self.gpu_role == GPU_ROLE_FIRST_CLASS

    def is_probe_only_gpu(self) -> Bool:
        return self.gpu_role == GPU_ROLE_PROBE_ONLY

    def line(self) -> String:
        var text = self.runtime + " " + self.status_name()
        if self.version != "":
            text += " - version " + self.version
        if self.device != "":
            text += ", device " + self.device
        if self.detail != "":
            text += " (" + self.detail + ")"
        if (self.runtime == "HIP" or self.runtime == "Vulkan") and (
            self.gpu_role != GPU_ROLE_UNDECIDED
        ):
            text += " [gpu role: " + self.gpu_role_name() + "]"
        return text


def is_software_vulkan_device(device: String) -> Bool:
    """llvmpipe / lvp is software rendering, never a GPU device."""
    return "llvmpipe" in device or "(lvp)" in device


def backend_capability_from_probe(
    runtime: String, probe: RawBackendProbe
) -> BackendCapability:
    """Pure builder: fake probes in, typed record out (unit-tested)."""
    var cap = BackendCapability(runtime)
    cap.detail = probe.detail
    if not probe.found:
        cap.status = BACKEND_ABSENT
        return cap
    if runtime == "Vulkan" and is_software_vulkan_device(probe.device):
        cap.status = BACKEND_ABSENT
        cap.detail = (
            "only a software Vulkan device was observed ("
            + probe.device
            + "); no GPU Vulkan device"
        )
        return cap
    cap.version = probe.version
    cap.device = probe.device
    if probe.degraded:
        cap.status = BACKEND_DEGRADED
    else:
        cap.status = BACKEND_PRESENT
    return cap


struct BackendRegistry(Copyable, ImplicitlyCopyable):
    """The four runtime records, in HIP / Vulkan / XRT / CPU order."""

    var hip: BackendCapability
    var vulkan: BackendCapability
    var xrt: BackendCapability
    var cpu: BackendCapability

    def __init__(
        out self,
        hip: BackendCapability,
        vulkan: BackendCapability,
        xrt: BackendCapability,
        cpu: BackendCapability,
    ):
        self.hip = hip
        self.vulkan = vulkan
        self.xrt = xrt
        self.cpu = cpu

    def count_available(self) -> Int:
        var n = 0
        if self.hip.is_available():
            n += 1
        if self.vulkan.is_available():
            n += 1
        if self.xrt.is_available():
            n += 1
        if self.cpu.is_available():
            n += 1
        return n

    def capability_named(self, runtime: String) raises -> BackendCapability:
        if runtime == "HIP":
            return self.hip
        if runtime == "Vulkan":
            return self.vulkan
        if runtime == "XRT":
            return self.xrt
        if runtime == "CPU":
            return self.cpu
        raise Error(coded_error_text("VAL-003", "unknown backend runtime: " + runtime))

    def lines(self) -> List[String]:
        var out = List[String]()
        out.append(self.hip.line())
        out.append(self.vulkan.line())
        out.append(self.xrt.line())
        out.append(self.cpu.line())
        return out^


def build_backend_registry(
    hip: RawBackendProbe,
    vulkan: RawBackendProbe,
    xrt: RawBackendProbe,
    cpu: RawBackendProbe,
) -> BackendRegistry:
    return BackendRegistry(
        backend_capability_from_probe("HIP", hip),
        backend_capability_from_probe("Vulkan", vulkan),
        backend_capability_from_probe("XRT", xrt),
        backend_capability_from_probe("CPU", cpu),
    )


def registry_with_gpu_winner(
    registry: BackendRegistry, winner_runtime: String
) raises -> BackendRegistry:
    """Copy of the registry with the A-085 winner applied (A-086).

    The winner (HIP or Vulkan) becomes first-class; the other GPU
    backend becomes probe-only. XRT and CPU records are untouched
    and stay undecided. Any other winner name raises VAL-003:
    the bake-off is HIP vs Vulkan only.
    """
    if winner_runtime != "HIP" and winner_runtime != "Vulkan":
        raise Error(
            coded_error_text(
                "VAL-003",
                "bake-off winner must be HIP or Vulkan, got: "
                + winner_runtime,
            )
        )
    var hip = registry.hip
    var vulkan = registry.vulkan
    if winner_runtime == "HIP":
        hip.gpu_role = GPU_ROLE_FIRST_CLASS
        vulkan.gpu_role = GPU_ROLE_PROBE_ONLY
    else:
        vulkan.gpu_role = GPU_ROLE_FIRST_CLASS
        hip.gpu_role = GPU_ROLE_PROBE_ONLY
    return BackendRegistry(hip, vulkan, registry.xrt, registry.cpu)


def registry_without_gpu_winner(
    registry: BackendRegistry,
) -> BackendRegistry:
    """Copy with both GPU roles back to undecided (pending state)."""
    var hip = registry.hip
    var vulkan = registry.vulkan
    hip.gpu_role = GPU_ROLE_UNDECIDED
    vulkan.gpu_role = GPU_ROLE_UNDECIDED
    return BackendRegistry(hip, vulkan, registry.xrt, registry.cpu)


def gpu_first_class_runtime(registry: BackendRegistry) -> String:
    """The first-class GPU runtime, or '' while the verdict is pending."""
    if registry.hip.is_first_class_gpu():
        return String("HIP")
    if registry.vulkan.is_first_class_gpu():
        return String("Vulkan")
    return String("")


def gpu_probe_only_runtime(registry: BackendRegistry) -> String:
    """The probe-only GPU runtime, or '' while the verdict is pending."""
    if registry.hip.is_probe_only_gpu():
        return String("HIP")
    if registry.vulkan.is_probe_only_gpu():
        return String("Vulkan")
    return String("")


def _after(text: String, marker: String) -> String:
    var parts = text.split(marker, 1)
    if len(parts) != 2:
        return String("")
    return String(parts[1].strip())


def parse_hip_version_header(text: String) -> String:
    """Parse HIP_VERSION_MAJOR/MINOR/PATCH defines into 'M.m.p'."""
    var major = _after(text, "#define HIP_VERSION_MAJOR")
    var minor = _after(text, "#define HIP_VERSION_MINOR")
    var patch = _after(text, "#define HIP_VERSION_PATCH")
    if major == "" or minor == "" or patch == "":
        return String("")
    return (
        String(major.split()[0])
        + "."
        + String(minor.split()[0])
        + "."
        + String(patch.split()[0])
    )


def parse_rocminfo_device(text: String) -> String:
    """First Radeon marketing name in rocminfo output, else ''."""
    var fallback = String("")
    for line in text.split("\n"):
        if "Marketing Name:" in String(line) and "Radeon" in String(line):
            if "Graphics" in String(line):
                return _after(String(line), "Marketing Name:")
            if fallback == "":
                fallback = _after(String(line), "Marketing Name:")
    return fallback


def parse_vulkan_summary(text: String) -> RawBackendProbe:
    """Parse `vulkaninfo --summary`: first non-software GPU device.

    Version is the Vulkan apiVersion of that device section. If the
    only device is llvmpipe the probe keeps it as its device so the
    builder can refuse it as a GPU (absent, with that reason).
    """
    var probe = RawBackendProbe()
    var pending_version = String("")
    var software_device = String("")
    var software_version = String("")
    for line in text.split("\n"):
        var trimmed = String(line.strip())
        if trimmed.startswith("apiVersion"):
            pending_version = _after(trimmed, "=")
        if trimmed.startswith("deviceName"):
            var name = _after(trimmed, "=")
            if is_software_vulkan_device(name):
                if software_device == "":
                    software_device = name
                    software_version = pending_version
                continue
            probe.found = True
            probe.version = pending_version
            probe.device = name
            probe.detail = "Vulkan GPU device reported by vulkaninfo"
            return probe
    if software_device != "":
        probe.found = True
        probe.version = software_version
        probe.device = software_device
        probe.detail = "vulkaninfo reported only a software device"
    return probe


def parse_xrt_package_version(text: String) -> String:
    """Parse dpkg version '1:2.25.0-4ubuntu1' into '2.25.0'."""
    var value = String(text.strip())
    var epoch = value.split(":", 1)
    if len(epoch) == 2:
        var after_epoch = String(epoch[1].copy())
        value = after_epoch
    var release = value.split("-", 1)
    if len(release) == 2:
        var before_release = String(release[0].copy())
        value = before_release
    return value


def probe_cpu() -> RawBackendProbe:
    var probe = RawBackendProbe()
    try:
        probe.device = observe_cpu_name()
        probe.found = True
        probe.detail = "host CPU reported by /proc/cpuinfo"
    except error:
        probe.detail = "cpuinfo probe failed: " + String(error)
    return probe


def probe_hip() -> RawBackendProbe:
    var probe = RawBackendProbe()
    if not AMDGate.is_available():
        probe.detail = "libamdhip64/libhipblas not loadable"
        return probe
    probe.found = True
    probe.detail = "libamdhip64 loadable via AMDGate"
    try:
        with open("/usr/include/hip/hip_version.h", "r") as source:
            probe.version = parse_hip_version_header(source.read())
    except:
        pass
    try:
        var info = run_checked_argv(["rocminfo"], 65536)
        probe.device = parse_rocminfo_device(info)
    except:
        pass
    if probe.device == "":
        probe.degraded = True
        probe.detail += "; rocminfo device identity not observed"
    return probe


def probe_vulkan() -> RawBackendProbe:
    var probe = RawBackendProbe()
    try:
        var info = run_checked_argv(["vulkaninfo", "--summary"], 65536)
        probe = parse_vulkan_summary(info)
    except error:
        probe.detail = "vulkaninfo probe failed: " + String(error)
    return probe


def probe_xrt() -> RawBackendProbe:
    """XRT/NPU presence from sysfs; never an execution claim.

    Unprivileged `xrt-smi examine` fails on this host (mmap blocked
    by RLIMIT_MEMLOCK) even though the NPU exists, so presence is
    taken from /sys/class/accel/accel0 + /dev/accel/accel0 and the
    version from the installed XRT package, not from that probe.
    """
    var probe = RawBackendProbe()
    var sysfs_seen = False
    try:
        with open("/sys/class/accel/accel0/dev", "r") as source:
            _ = source.read()
            sysfs_seen = True
    except:
        pass
    if not sysfs_seen:
        probe.detail = "no /sys/class/accel/accel0 node observed"
        return probe
    probe.found = True
    probe.device = String("NPU via /dev/accel/accel0 (XDNA, amdxdna)")
    probe.detail = (
        "device present via sysfs /dev/accel/accel0; unprivileged"
        " xrt-smi examine is blocked (RLIMIT_MEMLOCK), so this is"
        " presence only -- no NPU execution is claimed"
    )
    try:
        var out = run_checked_argv(
            ["dpkg-query", "-W", "-f=${Version}", "libxrt2"], 4096
        )
        probe.version = parse_xrt_package_version(out)
    except:
        pass
    if probe.version == "":
        probe.degraded = True
        probe.detail += "; XRT version not observed"
    return probe


def observe_backend_registry() -> BackendRegistry:
    """Live registry: each probe fails closed to absent/degraded.

    A-086 seat application (banking 2026-11-13): the banked
    A-085 verdict (closure 3822d595 -- Vulkan PRIMARY, HIP
    PARKED probe-only) is applied to the live registry here,
    the one place live surfaces (doctor) observe it:
    Vulkan first-class, HIP probe-only. The injectable
    build_backend_registry stays verdict-parametric so tests
    prove pending + both decided states."""
    var registry = build_backend_registry(
        probe_hip(), probe_vulkan(), probe_xrt(), probe_cpu()
    )
    var hip = registry.hip
    var vulkan = registry.vulkan
    hip.gpu_role = GPU_ROLE_PROBE_ONLY
    vulkan.gpu_role = GPU_ROLE_FIRST_CLASS
    return BackendRegistry(hip, vulkan, registry.xrt, registry.cpu)
