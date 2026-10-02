# Captured ordinary native F32 input gate — 2026-10-01

Two public native four-token replays each commit32 positions. Complete layer27
FFN-normalized/attention/SiLU source vectors retain114688 original F32 values.
114677 are not exactly F16-representable; none overflows, maximum magnitude
27.140867. Q/K/V use representative FFN norms; output/gate/up/down use their
actual operands. Batch32 repeats the four captured vectors eight times.

All1,990,656 complete native outputs and2520 selected independent Float64 dots
pass unchanged scaled .002/RMS .0002 budgets, with all input/whole-span guards
and12 invalid-span rejects. Complete-native worst errors .0013060/.00009482;
selected-independent worst .00020492/.00007762. Collection completion alone
never passes a numeric gate. Every failed numeric report would retain all cases.

All host compilation ends before capture; CPU oracles run afterward. Initial
list-constructor/build-flag errors are retained. Nine portable adversarial tests
pass; optional sm_75/sm_89 host builds pass. Production binary stays f3442a1e,
service active and authenticated health HTTP200 ready. Exact pushed CI is separate.
No full-model quality, timing, state/control or provider promotion. Next scope
bounded whole-model prefill. capture.json retains all metrics/tokens/selected
rows; provenance.json hashes raw source/CSV/binary/build artifacts outside Git.
[Operation](../../NATIVE_TURING_ACTIVATIONS.md).
