# Loader Domain: GGUFSeer & RuneWeaver

## Domain Overview
The `loader` domain manages disk file mapping and token translation.

- **`gguf.mojo` (GGUFSeer):** Zero-allocation GGUF binary format parser. Maps file weights directly into `MimirWell` memory via POSIX `mmap`.
- **`tokenizer.mojo` (RuneWeaver):** BPE tokenizer translating string prompts to token ID arrays and back.

## Key Invariants
- `GGUFSeer` must check magic bytes (`GGUF` = `0x46554747`) and handle `mmap` errors safely.
- No copy of model weight buffers during `mmap_and_load`.
