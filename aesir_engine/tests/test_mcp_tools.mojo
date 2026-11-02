"""MCP model-as-tools (J-109): the pure protocol +
dispatch layer -- the bounded scanner, the method
classification, the initialize handshake, the tool
schemas, model-info dispatch from catalogue facts,
the embed refusal, the generate dispatch verdicts
(no-engine tool error; NEEDS_GENERATE when bound; the
completion envelopes), and the protocol error codes.
J-112 adds the services dispatch group: census, grade,
tokenize (the no-tokenizer error; NEEDS_TOKENIZE when
bound), and bench (NEEDS_BENCH, host-executed).

No number in this suite is a behaviour of a live engine:
no model was loaded and no text was generated. The live
generation leg is deferred-with-reason in the J-109 doc
(section 5), re-cited at the J-118 gate.
"""
from core.mcp_tools import (
    McpModelFact,
    McpReply,
    McpSession,
    mcp_bench_completion,
    mcp_classify_method,
    mcp_embed_refusal_reason,
    mcp_generate_completion,
    mcp_generate_failure,
    mcp_handle_line,
    mcp_json_escape,
    mcp_json_object_ok,
    mcp_method_initialize,
    mcp_method_notification,
    mcp_method_ping,
    mcp_method_tools_call,
    mcp_method_tools_list,
    mcp_method_unknown,
    mcp_no_engine_reason,
    mcp_no_tokenizer_reason,
    mcp_protocol_version,
    mcp_scan_field,
    mcp_server_name,
    mcp_tokenize_completion,
    mcp_tokenize_failure,
    mcp_tool_names,
    mcp_tools_list_result,
)


def expect_true(cond: Bool, what: String) raises:
    if not cond:
        raise Error("McpTools " + what + ": expected true")


def expect_false(cond: Bool, what: String) raises:
    if cond:
        raise Error("McpTools " + what + ": expected false")


def expect_eq(actual: Int, expected: Int, what: String) raises:
    if actual != expected:
        raise Error(
            "McpTools " + what + ": expected " + String(expected)
            + ", got " + String(actual)
        )


def expect_in(haystack: String, needle: String, what: String) raises:
    if needle not in haystack:
        raise Error(
            "McpTools " + what + ": expected '" + needle
            + "' inside '" + haystack + "'"
        )


def expect_not_in(haystack: String, needle: String, what: String) raises:
    if needle in haystack:
        raise Error(
            "McpTools " + what + ": did not expect '" + needle
            + "' inside '" + haystack + "'"
        )


def facts() -> List[McpModelFact]:
    var out = List[McpModelFact]()
    out.append(
        McpModelFact(
            "qwen3-0.6b",
            "latest",
            "Qwen/Qwen3-0.6B-GGUF",
            "qwen3-0.6b-q4_k_m.gguf",
            "0123456789abcdef0123456789abcdef01234567",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            398000000,
            "Q4_K_M",
        )
    )
    out.append(
        McpModelFact(
            "olmoe-1b-7b",
            "latest",
            "allenai/OLMoE-1B-7B-0924-GGUF",
            "olmoe-1b-7b-q4_k_m.gguf",
            "89abcdef0123456789abcdef0123456789abcdef",
            "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
            4213512672,
            "Q4_K_M",
        )
    )
    return out^


def initialized_session() -> McpSession:
    var s = McpSession()
    s.initialized = True
    return s


