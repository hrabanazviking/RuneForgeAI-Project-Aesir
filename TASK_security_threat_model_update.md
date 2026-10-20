# AES500-361 — verified security boundary contract

## Objective and owner

Reconcile the target-state security threat model with controls that have
current implementation and executable evidence. The owners are native service,
loader/model admission, and project security documentation.

## Invariants

1. Target controls and verified controls are labeled separately.
2. Every verified control links to its current reproduction/evidence surface.
3. Residual risks stay visible, including no TLS/remote access,
   multi-tenancy, authorization scopes, exhaustive fuzzing, production audit,
   or secure GPU-memory erasure.
4. Test evidence is not a certification, exhaustive attack proof, or blanket
   deployment recommendation.
5. The existing local-only API and model-admission behavior are not changed by
   this documentation slice.

## Acceptance and exclusions

Update `SECURITY_POSTURE.md` and the AES-OPS-003 ledger language to match
`docs/NATIVE_SERVICE.md`. Verify documentation drift and link/hygiene gates.
This slice does not add runtime controls, new attack tests, TLS, remote access,
or a production security assessment.
