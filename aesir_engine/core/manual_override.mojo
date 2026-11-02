"""Manual override supremacy (Janas road J-047).

J-036 built the placement option surface and recorded two things
it deliberately did not build: the `--mode` preset family the
census names (its section 9: J-047's to build or refuse), and
refusal of a placement against the real inventory (its section
7 note: "Placement against the real inventory is J-037 meeting
J-047 -- invalid devices refused with the reason, at open").
J-037 then built the inventory, J-040/J-041/J-042 the choosers
(manual choices fixed as MANUAL-FIXED, never ranked), J-044 the
learned file (learned values are DEFAULTS ONLY; a host consults
them only for kinds left on auto), J-045 re-trials (MANUAL-FIXED
kinds are never re-trialled), and J-046 the within-tolerance
proof (its builder refuses a non-auto option: a manual choice
has no auto choice to grade). This module is the supremacy
layer those slices point at. It builds three things:

1. THE PRESET SURFACE. `--mode auto|eco|max` (env equivalent
   AESIR_MODE), in J-036's exact shape: exact lower-case
   spellings, refusals with reasons, the supplying source
   recorded, precedence cli > env > default. A preset resolves
   into per-kind placement/thread INTENTS that sit BELOW hand
   choices (the census's own rule, J-003 row: "A hand choice
   holds over --mode presets"). What the modes mean is defined
   ONLY from the census and Aesir's own measured Part III
   facts -- never from invented device claims:
   - auto (the default, and the value when --mode is unset):
     no preset intent governs any kind; resolution falls
     through to learned, then auto measurement, exactly as
     J-044's host contract states today.
   - eco: a FIXED intent per kind -- the CPU at the serial
     rung, `cpu threads=1`. The device half is the census's
     one documented eco rule ("eco never uses the GPU for
     speed alone"), taken at its strongest honest reading: in
     eco the GPU is not in the field at all. The thread half
     is J-040's session default, the minimal-resource rung BY
     CONSTRUCTION (one thread, CPU only). Eco claims nothing
     about speed: it is an economy intent, not a measurement,
     and no eco number exists or is implied.
   - max: a MEASURE intent per kind -- no fixed placement;
     the kind is measured by its chooser over the FULL auto
     field (every device the inventory and the kill switches
     leave eligible, the widest thread ladder J-039 derives),
     and the learned default is BYPASSED for the kind. Max
     claims no device is fast: the GPU/NPU still carry no
     executor today and ride the chooser records as excluded /
     unmeasurable-with-reason exactly as under plain auto
     (J-040). What max changes is only that yesterday's
     learned choice may not shortcut today's measurement --
     the widest honest look, taken fresh. (Answered-locally:
     the census documents no max semantics beyond the name;
     this is Aesir's definition, recorded in the J-047 doc.)
   Anything a preset would need that does not exist fails
   closed exactly like the rest of Part III: a drafts preset
   intent is stored/resolved, never used -- require_draft_
   check_use (J-036, gap G1) still gates every drafts use
   until Part V.

2. PRECEDENCE RESOLUTION, per pass kind, as pure functions
   (resolve_kind_precedence / resolve_precedence). The stack,
   stated once and unit-tested layer by layer:
   (a) HAND. A resolved J-036 option that was actually set
       (source cli or env) governs absolutely:
       - single / co-work forms govern as MANUAL-FIXED: the
         choice stands verbatim; it is never measured against,
         never ranked, never re-trialled (J-040/J-045
         discipline, generalised here to the whole stack);
       - a race form governs as MANUAL-RACE: measurement is
         restricted to exactly the named members; preset and
         learned are skipped for the kind -- the hand chose
         the field, nobody widens or narrows it;
       - an EXPLICIT `auto` (written by hand, source cli/env)
         governs as MANUAL-AUTO: it is still a hand statement
         -- the user directed fresh measurement -- so preset
         and learned are skipped for the kind and the chooser
         measures the full auto field. (Answered-locally,
         recorded in the J-047 doc: J-036 stores an explicit
         auto with its supplying source precisely so this
         distinction exists; an UNSET auto, source default,
         is silence, not a statement, and falls through.)
   (b) PRESET. Only where the hand is silent (option unset):
       eco governs as PRESET-FIXED, max as PRESET-MEASURE
       (above). Mode auto governs nothing.
   (c) LEARNED. Only where the hand is silent AND no preset
       governs: a present J-044 choice for the kind applies
       as the session default (LEARNED), with its provenance
       (decision + originating option) on the resolution. A
       learned choice whose decision is MANUAL-FIXED is a
       persisted hand choice: it applies with that provenance
       stated and is never re-trialled (J-045). An absent
       learned kind supplies nothing.
   (d) AUTO. Where nothing above governs: the kind's chooser
       measures (AUTO), exactly J-040/J-041/J-042.
   Every resolution reports its governing layer and provenance
   and whether a re-trial could ever apply to it (only
   LEARNED-measured and AUTO outcomes can feed a learned
   entry J-045 re-trials; hand and preset outcomes are
   standing user instructions, not measurements).

3. INVALID-DEVICE REFUSAL AT OPEN, generalised
   (validate_open_choices). A hand, preset, or learned choice
   naming a device J-037's inventory says this machine does
   not have -- or the parked NPU as an execution device --
   is REFUSED at open with the reason naming the device, the
   pass kind, and the inventory fact (the entry's own rendered
   truth). The refusal is WHOLE, in every value form: a single
   device, either member of an `a+b` co-work pair, and every
   member of a comma race list is checked, and one absent
   member refuses the entire choice. No device is ever
   silently dropped from a list, substituted with auto/cpu,
   or trimmed so the rest can proceed -- the NPU-for-reply
   parse refusal of J-036, generalised to open time and to
   every source of a choice. J-036's parse layer still refuses
   what it can refuse without machine state (unknown words,
   killed devices, NPU for drafts/reply); this layer refuses
   what only the machine's truth can judge. The CPU is checked
   like any device: an inventory whose cpu entry is absent
   refuses even a cpu choice, with its reason.

HOST CONTRACT (binding; this module fakes no integration): a
surface opening a session (1) resolves placement (J-036) and
the mode (scan_mode_args + mode_env_inputs + resolve_mode
here), (2) observes the inventory (J-037) and loads/looks up
the learned entry (J-044), (3) calls validate_open_choices --
a refusal raises through open with its reason, before any
pass runs, (4) calls resolve_precedence and follows each
kind's governing layer: MANUAL-FIXED / PRESET-FIXED choices
stand as resolved; MANUAL-RACE / MANUAL-AUTO / PRESET-MEASURE
/ AUTO kinds go to their choosers under exactly the field the
resolution states; LEARNED kinds seed from the learned choice
instead of measuring. This slice wires the module into NO
live session path: no session consumes a precedence resolution
or a mode preset yet, and claiming otherwise would fake the
integration. See docs/janas/J047_MANUAL_OVERRIDE.md.
"""

