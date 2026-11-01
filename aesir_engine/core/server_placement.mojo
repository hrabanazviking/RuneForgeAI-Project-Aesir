"""Server placement parity (Janas road J-049).

Part III built placement as a session-open discipline: J-036's
options (--prompt-on / --drafts-on / --reply-on, env equivalents,
kill switches, the quality family), J-037's inventory, J-040--
J-043's choosers, J-044's learned defaults, J-047's supremacy
stack (hand > preset > learned > auto, per pass kind) and its
generalised invalid-device refusal at open. Every one of those
slices recorded the same gap in its NOT PROVEN list: server
parity is J-049. This module is that parity layer. What the
tree's server surface actually is was read from the tree for
this slice (docs/janas/J049_SERVER_PLACEMENT_PARITY.md section
1 carries the inspection):

- The live service is cli/native_serve.mojo's serve_loaded():
  ONE resident session (Llama3CUDASession / Gemma4CUDASession),
  concurrency 1, its backend fixed at startup -- dispatch_
  native_serve() refuses any --accel but cuda ("no CPU
  fallback"), and the device, profile, and context are chosen
  once, before the first request. Per request the loop calls
  session.reset(), configure_sampling(), configure_control()
  (plus configure_output() / configure_tool() on the OpenAI
  routes), then begin_turn(). There is no configure-placement
  on any session, and no placement field in any request parser.
- The request parsers are bounded and fail closed on unknown
  fields. Native POST /v1/generate (GenerateRequest, flat
  fields), Ollama POST /api/generate + /api/chat (OllamaRequest:
  the options object carries NUMBERS only; num_ctx is checked
  by server/local_protocol.mojo's require_loaded_context() --
  a per-request value must equal the loaded context or be
  omitted, else the request is refused), OpenAI POST
  /v1/chat/completions + /v1/completions (OpenAIRequest, flat
  fields). Sampling shows the cheap-state pattern: parsers seed
  from the session defaults and per-request values override
  through with_sampling_option(), because configure_sampling()
  exists per request. server/api.mojo's BifrostGate is a
  disconnected scaffold (its dispatch returns 501 for every
  model-backed route) and is NOT a parity target.

THE PARITY RULE, decided in the J-049 doc section 2 before any
code: placement is allocation-bound state, like the context,
not cheap state, like sampling. A resident session's passes
execute where the session was opened; nothing can re-place a
pass per request. So:

- SESSION DEFAULTS govern. At serve open the host resolves the
  J-036 options + the J-047 mode from the serve command line
  and environment exactly as a CLI surface does, validates
  every governing named device against the inventory at open
  (J-047), applies the quality use gate (J-036), resolves the
  per-kind precedence ONCE (J-047), and checks every FIXED
  outcome against the resident placement the session will
  actually execute (this module's defaults conformance): a
  session default its own resident session cannot execute
  refuses the open, it does not open misplaced.
- PER-REQUEST OVERRIDE exists exactly where the API allows:
  the three generation request shapes may each carry
  prompt_on / drafts_on / reply_on (J-036 grammar, string
  values) and mode (J-047 grammar). Placement strings never
  enter Ollama's options object -- its parser consumes numbers
  only -- so on every shape the fields are flat/top-level,
  matching each surface's own flat fields (the native and
  OpenAI shapes) and Ollama's top-level string fields (model /
  prompt / system). Non-generation routes (show, tags, ps,
  models, health) carry no placement fields: a control a route
  cannot use is refused there as an unsupported field, exactly
  OllamaShowRequest's standing discipline.
- A request value is a HAND statement for that one request
  (the requester is the hand for their request): per kind,
  request hand > request mode preset > the session's resolved
  outcome, mirroring J-047's stack with the request layer on
  top. Request values are parsed, kill-checked, and inventory-
  checked whole, with the same refusals as at open (J-036 /
  J-047) -- a request can never resurrect a killed device,
  name an absent one, or drop a member of a list.
- CONFORMANCE is require_loaded_context()'s shape, applied to
  placement: a request-governed FIXED placement for the prompt
  or reply kind must EQUAL the resident session's executed
  placement for that kind, or the request is refused with the
  reason (never silently ignored, never silently honoured,
  never executed by re-placing the session). A request-
  governed MEASUREMENT demand (a race list, an explicit auto,
  --mode max) is refused with its reason: measurement is an
  open-time act (the choosers' choices are session-kept,
  J-040--J-042) and no per-request measurement exists. A
  request that states nothing for a kind is served under the
  session default for that kind -- that is what session
  defaults mean. Request outcomes never mutate the session
  defaults and never feed the learned file.
- DRAFTS follows the whole road's discipline: a request drafts
  value resolves and validates like the others (choosing is
  not using), but no generation route executes a draft-check
  pass, so drafts outcomes face no resident conformance here;
  any future route that WOULD execute one must call J-036's
  require_draft_check_use() first, which refuses until Part V.

HOST CONTRACT (binding; this module fakes no integration):
(1) dispatch_native_serve learns the placement + mode flags by
scanning its argv with J-036's scan_placement_args() + J-047's
scan_mode_args() and resolving with placement_env_inputs() /
mode_env_inputs() + resolve_placement_options() / resolve_mode()
-- today it refuses those flags as unsupported service options,
which is the startup half of the gap this slice names. (2) The
serve open then calls resolve_server_defaults() (open refusal +
quality gate + one precedence resolution), states the resident
placement truthfully (for the CUDA service: single gpu for the
prompt and reply kinds -- the backend=cuda the loop's own
banner, health, and readiness documents already state), and
calls require_server_defaults_conformance() before serving.
(3) Each generation parser claims the four placement field
names through apply_server_placement_field() BEFORE its own
unknown-field refusal (a claimed name is this surface's; an
unclaimed name keeps the parser's standing refusal), then the
loop calls resolve_server_request_placement() and
require_server_request_conformance() before session.reset();
a refusal answers the request with its reason and leaves the
session untouched. This slice wires the module into NO live
server path: serve_loaded() consumes no placement resolution
yet, and claiming otherwise would fake the integration. See
docs/janas/J049_SERVER_PLACEMENT_PARITY.md.
"""

