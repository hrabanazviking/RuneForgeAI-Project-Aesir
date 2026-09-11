# PROJECT AESIR ROUND 2
## Model Adoption + Usability Sprint

**Goal:** Turn Project Aesir from a runtime that supports a few verified models into a **model-flexible local AI platform** that can inspect, recognize, configure, download, run, and serve a broad range of GGUF models with minimal user intervention.

The guiding rule for this round:

> **Stop adding individual models. Start adding model families and capabilities.**

Do not duplicate entire inference engines for every new model. Generalize common transformer machinery, then use small architecture-specific profiles/adapters for the pieces that genuinely differ.

---

## 1. Build the Aesir Model Compatibility Registry

Create a central registry conceptually like:

```text
ModelArchitectureRegistry
```

Each architecture adapter should describe:

```text
architecture
family
model_variant
tokenizer_family
chat_template
attention_type
rope_type
activation
normalization
moe_or_dense
tensor_naming
supported_quantizations
context_limit
cuda_support
cpu_support
capability_flags
```

Aesir should inspect GGUF metadata and answer:

```text
Architecture: qwen3
Variant: 4B
Quantization: Q4_K_M
Tokenizer: Qwen BPE
Context available: 32768
Backend: CUDA supported
Chat template: detected
Status: READY
```

instead of requiring the user to already know what profile to select.

The eventual ideal command is simply:

```bash
aesir run model.gguf
```

Aesir figures out the rest.

---

## 2. Replace Hardcoded Architecture Constants With Profiles

Round 1 begins this for Gemma E2B/E4B.

Round 2 should push that pattern across the runtime.

Common engine components should accept model profile parameters instead of constants such as:

```text
layer count
hidden dimension
FFN dimension
head count
KV head count
head dimension
vocab size
RoPE dimensions
context length
sliding window
attention schedule
norm epsilon
```

Keep architecture-specific validators strict.

This gives you:

```text
Generic transformer machinery
           ↓
Architecture adapter
           ↓
Variant profile
           ↓
Actual GGUF metadata validation
```

That is enormously more scalable than:

```text
gemma4_e2b_engine
gemma4_e4b_engine
qwen4b_engine
qwen8b_engine
llama8b_engine
...
```

No engine hydra.

---

## 3. Prioritize Model Families That Matter in Real Local AI

Attack families roughly in this order.

### Tier A: Core targets

```text
Gemma 4
Llama 3.x
Qwen family
Mistral family
```

Aesir already has Gemma 4 and Llama 3 footholds.

**Qwen should be especially high priority** because it gives Aesir access to an enormous ecosystem of general-purpose, coding, reasoning, roleplay, and fine-tuned models.

### Tier B

```text
Phi
DeepSeek-derived dense GGUF models
Yi-family derivatives
Nemotron/Llama-derived variants
```

### Tier C

```text
MoE architectures
specialized multimodal architectures
unusual experimental architectures
```

MoE should come after dense models are boringly reliable.

---

## 4. Build a General Quantization Compatibility Layer

This may unlock more models than architecture work.

Instead of saying:

```text
Aesir supports Q4_K_M Gemma.
```

move toward:

```text
Aesir supports these tensor formats:
Q4_0
Q4_1
Q4_K_S
Q4_K_M
Q5_K_S
Q5_K_M
Q6_K
Q8_0
F16
BF16
```

Then architecture adapters request tensor operations without caring about how the weights are packed.

Conceptually:

```text
Transformer Layer
      ↓
Tensor Operation
      ↓
Quantization Dispatcher
      ↓
Q4_K / Q5_K / Q6_K / Q8 / BF16 kernel
```

Existing quantization work gives Aesir a head start here.

### Highest-value initial target

Get the entire common **K-quant family** operating consistently first.

That covers a huge amount of the current GGUF ecosystem.

---

## 5. Automatic Chat Template Detection

Aesir should stop making users understand chat-template archaeology.

Inspect:

```text
tokenizer.chat_template
general.architecture
tokenizer metadata
special token IDs
```

Then automatically select:

```text
Gemma
Llama 3
ChatML
Qwen
Mistral
etc.
```

Add:

```bash
aesir inspect model.gguf
```

which reports something like:

```text
Aesir Model Inspection

Name: RuneForge-Qwen
Architecture: qwen
Parameters: 4.0B
Quantization: Q4_K_M
Context: 32768
Tokenizer: Qwen
Chat Template: ChatML-compatible
CUDA: supported
CPU: supported
Recommended context: 16384
Estimated VRAM: 3.4 GiB

READY
```

That command alone would make debugging model compatibility dramatically easier.

---

## 6. Make Model Installation Ridiculously Easy

Target UX:

```bash
aesir pull owner/model
```

or:

```bash
aesir pull owner/model --quant Q4_K_M
```

Aesir should:

```text
query repository
find GGUF files
rank compatible quantizations
show sizes
download
resume if interrupted
verify
register model
inspect architecture
choose recommended defaults
```

Interactive version:

```text
Choose quantization:

1. Q4_K_M   3.4 GB   Recommended
2. Q5_K_M   4.1 GB   Higher quality
3. Q6_K     4.8 GB   High quality
4. Q8_0     6.2 GB   Very high quality
```

For nomadic and unreliable connections, **resume support matters a lot**.

If Starlink, cellular, or public Wi-Fi drops at 73%, Aesir should resume at 73%, not start over.

---

## 7. Build a Proper Model Selector Into the TUI

Startup could become:

```text
┌──────────────── PROJECT A.E.S.I.R. ────────────────┐
│                                                    │
│  Models                                            │
│                                                    │
│  > Gemma-4-E2B        Q4_K_M   3.4 GB   CUDA ✓    │
│    Stheno-v3.2        Q4_K_S   4.7 GB   CUDA ✓    │
│    Norse-Qwen-3B      Q4_K_M   2.1 GB   CUDA ✓    │
│                                                    │
│  [Enter] Chat                                      │
│  [I] Inspect                                       │
│  [P] Pull model                                    │
│  [S] Settings                                      │
│                                                    │
└────────────────────────────────────────────────────┘
```

Users should not need to type model paths during normal use.

---

## 8. Make Defaults Intelligent

Instead of forcing:

```bash
--context
--device
--reserve-mib
--profile
--max-tokens
```

every time, let Aesir determine sane defaults.

For example:

```text
model supports: 131072
machine comfortably supports: 32768
user preference: 16384

Aesir selects: 16384
```

Likewise:

```text
GPU 0: RTX 4070 8GB
GPU free: 7.1GB
model: 3.4GB
KV estimate: 1.2GB
workspace: 0.5GB

Selected CUDA:0
```

Still allow explicit overrides.

The goal is powerful software that does not make the user act as its unpaid systems administrator.

---

## 9. Create Compatibility Levels

Do not use only:

```text
supported / unsupported
```

Use:

```text
VERIFIED
COMPATIBLE
EXPERIMENTAL
UNSUPPORTED
```

For example:

```text
Gemma 4 E2B Q4_K_M
VERIFIED

Qwen3 4B Q4_K_M
COMPATIBLE

Mistral variant XYZ
EXPERIMENTAL

Unknown architecture
UNSUPPORTED
```

This allows Aesir to be ambitious without pretending every model has received the same level of testing.

---

## 10. Make Ollama Compatibility Feel Native

Round 1 gets the essential API working.

Round 2 should make it boringly compatible.

Target:

```text
/api/version
/api/tags
/api/show
/api/generate
/api/chat
/api/ps
/api/pull
/api/create
/api/delete
/api/copy
/api/embed
```

Implement incrementally.

Most importantly, programs expecting Ollama should be able to point at:

```text
http://127.0.0.1:11434
```

and simply work.

Conceptually:

```text
Application
    ↓
"Hello Ollama"
    ↓
Aesir responds
    ↓
native Mojo inference
```

---

## 11. Finish OpenAI Compatibility

Make this equally first-class:

```text
GET  /v1/models
POST /v1/chat/completions
POST /v1/completions
POST /v1/embeddings
```

Then Aesir becomes usable by software supporting either:

- **Ollama API**
- **OpenAI API**

which covers a huge portion of the local-AI ecosystem.

---

## 12. Friendly Errors Instead of Engine Gobbledygook

Bad:

```text
Unsupported tensor dimension at layer 17.
```

Better:

```text
Aesir cannot run this model yet.

Architecture: Qwen3
Quantization: Q4_K_M

Reason:
Qwen3 attention is recognized, but this build does not yet
support its required RoPE configuration.

Try:
aesir inspect model.gguf

Compatibility:
EXPERIMENTAL
```

This becomes increasingly important once people outside the project start using Aesir.

---

## 13. Add `aesir doctor`

```bash
aesir doctor
```

Reports:

```text
Project Aesir Diagnostic

Mojo runtime           ✓
CUDA                   ✓
GPU                    RTX 4070 Laptop
VRAM                   8 GB
Free VRAM              6.8 GB
Model store            ✓
Disk space             2.7 TB
Ollama API             listening :11434
OpenAI API             listening :11434
Model catalog          7 models
Broken models          0
Network                available

SYSTEM READY
```

And:

```bash
aesir doctor model.gguf
```

performs model-specific diagnosis.

---

## 14. Add Model Aliases and Favorites

Instead of:

```text
gemma-4-E2B-it-Q4_K_M.gguf
```

allow:

```text
gemma
```

or:

```text
runa
```

or:

```text
stheno
```

Commands:

```bash
aesir alias gemma gemma4-e2b:latest
aesir favorite gemma
```

Then:

```bash
aesir chat gemma
```

**Implemented 2026-09-11:** aliases and favorites persist in a checksummed
metadata layer separate from model manifests and blobs. `gemma` now resolves to
the installed `gemma4-e2b:latest` catalog model, favorites are visibly marked
and ordered first in path-free selection, and list/remove commands are included.

---

## 15. Persist User Settings

For example:

```text
~/.config/aesir/config.toml
```

Remember:

```text
default model
preferred context
preferred CUDA device
temperature
top_p
top_k
system prompt
API port
TUI preference
download directory
model storage directory
```

Then normal invocation becomes simply:

```bash
aesir
```

and the user's environment appears.

---

## 16. Conversation Save/Load

For standalone chat:

```text
/save
/load
/new
/export
```

Persist conversations locally.

Potential location:

```text
~/.local/share/aesir/chats/
```

This is also the natural bridge toward Muninn later.

Keep memory intelligence out of this sprint.

First make conversation persistence reliable.

---

## 17. Model Hot Switching

Eventually:

```text
/model gemma
```

inside the TUI.

Aesir unloads one model and loads another without exiting the application.

This gives it more of an LM Studio-style experience while staying terminal-native and lightweight.

**Implemented 2026-09-11:** `/model <name-or-alias-or-path>` validates the next
native CUDA model before releasing the current session, preserves the same PID,
terminal and user settings through a fresh CUDA runtime image, and starts a new
model-specific conversation without overlapping GPU allocations. Physical
Gemma → Qwen → Gemma switching passed in one chat task.

---

## 18. Performance Auto-Profiling

On first run of a model:

```text
Benchmarking optimal kernel configuration...
```

A short calibration can determine:

```text
best workgroup size
best quantized GEMM kernel
preferred batch size
prefill configuration
KV strategy
```

Cache the result by:

```text
GPU + model architecture + quantization
```

Existing quantization autotuning work can naturally extend into this.

---

## 19. Model Compatibility Test Harness

Create something like:

```text
models/compatibility_manifest.json
```

or equivalent with entries such as:

```text
model
architecture
quantization
expected tokenizer output
expected first tokens
context test
backend
status
```

Then eventually:

```bash
aesir compatibility test ./models
```

could test a directory of GGUFs automatically.

This prevents unsupported assumptions like:

> "It worked on one Qwen file three months ago, therefore the README says Qwen supported."

Compatibility claims should be backed by repeatable verification.

---

# Round 2 Strict Priority

Use this hierarchy:

```text
1. Architecture/profile registry
2. Generalize Gemma/Llama model profile machinery
3. Qwen-family support
4. Broaden K-quant support
5. Automatic chat-template/tokenizer selection
6. aesir inspect
7. model-name resolution everywhere
8. polished TUI model selector
9. intelligent defaults
10. Ollama compatibility completion
11. OpenAI compatibility completion
12. resumable model downloading
13. aesir doctor
14. conversation persistence
15. aliases/favorites
16. model hot switching
```

Qwen should be the model-family target immediately after the abstraction work because it offers extremely high practical payoff across general-purpose, coding, reasoning, roleplay, and fine-tuned local models.

---

# Round 2 End State

The victory condition is no longer:

> Aesir can run Gemma E2B.

It becomes:

> **Give Aesir a normal compatible GGUF, and Aesir usually figures out what it is, tells you whether it can run it, chooses sensible settings, lets you chat with it immediately, and exposes it to existing applications through familiar APIs.**

At that point, Project Aesir starts feeling less like an inference-engine research project and more like a **real local-AI operating environment**.

---

# Non-Goals for Round 2

Unless all higher-priority items are already complete and verified, do **not** let this sprint sprawl into:

- full multimodal vision/audio inference
- distributed multi-node inference
- cloud-hosted model routing
- speculative decoding
- multi-GPU inference
- AMD/ROCm backend
- NPU backend
- agent framework
- Muninn cognitive memory
- full Runa integration
- tool/function calling
- model training or fine-tuning
- elaborate graphical desktop UI

Those belong to later rounds.

Round 2 is about making **local model use broad, smooth, discoverable, and pleasant**.

---

# Verification Gates

Before declaring Round 2 complete, verify:

```text
[x] Existing verified Gemma 4 E4B support still passes
[x] Gemma 4 E2B support still passes
[x] Existing Llama 3 support still passes
[x] At least one Qwen-family model runs successfully
[x] Multiple supported K-quants load and generate correctly
[x] GGUF architecture detection works
[x] Chat template selection works automatically
[x] aesir inspect gives useful diagnostics
[x] Friendly unsupported-model errors work
[x] TUI model selection works without typing file paths
[x] Ollama-compatible clients can discover and chat with models
[x] OpenAI-compatible clients can discover and chat with models
[x] Downloads can resume after interruption
[x] aesir doctor reports useful system/model state
[x] Existing tests remain green
[x] New compatibility tests are added for every newly claimed family
```

---

# Commit Discipline

Keep commits narrow and understandable.

Suggested sequence:

```text
feat(models): add architecture compatibility registry
refactor(gemma): move variant constants into profiles
refactor(llama): move model constants into profiles
feat(qwen): add initial dense GGUF support
feat(quant): broaden K-quant dispatcher
feat(models): add automatic chat-template detection
feat(cli): add aesir inspect
feat(tui): add model selector and intelligent defaults
feat(api): expand Ollama compatibility
feat(api): complete OpenAI chat compatibility
feat(pull): add resumable downloads
feat(cli): add aesir doctor
feat(chat): add conversation persistence
feat(models): add aliases and favorites
feat(tui): add model hot switching
test(models): add compatibility manifest and verification harness
docs: document supported model families and compatibility levels
```

Avoid giant all-in-one commits unless there is no practical alternative.

---

# Guiding Principle

> **Aesir should make powerful local AI feel simple without making the engine simplistic.**

The complexity belongs inside the forge.

The user should mostly see:

```bash
aesir
```

and get to work.
