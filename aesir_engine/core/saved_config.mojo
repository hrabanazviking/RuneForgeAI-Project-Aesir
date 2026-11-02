"""The saved configuration: a user's explicit statements,
persisted per user, and reconciled with the learned file as
one story (Janas road J-104).

The roadmap text: "/save-config analogue: placement choices,
draft settings, cache cap persist per user and are shown on
demand; the learned file (J-044) and saved config reconciled
as one story." J-099's census (row T04) named the delta
exactly: the learned file exists (J-044, draft section
J-083), the placement grammar exists (J-036), the precedence
exists (J-047: hand > preset > learned > auto), the cache-cap
grammar exists (J-018) -- what was absent is any
/save-config-family command, any per-user store for EXPLICIT
statements (as opposed to measured ones), and the one-story
reconciliation. This module is that absent half; it rebuilds
none of the layers it binds.

THE TWO STORES ARE TWO KINDS OF STATEMENT. The learned file
(core/learned_file.mojo) holds what the machine MEASURED:
placement + thread choices and one draft configuration per
machine+model key, in Aesir's cache home. This module's
store holds what the user STATED: placement choices per pass
kind (J-036 values), one draft statement (J-083's
vocabulary), and the expert-cache cap (J-018's byte sizes).
A stated value is a hand statement in J-047's sense; a
learned value is a default only. Neither store writes the
other, and their erasure paths are separate (below).

THE SAVED STORE. One record per user, keyed by nothing: its
contents are statements, not measurements, so no machine or
model key belongs in it -- it lives in the same cache home
and applies on that machine for that user until changed or
erased. The file is Aesir's own format, versioned and
human-readable (header AESIR_SAVED_CONFIG_V1, fixed-order
lines, FNV-1a checksum over the whole body -- the learned
file's discipline), saves are atomic (stage in the same
directory, fsync, rename, sync the parent), and the parser
is strict: any unknown, missing, reordered, or extra line is
a refusal, which is also what keeps an expert-map section
out -- J-027 measured cache persistence and REJECTED it, and
no field of this record can hold one.

THE PATH. AESIR_SAVED_CONFIG_FILE names the file itself and
wins; else $AESIR_CACHE_HOME/saved-config.v1; else
$HOME/.cache/aesir/saved-config.v1; else
.aesir-cache/saved-config.v1 relative to the working
directory (the learned file's rule and env style, its own
first env). saved_config_path() reads the live environment;
resolve_saved_path() is its pure, unit-tested form. An env
set to the empty string counts as unset.

LOAD HONESTY, the learned file's three states: MISSING (no
file at the path -- the clean no-saved state, data, never an
error), LOADED (parsed whole, checksum verified, every field
validated -- only a LOADED state states anything), REFUSED
(the file exists but is corrupt, truncated, of an unknown
version, oversized, or unreadable -- a clean refusal with
the reason, ZERO fields carried, the file left untouched;
storing into a REFUSED file raises rather than silently
overwriting evidence of corruption). An empty saved config
is refused at save: a config stating no field is not a
config; having none is expressed by erasure.

THE FIELD SET, and nothing else: prompt_on / drafts_on /
reply_on (each a J-036 placement value in canonical written
form, validated by re-parsing for its kind and requiring the
canonical rendering to round-trip, exactly as the learned
file validates a learned choice's option provenance -- the
pass-kind legality J-036 enforces, the NPU refused for
drafts and reply, comes with the parse); one draft statement
(source / mtp state / draft model / k, structurally
validated by the same rules core/learned_file.mojo's
validate_draft pins, in the same vocabulary); the cache cap
in bytes (a positive count; 0 is resolve_hard_cap's UNSET
sentinel and is never a statable cap -- stating "no cap" is
done by clearing the field); and a saved-at stamp (unix
seconds, supplied by the host from the learned file's clock
read). No sampling settings (the chat's /set owns those per
session), no model choice (the picker's domain), no expert
map (J-027).

THE ONE STORY (the reconciliation this slice exists for).
config_story_report renders, per field, the saved statement,
the learned statement for the caller's exact key (or the
lookup's named non-apply outcome), and the effective value
with the layer that supplied it. The per-field rules:

- Placement, per kind: the first layer that states the kind
  governs, in J-047's order with the saved layer placed in
  the hand layer -- (1) a session explicit option (the
  freshest hand statement), (2) the saved config (a
  persisted hand statement), (3) a --mode preset where it
  fixes the kind, (4) the learned choice (measured, exact
  key only), (5) auto (measure at open). Within the hand
  layer the fresher statement wins; a persisted hand
  statement outranks a preset because J-047 ranks hand over
  preset without distinguishing fresh from persisted hands
  (answered-locally, J-104 doc section 8).
- Draft settings: session draft configuration > saved draft
  statement > the learned entry's draft section (exact key)
  > no draft configuration. Resolution states intent and
  provenance only -- using a draft configuration still
  stands or falls at core/draft_config.mojo's
  require_draft_config_use() (G-PROPOSER + G-EXECUTOR stand).
- Cache cap: the saved config is the ONLY store that owns
  this field (the learned file has no cap field and none may
  be added); effective is the saved cap, or unset.
- Thread counts are never stated here (a placement option
  fixes no thread count); the learned choice's thread count
  is the only persisted thread statement, as J-044 states it.

A REFUSED store never participates: the story reports it as
refused with its reason and resolves from the remaining
layers; a refused store is never partially read and never
silently treated as missing.

SEPARATE ERASE PATHS, stated on the report's face: erasing
the saved config (erase_saved_config, or /save-config
erase) removes the saved file only -- learned entries are
untouched. Erasing learned state is the learned file's own
erase functions only -- the saved config is untouched.
Neither path calls the other, ever.

THE COMMAND FAMILY. parse_config_command parses the chat's
/save-config grammar purely (the chat layer executes the
parsed action): "/save-config" shows the story;
"/save-config <field> <value>" states one field
(prompt-on / drafts-on / reply-on, draft-source, draft-mtp,
draft-model, draft-k, cache-cap -- values are single tokens,
as the chat's /set values are); "/save-config clear <field>"
unstates one field; "/save-config erase" erases the saved
file only; "/save-config help" states the usage. The
assembled configuration is validated WHOLE before anything
is written; a refusal names the field and the reason and
writes nothing. The draft fields' apply semantics follow
J-083's readings: stating draft-source mtp-head also records
mtp on (the only consistent reading); stating draft-mtp on
with no source stated selects the mtp-head source; stating
a draft model with no source stated selects the draft-model
source; contradictions (mtp on beside a draft-model source)
are refused by name, never resolved silently.
saved_config_command_response is the chat host's one call:
parse, execute against saved_config_path() (with the learned
file read beside it, read-only, for the show form), and
return the text to emit.

HOST CONTRACT (binding; this module fakes no integration):
at model open a surface (1) loads both stores (MISSING and
REFUSED are data, printed with their reasons); (2) resolves
each kind through resolve_kind_story with its session
options, the resolved preset, the saved load, and the
learned lookup for the session's exact key, and the draft
and cap fields through their resolvers; (3) consumes the
resolutions only as far as the underlying layers allow
today (placement consumption is the chooser surfaces' own
state, drafts stand at J-083's use gate). The chat wiring in
this slice executes the command family against the disk
surface and shows the two stores side by side as one story
at file level; the per-key effective resolution is this
module's proven pure layer, consumed at open per this
contract. See docs/janas/J104_SAVED_CONFIGURATION.md.
"""

