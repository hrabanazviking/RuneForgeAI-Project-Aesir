# DEPENDENCY POLICY — Project Æsir

## Authority

This document governs every external dependency introduced into Project Æsir. It defines what is permitted, what requires justification, what is forbidden, and how approvals work. The ENGINEERING_DOCTRINE.md establishes that the project must remain lean and auditable. This document defines what lean and auditable mean in practice.

A dependency is any code that the project consumes but does not own. This includes Mojo packages, Python modules invoked through interop, C libraries linked through FFI, system libraries accessed through dynamic loading, and build-time tools required for compilation or testing.

Every dependency is a liability. It is code you did not write, cannot fully verify, and must trust to behave correctly across versions and platforms. Dependencies save time initially and cost time eternally. This policy exists to ensure that every dependency earns its place.

---

## Section One: Core Principles

### Principle of Minimal Surface Area

The project should depend on as few external codebases as possible. Fewer dependencies means fewer attack surfaces, fewer version conflicts, fewer breaking changes from upstream, and fewer license obligations to track.

### Principle of Provenance

Every dependency must have a documented origin, license, maintainer, and version. Unknown dependencies are forbidden. If you cannot identify where the code came from and who is responsible for it, you cannot include it.

### Principle of Auditability

Every dependency must be inspectable. Closed-source dependencies are forbidden. Obfuscated or minified source without a readable counterpart is forbidden. If we cannot read the code, we cannot trust it.

### Principle of Isolation

Dependencies must not leak their abstractions into the project's public interfaces. If a dependency is replaced, the replacement must not require changes outside the consuming module. Dependencies are implementation details, not architectural commitments.

### Principle of Reversibility

Every dependency inclusion must have a hypothetical removal path. If the dependency were discontinued or revealed to be insecure, could the project survive without it? If the answer is no, the dependency has too much coupling.

---

## Section Two: Dependency Tiers

### Tier 1: Permitted Without Justification

These dependencies are foundational and universally trusted. They require no special approval but must still be recorded in the dependency manifest.

| Dependency | Type | Reason |
|------------|------|--------|
| Mojo Standard Library | Language stdlib | Ships with the compiler. Cannot be avoided. |
| LLVM runtime | Compiler backend | Required for Mojo compilation. Inherent to the toolchain. |
| System GPU drivers (CUDA, ROCm) | System library | Necessary for GPU execution. Managed by the OS, not by us. |
| System threading primitives (pthread) | System library | Required for concurrent execution. Provided by the OS. |

Tier 1 dependencies are assumed present on the target system. They are not vendored, not pinned, and not shipped with the project. They are prerequisites, not dependencies in the traditional sense.

### Tier 2: Permitted With Justification

These dependencies are commonly useful but require a written justification in the dependency manifest before inclusion. The justification must explain why the problem cannot be solved with Mojo's standard library alone.

| Category | Examples | Justification Required |
|----------|----------|----------------------|
| C standard library functions (libc) | malloc, free, memcpy, strlen | Why is a Mojo-native alternative insufficient? |
| BLAS/LAPACK implementations | OpenBLAS, MKL | What linear algebra operation requires this, and why is a Mojo implementation inadequate? |
| File format parsers (image, audio) | libpng, libjpeg | What format is being parsed, and why is it necessary for an LLM inference engine? |
| Compression libraries | zlib, lz4, zstd | What is being decompressed, and is the performance gain over a Mojo implementation significant? |
| Crypto primitives | OpenSSL, libsodium | What cryptographic operation is required, and why must it use an external library? |

### Tier 3: Restricted — Requires Architect Approval

These dependencies carry significant risk and require explicit Architect role approval before inclusion. The approval must be recorded in a DECISIONS entry.

| Category | Risk | Approval Criteria |
|----------|------|-------------------|
| Python modules via interop | Pulls in CPython runtime, GIL, and transitive dependency tree | Must prove no Mojo-native solution exists. Must isolate all Python calls behind a single module boundary. Must document performance overhead. |
| C++ libraries with complex ABIs | Template-heavy headers, STL dependencies, exception handling | Must prove no C library alternative exists. Must wrap in a thin C ABI shim. Must not let C++ types cross the boundary. |
| Frameworks (web, ORM, DI) | Imposes architectural opinions on the project | Almost always denied. The project defines its own architecture. Frameworks that dictate structure are antithetical to the project's design philosophy. |
| Anything with a copyleft license | GPL, LGPL, AGPL | See Section Five. Generally denied unless the project license is compatible. |

