# CLI Domain Interface Specification (`cli/`)

> **Current supported command boundary — 2026-09-02:** `pull` downloads the
> documented public pinned GGUF artifact; `chat --accel cuda` and
> `run --accel cuda` execute the dense text-only Gemma 4 E4B Q4_K_M profile with
> native CUDA. Native catalog `create`, `list`, `show`, `cp`, `rm`, `verify`, and `gc`
> persist through `DurableModelStore`; `create --model` imports measured
> SHA-256-addressed bytes, and pinned `pull --name` registers a verified Hub
> artifact. `gc` performs a locked reference-aware sweep after full namespace
> validation. Generic REPL behavior and compatibility surfaces below are not
> thereby implemented.
> `chat --accel cuda --profile llama3` additionally runs the admitted Stheno
> Q4_K_S profile with an 8K context. CUDA single-shot `run` auto-detects either
> profile. `hardware list` and `compute plan|explain` expose observed resources
> and checked native model plans. Chat accepts `--profile auto`, `--device
> auto|N` and `--reserve-mib N`; see `docs/NATIVE_RUNTIME.md`.

> *"Through rune-carved directives and terminal currents, the sovereign engine obeys the commands of mortals."*  
> — **Rúnhild Svartdóttir, The Architect**

---

## Interactive home launcher

The executable opens `cli/home.mojo` for `aesir home [--model-store path]` or
an empty invocation with both stdin and stdout attached to terminals. Empty
redirected invocations retain command help; explicit redirected `home` fails
immediately with guidance. `home --help` is available without a terminal.
`main` owns this routing, while embedded `dispatch_command([])` retains help.

Home reports installed/recipe counts without GPU allocation or model hashing.
It offers CUDA chat, catalog listing, doctor, repair preview, command help and
quit. Every external action uses an attached child of the current executable
with explicit argv and the selected store. Children inherit terminal streams
and environment; their exit is reaped and displayed before returning to Home.
Chat GPU state and model-switch `execv` stay in the child process. Home itself
does not become a resident inference server. Ctrl+C cancels menu input, and
EOF/quit exits. Child cancellation follows that child's existing policy.
Model imports and preference repair application are never implicit menu actions.

## Native CUDA chat controls

`cli/sampling.mojo` maps native sampling flags and re-exports core value
validation for interactive settings. `cuda_chat.mojo` owns `/help`, `/show`, `/clear`, `/new`, `/save`,
`/load`, `/export`, `/set` and `/bye`,
reports successful state changes and rejections to the durable transcript,
and treats prompt-file lines literally. The core owns sampler/KV state.
CLI syntax, defaults and limitations are in `docs/NATIVE_RUNTIME.md`.

Interactive `/model <name-or-alias-or-path>` is owned by the outer CUDA-chat
lifecycle, not either concrete session. It resolves and inspects the target
while the current session remains recoverable, returns the accepted request out
of that session's scope, then uses a same-PID `execv` image replacement before
the next plan/load. The handoff preserves terminal input, settings, signal
bootstrap state, and an inherited transcript descriptor while deliberately
discarding model-specific conversation/KV state. This avoids overlapping GPU
allocations and the observed MAX sequential-context deadlock. Floating sampling
controls cross the exec boundary as exponent-free unsigned decimal text from
`core/sampling_options.mojo::sampling_decimal_text`. It expands the standard
Float32 formatter's exponent form, enforces the existing 64-byte public grammar,
and verifies exact bit-level round trip before exec. Signed zero becomes `0`;
negative/nonfinite values fail. The public CLI still rejects exponent notation.
Count and seed handoff remains integer text.

`cli/conversation.mojo` owns the bounded checksummed v1 snapshot codec,
exclusive owner-private file publication, loading, and readable Markdown
export. Snapshots bind the exact committed token IDs and sampler draw position
to the open model inode's SHA-256, profile, context, system prompt, and sampling
identity. Compatibility is checked before reset; core session restore then
replays validated tokens into empty KV without sampling or retokenizing text.
`scripts/conversations.py` is the separate named-library presentation layer. It
imports only validated snapshots and owns bounded Unicode names, stable entry
IDs, locking, restart listing, rename, compatibility-filtered open, and
exclusive readable export. It does not import Mojo modules, mutate CUDA state,
or replace the native `/load` compatibility boundary.

