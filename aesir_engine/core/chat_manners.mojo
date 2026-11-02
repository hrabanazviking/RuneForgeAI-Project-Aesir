"""Chat manners: the behavioural rules of the chat surface,
as one pure, tested layer (Janas road J-105).

The roadmap text: "Chat: manners. Ctrl-C stops a reply and
nothing else; Ctrl-D leaves; the engine writes only where it
is told (its cache home + chosen outputs); model files are
never modified -- each manner a tested behaviour." J-099's
census (row T06) named the rest of this slice's delta:
unknown commands/options are refused by name but carry no
nearest-match suggestion, and a near-miss AESIR_* env var is
silently never read, with no reporting at start.

THE FOUR MANNERS, AS DECISIONS. This module owns no session
and fakes none; it turns the facts a host already has into
the decision the manners require, and the hosts execute the
decisions.

M1 -- Ctrl-C stops a reply and nothing else. The reader
(cli/interrupts.mojo) already keeps its outcomes distinct:
an interrupted read, an EOF, and a line of text are three
different facts. What conflated them was the main prompt,
which read through the text-only compatibility wrapper and
treated the empty string -- interruption and EOF alike --
as session end, so Ctrl-C at the prompt LEFT the chat with
nothing to stop. classify_prompt_line is the fix's rule: an
interrupted read is LINE_REPROMPT (the reader has already
discarded the partial line; the session re-prompts and
nothing else happens). During a reply, the interrupt's one
job is the session's own cancellation (finish reason
"cancelled", core/generation_control.mojo); post_turn_action
states what remains: an interrupt that cancelled the reply
is spent (POST_TURN_STAY), an interrupt that arrived after
the reply finished had nothing to stop and is drained with
a note (POST_TURN_STAY_NOTED) -- an interrupt alone never
ends an interactive session. The scripted from-file prompt
mode is out of this rule's scope by design (doc section 8):
a batch has no session to preserve, and its break-on-
interrupt stands.

M2 -- Ctrl-D leaves. Bare EOF is LINE_LEAVE; a final
unterminated line at EOF is LINE_SUBMIT_FINAL (submitted
once; the next read leaves). A blank line also leaves --
the surface's pre-existing stated behaviour ("Blank input/
EOF ends the session"), kept unchanged; /bye leaves, as
before.

M3 -- the engine writes only where it is told.
classify_write_destination grades a destination against the
cache home, the roots the user chose (a transcript path, a
/save or /export target, the autosave directory, the model
store, a checkpoint directory), and the model files: cache
and chosen destinations are allowed, anything else is a
stray write, refused by the rule. Prefix matching is
path-segment exact (/cache2 is not under /cache) and an
empty root matches nothing. The doc's census (J-105
section 3) grades every file-mutating site in the tree
against this classifier; the classifier is the tested rule
the census stands on.

M4 -- model files are never modified. The classifier checks
the model files FIRST, before the cache allowance: a model
file that happens to live under the cache home is still
never a write target. The construction agrees: the GGUF
loader opens O_RDONLY and maps PROT_READ
(loader/gguf.mojo), and the streaming reader preads from a
read-only descriptor (core/stream_reader.mojo).

SUGGESTIONS (T06). Refusal-by-name gains a nearest match:
edit_distance (Levenshtein over bytes; every vocabulary
here is ASCII) and suggest_match (nearest candidate within
distance 2 and strictly inside the typed length; first in
candidate order on ties; an exact match or an empty typed
string suggests nothing). A suggestion is an addition to a
refusal, never a change to what is refused, and a suggested
name is never executed. The candidate sets mirror their
surfaces exactly -- the CLI's top-level commands, the
chat's slash names, the chat option flags -- and the
slice's inspect pins each set against its surface.

ENV-TYPO REPORTING (T06). Every AESIR_* variable is read by
an exact-name getenv, so a misspelt name is silently never
read and the setting it meant to carry is dropped without a
word. audit_env_name reports a present name only when it
starts with AESIR_, is not itself known, and sits within
suggestion distance of a known name; a stranger AESIR_* name
near nothing known is not reported (it may be the user's
own extension -- the manner reports likely typos, not
strangers), and a correctly spelt name is never reported.
The known set is the tree's env-read census (21 names read
by literal call sites in core/cli/server/loader) plus three
further documented names (AESIR_EXPERT_CACHE_BYTES,
AESIR_DENSE_LAYER_CACHE_BYTES, AESIR_PREFILL_BATCH). Two of
the three have no read site anywhere in the tree today, so
a user setting one is silently ignored -- the same harm, so
a near miss of one is reported too. The third,
AESIR_PREFILL_BATCH, IS read, in aesir.mojo (the engine's
root module, outside the census directories): it belongs in
the known set as a read name, and the doc records this
correction in J-105 section 7. env_manner_warnings is this module's one
impure function, in the tree's pattern: it reads
/proc/self/environ and returns one warning line per near
miss; an unreadable environ yields no warnings and no
error -- the audit is a manner, not a gate.

HOST CONTRACT. cli/cuda_chat.mojo's interactive loops read
with read_interruptible_line_result and act on
classify_prompt_line + post_turn_action; its two
chat_control bodies and cli/commands.mojo add
suggestion_suffix(suggest_*(typed)) to their unknown-name
refusals; run_cuda_chat prints env_manner_warnings() at
start. Nothing here opens a model, starts a session, or
writes a file.
"""
from std.collections import InlineArray
from std.ffi import external_call
from std.memory import Pointer


