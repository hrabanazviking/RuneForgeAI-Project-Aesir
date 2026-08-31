# cli/multi_engine.mojo
# Reserved multi-engine CLI surfaces

from std.sys import argv

def dispatch_llama_cli(args: List[String]) raises -> Bool:
    """
    ᛚᛚᚨᛗᚨ·ᚲᛚᛁ — Reserved llama-oriented Terminal Dispatcher (dispatch_llama_cli)
    ═════════════════════════════════════════════════════════════════════════════════════════════
    Preserves the public llama.cpp-oriented dispatcher name while rejecting the
    unimplemented compatibility surface.
    """
    if len(args) == 0:
        raise Error("CLI dispatcher arguments must not be empty")
    _ = args
    raise Error("llama.cpp CLI compatibility is not implemented")


def dispatch_exl2_cli(args: List[String]) raises -> Bool:
    """
    ᛖᚲᛋᛚᛗᚨ·ᚲᛚᛁ — The ExLlamaV2 / ExLlamaV3 Bitrate Dispatcher (dispatch_exl2_cli)
    ══════════════════════════════════════════════════════════════════════════════
    Preserves the public ExLlama dispatcher name while rejecting the
    unimplemented format/runtime surface.
    """
    if len(args) == 0:
        raise Error("CLI dispatcher arguments must not be empty")
    _ = args
    raise Error("ExLlama/EXL2 conversion and inference are not implemented")


def dispatch_onnx_cli(args: List[String]) raises -> Bool:
    """
    ᛟᚾᚾᛏ·ᚲᛚᛁ — The ONNX Runtime Graph Dispatcher (dispatch_onnx_cli)
    ══════════════════════════════════════════════════════════════════
    Preserves the public ONNX dispatcher name while rejecting the unimplemented
    parser/runtime surface.
    """
    if len(args) == 0:
        raise Error("CLI dispatcher arguments must not be empty")
    _ = args
    raise Error("ONNX CLI graph execution is not implemented")
