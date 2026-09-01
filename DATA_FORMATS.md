# DATA FORMATS — Project Æsir

## Authority

This document defines every structured data format that Project Æsir produces, consumes, or transports. It specifies schemas, encoding rules, versioning policies, validation requirements, and interchange contracts. It complements ENGINEERING_DOCTRINE.md by establishing the exact byte-level shapes that data must conform to when crossing any boundary—filesystem, network, IPC, or persistence layer.

A data format is a treaty between producers and consumers. Ambiguous treaties cause war. This document eliminates ambiguity.

If a format is not defined here, it does not exist in this project. Ad hoc formats are defects. Undocumented schemas are defects. Informal JSON blobs exchanged between modules without a specification are defects. Every byte that crosses a boundary does so under a contract named in this document.

---

## Section One: Governing Principles

### Principle of Explicit Schema

Every data format has a written schema. The schema defines fields, types, constraints, optionality, and semantics. Code that produces or consumes the format must validate against the schema. Schemas are not aspirational—they are enforced.

### Principle of Forward Compatibility

Formats must tolerate unknown fields without crashing. A consumer that encounters a field it does not recognize must preserve the field (if round-tripping) or ignore it (if read-only). This allows format evolution without coordinated upgrades across all producers and consumers.

### Principle of Backward Compatibility

New schema versions must accept data produced by older versions. Fields added in newer versions are optional in older data. Removed fields are not reintroduced. Renaming a field is a breaking change that requires a format version increment.

### Principle of Canonical Encoding

Each format has exactly one canonical encoding. Variations (whitespace, key ordering, numeric representation) are normalized to the canonical form before persistence or transmission. Canonical encoding enables checksumming, deduplication, and deterministic comparison.

### Principle of Text Over Binary (Where Feasible)

Text formats (JSON, TOML, YAML) are preferred for configuration, metadata, and API payloads. Binary formats (safetensors, GGUF, msgpack) are used only where text is impractical due to size or performance. Text is auditable. Binary is opaque. Prefer auditable.

### Principle of Double Quotes

All string literals in all formats throughout the project use double quotes (`"text"`), never single quotes (`'text'`). This applies to JSON, TOML, YAML, Mojo source, Python source, and any configuration file. Single quotes are a stylistic inconsistency that introduces parsing ambiguities in some formats and is forbidden.

---

## Section Two: Format Catalog

| Format ID | Name | Encoding | Use Case | Defined In |
|-----------|------|----------|----------|------------|
| FMT-GGUFA | GGUF Archive | Binary | Model packaging and distribution | Section Four |
| FMT-STENS | Safetensors | Binary | Weight storage (alternate to GGUF) | Section Five |
| FMT-APIREQ | API Request (REST) | JSON | Inbound HTTP request payloads | Section Six |
| FMT-APIRES | API Response (REST) | JSON | Outbound HTTP response payloads | Section Seven |
| FMT-STRMSG | Stream Message (SSE) | Text (SSE) | Streaming response chunks | Section Eight |
| FMT-CONFIG | Configuration File | TOML | System configuration | Section Nine |
| FMT-MODREG | Model Registry | TOML | Model path and metadata registry | Section Ten |
| FMT-KVCACH | KV Cache Snapshot | Binary (MsgPack) | Session state persistence | Section Eleven |
| FMT-SESSTA | Session State | JSON | Session metadata and resumption | Section Twelve |
| FMT-LOGSTD | Structured Log Entry | JSON | Log file and log stream output | Section Thirteen |
| FMT-METRIC | Metrics Export | Prometheus Text | Prometheus scrape endpoint | Section Fourteen |
| FMT-TOKENS | Token Sequence | Binary (internally) / JSON (externally) | Tokenized text representation | Section Fifteen |
| FMT-SAMPL | Sampler Parameters | JSON (embedded in request) | Sampling configuration | Section Sixteen |
| FMT-CHECK | Model Checksum Registry | TOML | Integrity verification data | Section Seventeen |
| FMT-SBOM | Software Bill of Materials | Markdown | Dependency and supply chain tracking | Section Eighteen |

---

## Section Three: Serialization Format Choices

### JSON — Used For

- API request and response payloads
- Session state files
- Structured log entries
- Any human-readable data interchange

**Parser**: `json` module (Mojo stdlib when available, or a vendored minimal parser)

**Constraints**:
- UTF-8 encoded only
- No BOM
- Pretty-printed in configuration files (2-space indent)
- Compact in network payloads (no extraneous whitespace)
- Maximum nesting depth: 16
- Maximum object size: 10 MB (matching HTTP body limit)
- Numbers: IEEE 754 double precision (JSON standard). Integers exceeding 2^1^ are transmitted as strings to preserve precision.

### TOML — Used For

- System configuration (`config.toml`)
- Model registry (`models.toml`)
- Checksum registry (`checksums.toml`)

**Parser**: `toml` module

**Constraints**:
- UTF-8 encoded
- Tables use dotted keys: `[section.subsection]`
- Arrays of tables use `[[array_name]]`
- Strings use double quotes: `key = "value"`
- Multiline strings use triple double quotes: `"""multi"""`
- Booleans lowercase: `true`, `false`
- Dates in ISO 8601: `2026-08-15T14:30:00Z`
- No inline tables for complex structures (split into named tables)

### MsgPack — Used For

- KV cache snapshots (binary, compact)
- Internal IPC payloads where JSON overhead is unacceptable

**Encoder**: `msgpack` module (vendored or stdlib)

**Constraints**:
- Compact mode (smallest possible representation)
- No extension types unless documented in this file
- Schema-tagged: every MsgPack payload begins with a 2-byte format identifier

