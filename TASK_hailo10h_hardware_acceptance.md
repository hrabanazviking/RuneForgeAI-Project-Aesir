# Hailo-10H slices 139–140: repeatable physical acceptance

Date: 2026-10-19. Status: contracted before implementation.

Authorization: the owner requested pulling Project Aesir, checking roadmap
status, and continuing the Hailo-10 roadmap on this Pi with the established
autonomous workflow. Continue the existing `docs/cross-cutting-hailo-mission`
branch; publish this contract before implementation, then publish completed
slices with measured evidence. Preserve the separate main and AES500 work.

## Current truth

The original MIMISBRUNNR campaign delivered its CPU fallback after raw-mailbox
H111 failed. The active mission explicitly supersedes those restrictions with
direct in-process HailoRT GenAI, excludes CPU/CUDA/cloud inference and proxies,
and has implementation receipts through slice 138 at `619b2d1`. Its roadmap
checkboxes and introductory text have not caught up with those receipts.
HailoRT/firmware 5.3.0 and HAILO10H identify successfully on this boot through
the supported CLI. The driver device node is `h1x-0`, not `hailo0`.

## Owned work and invariants

- Reconcile branch-specific roadmap status against committed evidence.
- Slice 139: add a TEST-ONLY Python hardware acceptance seam around the real
  canonical Mojo executable. No mock inference, CPU oracle LLM, or proxy.
- Require an explicit binary, artifact, pinned profile, and fresh evidence
  directory. Independently hash the artifact; bind binary/library/profile
  identities, retain raw stdout/stderr including failures, and distinguish
  structural validator tests from actual physical execution.
- Slice 140: rebuild the direct backend and run real single-shot inference,
  persistent conversation, reset and closed-session checks on this Hailo-10H.
  Verify nonempty output, declared public-prompt expectations, device/runtime/
  model identity, context lifecycle and terminal completion states. Record
  instruction-format limitations without converting them into broad quality
  claims. Hardware failures remain failures, never skips or fabricated passes.
- Fix defects uncovered within this seam or its immediate backend boundary,
  with a regression and an explicit evidence scope.
- Keep existing operator services, driver binding, firmware and OS intact.
  No kernel work, reboot, raw register writes, unbind or reset is in scope.

## Files and verification

Owning domain: AESIR direct backend tests and its interface/evidence documents.
Expected files: `tests/test_hailo10h_hardware.py`, focused validator tests and
profile data, existing boundary tests if needed, Hailo roadmap/status documents,
`CAPABILITY_LEDGER.md`, `TODO.md`, and `DEVLOG.md`.

Build with `scripts/build_hailo10h.sh`; run C ABI/CLI boundary tests, the Mojo
exception cleanup probe, the validator regressions, and the actual hardware
acceptance seam. Inspect final diff and preserve failure evidence. The general
CPU/CUDA master is not this build's acceptance suite and must not be run as
CPU LLM fallback. Verify exact remote branch head after each push. Report
hosted CI independently of physical acceptance.

Completion means these two slices have reproducible code, reviewed evidence,
synchronized status and published commits. It does not mean all 200 slices,
model quality, performance, packaging, or release acceptance are complete.
