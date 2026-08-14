# Loader Domain: GGUFSeer & RuneWeaver

## Domain Overview
The `loader` domain manages disk file mapping and token translation.

- **`gguf.mojo` (GGUFSeer):** Bounds-oriented GGUF v3 Llama/F16 loader. Supported F16 tensors alias the POSIX `mmap`; required F32 normalization vectors are converted into `MimirWell`.
- **`tokenizer.mojo` (RuneWeaver):** BPE tokenizer translating string prompts to token ID arrays and back.
- **`huggingface.mojo`:** Local tag and URL helpers; downloading explicitly raises unsupported.
- **`onnx.mojo`:** Reserved descriptor; parsing and mapping return false.

## Key Invariants
- `GGUFSeer` must check magic bytes (`GGUF` = `0x46554747`) and handle `mmap` errors safely.
- No copy of model weight buffers during `mmap_and_load`.
