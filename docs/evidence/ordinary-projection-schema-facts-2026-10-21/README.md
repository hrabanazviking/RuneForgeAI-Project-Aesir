# Qualified constructor metadata only

Twelve pinned4.57.1 SmolLM3 meta-constructor cases; no real parameter storage,
full model, source weights or model/layer/attention forward. Apache2 and Torch
BSD/bundled license identities are in the audit. The earlier configuration-only
license receipt had Torch absent; this isolated constructor oracle now imports
installed2.11.0+cpu, without adding a production dependency. External module
identities are hashes only; implementation was not copied or translated.

Raw traces and intermediate probes remain outside the repository at the exact
paths/hashes in archive-identities. Initial8 cases used norm dimension8 correctly.
The expanded12-case probe still fixed norm dimension8 for newly varied hidden
sizes; final probe explicitly uses config.hidden_size and records the argument.
An initial audit incorrectly matched imported safetensors Python package files
as model payloads. The corrected audit distinguishes model file extensions;
that was an audit pattern correction, not a model load. Both scripts are retained.

No constructor acceptance is a valid-model or numerical-semantics oracle.
Odd/tiny heads, cache false and tp2 are header observations only. Remaining
rotary/scaling/cache/training/activation behavior and hardware execution are open.
