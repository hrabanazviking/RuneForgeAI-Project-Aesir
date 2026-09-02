# Dependency manifest

The native Gemma 4 path uses the repository's locked Mojo 1.0.0 / MAX 26.5.0
environment (`pixi.lock`). MAX owns CUDA contexts, buffers and launches; all
model operations and tokenization are Mojo code. NVIDIA's system driver is a
prerequisite. No external inference engine or Python runtime is used for chat.

The loader uses Linux libc file mapping and bounded process/file operations.
Hugging Face transfers use the system `curl` (HTTPS certificate verification,
redirect restrictions, optional parallel ranges) and `sha256sum` (GNU coreutils).
Content-addressed model-store import and verification also use `sha256sum`,
reading the exact inherited open descriptor through Linux procfs.
Model-store `gc` uses GNU `find` (findutils) over an inherited procfs directory
descriptor with NUL-delimited output; it never interpolates a shell command.
These are separate executables invoked with argv, never a shell command string.
They are justified because this toolchain has no maintained native HTTPS client;
argv-only process execution is isolated in the loader and
`core/posix_process.mojo`. Curl must support `--parallel`
for `--connections > 1` (curl 7.66+). No executable is vendored.

Test-only tools: Python standard library for orchestration, `tokenizers 0.22.2`
for independently generated tokenizer fixtures, and `gguf 0.19.0` with NumPy
for independent real-weight dequantization/matvec expectations. These are never
imported by production Mojo. See `THIRD_PARTY_NOTICES.md` for the pinned MIT
architecture/quantization reference. Public model weights are external artifacts
under their model license, pinned in the task contract and `GEMMA4_CUDA.md`.
