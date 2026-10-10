# AES500-152 byte BPE merge baseline

The generated in-memory vectors establish:

- Equal scores for `ab` and `bc` over `abc` select the leftmost pair, producing
  token IDs `[4, 3]`.
- A higher score for `bc` over `ab` selects the right pair first, producing
  `[1, 5]` when no final `abc` token exists.
- Repeated merges of `ab` and then `abc` converge to token ID `[6]`.
- The UTF-8 bytes for 😀 map through `<0xF0>`, `<0x9F>`, `<0x98>`, `<0x80>` to
  IDs `[11, 12, 13, 14]`.

Baseline source revision: `0896a0c5c50400da84f594e95940303b591d3fa9`.
Mojo: `1.0.0 (ed45d567)`. `tokenizer.mojo` SHA-256:
`c26583a88237665bda6aa161093fdc7aac69e2b1ddfb54444f24e789149a96df`.
The test is `aesir_engine/tests/test_tokenizer.mojo`; its pre-change SHA-256 is
`24c05c73044c1cc6a8bbd2a0afa48d5a0a4d518ccec011a2245bcca9a49ef783`.

The sm_89 master suite passes 218 named cases, zero fail, one external-fixture
skip (219 total). These are deterministic synthetic vectors and do not prove
external tokenizer parity or model-level text fidelity.
