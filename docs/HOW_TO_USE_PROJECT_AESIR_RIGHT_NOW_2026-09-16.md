# How to Use Project A.E.S.I.R. Right Now

**Easy practical guide**  
**Current as of September 16, 2026**

> **Why this guide has a date:** A.E.S.I.R. is changing rapidly. Commands, supported models, setup requirements, and compatibility features are likely to change. Treat this as a September 16, 2026 snapshot and check newer repository documentation when available.

## Who is this guide for?

This guide is for someone who understands basic computer tasks and can paste commands into a terminal, but does not necessarily understand AI inference engineering, CUDA kernels, GGUF internals, Mojo, or model architecture.

A.E.S.I.R. is still experimental developer software. It is becoming easier to use, but this is not yet a one-click consumer application.

---

# 1. What can I realistically do with A.E.S.I.R. today?

On a currently supported setup you can:

- build the native A.E.S.I.R. program
- launch its terminal Home screen
- inspect your local model catalog
- import GGUF model files into A.E.S.I.R.'s protected model store
- verify stored model files
- give models shorter aliases and favorites
- inspect GGUF information
- inspect hardware and memory-fit information
- run diagnostics with `aesir doctor`
- chat interactively with supported native CUDA models
- run a local authenticated A.E.S.I.R. HTTP service
- run the early Ollama-compatible local service
- experiment with applications that only require the currently implemented Ollama/OpenAI-compatible text surface

You should **not** expect arbitrary GGUF files, every GPU vendor, every Ollama client feature, embeddings, vision, tools, or Internet-facing serving to work yet.

---

# 2. The easiest currently documented environment

The current practical environment is:

```text
Linux x86-64
or
Windows 11 → WSL2 → Linux A.E.S.I.R.

plus

NVIDIA GPU + working NVIDIA/WSL CUDA support
```

The repository's exercised CUDA development target is NVIDIA Ada `sm_89`. Compilation for another target does not by itself prove that target physically works.

You also need the repository's already prepared/installed development environment, including Python 3, Pixi, the locked Mojo environment, required system libraries, and an NVIDIA driver appropriate to your setup.

A.E.S.I.R.'s inference runtime itself is native Mojo. Python in the launch workflow is launch/build plumbing, not the code secretly performing model inference.

---

# 3. Start from the repository checkout

Open a terminal in your local A.E.S.I.R. repository checkout.

For Windows, use the WSL distribution in which you prepared the A.E.S.I.R. environment. Keep the checkout and prepared environment on local storage appropriate to the documented setup.

---

# 4. Build a fresh local executable

On Linux or inside WSL:

```bash
python3 scripts/launch.py --build
```

Then verify that the prepared build still matches the checkout:

```bash
python3 scripts/launch.py --check
```

A normal launch deliberately does not rebuild or download dependencies behind your back. If source files changed, rebuild explicitly.

---

# 5. Open A.E.S.I.R. Home

The simplest current entry point is:

```bash
python3 scripts/launch.py
```

You can also request Home explicitly:

```bash
python3 scripts/launch.py -- home --model-store .aesir/models
```

The native command underneath is:

```bash
aesir home --model-store .aesir/models
```

Home is a terminal menu intended to make chat, catalog browsing, diagnostics, and repair-related actions easier to discover.

If no models are installed yet, Home can still open. You simply will not have model weights available to chat with.

---

# 6. Windows users: use the PowerShell launcher

From PowerShell in the repository checkout:

```powershell
./scripts/launch.ps1 -Build
./scripts/launch.ps1 -Check
./scripts/launch.ps1
```

To explicitly open Home with the default local model-store path:

```powershell
./scripts/launch.ps1 -AppArgs @('home', '--model-store', '.aesir/models')
```

If you use more than one WSL distribution, you can specify the prepared distribution:

```powershell
./scripts/launch.ps1 -Distribution 'Ubuntu' -AppArgs @('home', '--help')
```

The PowerShell script does not install WSL or create the development environment for you. It bridges into an environment you have already prepared.

---

# 7. Run a health/diagnostic check

A useful early step is:

```bash
python3 scripts/launch.py -- doctor --model-store .aesir/models --json
```

`aesir doctor` is designed to check useful local conditions such as CUDA, storage integrity, disk visibility, listeners, and model compatibility without requiring Internet access for the diagnostic itself.