### Tier 4: Forbidden

These dependencies are categorically prohibited. No justification, no approval, no exceptions.

| Category | Reason |
|----------|--------|
| Proprietary or closed-source libraries | Cannot audit. Cannot verify. Cannot trust. |
| Libraries with telemetry or analytics | The project sends no data anywhere. Ever. |
| Libraries requiring network activation or license servers | The project must function fully offline. |
| Libraries with known unpatched critical vulnerabilities | Security liabilities. |
| Libraries maintained by anonymous or unverifiable authors | No accountable party. |
| Libraries that bundle other forbidden dependencies transitively | Guilt by association. If it drags in telemetry, it is telemetry. |
| Entire language runtimes used as conveniences | Pulling in Node.js to parse JSON. Pulling in Ruby to run a build script. Pulling in Perl for text processing. Use Mojo. |
| "Smart" wrapper libraries that obscure their underlying dependencies | If you cannot tell what a wrapper wraps, you cannot audit it. |

---

## Section Three: The Dependency Manifest

### File Location

`docs/DEPENDENCIES.md`

This file is the single source of truth for all external dependencies. If a dependency is not listed here, it is not approved. If code imports something not in this manifest, the build must fail.

### Manifest Format

```markdown
# Dependency Manifest — Project Æsir

## Tier 1 — Prerequisites

| Dependency | Version Constraint | Purpose | Required At |
|------------|-------------------|---------|-------------|
| Mojo Standard Library | >= 1.0.0 | Language foundation | Compile time |
| CUDA Toolkit | >= 12.1 | GPU execution (NVIDIA path) | Runtime (if GPU present) |
| ROCm | >= 6.2 | GPU execution (AMD path) | Runtime (if GPU present) |

## Tier 2 — Justified Dependencies

| Dependency | Version Constraint | Purpose | Justification | Introduced In | Approved By |
|------------|-------------------|---------|---------------|----------------|-------------|
| zlib | >= 1.3.1 | GGUF file decompression | GGUF files use zlib compression for tensor data. Mojo stdlib lacks inflate implementation. Performance-critical: decompression throughput directly impacts model load time. | feat/gguf-zlib-support | Architect |

## Tier 3 — Restricted Dependencies

| Dependency | Version Constraint | Purpose | Approval Reference | Introduced In | Approved By |
|------------|-------------------|---------|-------------------|----------------|-------------|
| (none currently) | — | — | — | — | — |

## Forbidden Dependencies

No entries. If a forbidden dependency is discovered in the codebase, it is removed immediately and the introducing agent is notified.
```

### Manifest Maintenance

The Scribe role is responsible for keeping the manifest current. Every PR that introduces, upgrades, or removes a dependency must update the manifest in the same PR. A stale manifest is a documentation defect.

### Manifest Audit

The Auditor role verifies the manifest against actual imports quarterly. The audit procedure:

1. Extract all `import` and `from ... import` statements from Mojo source files.
2. Extract all `external_call` references from FFI code.
3. Extract all `Python.import_module` calls from interop code.
4. Cross-reference every external reference against the manifest.
5. Report unmatched references as violations.

Results are recorded in `docs/audits/dependency-audit-YYYY-MM-DD.md`.

---

## Section Four: Python Interop Policy

### General Stance

Python interop is the most dangerous dependency category because it appears cheap but carries enormous hidden costs. Each `Python.import_module("foo")` call pulls in:

- The CPython interpreter (already running if Mojo uses interop)
- The imported module's entire dependency tree
- The GIL, which constrains concurrent execution
- Potential C extensions that may not be thread-safe
- Version-specific behavior that varies across Python installations

### When Python Interop Is Permissible

Python interop is permissible only when ALL of the following are true:

1. **No Mojo-native solution exists** for the specific functionality required.
2. **The functionality is not performance-critical** (not on the inference hot path).
3. **The Python module is pure Python** (no C extensions that complicate deployment).
4. **The module is widely maintained** (active development within the last 12 months).
5. **The module's own dependency tree is minimal** (fewer than 5 transitive dependencies).
6. **All Python calls are isolated** behind a single Mojo module that serves as the interop boundary.

### When Python Interop Is Forbidden

Python interop is forbidden when ANY of the following are true:

1. The functionality is on the inference hot path (tokenization, forward pass, sampling, KV cache management).
2. A Mojo-native solution exists or could reasonably be implemented within the project's scope.
3. The Python module requires network access during normal operation.
4. The Python module has its own telemetry, analytics, or error reporting.
5. The Python module is abandonware (no commits in 24+ months).
6. The interop would require shipping a specific Python version with the project.

