"""Chat manners (J-105): the pure decision layer of the chat
surface's manners -- the prompt-line decision table (an
interrupted read re-prompts and does nothing else; bare EOF
leaves; a final unterminated line at EOF is submitted once;
blank and /bye keep their pre-existing leave behaviour), the
post-turn table (an interrupt that cancelled a reply is
spent; one that arrived after the reply is drained with a
note; an interrupt alone never ends the session), the
suggestion rules behind refusal-by-name (Levenshtein values,
the distance/length threshold, tie order, exact and empty
typing suggesting nothing, the candidate sets' own
suggestions), the AESIR_* env-typo audit (known names never
reported, near misses reported with the right target --
including the documented three -- strangers not
reported), the write-discipline classifier (cache home and
chosen roots allowed, prefix siblings refused, a model path
refused even inside the cache home), and the environ host
surface's shape (it runs, it finds the standard names, and
every line it returns is an env-manner warning).

No number in this suite is a behaviour of a live session: no
inference ran and no chat was started. The live chat leg is
J-105's deferred leg (doc section 5), re-cited at the J-118
gate.
"""
from core.chat_manners import (
    LINE_LEAVE,
    LINE_REPROMPT,
    LINE_SUBMIT,
    LINE_SUBMIT_FINAL,
    POST_TURN_STAY,
    POST_TURN_STAY_NOTED,
    WRITE_ALLOWED_CACHE,
    WRITE_ALLOWED_CHOSEN,
    WRITE_REFUSED_MODEL,
    WRITE_REFUSED_STRAY,
    audit_env_name,
    audit_env_names,
    chat_command_names,
    chat_option_names,
    classify_prompt_line,
    classify_write_destination,
    cli_command_names,
    documented_env_names,
    edit_distance,
    env_manner_warnings,
    first_word,
    known_env_names,
    line_action_name,
    path_is_under,
    post_turn_action,
    suggest_chat_command,
    suggest_chat_option,
    suggest_cli_command,
    suggest_match,
    suggestion_suffix,
    write_destination_name,
    _environ_names,
)


def expect_eq_int(got: Int, want: Int, what: String) raises:
    if got != want:
        raise Error(
            "ChatManners " + what + ": expected " + String(want)
            + ", got " + String(got)
        )


