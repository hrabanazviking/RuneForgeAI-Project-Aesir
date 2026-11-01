"""Draft configuration surface (Janas road J-083).

The roadmap text: "--mtp / --no-mtp / --draft <model> in
Janas's shapes, Aesir's words; chat + server parity;
saved-config persistence via Part III's learned file."

WHAT EXISTED BEFORE THIS SLICE (inspected first-hand; the
J-083 doc section 2 carries the full record). Aesir had NO
draft configuration surface: no --mtp, --no-mtp, or --draft
flag anywhere in the tree (the only --draft-shaped flag is
J-036's --drafts-on, a PLACEMENT option for the draft-check
pass, a different surface that this module does not touch).
The pieces this surface binds already existed, scattered:
J-036's option-surface discipline (scan / env / resolve,
precedence cli > env > default, refuse-by-name, a fail-closed
use gate); J-071's proposer shapes and caps (model proposers
15, conversation 8, read here through plan_proposer, never
restated); J-072's loop initial k (LOOP_K_INITIAL, imported,
never restated); J-074's cross-model pair gate, J-077's MTP
admission gate, and J-078's assistant pair gate (the recorded
pair gates a configured pair must pass); J-044's learned
file, whose own record names this slice as persisting via
it. The chat and server surfaces parse their arguments
through separate code today (cli/options.mojo's
parse_cli_options for chat; the server surfaces' own request
parsers, with J-049's server_placement as the parity-layer
precedent) -- so parity here is by construction: ONE shared
scan/resolve in this module, called by both surfaces'
entry points (resolve_chat_draft_config /
resolve_server_draft_config), proven by the same tests
driving both.

THE VERDICT / REFUSAL RULES (pre-registered here, before
the code; the module's tests grade exactly these):

- One proposer source per configuration. --mtp selects the
  target's own MTP head (J-071 SLOT_HEAD, PROPOSER_MTP_HEAD);
  --draft <model> selects a separate draft model
  (PROPOSER_CROSS_MODEL's slot). Stating both is refused by
  name (REFUSE_CONTRADICTORY_SOURCES): a session runs one
  proposer slot per round (J-072), and a configuration that
  names two sources has no honest reading.
- --mtp with --no-mtp, in any layer or across layers, is
  refused by name (REFUSE_CONTRADICTORY_MTP). Precedence
  never silently resolves a hand contradiction.
  --no-mtp with --draft is NOT a contradiction: --no-mtp
  disables the head source only, and the configuration
  records mtp=off beside the draft-model source.
- k (the configured initial draft length, --draft-k /
  AESIR_DRAFT_K) defaults to J-072's LOOP_K_INITIAL and is
  validated against the SELECTED source's cap, read from
  J-071's plan_proposer on every validation (model sources
  15; no-source configurations validate against the band
  cap 15 the same way). Outside 1..cap is refused by name
  (REFUSE_K_OUT_OF_BAND), naming the cap and its owner.
  The conversation proposer's tighter cap (8) binds no
  configuration here: conversation drafts are not a
  configurable source on this surface (J-071's slot exists;
  no flag states it), and that exclusion is stated, not
  implied.
- A configured --draft pair is validated by the RECORDED
  pair gate, not by this module's opinion:
  validate_draft_model_pair calls J-074's evaluate_pair
  with the configuration's k and the caller-stated pair
  facts, and any inadmissible verdict is raised by the
  gate's own reason name (REFUSE_MISSING_FILE for a missing
  or unknown-named file, REFUSE_UNKNOWN_FAMILY_PAIRING,
  REFUSE_TOKENIZER_UNVERIFIED / _MISMATCH, REFUSE_K_OVER_CAP,
  REFUSE_BUDGET_EXCEEDED). A configured --mtp is validated
  by J-077's evaluate_mtp_admission over the caller-stated
  tensor directory, raised by J-077's refusal line
  (REFUSE_NO_MTP for a file whose heads are not there,
  REFUSE_NOT_PROVEN for an uncensused file). This module
  builds no second gate.
- Persistence is Part III's learned file, in its own
  format: a validated configuration is stored into a
  LearnedEntry's draft section (core/learned_file.mojo's
  J-083 extension: same file, same cache home, same atomic
  writes and checksum; V1 files without draft
  configurations are byte-identical to J-044's) through
  store_learned_entry, and read back through
  load_learned_file + lookup_learned. There is no second
  config store. Storing follows store_learned_entry's own
  semantics: one entry per machine+model key, replaced
  whole -- a host holding learned pass choices for the key
  merges them into the entry (apply_draft_config) before
  storing, exactly as the learned file's contract states.
- THE USE GATE STANDS. Configuring is not using. No
  proposer implementation exists in-tree (G-PROPOSER) and
  no verify-pass executor exists in-tree (G-EXECUTOR);
  J-036's require_draft_check_use() still raises and the
  facade's speculative_generate still raises
  not-implemented. require_draft_config_use() therefore
  raises for EVERY configuration -- a configured source by
  the blockers' names, an unconfigured one by
  REFUSE_NO_SOURCE -- and nothing in this module calls a
  session, lifts a gate, or honours a stored configuration
  silently. A stored configuration records and validates
  intent; that is all it does today.

HOST CONTRACT (binding; this module fakes no integration):
a chat or server surface (1) scans its argv with
scan_draft_args (or resolves a request's stated fields
through the same raw layer), reads draft_env_inputs, and
resolves ONCE through resolve_draft_config (the two named
entry wrappers exist so each surface's call is auditable;
both call the one resolver); (2) for a configured source,
runs the matching recorded gate (validate_mtp_source /
validate_draft_model_pair) over facts it read from the
actual files, and files any refusal by name -- a
configuration that fails its gate is not persisted and
not used; (3) persists a gate-passing configuration via
persist_draft_config under the session's machine+model
key; (4) before any generation that would consume a draft
configuration, calls require_draft_config_use() -- which
refuses until the blockers lift. This slice wires the
module into no live chat or server path: no surface calls
it yet, and claiming otherwise would fake the integration
(the J-036/J-044/J-049 precedent). See
docs/janas/J083_DRAFT_CONFIG_SURFACE.md.
"""