### Prometheus Text Format — Used For

- Metrics export at `/metrics` endpoint

**Constraints**:
- UTF-8, line-delimited
- HELP and TYPE comments precede metric families
- Labels sorted alphabetically
- No duplicate label names within a single metric

### Safetensors — Used For

- Model weight storage (when not using GGUF)
- Direct loading into GPU memory with mmap

### GGUF — Used For

- Primary model distribution format
- Includes tokenizer, metadata, and quantized weights in a single file

---

## Section Four: GGUF Archive Format (FMT-GGUFA)

### Overview

GGUF (GPT-Generated Unified Format) is the primary model packaging format for Project Æsir. It bundles model weights, tokenizer vocabulary, and architecture metadata into a single binary file with mmap-friendly layout.

### File Structure

```
Offset  Size     Content
0x00    4        Magic bytes: "GGUF" (0x47 0x47 0x55 0x46)
0x04    4        Version (uint32 LE, current: 3)
0x08    8        Tensor count (uint64 LE)
0x10    8        Metadata KV count (uint64 LE)
0x18    variable Metadata KV pairs
...     variable Tensor infos
...     variable Tensor data (padding-aligned)
```

### Metadata KV Pairs

Metadata keys are ASCII strings. Values are typed:

| Type ID | Type | Mojo Equivalent |
|---------|------|------------------|
| 0 | uint8 | UInt8 |
| 1 | int8 | Int8 |
| 2 | uint16 | UInt16 |
| 3 | int16 | Int16 |
| 4 | uint32 | UInt32 |
| 5 | int32 | Int32 |
| 6 | float32 | Float32 |
| 7 | bool | Bool |
| 8 | string | String |
| 9 | array | Array of above types |
| 10 | uint64 | UInt64 |
| 11 | int64 | Int64 |
| 12 | float64 | Float64 |

### Required Metadata Keys

| Key | Type | Example | Purpose |
|-----|------|---------|---------|
| `general.architecture` | string | `"llama"` | Model architecture identifier |
| `general.name` | string | `"Llama-2-7B"` | Human-readable model name |
| `general.file_type` | string | `"F16"` or `"Q4_K_M"` | Weight precision indicator |
| `general.quantization_version` | uint32 | `2` | Quantization format version |
| `{arch}.context_length` | uint64 | `4096` | Maximum context window |
| `{arch}.embedding_length` | uint64 | `4096` | Hidden dimension size |
| `{arch}.block_count` | uint64 | `32` | Number of transformer layers |
| `{arch}.attention.head_count` | uint64 | `32` | Number of attention heads |
| `{arch}.attention.head_count_kv` | uint64 | `32` | Number of KV heads (GQA support) |
| `{arch}.attention.layer_norm_rms_epsilon` | float32 | `1e-5` | RMS norm epsilon |
| `{arch}.rope.dimension_count` | uint64 | `128` | RoPE dimension |
| `{arch}.rope.freq_base` | float32 | `10000.0` | RoPE base frequency |
| `tokenizer.ggml.model` | string | `"llama"` | Tokenizer type |
| `tokenizer.ggml.tokens` | array[string] | `["<s>", "</s>", ...]` | Vocabulary |
| `tokenizer.ggml.token_type` | array[int32] | `[1, 1, 2, ...]` | Token type flags |
| `tokenizer.ggml.scores` | array[float32] | `[0.0, 0.0, ...]` | Token scores (if applicable) |
| `tokenizer.ggml.bos_token_id` | uint32 | `1` | Beginning of sequence token |
| `tokenizer.ggml.eos_token_id` | uint32 | `2` | End of sequence token |
| `tokenizer.ggml.padding_token_id` | uint32 | `0` | Padding token |
| `tokenizer.ggml.unknown_token_id` | uint32 | `0` | Unknown token |

### Tensor Info Records

Each tensor info record contains:

| Field | Type | Description |
|-------|------|-------------|
| name | string | Tensor name (e.g., `token_embd.weight`) |
| ndims | uint32 | Number of dimensions |
| dims | uint64[ndims] | Dimension sizes |
| dtype | uint32 | Data type (enum) |
| offset | uint64 | Offset from start of tensor data section |

### Tensor Data Types

| ID | Name | Bits per element | Mojo DType |
|----|------|-------------------|------------|
| 0 | F32 | 32 | float32 |
| 1 | F16 | 16 | float16 |
| 2 | Q4_0 | 4 | (quantized, custom unpack) |
| 3 | Q4_1 | 4 | (quantized, custom unpack) |
| 6 | Q5_0 | 5 | (quantized, custom unpack) |
| 7 | Q5_1 | 5 | (quantized, custom unpack) |
| 8 | Q8_0 | 8 | (quantized, custom unpack) |
| 9 | Q8_1 | 8 | (quantized, custom unpack) |
| 10 | Q2_K | 2 | (K-quant, custom unpack) |
| 11 | Q3_K | 3 | (K-quant, custom unpack) |
| 12 | Q4_K | 4 | (K-quant, custom unpack) |
| 13 | Q5_K | 5 | (K-quant, custom unpack) |
| 14 | Q6_K | 6 | (K-quant, custom unpack) |
| 15 | Q8_K | 8 | unsupported by this loader |
| 16 | IQ2_XXS | 2.0625 | quantized, canonical host unpack |
| 17 | IQ2_XS | ~2 | unsupported by this loader |
| 18 | IQ3_XXS | ~3 | unsupported by this loader |
| 19 | IQ1_S | 1.5625 | quantized, canonical host unpack |
| 30 | BF16 | 16 | unsupported by this loader |
| 34 | TQ1_0 | 1.6875 | quantized, canonical host unpack |