def expect_eq_str(got: String, want: String, what: String) raises:
    if got != want:
        raise Error(
            "ChatManners " + what + ": expected '" + want
            + "', got '" + got + "'"
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("ChatManners " + what + ": expected true")


def test_prompt_line_decisions() raises:
    # M1: Ctrl-C at the prompt re-prompts, whatever the read
    # carried -- even a partial line, even beside EOF.
    expect_eq_int(
        classify_prompt_line(True, False, ""), LINE_REPROMPT,
        "interrupt, empty",
    )
    expect_eq_int(
        classify_prompt_line(True, False, "half a line"), LINE_REPROMPT,
        "interrupt, partial text discarded",
    )
    expect_eq_int(
        classify_prompt_line(True, True, ""), LINE_REPROMPT,
        "interrupt wins over eof",
    )
    # M2: Ctrl-D leaves; a final unterminated line is
    # submitted once first.
    expect_eq_int(
        classify_prompt_line(False, True, ""), LINE_LEAVE, "bare eof leaves",
    )
    expect_eq_int(
        classify_prompt_line(False, True, "last words"), LINE_SUBMIT_FINAL,
        "eof with text submits final",
    )
    # Pre-existing stated behaviours, kept: blank leaves,
    # /bye leaves, ordinary text submits.
    expect_eq_int(
        classify_prompt_line(False, False, ""), LINE_LEAVE, "blank leaves",
    )
    expect_eq_int(
        classify_prompt_line(False, False, "/bye"), LINE_LEAVE, "/bye leaves",
    )
    expect_eq_int(
        classify_prompt_line(False, True, "/bye"), LINE_LEAVE,
        "/bye at eof still leaves (not a submitted turn)",
    )
    expect_eq_int(
        classify_prompt_line(False, False, "hello"), LINE_SUBMIT,
        "ordinary text submits",
    )
    expect_eq_int(
        classify_prompt_line(False, False, "/help"), LINE_SUBMIT,
        "slash text submits to control",
    )
    expect_eq_str(line_action_name(LINE_REPROMPT), "REPROMPT", "reprompt name")
    expect_eq_str(
        line_action_name(LINE_SUBMIT_FINAL), "SUBMIT_FINAL", "final name",
    )
    expect_eq_str(line_action_name(99), "UNKNOWN", "unknown line code name")


def test_post_turn_decisions() raises:
    expect_eq_int(
        post_turn_action(False, "length"), POST_TURN_STAY,
        "no interrupt, stay",
    )
    expect_eq_int(
        post_turn_action(False, "cancelled"), POST_TURN_STAY,
        "no interrupt after cancelled, stay",
    )
    # The interrupt stopped the reply: its one job is done.
    expect_eq_int(
        post_turn_action(True, "cancelled"), POST_TURN_STAY,
        "interrupt spent by cancelling",
    )
    # The reply finished on its own; the late interrupt had
    # nothing to stop: drained, noted, session continues.
    expect_eq_int(
        post_turn_action(True, "length"), POST_TURN_STAY_NOTED,
        "late interrupt noted",
    )
    expect_eq_int(
        post_turn_action(True, "stop"), POST_TURN_STAY_NOTED,
        "late interrupt noted (stop)",
    )


def test_suggestion_rules() raises:
    expect_eq_int(edit_distance("kitten", "sitting"), 3, "kitten/sitting")
    expect_eq_int(edit_distance("", "abc"), 3, "empty left")
    expect_eq_int(edit_distance("abc", ""), 3, "empty right")
    expect_eq_int(edit_distance("abc", "abc"), 0, "identical")
    expect_eq_int(edit_distance("flaw", "lawn"), 2, "flaw/lawn")
    expect_eq_int(edit_distance("AESIR_CAHCE_HOME", "AESIR_CACHE_HOME"), 2,
                  "transposition costs two")
    var pair = List[String]()
    pair.append(String("abd"))
    pair.append(String("abe"))
    expect_eq_str(
        suggest_match("abc", pair), "abd", "tie keeps the earliest",
    )
    expect_eq_str(suggest_match("abd", pair), "", "exact suggests nothing")
    expect_eq_str(suggest_match("ab", pair), "", "too short suggests nothing")
    expect_eq_str(suggest_match("", pair), "", "empty suggests nothing")
    expect_eq_str(
        suggest_match("xyzqq", pair), "", "far suggests nothing",
    )
    expect_eq_str(
        suggestion_suffix("pull"), "; did you mean 'pull'?",
        "suffix renders",
    )
    expect_eq_str(suggestion_suffix(""), "", "no suggestion, no suffix")


def test_candidate_suggestions() raises:
    expect_eq_int(len(cli_command_names()), 41, "cli candidate count")
    expect_eq_int(len(chat_command_names()), 18, "chat candidate count")
    expect_eq_int(len(chat_option_names()), 18, "option candidate count")
    expect_eq_str(suggest_cli_command("pul"), "pull", "pul -> pull")
    expect_eq_str(suggest_cli_command("benhc"), "bench", "benhc -> bench")
    expect_eq_str(suggest_cli_command("chat"), "", "exact cli name")
    expect_eq_str(suggest_cli_command("zzzz"), "", "stranger cli name")
    expect_eq_str(
        suggest_chat_command("/sav"), "/save", "/sav -> /save",
    )
    expect_eq_str(
        suggest_chat_command("/save-config"), "", "exact slash name",
    )
    expect_eq_str(
        suggest_chat_command("/hep"), "/help", "/hep -> /help",
    )
    expect_eq_str(
        suggest_chat_option("--acel"), "--accel", "--acel -> --accel",
    )
    expect_eq_str(
        suggest_chat_option("--accel"), "", "exact option name",
    )
    expect_eq_str(first_word("/save-config clear x"), "/save-config",
                  "first word of a command line")
    expect_eq_str(first_word("/help"), "/help", "first word, no spaces")


def test_env_audit() raises:
    expect_eq_int(len(known_env_names()), 24, "known env count")
    expect_eq_int(len(documented_env_names()), 3, "documented env count")
    # Correctly spelt names are never reported -- read ones
    # and documented ones alike.
    expect_eq_str(audit_env_name("AESIR_CACHE_HOME"), "", "known read name")
    expect_eq_str(audit_env_name("AESIR_THREADS"), "", "known threads")
    expect_eq_str(
        audit_env_name("AESIR_EXPERT_CACHE_BYTES"), "",
        "known documented name",
    )
    # Near misses are reported with the right target.
    expect_eq_str(
        audit_env_name("AESIR_CAHCE_HOME"), "AESIR_CACHE_HOME",
        "transposed cache home",
    )
    expect_eq_str(
        audit_env_name("AESIR_THREAD"), "AESIR_THREADS", "dropped letter",
    )
    expect_eq_str(
        audit_env_name("AESIR_EXPERT_CACHE_BYTE"),
        "AESIR_EXPERT_CACHE_BYTES",
        "near miss of a documented name",
    )
    expect_eq_str(
        audit_env_name("AESIR_KV_PRECISON"), "AESIR_KV_PRECISION",
        "dropped letter, kv precision",
    )
    # Strangers and non-AESIR names are not reported.
    expect_eq_str(audit_env_name("AESIR_FOO"), "", "stranger AESIR_ name")
    expect_eq_str(audit_env_name("PATH"), "", "non-AESIR name")
    expect_eq_str(audit_env_name("AESIR"), "", "bare prefix")
    var present = List[String]()
    present.append(String("PATH"))
    present.append(String("AESIR_CAHCE_HOME"))
    present.append(String("AESIR_THREADS"))
    present.append(String("AESIR_SOMETHING_ELSE"))
    var warnings = audit_env_names(present)
    expect_eq_int(len(warnings), 1, "one warning for one near miss")
    expect_true(
        "AESIR_CAHCE_HOME" in warnings[0]
        and "AESIR_CACHE_HOME" in warnings[0]
        and "never read" in warnings[0],
        "warning names the typo, the target, and the consequence",
    )


def test_write_classifier() raises:
    var cache = String("/home/u/.cache/aesir")
    var chosen = List[String]()
    chosen.append(String("/work/transcript.md"))
    chosen.append(String("/work/autosave"))
    var models = List[String]()
    models.append(String("/models/m.gguf"))
    models.append(String("/home/u/.cache/aesir/stored.gguf"))
    expect_eq_int(
        classify_write_destination(
            "/home/u/.cache/aesir/learned-placement.v1", cache, chosen, models
        ),
        WRITE_ALLOWED_CACHE, "learned file under the cache home",
    )
    expect_eq_int(
        classify_write_destination(cache, cache, chosen, models),
        WRITE_ALLOWED_CACHE, "the cache home itself",
    )
    expect_eq_int(
        classify_write_destination(
            "/home/u/.cache/aesir", cache + String("/"), chosen, models
        ),
        WRITE_ALLOWED_CACHE, "trailing slash on the root still matches",
    )
    expect_eq_int(
        classify_write_destination(
            "/home/u/.cache/aesir2/x", cache, chosen, models
        ),
        WRITE_REFUSED_STRAY, "prefix sibling is not under the cache home",
    )
    expect_eq_int(
        classify_write_destination("/work/transcript.md", cache, chosen, models),
        WRITE_ALLOWED_CHOSEN, "the chosen transcript file",
    )
    expect_eq_int(
        classify_write_destination(
            "/work/autosave/gen/0001", cache, chosen, models
        ),
        WRITE_ALLOWED_CHOSEN, "under the chosen autosave directory",
    )
    expect_eq_int(
        classify_write_destination("/models/m.gguf", cache, chosen, models),
        WRITE_REFUSED_MODEL, "a model file is never a write target",
    )
    expect_eq_int(
        classify_write_destination(
            "/home/u/.cache/aesir/stored.gguf", cache, chosen, models
        ),
        WRITE_REFUSED_MODEL,
        "a model file inside the cache home is still refused (M4 first)",
    )
    expect_eq_int(
        classify_write_destination("/etc/passwd", cache, chosen, models),
        WRITE_REFUSED_STRAY, "a stray path is refused",
    )
    var empty_roots = List[String]()
    empty_roots.append(String(""))
    expect_eq_int(
        classify_write_destination("/work/transcript.md", cache, empty_roots, models),
        WRITE_REFUSED_STRAY, "an empty chosen root matches nothing",
    )
    expect_true(path_is_under("/a/b/c", "/a/b"), "under, nested")
    expect_true(not path_is_under("/a/bc", "/a/b"), "not under, sibling")
    expect_eq_str(
        write_destination_name(WRITE_REFUSED_MODEL), "REFUSED_MODEL",
        "model verdict name",
    )
    expect_eq_str(write_destination_name(77), "UNKNOWN", "unknown verdict name")


def test_environ_surface() raises:
    var names = _environ_names()
    expect_true(len(names) > 0, "environ yields names on this machine")
    var saw_path = False
    for i in range(len(names)):
        if names[i] == "PATH":
            saw_path = True
        expect_true(
            "=" not in names[i], "environ entries are names, not pairs",
        )
    expect_true(saw_path, "environ contains PATH")
    var warnings = env_manner_warnings()
    for i in range(len(warnings)):
        expect_true(
            warnings[i].startswith("env manner: "),
            "every live warning is an env-manner line",
        )


def main() raises:
    test_prompt_line_decisions()
    print("PASS: prompt-line decisions (interrupt re-prompts; eof leaves; final line submits; blank//bye kept)")
    test_post_turn_decisions()
    print("PASS: post-turn decisions (cancelled spends the interrupt; a late interrupt is noted, never a leave)")
    test_suggestion_rules()
    print("PASS: suggestion rules (distances, threshold, tie order, exact/empty/short suggest nothing, suffix)")
    test_candidate_suggestions()
    print("PASS: candidate sets (cli 41, chat 18, options 18; their own near misses resolve)")
    test_env_audit()
    print("PASS: env audit (known never reported; near misses named with target; strangers and non-AESIR silent)")
    test_write_classifier()
    print("PASS: write classifier (cache + chosen allowed; sibling/stray refused; model refused first, even in cache)")
    test_environ_surface()
    print("PASS: environ surface (names parsed from /proc/self/environ; live warnings are manner lines)")
    print("ALL PASS: chat manners (7 groups)")