def call_line(tool: String, arguments: String) -> String:
    return (
        String("{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":")
        + String("\"tools/call\",\"params\":{\"name\":\"")
        + tool
        + String("\",\"arguments\":") + arguments + String("}}")
    )


def test_scanner() raises:
    var line = String(
        "{\"jsonrpc\":\"2.0\",\"id\":42,\"method\":\"tools/call\","
        "\"params\":{\"name\":\"aesir_generate\",\"arguments\":"
        "{\"prompt\":\"hi \\\"there\\\"\",\"max_tokens\":64}},"
        "\"flag\":true,\"nothing\":null}"
    )
    expect_true(mcp_json_object_ok(line), "object ok")
    var method = mcp_scan_field(line, "method")
    expect_true(method.found, "method found")
    expect_true(method.value == "tools/call", "method value")
    var idf = mcp_scan_field(line, "id")
    expect_true(idf.found and idf.kind == "number", "id kind")
    expect_true(idf.value == "42", "id raw")
    var params = mcp_scan_field(line, "params")
    expect_true(params.found and params.kind == "object", "params object")
    var name = mcp_scan_field(params.value, "name")
    expect_true(name.value == "aesir_generate", "nested name")
    var args = mcp_scan_field(params.value, "arguments")
    expect_true(args.found and args.kind == "object", "arguments object")
    var prompt = mcp_scan_field(args.value, "prompt")
    expect_true(prompt.value == "hi \"there\"", "escaped prompt decoded")
    var mt = mcp_scan_field(args.value, "max_tokens")
    expect_true(mt.found and mt.value == "64", "max_tokens raw")
    var flag = mcp_scan_field(line, "flag")
    expect_true(flag.found and flag.kind == "bool", "bool kind")
    var nothing = mcp_scan_field(line, "nothing")
    expect_true(nothing.found and nothing.kind == "null", "null kind")
    var absent = mcp_scan_field(line, "zzz")
    expect_false(absent.found, "absent field")
    expect_false(mcp_json_object_ok("not json"), "garbage refused")
    expect_false(
        mcp_json_object_ok("{\"a\":1} trailing"), "trailing refused"
    )
    expect_false(mcp_json_object_ok("{\"a\":"), "truncated refused")
    expect_false(mcp_json_object_ok(""), "empty refused")
    var esc = mcp_json_escape("a\"b\\c\nd")
    expect_true(esc == "a\\\"b\\\\c\\nd", "escape output")
    print("PASS: scanner (fields, nesting, escapes, malformed refused)")


def test_classification() raises:
    expect_eq(
        mcp_classify_method("initialize"),
        mcp_method_initialize(),
        "initialize class",
    )
    expect_eq(
        mcp_classify_method("ping"), mcp_method_ping(), "ping class"
    )
    expect_eq(
        mcp_classify_method("tools/list"),
        mcp_method_tools_list(),
        "tools/list class",
    )
    expect_eq(
        mcp_classify_method("tools/call"),
        mcp_method_tools_call(),
        "tools/call class",
    )
    expect_eq(
        mcp_classify_method("notifications/initialized"),
        mcp_method_notification(),
        "notification class",
    )
    expect_eq(
        mcp_classify_method("resources/list"),
        mcp_method_unknown(),
        "unknown class",
    )
    var names = mcp_tool_names()
    expect_eq(len(names), 7, "seven tools")
    expect_true(names[0] == "aesir_generate", "tool 0")
    expect_true(names[1] == "aesir_model_info", "tool 1")
    expect_true(names[2] == "aesir_embed", "tool 2")
    expect_true(names[3] == "aesir_tokenize", "tool 3")
    expect_true(names[4] == "aesir_grade", "tool 4")
    expect_true(names[5] == "aesir_census", "tool 5")
    expect_true(names[6] == "aesir_bench", "tool 6")
    expect_true(mcp_server_name() == "aesir", "server name")
    expect_true(mcp_protocol_version() == "2024-11-05", "protocol version")
    print("PASS: classification (methods, seven tool names, facts)")


def test_handshake_and_errors() raises:
    var f = facts()
    var fresh = McpSession()
    # tools/list before initialize -> -32002
    var early = mcp_handle_line(
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/list\"}",
        fresh, f, False, "",
    )
    expect_true(early.respond, "early responds")
    expect_in(early.payload, "\"code\":-32002", "not-initialized code")
    # initialize -> handshake, now_initialized
    var init = mcp_handle_line(
        "{\"jsonrpc\":\"2.0\",\"id\":\"abc\",\"method\":\"initialize\","
        "\"params\":{\"protocolVersion\":\"2024-11-05\","
        "\"capabilities\":{},\"clientInfo\":{\"name\":\"t\","
        "\"version\":\"1\"}}}",
        fresh, f, False, "",
    )
    expect_true(init.respond, "init responds")
    expect_true(init.now_initialized, "init sets flag")
    expect_in(init.payload, "\"id\":\"abc\"", "string id echoed raw")
    expect_in(
        init.payload, "\"protocolVersion\":\"2024-11-05\"", "version"
    )
    expect_in(init.payload, "\"serverInfo\":{\"name\":\"aesir\"", "server")
    expect_in(init.payload, "\"tools\":{}", "tools capability")
    # notification -> silence
    var note = mcp_handle_line(
        "{\"jsonrpc\":\"2.0\",\"method\":"
        "\"notifications/initialized\"}",
        initialized_session(), f, False, "",
    )
    expect_false(note.respond, "notification silent")
    # ping -> {}
    var ping = mcp_handle_line(
        "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"ping\"}",
        initialized_session(), f, False, "",
    )
    expect_in(ping.payload, "\"id\":2", "numeric id echoed")
    expect_in(ping.payload, "\"result\":{}", "ping result")
    # unknown method -> -32601
    var unk = mcp_handle_line(
        "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"resources/list\"}",
        initialized_session(), f, False, "",
    )
    expect_in(unk.payload, "\"code\":-32601", "unknown method code")
    # no method -> -32600
    var nomethod = mcp_handle_line(
        "{\"jsonrpc\":\"2.0\",\"id\":4}",
        initialized_session(), f, False, "",
    )
    expect_in(nomethod.payload, "\"code\":-32600", "no method code")
    # malformed -> -32700 with null id
    var bad = mcp_handle_line(
        "{not json", initialized_session(), f, False, ""
    )
    expect_in(bad.payload, "\"code\":-32700", "parse code")
    expect_in(bad.payload, "\"id\":null", "parse id null")
    print("PASS: handshake + protocol errors (-32002/-32601/-32600/-32700)")


def test_tools_list() raises:
    var result = mcp_tools_list_result()
    expect_in(result, "\"name\":\"aesir_generate\"", "generate listed")
    expect_in(result, "\"name\":\"aesir_model_info\"", "info listed")
    expect_in(result, "\"name\":\"aesir_embed\"", "embed listed")
    expect_in(result, "\"name\":\"aesir_tokenize\"", "tokenize listed")
    expect_in(result, "\"name\":\"aesir_grade\"", "grade listed")
    expect_in(result, "\"name\":\"aesir_census\"", "census listed")
    expect_in(result, "\"name\":\"aesir_bench\"", "bench listed")
    expect_in(result, "\"inputSchema\"", "schemas present")
    expect_in(result, "\"required\":[\"prompt\"]", "prompt required")
    expect_in(result, "UNAVAILABLE", "embed refusal in description")
    var reply = mcp_handle_line(
        "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"tools/list\"}",
        initialized_session(), facts(), False, "",
    )
    expect_true(reply.respond, "list responds")
    expect_in(reply.payload, "\"tools\":[", "tools array")
    print("PASS: tools/list (exactly seven tools, honest embed schema)")


def test_model_info() raises:
    var f = facts()
    var s = initialized_session()
    var one = mcp_handle_line(
        call_line("aesir_model_info", "{\"model\":\"qwen3-0.6b\"}"),
        s, f, False, "",
    )
    expect_true(one.respond, "info responds")
    expect_in(one.payload, "\"isError\":false", "info not error")
    expect_in(
        one.payload,
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "sha pin in record",
    )
    expect_in(one.payload, "Qwen/Qwen3-0.6B-GGUF", "repository in record")
    expect_in(one.payload, "398000000", "size in record")
    expect_in(
        one.payload, "known-models catalogue record", "source named"
    )
    expect_in(
        one.payload, "\\\"live_session_bound\\\":false", "bound stated"
    )
    var by_ref = mcp_handle_line(
        call_line(
            "aesir_model_info", "{\"model\":\"olmoe-1b-7b:latest\"}"
        ),
        s, f, False, "",
    )
    expect_in(by_ref.payload, "allenai/OLMoE", "name:tag resolves")
    var listing = mcp_handle_line(
        call_line("aesir_model_info", "{}"), s, f, False, ""
    )
    expect_in(listing.payload, "qwen3-0.6b:latest", "listing has first")
    expect_in(listing.payload, "olmoe-1b-7b:latest", "listing has second")
    expect_in(listing.payload, "2 entries", "listing count")
    var unknown = mcp_handle_line(
        call_line("aesir_model_info", "{\"model\":\"nope\"}"),
        s, f, False, "",
    )
    expect_in(unknown.payload, "\"isError\":true", "unknown is tool error")
    expect_in(unknown.payload, "unknown model: nope", "unknown named")
    expect_in(
        unknown.payload, "qwen3-0.6b:latest", "known named in error"
    )
    print("PASS: model_info (record verbatim, listing, unknown refused)")


def test_embed_refusal() raises:
    var reply = mcp_handle_line(
        call_line("aesir_embed", "{\"input\":\"hello\"}"),
        initialized_session(), facts(), False, "",
    )
    expect_true(reply.respond, "embed responds")
    expect_in(reply.payload, "\"isError\":true", "embed is tool error")
    expect_in(
        reply.payload, "no embedding", "embed reason present"
    )
    expect_in(
        reply.payload, "embeddings:false", "embed ground present"
    )
    expect_not_in(reply.payload, "\"embedding\"", "no vector field")
    expect_not_in(reply.payload, "[0.", "no vector numbers")
    var missing = mcp_handle_line(
        call_line("aesir_embed", "{}"),
        initialized_session(), facts(), False, "",
    )
    expect_in(missing.payload, "\"code\":-32602", "missing input -32602")
    expect_true(
        mcp_embed_refusal_reason().byte_length() > 100, "reason length"
    )
    print("PASS: embed refusal (tool error, reason, no vector anywhere)")


def test_generate_dispatch() raises:
    var f = facts()
    var s = initialized_session()
    var missing = mcp_handle_line(
        call_line("aesir_generate", "{}"), s, f, False, ""
    )
    expect_in(missing.payload, "\"code\":-32602", "missing prompt code")
    expect_in(missing.payload, "prompt", "missing prompt named")
    var empty = mcp_handle_line(
        call_line("aesir_generate", "{\"prompt\":\"\"}"),
        s, f, False, "",
    )
    expect_in(empty.payload, "\"code\":-32602", "empty prompt code")
    var unbound = mcp_handle_line(
        call_line("aesir_generate", "{\"prompt\":\"hello\"}"),
        s, f, False, "",
    )
    expect_true(unbound.respond, "unbound responds")
    expect_false(unbound.needs_generate, "unbound does not generate")
    expect_in(unbound.payload, "\"isError\":true", "unbound tool error")
    expect_in(
        unbound.payload, "no live model session", "unbound reason"
    )
    expect_true(mcp_no_engine_reason().byte_length() > 100, "reason len")
    var bound = mcp_handle_line(
        call_line(
            "aesir_generate",
            "{\"prompt\":\"hello\",\"max_tokens\":99999}",
        ),
        s, f, True, "qwen3-0.6b:latest",
    )
    expect_false(bound.respond, "bound waits for host")
    expect_true(bound.needs_generate, "bound needs generate")
    expect_true(bound.gen_prompt == "hello", "bound prompt carried")
    expect_eq(bound.gen_max_tokens, 4096, "max_tokens clamped")
    expect_true(bound.gen_id_raw == "7", "bound id carried")
    var done = mcp_generate_completion(bound.gen_id_raw, "world")
    expect_in(done, "\"id\":7", "completion id")
    expect_in(done, "\"isError\":false", "completion not error")
    expect_in(done, "world", "completion text")
    var failed = mcp_generate_failure(bound.gen_id_raw, "engine died")
    expect_in(failed, "\"isError\":true", "failure is tool error")
    expect_in(failed, "engine died", "failure reason")
    var mismatch = mcp_handle_line(
        call_line(
            "aesir_generate",
            "{\"prompt\":\"hi\",\"model\":\"other\"}",
        ),
        s, f, True, "qwen3-0.6b:latest",
    )
    expect_in(
        mismatch.payload, "\"isError\":true", "mismatch is tool error"
    )
    expect_in(mismatch.payload, "qwen3-0.6b:latest", "bound named")
    var bad_tool = mcp_handle_line(
        call_line("aesir_frobnicate", "{}"), s, f, False, ""
    )
    expect_in(bad_tool.payload, "\"code\":-32602", "unknown tool code")
    expect_in(bad_tool.payload, "unknown tool", "unknown tool named")
    print("PASS: generate dispatch (validation, unbound, bound, envelopes)")


def test_services_dispatch() raises:
    var f = facts()
    var s = initialized_session()
    # census: the population + the services inventory, no model bound.
    var census = mcp_handle_line(
        call_line("aesir_census", "{}"), s, f, False, ""
    )
    expect_true(census.respond, "census responds")
    expect_in(census.payload, "\"isError\":false", "census not error")
    expect_in(census.payload, "known-models census: 2 entries", "census count")
    expect_in(census.payload, "4611512672 bytes total", "census total")
    expect_in(census.payload, "aesir services (9 inventoried)", "inventory in census")
    expect_in(census.payload, "mcp_client", "inventory names deferred door")
    # grade: exact + valid -> FAITHFUL; unstated comparator -> artifact.
    var exact = mcp_handle_line(
        call_line(
            "aesir_grade",
            "{\"rank\":0,\"gap_milli\":0,\"comparator_valid\":true}",
        ),
        s, f, False, "",
    )
    expect_in(exact.payload, "step EXACT", "grade exact step")
    expect_in(exact.payload, "verdict FAITHFUL", "grade faithful verdict")
    var unstated = mcp_handle_line(
        call_line("aesir_grade", "{\"rank\":1,\"gap_milli\":250}"),
        s, f, False, "",
    )
    expect_in(unstated.payload, "step NEAR_TIE", "grade near-tie step")
    expect_in(
        unstated.payload, "COMPARATOR_ARTIFACT", "unstated comparator verdict"
    )
    var inconsistent = mcp_handle_line(
        call_line(
            "aesir_grade",
            "{\"rank\":0,\"gap_milli\":5,\"comparator_valid\":true}",
        ),
        s, f, False, "",
    )
    expect_in(
        inconsistent.payload, "\"isError\":true", "inconsistent is tool error"
    )
    expect_in(inconsistent.payload, "grade refused", "inconsistent refused")
    var missing = mcp_handle_line(
        call_line("aesir_grade", "{\"rank\":1}"), s, f, False, ""
    )
    expect_in(missing.payload, "\"code\":-32602", "missing gap code")
    var negative = mcp_handle_line(
        call_line("aesir_grade", "{\"rank\":-1,\"gap_milli\":0}"),
        s, f, False, "",
    )
    expect_in(negative.payload, "\"code\":-32602", "negative rank code")
    # tokenize: validation, the unbound error, the bound verdict.
    var tok_missing = mcp_handle_line(
        call_line("aesir_tokenize", "{}"), s, f, False, ""
    )
    expect_in(tok_missing.payload, "\"code\":-32602", "tokenize missing code")
    var tok_unbound = mcp_handle_line(
        call_line("aesir_tokenize", "{\"text\":\"hello\"}"),
        s, f, False, "",
    )
    expect_true(tok_unbound.respond, "tokenize unbound responds")
    expect_false(tok_unbound.needs_tokenize, "unbound does not tokenize")
    expect_in(tok_unbound.payload, "\"isError\":true", "unbound tool error")
    expect_in(tok_unbound.payload, "no tokenizer is bound", "unbound reason")
    expect_true(
        mcp_no_tokenizer_reason().byte_length() > 100, "tokenizer reason len"
    )
    var tok_bound = mcp_handle_line(
        call_line("aesir_tokenize", "{\"text\":\"hello\"}"),
        s, f, True, "qwen3-0.6b:latest",
    )
    expect_false(tok_bound.respond, "bound tokenize waits for host")
    expect_true(tok_bound.needs_tokenize, "bound needs tokenize")
    expect_true(tok_bound.tok_text == "hello", "bound text carried")
    expect_true(tok_bound.gen_id_raw == "7", "bound tokenize id carried")
    var tok_done = mcp_tokenize_completion(tok_bound.gen_id_raw, "ids: [9707]")
    expect_in(tok_done, "\"isError\":false", "tokenize completion ok")
    expect_in(tok_done, "9707", "tokenize completion ids")
    var tok_failed = mcp_tokenize_failure(tok_bound.gen_id_raw, "no vocab")
    expect_in(tok_failed, "\"isError\":true", "tokenize failure is error")
    var tok_mismatch = mcp_handle_line(
        call_line(
            "aesir_tokenize", "{\"text\":\"hi\",\"model\":\"other\"}"
        ),
        s, f, True, "qwen3-0.6b:latest",
    )
    expect_in(tok_mismatch.payload, "qwen3-0.6b:latest", "tokenize bound named")
    # bench: the host-executed verdict + its completion envelope.
    var bench = mcp_handle_line(
        call_line("aesir_bench", "{}"), s, f, False, ""
    )
    expect_false(bench.respond, "bench waits for host")
    expect_true(bench.needs_bench, "bench needs host execution")
    expect_true(bench.gen_id_raw == "7", "bench id carried")
    var bench_done = mcp_bench_completion(bench.gen_id_raw, "REPORT")
    expect_in(bench_done, "\"isError\":false", "bench completion ok")
    expect_in(bench_done, "REPORT", "bench completion text")
    print("PASS: services dispatch (census, grade, tokenize, bench)")


def main() raises:
    test_scanner()
    test_classification()
    test_handshake_and_errors()
    test_tools_list()
    test_model_info()
    test_embed_refusal()
    test_generate_dispatch()
    test_services_dispatch()
    print("ALL PASS: mcp tools (8 groups)")
