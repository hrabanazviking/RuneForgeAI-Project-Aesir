"""Pure bounded-protocol adversarial checks; physical service tests are separate."""
from server.local_protocol import FlatJSON, LocalHTTPHead, valid_utf8, resolve_request_token_limit, require_loaded_context
from cli.native_serve import GenerateRequest, local_response
from server.local_transport import c_path_bytes
from server.ollama import OllamaRequest, OllamaModelInfo, ollama_tags, ollama_catalog_tags, ollama_show, ollama_ps, ollama_generate_chunk, ollama_chat_chunk
from server.openai import OpenAIRequest, OpenAIGate
from core.sampling_config import NativeSamplingConfig
from cli.sampling import with_sampling_option
from cli.native_settings import resolve_native_settings, native_config_sampling
from config import parse_config_json


def test_local_path_bounds() raises:
    var bytes = c_path_bytes("Halló")
    if len(bytes) != 7 or bytes[6] != 0 or UInt8(bytes[4]) != 195 or UInt8(bytes[5]) != 179:
        raise Error("Native C path lost UTF-8 or terminator")
    var long_path = String("")
    for _ in range(4096):
        long_path += "x"
    var cases: List[String] = ["", "bad\0path", long_path]
    for path in cases:
        var rejected = False
        try:
            _ = c_path_bytes(path)
        except:
            rejected = True
        if not rejected:
            raise Error("Invalid native path accepted")