from std.ffi import external_call
from std.memory import Pointer
from std.collections import InlineArray

from core.device_inventory import DeviceEntry, DeviceInventory
from core.learned_file import LearnedEntry, LearnedPassChoice
from core.placement_options import (
    DEVICE_CPU,
    DEVICE_NPU,
    PASS_DRAFTS,
    PASS_PROMPT,
    PASS_REPLY,
    PLACE_AUTO,
    PLACE_COWORK,
    PLACE_RACE,
    PLACE_SINGLE,
    SOURCE_CLI,
    SOURCE_DEFAULT,
    SOURCE_ENV,
    PlacementChoice,
    PlacementOption,
    PlacementOptions,
    device_name,
    effective_auto_devices,
    pass_name,
    source_name,
)

# Mode codes (the census's --mode family, J-003 row).
comptime MODE_AUTO = 0
comptime MODE_ECO = 1
comptime MODE_MAX = 2

# Governing layers (KindResolution.governing), in stack order.
comptime GOV_MANUAL_FIXED = 0
comptime GOV_MANUAL_RACE = 1
comptime GOV_MANUAL_AUTO = 2
comptime GOV_PRESET_FIXED = 3
comptime GOV_PRESET_MEASURE = 4
comptime GOV_LEARNED = 5
comptime GOV_AUTO = 6


def mode_name(code: Int) -> String:
    if code == MODE_ECO:
        return String("eco")
    if code == MODE_MAX:
        return String("max")
    return String("auto")


