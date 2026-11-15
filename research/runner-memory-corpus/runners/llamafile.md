# OR-2 — llamafile: The Single-Executable Distribution of llama.cpp

**Project:** llamafile
**Repository:** https://github.com/mozilla-ai/llamafile (formerly Mozilla-Ocho/llamafile; GitHub redirects the old location)
**Documentation:** https://docs.mozilla.ai/llamafile
**Announcement:** “Introducing llamafile”, Mozilla Hacks, 29 November 2023 — https://hacks.mozilla.org/2023/11/introducing-llamafile/
**Adoption / relaunch:** “llamafile Returns”, Mozilla.ai blog, 29 October 2025
**Principal creator:** Justine Tunney (creator of Cosmopolitan Libc), initially with Mozilla’s innovation group / Mozilla Builders; now maintained and “revamped” by Mozilla.ai, per the current README
**Licence stack — as verified from the repository and its dependencies (see §1.1):**

- llamafile itself: **Apache-2.0**
- llamafile’s changes to llama.cpp and to whisper.cpp: **MIT**, matching those upstream projects, explicitly so the changes remain upstreamable
- llama.cpp: **MIT**
- whisper.cpp: **MIT**
- Cosmopolitan Libc and the Actually Portable Executable (APE) format: **ISC** (Tunney’s APE page records “APE is now licensed ISC”, update dated 28 December 2020; contemporary Cosmopolitan release coverage likewise describes the project as ISC-licensed)
- Model weights bundled inside any given llamafile: **under their own licences, separately** — e.g. a Llama-derived file carries that model family’s licence terms. The llamafile software licence does not re-licence the weights.

**As of:** 2026-11-15. All sources below were accessed 2026-11-15 unless a publication date is given for the source itself.

**Essence.** llamafile is not a new inference engine. It is a *distribution format and packaging framework* that takes llama.cpp, compiles it with Cosmopolitan Libc into an Actually Portable Executable, and optionally embeds GGUF model weights plus a default-arguments file inside that same executable, using a ZIP container whose entries are page-aligned so they can be memory-mapped in place. The result is a single file — in the pre-built case, the model *is* the program — that runs with no installation on six operating systems (Linux, macOS, Windows, FreeBSD, OpenBSD, NetBSD) across AMD64 and ARM64, presenting either a terminal interface, a one-shot command-line interface, or llama.cpp’s HTTP server with its web UI and OpenAI-compatible endpoints. It is the field’s purest answer to the question “how does a local model reach a non-technical user?”: you send them one file, they run it. Everything else in this dossier — the polyglot header, the fused versioning, the 4 GB Windows ceiling, the signing friction, the inability to swap models without repacking — follows from that one decision.

---

## 1. Header notes and licence verification

### 1.1 What was verified, and where

The current README (mozilla-ai/llamafile, `main`, read 2026-11-15) states the project’s goal in its own terms — making open LLMs accessible by combining llama.cpp with Cosmopolitan Libc into a single-file executable that runs locally on most operating systems and CPU architectures with no installation — and carries a dedicated Licensing section. That section says, in substance: the llamafile project is Apache-2.0-licensed, while the project’s changes to llama.cpp and whisper.cpp are MIT-licensed, like those projects themselves, to remain compatible and upstreamable. The 29 November 2023 Mozilla Hacks announcement says the same thing in the same structure: llamafile is Apache-2.0, and “our changes to llama.cpp itself are licensed MIT (the same license used by llama.cpp itself)”.

That split matters for anyone reusing the work:

- Code that is *llamafile’s own* — the packaging, the Cosmopolitan integration, the server/CLI glue as maintained in the llamafile repository — is used under Apache-2.0, with its patent grant and its requirement to state changes.
- Code that is a *patch to llama.cpp or whisper.cpp* is MIT, and can in principle flow upstream or be taken into an MIT codebase without Apache friction.
- Cosmopolitan is a separate dependency with its own permissive licence (ISC, a simplified BSD/MIT-style licence). It is *not* Apache-2.0 and *not* MIT; a compliance inventory that lists only “Apache + MIT” for a llamafile artefact is incomplete.
- The weights are a fourth layer. A pre-built llamafile distributed on Hugging Face is a combined artefact of Apache/MIT/ISC code *plus* a model whose licence is whatever its publisher chose. The README’s own historical examples flagged this explicitly (e.g. noting the model licence alongside the download). Any redistribution story must carry the model licence separately.

*Unverifiable in this sweep:* the exact copyright-holder line inside the current `LICENSE` file was not opened directly; a secondary licence review (USASI, fact-reviewed 1 October 2026) reports it names the Mozilla Foundation. That detail is marked as second-hand here and should be confirmed from the file itself before any legal reliance.

### 1.2 Lineage in one paragraph

First released 29 November 2023 as a product of Mozilla’s innovation group, developed by Justine Tunney through the Mozilla Internet Ecosystem (MIECO) programme, which had also funded Cosmopolitan 3.0. It lived under Mozilla Builders / the Mozilla-Ocho GitHub organisation through the 0.7–0.9 series, which is where its CPU-performance reputation was made. On 29 October 2025 Mozilla.ai announced it was adopting the project — the codebase “officially joined the mozilla.ai organization in GitHub” — to advance “open, local, privacy-first AI”, with a refresh and modernisation promised. The current README describes the result as a Mozilla Builders project “now revamped by Mozilla.ai”, and documents a 0.10 series built on a new build system whose stated purpose is to stay more easily aligned with recent llama.cpp releases. The README is candid that the 0.10 line “might be missing some of the features you were accustomed to” from the classic line, and that older releases remain available. Pre-built files now state which server version they were bundled with.

---

## 2. The APE mechanism: how one binary runs across OS and architecture

This is the section a systems engineer needs to get right, because llamafile’s portability is routinely described as “a fat binary” and that phrase, unqualified, misleads. There are *three* different portability problems being solved at once — operating-system format, CPU instruction set / microarchitecture, and C-library / syscall ABI — and APE solves each with a different trick.

### 2.1 The polyglot header: one file, several valid beginnings

An Actually Portable Executable is a *polyglot file*: the same byte sequence is simultaneously a valid Windows PE executable, a valid shell script, and — through the loader the script bootstraps — a valid ELF / Mach-O program. Tunney’s own explanation (APE page, 24 August 2020) traces the discovery to an accident of history: a Windows PE file can be encoded as a Unix Sixth Edition shell script because the Thompson shell did not use a shebang line. There is therefore no leading `#!` that must be reconciled with the `MZ` magic Windows requires; the opening bytes can serve both parsers at once.

Concretely, as documented on that page and summarised in the project’s technical-details page:

1. The file opens with the ASCII sequence beginning `MZqFpD='`. To Windows, `MZ` is the DOS/PE magic and the file proceeds as a PE. To a CPU executing it as code, those same bytes decode as harmless x86 instructions that hop toward the real entry point (Tunney gives the decoding: `pop`, conditional jumps). To a POSIX shell reading it as a script, it is the start of a variable assignment that swallows the binary header that follows, up to a closing quote.
2. Inside that quoted region sits a label the page renders as the BIOS boot sector marker — the header also has to survive being treated as a bootable image.
3. The shell-script portion then does the real bootstrap work. In Tunney’s published skeleton it opens the file itself on a new file descriptor, writes an ELF header — described as a “linker-encoded FreeBSD header” — through that descriptor, and re-executes itself (`exec "$0" "$@"`). If that fails, it falls back to running itself under `qemu-x86_64` if present, and otherwise exits. The point of the re-exec is to hand control from “shell interpreting a script” to “kernel / loader mapping a native binary”, without ever creating a second distributed file.
4. After the prologue, the file lays out, in sequence: real-mode / boot material, ELF segments, an OpenBSD note, a NetBSD note, Mach-O headers, then the shared code and data, and finally a ZIP directory at the end of the file (see §3 for why the tail is a ZIP).

Each operating system’s loader therefore finds the header *it* requires at the offset *it* requires, and ignores or skips the material meant for the others. Windows never executes the shell text as a script; a Unix shell never tries to load the PE; the Unix kernel path is reached via the script’s self-re-exec through the APE loader.