### Python Interop Boundary Pattern

When Python interop is approved, all Python calls must be isolated behind a single Mojo module:

```
src/python_bridge/
├── INTERACE.md          # Public interface (Mojo types only)
├── bridge.mojo          # All Python.import_module calls live here
├── converters.mojo      # Mojo ↔ Python type conversion
└── README.md
```

Rules for the bridge module:
- No other module in the project may call `Python.import_module` directly.
- The bridge module's public interface uses only Mojo types. Python objects never escape the bridge.
- The bridge module handles all GIL acquisition and release.
- The bridge module logs every Python call at debug level for diagnostic purposes.
- The bridge module catches all Python exceptions and converts them to Mojo typed errors.

### Approved Python Modules

Currently approved Python modules (if any) are listed in the Tier 3 section of the dependency manifest with their approval references. As of this document's creation, no Python modules are approved. The project aims to be Python-free at runtime.

---

## Section Five: Licensing Requirements

### Compatible Licenses

Project Æsir is licensed under the Apache License 2.0. Only dependencies with compatible licenses may be included.

**Fully Compatible (no obligations beyond attribution):**
- Apache License 2.0
- MIT License
- ISC License
- BSD 0-Clause
- BSD 2-Clause
- BSD 3-Clause
- Boost Software License
- Unicode Data License
- Zlib License

**Conditionally Compatible (requires careful review):**
- Mozilla Public License 2.0 (weak copyleft, file-level. Requires source disclosure for modified MPL files only. Generally compatible if we do not modify the library.)
- Eclipse Public License 2.0 (similar to MPL. Review required.)

**Incompatible (forbidden):**
- GNU General Public License (GPL) 2.0 or 3.0 (strong copyleft. Infects the entire project.)
- GNU Lesser General Public License (LGPL) (dynamic linking may be permissible, but the restrictions are complex and the risk is unjustified.)
- Affero General Public License (AGPL) (network copyleft. Completely incompatible with a local-first project.)
- Creative Commons NonCommercial (CC BY-NC) (commercial use restricted. Project must remain usable commercially.)
- Source-available but not OSI-approved licenses (proprietary in disguise.)
- "Fair Source" or "BSL" licenses with eventual-open provisions (timing and conditions are unreliable.)

### License Verification Procedure

Before including any dependency:

1. Locate the dependency's LICENSE file.
2. Verify the license is in the compatible list above.
3. Check for additional CLAUDE.md or NOTICE files that impose additional obligations.
4. Record the license in the dependency manifest.
5. Ensure the project's NOTICE file acknowledges the dependency.
6. If the dependency is conditionally compatible, create a DECISIONS entry documenting the review.

### Transitive License Checking

Dependencies bring their own dependencies. The Auditor must verify that the entire transitive closure of dependencies contains only compatible licenses. A permissively-licensed library that links against an LGPL library creates an LGPL obligation for the project.

Tooling for transitive license checking should be automated where possible. Until automated tooling exists, manual verification is required for every new dependency.

---

## Section Six: Versioning and Pinning

### Version Pinning Policy

All dependencies must be version-pinned. Floating dependencies (using "latest" or unpinned version ranges) are forbidden.

```toml
# Good — pinned
zlib = ">=1.3.1,<1.4.0"

# Bad — floating
zlib = "*"
zlib = "latest"
```

### Pin Granularity

- **Major version pinned** for stable, well-understood dependencies: `>= 1.0.0, < 2.0.0`
- **Minor version pinned** for dependencies with frequent breaking changes in minor releases: `>= 1.3.0, < 1.4.0`
- **Exact version pinned** for security-sensitive or ABI-sensitive dependencies: `== 1.3.1`

### Upgrade Policy

Dependency upgrades require:

1. A review of the changelog or release notes for breaking changes.
2. Running the full test suite against the new version.
3. Running performance benchmarks to detect regressions.
4. Updating the dependency manifest with the new version.
5. A commit type of `chore: upgrade [dependency] from [old] to [new]`.

Automated dependency upgrade bots ( Dependabot, Renovate) may be enabled for patch-version upgrades only. Minor and major upgrades require manual review.

### Lockfile

The project maintains a lockfile (`deps.lock`) that records the exact resolved version of every dependency and transitive dependency. The lockfile is committed and reproduced in CI. This ensures that every build uses identical dependency versions regardless of when it is built.