# --- M1/M2: the prompt-line decisions ---------------------------------------

comptime LINE_SUBMIT = 0
comptime LINE_LEAVE = 1
comptime LINE_REPROMPT = 2
comptime LINE_SUBMIT_FINAL = 3

comptime POST_TURN_STAY = 0
comptime POST_TURN_STAY_NOTED = 1


def line_action_name(code: Int) -> String:
    if code == LINE_SUBMIT:
        return String("SUBMIT")
    if code == LINE_LEAVE:
        return String("LEAVE")
    if code == LINE_REPROMPT:
        return String("REPROMPT")
    if code == LINE_SUBMIT_FINAL:
        return String("SUBMIT_FINAL")
    return String("UNKNOWN")


def post_turn_action_name(code: Int) -> String:
    if code == POST_TURN_STAY:
        return String("STAY")
    if code == POST_TURN_STAY_NOTED:
        return String("STAY_NOTED")
    return String("UNKNOWN")


def classify_prompt_line(interrupted: Bool, eof: Bool, text: String) -> Int:
    """The manner decision for one prompt read (M1 + M2).

    interrupted wins over every other fact: Ctrl-C at the
    prompt re-prompts and does nothing else, whatever partial
    text the read carried. Bare EOF leaves (Ctrl-D); an
    unterminated final line at EOF is submitted once. A blank
    line and /bye leave, the surface's pre-existing stated
    behaviours, kept unchanged.
    """
    if interrupted:
        return LINE_REPROMPT
    if text == "/bye":
        return LINE_LEAVE
    if eof:
        if text.byte_length() == 0:
            return LINE_LEAVE
        return LINE_SUBMIT_FINAL
    if text.byte_length() == 0:
        return LINE_LEAVE
    return LINE_SUBMIT


def post_turn_action(interrupt_pending: Bool, finish_reason: String) -> Int:
    """What an interactive session does after a turn (M1).

    No pending interrupt: stay, silently. A pending interrupt
    whose turn finished "cancelled" did its one job -- it
    stopped that reply -- and is spent: stay, silently. A
    pending interrupt whose reply finished on its own had
    nothing to stop: stay, with a note. An interrupt alone
    never ends the session.
    """
    if not interrupt_pending:
        return POST_TURN_STAY
    if finish_reason == "cancelled":
        return POST_TURN_STAY
    return POST_TURN_STAY_NOTED


# --- suggestions (T06) -------------------------------------------------------