from std.ffi import external_call
from std.memory import Pointer
from std.collections import InlineArray

from core.expert_cache import parse_byte_size
from core.learned_file import (
    LEARNED_DRAFT_MTP_OFF,
    LEARNED_DRAFT_MTP_ON,
    LEARNED_DRAFT_MTP_UNSET,
    LEARNED_DRAFT_SOURCE_DRAFT_MODEL,
    LEARNED_DRAFT_SOURCE_MTP_HEAD,
    LEARNED_DRAFT_SOURCE_NONE,
    LOAD_LOADED,
    LOAD_MISSING,
    LOAD_REFUSED,
    LOOKUP_APPLIED,
    LearnedEntry,
    LearnedLoad,
    LookupResult,
    learned_draft_mtp_name,
    learned_draft_source_name,
    learned_file_path,
    learned_now_seconds,
    load_learned_file,
    load_status_name,
    lookup_status_name,
)
from core.placement_options import (
    PASS_DRAFTS,
    PASS_PROMPT,
    PASS_REPLY,
    parse_placement_value,
    pass_name,
)
from core.speculative_loop import LOOP_K_INITIAL
from core.text_admission import admit_text_bytes

comptime SAVED_HEADER = "AESIR_SAVED_CONFIG_V1"
comptime SAVED_FILE_NAME = "saved-config.v1"
comptime MAX_SAVED_BYTES = 65536
comptime MAX_SAVED_TEXT_BYTES = 4096
comptime MAX_CACHE_CAP_BYTES = 1152921504606846976

# Saved-load states (SavedLoad.status).
comptime SAVED_MISSING = 0
comptime SAVED_LOADED = 1
comptime SAVED_REFUSED = 2

# Field keys (the command family's field names, and the
# report's). KIND fields carry their pass kind.
comptime FIELD_PROMPT_ON = "prompt-on"
comptime FIELD_DRAFTS_ON = "drafts-on"
comptime FIELD_REPLY_ON = "reply-on"
comptime FIELD_DRAFT_SOURCE = "draft-source"
comptime FIELD_DRAFT_MTP = "draft-mtp"
comptime FIELD_DRAFT_MODEL = "draft-model"
comptime FIELD_DRAFT_K = "draft-k"
comptime FIELD_CACHE_CAP = "cache-cap"


def saved_load_status_name(code: Int) -> String:
    if code == SAVED_LOADED:
        return String("LOADED")
    if code == SAVED_REFUSED:
        return String("REFUSED")
    return String("MISSING")


def field_pass_kind(field: String) -> Int:
    """The pass kind a placement field names, or -1."""
    if field == FIELD_PROMPT_ON:
        return PASS_PROMPT
    if field == FIELD_DRAFTS_ON:
        return PASS_DRAFTS
    if field == FIELD_REPLY_ON:
        return PASS_REPLY
    return -1


def field_known(field: String) -> Bool:
    return (
        field_pass_kind(field) >= 0
        or field == FIELD_DRAFT_SOURCE
        or field == FIELD_DRAFT_MTP
        or field == FIELD_DRAFT_MODEL
        or field == FIELD_DRAFT_K
        or field == FIELD_CACHE_CAP
    )


def saved_field_names() -> String:
    return String(
        "prompt-on, drafts-on, reply-on, draft-source, draft-mtp,"
        " draft-model, draft-k, cache-cap"
    )


# --- small shared helpers (the tree's persisted-record style) --------


def _saved_checksum(payload: String) -> UInt64:
    """FNV-1a over the canonical body (the learned file's)."""
    var checksum: UInt64 = 14695981039346656037
    for byte in payload.as_bytes():
        checksum = (checksum ^ UInt64(byte)) * 1099511628211
    return checksum


def _saved_hex(value: UInt64) -> String:
    var chars = String("0123456789abcdef")
    var result = String("")
    for shift in range(60, -4, -4):
        var nibble = Int((value >> UInt64(shift)) & 15)
        result += String(chars[byte=nibble : nibble + 1])
    return result


def _saved_parse_hex(value: String) raises -> UInt64:
    if len(value.bytes()) != 16:
        raise Error("SavedConfig: checksum must be 16 lowercase hex digits")
    var result: UInt64 = 0
    for byte in value.as_bytes():
        var nibble: Int
        if byte >= 48 and byte <= 57:
            nibble = Int(byte - 48)
        elif byte >= 97 and byte <= 102:
            nibble = Int(byte - 87)
        else:
            raise Error("SavedConfig: checksum holds a non-hex digit")
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
    raise Error("SavedConfig: hex field holds a non-hex digit")


def _hex_decode(value: String, label: String) raises -> String:
    if len(value.bytes()) % 2 != 0:
        raise Error("SavedConfig: " + label + " hex is odd-length")
    var output = List[Byte]()
    var source = value.as_bytes()
    for index in range(0, len(source), 2):
        var decoded = (
            (_hex_nibble(Int(source[index])) << 4)
            | _hex_nibble(Int(source[index + 1]))
        )
        output.append(Byte(decoded))
    return admit_text_bytes(output, label, MAX_SAVED_TEXT_BYTES, True)


def _parse_nonnegative(text: String, field: String) raises -> Int:
    """One strict unsigned decimal (digits only, no sign, no
    whitespace inside; surrounding whitespace stripped)."""
    var value = String(text.strip())
    if value.byte_length() == 0:
        raise Error("SavedConfig: " + field + " must not be empty")
    var result = 0
    for byte in value.as_bytes():
        if byte < 48 or byte > 57:
            raise Error(
                "SavedConfig: " + field + " '" + text
                + "' is not an unsigned decimal"
            )
        result = result * 10 + Int(byte - 48)
        if result > MAX_CACHE_CAP_BYTES:
            raise Error("SavedConfig: " + field + " is out of range")
    return result


def _parse_stamp(text: String, field: String) raises -> Int64:
    return Int64(_parse_nonnegative(text, field))


def _check_printable(text: String, field: String, max_bytes: Int) raises:
    if text.byte_length() == 0 or text.byte_length() > max_bytes:
        raise Error(
            "SavedConfig: " + field + " must be 1.."
            + String(max_bytes) + " bytes"
        )
    for byte in text.as_bytes():
        var code = Int(byte)
        if code < 32 or code > 126:
            raise Error("SavedConfig: " + field + " holds a non-printable byte")


# --- the saved record ----------------------------------------------------


