# tests/test_multi_engine.mojo
# Verification of formatter scaffolds and unsupported ecosystem boundaries

from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from core.mimir_well import MimirWell, Scalar, f16
from core.grammar import GBNFGrammar
from core.speculative import SpeculativeEngine
from loader.onnx import ONNXModelSeer
from server.openai import OpenAIGate
from server.api import unsupported_http_response, route_not_found_response
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
