# SECURITY POSTURE — Project Æsir

> **Status boundary — 2026-08-31:** This document retains a target threat model,
> not a certification that every control below exists. Native local serving now
> has mandatory file-backed authentication, loopback-only binding, strict input
> bounds and cooperative I/O/generation limits. The tested scope and remaining
> risks are specified in [NATIVE_SERVICE.md](docs/NATIVE_SERVICE.md). There is no
> TLS, remote access, multi-tenant isolation, rate limiter or production security
> assessment. Do not expose the endpoint publicly based on target text below.

## Authority

This document defines the security stance, threat model, defensive measures, and incident response procedures for Project Æsir. It complements ENGINEERING_DOCTRINE.md by specifying how the system protects itself, its users, and its data. Where the doctrine says "secure," this document defines what secure means in practice.

Security is not a feature. It is a precondition. A fast inference engine that leaks user prompts to third parties is not a product. It is a liability with a benchmark score.

This document assumes the adversary is real, the network is hostile, and the input is untrusted until proven otherwise. Paranoia is the correct default. Trust is earned, verified, and revoked on evidence.

---

## Section One: Security Philosophy

### Defense in Depth

No single security measure is sufficient. The project layers defenses so that failure of one control does not collapse the entire perimeter. The layers, from outermost to innermost:

1. **Network perimeter** — Firewall rules, TLS termination, rate limiting
2. **Transport security** — Encrypted channels, certificate validation
3. **Authentication** — Identity verification for API consumers
4. **Authorization** — Permission scopes per authenticated identity
5. **Input validation** — Schema enforcement, sanitization, size limits
6. **Execution isolation** — Sandboxed model execution, resource caps
7. **Output filtering** — Response scrubbing, leakage prevention
8. **Audit logging** — Tamper-resistant record of all security-relevant events

Each layer assumes the previous layer has been breached. Each layer must function independently.

### Zero Trust Internally

The project does not grant implicit trust to any component based on network position. Internal module calls validate inputs the same way external API calls do. A request from BifrostGate to MimirWell undergoes the same schema validation as a request from an external HTTP client.

"No internal attacker" is an assumption that fails the moment a dependency is compromised. Treat every module boundary as a potential adversarial interface.

### Least Privilege by Default

Every component, process, and API key possesses the minimum permissions required to fulfill its function. Nothing runs as root unless absolutely necessary. No module has read access to files outside its designated scope. No API key grants capabilities beyond its intended use.

### Fail Secure

When a security control fails, the system fails into a secure state. Failed authentication denies access. Failed input validation rejects the request. Failed TLS negotiation terminates the connection. A system that fails open is a system waiting to be exploited.

### Observable Over Silent

Security events are logged loudly, not swallowed quietly. A failed authentication attempt produces a log entry. A rejected input produces a log entry. A blocked network connection produces a log entry. Silent rejection hides attacks from defenders. Auditable rejection exposes them.

---

## Section Two: Threat Model

### Assets Worth Protecting

| Asset | Sensitivity | Impact of Compromise |
|-------|-------------|----------------------|
| User prompts | High | Prompts may contain personal, confidential, or sensitive information. Leakage violates user trust and potentially legal obligations. |
| Generated outputs | Medium | Outputs may contain information derived from sensitive prompts. Cached outputs retain sensitivity. |
| Model weights | Medium | Weights are large binary assets. Corruption produces garbage output. Theft is an intellectual property concern but not a security catastrophe. |
| KV cache contents | High | Contains intermediate representations of user prompts. May allow reconstruction of input text. |
| Configuration files | Medium | Contains paths, port assignments, performance settings. May reveal system topology. |
| API keys and secrets | Critical | Credentials for authentication. Compromise allows unauthorized access. |
| System logs | Medium | Contains request metadata, error traces, timing information. May leak prompt content through error messages. |
| Process memory | High | Contains model weights, KV cache, active prompts, and secrets in plaintext. Memory dump equals total compromise. |

### Adversary Profiles

**Profile A: Remote Unauthorized Attacker**
- Capability: Network access to the API endpoint
- Motivation: Data exfiltration, denial of service, reconnaissance
- Likelihood: High (internet-facing services are perpetually probed)
- Primary defense: Transport encryption, authentication, rate limiting, input validation

