# 08 — Mojo Toolchain and Workflow

*Version reflected: **Mojo 1.1.0 (stable, September 17, 2026)**. Every command, flag, and package name below was taken from an official Mojo page opened on 2026-10-19: the install page, system requirements, the CLI reference, the manual’s packages and packaging pages, the quickstart, and the get-started tutorial. Where the current toolchain differs from what older tutorials describe, this file says so — that difference is the main reason this file exists.*

## 1. How Mojo is distributed now

The 1.1.0 install page opens with the sentence that defines the current era: “Mojo installs exactly like a Python or Conda package on macOS and Linux.” There is no separate SDK installer in the documented flow, and no Modular account step. Mojo arrives as a package named `mojo` inside an environment managed by a Python/Conda-style tool, and the `mojo` command-line tool arrives with it.

Name the older eras only to quarantine them. Earlier distribution went through a Modular CLI, then through `magic`, then through `pixi`-first flows. The current install page presents **none** of the Modular CLI or `magic`: it presents two tabs, **`uv`** and **`pixi`**, and the quickstart summarizes the requirement as “Install Mojo in a `pixi` or `uv` environment.” A tutorial whose first step is a Modular CLI or `magic` command describes a superseded distribution, whatever its other merits.

Two adjacent offers on the same page are part of the modern workflow: the **VS Code extension** (from the VS Code Marketplace and the Open VSX Registry) “for syntax highlighting, code completion, and debugging support”; and **Mojo agent skills**, installed with `npx skills add modular/skills`, which “keep your AI coding assistants aligned with the latest language updates and best practices.” In a language that removed real syntax at 1.1, that second offer is Modular’s own answer to stale training data.

## 2. System requirements

The requirements page states the platform story in one line: “Mojo runs on Mac, Linux, and Windows (with WSL). You don’t need a GPU to program with Mojo — GPU support is optional.” Note the precision: the install page scopes its install to macOS and Linux; the requirements page adds Windows **with WSL**. Do not shorten that into “Mojo supports Windows” without the qualifier.

- **OS:** Linux with glibc 2.34 or later (e.g. Ubuntu 22.04 LTS or later — Modular tests on Ubuntu 22.04 LTS or later, expects other distributions meeting the glibc requirement to work, and suggests a container with a compatible base image on older systems); Mac; Windows with WSL.
- **CPU:** x86-64-v3 (Haswell-class or newer, roughly 2013 onward) or ARM64 Neoverse N1 or newer (e.g. AWS Graviton2 and later) on Linux; Apple silicon on macOS. The x86-64-v3 requirement does not apply to ARM64 or Apple silicon hosts.
- **RAM:** 8 GiB minimum for Mojo development. MAX inference and model serving require significantly more, varying by model.
- **Software:** a C compiler such as `cc`, `gcc`, or `clang` on Linux, used as a linker; Xcode or Xcode Command Line Tools 16 or later on macOS.
- **GPU (optional):** GPU programming across NVIDIA, AMD, and Apple silicon GPUs, with per-vendor driver and hardware tables on the requirements page. Treat that page, not this summary, as authoritative for any specific card: it distinguishes “continuously tested” from “known compatible” hardware, and documents fallbacks such as setting `MODULAR_NVPTX_COMPILER_PATH` to a system `ptxas` for older NVIDIA drivers.

## 3. Installing Mojo 1.1.0

### 3.1 With `uv` — the flow the install page spells out

```bash
# If needed, install uv:
curl -LsSf https://astral.sh/uv/install.sh | sh

# Install Mojo into the current environment:
uv pip install mojo

# Or create a project and install Mojo into it:
uv init hello-world
cd hello-world
uv add mojo
```

For the latest nightly instead of stable, the install page directs you to switch to the nightly docs rather than improvise a flag. The releases page shows what that means: on the day consulted, the nightly was `mojo==1.2.0.dev2026101405`, against stable `mojo==1.1.0`. Pin a nightly only deliberately.

### 3.2 With `pixi`

The install page offers `pixi` as the second tab, and the quickstart treats the two environments as equivalents. The `pixi` mechanics documented across the current Mojo and MAX pages are consistent: install `pixi` (`curl -fsSL https://pixi.sh/install.sh | sh` — the command the packaging guide uses), create a project, add the package, run commands through the project environment, and enter it with `pixi shell` when you want an activated shell.

The GPU tutorial shows the project shape in full — installing the `max` package rather than bare `mojo`, because it needs “the Mojo compiler and the MAX accelerator library where the GPU APIs live”:

