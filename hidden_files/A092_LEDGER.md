# A-092 Ledger - NPU hello-compute (team-22)

- Date: 2026-11-13 (EST, purpleraider local)
- Machine: purpleraider - ASUS ROG Flow Z13, AMD Ryzen AI Max+ 395, XDNA 2 NPU [0000:c5:00.1], aie2p 6x8, firmware 1.1.2.65, XRT 2.25.00
- Worktree: /home/volmarr/aesir-team-22, branch yrsa/aesir-team-22, base d67e0773 (banked main, 88 of 216)
- Verdict: PASS - one real matmul executed on the NPU, verified exact vs the CPU oracle. First AIE kernel execution claimed in this project; A-007/A-016/A-091 proved presence, buffers and census only.

## Acceptance mapping
- Real matmul on the chosen stack: IRON/mlir-aie design (the roadmap named AIE kernel path) compiled with Peano, executed through system XRT (A-007 native road). C = A @ B, 64x64x64, int16 in, int32 out, one AIE compute tile, tile 32x32x32.
- Oracle: exact integer equality on all 4096 elements vs an independent in-program CPU oracle (int64 accumulate) - stronger than the tolerance wording. 3 of 3 runs PASS, identical checksum 16383547698108786409.
- Device-execution evidence: live device name from the XRT handle (NPU Strix Halo), xclbin uuid 4cbcd846-4818-a373-e0e7-3c8048631b1c, run.wait() returned ert_cmd_state 4 (ERT_CMD_STATE_COMPLETED), output buffer pre-filled with sentinel 0x7fffffff and 0 sentinels remained after sync-back.
- Corroboration: vendor xrt-smi validate all PASSED on the same BDF (gemm 3.7 TOPS, latency 65.0 us avg, throughput 93723 op/s) - a092_validate2.log. The 3.7 TOPS figure is the vendor test number, not an Aesir benchmark.

## Toolchain stand-up (no system packages, no Docker)
All in scratch/a092/ of this worktree (uncommitted, about 700 MB of wheels and sources):
- mlir_aie 1.4.5 cp314 wheel (Xilinx/mlir-aie GitHub release v1.4.5): aiecc, aie-opt, IRON Python API.
- llvm_aie nightly wheel (Xilinx/llvm-aie, asset dated 2026-11-13): Peano clang for AIE kernel objects. No proprietary Chess used (use-chess 0).
- pip --target scratch deps: cloudpickle 3.1.2, ml_dtypes 0.6.0, numpy 2.5.4.
- mlir-aie v1.4.5 source tarball: the single-core matmul design, filed verbatim at spikes/a092_npu_hello/design_single_core.py (AMD, Apache-2.0).
- XRT headers from Xilinx/XRT branch XRT-2.25 (src/runtime_src/core/include only) plus a version-slim header generated from the repo template with version (2, 25); host runner links the installed /usr/lib/x86_64-linux-gnu/libxrt_coreutil.so.2 directly because no unversioned linker symlink exists without the dev package.
- Host runner: aesir_engine/npu_matmul_probe.cpp (A-016 pattern). Build transcripts a092_build4.log (design, exit 0) and a092_hostbuild7.log (host, exit 0) in hidden_files; earlier failed attempts remain in scratch logs.
- Design build output: final.xclbin 9935 B sha256 83e47803a9f30c5b5c89ed102999a37808adc78043d2d06af3b38afda029dd47; insts.bin 660 B / 165 words sha256 94ed9afbef70871fc3c4e46db4b029f7e41ec78e7e666e18e3ede62e0a8f77f2. Binaries stay in scratch, hashes here, per repo hygiene.

## Runs (sudo -n; A-007 memlock caveat stands, limit never changed)
- a092_run1.log: sudo xrt-smi examine header + run 1 PASS (mismatches 0, sentinel_remaining 0, ert_cmd_state 4, exit 0).
- a092_run2.log: runs 2 and 3, both PASS, identical checksum, exit 0.
- Coordination: seat gate A-090 was live at tick start; no suite or heavy build ran until ps showed it finished. Team-23 (A-093) showed no conflicting NPU tool use in its CAMPAIGN_STATE.md; this team NPU use is recorded in its own CAMPAIGN_STATE.md outcome.

## VTD validate (roadmap named first step)
- a092_validate.log: first attempt failed as A-091 recorded - archive amdxdna/bins/xrt_smi_strx.a absent. The helper named in the error text is not on this machine (a092_vtd_install.log).
- Fetched the archive from Xilinx/VTD (archive/strx/xrt_smi_strx.a, 66826978 B, sha256 1d3a9b2195619c40e5e9303d61a0c399385ba178cff29482d8d3aa861f4af35d) and placed it in the documented per-user XRT data dir for the sudo user, /root/.local/share/xrt/2.25.00/amdxdna/bins/ - a data archive, not a package install; no package state changed. Validate then passed (above).

## Dead ends filed honestly
- IRON Python host runtime imports pyxrt - absent; its only packaged form is the system package python3-xrt, which this slice must not install. Worked around with the C++ host runner.
- FastFlowLM xclbins use the same MLIR_AIE DPU signature (inspected with xclbinutil), but the instruction stream is supplied by its runtime at run time, not stored in the xclbin, so they cannot run a controlled matmul standalone. Not used (per A-091 warning).
- XRT master headers drift from the installed 2.25 API; the XRT-2.25 branch headers match. The runner uses the xclbin-object flow (construct, register, hw_context by uuid).

## Suite (E-MASTER, solo, this worktree)
- hidden_files/a092_run_all.log via hidden_files/run_a092.sh (seat-gate shape, target gfx1151): 602 passed / 1 failed / 2 skipped / 605 total - identical to the base baseline. Sole failure: pre-existing gguf.tensor_directory_interface (J-022 drift). No named intermittents appeared; no re-run needed. This slice adds no run_all cases (probe requires sudo plus the scratch toolchain; A-016 precedent), pin stays 605.

## Next work (recorded, not done here)
- A-093 (team-23) can treat NPU kernel execution as proven and probe BO/dma-buf sharing against a live kernel path.
- A-094 has a working stand-up recipe (this ledger) for measuring larger and whole-array matmul shapes.
- Open roads: python3-xrt install (system package, needs an order permitting it), memlock limit raise (Volmarr ruling), run_all wiring (needs a sudo-free run path first).
