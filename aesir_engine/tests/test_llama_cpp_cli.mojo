# tests/test_llama_cpp_cli.mojo
# Verification of llama.cpp CLI subcommand & argument differential parser validator

from cli.llama_cpp_compat import (
    LlamaCppCLIConfig,
    is_supported_llama_cpp_subcommand,
    validate_llama_cpp_cli_contract,
    parse_llama_cpp_cli_args,
)

def test_llama_cpp_subcommands() raises:
    print("--- Testing unavailable llama.cpp subcommand boundary ---")
    for command in ["main", "cli", "llama-cli", "server", "llama-server", "quantize"]:
        if is_supported_llama_cpp_subcommand(command):
            raise Error("llama.cpp compatibility reported a supported subcommand")
        var rejected = False
        try:
            validate_llama_cpp_cli_contract(command)
        except error:
            rejected = "not implemented" in String(error)
        if not rejected:
            raise Error("llama.cpp contract did not reject subcommand: " + command)
    print("unavailable llama.cpp subcommand boundary: PASS")


def test_llama_cpp_arg_parsing() raises:
    print("--- Testing unavailable llama.cpp argument parser ---")
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

    var rejected = False
    try:
        _ = parse_llama_cpp_cli_args(args)
    except error:
        rejected = "not implemented" in String(error)
    if not rejected:
        raise Error("detached llama.cpp-like flag parser reported compatibility")
    print("unavailable llama.cpp argument parser: PASS")


def main() raises:
    test_llama_cpp_subcommands()
    test_llama_cpp_arg_parsing()