def governing_name(code: Int) -> String:
    if code == GOV_MANUAL_FIXED:
        return String("MANUAL-FIXED")
    if code == GOV_MANUAL_RACE:
        return String("MANUAL-RACE")
    if code == GOV_MANUAL_AUTO:
        return String("MANUAL-AUTO")
    if code == GOV_PRESET_FIXED:
        return String("PRESET-FIXED")
    if code == GOV_PRESET_MEASURE:
        return String("PRESET-MEASURE")
    if code == GOV_LEARNED:
        return String("LEARNED")
    return String("AUTO")


def parse_mode_value(text: String) raises -> Int:
    """One --mode value: auto | eco | max, exact lower-case.

    Anything else is refused with the reason, never
    reinterpreted (J-036's grammar discipline, this surface
    included)."""
    var value = String(text.strip())
    if value == "auto":
        return MODE_AUTO
    if value == "eco":
        return MODE_ECO
    if value == "max":
        return MODE_MAX
    raise Error(
        "ManualOverride: --mode value '"
        + text
        + "' is not a mode (modes are auto, eco, max, spelled"
        + " lower-case)"
    )


# --- the raw layer and resolution of the mode itself -------------------


struct RawModeInputs(Copyable, ImplicitlyCopyable):
    """Unparsed --mode strings from one layer (argv scan or env
    read), in J-036's raw-layer shape: a value plus a was-set
    flag; precedence is decided in resolve_mode, never here."""

    var value: String
    var value_set: Bool

    def __init__(out self):
        self.value = String("")
        self.value_set = False


struct ModeOption(Copyable, ImplicitlyCopyable):
    """The resolved preset: the mode, which layer supplied it,
    and whether any layer supplied it at all. An unset mode is
    mode auto with source default -- it governs nothing, and
    was_set keeps that silence distinguishable from an explicit
    --mode auto (which is recorded, and still governs nothing:
    auto is the absence of a preset intent, stated)."""

    var mode: Int
    var source: Int
    var was_set: Bool

    def __init__(out self):
        self.mode = MODE_AUTO
        self.source = SOURCE_DEFAULT
        self.was_set = False

    def describe(self) -> String:
        return (
            "mode: "
            + mode_name(self.mode)
            + " ("
            + source_name(self.source)
            + ")"
        )


def resolve_mode(cli: RawModeInputs, env: RawModeInputs) raises -> ModeOption:
    """Resolve the two raw layers: cli over env over default,
    per J-036's precedence. A set value is parsed (and refused)
    exactly once, at its supplying layer."""
    var option = ModeOption()
    if cli.value_set:
        option.mode = parse_mode_value(cli.value)
        option.source = SOURCE_CLI
        option.was_set = True
        return option
    if env.value_set:
        option.mode = parse_mode_value(env.value)
        option.source = SOURCE_ENV
        option.was_set = True
        return option
    return option


def _looks_like_mode_flag(arg: String) -> Bool:
    """True for args in this surface's namespace, known or not.

    --model is NOT in this namespace (other surfaces own it --
    the model picker's flag must never be refused here), so the
    namespace is exactly --mode, --mode=..., and --mode<other>
    spellings that do not continue into --model."""
    if arg == "--mode" or arg.startswith("--mode="):
        return True
    return arg.startswith("--mode") and not arg.startswith("--model")


def _split_mode_flag(arg: String) -> Tuple[String, String, Bool]:
    var eq = arg.find("=")
    if eq >= 0:
        return (String(arg[byte=:eq]), String(arg[byte=eq + 1:]), True)
    return (arg, String(""), False)


def scan_mode_args(args: List[String]) raises -> RawModeInputs:
    """Scan a shared argv for --mode (both `--mode value` and
    `--mode=value` forms). Flags outside this surface's
    namespace are ignored (other surfaces own them). Refusals:
    a missing value, the option set twice (state it once), and
    any unrecognised spelling inside the namespace -- a typo'd
    mode flag must not become a silently preset-less run."""
    var raw = RawModeInputs()
    var i = 0
    while i < len(args):
        var arg = args[i]
        if not _looks_like_mode_flag(arg):
            i += 1
            continue
        var split = _split_mode_flag(arg)
        var name = split[0]
        var inline_value = split[1]
        var has_eq = split[2]
        if name != "--mode":
            raise Error(
                "ManualOverride: unknown option '"
                + name
                + "' in the mode surface (the option is --mode)"
            )
        var value = inline_value
        if not has_eq:
            if i + 1 >= len(args):
                raise Error(
                    "ManualOverride: --mode requires a value, but"
                    " none follows it"
                )
            value = args[i + 1]
            i += 1
        if raw.value_set:
            raise Error("ManualOverride: --mode is set twice; state it once")
        raw.value = value
        raw.value_set = True
        i += 1
    return raw