from core.device_inventory import DeviceInventory
from core.learned_file import LearnedEntry
from core.manual_override import (
    GOV_AUTO,
    GOV_LEARNED,
    GOV_MANUAL_AUTO,
    GOV_MANUAL_FIXED,
    GOV_MANUAL_RACE,
    GOV_PRESET_FIXED,
    GOV_PRESET_MEASURE,
    MODE_AUTO,
    MODE_ECO,
    MODE_MAX,
    KindResolution,
    ModeOption,
    OverrideResolution,
    governing_name,
    mode_name,
    parse_mode_value,
    require_named_device_present,
    resolve_precedence,
    validate_choice_at_open,
    validate_open_choices,
)
from core.placement_options import (
    DEVICE_CPU,
    PASS_DRAFTS,
    PASS_PROMPT,
    PASS_REPLY,
    PLACE_AUTO,
    PLACE_COWORK,
    PLACE_RACE,
    PLACE_SINGLE,
    PlacementChoice,
    PlacementOptions,
    device_name,
    parse_placement_value,
    pass_name,
    require_quality_use,
    validate_against_kills,
)

# Provenance surfaces for a per-request outcome: the value that
# governed came from the session's open-time resolution, or from
# this request's own fields.
comptime PROV_SESSION = 0
comptime PROV_REQUEST = 1


def provenance_name(code: Int) -> String:
    if code == PROV_REQUEST:
        return String("request")
    return String("session")


def server_placement_field_name(pass_kind: Int) -> String:
    """The wire name of one kind's per-request placement field."""
    if pass_kind == PASS_DRAFTS:
        return String("drafts_on")
    if pass_kind == PASS_REPLY:
        return String("reply_on")
    return String("prompt_on")


def is_server_placement_field(name: String) -> Bool:
    """True for the four names this surface claims on a request:
    prompt_on / drafts_on / reply_on / mode. Every other name is
    the host parser's own business (its fields, or its standing
    unknown-field refusal)."""
    return (
        name == "prompt_on"
        or name == "drafts_on"
        or name == "reply_on"
        or name == "mode"
    )


def _single_choice(code: Int) -> PlacementChoice:
    var choice = PlacementChoice()
    choice.form = PLACE_SINGLE
    choice.first = code
    choice.count = 1
    return choice


# --- the per-request raw layer -------------------------------------------


