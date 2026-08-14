# Project Aesir: Repository Overview

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
    ├── model.gguf                     ← Development model weights fixture
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
Project Aesir uses Pixi for zero-dependency Mojo environment management.

```bash
cd ~/AntiGravity_Viking_Longhall/Project_Aesir/aesir_engine
export PATH="$HOME/.pixi/bin:$PATH"
```

### 2. Running the Test Suite
Execute all 8 verification unit tests:

```bash
pixi run mojo run tests/run_all.mojo
```

### 3. Compiling the Engine Binary
Build the native binary executable:

```bash
pixi run mojo build main.mojo -o aesir
```

### 4. Running the Engine Server
Start the bare-metal server on port 11434:

```bash
./aesir
```
