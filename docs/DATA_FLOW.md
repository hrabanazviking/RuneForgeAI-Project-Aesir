# Project A.E.S.I.R. current data flows

**Current as of September 1, 2026.** This map describes executable paths in the
current repository. The [capability ledger](../CAPABILITY_LEDGER.md) remains the
authority for evidence status and limits. Vision documents describe direction;
they do not add runtime edges to this map.

## Command routing

```mermaid
flowchart LR
    User --> Main[main.mojo]
    Main --> Dispatch[cli/commands.mojo]
    Dispatch -->|run| CPU[AesirEngine CPU path]
    Dispatch -->|run/chat --accel cuda| CUDA[Native CUDA profile]
    Dispatch -->|serve| Service[Authenticated loopback service]
    Dispatch -->|pull| Hub[Hugging Face downloader]
    Dispatch -->|create/list/show/cp/rm/verify| Store[Durable catalog + SHA-256 blobs]
    Dispatch -->|config/hardware/compute| Inspect[Validation and observation]
    Dispatch -->|reserved command| Reject[Explicit unsupported error]
```

`dispatch_command()` separates recognized options from positionals, validates
option ownership, and rejects accepted-but-unconnected intent before model
loading. `run` selects the CPU path or one of the two native CUDA profiles.
`chat` is CUDA-only. Reserved daemon, process-control, push, external-engine,
ONNX-execution, and swarm commands fail explicitly.

## Public Hugging Face GGUF download

```mermaid
sequenceDiagram
    participant U as CLI caller
    participant C as dispatch_pull
    participant H as HuggingFaceSeer
    participant P as curl / sha256sum
    participant F as caller-selected filesystem

    U->>C: owner/name, filename, revision, size, SHA-256, output
    C->>C: validate flags, duplicates, ranges, path intent
    C->>H: download_hf_model(...)
    H->>H: validate exact repository identity and immutable pin
    H->>F: create exclusive staged file
    H->>P: checked argv; HTTPS-only download
    opt 2..8 connections
        H->>P: bounded HTTP byte ranges
        H->>F: verify each range and assemble in order
    end
    H->>F: verify byte count and GGUF v3 header
    H->>P: calculate SHA-256 through checked argv
    H->>F: fsync and publish without overwrite
    H-->>U: verified size, digest, and revision
```

The downloader handles one public, pinned GGUF artifact. It does not use a
shell, accept insecure redirects, overwrite a destination, populate engine
memory, register the artifact in the recipe catalog, authenticate to the Hub,
resume an interrupted transfer, or infer model compatibility from its name.

## Native CPU GGUF inference

```mermaid
sequenceDiagram
    participant U as run caller
    participant E as AesirEngine
    participant G as GGUFSeer
    participant T as RuneWeaver
    participant M as MimirWell / KVCache
    participant I as forward_pass

    U->>E: model path, prompt, max tokens
    E->>E: reject accelerator/NPU/multi-device intent
    E->>G: open and read-only mmap GGUF
    G->>G: parse bounded metadata, vocabulary, tensor descriptors
    G->>M: copy/convert admitted tensors into owned arena regions
    E->>T: encode prompt
    E->>M: allocate request-owned KV cache
    loop prompt prefill and greedy generation
        E->>I: token history, absolute position, model descriptors, KV
        I->>M: use request workspace; retain KV positions
        I-->>E: argmax token ID
        E->>T: decode visible token text
        E->>E: apply EOS/token/string/context/length stop policy
    end
    E->>M: restore arena to runtime offset
    E-->>U: GenerationResult
```

The external `E-REAL` fixture establishes this narrow F16 CPU path. Logical
host sharding tests prove partition arithmetic and sequential host reconstruction
only. They do not create concurrent workers or execute on multiple GPUs.

## Native CUDA inference profiles

```mermaid
flowchart TD
    Admission[run/chat/serve admission] --> Inspect[GGUF metadata inspection]
    Inspect --> Detect{profile}
    Detect -->|dense Gemma 4 E4B Q4_K_M| Gemma[Gemma4CUDASession]
    Detect -->|Llama 3 8B Q4_K_S| Llama[Llama3CUDASession]
    Detect -->|anything else| Refuse[Reject unsupported profile]
    Gemma --> Select[Observed CUDA device selection]
    Llama --> Select
    Select --> Budget[Host and device memory admission]
    Budget --> Load[Allocate and copy packed weights / runtime buffers]
    Load --> Generate[Persistent serialized CUDA session]
    Generate --> Output[Host tokenization, scheduling, decode, and I/O]
```

Both profile implementations keep packed model weights, activations, KV cache,
model math, logits, and token selection on the selected NVIDIA device. Host code
owns admission, tokenization, scheduling, decoded output, transcripts, deadlines,
and Ctrl+C observation. There is no CPU fallback after CUDA admission and no
in-flight kernel preemption. Unsupported architecture, quantization, context,
memory, or device combinations fail before claiming execution.

