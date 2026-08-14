# CLI Domain Interface Specification (`cli/`)

> *"Through rune-carved directives and terminal currents, the sovereign engine obeys the commands of mortals."*  
> — **Rúnhild Svartdóttir, The Architect**

---

## Public Structs & Functions

### `Modelfile` (`cli/modelfile.mojo`)
Encapsulates an Ollama-shaped subset of Modelfile directives (`FROM`,
`PARAMETER`, `SYSTEM`, `TEMPLATE`, `LICENSE`, `MESSAGE`). Full syntax or
behavioral compatibility is not established.

```mojo
struct Modelfile(Copyable):
    var from_model: String
    var parameters: Dict[String, String]
    var system_prompt: String
    var template: String
    var license_info: String
    var messages: List[String]

    def __init__(out self): ...
    def __init__(out self, from_model: String, parameters: Dict[String, String], system_prompt: String, template: String, license_info: String, messages: List[String]): ...
    def copy(self) -> Self: ...
```

### `parse_modelfile` (`cli/modelfile.mojo`)
Parses raw Modelfile text content into a structured `Modelfile` runestone.

```mojo
def parse_modelfile(content: String) raises -> Modelfile: ...
```

---

### `ModelManifest` (`cli/manifest.mojo`)
Preserves model metadata scroll: model name, tag, SHA-256 digest ID, size in bytes, quantization rune, structural dimensions, modification timestamp, and raw Modelfile inscriptions.

```mojo
struct ModelManifest(Copyable, ImplicitlyCopyable):
    var name: String
    var tag: String
    var digest: String
    var size_bytes: Int64
    var quantization: String
    var hidden_dim: Int
    var num_layers: Int
    var modified_time: String
    var modelfile_content: String

    def __init__(out self, name: String, tag: String = "latest", digest: String = "", size_bytes: Int64 = 0, quantization: String = "unknown", hidden_dim: Int = 0, num_layers: Int = 0, modified_time: String = "", modelfile_content: String = ""): ...
    def copy(self) -> Self: ...
    def size_formatted(self) -> String: ...
```

### `RuneModelStore` (`cli/manifest.mojo`)
In-memory manifest collection used by local tests. It starts empty, does not
persist model bytes, and reports no active processes. Mutation helpers alter
only the current value; they are not wired to CLI storage operations.

```mojo
struct RuneModelStore(Copyable):
    var catalog: Dict[String, ModelManifest]
    var model_keys: List[String]

    def __init__(out self) raises: ...
    def copy(self) -> Self: ...
    def list_models(self) raises -> List[ModelManifest]: ...
    def get_model(self, name: String) raises -> ModelManifest: ...
    def create_model(mut self, name: String, modelfile_content: String) raises: ...
    def copy_model(mut self, source: String, target: String) raises: ...
    def remove_model(mut self, name: String) -> Bool: ...
    def get_active_ps(self) raises -> List[ModelManifest]: ...
```

---

### `RuneREPL` (`cli/repl.mojo`)
Reserves the interactive terminal interface. `run_repl()` currently raises
`interactive REPL is not implemented`; it does not read stdin or generate a
sample response.

```mojo
struct RuneREPL:
    var model_name: String
    var system_prompt: String
    var temperature: Float64
    var stream_enabled: Bool

    def __init__(out self, model_name: String = "aesir:latest"): ...
    def render_welcome(self): ...
    def render_help(self): ...
    def run_repl(mut self) raises: ...
```

### `run_single_shot` (`cli/repl.mojo`)
Executes one real deterministic prompt run and writes the decoded result to
terminal stdout. The default proof length is 32 new tokens.

```mojo
def run_single_shot(
    model_name: String,
    prompt: String,
    max_new_tokens: Int = 32,
) raises: ...
```

---

### `parse_positive_int` (`cli/commands.mojo`)

Parses the decimal argument to `--max-tokens`, rejecting empty, zero,
nonnumeric, negative, and overflowed values with an explicit error.

```mojo
def parse_positive_int(value: String) raises -> Int: ...
```

Single-shot syntax is:

```text
aesir run <model-path> [--max-tokens N] <prompt...>
```

With no prompt arguments, `run` reaches the reserved REPL entry point and raises
an explicit unsupported error.

---

### `dispatch_command` (`cli/commands.mojo`)
Main CLI router. `help`, `--help`, `version`, and the real single-shot
`run <model-path> [--max-tokens N] <prompt...>` path are implemented. `serve`,
model-store/distribution commands, interactive `run`, multi-engine commands,
and swarm commands raise stable unsupported errors and emit no success output.

```mojo
def dispatch_command(args: List[String]) raises: ...
```

---

### Multi-Engine CLI Dispatchers (`cli/multi_engine.mojo`) (Slice 11)
Preserves public entry points for llama.cpp-, ExLlama/EXL2-, and ONNX-shaped
commands. Each function raises an explicit unsupported error; no benchmark,
conversion, health, completion, cache, or perplexity result is fabricated.

```mojo
def dispatch_llama_cli(args: List[String]) raises -> Bool: ...
def dispatch_exl2_cli(args: List[String]) raises -> Bool: ...
def dispatch_onnx_cli(args: List[String]) raises -> Bool: ...
```

---

## Domain Boundary Laws for `cli/`

1. **Subcommand Dispatch:** `cli/commands.mojo` acts as the command gateway router for binary execution from `main.mojo`.
2. **Facade Isolation:** `cli/repl.mojo` and `cli/commands.mojo` interact with inference strictly via `AesirEngine` in `aesir.mojo` or `BifrostGate` in `server/api.mojo`. They **must never** import `core/compute.mojo`, `core/inference.mojo`, or `core/mimir_well.mojo` directly.
3. **Model & Manifest Independence:** `cli/modelfile.mojo` and `cli/manifest.mojo` own configuration parsing and catalog storage and have zero dependencies on hardware kernels or socket connections.
4. **Generation Option Ownership:** CLI code validates and forwards the positive token limit but never owns autoregressive state, KV memory, EOS policy, or token decoding; those remain in `AesirEngine`.