struct ServerPlacementRequest(Copyable, ImplicitlyCopyable):
    """One generation request's placement fields, raw: a value
    plus a was-set flag per kind, and the mode likewise, in
    J-036's raw-layer shape. Precedence and parsing are decided
    in resolve_server_request_placement, never here."""

    var prompt: String
    var prompt_set: Bool
    var drafts: String
    var drafts_set: Bool
    var reply: String
    var reply_set: Bool
    var mode: String
    var mode_set: Bool

    def __init__(out self):
        self.prompt = String("")
        self.prompt_set = False
        self.drafts = String("")
        self.drafts_set = False
        self.reply = String("")
        self.reply_set = False
        self.mode = String("")
        self.mode_set = False

    def any_set(self) -> Bool:
        return (
            self.prompt_set
            or self.drafts_set
            or self.reply_set
            or self.mode_set
        )

    def raw_for(self, pass_kind: Int) -> Tuple[String, Bool]:
        if pass_kind == PASS_DRAFTS:
            return (self.drafts, self.drafts_set)
        if pass_kind == PASS_REPLY:
            return (self.reply, self.reply_set)
        return (self.prompt, self.prompt_set)


def apply_server_placement_field(
    mut request: ServerPlacementRequest, name: String, value: String
) raises -> Bool:
    """Claim one request field for this surface.

    Returns True when `name` is one of the four placement field
    names (the value is stored raw; parsing happens at resolve),
    False when it is not this surface's field (the host parser
    then applies its own field handling or its standing
    unknown-field refusal). A placement field stated twice on
    one request is refused -- state it once, exactly J-036's
    argv discipline -- never silently overridden."""
    if not is_server_placement_field(name):
        return False
    if name == "mode":
        if request.mode_set:
            raise Error(
                "ServerPlacement: request field 'mode' is set"
                " twice; state it once"
            )
        request.mode = value
        request.mode_set = True
        return True
    var kind = PASS_PROMPT
    if name == "drafts_on":
        kind = PASS_DRAFTS
    elif name == "reply_on":
        kind = PASS_REPLY
    var current = request.raw_for(kind)
    if current[1]:
        raise Error(
            "ServerPlacement: request field '"
            + name
            + "' is set twice; state it once"
        )
    if kind == PASS_PROMPT:
        request.prompt = value
        request.prompt_set = True
    elif kind == PASS_DRAFTS:
        request.drafts = value
        request.drafts_set = True
    else:
        request.reply = value
        request.reply_set = True
    return True


# --- session defaults ------------------------------------------------------


struct ServerPlacementDefaults(Copyable, Movable):
    """The session's placement state, resolved ONCE at serve
    open: the J-036 options, the J-047 mode, and the J-047
    precedence resolution taken over them. Immutable per
    request by construction -- resolution functions take it by
    value and return per-request outcomes; nothing here is
    mutated by a request."""

    var options: PlacementOptions
    var mode: ModeOption
    var resolution: OverrideResolution

    def __init__(out self):
        self.options = PlacementOptions()
        self.mode = ModeOption()
        self.resolution = OverrideResolution()

    def for_kind(self, pass_kind: Int) -> KindResolution:
        return self.resolution.for_kind(pass_kind)


def resolve_server_defaults(
    options: PlacementOptions,
    mode: ModeOption,
    learned: LearnedEntry,
    has_learned: Bool,
    inventory: DeviceInventory,
) raises -> ServerPlacementDefaults:
    """Resolve the session defaults at serve open, in a stated
    order: J-047's open validation first (every governing named
    device present, refused whole with its reason), then
    J-036's quality use gate (a lowered tier or engaged lever
    refuses the open -- the levers are unbuilt, J-091 owns their
    evidence), then the one precedence resolution every request
    on this session falls back to."""
    validate_open_choices(options, mode, learned, has_learned, inventory)
    require_quality_use(options)
    var defaults = ServerPlacementDefaults()
    defaults.options = options
    defaults.mode = mode
    defaults.resolution = resolve_precedence(
        options, mode, learned, has_learned
    )
    return defaults^


# --- the resident placement -------------------------------------------------


