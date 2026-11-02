"""The learned file: placement + thread choices persisted between
sessions (Janas road J-044).

J-036 built the placement option surface, J-037 the machine
truth, J-038 the measurement harness, J-039 the thread trials,
J-040/J-041/J-042 the per-kind choosers (prompt / reply /
draft-check), and J-043 the prompt co-work planner. Every one of
those slices keeps its choice for ONE session and says so: the
record is decided once, held in a session holder, and gone when
the process exits. This module is the persistence those slices
named and did not build: the chosen placement + thread choice
for each pass kind, written to Aesir's own learned file, keyed
by the machine that measured it and the shape of the model it
was measured for, loaded at open, shown on request, and
erasable. J-045 (re-trials) owns re-measuring a learned choice;
this slice stores the provenance a re-trial needs (the key it
was measured under, the option it came from, the decision that
produced it, and when it was measured) and builds no re-trial
logic.

WHAT IS LEARNED, per pass kind (prompt / drafts / reply), and
nothing else:

- the resolved option the choice came from, in J-036's
  canonical written form (auto, a single device, an `a+b`
  co-work pair, or a comma race list) -- provenance, so a
  re-trial knows what was asked;
- the chosen placement as the choosers render it (their
  chosen label: `cpu threads=2` for a thread rung, `cpu` /
  `cpu+gpu` for a device-fixed choice);
- the chosen device code and the chosen thread count (0 on a
  device-fixed choice: a device option does not fix a thread
  count, exactly as the choosers record it);
- the decision that produced it, by name (MEASURED-WIN,
  DEFAULT-CONFIRMED, DEFAULT-BY-NOISE, SOLE-MEASURED,
  NO-MEASURED-FALLBACK, MANUAL-FIXED -- the J-040 rule's codes,
  adopted unchanged by J-041/J-042).

A kind whose chooser REFUSED (no choice exists) is stored as
ABSENT for that kind: a refusal is not a choice and leaves no
learned default. An entry with no kind present is refused at
save: there is nothing learned in it.

WHAT IS NEVER LEARNED. No expert map. J-027 measured cache
persistence and REJECTED it (a persisted expert map saves no
net byte anywhere on the real trace; the oracle ceiling nets
exactly zero), and its closure binds this slice: the learned
file holds placement + thread choices ONLY, and no expert-map
section may be added to it on that evidence. The serialiser
has no field for one and the parser refuses any line it does
not know, so a map cannot smuggle itself in as an extra field.

THE KEY. An entry applies only to the machine + model shape
it was measured under:

- MachineKey derives from the inventory's own facts
  (core/device_inventory.mojo): the CPU model string, logical
  / physical / package counts and the machine-stated hybrid
  split from CpuFacts, plus the GPU name, VRAM total and
  device count from GpuFacts. No single machine-identity field
  exists in the tree today; the key is DERIVED from those
  existing fields (answered-locally, recorded in the J-044
  doc). A host that holds no GPU probe facts keys the GPU as
  absent (a default GpuFacts) -- the host contract below
  states that duty in the open.
- ModelShape derives from the GGUF loader's own config
  fields (loader/gguf.mojo's GGUFModelConfig): architecture,
  embedding length, block count, head counts, feed-forward
  length, context length, and the MoE routing geometry
  (expert count / experts used; both 0 for a dense file).
  This module does not import the loader (core does not depend
  on loader anywhere in the Part III line); the host maps the
  config's fields onto ModelShape's, one for one, at open.

Lookup is exact on BOTH halves. A key mismatch is never an
error and never a partial apply: lookup_learned states which
half mismatched (machine / model shape / both / no entry at
all), with the reason, and the caller falls back to measuring
or to the session default exactly as if nothing was learned.

THE FILE. Aesir's own format, versioned, human-readable: a
header line (AESIR_LEARNED_PLACEMENT_V1), an entry count, one
fixed-order line block per entry, and an FNV-1a checksum over
the whole body in the tree's persisted-record style
(core/state_vault.mojo, cli/model_preferences.mojo). Free-text
key material that can carry arbitrary bytes (the CPU model
and GPU name strings) is hex-encoded, as the preferences file
encodes its values; every other field is plain text a reader
can check by eye. Saves are atomic (stage in the same
directory, fsync, rename, sync the parent -- the StateVault
discipline), so a crash mid-save leaves the old file or the
new one, never a torn one.

THE CACHE HOME. The tree resolves no cache/config home today
(the model store is a relative `.aesir/models` path, chosen
per surface). Answered-locally, in the tree's env style: the
learned file's path is AESIR_LEARNED_FILE when that env names
a full path; else $AESIR_CACHE_HOME/learned-placement.v1 when
AESIR_CACHE_HOME names a directory; else
$HOME/.cache/aesir/learned-placement.v1; else
.aesir-cache/learned-placement.v1 relative to the working
directory. learned_file_path() reads the live environment;
resolve_learned_path() is its pure, unit-tested form. The
file name is learned-placement.v1.

LOAD HONESTY, the four states a surface must distinguish:

- MISSING (no file at the path): the clean no-learned state.
  Not an error, never raised: a first run has nothing learned
  yet, and load returns it as data.
- LOADED: the file parsed whole, checksum verified, every
  entry validated. Only a LOADED state can apply an entry.
- REFUSED (the file exists but is corrupt, truncated, of an
  unknown version, oversized, or unreadable): a clean refusal
  with the reason stated, ZERO entries carried, never a crash
  and never a partial apply. The file is left untouched --
  erasing it is the caller's explicit act, not a load side
  effect. Storing into a REFUSED file likewise raises rather
  than silently overwriting evidence of corruption.
- An entry naming the parked NPU as its chosen device is
  refused at save AND at parse: the Hailo ledger is parked by
  campaign law (J-037), and a parked device may not re-enter
  as a persisted default. (A prompt OPTION may still name the
  NPU in J-036's grammar -- that is a parse-time surface fact,
  refused at use by J-047's road; it is never a learned
  choice, because no chooser can choose an excluded device.)

MANUAL SUPREMACY, stated here because J-047 is next and this
file must not pre-violate it: a learned value is a DEFAULT
ONLY. It supplies the choice a session would otherwise have
to measure, for exactly the key it was measured under. An
explicit --prompt-on / --drafts-on / --reply-on option (or its
env equivalent) overrides the learned value for its kind,
always, and nothing in this module ranks, argues with, or
rewrites a hand choice: the choosers already fix manual
choices as MANUAL-FIXED without ranking, and a host applying
a learned entry must do so only for kinds the user left on
auto. Every report this module renders carries that sentence
on its face.

J-083 EXTENSION (the draft configuration section). J-044's
own record named J-083's draft configuration surface as
persisting via this file. A LearnedEntry therefore also
carries one draft configuration (source / mtp state / draft
file / k, validated structurally by validate_draft; the
surface refusals live in core/draft_config.mojo). Files with
no draft configuration serialise exactly as J-044's V1; a
file carrying one serialises as V2 (five extra fixed-order
lines per entry, draft file hex-encoded like the other
free-text material). The parser accepts both versions and
refuses any other. This is a configuration record, not an
expert map: J-027's binding stands and the report still
carries its sentence.

HOST CONTRACT (binding on the surfaces that consume this
module; this module fakes no integration): at model open a
surface (1) observes the inventory and CPU facts (J-037),
builds the MachineKey from the facts it holds, and maps the
opened model's GGUFModelConfig onto a ModelShape; (2) calls
load_learned_file(learned_file_path()) once -- MISSING and
REFUSED are data, printed beside the device line with their
reasons, never raised through open; (3) for each kind the
user left on auto, calls lookup_learned and, on APPLIED,
seeds that kind's session choice from the entry instead of
measuring (an explicit option always wins -- see manual
supremacy above); (4) when it measures a fresh choice, stores
it with store_learned_entry, stamped by learned_now_seconds()
(the re-trial provenance J-045 consumes); (5) prints
LearnedLoad.report() on request (the show-on-request surface
J-050's explainability report will cite). Erasure is
erase_learned_file (the whole file) or erase_learned_entry
(one key). This slice wires the module into NO live session
path beyond the aesir.mojo comment: no session consumes a
learned choice yet, and claiming otherwise would fake the
integration. See docs/janas/J044_LEARNED_FILE.md.
"""