def test_local_json() raises:
    var parser = FlatJSON(" {\"prompt\":\"Halló \\uD83C\\uDF0A\\n\",\"max_tokens\":32} ")
    var fields = parser.fields()
    if len(fields) != 2 or fields[0].value != "Halló 🌊\n" or fields[1].value != "32":
        raise Error("JSON decoding failed")
    var cases: List[String] = ["{\"x\":01}", "{\"x\":+1}", "{\"x\":1.}", "{\"x\":1e}", "{\"x\":NaN}", "{\"x\":{}}", "{\"x\":1,\"x\":2}", "{\"x\":1,}", "{}{}", "{\"x\":\"\\uD800\"}", "{\"x\":\"\\uDC00\"}", "{\"x\":\"\\u0000\"}", "{\"x\":\"a\n\"}", "{\"x\":\"\\q\"}", "{\"x\":\""]
    for source in cases:
        var rejected = False
        try:
            var invalid = FlatJSON(source)
            _ = invalid.fields()
        except:
            rejected = True
        if not rejected:
            raise Error("Malformed JSON accepted")
    var generate = OllamaRequest("{\"model\":\"gemma4-e2b:latest\",\"prompt\":\"Halló\",\"stream\":false,\"options\":{\"num_ctx\":16384,\"temperature\":0.7,\"top_k\":20,\"top_p\":0.9,\"min_p\":0.05,\"seed\":42,\"repeat_penalty\":1.1}}")
    if generate.model != "gemma4-e2b:latest" or generate.prompt != "Halló" or generate.stream or generate.num_ctx != 16384 or generate.sampling.top_k != 20:
        raise Error("Ollama generate request parsing failed")
    var chat = OllamaRequest("{\"model\":\"gemma4-e2b\",\"stream\":false,\"messages\":[{\"role\":\"system\",\"content\":\"Be brief.\"},{\"role\":\"user\",\"content\":\"Hello\"},{\"role\":\"assistant\",\"content\":\"Hi\"},{\"role\":\"user\",\"content\":\"Offline?\"}]}")
    if not chat.has_messages or chat.system != "Be brief." or "Assistant: Hi" not in chat.chat_prompt or not chat.chat_prompt.endswith("User: Offline?\n"):
        raise Error("Ollama chat request parsing failed")
    var openai_chat = OpenAIRequest("{\"model\":\"gemma4-e2b\",\"stream\":true,\"max_tokens\":32,\"temperature\":0.7,\"top_p\":0.9,\"messages\":[{\"role\":\"system\",\"content\":\"Be brief.\"},{\"role\":\"user\",\"content\":\"Offline?\"}]}")
    if (not openai_chat.has_messages or not openai_chat.stream
            or openai_chat.max_tokens != 32
            or openai_chat.system != "Be brief."
            or not openai_chat.chat_prompt.endswith("User: Offline?\n")):
        raise Error("OpenAI chat request parsing failed")
    var openai_models = List[String]()
    openai_models.append("gemma4-e2b:latest")
    openai_models.append("qwen:latest")
    var openai_catalog = OpenAIGate.format_model_catalog(openai_models, 1789130000)
    if "gemma4-e2b:latest" not in openai_catalog or "qwen:latest" not in openai_catalog:
        raise Error("OpenAI catalog response omitted a model")
    var info = OllamaModelInfo("gemma4-e2b:latest", "sha256:abc", 3106738272, "Q4_K_M", "2026-09-09T00:00:00Z", "FROM gemma", "gemma4", "2B")
    if "gemma4-e2b:latest" not in ollama_tags(info) or "num_ctx 16384" not in ollama_show(info, 16384):
        raise Error("Ollama model response serialization failed")
    var running = ollama_ps(info, 3323822692, 16384)
    if "\"size_vram\":3323822692" not in running or "\"context_length\":16384" not in running:
        raise Error("Ollama running-model response serialization failed")
    if ("\"response\":\"Halló\",\"done\":false" not in ollama_generate_chunk(info.name, "Halló")
            or "\"content\":\"Halló\"" not in ollama_chat_chunk(info.name, "Halló")):
        raise Error("Ollama incremental record serialization failed")
    var catalog = List[OllamaModelInfo]()
    catalog.append(info)
    catalog.append(OllamaModelInfo("qwen:latest", "sha256:def", 495107776, "Q6_K", "2026-09-11T00:00:00Z", "FROM qwen", "qwen3", "0.6B"))
    var tags = ollama_catalog_tags(catalog)
    if "gemma4-e2b:latest" not in tags or "qwen:latest" not in tags:
        raise Error("Ollama catalog tags omitted an installed model")
    var ollama_cases: List[String] = [
        "{\"model\":\"m\",\"messages\":[]}",
        "{\"model\":\"m\",\"messages\":[{\"role\":\"assistant\",\"content\":\"x\"}]}",
        "{\"model\":\"m\",\"options\":{\"mirostat\":1}}",
        "{\"model\":\"m\",\"stream\":null}",
        "{\"model\":\"m\",\"messages\":[{\"role\":\"tool\",\"content\":\"x\"}]}",
    ]
    for source in ollama_cases:
        var rejected = False
        try:
            _ = OllamaRequest(source)
        except:
            rejected = True
        if not rejected:
            raise Error("Unsupported Ollama JSON accepted")


def test_local_http() raises:
    var key = String("test-key")
    var head = String("POST /v1/generate HTTP/1.1\r\nHost: 127.0.0.1:18434\r\nAuthorization: Bearer test-key\r\nContent-Type: application/json\r\nContent-Length: 16\r\n\r\n")
    var accepted = LocalHTTPHead(head, 18434, key)
    if accepted.status != 200 or accepted.length != 16:
        raise Error("Valid local request rejected")
    if LocalHTTPHead(head, 18434, "wrong-key").status != 401:
        raise Error("Wrong key accepted")
    if LocalHTTPHead(head.replace("Authorization: Bearer test-key\r\n", ""), 18434, "", False).status != 200:
        raise Error("Explicit loopback compatibility mode still required authentication")
    if LocalHTTPHead(head, 18435, key).status != 403:
        raise Error("Untrusted Host accepted")
    var cases: List[String] = ["GET / HTTP/1.0\r\n\r\n", "GET / HTTP/1.1\n\n", "GET / HTTP/1.1\r\nHost: a\r\nHost: b\r\n\r\n", "GET / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n", "GET / HTTP/1.1\r\n X: folded\r\n\r\n", "GET / HTTP/1.1\r\nContent-Length: -1\r\n\r\n", "GET / HTTP/1.1\r\nX: a\nInjected: b\r\n\r\n"]
    for source in cases:
        var rejected = False
        try:
            _ = LocalHTTPHead(source, 18434, key)
        except:
            rejected = True
        if not rejected:
            raise Error("Malformed HTTP accepted")
    var stream_response = local_response(
        200, "{\"done\":true}\n", True, "application/x-ndjson"
    )
    if "Content-Type: application/x-ndjson" not in stream_response:
        raise Error("Ollama streaming response lost its NDJSON media type")