```bash
pixi init gpu-intro \
  -c https://conda.modular.com/max-nightly/ -c conda-forge \
  && cd gpu-intro
pixi add max
pixi run mojo --version
pixi shell
```

Two lessons transfer to a plain Mojo project. First, verification is `mojo --version` **inside the project environment** (`pixi run mojo --version`), not a global lookup. Second, a tutorial’s package name is part of its requirements: `pixi add max` there is not a typo for `mojo`. For a language-only project, follow the install page’s `mojo` package; for GPU/MAX work expect `max` (or `max-all` / `max[all]` with pip or uv, per the same tutorial, when you also want the rest of the developer tools and the serving and benchmarking commands).

### 3.3 Verify, then run the quickstart

Either way, the documented sanity check is `mojo --version` — the CLI reference confirms it (also `-v`) “prints the Mojo version and exits.” Then confirm the toolchain end-to-end with the quickstart’s first program: create `analyzer.mojo` containing a `def main():` that prints, and run `mojo analyzer.mojo`. The quickstart’s takeaway is the right acceptance test: if you see the program’s output, “your setup works,” and “all Mojo executables use `main()` as their entry point.”

## 4. Project layout: files, modules, packages

- **A program** is a `.mojo` file with a `main()` function. The get-started tutorial builds Conway’s Game of Life this way: a `life.mojo` importing a `Grid` type from a sibling `grid.mojo`.
- **A module** is a single `.mojo` file containing code for other files to import — typically structs and functions, and typically **without** a `main()`. The manual’s example defines a `MyPair` struct in `mymodule.mojo` and imports it from `main.mojo` in the same directory with `from mymodule import MyPair`. Importing the whole module (`import mymodule`, optionally `as` an alias) is also documented.
- **The hard edge:** in the manual’s words, “you can’t import `.mojo` files as modules if they reside in other directories” — unless that directory is treated as a package.
- **A package** is a directory of modules that includes an `__init__.mojo` file. “The `__init__.mojo` file is essential. If you don’t have it, Mojo won’t recognize the directory as a package and you can’t import `mymodule`.” The file may be empty; unlike Python, top-level code is not supported in `.mojo` files, so `__init__.mojo` cannot execute code on import — but it can define structs and functions, and, more idiomatically, re-export members (`from .mymodule import MyPair`) so callers can write `from mypackage import MyPair`.
- **Imports got stricter at 1.0/1.1:** the 1.0 notes overhaul the import system for explicit, consistent name resolution, and the 1.1 notes make intra-package access without an explicit `import` an error. Write the import you depend on, in every file, even inside your own package.

A minimal documented layout:

```text
main.mojo
mypackage/
    __init__.mojo
    mymodule.mojo
```

with `mojo main.mojo` working immediately from that directory. When a package must live elsewhere, the documented mechanisms are `-I <PATH>` on `run`, `build`, and `precompile` (“appends the given path to the list of directories to search for imported Mojo files”), or precompilation (§6.3).

## 5. The `mojo` CLI in 1.1.0 — the whole list

The CLI reference says the `mojo` CLI provides “all the tools you need for Mojo development, such as commands to run, compile, and precompile Mojo code,” and lists exactly eight subcommands:

| Command | Documented purpose |
|---|---|
| `mojo run` | Builds and executes a Mojo file. |
| `mojo build` | Builds an executable from a Mojo file. |
| `mojo repl` | Launches the Mojo REPL. |
| `mojo debug` | Launches the Mojo debugger, via the CLI or an external editor. |
| `mojo precompile` | Precompiles a Mojo package. |
| `mojo format` | Formats Mojo source files. |
| `mojo doc` | Compiles docstrings from a Mojo file. |
| `mojo demangle` | Demangles the given name. |

**There is no `mojo test` and no `mojo package` subcommand in the 1.1.0 CLI reference.** Testing is a standard-library matter (§7); distribution is a packaging-guide matter (§8). Older material presenting `mojo package` as the bundling path describes the pre-1.1 toolchain — and the 1.1 release notes remove support for `.mojopkg` files entirely. Two shorthands **are** documented: omit `run` (`mojo hello.mojo` runs the file) and omit `repl` (running `mojo` with no commands starts a REPL). Every subcommand accepts `--help` (e.g. `mojo precompile --help`); the top-level command also offers `--print-cache-location` and `--clear-cache` for the `.mojo_cache` compile cache (the latter asks for confirmation unless you pass `-f` / `--force`).

## 6. The daily commands

### 6.1 Run

