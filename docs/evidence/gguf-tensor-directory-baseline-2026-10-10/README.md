# AES500-142 GGUF tensor directory baseline

A generated version-3 mapped GGUF contains five valid metadata entries, one
rank-one `fixture.weight` F16 directory record, aligned data offset, and one
F16 value. `mmap_and_load` maps the 1x1 tensor, then rejects the deliberately
incomplete model because required inference tensors are absent. The test checks
the mapped tensor descriptor survives cleanup for inspection, while the loader
ends FAILED and unmapped. This captures directory traversal and basic F16
mapping only; it does not establish full model validity, compressed layouts,
overlap handling, or general dimension arithmetic safety.

Baseline source revision: `c247d5ad4990bf3468ab0343a5d680fda68f4c3a`.
Mojo: `1.0.0 (ed45d567)`. `gguf.mojo` SHA-256:
`ec1de27aa9faaa3c4063ca710e75f26f305c5eacf0ef86e3a207c45d2e90832c`.
Probe file SHA-256:
`09d22ddc5a2e605d4d06efe578890e41fd7ed9296348c4060d46725e78e57c57`.

Reproduce the historical baseline at the cited source revision with:

```sh
pixi run mojo run --target-accelerator sm_89 -I aesir_engine aesir_engine/tests/test_gguf_metadata_types.mojo
```

The test creates and unlinks its temporary file; it uses no external model.