A diagnostic result is not the same thing as proving that every model can run. It helps identify the state of the environment.

---

# 8. See what models A.E.S.I.R. knows about

Using the native executable/CLI, the model store supports:

```bash
aesir list
```

For machine-readable output:

```bash
aesir list --format json
```

To show one installed model:

```bash
aesir show MODEL_NAME
```

The default model-store root is `.aesir/models` unless your configuration selects another supported path.

---

# 9. Import a GGUF model you already have

If you already possess a GGUF file and an appropriate Modelfile recipe, import it into the durable store with:

```bash
aesir create mymodel:latest \
  --modelfile Modelfile \
  --model ./my-model.gguf
```

A.E.S.I.R. copies and hashes the model into its content-addressed store and records the catalog entry.

Importing a file does **not** magically mean A.E.S.I.R. knows how to execute its architecture. Storage and execution support are separate questions.

Verify the stored bytes with:

```bash
aesir verify mymodel:latest
```

---

# 10. Use aliases and favorites

If a model has a long catalog name, create a short alias:

```bash
aesir alias mymodel mymodel:latest
```

Mark a model as a favorite:

```bash
aesir favorite mymodel
```

See your aliases/favorites:

```bash
aesir aliases
aesir favorites
```

Favorites are useful in the newer path-free model-selection workflow because they are presented ahead of ordinary entries.

---

# 11. Inspect a GGUF before trying to run it

The current README documents:

```bash
aesir inspect <model> --format json
```

This is useful for looking at GGUF metadata/layout information.

**Important:** inspection means "A.E.S.I.R. can read and report this information." It does not mean "this model is supported for inference."

---

# 12. Ask A.E.S.I.R. about hardware/memory fit

The current CLI includes memory-fit planning/explanation work. Start with:

```bash
aesir compute explain
```

The September 16 implementation can explain fit decisions using concrete byte counts such as required memory, available memory, reserve, usable memory, deficit, and headroom.

Use this to understand *why* a model appears to fit or not fit rather than relying only on a vague yes/no answer.

---

# 13. Chat with a supported CUDA model

The native runtime's general chat form is:

```bash
aesir chat MODEL --accel cuda
```

For example, after a supported model has been correctly installed/cataloged, its catalog name or supported alias can be selected rather than manually typing a filesystem path in newer workflows.

The current native CUDA chat paths support common controls such as temperature, top-k, top-p, min-p, seed, repetition penalty, context/reply settings, and reset/settings behavior.

Because model support is still architecture-specific, consult the current README, `docs/NATIVE_RUNTIME.md`, and model-specific guides before assuming a newly downloaded GGUF will run.

---

# 14. Preview settings without loading the model

For supported chat/service commands, current documentation includes `--show-settings` so you can inspect the resolved settings before allocating/loading a model.

Examples:

```bash
aesir chat MODEL --accel cuda --show-settings
```

and

```bash
aesir serve MODEL --accel cuda --show-settings
```

This is useful when stored recipes, JSON configuration, and explicit command-line options are being combined.

A settings preview is not proof that the model fits hardware or can execute.

---

# 15. Run the early Ollama-compatible local service

This is one of the most interesting current features because it lets ordinary local-AI clients begin talking to A.E.S.I.R. through a familiar protocol.

For the currently documented Gemma 4 E2B service example, first import the model into the catalog:

```bash
.aesir/aesir create gemma4-e2b:latest \
  --modelfile Modelfile.gemma4-e2b \
  --model .aesir/models/gemma-4-E2B-it-Q4_K_M.gguf
```

Then start Ollama-compatible mode:

```bash
.aesir/aesir serve gemma4-e2b:latest --accel cuda --ollama \
  --context 16384 --max-tokens 256
```

A.E.S.I.R. listens locally at:

```text
127.0.0.1:11434
```

That is Ollama's familiar local port.

The current implemented routes are:

```text
GET  /api/version
GET  /api/tags
POST /api/show
POST /api/generate
POST /api/chat
```

## Important limitation: streaming is not implemented yet

Requests to generation/chat currently need:

```json
"stream": false
```

A client that requires Ollama's streaming NDJSON behavior will not yet be fully compatible.

The service also does not yet provide the complete Ollama model-management, embeddings, tool-calling, multimodal, or remote-listening surface.

