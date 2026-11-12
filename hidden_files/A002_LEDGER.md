# A-002 Ledger — Pixi environment + CPU build on the Z13

Slice: A-002 (Wave 1) — Project Aesir Z13 Massive Roadmap
Host: purpleraider (ASUS ROG Flow Z13, AMD Ryzen AI Max+ 395 / Radeon 8060S gfx1151, kernel 7.3.0-10-generic, Kubuntu)
Worktree: /home/volmarr/aesir-team-02, branch yrsa/aesir-team-02, base ba0cf066
Date: 2026-11-11 (EST)

## Acceptance verdict: PASS

- `pixi install` from the repo lockfile: exit 0.
- CPU build of the engine: succeeds (BUILD_EXIT=0, 0 compiler errors).
- Binary `--help` smoke: HELP_EXIT=0, full CLI help printed.

## Exact commands (in order, all run in /home/volmarr/aesir-team-02)

Environment (pixi binary is at ~/.pixi/bin/pixi, not on the default PATH):
  export PATH="$HOME/.pixi/bin:$PATH"
  pixi install            # manifest ./pixi.toml (name project_aesir), lockfile ./pixi.lock

Versions (inside the installed env; full `pixi list` in a002_versions.log):
  pixi run mojo --version   -> Mojo 1.0.0 (ed45d567)
  pixi run python --version -> Python 3.14.6
  pixi --version            -> pixi 0.76.2
  max 26.5.0, max-core 26.5.0, mojo 1.0.0 (from pixi list)

Native C shims (the exact recipe the CAPABILITY_LEDGER E-MASTER command uses;
the engine links these symbols: aesir_hailo10h_*, aesir_par_*, aesir_cpu_vnni):
  cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o /tmp/aesir-a002-shims/libaesir_hailo10h.so
  cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o /tmp/aesir-a002-shims/libaesir_par.so -lpthread

CPU build (final, attempt 4):
  pixi run mojo build -I . --target-accelerator gfx1151 -Xlinker -L/tmp/aesir-a002-shims -Xlinker -laesir_hailo10h -Xlinker -laesir_par aesir_engine/main.mojo -o /tmp/aesir-a002-cpu

Help smoke:
  pixi run env LD_LIBRARY_PATH=/tmp/aesir-a002-shims /tmp/aesir-a002-cpu --help   -> exit 0

## Build artifact

/tmp/aesir-a002-cpu — ELF 64-bit LSB pie executable, x86-64, 3,878,480 bytes,
sha256 cf626129ca78cccec4a2ddcfc0b307d74bd9df3775665470a2281b4e5c2b49bc

## Attempt history (all logs in this hidden_files/ directory)

1. a002_cpu_build.log — `pixi run mojo build aesir_engine/main.mojo` (the E-BUILD
   shape minus its NVIDIA flag): FAIL, `unable to locate module hailbru`
   (hailbru/ is a top-level package at repo root; needs `-I .`, as E-MASTER uses).
2. a002_cpu_build_attempt2.log — added `-I .`, no accelerator flag: FAIL at
   compile time. MAX std gpu/host/info constraint `Unknown GPU architecture
   detected`, reached via CUDAGate.launch_gemm_cuda -> CUDAF16GemmExecutor ->
   DeviceContext instantiation from core/compute.mojo gemm_f16_gpu. The engine
   has no comptime switch to exclude the CUDA gate, so MAX requires an explicit
   accelerator architecture at compile time on this host.
3. a002_cpu_build_attempt3.log — `-I . --target-accelerator gfx1151`: compiles,
   link FAIL (undefined aesir_hailo10h_* / aesir_par_* / aesir_cpu_vnni).
4. a002_cpu_build_attempt4.log — attempt 3 + the E-MASTER C shims linked:
   BUILD_EXIT=0, 0 errors (deprecation warnings only).

## Honesty notes

- NO NVIDIA target flags were used anywhere in this slice. The historical
  E-BUILD command pins `--target-accelerator sm_89`; A-002 forbids that.
- `--target-accelerator gfx1151` names this machine's own AMD iGPU arch. It is
  present only because MAX instantiates the (runtime-dormant, dlopen-probed)
  CUDA gate at compile time and refuses to compile with no arch on this host.
  It does not make this an accelerator run: the built binary is the standard
  engine, its verified runtime path on this host is the CPU GGUF path, and no
  accelerator execution is claimed (accelerator-visible != accelerator-run).
- The `--help` smoke runs inside the pixi env (Mojo runtime libs) with the
  shim dir on LD_LIBRARY_PATH; a bare-shell run of a Mojo binary exits 127
  (libKGENCompilerRTShared.so not found) — same for the pre-existing tracked
  aesir_main binary, verified by recon.
- Root pixi.toml vs aesir_engine/pixi.toml differ only in workspace name and
  the root's extra markdown-it-py pin; root lockfile pins platformdirs 4.11.3
  (engine copy 4.11.2). A-002 used the repo-root manifest/lockfile.

## Logs (on-device, gitignored *.log per repo policy)

a002_pixi_install.log, a002_versions.log, a002_cpu_build.log,
a002_cpu_build_attempt2.log, a002_cpu_build_attempt3.log,
a002_cpu_build_attempt4.log, a002_help_smoke.log