struct SavedConfig(Copyable, ImplicitlyCopyable):
    """One user's saved statements (module header's field set).

    Absent placement fields carry the canonical "-" text;
    an absent draft statement carries source none / mtp
    unset / model "-" / k 0; an absent cap carries 0 bytes.
    saved_at is the host-supplied unix-seconds stamp of the
    save that wrote this record (0 only on a never-saved,
    in-memory empty record -- which validate refuses to
    serialise for the emptiness, not the stamp)."""

    var prompt_on_present: Bool
    var prompt_on: String
    var drafts_on_present: Bool
    var drafts_on: String
    var reply_on_present: Bool
    var reply_on: String
    var draft_present: Bool
    var draft_source: Int
    var draft_mtp: Int
    var draft_model: String
    var draft_k: Int
    var cache_cap_present: Bool
    var cache_cap_bytes: Int
    var saved_at: Int64

    def __init__(out self):
        self.prompt_on_present = False
        self.prompt_on = String("-")
        self.drafts_on_present = False
        self.drafts_on = String("-")
        self.reply_on_present = False
        self.reply_on = String("-")
        self.draft_present = False
        self.draft_source = LEARNED_DRAFT_SOURCE_NONE
        self.draft_mtp = LEARNED_DRAFT_MTP_UNSET
        self.draft_model = String("-")
        self.draft_k = 0
        self.cache_cap_present = False
        self.cache_cap_bytes = 0
        self.saved_at = 0

    def placement(self, pass_kind: Int) -> Tuple[Bool, String]:
        if pass_kind == PASS_DRAFTS:
            return (self.drafts_on_present, self.drafts_on)
        if pass_kind == PASS_REPLY:
            return (self.reply_on_present, self.reply_on)
        return (self.prompt_on_present, self.prompt_on)

    def has_any(self) -> Bool:
        return (
            self.prompt_on_present
            or self.drafts_on_present
            or self.reply_on_present
            or self.draft_present
            or self.cache_cap_present
        )

    def _validate_placement(
        self, present: Bool, text: String, pass_kind: Int
    ) raises:
        var kind_name = pass_name(pass_kind)
        if not present:
            if text != "-":
                raise Error(
                    "SavedConfig: an absent " + kind_name
                    + " placement must carry its canonical '-' text"
                )
            return
        var parsed = parse_placement_value(text, pass_kind)
        if parsed.describe() != text:
            raise Error(
                "SavedConfig: the " + kind_name + " placement '"
                + text + "' is not in J-036 canonical written form"
            )

    def validate_draft(self) raises:
        """The draft statement's structural validity: the
        learned file's validate_draft rules, same vocabulary
        (form only; the surface gates are draft_config's)."""
        if not self.draft_present:
            if (
                self.draft_source != LEARNED_DRAFT_SOURCE_NONE
                or self.draft_mtp != LEARNED_DRAFT_MTP_UNSET
                or self.draft_model != "-"
                or self.draft_k != 0
            ):
                raise Error(
                    "SavedConfig: an absent draft statement must"
                    " carry its canonical empty fields"
                )
            return
        if (
            self.draft_source != LEARNED_DRAFT_SOURCE_MTP_HEAD
            and self.draft_source != LEARNED_DRAFT_SOURCE_DRAFT_MODEL
        ):
            raise Error(
                "SavedConfig: a present draft statement names an"
                " unknown source code"
            )
        if self.draft_mtp < 0 or self.draft_mtp > 2:
            raise Error(
                "SavedConfig: a present draft statement holds an"
                " unknown mtp state code"
            )
        if self.draft_k < 1 or self.draft_k > 15:
            raise Error(
                "SavedConfig: a present draft statement's k is"
                " outside the draft-check band 1..15 (J-071)"
            )
        _check_printable(self.draft_model, "draft model", 512)
        if self.draft_source == LEARNED_DRAFT_SOURCE_MTP_HEAD:
            if self.draft_model != "-":
                raise Error(
                    "SavedConfig: an mtp-head draft statement names"
                    " no separate draft file (the head is the"
                    " target's own)"
                )
            if self.draft_mtp != LEARNED_DRAFT_MTP_ON:
                raise Error(
                    "SavedConfig: an mtp-head draft statement must"
                    " record mtp on"
                )
        else:
            if self.draft_model == "-" or self.draft_model.byte_length() == 0:
                raise Error(
                    "SavedConfig: a draft-model statement must name"
                    " its draft file"
                )

    def validate(self) raises:
        self._validate_placement(
            self.prompt_on_present, self.prompt_on, PASS_PROMPT
        )
        self._validate_placement(
            self.drafts_on_present, self.drafts_on, PASS_DRAFTS
        )
        self._validate_placement(
            self.reply_on_present, self.reply_on, PASS_REPLY
        )
        self.validate_draft()
        if self.cache_cap_present:
            if self.cache_cap_bytes < 1 or (
                self.cache_cap_bytes > MAX_CACHE_CAP_BYTES
            ):
                raise Error(
                    "SavedConfig: a stated cache cap must be within"
                    " 1..MAX_CACHE_CAP_BYTES (0 is the unset"
                    " sentinel; clear the field to state no cap)"
                )
        elif self.cache_cap_bytes != 0:
            raise Error(
                "SavedConfig: an absent cache cap must carry 0 bytes"
            )
        if self.saved_at < 0:
            raise Error("SavedConfig: the saved-at stamp must be >= 0")

    def draft_render(self) -> String:
        if not self.draft_present:
            return String("absent (no saved draft statement)")
        return (
            "source "
            + learned_draft_source_name(self.draft_source)
            + ", mtp "
            + learned_draft_mtp_name(self.draft_mtp)
            + ", model "
            + self.draft_model
            + ", k "
            + String(self.draft_k)
        )

    def render(self) -> String:
        var out_str = String("saved configuration\n")
        out_str += "  saved-at: " + String(self.saved_at) + " (unix s)\n"
        for kind in [PASS_PROMPT, PASS_DRAFTS, PASS_REPLY]:
            var stated = self.placement(kind)
            if stated[0]:
                out_str += "  " + pass_name(kind) + ": " + stated[1] + "\n"
            else:
                out_str += (
                    "  " + pass_name(kind)
                    + ": absent (no saved placement)\n"
                )
        out_str += "  drafts-config: " + self.draft_render() + "\n"
        if self.cache_cap_present:
            out_str += (
                "  cache-cap: " + String(self.cache_cap_bytes) + " bytes\n"
            )
        else:
            out_str += "  cache-cap: absent (no saved cap; unset)\n"
        return out_str


# --- serialisation -------------------------------------------------------
#
# The line format, fixed order (the parser walks it by exact
# offsets; any unknown, missing, reordered, or extra line is
# a refusal, which is also what keeps an expert-map section
# out: there is no line for one to occupy).
#
#   AESIR_SAVED_CONFIG_V1
#   prompt_on_present / prompt_on
#   drafts_on_present / drafts_on
#   reply_on_present / reply_on
#   draft_present / draft_source / draft_mtp /
#   draft_model_hex (the draft file name hex-encoded, like
#   the learned file's free-text material) / draft_k
#   cache_cap_present / cache_cap_bytes
#   saved_at
#   checksum=<16 lowercase hex, FNV-1a over every line above,
#   each terminated by exactly one newline>
# 16 lines in total.


def serialize_saved_config(config: SavedConfig) raises -> String:
    """Serialise the saved record. Raises on an invalid or
    empty configuration: a file that cannot be written whole
    is never written, and an empty config is not a config."""
    config.validate()
    if not config.has_any():
        raise Error(
            "SavedConfig: a configuration stating no field is not"
            " a configuration and is never saved (erase instead)"
        )
    var body = String(SAVED_HEADER) + "\n"
    body += (
        "prompt_on_present="
        + (String("1") if config.prompt_on_present else String("0"))
        + "\n"
    )
    body += "prompt_on=" + config.prompt_on + "\n"
    body += (
        "drafts_on_present="
        + (String("1") if config.drafts_on_present else String("0"))
        + "\n"
    )
    body += "drafts_on=" + config.drafts_on + "\n"
    body += (
        "reply_on_present="
        + (String("1") if config.reply_on_present else String("0"))
        + "\n"
    )
    body += "reply_on=" + config.reply_on + "\n"
    body += (
        "draft_present="
        + (String("1") if config.draft_present else String("0"))
        + "\n"
    )
    body += "draft_source=" + String(config.draft_source) + "\n"
    body += "draft_mtp=" + String(config.draft_mtp) + "\n"
    body += "draft_model_hex=" + _hex_encode(config.draft_model) + "\n"
    body += "draft_k=" + String(config.draft_k) + "\n"
    body += (
        "cache_cap_present="
        + (String("1") if config.cache_cap_present else String("0"))
        + "\n"
    )
    body += "cache_cap_bytes=" + String(config.cache_cap_bytes) + "\n"
    body += "saved_at=" + String(config.saved_at) + "\n"
    if len(body.bytes()) + 26 > MAX_SAVED_BYTES:
        raise Error("SavedConfig: serialised record exceeds the file cap")
    return body + "checksum=" + _saved_hex(_saved_checksum(body))


