"""OpenAI-shape audit (J-106): the pure audit layer of the
server surface -- the chat-completions field table (honoured
/ partial / refused, with the slice's closures counted in),
the raw-completions field table, the message field and role
tables, the route table (served incl. the models retrieve
pattern, the 501 refusal class with its reasons and bodies,
the kept-404 families), and the closures themselves at the
parser and formatter surface they land in (max_completion_
tokens precedence, the developer role, cached_tokens usage
accounting, the session status's cached count).

No number in this suite is a behaviour of a live server: no
socket was opened, no session started, no inference ran.
The live server leg is J-106's deferred leg (doc section
5), re-cited at the J-118 gate.
"""
from core.openai_audit import (
    FIELD_HONOURED,
    FIELD_PARTIAL,
    FIELD_REFUSED,
    ROUTE_SERVED,
    ROUTE_REFUSED_501,
    ROUTE_KEPT_404,
    chat_field_names,
    chat_field_verdict,
    completion_field_names,
    completion_field_verdict,
    field_verdict_name,
    is_model_retrieve,
    kept_404_route_families,
    message_field_names,
    message_field_verdict,
    message_role_names,
    message_role_verdict,
    refusal_reason,
    refused_route_names,
    route_verdict,
    route_verdict_name,
    served_route_names,
    unsupported_route_body,
)
from core.generation_control import NativeGenerationStatus
from server.openai import OpenAIRequest, OpenAIGate


def expect_eq_int(got: Int, want: Int, what: String) raises:
    if got != want:
        raise Error(
            "OpenAIAudit " + what + ": expected " + String(want)
            + ", got " + String(got)
        )


def expect_eq_str(got: String, want: String, what: String) raises:
    if got != want:
        raise Error(
            "OpenAIAudit " + what + ": expected '" + want
            + "', got '" + got + "'"
        )


def expect_true(value: Bool, what: String) raises:
    if not value:
        raise Error("OpenAIAudit " + what + ": expected true")


def expect_in(haystack: String, needle: String, what: String) raises:
    if needle not in haystack:
        raise Error(
            "OpenAIAudit " + what + ": expected '" + needle
            + "' inside '" + haystack + "'"
        )


def test_chat_field_table() raises:
    var names = chat_field_names()
    expect_eq_int(len(names), 31, "chat field table size")
    var honoured = 0
    var partial = 0
    var refused = 0
    for name in names:
        var verdict = chat_field_verdict(name)
        if verdict == FIELD_HONOURED:
            honoured += 1
        elif verdict == FIELD_PARTIAL:
            partial += 1
        elif verdict == FIELD_REFUSED:
            refused += 1
    expect_eq_int(honoured, 8, "chat honoured count")
    expect_eq_int(partial, 4, "chat partial count")
    expect_eq_int(refused, 19, "chat refused count")
    expect_eq_int(chat_field_verdict("max_completion_tokens"), FIELD_HONOURED,
                  "max_completion_tokens closed")
    expect_eq_int(chat_field_verdict("n"), FIELD_PARTIAL, "n partial (one choice)")
    expect_eq_int(chat_field_verdict("response_format"), FIELD_PARTIAL,
                  "response_format partial (strict boolean only)")
    expect_eq_int(chat_field_verdict("tools"), FIELD_PARTIAL,
                  "tools partial (one zero-arg Gemma function)")
    expect_eq_int(chat_field_verdict("tool_choice"), FIELD_PARTIAL,
                  "tool_choice partial (auto only)")
    expect_eq_int(chat_field_verdict("logprobs"), FIELD_REFUSED, "logprobs refused")
    expect_eq_int(chat_field_verdict("stop"), FIELD_REFUSED, "stop refused")
    expect_eq_int(chat_field_verdict("prompt_on"), FIELD_REFUSED,
                  "placement fields refused on this route (T20)")
    expect_eq_int(chat_field_verdict("some_future_field"), FIELD_REFUSED,
                  "strangers refused, never ignored")
    expect_eq_str(field_verdict_name(FIELD_HONOURED), "HONOURED", "verdict name")
    expect_eq_str(field_verdict_name(99), "UNKNOWN", "verdict name fallback")
    print("PASS: chat field table (31 fields: 8 honoured, 4 partial, 19 refused; strangers refused)")


