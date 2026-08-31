# tests/test_multi_engine.mojo
# Verification of formatter scaffolds and unsupported ecosystem boundaries

from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from core.mimir_well import MimirWell, Scalar, f16
from core.grammar import GBNFGrammar
from core.speculative import SpeculativeEngine
from loader.onnx import ONNXModelSeer
from server.openai import OpenAIGate
from server.api import (
    BifrostGate,
    HTTPRequest,
    parse_http_request,
    dispatch_http_request,
    build_http_response,
    build_sse_chunk,
    build_http_chunk,
    write_all_bytes,
    unsupported_http_response,
    route_not_found_response,
    legacy_route_response,
    json_escape_string,
    RequestContext,
    build_structured_error,
)
from cli.multi_engine import dispatch_llama_cli, dispatch_exl2_cli, dispatch_onnx_cli

def test_openai_api_formatter() raises:
    print("--- Testing OpenAIGate local JSON formatter scaffold ---")
    var success = True
    var json_resp = OpenAIGate.format_chat_completion("aesir:latest", "Hello \"world\"\nnext")
    if "\"model\": \"aesir:latest\"" not in json_resp or "Hello \\\"world\\\"\\nnext" not in json_resp:
        print("FAIL: OpenAIGate response omitted the supplied model or content")
        success = False
    if "\"aesir_status\": \"formatter_scaffold\"" not in json_resp:
        print("FAIL: OpenAIGate formatter omitted status")
        success = False
    if "\"prompt_tokens\": 0" not in json_resp or "\"total_tokens\": 0" not in json_resp:
        print("FAIL: OpenAIGate formatter invented token usage")
        success = False
    if "1700000000" in json_resp or "chatcmpl-aesir-v1" in json_resp:
        print("FAIL: OpenAIGate formatter retained fictional identity or time")
        success = False

    var chunk_resp = OpenAIGate.format_chat_chunk("aesir:latest", "Hello")
    if "data: {" not in chunk_resp or "\"content\": \"Hello\"" not in chunk_resp:
        print("FAIL: OpenAIGate chunk omitted its SSE prefix or supplied content")
        success = False
    if "\"aesir_status\": \"formatter_scaffold\"" not in chunk_resp:
        print("FAIL: OpenAIGate chunk omitted status")
        success = False

    var embedding_resp = OpenAIGate.format_embeddings("aesir:latest")
    if "\"error\": \"unsupported\"" not in embedding_resp:
        print("FAIL: embedding formatter invented vector data")
        success = False

    if success:
        print("OpenAIGate: PASS")
    else:
        raise Error("OpenAIGate formatter invariant mismatch")


def test_gbnf_grammar() raises:
    print("--- Testing fail-closed legacy grammar boundary ---")
    var grammar = GBNFGrammar("json")
    var logits = alloc(Layout[Scalar[f16]](count=16)).unsafe_leak()
    for i in range(16):
        logits.unsafe_store(i, Scalar[f16](0.5))
    var rejected = False
    try:
        grammar.apply_grammar_mask(logits, 16)
    except error:
        rejected = "decoded token text is required" in String(error)
    if not rejected:
        raise Error("legacy token-ID-only grammar mask did not fail closed")
    for i in range(16):
        if logits.unsafe_load(i) != Scalar[f16](0.5):
            raise Error("rejected grammar request mutated caller logits")
    logits.unsafe_free()
    print("fail-closed legacy grammar boundary: PASS")


def test_speculative_engine() raises:
    print("--- Testing fail-closed legacy speculative boundary ---")
    var spec = SpeculativeEngine(4)
    var draft_tokens = alloc(Layout[Int](count=4)).unsafe_leak()
    var target_logits = alloc(Layout[Scalar[f16]](count=16)).unsafe_leak()

    for i in range(4):
        draft_tokens.unsafe_store(i, i)
    for i in range(16):
        target_logits.unsafe_store(i, Scalar[f16](0.0))

    var rejected = False
    try:
        _ = spec.verify_tokens(draft_tokens, target_logits, 4)
    except error:
        rejected = "unsupported" in String(error)
    draft_tokens.unsafe_free()
    target_logits.unsafe_free()
    if not rejected:
        raise Error("legacy speculative pointer contract did not fail closed")
    print("fail-closed legacy speculative boundary: PASS")


def test_onnx_model_seer() raises:
    print("--- Testing honest ONNX execution boundary ---")
    var seer = ONNXModelSeer("model.onnx")
    if seer.ir_version != 0 or seer.num_nodes != 0 or seer.producer_name != "":
        raise Error("ONNX parser invented model metadata before parsing")
    var well = MimirWell(1024)
    var mapping_rejected = False
    try:
        _ = seer.map_to_well(well)
    except error:
        mapping_rejected = True
        if "not implemented" not in String(error):
            raise Error("ONNX mapping rejection omitted stable boundary text")
    if not mapping_rejected:
        raise Error("ONNX parser reported tensor mapping success")
    print("honest ONNX execution boundary: PASS")