`cli/conversation_autosave.mojo` owns the opt-in atomic-generation layer over
that codec. It locks one caller-created private directory, writes a synced
inflight marker before generation, publishes immutable snapshots before an
atomic checksummed manifest, and evicts only generation names present in the
prior authoritative manifest. `cuda_chat.mojo` restores the latest snapshot
only through `require_conversation_compatible` and core KV replay. Autosave is
not the named library, does not scan arbitrary directory contents, and does not
permit model switching in this slice.

## Native service sampling defaults

`serve` accepts the same seven native sampling flags as `chat`. The resulting
config is passed both to the allocated session and to the service's immutable
request baseline. Each request copies that baseline before applying explicit
fields; request-specific changes never become defaults for the next request.
`repeat-last-n` is a startup-only allocation choice. Native recipe/config
layering and request limits are described below.

## Native config, recipe and explicit-CLI settings

`cli/native_settings.mojo` owns a shared pre-planning resolver used by chat and
serve. Native defaults are overlaid by explicitly present JSON config sampling,
then the registered model's recipe, then only explicit CLI fields.
Stored `num_ctx`/`num_predict` request context/reply limits;
the seven native sampling parameters and `SYSTEM` are applied. Explicit zero
temperature/seed and empty CLI/recipe system prompts are preserved. Direct GGUF
paths have no stored recipe. FROM identifies recipe metadata, not a second load.

Chat/serve accept one `--config file` (`-c`) or `--model-store path`, never both.
Alias-normalized duplicate and conflicting selectors fail before config access.
Only explicitly selected files are loaded, once before model selection, keys,
prompt files and transcripts. The existing JSON schema connects temperature,
top_p and storage.model_store_path; omitted sampling fields do not materialize
the config container's neutral defaults. No new schema fields are introduced.
Native sampling validation rejects Float32 overflow, positive temperature
underflow and top_p outside (0, 1] even if higher-priority layers override them.
Non-neutral unconnected hardware/safety/experimental/interface settings reject;
hardware.acceleration_backend accepts only auto/cuda and still requires explicit
`--accel cuda`. The config path is not reread across model-switch exec: current
effective sampling and the selected store are carried by the existing handoff.
See `docs/CONFIGURATION.md` for exact scope and normalization semantics.

Strict native parsing accepts FROM, PARAMETER, SYSTEM and LICENSE; TEMPLATE,
MESSAGE, unknown directives, duplicate singleton directives, custom stops,
presence/frequency penalties and other unsupported parameters are rejected.
Invalid numeric recipe values are rejected even when a CLI flag overrides them.
The permissive catalog grammar remains separate so recipes can still be stored
and inspected without claiming they are natively executable.

`chat <model> --accel cuda --show-settings` and `serve <model> --accel cuda
--show-settings` emit one versioned JSON object from this resolver. No GPU
session, listener, key, transcript or prompt file is opened. Catalog references
still resolve/verify their stored blobs. Context/reply request 0 means automatic,
not an observed capacity. Preview does not inspect model architecture or establish
execution/fit; direct-path preview can describe a nonexistent path's defaults.

During `/model`, target recipe syntax/value support is checked before the current
session is released. Existing handoff retains current sampling/system as explicit
CLI values; only originally explicit context/reply limits carry over, so otherwise
the target recipe supplies those requests. Final combined limits and hardware fit
are checked after handoff. Float sampling fields are serialized without exponent
notation and tested across stratified finite Float32 values. Physical switches
with recipes/config remain unverified.

## Catalog store selection

`list`/`ls`, `show`, `create`, `verify`, `gc`, `cp`, and `rm`/`delete`
accept `--model-store <relative-path>` or `--config <file>` (`-c`). These
selectors are mutually exclusive, including when they would name the same
store; duplicate selectors are errors. With neither, the store remains
`.aesir/models`. Config-only calls retain `storage.model_store_path` behavior.
Direct paths use the shared safe relative POSIX path validator. Invalid or
conflicting selectors fail before config loading or durable-store access;
they cannot silently select a store for a mutation. This changes command
selection only, not catalog format or transaction semantics.

