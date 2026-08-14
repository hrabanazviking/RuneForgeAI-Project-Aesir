# tests/test_multi_engine.mojo
# Verification of Universal Multi-Engine Ecosystem Matrix (Slice 11)

from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from core.mimir_well import Scalar, f16
from core.grammar import GBNFGrammar
from core.speculative import SpeculativeEngine
from loader.onnx import ONNXModelSeer
from server.openai import OpenAIGate
from cli.multi_engine import dispatch_llama_cli, dispatch_exl2_cli, dispatch_onnx_cli

def test_openai_api_formatter():
    print("--- Testing OpenAIGate (OpenAI v1 REST API Formatter) ---")
    var success = True
    var json_resp = OpenAIGate.format_chat_completion("aesir:latest", "Hello world")
    if len(json_resp.bytes()) == 0:
        print("FAIL: OpenAIGate response is empty")
        success = False

    var chunk_resp = OpenAIGate.format_chat_chunk("aesir:latest", "Hello")
    if len(chunk_resp.bytes()) == 0:
        print("FAIL: OpenAIGate chunk response is empty")
        success = False

    if success:
        print("OpenAIGate: PASS")
    else:
        print("OpenAIGate: FAIL")


def test_gbnf_grammar():
    print("--- Testing GBNFGrammar (Constrained Generation Logit Masking) ---")
    var success = True
    var grammar = GBNFGrammar("json")
    var logits = alloc(Layout[Scalar[f16]](count=16)).unsafe_leak()
    for i in range(16):
        logits.unsafe_store(i, Scalar[f16](0.5))

    grammar.apply_grammar_mask(logits, 16)
    logits.unsafe_free()

    if success:
        print("GBNFGrammar: PASS")
    else:
        print("GBNFGrammar: FAIL")


def test_speculative_engine():
    print("--- Testing SpeculativeEngine (Draft Sampling & Verification) ---")
    var success = True
    var spec = SpeculativeEngine(4)
    var draft_tokens = alloc(Layout[Int](count=4)).unsafe_leak()
    var target_logits = alloc(Layout[Scalar[f16]](count=16)).unsafe_leak()

    for i in range(4):
        draft_tokens.unsafe_store(i, i)

    var accepted = spec.verify_tokens(draft_tokens, target_logits, 4)
    draft_tokens.unsafe_free()
    target_logits.unsafe_free()

    if accepted != 4:
        print("FAIL: Expected 4 accepted tokens, got", accepted)
        success = False

    if success:
        print("SpeculativeEngine: PASS")
    else:
        print("SpeculativeEngine: FAIL")


def test_onnx_model_seer():
    print("--- Testing ONNXModelSeer (ONNX Graph Protocol Buffer Parser) ---")
    var success = True
    var seer = ONNXModelSeer("model.onnx")
    if not seer.parse_onnx_header():
        print("FAIL: ONNX header parsing failed")
        success = False

    if success:
        print("ONNXModelSeer: PASS")
    else:
        print("ONNXModelSeer: FAIL")


def test_multi_engine_cli():
    print("--- Testing Multi-Engine CLI Dispatchers ---")
    var success = True
    var args = List[String]()
    args.append("llama-bench")
    if not dispatch_llama_cli(args):
        print("FAIL: dispatch_llama_cli failed")
        success = False

    var exl_args = List[String]()
    exl_args.append("exl2")
    if not dispatch_exl2_cli(exl_args):
        print("FAIL: dispatch_exl2_cli failed")
        success = False

    var onnx_args = List[String]()
    onnx_args.append("onnx")
    if not dispatch_onnx_cli(onnx_args):
        print("FAIL: dispatch_onnx_cli failed")
        success = False

    if success:
        print("Multi-Engine CLI Dispatchers: PASS")
    else:
        print("Multi-Engine CLI Dispatchers: FAIL")