from std.ffi import external_call
from std.memory import Pointer
from std.collections import InlineArray

from core.device_inventory import CpuFacts, GpuFacts
from core.observation_integer import bounded_decimal
from core.placement_options import (
    DEVICE_CPU,
    DEVICE_GPU,
    DEVICE_NPU,
    PASS_DRAFTS,
    PASS_PROMPT,
    PASS_REPLY,
    PLACE_COWORK,
    PLACE_SINGLE,
    device_name,
    parse_placement_value,
    pass_name,
)
from core.text_admission import admit_text_bytes

comptime LEARNED_HEADER = "AESIR_LEARNED_PLACEMENT_V1"
# J-083: a file in which at least one entry carries a draft
# configuration serialises under the V2 header (V1 entries gain
# five draftcfg lines per entry; see the serialisation note).
# The parser accepts both versions; a V1 file parses with every
# draft configuration ABSENT, and a state with no draft
# configuration serialises as V1, byte-identical to J-044.
comptime LEARNED_HEADER_V2 = "AESIR_LEARNED_PLACEMENT_V2"

# Draft-configuration source codes (J-083; the vocabulary is
# defined here, in the persistence layer, and
# core/draft_config.mojo imports it -- one definition site).
comptime LEARNED_DRAFT_SOURCE_NONE = 0
comptime LEARNED_DRAFT_SOURCE_MTP_HEAD = 1
comptime LEARNED_DRAFT_SOURCE_DRAFT_MODEL = 2

# Draft-configuration MTP states (J-083).
comptime LEARNED_DRAFT_MTP_UNSET = 0
comptime LEARNED_DRAFT_MTP_ON = 1
comptime LEARNED_DRAFT_MTP_OFF = 2


def learned_draft_source_name(code: Int) -> String:
    if code == LEARNED_DRAFT_SOURCE_MTP_HEAD:
        return String("mtp-head")
    if code == LEARNED_DRAFT_SOURCE_DRAFT_MODEL:
        return String("draft-model")
    return String("none")


def learned_draft_mtp_name(code: Int) -> String:
    if code == LEARNED_DRAFT_MTP_ON:
        return String("on")
    if code == LEARNED_DRAFT_MTP_OFF:
        return String("off")
    return String("unset")
comptime LEARNED_FILE_NAME = "learned-placement.v1"
comptime MAX_LEARNED_BYTES = 262144
comptime MAX_LEARNED_ENTRIES = 64
comptime MAX_TEXT_BYTES = 4096

# Load states (LearnedLoad.status).
comptime LOAD_MISSING = 0
comptime LOAD_LOADED = 1
comptime LOAD_REFUSED = 2

# Lookup outcomes (LookupResult.status).
comptime LOOKUP_APPLIED = 0
comptime LOOKUP_NO_ENTRY = 1
comptime LOOKUP_MACHINE_MISMATCH = 2
comptime LOOKUP_MODEL_MISMATCH = 3
comptime LOOKUP_BOTH_MISMATCH = 4
comptime LOOKUP_NOT_LOADED = 5


def load_status_name(code: Int) -> String:
    if code == LOAD_LOADED:
        return String("LOADED")
    if code == LOAD_REFUSED:
        return String("REFUSED")
    return String("MISSING")


def lookup_status_name(code: Int) -> String:
    if code == LOOKUP_APPLIED:
        return String("APPLIED")
    if code == LOOKUP_NO_ENTRY:
        return String("NO-ENTRY")
    if code == LOOKUP_MACHINE_MISMATCH:
        return String("MACHINE-MISMATCH")
    if code == LOOKUP_MODEL_MISMATCH:
        return String("MODEL-MISMATCH")
    if code == LOOKUP_BOTH_MISMATCH:
        return String("BOTH-MISMATCH")
    return String("NOT-LOADED")


# --- small shared helpers (the tree's persisted-record style) --------


def _learned_checksum(payload: String) -> UInt64:
    """FNV-1a over the canonical body (state_vault's checksum)."""
    var checksum: UInt64 = 14695981039346656037
    for byte in payload.as_bytes():
        checksum = (checksum ^ UInt64(byte)) * 1099511628211
    return checksum


def _learned_hex(value: UInt64) -> String:
    var chars = String("0123456789abcdef")
    var result = String("")
    for shift in range(60, -4, -4):
        var nibble = Int((value >> UInt64(shift)) & 15)
        result += String(chars[byte=nibble : nibble + 1])
    return result


def _learned_parse_hex(value: String) raises -> UInt64:
    if len(value.bytes()) != 16:
        raise Error("LearnedFile: checksum must be 16 lowercase hex digits")
    var result: UInt64 = 0
    for byte in value.as_bytes():
        var nibble: Int
        if byte >= 48 and byte <= 57:
            nibble = Int(byte - 48)
        elif byte >= 97 and byte <= 102:
            nibble = Int(byte - 87)
        else:
            raise Error("LearnedFile: checksum holds a non-hex digit")
        result = (result << 4) | UInt64(nibble)
    return result


def _hex_encode(value: String) -> String:
    var alphabet = String("0123456789abcdef")
    var output = String("")
    for byte in value.as_bytes():
        var code = Int(byte)
        output += String(alphabet[byte=code >> 4 : (code >> 4) + 1])
        output += String(alphabet[byte=code & 15 : (code & 15) + 1])
    return output


def _hex_nibble(code: Int) raises -> Int:
    if code >= 48 and code <= 57:
        return code - 48
    if code >= 97 and code <= 102:
        return code - 87
    raise Error("LearnedFile: hex field holds a non-hex digit")


def _hex_decode(value: String, label: String) raises -> String:
    if len(value.bytes()) % 2 != 0:
        raise Error("LearnedFile: " + label + " hex is odd-length")
    var output = List[Byte]()
    var source = value.as_bytes()
    for index in range(0, len(source), 2):
        var decoded = (
            (_hex_nibble(Int(source[index])) << 4)
            | _hex_nibble(Int(source[index + 1]))
        )
        output.append(Byte(decoded))
    return admit_text_bytes(output, label, MAX_TEXT_BYTES, True)


def _parse_signed(text: String, field: String) raises -> Int:
    """One strict signed decimal: an optional '-', then digits.

    The key's unknown-count sentinels are -1 (J-037's facts), so
    the persisted form needs signs; everything else about the
    parse is bounded_decimal's strictness (digits only, overflow
    refused, never reinterpreted)."""
    var value = String(text.strip())
    if value.byte_length() == 0:
        raise Error("LearnedFile: " + field + " must not be empty")
    var negative = False
    var digits = value
    if value.startswith("-"):
        negative = True
        digits = String(value[byte=1:])
        if digits.byte_length() == 0:
            raise Error("LearnedFile: " + field + " is a bare sign")
    var magnitude = bounded_decimal(digits)
    if negative:
        return -magnitude
    return magnitude


def _check_printable(text: String, field: String, max_bytes: Int) raises:
    """A persisted label: non-empty printable ASCII within bound.

    Labels are single-line by construction (the choosers render
    them so); control bytes or a newline would break the line
    format itself, so they are refused, never escaped silently.
    """
    if text.byte_length() == 0 or text.byte_length() > max_bytes:
        raise Error(
            "LearnedFile: "
            + field
            + " must be 1.."
            + String(max_bytes)
            + " bytes"
        )
    for byte in text.as_bytes():
        var code = Int(byte)
        if code < 32 or code > 126:
            raise Error(
                "LearnedFile: " + field + " holds a non-printable byte"
            )


def _decision_known(name: String) -> Bool:
    """The J-040 decision names (adopted unchanged by J-041/J-042)."""
    return (
        name == "MEASURED-WIN"
        or name == "DEFAULT-CONFIRMED"
        or name == "DEFAULT-BY-NOISE"
        or name == "SOLE-MEASURED"
        or name == "NO-MEASURED-FALLBACK"
        or name == "MANUAL-FIXED"
    )


# --- the key halves ----------------------------------------------------