## Model inspection evidence

`inspect <model> [--context N] [--format text|json] [--model-store path]`
maps bounded GGUF metadata and applies the architecture registry plus the exact
native profile/tensor validator. JSON is schema version 1 with scope
`gguf_metadata_and_native_layout` and `execution_tested: false`. It distinguishes
metadata context, recommended context, caller-requested context and the context
actually evaluated. `tensor_validation` is `not_run`, `passed`, or `failed`;
unsupported families/variants/quantizations remain `not_run` because no native
layout contract applies. Successful validation includes exact planned device
buffer bytes, but does not observe a GPU or establish fit/allocation/inference.

When a recognized profile fails metadata/tensor validation, `reason` retains the
bounded loader/profile error (including the failing metadata or tensor name)
instead of replacing it with a generic mismatch. This is diagnostic detail from
local model structure, not untrusted code execution. Text and JSON render the
same `ModelCompatibility` result. Catalog references still rehash their blob
before inspection; direct paths use the loader's no-follow regular-file boundary.
Observed device/host fit explanation belongs to `compute explain` and S08b.

## Native memory-fit explanation

`compute plan|explain <model>` applies one shared checked fit contract to the
selected CUDA device and host upload allowance. Its output includes stable
reason codes and exact required, observed available, reserve, usable, deficit
and headroom byte counts. The arithmetic checks reserve before evaluating
`required <= available - reserve`, avoiding subtraction overflow. Selection
errors preserve a cause for each considered device, including incompatible API,
compatibility failure, native address-range overflow and a missing requested
index. Automatic context exhaustion retains the final fit evidence. The report
is a raceable planning snapshot and neither uploads weights nor proves that a
later allocation or inference will succeed.

## Native diagnostics

`cli/doctor.mojo` owns parsing and presentation for `aesir doctor [model]
[--model-store path] [--format text|json]`. Linux disk and socket-table observations live in
`core/native_diagnostics.mojo`; CUDA facts come through the engine facade, and
catalog integrity comes from `DurableModelStore`. The command rehashes every
installed catalog blob, identifies recipe-only entries separately, and can
append the existing architecture-registry inspection for one model. It does
not contact a listening socket or the public internet, and neither API
listeners nor network access are prerequisites for offline inference readiness.
Readiness requires at least one installed SHA-256 blob, not just a recipe;
it describes CUDA/storage prerequisites, not model execution compatibility.
Store arguments are validated before hardware discovery.

JSON output is one document with `schema_version: 1`, `scope:
"cuda_storage_prerequisites"`, `ready`, and `execution_tested: false`.
`cuda`, `store`, `disk`, and `api` hold observations; unknown byte counts,
unreadable-store counts and unobserved listeners are `null`. Disk capacity names
the observed path, including `.` when the requested store does not yet exist.
`issues` contains stable codes and suggested actions. `model` is null when
omitted, otherwise contains `reference`, `inspection_ok`, `execution_tested`,
`result` (the existing inspection schema), and `error`. Successful inspection
does not imply a supported model or tested execution; inspect its compatibility
fields. Root readiness deliberately remains prerequisite-only.

Diagnostic findings, including optional model-inspection failures, return a
report and successful command exit in both formats. Invalid command options are
execution errors and return nonzero; they do not emit a partial JSON report.
Scripts must inspect `ready`, `issues`, and optional `model` fields rather than
treating a zero exit as proof of inference readiness. Observations are collected
once per invocation and neither format performs external network probes.

## Model preferences

`cli/model_preferences.mojo` owns aliases and favorites as a separate bounded,
checksummed, atomically replaced `preferences.v1` record under the model-store
root. Alias values are canonical catalog `name:tag` identities; they do not
create manifests or duplicate blobs. `cli/model_reference.mojo` applies aliases
only to non-path references, and `cli/model_selector.mojo` builds a stable
favorite-first view without mutating durable catalog order. The commands are
`alias`, `aliases`, `unalias`, `favorite`, `favorites`, and `unfavorite`.