---

## Section Seven: Vendoring Policy

### When to Vendor

Vendoring means copying a dependency's source code directly into the project repository. Vendor a dependency when:

1. The dependency is small (under 1000 lines of source).
2. The dependency is stable (no frequent upstream changes).
3. The dependency's upstream is at risk of disappearing (maintainer inactive, repository archived).
4. The dependency requires patches that upstream will not accept.
5. The dependency's build system is complex and vendoring simplifies the build.

### When Not to Vendor

Do not vendor when:

1. The dependency is large (tens of thousands of lines).
2. The dependency is actively developed with frequent security patches.
3. Vendoring would create maintenance burden exceeding the burden of tracking upstream.
4. The dependency has its own complex dependency tree that would also need vendoring.

### Vendoring Procedure

1. Copy the source into `vendor/[dependency-name]/`.
2. Include the original LICENSE file.
3. Include the original NOTICE file if present.
4. Add a `vendor/[dependency-name]/VENDOR_INFO.md` recording:
   - Original repository URL
   - Exact version/commit vendored
   - Date of vendoring
   - Any modifications made
   - Reason for vendoring
5. Update the dependency manifest to mark the dependency as vendored.
6. Update THIRD_PARTY_NOTICES.md.

### Vendored Code Modifications

Modifications to vendored code must be:
- Documented in `VENDOR_INFO.md`
- Marked clearly in the source with comments: `# Modified for Project Æsir: [reason]`
- Submitted upstream as a PR where feasible

Vendored code that has been substantially modified should be considered for migration out of `vendor/` into `src/` as a first-class project module.

---

## Section Eight: Security Assessment

### Threat Model

Dependencies are a primary vector for supply-chain attacks. The project assumes the following threats:

- **Malicious updates**: A dependency maintainer publishes a version containing malware.
- **Account compromise**: A dependency's package account is hijacked.
- **Typosquatting**: A similarly-named malicious package is installed by mistake.
- **Transitive vulnerabilities**: A dependency's dependency contains a vulnerability.

### Mitigation Requirements

1. **Checksum verification**: All dependency downloads must be verified against known checksums.
2. **Minimal privileges**: Dependencies must not require elevated permissions to install or run.
3. **Network isolation**: Dependencies must not make outbound network connections during installation or runtime unless explicitly approved.
4. **Regular auditing**: The Auditor role runs dependency vulnerability scans monthly. Results are recorded in `docs/audits/security-audit-YYYY-MM-DD.md`.
5. **Rapid removal procedure**: If a dependency is found to be compromised, the procedure is:
   ```
   1. Quarantine: Remove the dependency from the build immediately.
   2. Assess: Determine what functionality relied on it.
   3. Replace: Implement a Mojo-native alternative or find a vetted replacement.
   4. Document: Record the incident in DECISIONS and DEVLOG.
   ```

### SBOM (Software Bill of Materials)

The project maintains an SBOM listing all dependencies, their versions, licenses, and suppliers. The SBOM is generated from the dependency manifest and lockfile. It is updated whenever dependencies change.

SBOM location: `docs/SBOM.md`

---

## Section Nine: Build-Time vs Runtime Dependencies

### Build-Time Dependencies

Build-time dependencies are required only during compilation. They do not ship with the runtime binary.

Examples:
- Mojo compiler
- Linker (lld)
- Build system tools (make, cmake if wrapping C deps)
- Code generators

Build-time dependencies are tracked in the dependency manifest but do not require the same level of runtime security scrutiny. However, a compromised build tool can inject malicious code into the compiled output, so build-time dependencies still require provenance verification.

### Runtime Dependencies

Runtime dependencies are required during execution. They ship with the deployed binary or must be present on the target system.

Runtime dependencies bear the full weight of this policy: licensing, security, versioning, and auditability.

### Test-Time Dependencies

Test-time dependencies are required only for running tests. They do not ship with the runtime binary.

Examples:
- Benchmark harnesses
- Property-based testing libraries
- Mock frameworks (though mocks are discouraged per TESTING_PROTOCOL.md)

Test-time dependencies are tracked separately and must not leak into production builds. The build system must exclude test dependencies from release artifacts.

---

## Section Ten: Removal and Replacement Procedure

### When to Remove a Dependency