TQ1_0 serializes 256 balanced ternary weights into 52 packed bytes followed by
one F16 scale. Its exact stored rate is 1.6875 bits per weight including that
scale; the BitNet 1.58-bit label refers to ternary information content, not the
serialized GGML block size. `TERNARY_155BIT` is the core descriptor's legacy
source-compatible alias for this on-disk format.

### Parser Validation Requirements

The GGUFSeer module MUST validate:
1. Magic bytes match `0x47475546`
2. Version is supported (currently: 3)
3. Tensor count matches actual tensor info records
4. Metadata KV count matches actual KV pairs
5. Every tensor offset + tensor byte size ≤ file size
6. Required metadata keys are present
7. No tensor name is empty or contains path separators
8. Dim arrays contain no zero-valued dimensions (scalar tensors exempted)
9. Quantization type is supported by the engine (reject unsupported, do not guess)

### Alignment and Padding

Tensor data is aligned to 32-byte boundaries. Padding bytes between tensors are zero-filled. The first tensor data offset is relative to the end of the tensor info section, not the file start.

---

## Section Five: Safetensors Format (FMT-STENS)

### Overview

Safetensors is used as an alternative weight storage format for models that are not packaged as GGUF. It provides memory-mappable storage with a JSON header describing tensor layout.

### File Structure

```
Offset  Size     Content
0x00    8        Header length (uint64 LE)
0x08    N        JSON header (UTF-8, N = header length)
0x08+N  variable Tensor data (contiguous, offset-based)
```

### JSON Header Schema

```json
{
    "__metadata__": {
        "format": "pt",
        "architecture": "llama",
        "context_length": "4096"
    },
    "token_embd.weight": {
        "dtype": "F16",
        "shape": [32000, 4096],
        "data_offsets": [0, 262144000]
    },
    "layers.0.attention.wq.weight": {
        "dtype": "BF16",
        "shape": [4096, 4096],
        "data_offsets": [262144000, 271581184]
    }
}
```

### Field Semantics

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `__metadata__` | object | No | Arbitrary metadata key-value pairs |
| `{tensor_name}.dtype` | string | Yes | One of: F32, F16, BF16, I8, I16, I32, I64, U8, U16, U32, U64 |
| `{tensor_name}.shape` | array[int] | Yes | Dimensions (row-major) |
| `{tensor_name}.data_offsets` | array[int] | Yes | [start, end] offsets relative to start of tensor data section |

### Validation Requirements

1. Header length ≤ 100 MB (sanity cap)
2. JSON header is valid UTF-8
3. Every tensor has dtype, shape, and data_offsets
4. data_offsets[0] ≤ data_offsets[1]
5. Largest data_offsets[1] ≤ file size − header length − 8
6. No overlapping tensor data regions
7. dtype string is in the supported set
8. No empty tensor names
9. No tensor names containing path separators

---

## Section Six: API Request Format (FMT-APIREQ)

### Chat Completions Request

Endpoint: `POST /v1/chat/completions`

```json
{
    "model": "llama-2-7b-q4",
    "messages": [
        {
            "role": "system",
            "content": "You are a helpful assistant."
        },
        {
            "role": "user",
            "content": "What is the capital of France?"
        }
    ],
    "temperature": 0.7,
    "top_p": 0.9,
    "top_k": 40,
    "max_tokens": 256,
    "stop": ["\n\nHuman:"],
    "stream": false,
    "frequency_penalty": 0.0,
    "presence_penalty": 0.0,
    "seed": null,
    "n": 1,
    "logprobs": false,
    "top_logprobs": null,
    "user": null
}
```

### Field Specification

| Field | Type | Required | Default | Constraints |
|--------|------|----------|---------|-------------|
| `model` | string | Yes | — | Non-empty, ≤ 128 chars, no path separators, must be in registry |
| `messages` | array[object] | Yes | — | Non-empty, 1-1000 entries, alternating roles permitted |
| `messages[].role` | string | Yes | — | One of: `"system"`, `"user"`, `"assistant"` |
| `messages[].content` | string | Yes | — | Non-empty (for non-system), ≤ context_window tokens |
| `temperature` | float | No | `1.0` | 0.0 ≤ v ≤ 2.0, not NaN, not Inf |
| `top_p` | float | No | `1.0` | 0.0 < v ≤ 1.0, not NaN, not Inf |
| `top_k` | int | No | `0` (disabled) | 0 ≤ v ≤ 1000 |
| `max_tokens` | int | No | `256` | 1 ≤ v ≤ 4096 |
| `stop` | array[string] | No | `[]` | ≤ 4 entries, each ≤ 64 chars, no duplicates |
| `stream` | bool | No | `false` | — |
| `frequency_penalty` | float | No | `0.0` | -2.0 ≤ v ≤ 2.0 |
| `presence_penalty` | float | No | `0.0` | -2.0 ≤ v ≤ 2.0 |
| `seed` | int \| null | No | `null` | 0 ≤ v ≤ 2^2^−1 |
| `n` | int | No | `1` | 1 ≤ v ≤ 4 (limited for resource conservation) |
| `logprobs` | bool | No | `false` | — |
| `top_logprobs` | int \| null | No | `null` | If present: 0 ≤ v ≤ 20, requires `logprobs: true` |
| `user` | string \| null | No | `null` | ≤ 128 chars, for tracking only, not used in generation |

### Completions Request

Endpoint: `POST /v1/completions`