def main() raises:
    test_local_json()
    test_local_http()
    test_local_generation_request()
    test_local_path_bounds()
    print("PASS bounded JSON and HTTP rejection")


def test_sampling_default_precedence() raises:
    var baselines = List[NativeSamplingConfig]()
    baselines.append(NativeSamplingConfig())
    baselines.append(NativeSamplingConfig(0.8, 12, 0.7, 0.1, 1.2, 128, 99))
    baselines.append(NativeSamplingConfig(1, 256, 1, 1, 0.5, 8192, UInt64(18446744073709551615)))
    var names: List[String] = ["temperature", "top_p", "seed", "top_k", "min_p", "repeat_penalty"]
    var cli_names: List[String] = ["temperature", "top-p", "seed", "top-k", "min-p", "repeat-penalty"]
    var values: List[String] = ["0", "0.5", "0", "20", "0.25", "1.1"]
    for baseline in baselines:
        var original = baseline.description()
        for index in range(len(names)):
            var field = "\"" + names[index] + "\":" + values[index]
            var expected = with_sampling_option(baseline, cli_names[index], values[index])
            var native = GenerateRequest("{\"prompt\":\"x\"," + field + "}", 64, 1000, baseline)
            var ollama = OllamaRequest("{\"model\":\"m\",\"prompt\":\"x\",\"options\":{" + field + "}}", baseline)
            if native.sampling.description() != expected.description() or ollama.sampling.description() != expected.description():
                raise Error("CLI/native/Ollama sampling precedence differs: " + names[index])
            if index < 3:
                var openai = OpenAIRequest("{\"model\":\"m\",\"prompt\":\"x\"," + field + "}", baseline)
                if openai.sampling.description() != expected.description():
                    raise Error("CLI/OpenAI sampling precedence differs: " + names[index])
            else:
                var rejected = False
                try:
                    _ = OpenAIRequest("{\"model\":\"m\",\"prompt\":\"x\"," + field + "}", baseline)
                except:
                    rejected = True
                if not rejected:
                    raise Error("OpenAI accepted an unsupported sampling field")
        var native = GenerateRequest("{\"prompt\":\"next\"}", 64, 1000, baseline)
        var ollama = OllamaRequest("{\"model\":\"m\",\"prompt\":\"next\"}", baseline)
        var openai = OpenAIRequest("{\"model\":\"m\",\"prompt\":\"next\"}", baseline)
        if native.sampling.description() != original or ollama.sampling.description() != original or openai.sampling.description() != original or baseline.description() != original:
            raise Error("Request sampling leaked into immutable defaults or later requests")
    for adapter in range(3):
        var invalid = NativeSamplingConfig()
        invalid.top_k = 0
        var rejected = False
        try:
            if adapter == 0:
                _ = GenerateRequest("{\"prompt\":\"x\"}", 64, 1000, invalid)
            elif adapter == 1:
                _ = OllamaRequest("{\"model\":\"m\"}", invalid)
            else:
                _ = OpenAIRequest("{\"model\":\"m\"}", invalid)
        except:
            rejected = True
        if not rejected:
            raise Error("Invalid service sampling defaults accepted")
        rejected = False
        try:
            if adapter == 0:
                _ = GenerateRequest("{\"prompt\":\"x\",\"repeat_last_n\":12}", 64, 1000)
            elif adapter == 1:
                _ = OllamaRequest("{\"model\":\"m\",\"options\":{\"repeat_last_n\":12}}")
            else:
                _ = OpenAIRequest("{\"model\":\"m\",\"repeat_last_n\":12}")
        except:
            rejected = True
        if not rejected:
            raise Error("Request changed session-owned repetition window")