`repair-preferences [--dry-run|--apply] [--model-store path | --config file]`
defaults to a dry run. It reports `missing_model` and `recipe_only` findings
for aliases and favorites. Only `--apply` removes missing-model shortcuts;
recipe-only shortcuts and references to temporarily missing/corrupt weight
blobs are preserved. It never removes model bytes or manifests. Invalid modes,
duplicate/mixed modes, and mode flags on other preference commands fail.

`DurableModelPreferences.audit_and_repair` obtains the same directory flock as
catalog writers, then reloads both records. `storage.load_catalog_at_locked_root`
reads the catalog through `/proc/self/fd/<root-fd>` so the decision and preference
publication use the pinned directory. A missing or invalid catalog is an error,
not permission to prune all shortcuts. Invalid preferences also fail without
repair. Missing preferences are explicitly unconfigured (`readable: false` in
doctor), not a healthy empty record; ordinary alias/favorite creation still
initializes preferences normally. Raw and hex-encoded NUL bytes in catalog or
preference records are rejected before null-terminated conversion. Full strict
UTF-8 admission for all persistence codecs remains S09.
Only a changed explicit repair publishes a replacement preferences
record; previews and no-ops do not stage files. Cooperative writers share this
lock; this is not a claim of crash-injection or hostile concurrent-writer proof.

Doctor adds a `preferences` object with `readable`, `stale_count` (null if
unavailable), `error`, and `findings` (`kind`, `name`, `target`, `reason`).
Unavailable records are disclosed; they are not silently treated as clean.
Shortcut health remains separate from root CUDA/storage prerequisite readiness.
The interactive model chooser filters recipe-only catalog entries before
favorite ordering and numbering; blob verification still occurs at resolution.
Model sizes use the shared binary-unit formatter, without truncating scientific
notation into a misleading gigabyte figure for small models.

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
    def to_generation_config(self, context_length: Int = 4096) raises -> GenerationConfig: ...
```

### `parse_modelfile` (`cli/modelfile.mojo`)
Parses raw Modelfile text content into a structured `Modelfile` runestone. Handles multiline triple quotes `"""..."""` and escape unescaping. Raises catchable `Error` if `FROM` directive is missing.

```mojo
def parse_modelfile(content: String, strict_native: Bool = False) raises -> Modelfile: ...
```

Duplicate `PARAMETER` keys (including repeated `stop`) are rejected, not
last-write-wins. Parameter extraction removes only the directive/key prefixes;
literal occurrences of those words within a quoted value are preserved.
Users must resolve duplicate settings explicitly; existing files are not edited.

Generic `to_generation_config(context_length=4096)` recognizes `num_predict`,
`temperature`, `top_k`, `top_p`, `min_p`, `repeat_penalty`, `presence_penalty`,
`frequency_penalty`, `stop`, and `seed`; unknown conversion parameters fail.
Numbers use the bounded core unsigned decimal/UInt64 grammar, with an optional
minus only for presence/frequency penalties. Count conversion checks Int range;
seeds preserve full UInt64 precision. Omitted token limit is
`min(16000, context_length)`; explicit limits are validated, never clamped.
Context must be positive. The generic config's ranges remain distinct from
native CUDA limits. `num_ctx` is not consumed here: pass context explicitly.
This generic conversion is separate from the native recipe resolver above.
Legacy permissive `parse_int`/`parse_float` helpers and their other consumers
are unchanged by this bounded admission fix.

---

### `ModelManifest` (`cli/manifest.mojo`)
Preserves caller-supplied or measured model metadata: model name, tag,
non-cryptographic recipe fingerprint or cryptographic blob digest, byte size, quantization, structural dimensions,
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
    def create_model_from_blob(mut self, name: String, modelfile_content: String, digest: String, size_bytes: Int64) raises: ...
    def copy_model(mut self, source: String, target: String) raises: ...
    def remove_model(mut self, name: String) raises -> Bool: ...
    def get_active_ps(self) raises -> List[ModelManifest]: ...
```

### `DurableModelStore` (`cli/storage.mojo`)