def edit_distance(a: String, b: String) -> Int:
    """Levenshtein distance over bytes (ASCII vocabularies)."""
    var a_bytes = a.as_bytes()
    var b_bytes = b.as_bytes()
    var n = len(a_bytes)
    var m = len(b_bytes)
    if n == 0:
        return m
    if m == 0:
        return n
    var previous = List[Int]()
    var current = List[Int]()
    for j in range(m + 1):
        previous.append(j)
        current.append(0)
    for i in range(1, n + 1):
        current[0] = i
        for j in range(1, m + 1):
            var cost = 0 if a_bytes[i - 1] == b_bytes[j - 1] else 1
            var deletion = previous[j] + 1
            var insertion = current[j - 1] + 1
            var substitution = previous[j - 1] + cost
            var best = deletion
            if insertion < best:
                best = insertion
            if substitution < best:
                best = substitution
            current[j] = best
        for j in range(m + 1):
            previous[j] = current[j]
    return previous[m]


def suggest_match(typed: String, candidates: List[String]) -> String:
    """The nearest candidate typed most likely meant, or "".

    A candidate qualifies at distance <= 2 and strictly
    inside the typed length (a 1-2 character typed string
    suggests nothing: too little evidence). Nearest wins;
    ties keep the earliest candidate. An exact match
    suggests nothing.
    """
    if typed.byte_length() < 3:
        return String("")
    var best = String("")
    var best_distance = 3
    for i in range(len(candidates)):
        var candidate = candidates[i]
        if candidate == typed:
            return String("")
        var distance = edit_distance(typed, candidate)
        if distance < best_distance:
            best_distance = distance
            best = candidate
    if best_distance <= 2:
        return best
    return String("")


def suggestion_suffix(suggestion: String) -> String:
    """The refusal suffix for a suggestion ("" when none)."""
    if suggestion.byte_length() == 0:
        return String("")
    return String("; did you mean '") + suggestion + String("'?")


def cli_command_names() -> List[String]:
    """The CLI's top-level command names, in dispatch order:
    cli/commands.mojo's dispatch_command chain plus the
    catalog and preference predicates it routes through.
    Pinned against that surface by the slice's inspect."""
    var names = List[String]()
    names.append(String("help"))
    names.append(String("pull"))
    names.append(String("get"))
    names.append(String("inspect"))
    names.append(String("vision"))
    names.append(String("doctor"))
    names.append(String("keygen"))
    names.append(String("chat"))
    names.append(String("serve"))
    names.append(String("ps"))
    names.append(String("stop"))
    names.append(String("hardware"))
    names.append(String("compute"))
    names.append(String("bench"))
    names.append(String("config"))
    names.append(String("run"))
    names.append(String("daemon"))
    names.append(String("push"))
    names.append(String("swarm"))
    names.append(String("llama-cli"))
    names.append(String("llama-server"))
    names.append(String("llama-bench"))
    names.append(String("exl2"))
    names.append(String("onnx"))
    names.append(String("list"))
    names.append(String("ls"))
    names.append(String("show"))
    names.append(String("create"))
    names.append(String("verify"))
    names.append(String("catalog"))
    names.append(String("gc"))
    names.append(String("cp"))
    names.append(String("rm"))
    names.append(String("delete"))
    names.append(String("repair-preferences"))
    names.append(String("aliases"))
    names.append(String("favorites"))
    names.append(String("alias"))
    names.append(String("unalias"))
    names.append(String("favorite"))
    names.append(String("unfavorite"))
    return names^


def chat_command_names() -> List[String]:
    """The chat's slash names: both chat_control bodies'
    branches plus the loop-level /compose, /edit,
    /transcript and /bye. Pinned by the slice's inspect."""
    var names = List[String]()
    names.append(String("/show"))
    names.append(String("/history"))
    names.append(String("/turn"))
    names.append(String("/clear"))
    names.append(String("/new"))
    names.append(String("/help"))
    names.append(String("/services"))
    names.append(String("/constrain"))
    names.append(String("/save-config"))
    names.append(String("/save"))
    names.append(String("/load"))
    names.append(String("/export"))
    names.append(String("/set"))
    names.append(String("/model"))
    names.append(String("/compose"))
    names.append(String("/edit"))
    names.append(String("/transcript"))
    names.append(String("/bye"))
    return names^


