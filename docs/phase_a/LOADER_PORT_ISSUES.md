# Loader Port Issues (H008)

Blocking issues found during the ARM64 loader port check. Filed per H008
acceptance criteria — not silently worked around.

## ISSUE-1: GGUFSeer does not compile under Mojo 1.1.0 (toolchain drift)

**Severity:** Blocking (for any GGUFSeer use under the current toolchain)
**ARM64-specific:** NO — reproduces identically on x86_64 and ARM64.

`aesir_engine/loader/gguf.mojo` line 4:

```mojo
from std.collections import Dict, InlineArray
```

`InlineArray` was removed from `std.collections` in Mojo 1.1.0. It is not
available under any other std path either (`std.collections.inline_array`
does not exist — verified on-device 2026-10-10).

The only use is `aesir_engine/loader/gguf.mojo` line 415:

```mojo
var stat = InlineArray[UInt64, 18](fill=0)
```

**Reproducer (x86_64, forge, Mojo 1.1.0 via pixi):**

```
cd ~/workspace/RuneForgeAI-Project-Aesir/aesir_engine
# with a harness importing loader.gguf:
pixi run mojo build harness.mojo
# -> loader/gguf.mojo:4:35: error: package 'collections' does not contain 'InlineArray'
```

Same error on Mimir (ARM64, native Mojo 1.1.0).

**Why not fixed in H008:** the slice authorizes only *additive ARM64-specific*
fixes to loaders, and the repo hard law is additive-only. Replacing
`InlineArray` is a modification to an existing domain driven by toolchain
drift (not by ARM64), so it belongs to a 1.1.0-migration slice, not to the
port check. The port check was re-scoped (SÓLRÚN audit): a standalone
pure-Mojo GGUF header parser verified ARM64 parse correctness instead —
see `data/phase_a/loader_port_check.json` (byte-identical x86_64 vs ARM64
on all 3 test files).

## SCOPE FINDING (not a failure): Hladgerð has no implementation

The roadmap names "GGUFSeer, Hladgerð" as the existing loaders. **Hladgerð
does not exist** — no module, struct, or function by that name anywhere in
the repo. It appears only as a named domain ("Weight Management | Weight
loading, quantization, conversion") in `ENGINEERING_DOCTRINE.md`,
`TESTING_PROTOCOL.md`, `GIT_DISCIPLINE.md`, and the roadmap itself.

Consequence: the safetensors half of H008 cannot run, and Aesir currently
has **no safetensors parsing capability at all**. Implementing a safetensors
loader (whether named Hladgerð or not) is new work for a later campaign,
not a port-check fix.