---

# 16. Test Ollama-style generation manually

With the Ollama-compatible service running, a local test looks like:

```bash
curl -sS -H 'Content-Type: application/json' \
  -d '{"model":"gemma4-e2b","prompt":"What is two plus two?","stream":false,"options":{"num_ctx":16384}}' \
  http://127.0.0.1:11434/api/generate
```

Chat looks like:

```bash
curl -sS -H 'Content-Type: application/json' \
  -d '{"model":"gemma4-e2b","messages":[{"role":"user","content":"Hello"}],"stream":false}' \
  http://127.0.0.1:11434/api/chat
```

Each HTTP generation is currently stateless from the API client's perspective. For chat, the client sends the prior conversation messages again.

---

# 17. Run A.E.S.I.R.'s authenticated native service

A.E.S.I.R. also has its own local authenticated service rather than only the Ollama compatibility mode.

Create a private service-key directory and key on a Linux filesystem:

```bash
mkdir -p "$HOME/.config/aesir"
./aesir keygen "$HOME/.config/aesir/service.key"
```

Then start a supported model, for example using the documented general pattern:

```bash
./aesir serve MODEL \
  --accel cuda \
  --api-key-file "$HOME/.config/aesir/service.key" \
  --context CONTEXT \
  --max-tokens 256 \
  --timeout-ms 30000
```

The authenticated native service defaults to local port `18434` and loopback-only binding.

Do not expose this service to the public Internet. The current security contract is intentionally for a local client, not public multi-user hosting.

---

# 18. Clean up unused model blobs carefully

Removing a catalog entry does not necessarily mean shared model bytes should immediately disappear. A.E.S.I.R. separates catalog removal from garbage collection.

Remove a catalog entry:

```bash
aesir rm MODEL_NAME
```

Then, when appropriate, run:

```bash
aesir gc
```

The garbage collector validates the model-store namespace before deleting unreferenced canonical blobs.

---

# 19. What should a new user try first?

A simple first-session sequence is:

```text
1. Build A.E.S.I.R.
2. Run --check.
3. Open Home.
4. Run aesir doctor.
5. List the model catalog.
6. Import/verify one known-supported GGUF.
7. Inspect it.
8. Check memory fit.
9. Chat with it locally.
10. Only after native chat works, try the local HTTP/Ollama-compatible service.
```

This keeps troubleshooting simple. If step 6 fails, you do not need to debug HTTP. If native chat fails, you do not need to wonder whether an external client is the problem.

---

# 20. Things not to assume

Do not assume that:

- every GGUF will run because it can be imported
- every quantization primitive means full-model support
- an `inspect` result proves inference compatibility
- a memory-fit result proves architecture support
- compiling for a GPU target proves physical support
- Ollama compatibility means complete Ollama parity
- the local HTTP service is safe to publish on the Internet
- Windows PowerShell launch means A.E.S.I.R. is a native Windows binary
- roadmap features are already implemented

A.E.S.I.R.'s development philosophy deliberately separates **working evidence** from **future intention**.

---

# 21. Where to look when this guide becomes stale

Because this document is dated **September 16, 2026**, check these sources for newer truth:

- `README.md`
- `CAPABILITY_LEDGER.md`
- `BEST_IN_CLASS_GAMEPLAN.md`
- `docs/NATIVE_RUNTIME.md`
- `docs/NATIVE_SERVICE.md`
- `docs/MODEL_STORE.md`
- `docs/LOCAL_LAUNCH.md`
- `docs/CONFIGURATION.md`
- `docs/DEVLOG.md`

For a non-technical introduction, see:

- `docs/PROJECT_AESIR_PLAIN_ENGLISH_GUIDE_2026-09-16.md`

For the dated capability summary, see:

- `docs/PROJECT_AESIR_WHAT_WORKS_NOW_2026-09-16.md`

---

# 22. Final beginner summary

If you remember only four things:

1. **A.E.S.I.R. is real working experimental inference software, not only a roadmap.**
2. **Its strongest current practical path is Linux/WSL2 + supported NVIDIA CUDA models.**
3. **The terminal Home, model store, diagnostics, native chat, and early compatibility APIs are usable now.**
4. **It is changing quickly, so always prefer newer dated documentation over this September 16 snapshot when the two disagree.**
