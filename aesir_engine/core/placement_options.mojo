"""Per-pass device placement options (Janas road J-036).

J-035 named Aesir's three pass kinds -- prompt, draft-check, reply --
role first, width second, and recorded that no token count routes
execution anywhere in the tree today (its gap G3). This module is the
option surface those kinds are placed through: the parsing,
validation, precedence, and refusal layer. It executes nothing, it
chooses nothing, and it launches nothing. Auto choice by measurement
is J-038--J-042; co-work execution is J-043; the draft-check pass
itself is Part V (J-071/J-072). What exists here, and only here, is
the grammar every later slice consumes:

- --prompt-on / --drafts-on / --reply-on, each taking `auto` (the
  default when unset), a single device, `a+b` co-work (exactly two
  distinct devices working one pass together), or a comma list of
  two or more distinct devices (the race candidates a later slice
  measures among). Aesir's device words are its own tree's words:
  cpu, gpu, npu.
- Env equivalents AESIR_PROMPT_ON / AESIR_DRAFTS_ON / AESIR_REPLY_ON.
  Precedence, stated once and tested: a command-line value beats the
  environment, the environment beats the default. The resolved
  option records which layer supplied it.
- Kill switches --no-gpu / --no-npu and the env forms AESIR_GPU=0 /
  AESIR_NPU=0 (AESIR_GPU=1 / AESIR_NPU=1 state explicitly that the
  device is not killed; any other value is refused, never
  reinterpreted). A kill is not subject to precedence: a device
  killed from any source is dead for every option, and a placement
  that names a killed device is refused with the reason. `auto`
  under a kill stays valid -- the CPU always remains -- and the
  resolved option's effective view names the surviving devices.
  --no-cpu is refused: the CPU takes part in every pass (the census's
  standing role, and Aesir's own oracle discipline), so there is no
  CPU kill switch.
- Pass-kind legality, refused at parse/validation with the reason:
  the NPU never takes a reply pass and never takes a draft-check
  pass (the census records both refusals for Janas; the roadmap's
  J-047 names the NPU-for-reply refusal pattern, generalised, as
  Aesir's intended shape, so Aesir refuses -- it never silently
  drops a named device from a list and races the rest).
- The draft-check absence, fail-closed at use: Aesir has no
  draft-check pass yet (J-035 gap G1). --drafts-on therefore parses
  and validates exactly like the other two options, and the parsed
  value is stored -- but require_draft_check_use() raises, always,
  until Part V builds the pass. A drafts placement is never silently
  ignored and never silently honoured.

Quality tiers ride this same surface (J-014 gate adjustment A2:
placement options and quality options are one surface in Janas and
are one surface in Aesir). Parsed and stored here, beside placement:

- --quality high|medium|low (env AESIR_QUALITY). Aesir's default is
  high -- nothing lowered -- where Janas's documented default is
  low: a conscious difference, recorded in the J-036 doc. Aesir's
  levers do not exist yet, and a default that lowered quality would
  silently change the function every faithfulness grade stands on.
- --head 4 (env AESIR_HEAD): the head-requant lever's option. The
  only documented lever value is 4; the native head is the absence
  of the option, any other value is refused.
- --attention fast|exact (env AESIR_ATTENTION; default exact).
- --bits 2|4|6 (env AESIR_BITS): the bit-plane expert-read lever's
  option; the native read is the absence of the option.
- require_quality_use() fails closed on any lowered tier or engaged
  lever, with the reason: the levers are not built, and their
  agreement evidence is produced under J-091's ladder. --quality
  high with no lever engaged is exactly today's behaviour and is
  the only quality state a session may run under.

HOST CONTRACT (binding on the surfaces that consume this module;
this module fakes no integration): a CLI or server surface scans its
argv with scan_placement_args, reads the environment with
placement_env_inputs, resolves once at startup with
resolve_placement_options (which raises on the first refusal, with
its reason), and reports the resolved surface with describe(). No
session consumes a placement choice yet -- prompt and reply passes
still run where their surfaces have always run them -- and no
surface may claim otherwise until J-038+ wires consumption. The
parsed config is the deliverable; the consumption gap is named in
docs/janas/J036_PLACEMENT_OPTIONS.md and roaded to J-038+.
"""