def _field(lines: List[String], index: Int, prefix: String) raises -> String:
    var line = lines[index]
    if not line.startswith(prefix):
        raise Error(
            "SavedConfig: line "
            + String(index + 1)
            + " must start with '"
            + prefix
            + "', got '"
            + line
            + "'"
        )
    return String(line[byte=prefix.byte_length():])


def _parse_flag(lines: List[String], index: Int, prefix: String) raises -> Bool:
    var text = _field(lines, index, prefix)
    if text == "1":
        return True
    if text == "0":
        return False
    raise Error("SavedConfig: " + prefix + "value must be 0 or 1")


def parse_saved_config(text: String) raises -> SavedConfig:
    """Parse the whole saved record, strictly. ANY deviation
    -- size, header, line count or order, field form,
    checksum, field validity -- raises with the reason. The
    disk loader turns that raise into the REFUSED state;
    nothing here ever returns a partial record."""
    if len(text.bytes()) == 0 or len(text.bytes()) > MAX_SAVED_BYTES:
        raise Error("SavedConfig: file size is outside 1..MAX_SAVED_BYTES")
    var lines = List[String]()
    for raw in text.split("\n"):
        lines.append(String(raw))
    if len(lines) != 16:
        raise Error(
            "SavedConfig: line count does not match the V1 format"
            " (truncated or extended file)"
        )
    var checksum_text = _field(lines, 15, "checksum=")
    var stated = _saved_parse_hex(checksum_text)
    var body = String("")
    for i in range(15):
        body += lines[i] + "\n"
    if _saved_checksum(body) != stated:
        raise Error("SavedConfig: checksum mismatch (corrupt or truncated file)")
    if lines[0] != SAVED_HEADER:
        raise Error(
            "SavedConfig: header is not "
            + SAVED_HEADER
            + " (unknown version or not a saved configuration)"
        )
    var config = SavedConfig()
    config.prompt_on_present = _parse_flag(lines, 1, "prompt_on_present=")
    config.prompt_on = _field(lines, 2, "prompt_on=")
    config.drafts_on_present = _parse_flag(lines, 3, "drafts_on_present=")
    config.drafts_on = _field(lines, 4, "drafts_on=")
    config.reply_on_present = _parse_flag(lines, 5, "reply_on_present=")
    config.reply_on = _field(lines, 6, "reply_on=")
    config.draft_present = _parse_flag(lines, 7, "draft_present=")
    config.draft_source = _parse_nonnegative(
        _field(lines, 8, "draft_source="), "draft source"
    )
    config.draft_mtp = _parse_nonnegative(
        _field(lines, 9, "draft_mtp="), "draft mtp"
    )
    config.draft_model = _hex_decode(
        _field(lines, 10, "draft_model_hex="), "draft model"
    )
    config.draft_k = _parse_nonnegative(
        _field(lines, 11, "draft_k="), "draft k"
    )
    config.cache_cap_present = _parse_flag(lines, 12, "cache_cap_present=")
    config.cache_cap_bytes = _parse_nonnegative(
        _field(lines, 13, "cache_cap_bytes="), "cache cap bytes"
    )
    config.saved_at = _parse_stamp(_field(lines, 14, "saved_at="), "saved at")
    config.validate()
    if not config.has_any():
        raise Error(
            "SavedConfig: the record states no field (an empty"
            " configuration is never a saved file)"
        )
    return config


# --- the loaded state ------------------------------------------------------


struct SavedLoad(Copyable, ImplicitlyCopyable):
    """The state one load produces: MISSING (clean, no file),
    LOADED (the record whole and verified), or REFUSED (the
    file exists but is not usable; reason stated). Only
    LOADED carries a configuration -- a refusal never
    partially applies, by construction. (ImplicitlyCopyable:
    the record is plain values, and the story layer copies
    loads freely.)"""

    var status: Int
    var reason: String
    var path: String
    var config: SavedConfig

    def __init__(out self):
        self.status = SAVED_MISSING
        self.reason = String("not loaded")
        self.path = String("")
        self.config = SavedConfig()

    def report(self) -> String:
        var out_str = String("saved configuration report\n")
        out_str += "path: " + self.path + "\n"
        if self.status == SAVED_LOADED:
            out_str += "state: LOADED\n"
            out_str += self.config.render()
        elif self.status == SAVED_REFUSED:
            out_str += (
                "state: REFUSED -- "
                + self.reason
                + " (no field is applied; the file is left untouched)\n"
            )
        else:
            out_str += (
                "state: MISSING -- no saved configuration at this"
                " path; the clean no-saved state (nothing is"
                " applied and nothing is in error)\n"
            )
        return out_str


# --- the cache home --------------------------------------------------------


def _saved_env_value(name: String) -> Tuple[Bool, String]:
    """Read one environment variable: (is_set, value), in the
    learned file's shape with a path-sized value bound."""
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


def resolve_saved_path(
    file_env: Tuple[Bool, String],
    cache_env: Tuple[Bool, String],
    home_env: Tuple[Bool, String],
) -> String:
    """The pure path rule (module header): AESIR_SAVED_CONFIG_FILE
    names the file itself and wins; AESIR_CACHE_HOME names the
    cache directory; HOME gives $HOME/.cache/aesir; with none
    of them, a relative .aesir-cache directory. An env set to
    the empty string counts as unset."""
    if file_env[0] and file_env[1].byte_length() > 0:
        return file_env[1]
    if cache_env[0] and cache_env[1].byte_length() > 0:
        return cache_env[1] + "/" + SAVED_FILE_NAME
    if home_env[0] and home_env[1].byte_length() > 0:
        return home_env[1] + "/.cache/aesir/" + SAVED_FILE_NAME
    return String(".aesir-cache/") + SAVED_FILE_NAME


def saved_config_path() -> String:
    """The live saved-config path from this process's env."""
    return resolve_saved_path(
        _saved_env_value("AESIR_SAVED_CONFIG_FILE"),
        _saved_env_value("AESIR_CACHE_HOME"),
        _saved_env_value("HOME"),
    )


# --- file IO (the learned file's proven discipline, this file's bounds) ---


def _saved_cstring(value: String) raises -> List[Int8]:
    if len(value.bytes()) == 0 or len(value.bytes()) >= 4096:
        raise Error("SavedConfig: path must contain 1..4095 bytes")
    var result = List[Int8]()
    for byte in value.as_bytes():
        if byte == 0:
            raise Error("SavedConfig: path contains NUL")
        result.append(Int8(byte))
    result.append(0)
    return result^


def _saved_parent(path: String) -> String:
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
    var parent = _saved_parent(path)
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
        var encoded = _saved_cstring(current)
        if external_call["mkdir", Int32](encoded.unsafe_ptr(), 448) != 0:
            var errno_ptr = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_ptr.unsafe_load() != 17:
                raise Error(
                    "SavedConfig: cannot create cache directory '"
                    + current
                    + "'"
                )