The current llamafile documentation describes the deployed form of this, rather than the 2020 minimal skeleton:

- **On Windows**, llamafile “runs as a native portable executable” — no loader extraction step.
- **On Unix systems**, the file “extracts a small loader program named `ape` to `$TMPDIR/.ape-1.10` which is used to map your model into memory” (Supported Systems page, read 2026-11-15). The technical-details page puts the loader at about 8 KB and its destination as `${TMPDIR:-${HOME:-.}}/.ape` in the classic description.
- **Assimilate as the escape hatch.** Cosmopolitan ships a program called `assimilate` (bundled with the `cosmocc` compiler) that rewrites an APE in place into the host platform’s *native* executable format. The technical-details page presents this explicitly as the guarantee that “a fallback path exists for traditional release processes when it’s needed” — i.e. if a distributor needs a conventional signed native binary for one platform, they can sacrifice portability for that copy and get one.

### 2.2 Architecture portability: the program is built twice

APE’s original 2020 design was x86-64 only — Tunney’s page is explicit that the lingua franca is the x86-64 Linux syscall ABI, with emulation (qemu, or an embedded emulator build) discussed as the route to ARM, at a size and performance cost. llamafile does *not* rely on emulation for its normal path. Its technical-details page states the solution plainly, in substance:

> Architecture portability is solved by building llama.cpp twice — once for AMD64 and again for ARM64 — and wrapping both builds with the shell script that carries the `MZ` prefix.

So a llamafile is “fat” in the classic sense at the *code* level: it contains two complete native builds of the inference engine, and the bootstrap selects the one matching the host CPU. The weights, being data in GGUF format, are architecture-neutral and are shared, not duplicated. This distinction matters for size accounting (§2.5): the duplication cost is paid on the *runtime* (tens of megabytes class), not on the *model* (gigabytes class).

Within a single architecture there is a second, finer dispatch. The technical-details page’s “microarchitectural portability” section describes how the hot matrix-multiplication quant kernels — normally written separately for SSSE3, AVX, and AVX2 — are factored into files that can be included multiple times with different compiler target attributes, with a wrapper that uses Cosmopolitan’s CPU-feature detection to dispatch at runtime to the implementation the host supports. The Supported Systems page gives the floor and the conditional ladder: AMD64 requires AVX or the program prints an error and refuses to run; AVX2, AVX-512, FMA, F16C, and VNNI are enabled at runtime when present. ARM64 requires ARMv8a or newer. In other words, one artefact spans not just two ISAs but a whole microarchitecture range within each, without the user choosing a build — the same property a Go runner would normally get from per-CPU build tags or from shipping several binaries, obtained here by runtime dispatch inside one file.

### 2.3 The libc problem: Cosmopolitan as a syscall translation layer

A binary format trick alone does not make a program portable, because the program still has to *ask the operating system for things* — memory, files, sockets, threads — and each OS names and numbers those requests differently. Cosmopolitan Libc is the layer that absorbs that difference. It provides a C library whose system-call wrappers are symbolic rather than hard-coding one OS’s numbers and constants, so the linker can generate the structures each target needs and the runtime can issue the host’s native syscalls. Tunney’s APE page describes the required concession honestly: it “requires a minor ABI change, where C preprocessor macros relating to system interfaces need to be symbolic”, with cases like switching on `errno` constants called out as the friction point.

For llamafile specifically, two Cosmopolitan consequences dominate:

- **Static linking is mandatory, and that breaks the usual GPU story.** The technical-details page states it directly: Cosmopolitan uses static linking “since that’s the only way to get the same executable to run on six OSes”, and GPU support cannot be statically linked in the usual way. The classic llamafile solution was to embed the *source* of each GPU module (the single-file Metal and CUDA implementations from llama.cpp) inside the file’s ZIP, detect a host compiler at runtime (Xcode tools on macOS, `nvcc` elsewhere), compile the module for the host’s exact GPU architecture on first use, and then bridge into the platform’s dynamic libraries through a Cosmopolitan `dlopen()` implementation — including, on AMD64, runtime rewriting of TLS register accesses and, on ARM, fixing the TLS register by compiler flag, plus using the Windows calling-convention attribute for function pointers crossing the boundary so the same module can talk to Windows drivers. The current 0.10 documentation describes a more conventional arrangement — prebuilt `ggml-(cuda|rocm|vulkan)` shared libraries looked up in a defined search order (beside the executable first, then in the bundle, then under `~/.llamafile/…`, then `$HOME`), with macOS Metal still involving a small module compiled with the Xcode Command Line Tools on first run and cached under `$TMPDIR/.llamafile` or `$HOME/.llamafile`. *Reading note:* the two descriptions come from two generations of the project (classic technical-details narrative vs. the 0.10 Supported Systems page) and both were live in the documentation as read on 2026-11-15. The dossier treats the 0.10 page as current for shipped 0.10 builds and the technical-details page as the explanation of the mechanism the classic line pioneered; anyone implementing against this should verify which path a specific release binary takes.
- **No installer, no system dependencies — by construction.** Because the C library travels with the program and the program asks for nothing from the host except syscalls, a GPU driver, and (in the cases above) a host compiler or bundled GPU library, there is nothing to install. That is not a packaging choice layered on top; it is a consequence of the libc choice.

### 2.4 Supported envelope, as documented

From the current Supported Systems page (read 2026-11-15):

| Dimension | Documented support |
|---|---|
| Linux | Kernel 2.6.18+ (framed as every distro since RHEL5, c. 2007) |
| macOS | Darwin 23.1.0+ as the tested floor (a footnote says 15.6+ *should* work but is untestable by the project); GPU only on ARM64 |
| Windows | Windows 10+, AMD64 only |
| FreeBSD | 13+ |
| NetBSD | 9.2+, AMD64 only |
| OpenBSD | 7.0 to 7.4, AMD64 only |
| AMD64 CPU | AVX required; AVX2 / AVX-512 / FMA / F16C / VNNI opportunistically used |
| ARM64 CPU | ARMv8a+ (Apple Silicon through 64-bit Raspberry Pi, provided the weights fit in memory) |
| GPU | Apple Metal (built-in, macOS ARM64); NVIDIA CUDA (Linux / Windows / WSL; bundled library covers compute capability 7.5+); AMD HIP/ROCm (Linux / Windows; library obtained separately, ROCm runtime required); Vulkan (Linux / Windows / macOS, via MoltenVK on macOS) as the broad fallback, including Intel hardware. No Intel oneAPI/SYCL backend. |

The same page warns that the 0.10 series “has not been tested on every GPU and platform yet”, with the AMD and Windows paths called out as best-effort in particular. Earlier third-party coverage of the 0.10.0 launch (March 2026) reported Windows GPU support as still missing at that point; the current documentation lists CUDA and Vulkan as supported on Windows. Those are not necessarily contradictory — they are snapshots at different points in a fast-moving series — but the honest summary as of 2026-11-15 is: *documented as supported, self-described as incompletely tested.*

### 2.5 Size and startup costs, honestly

**Size.** Three components stack up:

1. *The APE / Cosmopolitan overhead itself is tiny in isolation.* Tunney’s canonical examples are a 12 KB game-of-life program and a 16 KB hello-world — described as roughly 100× smaller than a Go hello-world. That figure is real but irrelevant at LLM scale, and the dossier flags it so no reader imports it into a model-sized calculation.
2. *The duplicated runtime is the real portability tax.* Two native builds of llama.cpp (AMD64 + ARM64), each carrying multiple SIMD variants of its hot kernels, plus embedded GPU-module material and the web UI assets, plus the ZIP directory. Publicly, the bare llamafile executables and server executables are in the tens-of-megabytes class (the troubleshooting documentation casually notes a LLaVA server executable sitting “just 30 MB shy” of the 4 GB Windows limit once its weights are included, which tells you the weights dominate that arithmetic). Against a multi-gigabyte model this tax is a rounding error; against a bare-runner download (the Ollama comparison case) it means the “universal” runner is strictly larger than any one native runner it replaces. That is the correct trade to name: you download every platform’s runtime so that you never have to *choose* a platform’s runtime.
3. *The weights dominate everything.* Pre-built llamafiles in the current Mozilla.ai Hugging Face collection run from a Qwen3.5 0.8B Q8_0 file (the README’s quick-start example, chosen as the smallest the project has built) up through multi-gigabyte files; secondary coverage of the 0.10 collection describes a range up to a ~19 GB Qwen3.5 27B file. At that end, “one file” stops being a convenience phrase and becomes a concrete filesystem, transfer, and (§7) operating-system-limit problem.