from std.ffi import external_call
from std.memory import Pointer
from std.collections import InlineArray

# Device codes. The names are Aesir's own device words, as used by
# the tree's sessions and the J-003 census's value forms.
comptime DEVICE_CPU = 0
comptime DEVICE_GPU = 1
comptime DEVICE_NPU = 2

# Pass-kind codes (J-035's adopted taxonomy, role-primary).
comptime PASS_PROMPT = 0
comptime PASS_DRAFTS = 1
comptime PASS_REPLY = 2

# Placement value forms.
comptime PLACE_AUTO = 0
comptime PLACE_SINGLE = 1
comptime PLACE_COWORK = 2
comptime PLACE_RACE = 3

# Option sources, recorded on every resolved option.
comptime SOURCE_DEFAULT = 0
comptime SOURCE_ENV = 1
comptime SOURCE_CLI = 2


def device_name(code: Int) -> String:
    if code == DEVICE_GPU:
        return String("gpu")
    if code == DEVICE_NPU:
        return String("npu")
    return String("cpu")


def device_code(name: String) raises -> Int:
    """One device word to its code; anything else is refused by name."""
    if name == "cpu":
        return DEVICE_CPU
    if name == "gpu":
        return DEVICE_GPU
    if name == "npu":
        return DEVICE_NPU
    raise Error(
        "Placement: unknown device '"
        + name
        + "' (devices are cpu, gpu, npu, spelled lower-case)"
    )


def pass_name(kind: Int) -> String:
    if kind == PASS_DRAFTS:
        return String("drafts")
    if kind == PASS_REPLY:
        return String("reply")
    return String("prompt")


def source_name(source: Int) -> String:
    if source == SOURCE_CLI:
        return String("cli")
    if source == SOURCE_ENV:
        return String("env")
    return String("default")


struct PlacementChoice(Copyable, ImplicitlyCopyable):
    """One parsed placement value: its form and its devices.

    Devices are stored as codes in written order; `count` is 0 for
    auto, 1 for a single device, 2 for co-work, and 2..3 for a race
    list (three devices exist, so three is the whole field).
    """

    var form: Int
    var first: Int
    var second: Int
    var third: Int
    var count: Int

    def __init__(out self):
        self.form = PLACE_AUTO
        self.first = DEVICE_CPU
        self.second = DEVICE_CPU
        self.third = DEVICE_CPU
        self.count = 0

    def device_at(self, index: Int) -> Int:
        if index == 1:
            return self.second
        if index == 2:
            return self.third
        return self.first

    def names_device(self, code: Int) -> Bool:
        for i in range(self.count):
            if self.device_at(i) == code:
                return True
        return False

    def describe(self) -> String:
        """The canonical written form: auto, gpu, npu+gpu, npu,gpu."""
        if self.form == PLACE_AUTO:
            return String("auto")
        var out_str = device_name(self.first)
        if self.form == PLACE_COWORK:
            return out_str + "+" + device_name(self.second)
        if self.form == PLACE_RACE:
            out_str += "," + device_name(self.second)
            if self.count == 3:
                out_str += "," + device_name(self.third)
        return out_str


def _trim(text: String) -> String:
    return String(text.strip())