def test_completion_field_table() raises:
    var names = completion_field_names()
    expect_eq_int(len(names), 19, "completion field table size")
    var honoured = 0
    var partial = 0
    var refused = 0
    for name in names:
        var verdict = completion_field_verdict(name)
        if verdict == FIELD_HONOURED:
            honoured += 1
        elif verdict == FIELD_PARTIAL:
            partial += 1
        elif verdict == FIELD_REFUSED:
            refused += 1
    expect_eq_int(honoured, 8, "completion honoured count")
    expect_eq_int(partial, 1, "completion partial count")
    expect_eq_int(refused, 10, "completion refused count")
    expect_eq_int(completion_field_verdict("suffix"), FIELD_REFUSED,
                  "suffix refused here (FIM is J-111)")
    expect_eq_int(completion_field_verdict("echo"), FIELD_REFUSED, "echo refused")
    expect_eq_int(completion_field_verdict("best_of"), FIELD_REFUSED, "best_of refused")
    print("PASS: completion field table (19 fields: 8 honoured, 1 partial, 10 refused)")


def test_message_tables() raises:
    var fields = message_field_names()
    expect_eq_int(len(fields), 7, "message field table size")
    expect_eq_int(message_field_verdict("role"), FIELD_HONOURED, "role honoured")
    expect_eq_int(message_field_verdict("content"), FIELD_HONOURED, "content honoured")
    expect_eq_int(message_field_verdict("tool_call_id"), FIELD_REFUSED,
                  "tool_call_id refused")
    expect_eq_int(message_field_verdict("name"), FIELD_REFUSED, "name refused")
    var roles = message_role_names()
    expect_eq_int(len(roles), 6, "role table size")
    expect_eq_int(message_role_verdict("developer"), FIELD_HONOURED,
                  "developer honoured as system (closed)")
    expect_eq_int(message_role_verdict("system"), FIELD_HONOURED, "system honoured")
    expect_eq_int(message_role_verdict("tool"), FIELD_REFUSED, "tool role refused")
    expect_eq_int(message_role_verdict("function"), FIELD_REFUSED,
                  "function role refused")
    print("PASS: message tables (2/7 fields honoured; 4/6 roles honoured incl. developer)")


def test_route_table() raises:
    expect_eq_int(len(served_route_names()), 8, "served route count")
    expect_eq_int(len(refused_route_names()), 6, "refused route count")
    expect_eq_int(len(kept_404_route_families()), 8, "kept family count")
    expect_eq_int(route_verdict("POST", "/v1/chat/completions"), ROUTE_SERVED,
                  "chat served")
    expect_eq_int(route_verdict("POST", "/v1/completions"), ROUTE_SERVED,
                  "completions served")
    expect_eq_int(route_verdict("GET", "/v1/models"), ROUTE_SERVED, "models list served")
    expect_eq_int(route_verdict("GET", "/v1/models/gemma4-e2b:latest"), ROUTE_SERVED,
                  "models retrieve served (closed)")
    expect_eq_int(route_verdict("POST", "/v1/embeddings"), ROUTE_REFUSED_501,
                  "embeddings 501")
    expect_eq_int(route_verdict("POST", "/v1/audio/transcriptions"), ROUTE_REFUSED_501,
                  "speech-to-text 501 (gate refusal)")
    expect_eq_int(route_verdict("POST", "/v1/audio/speech"), ROUTE_REFUSED_501,
                  "speech synthesis 501")
    expect_eq_int(route_verdict("POST", "/v1/responses"), ROUTE_REFUSED_501,
                  "responses 501")
    expect_eq_int(route_verdict("POST", "/v1/moderations"), ROUTE_REFUSED_501,
                  "moderations 501")
    expect_eq_int(route_verdict("GET", "/v1/embeddings"), ROUTE_KEPT_404,
                  "wrong method on a refused route stays 404")
    expect_eq_int(route_verdict("POST", "/v1/files"), ROUTE_KEPT_404,
                  "files family kept 404")
    expect_eq_int(route_verdict("GET", "/v1/models/a/b"), ROUTE_KEPT_404,
                  "deep models path stays 404")
    expect_eq_int(route_verdict("GET", "/nonsense"), ROUTE_KEPT_404,
                  "strangers stay 404")
    expect_true(is_model_retrieve("GET", "/v1/models/m"), "retrieve pattern")
    expect_true(not is_model_retrieve("GET", "/v1/models/"), "empty id is not retrieve")
    expect_true(not is_model_retrieve("POST", "/v1/models/m"), "retrieve is GET only")
    expect_eq_str(route_verdict_name(ROUTE_REFUSED_501), "REFUSED_501", "route name")
    print("PASS: route table (8 served incl. retrieve, 6 refused-501, families + strangers 404)")