struct ResidentPlacement(Copyable, ImplicitlyCopyable):
    """The host's statement of where the resident session
    actually executes its passes: one FIXED device set (a
    single device or a co-work pair, in PlacementChoice form)
    per executed kind. `stated` records whether the host stated
    it at all -- conformance fails closed on an unstated
    resident, because a parity check against an unknown truth
    would be a guess. The drafts kind has no resident entry:
    no generation route executes a draft-check pass."""

    var stated: Bool
    var prompt: PlacementChoice
    var reply: PlacementChoice

    def __init__(out self):
        self.stated = False
        self.prompt = PlacementChoice()
        self.reply = PlacementChoice()

    def for_kind(self, pass_kind: Int) -> PlacementChoice:
        if pass_kind == PASS_REPLY:
            return self.reply
        return self.prompt

    def describe(self) -> String:
        if not self.stated:
            return String("resident placement not stated")
        return (
            "prompt on "
            + self.prompt.describe()
            + ", reply on "
            + self.reply.describe()
        )


def resident_single(code: Int) -> ResidentPlacement:
    """A resident executing both kinds on one device (the CUDA
    service's shape: resident_single(DEVICE_GPU))."""
    var resident = ResidentPlacement()
    resident.stated = True
    resident.prompt = _single_choice(code)
    resident.reply = _single_choice(code)
    return resident


# --- conformance of the session defaults (at open) ---------------------------


def _defaults_fixed_text(
    defaults: ServerPlacementDefaults, resolution: KindResolution
) -> String:
    """The fixed device SET one session outcome carries, in
    PlacementChoice canonical text: a manual-fixed outcome
    carries its whole hand choice (single or co-work); a
    preset-fixed or learned outcome carries its one device
    (eco's cpu; a learned choice's device -- J-044 choices are
    single-device by record shape). Empty when the outcome
    fixes nothing (a measurement outcome)."""
    if not resolution.has_fixed:
        return String("")
    if resolution.governing == GOV_MANUAL_FIXED:
        if resolution.kind == PASS_DRAFTS:
            return defaults.options.drafts.choice.describe()
        if resolution.kind == PASS_REPLY:
            return defaults.options.reply.choice.describe()
        return defaults.options.prompt.choice.describe()
    return device_name(resolution.device)


def require_server_defaults_conformance(
    defaults: ServerPlacementDefaults, resident: ResidentPlacement
) raises:
    """At-open conformance, the defaults half of the parity
    rule: every FIXED prompt/reply outcome in the session
    resolution must equal the resident placement for its kind.
    A mismatch refuses the open with the reason -- a service
    may not open under defaults its resident session cannot
    execute and then discover it per request. Measurement
    outcomes fix nothing and are not checked here: the host's
    resident statement is by contract the kept choice any
    open-time measurement produced, so they agree by
    construction (module header)."""
    if not resident.stated:
        raise Error(
            "ServerPlacement: the resident session's executed"
            " placement was not stated, so the session defaults"
            " cannot be verified against it; state the resident"
            " placement at open (host contract, J-049)"
        )
    for kind in [PASS_PROMPT, PASS_REPLY]:
        var resolution = defaults.for_kind(kind)
        var fixed = _defaults_fixed_text(defaults, resolution)
        if fixed.byte_length() == 0:
            continue
        var executed = resident.for_kind(kind).describe()
        if fixed != executed:
            raise Error(
                "ServerPlacement: session default for a "
                + pass_name(kind)
                + " pass is fixed at '"
                + fixed
                + "' ("
                + governing_name(resolution.governing)
                + "), but the resident session executes "
                + pass_name(kind)
                + " passes on '"
                + executed
                + "' -- the open is refused; state a default the"
                " resident session can execute, or open the"
                " session on the stated devices"
            )


# --- per-request resolution ---------------------------------------------------