def parse_placement_value(text: String, pass_kind: Int) raises -> PlacementChoice:
    """Parse one placement value for one pass kind.

    Grammar: `auto` | device | device `+` device | device (`,`
    device)+. Refusals (all with reasons, all tested): empty value,
    unknown device, `auto` used as a list member, co-work with the
    same device twice / more than two devices / an empty side, a
    race list with an empty entry or a duplicate, a value mixing
    `+` and `,`, and the NPU named for a draft-check or reply pass.
    Kill switches are NOT applied here -- resolve_placement_options
    applies them, because a parse has no machine state.
    """
    var kind_name = pass_name(pass_kind)
    var value = _trim(text)
    if value.byte_length() == 0:
        raise Error(
            "Placement: --"
            + kind_name
            + "-on value must not be empty (auto, a device, a+b, or a,b)"
        )
    var choice = PlacementChoice()
    if value == "auto":
        return choice
    var has_plus = value.find("+") >= 0
    var has_comma = value.find(",") >= 0
    if has_plus and has_comma:
        raise Error(
            "Placement: --"
            + kind_name
            + "-on value '"
            + value
            + "' mixes co-work '+' and race ','; write one form"
        )
    if has_plus:
        var parts = value.split("+")
        if len(parts) != 2:
            raise Error(
                "Placement: co-work '"
                + value
                + "' must name exactly two devices joined by '+'"
            )
        var left = _trim(String(parts[0]))
        var right = _trim(String(parts[1]))
        if left.byte_length() == 0 or right.byte_length() == 0:
            raise Error(
                "Placement: co-work '"
                + value
                + "' has an empty side; both sides must name a device"
            )
        if left == "auto" or right == "auto":
            raise Error(
                "Placement: co-work '"
                + value
                + "' names 'auto', which is a whole value, not a device"
            )
        var a = device_code(left)
        var b = device_code(right)
        if a == b:
            raise Error(
                "Placement: co-work '"
                + value
                + "' names "
                + left
                + " twice; co-work needs two distinct devices"
            )
        choice.form = PLACE_COWORK
        choice.first = a
        choice.second = b
        choice.count = 2
    elif has_comma:
        var parts = value.split(",")
        if len(parts) < 2 or len(parts) > 3:
            raise Error(
                "Placement: race list '"
                + value
                + "' must name two or three distinct devices joined by ','"
            )
        choice.form = PLACE_RACE
        choice.count = len(parts)
        for i in range(len(parts)):
            var entry = _trim(String(parts[i]))
            if entry.byte_length() == 0:
                raise Error(
                    "Placement: race list '"
                    + value
                    + "' has an empty entry; every entry must name a device"
                )
            if entry == "auto":
                raise Error(
                    "Placement: race list '"
                    + value
                    + "' names 'auto', which is a whole value, not a device"
                )
            var code = device_code(entry)
            for j in range(i):
                if choice.device_at(j) == code:
                    raise Error(
                        "Placement: race list '"
                        + value
                        + "' names "
                        + entry
                        + " twice; race candidates must be distinct"
                    )
            if i == 0:
                choice.first = code
            elif i == 1:
                choice.second = code
            else:
                choice.third = code
    else:
        choice.form = PLACE_SINGLE
        choice.first = device_code(value)
        choice.count = 1
    # Pass-kind legality: the NPU never takes a draft-check pass and
    # never takes a reply pass. Refused whole, never trimmed out of
    # the value -- a named device is never silently dropped.
    if pass_kind != PASS_PROMPT and choice.names_device(DEVICE_NPU):
        raise Error(
            "Placement: --"
            + kind_name
            + "-on '"
            + value
            + "' names the npu, which never takes a "
            + kind_name
            + " pass (draft-check and reply passes run on cpu/gpu only)"
        )
    return choice


struct DeviceKills(Copyable, ImplicitlyCopyable):
    """The kill switches, from every source, with their provenance."""

    var gpu_killed: Bool
    var npu_killed: Bool
    var gpu_source: String
    var npu_source: String

    def __init__(out self):
        self.gpu_killed = False
        self.npu_killed = False
        self.gpu_source = String("")
        self.npu_source = String("")

    def is_killed(self, code: Int) -> Bool:
        if code == DEVICE_GPU:
            return self.gpu_killed
        if code == DEVICE_NPU:
            return self.npu_killed
        return False

    def kill_source(self, code: Int) -> String:
        if code == DEVICE_GPU:
            return self.gpu_source
        if code == DEVICE_NPU:
            return self.npu_source
        return String("")

    def any(self) -> Bool:
        return self.gpu_killed or self.npu_killed


def validate_against_kills(
    choice: PlacementChoice, pass_kind: Int, kills: DeviceKills
) raises:
    """Refuse a placement that names a killed device, with the reason.

    `auto` names no device and is never refused here: its effective
    view simply loses the killed devices (the CPU always remains).
    """
    for i in range(choice.count):
        var code = choice.device_at(i)
        if kills.is_killed(code):
            raise Error(
                "Placement: --"
                + pass_name(pass_kind)
                + "-on '"
                + choice.describe()
                + "' names "
                + device_name(code)
                + ", which is killed by "
                + kills.kill_source(code)
            )