from std.ffi import external_call
from std.memory import Pointer
from std.collections import InlineArray

from core.cross_model_pairing import (
    ModelSide,
    PairVerdict,
    TokenizerComparison,
    evaluate_pair,
    pair_reason_name,
)
from core.learned_file import (
    LOAD_LOADED,
    LOAD_MISSING,
    LOAD_REFUSED,
    LOOKUP_APPLIED,
    LearnedEntry,
    MachineKey,
    ModelShape,
    load_learned_file,
    load_status_name,
    lookup_learned,
    lookup_status_name,
    store_learned_entry,
)
from core.mtp_head_support import (
    MtpAdmission,
    evaluate_mtp_admission,
    mtp_refusal_line,
)
from core.placement_options import SOURCE_CLI, SOURCE_DEFAULT, SOURCE_ENV, source_name
from core.speculative_loop import LOOP_K_INITIAL
from core.speculative_verify import (
    PROPOSER_CROSS_MODEL,
    PROPOSER_MTP_HEAD,
    plan_proposer,
    proposer_kind_name,
)

# Proposer sources a configuration may name. The codes are
# the learned file's draft-source codes (one vocabulary, two
# layers): NONE / MTP_HEAD / DRAFT_MODEL.
comptime DRAFT_SOURCE_NONE = 0
comptime DRAFT_SOURCE_MTP_HEAD = 1
comptime DRAFT_SOURCE_DRAFT_MODEL = 2

# MTP states (the learned file's codes, likewise).
comptime DRAFT_MTP_UNSET = 0
comptime DRAFT_MTP_ON = 1
comptime DRAFT_MTP_OFF = 2