`mojo run [options] <path> [path-arguments...]` “compiles the Mojo file at the given path and immediately executes it.” Options for the command must appear **before** the file path; anything after the path is passed to the Mojo program. The compilation options shared by `run`, `build`, and `debug` are the working vocabulary of Mojo performance work:

- `--optimization-level <LEVEL>` / `-O`: 0 to 3, **default 3**; `--no-optimization` means level 0.
- `-I <PATH>`: import search directory (above). `-D <KEY=VALUE>`: define a compile-time value readable through the `std.defines` module — `-Dfoo=42` makes `foo` queryable as `42`.
- `--debug-level <LEVEL>` / `-g`: `none`, `line-tables`, or `full`; default `none`, except under `mojo debug`, which defaults to `full`. The docs add that “there are issues when generating debug info for some Mojo programs that have yet to be addressed.”
- Target selection: `--target-triple`, `--target-cpu`, `--target-features`, `--target-abi`, `--march`, `--mcpu`, `--mtune`, and `--target-accelerator <ACCELERATOR>`, exemplified by `sm_90` for an NVIDIA H100 and `gfx942` for an AMD MI300. Discovery flags `--print-supported-targets`, `--print-supported-cpus`, `--print-supported-accelerators`, and `--print-effective-target` print the corresponding information and exit — use them instead of guessing an architecture string.
- Diagnostics and safety: `--Werror`; `--warn-on-unstable-apis` (directly relevant while the library’s stable subset is still growing); and the experimental `--sanitize <CHECK>` with values `address` (memory issues) and `thread` (multi-threading issues).

### 6.2 Build

`mojo build [options] <path>` compiles a Mojo file into an executable, saved by default to the current directory, named after the input file without its extension; `-o <PATH>` sets the output. `--emit` selects the output kind: `exe` (default), `shared-lib`, `object` (experimental), `llvm` (unoptimized LLVM IR), `llvm-bitcode`, and `asm` — for GPU targets, `asm` also emits a sidecar file per kernel: `.ptx` for NVIDIA, `.amdgcn` for AMD, `.ll` for Metal. That emit list is the documented inspection on-ramp (§7.3): when you need to see what the compiler produced, ask for it by name.

One warning from the `build` page belongs in every workflow note: “any Python libraries used in your Mojo project are not included in the executable binary, so they must be provided by the environment where you run the executable.” A built binary that calls into Python is not self-contained with respect to those libraries.

### 6.3 Precompile a package

`mojo precompile [options] <path>` “precompiles a directory of Mojo source files into a binary package suitable to share and import into other Mojo programs and modules.” Workflow: add `__init__.mojo` to the package directory, pass the directory, and name the output with `-o`:

```bash
mojo precompile mypackage -o mypack.mojoc
```

The output filename must end in `.mojoc` or `.mojopkg` per the CLI page, and the filename (minus extension) defines the importable package name — which is encoded in the file, so renaming means re-running `precompile`, not renaming the file. Without `-o`, a `.mojoc` file is generated in the current directory, named after the input directory. Where you see `.mojopkg` in that option list, hold it against the 1.1 notes, which remove `.mojopkg` support: **produce `.mojoc`.**

Understand what a `.mojoc` is and is not, because the docs state both halves. It **is** faster to build against than source, technically portable across systems (it contains only non-elaborated code; code becomes architecture-specific only after import into a program compiled with `mojo build`), and importable exactly as if it were the source package. It **is not** “intended as a distributable format, as it is tied to the version of the compiler that produced it” — loading it with a different compiler version errors. Precompilation is a build accelerator and internal sharing mechanism, not a release artifact. Releases go through §8.

### 6.4 Format, and `mojo doc`

`mojo format [options] <sources...>` “formats the given set of Mojo sources using a Mojo-specific lint tool.” Its documented options are deliberately small: `--line-length <INTEGER>` / `-l` sets the maximum line length, **default 80**, and `--quiet` / `-q` disables non-error messages. Run it before committing; expect it, not personal preference, to settle style arguments. (The manual’s basics page notes a preference for 4 spaces for indentation; the formatter is the enforceable version of that preference.) `mojo doc` “compiles docstrings from a Mojo file” — the basics page says you can generate an API reference from docstrings with it, while noting docstring conventions are “a topic we’ve yet to fully specify,” so do not over-promise a mature documentation pipeline on top of it.

## 7. Testing, benchmarking, debugging, and profiling

### 7.1 Testing and benchmarking live in the standard library