def test_multi_engine_cli() raises:
    print("--- Testing unsupported multi-engine CLI dispatchers ---")
    var args = List[String]()
    args.append("llama-bench")
    # Test empty args list parameter rejection
    var empty_args = List[String]()
    var empty_dispatch_rejected = False
    try:
        _ = dispatch_llama_cli(empty_args)
    except error:
        empty_dispatch_rejected = True
        if "must not be empty" not in String(error):
            raise Error("llama empty dispatch rejection omitted empty error text")
    if not empty_dispatch_rejected:
        raise Error("dispatch_llama_cli allowed empty args parameter")

    var llama_rejected = False
    try:
        _ = dispatch_llama_cli(args)
    except error:
        llama_rejected = True
        if "not implemented" not in String(error):
            raise Error("llama.cpp rejection omitted stable truth text")
    if not llama_rejected:
        raise Error("llama.cpp dispatcher returned fabricated success")

    var exl_args = List[String]()
    exl_args.append("exl2")
    var exl_rejected = False
    try:
        _ = dispatch_exl2_cli(exl_args)
    except error:
        exl_rejected = True
        if "not implemented" not in String(error):
            raise Error("ExLlama rejection omitted stable truth text")
    if not exl_rejected:
        raise Error("ExLlama dispatcher returned fabricated success")

    var onnx_args = List[String]()
    onnx_args.append("onnx")
    var onnx_rejected = False
    try:
        _ = dispatch_onnx_cli(onnx_args)
    except error:
        onnx_rejected = True
        if "not implemented" not in String(error):
            raise Error("ONNX rejection omitted stable truth text")
    if not onnx_rejected:
        raise Error("ONNX dispatcher returned fabricated success")

    print("unsupported multi-engine CLI dispatchers: PASS")


def test_unsupported_http_responses() raises:
    print("--- Testing honest unsupported HTTP responses ---")
    var unsupported = unsupported_http_response("OpenAI API execution")
    if "501 Not Implemented" not in unsupported:
        raise Error("known unsupported route omitted HTTP 501")
    if "\"error\":\"unsupported\"" not in unsupported:
        raise Error("known unsupported route omitted unsupported error body")
    if "200 OK" in unsupported or "\"status\":\"ok\"" in unsupported:
        raise Error("known unsupported route emitted success state")

    var missing = route_not_found_response()
    if "404 Not Found" not in missing:
        raise Error("unknown route omitted HTTP 404")
    if "\"error\":\"route_not_found\"" not in missing:
        raise Error("unknown route omitted not-found error body")

    var legacy_paths: List[String] = [
        "/health", "/v1/models", "/api/tags",
        "/v1/chat/completions", "/api/chat", "/api/generate",
    ]
    for path in legacy_paths:
        var response = legacy_route_response(path)
        if "501 Not Implemented" not in response:
            raise Error("legacy compatibility route omitted HTTP 501: " + path)
        if "200 OK" in response or "\"status\":\"ok\"" in response:
            raise Error("legacy compatibility route fabricated success: " + path)
    if "404 Not Found" not in legacy_route_response("/not-a-route"):
        raise Error("legacy compatibility router accepted an unknown path")

    print("honest unsupported HTTP responses: PASS")


def test_posix_socket_server() raises:
    print("--- Testing bare-metal POSIX socket bind/listen setup & options ---")
    # Test invalid port bounds rejection
    var invalid_port_rejected = False
    try:
        var bad_server = BifrostGate(0)
    except error:
        invalid_port_rejected = True
        if "between 1 and 65535" not in String(error):
            raise Error("invalid port rejection omitted expected error text")
    if not invalid_port_rejected:
        raise Error("BifrostGate allowed port 0 initialization")

    var server = BifrostGate(18434)
    if not server.is_valid():
        raise Error("BifrostGate socket creation failed: invalid file descriptor")
    if not server.set_nonblocking(True):
        server.close()
        raise Error("BifrostGate non-blocking option configuration failed")
    if not server.start():
        server.close()
        raise Error("BifrostGate start listening failed")
    server.close()
    if server.is_valid():
        raise Error("BifrostGate close failed to reset file descriptor")
    print("bare-metal POSIX socket bind/listen setup & options: PASS")