def draft_source_name(code: Int) -> String:
    if code == DRAFT_SOURCE_MTP_HEAD:
        return String("mtp-head")
    if code == DRAFT_SOURCE_DRAFT_MODEL:
        return String("draft-model")
    return String("none")


def draft_mtp_name(code: Int) -> String:
    if code == DRAFT_MTP_ON:
        return String("on")
    if code == DRAFT_MTP_OFF:
        return String("off")
    return String("unset")


def _source_proposer_kind(source: Int) raises -> Int:
    """The J-071 proposer kind a source's k cap is read from.

    No-source configurations validate k against the head
    kind's shape: every model proposer shares the band cap,
    and plan_proposer refuses an unknown kind, so the band
    is never restated here."""
    if source == DRAFT_SOURCE_DRAFT_MODEL:
        return PROPOSER_CROSS_MODEL
    return PROPOSER_MTP_HEAD


def draft_k_cap(source: Int) raises -> Int:
    """The k cap for a configuration's source, from J-071."""
    return plan_proposer(_source_proposer_kind(source)).max_k


struct DraftConfig(Copyable, ImplicitlyCopyable):
    """One resolved draft configuration: the intent a
    surface stated, validated, and may persist.

    source names the one proposer source; mtp_state records
    the --mtp / --no-mtp statement independently (a
    draft-model configuration may carry mtp=off); draft_model
    is the stated draft file for the draft-model source and
    the canonical "-" otherwise; k is the configured initial
    draft length (J-072's initial by default). The *_layer
    fields record which layer supplied each statement
    (J-036's source codes), for the parity report."""

    var source: Int
    var mtp_state: Int
    var draft_model: String
    var k: Int
    var mtp_layer: Int
    var model_layer: Int
    var k_layer: Int

    def __init__(out self):
        self.source = DRAFT_SOURCE_NONE
        self.mtp_state = DRAFT_MTP_UNSET
        self.draft_model = String("-")
        self.k = LOOP_K_INITIAL
        self.mtp_layer = SOURCE_DEFAULT
        self.model_layer = SOURCE_DEFAULT
        self.k_layer = SOURCE_DEFAULT

    def describe(self) -> String:
        """The canonical one-line rendering, identical on
        every surface (the parity tests pin this string)."""
        var out_str = String("draft-config: source=")
        out_str += draft_source_name(self.source)
        out_str += " mtp=" + draft_mtp_name(self.mtp_state)
        out_str += " (layer " + source_name(self.mtp_layer) + ")"
        out_str += " model=" + self.draft_model
        out_str += " (layer " + source_name(self.model_layer) + ")"
        out_str += " k=" + String(self.k)
        out_str += " (layer " + source_name(self.k_layer) + ")"
        out_str += " [use refused: G-PROPOSER + G-EXECUTOR stand]"
        return out_str