**Startup.** The project’s own technical-details summary claims the design “launches itself and runs inference on embedded weights in milliseconds without needing to be copied or installed”, with `mmap()` as the enabling mechanism: the loader maps the executable, the executable re-opens itself as a file and maps the weights, and page-aligned weights can then be handed directly to the CPU and GPU without a copy or a decompression pass. That is the *mechanism* claim, and it is plausible for the mapping step itself. It should not be read as a measured cold-start benchmark: this sweep found **no primary-source published measurement of llamafile time-to-first-token, model-load time, or process-start latency** — Mozilla.ai’s September 2026 benchmark post explicitly lists load time, time-to-first-token, memory, and power as *not yet measured* (see §5). The known, documented startup costs that do exist are:

- one loader extraction on Unix (the small `ape` program written to a temp location on the path described in §2.1);
- one self-re-exec through the shell prologue on Unix;
- on macOS ARM64, a **first-run compilation** of the Metal module requiring the Xcode Command Line Tools, cached afterwards — the troubleshooting page lists the absence of those tools as a failure mode on Apple Silicon;
- in the classic design, first-run compilation of whichever GPU module applies, for the same reason.

*Speculation, marked as such:* on a warm cache with CPU inference and a small model, APE startup overhead is very likely negligible next to weight mapping and KV-cache setup; on a first-ever run on macOS with GPU, the module-compilation step is very likely the dominant startup cost by orders of magnitude. Neither statement was measured in a source read for this dossier.

---

## 3. The packaging model: weights inside the executable

### 3.1 A llamafile is a ZIP archive that executes

The single most useful mental model, and the one the current “Creating llamafiles” documentation leads with, is: **a llamafile bundles the executable, the model weights, and a set of default arguments into one self-contained file using the APE format, which supports ZIP as a container for extra data.** Because the container is a genuine ZIP (with its directory at the end of the file, where ZIP readers look for it, and with ZIP64 support for large entries), a finished llamafile can be inspected with ordinary tools — the documentation suggests listing its contents with a standard unzip listing command, and notes that on Windows renaming it to `.zip` and opening it in a ZIP GUI works. The executable headers at the front and the archive directory at the back do not interfere, because each reader starts from its own end of the file. Tunney’s APE page makes the same point about APE files generally: PKZIP placed its marker at the end of the file rather than the beginning, which is what makes the synthesis possible at all.

This has a consequence worth stating for an engineering reader: *the packaging format is not proprietary.* Anyone can list, extract, and repack a llamafile with documented tooling. The upgrade path in §3.4 depends entirely on this property.

### 3.2 zipalign and the page-alignment requirement

Naïvely concatenating a GGUF file onto an executable would “work” as storage and fail as engineering, because llama.cpp wants to memory-map the weights and hand pointers straight to the GPU, and GPU APIs such as Apple Metal require page-aligned data. The technical-details page’s “ZIP weights embedding” section explains the fix: each local file inside the ZIP must start on a page-size boundary, stored uncompressed, so that once the whole file is mapped, the weights are already at addresses a GPU can accept — no copy, no realignment buffer, no double memory.

No off-the-shelf ZIP tool offered the needed alignment control, so the project wrote its own: `zipalign`, described in the classic README as roughly 500 lines of C written for exactly this insertion job. (Note for anyone searching: the documentation explicitly warns this is *not* the Android tool of the same name; the llamafile one now lives as its own project/submodule and builds alongside llamafile.) In the current build, `zipalign` is produced as part of the source build and is the documented tool for the packing step.

The packing workflow, as documented in the current “Creating llamafiles” page, is conceptually three steps — described here in the dossier’s words, with only the tool’s interface labels retained:

1. Start from a copy of the bare llamafile executable, renamed to the target model’s llamafile name.
2. Prepare a `.args` file (see §3.3).
3. Invoke `zipalign` in its uncompressed mode to insert the GGUF weight file(s) — a main model and, for multimodal models, a separate projection file — plus the `.args` file into that copy.

The result is run directly; there is no install step, no extraction step at distribution time, and no separate model directory.

### 3.3 The `.args` file: default arguments as cargo

The `.args` file is a small text file embedded alongside the weights. Its format is deliberately trivial: **one argument per line**, in the same spelling the command line would use. At minimum it names the model to load, using a path with a `/zip/` prefix that refers to a file *inside* the llamafile itself rather than on the host filesystem. Beyond the model path it can carry anything the underlying llama.cpp-based program accepts: a multimodal projector path, a host binding, a GPU-layer count, sampling defaults (temperature, top-k, top-p, and so on), context and generation lengths, a server flag — whatever the packager wants the zero-argument experience to be.

One token has special meaning: a line containing only `...` marks the position at which any *additional* arguments the end user actually types are spliced into the argument list. Without it, the embedded defaults are the whole story; with it, a llamafile can be both “double-click and it serves on this host and port with these sampling settings” and “still a normal program you can override”.

This is a small mechanism with an outsized product effect, and it deserves to be named as one of llamafile’s real inventions rather than a detail:

- It moves *configuration* into the artefact. The packager’s intent — this model, this projector, serve it, offload fully to GPU — travels with the file instead of living in a README the recipient will not read.
- It makes the zero-argument invocation meaningful. `./model.llamafile` with no flags does the right thing because the right thing was packed in.
- It is inspectable and editable with the same ZIP tooling as everything else in the file. Changing a default does not require recompilation, only repacking.

### 3.4 Distribution consequences: fused versioning

Fusing weights and runtime into one artefact cuts both ways, and the dossier states both sides as the project itself presents them:

**The benefit — no version skew, forever.** The 2023 announcement makes the archival argument explicitly: as models and weight formats evolve, a llamafile gives you a way to ensure a given set of weights “will remain usable and perform consistently and reproducibly, forever”, because the exact runtime that knows how to read them is frozen inside the same file. There is no future in which a user has model version X, runner version Y, and a template mismatch between them. Anyone who has supported Ollama-style deployments — where the runner auto-updates, the model was pulled months earlier, and the chat template lives in a third place — will recognise the failure class this eliminates by construction. The current README reinforces the provenance half of this: pre-built llamafiles “always show which version of the server they have been bundled with”, and the creating documentation recommends that anyone publishing a llamafile state the git revision or release version used to build it, and embed a notice of any source changes (which Apache-2.0 requires) inside the file itself via `zipalign`.

**The cost — updates are re-downloads, unless you do surgery.** If the runtime is fixed, the only vendor-supplied upgrade is a whole new artefact: new runtime *plus* the same multi-gigabyte weights again. The project’s own answer, given by Tunney in a public Hacker News reply about the upgrade path (January 2024, surfaced in this sweep), is twofold: either re-download the full re-uploaded weights for the new release, *or* treat the llamafile as the ZIP it is — extract the GGUF weights and the `.args` file from the old file with a standard unzip tool, download the new bare llamafile binary and `zipalign`, and repack the weights you already have into the new runtime. The second path is genuinely available and documented by example, but it must be described honestly: it is a *developer* workflow involving archive tooling and a packing utility, not something the non-technical recipient who is llamafile’s headline audience will ever do. For that audience, the practical upgrade path is “download the whole thing again”.

**The corollary — one file, one model.** Each bundled llamafile contains exactly one model (plus its projector, if multimodal). There is no model library, no switching, no sharing of one runtime across a collection, unless the user abandons the bundled form and runs the bare binary with external weights (§4.3). Storage economics follow: ten models as llamafiles means ten copies of the runtime — trivial — *and* no deduplication of anything else, because there is nothing else shared to deduplicate. More importantly, *curation* economics follow: every model × quantisation × runtime-version combination is a distinct multi-gigabyte artefact someone must build, host, and mirror. Mozilla.ai’s Hugging Face collection is exactly that matrix, maintained centrally.

### 3.5 The bare-binary form

