# AES500-132 GGUF metadata type baseline

## Scope

This baseline probes selected-key type mismatches in the current mapped-file
metadata parser. It does not claim general GGUF compatibility or model validity.
The exact executable corpus is `aesir_engine/tests/test_gguf_metadata_types.mojo`.

## Probes

Each generated file has a version-3 header, five metadata pairs, no tensors, and valid tokenizer token, score, and type
arrays. The architecture entry remains valid; each target field uses an
intentionally mismatched scalar encoding. The fixture test records whether
`inspect_metadata` succeeds, whether the mapped state remains owned, and whether
the relevant configuration default is unchanged.

Tested mismatches are `llama.context_length` as UInt64,
`llama.rope.freq_base` as UInt32, `tokenizer.ggml.add_bos_token` as UInt32, and
`general.alignment` as UInt64. All four currently skip the key using the encoded
width, preserve the default field value, and allow metadata inspection to
complete with the valid tokenizer fixture. This does not establish model
configuration readiness, tensor validity, or inference acceptance.

## Identity and reproduction

Source baseline revision: `932aa7ef0bbdc16f40c4068c46b0fcb6a7835bec`.
Mojo: `1.0.0 (ed45d567)`. Baseline source hash: `gguf.mojo`
`b1e3e41bbed0aa120f5f367f1f9975c114d6a07c8ab7b9b6e6605452c20d8347`; probe
hash: `test_gguf_metadata_types.mojo`
`6e08ff332024a0e3fe4ddb4b30c6f0b798b4abf649bae79b45453334100a2ac7`.
To reproduce the historical pre-change baseline, check out source revision
`cb60719df3dc30548fb3c73507d94ed4d8657f8b` and run the command below. The
current branch has moved the same fixture to the rejection contract in
AES500-134, so the baseline observations are historical and hash-bound.

```sh
pixi run mojo run --target-accelerator sm_89 -I aesir_engine aesir_engine/tests/test_gguf_metadata_types.mojo
```

The test generates and unlinks temporary files. Expected behavior and exact
observations are emitted by the test; no external model fixture is used.