def validate_draft_config(config: DraftConfig) raises:
    """The surface's own validation (the header's rules).

    Pair-gate and head-admission validation are separate
    (validate_draft_model_pair / validate_mtp_source): they
    need file facts this layer does not hold. What is
    refused here, by name: an unknown source or mtp code, an
    mtp-head configuration whose mtp is not on or that names
    a separate file, a draft-model configuration with no
    file named or with mtp on (the contradiction), a
    no-source configuration with mtp on, and k outside
    1..cap for the configuration's source (cap read from
    J-071's plan_proposer, never restated)."""
    if (
        config.source != DRAFT_SOURCE_NONE
        and config.source != DRAFT_SOURCE_MTP_HEAD
        and config.source != DRAFT_SOURCE_DRAFT_MODEL
    ):
        raise Error("DraftConfig: REFUSE_UNKNOWN_SOURCE -- unknown source code")
    if config.mtp_state < 0 or config.mtp_state > 2:
        raise Error("DraftConfig: REFUSE_UNKNOWN_MTP_STATE -- unknown mtp state code")
    if config.source == DRAFT_SOURCE_MTP_HEAD:
        if config.mtp_state != DRAFT_MTP_ON:
            raise Error(
                "DraftConfig: REFUSE_MTP_NOT_ON -- an mtp-head"
                " configuration must record mtp on"
            )
        if config.draft_model != "-":
            raise Error(
                "DraftConfig: REFUSE_CONTRADICTORY_SOURCES -- an"
                " mtp-head configuration names no separate draft"
                " file ('" + config.draft_model + "')"
            )
    elif config.source == DRAFT_SOURCE_DRAFT_MODEL:
        if config.draft_model == "-" or config.draft_model.byte_length() == 0:
            raise Error(
                "DraftConfig: REFUSE_MISSING_DRAFT_MODEL -- a"
                " draft-model configuration must name its draft file"
            )
        if config.mtp_state == DRAFT_MTP_ON:
            raise Error(
                "DraftConfig: REFUSE_CONTRADICTORY_SOURCES --"
                " --draft <model> and --mtp name two proposer"
                " sources; state one"
            )
    else:
        if config.mtp_state == DRAFT_MTP_ON:
            raise Error(
                "DraftConfig: REFUSE_CONTRADICTORY_SOURCES --"
                " mtp on with no proposer source is not a"
                " configuration"
            )
        if config.draft_model != "-":
            raise Error(
                "DraftConfig: REFUSE_CONTRADICTORY_SOURCES -- a"
                " draft file is named but the source is none"
            )
    var cap = draft_k_cap(config.source)
    if config.k < 1 or config.k > cap:
        raise Error(
            "DraftConfig: REFUSE_K_OUT_OF_BAND -- k="
            + String(config.k)
            + " is outside 1.."
            + String(cap)
            + " for source "
            + draft_source_name(config.source)
            + " (cap from J-071 plan_proposer("
            + proposer_kind_name(_source_proposer_kind(config.source))
            + "), never restated here)"
        )


# --- the recorded gates, bound not rebuilt -------------------------------


def validate_mtp_source(
    config: DraftConfig,
    target_file_name: String,
    directory_read: Bool,
    tensor_names: List[String],
) raises -> MtpAdmission:
    """Validate a --mtp configuration through J-077's gate.

    The caller states the target file's tensor directory as
    it read it (directory_read False states it read none).
    An inadmissible file raises with J-077's own refusal
    line (REFUSE_NO_MTP / REFUSE_VOCAB_ONLY /
    REFUSE_NOT_PROVEN / REFUSE_EMPTY_FILE_NAME)."""
    if config.source != DRAFT_SOURCE_MTP_HEAD:
        raise Error(
            "DraftConfig: REFUSE_NOT_MTP_SOURCE -- this"
            " configuration's source is "
            + draft_source_name(config.source)
            + ", not mtp-head"
        )
    var admission = evaluate_mtp_admission(
        target_file_name, directory_read, tensor_names
    )
    if not admission.admitted:
        raise Error(
            "DraftConfig: --mtp refused for '"
            + target_file_name
            + "': "
            + mtp_refusal_line(admission)
        )
    return admission^


def validate_draft_model_pair(
    config: DraftConfig,
    drafter: ModelSide,
    target: ModelSide,
    tokenizer: TokenizerComparison,
    tokenizer_verified: Bool,
    free_at_open_bytes: Int,
    total_bytes: Int,
    hard_cap_bytes: Int,
    per_token_routed_bytes: Int,
) raises -> PairVerdict:
    """Validate a --draft configuration through J-074's gate.

    The pair facts are the caller's, stated in J-074's own
    shapes; the configuration contributes only its k. An
    inadmissible pair raises with the gate's reason name
    (pair_reason_name's vocabulary: REFUSE_MISSING_FILE,
    REFUSE_UNKNOWN_FAMILY_PAIRING, REFUSE_DRAFTER_NOT_SMALLER,
    REFUSE_TOKENIZER_UNVERIFIED, REFUSE_TOKENIZER_MISMATCH,
    REFUSE_K_OVER_CAP, REFUSE_BUDGET_EXCEEDED)."""
    if config.source != DRAFT_SOURCE_DRAFT_MODEL:
        raise Error(
            "DraftConfig: REFUSE_NOT_DRAFT_SOURCE -- this"
            " configuration's source is "
            + draft_source_name(config.source)
            + ", not draft-model"
        )
    var verdict = evaluate_pair(
        drafter,
        target,
        tokenizer,
        tokenizer_verified,
        config.k,
        free_at_open_bytes,
        total_bytes,
        hard_cap_bytes,
        per_token_routed_bytes,
    )
    if not verdict.admissible:
        raise Error(
            "DraftConfig: --draft pair refused for '"
            + config.draft_model
            + "': "
            + pair_reason_name(verdict.reason_code)
            + " (J-074 evaluate_pair; the pair is not"
            + " configured, persisted, or used)"
        )
    return verdict^