**Profile B: Authenticated Malicious User**
- Capability: Valid API credentials, ability to submit arbitrary prompts
- Motivation: Prompt injection, model abuse, resource exhaustion, lateral movement
- Likelihood: Medium (any multi-user deployment faces insider risk)
- Primary defense: Authorization scopes, resource quotas, output filtering, anomaly detection

**Profile C: Supply Chain Attacker**
- Capability: Compromised dependency or build tool
- Motivation: Backdoor insertion, data exfiltration, cryptominer deployment
- Likelihood: Low-Medium (mitigated by DEPENDENCY_POLICY.md)
- Primary defense: Dependency auditing, checksum verification, build reproducibility, vendoring of critical paths

**Profile D: Local Privileged Observer**
- Capability: Physical or root access to the host machine
- Motivation: Memory inspection, secret extraction, tampering
- Likelihood: Low (primarily relevant for shared hosting or cloud deployments)
- Primary defense: Process isolation, encrypted-at-rest storage, minimized secret lifetime, acknowledgment that this threat cannot be fully defeated without hardware-level protections (TEE, SGX, SEV-SNP)

**Profile E: Malformed Input Injector**
- Capability: Submit specially crafted requests designed to trigger parser bugs, buffer overflows, or integer exploits
- Motivation: Remote code execution, crash, information leakage
- Likelihood: Medium (automated scanners probe continuously)
- Primary defense: Rigorous input validation, fuzzing, memory-safe language (Mojo's ownership system prevents many classical memory corruption bugs)

### Out of Scope

The following threats are explicitly out of scope for this document:
- Physical security of the host facility (handled by deployment environment)
- Side-channel attacks requiring physical proximity (TEMPEST, power analysis)
- Nation-state-level targeted attacks with bespoke zero-days (defense requires resources beyond this project's scope)
- Attacks against the underlying operating system kernel (defer to OS hardening guides)

These exclusions are documented, not ignored. They are handled by complementary measures outside this project's control.

---

## Section Three: Attack Surface Inventory

### External Attack Surfaces

| Surface | Protocol | Exposure | Risk |
|---------|----------|----------|------|
| HTTP API (BifrostGate) | TCP, configurable port | Network-bound | Primary ingress point. Receives untrusted input. |
| WebSocket streaming | TCP, same port as HTTP | Network-bound | Bidirectional channel for streaming responses. |
| Model file loading | Local filesystem | Local-only | Malformed GGUF files could exploit parser bugs. |
| Configuration loading | Local filesystem | Local-only | Malformed configs could alter security-sensitive settings. |

### Internal Attack Surfaces

| Surface | Direction | Risk |
|---------|-----------|------|
| Module-to-module IPC | Internal | Compromised module could send malformed data to another module. |
| KV cache shared memory | Internal | KV cache poisoning could corrupt generation for other sessions. |
| Model weight memory | Internal | Corrupted weights produce corrupted output. Integrity verification needed. |
| Log file writes | Internal | Log injection could forge audit trail entries. |

### Shrinking the Surface

Attack surfaces shrink through:
1. **Binding to localhost by default** — The HTTP server binds to 127.0.0.1, not 0.0.0.0. Users who want remote access must explicitly configure it.
2. **Disabling unused endpoints** — If streaming is not needed, the WebSocket endpoint is not registered.
3. **Minimal CORS** — No wildcard origins. CORS is opt-in and explicit.
4. **No admin panel** — There is no web-based administration interface. Configuration is file-based. Administration is CLI-based.
5. **No file upload endpoints** — The API accepts text prompts, not multipart file uploads. Model files are loaded from the local filesystem only.

---

## Section Four: Authentication and Authorization

### Authentication Models

Project Æsir supports two authentication modes:

**Mode 1: No Authentication (Single-User Local)**
- Default mode for local single-user deployments
- Server binds to localhost only
- No API key required
- Suitable for developer workstations and personal machines
- Unsuitable for any network-accessible deployment

**Mode 2: API Key Authentication (Multi-User)**
- Enabled when server binds to a non-localhost address
- Every request must include a valid API key in the `Authorization: Bearer [key]` header
- API keys are defined in the configuration file and loaded at startup
- Keys are compared in constant time to prevent timing attacks
- Failed authentication returns 401 with a generic error message (no key echoed, no hint about whether the key exists)

### API Key Management

API keys are:
- Stored in the configuration file as SHA-256 hashes, never in plaintext
- Loaded at startup into an in-memory lookup table
- Minimum 32 characters, recommended 64 characters of random alphanumeric data
- Generated using a CSPRNG (cryptographically secure pseudorandom number generator)
- Logged only by hash prefix (first 8 characters) for debugging, never in full

Configuration example:
```toml
[auth]
enabled = true
keys = [
    "sha256:a1b2c3...",  # Alice
    "sha256:d4e5f6...",  # Bob
]
rate_limit_per_minute = 60
```

### Authorization Scopes

When multi-user authentication is enabled, API keys carry scopes:

| Scope | Permissions |
|-------|-------------|
| `infer` | Submit completion and chat completion requests |
| `infer-stream` | Submit streaming requests |
| `admin-status` | GET /health, GET /stats |
| `admin-shutdown` | POST /shutdown |

Default scope for new keys: `infer,infer-stream`. Admin scopes require explicit assignment.

### Session Isolation

Authenticated sessions are isolated:
- Each session has its own KV cache allocation
- Sessions cannot read another session's KV cache
- Session identifiers are random 128-bit values
- Session identifiers are not enumerable (no sequential IDs)
- Session timeouts are configurable (default: 30 minutes idle)

---

## Section Five: Transport Security

### TLS Requirements

When the server is reachable over a network (non-localhost binding), TLS is mandatory.

- **Minimum TLS version**: 1.2 (1.3 preferred)
- **Cipher suites**: ECDHE-ECDSA-AES256-GCM-SHA384, ECDHE-RSA-AES256-GCM-SHA384, and equivalents. No RC4, no DES, no NULL cipher suites.
- **Certificate validation**: Certificates must be valid, non-expired, and chained to a trusted CA. Self-signed certificates are permitted for internal deployments but must be explicitly configured as trusted.
- **HSTS**: Enabled when TLS is enabled. `Strict-Transport-Security: max-age=31536000; includeSubDomains`
- **Certificate reloading**: Supported without restart via SIGHUP signal handler.

### Plaintext Fallback

Plaintext HTTP is permitted ONLY when:
1. The server is bound to localhost (127.0.0.1 or ::1)
2. No remote network access is configured
3. A warning is logged at startup: "Running in plaintext mode on localhost. Do not expose this port to the network."

If the server is bound to a non-localhost address without TLS configured, it refuses to start. This is not a warning. It is a hard stop.

### WebSocket Security

WebSocket connections:
- Inherit the TLS configuration of the HTTP server
- Require the same API key authentication as HTTP requests
- Validate the `Sec-WebSocket-Key` header
- Enforce origin checking (no wildcard origin acceptance)
- Limit message size to 1 MB per frame
- Close connections that send malformed frames

---

## Section Six: Input Validation

### Request Schema Enforcement

Every inbound request is validated against a strict schema before any processing begins. Invalid requests are rejected with a 400 status code. No partial processing occurs on rejected input.

Validation rules for completion requests:

| Field | Type | Constraints | Rejection Condition |
|-------|------|-------------|---------------------|
| `model` | string | non-empty, ≤ 128 chars | empty, > 128 chars, contains path separators |
| `prompt` | string | non-empty, ≤ max_context_length tokens | empty, exceeds context limit |
| `max_tokens` | integer | 1 ≤ value ≤ 4096 | < 1, > 4096 |
| `temperature` | float | 0.0 ≤ value ≤ 2.0 | < 0.0, > 2.0, NaN, Inf |
| `top_p` | float | 0.0 < value ≤ 1.0 | ≤ 0.0, > 1.0, NaN, Inf |
| `top_k` | integer | 0 ≤ value ≤ 1000 | < 0, > 1000 |
| `stop` | array[string] | ≤ 4 entries, each ≤ 64 chars | > 4 entries, entry > 64 chars |
| `stream` | boolean | true or false | any non-boolean value |

### Path Traversal Prevention

The `model` field in requests is treated as untrusted input. It must never be used as a direct filesystem path. The engine resolves model names through a configured model registry, not through direct path interpolation.

```mojo
# Forbidden — direct path construction from user input
let model_path = "/models/" + request.model + ".gguf"

# Required — registry lookup with whitelist
let model_path = model_registry.resolve(request.model)
# Registry returns Option[String]; None for unknown models
```

### Payload Size Limits

| Payload Component | Limit | Action on Exceed |
|--------------------|-------|-------------------|
| Total request body | 10 MB | 413 Request Entity Too Large |
| Prompt token count | max_context_length | 400 with explanatory message |
| Number of stop sequences | 4 | 400 with explanatory message |
| HTTP header count | 50 | 400 Bad Request |
| Individual header size | 8 KB | 400 Bad Request |
| URL length | 2048 chars | 414 URI Too Long |

### Unicode Handling

- All input is decoded as UTF-8. Invalid UTF-8 sequences are rejected.
- Homoglyph detection is not implemented (out of scope for a local inference engine), but normalization (NFKC) is applied to prevent trivial unicode-based bypass tricks.
- Null bytes (U+0000) in input are rejected. They have no legitimate purpose in text prompts and are a common payload for C-string truncation attacks.

### Injection Resistance

The inference engine does not execute user-supplied text as code. User prompts are processed as token sequences, not as commands. However, the following precautions are taken:

- Prompt text is never interpolated into SQL queries (there is no SQL database).
- Prompt text is never interpolated into shell commands.
- Prompt text is never interpolated into file paths.
- Prompt text is never interpolated into Mojo source code or eval expressions.
- Prompt text is never passed to `Python.import_module` or any dynamic import mechanism.

---

## Section Seven: Model Security

### Malformed Model Protection

GGUF files are untrusted binary input. The parser (GGUFSeer) must defend against:

| Attack | Defense |
|--------|--------|
| Truncated header | Validate minimum header size before parsing. Reject if header shorter than expected. |
| Impossible tensor offsets | Sanity-check tensor offsets against file size. Reject if offset + size > file_size. |
| Oversized metadata values | Cap individual metadata value size at 1 MB. Reject if exceeded. |
| Recursive or cyclic metadata structures | Flat metadata format in GGUF; no recursion possible. Validate anyway. |
| Integer overflow in size calculations | Use saturating arithmetic for all size computations. Overflow → rejection. |
| Zip bombs (compressed payload decompressing to enormous size) | Cap decompressed size at 10× compressed size. Reject if exceeded. |
| Magic byte spoofing | Validate magic bytes first, then validate structural consistency. Spoofed magic with invalid structure is rejected. |

### Model Integrity Verification

Optional model integrity checking via SHA-256 checksums:

```toml
[model_verification]
enabled = true  # Default: false
checksums_file = "config/model_checksums.toml"
fail_on_mismatch = true  # Default: true. If false, log warning but proceed.
```

When enabled, the loader computes the SHA-256 of the model file and compares it against the recorded checksum. Mismatch indicates corruption or tampering.

### Prompt Injection Awareness

Project Æsir is an inference engine, not a chatbot framework. It does not implement system prompts, role-play guards, or content policy filters. However, the following design decisions reduce prompt injection risk for downstream applications:

1. **Clear separation of system and user content** — The API accepts `system` and `user` roles in chat completions. These are concatenated into the prompt with distinct delimiter tokens, not as raw text merges.
2. **No tool calling by default** — The engine does not execute tools, browse the web, or run code based on model output. Model output is text, not commands.
3. **Output is inert** — Generated tokens are returned as text. They are not interpreted, executed, or used as indices into any privileged operation.

Applications built on top of Project Æsir are responsible for their own prompt injection defenses. The engine provides the boundary; the application must enforce it.

---

## Section Eight: Resource Exhaustion Defense

### Denial of Service Prevention

| Vector | Defense |
|--------|---------|
| Request flooding | Rate limiting per API key (configurable, default 60 req/min) |
| Oversized prompts | Token count validation before processing |
| Long-running generation | max_tokens cap (default 4096, configurable) |
| Slowloris-style slow reads | Connection read timeout (default 30 seconds) |
| Connection saturation | Max concurrent connections (default 100, configurable) |
| KV cache exhaustion | Max concurrent sessions enforced by scheduler; excess requests queued or rejected |
| Infinite loops in generation | Stop sequence evaluation on every token; EOS token always terminates |
| Memory exhaustion | GPU memory utilization cap (default 90%; reserve 10% for system) |

### Graceful Degradation Under Load

When the system approaches capacity limits:
1. **Soft limit (80%)**: New requests are accepted but queued. Response time increases. Warning logged.
2. **Hard limit (95%)**: New requests are rejected with 503 Service Unavailable and `Retry-After` header suggesting retry delay.
3. **Critical (99%)**: Lowest-priority sessions are preempted (KV cache evicted) to free resources. Preempted sessions receive a 503 with session ID for resumption.

The system never crashes due to resource exhaustion. It degrades, rejects, and survives.

---

## Section Nine: Secrets Management

### What Counts as a Secret

- API keys for authentication
- TLS private keys
- Signing keys for model checksums
- Configuration file contents (may contain sensitive paths or settings)

### Storage

Secrets are stored in:
1. **Configuration files** with restrictive permissions (chmod 600)
2. **Environment variables** for container deployments
3. **Never in source code**
4. **Never in git history**
5. **Never in log files**
6. **Never in error messages**

### Lifetime

- Secrets are loaded at startup into protected memory.
- Secrets are overwritten with zeros before process exit.
- Secrets are never written to disk in plaintext.
- Secret-containing memory pages are locked (mlock) to prevent swapping to disk.

### Rotation

API key rotation procedure:
1. Generate new key using CSPRNG.
2. Compute SHA-256 hash of new key.
3. Add hash to configuration file.
4. Signal process to reload configuration (SIGHUP).
5. Verify new key works.
6. Remove old key hash from configuration.
7. Signal process to reload again.
8. Old key is now invalid. No downtime occurred.

### Secret Leakage Detection

The Auditor role runs periodic scans for accidental secret leakage:

```bash
# Search git history for potential secrets
git log -p | grep -iE "(password|secret|token|api_key|apikey)" \
    | grep -v "^---" | grep -v "^+++" \
    | grep -v "# .*password" | grep -v "// .*password"

# Search working tree for hardcoded secrets
grep -rn "sk-" src/ tests/
grep -rn "Bearer " src/ tests/
```

Findings are investigated. Actual secret leakage triggers the INCIDENT_RESPONSE procedure (Section Twelve).

---

## Section Ten: Logging and Audit Trail

### What Is Logged

| Event | Log Level | Contents |
|-------|-----------|----------|
| Successful authentication | INFO | Timestamp, key hash prefix, source IP |
| Failed authentication | WARN | Timestamp, source IP, failure reason (generic) |
| Request received | DEBUG | Timestamp, session ID, model name, prompt token count |
| Request completed | INFO | Timestamp, session ID, tokens generated, latency, status code |
| Request rejected | WARN | Timestamp, rejection reason (schema, size, rate limit), no prompt content |
| Rate limit triggered | WARN | Timestamp, key hash prefix, current rate, limit |
| TLS handshake failure | WARN | Timestamp, source IP, failure reason |
| Model loading | INFO | Timestamp, model name, file path, load duration |
| Model integrity mismatch | ERROR | Timestamp, model name, expected hash, actual hash |
| Configuration reload | INFO | Timestamp, signal source, what changed |
| Session preempted | WARN | Timestamp, session ID, reason |
| Fatal error | ERROR | Timestamp, error type, stack trace (no user data) |
| Process shutdown | INFO | Timestamp, shutdown reason, active session count |

### What Is Never Logged

- Full API keys (only hash prefix)
- Prompt contents (never, under any circumstance)
- Generated output contents (never)
- TLS private key material
- Configuration file raw contents
- User personal data (names, emails, IPs in production logs are acceptable for security auditing but must be anonymized in non-security logs)

### Log Integrity

Logs are written to append-only files. Once written, a log entry is not modified or deleted programmatically. Log rotation preserves rotated files for a configurable retention period (default: 90 days).

For high-security deployments, logs can be forwarded to a remote syslog server in real-time. This prevents local log tampering by an attacker with host access.

### Log Injection Prevention

Log entries sanitize user-supplied data before inclusion:
- Newline characters in user input are escaped (`\n` → `\\n`) to prevent log forging
- Control characters are stripped
- User-supplied strings are truncated to 256 characters in log entries
- Structured JSON logging is used to prevent format confusion

---

## Section Eleven: Hardening Baselines

### Process Hardening

| Measure | Default | Configuration |
|---------|---------|---------------|
| Run as non-root user | Required | `user = "aesir"` in config |
| Drop capabilities on startup | Required | `capabilities.drop = true` |
| Set RLIMIT_NOFILE | 1024 | `rlimits.nofile = 1024` |
| Set RLIMIT_CPU | Unlimited | Configurable per deployment |
| umask | 0077 | Set at process startup |
| stdout/stderr redirection | To log files | `log.stdout = "/var/log/aesir/out.log"` |

### Filesystem Hardening

| Path | Permissions | Owner |
|------|-------------|-------|
| Binary executable | 0755 | root:aesir |
| Configuration directory | 0700 | aesir:aesir |
| Model storage directory | 0750 | aesir:aesir |
| Log directory | 0750 | aesir:aesir |
| PID file | 0644 | aesir:aesir |

### Network Hardening

| Measure | Implementation |
|---------|----------------|
| Bind address | Default localhost; explicit configuration required for remote |
| Listen backlog | 128 (handles connection bursts) |
| SYN cookies | Handled by OS; documented in deployment guide |
| IPv6 | Supported; same security rules as IPv4 |
| Reverse proxy recommended | nginx or Caddy in front for TLS termination, rate limiting, and request buffering |

### Container Hardening

When deployed in containers:
- Base image: minimal (distroless or Alpine)
- Run as non-root user (USER directive in Dockerfile)
- Read-only root filesystem (--readonly flag)
- No privilege escalation (--security-opt=no-new-privileges)
- Seccomp profile applied
- Resource limits set via cgroups
- No SSH server inside container
- No shell inside container (distroless)

---

## Section Twelve: Incident Response

### Severity Classification

| Severity | Definition | Response Time | Notification |
|----------|------------|---------------|--------------|
| SEV-1 (Critical) | Confirmed data breach, RCE, or secret leakage | Immediate | Coordinator + all agents halted |
| SEV-2 (High) | Authentication bypass, DoS achieving outage, model integrity failure | Within 1 hour | Coordinator + Architect + Auditor |
| SEV-3 (Medium) | Rate limit circumvention, information leakage in logs, TLS misconfiguration | Within 4 hours | Coordinator + Auditor |
| SEV-4 (Low) | Failed intrusion attempt, anomalous request pattern, minor config exposure | Within 24 hours | Auditor logs findings |

### Response Procedure

**Immediate Actions (SEV-1, SEV-2):**
1. **Contain**: Stop the process if active intrusion is suspected. Disconnect from network if exfiltration is occurring.
2. **Preserve Evidence**: Copy log files, process state, and memory dump (if feasible) to a secured location before any cleanup.
3. **Notify**: Contact the human coordinator with a factual summary. No speculation. Facts only.
4. **Assess Scope**: Determine which sessions, secrets, or data were exposed.
5. **Rotate Secrets**: All API keys and TLS certificates are regenerated. Old credentials are invalidated.

**Investigation Phase:**
1. Timeline reconstruction from logs.
2. Root cause identification.
3. Impact assessment (what was accessed, what was leaked, what was corrupted).
4. Documentation in `docs/incidents/INCIDENT-YYYY-MM-DD-N.md`.

**Remediation Phase:**
1. Patch the vulnerability that enabled the incident.
2. Add regression tests that reproduce the attack vector and verify the fix.
3. Update this document if the incident revealed a gap in the threat model.
4. Update hardening baselines if the incident revealed a configuration weakness.
5. Post-mortem review with all stakeholders.

### Incident Report Format

```markdown
# Incident Report — YYYY-MM-DD — SEV-N

## Summary
[Factual description of what happened, no speculation]

## Discovery
[How the incident was detected — alarm, log review, user report]

## Timeline
| Time (UTC) | Event |
|------------|-------|
| HH:MM | [Event] |
| HH:MM | [Event] |

## Impact
[What was affected: sessions, data, services, secrets]

## Root Cause
[Technical explanation of the vulnerability or failure]

## Remediation
[Actions taken to fix the immediate issue]

## Preventive Measures
[Actions taken to prevent recurrence]

## Lessons Learned
[What the incident revealed about the security posture]

## Status
[Open / Resolved / Monitoring]
```

---

## Section Thirteen: Security Review Checklist

Before any feature that touches authentication, network handling, input processing, or file I/O is merged:

```
SECURITY REVIEW CHECKLIST
=========================

Feature: _________________________________
Domain: _________________________________
Reviewer: _________________________________
Date: _________________________________

--- Input Validation ---

[ ] All user-supplied input is validated against a strict schema
[ ] Path traversal prevention verified (no direct path construction from user input)
[ ] Payload size limits enforced
[ ] Unicode normalized (NFKC) and null bytes rejected
[ ] Integer overflow defended with saturating arithmetic

--- Authentication ---

[ ] API key comparison uses constant-time comparison
[ ] Failed authentication returns generic error (no information leakage)
[ ] API keys stored as hashes, not plaintext
[ ] Authorization scopes enforced per endpoint

--- Transport ---

[ ] TLS required for non-localhost bindings
[ ] Cipher suites restricted to strong set
[ ] HSTS header present when TLS enabled
[ ] WebSocket origin checking enforced

--- Resource Limits ---

[ ] Rate limiting configured
[ ] Max concurrent connections enforced
[ ] Max request body size enforced
[ ] KV cache exhaustion handled gracefully (preemption, not crash)

--- Secrets ---

[ ] No secrets in source code
[ ] No secrets in log statements
[ ] No secrets in error messages
[ ] Configuration files have restrictive permissions
[ ] Secret memory is zeroed before exit

--- Logging ---

[ ] Prompt contents never logged
[ ] Generated outputs never logged
[ ] API keys logged only as hash prefix
[ ] Log injection prevented (newline escaping, control char stripping)

--- Model Loading ---

[ ] GGUF parser defends against truncated headers
[ ] Tensor offsets validated against file size
[ ] Decompression ratio capped (zip bomb defense)
[ ] Optional integrity verification via checksum

--- Filesystem ---

[ ] Process runs as non-root user
[ ] Configuration directory permissions restrictive
[ ] No write access outside designated directories

--- Dependencies ---

[ ] No new dependency introduced without DEPENDENCY_POLICY.md compliance
[ ] No dependency with telemetry or analytics
[ ] Supply chain checksums verified

--- Incident Readiness ---

[ ] Logging captures sufficient information for forensic analysis
[ ] Log retention period configured
[ ] Incident response procedure documented and accessible
```

---

## Section Fourteen: Quick Reference

```
BEFORE EXPOSING TO NETWORK:
□ TLS configured and certificate valid
□ Authentication enabled (non-plaintext API keys)
□ Server binds to intended address (not 0.0.0.0 unless deliberate)
□ Rate limiting configured
□ Firewall rules permit only intended ports
□ Reverse proxy in front (recommended)

BEFORE ACCEPTING USER INPUT:
□ Schema validation enforced for all fields
□ Size limits on all payloads
□ Path traversal prevention verified
□ Null bytes rejected
□ Unicode normalized

BEFORE LOGGING ANYTHING:
□ No prompt contents in log
□ No generated output in log
□ No full API keys in log
□ No secrets in log
□ Log injection prevented

IF SUSPECTING COMPROMISE:
□ Stop the process
□ Preserve logs and evidence
□ Notify coordinator with facts only
□ Rotate all secrets
□ Do not speculate in communications
```

---

## Closing Principle

Security is not a product. It is a posture. It is the accumulated result of hundreds of small decisions: validating an input, comparing a key in constant time, rejecting a malformed packet, refusing to log a prompt, binding to localhost by default.

Each decision individually seems trivial. Collectively, they determine whether the system withstands adversity or collapses under it.

The adversary does not need to be genius. The adversary needs only one overlooked input, one unvalidated field, one secret committed to git, one dependency that phones home. Our job is to close those doors before they are opened, not after they are walked through.

Paranoia is a feature. Deploy it generously.

---

*Last updated: 2026-08-15. Maintained by the Auditor role. Threat model reviews conducted quarterly. Incident reports filed under docs/incidents/*

---
