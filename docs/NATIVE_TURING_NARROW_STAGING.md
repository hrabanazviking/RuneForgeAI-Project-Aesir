# Isolated16-column shared staging

Use this primitive probe to test a resource/speed hypothesis suggested by the
[owned strategy3 projection/resource trace](NATIVE_TURING_DOWN_PROJECTION_TRACE.md).
The actual updated FFN gate/up/down account for51.9283% of long summed GPU kernel
duration. Recorded255 registers per thread is an observation, not a bottleneck
cause or an occupancy diagnosis. No production dispatch selects this candidate.

## Kernel and ownership

The optional core module appends narrow_turing_kernel/project_turing_narrow while
preserving every previous kernel/wrapper verbatim. Precision0, original packed
Q4/Q5/Q6, rows64/128 and batches4/8/16/32 are explicit compile-time constraints.
Each32-value packed group is consumed as two16-column halves. Only16 decoding
lanes write shared cells; all32 lanes still execute original public MMA and both
barriers. Input/weight half selection binds chronological columns, including Q6
scale half lanes. Every active/padded row/token cell is initialized before reads.
High/residual F16 conversions and sequential F32 accumulation order remain.
Rows64/128 use128/256 threads. Defined padded shared arrays at batch32 require
5440/9792 bytes, compared with original10560/19008. Extra barriers/half-lane stores
could offset lower storage; lower bytes do not prove speed or lower register use.
No extra global workspace, model mutation or production import is introduced.

The shared primitive harness adds final narrow_rows=0, exclusive with cached
headers/large rows/un-staged Turing selection. Legacy omissions stay identical.
The new native collector admits rows64/128 before model load and prints explicit
MODE,turing_mma_staged_narrow_f16_f32,rows,16. Shared evidence parser admits only
that geometry with complete three-owner F32 bytes and original timing rotation.
The original comparison owner is rows64/columns32, including for candidate128.
A cross-capture comparison against older128/32 results is not a valid new score.

## Build, execute, validate

Finish all edits/build/master/check gates first; serialize all GPU captures before
pinned independent CPU oracles. Keep an unchanged registered service running and
verify memory headroom. Use original packed source bytes, never private corpus or
keys as evidence. The probe directly owns one separate CUDA context/session.

```sh
pixi run --frozen --no-install --offline mojo build -I aesir_engine \
  --target-accelerator sm_75 aesir_engine/tests/test_turing_narrow_staging.mojo \
  -o "$ARTIFACTS/aesir-turing-narrow-staging"
"$ARTIFACTS/aesir-turing-narrow-staging" "$MODEL" 64 > "$ARTIFACTS/rows64.csv"
"$ARTIFACTS/aesir-turing-narrow-staging" "$MODEL" 128 > "$ARTIFACTS/rows128.csv"
"$ORACLE_PYTHON" scripts/check_packed_matrix.py "$ARTIFACTS/rows64.csv" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA" --output "$ARTIFACTS/rows64.json"
"$ORACLE_PYTHON" scripts/check_packed_matrix.py "$ARTIFACTS/rows128.csv" \
  --model "$MODEL" --model-sha256 "$MODEL_SHA" --output "$ARTIFACTS/rows128.json"
```

Shell redirection itself can overwrite paths; use a new private directory and
exclusive supervised creation for real acceptance. JSON checker always uses
exclusive creation. Both target builds, original/header probes, master and normal
build/check must precede physical work. Unsupported rows256 with a nonexistent
model path refuses before model/CUDA. Retain binary/source/model/CSV hashes,
complete stderr, UTC process receipts and every failed attempt. Python inference
is forbidden in this primitive path; pinned gguf0.19.0/NumPy2.4.4 independently
decode original weights and compute selected Float64 dots only as a test oracle.

Each configuration requires144 synthetic format/tail cases,12 span refusals,
all1658880 real outputs per native/candidate/original owner,2100 selected dots and
all1622640 guards. Candidate/original actual UInt32 F32 bits (signed zero included)
must match, and unchanged .002 scaled/.0002 normalized RMS gates apply to all
owners. All840 timings retain ten rotated samples of three actual launches plus
synchronization per owner/case. Warmed allocation/export/oracle/process durations
are excluded from primitive scores. original_to_candidate_ratio above1 means
lower elapsed than the original64 owner, and below1 means slower. All complete
numerical/hash failures and interruptions withhold every ratio. Never rank only a
favorable subset or replace a rejected result. Hosted CI tests19 portable evidence
contracts and compiles the probe; physical gates are separate.

Read the evidence for measured outcome. A passing primitive kernel cannot certify
actual F32 full-model inputs, complete model/decode/replay/control quality, broader
context/device/concurrency/soak, production32 or refreshed Ollama speed lead.