def require_draft_config_use(config: DraftConfig) raises:
    """The fail-closed use gate for a draft configuration.

    Stands while the road's two global blockers stand:
    G-PROPOSER (no proposer implementation exists in-tree
    for any kind) and G-EXECUTOR (no verify-pass executor
    exists in-tree; J-036's require_draft_check_use() still
    raises and the facade's speculative_generate still
    raises not-implemented). Any attempt to USE a
    configuration raises here, by name -- a configured
    source by the blockers, an unconfigured one by
    REFUSE_NO_SOURCE. Recording, validating, and persisting
    a configuration are not use and never call this."""
    validate_draft_config(config)
    if config.source == DRAFT_SOURCE_NONE:
        raise Error(
            "DraftConfig: REFUSE_NO_SOURCE -- no draft source"
            " is configured (state --mtp or --draft <model>);"
            " there is nothing to use"
        )
    raise Error(
        "DraftConfig: using a draft configuration is refused"
        " -- G-PROPOSER (no proposer implementation exists"
        " in-tree) and G-EXECUTOR (no verify-pass executor"
        " exists in-tree) stand; require_draft_check_use()"
        " (J-036) still fails closed and the facade's"
        " speculative_generate still raises not-implemented."
        " A stored configuration records intent only, until"
        " Part V's live legs land (recipe at the J-086 gate)"
    )


# --- raw layers: argv scan + environment (J-036's shape) -----------------


struct RawDraftInputs(Copyable, ImplicitlyCopyable):
    """One raw layer (cli or env) in J-036's shape: every
    statement beside its was-set flag; precedence and
    contradiction are the resolver's, not the container's.
    mtp_env_bad carries an AESIR_MTP value that is neither
    1 nor 0, so the resolver refuses it with its reason even
    when nothing else is stated (J-036's kill-value rule)."""

    var mtp_on_set: Bool
    var mtp_off_set: Bool
    var draft_model: String
    var draft_model_set: Bool
    var draft_k: String
    var draft_k_set: Bool
    var mtp_env_bad: String
    var mtp_env_bad_set: Bool

    def __init__(out self):
        self.mtp_on_set = False
        self.mtp_off_set = False
        self.draft_model = String("")
        self.draft_model_set = False
        self.draft_k = String("")
        self.draft_k_set = False
        self.mtp_env_bad = String("")
        self.mtp_env_bad_set = False


def _looks_like_draft_flag(arg: String) -> Bool:
    """True for args in this surface's namespace, known or
    not (J-036's scan discipline): a typo'd draft flag must
    not become a silently undrafted -- or silently drafted
    -- run."""
    return (
        arg.startswith("--mtp")
        or arg.startswith("--no-mtp")
        or arg.startswith("--draft")
    )


def _split_draft_flag(arg: String) -> Tuple[String, String, Bool]:
    var eq = arg.find("=")
    if eq >= 0:
        return (String(arg[byte=:eq]), String(arg[byte=eq + 1:]), True)
    return (arg, String(""), False)