def _saved_write_all(fd: Int32, content: String) raises:
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
            raise Error("SavedConfig: staged write failed")
        if written == 0:
            raise Error("SavedConfig: staged write made no progress")
        offset += written


def _saved_sync_parent(path: String) raises:
    var parent = _saved_cstring(_saved_parent(path))
    var fd = external_call["open64", Int32](
        parent.unsafe_ptr(), Int32(720896), Int32(0)
    )
    if fd < 0:
        raise Error("SavedConfig: cannot open parent directory to sync")
    var sync_result = external_call["fsync", Int32](fd)
    var close_result = external_call["close", Int32](fd)
    if sync_result != 0 or close_result != 0:
        raise Error("SavedConfig: cannot synchronise parent directory")


def _saved_atomic_write(path: String, content: String) raises:
    if len(content.bytes()) == 0 or len(content.bytes()) > MAX_SAVED_BYTES:
        raise Error("SavedConfig: serialised record has an invalid size")
    var target = _saved_cstring(path)
    var staged = _saved_cstring(path + ".tmp.XXXXXX")
    var fd = external_call["mkstemp", Int32](staged.unsafe_ptr())
    if fd < 0:
        raise Error("SavedConfig: cannot create the staged file")
    try:
        _saved_write_all(fd, content)
        if external_call["fsync", Int32](fd) != 0:
            raise Error("SavedConfig: cannot synchronise the staged file")
    except error:
        _ = external_call["close", Int32](fd)
        _ = external_call["unlink", Int32](staged.unsafe_ptr())
        raise error
    if external_call["close", Int32](fd) != 0:
        _ = external_call["unlink", Int32](staged.unsafe_ptr())
        raise Error("SavedConfig: cannot close the staged file")
    if external_call["rename", Int32](staged.unsafe_ptr(), target.unsafe_ptr()) != 0:
        _ = external_call["unlink", Int32](staged.unsafe_ptr())
        raise Error("SavedConfig: cannot atomically replace the saved file")
    _saved_sync_parent(path)


def _saved_read(path: String) raises -> Tuple[Int, String]:
    """Read the saved file: (0, text) on success, (1, "") when
    the file does not exist, (2, reason) for every other
    failure. The loader maps 1 to MISSING and 2 to REFUSED."""
    var encoded_path = _saved_cstring(path)
    var fd = external_call["open64", Int32](
        encoded_path.unsafe_ptr(), Int32(657408), Int32(0)
    )
    if fd < 0:
        var errno_ptr = external_call[
            "__errno_location", Pointer[Int32, MutUntrackedOrigin]
        ]()
        if errno_ptr.unsafe_load() == 2:
            return (1, String(""))
        return (2, String("the saved file could not be opened"))
    var stat = InlineArray[UInt64, 18](fill=0)
    if external_call["fstat", Int32](fd, stat.unsafe_ptr()) != 0:
        _ = external_call["close", Int32](fd)
        return (2, String("the saved file could not be inspected"))
    if stat[3] & 61440 != 32768:
        _ = external_call["close", Int32](fd)
        return (2, String("the saved path is not a regular file"))
    if stat[6] == 0:
        _ = external_call["close", Int32](fd)
        return (
            2,
            String("the saved file is empty (truncated or never written)"),
        )
    if stat[6] > UInt64(MAX_SAVED_BYTES):
        _ = external_call["close", Int32](fd)
        return (2, String("the saved file exceeds the size cap"))
    var pinned_size = stat[6]
    var buffer = List[Byte]()
    buffer.resize(MAX_SAVED_BYTES + 1, 0)
    var size = 0
    while True:
        var count = external_call["pread", Int](
            fd, buffer.unsafe_ptr().unsafe_offset(size),
            MAX_SAVED_BYTES + 1 - size, Int64(size),
        )
        if count < 0:
            var errno_ptr = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_ptr.unsafe_load() == 4:
                continue
            _ = external_call["close", Int32](fd)
            return (2, String("the saved file read failed"))
        if count == 0:
            break
        size += count
        if size > MAX_SAVED_BYTES:
            _ = external_call["close", Int32](fd)
            return (2, String("the saved file exceeds the size cap"))
    if UInt64(size) != pinned_size:
        _ = external_call["close", Int32](fd)
        return (2, String("the saved file changed size during the read"))
    if external_call["close", Int32](fd) != 0:
        return (2, String("the saved file close failed"))
    var content = List[Byte]()
    for index in range(size):
        content.append(buffer[index])
    try:
        var text = admit_text_bytes(content, "saved file", MAX_SAVED_BYTES)
        return (0, text)
    except error:
        return (2, String("the saved file is not valid text: ") + String(error))


# --- the disk surface ------------------------------------------------------


def load_saved_config(path: String) -> SavedLoad:
    """Load the saved record. Never raises: a missing file is
    the clean MISSING state, a corrupt/truncated/unreadable
    file is the clean REFUSED state with its reason, and only
    a whole, checksum-verified, fully validated record is
    LOADED."""
    var load = SavedLoad()
    load.path = path
    var read: Tuple[Int, String]
    try:
        read = _saved_read(path)
    except error:
        load.status = SAVED_REFUSED
        load.reason = String(error)
        return load^
    if read[0] == 1:
        load.status = SAVED_MISSING
        load.reason = String("no saved configuration at this path")
        return load^
    if read[0] == 2:
        load.status = SAVED_REFUSED
        load.reason = read[1]
        return load^
    try:
        load.config = parse_saved_config(read[1])
        load.status = SAVED_LOADED
        load.reason = String("loaded whole and verified")
    except error:
        load.status = SAVED_REFUSED
        load.reason = String(error)
        load.config = SavedConfig()
    return load^


def save_saved_config(path: String, config: SavedConfig) raises:
    """Write the saved record atomically. Serialisation
    validates first, so an invalid or empty configuration
    never reaches disk; parent directories are created (the
    cache home's first save)."""
    var text = serialize_saved_config(config)
    _ensure_parent_dirs(path)
    _saved_atomic_write(path, text)


def store_saved_config(path: String, config: SavedConfig) raises:
    """Save over whatever state the path holds, EXCEPT a
    REFUSED (corrupt) file: storing must never silently
    overwrite corruption; erase the file explicitly first."""
    var load = load_saved_config(path)
    if load.status == SAVED_REFUSED:
        raise Error(
            "SavedConfig: refusing to store into a corrupt saved"
            " file ("
            + load.reason
            + "); erase it explicitly first"
        )
    save_saved_config(path, config)


struct SavedEraseResult(Copyable, ImplicitlyCopyable):
    """One saved-file erasure's outcome as data: erased, or
    already absent (the clean state, not a failure), or
    failed with the reason. Erasure never raises."""

    var erased: Bool
    var was_present: Bool
    var reason: String

    def __init__(out self):
        self.erased = False
        self.was_present = False
        self.reason = String("not attempted")


def erase_saved_config(path: String) -> SavedEraseResult:
    """Erase the whole saved file -- THIS STORE ONLY. The
    learned file is a different path and is never touched
    here (the separate erase paths of the module header).
    After erasure, a load is the clean MISSING state."""
    var result = SavedEraseResult()
    try:
        var encoded = _saved_cstring(path)
        if external_call["unlink", Int32](encoded.unsafe_ptr()) != 0:
            var errno_ptr = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_ptr.unsafe_load() == 2:
                result.erased = True
                result.was_present = False
                result.reason = String(
                    "no saved configuration was present; already erased"
                )
                return result
            result.reason = String("the saved file could not be unlinked")
            return result
        result.erased = True
        result.was_present = True
        result.reason = String("the saved configuration was erased")
        return result
    except error:
        result.reason = String(error)
        return result