struct MachineKey(Copyable, ImplicitlyCopyable):
    """The machine half of the key, derived from J-037's facts.

    cpu_model / gpu_name are the probe's own strings, carried
    verbatim (hex-encoded in the file). Counts use J-037's
    sentinels: -1 where the machine states no count (physical
    cores, packages, the hybrid split). A GPU the facts do not
    state is count 0 with an empty name and vram -1.
    """

    var cpu_model: String
    var logical: Int
    var physical_cores: Int
    var packages: Int
    var perf_cores: Int
    var eff_cores: Int
    var gpu_name: String
    var gpu_vram_total_bytes: Int
    var gpu_count: Int

    def __init__(out self):
        self.cpu_model = String("")
        self.logical = 0
        self.physical_cores = -1
        self.packages = -1
        self.perf_cores = -1
        self.eff_cores = -1
        self.gpu_name = String("")
        self.gpu_vram_total_bytes = -1
        self.gpu_count = 0

    def equals(self, other: MachineKey) -> Bool:
        return (
            self.cpu_model == other.cpu_model
            and self.logical == other.logical
            and self.physical_cores == other.physical_cores
            and self.packages == other.packages
            and self.perf_cores == other.perf_cores
            and self.eff_cores == other.eff_cores
            and self.gpu_name == other.gpu_name
            and self.gpu_vram_total_bytes == other.gpu_vram_total_bytes
            and self.gpu_count == other.gpu_count
        )

    def validate(self) raises:
        _check_printable(self.cpu_model, "machine cpu model", 512)
        if self.logical < 1:
            raise Error("LearnedFile: machine logical count must be >= 1")
        if self.physical_cores != -1 and self.physical_cores < 1:
            raise Error(
                "LearnedFile: machine physical cores must be -1 or >= 1"
            )
        if self.packages != -1 and self.packages < 1:
            raise Error("LearnedFile: machine packages must be -1 or >= 1")
        var split_unset = self.perf_cores == -1 and self.eff_cores == -1
        var split_set = self.perf_cores >= 0 and self.eff_cores >= 0
        if not (split_unset or split_set):
            raise Error(
                "LearnedFile: machine hybrid split must be both -1"
                " (not machine-stated) or both >= 0"
            )
        if self.gpu_count < 0 or self.gpu_count > 64:
            raise Error("LearnedFile: machine gpu count must be 0..64")
        if self.gpu_count == 0:
            if self.gpu_name.byte_length() != 0 or self.gpu_vram_total_bytes != -1:
                raise Error(
                    "LearnedFile: a machine with no gpu states an empty"
                    " gpu name and vram -1"
                )
        else:
            _check_printable(self.gpu_name, "machine gpu name", 512)
            if self.gpu_vram_total_bytes < 0:
                raise Error(
                    "LearnedFile: a present gpu states its vram total"
                )

    def render(self) -> String:
        var out_str = String("machine: cpu '") + self.cpu_model + "'"
        out_str += (
            ", "
            + String(self.logical)
            + " logical / "
            + String(self.physical_cores)
            + " physical / "
            + String(self.packages)
            + " package(s)"
        )
        if self.perf_cores >= 0:
            out_str += (
                ", perf "
                + String(self.perf_cores)
                + " + eff "
                + String(self.eff_cores)
            )
        else:
            out_str += ", hybrid split not machine-stated"
        if self.gpu_count == 0:
            out_str += "; gpu none stated"
        else:
            out_str += (
                "; gpu '"
                + self.gpu_name
                + "' vram "
                + String(self.gpu_vram_total_bytes)
                + " B x"
                + String(self.gpu_count)
            )
        return out_str


def machine_key_from_facts(cpu: CpuFacts, gpu: GpuFacts) -> MachineKey:
    """Derive the machine key from the inventory's own facts.

    The GPU half is exactly what the handed GpuFacts state: a
    default GpuFacts (count 0) keys as no-GPU-stated. A host
    whose probe answered must hand the probe's facts -- keying
    a present GPU as absent would collide two machines' learned
    entries, and the duty is the host's (module header)."""
    var key = MachineKey()
    key.cpu_model = cpu.model
    key.logical = cpu.logical
    key.physical_cores = cpu.physical_cores
    key.packages = cpu.packages
    key.perf_cores = cpu.perf_cores
    key.eff_cores = cpu.eff_cores
    key.gpu_name = gpu.name
    key.gpu_vram_total_bytes = gpu.vram_total_bytes
    key.gpu_count = gpu.count
    return key


struct ModelShape(Copyable, ImplicitlyCopyable):
    """The model half of the key: GGUFModelConfig's shape fields.

    expert_count / expert_used_count are the loader's MoE
    routing geometry; both are 0 for a dense file, exactly as
    the loader states them.
    """

    var architecture: String
    var embedding_length: Int
    var block_count: Int
    var head_count: Int
    var head_count_kv: Int
    var feed_forward_length: Int
    var context_length: Int
    var expert_count: Int
    var expert_used_count: Int

    def __init__(out self):
        self.architecture = String("")
        self.embedding_length = 0
        self.block_count = 0
        self.head_count = 0
        self.head_count_kv = 0
        self.feed_forward_length = 0
        self.context_length = 0
        self.expert_count = 0
        self.expert_used_count = 0

    def equals(self, other: ModelShape) -> Bool:
        return (
            self.architecture == other.architecture
            and self.embedding_length == other.embedding_length
            and self.block_count == other.block_count
            and self.head_count == other.head_count
            and self.head_count_kv == other.head_count_kv
            and self.feed_forward_length == other.feed_forward_length
            and self.context_length == other.context_length
            and self.expert_count == other.expert_count
            and self.expert_used_count == other.expert_used_count
        )

    def validate(self) raises:
        if self.architecture.byte_length() == 0 or self.architecture.byte_length() > 64:
            raise Error("LearnedFile: model architecture must be 1..64 bytes")
        for byte in self.architecture.as_bytes():
            var code = Int(byte)
            var allowed = (
                (code >= 48 and code <= 57)
                or (code >= 97 and code <= 122)
                or code == 45
                or code == 46
                or code == 95
            )
            if not allowed:
                raise Error(
                    "LearnedFile: model architecture holds a byte outside"
                    " [a-z0-9._-]"
                )
        if self.embedding_length < 1 or self.block_count < 1 or self.head_count < 1:
            raise Error(
                "LearnedFile: model embedding/block/head counts must be >= 1"
            )
        if (
            self.head_count_kv < 0
            or self.feed_forward_length < 0
            or self.context_length < 0
        ):
            raise Error("LearnedFile: model shape counts must be >= 0")
        if self.expert_count < 0 or self.expert_used_count < 0:
            raise Error("LearnedFile: model expert counts must be >= 0")
        if self.expert_count == 0 and self.expert_used_count != 0:
            raise Error(
                "LearnedFile: a dense shape (0 experts) states 0 used"
            )
        if self.expert_count > 0 and self.expert_used_count > self.expert_count:
            raise Error("LearnedFile: experts used exceeds expert count")

    def render(self) -> String:
        var out_str = String("model: ") + self.architecture
        out_str += (
            " emb="
            + String(self.embedding_length)
            + " blk="
            + String(self.block_count)
            + " heads="
            + String(self.head_count)
            + "/"
            + String(self.head_count_kv)
            + " ffn="
            + String(self.feed_forward_length)
            + " ctx="
            + String(self.context_length)
        )
        if self.expert_count > 0:
            out_str += (
                " experts="
                + String(self.expert_count)
                + " used="
                + String(self.expert_used_count)
            )
        else:
            out_str += " dense"
        return out_str


def model_shape(
    architecture: String,
    embedding_length: Int,
    block_count: Int,
    head_count: Int,
    head_count_kv: Int,
    feed_forward_length: Int,
    context_length: Int,
    expert_count: Int,
    expert_used_count: Int,
) -> ModelShape:
    """Build a ModelShape from raw shape values -- the shape the
    host's GGUFModelConfig mapping (module header) produces."""
    var shape = ModelShape()
    shape.architecture = architecture
    shape.embedding_length = embedding_length
    shape.block_count = block_count
    shape.head_count = head_count
    shape.head_count_kv = head_count_kv
    shape.feed_forward_length = feed_forward_length
    shape.context_length = context_length
    shape.expert_count = expert_count
    shape.expert_used_count = expert_used_count
    return shape