def effective_auto_devices(kills: DeviceKills) -> String:
    """The devices `auto` may still choose among, kills applied."""
    var out_str = String("cpu")
    if not kills.gpu_killed:
        out_str += ", gpu"
    if not kills.npu_killed:
        out_str += ", npu"
    return out_str


struct RawPlacementInputs(Copyable, ImplicitlyCopyable):
    """Unparsed option strings from one layer (argv scan or env read).

    Every field is a raw string plus a was-set flag, in the tree's
    *_was_set style (cli/options.mojo): precedence is a property of
    the layers, decided in resolve_placement_options, never here.
    """

    var prompt: String
    var prompt_set: Bool
    var drafts: String
    var drafts_set: Bool
    var reply: String
    var reply_set: Bool
    var quality: String
    var quality_set: Bool
    var head: String
    var head_set: Bool
    var attention: String
    var attention_set: Bool
    var bits: String
    var bits_set: Bool
    var no_gpu: Bool
    var no_npu: Bool
    var gpu_env: String
    var gpu_env_set: Bool
    var npu_env: String
    var npu_env_set: Bool

    def __init__(out self):
        self.prompt = String("")
        self.prompt_set = False
        self.drafts = String("")
        self.drafts_set = False
        self.reply = String("")
        self.reply_set = False
        self.quality = String("")
        self.quality_set = False
        self.head = String("")
        self.head_set = False
        self.attention = String("")
        self.attention_set = False
        self.bits = String("")
        self.bits_set = False
        self.no_gpu = False
        self.no_npu = False
        self.gpu_env = String("")
        self.gpu_env_set = False
        self.npu_env = String("")
        self.npu_env_set = False


struct PlacementOption(Copyable, ImplicitlyCopyable):
    """One resolved placement: the parsed choice plus its source."""

    var choice: PlacementChoice
    var source: Int
    var was_set: Bool

    def __init__(out self):
        self.choice = PlacementChoice()
        self.source = SOURCE_DEFAULT
        self.was_set = False


struct QualityOptions(Copyable, ImplicitlyCopyable):
    """The resolved quality-tier surface (gate A2's other half).

    Defaults are today's behaviour exactly: quality high (nothing
    lowered), native head, exact attention, native expert reads.
    head_bits / bits are 0 when unset (the native read); sources are
    recorded per field in the *_source companions.
    """

    var quality: String
    var quality_source: Int
    var head_bits: Int
    var head_source: Int
    var attention: String
    var attention_source: Int
    var bits: Int
    var bits_source: Int

    def __init__(out self):
        self.quality = String("high")
        self.quality_source = SOURCE_DEFAULT
        self.head_bits = 0
        self.head_source = SOURCE_DEFAULT
        self.attention = String("exact")
        self.attention_source = SOURCE_DEFAULT
        self.bits = 0
        self.bits_source = SOURCE_DEFAULT

    def any_lever_engaged(self) -> Bool:
        return (
            self.quality != "high"
            or self.head_bits != 0
            or self.attention != "exact"
            or self.bits != 0
        )


