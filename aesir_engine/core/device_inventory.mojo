"""Device inventory and truth (Janas road J-037).

J-036 built the placement surface and recorded its own limit in the
open: that layer has no machine state, refuses nothing on inventory
grounds, and inventing an inventory there would fake this slice's
subject. This module is the machine's truth, probed at open:

- CPU -- /proc/cpuinfo parsed as the kernel reports it: model name,
  logical processor count, physical cores counted from distinct
  (physical id, core id) pairs, and package count from distinct
  physical ids. A performance/efficiency split is reported ONLY
  when the machine itself states one (the Intel hybrid sysfs
  cpulists /sys/devices/cpu_core and /sys/devices/cpu_atom); on a
  machine whose sources say nothing about core classes the split
  is recorded as not reported -- never guessed from the model name.
- GPU -- the nvidia-smi-class probe (argv-only, through the tree's
  own bounded subprocess runner, core/posix_process.mojo): name and
  VRAM total/free per device when the probe answers. When it does
  not, the entry is absent WITH the probe's failure as its reason,
  cross-checked against the /sys/class/drm listing so a card the
  NVIDIA probe cannot speak for is named as unclaimed rather than
  silently dropped. CUDA_VISIBLE_DEVICES hiding every device is
  likewise stated as the reason. The tree's heavier CUDA discovery
  (core/cuda_gate.mojo's CUDAGate.discover_physical_devices, used
  by the dense sessions and doctor) remains the session-side probe;
  this inventory deliberately does not import that MAX graph, so
  the truth line is available to the lightest surfaces too -- the
  two probes answer the same question at different weights, and
  docs/janas/J037_DEVICE_INVENTORY.md records that division.
- NPU -- presence strictly per Aesir's own ledgers. The one NPU
  Aesir has a ledger for is the Hailo on the finish-line road, and
  that road is PARKED by campaign law: the chip is never run, its
  branch is never touched, and this module never probes it. The
  NPU entry therefore reports the ledger state (parked), marked
  not probed, and never becomes a live chip claim. The other
  ledger states (not present, not probed) exist for machines and
  moments whose ledgers say so; all are data, none is a probe.

The deliverable shape is the bench-style device line: ONE line on
which every device kind -- cpu, gpu, npu -- is either quantified
or refused-with-reason. A kind missing from the line is a defect
in this slice (the tests pin all three spellings on every line the
builder can produce). The structured entries ride beside the line
for programmatic consumers; require_device_present is the feed
point J-047's generalised refusal consumes (a placement naming an
absent device is refused there, with this entry's reason).

HOST CONTRACT: a surface opening a session calls
observe_device_inventory() once, prints device_line() beside the
placement surface's describe() report, and keeps the structured
inventory for J-038+ (measurement candidates) and J-047 (refusals).
This module chooses nothing and places nothing; it reports.
Reusing what the tree already had is deliberate: /proc parsing
discipline and bounded decimals follow core/native_hardware.mojo
and core/observation_integer.mojo (whose HostMemory/CPU-name
helpers sessions already use for memory admission -- this module
adds the topology those helpers never claimed), and subprocess
execution is core/posix_process.mojo's argv-only runner.
"""

from std.ffi import external_call
from std.memory import Pointer
from std.collections import InlineArray

from core.native_diagnostics import human_bytes
from core.observation_integer import bounded_decimal
from core.posix_process import run_checked_argv

# NPU ledger states (Aesir's own ledgers, never a live probe).
comptime NPU_LEDGER_PARKED = 0
comptime NPU_LEDGER_NOT_PRESENT = 1
comptime NPU_LEDGER_NOT_PROBED = 2


