# Explicit source-bound rotary mathematical recipes

Date:2026-10-21. Contract TASK_hailo10h_rotary_recipes.md and published-before-code
docs/HAILO10H_ROTARY_RECIPES_DESIGN.md, both branches048924d. Owner-fixed broad
ordinary model target unchanged. This is original Mojo compiler IR and hypothetical
storage accounting, never an executable Hailo program or source-model execution.

## Implementation and compatibility

RotaryLoweringPolicy owns explicit adjacent/split_half basis, provenance and
recipe/work bounds. Old unary recipe and expanded-graph APIs retain unchanged
output and opaque rotary nodes. Opt-in overloads map both source activation and
index positions, preserving their exact IDs/domains and owned local descriptors.
Original recipe expansion emits13 mathematical operations: inverse-frequency
constant definition, position/frequency angle construction, cosine/sine, the two
explicit gathers, four products, subtraction/addition and tail-preserving scatter.
The frequency is b**(-2*j/R); each pair uses the elementary2x2 rotation. Partial
rotary dimensions preserve all tail components and Q/K head counts remain distinct.

The typed semantic plan's Float32 base bits are retained exactly. This does not
silently narrow ordinary Float64 config values or claim their complete adapter;
that precision reconciliation and the remaining source modifiers remain open.
No format name or tensor shape automatically chooses the basis. Qualified pinned
ordinary public-callable facts support split_half for that interface only, with
static oracle/negative/license evidence in the pre-code fact receipt.

Expanded graph integrates every emitted dependency and preserves source outputs,
KV aliases and export identities. Storage validates the exact selected recipe
kinds/edges/shapes/base/basis/provenance/position mapping against rederived source
recipes, rejects changed/stale groups, and recomputes inclusive global lifetimes.
The sole new index operand is rotary_angles position0. All13 produced values are
real activations, so their actual descriptor shapes/lifetimes are charged in the
existing explicit hypothetical-width scenario. There is no uncounted device table,
placed arena, resource-fit or numerical precision claim.

Policy admission precedes rotary descriptor allocation: scan bound, actual count,
checked coarse work=len(source.operations)+count*(128+basis.UTF8+provenance.UTF8).
No full tensor of activations or weights is allocated or evaluated by production.
Malformed source roles/arity/shape/products/aliases/order/lifetimes/positions/base
and bounds refuse; returned policies, maps, strings and shapes own their storage.

## Evidence and remaining work

Thirty warning-free ARM64 entrypoints build. Sixteen final suites pass:
**104 methods/2864 native calls**. New rotary suite5/153 has76 accepted calls and
77 expected refusals,37 complete structures,18 complete frozen legacy outputs,
75 adversarial source/derived/snapshot mutations, two short policy refusals and
three exact/ownership checks. Fourteen compiler regressions94/2559 preserve108
full frozen consumer outputs; decoder policy5/152 preserves40 complete NoPE graphs.
Six isolated primitive fixtures compare256 scalars against independent complex
2x2 rotation, including zero positions/tails and norm preservation. Native trace
has no Torch, network connect or Hailo device open. Final source/binary hashes
remain unchanged through verification.

Review additionally hardened source lifetime ranges and validates the entire
owned rotary recipe snapshot against rederived values/operations/mappings, as
well as the global expanded graph. All13 added refusal cases pass. Full raw
outputs/traces/binaries remain in the external work archive with exact published
identities. The published compact receipt includes commands/logs/source hashes,
per-call output identities, representative complete graph and primitive values:
`docs/evidence/rotary-recipes-2026-10-21/`.

Initial native compilation required an explicit Mojo move return and initial API
builds warned about ignored List.pop values; both were corrected with logs kept.
An early full comparison harness ran before the final legacy recipe executable
existed; its FileNotFoundError and all earlier runs remain, with subsequent full
acceptance separately identified. Successful final runs are identified separately.
Static frequency observation differs from ideal real math by up to2.9196e-7;
no test-only float result qualifies finite device precision or approximation.

The new inspector is an internal synthetic-source compiler diagnostic. No source
payload mathematics, model/layer/attention forward, external inference compiler,
DFC, user conversion, vendor artifact or device program is used. Tiny numerical
checks interpret one emitted rotary primitive on test-owned constants only.
No CPU/CUDA/cloud model execution, Hailo device access, upload or hardware fit is
claimed. Actual numerical instruction/register/configuration generation, precision,
packing, placement, upload/activation/results/cleanup remain required, together
with complete ordinary source semantics and broad format/architecture coverage.
After publication/remote verification continue the parent rotary/modifier work
and actual numerical backend automatically.

Whole-repository consistency remains failing: 17862 diagnostics,
comprising17494 baseline and368 new retained receipt-path diagnostics;
no new nonreceipt diagnostic after line-number normalization. Ledger census is
106 verified/151 total, with no duplicate ID. Hosted defaults checkpoint CI
failed the existing historical-master compile step; no master pass is claimed.
