# Project Aesir: Repository Overview

> **Current-runtime note (2026-08-30):** This directory map preserves earlier
> names and planned modules. For what can be run now, begin with
> [CURRENT_STATUS.md](CURRENT_STATUS.md) and [GEMMA4_CUDA.md](GEMMA4_CUDA.md).
> The source tree has grown beyond the illustrative map below; it must not be
> used as evidence that listed server, multi-engine, or accelerator features
> are operational.

> *"Know the whole terrain before laying down the first stone."*  
> — **Védis Eikleið, The Cartographer**

---

## 📁 Repository Directory Structure

```
Project_Aesir/
├── README.md                          ← Primary project landing page
├── MYTHIC_ENGINEERING.md              ← Working protocol & role-based methodology
├── TODO.md                            ← Living roadmap & task tracker
├── ARCHITECTURE.md                    ← Root architecture map
├── DATA_FLOW.md                       ← Root data flow sequence diagram
├── DEVLOG.md                          ← Development log & audit history
├── docs/                              ← Architecture & Philosophy Domain
│   ├── PHILOSOPHY.md                  ← Skald: Mythic philosophy & 5 pillars
│   ├── SYSTEM_VISION.md               ← Skald: Roadmap & performance targets
│   ├── DOMAIN_MAP.md                  ← Architect: Domain boundaries & design laws
│   ├── ARCHITECTURE.md                ← Architect: Complete technical architecture
│   ├── DATA_FLOW.md                   ← Cartographer: Request sequence & flow
│   ├── REPO_OVERVIEW.md               ← Cartographer: Repository structure & navigation
│   ├── DECISIONS/                     ← Architecture Decision Records (ADRs)
│   │   ├── 0001-bare-metal-mojo.md
│   │   ├── 0002-zero-allocation-mimirwell.md
│   │   └── 0003-bifrost-socket-decoupling.md
│   └── bugs/                          ← Bug audit reports
│       ├── 0001-mimirwell-dynamic-alloc.md
│       ├── 0002-ggufseer-mmap-leak.md
│       └── 0003-bifrost-string-lifetime.md
└── aesir_engine/                      ← Source Code Realm
    ├── pixi.toml / pixi.lock           ← Pixi environment configuration
    ├── main.mojo                      ← Entry point binary runner
    ├── aesir.mojo                     ← AesirEngine facade orchestrator
    ├── model.gguf                     ← Invalid 24-byte legacy placeholder; not evidence
    ├── core/                          ← Compute & Memory Domain
    │   ├── README.md                  ← Core domain documentation
    │   ├── INTERFACE.md               ← Core public API specification
    │   ├── mimir_well.mojo            ← MimirWell memory pool & RuneTensor
    │   └── compute.mojo               ← Nidavellir SIMD compute kernels
    ├── loader/                        ← Weights & Tokenization Domain
    │   ├── README.md                  ← Loader domain documentation
    │   ├── INTERFACE.md               ← Loader public API specification
    │   ├── gguf.mojo                  ← GGUFSeer mmap weight parser
    │   └── tokenizer.mojo             ← RuneWeaver BPE tokenizer
    ├── server/                        ← Transport Domain
    │   ├── README.md                   subterranean Server documentation
    │   ├── INTERFACE.md               ← Server public API specification
    │   └── api.mojo                   ← BifrostGate POSIX HTTP server
    └── tests/                         ← Verification Domain
        ├── README.md                  ← Testing domain documentation
        ├── INTERFACE.md               ← Testing suite specification
        ├── run_all.mojo               ← Master test orchestrator
        ├── test_compute.mojo          ← Compute kernel unit tests
        ├── test_gguf.mojo             ← GGUFSeer & GGMLType unit tests
        └── test_tokenizer.mojo        ← RuneWeaver unit tests
```

---

## 🛠️ Build & Execution Quick Guide

### 1. Environment Setup
Project Aesir uses Pixi for its locked Mojo/MAX environment. Run commands from
the repository root; the CUDA workflow and its dependencies are documented in
[GEMMA4_CUDA.md](GEMMA4_CUDA.md).

```bash
pixi install --locked
```

### 2. Running the Test Suite
Execute the counted verification suite:

```bash
pixi run mojo run aesir_engine/tests/run_all.mojo
```

### 3. Compiling the Engine Binary
Build the native binary executable:

```bash
pixi run mojo build -I aesir_engine aesir_engine/main.mojo -o .aesir/aesir
```

### 4. Running a supported model

The only documented native CUDA model profile is Gemma 4 E4B Q4_K_M. Follow the
download and chat command in [GEMMA4_CUDA.md](GEMMA4_CUDA.md). The server
modules are not a supported inference service.

```bash
.aesir/aesir chat <model.gguf> --accel cuda --max-tokens 16384 --context 32768
```