struct CpuFacts(Copyable, ImplicitlyCopyable):
    """CPU truth as the machine's own sources state it.

    physical_cores / packages are -1 when the source carries no
    topology pairs (the count is then not derived -- never guessed
    from the model name or the logical count). perf_cores /
    eff_cores are -1 unless a hybrid source states the split.
    """

    var model: String
    var logical: Int
    var physical_cores: Int
    var packages: Int
    var perf_cores: Int
    var eff_cores: Int

    def __init__(out self):
        self.model = String("")
        self.logical = 0
        self.physical_cores = -1
        self.packages = -1
        self.perf_cores = -1
        self.eff_cores = -1

    def has_hybrid_split(self) -> Bool:
        return self.perf_cores >= 0 and self.eff_cores >= 0


def _cpuinfo_value(line: String) -> Tuple[String, String]:
    """Split one cpuinfo line into (key, value), both stripped."""
    var pair = line.split(":", 1)
    if len(pair) != 2:
        return (String(""), String(""))
    return (String(pair[0].strip()), String(pair[1].strip()))


def parse_cpuinfo(text: String) raises -> CpuFacts:
    """Parse /proc/cpuinfo text into CpuFacts.

    Logical processors are the `processor` entries; physical cores
    are the distinct (physical id, core id) pairs across those
    entries; packages are the distinct physical ids. A block that
    reports only some topology leaves the rest unknown (-1) -- the
    parser states what the source states and nothing more. A text
    with no processor entries is refused: it is not a cpuinfo.
    """
    var facts = CpuFacts()
    var pairs = List[String]()
    var packages_seen = List[String]()
    var cur_phys = String("")
    var cur_core = String("")
    var have_phys = False
    var have_core = False

    for raw_line in text.split("\n"):
        var kv = _cpuinfo_value(String(raw_line))
        var key = kv[0]
        var value = kv[1]
        if key == "processor":
            if have_phys and have_core:
                var pair_key = cur_phys + ":" + cur_core
                var seen = False
                for existing in pairs:
                    if existing == pair_key:
                        seen = True
                        break
                if not seen:
                    pairs.append(pair_key)
            have_phys = False
            have_core = False
            facts.logical += 1
        elif key == "model name" or key == "Hardware":
            if facts.model.byte_length() == 0:
                facts.model = value
        elif key == "physical id":
            cur_phys = value
            have_phys = True
            var pkg_seen = False
            for existing in packages_seen:
                if existing == value:
                    pkg_seen = True
                    break
            if not pkg_seen:
                packages_seen.append(value)
        elif key == "core id":
            cur_core = value
            have_core = True
    if have_phys and have_core:
        var pair_key = cur_phys + ":" + cur_core
        var seen = False
        for existing in pairs:
            if existing == pair_key:
                seen = True
                break
        if not seen:
            pairs.append(pair_key)
    if facts.logical <= 0:
        raise Error("DeviceInventory: cpuinfo reported no processors")
    if facts.model.byte_length() == 0:
        facts.model = String("unknown (kernel did not report a CPU model)")
    if len(pairs) > 0:
        facts.physical_cores = len(pairs)
        facts.packages = len(packages_seen)
    return facts


def count_cpulist(text: String) raises -> Int:
    """Count the CPUs in one sysfs cpulist (`0-7,12` form).

    An empty list counts 0. Malformed entries are refused, never
    reinterpreted -- the split this feeds must be machine-stated.
    """
    var value = String(text.strip())
    if value.byte_length() == 0:
        return 0
    var total = 0
    for part in value.split(","):
        var entry = String(part.strip())
        var dash = entry.find("-")
        if dash >= 0:
            var lo = bounded_decimal(String(entry[byte=:dash].strip()))
            var hi = bounded_decimal(String(entry[byte=dash + 1:].strip()))
            if hi < lo:
                raise Error(
                    "DeviceInventory: cpulist range '"
                    + entry
                    + "' runs backwards"
                )
            total += hi - lo + 1
        else:
            _ = bounded_decimal(entry)
            total += 1
    return total