def test_local_generation_request() raises:
    if GenerateRequest('{"prompt":"x"}', 512, 1000).max_tokens != 512:
        raise Error("Native request ignored the resolved service reply default above 256")
    test_request_limit_precedence()
    test_sampling_default_precedence()
    test_native_recipe_precedence()
    var valid = GenerateRequest("{\"prompt\":\"Halló 🌊\",\"seed\":18446744073709551615,\"max_tokens\":16}", 64, 1000)
    if valid.prompt != "Halló 🌊" or valid.sampling.seed != UInt64(18446744073709551615) or valid.max_tokens != 16:
        raise Error("Native generation request lost text or integer precision")
    if not GenerateRequest('{"prompt":"x","stream":true}', 64, 1000).stream:
        raise Error("Native generation streaming flag was not accepted")
    if GenerateRequest('{"prompt":"x","stream":false}', 64, 1000).stream:
        raise Error("Native generation false streaming flag was not preserved")
    var cases: List[String] = [
        "{}", "{\"prompt\":1}", "{\"prompt\":\"\"}", "{\"prompt\":\"x\",\"seed\":18446744073709551616}",
        "{\"prompt\":\"x\",\"max_tokens\":0}", "{\"prompt\":\"x\",\"max_tokens\":65}",
        "{\"prompt\":\"x\",\"timeout_ms\":0}", "{\"prompt\":\"x\",\"timeout_ms\":1001}",
        "{\"prompt\":\"x\",\"top_k\":257}", "{\"prompt\":\"x\",\"top_p\":0}",
        "{\"prompt\":\"x\",\"stream\":1}", "{\"prompt\":\"x\",\"temperature\":\"0.8\"}",
        "{\"prompt\":\"x\",\"unknown\":1}", "{\"prompt\":\"x\",\"temperature\":-1}",
    ]
    for body in cases:
        var rejected = False
        try:
            _ = GenerateRequest(body, 64, 1000)
        except:
            rejected = True
        if not rejected:
            raise Error("Unsupported generation request accepted")