```json
{
    "model": "llama-2-7b-q4",
    "prompt": "Once upon a time",
    "temperature": 0.8,
    "max_tokens": 100,
    "stream": false
}
```

Additional fields beyond chat completions:

| Field | Type | Required | Default | Constraints |
|--------|------|----------|---------|-------------|
| `prompt` | string \| array[string] | Yes | — | Non-empty, ≤ context_window tokens per entry, ≤ 4 entries if array |
| `suffix` | string \| null | No | `null` | ≤ 256 chars, appended after generation |
| `echo` | bool | No | `false` | If true, include prompt in response |
| `logit_bias` | object \| null | No | `null` | Map of token_id → bias (-100 to 100), ≤ 100 entries |

### Embeddings Request

Endpoint: `POST /v1/embeddings`

```json
{
    "model": "llama-2-7b-q4",
    "input": "text to embed"
}
```

| Field | Type | Required | Default | Constraints |
|--------|------|----------|---------|-------------|
| `input` | string \| array[string] | Yes | — | Non-empty, ≤ 2048 tokens per entry, ≤ 64 entries if array |
| `encoding_format` | string | No | `"float"` | One of: `"float"`, `"base64"` |
| `dimensions` | int | No | model default | 1 ≤ v ≤ embedding_dimension |

### Canonical Ordering

Fields in serialized JSON output are alphabetically ordered. This ensures deterministic output for caching, checksumming, and testing. Input ordering is not mandated (JSON objects are unordered by definition).

---

## Section Seven: API Response Format (FMT-APIRES)

### Chat Completions Response (Non-Streaming)

```json
{
    "id": "chatcmpl-a1b2c3d4e5f6",
    "object": "chat.completion",
    "created": 1723737600,
    "model": "llama-2-7b-q4",
    "choices": [
        {
            "index": 0,
            "message": {
                "role": "assistant",
                "content": "The capital of France is Paris."
            },
            "finish_reason": "stop"
        }
    ],
    "usage": {
        "prompt_tokens": 52,
        "completion_tokens": 8,
        "total_tokens": 60
    }
}
```

### Field Specification

| Field | Type | Always Present | Description |
|--------|------|-----------------|-------------|
| `id` | string | Yes | Unique request ID, format: `chatcmpl-[16 hex chars]` |
| `object` | string | Yes | Constant: `"chat.completion"` |
| `created` | int | Yes | Unix timestamp (seconds) |
| `model` | string | Yes | Model name as resolved from registry |
| `choices` | array[object] | Yes | 1 to `n` entries |
| `choices[].index` | int | Yes | 0-indexed position |
| `choices[].message.role` | string | Yes | Always `"assistant"` |
| `choices[].message.content` | string | Yes | Generated text (may be empty if interrupted) |
| `choices[].finish_reason` | string | Yes | One of: `"stop"`, `"length"`, `"content_filter"`, `"tool_calls"` |
| `choices[].logprobs` | object \| null | If requested | Token logprob data |
| `usage.prompt_tokens` | int | Yes | Token count of input |
| `usage.completion_tokens` | int | Yes | Token count of output |
| `usage.total_tokens` | int | Yes | Sum of above |

### Finish Reason Semantics

| Value | Meaning |
|-------|---------|
| `"stop"` | Natural termination (EOS token or stop sequence matched) |
| `"length"` | Hit max_tokens limit |
| `"content_filter"` | Output filtered by downstream safety layer (not implemented by engine itself) |
| `"tool_calls"` | Model indicated a tool call (not implemented; reserved) |

### Completions Response

```json
{
    "id": "cmpl-a1b2c3d4e5f6",
    "object": "text_completion",
    "created": 1723737600,
    "model": "llama-2-7b-q4",
    "choices": [
        {
            "text": ", there was a dragon.",
            "index": 0,
            "logprobs": null,
            "finish_reason": "length"
        }
    ],
    "usage": {
        "prompt_tokens": 4,
        "completion_tokens": 5,
        "total_tokens": 9
    }
}
```

### Embeddings Response

```json
{
    "object": "list",
    "data": [
        {
            "object": "embedding",
            "index": 0,
            "embedding": [0.0023, -0.0091, 0.0156, ...]
        }
    ],
    "model": "llama-2-7b-q4",
    "usage": {
        "prompt_tokens": 3,
        "total_tokens": 3
    }
}
```

### Error Response

Defined in ERROR_TAXONOMY.md, Section Sixteen. Repeated here for completeness:

```json
{
    "error": {
        "type": "invalid_request_error",
        "code": "VAL-003",
        "param": "temperature",
        "message": "Temperature value 3.5 is out of range [0.0, 2.0]",
        "request_id": "req_a1b2c3d4"
    }
}
```

---

## Section Eight: Stream Message Format (FMT-STRMSG)

### SSE Framing

Streaming responses use Server-Sent Events (SSE) framing:

```
data: {"id":"chatcmpl-a1b2","object":"chat.completion.chunk","created":1723737600,"model":"llama-2-7b-q4","choices":[{"index":0,"delta":{"role":"assistant"},"finish_reason":null}]}

data: {"id":"chatcmpl-a1b2","object":"chat.completion.chunk","created":1723737600,"model":"llama-2-7b-q4","choices":[{"index":0,"delta":{"content":"The"},"finish_reason":null}]}

data: {"id":"chatcmpl-a1b2","object":"chat.completion.chunk","created":1723737600,"model":"llama-2-7b-q4","choices":[{"index":0,"delta":{"content":" capital"},"finish_reason":null}]}

data: {"id":"chatcmpl-a1b2","object":"chat.completion.chunk","created":1723737600,"model":"llama-2-7b-q4","choices":[{"index":0,"delta":{},"finish_reason":"stop"}],"usage":{"prompt_tokens":52,"completion_tokens":8,"total_tokens":60}}

data: [DONE]
```

