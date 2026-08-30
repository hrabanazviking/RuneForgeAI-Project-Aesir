# Loader Domain: GGUFSeer & RuneWeaver

## Domain Overview
The `loader` domain manages disk file mapping and token translation.

- **`gguf.mojo` (GGUFSeer):** Bounds-oriented GGUF v3 Llama/F16 loader for the CPU slice. Supported F16 tensors alias the POSIX `mmap`; required F32 normalization vectors are converted into `MimirWell`.
- **`packed_gguf.mojo`:** Bounded dense packed-GGUF ownership for the documented Gemma E4B and Llama 3 8B CUDA profiles.
- **`gemma4_tokenizer.mojo` / `llama3_tokenizer.mojo`:** Separate native model-driven BPE and explicit chat-control framing. Llama 3 uses generated Unicode categories and GPT-2 byte mapping; Gemma uses its own vocabulary/merge rules.
- **`tokenizer.mojo` (RuneWeaver):** BPE tokenizer translating string prompts to token ID arrays and back.
- **`huggingface.mojo`:** Validated public pinned-GGUF download through `pull`; system `curl` and `sha256sum` are explicit dependencies. Authentication, resume, upload, and store registration are unsupported.
- **`onnx.mojo`:** Reserved descriptor; parsing and mapping return false.

## Key Invariants
- `GGUFSeer` must check magic bytes (`GGUF` = `0x46554747`) and handle `mmap` errors safely.
- No copy of model weight buffers during `mmap_and_load`.
