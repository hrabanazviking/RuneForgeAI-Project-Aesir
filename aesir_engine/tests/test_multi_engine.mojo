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
    json_escape_string,
    RequestContext,
    build_structured_error,
)
from cli.multi_engine import dispatch_llama_cli, dispatch_exl2_cli, dispatch_onnx_cli

def test_openai_api_formatter() raises:
    print("--- Testing OpenAIGate local JSON formatter scaffold ---")
    var success = True
    var json_resp = OpenAIGate.format_chat_completion("aesir:latest", "Hello world")
    if '"model": "aesir:latest"' not in json_resp or '"content": "Hello world"' not in json_resp:
        print("FAIL: OpenAIGate response omitted the supplied model or content")
        success = False
    if '"aesir_status": "formatter_scaffold"' not in json_resp:
        print("FAIL: OpenAIGate formatter omitted scaffold status")
        success = False
    if '"prompt_tokens": 0' not in json_resp or '"total_tokens": 0' not in json_resp:
        print("FAIL: OpenAIGate formatter invented token usage")
        success = False

    var chunk_resp = OpenAIGate.format_chat_chunk("aesir:latest", "Hello")
    if "data: {" not in chunk_resp or '"content": "Hello"' not in chunk_resp:
        print("FAIL: OpenAIGate chunk omitted its SSE prefix or supplied content")
        success = False
    if '"aesir_status": "formatter_scaffold"' not in chunk_resp:
        print("FAIL: OpenAIGate chunk omitted scaffold status")
        success = False

    var embedding_resp = OpenAIGate.format_embeddings("aesir:latest")
    if '"error": "unsupported"' not in embedding_resp:
        print("FAIL: embedding formatter invented vector data")
        success = False

    if success:
        print("OpenAIGate: PASS")
    else:
        raise Error("OpenAIGate formatter invariant mismatch")


def test_gbnf_grammar() raises:
    print("--- Testing toy GBNF-shaped odd-index mask scaffold ---")
    var success = True
    var grammar = GBNFGrammar("json")
    grammar.state = 1
    var logits = alloc(Layout[Scalar[f16]](count=16)).unsafe_leak()
    for i in range(16):
        logits.unsafe_store(i, Scalar[f16](0.5))

    grammar.apply_grammar_mask(logits, 16)
    for i in range(16):
        if i % 2 == 1 and logits.unsafe_load(i) != Scalar[f16](-65504.0):
            print("FAIL: GBNFGrammar did not mask odd token index", i)
            success = False
            break
        if i % 2 == 0 and logits.unsafe_load(i) != Scalar[f16](0.5):
            print("FAIL: GBNFGrammar changed allowed even token index", i)
            success = False
            break
    # Test sentinel pointer and non-positive vocab_size early return safety
    var sentinel_ptr = Pointer[Scalar[f16], MutUntrackedOrigin](unsafe_from_address=1)
    grammar.apply_grammar_mask(sentinel_ptr, 16)
    grammar.apply_grammar_mask(logits, 0)
    grammar.apply_grammar_mask(logits, -5)

    logits.unsafe_free()

    if success:
        print("GBNFGrammar: PASS")
    else:
        raise Error("GBNFGrammar scaffold masking invariant mismatch")


def test_speculative_engine() raises:
    print("--- Testing local speculative acceptance arithmetic scaffold ---")
    var success = True
    var spec = SpeculativeEngine(4)
    var draft_tokens = alloc(Layout[Int](count=4)).unsafe_leak()
    var target_logits = alloc(Layout[Scalar[f16]](count=16)).unsafe_leak()

    for i in range(4):
        draft_tokens.unsafe_store(i, i)
    for i in range(16):
        target_logits.unsafe_store(i, Scalar[f16](0.0))

    var accepted = spec.verify_tokens(draft_tokens, target_logits, 4)
    # Test sentinel pointer address and non-positive count early return safety
    var sentinel_draft = Pointer[Int, MutUntrackedOrigin](unsafe_from_address=1)
    var sentinel_logits = Pointer[Scalar[f16], MutUntrackedOrigin](unsafe_from_address=1)
    var s1 = spec.verify_tokens(sentinel_draft, target_logits, 4)
    var s2 = spec.verify_tokens(draft_tokens, sentinel_logits, 4)
    var s3 = spec.verify_tokens(draft_tokens, target_logits, 0)
    var s4 = spec.verify_tokens(draft_tokens, target_logits, -1)
    if s1 != 1 or s2 != 1 or s3 != 1 or s4 != 1:
        print("FAIL: SpeculativeEngine did not return 1 for sentinel pointers or non-positive count")
        success = False

    draft_tokens.unsafe_free()
    target_logits.unsafe_free()

    if accepted != 4:
        print("FAIL: Expected 4 accepted tokens, got", accepted)
        success = False

    if success:
        print("SpeculativeEngine: PASS")
    else:
        raise Error("SpeculativeEngine scaffold acceptance invariant mismatch")


def test_onnx_model_seer() raises:
    print("--- Testing honest ONNX unavailable state ---")
    var seer = ONNXModelSeer("model.onnx")
    if seer.ir_version != 0 or seer.num_nodes != 0 or seer.producer_name != "":
        raise Error("ONNX scaffold invented parsed model metadata")
    if seer.parse_onnx_header():
        raise Error("ONNX scaffold reported header parsing success")
    var well = MimirWell(1024)
    if seer.map_to_well(well):
        raise Error("ONNX scaffold reported tensor mapping success")
    print("honest ONNX unavailable state: PASS")


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
    if '"error":"unsupported"' not in unsupported:
        raise Error("known unsupported route omitted unsupported error body")
    if "200 OK" in unsupported or '"status":"ok"' in unsupported:
        raise Error("known unsupported route emitted success state")

    var missing = route_not_found_response()
    if "404 Not Found" not in missing:
        raise Error("unknown route omitted HTTP 404")
    if '"error":"route_not_found"' not in missing:
        raise Error("unknown route omitted not-found error body")

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
    if "HTTP/1.1 200 OK" not in response or '"object": "chat.completion"' not in response:
        raise Error("Route dispatcher failed to format OpenAI chat completion response for /v1/chat/completions")

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
    print("--- Testing OpenAI REST API Gateway (/v1/chat/completions, /v1/models, /v1/embeddings) ---")
    var models_req = parse_http_request("GET /v1/models HTTP/1.1\r\nHost: 127.0.0.1:18434\r\n\r\n")
    var models_resp = dispatch_http_request(models_req)
    if "HTTP/1.1 200 OK" not in models_resp or '"object": "list"' not in models_resp:
        raise Error("Route dispatcher failed on /v1/models: got " + models_resp)

    var emb_req = parse_http_request("POST /v1/embeddings HTTP/1.1\r\nHost: 127.0.0.1:18434\r\n\r\n")
    var emb_resp = dispatch_http_request(emb_req)
    if "HTTP/1.1 200 OK" not in emb_resp or '"error": "unsupported"' not in emb_resp:
        raise Error("Route dispatcher failed on /v1/embeddings: got " + emb_resp)

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