### Delta Object

The `delta` field contains only the changed portion of the message:

| Stage | Delta Content |
|-------|---------------|
| First chunk | `{"role": "assistant"}` (no content yet) |
| Middle chunks | `{"content": "[token_text]"}` |
| Final chunk | `{}` (empty, accompanied by `finish_reason`) |

### Terminator

The stream concludes with `data: [DONE]\n\n`. This sentinel is sent after the final data chunk. Clients must close the connection upon receiving it.

### Error During Stream

If an error occurs mid-stream, a final error chunk is sent:

```
data: {"error":{"type":"server_error","code":"INF-001","message":"Forward pass failed","request_id":"req_a1b2"}}
```

The connection is then closed by the server. No `[DONE]` sentinel is sent for errored streams.

### Heartbeat

To keep connections alive through proxies, a comment line is sent every 15 seconds of inactivity:

```
: heartbeat
```

Comment lines start with `:` and are ignored by compliant SSE clients.

---

## Section Nine: Configuration File Format (FMT-CONFIG)

### File: `config.toml`

```toml
[server]
host = "127.0.0.1"
port = 8080
workers = 4
max_connections = 100
request_timeout_seconds = 30

[tls]
enabled = false
cert_file = ""
key_file = ""

[auth]
enabled = false
keys = []
rate_limit_per_minute = 60

[models]
registry_file = "config/models.toml"
default_model = "llama-2-7b-q4"

[inference]
max_context_length = 4096
max_concurrent_sessions = 32
gpu_memory_utilization = 0.90
enable_prefix_caching = true
enable_chunked_prefill = true
chunk_size = 512

[scheduler]
policy = "fcfs"  # fcfs | priority | fair
max_num_seqs = 64
max_num_batched_tokens = 4096

[kv_cache]
block_size = 16
swap_space_gb = 4.0

[logging]
level = "info"  # trace | debug | info | warn | error
stdout = true
file_path = "logs/aesir.log"
rotation_size_mb = 100
retention_days = 90

[metrics]
enabled = true
path = "/metrics"

[model_verification]
enabled = false
checksums_file = "config/checksums.toml"
fail_on_mismatch = true

[gpu]
device_id = 0
cuda_graph_enabled = true
flash_attention = true
```

### Validation Rules

1. All fields have type-annotated defaults. Missing optional fields use defaults.
2. Required fields (marked in schema) must be present or CFG-004 is raised.
3. Unknown fields trigger CFG-005 (warning) and are ignored.
4. Numeric ranges are validated at load time (e.g., `gpu_memory_utilization` must be 0.0–1.0).
5. Enum fields (`policy`, `level`) must match allowed values exactly.
6. File path fields are validated for readability at startup (fail-fast).
7. Environment variable substitution is supported: `${VAR_NAME}` in string values is replaced with the environment variable's value. Undefined variables cause CFG-004.

---

## Section Ten: Model Registry Format (FMT-MODREG)

### File: `config/models.toml`

```toml
[[models]]
name = "llama-2-7b-q4"
path = "models/llama-2-7b-chat.Q4_K_M.gguf"
architecture = "llama"
context_length = 4096
quantization = "Q4_K_M"
enabled = true

[[models]]
name = "mistral-7b-q5"
path = "models/mistral-7b-instruct-v0.2.Q5_K_M.gguf"
architecture = "llama"
context_length = 32768
quantization = "Q5_K_M"
enabled = true

[[models]]
name = "phi-3-mini-q8"
path = "models/Phi-3-mini-4k-instruct.Q8_0.gguf"
architecture = "phi3"
context_length = 4096
quantization = "Q8_0"
enabled = false
```

### Field Specification

| Field | Type | Required | Default | Constraints |
|--------|------|----------|---------|-------------|
| `name` | string | Yes | — | Unique, non-empty, ≤ 128 chars, no path separators |
| `path` | string | Yes | — | Relative to models directory, file must exist |
| `architecture` | string | Yes | — | Must be in supported architecture list |
| `context_length` | int | No | From model metadata | 128 ≤ v ≤ 131072 |
| `quantization` | string | No | From model metadata | Must be in supported quantization list |
| `enabled` | bool | No | `true` | Disabled models are not listed in API responses |

### Path Resolution

Paths are resolved relative to the configured models directory, not relative to the configuration file or working directory. This enforces location-agnostic operation per the Law of Flexible Roots.

Resolution order:
1. Join models_directory + configured path
2. Normalize (resolve `..` and `.`)
3. Verify normalized path is within models_directory (path traversal defense)
4. Verify file exists and is readable

---

## Section Eleven: KV Cache Snapshot Format (FMT-KVCACH)

### Purpose

KV cache snapshots allow session suspension and resumption. A snapshot captures the full KV cache state for a session so generation can continue without recomputing the prompt.

### File Extension

`.kvcache`

### Encoding

MsgPack with a 2-byte format identifier prefix:

| Bytes | Value | Meaning |
|-------|-------|---------|
| 0x00 | 0xAE | Magic byte 1 ("A" for Æsir) |
| 0x01 | 0x4B | Magic byte 2 ("K" for KV) |
| 0x02 | 0x01 | Format version (currently 1) |

### Payload Structure (after prefix)

