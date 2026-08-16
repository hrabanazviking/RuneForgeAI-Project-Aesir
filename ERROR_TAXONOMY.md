# ERROR TAXONOMY — Project Æsir

## Authority

This document defines the complete classification, numbering, propagation, and handling rules for every error condition that Project Æsir may encounter or emit. It complements ENGINEERING_DOCTRINE.md by specifying what constitutes an error, how errors travel through the system, and what recovery looks like for each category.

An error is not a crash. A crash is what happens when an error was not handled. This document exists to ensure that every failure mode is anticipated, classified, caught, communicated, and recovered from—or escalated deliberately rather than chaotically.

Mojo's typed error system compiles errors to alternate return values without stack unwinding. This is an architectural advantage. The taxonomy below leverages that mechanism: errors are values, not exceptions thrown into the void. They flow through typed channels, are matched at boundaries, and are resolved at the layer equipped to handle them.

If an error is not in this taxonomy, it is either a bug in the error system itself or a condition that has not been anticipated. Both are defects.

---

## Section One: Taxonomy Principles

### Errors Are Values, Not Mysteries

Every error in Project Æsir is a structured value with:
- A stable identifier (category + code)
- A human-readable message
- A machine-readable payload
- A severity level
- A recovery disposition

Errors are never represented as bare strings, integer codes without context, or panics. An error that cannot be structured cannot be handled, logged, or tested systematically.

### Errors Propagate Along Boundaries

Errors originate in the module where the failure is detected. They propagate upward through the call stack until they reach a layer that can either recover or translate them into a different error type appropriate for the next boundary.

Translation rules:
- A module never leaks its internal error types across its public interface boundary.
- Internal errors are caught at the boundary and translated into the module's public error type.
- The original error is preserved as a `cause` field for diagnostic chaining.
- No error is silently swallowed. If an error is caught and ignored, a debug log entry must explain why.

### Errors Are Recoverable Until Proven Otherwise

The default assumption is that an error can be recovered from. Only errors classified as Fatal are unrecoverable. Every other category must have a defined recovery path, even if that path is "reject the request and return an error response to the caller."

Recovery does not mean pretend the error did not happen. Recovery means the system continues functioning in a defined state despite the error.

### Errors Are Testable

Every error condition defined in this taxonomy must have at least one test that triggers the condition and verifies the resulting error value. An error path that is never exercised in testing is an unverified assumption.

---

## Section Two: Error Severity Levels

| Severity | Identifier | Meaning | System Behavior | Example |
|----------|------------|---------|------------------|---------|
| Trace | `TRACE` | Diagnostic information, not an error | Logged at debug level, no action | Slow kernel detected, switched to fallback |
| Notice | `NOTICE` | Unusual but non-blocking condition | Logged at info level, continued | Model loaded with warnings about unsupported metadata |
| Warning | `WARN` | Degraded operation, action advisable | Logged at warn level, continued | KV cache efficiency below threshold |
| Error | `ERROR` | Operation failed, caller must handle | Returned to caller, caller decides | Tokenization failed on invalid input |
| Critical | `CRITICAL` | Subsystem failed, system partially degraded | Subsystem disabled, fallback engaged | GPU context lost, switched to CPU |
| Fatal | `FATAL` | System cannot continue safely | Process terminates with exit code | Model weights corrupted and no fallback available |

### Severity Escalation Rules

- An Error that recurs beyond a threshold (default: 5 occurrences within 60 seconds) escalates to Critical.
- A Critical that cannot be recovered from escalates to Fatal.
- A Warning that persists beyond a threshold (default: 100 consecutive occurrences) escalates to Error.
- Severity never de-escalates automatically. De-escalation requires explicit acknowledgement and a configuration reload.

---

## Section Three: Error Categories

### Category Overview

| Category | Prefix | Range | Layer | Disposition |
|----------|--------|-------|-------|-------------|
| Configuration | CFG | 001-099 | Grunnr (foundation) | Reject at startup, refuse to run |
| Model Loading | MDL | 100-199 | GGUFSeer | Reject request, return error to caller |
| Tokenization | TOK | 200-299 | WordCarver | Reject request, return error to caller |
| Inference | INF | 300-399 | BrainForge | Retry, fallback, or reject request |
| Memory | MEM | 400-499 | HuginnKeeper | Fallback, preemption, or fatal |
| GPU | GPU | 500-599 | SparkLayer | Fallback to CPU or fatal |
| Network | NET | 600-699 | BifrostGate | Reject request, return HTTP error |
| Validation | VAL | 700-799 | HeimdallWatch | Reject request, return 400 |
| Security | SEC | 800-899 | HeimdallWatch | Reject request, return 403/401, log alert |
| Internal | INT | 900-999 | All modules | Log, file bug, attempt recovery |

---

## Section Four: Configuration Errors (CFG)