# --- the one story: reconciliation -----------------------------------------


struct FieldResolution(Copyable, ImplicitlyCopyable):
    """One field's reconciliation outcome: the effective text,
    the layer that supplied it (its provenance, in words), and
    a detail sentence. Layers, in the order they win:
    "session hand", "saved hand", "preset", "learned",
    "auto", "none"."""

    var layer: String
    var text: String
    var detail: String

    def __init__(out self):
        self.layer = String("none")
        self.text = String("-")
        self.detail = String("not resolved")


def _learned_choice_text(lookup: LookupResult, pass_kind: Int) -> Tuple[Bool, String]:
    """The learned side of one kind, as (states anything, text).

    Only an APPLIED lookup whose entry holds a choice for the
    kind states anything; every other outcome states nothing
    and the caller names the outcome instead."""
    if lookup.status != LOOKUP_APPLIED:
        return (False, String("-"))
    var choice = lookup.entry.pass_choice(pass_kind)
    if not choice.present:
        return (False, String("-"))
    return (
        True,
        choice.placement_text
        + " (from option "
        + choice.option_text
        + ", decision "
        + choice.decision
        + ")",
    )


def resolve_kind_story(
    pass_kind: Int,
    session_text: String,
    session_set: Bool,
    saved: SavedLoad,
    preset_text: String,
    lookup: LookupResult,
) -> FieldResolution:
    """Resolve one placement kind through the one-story order
    (module header): session hand > saved hand > preset >
    learned > auto. preset_text is the preset's fixed label
    for the kind, or "" where the preset does not fix it (a
    measurement-directive preset like max fixes nothing and
    is reported through the auto layer's detail by the
    caller-facing report, not smuggled in here)."""
    var resolution = FieldResolution()
    var kind_name = pass_name(pass_kind)
    if session_set:
        resolution.layer = String("session hand")
        resolution.text = session_text
        resolution.detail = (
            "this session's explicit "
            + kind_name
            + " option is the freshest hand statement and governs"
        )
        return resolution
    if saved.status == SAVED_LOADED:
        var stated = saved.config.placement(pass_kind)
        if stated[0]:
            resolution.layer = String("saved hand")
            resolution.text = stated[1]
            resolution.detail = (
                "the saved configuration states the "
                + kind_name
                + " placement; a persisted hand statement governs"
                " over preset and learned (J-047's hand layer)"
            )
            return resolution
    if preset_text.byte_length() > 0:
        resolution.layer = String("preset")
        resolution.text = preset_text
        resolution.detail = (
            "the session's --mode preset fixes the "
            + kind_name
            + " placement and no hand layer states it"
        )
        return resolution
    var learned = _learned_choice_text(lookup, pass_kind)
    if learned[0]:
        resolution.layer = String("learned")
        resolution.text = learned[1]
        resolution.detail = (
            "the learned choice for this exact machine+model key"
            " supplies the "
            + kind_name
            + " default; a learned value is a default only"
        )
        return resolution
    resolution.layer = String("auto")
    resolution.text = String("auto")
    resolution.detail = (
        "no layer states the "
        + kind_name
        + " placement; the session measures or defaults at open"
    )
    return resolution


def _learned_draft_text(lookup: LookupResult) -> Tuple[Bool, String]:
    if lookup.status != LOOKUP_APPLIED:
        return (False, String("-"))
    var entry = lookup.entry.copy()
    if not entry.draft_present:
        return (False, String("-"))
    return (
        True,
        "source "
        + learned_draft_source_name(entry.draft_source)
        + ", mtp "
        + learned_draft_mtp_name(entry.draft_mtp)
        + ", model "
        + entry.draft_model
        + ", k "
        + String(entry.draft_k),
    )


def resolve_draft_story(
    session_text: String,
    session_set: Bool,
    saved: SavedLoad,
    lookup: LookupResult,
) -> FieldResolution:
    """Resolve the draft field: session draft configuration >
    saved draft statement > the learned entry's draft section
    (exact key) > no draft configuration. Intent and
    provenance only -- use still stands at J-083's gate."""
    var resolution = FieldResolution()
    if session_set:
        resolution.layer = String("session hand")
        resolution.text = session_text
        resolution.detail = (
            "this session's draft configuration is the freshest"
            " hand statement and governs"
        )
        return resolution
    if saved.status == SAVED_LOADED and saved.config.draft_present:
        resolution.layer = String("saved hand")
        resolution.text = saved.config.draft_render()
        resolution.detail = (
            "the saved configuration states the draft settings;"
            " a persisted hand statement governs over the"
            " learned draft section"
        )
        return resolution
    var learned = _learned_draft_text(lookup)
    if learned[0]:
        resolution.layer = String("learned")
        resolution.text = learned[1]
        resolution.detail = (
            "the learned entry for this exact key carries the"
            " draft configuration (J-083's section)"
        )
        return resolution
    resolution.layer = String("none")
    resolution.text = String("no draft configuration")
    resolution.detail = String(
        "no layer states draft settings; drafts are unconfigured"
    )
    return resolution


def resolve_cap_story(saved: SavedLoad) -> FieldResolution:
    """Resolve the cache cap: the saved config is the only
    store that owns this field."""
    var resolution = FieldResolution()
    if saved.status == SAVED_LOADED and saved.config.cache_cap_present:
        resolution.layer = String("saved hand")
        resolution.text = String(saved.config.cache_cap_bytes) + " bytes"
        resolution.detail = (
            "the saved configuration states the expert-cache cap;"
            " no other store owns this field"
        )
        return resolution
    resolution.layer = String("none")
    resolution.text = String("unset")
    resolution.detail = (
        "no saved cap; the cap is whatever the session's"
        " --expert-cache-bytes / AESIR_EXPERT_CACHE_BYTES state,"
        " or unset (J-018)"
    )
    return resolution


def _layer_line(label: String, resolution: FieldResolution) -> String:
    return (
        "  "
        + label
        + ": effective '"
        + resolution.text
        + "' ["
        + resolution.layer
        + "] -- "
        + resolution.detail
        + "\n"
    )


def config_story_report(
    saved: SavedLoad,
    learned: LearnedLoad,
    lookup: LookupResult,
    session_texts: List[String],
    session_set: List[Bool],
    preset_texts: List[String],
    session_draft_text: String,
    session_draft_set: Bool,
) -> String:
    """The one-story report: both stores' states, then every
    field resolved with its provenance. session_texts /
    session_set / preset_texts are indexed by pass kind
    (prompt, drafts, reply). A REFUSED store is reported as
    refused with its reason and never participates; a
    non-APPLIED lookup is named by its outcome, never
    silently read as "nothing learned"."""
    var out_str = String("saved configuration -- one story\n")
    out_str += "saved store: " + saved.path + " -- state "
    out_str += saved_load_status_name(saved.status)
    if saved.status == SAVED_LOADED:
        out_str += " (saved-at " + String(saved.config.saved_at) + ")\n"
    elif saved.status == SAVED_REFUSED:
        out_str += " -- REFUSED: " + saved.reason + "\n"
    else:
        out_str += " -- no saved configuration\n"
    out_str += "learned store: " + learned.path + " -- state "
    out_str += load_status_name(learned.status)
    if learned.status == LOAD_REFUSED:
        out_str += " -- REFUSED: " + learned.reason
    out_str += (
        "; lookup for this key: " + lookup_status_name(lookup.status)
        + " -- " + lookup.reason + "\n"
    )
    for kind in [PASS_PROMPT, PASS_DRAFTS, PASS_REPLY]:
        var resolution = resolve_kind_story(
            kind,
            session_texts[kind],
            session_set[kind],
            saved,
            preset_texts[kind],
            lookup,
        )
        out_str += _layer_line("placement " + pass_name(kind), resolution)
    out_str += _layer_line(
        "draft settings",
        resolve_draft_story(
            session_draft_text, session_draft_set, saved, lookup
        ),
    )
    out_str += _layer_line("cache cap", resolve_cap_story(saved))
    out_str += (
        "hand supremacy: a hand statement is never argued with;"
        " within the hand layer the fresher statement (this"
        " session's) governs over the persisted one, and any"
        " hand statement governs over preset, learned, and auto\n"
    )
    out_str += (
        "learned values are defaults only: they supply what a"
        " session would otherwise have to measure, for exactly"
        " the key they were measured under\n"
    )
    out_str += (
        "erasure: the saved configuration and the learned file"
        " have separate erase paths -- erasing one never touches"
        " the other\n"
    )
    out_str += (
        "expert maps: none -- neither store holds one (J-027"
        " measured rejection)\n"
    )
    return out_str


