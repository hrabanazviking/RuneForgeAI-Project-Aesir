# CLI Domain Interface Specification (`cli/`)

> **Current supported command boundary — 2026-08-30:** `pull` downloads the
> documented public pinned GGUF artifact; `chat --accel cuda` and
> `run --accel cuda` execute the dense text-only Gemma 4 E4B Q4_K_M profile with
> native CUDA. Legacy Ollama-shaped commands, generic REPL behavior, model-store
> lifecycle, and compatibility surfaces below are not thereby implemented.
> `chat --accel cuda --profile llama3` additionally runs the admitted Stheno
> Q4_K_S profile with an 8K context. CUDA single-shot `run` auto-detects either
> profile. `hardware list` and `compute plan|explain` expose observed resources
> and checked native model plans. Chat accepts `--profile auto`, `--device
> auto|N` and `--reserve-mib N`; see `docs/NATIVE_RUNTIME.md`.

> *"Through rune-carved directives and terminal currents, the sovereign engine obeys the commands of mortals."*  
> — **Rúnhild Svartdóttir, The Architect**

---

## Native CUDA chat controls

`cli/sampling.mojo` validates native sampling flags and interactive setting
values. `cuda_chat.mojo` owns `/help`, `/show`, `/clear`, `/set` and `/bye`,
reports successful state changes and rejections to the durable transcript,
and treats prompt-file lines literally. The core owns sampler/KV state.
CLI syntax, defaults and limitations are in `docs/NATIVE_RUNTIME.md`.

## Public Structs & Functions

### `Modelfile` (`cli/modelfile.mojo`)
Encapsulates an Ollama-shaped subset of Modelfile directives (`FROM`,
`PARAMETER`, `SYSTEM`, `TEMPLATE`, `LICENSE`, `MESSAGE`) with single/double/triple-quote
multiline directive support and conversion to `GenerationConfig`.

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
    def to_generation_config(self) raises -> GenerationConfig: ...
```

### `parse_modelfile` (`cli/modelfile.mojo`)
Parses raw Modelfile text content into a structured `Modelfile` runestone. Handles multiline triple quotes `"""..."""` and escape unescaping. Raises catchable `Error` if `FROM` directive is missing.

```mojo
def parse_modelfile(content: String) raises -> Modelfile: ...
```

---

### `ModelManifest` (`cli/manifest.mojo`)
Preserves caller-supplied model metadata: model name, tag, non-cryptographic
content fingerprint, optional byte size, quantization, structural dimensions,
modification timestamp, and raw Modelfile text. Creation does not invent model
metadata that has not been measured.

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
    def serialize(self) -> String: ...
```

### `compute_modelfile_fingerprint` (`cli/manifest.mojo`)
Computes a deterministic FNV-1a 64-bit fingerprint starting with `fnv1a64:`.
This is an identity hint, not a cryptographic integrity digest.

```mojo
def compute_modelfile_fingerprint(content: String) -> String: ...
```

### `RuneModelStore` (`cli/manifest.mojo`)
In-memory model catalog supporting deterministic fingerprints and text
serialization/deserialization. The module does not read or write a durable
catalog on its own.

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
    def remove_model(mut self, name: String) raises -> Bool: ...
    def get_active_ps(self) raises -> List[ModelManifest]: ...
```

### `DurableModelStore` (`cli/storage.mojo`)

Linux durable-catalog boundary. The caller supplies a validated relative store
root. An absent catalog loads as empty; mutations stage a same-directory file,
sync it, atomically rename it, sync the containing directory, and publish the
new in-memory state only after the durable commit succeeds. Catalog v1 is
bounded, versioned, delimiter-safe, and rejects malformed records, duplicate
identities, unsafe references, and unsupported versions. Model-byte blob
ingestion remains outside this slice.

```mojo
struct DurableModelStore:
    var root_path: String
    var store: RuneModelStore

    def __init__(out self, root_path: String) raises: ...
    def list_models(self) raises -> List[ModelManifest]: ...
    def get_model(self, name: String) raises -> ModelManifest: ...
    def create_model(mut self, name: String, modelfile_content: String) raises: ...
    def copy_model(mut self, source: String, target: String) raises: ...
    def remove_model(mut self, name: String) raises: ...
```

`validate_store_root`, `serialize_catalog`, and `deserialize_catalog` expose
the corresponding validation and catalog-codec boundaries for callers and
focused verification. Store-root validation delegates to the authoritative
`AesirConfig.model_store_path` schema, whose relative default is
`.aesir/models`.

---

### `RuneREPL` (`cli/repl.mojo`)
Slash-command state machine with hyperparameter tuning (`GenerationConfig`)
and history management (`/?`, `/set`, `/show`, `/clear`, `/bye`). Ordinary
chat input and the terminal loop fail closed until inference wiring exists.

```mojo
struct RuneREPL:
    var model_name: String
    var system_prompt: String
    var config: GenerationConfig
    var history: List[ChatMessage]

    def __init__(out self, model_name: String = "aesir:latest"): ...
    def render_welcome(self): ...
    def render_help(self): ...
    def process_input_line(mut self, raw_line: String) raises -> String: ...
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