# --- one kind's learned choice -----------------------------------------


struct LearnedPassChoice(Copyable, ImplicitlyCopyable):
    """One pass kind's learned choice, in the choosers' own terms.

    present == False is the ABSENT state: the kind's chooser
    refused, or nothing was ever learned for the kind; the other
    fields then carry their canonical empty values and are never
    consulted. When present: option_text is the resolved J-036
    option in canonical written form (provenance), placement_text
    is the chooser's chosen label verbatim, device/threads are
    the chosen device code and thread count (threads 0 on a
    device-fixed choice), and decision is the J-040 decision
    name that produced the choice.
    """

    var present: Bool
    var option_text: String
    var placement_text: String
    var device: Int
    var threads: Int
    var decision: String

    def __init__(out self):
        self.present = False
        self.option_text = String("-")
        self.placement_text = String("-")
        self.device = DEVICE_CPU
        self.threads = 0
        self.decision = String("-")

    def validate(self, pass_kind: Int) raises:
        var kind_name = pass_name(pass_kind)
        if not self.present:
            if (
                self.option_text != "-"
                or self.placement_text != "-"
                or self.decision != "-"
                or self.device != DEVICE_CPU
                or self.threads != 0
            ):
                raise Error(
                    "LearnedFile: absent "
                    + kind_name
                    + " choice must carry its canonical empty fields"
                )
            return
        if self.device == DEVICE_NPU:
            raise Error(
                "LearnedFile: the "
                + kind_name
                + " choice names the npu as its chosen device -- the"
                " npu is the parked Hailo ledger (J-037, parked by"
                " campaign law, never probed, never run) and a parked"
                " device is never persisted as a learned choice"
            )
        if self.device != DEVICE_CPU and self.device != DEVICE_GPU:
            raise Error(
                "LearnedFile: "
                + kind_name
                + " choice holds an unknown device code"
            )
        if self.threads < 0:
            raise Error(
                "LearnedFile: " + kind_name + " thread count must be >= 0"
            )
        if self.device != DEVICE_CPU and self.threads != 0:
            raise Error(
                "LearnedFile: a non-cpu "
                + kind_name
                + " choice fixes no thread count (threads must be 0;"
                " the thread axis is the cpu's, as the choosers record)"
            )
        _check_printable(self.option_text, kind_name + " option", 64)
        _check_printable(self.placement_text, kind_name + " placement", 128)
        _check_printable(self.decision, kind_name + " decision", 32)
        if not _decision_known(self.decision):
            raise Error(
                "LearnedFile: "
                + kind_name
                + " decision '"
                + self.decision
                + "' is not a J-040 decision name"
            )
        var parsed = parse_placement_value(self.option_text, pass_kind)
        if parsed.describe() != self.option_text:
            raise Error(
                "LearnedFile: "
                + kind_name
                + " option '"
                + self.option_text
                + "' is not in J-036 canonical written form"
            )
        var is_manual_form = (
            parsed.form == PLACE_SINGLE or parsed.form == PLACE_COWORK
        )
        if is_manual_form and self.decision != "MANUAL-FIXED":
            raise Error(
                "LearnedFile: an explicit single/co-work "
                + kind_name
                + " option fixes its choice (MANUAL-FIXED); decision '"
                + self.decision
                + "' contradicts the option it is filed under"
            )
        if not is_manual_form and self.decision == "MANUAL-FIXED":
            raise Error(
                "LearnedFile: MANUAL-FIXED requires an explicit"
                " single/co-work "
                + kind_name
                + " option; '"
                + self.option_text
                + "' is an auto/race form"
            )

    def render(self, pass_kind: Int) -> String:
        if not self.present:
            return pass_name(pass_kind) + ": absent (no learned choice)"
        return (
            pass_name(pass_kind)
            + ": "
            + self.placement_text
            + " (device "
            + device_name(self.device)
            + ", threads "
            + String(self.threads)
            + ", decision "
            + self.decision
            + ", from option "
            + self.option_text
            + ")"
        )


def learned_pass_from_choice(
    option_text: String,
    chosen_label: String,
    chosen_device: Int,
    chosen_threads: Int,
    decision: String,
    has_choice: Bool,
) -> LearnedPassChoice:
    """Build one kind's learned choice from a chooser record's own
    fields (every J-040/J-041/J-042 record carries exactly these:
    option_text, chosen_label, chosen_device, chosen_threads,
    decision name, has_choice). A record with no choice (a
    refusal) builds the ABSENT state -- a refusal leaves no
    learned default (module header). Validation is the entry's
    and the serialiser's, not this builder's."""
    var choice = LearnedPassChoice()
    if not has_choice:
        return choice
    choice.present = True
    choice.option_text = option_text
    choice.placement_text = chosen_label
    choice.device = chosen_device
    choice.threads = chosen_threads
    choice.decision = decision
    return choice


# --- one learned entry ---------------------------------------------------


struct LearnedEntry(Copyable, Movable):
    """One key's learned choices: the machine + model shape the
    choices were measured under, when they were measured (unix
    seconds -- the provenance J-045's re-trials consume), and
    the three pass kinds' choices."""

    var machine: MachineKey
    var model: ModelShape
    var measured_at: Int64
    var prompt: LearnedPassChoice
    var drafts: LearnedPassChoice
    var reply: LearnedPassChoice
    # J-083: the entry's learned draft configuration (the
    # --mtp / --no-mtp / --draft surface's resolved state, as
    # validated by core/draft_config.mojo). Absent by default:
    # draft_present False carries the canonical empties
    # (source none, mtp unset, model "-", k 0).
    var draft_present: Bool
    var draft_source: Int
    var draft_mtp: Int
    var draft_model: String
    var draft_k: Int

    def __init__(out self):
        self.machine = MachineKey()
        self.model = ModelShape()
        self.measured_at = 0
        self.prompt = LearnedPassChoice()
        self.drafts = LearnedPassChoice()
        self.reply = LearnedPassChoice()
        self.draft_present = False
        self.draft_source = LEARNED_DRAFT_SOURCE_NONE
        self.draft_mtp = LEARNED_DRAFT_MTP_UNSET
        self.draft_model = String("-")
        self.draft_k = 0

    def pass_choice(self, pass_kind: Int) -> LearnedPassChoice:
        if pass_kind == PASS_DRAFTS:
            return self.drafts
        if pass_kind == PASS_REPLY:
            return self.reply
        return self.prompt

    def has_any(self) -> Bool:
        return (
            self.prompt.present
            or self.drafts.present
            or self.reply.present
            or self.draft_present
        )

    def validate_draft(self) raises:
        """The J-083 draft configuration's structural validity.

        This layer checks form only (canonical empties when
        absent; a named source, a stated MTP state, the J-071
        draft-check band for k, and the source/file consistency
        when present). The surface refusals (contradictions,
        pair gates, caps read from J-071's account) are
        core/draft_config.mojo's, applied before a configuration
        ever reaches this file."""
        if not self.draft_present:
            if (
                self.draft_source != LEARNED_DRAFT_SOURCE_NONE
                or self.draft_mtp != LEARNED_DRAFT_MTP_UNSET
                or self.draft_model != "-"
                or self.draft_k != 0
            ):
                raise Error(
                    "LearnedFile: an absent draft configuration"
                    " must carry its canonical empty fields"
                )
            return
        if (
            self.draft_source != LEARNED_DRAFT_SOURCE_MTP_HEAD
            and self.draft_source != LEARNED_DRAFT_SOURCE_DRAFT_MODEL
        ):
            raise Error(
                "LearnedFile: a present draft configuration names"
                " an unknown source code"
            )
        if self.draft_mtp < 0 or self.draft_mtp > 2:
            raise Error(
                "LearnedFile: a present draft configuration holds"
                " an unknown mtp state code"
            )
        if self.draft_k < 1 or self.draft_k > 15:
            raise Error(
                "LearnedFile: a present draft configuration's k"
                " is outside the draft-check band 1..15 (J-071)"
            )
        _check_printable(self.draft_model, "draft model", 512)
        if self.draft_source == LEARNED_DRAFT_SOURCE_MTP_HEAD:
            if self.draft_model != "-":
                raise Error(
                    "LearnedFile: an mtp-head draft configuration"
                    " names no separate draft file (the head is"
                    " the target's own)"
                )
            if self.draft_mtp != LEARNED_DRAFT_MTP_ON:
                raise Error(
                    "LearnedFile: an mtp-head draft configuration"
                    " must record mtp on"
                )
        else:
            if self.draft_model == "-" or self.draft_model.byte_length() == 0:
                raise Error(
                    "LearnedFile: a draft-model configuration"
                    " must name its draft file"
                )

    def validate(self) raises:
        self.machine.validate()
        self.model.validate()
        if self.measured_at <= 0:
            raise Error(
                "LearnedFile: an entry's measured-at stamp must be"
                " positive (unix seconds; J-045 re-trial provenance)"
            )
        if not self.has_any():
            raise Error(
                "LearnedFile: an entry with no kind present learns"
                " nothing and is refused"
            )
        self.prompt.validate(PASS_PROMPT)
        self.drafts.validate(PASS_DRAFTS)
        self.reply.validate(PASS_REPLY)
        self.validate_draft()

    def render(self) -> String:
        var out_str = String("entry\n")
        out_str += "  " + self.machine.render() + "\n"
        out_str += "  " + self.model.render() + "\n"
        out_str += "  measured-at: " + String(self.measured_at) + " (unix s)\n"
        out_str += "  " + self.prompt.render(PASS_PROMPT) + "\n"
        out_str += "  " + self.drafts.render(PASS_DRAFTS) + "\n"
        out_str += "  " + self.reply.render(PASS_REPLY) + "\n"
        if self.draft_present:
            out_str += (
                "  drafts-config: source "
                + learned_draft_source_name(self.draft_source)
                + ", mtp "
                + learned_draft_mtp_name(self.draft_mtp)
                + ", model "
                + self.draft_model
                + ", k "
                + String(self.draft_k)
                + "\n"
            )
        else:
            out_str += "  drafts-config: absent (no learned draft configuration)\n"
        return out_str