It is essential not to overstate the fusion: llamafile *also* ships as a bare executable with no embedded weights, which accepts any external GGUF file via the normal model flag. The README’s Windows note points large-model users at exactly this form. In that mode llamafile is simply a highly portable llama.cpp build — still interesting (one download runs everywhere) but no longer a distinct distribution philosophy. Several of the weaknesses in §7 are weaknesses of the *bundled* form specifically, and the bare form is the project’s own mitigation for most of them.

---

## 4. Runtime behaviour: it is llama.cpp inside

### 4.1 What runs

A llamafile’s inference, tokenisation, sampling, grammar support, and serving are llama.cpp’s. The 0.10 build system’s stated purpose is to track upstream llama.cpp more closely (the source-installation documentation shows the build literally producing the upstream server binary, compiled with the Cosmopolitan compiler, alongside the llamafile executable and `zipalign`). Model support, quantisation support, and bug-for-bug behaviour therefore follow llama.cpp’s, subject to the lag and the patch set of the llamafile release in question. The project maintains its patches to llama.cpp and whisper.cpp as MIT-licensed changes (§1.1), historically including significant performance work that was written to be upstreamable (§5).

The same packaging carries a sibling: **whisperfile**, a single-file speech-to-text executable built on whisper.cpp with the same Cosmopolitan treatment, supporting transcription and translation across the same platform set. It is part of the repository and documentation set, and it demonstrates that the format generalises beyond chat models to any “weights + C/C++ runtime” program.

### 4.2 Modes, as documented

The current documentation (“Running a llamafile”, read 2026-11-15) describes the llamafile executable as one program with selectable modes, plus a combined default:

- **Combined mode (the default in the current generation).** Running a bundled llamafile with no mode flag starts *both* a terminal chat interface *and* the HTTP server (default `http://localhost:8080`) simultaneously, so the same process can be chatted with locally and called as an API endpoint at the same time.
- **Server mode (`--server`).** Runs llama.cpp’s HTTP server: a browser chat UI plus OpenAI-compatible endpoints (chat completions, completions, embeddings where the model supports them, health). Host and port are configurable; binding beyond localhost is an explicit flag choice. The documentation notes the web UI is inherited from llama.cpp — some UI messages still name the upstream server binary — and that current builds support options such as Jinja templating for agent-style use and a set of built-in local tools enabled selectively, with the server restricting allowed browser origins to localhost by default when those tools are on. Those tool details are 0.10-era surface area and should be re-verified against a specific release before being relied on.
- **Chat / TUI mode (`--chat`, and the terminal UI generally).** An interactive terminal conversation with its own slash-commands for context management, file handling, and dumping a conversation to a file.
- **CLI mode (`--cli`).** One-shot, scriptable inference: a prompt in (via flag, file, or stdin), text or a structured answer out. The documentation shows it used for prose, for image description with a multimodal model, for web-page summarisation by piping text in, and — for specialised “decision” models — for JSON-in / JSON-out classification-style calls. Grammar-constrained output, a llama.cpp capability, is shown used the Unix way: llamafile as a filter in a shell pipeline whose output is consumed by the next command. This mode is the one that makes a llamafile a *Unix tool* rather than an application, and it is easy to underrate.

Flags not consumed by the llamafile wrapper pass through to the underlying llama.cpp program, and the documentation treats “bundled llamafile with extra flags” and “bare binary with an external model and the same flags” as equivalent invocations. The `.args` splice token (§3.3) is what reconciles embedded defaults with those extra flags.

### 4.3 External weights

The bare binary plus an external GGUF is a first-class, documented mode, not a hack. It is the prescribed route for:

- any model whose bundled form would exceed the Windows 4 GB executable limit (§7);
- users who already have GGUF files on disk, including models downloaded by other applications (the quick-start documentation addresses reusing them);
- anyone who wants one runtime and many models — i.e. the Ollama-shaped workflow, minus the daemon and the model manager.

### 4.4 What Mozilla adds on top of llama.cpp

Stripped to essentials, the llamafile project’s own contribution over “llama.cpp, compiled normally” is:

1. **The Cosmopolitan port and its maintenance** — making llama.cpp build and run as an APE, including GPU and `dlopen()` support inside Cosmopolitan (the 2023 announcement names adding GPU and `dlopen()` support to Cosmopolitan as one of the “interesting and juicy problems” solved along the way).
2. **The packaging toolchain** — `zipalign`, the `.args` convention, the `/zip/` path convention for embedded files, and the documented create-your-own workflow.
3. **Performance work in the classic line** — the CPU matrix-multiplication library and dispatch work described in §5, written as MIT-licensed llama.cpp changes.
4. **Curation and distribution** — the pre-built collection on Hugging Face, version-labelled by bundled server release, plus the documentation set (quick start, pre-built catalogue, running, creating, source installation, technical details, supported systems, troubleshooting) now hosted under Mozilla.ai.
5. **The 0.10 rebuild** — a new build system tracking llama.cpp as a closely-followed dependency rather than a heavily forked one, trading some classic-line features (per the README’s own warning) for currency with upstream models and functionality.

What Mozilla does *not* add is equally definitional: no daemon, no background service, no model registry or pull/update manager, no accounts, no telemetry story, no multi-model serving, no orchestration. A llamafile is a process you run, not a platform you run on. That absence is the product.

---

## 5. Performance character

### 5.1 The baseline expectation: llama.cpp’s numbers

Because the engine is llama.cpp, the correct prior for any llamafile is “llama.cpp performance on this hardware, with this quantisation, with these flags” — and the most recent primary evidence confirms that prior emphatically. Mozilla.ai’s own comparative benchmark (blog post published 17 September 2026; llamafile 0.10.6, llama.cpp b10441, Ollama 0.34.0, LM Studio 2.28.2; Qwen models at 0.8B / 9B / 27B; Mac Studio M4 Max with Metal, a Linux server with an NVIDIA L40S with CUDA, and a Steam Deck with Vulkan) found, in its own summary:

- All four servers share the llama.cpp core and “land within a few percent on prompt processing once weights and environment are held fixed”. On Metal specifically, llama.cpp, llamafile, and Ollama sat within ±3% of each other at every prompt length tested.
- Most of the remaining decode difference was a *fixed per-token host cost*, measured at roughly 0.4 ms on the Mac, 1.8 ms on the L40S system, and 5.4 ms on the Steam Deck — which is why the same absolute gap looks like a large percentage on a small fast model and a small percentage on a large slow one.
- The things that *did* move numbers by tens of percent were build and configuration choices, not engine choice: enabling CUDA graphs in the llamafile build improved L40S decode by 16.8% (0.8B), 6.5% (9B), and 4.3% (27B); building with a newer Vulkan shader toolchain improved Steam Deck prompt processing by 25.9% (0.8B) and 63.3% (9B); the best speculative-decoding draft length flipped by platform (2 on Metal, 4 on CUDA).

The engineering lesson the Mozilla.ai authors draw — check how your server was *built*, not just which server it is — applies to llamafile itself: a llamafile’s speed is substantially a function of which flags and toolchain its packager used, a fact a recipient of a pre-built file cannot easily change.

The same post supplies a distribution-relevant footnote: on a roughly ten-year-old Intel MacBook Pro, only llama.cpp and llamafile ran successfully under its installed macOS, where the current Ollama and LM Studio distributions did not support that system. That is a *compatibility* result, not a speed result, and it is one of the strongest published data points for the APE approach: the portable artefact kept working on hardware/OS combinations the per-platform distributions had moved past.

### 5.2 The classic era: when llamafile was *faster* than llama.cpp

The 0.7–0.9 line had a genuinely different performance story, and an honest dossier must keep the two eras separate. In that period llamafile carried its own CPU matrix-multiplication work (named tinyBLAS in the project’s writing; the entry points surface in llama.cpp history as the llamafile `sgemm` / `mixmul` functions), aimed at the prompt-processing (prefill) phase, where large matrix-matrix multiplies dominate, rather than at single-token generation, where memory bandwidth dominates and there is less to win.

Reported results from that era, all from public primary or near-primary sources:

- The 0.7 release claimed prompt evaluation “anywhere between 30% to 500% faster than llama.cpp upstream” depending on hardware and weight format, with the gains concentrated in F16, BF16, Q8_0, Q4_0, and F32 weights, and with AVX-512 support giving Zen 4 owners up to a claimed 10× prompt-evaluation improvement in the best case (release notes as quoted in Hacker News discussion, April 2024; The Register’s contemporary coverage headlined the same 30–500% range).
- The 0.8 release (April 2024, covered by Phoronix from the release notes) extended the work to mixture-of-experts models — Mixtral and Grok class models running 2–5× faster on CPU for prompt processing after the MoE path was decomposed into the same optimised multiplies — and reported F16 prompt-evaluation gains of roughly 20% on a Raspberry Pi 5, 30% on Intel Skylake, and 60% on an Apple M2, each with before/after tokens-per-second figures for a small test model. Tunney’s upstream llama.cpp pull-request discussion for the MoE change reports the same shape independently: Mixtral 8×7B F16 prompt processing 2× faster on a Threadripper system, ~60% improvement for Mixtral 8×22B at Q4_0, and a Pi 5 reaching 78 tokens/second on non-MoE F16 prompt evaluation.
- A follow-on 0.8.2 release added AVX2 prompt-processing optimisations for the K-quants (contributed by the K-quants’ originator), with reported speedups in the 1.4–2.3× range across quants in the pull request and Tunney reporting 1.2–2.0× for prompt processing on x86-64 machines, plus token-generation gains up to ~1.33× in some cases (Phoronix coverage of the release, 2024).

Three cautions belong on these numbers. First, they are *prompt-processing* numbers almost exclusively; nobody in this literature claimed llamafile made bandwidth-bound token generation multiples faster, and a reader who carries “500% faster” into a chat-responsiveness expectation will be disappointed. Second, they are the project’s own release measurements on named hardware, not independent replications; the sweep found no third-party lab replication of the headline figures. Third, and most important for a 2026 reader: **the optimisations were upstreamed or upstreamable by design (MIT), and upstream llama.cpp absorbed this class of work over time.** Secondary 2026 coverage summarising the situation puts current llamafile and llama.cpp “within 5%” of each other, consistent with the Mozilla.ai benchmark in §5.1. The classic speed advantage should therefore be recorded as a *historical contribution that raised the whole field’s CPU prefill performance*, not as a present-tense reason to choose llamafile. What remains as a present-tense performance property is parity-plus-portability — plus whatever build-flag diligence the packager applied.

### 5.3 APE-specific overhead

No source read for this dossier published a controlled measurement isolating “APE packaging overhead” (same llama.cpp build, native vs. Cosmopolitan, same machine) for inference throughput. What can be stated from the mechanism and the documentation:

- *Steady-state inference* has no obvious APE tax: after the loader has mapped the program, syscalls are native, the compute kernels are native code dispatched by CPU features, and the weights are mapped, not interpreted. The September 2026 benchmark’s few-percent parity with a natively built llama.cpp server is indirect evidence that any residual overhead is small compared with build-configuration effects. *Marked as inference from parity data, not a direct measurement.*
- *Startup* pays the prologue / loader / possible GPU-module costs enumerated in §2.5. Unmeasured in primary sources.
- *GPU reach* historically paid a different kind of tax: not slowness, but *fragility* — runtime compilation dependencies, per-architecture module builds, and silent fallback to CPU when setup fails. The current documentation is explicit that fallback is silent by default and recommends forcing a named GPU backend during diagnosis precisely so a missing backend becomes a startup error instead of a quiet slow run. A Go runner should read that as a design confession: in llamafile, “GPU didn’t engage” is a known, documented support burden.

---

## 6. Ecosystem position

### 6.1 Mozilla’s local-AI strategy, as public fact

Mozilla has framed llamafile from the first week as an *access and control* project, not a performance project. The Mozilla Builders essay published alongside the launch (“llamafile: bringing LLMs to the people, and to your own computer”, 14 December 2023) argues the position in plain terms: cloud AI raises questions of privacy, access, and control — who listens, how data is used, who decides what a model will answer — and open source is presented as the answer because inspectability gives the user understanding and control. It then coins the frame the project still uses: **local AI** — AI that runs on your own computer, works with the network off, cannot be changed or withdrawn by anyone else, and exposes its conversations to no one else. llamafile is positioned as the distribution mechanism that makes local AI real for people who will never install a development toolchain.

Mozilla.ai, the Mozilla Foundation-backed organisation that adopted the project in October 2025, describes its own mission in matching language — AI that is “trustworthy, transparent, and controllable”, open-source infrastructure and tools that give people “greater transparency, flexibility, and control” — and lists llamafile among its open tools as a single-file, cross-platform, local-first, fully offline way to run open models, calling it a “key enabler of sovereign AI”. Its October 2025 adoption post commits to refreshing the codebase, modernising the foundations, and shaping the roadmap with community input, and stresses continuity for existing users: the code stays public, issues stay open, existing binaries remain available, and GitHub redirects handle the organisational move. Contemporary reporting on Mozilla.ai (The New Stack, November 2025) adds organisational context: Mozilla.ai was being reset from an applied-R&D organisation toward a sustainable, product-oriented public-benefit company whose revenue is meant to support its open-source mission, with llamafile named by its CEO as part of that open tool line. That commercial framing is context, not a llamafile fact, and is included only so a reader does not mistake Mozilla.ai for a purely grant-funded steward.

Within Mozilla’s own practice, llamafile also appears as *infrastructure*: Mozilla.ai’s Blueprints programme (community automation recipes) uses llamafile as the local model server in published blueprints — for example, computing embeddings locally to build a personal social-media timeline algorithm without sending posts to a cloud service. That is the strategy in miniature: llamafile as the dependable local-inference primitive other local-first software can assume.

### 6.2 Who llamafile is for

Simon Willison’s launch-day assessment (29 November 2023) called it “the single best way to get started running Large Language Models on your own computer”, and the ensuing two years have clarified *which* user that superlative belongs to:

- **The recipient, not the operator.** Someone sent a model by a colleague, a teacher, a family member, a publication, or a research group, who should have to do exactly three things: download, make executable (or rename on Windows), run. No package manager, no Python, no driver archaeology, no “which build for my OS” decision — the file already contains every OS’s answer.
- **The distributor who needs the artefact to just work, later, elsewhere.** A journalist shipping a model with a story, a researcher shipping the exact model a paper used, an archivist freezing a weights-plus-runtime pair that will still execute when the ecosystem has moved on (§3.4). The announcement’s reproducibility argument is aimed squarely here.
- **The offline and the poorly connected.** Download once, run forever, on a plane, in the field, in a jurisdiction or a building where cloud AI is unavailable or impermissible. Mozilla’s local-AI framing and Mozilla.ai’s “sovereign AI” language both name this user.
- **The privacy-constrained professional** (secondary coverage of the 0.10 launch names lawyers, doctors, and accountants as the archetype): the guarantee needed is not a policy page but the physical fact that the program needs no network.
- **The owner of old or odd hardware.** The ten-year-old MacBook data point (§5.1) and the BSD support are not checklist features; they are cases where llamafile is the *only* current distribution that still arrives. BSD users in particular have no Ollama-shaped alternative of comparable polish.
- **The scripter who wants a model as a Unix filter** (§4.2, CLI mode) without standing up a server or a Python environment.

The folk summary of the first case — “send your grandmother a model” — is not a quote from a source read in this sweep and is used here only as the corpus’s shorthand for the recipient archetype above. *Flagged as shorthand, not attribution.*

### 6.3 Who llamafile is not for

- **Anyone running a model collection.** Switch models and you switch files (bundled form) or fall back to the bare binary (at which point the comparison is with every other llama.cpp frontend, on their turf). There is no library, no pull, no update channel.
- **Anyone serving multiple users or models concurrently as a platform.** llamafile is a single process serving a single model with llama.cpp’s server semantics. Batching, scheduling, multi-tenancy, and fleet concerns belong to serving engines, not to a distribution format.
- **Windows users with large models, in bundled form.** The 4 GB ceiling (§7) removes exactly the users a “just send it” story most wants, for exactly the models (7B at high quantisation and up) they most likely want — unless they accept the two-file external-weights form.
- **Anyone who needs a guaranteed, signed, store-distributable binary.** See §7 on signing and endpoint-protection friction; the `assimilate` escape hatch exists because this need is real.
- **Anyone who needs the newest model architecture on day one.** llamafile’s currency is bounded by its llama.cpp tracking, and the 0.10 rebuild exists precisely because the classic line had drifted. A fused artefact is, by design, always a snapshot.

