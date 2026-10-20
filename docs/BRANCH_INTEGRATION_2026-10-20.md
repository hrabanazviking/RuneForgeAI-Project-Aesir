# Current branch integration into main

Owner request: merge all current branches so completed work reaches main.
Contract: `TASK_merge_current_branches_main.md`. Date: 2026-10-20.

Integrates AES500 e83b00a, latest Hailo 7636d65 and local C7 6bb6c9a,
starting from main e70b76a. Consistency 170aeaf and the remaining local
committed heads are already main ancestors. All source histories are retained.
The old C7 fixes were already superseded in main; its merge preserves ancestry
without reverting the current ARMVEGR implementation or Hailo-only guards.
Two deliberately retired historical paths remain retired; the receipt names
their retirement commits. Other checkouts and their uncommitted runs are intact.

Conflicts combine both devlogs, ledger evidence and interfaces; retain Gemma
and allowlisted tool descriptor helpers; preserve both tokenizer test sets;
merge strict UTF-8 admission with boundary-safe chunking; combine test imports
and registrations. Master registration is 266 executable cases plus one skip,
267 total. This is a registration count, not a completed suite run. Ledger
counts now reflect 138 recognized statuses and one historical noncanonical
entry. No historical status is promoted. The imported checker self-test's
outdated 120-entry expectation is reconciled to the actual 138-entry map.

## Verification and limits

Rebuilt native cache-layout: six methods, 89 calls (18 accept/71 refuse).
Rebuilt program RPC: eight methods, 140 calls (70 accept/70 refuse).
Merged host regression: 23 tokenizer methods, 27 UTF-8 chunk scenarios and
Gemma/allowlist descriptor composition pass. Artifact checker self-tests pass.
All Hailo source and evidence blobs retain their exact source-branch bytes;
current ARMVEGR and the owner's nine strategy uploads match starting main.

Historical master compile-only attempt fails on this Pi's Mojo 1.1 environment
(legacy InlineArray/MAX imports and an existing runtime-config test signature
mismatch). It was never executed. Repository consistency still reports 78
issues, including nine campaign-ledger schema diagnostics already present on
both starting main and Hailo. Historical path/artifact issues remain visible;
raw evidence is preserved. This merge does not claim full CI green.

CI now compiles the historical master rather than executing its CPU model
forwards, following the owner's Hailo-only scope, and runs the focused host
regression. Other gates remain present. No model is downloaded/evaluated and
no hardware is opened by this integration. Receipt:
`docs/evidence/branch-integration-2026-10-20/verification.json`.

The fixed target is `HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`: ordinary model
files, broad support, Aesir-owned internal Mojo lowering, all LLM execution on
Hailo-10H. Native mathematical schedules and transport primitives do not prove
numerical hardware execution. Next: `TASK_hailo10h_native_matrix_tiles.md`.