def test_request_limit_precedence() raises:
    var ceilings: List[Int] = [1, 64, 256, 512, 32768]
    for ceiling in ceilings:
        var requests: List[Int] = [0, 1, ceiling]
        for requested in requests:
            var native_body = String('{"prompt":"x"')
            var openai_body = String('{"model":"m","prompt":"x"')
            var ollama_body = String('{"model":"m","prompt":"x"')
            if requested != 0:
                native_body += ',"max_tokens":' + String(requested)
                openai_body += ',"max_tokens":' + String(requested)
                ollama_body += ',"options":{"num_predict":' + String(requested) + '}'
            var native = GenerateRequest(native_body + '}', ceiling, 1000)
            var openai = OpenAIRequest(openai_body + '}')
            var ollama = OllamaRequest(ollama_body + '}')
            var expected = ceiling if requested == 0 else requested
            if native.max_tokens != expected or resolve_request_token_limit(openai.max_tokens, ceiling) != expected or resolve_request_token_limit(ollama.num_predict, ceiling) != expected:
                raise Error("Request token precedence differs across native/OpenAI/Ollama")
        for adapter in range(3):
            var rejected = False
            try:
                if adapter == 0:
                    _ = GenerateRequest('{"prompt":"x","max_tokens":' + String(ceiling + 1) + '}', ceiling, 1000)
                elif adapter == 1:
                    var request = OpenAIRequest('{"model":"m","max_tokens":' + String(ceiling + 1) + '}')
                    _ = resolve_request_token_limit(request.max_tokens, ceiling)
                else:
                    var request = OllamaRequest('{"model":"m","options":{"num_predict":' + String(ceiling + 1) + '}}')
                    _ = resolve_request_token_limit(request.num_predict, ceiling)
            except:
                rejected = True
            if not rejected:
                raise Error("Request escaped service token ceiling")
        if GenerateRequest('{"prompt":"next"}', ceiling, 1000).max_tokens != ceiling:
            raise Error("Previous request changed the service reply default")
    var invalid: List[String] = ["0", "-1", "-2", "1.5", "1e2", "true", "null", "\"1\"", "9223372036854775808"]
    for value in invalid:
        for adapter in range(3):
            var rejected = False
            try:
                if adapter == 0:
                    _ = GenerateRequest('{"prompt":"x","max_tokens":' + value + '}', 512, 1000)
                elif adapter == 1:
                    _ = OpenAIRequest('{"model":"m","max_tokens":' + value + '}')
                else:
                    _ = OllamaRequest('{"model":"m","options":{"num_predict":' + value + '}}')
            except:
                rejected = True
            if not rejected:
                raise Error("Invalid explicit request token limit accepted: " + value)
    var invalid_ceilings: List[Int] = [0, -1, 32769]
    for value in invalid_ceilings:
        var rejected = False
        try:
            _ = resolve_request_token_limit(1, value)
        except:
            rejected = True
        if not rejected:
            raise Error("Invalid service token ceiling accepted")
    require_loaded_context(0, 1024)
    require_loaded_context(1024, 1024)
    var mismatched_contexts: List[Int] = [-1, 1, 512, 2048]
    for value in mismatched_contexts:
        var rejected = False
        try:
            require_loaded_context(value, 1024)
        except:
            rejected = True
        if not rejected:
            raise Error("Service accepted an unapplied context resize")
    var invalid_contexts: List[String] = ["0", "1", "-1", "32769", "1.5", "null"]
    for value in invalid_contexts:
        var rejected = False
        try:
            _ = OllamaRequest('{"model":"m","options":{"num_ctx":' + value + '}}')
        except:
            rejected = True
        if not rejected:
            raise Error("Invalid explicit Ollama context accepted")