Errors that prevent the system from starting or operating correctly due to invalid, missing, or contradictory configuration.

| Code | Name | Severity | Trigger | Recovery |
|------|------|----------|---------|----------|
| CFG-001 | CONFIG_FILE_NOT_FOUND | Fatal | Configuration file path does not exist | None. Print usage, exit. |
| CFG-002 | CONFIG_PARSE_ERROR | Fatal | TOML/YAML syntax error in config | None. Print parse error location, exit. |
| CFG-003 | CONFIG_TYPE_MISMATCH | Fatal | Expected string, got integer (or similar) | None. Print expected vs actual type, exit. |
| CFG-004 | REQUIRED_FIELD_MISSING | Fatal | Required configuration key absent | None. Print missing key, exit. |
| CFG-005 | UNKNOWN_FIELD | Warning | Configuration contains unrecognized key | Log warning, ignore unknown key, continue. |
| CFG-006 | INVALID_PORT_RANGE | Fatal | Port number outside 1-65535 | None. Print valid range, exit. |
| CFG-007 | BIND_ADDRESS_INVALID | Fatal | Bind address not parseable as IP | None. Print valid address format, exit. |
| CFG-008 | MODEL_PATH_NOT_FOUND | Fatal | Configured model directory does not exist | None. Print path, exit. |
| CFG-009 | DUPLICATE_SESSION_ID | Error | Two sessions configured with same ID | Reject second registration, log error. |
| CFG-010 | INCOMPATIBLE_OPTIONS | Fatal | Contradictory settings (e.g., CPU-only + GPU batch size) | None. Print contradiction, exit. |

### Configuration Error Handling

Configuration errors areFatal because running with a broken configuration produces undefined behavior. The system must fail fast and loud at startup. No heuristic guessing of missing values. No silent defaults for security-sensitive settings.

The only exception is CFG-005 (unknown field), which is a Warning because forward compatibility requires tolerating newer configuration keys that older binaries do not recognize.

---

## Section Five: Model Loading Errors (MDL)

Errors that occur during model file parsing, weight loading, or architecture detection.

| Code | Name | Severity | Trigger | Recovery |
|------|------|----------|---------|----------|
| MDL-001 | FILE_NOT_FOUND | Error | Model file path does not exist | Return error to caller. Caller may specify alternate model. |
| MDL-002 | PERMISSION_DENIED | Error | Model file exists but unreadable | Return error to caller. Suggest checking file permissions. |
| MDL-003 | MAGIC_BYTES_MISMATCH | Error | File does not start with GGUF magic | Return error. File is not a valid GGUF. |
| MDL-004 | VERSION_UNSUPPORTED | Error | GGUF version exceeds parser support | Return error. Suggest upgrading or using compatible model. |
| MDL-005 | HEADER_TRUNCATED | Error | File ended before header fully parsed | Return error. File is corrupted or incomplete. |
| MDL-006 | TENSOR_OFFSET_OUT_OF_BOUNDS | Error | Tensor data offset + size exceeds file size | Return error. File is corrupted. |
| MDL-007 | METADATA_VALUE_TOO_LARGE | Error | Single metadata value exceeds 1 MB limit | Return error. Metadata is malformed. |
| MDL-008 | DECOMPRESSION_RATIO_EXCEEDED | Error | Decompressed size > 10× compressed size | Return error. Possible zip bomb. |
| MDL-009 | UNKNOWN_ARCHITECTURE | Error | Architecture string not recognized | Return error. Model architecture unsupported. |
| MDL-010 | QUANTIZATION_UNSUPPORTED | Error | Quantization type not implemented | Return error. Suggest supported quantization. |
| MDL-011 | VOCABULARY_LOAD_FAILED | Error | Tokenizer vocabulary could not be loaded from model | Return error. Model file is incomplete. |
| MDL-012 | CONTEXT_LENGTH_INVALID | Error | Context length in metadata is 0 or implausibly large | Return error. Clamp to supported range. |
| MDL-013 | CHECKSUM_MISMATCH | Critical | SHA-256 of model file does not match recorded checksum | Disable model. Log security alert. Refuse to load. |
| MDL-014 | INSUFFICIENT_VRAM | Error | Model weights + estimated KV cache exceed available VRAM | Return error. Suggest smaller model or quantization. |
| MDL-015 | WEIGHT_LAYER_COUNT_MISMATCH | Error | Header declares N layers, file contains M tensors | Return error. File is internally inconsistent. |

---

## Section Six: Tokenization Errors (TOK)

Errors that occur during text-to-token or token-to-text conversion.

