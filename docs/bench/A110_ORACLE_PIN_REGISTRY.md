# A-110 - Oracle pin registry

Wave 13 (Oracle infrastructure). Roadmap acceptance: registry
file in-repo; a row without pins cannot be marked judged.

## What was built

- `oracle_pin_registry.json` (repository root) - the in-repo
  registry file. Every row records the four pins:
  `model_sha256`, `oracle_backend`, `oracle_build_hash`,
  `prompt_hash`, plus `row_id` and `judged`.
- `aesir_engine/core/oracle_pins.mojo` - the registry as
  data (`registry_rows()`, mirroring the JSON file so the
  two cannot drift silently - the suite cross-checks them)
  and the enforcement point: `mark_judged()` raises, naming
  every missing or malformed pin, so a row without pins
  cannot be marked judged. `missing_pins()` / `pins_complete()`
  expose the same check without raising.
- `aesir_engine/tests/test_oracle_pins_a110.mojo` - 7 suite
  cases (`oracle.pin_*`) wired into `run_all.mojo`
  (pin 670 -> 677).

## Pin discipline

- `model_sha256` and `prompt_hash` must be exactly 64
  lowercase hex characters (a sha256). `oracle_build_hash`
  must be 40 or 64 lowercase hex (commit id, or sha256 of
  the oracle grading source). `oracle_backend` must be
  non-empty.
- `prompt_hash` is the sha256 of the RAW prompt bytes -
  never a template-rendered prompt (a rendered prompt is a
  comparator artifact, not an input). Grading stays
  CPU teacher-forcing (rank + logit gap), CPU engine vs
  CPU comparator only, per the A-054 reference-oracle
  declaration. No accelerator claim is made by this slice.

## Filed rows (pins computed on purpleraider at filing)

- `A045-PARITY-8B` (judged): model sha256
  7b064f5842bf9532c91456deda288a1b672397a54fa729aa665952863033557c
  (the A-049-class fixture, re-verified on device this
  session, == the A-067/A-081 pin); backend
  `cpu-teacher-forcing`; build hash
  7c1e7bd5286f143bb1ca5193a28f1eae3efa541b87f15bce7f291101706ac87c
  (sha256 of `aesir_engine/core/parity_battery.mojo`, the
  rank + logit-gap grading core, at the A-110 base);
  prompt hash 8d28067405893cce8c8bce168b08e002bd8a6f34d35729a5c2b63813b8171ce6
  (sha256 of the RAW prompt "One day, Timmy went to", the
  A-045 battery prompt).
- `A110-PREREG-SEER` (pinned, not judged): pre-registered
  row for the next matrix run; same model and oracle build,
  prompt hash 7182c315c0af73fc2f7176203c1b73525716a3a1be2c6a9fff33561627773fe0
  (sha256 of "The old seer cast the runes").
- `A110-UNPINNED-EXAMPLE` (no pins, not judged): the
  standing counterexample - `mark_judged` refuses it, and
  the suite proves the refusal names all four pins.

## Capability Ledger

The Z13-P5-110 entry is owed to the Part V gate (A-117),
exactly as the Part IV per-slice verdicts were filed by
the A-108 gate; no Part V ledger section exists on the
banked base yet (A-109 opens the part in parallel).
