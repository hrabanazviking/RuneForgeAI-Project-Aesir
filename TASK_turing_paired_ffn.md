# SPD-01/02 — isolated paired FFN gate/up input staging

Established2026-10-03 before code; loop implementation2529d7a is pushed, exactCI
pending. Two narrower/runtime-loop experiments passed all numerical gates and
lost all original64 timing cases. Keep original constexpr32-column decoding and
try sharing inputs across two real FFN matrices. Actual trace gate/up together
use33.14% of long summed kernel duration, an observation rather than a cause.
Volmarr authorizes scoped implementation/push/repeat.

Separate optional native paired module computes64 rows of gate and64 rows of up
per CTA using8 warps/256 threads, padded32 columns, precision0 and original public
MMA/quant helpers. Each original16-row warp retains chronological output arithmetic;
warps0..3 write left and4..7 right. Original two packed tensors remain separate.
One initialized F16 input tile is shared; packed high/residual rows stage into two
64-row halves. Both barriers/all warps/padded row/token initialization remain.
Maximum shared19008 atbatch32, no new global workspace or production selection.
Same-kind12/13/14 pairs only; actual strict3B gate/up are checked12/12 with same
8192x3072 geometry and distinct offsets. No mixed-kind claim. Extra selection/
resource/parallelism costs may outweigh reuse; require complete same-capture data.

Pure pair admission invokes original checked matrix bounds for both, then rejects
intersecting packed weight spans and output spans before enqueue. Prove12 hostile
span cases before model/CUDA. Separate collector exercises144 synthetic same-kind
Q4/Q5/Q6 tail pairs and real gate/up atbatches4/8/16/32. Allocate disjoint candidate,
original64 and native outputs only in probe. Export all983040 F32 values perowner,
actual descriptor/input identities, original UInt32 equality including signedzero,
unchanged .002 scaled/.0002 RMS, complete unowned guards. Independent pinned GGUF/
NumPy checks600 selected Float64 dots with original descriptors/source hash.

Retain120 rotated timing records: native paired four-token launches, original two
64-row staged launches, fused paired launch; ten samples x3 actual pair calls each.
Warmups/allocation/export/process/oracle excluded; every ratio finite and atomic
only after all numeric/bits/guards/source/model/CSV identity gates. Bounded/no-follow
ordered full CSV, explicit mode/pair metadata/actual SPANS12/SYNTHETIC144/complete
counts; exclusive failed JSON on malformed/source/hash/interrupt/full failure.
Legacy matrix checker/schema remains unchanged. Portable adversarial contracts and
opt-in native compile join existingCI. No Python production/provider fallback.

Finishsm75/sm89/original/header/master/normal/check before serial paired GPU capture
then pinned CPU dots. Preserve every source/binary/model/CSV/process/build failure
and after hashes; verify unchanged authenticated active normal prefill4. Document
measured win/rejection/manual/owners/TODO/ledger/roadmap/devlog, push/exactCI. Repeat
or actual-F32/full-model gates only if a shape earns speed. Production32/model/
generation/replay/control/context/device/concurrency/soak/provider remain separate.
