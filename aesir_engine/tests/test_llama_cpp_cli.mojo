# tests/test_llama_cpp_cli.mojo
# Verification of llama.cpp CLI subcommand & argument differential parser validator

from cli.llama_cpp_compat import (
    LlamaCppCLIConfig,
    is_supported_llama_cpp_subcommand,
    validate_llama_cpp_cli_contract,
    parse_llama_cpp_cli_args,
)

def test_llama_cpp_subcommands() raises:
    print("--- Testing llama.cpp Subcommand Subset ---")
    if not is_supported_llama_cpp_subcommand("main"):
        raise Error("main should be supported in llama.cpp CLI subset")
    if not is_supported_llama_cpp_subcommand("llama-cli"):
        raise Error("llama-cli should be supported in llama.cpp CLI subset")
    if not is_supported_llama_cpp_subcommand("llama-server"):
        raise Error("llama-server should be supported in llama.cpp CLI subset")

    # Verify unsupported subcommand rejection
    if is_supported_llama_cpp_subcommand("quantize"):
        raise Error("quantize subcommand should NOT be supported")
    if is_supported_llama_cpp_subcommand("perplexity"):
        raise Error("perplexity subcommand should NOT be supported")

    var rejected = False
    try:
        validate_llama_cpp_cli_contract("perplexity")
    except:
        rejected = True
    if not rejected:
        raise Error("validate_llama_cpp_cli_contract failed to reject unsupported subcommand")

    print("llama.cpp subcommand subset: PASS")


def test_llama_cpp_arg_parsing() raises:
    print("--- Testing llama.cpp Differential CLI Argument Parser ---")
    var args = List[String]()
    args.append("-m")
    args.append("models/llama-3-8b.gguf")
    args.append("-p")
    args.append("Hello Aesir")
    args.append("-n")
    args.append("256")
    args.append("-c")
    args.append("4096")
    args.append("-t")
    args.append("8")
    args.append("-ngl")
    args.append("32")

    var config = parse_llama_cpp_cli_args(args)
    if config.model_path != "models/llama-3-8b.gguf":
        raise Error("model_path mismatch")
    if config.prompt != "Hello Aesir":
        raise Error("prompt mismatch")
    if config.n_predict != 256:
        raise Error("n_predict mismatch")
    if config.ctx_size != 4096:
        raise Error("ctx_size mismatch")
    if config.threads != 8:
        raise Error("threads mismatch")
    if config.n_gpu_layers != 32:
        raise Error("n_gpu_layers mismatch")

    print("llama.cpp differential CLI argument parser: PASS")


def main() raises:
    test_llama_cpp_subcommands()
    test_llama_cpp_arg_parsing()
