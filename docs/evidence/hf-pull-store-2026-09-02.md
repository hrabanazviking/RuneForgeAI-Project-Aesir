# Pinned Hugging Face Pull-to-Store Evidence — 2026-09-02

The built native CLI passed the opt-in live harness against a small public GGUF
from [`shibatch/tiny1m`](https://huggingface.co/shibatch/tiny1m). The fixture
identity was read from the Hugging Face model API and pinned before execution:

- revision: `dac47035fa06aa22cd694b67b8b744fd24e56ec3`
- file: `tiny1m.Q4_K_S.gguf`
- bytes: `689216`
- SHA-256: `1c960d5e9f01bfb42cca6285ff2739cdbef440942e63b95dae554d7612a50c6a`

```bash
python3 scripts/test_hf_download.py \
  --aesir .aesir/aesir-pull-store \
  --repo shibatch/tiny1m \
  --file tiny1m.Q4_K_S.gguf \
  --revision dac47035fa06aa22cd694b67b8b744fd24e56ec3 \
  --sha256 1c960d5e9f01bfb42cca6285ff2739cdbef440942e63b95dae554d7612a50c6a \
  --size 689216
```

Result: **7 passed, 0 failed**. The harness proved pinned HTTPS download and an
independent Python digest/size oracle, literal argv handling, preservation of an
existing destination, checksum rejection, size rejection, HTTP failure,
symlink-target preservation, `pull --name` registration, restart catalog
lookup, full stored-blob verification, exact byte equality, and owner-read-only
mode on a native Linux filesystem.

This establishes one public pinned GGUF pull-to-store transaction on Linux/WSL.
It does not establish authentication, resumable transfer, arbitrary model
compatibility, garbage collection, or portability.