Remove a dependency when:
1. A Mojo-native implementation becomes available.
2. The dependency is no longer maintained.
3. The dependency introduces unresolvable security vulnerabilities.
4. The dependency's license changes to something incompatible.
5. The dependency's functionality is no longer needed.
6. The dependency's performance is inadequate and cannot be improved.

### Replacement Procedure

1. **Assessment**: Identify all call sites that use the dependency.
2. **Alternative identification**: Determine the replacement strategy (native implementation, alternative library, elimination of functionality).
3. **Migration plan**: Document the order of changes. Update interfaces if needed.
4. **Implementation**: Replace call sites one at a time. Test after each replacement.
5. **Removal**: Delete the dependency from the manifest, lockfile, and build configuration.
6. **Verification**: Run full test suite. Run performance benchmarks. Confirm no regressions.
7. **Documentation**: Update DEVLOG, dependency manifest, and any affected INTERFACE.md files.

### Removal Commit Format

```
refactor: remove [dependency] from [domain]

Replaces [dependency] with [alternative].
Reason: [maintenance/security/license/performance concern].

Updated call sites: [count]
Tests: all passing
Performance: [delta, if measurable]

BREAKING CHANGE: none (internal replacement, public API unchanged)
```

---

## Section Eleven: Dependency Review Checklist

Before submitting a PR that introduces or changes a dependency:

```
DEPENDENCY REVIEW CHECKLIST
============================

Dependency: _________________________________
Version: _________________________________
Category: [ ] New | [ ] Upgrade | [ ] Removal

--- Tier Classification ---

[ ] Tier 1 (prerequisite, no justification needed)
[ ] Tier 2 (justified, written rationale provided)
[ ] Tier 3 (restricted, Architect approval recorded in DECISIONS)
[ ] Tier 4 (FORBIDDEN — STOP HERE IF CHECKED)

--- License Verification ---

[ ] License identified and recorded
[ ] License is in the compatible list
[ ] NOTICE file updated if required
[ ] THIRD_PARTY_NOTICES.md updated
[ ] Transitive dependencies checked for incompatible licenses

--- Security Assessment ---

[ ] No known unpatched critical vulnerabilities
[ ] No telemetry or analytics in the dependency
[ ] No network activation or license server requirements
[ ] Maintainer is identifiable and active
[ ] Checksum verification possible

--- Technical Assessment ---

[ ] No Mojo-native alternative exists (for Tier 2/3)
[ ] Performance impact assessed (if on hot path, denied)
[ ] Isolated behind a module boundary (no leakage into public interfaces)
[ ] Version pinned appropriately
[ ] Lockfile updated
[ ] Dependency manifest updated

--- Python Interop Specific (if applicable) ---

[ ] All Python calls isolated in python_bridge/ module
[ ] No Python objects escape the bridge
[ ] GIL handling implemented
[ ] Python exceptions converted to Mojo errors
[ ] Module is pure Python (no C extensions)
[ ] Module has minimal transitive dependencies

--- Removal Path ---

[ ] Hypothetical removal path documented
[ ] Replacement strategy identified (even if not implemented)
```

---

## Section Twelve: Quick Reference

```
BEFORE ADDING A DEPENDENCY:
□ Checked if Mojo stdlib can solve this?
□ Identified the dependency's license?
□ Verified the license is compatible?
□ Checked for known vulnerabilities?
§ Confirmed no telemetry/analytics?
□ Identified a removal path?
§ Classified the tier?
□ Prepared justification (Tier 2) or approval reference (Tier 3)?

NEVER:
□ Add a dependency without updating the manifest
□ Add a dependency with an incompatible license
□ Add a dependency with known critical vulnerabilities
□ Allow Python objects to escape the interop bridge
□ Use floating version constraints
□ Add a dependency that phones home

WHEN UNSURE:
□ Consult this document
□ Escalate to Architect role for Tier 3 classifications
□ Create a DECISIONS entry documenting the question and resolution
```

---

## Closing Principle

Every dependency is a bet that someone else's code is trustworthy, maintainable, and secure. The odds are usually acceptable for small, well-known libraries. They deteriorate rapidly for large, unfamiliar, or niche packages.

Default to building with what Mojo provides. Reach for external code only when the cost of building native outweighs the cost of maintaining the dependency. And when you do reach, document everything so that the next agent understands why the choice was made and how to undo it if necessary.

The leanest codebase is the one that depends on the least. Build accordingly.

---

*Last updated: 2026-08-15. Maintained by the Architect role. Security assessments maintained by the Auditor role. Changes require Architect review and coordinator approval for Tier 3+ additions.*

---