# --- serialisation -------------------------------------------------------
#
# The line format, fixed order (the parser walks it by exact
# offsets; any unknown, missing, reordered, or extra line is a
# refusal, which is also what keeps an expert-map section out:
# there is no line for one to occupy).
#
#   AESIR_LEARNED_PLACEMENT_V1
#   count=<n>
#   per entry (39 lines): entry / 9 machine lines / 9 model
#   lines / measured_at / per kind (prompt, drafts, reply):
#   <kind>_present, <kind>_option, <kind>_placement,
#   <kind>_device, <kind>_threads, <kind>_decision / end
#   checksum=<16 lowercase hex, FNV-1a over every line above,
#   each terminated by exactly one newline>
#
# J-083 extension: when any entry carries a draft
# configuration, the file serialises as
# AESIR_LEARNED_PLACEMENT_V2 and each entry block is 44 lines:
# the 39 above plus, before `end`, draftcfg_present,
# draftcfg_source, draftcfg_mtp, draftcfg_model_hex (the
# draft file name hex-encoded, like the other free-text key
# material), draftcfg_k. A state with no draft configuration
# serialises as V1, byte-identical to J-044's format.
#
# Absent kinds write "-" for their three text fields and 0 for
# device/threads (the canonical empty values validate() pins).


def _append_pass_lines(
    mut body: String, prefix: String, choice: LearnedPassChoice
):
    body += prefix + "_present=" + (String("1") if choice.present else String("0")) + "\n"
    body += prefix + "_option=" + choice.option_text + "\n"
    body += prefix + "_placement=" + choice.placement_text + "\n"
    body += prefix + "_device=" + String(choice.device) + "\n"
    body += prefix + "_threads=" + String(choice.threads) + "\n"
    body += prefix + "_decision=" + choice.decision + "\n"


def serialize_learned_file(entries: List[LearnedEntry]) raises -> String:
    """Serialise the whole learned state. Raises on the first
    invalid entry, on a duplicate key, or over the entry cap:
    a file that cannot be written whole is never written."""
    if len(entries) > MAX_LEARNED_ENTRIES:
        raise Error(
            "LearnedFile: entry count exceeds the cap of "
            + String(MAX_LEARNED_ENTRIES)
        )
    for i in range(len(entries)):
        entries[i].validate()
        for j in range(i):
            if (
                entries[i].machine.equals(entries[j].machine)
                and entries[i].model.equals(entries[j].model)
            ):
                raise Error(
                    "LearnedFile: two entries share one machine+model"
                    " key; a key holds exactly one learned state"
                )
    var any_draft = False
    for i in range(len(entries)):
        if entries[i].draft_present:
            any_draft = True
    var body = String(LEARNED_HEADER_V2 if any_draft else LEARNED_HEADER) + "\n"
    body += "count=" + String(len(entries)) + "\n"
    for i in range(len(entries)):
        var entry = entries[i].copy()
        body += "entry\n"
        body += "machine_cpu_model_hex=" + _hex_encode(entry.machine.cpu_model) + "\n"
        body += "machine_logical=" + String(entry.machine.logical) + "\n"
        body += "machine_physical=" + String(entry.machine.physical_cores) + "\n"
        body += "machine_packages=" + String(entry.machine.packages) + "\n"
        body += "machine_perf=" + String(entry.machine.perf_cores) + "\n"
        body += "machine_eff=" + String(entry.machine.eff_cores) + "\n"
        body += "machine_gpu_name_hex=" + _hex_encode(entry.machine.gpu_name) + "\n"
        body += "machine_gpu_vram_total=" + String(entry.machine.gpu_vram_total_bytes) + "\n"
        body += "machine_gpu_count=" + String(entry.machine.gpu_count) + "\n"
        body += "model_arch=" + entry.model.architecture + "\n"
        body += "model_embedding=" + String(entry.model.embedding_length) + "\n"
        body += "model_blocks=" + String(entry.model.block_count) + "\n"
        body += "model_heads=" + String(entry.model.head_count) + "\n"
        body += "model_kv_heads=" + String(entry.model.head_count_kv) + "\n"
        body += "model_ffn=" + String(entry.model.feed_forward_length) + "\n"
        body += "model_context=" + String(entry.model.context_length) + "\n"
        body += "model_experts=" + String(entry.model.expert_count) + "\n"
        body += "model_experts_used=" + String(entry.model.expert_used_count) + "\n"
        body += "measured_at=" + String(entry.measured_at) + "\n"
        _append_pass_lines(body, "prompt", entry.prompt)
        _append_pass_lines(body, "drafts", entry.drafts)
        _append_pass_lines(body, "reply", entry.reply)
        if any_draft:
            body += (
                "draftcfg_present="
                + (String("1") if entry.draft_present else String("0"))
                + "\n"
            )
            body += "draftcfg_source=" + String(entry.draft_source) + "\n"
            body += "draftcfg_mtp=" + String(entry.draft_mtp) + "\n"
            body += "draftcfg_model_hex=" + _hex_encode(entry.draft_model) + "\n"
            body += "draftcfg_k=" + String(entry.draft_k) + "\n"
        body += "end\n"
    if len(body.bytes()) + 26 > MAX_LEARNED_BYTES:
        raise Error("LearnedFile: serialised state exceeds the file cap")
    return body + "checksum=" + _learned_hex(_learned_checksum(body))


def _field(lines: List[String], index: Int, prefix: String) raises -> String:
    var line = lines[index]
    if not line.startswith(prefix):
        raise Error(
            "LearnedFile: line "
            + String(index + 1)
            + " must start with '"
            + prefix
            + "', got '"
            + line
            + "'"
        )
    return String(line[byte=prefix.byte_length():])