struct PlacementOptions(Copyable, ImplicitlyCopyable):
    """The whole resolved J-036 surface: three placements, the
    quality options, and the kill state they were resolved under."""

    var prompt: PlacementOption
    var drafts: PlacementOption
    var reply: PlacementOption
    var quality: QualityOptions
    var kills: DeviceKills

    def __init__(out self):
        self.prompt = PlacementOption()
        self.drafts = PlacementOption()
        self.reply = PlacementOption()
        self.quality = QualityOptions()
        self.kills = DeviceKills()

    def describe(self) -> String:
        """The startup report: every option, its value, its source,
        and -- for `auto` under a kill -- the surviving field. The
        drafts line carries its fail-closed state in the open, so no
        reader can mistake a stored drafts placement for a live one.
        """
        var out_str = String("")
        out_str += (
            "prompt: "
            + self.prompt.choice.describe()
            + " ("
            + source_name(self.prompt.source)
            + ")"
        )
        if self.prompt.choice.form == PLACE_AUTO:
            out_str += (
                " [auto field: "
                + effective_auto_devices(self.kills)
                + "]"
            )
        out_str += "\n"
        out_str += (
            "drafts: "
            + self.drafts.choice.describe()
            + " ("
            + source_name(self.drafts.source)
            + ")"
        )
        if self.drafts.choice.form == PLACE_AUTO:
            out_str += (
                " [auto field: "
                + effective_auto_devices(self.kills)
                + "]"
            )
        out_str += (
            " [use refused: no draft-check pass exists yet"
            " (J-035 gap G1; Part V J-071/J-072)]\n"
        )
        out_str += (
            "reply: "
            + self.reply.choice.describe()
            + " ("
            + source_name(self.reply.source)
            + ")"
        )
        if self.reply.choice.form == PLACE_AUTO:
            out_str += (
                " [auto field: "
                + effective_auto_devices(self.kills)
                + "]"
            )
        out_str += "\n"
        out_str += (
            "quality: "
            + self.quality.quality
            + " ("
            + source_name(self.quality.quality_source)
            + "); head: "
            + (
                String("native")
                if self.quality.head_bits == 0
                else String(self.quality.head_bits)
            )
            + " ("
            + source_name(self.quality.head_source)
            + "); attention: "
            + self.quality.attention
            + " ("
            + source_name(self.quality.attention_source)
            + "); bits: "
            + (
                String("native")
                if self.quality.bits == 0
                else String(self.quality.bits)
            )
            + " ("
            + source_name(self.quality.bits_source)
            + ")\n"
        )
        if self.kills.any():
            out_str += "kills:"
            if self.kills.gpu_killed:
                out_str += " gpu by " + self.kills.gpu_source + ";"
            if self.kills.npu_killed:
                out_str += " npu by " + self.kills.npu_source + ";"
            out_str += "\n"
        return out_str


def parse_quality_value(text: String) raises -> String:
    var value = _trim(text)
    if value == "high" or value == "medium" or value == "low":
        return value
    raise Error(
        "Placement: --quality value '"
        + text
        + "' is not a tier (tiers are high, medium, low)"
    )


def parse_head_value(text: String) raises -> Int:
    var value = _trim(text)
    if value == "4":
        return 4
    raise Error(
        "Placement: --head value '"
        + text
        + "' is not a lever value (the head lever takes 4;"
        + " the native head is the absence of the option)"
    )


def parse_attention_value(text: String) raises -> String:
    var value = _trim(text)
    if value == "fast" or value == "exact":
        return value
    raise Error(
        "Placement: --attention value '"
        + text
        + "' is not a lever value (attention takes fast or exact)"
    )


def parse_bits_value(text: String) raises -> Int:
    var value = _trim(text)
    if value == "2":
        return 2
    if value == "4":
        return 4
    if value == "6":
        return 6
    raise Error(
        "Placement: --bits value '"
        + text
        + "' is not a lever value (bits takes 2, 4, or 6;"
        + " the native read is the absence of the option)"
    )


def _parse_kill_env(text: String, name: String) raises -> Bool:
    """AESIR_GPU / AESIR_NPU: '0' kills, '1' explicitly does not.

    Any other value is refused, never reinterpreted (the census's
    settings discipline: bad values are refused, not guessed at).
    """
    var value = _trim(text)
    if value == "0":
        return True
    if value == "1":
        return False
    raise Error(
        "Placement: "
        + name
        + " value '"
        + text
        + "' is not a kill-switch value (0 kills the device, 1 does not)"
    )


def _resolve_kills(
    cli: RawPlacementInputs, env: RawPlacementInputs
) raises -> DeviceKills:
    """Kills from every layer, merged: a kill from any source holds.

    Kill switches are deliberately NOT under value precedence -- a
    --no-gpu on the command line is not undone by an env placement,
    and an AESIR_GPU=0 is not undone by a command-line placement
    (the placement is refused instead, in validate_against_kills).
    """
    var kills = DeviceKills()
    if cli.no_gpu:
        kills.gpu_killed = True
        kills.gpu_source = String("--no-gpu")
    if cli.no_npu:
        kills.npu_killed = True
        kills.npu_source = String("--no-npu")
    # The AESIR_GPU / AESIR_NPU env switches may arrive on either raw
    # layer (the env reader fills them; a host may also file them
    # with its argv scan). Both are honoured; cli layer first purely
    # so the recorded source is deterministic.
    if cli.gpu_env_set:
        if _parse_kill_env(cli.gpu_env, "AESIR_GPU") and not kills.gpu_killed:
            kills.gpu_killed = True
            kills.gpu_source = String("AESIR_GPU=0")
    if env.gpu_env_set:
        if _parse_kill_env(env.gpu_env, "AESIR_GPU") and not kills.gpu_killed:
            kills.gpu_killed = True
            kills.gpu_source = String("AESIR_GPU=0")
    if cli.npu_env_set:
        if _parse_kill_env(cli.npu_env, "AESIR_NPU") and not kills.npu_killed:
            kills.npu_killed = True
            kills.npu_source = String("AESIR_NPU=0")
    if env.npu_env_set:
        if _parse_kill_env(env.npu_env, "AESIR_NPU") and not kills.npu_killed:
            kills.npu_killed = True
            kills.npu_source = String("AESIR_NPU=0")
    return kills


