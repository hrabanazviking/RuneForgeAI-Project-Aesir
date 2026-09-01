# cli/llama_cpp_compat.mojo
# Explicit unavailable llama.cpp CLI compatibility boundary.

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
    _ = subcommand
    return False


def validate_llama_cpp_cli_contract(subcommand: String) raises:
    """
    Validates llama.cpp subcommand contract.
    Raises explicit Error with exit code 1 for unsupported subcommands.
    """
    _ = subcommand
    raise Error("llama.cpp CLI compatibility is not implemented")


def parse_llama_cpp_cli_args(args: List[String]) raises -> LlamaCppCLIConfig:
    """
    Reserved compatibility parser. Parsing a few similarly named flags without
    matching llama.cpp validation and behavior is not compatibility.
    """
    _ = args
    raise Error("llama.cpp CLI argument compatibility is not implemented")