```
[
    format_header: {
        "version": 1,
        "model_architecture": "llama",
        "model_quantization": "Q4_K_M",
        "context_length": 4096,
        "n_layers": 32,
        "n_heads_kv": 32,
        "head_dim": 128,
        "block_size": 16,
        "snapshot_created": 1723737600
    },
    session_metadata: {
        "session_id": "sess_a1b2c3...",
        "prompt_tokens": 256,
        "generated_tokens": 64,
        "total_tokens": 320
    },
    blocks: [
        {
            "block_index": 0,
            "slot": 3,
            "token_range": [0, 16],
            "data_size": 1048576,
            "data_hash": "sha256:..."
        },
        ...
    ]
]
```

### Binary Data Region

After the MsgPack-encoded metadata, the actual KV cache data follows as a contiguous binary blob. Each block's data is located at `blocks[i].data_offset` from the start of the binary region.

### Integrity

Each block includes a SHA-256 hash of its uncompressed data. On load, hashes are verified. Mismatch triggers MEM-009 (page table corruption analog) or a dedicated KVCACHE_CHECKSUM_MISMATCH error.

### Compression

Snapshot data is optionally compressed with LZ4 (fast) or zstd (compact). The compression algorithm is recorded in the format header. Uncompressed snapshots are permitted for maximum load speed.

---

## Section Twelve: Session State Format (FMT-SESSTA)

### File Extension

`.session.json`

### Schema

```json
{
    "session_id": "sess_a1b2c3d4e5f6a7b8",
    "model": "llama-2-7b-q4",
    "created_at": 1723737600,
    "last_active": 1723741200,
    "state": "idle",
    "prompt_tokens": 256,
    "generated_tokens": 128,
    "conversation": [
        {
            "role": "system",
            "content": "You are a helpful assistant.",
            "tokens": 9
        },
        {
            "role": "user",
            "content": "Tell me about Norway.",
            "tokens": 7
        },
        {
            "role": "assistant",
            "content": "Norway is a Scandinavian country...",
            "tokens": 128
        }
    ],
    "sampler_params": {
        "temperature": 0.7,
        "top_p": 0.9,
        "top_k": 40
    },
    "kv_cache_ref": "sessions/sess_a1b2c3.kvcache"
}
```

### State Machine Values

| State | Meaning |
|-------|---------|
| `"idle"` | Session exists, no active generation |
| `"generating"` | Generation in progress |
| `"paused"` | Session paused by user or system |
| `"expired"` | Session timed out, awaiting cleanup |
| `"errored"` | Last generation failed catastrophically |

### Conversation Entry

Each conversation entry records:
- `role`: Who produced the message
- `content`: The text content
- `tokens`: Token count (stored for budget tracking without re-tokenization)

The conversation array is append-only. Edits create new entries; they do not mutate existing ones. This preserves audit trail integrity.

---

## Section Thirteen: Structured Log Format (FMT-LOGSTD)

### Schema

Each log entry is a single JSON object on one line (JSON Lines / NDJSON format):

```json
{"ts":"2026-08-15T14:30:00.123456Z","level":"info","module":"BrainForge","event":"generation_complete","session_id":"sess_a1b2","request_id":"req_a1b2","duration_ms":450,"tokens":128,"extra":{"cache_hit_ratio":0.82}}
```

### Field Specification

| Field | Type | Always Present | Description |
|--------|------|-----------------|-------------|
| `ts` | string | Yes | RFC 3339 timestamp with microsecond precision |
| `level` | string | Yes | One of: `trace`, `debug`, `info`, `warn`, `error`, `critical`, `fatal` |
| `module` | string | Yes | Module name where the event originates |
| `event` | string | Yes | Event identifier (snake_case) |
| `session_id` | string | No | Associated session (omitted for system-level events) |
| `request_id` | string | No | Associated request (omitted for non-request events) |
| `duration_ms` | int | No | Duration in milliseconds (for timed events) |
| `extra` | object | No | Additional structured context (free-form, module-specific) |

### Sanitization

Before serialization:
- All user-supplied content is excluded (no prompt text, no generated text)
- API keys are replaced with hash prefix: `key_ab12****`
- File paths are relativized to project root (no absolute paths in logs)
- Control characters in any string field are escaped
- Newlines within field values are escaped to literal `\n`

### File Rotation

Log files rotate when they reach `rotation_size_mb` (default: 100 MB). Rotated files are named `aesir.log.YYYY-MM-DD.N`. Retention is `retention_days` (default: 90). Deleted rotated files are securely erased (overwrite with zeros before unlink) if configured.

---

## Section Fourteen: Metrics Export Format (FMT-METRIC)

### Endpoint

`GET /metrics` (Prometheus exposition format)

### Metric Families

```
# HELP aesir_requests_total Total number of API requests received
# TYPE aesir_requests_total counter
aesir_requests_total{endpoint="/v1/chat/completions"} 1542
aesir_requests_total{endpoint="/v1/completions"} 203
aesir_requests_total{endpoint="/v1/embeddings"} 17

# HELP aesir_tokens_generated_total Total tokens generated
# TYPE aesir_tokens_generated_total counter
aesir_tokens_generated_total{model="llama-2-7b-q4"} 198432

# HELP aesir_ttft_seconds Time to first token in seconds
# TYPE aesir_ttft_seconds histogram
aesir_ttft_seconds_bucket{le="0.05"} 1342
aesir_ttft_seconds_bucket{le="0.1"} 1498
aesir_ttft_seconds_bucket{le="0.25"} 1521
aesir_ttft_seconds_bucket{le="0.5"} 1538
aesir_ttft_seconds_bucket{le="1.0"} 1541
aesir_ttft_seconds_bucket{le="+Inf"} 1542
aesir_ttft_seconds_sum 112.34
aesir_ttft_seconds_count 1542

# HELP aesir_gpu_memory_bytes GPU memory usage in bytes
# TYPE aesir_gpu_memory_bytes gauge
aesir_gpu_memory_bytes{device="0",type="used"} 17179869184
aesir_gpu_memory_bytes{device="0",type="total"} 25769803776

# HELP aesir_kv_cache_blocks KV cache block utilization
# TYPE aesir_kv_cache_blocks gauge
aesir_kv_cache_blocks{state="used"} 148
aesir_kv_cache_blocks{state="free"} 116
aesir_kv_cache_blocks{state="swapped"} 0

# HELP aesir_errors_total Total errors by category
# TYPE aesir_errors_total counter
aesir_errors_total{category="val"} 178
aesir_errors_total{category="net"} 45
aesir_errors_total{category="tok"} 12
```