def _mode_env_value(name: String) -> Tuple[Bool, String]:
    """Read one environment variable: (is_set, value), in
    placement_options' shape. An empty value counts as set --
    the mode parser refuses it with the reason."""
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


def mode_env_inputs() -> RawModeInputs:
    """Read AESIR_MODE into a raw layer (the env equivalent of
    --mode, named by Aesir's own AESIR_ rule, J-036 section 9's
    naming precedent for surface fields the census names only
    in flag form)."""
    var raw = RawModeInputs()
    var mode = _mode_env_value("AESIR_MODE")
    if mode[0]:
        raw.value = mode[1]
        raw.value_set = True
    return raw


# --- preset intents ------------------------------------------------------


struct PresetIntent(Copyable, ImplicitlyCopyable):
    """What one mode asks of one pass kind, before precedence:
    governs says whether the preset speaks for the kind at all;
    fixed says whether it speaks a fixed placement (eco) or a
    measurement directive (max). device/threads carry the fixed
    placement when fixed; label is its rendered form."""

    var governs: Bool
    var fixed: Bool
    var device: Int
    var threads: Int
    var label: String
    var note: String

    def __init__(out self):
        self.governs = False
        self.fixed = False
        self.device = DEVICE_CPU
        self.threads = 0
        self.label = String("")
        self.note = String("no preset intent")


def preset_intent(mode: ModeOption, pass_kind: Int) -> PresetIntent:
    """The per-kind intent of a resolved mode (module header).

    eco and max speak for every kind in the same device/thread
    terms; the kind enters the note, and the drafts kind's note
    carries its fail-closed state so no reader mistakes a
    resolved drafts intent for a usable one."""
    var intent = PresetIntent()
    var kind_name = pass_name(pass_kind)
    if mode.mode == MODE_ECO:
        intent.governs = True
        intent.fixed = True
        intent.device = DEVICE_CPU
        intent.threads = 1
        intent.label = String("cpu threads=1")
        intent.note = (
            "preset eco ("
            + source_name(mode.source)
            + "): the "
            + kind_name
            + " kind runs on the cpu at the serial rung -- eco"
            " never uses the gpu for speed alone (census J-003),"
            " taken here at its strongest honest reading (the"
            " gpu is not in eco's field at all), and the serial"
            " rung is the session default of J-040, minimal by"
            " construction; eco claims no speed, only economy"
        )
    elif mode.mode == MODE_MAX:
        intent.governs = True
        intent.fixed = False
        intent.label = String("auto (full field)")
        intent.note = (
            "preset max ("
            + source_name(mode.source)
            + "): the "
            + kind_name
            + " kind is measured over the full auto field and"
            " the learned default is bypassed, so the widest"
            " honest look is taken fresh; max claims no device"
            " is fast -- devices without an executor still ride"
            " the chooser record as excluded /"
            " unmeasurable-with-reason (J-040)"
        )
    else:
        intent.note = String(
            "mode auto states no preset intent for the "
            + kind_name
            + " kind; resolution falls through to the learned"
            " default, then auto measurement"
        )
    if pass_kind == PASS_DRAFTS and intent.governs:
        intent.note += (
            "; choosing is not using -- any use of a drafts"
            " placement still fails closed (J-036 gap G1) until"
            " Part V builds the pass"
        )
    return intent


# --- precedence resolution -------------------------------------------------