def apply_hybrid_split(
    mut facts: CpuFacts, core_cpulist: String, atom_cpulist: String
) raises:
    """Record a performance/efficiency split the machine states.

    Both sysfs cpulists (Intel hybrid: cpu_core = performance,
    cpu_atom = efficiency) must be non-empty for a split to exist.
    Any other shape leaves the split unreported (-1): this function
    is the only road by which a split enters the facts, and it takes
    the machine's numbers verbatim.
    """
    if String(core_cpulist.strip()).byte_length() == 0:
        return
    if String(atom_cpulist.strip()).byte_length() == 0:
        return
    facts.perf_cores = count_cpulist(core_cpulist)
    facts.eff_cores = count_cpulist(atom_cpulist)


struct GpuFacts(Copyable, ImplicitlyCopyable):
    """GPU truth from one answering probe: the first device in
    full, plus the device count when the probe lists more."""

    var name: String
    var vram_total_bytes: Int
    var vram_free_bytes: Int
    var count: Int

    def __init__(out self):
        self.name = String("")
        self.vram_total_bytes = -1
        self.vram_free_bytes = -1
        self.count = 0


def _mib_to_bytes(text: String) raises -> Int:
    var mib = bounded_decimal(String(text.strip()))
    if mib > 9223372036854775807 // 1048576:
        raise Error("DeviceInventory: GPU memory figure overflows bytes")
    return mib * 1048576


def parse_nvidia_smi_csv(text: String) raises -> GpuFacts:
    """Parse `nvidia-smi --query-gpu=name,memory.total,memory.free
    --format=csv,noheader,nounits` output (MiB figures).

    One row per device; the first row is reported in full and the
    rest counted. Empty output and malformed rows are refused --
    an answering probe whose words cannot be read is a probe
    failure with that reason, not a device.
    """
    var facts = GpuFacts()
    for raw_line in text.split("\n"):
        var line = String(raw_line.strip())
        if line.byte_length() == 0:
            continue
        var parts = line.split(",")
        if len(parts) != 3:
            raise Error(
                "DeviceInventory: nvidia-smi row '"
                + line
                + "' does not carry name, memory.total, memory.free"
            )
        if facts.count == 0:
            facts.name = String(parts[0].strip())
            if facts.name.byte_length() == 0:
                raise Error("DeviceInventory: nvidia-smi row has no name")
            facts.vram_total_bytes = _mib_to_bytes(String(parts[1]))
            facts.vram_free_bytes = _mib_to_bytes(String(parts[2]))
        facts.count += 1
    if facts.count <= 0:
        raise Error("DeviceInventory: nvidia-smi returned no GPU rows")
    return facts


def parse_drm_listing(text: String) -> Bool:
    """True when a /sys/class/drm listing names a card device
    (an exact `card<digits>` entry; connector entries such as
    `card0-DP-1` do not count on their own)."""
    for raw in text.split("\n"):
        var entry = String(raw.strip())
        if not entry.startswith("card"):
            continue
        var rest = String(entry[byte=4:])
        if rest.byte_length() == 0:
            continue
        var digits = True
        for byte in rest.as_bytes():
            if byte < 48 or byte > 57:
                digits = False
                break
        if digits:
            return True
    return False


struct DeviceEntry(Copyable, ImplicitlyCopyable):
    """One device kind on the line: present-with-facts, or absent
    with the exact reason. Exactly one of detail / reason carries
    the entry's truth; neither is ever left silently empty."""

    var kind: String
    var present: Bool
    var detail: String
    var reason: String

    def __init__(out self, kind: String):
        self.kind = kind
        self.present = False
        self.detail = String("")
        self.reason = String("not probed")

    def render(self) -> String:
        if self.present:
            return self.kind + " present — " + self.detail
        return self.kind + " absent — " + self.reason