def chat_option_names() -> List[String]:
    """The chat option flags: run_cuda_chat's parser
    literals, in parser order. Pinned by the inspect."""
    var names = List[String]()
    names.append(String("--model-store"))
    names.append(String("--profile"))
    names.append(String("--accel"))
    names.append(String("--context"))
    names.append(String("--max-tokens"))
    names.append(String("--system"))
    names.append(String("--prompts"))
    names.append(String("--log"))
    names.append(String("--config"))
    names.append(String("--device"))
    names.append(String("--reserve-mib"))
    names.append(String("--timeout-ms"))
    names.append(String("--autosave-dir"))
    names.append(String("--autosave-retain"))
    names.append(String("--tui"))
    names.append(String("--show-settings"))
    names.append(String("--switch-origin"))
    names.append(String("--resume-log-fd"))
    return names^


def suggest_cli_command(typed: String) -> String:
    return suggest_match(typed, cli_command_names())


def suggest_chat_command(typed: String) -> String:
    return suggest_match(typed, chat_command_names())


def suggest_chat_option(typed: String) -> String:
    return suggest_match(typed, chat_option_names())


def first_word(text: String) -> String:
    """The first space-delimited word of a command line --
    the word a slash refusal names and grades."""
    var word = String("")
    for byte in text.as_bytes():
        if byte == 32:
            break
        word += chr(Int(byte))
    return word


# --- env-typo audit (T06) ----------------------------------------------------


def documented_env_names() -> List[String]:
    """Further documented AESIR_* names beyond the census
    directories' read sites (J-105 doc section 7): two have
    no read site anywhere yet, so a user setting one is
    silently ignored today -- the same harm the audit
    guards; the third (AESIR_PREFILL_BATCH) is read in
    aesir.mojo. Near misses of all three are reported."""
    var names = List[String]()
    names.append(String("AESIR_EXPERT_CACHE_BYTES"))
    names.append(String("AESIR_DENSE_LAYER_CACHE_BYTES"))
    names.append(String("AESIR_PREFILL_BATCH"))
    return names^


def known_env_names() -> List[String]:
    """Every AESIR_* name the tree reads by a literal env
    call site, plus the documented three. Pinned against the
    tree's read-site census by the slice's inspect."""
    var names = List[String]()
    names.append(String("AESIR_CACHE_HOME"))
    names.append(String("AESIR_LEARNED_FILE"))
    names.append(String("AESIR_SAVED_CONFIG_FILE"))
    names.append(String("AESIR_MODE"))
    names.append(String("AESIR_PROMPT_ON"))
    names.append(String("AESIR_DRAFTS_ON"))
    names.append(String("AESIR_REPLY_ON"))
    names.append(String("AESIR_QUALITY"))
    names.append(String("AESIR_HEAD"))
    names.append(String("AESIR_ATTENTION"))
    names.append(String("AESIR_BITS"))
    names.append(String("AESIR_GPU"))
    names.append(String("AESIR_NPU"))
    names.append(String("AESIR_MTP"))
    names.append(String("AESIR_DRAFT_MODEL"))
    names.append(String("AESIR_DRAFT_K"))
    names.append(String("AESIR_KV_PRECISION"))
    names.append(String("AESIR_KV_SCALE"))
    names.append(String("AESIR_THREADS"))
    names.append(String("AESIR_PAR_MIN_WORK"))
    names.append(String("AESIR_VNNI"))
    var documented = documented_env_names()
    for i in range(len(documented)):
        names.append(documented[i])
    return names^


def audit_env_name(name: String) -> String:
    """The known name a present env name most likely meant,
    or "" (not a reportable near miss: correctly spelt, not
    an AESIR_* name, or a stranger near nothing known)."""
    if not name.startswith("AESIR_"):
        return String("")
    var known = known_env_names()
    for i in range(len(known)):
        if known[i] == name:
            return String("")
    return suggest_match(name, known)


def audit_env_names(names: List[String]) -> List[String]:
    """One warning line per near miss in a name list."""
    var warnings = List[String]()
    for i in range(len(names)):
        var meant = audit_env_name(names[i])
        if meant.byte_length() > 0:
            warnings.append(
                String("env manner: ") + names[i]
                + String(" is set but is never read; did you mean ")
                + meant + String("? The setting it carries is ignored.")
            )
    return warnings^


