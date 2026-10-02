# Optional scaled residual precision experiment

The preceding unscaled three/four-term candidates pass original quality budgets
but miss the separately declared native-model RMS goal .0005. Read
[the retained rejection](NATIVE_TURING_ACTIVATION_RESIDUAL.md) before using this
experiment. Normal runtime admission remains one/four tokens; these candidates
are isolated test paths.

## Representation and accumulation

The optional fifth project_turing_staged parameter now admits precision 3/4,
only for CTA rows 64 and input width 32. Both retain high=F16(original), and
store low=F16(4096*(original-F32(high))) for weights and activations. Original
packed equations own the weight values. Scale 4096 is an exact power of two.
The shared allocation and checked span ownership are unchanged: at most 12672
bytes, with no new global workspace or full model copy. Every consumed shared
cell initializes before the existing two all-thread barriers.

All four high/low products use public F16-input/F32-accumulator MMA. Each
correction product starts with a zero F32 accumulator, then is divided by 4096
for one low operand or 16777216 for two, before adding to the unscaled total.
No total containing an unscaled high-high contribution is divided. Mode 3
accumulates high-high into the existing total, whereas mode 4 starts even that
product at zero, then adds it in F32. The extracted accumulate_staged helper
keeps legacy modes 0/1/2 and their original accumulation order intact.

These are candidate numerical designs, not an established hardware explanation
for previous errors. Fixed measurements decide acceptance. Nonfinite conversion
or output, invalid spans, missing values or guard failure rejects the evidence.

## Reproduction and fixed gates

Use the original models, private artifact paths and complete checker commands
from [captured-input operation](NATIVE_TURING_ACTIVATIONS.md) and
[whole-model operation](NATIVE_TURING_MODEL_PREFILL.md). Build both probes as in
the previous residual manual, then select final integer precision 0, 3 or 4 in
separate owned processes with new output files. Finish every host compilation
before scored GPU work. Serialize all GPU sessions, then run independent CPU
oracles. Keep every failed and successful attempt outside Git.

Legacy zero metadata stays unchanged. The explicit split identities used by
modes 1/2 now additionally admit 3/4; unknown modes, mixed or duplicate metadata,
wrong shapes and incomplete or late records reject. The same complete captured
coverage remains: 1,990,656 native outputs, 2520 selected independent dots,
114688 original F32 sources, input guards and 12 invalid spans per mode.
Whole-model coverage remains all 513024 final-prompt values per mode versus
normal native and independent CPU F32 references, exact repeats/commits, eight
invalid tiles, 4352 guards and all 32 alternating warm/scored timing records.

All original .002-scaled/.0002-RMS projection and .05-max/.005-RMS/matching-argmax
model gates remain. Nonzero model modes must also earn native-to-matrix RMS
at most .0005 in every public case. Completion alone never passes. Any failed
gate retains full metrics and withholds every speed ratio; failed rescoring
also removes earlier medians and ratios. One warm/export pair is unscored,
then three alternating fresh pairs remain per public prompt.

Only complete passes may earn isolated prefill ratios. The result never proves
production memory/control/cancellation, generation/sampling/restore/concurrency,
broader contexts, complete requests, Ollama/provider lead or second-session
integration. Hosted CI compiles probes without claiming physical execution.

## Retained complete results — 2026-10-02

All three captured-input sessions pass unchanged budgets: 5,971,968 complete
native outputs, 7560 selected independent dots, 344064 source values and every
guard/invalid span. All three model sessions preserve exact repeats/commits,
all 13056 guards and every original independent .05/.005/matching-argmax gate.
Both new modes miss the additionally declared native-model RMS goal .0005.

| Mode | Worst captured native RMS | Long native-model RMS | Refinement | Accepted long prefill ratio |
|---|---:|---:|---|---:|
| 0, original | .00009482 | .00291580 | original budgets pass | 1.675 |
| 3, scaled corrections | .00000468 | .00113806 | rejected | withheld |
| 4, separate high-high product | .000000394 | .00122564 | rejected | withheld |

Mode 4 improves captured projection RMS about 241x from mode 0, but its complete
long model still misses the stricter goal. Independent long matrix RMS is
.00161759/.00245646 for modes 3/4, under the older .005 limit. Preserve every
raw value and all 96 warm/scored timing records; do not publish accepted speed
ratios for either rejected candidate. No hardware cause follows from these
measurements. Broader Q5_K/model/context precision remains unproved.

All compilation finished before serialized GPU captures, with CPU oracles only
afterward. sm75/sm89 probes and legacy staging compile; ten captured-input and
nine model contracts pass. Normal binary remains f3442a1e and authenticated
active readiness is checked separately. Exact pushed CI has its own receipt.
[Reviewed evidence](evidence/turing-scaled-residual-2026-10-02/README.md).
Next harden checked workspace/profile/device admission for the original passing
matrix fixture before earning production memory/control/generation/restore gates.