def _pick(
    cli_value: String,
    cli_set: Bool,
    env_value: String,
    env_set: Bool,
) -> Tuple[String, Int, Bool]:
    """Precedence for one value option: cli over env over default."""
    if cli_set:
        return (cli_value, SOURCE_CLI, True)
    if env_set:
        return (env_value, SOURCE_ENV, True)
    return (String(""), SOURCE_DEFAULT, False)


def _resolve_one(
    cli_value: String,
    cli_set: Bool,
    env_value: String,
    env_set: Bool,
    pass_kind: Int,
    kills: DeviceKills,
) raises -> PlacementOption:
    var picked = _pick(cli_value, cli_set, env_value, env_set)
    var option = PlacementOption()
    option.source = picked[1]
    option.was_set = picked[2]
    if not picked[2]:
        return option
    option.choice = parse_placement_value(picked[0], pass_kind)
    validate_against_kills(option.choice, pass_kind, kills)
    return option


def resolve_placement_options(
    cli: RawPlacementInputs, env: RawPlacementInputs
) raises -> PlacementOptions:
    """Resolve the two raw layers into the validated surface.

    Order of refusal: kill-switch values are validated first (a bad
    AESIR_GPU is refused even if nothing names the GPU), then each
    placement in prompt / drafts / reply order (parse, pass-kind
    legality, kills), then the quality fields. The first refusal
    stops resolution and carries its reason.
    """
    var kills = _resolve_kills(cli, env)
    var options = PlacementOptions()
    options.kills = kills
    options.prompt = _resolve_one(
        cli.prompt, cli.prompt_set, env.prompt, env.prompt_set,
        PASS_PROMPT, kills,
    )
    options.drafts = _resolve_one(
        cli.drafts, cli.drafts_set, env.drafts, env.drafts_set,
        PASS_DRAFTS, kills,
    )
    options.reply = _resolve_one(
        cli.reply, cli.reply_set, env.reply, env.reply_set,
        PASS_REPLY, kills,
    )
    var quality = QualityOptions()
    var q = _pick(cli.quality, cli.quality_set, env.quality, env.quality_set)
    if q[2]:
        quality.quality = parse_quality_value(q[0])
        quality.quality_source = q[1]
    var h = _pick(cli.head, cli.head_set, env.head, env.head_set)
    if h[2]:
        quality.head_bits = parse_head_value(h[0])
        quality.head_source = h[1]
    var a = _pick(
        cli.attention, cli.attention_set, env.attention, env.attention_set
    )
    if a[2]:
        quality.attention = parse_attention_value(a[0])
        quality.attention_source = a[1]
    var b = _pick(cli.bits, cli.bits_set, env.bits, env.bits_set)
    if b[2]:
        quality.bits = parse_bits_value(b[0])
        quality.bits_source = b[1]
    options.quality = quality
    return options


def require_draft_check_use() raises:
    """The fail-closed use gate for draft-check placement.

    Aesir has no draft-check pass (J-035 gap G1): no proposer, no
    verification batch, no KV rollback in any session. Any attempt
    to USE a drafts placement -- for any value, including auto --
    raises here until Part V (J-071/J-072) builds the pass and this
    gate is replaced by its real consumption. Parsing and storing a
    --drafts-on value is not use; sessions that run no draft-check
    never call this, and nothing may silently drop the stored value
    instead of calling it.
    """
    raise Error(
        "Placement: draft-check passes do not exist in Aesir yet"
        " (J-035 gap G1); --drafts-on is parsed and stored, but using"
        " a drafts placement is refused until Part V (J-071/J-072)"
        " builds the draft-check pass"
    )