| Code | Name | Severity | Trigger | Recovery |
|------|------|----------|---------|----------|
| TOK-001 | EMPTY_INPUT | Error | Empty string submitted for tokenization | Return error. Prompt must be non-empty. |
| TOK-002 | INPUT_TOO_LONG | Error | Input exceeds maximum token limit after encoding | Return error. Suggest truncating input. |
| TOK-003 | INVALID_UTF8 | Error | Input contains invalid UTF-8 byte sequences | Return error. Specify byte offset of invalid sequence. |
| TOK-004 | NULL_BYTE_DETECTED | Error | Input contains U+0000 | Return error. Null bytes are rejected. |
| TOK-005 | VOCABULARY_LOOKUP_MISS | Notice | Token ID in decode path not in vocabulary | Substitute with unk_token. Log notice. |
| TOK-006 | BPE_MERGE_INCOMPLETE | Warning | Partial merge rule found during encoding | Fall back to unmerged tokens. Log warning. |
| TOK-007 | VOCABULARY_NOT_LOADED | Error | Tokenizer called before vocabulary loaded | Return error. Indicates initialization order bug. |
| TOK-008 | SPECIAL_TOKEN_MISUSE | Error | User input contains reserved special token strings | Return error. Strip or reject depending on configuration. |
| TOK-009 | ENCODING_OVERFLOW | Error | Token count exceeds Int32 max | Return error. Input is astronomically large. |
| TOK-010 | DECODE_EMPTY_SEQUENCE | Notice | Empty token list submitted for decoding | Return empty string. Log notice. |

---

## Section Seven: Inference Errors (INF)

Errors that occur during the forward pass, sampling, or generation loop.

| Code | Name | Severity | Trigger | Recovery |
|------|------|----------|---------|----------|
| INF-001 | FORWARD_PASS_EXCEPTION | Critical | Unhandled exception in transformer forward pass | Abort current generation. Return partial output if any. Switch to fallback kernel if available. |
| INF-002 | SAMPLER_NAN_OR_INF | Error | Logits contain NaN or Inf values | Replace NaN/Inf with large negative value (-1e10). Continue generation. Log error. |
| INF-003 | MAX_TOKENS_REACHED | Notice | Generation hit max_tokens limit | Normal termination. Return completed output. |
| INF-004 | EOS_GENERATED | Notice | End-of-sequence token sampled | Normal termination. Return completed output. |
| INF-005 | STOP_SEQUENCE_MATCHED | Notice | Generated text matched a configured stop sequence | Normal termination. Strip stop sequence from output. |
| INF-006 | CONTEXT_WINDOW_EXCEEDED | Error | Generated tokens + prompt tokens exceed context window | Abort generation. Return partial output with truncation notice. |
| INF-007 | KV_CACHE_BLOCK_ALLOCATION_FAILED | Critical | No free KV cache blocks available for continuation | Preempt lowest-priority session. Retry allocation. If preemption impossible, return 503. |
| INF-008 | KERNEL_LAUNCH_TIMEOUT | Critical | GPU kernel took > 30 seconds (configurable) | Abort kernel. Reset GPU context. Retry once. If retry fails, switch to CPU. |
| INF-009 | TEMPERATURE_INVALID | Error | Temperature value corrupted to out-of-range mid-generation | Clamp to nearest valid value. Continue. Log error. |
| INF-010 | TOP_P_INVALID | Error | top_p value corrupted to out-of-range | Clamp to 1.0 (nucleus disabled). Continue. Log error. |
| INF-011 | GENERATION_LOOP_STUCK | Warning | Same token generated > 50 consecutive times | Log warning. If configured, inject diversity penalty. Continue. |
| INF-012 | PREFILL_CHUNK_FAILED | Critical | Forward pass failed during chunked prefill | Abort request. Return 500. Free KV cache blocks. Log error with chunk index. |
| INF-013 | BATCH_SCHEDULER_DEADLOCK | Fatal | Scheduler unable to make progress for > 5 seconds | Dump scheduler state to log. Terminate process. Requires restart. |
| INF-014 | SPECULATIVE_DRAFT_MISMATCH | Trace | Draft model tokens rejected by target model | Normal operation of speculative decoding. Log at trace level. No action. |
| INF-015 | MODEL_OUTPUT_EMPTY | Error | Forward pass produced zero-length output | Return error. Likely indicates architecture bug or corrupted weights. |

---

## Section Eight: Memory Errors (MEM)

Errors related to memory allocation, deallocation, or access violations.