struct KindResolution(Copyable, ImplicitlyCopyable):
    """One pass kind's resolved precedence: which layer governs,
    its provenance in words, the effective placement when the
    governing layer fixes one (has_fixed), the measurement
    field when the governing layer directs measurement
    (measure_field), whether a re-trial could ever apply to
    this outcome, and the reason the layer governs."""

    var kind: Int
    var governing: Int
    var provenance: String
    var effective_text: String
    var device: Int
    var threads: Int
    var has_fixed: Bool
    var measure_field: String
    var retrial_applies: Bool
    var reason: String

    def __init__(out self):
        self.kind = PASS_PROMPT
        self.governing = GOV_AUTO
        self.provenance = String("")
        self.effective_text = String("auto")
        self.device = -1
        self.threads = 0
        self.has_fixed = False
        self.measure_field = String("")
        self.retrial_applies = True
        self.reason = String("not resolved")

    def render(self) -> String:
        var out_str = (
            pass_name(self.kind)
            + ": "
            + governing_name(self.governing)
            + " ("
            + self.provenance
            + ")"
        )
        if self.has_fixed:
            out_str += " -- fixed: " + self.effective_text
        else:
            out_str += (
                " -- measure: field ["
                + self.measure_field
                + "]"
            )
        out_str += " -- " + self.reason + "\n"
        return out_str


def resolve_kind_precedence(
    pass_kind: Int,
    hand: PlacementOption,
    mode: ModeOption,
    learned: LearnedPassChoice,
    auto_field: String,
) -> KindResolution:
    """The precedence stack (module header) for ONE kind, as a
    pure function of the kind's resolved hand option, the
    resolved mode, the kind's learned choice (its ABSENT state
    when nothing was learned or no entry applies), and the
    kill-shrunk auto field text (effective_auto_devices)."""
    var resolution = KindResolution()
    resolution.kind = pass_kind
    var kind_name = pass_name(pass_kind)

    # (a) The hand, when it spoke at all.
    if hand.was_set:
        var choice = hand.choice
        resolution.provenance = (
            "hand choice, source " + source_name(hand.source)
        )
        if choice.form == PLACE_SINGLE or choice.form == PLACE_COWORK:
            resolution.governing = GOV_MANUAL_FIXED
            resolution.effective_text = choice.describe()
            resolution.device = choice.first
            resolution.threads = 0
            resolution.has_fixed = True
            resolution.retrial_applies = False
            resolution.reason = (
                "the hand choice '"
                + choice.describe()
                + "' for the "
                + kind_name
                + " kind holds over the preset, the learned"
                " default, and auto measurement: it is never"
                " measured against, never ranked, and never"
                " re-trialled"
            )
        elif choice.form == PLACE_RACE:
            resolution.governing = GOV_MANUAL_RACE
            resolution.effective_text = choice.describe()
            resolution.measure_field = choice.describe()
            resolution.retrial_applies = False
            resolution.reason = (
                "the hand race '"
                + choice.describe()
                + "' for the "
                + kind_name
                + " kind fixes the measured field to exactly its"
                " named members: the preset and the learned"
                " default are skipped, and no layer widens or"
                " narrows the field the hand chose"
            )
        else:
            resolution.governing = GOV_MANUAL_AUTO
            resolution.effective_text = String("auto")
            resolution.measure_field = auto_field
            resolution.retrial_applies = False
            resolution.reason = (
                "an explicit auto, written by hand (source "
                + source_name(hand.source)
                + "), is a hand statement for the "
                + kind_name
                + " kind: it directs fresh measurement over the"
                " full auto field, so the preset and the learned"
                " default are skipped -- the measurement the user"
                " asked for is the one that runs"
            )
        if pass_kind == PASS_DRAFTS:
            resolution.reason += (
                "; choosing is not using -- any use of a drafts"
                " placement still fails closed (J-036 gap G1)"
                " until Part V builds the pass"
            )
        return resolution

    # (b) The preset, only where the hand is silent.
    var intent = preset_intent(mode, pass_kind)
    if intent.governs:
        resolution.provenance = (
            "preset " + mode_name(mode.mode) + ", source "
            + source_name(mode.source)
        )
        if intent.fixed:
            resolution.governing = GOV_PRESET_FIXED
            resolution.effective_text = intent.label
            resolution.device = intent.device
            resolution.threads = intent.threads
            resolution.has_fixed = True
            resolution.retrial_applies = False
            resolution.reason = (
                intent.note
                + "; the hand is silent for the "
                + kind_name
                + " kind, so the preset governs over the learned"
                " default and auto measurement"
            )
        else:
            resolution.governing = GOV_PRESET_MEASURE
            resolution.effective_text = String("auto")
            resolution.measure_field = auto_field
            resolution.retrial_applies = False
            resolution.reason = (
                intent.note
                + "; the hand is silent for the "
                + kind_name
                + " kind, so the preset governs over the learned"
                " default"
            )
        return resolution

    # (c) The learned default, only under silence + no preset.
    if learned.present:
        resolution.governing = GOV_LEARNED
        resolution.effective_text = learned.placement_text
        resolution.device = learned.device
        resolution.threads = learned.threads
        resolution.has_fixed = True
        if learned.decision == "MANUAL-FIXED":
            resolution.provenance = (
                "learned default (a persisted hand choice:"
                " decision MANUAL-FIXED, from option "
                + learned.option_text
                + ")"
            )
            resolution.retrial_applies = False
            resolution.reason = (
                "the learned entry for the "
                + kind_name
                + " kind is itself a persisted hand choice"
                " (MANUAL-FIXED, from option '"
                + learned.option_text
                + "'): it applies as the session default with"
                " its provenance stated, and it is never"
                " re-trialled (J-045)"
            )
        else:
            resolution.provenance = (
                "learned default (decision "
                + learned.decision
                + ", from option "
                + learned.option_text
                + ")"
            )
            resolution.retrial_applies = True
            resolution.reason = (
                "the hand is silent and no preset governs the "
                + kind_name
                + " kind, so the learned choice applies as the"
                " session default (J-044: defaults only -- any"
                " hand statement above would have overridden it)"
            )
        return resolution

    # (d) Auto measurement: nothing above governs.
    resolution.governing = GOV_AUTO
    resolution.provenance = String("no hand, preset, or learned statement")
    resolution.effective_text = String("auto")
    resolution.measure_field = auto_field
    resolution.retrial_applies = True
    resolution.reason = (
        "nothing governs the "
        + kind_name
        + " kind -- no hand choice, no preset intent, no learned"
        " choice -- so its chooser measures (J-040/J-041/J-042)"
    )
    if pass_kind == PASS_DRAFTS:
        resolution.reason += (
            "; the drafts chooser's honest state today is its"
            " unmeasurable fallback (gap G1)"
        )
    return resolution