Relative to its nearest relative in this corpus, KoboldCpp: both pursue “one file, no install” for end users, but they fuse at different layers. KoboldCpp fuses a *roleplay-oriented application* (its own UI and feature set) into a portable single executable per platform; llamafile fuses a *general llama.cpp runtime plus optionally the weights themselves* into a single file that is portable *across* platforms. KoboldCpp’s file knows what application you will run; llamafile’s file knows what *model* you will run. A Go runner can learn from both, but should not confuse their units of distribution.

---

## 7. Strengths and weaknesses

### Strengths

1. **Zero-install, zero-choice distribution.** One URL, one file, every desktop OS. No other runner in this corpus reduces the recipient’s decision count to zero; Ollama reduces it to “install the app, pull the model”, which is two systems to trust and version instead of one artefact.
2. **Provenance and reproducibility by construction.** Runtime and weights are frozen together, version-labelled, inspectable as a ZIP, and rebuildable from documented parts. The artefact is its own lockfile.
3. **Genuine platform breadth, including the long tail.** Six operating systems, two ISAs, runtime SIMD dispatch, a CPU path that keeps decade-old hardware in service, and BSD support — breadth no per-platform build matrix in this corpus matches from a single artefact.
4. **It is a standard container, not a proprietary one.** ZIP in, ZIP out: list it, extract the weights, repack them into a newer runtime, embed a licence notice. The format invites surgery instead of forbidding it.
5. **Configuration travels with the artefact** via `.args` (§3.3). The packager’s working setup is the recipient’s starting setup.
6. **Full llama.cpp surface in scriptable form.** Server, chat, and one-shot CLI modes, grammars, multimodal projectors, embeddings — the portable file is also a composable Unix tool.
7. **Offline and private by physics, not by policy.** No account, no phone-home in the distribution model, no network requirement after download.
8. **A demonstrated upstream citizen.** The classic line’s CPU work was MIT-licensed for upstreaming and measurably raised llama.cpp’s own prefill performance; the project’s licence hygiene (§1.1) is better than most forks’.

### Weaknesses

1. **The Windows 4 GB executable limit is a hard, structural ceiling.** Windows will not execute a PE image larger than 4 GB, and the README states the consequence without hedging: any llamafile above 4 GB will not work on Windows as a bundled file. This is not an edge case — a 7B model at Q8_0, or at Q4 with a projector and headroom, lives at or past that line, and the historical LLaVA example was sized explicitly to sit “just 30 MB shy” of it. The workarounds (external weights; running inside WSL, which the documentation notes also lifts the limit) both abandon the single-file promise for the largest desktop audience. Any honest account of llamafile starts its weakness list here.
2. **File-size reality for large models.** A 19 GB-class single file is hostile to everything around it: FAT32 media cannot hold it, many file-sharing and messaging channels cap far below it, a corrupted byte can invalidate a download that cannot be resumed or partially repaired as separate parts could, virus scanners take a long time with it, and “send it to a friend” quietly becomes “run a small file-transfer operation”. The format’s elegance is inversely proportional to model size, and model sizes have grown since 2023 faster than the format’s comfort zone.
3. **Code-signing and endpoint-protection friction, documented by the project itself.** The current troubleshooting page is the primary evidence, and it is unusually frank: on *any* platform, if the process is immediately killed, the first instruction is to check for CrowdStrike and ask to be whitelisted; on macOS, a dedicated section handles the “cannot be opened because the developer cannot be verified” Gatekeeper refusal, with steps to allow the file in Privacy & Security and a fallback that temporarily disables system policy checking entirely — a step no security-conscious distributor wants to teach a grandmother. The mechanism explains the symptom: an APE is, by design, a self-rewriting polyglot that extracts and executes a loader, which is behaviourally adjacent to what malware droppers do, and it cannot carry a conventional per-platform signature in its portable form because any post-signing modification (including the user’s own repacking, and including macOS’s first-run self-assimilation behaviour) breaks the signed byte range. Contemporary Cosmopolitan discussion records the same fight on the Windows side, with Tunney describing uploading each build to Microsoft’s security-intelligence service to request whitelisting after its hello-world executables were flagged. *Assessment, marked as synthesis:* signing friction is not a bug llamafile can patch; it is a standing tax the APE form pays to platform gatekeepers, partially payable per-release through whitelisting and per-user through override instructions.
4. **Single-model-per-file rigidity.** One bundled file, one model, one default configuration (§3.4). Experimentation — the normal first week of any local-LLM user’s life — means either a shelf of multi-gigabyte near-duplicates or retreat to the bare binary. There is no middle form (shared runtime, swappable weights, still one download) in the documented model.
5. **Update economics.** Every runtime fix, security patch, or new-architecture support release implies redistributing every bundled model artefact, or expecting users to perform ZIP surgery (§3.4). Mozilla.ai carries that cost centrally for its collection; an independent packager carries it alone. A vulnerable llamafile in the wild has no patch channel at all — it will run, faithfully and forever, with its original bugs, which is the dark side of the announcement’s “usable … forever” promise.
6. **Silent GPU fallback and first-run GPU fragility.** The documentation’s own diagnostic advice (§5.3) concedes that a llamafile can appear to work while quietly running on CPU, and that first GPU use can depend on a host compiler toolchain being present. For the non-technical audience, “it works but slowly, for reasons invisible to you” is a worse failure than a clear error.
7. **Platform asterisks inside the portability headline.** Windows is AMD64-only; OpenBSD support is a bounded version range; macOS GPU is ARM64-only; the bundled NVIDIA library omits older GPU generations and the IQ-quant kernels (those layers silently stay on CPU); the ROCm library is a separate download requiring a separately installed runtime; the 0.10 series is self-described as untested across the full matrix. “Runs everywhere” is true at the level of *starts and produces correct output*; it is not true at the level of *runs equally well everywhere*, and the gap lives exactly where support burden lives.
8. **Shell-prologue brittleness at the margins.** The troubleshooting page documents Unix-side failure modes that follow from the polyglot design: older `zsh`/fish and Python `subprocess` paths mishandling the Thompson-shell prologue, and Linux `binfmt_misc` registrations (including Wine’s) misrouting APE files, repairable by registering an APE handler. Each is minor; together they mean the first run — the moment the whole value proposition is staked on — has more distinct failure modes than a native binary’s first run.
9. **No management plane, deliberately.** No updates, no catalogue, no health reporting, no remote anything. For fleets, classrooms, or any deployment where someone is *responsible* for many copies, llamafile gives that person nothing to hold. This is listed as a weakness because the corpus’s reader is building a runner people will operate, and should see the cost of llamafile’s purity stated plainly: everything Ollama’s daemon and registry do, llamafile’s distributor and recipient must do by hand.

---

## 8. Ideas to steal for a Go runner

Each idea is stated with what a Go-based, Ollama-improved runner would gain and what it would cost or risk. The through-line, stated once here so it does not have to be repeated under each item: **Go cannot steal the APE mechanism.** A Go binary is a native binary for one operating system and one architecture; `GOOS`/`GOARCH` cross-compilation produces *many* files, not one polyglot file, and Go’s runtime, its syscall layer, and its linking model offer no equivalent of Cosmopolitan’s symbolic-syscall libc or of the PE/shell polyglot header. Any proposal that begins “we will ship one Go binary that runs on all platforms” is false at the toolchain level. What *is* stealable is llamafile’s set of *decisions* — about what an artefact is, what travels inside it, and what the recipient is never asked to decide — re-implemented with Go-honest mechanisms: a small matrix of per-platform binaries, an embedded or sidecar payload format, and a resolver that makes the matrix invisible to the user.

### 8.1 Distribution as a feature: one artefact, zero install