| Code | Name | Severity | Trigger | Recovery |
|------|------|----------|---------|----------|
| MEM-001 | HOST_MALLOC_FAILED | Critical | System malloc returned null | Abort current operation. Log memory state. Return 503. |
| MEM-002 | DEVICE_ALLOC_FAILED | Critical | GPU memory allocation returned null | Free unused KV cache blocks. Retry. If still fails, switch to CPU. |
| MEM-003 | OUT_OF_MEMORY | Critical | Combined system + GPU memory exhausted | Preempt sessions in reverse priority order. Free memory. Retry. |
| MEM-004 | USE_AFTER_FREE | Fatal | Mojo origin checker detected access to freed memory | Dump origin trace. Terminate process. This is a bug, not a runtime condition. |
| MEM-005 | DOUBLE_FREE | Fatal | Destructor called on already-freed value | Dump origin trace. Terminate process. Bug. |
| MEM-006 | MEMORY_LEAK_DETECTED | Warning | Allocations tracker detects monotonic growth | Log warning with allocation site. Continue. File bug for investigation. |
| MEM-007 | STACK_OVERFLOW | Fatal | Stack limit exceeded (deep recursion) | Terminate process. Indicates algorithmic bug. |
| MEM-008 | KV_CACHE_FRAGMENTATION_HIGH | Warning | KV cache fragmentation > 10% | Log warning. Trigger defragmentation pass if configured. Continue. |
| MEM-009 | PAGE_TABLE_CORRUPTION | Fatal | KV cache page table entries inconsistent | Dump page table state. Terminate process. Bug. |
| MEM-010 | HUGE_PAGE_ALLOCATION_FAILED | Notice | Huge page request fell back to regular pages | Log notice. Performance may degrade slightly. Continue. |

---

## Section Nine: GPU Errors (GPU)

Errors originating from GPU operations, driver interactions, or CUDA/ROCm runtime.

| Code | Name | Severity | Trigger | Recovery |
|------|------|----------|---------|----------|
| GPU-001 | CUDA_INIT_FAILED | Critical | cuInit returned error | Fall back to CPU. Log error with driver version. |
| GPU-002 | DEVICE_NOT_FOUND | Error | No CUDA-capable device detected | Fall back to CPU. Log notice. |
| GPU-003 | KERNEL_LAUNCH_FAILED | Critical | cudaLaunchKernel returned error | Retry once with smaller grid. If retry fails, fall back to CPU. |
| GPU-004 | DEVICE_SYNCHRONIZE_TIMEOUT | Critical | cudaDeviceSync timed out | Reset device. Retry. If reset fails, escalate to Fatal. |
| GPU-005 | ILLEGAL_MEMORY_ACCESS | Critical | GPU reported illegal memory access (segfault on device) | Reset device context. If unrecoverable, terminate. |
| GPU-006 | DRIVER_VERSION_MISMATCH | Warning | Compiled against CUDA X.Y, runtime is CUDA X.Z | Log warning. Proceed if minor version diff. Halt if major diff. |
| GPU-007 | PCIE_LINK_DEGRADED | Notice | GPU running at reduced PCIe lane width | Log notice. Performance impacted. Continue. |
| GPU-008 | THERMAL_THROTTLING | Notice | GPU thermal throttle active | Log notice. Reduce batch size if configured. Continue. |
| GPU-009 | FALLBACK_TO_CPU | Notice | GPU path failed, switched to CPU execution | Log notice. Performance degraded. Continue serving. |
| GPU-010 | MULTI_GPU_SYNC_FAILURE | Critical | NCCL/RCCL synchronization failed across GPUs | Attempt single-GPU fallback. If model requires multi-GPU, return 503. |
| GPU-011 | GRAPH_CAPTURE_FAILED | Warning | CUDA graph capture failed for current configuration | Fall back to eager execution. Log warning. Continue. |
| GPU-012 | RO CM_INIT_FAILED | Critical | rocM initialization failed | Fall back to CPU. Log error with ROCm version. |

---

## Section Ten: Network Errors (NET)

Errors related to HTTP request handling, connection management, and transport.

| Code | Name | Severity | Trigger | Recovery |
|------|------|----------|---------|----------|
| NET-001 | CONNECTION_ACCEPT_FAILED | Warning | accept() returned error on listening socket | Log errno. Retry accept. If persistent, Critical. |
| NET-002 | REQUEST_READ_TIMEOUT | Notice | Client did not send complete request within timeout | Close connection. Log notice. No response sent. |
| NET-003 | REQUEST_BODY_TOO_LARGE | Error | Request body exceeded configured max size | Send 413. Close connection. Log error. |
| NET-004 | MALFORMED_HTTP_REQUEST | Error | HTTP parser could not parse request | Send 400. Close connection. Log error. |
| NET-005 | WEBSOCKET_HANDSHAKE_FAILED | Error | WebSocket upgrade negotiation failed | Send 400. Log error. |
| NET-006 | STREAM_CLIENT_DISCONNECT | Notice | Client disconnected during streaming response | Stop generation. Free resources. Log notice. No error to client. |
| NET-007 | BACKPRESSURE_WRITE_FULL | Warning | Socket send buffer full during streaming | Apply backpressure: pause generation until buffer drains. Resume when writable. |
| NET-008 | TOO_MANY_CONNECTIONS | Warning | Connection count at configured maximum | Reject new connection. Log warning. |
| NET-009 | TLS_HANDSHAKE_FAILED | Warning | TLS negotiation failed | Close connection. Log warning with TLS error code. |
| NET-010 | LISTEN_BIND_FAILED | Fatal | Could not bind to configured port | Log error (port in use?). Terminate. Administrator must intervene. |
| NET-011 | DNS_RESOLUTION_FAILED | Error | Could not resolve hostname (if forwarding/proxying) | Return 502. Log error. |