Since there is no test subcommand, the documented testing surface is the **`testing`** package in `std` — “Unit testing: Assertions (equal, true, raises) and test suites,” in the standard-library index’s words — alongside a **`benchmark`** package (“Performance benchmarking: statistical analysis and detailed reports”) and a `time` package offering monotonic clocks, performance counters, `sleep`, and `time_function`. The roadmap corroborates the shape: a testing framework and a benchmarking framework are listed as Phase 2 toolchain work **in progress**, located in the standard library. The packaging guide shows the pragmatic pattern in a recipe’s test step — tests are Mojo programs run with the ordinary runner: `mojo run test.mojo`.

The honest workflow statement for 1.1.0: write tests as Mojo code using `std.testing`, run them with `mojo run` (or through your project environment, e.g. `pixi run mojo …`), and benchmark with `std.benchmark` rather than hand-timing loops. Do not write `mojo test` into a script or tutorial and expect the 1.1 CLI to honor it.

### 7.2 Debugging: `mojo debug`

`mojo debug` launches the Mojo debugger, which “underneath uses the LLDB debugger, or cuda-gdb.” Four session modes are documented: build and debug a Mojo file (this mode defaults to `-O0` and `--debug-level=full`); debug a precompiled program; attach to a running process with `--pid <pid>` or `--process-name <process-name>`; and start the debugger CLI on its own. Interfaces: the debugger CLI by default, or — with `--vscode` — a VS Code debug session via the Mojo extension (VS Code must be running and the extension enabled). The capability split is worth memorizing: **LLDB is the default and “has great support for CPU Mojo code, but has no support at all for Mojo GPU code,”** while **cuda-gdb** (`--cuda-gdb`) “has minimal support for CPU Mojo code but it has support for GPU Mojo code,” and can step into GPU code at the cost of a degraded CPU experience. The page also notes the debugger can debug programs in other native languages such as Rust, C, and C++, because it is based on LLDB / cuda-gdb.

### 7.3 Profiling: what is, and is not, documented

No profiler subcommand appears in the 1.1.0 CLI reference, and the roadmap lists **Profiler** as a Phase 2 toolchain item that is **not started**. This file therefore documents no `mojo profile` workflow, because none was found in the official pages read. The documented performance workflow in 1.1.0 is instead: benchmark with `std.benchmark`; compile at a known optimization level (`-O` defaults to 3; use `-O0` deliberately for debugging, as `mojo debug` does); inspect generated output with `mojo build --emit` (`asm`, `llvm`, `llvm-bitcode`, plus GPU sidecars); and use `--sanitize address` / `thread` when the question is memory or concurrency correctness rather than speed. If a future release adds a profiler, this section is the one to rewrite first.

## 8. Packaging and distribution

Distribution in the current documentation is a **conda-package** workflow built on **rattler-build**. The packaging guide “explains how to turn your Mojo project into a distributable conda package using rattler-build,” publishable to any conda-compatible index — prefix.dev, anaconda.org, and an S3 bucket are named — with the greatest visibility in the **modular-community** channel on prefix.dev.

1. **Write `recipe.yaml`** — by convention at `conda.recipe/recipe.yaml` in the project root. It describes the source location, the build process (a `mojo precompile` command), dependencies, and test commands. The guide’s template places the library under `src/<package_name>/` with an `__init__.mojo`, alongside a `test.mojo`, a `LICENSE`, and a `README.md`.
2. **Mind the three recipe rules the guide singles out.** Use a full 40-character commit SHA as `source.rev`, so anyone building from the recipe gets the exact same source. Start `build.number` at 0, increment it (rather than the version) when rebuilding the same version — for example to pick up a new compiler release — and reset it to 0 on a version bump. Make the build script output the `.mojoc` into `$PREFIX/lib/mojo/`, because “this path is what makes the package auto-discoverable by the Mojo compiler.” Pin the compiler too: the recipe must specify the required `mojo-compiler` version in `requirements.build`, and `pin_compatible('mojo-compiler')` in `requirements.run` generates the matching run constraint, preventing a precompiled package from silently running against an incompatible compiler.
3. **Build with rattler-build**, installed via `pixi global install rattler-build` after installing `pixi`. The documented build invocation names its channels explicitly — `conda-forge`, `https://conda.modular.com/max` (for `mojo-compiler` and `max`), and the modular-community channel if you depend on other community packages. rattler-build then creates an isolated build environment, fetches the source, runs the build script to compile the `.mojoc`, bundles a `.conda` archive into an `output/` directory, and runs the recipe’s test commands. A failed build can be investigated in its documented debug shell (`rattler-build debug shell`).
4. **Publish** by uploading the `.conda` file to a compatible host — or, for modular-community, by opening a pull request to the modular-community GitHub repository adding your `recipe.yaml` under `recipes/<package-name>/`; the repository builds and hosts the package from the recipe. Users then install it with `pixi` by adding the channel to their project manifest (`pixi.toml`).

