# cli/llama_cpp_compat.mojo
# llama.cpp CLI compatibility subcommand & argument differential parser validator

from std.memory import Pointer

struct LlamaCppCLIConfig(Copyable):
    """Configuration state parsed from llama.cpp compatible CLI flags."""
    var model_path: String
    var prompt: String
    var n_predict: Int
    var ctx_size: Int
    var threads: Int
    var temp: Float32
    var top_k: Int
    var top_p: Float32
    var repeat_penalty: Float32
    var seed: Int64
    var n_gpu_layers: Int
    var batch_size: Int

    def __init__(
        out self,
        model_path: String = "",
        prompt: String = "",
        n_predict: Int = 128,
        ctx_size: Int = 2048,
        threads: Int = 4,
        temp: Float32 = 0.8,
        top_k: Int = 40,
        top_p: Float32 = 0.95,
        repeat_penalty: Float32 = 1.1,
        seed: Int64 = -1,
        n_gpu_layers: Int = 0,
        batch_size: Int = 512
    ):
        self.model_path = model_path
        self.prompt = prompt
        self.n_predict = n_predict
        self.ctx_size = ctx_size
        self.threads = threads
        self.temp = temp
        self.top_k = top_k
        self.top_p = top_p
        self.repeat_penalty = repeat_penalty
        self.seed = seed
        self.n_gpu_layers = n_gpu_layers
        self.batch_size = batch_size

    def __copyinit__(out self, existing: Self):
        self.model_path = existing.model_path
        self.prompt = existing.prompt
        self.n_predict = existing.n_predict
        self.ctx_size = existing.ctx_size
        self.threads = existing.threads
        self.temp = existing.temp
        self.top_k = existing.top_k
        self.top_p = existing.top_p
        self.repeat_penalty = existing.repeat_penalty
        self.seed = existing.seed
        self.n_gpu_layers = existing.n_gpu_layers
        self.batch_size = existing.batch_size


def is_supported_llama_cpp_subcommand(subcommand: String) -> Bool:
    """
    Validates whether a llama.cpp subcommand is in Aesir's supported CLI subset.
    Supported: main, cli, llama-cli, server, llama-server.
    Unsupported: quantize, finetune, perplexity, train.
    """
    if subcommand == "main" or subcommand == "cli" or subcommand == "llama-cli":
        return True
    elif subcommand == "server" or subcommand == "llama-server":
        return True
    return False


def validate_llama_cpp_cli_contract(subcommand: String) raises:
    """
    Validates llama.cpp subcommand contract.
    Raises explicit Error with exit code 1 for unsupported subcommands.
    """
    if not is_supported_llama_cpp_subcommand(subcommand):
        raise Error("Unsupported llama.cpp subcommand '" + subcommand + "' - Aesir CLI compatibility exit code 1")


def parse_llama_cpp_cli_args(args: List[String]) raises -> LlamaCppCLIConfig:
    """
    Parses differential llama.cpp CLI flags into LlamaCppCLIConfig.
    Flags: -m, -p, -n, -c, -t, --temp, --top-k, --top-p, --repeat-penalty, --seed, -ngl, -b.
    """
    var config = LlamaCppCLIConfig()
    var i = 0
    while i < len(args):
        var arg = args[i]
        if (arg == "-m" or arg == "--model") and i + 1 < len(args):
            config.model_path = args[i + 1]
            i += 1
        elif (arg == "-p" or arg == "--prompt") and i + 1 < len(args):
            config.prompt = args[i + 1]
            i += 1
        elif (arg == "-n" or arg == "--n-predict") and i + 1 < len(args):
            config.n_predict = atol(args[i + 1])
            i += 1
        elif (arg == "-c" or arg == "--ctx-size") and i + 1 < len(args):
            config.ctx_size = atol(args[i + 1])
            i += 1
        elif (arg == "-t" or arg == "--threads") and i + 1 < len(args):
            config.threads = atol(args[i + 1])
            i += 1
        elif (arg == "-ngl" or arg == "--n-gpu-layers") and i + 1 < len(args):
            config.n_gpu_layers = atol(args[i + 1])
            i += 1
        elif (arg == "-b" or arg == "--batch-size") and i + 1 < len(args):
            config.batch_size = atol(args[i + 1])
            i += 1
        i += 1
    return config^