def scan_draft_args(args: List[String]) raises -> RawDraftInputs:
    """Scan a shared argv for this surface's flags.

    Owns --mtp / --no-mtp (switches, no value), --draft and
    --draft-k (values, both `--flag value` and `--flag=value`
    forms). Flags outside the namespace are ignored (other
    surfaces own them -- including J-036's --drafts-on, a
    placement flag whose name merely resembles this one's).
    Refusals: a value flag with no value, a value handed to
    a switch, the same statement twice, and any
    unrecognised flag inside the namespace."""
    var raw = RawDraftInputs()
    var i = 0
    while i < len(args):
        var arg = args[i]
        if not _looks_like_draft_flag(arg):
            i += 1
            continue
        var split = _split_draft_flag(arg)
        var name = split[0]
        var inline_value = split[1]
        var has_eq = split[2]
        if name == "--drafts-on":
            # J-036's placement flag, not this surface's:
            # its value (if in `--flag value` form) is the
            # placement surface's to consume; skip the flag
            # token only, exactly as that scan skips ours.
            i += 1
            continue
        if name == "--mtp" or name == "--no-mtp":
            if has_eq:
                raise Error(
                    "DraftConfig: "
                    + name
                    + " is a switch and takes no value (got '"
                    + inline_value
                    + "')"
                )
            if name == "--mtp":
                if raw.mtp_on_set:
                    raise Error("DraftConfig: --mtp is set twice; state it once")
                raw.mtp_on_set = True
            else:
                if raw.mtp_off_set:
                    raise Error("DraftConfig: --no-mtp is set twice; state it once")
                raw.mtp_off_set = True
            i += 1
            continue
        var is_value_flag = name == "--draft" or name == "--draft-k"
        if not is_value_flag:
            raise Error(
                "DraftConfig: unknown option '"
                + name
                + "' in the draft configuration surface (options"
                + " are --mtp, --no-mtp, --draft, --draft-k)"
            )
        var value = inline_value
        if not has_eq:
            if i + 1 >= len(args):
                raise Error(
                    "DraftConfig: " + name + " requires a value, but none follows it"
                )
            value = args[i + 1]
            i += 1
        if name == "--draft":
            if raw.draft_model_set:
                raise Error("DraftConfig: --draft is set twice; state it once")
            raw.draft_model = value
            raw.draft_model_set = True
        else:
            if raw.draft_k_set:
                raise Error("DraftConfig: --draft-k is set twice; state it once")
            raw.draft_k = value
            raw.draft_k_set = True
        i += 1
    return raw


def _draft_env_value(name: String) -> Tuple[Bool, String]:
    """One environment variable: (is_set, value), in
    learned_file's shape with a path-sized value bound."""
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
    while i < 1024:
        var c = raw.unsafe_load(i)
        if c == 0:
            break
        value += chr(Int(c))
        i += 1
    return (True, value)


def draft_env_inputs() -> RawDraftInputs:
    """Read this surface's environment equivalents.

    AESIR_MTP carries the mtp statement (1 = --mtp,
    0 = --no-mtp; any other value is carried as a bad value
    for the resolver to refuse, never reinterpreted);
    AESIR_DRAFT_MODEL carries the draft file; AESIR_DRAFT_K
    carries the configured k. An env var set empty counts
    as set -- its refusal is the resolver's, stated, not
    silent."""
    var raw = RawDraftInputs()
    var mtp = _draft_env_value("AESIR_MTP")
    if mtp[0]:
        if mtp[1] == "1":
            raw.mtp_on_set = True
        elif mtp[1] == "0":
            raw.mtp_off_set = True
        else:
            raw.mtp_env_bad = mtp[1]
            raw.mtp_env_bad_set = True
    var model = _draft_env_value("AESIR_DRAFT_MODEL")
    if model[0]:
        raw.draft_model = model[1]
        raw.draft_model_set = True
    var k = _draft_env_value("AESIR_DRAFT_K")
    if k[0]:
        raw.draft_k = k[1]
        raw.draft_k_set = True
    return raw


