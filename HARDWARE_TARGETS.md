# Hardware targets and observed support

> **Status boundary — 2026-08-30:** This file records ambitions and planning
> constraints, not a hardware support matrix. The only physical accelerator
> inference evidence is dense text-only Gemma 4 E4B Q4_K_M on the observed RTX
> 4070 Laptop GPU under WSL2. CUDA support is not universal GPU support. CPU
> GGUF Llama F16 is separately verified. See [docs/CURRENT_STATUS.md](docs/CURRENT_STATUS.md)
> and the [capability ledger](CAPABILITY_LEDGER.md) before relying on a target.

The project aims to broaden local hardware support over time. No claim of
operating-system, vendor, accelerator, multi-device, NPU, or general model
agnosticism is currently justified.