def cpu_entry(facts: CpuFacts) -> DeviceEntry:
    var entry = DeviceEntry("cpu")
    entry.present = True
    var detail = (
        facts.model + ": " + String(facts.logical) + " logical"
    )
    if facts.physical_cores > 0:
        detail += ", " + String(facts.physical_cores) + " physical cores"
        if facts.packages > 0:
            detail += (
                " in " + String(facts.packages) + " package"
                + (String("s") if facts.packages != 1 else String(""))
            )
        if facts.logical % facts.physical_cores == 0:
            detail += (
                ", "
                + String(facts.logical // facts.physical_cores)
                + " thread(s) per core"
            )
    else:
        detail += ", physical core count not reported by cpuinfo"
    if facts.has_hybrid_split():
        detail += (
            "; performance "
            + String(facts.perf_cores)
            + " + efficiency "
            + String(facts.eff_cores)
            + " (machine-stated via sysfs cpu_core/cpu_atom)"
        )
    else:
        detail += "; performance/efficiency split not reported by this machine"
    entry.detail = detail
    entry.reason = String("")
    return entry


def gpu_entry(facts: GpuFacts) -> DeviceEntry:
    var entry = DeviceEntry("gpu")
    entry.present = True
    var detail = (
        facts.name
        + ": "
        + human_bytes(facts.vram_total_bytes)
        + " VRAM ("
        + human_bytes(facts.vram_free_bytes)
        + " free at probe)"
    )
    if facts.count > 1:
        detail += "; " + String(facts.count) + " devices probed, first reported"
    entry.detail = detail
    entry.reason = String("")
    return entry


def gpu_absent_entry(reason: String) -> DeviceEntry:
    var entry = DeviceEntry("gpu")
    entry.present = False
    entry.reason = reason
    return entry


def npu_entry(ledger_state: Int, note: String) -> DeviceEntry:
    """The NPU entry from Aesir's ledger alone. Never a probe:
    the Hailo road is parked by campaign law, so on this road the
    entry can only ever state the ledger, marked not probed."""
    var entry = DeviceEntry("npu")
    entry.present = False
    if ledger_state == NPU_LEDGER_PARKED:
        entry.reason = (
            "Hailo NPU is parked by Aesir's campaign law (finish-line"
            " gate closed); reported from the ledger, not probed,"
            " never run by this road"
        )
    elif ledger_state == NPU_LEDGER_NOT_PRESENT:
        entry.reason = "no NPU in Aesir's ledgers for this machine"
    else:
        entry.reason = "NPU presence not probed on this machine"
    if note.byte_length() > 0:
        entry.reason += " (" + note + ")"
    return entry


struct DeviceInventory(Copyable, ImplicitlyCopyable):
    """The whole truth at open: one entry per device kind."""

    var cpu: DeviceEntry
    var gpu: DeviceEntry
    var npu: DeviceEntry

    def __init__(out self):
        self.cpu = DeviceEntry("cpu")
        self.gpu = DeviceEntry("gpu")
        self.npu = DeviceEntry("npu")

    def entry(self, kind: String) raises -> DeviceEntry:
        if kind == "cpu":
            return self.cpu
        if kind == "gpu":
            return self.gpu
        if kind == "npu":
            return self.npu
        raise Error("DeviceInventory: unknown device kind '" + kind + "'")

    def has(self, kind: String) raises -> Bool:
        return self.entry(kind).present

    def device_line(self) -> String:
        """The bench-style device line: every kind quantified or
        refused-with-reason, on one line, none omitted."""
        return (
            "devices: "
            + self.cpu.render()
            + " | "
            + self.gpu.render()
            + " | "
            + self.npu.render()
        )

    def describe(self) -> String:
        """The structured form: one entry per line, same truth."""
        return (
            self.cpu.render()
            + "\n"
            + self.gpu.render()
            + "\n"
            + self.npu.render()
            + "\n"
        )


def require_device_present(inv: DeviceInventory, kind: String) raises:
    """The J-047 feed point: refuse a use of an absent device,
    carrying the inventory entry's own reason."""
    var entry = inv.entry(kind)
    if not entry.present:
        raise Error(
            "DeviceInventory: "
            + kind
            + " was requested, but this machine's inventory says: "
            + entry.reason
        )


def _env_value(name: String) -> Tuple[Bool, String]:
    """Read one environment variable (placement_options' shape)."""
    var buf = InlineArray[Int8, 32](fill=0)
    var bytes = name.as_bytes()
    if len(bytes) >= 32:
        return (False, String(""))
    for i in range(len(bytes)):
        buf[i] = Int8(bytes[i])
    var raw = external_call["getenv", Pointer[UInt8, MutUntrackedOrigin]](
        buf.unsafe_ptr()
    )
    if Int(raw) == 0:
        return (False, String(""))
    var value = String("")
    var i = 0
    while i < 256:
        var c = raw.unsafe_load(i)
        if c == 0:
            break
        value += chr(Int(c))
        i += 1
    return (True, value)


def _probe_gpu() -> DeviceEntry:
    """The live GPU probe: nvidia-smi-class, argv-only.

    Every failure path lands in the entry's reason -- the probe
    failing IS the inventory fact on a machine it cannot speak for,
    stated with the probe's own error and the DRM cross-check.
    """
    var hidden = _env_value("CUDA_VISIBLE_DEVICES")
    if hidden[0] and (
        hidden[1].byte_length() == 0 or hidden[1] == "NoDevFiles"
    ):
        return gpu_absent_entry(
            "CUDA_VISIBLE_DEVICES='"
            + hidden[1]
            + "' hides every CUDA device from this process"
        )
    try:
        var out = run_checked_argv(
            [
                "nvidia-smi",
                "--query-gpu=name,memory.total,memory.free",
                "--format=csv,noheader,nounits",
            ],
            4096,
        )
        try:
            return gpu_entry(parse_nvidia_smi_csv(out))
        except parse_error:
            return gpu_absent_entry(
                "nvidia-smi answered but its output could not be"
                " read: " + String(parse_error)
            )
    except probe_error:
        var reason = (
            "no GPU probe answered: nvidia-smi failed ("
            + String(probe_error)
            + ")"
        )
        try:
            var listing = run_checked_argv(["ls", "/sys/class/drm"], 4096)
            if parse_drm_listing(listing):
                reason += (
                    "; /sys/class/drm lists a card device, but no"
                    " vendor/VRAM probe answered for it, so no GPU"
                    " is claimed"
                )
            else:
                reason += "; /sys/class/drm lists no card device"
        except:
            reason += "; /sys/class/drm could not be listed either"
        return gpu_absent_entry(reason)


def observe_device_inventory() -> DeviceInventory:
    """Probe this machine at open and return its truth.

    Never raises: each kind's probe failure becomes that kind's
    absent-with-reason entry, because at open the honest output is
    the line itself, reasons included. The NPU is not probed at
    all -- its entry is the parked ledger state, by law.
    """
    var inv = DeviceInventory()
    try:
        var text: String
        with open("/proc/cpuinfo", "r") as source:
            text = source.read()
        var facts = parse_cpuinfo(text)
        try:
            var core_list: String
            var atom_list: String
            with open("/sys/devices/cpu_core/cpulist", "r") as source:
                core_list = source.read()
            with open("/sys/devices/cpu_atom/cpulist", "r") as source:
                atom_list = source.read()
            apply_hybrid_split(facts, core_list, atom_list)
        except:
            pass
        inv.cpu = cpu_entry(facts)
    except cpu_error:
        var entry = DeviceEntry("cpu")
        entry.present = False
        entry.reason = (
            "cpuinfo could not be read or parsed: " + String(cpu_error)
        )
        inv.cpu = entry
    inv.gpu = _probe_gpu()
    inv.npu = npu_entry(NPU_LEDGER_PARKED, String(""))
    return inv
