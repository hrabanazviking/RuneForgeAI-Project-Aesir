# H002 — Cross-Compile Recipe: Mojo x86_64 → aarch64 (Mimir)

**Status:** VERIFIED WORKING (2026-10-10). Two independent clean runs produced
bit-identical binaries that run on Mimir with identical output checksums.
Full command log: `data/phase_a/toolchain_cross_attempt.log`.

## When to use this

H001 (native Mojo on the Pi) works, so this recipe is the documented fallback —
the project is never single-pathed. Use it when the forge (x86_64) must produce
Pi binaries: batch builds on the fast machine, ship to Mimir, run.

## Prerequisites (all verified present)

| Item | How obtained |
|---|---|
| x86_64 Linux build host ("forge") | existing machine |
| pixi 0.81.0 (`~/.pixi/bin/pixi`) | pre-existing install |
| Mojo 1.1.0 via pixi, channel `https://conda.modular.com/max`, `platforms = ["linux-64"]` | `pixi.toml` in `~/mimisbrunnr-x86/mojo_xcompile`; `pixi install` resolves it |
| `aarch64-linux-gnu-gcc` 13.3.0 (Ubuntu) | **system package**: `apt-get update && apt-get install gcc-aarch64-linux-gnu` |
| aarch64 Mojo runtime libs (see table below) | **copied files**: pulled from Mimir's own pixi env (see "Runtime libraries") |
| Mojo source using `def` (Mojo 1.x removed `fn`) | project convention |

**Gotcha:** run mojo via `pixi run mojo ...` from the pixi project dir. Invoking
the mojo binary directly fails to locate the stdlib (`use of unknown
declaration 'Int'` / `'print'`) — the pixi environment activation is required.

## Runtime libraries — every one accounted for

The cross-built binary's complete runtime closure on Mimir (measured with
`ldd` on the Pi, 2026-10-10 — nothing left as "it just worked"):

| Library (as resolved on Mimir) | Direct or transitive | How obtained |
|---|---|---|
| `libKGENCompilerRTShared.so` → `~/mojo-dev/.pixi/envs/default/lib/` | **direct** (only `.so` on the mojo link line) | **copied file**: pulled from Mimir's pixi env via device `file.read` (64 KiB chunks, gzipped for transfer), 1200128 bytes |
| `libMSupportGlobals.so` → Mimir pixi lib | transitive (DT_NEEDED of KGEN) | **copied file**: same pull method, 49504 bytes |
| `libAsyncRTRuntimeGlobals.so` → Mimir pixi lib | transitive (DT_NEEDED of KGEN) | **copied file**: same pull method, 668584 bytes |
| `libstdc++.so.6` → Mimir pixi lib | transitive | **already on target**: ships inside Mimir's pixi env, resolved via rpath |
| `libgcc_s.so.1` → Mimir pixi lib | transitive | **already on target**: ships inside Mimir's pixi env, resolved via rpath |
| `libc.so.6`, `libm.so.6`, `libdl.so.2` → `/lib/aarch64-linux-gnu/` | transitive | **system libraries**: part of the Pi's Debian userland, resolved by the system loader |
| `/lib/ld-linux-aarch64.so.1` (interpreter) | — | **system**: Pi's dynamic loader |

The three copied files were verified after reassembly with `file` (all report
`ELF 64-bit LSB shared object, ARM aarch64`) and their byte sizes match
Mimir's originals exactly. They are needed **at link time on the forge**
(the cross-linker must see aarch64 objects); at **run time on Mimir** the
identical files are already present in the pixi env and are found through the
baked-in rpath — so they do **not** need to be shipped alongside the binary.

## The recipe (copy-pasteable)