Linux durable-catalog boundary. The caller supplies a validated relative store
root. Native `create`, `list`/`ls`, `show`, `cp`, and `rm`/`delete` dispatchers
use it across process restarts. An absent catalog loads as empty; mutations stage a same-directory file,
sync it, atomically rename it, sync the containing directory, and publish the
new in-memory state only after the durable commit succeeds. Catalog v1 is
bounded, versioned, delimiter-safe, and rejects malformed records, duplicate
identities, unsafe references, and unsupported versions. Blob ingestion copies
a final-symlink-rejected, nonempty seekable source inode, hashes the exact open
descriptor, and publishes `blobs/sha256/<digest>` without overwriting an
existing entry. Existing entries are size/hash verified before deduplication;
a catalog failure removes a blob newly published by that transaction. Garbage
collection validates all catalog references and directory entries before its
first deletion, then removes unreachable canonical blobs and abandoned stages.
`BlobGCResult` reports `scanned_blobs`, `referenced_blobs`, `removed_blobs`,
`removed_stages`, and `reclaimed_bytes` for the completed locked sweep.

```mojo
struct DurableModelStore:
    var root_path: String
    var store: RuneModelStore

    def __init__(out self, root_path: String) raises: ...
    def list_models(self) raises -> List[ModelManifest]: ...
    def get_model(self, name: String) raises -> ModelManifest: ...
    def create_model(mut self, name: String, modelfile_content: String) raises: ...
    def ingest_model(mut self, name: String, modelfile_content: String, source_path: String, expected_digest: String = "", expected_size: Int64 = 0) raises -> BlobRecord: ...
    def verify_model(self, name: String) raises -> BlobRecord: ...
    def garbage_collect(mut self) raises -> BlobGCResult: ...
    def copy_model(mut self, source: String, target: String) raises: ...
    def remove_model(mut self, name: String) raises: ...
```

`validate_store_root`, `serialize_catalog`, and `deserialize_catalog` expose
the corresponding validation and catalog-codec boundaries for callers and
focused verification. Store-root validation delegates to the authoritative
`AesirConfig.model_store_path` schema, whose relative default is
`.aesir/models`.
`validate_manifest_storage_identity` is the single recipe/blob digest-and-size
invariant used by catalog decode, durable serialization, and collection.

`scripts/test_catalog_crash_atomicity.py` is the Linux process-crash evidence
for the catalog commit protocol. Its test-only interposition shim kills the
unmodified native binary after successful staged write, staged-file `fsync`,
rename, and directory `fsync`. Restart must expose exactly the old catalog for
pre-rename kills or the complete new catalog for post-rename kills, and a later
mutation must still succeed. This is not sudden-power-loss, injected-error, or
garbage-collection crash proof; pre-rename staging remnants are currently
ignored rather than automatically removed.

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
selected schema and prints its normalized representation. Catalog commands are
restart safe; content-addressed import and verification are implemented. `ps`,
`stop`, `push`, authenticated pull, resumable parallel pull,
interactive `run`, multi-engine commands, and swarm commands raise stable
unsupported errors and emit no success output.

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

`PullRequest` and `parse_pull_request()` validate the complete syntax without
performing I/O. `pull <repo> <file.gguf> --revision <sha> --sha256 <digest>
--size <bytes> --output <path> [--connections 1..8] [--name <name[:tag]>
[--config <path>]]` retrieves and verifies a public model. `--name` preflights
the selected store and admits the pinned identity again inside locked blob
ingestion before catalog mutation.

`chat <gemma4.gguf> --accel cuda [--prompts file] [--log file]
[--autosave-dir private-directory] [--autosave-retain 1..64]
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

### Durable quantization tuning cache

`DurableQuantizationTuningCache(root_path, build_fingerprint)` stores the core
autotuner's checksummed v1 codec as `quantization-tuning.v1`. The Linux boundary
accepts a normalized relative root, creates missing directories with mode 0700,
locks and opens the final directory without following a symlink, reads the
target with `O_NOFOLLOW`, enforces the 1 MiB limit, stages through `mkstemp`,
syncs the staged file, atomically renames it, and syncs the directory. `load()`
returns false for an absent record and transactionally restores a present valid
record. Callers still supply the build fingerprint; automatic runtime wiring is
outside this storage interface.
