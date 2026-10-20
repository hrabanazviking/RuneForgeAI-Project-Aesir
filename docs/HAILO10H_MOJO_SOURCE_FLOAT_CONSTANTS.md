# Owned floating source constant windows

Date: 2026-10-19. Contract: `TASK_hailo10h_source_float_constants.md`.

## Implemented compiler boundary

`smidr/source_float_constants.mojo` reads bounded element windows from an open
PackedGGUF owner and returns copied source bindings plus owned IEEE binary32
bit patterns. The path wrapper closes its mapping before returning. Source
F32 words pass through unchanged; BF16 occupies the upper 16 bits of a binary32
word; F16 fields are expanded with integer sign/exponent/fraction operations.
The diagnostic inspector limits a window to 4096 elements as a host allocation
bound, not a hardware model limit. The borrowed-reader API requires its caller
to supply an explicit positive host window bound.

The reader checks a live mapping/fd, tensor existence/kind, positive checked
shape and byte products, exact source byte extent, and first/count/host-bound
arithmetic before allocating. A new loader `_read_u16` checks mapping state
and exact two-byte range without reading beyond a half-word file tail. No raw
file pointer escapes the loader or source window. Existing parser behavior is
unchanged. Unsupported packed kinds produce a named conversion gap; they are
not declared permanently ineligible for the Hailo target.

Signed zeros, finite normals, subnormals and infinities are represented exactly.
F16 NaN sign and ten fraction bits are placed into binary32, leaving lower
fraction bits zero; BF16 bits shift unchanged. This preserves the encoded
quiet/signaling bit and payload placement without floating evaluation or
quieting. F32 NaN payloads remain byte-exact. These are compiler representation
rules, not a claim about device NaN/subnormal behavior or numerical precision.

## Verification

Mojo 1.1.0 builds are warning-free:

```sh
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine smidr/tools/source_float_constants.mojo -o ../source-float-constants
MODULAR_CACHE_DIR=../mojo-cache mojo build -I . -I aesir_engine tests/hailo_source_float_api.mojo -o ../source-float-api
python3 tests/test_hailo_source_float_constants.py --binary ../source-float-constants --api-binary ../source-float-api --strace /usr/bin/strace --evidence docs/evidence/source-float-constants-2026-10-19
```

Six methods pass, **64 native calls: 40 accepted and 24 refused**. Every one of
65,536 F16 and 65,536 BF16 patterns is read through actual synthetic GGUF tensor
windows. F16 finite values use Python's independent IEEE half/float struct
conversion; BF16 finite values use a value-based ldexp/struct oracle. Infinity
and NaN field/classification/payload policy is checked explicitly, including
all 2046 F16 and 254 BF16 NaN encodings. F32 pass-through includes signed zero,
subnormals, infinities, signaling/quiet payloads and seeded arbitrary words.
No tensor arithmetic, model/layer forward or source-model weight evaluation is
performed; production performs representation decoding only.

Additional checks cover row-crossing and final single-half-word windows,
missing/out-of-range/over-budget windows, packed-kind refusal, truncated files,
closed mappings, invalid source shapes/extents, unsigned half-word boundaries
and arrays retained across mapping destruction. Source hashes are unchanged.
Evidence records reproducible source hashes, output/bitstream hashes, counts
and sample boundaries rather than repeating all exhaustive output integers.
The read-only syscall trace contains no Hailo node or CUDA/HailoRT library.

After the additive loader change, rebuilt source inventory six methods/16 calls
and rebuilt expanded-storage seven methods/88 calls pass again. These are
bounded regressions, not a full hosted CI claim. Evidence directory:
`docs/evidence/source-float-constants-2026-10-19/`.

## Remaining gates

The output explicitly says device_weight_format, source_fingerprint_verified
and execution_tested are false. This window is an observation of the current
mapping, not an immutable file identity guarantee for later reopening or
concurrent file mutation. Compiler graph binding/identity, quantized constants,
source permutation/layout, device packing/precision and numerical tolerance
remain required work. It allocates no Hailo memory and submits no program.
The next slice studies and independently implements packed quantized source
constant fields, starting incrementally with Q4_K; the broad model/format and
Hailo-only execution goal is unchanged.

## Format provenance

Original integer decoding, without external implementation study/copy or
runtime linkage. Public representation facts were checked in
[Python struct documentation](https://docs.python.org/3/library/struct.html)
and [Google's BF16 conversion documentation](https://docs.cloud.google.com/tpu/docs/bfloat16).
Only source-format facts are used; no accelerator-specific behavior is adopted.
GGUF type tags reuse the project's previously licensed/pinned format study.