Note what this replaces: no `mojo package` step, no `.mojopkg` artifact, and no Mojo-specific registry in the current documented distribution path — the ecosystem rides on conda packaging, `pixi` manifests, and compiler-version pinning. The roadmap lists “Packaging and package management: To enable a vibrant ecosystem of Mojo libraries” as Phase 2 ecosystem work, which is why the current guide is a well-specified bridge rather than a finished package manager.

## 9. REPL, Jupyter, and interactive work

The REPL is documented, with a frank caveat. `mojo repl [lldb-options]` “launches a Mojo read-evaluate-print loop (REPL) environment, which provides interactive development in the terminal”; options are forwarded to the underlying LLDB tool, which runs the REPL; running `mojo` with no arguments starts it too. The same page then warns: **“the REPL has known issues and isn’t under active development. We don’t offer any REPL stability guarantees,”** and points to a forum discussion for its roadmap status. Use it for short experiments if it serves you, and build real work in files run with `mojo run` — which is how every official tutorial cited here proceeds. The quickstart (15–30 minutes) and the get-started Game of Life tutorial (45–60 minutes) are both file-and-terminal workflows with checkpoints, not notebook workflows.

On Jupyter, honesty is required: **no current official Jupyter or notebook workflow was found in the pages read for this file.** Older Mojo material did present notebooks, but presenting that as the 1.1.0 workflow without a current page behind it would violate this corpus’s accuracy rule. The interactive surfaces vouched for here are the REPL above, the VS Code extension, and the Mojo agent skills (`npx skills add modular/skills`). If Jupyter support is re-documented, add it here with its URL — do not restore it from memory.

## 10. A working day, end to end

```bash
uv init hello-world && cd hello-world   # pixi is the documented alternative
uv add mojo
mojo --version            # expect the 1.1.0 line on the stable channel

# Write code in a .mojo file with def main():, then:
mojo hello.mojo           # run shorthand — same as: mojo run hello.mojo
mojo format hello.mojo    # formatter decides style; default line length 80
mojo build hello.mojo -o hello
./hello

# Grow: split reusable code into a package
# (mypackage/__init__.mojo + mypackage/mymodule.mojo, import it explicitly),
# and precompile it when another project needs it as a dependency:
mojo precompile mypackage -o mypack.mojoc

# Test and measure with the standard library, not a test subcommand:
# std.testing for assertions and suites; std.benchmark for timings;
# run test programs with mojo run; debug with mojo debug (--cuda-gdb for GPU code).
```

Keep two version rituals attached to that day. When any outside snippet disagrees with the compiler, check the release notes for your version before changing code — 1.0 and 1.1 between them removed `fn`, `alias`, `@parameter if`/`for`, `.mojopkg`, implicit variable declaration, and the `read` convention, and each removal produces an error that looks like your mistake until you recognize it as a calendar. And re-read the install and CLI pages after any major release: distribution has already changed eras more than once in Mojo’s short life, and this file’s value is that it describes the era it names — 1.1.0 — and no other.

*Not verified in this session: a current official Jupyter workflow (see §9); any `mojo test` or `mojo package` subcommand (the 1.1.0 CLI reference lists neither — §5); a profiler command (the roadmap lists a profiler as not started — §7.3); and the contents of the install page’s `pixi` tab beyond the `uv`/`pixi` equivalence and the `pixi` mechanics documented on the packaging and GPU-tutorial pages cited below.*

## Sources

- https://mojolang.org/install/
- https://mojolang.org/docs/requirements/
- https://mojolang.org/releases/
- https://mojolang.org/docs/cli/
- https://mojolang.org/docs/cli/run/
- https://mojolang.org/docs/cli/build/
- https://mojolang.org/docs/cli/format/
- https://mojolang.org/docs/cli/repl/
- https://mojolang.org/docs/cli/precompile/
- https://mojolang.org/docs/cli/debug/
- https://mojolang.org/docs/manual/quickstart/
- https://mojolang.org/docs/manual/get-started/
- https://mojolang.org/docs/manual/packages/
- https://mojolang.org/docs/tools/packaging/
- https://mojolang.org/docs/manual/gpu/intro-tutorial/
- https://mojolang.org/docs/std/
- https://mojolang.org/docs/roadmap/
- https://mojolang.org/releases/v1.1.0/
