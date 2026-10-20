# Native ordinary safetensors static constant windows

Date: 2026-10-20. Published contract:
`TASK_hailo10h_safetensors_constants.md`. Format and representation facts were
published before code; no external implementation is copied/translated.

## Actual connected behavior

`smidr/safetensors_constants.mojo` reads bounded raw source words and exact
binary32 representation words from the repaired existing source owner. The
borrowed-reader method requires a live mapped owner and fd; rechecks header,
local dtype, full shape/byte span and first/count/bound arithmetic before
allocating output or reading value bytes. Relative window arithmetic uses
subtraction checks; every actual two-/four-byte read also passes the owner's
mapped range guard. The last half word needs only two readable bytes.

The path wrapper supplies all five existing parser policies and closes the
source on success/error. Returned move-only `SafetensorsConstantWindow` owns
its full-rank source binding, source extent/data origin, requested first/count
and two word lists. Raw F16/BF16 words are zero-extended to UInt32; F32 retains
all32 source bits. Expanded F16/BF16 words reuse original Aesir integer bit
helpers. Signed zeros, subnormals, infinities and NaN sign/payload/signaling-bit
placement are retained without floating evaluation or quieting. No tensor-load
conversion method, model/layer/attention or device operation is called.

Scalar, empty and arbitrary-rank tensors retain their source axes. Flat
row-major windows may cross axes; first==element_count,count==0 is valid, and
an empty tensor permits first0,count0 with a positive explicit element bound.
The diagnostic's131072-word reporting cap is not a production/model limit.
The production routine uses the caller's explicit element bound.

## Verification

Final warning-free native diagnostic/API builds, **nine methods/97 native
calls pass (77 accepted,20 refused)** with264204 exact raw/expanded word checks.
Both65536-pattern F16/BF16 spaces are exhaustively checked against the existing
independent Python value/representation oracle; F32 special/payload words and
496 seeded random patterns retain all bits. The format reader regression also
passes all eleven methods/219 calls, including its five legacy header-only
calls. No external model/format runtime is linked by the constant reader.

Other cases cover full-rank row-major subwindows/tails, the final two bytes,
scalars/empty shapes, Unicode/embedded-NUL names, zero-length windows, exact/
insufficient/zero bounds, signed Int64 extremes and parser policy refusal.
Eighteen direct API processes prove owned data/shapes after close and17 expected
API refusals for closed/stale owner fields, missing names, modified dtype/shape/
span and invalid windows/bounds. Those17 processes exit successfully because
the expected API error was observed; they do not represent accepted bad data.

Positive and refused-window syscall traces show read-only/nonblocking file
admission, read-only private mapping, close/unmap on the refused path, no
source mutation, ioctl, device, HailoRT/CUDA/ggml/Torch or external format runtime.
Source/binary hashes and all runs are in
`docs/evidence/safetensors-constants-2026-10-20/`.
The first production build needed explicit Int/Int64 comparison casts; the
first API-checker build used a reserved identifier. Both failed build logs and
the earlier passing run before the extra error-cleanup trace are preserved.

Reproduce from the repository root with installed strace supplied explicitly:

```sh
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine smidr/tools/safetensors_constants.mojo -o ../safetensors-constants
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine tests/hailo_safetensors_constants_api.mojo -o ../safetensors-constants-api
python3 tests/test_hailo_safetensors_constants.py --binary ../safetensors-constants --api ../safetensors-constants-api --strace "$AESIR_STRACE" --evidence ../safetensors-constants-recheck
```

## Remaining execution work

Source IDs0F16/1BF16/2F32 remain distinct from GGUF IDs. This representation
reader does not establish immutable backing-file identity against concurrent
mutation, dtype/quantized/sharded/config/architecture coverage, operation
semantics, device precision/layout/packing, physical placement, numerical CCWs,
upload/activation or hardware execution. Source-format breadth must continue;
these three initial dtypes are not a permanent model eligibility list.

Next: separate source format/configuration from the mathematical importer under
`TASK_hailo10h_source_neutral_semantics.md`, retaining source format/dtype/name/
shape/span provenance and existing GGUF regression. Continue actual numerical
encoding/configuration/transport gaps alongside that frontend connection. The
owner's fixed broad ordinary-model target remains; no outside compiler, special
user artifact/conversion, CPU/CUDA/cloud LLM forward or proxy is introduced.