### Label Cardinality Rules

- Labels with unbounded values (timestamps, request_ids, session_ids) are forbidden
- Label values must be ≤ 64 characters
- Total label count per metric ≤ 10
- Cardinally explosive patterns (user IDs, prompt hashes) are aggregated, not labeled individually

---

## Section Fifteen: Token Sequence Format (FMT-TOKENS)

### Internal Representation

Internally, token sequences are stored as Mojo `List[Int32]` (or `SIMD[DType.int32, N]` for vectorized operations). This is a runtime detail, not a serialization format.

### External Representation

When tokens are included in API responses (e.g., for debugging or logprob data), they are represented as JSON arrays of integers:

```json
{"tokens": [1, 450, 2104, 299]}
```

### Token Type Flags

Token type metadata (from GGUF tokenizer) uses bitmask values:

| Flag | Value | Meaning |
|------|-------|---------|
| NORMAL | 1 | Regular vocabulary token |
| UNKNOWN | 2 | Out-of-vocabulary fallback |
| CONTROL | 3 | Special control token (BOS, EOS, PAD) |
| UNUSED | 4 | Defined but not utilized |
| BYTE | 5 | Raw byte token (byte-level BPE) |

---

## Section Sixteen: Sampler Parameters Format (FMT-SAMPL)

### Embedded in Request

Sampler parameters are embedded within the API request JSON (defined in Section Six). They are not a standalone file format.

### Internal Canonical Form

When sampler parameters are extracted from a request, they are converted to an internal canonical struct:

```mojo
struct SamplerParams:
    var temperature: Float32       # 0.0 to 2.0
    var top_p: Float32             # 0.0 to 1.0
    var top_k: Int32               # 0 (disabled) to 1000
    var max_tokens: Int32          # 1 to 4096
    var stop_sequences: List[String]  # 0 to 4 entries
    var frequency_penalty: Float32 # -2.0 to 2.0
    var presence_penalty: Float32  # -2.0 to 2.0
    var seed: Optional[Int64]      # None or 0 to 2^2^-1
    var n: Int32                   # 1 to 4
    var logprobs: Bool             # true/false
    var top_logprobs: Optional[Int32]  # None or 0 to 20
    var logit_bias: Optional[Dict[Int32, Float32]]  # None or ≤100 entries
```

### Defaults

Missing fields from incoming requests are populated with defaults before being passed to the inference engine. The defaults are:

| Parameter | Default |
|-----------|---------|
| `temperature` | 1.0 |
| `top_p` | 1.0 |
| `top_k` | 0 |
| `max_tokens` | 256 |
| `stop` | [] |
| `frequency_penalty` | 0.0 |
| `presence_penalty` | 0.0 |
| `seed` | None |
| `n` | 1 |
| `logprobs` | false |
| `top_logprobs` | None |
| `logit_bias` | None |

Defaults are defined in code (not in configuration) because they reflect the API contract, not deployment environment.

---

## Section Seventeen: Model Checksum Registry (FMT-CHECK)

### File: `config/checksums.toml`

```toml
[[entries]]
model = "llama-2-7b-q4"
file = "models/llama-2-7b-chat.Q4_K_M.gguf"
sha256 = "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2"
size = 4371224576
recorded = "2026-08-10"

[[entries]]
model = "mistral-7b-q5"
file = "models/mistral-7b-instruct-v0.2.Q5_K_M.gguf"
sha256 = "d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3"
size = 5202151424
recorded = "2026-08-12"
```

### Validation

On model load (when verification is enabled):
1. Lookup model name in checksum registry
2. Compute SHA-256 of model file (streaming, constant memory)
3. Compare computed hash with recorded hash (constant-time comparison)
4. If mismatch: raise MDL-013 (CHECKSUM_MISMATCH, Critical severity)
5. If file size also recorded, verify size matches (cheap preliminary check)

---

## Section Eighteen: Software Bill of Materials (FMT-SBOM)

### File: `docs/SBOM.md`

Format: Markdown table (human-readable) plus machine-parseable structure.

```markdown
# Software Bill of Materials — Project Æsir

## Direct Dependencies

| Name | Version | License | Supplier | Type | Introduced |
|------|---------|---------|----------|------|------------|
| Mojo Stdlib | >=1.0.0 | Apache-2.0 | Modular | Build+Runtime | 2026-08-01 |
| zlib | 1.3.1 | Zlib | madler | Runtime | 2026-08-10 |

## Transitive Dependencies

(Dependencies brought in by direct dependencies)

| Name | Version | License | Required By | Type |
|------|---------|---------|-------------|------|
| (none currently) | — | — | — | — |

## Verification

- Last audit: 2026-08-15
- Audited by: Auditor role
- Findings: (none)
```

### Machine-Readable Variant