def test_native_recipe_precedence() raises:
    var config = parse_config_json('{"sampling":{"temperature":0.4,"top_p":0.6}}')
    var baseline = native_config_sampling(config)
    var none = List[String]()
    var partial = resolve_native_settings("FROM m.gguf\nPARAMETER temperature 0.8", NativeSamplingConfig(), none, 0, 64, "", baseline)
    if partial.sampling.temperature != Float32(0.8) or partial.sampling.top_p != Float32(0.6):
        raise Error("Recipe override discarded unrelated config fields")
    var cli_flags: List[String] = ["--temperature"]
    var cli_layer = resolve_native_settings("FROM m.gguf\nPARAMETER temperature 0.8", NativeSamplingConfig(), cli_flags, 0, 64, "", baseline)
    if cli_layer.sampling.temperature != 0 or cli_layer.sampling.top_p != Float32(0.6):
        raise Error("CLI override discarded unrelated config fields")
    var native_request = GenerateRequest('{"prompt":"x","top_p":0.5}', 64, 1000, cli_layer.sampling)
    var ollama_request = OllamaRequest('{"model":"m","prompt":"x","options":{"top_p":0.5}}', cli_layer.sampling)
    var openai_request = OpenAIRequest('{"model":"m","prompt":"x","top_p":0.5}', cli_layer.sampling)
    if native_request.sampling.description() != ollama_request.sampling.description() or native_request.sampling.description() != openai_request.sampling.description() or native_request.sampling.temperature != 0 or native_request.sampling.top_p != 0.5:
        raise Error("Config/recipe/CLI/request precedence differs across adapters")
    if baseline.temperature != Float32(0.4) or baseline.top_p != Float32(0.6) or cli_layer.sampling.top_p != Float32(0.6):
        raise Error("Resolution mutated an earlier settings layer")
    var content = String("FROM m.gguf\nPARAMETER temperature 0.8\nPARAMETER top_k 12\nPARAMETER top_p 0.7\nPARAMETER min_p 0.1\nPARAMETER repeat_penalty 1.2\nPARAMETER repeat_last_n 128\nPARAMETER seed 99\nPARAMETER num_ctx 1024\nPARAMETER num_predict 64\nSYSTEM Keep SYSTEM literal\n")
    var recipe = resolve_native_settings(content, NativeSamplingConfig(), none, 0, 256, "fallback")
    var expected = NativeSamplingConfig(0.8, 12, 0.7, 0.1, 1.2, 128, 99)
    if recipe.sampling.description() != expected.description() or recipe.context != 1024 or recipe.max_tokens != 64 or recipe.system != "Keep SYSTEM literal" or not recipe.has_system:
        raise Error("Native recipe controls not applied")
    var flags: List[String] = ["--temperature", "--seed", "--system", "--context", "--max-tokens"]
    var cli = NativeSamplingConfig()
    cli.seed = 0
    var overridden = resolve_native_settings(content, cli, flags, 2048, 128, "")
    expected.temperature = 0
    expected.seed = 0
    if overridden.sampling.description() != expected.description() or overridden.context != 2048 or overridden.max_tokens != 128 or overridden.system != "" or not overridden.has_system:
        raise Error("Explicit CLI recipe overrides lost zero/empty or inherited fields")
    var empty = resolve_native_settings("FROM m.gguf\nSYSTEM \"\"", cli, none, 0, 0, "fallback")
    if empty.system != "" or not empty.has_system:
        raise Error("Explicit empty recipe SYSTEM was lost")
    var invalid: List[String] = ["PARAMETER temperature NaN", "PARAMETER num_ctx 1", "PARAMETER num_ctx 32769", "PARAMETER num_predict 0", "PARAMETER stop end", "PARAMETER presence_penalty 0.1", "TEMPLATE custom", "MESSAGE user hi", "ADAPTER path", "SYSTEM one\nSYSTEM two", "FROM other.gguf", "SYSTEM \"\"\"start\nend\"\"\" trailing"]
    for line in invalid:
        var rejected = False
        try:
            _ = resolve_native_settings("FROM m.gguf\n" + line, cli, flags, 2048, 128, "")
        except:
            rejected = True
        if not rejected:
            raise Error("Unsupported or invalid native recipe accepted: " + line)
    var base = NativeSamplingConfig()
    var native = GenerateRequest("{\"prompt\":\"x\"}", 64, 1000, base, "recipe system")
    var ollama = OllamaRequest("{\"model\":\"m\",\"prompt\":\"x\"}", base, "recipe system")
    var openai = OpenAIRequest("{\"model\":\"m\",\"prompt\":\"x\"}", base, "recipe system")
    if native.system != "recipe system" or ollama.system != "recipe system" or openai.system != "recipe system":
        raise Error("API request omitted recipe system baseline")
    var explicit_native = GenerateRequest("{\"prompt\":\"x\",\"system\":\"\"}", 64, 1000, base, "recipe system")
    var explicit_ollama = OllamaRequest("{\"model\":\"m\",\"system\":\"\"}", base, "recipe system")
    var explicit_openai = OpenAIRequest("{\"model\":\"m\",\"messages\":[{\"role\":\"system\",\"content\":\"request system\"},{\"role\":\"user\",\"content\":\"x\"}]}", base, "recipe system")
    if explicit_native.system != "" or explicit_ollama.system != "" or explicit_openai.system != "request system":
        raise Error("Request system override was concatenated with or lost to baseline")