---

## Section Eleven: Validation Errors (VAL)

Errors caused by invalid user input that violates the request schema.

| Code | Name | Severity | Trigger | Recovery |
|------|------|----------|---------|----------|
| VAL-001 | MISSING_REQUIRED_FIELD | Error | Required field absent from request | Return 400 with field name. |
| VAL-002 | FIELD_TYPE_WRONG | Error | Field present but wrong type (string vs int) | Return 400 with expected type. |
| VAL-003 | VALUE_OUT_OF_RANGE | Error | Numerical value outside permitted range | Return 400 with valid range. |
| VAL-004 | STRING_TOO_LONG | Error | String field exceeds length limit | Return 400 with limit. |
| VAL-005 | ARRAY_TOO_LONG | Error | Array field exceeds element count limit | Return 400 with limit. |
| VAL-006 | UNKNOWN_MODEL_NAME | Error | Model field references unregistered model | Return 400 with list of available models. |
| VAL-007 | PATH_TRAVERSAL_ATTEMPT | Error | Model field contains path separators or .. | Return 400. Log security warning. |
| VAL-008 | DUPLICATE_STOP_SEQUENCE | Error | Stop array contains duplicate entries | Return 400. Deduplicate suggestion. |
| VAL-009 | NEGATIVE_MAX_TOKENS | Error | max_tokens < 1 | Return 400 with valid range. |
| VAL-010 | TEMPERATURE_IS_NAN | Error | Temperature is NaN | Return 400. Explain valid range. |
| VAL-011 | CONTRADICTORY_PARAMETERS | Error | Parameters conflict (e.g., top_k=0 and top_p=0.5 with beam_search=true) | Return 400 with explanation. |
| VAL-012 | PROMPT_CONTAINS_NULL_BYTES | Error | Prompt text contains U+0000 | Return 400. Explain null byte prohibition. |
| VAL-013 | PROMPT_NOT_VALID_UTF8 | Error | Prompt bytes are not valid UTF-8 | Return 400 with byte offset. |

---

## Section Twelve: Security Errors (SEC)

Errors triggered by authentication failures, authorization violations, or suspicious activity.

| Code | Name | Severity | Trigger | Recovery |
|------|------|----------|---------|----------|
| SEC-001 | AUTH_HEADER_MISSING | Error | No Authorization header on protected endpoint | Return 401. Log source IP. |
| SEC-002 | AUTH_KEY_INVALID | Error | API key hash does not match any registered key | Return 401. Log source IP and key hash prefix. |
| SEC-003 | AUTH_KEY_EXPIRED | Error | API key marked expired in configuration | Return 401. Log key hash prefix. |
| SEC-004 | SCOPE_INSUFFICIENT | Error | API key lacks required scope for endpoint | Return 403. Log key hash prefix and attempted scope. |
| SEC-005 | RATE_LIMIT_EXCEEDED | Warning | Request rate exceeded per-minute limit | Return 429 with Retry-After. Log key hash prefix. |
| SEC-006 | REPEAT_AUTH_FAILURE | Critical | > 10 failed auth attempts from same IP within 60s | Temporarily ban IP (configurable: 5 min default). Log alert. |
| SEC-007 | PAYLOAD_SIGNATURE_INVALID | Error | Request signature (if signing configured) does not match | Return 401. Log source IP. |
| SEC-008 | ORIGIN_NOT_ALLOWED | Error | WebSocket Origin header not in allowed list | Close connection. Log source IP and origin. |
| SEC-009 | SUSPICIOUS_PATTERN_DETECTED | Warning | Heuristic scanner flagged input as probing attempt | Return 400. Log warning with pattern matched. |
| SEC-010 | SECRET_LEAKAGE_PREVENTED | Critical | Logger detected attempt to write secret to log | Block log write. Log sanitized entry. Alert coordinator. |

---

## Section Thirteen: Internal Errors (INT)

Errors that indicate bugs in the system itself. These should never occur in production but must be handled defensively.