def _parse_pass(
    lines: List[String], base: Int, prefix: String, pass_kind: Int
) raises -> LearnedPassChoice:
    var choice = LearnedPassChoice()
    var present_text = _field(lines, base, prefix + "_present=")
    if present_text == "1":
        choice.present = True
    elif present_text == "0":
        choice.present = False
    else:
        raise Error(
            "LearnedFile: " + prefix + "_present must be 0 or 1"
        )
    choice.option_text = _field(lines, base + 1, prefix + "_option=")
    choice.placement_text = _field(lines, base + 2, prefix + "_placement=")
    choice.device = _parse_signed(
        _field(lines, base + 3, prefix + "_device="), prefix + " device"
    )
    choice.threads = _parse_signed(
        _field(lines, base + 4, prefix + "_threads="), prefix + " threads"
    )
    choice.decision = _field(lines, base + 5, prefix + "_decision=")
    choice.validate(pass_kind)
    return choice


def parse_learned_file(text: String) raises -> List[LearnedEntry]:
    """Parse the whole learned file, strictly. ANY deviation --
    size, header, count, line order, field form, checksum,
    entry validity, duplicate key -- raises with the reason.
    The disk loader turns that raise into the REFUSED state;
    nothing here ever returns a partial entry list."""
    if len(text.bytes()) == 0 or len(text.bytes()) > MAX_LEARNED_BYTES:
        raise Error("LearnedFile: file size is outside 1..MAX_LEARNED_BYTES")
    var lines = List[String]()
    for raw in text.split("\n"):
        lines.append(String(raw))
    if len(lines) < 3:
        raise Error("LearnedFile: file is truncated (header/count/checksum)")
    var checksum_text = _field(lines, len(lines) - 1, "checksum=")
    var stated = _learned_parse_hex(checksum_text)
    var body = String("")
    for i in range(len(lines) - 1):
        body += lines[i] + "\n"
    if _learned_checksum(body) != stated:
        raise Error("LearnedFile: checksum mismatch (corrupt or truncated file)")
    var is_v2 = lines[0] == LEARNED_HEADER_V2
    if lines[0] != LEARNED_HEADER and not is_v2:
        raise Error(
            "LearnedFile: header is not "
            + LEARNED_HEADER
            + " or "
            + LEARNED_HEADER_V2
            + " (unknown version or not a learned file)"
        )
    var block_lines = 44 if is_v2 else 39
    var count = _parse_signed(_field(lines, 1, "count="), "entry count")
    if count < 0 or count > MAX_LEARNED_ENTRIES:
        raise Error("LearnedFile: entry count is outside its bound")
    if len(lines) != 2 + count * block_lines + 1:
        raise Error(
            "LearnedFile: line count does not match the entry count"
            " (truncated or extended file)"
        )
    var entries = List[LearnedEntry]()
    for e in range(count):
        var base = 2 + e * block_lines
        if lines[base] != "entry":
            raise Error("LearnedFile: entry block does not start with 'entry'")
        if lines[base + block_lines - 1] != "end":
            raise Error("LearnedFile: entry block does not end with 'end'")
        var entry = LearnedEntry()
        entry.machine.cpu_model = _hex_decode(
            _field(lines, base + 1, "machine_cpu_model_hex="), "cpu model"
        )
        entry.machine.logical = _parse_signed(
            _field(lines, base + 2, "machine_logical="), "machine logical"
        )
        entry.machine.physical_cores = _parse_signed(
            _field(lines, base + 3, "machine_physical="), "machine physical"
        )
        entry.machine.packages = _parse_signed(
            _field(lines, base + 4, "machine_packages="), "machine packages"
        )
        entry.machine.perf_cores = _parse_signed(
            _field(lines, base + 5, "machine_perf="), "machine perf"
        )
        entry.machine.eff_cores = _parse_signed(
            _field(lines, base + 6, "machine_eff="), "machine eff"
        )
        entry.machine.gpu_name = _hex_decode(
            _field(lines, base + 7, "machine_gpu_name_hex="), "gpu name"
        )
        entry.machine.gpu_vram_total_bytes = _parse_signed(
            _field(lines, base + 8, "machine_gpu_vram_total="), "gpu vram"
        )
        entry.machine.gpu_count = _parse_signed(
            _field(lines, base + 9, "machine_gpu_count="), "gpu count"
        )
        entry.model.architecture = _field(lines, base + 10, "model_arch=")
        entry.model.embedding_length = _parse_signed(
            _field(lines, base + 11, "model_embedding="), "model embedding"
        )
        entry.model.block_count = _parse_signed(
            _field(lines, base + 12, "model_blocks="), "model blocks"
        )
        entry.model.head_count = _parse_signed(
            _field(lines, base + 13, "model_heads="), "model heads"
        )
        entry.model.head_count_kv = _parse_signed(
            _field(lines, base + 14, "model_kv_heads="), "model kv heads"
        )
        entry.model.feed_forward_length = _parse_signed(
            _field(lines, base + 15, "model_ffn="), "model ffn"
        )
        entry.model.context_length = _parse_signed(
            _field(lines, base + 16, "model_context="), "model context"
        )
        entry.model.expert_count = _parse_signed(
            _field(lines, base + 17, "model_experts="), "model experts"
        )
        entry.model.expert_used_count = _parse_signed(
            _field(lines, base + 18, "model_experts_used="), "model experts used"
        )
        var measured = _parse_signed(
            _field(lines, base + 19, "measured_at="), "measured at"
        )
        entry.measured_at = Int64(measured)
        entry.prompt = _parse_pass(lines, base + 20, "prompt", PASS_PROMPT)
        entry.drafts = _parse_pass(lines, base + 26, "drafts", PASS_DRAFTS)
        entry.reply = _parse_pass(lines, base + 32, "reply", PASS_REPLY)
        if is_v2:
            var present_text = _field(lines, base + 38, "draftcfg_present=")
            if present_text == "1":
                entry.draft_present = True
            elif present_text == "0":
                entry.draft_present = False
            else:
                raise Error("LearnedFile: draftcfg_present must be 0 or 1")
            entry.draft_source = _parse_signed(
                _field(lines, base + 39, "draftcfg_source="), "draft source"
            )
            entry.draft_mtp = _parse_signed(
                _field(lines, base + 40, "draftcfg_mtp="), "draft mtp"
            )
            entry.draft_model = _hex_decode(
                _field(lines, base + 41, "draftcfg_model_hex="), "draft model"
            )
            entry.draft_k = _parse_signed(
                _field(lines, base + 42, "draftcfg_k="), "draft k"
            )
        entry.validate()
        for j in range(len(entries)):
            if (
                entry.machine.equals(entries[j].machine)
                and entry.model.equals(entries[j].model)
            ):
                raise Error(
                    "LearnedFile: two entries share one machine+model key"
                )
        entries.append(entry^)
    return entries^


# --- the loaded state, lookup, and reports -------------------------------


struct LearnedLoad(Copyable, Movable):
    """The state one load produces: MISSING (clean, no file),
    LOADED (entries whole and verified), or REFUSED (the file
    exists but is not usable; reason stated, zero entries).
    Only LOADED carries entries -- a refusal never partially
    applies, by construction."""

    var status: Int
    var reason: String
    var path: String
    var entries: List[LearnedEntry]

    def __init__(out self):
        self.status = LOAD_MISSING
        self.reason = String("not loaded")
        self.path = String("")
        self.entries = List[LearnedEntry]()

    def report(self) -> String:
        """The show-on-request dump: state first, then every
        entry per key, then the two standing sentences (manual
        supremacy; no expert maps) on the face of the report."""
        var out_str = String("learned file report\n")
        out_str += "path: " + self.path + "\n"
        if self.status == LOAD_LOADED:
            out_str += (
                "state: LOADED ("
                + String(len(self.entries))
                + " entr"
                + (String("ies") if len(self.entries) != 1 else String("y"))
                + ")\n"
            )
            for i in range(len(self.entries)):
                out_str += self.entries[i].render()
        elif self.status == LOAD_REFUSED:
            out_str += (
                "state: REFUSED -- "
                + self.reason
                + " (no entry is applied; the file is left untouched)\n"
            )
        else:
            out_str += (
                "state: MISSING -- no learned file at this path;"
                " the clean no-learned state (nothing is applied"
                " and nothing is in error)\n"
            )
        out_str += (
            "manual supremacy: learned values are defaults only;"
            " an explicit --prompt-on / --drafts-on / --reply-on"
            " option (or its env equivalent) overrides the learned"
            " value for its kind, always\n"
        )
        out_str += (
            "expert maps: none -- this file holds placement +"
            " thread choices and draft configurations (J-083)"
            " only; no expert-map section exists"
            " (J-027 measured rejection)\n"
        )
        return out_str