A JSON representation is also maintained at `docs/sbom.json` for tooling:

```json
{
    "sbom_version": "1.0",
    "project": "aesir",
    "generated": "2026-08-15T14:30:00Z",
    "dependencies": [
        {
            "name": "Mojo Stdlib",
            "version": ">=1.0.0",
            "license": "Apache-2.0",
            "supplier": "Modular",
            "type": "runtime",
            "transitive": false
        }
    ]
}
```

---

## Section Eighteen A: Quantized GEMM Tuning Cache (FMT-QGTC)

`QuantizedGEMMAutotuner.serialize_cache()` emits a UTF-8, newline-delimited,
bounded cache record. Core returns the bytes to its caller and does not choose a
path or perform file I/O. `DurableQuantizationTuningCache` stores the record as
`quantization-tuning.v1` beneath a validated relative root using a locked final
directory, private staging file, file sync, atomic rename, and directory sync.

```text
AESIR_QGEMM_TUNING_CACHE_V1
BUILD:<lowercase hex of 1..128 printable ASCII bytes>
COUNT:<0..configured cache capacity>
ENTRY:<device-key hex>:<format>:<M>:<N>:<K>:<strategy>:<fused-ns>:<dequantized-ns>:<iterations>
CHECKSUM:<16 lowercase hex FNV-1a-64 over every preceding line joined by LF>
```

There are exactly `COUNT` entry lines and no trailing line. Numeric fields are
unsigned canonical decimal. Format is an internal `CompressedFormatType` value;
strategy `0` means fused raw packed GEMM and `1` means dequantize then F16 GEMM.
Dimensions, durations, and iterations must be positive; `K` must contain complete
blocks for the named format. The complete record is at most 1 MiB. Restore
requires the caller's expected build fingerprint to match, rejects duplicates,
unknown/external-metadata formats, malformed fields, count drift, and checksum
failure, and commits the parsed entries only after the entire record validates.

## Section Nineteen: Versioning and Evolution

### Format Version Numbers

Each format that includes a version field (GGUF, KV cache snapshot, SBOM) follows semantic versioning:

- **Major**: Breaking change (fields removed, semantics changed, encoding altered)
- **Minor**: Additive change (new optional fields, new enum values)
- **Patch**: Clarification (documentation renew, no schema alteration)

### Breaking Change Procedure

When a format requires a major version increment:

1. The new version is implemented alongside the old version (both supported).
2. A deprecation notice is added to the format documentation.
3. Writers produce the new version by default. Readers accept both.
4. After one release cycle, readers reject the old version.
5. The old version is removed from the document.

### Format Deprecation Policy

Formats are deprecated, not deleted. A deprecated format remains readable for one major release after deprecation. This ensures old session snapshots and logs remain interpretable.

---

## Section Twenty: Validation Enforcement

### Compile-Time Validation

Where possible, format schemas are expressed as Mojo structs with compile-time-checked field types. The compiler enforces structural conformance before runtime validation.

### Runtime Validation

At module boundaries, every incoming data structure is validated against its schema before processing. Validation includes:

1. Required field presence
2. Type conformance
3. Value range checks
4. String length and encoding checks
5. Array size limits
6. Enum membership

Failed validation produces the appropriate VAL-* error (see ERROR_TAXONOMY.md).

### Fuzz Testing

The Auditor role conducts fuzz testing on all format parsers:

| Target | Fuzzer | Campaign Duration | Success Criterion |
|--------|--------|-------------------|--------------------|
| GGUF parser | AFL++ | 24 hours | No crashes, no memory safety violations |
| JSON API parser | libFuzzer | 8 hours | No crashes, proper error return for malformed importing |
| TOML config parser | AFL++ | 8 hours | No crashes, proper error message for malformed importing |
| KV cache serializer | Custom | 4 hours | Round-trip integrity (serialize→deserialize→compare) |

---

## Section Twenty-One: Quick Reference

```
CHOOSING A FORMAT:
□ Is it configuration? → TOML
□ Is it an API payload? → JSON
□ Is it large binary data (weights)? → GGUF or Safetensors
□ Is it internal IPC needing compactness? → MsgPack
□ Is it metrics? → Prometheus text
□ Is it logs? → JSON Lines
□ Is it session state? → JSON (.session.json) + MsgPack (.kvcache)
□ Is it a bill of materials? → Markdown + JSON

SERIALIZING DATA:
□ Schema defined in this document?
□ Double quotes used for all strings?
□ Unknown fields tolerated (forward compat)?
□ Required fields validated?
□ Value ranges enforced?
□ Canonical encoding applied?

PARSING UNTRUSTED DATA:
□ Magic bytes/header validated first?
□ Size limits enforced before allocating?
□ Integer overflow defended?
□ Path traversal prevented?
□ Decompression ratio capped?
□ Malformed input produces defined error code?

VERSIONING:
□ Format version field included?
□ Reader supports current and previous major version?
□ Writer produces current major version?
```

---

## Closing Principle

Data formats are the ligature of a system—the connective tissue that binds modules together and the interface through which the system speaks to the outside world. Poorly defined formats produce mistranslation. Well-defined formats produce interoperability without ambiguity.

Every byte that crosses a boundary does so under a contract. Every contract is documented here. Every deviation from the contract is an error, not a quirk. Every error has a code, a recovery path, and a test.

The formats defined in this document are not suggestions. They are the law of the land. Build accordingly, serialize accordingly, and parse with paranoid rigor.

---

*Last updated: 2026-09-01. Maintained by the Architect role. Format additions or modifications require Architect review. Parser implementations require Auditor fuzz-testing certification before merge.*

---