| Code | Name | Severity | Trigger | Recovery |
|------|------|----------|---------|----------|
| INT-001 | INVARIANT_VIOLATED | Fatal | Asserted invariant failed at runtime | Dump state. Terminate. File bug immediately. |
| INT-002 | UNEXPECTED_NONE | Error | Optional returned None where None was believed impossible | Return 500. Log error with context. File bug. |
| INT-003 | STATE_MACHINE_ILLEGAL_TRANSITION | Error | FSM received event not valid for current state | Return 500. Log state and event. Reset FSM to safe state. |
| INT-004 | MODULE_INITIALIZATION_ORDER | Error | Module accessed before initialization completed | Return 500. Log dependency chain. Fix initialization order. |
| INT-005 | DEAD_CODE_REACHED | Fatal | Code path marked unreachable was executed | Dump stack. Terminate. Logic bug. |
| INT-006 | INTEGER_OVERFLOW_UNCAUGHT | Critical | Arithmetic overflow not caught by saturating op | Roll back operation. Log error. File bug. |
| INT-007 | THREAD_PANIC | Fatal | Worker thread panicked (Mojo panic) | Capture panic message. Terminate process. Restart required. |
| INT-008 | CHANNEL_SEND_CLOSED | Error | Tried to send on closed channel | Return 500. Log error. Receiver dropped prematurely. |
| INT-009 | CHANNEL_RECV_CLOSED | Error | Tried to recv on closed channel | Return 500. Log error. Sender dropped prematurely. |
| INT-010 | TIMER_DRIFT_EXCESSIVE | Warning | Wall-clock time diverged > 5% from expected | Log warning. Recalibrate timers. Continue. |
| INT-011 | FEATURE_FLAG_INCONSISTENT | Error | Feature flag state contradicts compiled capability | Return 500. Log flag state and capability. File bug. |
| INT-012 | SERIALIZATION_ROUND_TRIP_FAIL | Error | Deserialize(Serialize(x)) != x | Return 500. Log affected type. File bug. |

---

## Section Fourteen: Error Value Structure

### Mojo Error Struct

All errors in Project Æsir conform to this structure:

```mojo
struct AesirError:
    var category: ErrorCode.Category      # CFG, MDL, TOK, INF, MEM, GPU, NET, VAL, SEC, INT
    var code: ErrorCode.Code              # Specific code within category (e.g., 001, 002)
    var severity: ErrorCode.Severity      # TRACE, NOTICE, WARNING, ERROR, CRITICAL, FATAL
    var message: String                   # Human-readable description
    var module_origin: String             # Module where error originated
    var cause: Optional[AesirError]       # Chained cause (for error translation)
    var context: Dict[String, String]     # Machine-readable diagnostic context
    var timestamp: Int64                  # Unix epoch microseconds
    var session_id: Optional[String]      # Associated session, if any
    var request_id: Optional[String]      # Associated request, if any
```

### Error Construction Helpers

```mojo
# Convenience constructors
def cfg_error(code: Int, message: String, context: Dict[String, String] = Dict()) -> AesirError:
    return AesirError(Category.CONFIG, code, Severity.ERROR, message, current_module(), None, context, now_us(), None, None)

def mdl_fatal(code: Int, message: String, context: Dict[String, String] = Dict()) -> AesirError:
    return AesirError(Model.LOAD, code, Severity.FATAL, message, current_module(), None, context, now_us(), None, None)

def inf_critical(code: Int, message: String, session_id: String, request_id: String, cause: Optional[AesirError] = None) -> AesirError:
    return AesirError(INFERENCE, code, Severity.CRITICAL, message, current_module(), cause, Dict(), now_us(), Some(session_id), Some(request_id))
```

### Context Dictionary Conventions

The `context` dictionary carries structured diagnostic information. Standard keys:

| Key | Type | Purpose |
|-----|------|---------|
| `"file"` | String | Filename involved (for MDL errors) |
| `"offset"` | String | Byte offset (for parse errors) |
| `"expected"` | String | Expected value or type |
| `"actual"` | String | Actual value or type received |
| `"device_id"` | String | GPU device index (for GPU errors) |
| `"vrmb_total"` | String | Total VRAM in MB |
| `"vram_used"` | String | Used VRAM in MB |
| `"tensor_name"` | String | Name of problematic tensor |
| `"layer_index"` | String | Layer number (for INF errors) |
| `"attempt_count"` | String | Retry attempt number |
| `"fallback"` | String | Fallback path taken (if any) |

Custom keys are permitted but must be prefixed with the module name to avoid collision: `"WordCarver.byte_offset"`.

---

## Section Fifteen: Error Propagation Rules

### Within a Module

Errors propagate through Mojo's `raises` mechanism. A function that may produce an error must be marked `raises`. Callers must handle the error or also be marked `raises`.

```mojo
def tokenize(text: String) raises -> List[Int]:
    if text.length() == 0:
        raise tok_error(001, "empty_input", {})
    # ... tokenization logic
```

### Across Module Boundaries

When an error crosses a module boundary, it must be translated into the receiving module's error type. The original error is preserved as the `cause` field.