Interactive and prompt-file chat retain one loaded CUDA session across turns.
`/clear` resets session state while keeping weights loaded. A cancelled decode
closes the turn; cancellation during prefill marks the session reset-required.
The documented Gemma and Stheno 20-turn transcripts are evidence for their exact
profiles and hardware, not for arbitrary GGUF models.

## Authenticated native loopback service

```mermaid
sequenceDiagram
    participant O as Operator
    participant S as native_serve
    participant L as local_transport / local_protocol
    participant E as ControlledTextSession
    participant C as Client

    O->>S: serve model --accel cuda --api-key-file private-file
    S->>S: validate key file, model profile, device, memory, limits
    S->>L: bind authenticated IPv4 loopback listener
    C->>L: bounded HTTP request + bearer credential
    L->>L: parse strict request line, headers, length, and flat JSON
    L->>L: constant-time compare equal-length credentials
    L->>E: begin one serialized stateless generation request
    loop until stop, deadline, cancellation, or error
        L->>E: next_chunk()
        E-->>L: decoded text chunk / status
    end
    L-->>C: bounded HTTP response
    L->>L: record sequence, phase, status, elapsed time; omit prompt/response/key
```

The service supports one serialized request at a time and resets the model
session between requests. It has strict I/O and generation deadlines and
cooperative shutdown. It is not the legacy `BifrostGate` route scaffold and
does not claim OpenAI, Ollama, or llama.cpp compatibility. Those legacy-shaped
routes return HTTP 501.

## Durable catalog and content-addressed blobs

```mermaid
sequenceDiagram
    participant C as CLI process
    participant D as DurableModelStore
    participant F as .aesir/models/catalog.v1
    participant B as .aesir/models/blobs/sha256/digest

    C->>D: create/cp/rm/verify or list/show
    D->>D: validate configured relative root
    alt mutation
        D->>D: create root and acquire directory lock
        D->>F: read bounded versioned catalog without following final symlink
        D->>D: parse strict count and delimiter-safe manifests
        D->>D: apply mutation to candidate state
        opt create --model
            D->>B: copy exact open inode, fsync, SHA-256, linkat publish
            D->>B: verify existing digest before deduplication
        end
        D->>F: stage, fsync, atomic rename, directory fsync
        D->>D: publish candidate in memory
    else read
        D->>F: reopen and strictly parse current catalog
    end
    D-->>C: measured/recipe records or explicit error
```

Catalog records contain validated Modelfile recipes. Recipe-only records use a
deterministic non-cryptographic fingerprint. `create --model` records measured
SHA-256 and size for an immutable shared blob, and `verify` performs a full
rehash. Automatic pull registration, reference-aware garbage collection,
`ps`, `stop`, upload, and live session ownership are not implemented.

## Standalone local primitives

- `StateVault` persists a strict versioned marker containing token position,
  prompt count, timestamp, and an FNV-1a corruption checksum. Writes use staged
  sync, atomic same-directory replacement, and directory sync. No generation
  loop automatically consumes the marker, and it contains no model, tensor, KV,
  sampler, process, thread, or socket state.
- `AesirEventBus` is a bounded synchronous in-process journal with filtered
  subscriber mailboxes. It has no worker, lock, acknowledgement, retry, durable
  replay, or cross-process delivery.
- `RuneThreadPool` stores bounded task descriptors and cancellation/admission
  state. It creates no worker and executes no payload.
- `ErrorGuard` offers sentinel-address and one-index predicates plus NaN/Inf
  replacement for a valid caller-owned Float16 span. It is not wired into the
  current generation loops and cannot prove pointer provenance or alignment.
- `SkaldbrodirDetector`, thought redaction, strict tool-call JSON, grammar token
  text masking, and speculative acceptance arithmetic are bounded standalone
  components. Their wider model-loop integrations remain absent as specified in
  the ledger.

## Explicitly absent execution edges

```mermaid
flowchart LR
    Requested[Requested capability] --> Boundary{implemented end to end?}
    Boundary -->|yes, admitted profile| Execute[Execute and report observations]
    Boundary -->|no| Error[Raise or return explicit unsupported/HTTP 501]
```

There is no execution edge for AMD HIP, Intel Level Zero, Apple Metal, NPU,
multi-GPU, MAX graph execution, ONNX graphs, EXL2, llama.cpp delegation, swarm
networking, automatic RAG ingestion, speculative model execution, general GBNF,
tool execution, or the experimental CIA/WIC/NSFI/MQARI ideas. Descriptor,
parser, formatter, and arithmetic primitives for some of these areas do not
become runtime support unless the ledger records the corresponding end-to-end
evidence.