```bash
# 1. On the forge, in the pixi project dir, codegen for aarch64.
#    The final host link WILL fail — that is expected; we only need the .a.
cd ~/mimisbrunnr-x86/mojo_xcompile
mkdir -p /tmp/xbuild/ccwrap
cat > /tmp/xbuild/ccwrap/cc <<'EOF'
#!/bin/bash
# PATH-shadowing wrapper: log mojo's link line, rescue the archive, then fail
# through to the real cc exactly as mojo would.
echo "ARGS: $@" > /tmp/xbuild/ccwrap/args.log
for a in "$@"; do
  case "$a" in
    *.a) cp "$a" /tmp/xbuild/ccwrap/saved.a && echo "SAVED_A: $a" >> /tmp/xbuild/ccwrap/args.log ;;
  esac
done
exec /usr/bin/cc "$@"
EOF
chmod +x /tmp/xbuild/ccwrap/cc
PATH=/tmp/xbuild/ccwrap:$PATH ~/.pixi/bin/pixi run mojo build \
  --target-triple aarch64-unknown-linux-gnu -o /tmp/xbuild/hello_raw hello.mojo
# -> "error: failed to link executable" (expected); saved.a now holds the objects.

# 2. Cross-link by hand. Take mojo's captured link line and substitute:
#      cc -> aarch64-linux-gnu-gcc
#      <forge-pixi-lib>/libKGENCompilerRTShared.so -> <aarch64 copy of it>
#      rpath -> Mimir's pixi lib dir (this is the RUNPATH baked into the binary)
AARCH64_LIBS=/tmp/mimisbrunnr/forge-xlibs   # the three pulled .so files
aarch64-linux-gnu-gcc /tmp/xbuild/ccwrap/saved.a \
  "$AARCH64_LIBS/libKGENCompilerRTShared.so" \
  -Xlinker -rpath -Xlinker ~/mojo-dev/.pixi/envs/default/lib \
  -o /tmp/xbuild/hello_aarch64 -Wl,--gc-sections -lm
file /tmp/xbuild/hello_aarch64
# -> ELF 64-bit LSB pie executable, ARM aarch64 ...

# 3. Ship to Mimir. gzip first (the binary is mostly zero padding: 72 KB -> ~5 KB),
#    then one device file.write with sha256, then unpack and verify on the Pi.
gzip -k -9 /tmp/xbuild/hello_aarch64
# device file.write: data_b64=<base64 of hello_aarch64.gz>, path=/tmp/mimisbrunnr/hello_aarch64.gz,
#                    final=true, sha256=<sha256 of the .gz>
# on Mimir:
#   cd /tmp/mimisbrunnr && gunzip -f hello_aarch64.gz && chmod +x hello_aarch64
#   sha256sum hello_aarch64   # must match the forge's sha256
#   ldd hello_aarch64         # every line must resolve (see table above)
#   ./hello_aarch64           # expected output, exit 0
```

## Re-runnability proof

2026-10-10, two clean runs from scratch (fresh `mojo build`, fresh manual
link, fresh transfer):

| | Run 1 | Run 2 |
|---|---|---|
| Forge binary sha256 | `5dd85437…27ce9` | `5dd85437…27ce9` — **bit-identical** |
| Mimir stdout sha256 | `060c7a9c…0af0e` | `060c7a9c…0af0e` — **match** |
| Exit code | 0 | 0 |

(Full hashes in `data/phase_a/toolchain_cross_attempt.log`.) The toolchain is
deterministic for this input: the `.a` archives were byte-identical across runs
too (5160 bytes each).

## Known limitations

- Only `libKGENCompilerRTShared.so` appears on mojo's link line today; if a
  future Mojo program's link line names other runtime libs, pull their aarch64
  copies from Mimir the same way and add them to the manual link.
- The rpath is absolute to Mimir's pixi env
  (`~/mojo-dev/.pixi/envs/default/lib`). If that env moves, relink with
  the new path (or extend the recipe with `$ORIGIN`-relative libs).
- One transfer mishap is recorded honestly in the attempt log (a hand-chunked
  zero-padding segment was over-sent by 12 bytes; the device rejected the next
  chunk, and the run was redone via the gzip path). The gzip path is the
  recommended one: fewer chunks, sha256-verified, no manual counting.