def parse_draft_k(text: String) raises -> Int:
    """The --draft-k grammar: unsigned decimal, no sign, no
    whitespace, no partial parses (the tree's strict value
    grammars' shape). The band check is validate's, so the
    refusal there can name the cap."""
    var value = String(text.strip())
    if value.byte_length() == 0:
        raise Error("DraftConfig: REFUSE_BAD_K -- --draft-k value must not be empty")
    var result = 0
    for byte in value.as_bytes():
        if byte < 48 or byte > 57:
            raise Error(
                "DraftConfig: REFUSE_BAD_K -- --draft-k value '"
                + text
                + "' is not an unsigned decimal draft length"
            )
        result = result * 10 + Int(byte - 48)
        if result > 1000000:
            raise Error(
                "DraftConfig: REFUSE_BAD_K -- --draft-k value '"
                + text
                + "' is not a draft length"
            )
    return result


def resolve_draft_config(
    cli: RawDraftInputs, env: RawDraftInputs
) raises -> DraftConfig:
    """Resolve the two raw layers into the validated
    configuration -- THE shared resolver both surfaces call.

    Order of refusal: a bad AESIR_MTP value first (refused
    even if nothing else is stated), then the cross-layer
    mtp contradiction, then the source contradiction, then
    the picked values' own validation. Precedence is
    cli > env > default, per field independently -- except
    the mtp on/off statements, which are never resolved by
    precedence: both stated, anywhere, is a contradiction
    refused by name."""
    if cli.mtp_env_bad_set or env.mtp_env_bad_set:
        var bad = env.mtp_env_bad if env.mtp_env_bad_set else cli.mtp_env_bad
        raise Error(
            "DraftConfig: REFUSE_BAD_MTP_ENV -- AESIR_MTP value '"
            + bad
            + "' is not an mtp statement (1 states --mtp,"
            + " 0 states --no-mtp)"
        )
    var on_any = cli.mtp_on_set or env.mtp_on_set
    var off_any = cli.mtp_off_set or env.mtp_off_set
    if on_any and off_any:
        raise Error(
            "DraftConfig: REFUSE_CONTRADICTORY_MTP -- --mtp and"
            " --no-mtp are both stated (cli or env); a hand"
            " contradiction is refused, never resolved by"
            " precedence"
        )
    var config = DraftConfig()
    if on_any:
        config.mtp_state = DRAFT_MTP_ON
        config.mtp_layer = SOURCE_CLI if cli.mtp_on_set else SOURCE_ENV
    elif off_any:
        config.mtp_state = DRAFT_MTP_OFF
        config.mtp_layer = SOURCE_CLI if cli.mtp_off_set else SOURCE_ENV
    var model_set = cli.draft_model_set or env.draft_model_set
    if model_set:
        config.draft_model = (
            cli.draft_model if cli.draft_model_set else env.draft_model
        )
        config.model_layer = SOURCE_CLI if cli.draft_model_set else SOURCE_ENV
        if config.draft_model.byte_length() == 0:
            raise Error(
                "DraftConfig: REFUSE_MISSING_DRAFT_MODEL --"
                " --draft names no file (empty value)"
            )
    if on_any and model_set:
        raise Error(
            "DraftConfig: REFUSE_CONTRADICTORY_SOURCES --"
            " --mtp and --draft <model> name two proposer"
            " sources; a configuration states one (J-071's"
            " slots; J-072 runs one proposer per round)"
        )
    if on_any:
        config.source = DRAFT_SOURCE_MTP_HEAD
    elif model_set:
        config.source = DRAFT_SOURCE_DRAFT_MODEL
    var k_set = cli.draft_k_set or env.draft_k_set
    if k_set:
        var k_text = cli.draft_k if cli.draft_k_set else env.draft_k
        config.k = parse_draft_k(k_text)
        config.k_layer = SOURCE_CLI if cli.draft_k_set else SOURCE_ENV
    validate_draft_config(config)
    return config