```mojo
# Inside BifrostGate (HTTP layer)
def handle_completion_request(req: HttpRequest) -> HttpResponse:
    try:
        let tokens = word_carver.tokenize(req.prompt)
        let result = brain_forge.generate(tokens, req.params)
        return ok_response(result)
    except e: TokError:
        # Translate tokenization error into network error
        let net_err = net_error(400, "tokenization_failed", {
            "detail": e.message,
            "code": "TOK-" + String(e.code)
        })
        return error_response(net_err)
    except e: InfError:
        let net_err = net_error(500, "inference_failed", {
            "detail": e.message,
            "code": "INF-" + String(e.code),
            "retry_after": "5"
        })
        return error_response(net_err)
```

### Translation Matrix

| Source Module | Destination Module | Translation Rule |
|---------------|-------------------|------------------|
| GGUFSeer | BrainForge | MDL-* → INF-100-series (wrapped as model-load failure) |
| WordCarver | BifrostGate | TOK-* → NET-400-series (HTTP 400 with detail) |
| BrainForge | BifrostGate | INF-001..012 → NET-500-series (HTTP 500); INF-003..005 → NET-200 (success) |
| HuginnKeeper | BrainForge | MEM-007..009 → INF-007 (translated as KV cache failure) |
| SparkLayer | BrainForge | GPU-001..012 → INF-008 (translated as kernel/inference failure) |
| HeimdallWatch | BifrostGate | VAL-* → NET-400-series; SEC-* → NET-401/403/429 |

### Forbidden Propagation Patterns

- **Leaking internal errors to HTTP responses**: An INT-* error must never produce an HTTP response containing internal state. Return a generic 500 with no internal detail.
- **Swallowing errors without logging**: Catching an error and discarding it without a debug log entry is forbidden.
- **Propagating without translation**: Leaking a TokError into a module that expects NetError causes cascading type mismatches. Translate at the boundary.
- **Re-raising without context augmentation**: If you re-raise an error, add context. A bare re-throw loses the opportunity to annotate where the error traveled.

---

## Section Sixteen: HTTP Error Responses

### Response Format

All error responses follow a consistent JSON structure:

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

### HTTP Status Code Mapping

| Error Category | HTTP Status | Error Type String |
|----------------|-------------|-------------------|
| VAL-* | 400 | `invalid_request_error` |
| SEC-001..003 | 401 | `authentication_error` |
| SEC-004 | 403 | `authorization_error` |
| SEC-005 | 429 | `rate_limit_error` |
| MDL-001..012 | 400 | `invalid_model_error` |
| MDL-013..015 | 500 | `server_error` |
| TOK-* | 400 | `tokenization_error` |
| INF-001..012 | 500 | `server_error` |
| INF-013 | 503 | `service_unavailable` |
| INF-014..015 | 500 | `server_error` |
| MEM-001..003 | 503 | `service_unavailable` |
| MEM-004..005, 007..009 | 500 | `server_error` |
| GPU-* | 503 | `service_unavailable` (if fallback active) or 500 |
| NET-* | Corresponding HTTP status | Varied |
| INT-* | 500 | `server_error` (generic, no internal detail) |

### Error Detail Disclosure Policy

| Severity | HTTP Response Detail Level |
|----------|---------------------------|
| Trace | Not surfaced to client |
| Notice | Not surfaced to client |
| Warning | Not surfaced to client |
| Error | Full error message and code. No internal paths, no stack traces. |
| Critical | Generic message + code. No internal state. Logged with full detail server-side. |
| Fatal | No response sent (process terminating). |

Internal paths, module names, memory addresses, stack traces, and configuration values are never included in HTTP error responses. The client receives enough information to understand and correct their request. The server retains the full diagnostic detail in logs.

---

## Section Seventeen: Error Testing Requirements

### Mandatory Error Tests

Every error code defined in Sections Four through Thirteen must have at least one test in `tests/error_taxonomy/` that:

1. Triggers the error condition
2. Captures the resulting AesirError
3. Verifies the category, code, and severity
4. Verifies the message is non-empty
5. Verifies the context dictionary contains expected keys
6. Verifies the error propagates correctly across the relevant boundary

### Test File Naming

```
tests/error_taxonomy/
├── test_cfg_errors.mojo
├── test_mdl_errors.mojo
├── test_tok_errors.mojo
├── test_inf_errors.mojo
├── test_mem_errors.mojo
├── test_gpu_errors.mojo
├── test_net_errors.mojo
├── test_val_errors.mojo
├── test_sec_errors.mojo
└── test_int_errors.mojo
```

### Error Path Coverage

The TEST_COVERAGE.md capability ledger tracks error path coverage separately from line coverage. A module with 95% line coverage but 0% error path coverage is deficient.

Metric:
```
error_coverage = tested_error_codes / total_defined_error_codes
```