# --- the command family ------------------------------------------------------

comptime CONFIG_ACTION_SHOW = 0
comptime CONFIG_ACTION_SET = 1
comptime CONFIG_ACTION_CLEAR = 2
comptime CONFIG_ACTION_ERASE = 3
comptime CONFIG_ACTION_HELP = 4


struct ConfigCommand(Copyable, ImplicitlyCopyable):
    """One parsed /save-config command. field/value are
    meaningful for SET and CLEAR only."""

    var action: Int
    var field: String
    var value: String

    def __init__(out self):
        self.action = CONFIG_ACTION_SHOW
        self.field = String("")
        self.value = String("")


def config_command_usage() -> String:
    return String(
        "/save-config -- show the saved configuration and the"
        " learned file as one story\n"
        "/save-config <field> <value> -- state one field and save"
        " it (fields: "
        + saved_field_names()
        + ")\n"
        "/save-config clear <field> -- unstate one field and save\n"
        "/save-config erase -- erase the saved configuration only"
        " (the learned file is untouched)\n"
        "values: placement fields take a J-036 placement value"
        " (auto, a device, a+b, a,b list); draft-source takes"
        " mtp-head | draft-model | none; draft-mtp takes on | off"
        " | unset; draft-model takes a file name or -; draft-k"
        " takes an unsigned decimal in the band 1..15; cache-cap"
        " takes a byte size (plain bytes or a K/M/G suffix)"
    )


def _config_command_refusal(what: String) -> String:
    return String(
        "SavedConfig: /save-config "
        + what
        + " (usage: /save-config [help | erase | clear <field> |"
        " <field> <value>]; fields: "
        + saved_field_names()
        + ")"
    )


def parse_config_command(command: String) raises -> ConfigCommand:
    """Parse one /save-config command, purely. Refusals name
    the fault; unknown fields and actions are refused, never
    reinterpreted."""
    var parsed = ConfigCommand()
    if command == "/save-config":
        return parsed
    if not command.startswith("/save-config "):
        raise Error(_config_command_refusal("is not a /save-config command"))
    var rest = String(command[byte=13:])
    var tokens = List[String]()
    for raw in rest.split(" "):
        var token = String(raw)
        if token.byte_length() > 0:
            tokens.append(token)
    if len(tokens) == 1 and tokens[0] == "help":
        parsed.action = CONFIG_ACTION_HELP
        return parsed
    if len(tokens) == 1 and tokens[0] == "erase":
        parsed.action = CONFIG_ACTION_ERASE
        return parsed
    if len(tokens) == 2 and tokens[0] == "clear":
        if not field_known(tokens[1]):
            raise Error(
                _config_command_refusal(
                    "clear names unknown field '" + tokens[1] + "'"
                )
            )
        parsed.action = CONFIG_ACTION_CLEAR
        parsed.field = tokens[1]
        return parsed
    if len(tokens) == 2 and tokens[0] != "clear":
        if not field_known(tokens[0]):
            raise Error(
                _config_command_refusal(
                    "names unknown field '" + tokens[0] + "'"
                )
            )
        parsed.action = CONFIG_ACTION_SET
        parsed.field = tokens[0]
        parsed.value = tokens[1]
        return parsed
    raise Error(
        _config_command_refusal(
            "has the wrong shape (" + String(len(tokens)) + " tokens)"
        )
    )


def _draft_source_from_name(name: String) raises -> Int:
    if name == "mtp-head":
        return LEARNED_DRAFT_SOURCE_MTP_HEAD
    if name == "draft-model":
        return LEARNED_DRAFT_SOURCE_DRAFT_MODEL
    if name == "none":
        return LEARNED_DRAFT_SOURCE_NONE
    raise Error(
        "SavedConfig: draft-source '"
        + name
        + "' is not a draft source (mtp-head | draft-model | none)"
    )


def _draft_mtp_from_name(name: String) raises -> Int:
    if name == "on":
        return LEARNED_DRAFT_MTP_ON
    if name == "off":
        return LEARNED_DRAFT_MTP_OFF
    if name == "unset":
        return LEARNED_DRAFT_MTP_UNSET
    raise Error(
        "SavedConfig: draft-mtp '"
        + name
        + "' is not an mtp state (on | off | unset)"
    )


def _refresh_draft_present(mut config: SavedConfig):
    config.draft_present = (
        config.draft_source != LEARNED_DRAFT_SOURCE_NONE
        or config.draft_mtp != LEARNED_DRAFT_MTP_UNSET
        or config.draft_model != "-"
        or config.draft_k != 0
    )