*Steal:* Treat “the thing you download is the thing that runs, with nothing to install and nothing to configure” as a headline feature with an engineering budget, not as packaging afterthought. Concretely for a Go runner: a single self-contained executable per platform (Go already produces these naturally), weights obtainable as *one* file in *one* format, and a first run that needs no flags. Where llamafile fuses weights into the binary, the Go analogue is a *self-extracting or self-describing bundle* — for example, the runner plus a standard archive payload appended or embedded via Go’s embed mechanisms for small assets, or a documented runner-plus-GGUF pair presented to the user as a single download with a single name.

*Gain:* The recipient-side decision count collapses toward llamafile’s zero. Support burden collapses with it: “it doesn’t work” reports arrive with the artefact’s identity attached, not with an unknown combination of installer, version, and model pull.

*Cost / risk:* Go’s per-platform reality means the *publisher* maintains a build matrix (at minimum linux/amd64, linux/arm64, darwin/arm64, darwin/amd64, windows/amd64) and the *download page or resolver* must pick correctly — the exact choice llamafile deletes. Appending payloads to a Go binary also re-opens the signing wound (§8.4): a modified-after-signing binary is an unsigned binary on macOS and Windows. Budget for the matrix and the resolver as permanent infrastructure, or do not claim the feature.

### 8.2 Versioning honesty: fuse the runtime and the weights’ *requirements*

*Steal:* llamafile’s deepest lesson is not “embed the weights” but “make version skew impossible to express”. A Go runner can obtain most of that without embedding gigabytes: bind each model artefact to the exact runner contract it needs — format version, template, required features, tested runner range — in a manifest *inside* the model artefact (GGUF already carries metadata; a sidecar manifest in the same archive is the fallback), and have the runner refuse or loudly warn on mismatch instead of producing subtly wrong output. Publish pre-built “known-good pairs” (runner build + model file, hashed together) as the default download, exactly as Mozilla.ai labels each pre-built llamafile with its bundled server version.

*Gain:* The largest class of local-LLM support failures — template drift, format drift, silent quality regression after an auto-update — becomes either impossible or immediately diagnosable. Reproducibility claims (“this artefact produced this paper’s results”) become checkable.

*Cost / risk:* Refusal is a user-visible failure where silent degradation was previously (perversely) “working”. The manifest contract must be versioned and tooled from day one, or it becomes a second, worse versioning system layered on the first. And the fused-pair download reintroduces llamafile’s update economics (§7) in proportion to how literally the pairing is enforced: soft pairing (warn) is cheap, hard pairing (only blessed pairs run) is llamafile-priced.

### 8.3 The `.args` lesson: ship the working invocation inside the artefact

*Steal:* A defaults block, in the artefact, in plain text, one setting per line, with an explicit splice point where the user’s own flags override or extend it. For a Go runner this is a small embedded defaults file in the model bundle (or a defined GGUF metadata mapping), parsed before CLI flags, with the splice/override semantics documented in one paragraph. The packager who tuned the model — quantisation, context, sampling, projector, GPU offload — ships that tuning *as data*, and the recipient’s zero-flag run reproduces it.

*Gain:* “Just run it” becomes true for models whose good behaviour depends on non-default settings, which is most multimodal and many reasoning models. It also creates a natural place for per-model serving defaults in a multi-model runner: the model carries its own.

*Cost / risk:* Defaults are code for security purposes — a hostile bundle whose defaults bind a server to all interfaces, enable tools, or point at unexpected files is an attack, and llamafile’s own documentation warns about exactly this class for its built-in tools. A Go implementation needs an allowlist of bundle-settable options (sampling and context: yes; host binding, tool enablement, filesystem paths: no, or only with explicit user confirmation), plus a way for a user to *see* the effective configuration. Without the allowlist, do not ship the feature.

### 8.4 Design for the gatekeepers from the start

*Steal:* llamafile’s troubleshooting page is a map of where unsigned, self-modifying, loader-extracting artefacts die: Gatekeeper verification, CrowdStrike-style endpoint protection, Windows whitelisting. A Go runner should invert llamafile’s position deliberately: ship *conventional, per-platform, code-signed and (on macOS) notarised* native binaries, keep the binary immutable after signing (payloads and weights as separate files or as data the binary reads, never as bytes appended to the signed image), and treat “first run on a stock Mac / a corporate Windows laptop” as a tested release gate.

*Gain:* The entire §7 friction class — the overrides, the whitelist requests, the “temporarily disable all checking” instructions — is avoided rather than documented. This is the one place where Go’s boring per-platform nativeness is a competitive *advantage* over APE, and it should be claimed as such.

*Cost / risk:* Signing identities, notarisation pipelines, and certificate custody for five platforms are real, recurring operational costs, and they conflict with user-repackable artefacts (§8.2’s surgery story). The resolution is architectural: sign the *runner*, hash the *payload*, verify the payload against a signed manifest at load — integrity without immutability of the combined artefact. That design work is the price; skipping it and appending to a signed binary is the failure mode.

### 8.5 The ZIP lesson: use a standard container everyone can inspect

*Steal:* Whatever bundle format a Go runner adopts for “model + defaults + manifest”, make it a format the user’s existing tools can list and extract — a ZIP (or tar) with a documented layout, page- or block-aligned weight entries if memory-mapping from inside the archive is wanted, in the spirit of `zipalign`’s alignment insight. Go’s standard library reads ZIP natively, including locating entries in a file whose front is something else, which makes a “runner-readable, user-inspectable” bundle cheap to implement honestly.

*Gain:* Debuggability, extract-and-repack upgrade paths (ship a new runner, keep the weights — llamafile’s surgery path, but as a *supported* flow), third-party tooling for free, and no format-lock-in argument against adoption.

*Cost / risk:* Alignment-for-mmap constrains how entries can be compressed (weights must be stored, not deflated, to map in place — true for GGUF in practice, since quantised weights compress poorly anyway) and ZIP64 handling for >4 GB entries must be tested explicitly on every platform, especially Windows. A bundle that only the runner can open correctly is worse than no bundle.

### 8.6 Runtime dispatch instead of build proliferation

*Steal:* llamafile’s microarchitecture dispatch (§2.2) — compile the hot kernels in several variants, detect CPU features at startup, pick the best — as the answer to “which optimised build should the user download?”. Go narrows this idea but does not eliminate it: Go code can do runtime feature detection and select among implementations, and assembly or vectorised paths can be gated the same way llama.cpp gates AVX2/AVX-512. Even where the *inference core* is a cgo or subprocess llama.cpp/GGML build rather than pure Go, the *packaging* lesson holds: one artefact per OS/arch containing all microarchitecture variants, dispatched internally.

*Gain:* The download matrix stays at OS/arch granularity (five-ish artefacts) instead of exploding into per-CPU variants, and old hardware degrades to a correct slower path instead of an illegal-instruction crash — provided a documented minimum floor (llamafile’s “AVX required, refuses otherwise” is the honest pattern: a clear error beats a crash).

*Cost / risk:* Binary size grows with each variant, test matrix grows combinatorially (OS × arch × microarch × GPU backend), and Go’s own SIMD reach is limited compared with C intrinsics — the realistic Go-runner form of this idea lives in the native inference library it wraps, which reintroduces the build-system complexity the Go layer was meant to hide. Claim the packaging property; do not claim Go-native kernel parity.

### 8.7 CPU dignity and the old-hardware constituency

*Steal:* The positioning, backed by llamafile’s best modern data point: a first-class CPU path, honestly benchmarked, that keeps older and GPU-less machines useful — and a compatibility story (old OS versions, odd platforms) treated as a feature worth a release gate. Mozilla.ai’s benchmark found the field within a few percent *because* everyone shares llama.cpp; the differentiator it accidentally documented was that llamafile still *ran* on the ten-year-old machine. For a Go runner, Go’s own modest system requirements and static binaries make this constituency unusually reachable.

*Gain:* A user segment the GPU-first runners structurally abandon, plus resilience positioning (“your model still runs”) that compounds with §8.2’s archival story.

*Cost / risk:* Supporting old targets caps the features and dependencies the runner can adopt (newer OS APIs, newer GPU stacks) and every “it runs on a Pi / a 2015 laptop” claim must be paid for in continuous testing on exactly such hardware, or it rots into the kind of untested-matrix asterisk listed in §7.

