# SPD-01/02 — isolated16-column shared staging experiment

Established2026-10-03 before code; trace implementation70fb21b is pushed and exact
CI remains separately pending. Updated physical strategy3 gate/up/down sum51.9283%
of long summed GPU kernel durations. Recorded staged64/down128 registers255 and
static shared10560/19008 guide an experiment, without proving a bottleneck cause.
Volmarr authorizes successive scoped implementation/pushes.

Add separate narrow-column native sibling and wrapper in optional packed Turing
module. Preserve original staged/header-cache/large-row kernel bodies and defaults
verbatim; production never selects this candidate. Exercise rows64/128, columns16,
batch4/8/16/32, original precision0 packed12/13/14. Coalesced16 active decoding lanes
select the correct half of each original32-value group; initialize every shared
cell including padded rows/tokens, same high/residual F16 and original sequential
F32 MMA order, all threads reach both barriers. Shared rows64/128 withbatch32
require5440/9792 bytes versus10560/19008; threads128/256 unchanged. This could be
slower due to more barriers/half-lane stores; measure rather than assume.

Extend optional primitive harness final narrow_rows=0, exclusive from cached/large
flags, reuse original three-owner complete F32/signed-zero/full guards and rotated
native/candidate/original64 timings. New collector validates rows64/128 before
model/CUDA. Explicit mode narrow16 metadata admits only rows64/128/columns16;
legacy schemas unchanged. Complete144 synthetic cases/12 invalid spans per
configuration,1658880 real outputs perowner,2100 independent original-weight dots,
all guards and840 complete rotated timings. Scores require unchanged .002 scaled/
.0002 normalized RMS, every original F32 bit and independent admission; retain
complete failures and withhold all ratios on failure/hash drift/interrupt. No
budget relaxation, model mutation, workspace/device fallback or service promotion.

Portable adversarial metadata/bit/rotation/source/hash failure gates join existing
CI step. Buildsm75/sm89/original/master/normal/check before serial physical rows64
and128 captures; pinned CPU GGUF/NumPy only test oracle afterward. Retain failed
compile/launch/numerical artifacts, binary/source/model/CSV/provenance identities;
verify unchanged authenticated active prefill4 readiness. Document measured wins
or rejection in owners/manual/evidence/TODO/ledger/roadmap/devlog, push and exactCI.
Select next best measured slice afterward. Primitive evidence cannot promote
production32/full-model/generation/control/replay/broader/device/provider gates.