def test_refusal_bodies() raises:
    for key in refused_route_names():
        var parts = key.split(" ")
        var body = unsupported_route_body(String(parts[0]), String(parts[1]))
        expect_in(body, "\"code\":501", "refusal body carries 501 for " + key)
        expect_in(body, String(parts[1]), "refusal body names its route " + key)
        expect_true(refusal_reason(String(parts[0]), String(parts[1])).byte_length() > 40,
                    "refusal reason is a real sentence for " + key)
    var speech = unsupported_route_body("POST", "/v1/audio/transcriptions")
    expect_in(speech, "refused", "speech body states the refusal")
    var weird = unsupported_route_body("POST", "/v1/embeddings")
    expect_in(weird, "no embedding data path exists", "embeddings body states its reason")
    print("PASS: refusal bodies (501 + route + a real reason, per refused route)")


def test_parser_closures() raises:
    var alias_only = OpenAIRequest(
        "{\"model\":\"m\",\"prompt\":\"x\",\"max_completion_tokens\":48}")
    expect_eq_int(alias_only.max_tokens, 48, "max_completion_tokens honoured alone")
    var both = OpenAIRequest(
        "{\"model\":\"m\",\"prompt\":\"x\",\"max_tokens\":16,\"max_completion_tokens\":48}")
    expect_eq_int(both.max_tokens, 48, "max_completion_tokens takes precedence")
    var legacy_only = OpenAIRequest(
        "{\"model\":\"m\",\"prompt\":\"x\",\"max_tokens\":16}")
    expect_eq_int(legacy_only.max_tokens, 16, "max_tokens unchanged alone")
    var developer = OpenAIRequest(
        "{\"model\":\"m\",\"messages\":[{\"role\":\"developer\",\"content\":\"Be brief.\"},{\"role\":\"user\",\"content\":\"Hi\"}]}")
    expect_eq_str(developer.system, "Be brief.", "developer role lands as system")
    expect_true(developer.chat_prompt.endswith("User: Hi\n"), "developer turn kept")
    var refused = False
    try:
        _ = OpenAIRequest("{\"model\":\"m\",\"prompt\":\"x\",\"logprobs\":true}")
    except:
        refused = True
    expect_true(refused, "logprobs still refused by the parser, by name")
    var refused_stream_options = False
    try:
        _ = OpenAIRequest(
            "{\"model\":\"m\",\"prompt\":\"x\",\"stream\":true,\"stream_options\":{\"include_usage\":true}}")
    except:
        refused_stream_options = True
    expect_true(refused_stream_options, "stream_options still refused by the parser")
    print("PASS: parser closures (max_completion_tokens precedence, developer role; kept refusals hold)")


def test_usage_accounting() raises:
    var chat = OpenAIGate.format_chat_completion(
        "chatcmpl-aesir-1", 1788210000, "m", "Hello", "stop", 10, 3, 4)
    expect_in(chat, "\"prompt_tokens_details\"", "chat usage carries details")
    expect_in(chat, "\"cached_tokens\": 4", "chat usage carries the cached count")
    var completion = OpenAIGate.format_completion(
        "cmpl-aesir-1", 1788210000, "m", "Hello", "stop", 10, 3, 0)
    expect_in(completion, "\"cached_tokens\":0", "completion usage carries an honest zero")
    var tool = OpenAIGate.format_chat_tool_completion(
        "chatcmpl-aesir-1", 1788210000, "m", "call-aesir-1", "f", "{}", 10, 3, 2)
    expect_in(tool, "\"cached_tokens\":2", "tool usage carries the cached count")
    var defaulted = OpenAIGate.format_chat_completion(
        "chatcmpl-aesir-1", 1788210000, "m", "Hello", "stop", 10, 3)
    expect_in(defaulted, "\"cached_tokens\": 0", "default cached count is an honest zero")
    var over = False
    try:
        _ = OpenAIGate.format_chat_completion(
            "chatcmpl-aesir-1", 1788210000, "m", "Hello", "stop", 3, 1, 4)
    except:
        over = True
    expect_true(over, "cached count above the prompt count is refused")
    var status = NativeGenerationStatus(True, False, 10, 3, 13, "eos")
    expect_eq_int(status.cached_tokens, 0, "status cached count defaults to zero")
    var status_cached = NativeGenerationStatus(True, False, 10, 3, 13, "eos", 4)
    expect_eq_int(status_cached.cached_tokens, 4, "status carries the reused count")
    print("PASS: usage accounting (prompt_tokens_details.cached_tokens on all three forms; status carries it)")


def main() raises:
    test_chat_field_table()
    test_completion_field_table()
    test_message_tables()
    test_route_table()
    test_refusal_bodies()
    test_parser_closures()
    test_usage_accounting()
    print("ALL PASS: openai audit (7 groups)")