struct OverrideResolution(Copyable, Movable):
    """The whole precedence resolution: the mode, the auto
    field the resolutions were taken against, and one
    KindResolution per pass kind, rendered by report()."""

    var mode: ModeOption
    var auto_field: String
    var prompt: KindResolution
    var drafts: KindResolution
    var reply: KindResolution

    def __init__(out self):
        self.mode = ModeOption()
        self.auto_field = String("")
        self.prompt = KindResolution()
        self.drafts = KindResolution()
        self.reply = KindResolution()

    def for_kind(self, pass_kind: Int) -> KindResolution:
        if pass_kind == PASS_DRAFTS:
            return self.drafts
        if pass_kind == PASS_REPLY:
            return self.reply
        return self.prompt

    def report(self) -> String:
        var out_str = String("manual override resolution (J-047)\n")
        out_str += self.mode.describe() + "\n"
        out_str += (
            "precedence: hand > preset > learned > auto, per"
            " kind; a hand choice is never measured against,"
            " never ranked, and never re-trialled\n"
        )
        out_str += self.prompt.render()
        out_str += self.drafts.render()
        out_str += self.reply.render()
        out_str += (
            "learned values are defaults only; an explicit"
            " option overrides the learned value for its kind,"
            " always (J-044)\n"
        )
        return out_str


def resolve_precedence(
    options: PlacementOptions,
    mode: ModeOption,
    learned: LearnedEntry,
    has_learned: Bool,
) -> OverrideResolution:
    """Resolve all three kinds. has_learned states whether
    `learned` is an APPLIED entry (J-044 lookup): when it is
    False the entry argument is ignored and every kind sees
    the ABSENT learned state -- a non-applied entry (missing,
    refused, or key-mismatched) supplies nothing, exactly as
    J-044's lookup discipline states."""
    var resolution = OverrideResolution()
    resolution.mode = mode
    resolution.auto_field = effective_auto_devices(options.kills)
    var absent = LearnedPassChoice()
    var prompt_learned = learned.prompt if has_learned else absent
    var drafts_learned = learned.drafts if has_learned else absent
    var reply_learned = learned.reply if has_learned else absent
    resolution.prompt = resolve_kind_precedence(
        PASS_PROMPT, options.prompt, mode, prompt_learned,
        resolution.auto_field,
    )
    resolution.drafts = resolve_kind_precedence(
        PASS_DRAFTS, options.drafts, mode, drafts_learned,
        resolution.auto_field,
    )
    resolution.reply = resolve_kind_precedence(
        PASS_REPLY, options.reply, mode, reply_learned,
        resolution.auto_field,
    )
    return resolution^