def resolve_chat_draft_config(args: List[String]) raises -> DraftConfig:
    """The chat surface's entry: scan + env + the one
    resolver. Kept as a named wrapper so the chat surface's
    use of the shared parser is auditable (J-049's pattern)."""
    return resolve_draft_config(scan_draft_args(args), draft_env_inputs())


def resolve_server_draft_config(args: List[String]) raises -> DraftConfig:
    """The server surface's entry: the SAME scan + env +
    resolver as the chat surface's. Parity is this identity,
    and the test suite grades both entries on the same argv
    lists, field by field and by describe()."""
    return resolve_draft_config(scan_draft_args(args), draft_env_inputs())


# --- persistence via Part III's learned file -----------------------------


def apply_draft_config(
    entry: LearnedEntry, config: DraftConfig
) raises -> LearnedEntry:
    """Return a copy of `entry` carrying `config` as its
    learned draft configuration (the merge a host performs
    before storing, when it also holds learned pass choices
    for the key). The configuration is validated first; the
    entry's own validation is the store's."""
    validate_draft_config(config)
    var out_entry = entry.copy()
    out_entry.draft_present = True
    out_entry.draft_source = config.source
    out_entry.draft_mtp = config.mtp_state
    out_entry.draft_model = config.draft_model
    out_entry.draft_k = config.k
    return out_entry^


def draft_config_to_entry(
    config: DraftConfig,
    machine: MachineKey,
    model: ModelShape,
    measured_at: Int64,
) raises -> LearnedEntry:
    """Build the learned entry that carries `config` alone
    (no pass choices) under an exact machine+model key."""
    var entry = LearnedEntry()
    entry.machine = machine
    entry.model = model
    entry.measured_at = measured_at
    return apply_draft_config(entry, config)


def persist_draft_config(
    path: String,
    config: DraftConfig,
    machine: MachineKey,
    model: ModelShape,
    measured_at: Int64,
) raises -> Int:
    """Persist a validated configuration into the learned
    file at `path` (the entry count after storing).

    Delegates whole to J-044's store_learned_entry: same
    file, same atomic write, same refusal to store into a
    REFUSED file. One entry per key, replaced whole -- see
    the header's persistence rule."""
    var entry = draft_config_to_entry(config, machine, model, measured_at)
    return store_learned_entry(path, entry^)


struct DraftConfigLoad(Copyable, Movable):
    """One read-back's outcome: found with the configuration,
    or a named non-found state with its reason (mirroring
    LearnedLoad's honesty: MISSING is clean, REFUSED carries
    its reason, a key mismatch names its half)."""

    var found: Bool
    var reason: String
    var config: DraftConfig

    def __init__(out self):
        self.found = False
        self.reason = String("not loaded")
        self.config = DraftConfig()


def load_draft_config(
    path: String, machine: MachineKey, model: ModelShape
) -> DraftConfigLoad:
    """Read a persisted draft configuration back by exact
    key. Never raises: the learned load's states are data,
    exactly as J-044 states them."""
    var result = DraftConfigLoad()
    var load = load_learned_file(path)
    if load.status != LOAD_LOADED:
        result.reason = (
            "the learned state is "
            + load_status_name(load.status)
            + ", so no draft configuration can apply"
        )
        if load.status == LOAD_REFUSED:
            result.reason += " (" + load.reason + ")"
        return result^
    var lookup = lookup_learned(load, machine, model)
    if lookup.status != LOOKUP_APPLIED:
        result.reason = (
            "lookup "
            + lookup_status_name(lookup.status)
            + ": "
            + lookup.reason
        )
        return result^
    var entry = lookup.entry.copy()
    if not entry.draft_present:
        result.reason = (
            "the learned entry for this key carries no draft"
            " configuration"
        )
        return result^
    var config = DraftConfig()
    config.source = entry.draft_source
    config.mtp_state = entry.draft_mtp
    config.draft_model = entry.draft_model
    config.k = entry.draft_k
    result.config = config
    result.found = True
    result.reason = String("exact machine+model key match")
    return result^