### `CLIOptions` (`cli/options.mojo`)
CLI intent container and parser supporting `--verbose`, `--format json|text`,
`--keepalive <duration>`, `--modelfile <path>`, `--raw`, `--insecure`, and
`--max-tokens N`. It also records whether `--config` and `--accel` were
explicitly supplied, along with presence markers for every other parsed flag,
so command dispatch can apply precedence without mistaking defaults for caller
intent. Parsing a flag does not imply downstream operational support. Each
implemented command validates applicability and rejects options that do not yet
have a connected owner.

```mojo
struct CLIOptions:
    var verbose: Bool
    var format: String
    var keepalive_seconds: Int
    var modelfile_path: String
    var raw: Bool
    var insecure: Bool
    var max_tokens: Int
    var config_path: String
    var config_was_set: Bool
    var accel_backend: String
    var accel_was_set: Bool

def parse_duration_seconds(duration_str: String) raises -> Int: ...
def parse_cli_options(args: List[String]) raises -> CLIOptions: ...
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
aesir run <model-path> [options] <prompt...>
```

With no prompt arguments, `run` reaches the reserved REPL entry point and raises
an explicit unsupported error.

Recognized option tokens and their values are removed from positional assembly,
so control flags cannot become model prompt text. `auto` and `cpu` select the
verified CPU route. `cuda` selects the native Gemma 4 E4B session. Other unavailable accelerator intent raises before model
loading and never falls back under a hardware label. The tracked configuration
uses neutral values for unconnected runtime fields; changing one of those
fields on a single-shot run raises rather than being ignored.

---

### `dispatch_command` (`cli/commands.mojo`)
Main CLI router. Empty invocation, `help`, `--help`, `version`, configuration
validation, and the real single-shot `run <model-path> [options] <prompt...>`
path are implemented. `config [--config <path>]` reads and validates the
selected schema and prints its normalized representation. `serve`,
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
2. **Facade Isolation:** CLI code interacts with `AesirEngine` or the exported `Gemma4CUDASession`/`Llama3CUDASession` through `aesir.mojo`, or `BifrostGate` in `server/api.mojo`. It must not import compute kernels directly.
3. **Model & Manifest Independence:** `cli/modelfile.mojo` and `cli/manifest.mojo` own configuration parsing and catalog storage and have zero dependencies on hardware kernels or socket connections.
4. **Generation Option Ownership:** CLI validates/forwards limits and writes transcripts. The engine session owns autoregressive state, KV memory, EOS/length policy and UTF-8 decoding.
5. **Intent Must Be Enforced:** Explicit configuration and acceleration intent must be applied or rejected before execution. No accepted option may silently select a different backend or enter prompt text.

### Native download and CUDA chat

`pull <repo> <file.gguf> --revision <sha> --sha256 <digest> --size <bytes>
--output <path> [--connections 1..8]` retrieves and verifies a public model.

`chat <gemma4.gguf> --accel cuda [--prompts file] [--log file]
[--max-tokens 16384] [--context 32768] [--system text]` supports persistent
interactive input or one turn per nonempty UTF-8 file line. `--log` creates an
exclusive transcript and synchronizes it after each turn. No existing transcript
is overwritten. Errors do not print a completion summary. `run --accel cuda`
uses the same native engine for a single prompt. See `docs/GEMMA4_CUDA.md`.

`chat <llama3.gguf> --accel cuda --profile llama3` selects the native Llama 3
session. Defaults are `--context 8192 --max-tokens 8192`; the reply is bounded
by remaining context. Unsupported profiles, duplicate flags and excessive
limits fail before model/transcript operations. The default chat profile is
Gemma; single-shot CUDA `run` auto-detects Gemma or Llama 3. See
`docs/STHENO_CUDA.md` and `docs/NATIVE_RUNTIME.md`.

### Native cooperative generation control (2026-08-31)

`GenerationControl` and both CUDA sessions expose monotonic `timeout_ms`
(0..3600000, zero disabled) and a borrowed `cancel_fd` (-1 disabled). The owner
keeps the descriptor alive; core never consumes or closes it. Configure between
turns; calls are serialized. `cancel()` closes the active assistant with EOS;
interrupted prefill requires an explicit `reset()` before reuse. Failed CUDA
sessions stay failed. Chat exposes timeout/settings, `/show` reset state and
Ctrl+C through Linux signalfd plus a mask-preserving executable bootstrap.
See `docs/NATIVE_RUNTIME.md` for tested limits and physical reproduction.

### Serialized native service contract (2026-08-31)

The facade exports `ControlledTextSession`, `NativeGenerationStatus` and the
monotonic clock. Both CUDA sessions implement reset, begin/next/cancel, sampling
and deadline configuration, plus a copied status snapshot. The service holds
one session and serializes all mutation; this does not make sessions thread-safe.
`cli/native_serve.mojo` connects authenticated local requests to this contract.
`serve` is a foreground loopback command requiring an API key file; `daemon`
remains rejected. SIGINT/SIGTERM terminate cooperatively. API details and
production limitations are in `docs/NATIVE_SERVICE.md`.

### Native private-key publication

`aesir keygen <new-private-file>` calls `server/keyfiles.create_service_key`.
Linux `getrandom` supplies a 256-bit key; a separate random staging name is
exclusively created in the opened parent directory. File sync precedes atomic
no-replace linking; directory sync follows owned temporary-link removal. Existing
outputs are never deleted or replaced. Contents are never printed. All POSIX
path pointers refer to explicitly terminated, owned byte buffers. The native
key probe runs in CI without a GPU; crash/persistence limits are documented in
`docs/NATIVE_SERVICE.md`.