def test_http_parser_and_router() raises:
    print("--- Testing HTTP/1.1 request parser & route dispatcher ---")
    # Test empty HTTP request line rejection
    var empty_req_rejected = False
    try:
        _ = parse_http_request("")
    except error:
        empty_req_rejected = True
        if "Empty HTTP request" not in String(error):
            raise Error("empty HTTP request rejection omitted expected error text")
    if not empty_req_rejected:
        raise Error("parse_http_request allowed empty request string")

    var raw_post = (
        "POST /v1/chat/completions HTTP/1.1\r\n"
        + "Host: 127.0.0.1:11434\r\n"
        + "Content-Type: application/json\r\n"
        + "Content-Length: 26\r\n\r\n"
        + "{\"model\":\"aesir\",\"prompt\":\"hi\"}"
    )
    var req = parse_http_request(raw_post)
    if req.method != "POST":
        raise Error("HTTP parser failed to extract POST method: got " + req.method)
    if req.path != "/v1/chat/completions":
        raise Error("HTTP parser failed to extract path: got " + req.path)
    if req.content_length != 26:
        raise Error("HTTP parser failed to extract Content-Length: got " + String(req.content_length))
    if req.body != "{\"model\":\"aesir\",\"prompt\":\"hi\"}":
        raise Error("HTTP parser failed to extract body: got " + req.body)

    var response = dispatch_http_request(req)
    if "501 Not Implemented" not in response or "\"error\":\"unsupported\"" not in response:
        raise Error("Route dispatcher fabricated OpenAI inference success")

    var raw_unknown = "GET /unknown/path HTTP/1.1\r\nHost: localhost\r\n\r\n"
    var unknown_req = parse_http_request(raw_unknown)
    var unknown_resp = dispatch_http_request(unknown_req)
    if "404 Not Found" not in unknown_resp:
        raise Error("Route dispatcher failed to return HTTP 404 for unknown path")

    print("HTTP/1.1 request parser & route dispatcher: PASS")


def test_http_response_framing() raises:
    print("--- Testing HTTP/1.1 response framing & streaming utilities ---")
    var resp = build_http_response(200, "OK", "application/json", "{\"status\":\"ok\"}")
    if "HTTP/1.1 200 OK" not in resp:
        raise Error("build_http_response omitted status line")
    if "Content-Length: 15" not in resp:
        raise Error("build_http_response computed wrong Content-Length")
    if "Connection: close" not in resp:
        raise Error("build_http_response omitted Connection header")

    var sse = build_sse_chunk("message", "{\"text\":\"hi\"}")
    if "event: message\ndata: {\"text\":\"hi\"}\n\n" not in sse:
        raise Error("build_sse_chunk formatted invalid SSE event")

    var chunk = build_http_chunk("hello")
    if "5\r\nhello\r\n" not in chunk:
        raise Error("build_http_chunk formatted invalid chunked block")

    var term_chunk = build_http_chunk("")
    if term_chunk != "0\r\n\r\n":
        raise Error("build_http_chunk failed to format terminal chunked block")

    if write_all_bytes(-1, "data"):
        raise Error("write_all_bytes reported success on invalid file descriptor -1")

    print("HTTP/1.1 response framing & streaming utilities: PASS")


def test_openai_rest_gateway() raises:
    print("--- Testing fail-closed OpenAI REST compatibility boundaries ---")
    var models_req = parse_http_request("GET /v1/models HTTP/1.1\r\nHost: 127.0.0.1:18434\r\n\r\n")
    var models_resp = dispatch_http_request(models_req)
    if "501 Not Implemented" not in models_resp or "\"error\":\"unsupported\"" not in models_resp:
        raise Error("Route dispatcher fabricated model catalog success: got " + models_resp)

    var emb_req = parse_http_request("POST /v1/embeddings HTTP/1.1\r\nHost: 127.0.0.1:18434\r\n\r\n")
    var emb_resp = dispatch_http_request(emb_req)
    if "501 Not Implemented" not in emb_resp or "\"error\":\"unsupported\"" not in emb_resp:
        raise Error("Route dispatcher fabricated embeddings success: got " + emb_resp)

    print("OpenAI REST API Gateway: PASS")

def test_json_escape_string() raises:
    print("--- Testing JSON string escaper for quotes, backslashes, tabs, and newlines ---")
    var raw = String("hello \"world\"\nnext\\line\ttab")
    var escaped = json_escape_string(raw)
    if "\\\"world\\\"" not in escaped or "\\nnext\\\\line\\ttab" not in escaped:
        raise Error("json_escape_string failed to escape special characters: got '" + escaped + "'")
    print("JSON string escaper: PASS")

def test_request_context_and_structured_errors() raises:
    print("--- Testing RequestContext & Structured Error Formatting ---")
    var ctx = RequestContext("req-12345", "sess-abc", 5000)
    if ctx.request_id != "req-12345" or ctx.session_id != "sess-abc":
        raise Error("RequestContext property initialization mismatch")
    if ctx.is_cancelled:
        raise Error("RequestContext must default to is_cancelled = False")
    ctx.cancel()
    if not ctx.is_cancelled:
        raise Error("RequestContext cancel() must set is_cancelled = True")

    var err_json = build_structured_error(400, "invalid_request", "Missing prompt parameter", "req-12345")
    if '"code":400' not in err_json or '"type":"invalid_request"' not in err_json or '"request_id":"req-12345"' not in err_json:
        raise Error("build_structured_error formatted invalid JSON error payload: got '" + err_json + "'")
    print("RequestContext & Structured Error Formatting: PASS")

def main() raises:
    test_openai_api_formatter()
    test_gbnf_grammar()
    test_speculative_engine()
    test_onnx_model_seer()
    test_multi_engine_cli()
    test_unsupported_http_responses()
    test_posix_socket_server()
    test_http_parser_and_router()
    test_http_response_framing()
    test_openai_rest_gateway()
    test_json_escape_string()
    test_request_context_and_structured_errors()