struct ServerKindPlacement(Copyable, ImplicitlyCopyable):
    """One pass kind's placement FOR ONE REQUEST: the governing
    layer (J-047's codes), which surface supplied it (session
    or request), the fixed device set when the outcome fixes
    one (has_fixed_choice + fixed_choice, canonical), the
    measurement field when it directs measurement, and the
    reason. A request outcome is spent with its request: it
    never mutates the defaults and never feeds the learned
    file, so retrial_applies is False on every outcome this
    module returns for a request."""

    var kind: Int
    var governing: Int
    var provenance: Int
    var effective_text: String
    var has_fixed_choice: Bool
    var fixed_choice: PlacementChoice
    var measure_field: String
    var retrial_applies: Bool
    var reason: String

    def __init__(out self):
        self.kind = PASS_PROMPT
        self.governing = GOV_AUTO
        self.provenance = PROV_SESSION
        self.effective_text = String("auto")
        self.has_fixed_choice = False
        self.fixed_choice = PlacementChoice()
        self.measure_field = String("")
        self.retrial_applies = False
        self.reason = String("not resolved")

    def render(self) -> String:
        var out_str = (
            pass_name(self.kind)
            + ": "
            + governing_name(self.governing)
            + " ("
            + provenance_name(self.provenance)
            + ")"
        )
        if self.has_fixed_choice:
            out_str += " -- fixed: " + self.fixed_choice.describe()
        elif self.governing == GOV_MANUAL_FIXED or (
            self.governing == GOV_PRESET_FIXED
            or self.governing == GOV_LEARNED
        ):
            out_str += " -- fixed: " + self.effective_text
        else:
            out_str += " -- measure: field [" + self.measure_field + "]"
        out_str += " -- " + self.reason + "\n"
        return out_str


struct ServerRequestPlacement(Copyable, Movable):
    """One request's whole placement resolution: one
    ServerKindPlacement per pass kind, rendered by report()."""

    var prompt: ServerKindPlacement
    var drafts: ServerKindPlacement
    var reply: ServerKindPlacement

    def __init__(out self):
        self.prompt = ServerKindPlacement()
        self.drafts = ServerKindPlacement()
        self.reply = ServerKindPlacement()

    def for_kind(self, pass_kind: Int) -> ServerKindPlacement:
        if pass_kind == PASS_DRAFTS:
            return self.drafts
        if pass_kind == PASS_REPLY:
            return self.reply
        return self.prompt

    def report(self) -> String:
        var out_str = String("server placement resolution (J-049)\n")
        out_str += (
            "per kind: request hand > request preset > session"
            " resolution; a request value governs one request"
            " only and never mutates the session defaults\n"
        )
        out_str += self.prompt.render()
        out_str += self.drafts.render()
        out_str += self.reply.render()
        out_str += (
            "conformance: a request-governed fixed placement"
            " must equal the resident session's executed"
            " placement for its kind, and a request-governed"
            " measurement demand is refused -- measurement is"
            " an open-time act and no per-request measurement"
            " exists (J-049)\n"
        )
        return out_str


def _request_preset(
    mode_code: Int, pass_kind: Int
) -> Tuple[Bool, Bool, Int, Int]:
    """The per-kind intent of a REQUEST's mode, mirroring
    J-047's preset_intent semantics exactly (the session
    resolver's definition; this layer re-states it only to
    carry request provenance in its own words): (governs,
    fixed, device, threads). eco is fixed cpu threads=1; max
    measures over the full field; auto governs nothing."""
    if mode_code == MODE_ECO:
        return (True, True, DEVICE_CPU, 1)
    if mode_code == MODE_MAX:
        return (True, False, -1, 0)
    return (False, False, -1, 0)