def _environ_names() -> List[String]:
    """The names (before '=') in /proc/self/environ, or an
    empty list when it cannot be read. Non-raising by
    construction: every step is a raw descriptor call whose
    failure is a value, not an exception."""
    var names = List[String]()
    var path = List[Int8]()
    for byte in String("/proc/self/environ").as_bytes():
        path.append(Int8(byte))
    path.append(0)
    var fd = external_call["open64", Int32](path.unsafe_ptr(), Int32(0))
    if fd < 0:
        return names^
    var bytes = List[UInt8]()
    var chunk = InlineArray[UInt8, 4096](fill=0)
    while True:
        var count = external_call["read", Int](
            fd, chunk.unsafe_ptr(), Int(4096)
        )
        if count <= 0:
            break
        for i in range(count):
            bytes.append(chunk[i])
        if len(bytes) > 1048576:
            break
    _ = external_call["close", Int32](fd)
    # NUL-separated NAME=value entries: collect the bytes
    # before each entry's first '='.
    var entry = List[UInt8]()
    var in_value = False
    var entry_has_name = False
    for i in range(len(bytes)):
        var byte = bytes[i]
        if byte == 0:
            if entry_has_name:
                var name = String("")
                for k in range(len(entry)):
                    name += chr(Int(entry[k]))
                if name.byte_length() > 0:
                    names.append(name)
            entry = List[UInt8]()
            in_value = False
            entry_has_name = False
            continue
        if in_value:
            continue
        if byte == 61:
            in_value = True
            entry_has_name = True
            continue
        entry.append(byte)
    if entry_has_name:
        var name = String("")
        for k in range(len(entry)):
            name += chr(Int(entry[k]))
        if name.byte_length() > 0:
            names.append(name)
    return names^


def env_manner_warnings() -> List[String]:
    """The start-of-chat env audit: one warning line per
    near-miss AESIR_* name in this process's environment.
    Never raises: an unreadable environment is no warnings,
    not an error -- the audit is a manner, not a gate."""
    return audit_env_names(_environ_names())


# --- M3/M4: the write discipline ---------------------------------------------


comptime WRITE_ALLOWED_CACHE = 0
comptime WRITE_ALLOWED_CHOSEN = 1
comptime WRITE_REFUSED_MODEL = 2
comptime WRITE_REFUSED_STRAY = 3


def write_destination_name(code: Int) -> String:
    if code == WRITE_ALLOWED_CACHE:
        return String("ALLOWED_CACHE")
    if code == WRITE_ALLOWED_CHOSEN:
        return String("ALLOWED_CHOSEN")
    if code == WRITE_REFUSED_MODEL:
        return String("REFUSED_MODEL")
    if code == WRITE_REFUSED_STRAY:
        return String("REFUSED_STRAY")
    return String("UNKNOWN")


def path_is_under(path: String, root: String) -> Bool:
    """path == root or path under root + '/', segment-exact.
    An empty root matches nothing; a trailing '/' on root is
    ignored."""
    if root.byte_length() == 0:
        return False
    var trimmed = root
    while trimmed.byte_length() > 1 and trimmed.endswith("/"):
        var shortened = String("")
        var bytes = trimmed.as_bytes()
        for i in range(len(bytes) - 1):
            shortened += chr(Int(bytes[i]))
        trimmed = shortened
    if path == trimmed:
        return True
    return path.startswith(trimmed + String("/"))


def classify_write_destination(
    path: String,
    cache_home: String,
    chosen_roots: List[String],
    model_paths: List[String],
) -> Int:
    """The write-discipline verdict for one destination (M3
    + M4). Model files are checked FIRST: a model path is
    refused even when it lives under the cache home (M4
    outranks M3's cache allowance). Then the cache home,
    then the user-chosen roots; anything else is a stray
    write, refused by the rule."""
    for i in range(len(model_paths)):
        if path == model_paths[i]:
            return WRITE_REFUSED_MODEL
    if path_is_under(path, cache_home):
        return WRITE_ALLOWED_CACHE
    for i in range(len(chosen_roots)):
        if path_is_under(path, chosen_roots[i]):
            return WRITE_ALLOWED_CHOSEN
    return WRITE_REFUSED_STRAY