def require_quality_use(options: PlacementOptions) raises:
    """The fail-closed use gate for the quality-tier levers.

    --quality high with no lever engaged is today's behaviour and
    passes. Any lowered tier or engaged lever raises: the levers
    (head requant, fast attention, bit-plane expert reads) are not
    built, and their agreement evidence is produced under J-091's
    ladder -- a lowered tier may not silently become a no-op or a
    guess in the meantime.
    """
    var q = options.quality
    if q.quality != "high":
        raise Error(
            "Placement: --quality "
            + q.quality
            + " lowers the run, but the quality levers are not built"
            + " yet; their agreement evidence is produced under"
            + " J-091's ladder, so a lowered tier is refused at use"
        )
    if q.head_bits != 0:
        raise Error(
            "Placement: --head "
            + String(q.head_bits)
            + " engages the head-requant lever, which is not built"
            + " yet; its agreement evidence is produced under"
            + " J-091's ladder, so the lever is refused at use"
        )
    if q.attention != "exact":
        raise Error(
            "Placement: --attention fast engages the fast-attention"
            " lever, which is not built yet; its agreement evidence"
            " is produced under J-091's ladder, so the lever is"
            " refused at use"
        )
    if q.bits != 0:
        raise Error(
            "Placement: --bits "
            + String(q.bits)
            + " engages the bit-plane expert-read lever, which is"
            + " not built yet; its agreement evidence is produced"
            + " under J-091's ladder, so the lever is refused at use"
        )


# --- argv scan -----------------------------------------------------


def _looks_like_placement_flag(arg: String) -> Bool:
    """True for args in this surface's namespace, known or not.

    The scan owns --prompt-on / --drafts-on / --reply-on / --quality
    / --head / --attention / --bits / --no-gpu / --no-npu / --no-cpu;
    an arg that reaches for that namespace and misses is refused
    with its spelling, never silently passed over -- a typo'd
    placement flag must not become a silently unplaced run.
    """
    return (
        arg.startswith("--prompt")
        or arg.startswith("--drafts")
        or arg.startswith("--reply")
        or arg.startswith("--quality")
        or arg.startswith("--head")
        or arg.startswith("--attention")
        or arg.startswith("--bits")
        or arg.startswith("--no-")
    )


def _split_flag(arg: String) -> Tuple[String, String, Bool]:
    """Split `--flag=value` / `--flag value` forms: (name, value, has_eq)."""
    var eq = arg.find("=")
    if eq >= 0:
        return (String(arg[byte=:eq]), String(arg[byte=eq + 1:]), True)
    return (arg, String(""), False)