# --- invalid-device refusal at open ----------------------------------------


def require_named_device_present(
    pass_kind: Int,
    via: String,
    option_text: String,
    device_code: Int,
    inventory: DeviceInventory,
) raises:
    """Refuse one named device the inventory does not hold.

    The reason names the device, the pass kind, the choice it
    rode in on, and the inventory fact in the entry's own
    rendered words. The parked NPU needs no special case here:
    its inventory entry is absent-by-ledger on this road, so
    naming it as an execution device refuses through exactly
    this path, with the parked reason on the face of the
    refusal."""
    var entry = inventory.entry(device_name(device_code))
    if not entry.present:
        raise Error(
            "ManualOverride: "
            + via
            + " '"
            + option_text
            + "' names "
            + device_name(device_code)
            + " for a "
            + pass_name(pass_kind)
            + " pass, but this machine's inventory says: "
            + entry.render()
            + " -- the choice is refused whole at open; no"
            " device is dropped from it, substituted, or trimmed"
            " so the rest can proceed (J-047 generalised refusal)"
        )


def validate_choice_at_open(
    pass_kind: Int,
    choice: PlacementChoice,
    via: String,
    inventory: DeviceInventory,
) raises:
    """Check EVERY device one placement value names against the
    inventory: a single device, both members of a co-work pair,
    every member of a race list. The first absent member
    refuses the whole value (require_named_device_present);
    auto names no device and is never refused here."""
    for i in range(choice.count):
        require_named_device_present(
            pass_kind, via, choice.describe(), choice.device_at(i),
            inventory,
        )


def validate_open_choices(
    options: PlacementOptions,
    mode: ModeOption,
    learned: LearnedEntry,
    has_learned: Bool,
    inventory: DeviceInventory,
) raises:
    """The open-time refusal, whole and in a stated order:
    hand choices first (prompt, drafts, reply -- only kinds
    the user actually set name devices), then the preset's
    fixed devices (eco's cpu, per kind), then the learned
    defaults' chosen devices (only when an entry applies).
    The first refusal raises with its reason; a return means
    every named device is present in the inventory. Learned
    choices are validated even for kinds a hand choice or
    preset governs above them is NOT done -- a shadowed
    learned device is never applied, so it is never refused:
    only the choices that would actually govern are checked
    beyond the hand layer, via resolve_precedence's own
    verdicts."""
    var kinds = List[Int]()
    kinds.append(PASS_PROMPT)
    kinds.append(PASS_DRAFTS)
    kinds.append(PASS_REPLY)
    var hand_options = List[PlacementOption]()
    hand_options.append(options.prompt)
    hand_options.append(options.drafts)
    hand_options.append(options.reply)
    for i in range(3):
        if hand_options[i].was_set:
            validate_choice_at_open(
                kinds[i],
                hand_options[i].choice,
                "--" + pass_name(kinds[i]) + "-on (hand choice)",
                inventory,
            )
    var resolution = resolve_precedence(options, mode, learned, has_learned)
    for i in range(3):
        var kind = kinds[i]
        var resolved = resolution.for_kind(kind)
        # The hand layer was checked above in full (every named
        # device, every form); below it, only a governing fixed
        # device the hand did not already name needs the check.
        if resolved.governing == GOV_PRESET_FIXED:
            require_named_device_present(
                kind,
                "--mode " + mode_name(mode.mode) + " (preset)",
                resolved.effective_text,
                resolved.device,
                inventory,
            )
        elif resolved.governing == GOV_LEARNED:
            var learned_choice = learned.pass_choice(kind)
            require_named_device_present(
                kind,
                "learned default (from option '"
                + learned_choice.option_text
                + "')",
                learned_choice.placement_text,
                learned_choice.device,
                inventory,
            )
