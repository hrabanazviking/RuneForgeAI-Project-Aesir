# CLI Domain Interface Specification (`cli/`)

> *"Through rune-carved directives and terminal currents, the sovereign engine obeys the commands of mortals."*  
> — **Rúnhild Svartdóttir, The Architect**

---

## Public Structs & Functions

### `Modelfile` (`cli/modelfile.mojo`)
Encapsulates parsed directives carved into the runestone from an Ollama-compatible Modelfile (`FROM`, `PARAMETER`, `SYSTEM`, `TEMPLATE`, `LICENSE`, `MESSAGE`).

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

    def __init__(out self, name: String, tag: String = "latest", digest: String = "sha256:a1b2c3d4e5f6", size_bytes: Int64 = 4370000000, quantization: String = "Q4_K_M", hidden_dim: Int = 4096, num_layers: Int = 32, modified_time: String = "2 hours ago", modelfile_content: String = "FROM model.gguf"): ...
    def copy(self) -> Self: ...
    def size_formatted(self) -> String: ...
```

### `RuneModelStore` (`cli/manifest.mojo`)
Sovereign model catalog store managing model creation, manifest querying, model cloning, deletion, and active process tracking.

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
Provides interactive terminal chat prompt loop, streaming token generation current, and runtime slash commands (`/?`, `/help`, `/set`, `/show`, `/clear`, `/bye`).

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
Executes a single prompt run and streams output directly to terminal stdout.

```mojo
def run_single_shot(model_name: String, prompt: String) raises: ...
```

---

### `dispatch_command` (`cli/commands.mojo`)
Main entry point routing CLI subcommands (`serve`, `run`, `pull`, `push`, `create`, `list`/`ls`, `ps`, `rm`/`delete`, `cp`, `show`, `stop`, `swarm`, `help`) to sovereign Ollama and Swarm handlers. In **Slice 13**, `pull` detects HuggingFace tags (`hf.co/...`, `huggingface.co/...`, `org/repo`) via `HuggingFaceSeer.is_hf_tag`, streams model weights bare-metal via `download_hf_model`, and registers model manifests in `RuneModelStore`. In **Phase 14**, `swarm` dispatches swarm mesh operations (`join`, `list`/`ls`, `status`, `dispatch`) via `SwarmCluster`.

```mojo
def dispatch_command(args: List[String]) raises: ...
```

---

### Multi-Engine CLI Dispatchers (`cli/multi_engine.mojo`) (Slice 11)
Handles drop-in subcommand dispatching across llama.cpp, ExLlamaV3, and ONNX ecosystems.

```mojo
def dispatch_llama_cli(args: List[String]) -> Bool: ...
def dispatch_exl2_cli(args: List[String]) -> Bool: ...
def dispatch_onnx_cli(args: List[String]) -> Bool: ...
```

---

## Domain Boundary Laws for `cli/`

1. **Subcommand Dispatch:** `cli/commands.mojo` acts as the command gateway router for binary execution from `main.mojo`.
2. **Facade Isolation:** `cli/repl.mojo` and `cli/commands.mojo` interact with inference strictly via `AesirEngine` in `aesir.mojo` or `BifrostGate` in `server/api.mojo`. They **must never** import `core/compute.mojo`, `core/inference.mojo`, or `core/mimir_well.mojo` directly.
3. **Model & Manifest Independence:** `cli/modelfile.mojo` and `cli/manifest.mojo` own configuration parsing and catalog storage and have zero dependencies on hardware kernels or socket connections.

