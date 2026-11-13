# A-091 Ledger - XDNA 2 capability census (team-21)

- Date: 2026-11-13 (EST, purpleraider local)
- Machine: purpleraider - ASUS ROG Flow Z13, AMD Ryzen AI Max+ 395, XDNA 2 NPU, 121 GiB
- Worktree: /home/volmarr/aesir-team-21, branch yrsa/aesir-team-21, base 6396cd62 (banked main, 86 of 216)
- Deliverable: docs/bench/A091_XDNA2_CENSUS.md - every claim marked OBSERVED / DOCUMENTED / NOT OBSERVED / DERIVED.
- Method: XRT tooling on this machine (sudo -n for xrt-smi; unprivileged blocked by RLIMIT_MEMLOCK 8192 kB, re-verified fresh) + AMD documentation survey (UG1529 XDNA2 rows govern over Versal AIE-ML v2 where they differ). NO Docker. No code changes; doc-only slice, suite pin stays 600.

## Tool evidence (filed logs)
- a091_probe1.log: lspci [1022:17f0] rev 11, /dev/accel/accel0, amdxdna loaded, firmware files, ulimit -l = 8192, dpkg XRT 2.25.0-4ubuntu1 x4, xrt-smi + xclbinutil present, aiecc absent.
- a091_xrtsmi.log: unprivileged examine FAILS mmap len=67108864 EAGAIN exit 1; sudo examine exit 0: XRT 2.25.00, amdxdna 7.3.0-10-generic, firmware 1.1.2.65, [0000:c5:00.1] NPU Strix Halo aie2p 6x8; --report all adds Total Columns 8, no hardware contexts, Power Mode default, 0.002 W estimated, temp N/A.
- a091_probe2.log: sudo xrt-smi validate exit 1 - archive amdxdna/bins/xrt_smi_strx.a not found (VTD archive absent; A-092 first step). Filesystem find: FastFlowLM xclbins present under /opt/fastflowlm/share/flm/xclbins/ (third-party, corrects A-016 then-true no-xclbin record). Stack survey: libonnxruntime C libs only; no aiecc/aie-opt, no Vitis/Ryzen-AI packages.
- a091_probe3.log: FastFlowLM xclbin tier listing (mm/attn/vision per tier); python3 import onnxruntime FAILS (no module); python3 import xrt FAILS (no pyxrt).
- a091_probe4.log: xrt-smi examine JSON attempt (needs -o; plain text reports used instead) + repo grep showing roadmap A-091 text and Part I/II evidence boundary (NPU kernel execution still missing, road A-092).

## Census headline
OBSERVED: aie2p, topology 6x8, Total Columns 8 (xrt-smi, sudo). DOCUMENTED: 32 compute tiles 8x4 (AMD FOSDEM 2025; Taka et al.); 48 total tiles is DERIVED only. No NPU compute claimed or run.

## Documented-source survey (web, 2026-11-13)
UG1529 Basic Types XDNA2 row (int4/8/16/32, bf16, fp32, complex; bfp16ebs8/16 block vectors for matmul only; fp16 column blank for XDNA2; MX formats AIE-ML v2 only); UG1529 mmul modes; AM020/UG1603 per-tile memory 64 KB compute / 512 KB memory tile; MLIR-AIE programming guide (npu2 = Strix/Strix Halo/Krackan, AIE2P; shim row 0, mem row 1); Ryzen AI release notes (STX formats); AMD Max+ 395 product specs (50 TOPS, precision basis unstated); FOSDEM 2025 slide (32 TOPS INT8 at 1 GHz on array).

## Suite (E-MASTER, solo, this worktree)
- hidden_files/a091_run_all.log via hidden_files/run_a091.sh (seat-gate shape, target gfx1151): 597 passed / 1 failed / 2 skipped / 600 total - IDENTICAL to base baseline. Sole failure: pre-existing gguf.tensor_directory_interface (J-022 drift). No intermittents appeared; no re-run needed. Doc-only slice: pin stays 600, no cases added.
- Note: the launching device.invoke hit the ~125 s node timeout; the suite process survived on-device and completed (verified via log MOJO_EXIT line + SUMMARY block read from the log file).