def apply_config_set(
    config: SavedConfig, field: String, value: String, saved_at: Int64
) raises -> SavedConfig:
    """State one field on a copy of `config` and validate the
    assembled whole. On any refusal the copy dies with the
    raise and the caller's record is untouched -- nothing is
    written by a refused command. The draft fields follow
    J-083's readings (module header)."""
    var out_config = config.copy()
    var kind = field_pass_kind(field)
    if kind >= 0:
        var parsed = parse_placement_value(value, kind)
        var canonical = parsed.describe()
        if kind == PASS_PROMPT:
            out_config.prompt_on_present = True
            out_config.prompt_on = canonical
        elif kind == PASS_DRAFTS:
            out_config.drafts_on_present = True
            out_config.drafts_on = canonical
        else:
            out_config.reply_on_present = True
            out_config.reply_on = canonical
    elif field == FIELD_DRAFT_SOURCE:
        var source = _draft_source_from_name(value)
        out_config.draft_source = source
        if source == LEARNED_DRAFT_SOURCE_MTP_HEAD:
            # J-083's reading: --mtp selects the head and
            # records mtp on; the pair is one statement.
            out_config.draft_mtp = LEARNED_DRAFT_MTP_ON
            out_config.draft_model = String("-")
        _refresh_draft_present(out_config)
    elif field == FIELD_DRAFT_MTP:
        var mtp = _draft_mtp_from_name(value)
        if (
            mtp == LEARNED_DRAFT_MTP_ON
            and out_config.draft_source == LEARNED_DRAFT_SOURCE_NONE
        ):
            # J-083's reading: mtp on with no source selects
            # the head source, the only source mtp can mean.
            out_config.draft_source = LEARNED_DRAFT_SOURCE_MTP_HEAD
            out_config.draft_model = String("-")
        out_config.draft_mtp = mtp
        _refresh_draft_present(out_config)
    elif field == FIELD_DRAFT_MODEL:
        _check_printable(value, "draft model", 512)
        if (
            value != "-"
            and out_config.draft_source == LEARNED_DRAFT_SOURCE_NONE
        ):
            # J-083's reading: a named draft file with no
            # source stated selects the draft-model source.
            out_config.draft_source = LEARNED_DRAFT_SOURCE_DRAFT_MODEL
        out_config.draft_model = value
        _refresh_draft_present(out_config)
    elif field == FIELD_DRAFT_K:
        var k = _parse_nonnegative(value, "draft-k")
        if k < 1:
            raise Error(
                "SavedConfig: draft-k 0 states no draft length"
                " (the band starts at 1); clear the field to"
                " unstate it"
            )
        out_config.draft_k = k
        _refresh_draft_present(out_config)
    elif field == FIELD_CACHE_CAP:
        var cap = parse_byte_size(value)
        if cap == 0:
            raise Error(
                "SavedConfig: cache-cap 0 states no cap (0 is the"
                " unset sentinel); clear the field to state no cap"
            )
        out_config.cache_cap_present = True
        out_config.cache_cap_bytes = cap
    else:
        raise Error(_config_command_refusal("names unknown field '" + field + "'"))
    if out_config.draft_present and out_config.draft_k == 0:
        # A draft statement stated without a k takes J-072's
        # initial draft length, exactly as J-083's resolved
        # configuration defaults (LOOP_K_INITIAL): the band
        # 1..15 admits no 0, and a source stated alone must
        # not be refused for a field the user never mentioned.
        out_config.draft_k = LOOP_K_INITIAL
    out_config.saved_at = saved_at
    try:
        out_config.validate()
    except error:
        raise Error(
            "SavedConfig: stating "
            + field
            + " '"
            + value
            + "' leaves the configuration invalid: "
            + String(error)
        )
    return out_config


def apply_config_clear(
    config: SavedConfig, field: String, saved_at: Int64
) raises -> SavedConfig:
    """Unstate one field on a copy of `config` and validate
    the assembled whole. Refusals: the field is not stated;
    unstating it would leave an invalid assembled draft
    statement (the reason names the honest road); unstating
    it would empty the configuration (erase instead)."""
    var out_config = config.copy()
    var kind = field_pass_kind(field)
    if kind >= 0:
        var stated = out_config.placement(kind)
        if not stated[0]:
            raise Error(
                "SavedConfig: cannot clear " + field
                + " -- it is not stated"
            )
        if kind == PASS_PROMPT:
            out_config.prompt_on_present = False
            out_config.prompt_on = String("-")
        elif kind == PASS_DRAFTS:
            out_config.drafts_on_present = False
            out_config.drafts_on = String("-")
        else:
            out_config.reply_on_present = False
            out_config.reply_on = String("-")
    elif field == FIELD_DRAFT_SOURCE:
        if not out_config.draft_present:
            raise Error(
                "SavedConfig: cannot clear draft-source -- no"
                " draft statement is stated"
            )
        out_config.draft_source = LEARNED_DRAFT_SOURCE_NONE
        out_config.draft_mtp = LEARNED_DRAFT_MTP_UNSET
        out_config.draft_model = String("-")
        out_config.draft_k = 0
        out_config.draft_present = False
    elif field == FIELD_DRAFT_MTP:
        if not out_config.draft_present or (
            out_config.draft_mtp == LEARNED_DRAFT_MTP_UNSET
        ):
            raise Error(
                "SavedConfig: cannot clear draft-mtp -- it is not"
                " stated"
            )
        out_config.draft_mtp = LEARNED_DRAFT_MTP_UNSET
        _refresh_draft_present(out_config)
    elif field == FIELD_DRAFT_MODEL:
        if not out_config.draft_present or out_config.draft_model == "-":
            raise Error(
                "SavedConfig: cannot clear draft-model -- it is"
                " not stated"
            )
        out_config.draft_model = String("-")
        _refresh_draft_present(out_config)
    elif field == FIELD_DRAFT_K:
        if not out_config.draft_present or out_config.draft_k == 0:
            raise Error(
                "SavedConfig: cannot clear draft-k -- it is not stated"
            )
        # Clearing k resets it to J-072's initial draft length
        # (the statement's default), it does not unstate the
        # draft statement -- unstating the statement whole is
        # clearing draft-source.
        out_config.draft_k = LOOP_K_INITIAL
        _refresh_draft_present(out_config)
    elif field == FIELD_CACHE_CAP:
        if not out_config.cache_cap_present:
            raise Error(
                "SavedConfig: cannot clear cache-cap -- it is not stated"
            )
        out_config.cache_cap_present = False
        out_config.cache_cap_bytes = 0
    else:
        raise Error(_config_command_refusal("names unknown field '" + field + "'"))
    if not out_config.has_any():
        raise Error(
            "SavedConfig: clearing "
            + field
            + " would leave an empty configuration, which is"
            " never saved -- erase the saved configuration"
            " instead (/save-config erase)"
        )
    out_config.saved_at = saved_at
    try:
        out_config.validate()
    except error:
        raise Error(
            "SavedConfig: clearing "
            + field
            + " leaves the configuration invalid: "
            + String(error)
            + " (unstating a whole draft statement is done by"
            " clearing draft-source)"
        )
    return out_config


def saved_config_command_response(command: String) raises -> String:
    """The chat host's one call: parse the command, execute it
    against this process's saved-config path (with the learned
    file read beside it, read-only, for the show form), and
    return the text to emit. Raises with the refusal's reason;
    a refused command writes nothing."""
    var parsed = parse_config_command(command)
    if parsed.action == CONFIG_ACTION_HELP:
        return config_command_usage()
    var path = saved_config_path()
    if parsed.action == CONFIG_ACTION_SHOW:
        var saved = load_saved_config(path)
        var learned = load_learned_file(learned_file_path())
        var out_str = String("[saved configuration -- one story]\n")
        out_str += saved.report()
        out_str += learned.report()
        out_str += (
            "one story: the saved configuration holds what you"
            " stated (a hand statement); the learned file holds"
            " what the machine measured (a default only, per"
            " exact machine+model key). Per field, the governing"
            " layer is: this session's explicit option, then the"
            " saved statement, then a --mode preset, then the"
            " learned choice, then auto. The cache cap is owned"
            " by the saved configuration alone. Erasing one store"
            " never touches the other.\n"
        )
        return out_str
    if parsed.action == CONFIG_ACTION_ERASE:
        var erased = erase_saved_config(path)
        return (
            "[saved configuration erased: "
            + erased.reason
            + " -- the learned file is untouched]"
        )
    var load = load_saved_config(path)
    if load.status == SAVED_REFUSED:
        raise Error(
            "SavedConfig: the saved file at "
            + path
            + " is refused ("
            + load.reason
            + "); erase it explicitly first (/save-config erase)"
        )
    var stamp = learned_now_seconds()
    var updated: SavedConfig
    if parsed.action == CONFIG_ACTION_SET:
        updated = apply_config_set(load.config, parsed.field, parsed.value, stamp)
    else:
        updated = apply_config_clear(load.config, parsed.field, stamp)
    save_saved_config(path, updated)
    var verb = String("stated") if parsed.action == CONFIG_ACTION_SET else String("cleared")
    return (
        "[saved configuration: "
        + parsed.field
        + " "
        + verb
        + "; saved to "
        + path
        + "]\n"
        + updated.render()
    )
