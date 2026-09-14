"""Native recipe/explicit-CLI resolution before hardware planning."""
from core.sampling_config import NativeSamplingConfig
from core.sampling_options import with_sampling_option, sampling_uint
from cli.modelfile import parse_modelfile
from server.api import json_escape_string
from config import AesirConfig, load_config_file


def load_native_config(path: String, seen: List[String]) raises -> AesirConfig:
    """Resolve explicit selection only, rejecting ambiguity before file access."""
    if "--config" in seen:
        if "--model-store" in seen:
            raise Error("Native --config and --model-store are mutually exclusive")
        return load_config_file(path)
    return AesirConfig()


def native_config_sampling(config: AesirConfig) raises -> NativeSamplingConfig:
    """Admit only connected intent; keep neutral legacy schema fields inert."""
    if config.acceleration_backend != "auto" and config.acceleration_backend != "cuda":
        raise Error("Native configuration requires auto or cuda acceleration_backend")
    if config.target_npu != "auto" or config.num_gpu_layers != 0 or config.max_threads != 0:
        raise Error("Native configuration does not support target_npu, num_gpu_layers or max_threads overrides")
    if config.skaldbrodir_enabled or config.thinking_enabled:
        raise Error("Native configuration safety switches are not connected")
    if config.cia_enabled or config.wic_enabled or config.nsfi_enabled or config.mqari_enabled:
        raise Error("Native configuration experimental switches are not connected")
    if config.tui_enabled:
        raise Error("Native configuration tui_enabled is not connected; use chat --tui")
    var sampling = NativeSamplingConfig()
    if config.temperature_was_set:
        sampling.temperature = Float32(config.temperature)
        if config.temperature > 0 and sampling.temperature == 0:
            raise Error("Configuration temperature underflows native Float32")
    if config.top_p_was_set:
        sampling.top_p = Float32(config.top_p)
    sampling.validate()
    return sampling


struct NativeSettings(Copyable, ImplicitlyCopyable):
    var sampling: NativeSamplingConfig
    var context: Int
    var max_tokens: Int
    var system: String
    var has_system: Bool

    def __init__(out self, sampling: NativeSamplingConfig, context: Int,
                 max_tokens: Int, system: String, has_system: Bool):
        self.sampling = sampling
        self.context = context
        self.max_tokens = max_tokens
        self.system = system
        self.has_system = has_system


def native_recipe_count(value: String) raises -> Int:
    var count = sampling_uint(value)
    if count < 1 or count > 32768:
        raise Error("Native recipe context/reply count must be within 1..32768")
    return Int(count)


def resolve_native_settings(content: String, cli: NativeSamplingConfig,
        seen: List[String], context: Int, max_tokens: Int, system: String,
        config_sampling: NativeSamplingConfig = NativeSamplingConfig()) raises -> NativeSettings:
    cli.validate()
    config_sampling.validate()
    var result = NativeSettings(config_sampling, context, max_tokens, system, "--system" in seen)
    if content != "":
        var recipe = parse_modelfile(content, True)
        if recipe.system_prompt.byte_length() > 65536:
            raise Error("Native recipe system prompt exceeds 64 KiB")
        for name in recipe.parameters.keys():
            var value = recipe.parameters[name]
            if name == "num_ctx":
                var count = native_recipe_count(value)
                if count < 2:
                    raise Error("Native recipe context must leave input space")
                if "--context" not in seen:
                    result.context = count
            elif name == "num_predict":
                var count = native_recipe_count(value)
                if "--max-tokens" not in seen:
                    result.max_tokens = count
            elif name == "temperature" or name == "seed" or name == "top_k" or name == "top_p" or name == "min_p" or name == "repeat_penalty" or name == "repeat_last_n":
                result.sampling = with_sampling_option(result.sampling, name.replace("_", "-"), value)
            else:
                raise Error("Unsupported native recipe parameter: " + name)
        if recipe.system_was_set and "--system" not in seen:
            result.system = recipe.system_prompt
            result.has_system = True
    # Preserve explicit zero values without float-to-text roundtrips. Invalid
    # lower-priority recipe values still fail rather than hiding broken intent.
    if "--temperature" in seen:
        result.sampling.temperature = cli.temperature
    if "--top-k" in seen:
        result.sampling.top_k = cli.top_k
    if "--top-p" in seen:
        result.sampling.top_p = cli.top_p
    if "--min-p" in seen:
        result.sampling.min_p = cli.min_p
    if "--repeat-penalty" in seen:
        result.sampling.repetition_penalty = cli.repetition_penalty
    if "--repeat-last-n" in seen:
        result.sampling.repeat_last_n = cli.repeat_last_n
    if "--seed" in seen:
        result.sampling.seed = cli.seed
    result.sampling.validate()
    if result.system.byte_length() > 65536:
        raise Error("Native system prompt exceeds 64 KiB")
    if result.context != 0 and result.max_tokens >= result.context:
        raise Error("Effective context must leave room for input and reply")
    return result


def native_settings_json(settings: NativeSettings) -> String:
    var s = settings.sampling
    return ('{"schema_version":1,"stage":"before_hardware_planning",'
        + '"context_request":' + String(settings.context)
        + ',"max_tokens_request":' + String(settings.max_tokens)
        + ',"system_override":' + ("true" if settings.has_system else "false")
        + ',"system":"' + json_escape_string(settings.system) + '","sampling":{'
        + '"temperature":' + String(s.temperature) + ',"top_k":' + String(s.top_k)
        + ',"top_p":' + String(s.top_p) + ',"min_p":' + String(s.min_p)
        + ',"repeat_penalty":' + String(s.repetition_penalty)
        + ',"repeat_last_n":' + String(s.repeat_last_n) + ',"seed":' + String(s.seed) + '}}')