def scan_placement_args(args: List[String]) raises -> RawPlacementInputs:
    """Scan a shared argv for this surface's flags.

    Both `--flag value` and `--flag=value` forms are accepted.
    Flags outside the surface's namespace are ignored (other
    surfaces own them). Refusals: a value flag with no value, a
    value handed to a kill switch, the same option set twice
    (state it once -- never silently override), --no-cpu (refused
    outright: the CPU takes part in every pass and cannot be
    killed), and any unrecognised flag inside the namespace.
    """
    var raw = RawPlacementInputs()
    var i = 0
    while i < len(args):
        var arg = args[i]
        if not _looks_like_placement_flag(arg):
            i += 1
            continue
        var split = _split_flag(arg)
        var name = split[0]
        var inline_value = split[1]
        var has_eq = split[2]
        if name == "--no-gpu" or name == "--no-npu" or name == "--no-cpu":
            if has_eq:
                raise Error(
                    "Placement: "
                    + name
                    + " is a switch and takes no value (got '"
                    + inline_value
                    + "')"
                )
            if name == "--no-cpu":
                raise Error(
                    "Placement: --no-cpu is refused: the cpu takes part"
                    " in every pass and cannot be killed"
                )
            if name == "--no-gpu":
                if raw.no_gpu:
                    raise Error("Placement: --no-gpu is set twice; state it once")
                raw.no_gpu = True
            else:
                if raw.no_npu:
                    raise Error("Placement: --no-npu is set twice; state it once")
                raw.no_npu = True
            i += 1
            continue
        var is_value_flag = (
            name == "--prompt-on"
            or name == "--drafts-on"
            or name == "--reply-on"
            or name == "--quality"
            or name == "--head"
            or name == "--attention"
            or name == "--bits"
        )
        if not is_value_flag:
            raise Error(
                "Placement: unknown option '"
                + name
                + "' in the placement surface (options are --prompt-on,"
                + " --drafts-on, --reply-on, --quality, --head,"
                + " --attention, --bits, --no-gpu, --no-npu)"
            )
        var value = inline_value
        if not has_eq:
            if i + 1 >= len(args):
                raise Error(
                    "Placement: " + name + " requires a value, but none follows it"
                )
            value = args[i + 1]
            i += 1
        if name == "--prompt-on":
            if raw.prompt_set:
                raise Error("Placement: --prompt-on is set twice; state it once")
            raw.prompt = value
            raw.prompt_set = True
        elif name == "--drafts-on":
            if raw.drafts_set:
                raise Error("Placement: --drafts-on is set twice; state it once")
            raw.drafts = value
            raw.drafts_set = True
        elif name == "--reply-on":
            if raw.reply_set:
                raise Error("Placement: --reply-on is set twice; state it once")
            raw.reply = value
            raw.reply_set = True
        elif name == "--quality":
            if raw.quality_set:
                raise Error("Placement: --quality is set twice; state it once")
            raw.quality = value
            raw.quality_set = True
        elif name == "--head":
            if raw.head_set:
                raise Error("Placement: --head is set twice; state it once")
            raw.head = value
            raw.head_set = True
        elif name == "--attention":
            if raw.attention_set:
                raise Error("Placement: --attention is set twice; state it once")
            raw.attention = value
            raw.attention_set = True
        else:
            if raw.bits_set:
                raise Error("Placement: --bits is set twice; state it once")
            raw.bits = value
            raw.bits_set = True
        i += 1
    return raw


# --- environment read ----------------------------------------------


def _env_str(name: String) -> Tuple[Bool, String]:
    """Read one environment variable: (is_set, value).

    Modelled on core/parallel.mojo's _env_int: the variable name is
    staged in a fixed buffer for getenv, and the value is read back
    byte by byte up to a bound. An empty value counts as set -- the
    placement parser refuses empty values with the reason, which is
    the honest outcome for AESIR_PROMPT_ON= (stated, not silent).
    """
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


def placement_env_inputs() -> RawPlacementInputs:
    """Read this surface's environment equivalents into a raw layer.

    AESIR_PROMPT_ON / AESIR_DRAFTS_ON / AESIR_REPLY_ON carry the
    placement values; AESIR_QUALITY / AESIR_HEAD / AESIR_ATTENTION /
    AESIR_BITS carry the quality fields; AESIR_GPU / AESIR_NPU carry
    the env kill switches (validated at resolve time, so a bad value
    is refused with its reason even if nothing names the device).
    """
    var raw = RawPlacementInputs()
    var prompt = _env_str("AESIR_PROMPT_ON")
    if prompt[0]:
        raw.prompt = prompt[1]
        raw.prompt_set = True
    var drafts = _env_str("AESIR_DRAFTS_ON")
    if drafts[0]:
        raw.drafts = drafts[1]
        raw.drafts_set = True
    var reply = _env_str("AESIR_REPLY_ON")
    if reply[0]:
        raw.reply = reply[1]
        raw.reply_set = True
    var quality = _env_str("AESIR_QUALITY")
    if quality[0]:
        raw.quality = quality[1]
        raw.quality_set = True
    var head = _env_str("AESIR_HEAD")
    if head[0]:
        raw.head = head[1]
        raw.head_set = True
    var attention = _env_str("AESIR_ATTENTION")
    if attention[0]:
        raw.attention = attention[1]
        raw.attention_set = True
    var bits = _env_str("AESIR_BITS")
    if bits[0]:
        raw.bits = bits[1]
        raw.bits_set = True
    var gpu = _env_str("AESIR_GPU")
    if gpu[0]:
        raw.gpu_env = gpu[1]
        raw.gpu_env_set = True
    var npu = _env_str("AESIR_NPU")
    if npu[0]:
        raw.npu_env = npu[1]
        raw.npu_env_set = True
    return raw