### 8.8 What *not* to steal

For completeness, three llamafile properties a Go runner should consciously decline: (1) *the polyglot itself* — unimplementable in Go (§8 preamble) and the root of the signing/AV tax (§7); (2) *hard fusion as the only form* — llamafile itself retreats to the bare binary for large models, which is an admission that the fused form is a special case, not a default; a Go runner should make the *paired bundle* (§8.2) the special, delightful case and the managed multi-model runner the default; (3) *no management plane* — llamafile can afford it because Mozilla.ai curates centrally and recipients are individuals; a runner aspiring to be operated, updated, and trusted over time needs the update and provenance machinery llamafile omits, built in from the start rather than bolted on.

---

## 9. Sources

All web sources accessed 2026-11-15. Publication dates are given where the source states them. Primary sources are listed first in each group.

**Project and Mozilla primary sources**

- llamafile README, mozilla-ai/llamafile (`main`, GitHub) — project definition, quick start (Qwen3.5 0.8B Q8_0 example), Windows 4 GB note, 0.10 new-build-system note, Licensing section. https://github.com/mozilla-ai/llamafile/blob/main/README.md
- Stephen Hood (with Justine Tunney), “Introducing llamafile”, Mozilla Hacks, 29 November 2023 — first release, llama.cpp + Cosmopolitan combination, GPU/`dlopen()` work, Apache-2.0 / MIT licence statement, reproducibility argument. https://hacks.mozilla.org/2023/11/introducing-llamafile/
- “llamafile: bringing LLMs to the people, and to your own computer”, Mozilla Builders, 14 December 2023 — local-AI framing, privacy/access/control argument, six-OS claim. https://builders.mozilla.org/llamafile-bringing-llms-to-the-people-and-to-your-own-computer/
- “llamafile Returns”, Mozilla.ai blog, 29 October 2025 (as republished/summarised at TechCratic, 31 October 2025, and indexed by USASI) — Mozilla.ai adoption, refresh commitment, continuity for existing users. Original at blog.mozilla.ai (slug: llamafile-returns).
- llamafile documentation, docs.mozilla.ai (read 2026-11-15): “Technical details” (shell-script/`mmap()` overview, ZIP alignment and `zipalign`, microarchitectural dispatch, dual AMD64/ARM64 builds and the APE loader, `assimilate`, static-linking/GPU-module design); “Supported Systems” (OS/CPU floors, GPU backends and library search order, 0.10 testing caveat, IQ-quant and ROCm notes); “Creating llamafiles” (APE/ZIP container, `.args` format and `/zip/` prefix, `zipalign` workflow, provenance recommendations); “Running a llamafile” (CLI / chat / server / combined modes, external-weights equivalence, tool and templating options); “Source installation” (Cosmopolitan compiler 4.0.2, build outputs including the upstream server binary and `zipalign`); “Troubleshooting” (CrowdStrike whitelisting, macOS Gatekeeper section, `binfmt_misc` and shell-prologue issues, Windows 4 GB and WSL notes). https://docs.mozilla.ai/llamafile
- Davide Eynard, Anushri Gupta et al., “Benchmarking llama.cpp vs llamafile vs LM Studio vs Ollama: What Moved Throughput”, Mozilla.ai blog, 17 September 2026 — controlled comparison (llamafile 0.10.6, llama.cpp b10441, Ollama 0.34.0), few-percent prompt-processing parity, fixed per-token host costs, CUDA-graphs +16.8% and Vulkan-toolchain +63% configuration effects, ten-year-old MacBook Pro compatibility result, explicit list of unmeasured metrics (load time, time-to-first-token, memory, power). https://blog.mozilla.ai/benchmarking-local-llm-servers-llama-cpp-llamafile-lm-studio-and-ollama/
- Mozilla.ai organisational pages (llms.txt / open-tools listing, last updated 14 October 2026) — Mozilla.ai mission language and llamafile’s listing as a local-first open tool / “sovereign AI” enabler. https://www.mozilla.ai/

**Cosmopolitan / APE primary sources**

- Justine Tunney, “Actually Portable Executable”, justine.lol, 24 August 2020 (with later updates noted on the page, including “APE is now licensed ISC”, 28 December 2020) — Thompson-shell/PE polyglot discovery, published header skeleton (`MZqFpD=' …` prologue, ELF re-exec, qemu fallback), ZIP-at-the-end synthesis, symbolic-syscall ABI concession, example sizes (12 KB / 16 KB). Read via the author’s page mirror. https://justine.lol/ape.html
- Cosmopolitan Libc project (jart/cosmopolitan, GitHub) — referenced for the `ape` loader, `assimilate`, and `dlopen` implementations named in llamafile’s technical details.

**Performance-era sources (classic line)**

- Phoronix, “Llamafile 0.8 Releases With LLaMA3 & Grok Support, Faster F16 Performance”, April 2024 — 0.8 release notes: MoE 2–5× on CPU, F16 gains on Pi 5 / Skylake / M2 with before/after figures. https://www.phoronix.com/news/Llamafile-0.8-LLaMA3
- Phoronix, “Mozilla’s Llamafile 0.8.2 Scores Big With New AVX2 Performance Optimizations”, 2024 — K-quant AVX2 prompt-processing speedups (1.4–2.3× in the PR; 1.2–2.0× as reported by Tunney). https://www.phoronix.com/news/Llamafile-0.8.2-More-AVX2
- Justine Tunney, llama.cpp pull-request discussion for MoE prompt-evaluation speed (April 2024, via GitHub issue/PR mirrors) — `mixmul` decomposition, Threadripper / M2 Ultra / Pi 5 figures, tinyBLAS quant coverage.
- Hacker News discussion of the llamafile 0.7 release (April 2024) quoting the release notes — 30–500% prompt-evaluation range vs. upstream, AVX-512 / Zen 4 claim. https://news.ycombinator.com/item?id=39887263
- Hacker News thread, “What is the upgrade path for a Llamafile?” (January 2024), including Tunney’s reply — re-download vs. unzip-extract-and-repack upgrade paths. https://news.ycombinator.com/item?id=38824864
- The Register forum coverage of llamafile CPU performance gains, 3–4 April 2024 — contemporary third-party reporting of the 30–500% range.

**Contemporary and secondary sources (used for context, flagged as secondary in the text)**

- Simon Willison, “llamafile is the new best way to run an LLM on your own computer”, 29 November 2023. https://simonwillison.net/2023/Nov/29/llamafile/
- The New Stack, reporting on Mozilla.ai’s strategy and CEO interview, 25 November 2025 — Mozilla.ai’s reset toward a sustainable public-benefit product organisation; llamafile named in its open tool line.
- Help Net Security / Phoronix-line coverage of llamafile 0.10.0, 20 March 2026 — rebuild description, GPU-restoration timeline (Metal December 2025, CUDA on Linux February 2026), Windows GPU gap at launch, `cosmocc` 4.0.2 target. Treated as secondary; where it conflicts with current documentation, the documentation governs (§2.4).
- USASI, “llamafile: license, openness & source code”, fact-reviewed 1 October 2026 — secondary licence review (Apache-2.0 / MIT split; Mozilla Foundation named in `LICENSE` — marked second-hand in §1.1) and supported-systems summary.
- Mozilla.ai Blueprints, “Build your own local social media algorithm” (last updated 14 March 2025) — llamafile used as the local embeddings server in a published Mozilla blueprint.

**Unverifiable / not established in this sweep** (see also §1.1 and §5.3): no primary-source controlled measurement isolating APE packaging overhead; no primary-source llamafile cold-start / time-to-first-token benchmark; no independent third-party replication of the classic-era 30–500% prompt-evaluation claims; the exact `LICENSE`-file copyright line was confirmed only second-hand; pre-built collection size extremes beyond the README’s 0.8B example are documented in secondary coverage (~19 GB for the 27B file) rather than in a primary catalogue page read for this dossier.

---

*Dossier OR-2, Ollama Research Forge. Written in the author’s own words from the sources above; no source text is reproduced beyond short factual labels, flag names, and file-format markers necessary to identify the mechanisms described. Speculation is marked as speculation where it appears.*