def _resolve_request_kind(
    defaults: ServerPlacementDefaults,
    pass_kind: Int,
    raw: Tuple[String, Bool],
    request_choice: PlacementChoice,
    request_mode: Int,
    request_mode_set: Bool,
) -> ServerKindPlacement:
    var outcome = ServerKindPlacement()
    outcome.kind = pass_kind
    var kind_name = pass_name(pass_kind)
    var auto_field = defaults.resolution.auto_field

    # (a) The request hand, when the request stated the kind.
    if raw[1]:
        outcome.provenance = PROV_REQUEST
        outcome.effective_text = request_choice.describe()
        if (
            request_choice.form == PLACE_SINGLE
            or request_choice.form == PLACE_COWORK
        ):
            outcome.governing = GOV_MANUAL_FIXED
            outcome.has_fixed_choice = True
            outcome.fixed_choice = request_choice
            outcome.reason = (
                "the request's "
                + server_placement_field_name(pass_kind)
                + " value '"
                + request_choice.describe()
                + "' is a hand statement for this request: it"
                " governs the "
                + kind_name
                + " kind for this request only, over the"
                " request preset and the session resolution,"
                " and the session default is unchanged"
            )
        elif request_choice.form == PLACE_RACE:
            outcome.governing = GOV_MANUAL_RACE
            outcome.measure_field = request_choice.describe()
            outcome.reason = (
                "the request's "
                + server_placement_field_name(pass_kind)
                + " race '"
                + request_choice.describe()
                + "' fixes this request's measured field for the "
                + kind_name
                + " kind to exactly its named members; whether"
                " it may be honoured is conformance's question"
                " (measurement is an open-time act)"
            )
        else:
            outcome.governing = GOV_MANUAL_AUTO
            outcome.measure_field = auto_field
            outcome.reason = (
                "the request's explicit auto for the "
                + kind_name
                + " kind is a hand statement directing fresh"
                " measurement for this request; whether it may"
                " be honoured is conformance's question"
                " (measurement is an open-time act)"
            )
        if pass_kind == PASS_DRAFTS:
            outcome.reason += (
                "; choosing is not using -- no generation route"
                " executes a draft-check pass, and any use still"
                " fails closed (J-036 gap G1) until Part V"
            )
        return outcome

    # (b) The request preset, only where the request hand is
    # silent for the kind.
    if request_mode_set:
        var intent = _request_preset(request_mode, pass_kind)
        if intent[0]:
            outcome.provenance = PROV_REQUEST
            if intent[1]:
                outcome.governing = GOV_PRESET_FIXED
                outcome.effective_text = String("cpu threads=1")
                outcome.has_fixed_choice = True
                outcome.fixed_choice = _single_choice(intent[2])
                outcome.reason = (
                    "the request's mode "
                    + mode_name(request_mode)
                    + " preset governs the "
                    + kind_name
                    + " kind for this request (the request hand"
                    " is silent for it): fixed at cpu threads=1"
                    " -- eco never uses the gpu for speed alone"
                    " (census J-003, via J-047); the session"
                    " default is unchanged"
                )
            else:
                outcome.governing = GOV_PRESET_MEASURE
                outcome.effective_text = String("auto")
                outcome.measure_field = auto_field
                outcome.reason = (
                    "the request's mode "
                    + mode_name(request_mode)
                    + " preset directs measurement of the "
                    + kind_name
                    + " kind over the full auto field for this"
                    " request; whether it may be honoured is"
                    " conformance's question (measurement is an"
                    " open-time act)"
                )
            if pass_kind == PASS_DRAFTS:
                outcome.reason += (
                    "; choosing is not using -- any use of a"
                    " drafts placement still fails closed"
                    " (J-036 gap G1) until Part V"
                )
            return outcome

    # (c) The session resolution governs the kind, verbatim.
    var session = defaults.for_kind(pass_kind)
    outcome.provenance = PROV_SESSION
    outcome.governing = session.governing
    outcome.effective_text = session.effective_text
    outcome.measure_field = session.measure_field
    outcome.retrial_applies = session.retrial_applies
    if session.has_fixed:
        outcome.has_fixed_choice = True
        if session.governing == GOV_MANUAL_FIXED:
            if pass_kind == PASS_DRAFTS:
                outcome.fixed_choice = defaults.options.drafts.choice
            elif pass_kind == PASS_REPLY:
                outcome.fixed_choice = defaults.options.reply.choice
            else:
                outcome.fixed_choice = defaults.options.prompt.choice
        else:
            outcome.fixed_choice = _single_choice(session.device)
    outcome.reason = (
        "the request states nothing for the "
        + kind_name
        + " kind, so the session default governs: "
        + session.reason
    )
    return outcome