struct LookupResult(Copyable, Movable):
    """One lookup's outcome: APPLIED with the entry, or a named
    non-apply outcome with its reason. entry is meaningful only
    when status is APPLIED (entry_index >= 0)."""

    var status: Int
    var reason: String
    var entry_index: Int
    var entry: LearnedEntry

    def __init__(out self):
        self.status = LOOKUP_NOT_LOADED
        self.reason = String("not looked up")
        self.entry_index = -1
        self.entry = LearnedEntry()


def lookup_learned(
    load: LearnedLoad, machine: MachineKey, model: ModelShape
) -> LookupResult:
    """Exact-key lookup against a loaded state. A mismatch is
    data, never a raise: the reason names which half of the key
    failed, so the caller (and J-050's report) can state it."""
    var result = LookupResult()
    if load.status != LOAD_LOADED:
        result.status = LOOKUP_NOT_LOADED
        result.reason = (
            "the learned state is "
            + load_status_name(load.status)
            + ", so no entry can apply"
        )
        if load.status == LOAD_REFUSED:
            result.reason += " (" + load.reason + ")"
        return result^
    if len(load.entries) == 0:
        result.status = LOOKUP_NO_ENTRY
        result.reason = "the learned file holds no entries"
        return result^
    var machine_seen = False
    var model_seen = False
    for i in range(len(load.entries)):
        var candidate = load.entries[i].copy()
        var machine_eq = candidate.machine.equals(machine)
        var model_eq = candidate.model.equals(model)
        if machine_eq and model_eq:
            result.status = LOOKUP_APPLIED
            result.reason = String("exact machine+model key match")
            result.entry_index = i
            result.entry = candidate^
            return result^
        if machine_eq:
            machine_seen = True
        if model_eq:
            model_seen = True
    if machine_seen:
        result.status = LOOKUP_MODEL_MISMATCH
        result.reason = (
            "this machine has learned entries, but none for this"
            " model shape; the learned choices were measured for"
            " a different shape and are not applied"
        )
    elif model_seen:
        result.status = LOOKUP_MACHINE_MISMATCH
        result.reason = (
            "this model shape has learned entries, but none from"
            " this machine; choices measured on another machine"
            " are not applied"
        )
    else:
        result.status = LOOKUP_BOTH_MISMATCH
        result.reason = (
            "no learned entry matches this machine or this model"
            " shape; nothing is applied"
        )
    return result^


# --- the cache home --------------------------------------------------------


def _learned_env_value(name: String) -> Tuple[Bool, String]:
    """Read one environment variable: (is_set, value), in
    placement_options' shape with a path-sized value bound."""
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
    while i < 2048:
        var c = raw.unsafe_load(i)
        if c == 0:
            break
        value += chr(Int(c))
        i += 1
    return (True, value)


def resolve_learned_path(
    file_env: Tuple[Bool, String],
    cache_env: Tuple[Bool, String],
    home_env: Tuple[Bool, String],
) -> String:
    """The pure path rule (module header): AESIR_LEARNED_FILE
    names the file itself and wins; AESIR_CACHE_HOME names the
    cache directory; HOME gives $HOME/.cache/aesir; with none
    of them, a relative .aesir-cache directory. An env set to
    the empty string counts as unset -- an empty path names
    nothing, and guessing at it would hide a configuration
    error the surface should see."""
    if file_env[0] and file_env[1].byte_length() > 0:
        return file_env[1]
    if cache_env[0] and cache_env[1].byte_length() > 0:
        return cache_env[1] + "/" + LEARNED_FILE_NAME
    if home_env[0] and home_env[1].byte_length() > 0:
        return home_env[1] + "/.cache/aesir/" + LEARNED_FILE_NAME
    return String(".aesir-cache/") + LEARNED_FILE_NAME


def learned_file_path() -> String:
    """The live learned-file path from this process's env."""
    return resolve_learned_path(
        _learned_env_value("AESIR_LEARNED_FILE"),
        _learned_env_value("AESIR_CACHE_HOME"),
        _learned_env_value("HOME"),
    )


def learned_now_seconds() raises -> Int64:
    """Realtime unix seconds (state_vault's clock read) -- the
    measured-at stamp a host files with store_learned_entry."""
    var timestamp = InlineArray[Int64, 2](fill=0)
    if external_call["clock_gettime", Int32](Int32(0), timestamp.unsafe_ptr()) != 0:
        raise Error("LearnedFile: cannot observe the realtime clock")
    if timestamp[0] <= 0:
        raise Error("LearnedFile: observed an invalid realtime timestamp")
    return timestamp[0]


# --- file IO (state_vault's proven discipline, this file's bounds) -------


def _learned_cstring(value: String) raises -> List[Int8]:
    if len(value.bytes()) == 0 or len(value.bytes()) >= 4096:
        raise Error("LearnedFile: path must contain 1..4095 bytes")
    var result = List[Int8]()
    for byte in value.as_bytes():
        if byte == 0:
            raise Error("LearnedFile: path contains NUL")
        result.append(Int8(byte))
    result.append(0)
    return result^


def _learned_parent(path: String) -> String:
    var last_slash = -1
    var source = path.as_bytes()
    for index in range(len(source)):
        if source[index] == 47:
            last_slash = index
    if last_slash < 0:
        return String(".")
    if last_slash == 0:
        return String("/")
    return String(path[byte=0:last_slash])


def _ensure_parent_dirs(path: String) raises:
    """Create the learned file's parent chain (the cache home
    may not exist yet). Existing directories are success; any
    other mkdir failure raises with the step named."""
    var parent = _learned_parent(path)
    if parent == "." or parent == "/":
        return
    var segments = parent.split("/")
    var current = String("")
    if parent.startswith("/"):
        current = String("/")
    for raw in segments:
        var segment = String(raw)
        if segment.byte_length() == 0:
            continue
        if current.byte_length() > 0 and not current.endswith("/"):
            current += "/"
        current += segment
        var encoded = _learned_cstring(current)
        if external_call["mkdir", Int32](encoded.unsafe_ptr(), 448) != 0:
            var errno_ptr = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_ptr.unsafe_load() != 17:
                raise Error(
                    "LearnedFile: cannot create cache directory '"
                    + current
                    + "'"
                )


def _learned_write_all(fd: Int32, content: String) raises:
    var source = content.as_bytes()
    var offset = 0
    while offset < len(source):
        var written = external_call["pwrite", Int](
            fd, source.unsafe_ptr().unsafe_offset(offset),
            len(source) - offset, Int64(offset),
        )
        if written < 0:
            var errno_ptr = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_ptr.unsafe_load() == 4:
                continue
            raise Error("LearnedFile: staged write failed")
        if written == 0:
            raise Error("LearnedFile: staged write made no progress")
        offset += written


def _learned_sync_parent(path: String) raises:
    var parent = _learned_cstring(_learned_parent(path))
    var fd = external_call["open64", Int32](
        parent.unsafe_ptr(), Int32(720896), Int32(0)
    )
    if fd < 0:
        raise Error("LearnedFile: cannot open parent directory to sync")
    var sync_result = external_call["fsync", Int32](fd)
    var close_result = external_call["close", Int32](fd)
    if sync_result != 0 or close_result != 0:
        raise Error("LearnedFile: cannot synchronise parent directory")