**Target**: error_coverage ≥ 0.95
**Minimum**: error_coverage ≥ 0.80

### Fuzzing for Undocumented Errors

The Auditor role conducts fuzzing campaigns to discover error conditions not catalogued in this taxonomy. Newly discovered conditions are:

1. Added to the appropriate category table
2. Assigned a code
3. Given a recovery path
4. Covered by a test

An undocumented error that occurs in production is a taxonomy gap, not an unavoidable surprise.

---

## Section Eighteen: Error Reporting and Analytics

### Error Metrics

The engine exposes error metrics via the `/metrics` endpoint (Prometheus format):

```
# TYPE aesir_errors_total counter
aesir_errors_total{category="cfg"} 0
aesir_errors_total{category="mdl"} 3
aesir_errors_total{category="tok"} 12
aesir_errors_total{category="inf"} 2
aesir_errors_total{category="mem"} 0
aesir_errors_total{category="gpu"} 1
aesir_errors_total{category="net"} 45
aesir_errors_total{category="val"} 178
aesir_errors_total{category="sec"} 3
aesir_errors_total{category="int"} 0

# TYPE aesir_errors_by_code gauge
aesir_errors_by_code{code="val-003"} 42
aesir_errors_by_code{code="val-001"} 28
aesir_errors_by_code{code="net-006"} 15
aesir_errors_by_code{code="tok-001"} 8
```

### Error Rate Alerts

Configurable alert thresholds:

```toml
[alerts]
error_rate_per_minute = 10        # > 10 errors/min → alert
critical_per_hour = 1             # > 1 critical/hour → alert
fatal_ever = true                 # any fatal → immediate alert
auth_failure_burst = 10           # > 10 auth failures in 60s → alert
```

Alerts are delivered via configured notification channels (log file, webhook, email). Default: log file only.

---

## Section Nineteen: Agent Responsibilities for Errors

### When an Agent Encounters an Error

1. **Classify**: Determine which category and code from this taxonomy the error corresponds to.
2. **Handle**: Follow the defined recovery path for that code.
3. **Log**: Emit a structured log entry with the error value.
4. **Test**: Ensure a test exists for this error path. If not, create one.
5. **Document**: If the error is new (not in taxonomy), add it to this document before closing the ticket.

### When an Agent Introduces a New Error Condition

1. Assign a code in the appropriate category, using the next available number.
2. Define severity, trigger, and recovery.
3. Add the code to the relevant category table in this document.
4. Write a test that triggers the condition.
5. Update the translation matrix if the error crosses module boundaries.
6. Update the HTTP status code mapping if the error reaches the API.

### When an Agent Fixes an Error Path

1. Verify the fix resolves the root cause, not just the symptom.
2. Ensure the error test still passes (the error should still be producible if the condition is legitimately possible).
3. If the error is no longer producible due to the fix, mark the test as `xfail` with a comment explaining why.
4. Update the error's recovery path in this document if the fix changes how recovery works.

---

## Section Twenty: Quick Reference

```
ENCOUNTERING AN ERROR:
□ Identified category and code from taxonomy?
□ Followed defined recovery path?
□ Logged structured error entry?
□ Test exists for this error path?
□ If new error: added to taxonomy?

INTRODUCING A NEW ERROR CONDITION:
□ Assigned next available code in category?
□ Defined severity, trigger, recovery?
□ Added to category table in this document?
□ Written triggering test?
□ Updated translation matrix (if crosses boundaries)?
□ Updated HTTP status mapping (if reaches API)?

HANDLING ERRORS ACROSS BOUNDARIES:
□ Translated error to receiving module's type?
□ Preserved original error as cause field?
□ Added context to error before propagation?
□ No internal details leaked to HTTP response?
□ Logged at appropriate severity?

NEVER:
□ Swallow an error without logging
□ Leak internal paths in HTTP responses
□ Propagate an error without translation across a boundary
□ Invent ad hoc error codes outside this taxonomy
□ Use bare strings or ints as error representations
```

---

## Closing Principle

Every error is a story. It has a protagonist (the module that detected it), a setting (the runtime context), a conflict (the condition that failed), and a resolution (the recovery path). A taxonomy ensures that every story has a genre, a catalog number, and a known ending.

Systems without error taxonomies improvise. They produce inconsistent error messages, swallow failures silently, leak internal state to attackers, and leave operators guessing at 3 AM what "Error: something went wrong" means in the context of a production outage.

Systems with error taxonomies communicate. They produce structured, diagnosable, testable failures. They tell the operator exactly what broke, where, and what the system did about it. They turn crises into procedures.

Catalogue every failure. Handle every failure. Test every failure. No surprises.

---

*Last updated: 2026-08-15. Maintained jointly by the Architect (taxonomy structure) and Auditor (error coverage verification). New error codes require Architect review. Error tests are mandatory for merge.*

---