def resolve_server_request_placement(
    defaults: ServerPlacementDefaults,
    request: ServerPlacementRequest,
    inventory: DeviceInventory,
) raises -> ServerRequestPlacement:
    """Resolve one request's placement against the session
    defaults. Validation runs before resolution, in a stated
    order: each stated value is parsed (J-036 grammar and
    pass-kind legality), the request mode is parsed (J-047
    grammar), stated choices are checked against the SESSION's
    kill switches (a request can never resurrect a device the
    session killed), and every device a stated choice names is
    checked against the inventory whole (J-047's generalised
    refusal, request layer). The first refusal raises with its
    reason and no request is served under a partial resolution.
    Resolution itself is the stack in the module header:
    request hand > request preset > session resolution, per
    kind."""
    var kinds = List[Int]()
    kinds.append(PASS_PROMPT)
    kinds.append(PASS_DRAFTS)
    kinds.append(PASS_REPLY)
    var choices = List[PlacementChoice]()
    for kind in kinds:
        var raw = request.raw_for(kind)
        var choice = PlacementChoice()
        if raw[1]:
            choice = parse_placement_value(raw[0], kind)
            validate_against_kills(
                choice, kind, defaults.options.kills
            )
            validate_choice_at_open(
                kind,
                choice,
                "request field '"
                + server_placement_field_name(kind)
                + "'",
                inventory,
            )
        choices.append(choice)
    var request_mode = MODE_AUTO
    if request.mode_set:
        request_mode = parse_mode_value(request.mode)
        if request_mode == MODE_ECO:
            # Eco's fixed cpu must exist on this machine for any
            # kind the request hand left silent; a kind the hand
            # stated is already validated above and the preset
            # never governs it, so it is not checked here.
            for i in range(3):
                if not request.raw_for(kinds[i])[1]:
                    require_named_device_present(
                        kinds[i],
                        "request field 'mode' (preset eco)",
                        "cpu threads=1",
                        DEVICE_CPU,
                        inventory,
                    )
    var placement = ServerRequestPlacement()
    for i in range(3):
        var outcome = _resolve_request_kind(
            defaults,
            kinds[i],
            request.raw_for(kinds[i]),
            choices[i],
            request_mode,
            request.mode_set,
        )
        if kinds[i] == PASS_PROMPT:
            placement.prompt = outcome
        elif kinds[i] == PASS_DRAFTS:
            placement.drafts = outcome
        else:
            placement.reply = outcome
    return placement^


# --- conformance of one request (before it is served) -------------------------


def require_server_request_conformance(
    placement: ServerRequestPlacement, resident: ResidentPlacement
) raises:
    """Per-request conformance, require_loaded_context()'s
    shape for placement: only REQUEST-governed outcomes are
    checked (session-governed kinds were conformed at open).
    For the prompt and reply kinds -- the kinds a generation
    request executes -- a request-governed FIXED placement must
    equal the resident session's executed placement, and a
    request-governed MEASUREMENT demand (race, explicit auto,
    mode max) is refused: measurement is an open-time act, the
    choosers' choices are session-kept, and no per-request
    measurement exists to honour the demand with. Drafts
    outcomes are not checked: no generation route executes a
    draft-check pass (module header). Every refusal names the
    kind, what the request asked, what the resident session
    executes, and the road (state it in the session defaults
    at open)."""
    var any_request_governed = False
    for kind in [PASS_PROMPT, PASS_REPLY]:
        if placement.for_kind(kind).provenance == PROV_REQUEST:
            any_request_governed = True
    if any_request_governed and not resident.stated:
        raise Error(
            "ServerPlacement: the request governs a placement,"
            " but the resident session's executed placement was"
            " not stated, so conformance cannot be verified;"
            " state the resident placement at open (host"
            " contract, J-049)"
        )
    for kind in [PASS_PROMPT, PASS_REPLY]:
        var outcome = placement.for_kind(kind)
        if outcome.provenance != PROV_REQUEST:
            continue
        var executed = resident.for_kind(kind).describe()
        if outcome.has_fixed_choice:
            if outcome.fixed_choice.describe() != executed:
                raise Error(
                    "ServerPlacement: request placement for a "
                    + pass_name(kind)
                    + " pass is fixed at '"
                    + outcome.fixed_choice.describe()
                    + "', but the resident session executes "
                    + pass_name(kind)
                    + " passes on '"
                    + executed
                    + "' -- the request is refused, never"
                    " silently ignored and never honoured by"
                    " re-placing the session; state the placement"
                    " in the session defaults at open, or open"
                    " the session on the requested devices"
                )
        else:
            raise Error(
                "ServerPlacement: request placement for a "
                + pass_name(kind)
                + " pass asks for measurement ("
                + governing_name(outcome.governing)
                + ", field ["
                + outcome.measure_field
                + "]), but measurement is an open-time act:"
                " the choosers' choices are session-kept and"
                " no per-request measurement exists -- the"
                " request is refused; state the placement in"
                " the session defaults at open instead"
            )