def _learned_atomic_write(path: String, content: String) raises:
    if len(content.bytes()) == 0 or len(content.bytes()) > MAX_LEARNED_BYTES:
        raise Error("LearnedFile: serialised state has an invalid size")
    var target = _learned_cstring(path)
    var staged = _learned_cstring(path + ".tmp.XXXXXX")
    var fd = external_call["mkstemp", Int32](staged.unsafe_ptr())
    if fd < 0:
        raise Error("LearnedFile: cannot create the staged file")
    try:
        _learned_write_all(fd, content)
        if external_call["fsync", Int32](fd) != 0:
            raise Error("LearnedFile: cannot synchronise the staged file")
    except error:
        _ = external_call["close", Int32](fd)
        _ = external_call["unlink", Int32](staged.unsafe_ptr())
        raise error
    if external_call["close", Int32](fd) != 0:
        _ = external_call["unlink", Int32](staged.unsafe_ptr())
        raise Error("LearnedFile: cannot close the staged file")
    if external_call["rename", Int32](staged.unsafe_ptr(), target.unsafe_ptr()) != 0:
        _ = external_call["unlink", Int32](staged.unsafe_ptr())
        raise Error("LearnedFile: cannot atomically replace the learned file")
    _learned_sync_parent(path)


def _learned_read(path: String) raises -> Tuple[Int, String]:
    """Read the learned file: (0, text) on success, (1, "") when
    the file does not exist, (2, reason) for every other failure
    (unreadable, not a regular file, empty, oversized, changed
    mid-read). The loader maps 1 to MISSING and 2 to REFUSED."""
    var encoded_path = _learned_cstring(path)
    var fd = external_call["open64", Int32](
        encoded_path.unsafe_ptr(), Int32(657408), Int32(0)
    )
    if fd < 0:
        var errno_ptr = external_call[
            "__errno_location", Pointer[Int32, MutUntrackedOrigin]
        ]()
        if errno_ptr.unsafe_load() == 2:
            return (1, String(""))
        return (2, String("the learned file could not be opened"))
    var stat = InlineArray[UInt64, 18](fill=0)
    if external_call["fstat", Int32](fd, stat.unsafe_ptr()) != 0:
        _ = external_call["close", Int32](fd)
        return (2, String("the learned file could not be inspected"))
    if stat[3] & 61440 != 32768:
        _ = external_call["close", Int32](fd)
        return (2, String("the learned path is not a regular file"))
    if stat[6] == 0:
        _ = external_call["close", Int32](fd)
        return (
            2,
            String("the learned file is empty (truncated or never written)"),
        )
    if stat[6] > UInt64(MAX_LEARNED_BYTES):
        _ = external_call["close", Int32](fd)
        return (2, String("the learned file exceeds the size cap"))
    var pinned_size = stat[6]
    var buffer = List[Byte]()
    buffer.resize(MAX_LEARNED_BYTES + 1, 0)
    var size = 0
    while True:
        var count = external_call["pread", Int](
            fd, buffer.unsafe_ptr().unsafe_offset(size),
            MAX_LEARNED_BYTES + 1 - size, Int64(size),
        )
        if count < 0:
            var errno_ptr = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_ptr.unsafe_load() == 4:
                continue
            _ = external_call["close", Int32](fd)
            return (2, String("the learned file read failed"))
        if count == 0:
            break
        size += count
        if size > MAX_LEARNED_BYTES:
            _ = external_call["close", Int32](fd)
            return (2, String("the learned file exceeds the size cap"))
    if UInt64(size) != pinned_size:
        _ = external_call["close", Int32](fd)
        return (2, String("the learned file changed size during the read"))
    if external_call["close", Int32](fd) != 0:
        return (2, String("the learned file close failed"))
    var content = List[Byte]()
    for index in range(size):
        content.append(buffer[index])
    try:
        var text = admit_text_bytes(content, "learned file", MAX_LEARNED_BYTES)
        return (0, text)
    except error:
        return (2, String("the learned file is not valid text: ") + String(error))


# --- the disk surface ------------------------------------------------------


def load_learned_file(path: String) -> LearnedLoad:
    """Load at open. Never raises: a missing file is the clean
    MISSING state, a corrupt/truncated/unreadable file is the
    clean REFUSED state with its reason, and only a whole,
    checksum-verified, fully validated file is LOADED."""
    var load = LearnedLoad()
    load.path = path
    var read: Tuple[Int, String]
    try:
        read = _learned_read(path)
    except error:
        load.status = LOAD_REFUSED
        load.reason = String(error)
        return load^
    if read[0] == 1:
        load.status = LOAD_MISSING
        load.reason = String("no learned file at this path")
        return load^
    if read[0] == 2:
        load.status = LOAD_REFUSED
        load.reason = read[1]
        return load^
    try:
        load.entries = parse_learned_file(read[1])
        load.status = LOAD_LOADED
        load.reason = String("loaded whole and verified")
    except error:
        load.status = LOAD_REFUSED
        load.reason = String(error)
        load.entries = List[LearnedEntry]()
    return load^


def save_learned_file(path: String, entries: List[LearnedEntry]) raises:
    """Write the whole learned state atomically. Serialisation
    validates first, so an invalid state never reaches disk;
    parent directories are created (the cache home's first
    save). An empty entry list writes a valid empty file --
    the state per-key erasure of the last entry leaves."""
    var text = serialize_learned_file(entries)
    _ensure_parent_dirs(path)
    _learned_atomic_write(path, text)


def store_learned_entry(path: String, entry: LearnedEntry) raises -> Int:
    """Learn one entry: replace the same key's prior entry or
    append, preserving every other key, and return the entry
    count now held. A REFUSED (corrupt) existing file raises --
    storing must never silently overwrite corruption; erase
    the file explicitly first. A MISSING file starts fresh."""
    entry.validate()
    var load = load_learned_file(path)
    if load.status == LOAD_REFUSED:
        raise Error(
            "LearnedFile: refusing to store into a corrupt learned"
            " file ("
            + load.reason
            + "); erase it explicitly first"
        )
    var entries = List[LearnedEntry]()
    for i in range(len(load.entries)):
        var existing = load.entries[i].copy()
        if not (
            existing.machine.equals(entry.machine)
            and existing.model.equals(entry.model)
        ):
            entries.append(existing^)
    entries.append(entry.copy())
    save_learned_file(path, entries)
    return len(entries)


struct EraseResult(Copyable, ImplicitlyCopyable):
    """One whole-file erasure's outcome as data: erased, or
    already absent (the clean state, not a failure), or failed
    with the reason. Erasure never raises -- a surface reports
    the outcome, it does not crash on it."""

    var erased: Bool
    var was_present: Bool
    var reason: String

    def __init__(out self):
        self.erased = False
        self.was_present = False
        self.reason = String("not attempted")


def erase_learned_file(path: String) -> EraseResult:
    """Erase the whole learned file. After it, a load is the
    clean MISSING state. An absent file is already the erased
    state and reports so."""
    var result = EraseResult()
    try:
        var encoded = _learned_cstring(path)
        if external_call["unlink", Int32](encoded.unsafe_ptr()) != 0:
            var errno_ptr = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_ptr.unsafe_load() == 2:
                result.erased = True
                result.was_present = False
                result.reason = String(
                    "no learned file was present; already erased"
                )
                return result
            result.reason = String("the learned file could not be unlinked")
            return result
        result.erased = True
        result.was_present = True
        result.reason = String("the learned file was erased")
        return result
    except error:
        result.reason = String(error)
        return result


def erase_learned_entry(
    path: String, machine: MachineKey, model: ModelShape
) raises -> Bool:
    """Erase one key's entry; True when an entry was removed.
    A missing file or an absent key is False, not an error --
    nothing was learned for the key either way. A REFUSED
    (corrupt) file raises: per-key surgery on a corrupt file
    would guess at its contents; whole-file erasure is the
    honest road there. Removing the last entry leaves a valid
    empty file (distinct from the erased-file MISSING state,
    and reported as such by load)."""
    var load = load_learned_file(path)
    if load.status == LOAD_MISSING:
        return False
    if load.status == LOAD_REFUSED:
        raise Error(
            "LearnedFile: refusing per-key erasure on a corrupt"
            " learned file ("
            + load.reason
            + "); erase the whole file instead"
        )
    var kept = List[LearnedEntry]()
    var removed = False
    for i in range(len(load.entries)):
        var existing = load.entries[i].copy()
        if (
            existing.machine.equals(machine)
            and existing.model.equals(model)
        ):
            removed = True
        else:
            kept.append(existing^)
    if not removed:
        return False
    save_learned_file(path, kept)
    return True
