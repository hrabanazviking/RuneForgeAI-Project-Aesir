# A-091 — XDNA 2 capability census

Slice A-091 (Wave 11 opener, NPU first light). Capability census
of the XDNA 2 NPU in purpleraider (ASUS ROG Flow Z13, AMD Ryzen
AI Max+ 395, Strix Halo), from XRT tooling run on this machine
plus AMD documentation.

## Marking law (the acceptance rule for this slice)

Every claim in this census carries exactly one mark:

- **OBSERVED** — produced by tooling run on this Z13 during
  this census (2026-11-13), or by an earlier banked slice's
  filed evidence on this same machine (named per claim).
- **DOCUMENTED** — stated in AMD documentation or an
  AMD-authored source (named per claim). Documented is not
  observed: no documented figure below was measured here.
- **NOT OBSERVED** — the tool or evidence that would show it
  is unavailable on this machine today; filed as a gap,
  never guessed.
- **DERIVED** — arithmetic or composition of marked claims;
  the derivation is shown and it inherits the weaker mark.

## HEADLINE

The NPU is present, identified, and driver-healthy: XRT
reports architecture **aie2p, topology 6x8, 8 total columns**
(OBSERVED). AMD documents the XDNA 2 compute array as
**32 compute tiles (8 columns x 4 rows)** (DOCUMENTED) — the
figure that reconciles with the observed 6-row topology once
the documented shim row and memory-tile row are counted.
**No AIE kernel has run on this NPU in this census, and none
is claimed.** Kernel execution is A-092's acceptance, not
this slice's.

## 1. Identity and tooling (all OBSERVED, this census)

| Claim | Value | Source |
|---|---|---|
| PCI device | c5:00.1 AMD Strix/Krackan/Strix Halo NPU [1022:17f0] rev 11 | lspci, a091_probe1.log |
| Device node | /dev/accel/accel0 (root:render, user ACL rw) | ls, a091_probe1.log |
| Kernel driver | amdxdna loaded (in-tree, kernel 7.3.0-10-generic) | lsmod, xrt-smi |
| Firmware | NPU firmware 1.1.2.65 (files under /lib/firmware/amdnpu/17f0_11/) | xrt-smi examine, ls |
| XRT userland | 2.25.00, Ubuntu packages libxrt2 / libxrt-npu2 / libxrt-utils / libxrt-utils-npu 1:2.25.0-4ubuntu1 | dpkg, xrt-smi |
| xrt-smi examine (sudo) | [0000:c5:00.1] NPU Strix Halo, Architecture aie2p, Topology 6x8 | a091_xrtsmi.log |
| xrt-smi examine --report all (sudo) | Total Columns 8; AIE Partitions: no hardware contexts running; Power Mode default; Estimated Power 0.002 W; Temperature N/A | a091_xrtsmi.log |
| Unprivileged xrt-smi | FAILS: mmap len=67108864 EAGAIN; RLIMIT_MEMLOCK is 8192 kB vs the 64 MiB locked map XRT wants | a091_probe1.log, a091_xrtsmi.log |
| xrt-smi validate | CANNOT RUN: archive amdxdna/bins/xrt_smi_strx.a not found (Xilinx VTD archive absent) | a091_probe2.log |

The memlock wall is the A-007 caveat, re-verified fresh: all
NPU tooling in this census ran via sudo -n. Raising the user
memlock limit remains Volmarr's decision, not taken here.
The validate archive is A-092's first step by roadmap, not
this slice's; what validate would have shown is therefore
NOT OBSERVED.

## 2. AIE tile array

| Claim | Mark | Source |
|---|---|---|
| Array topology as the tool reports it: 6x8, 8 total columns, architecture aie2p | OBSERVED | xrt-smi examine (sudo), a091_xrtsmi.log |
| Compute tiles: 32, as an 8-column x 4-row array | DOCUMENTED | AMD FOSDEM 2025 slide (8x4 array of AIE tiles); Taka et al., Striking the Balance (AMD co-authors): XDNA2 contains 32 cores as a 4x8 array |
| Tile kinds: compute tiles run kernels; one memory-tile row (row 1, L2 scratchpad); one shim-tile row (row 0) bridges the array to main memory via shim DMA; data path is shim -> (mem) -> compute; each tile has its own DMA engine | DOCUMENTED | MLIR-AIE / IRON programming guide (AMD/Xilinx) |
| Total tile positions 48 = 32 compute + 8 memory + 8 shim | DERIVED (from OBSERVED 6x8 + DOCUMENTED row layout) | arithmetic shown; no AMD page fetched states 48 total for Strix Halo, so this is never presented as a directly documented or observed count |
| Per-SKU array differences across Ryzen AI Max 300 SKUs | NOT OBSERVED / not documented in sources fetched | all SKUs list the same NPU rating; no cut-down array was documented |

Headline, stated with its marks intact: **tile count is
6x8 / 8 columns as OBSERVED by XRT, and 32 compute tiles as
DOCUMENTED by AMD.**

## 3. Supported data types

| Claim | Mark | Source |
|---|---|---|
| Peak NPU rating: up to 50 TOPS (Ryzen AI Max+ 395); the product page does not state the precision basis for that figure | DOCUMENTED | AMD Ryzen AI Max+ 395 product specifications |
| 32 TOPS on the array for INT8 at 1 GHz, up to 50+ TOPS boosted | DOCUMENTED | AMD FOSDEM 2025 slide |
| Native vector types, XDNA2 row: int4/uint4, int8/uint8, int16/uint16, int32/uint32, bfloat16, float (fp32), cint16/cint32/cfloat; accumulators acc32..acc64 and accfloat | DOCUMENTED | AMD UG1529, AI Engine API, Basic Types (XDNA2 row) |
| fp16 is NOT a native XDNA2 vector type: the XDNA2 float16 column in UG1529 is blank (fp16 appears for Versal AIE-ML v2, a different architecture row) | DOCUMENTED | AMD UG1529, same table; do not import Versal AIE-ML v2 type support into this census |
| Block floating point is the XDNA2 specialisation: bfp16ebs8 / bfp16ebs16 block vectors (8/16-element blocks, shared 8-bit exponent), documented for matrix multiplication only, with no elementwise arithmetic support | DOCUMENTED | AMD UG1529, block-vector types |
| MX4/MX6/MX9 formats: listed for AIE-ML v2 only, NOT for XDNA2 | DOCUMENTED | AMD UG1529, same table |
| Software-visible formats (Ryzen AI software, STX = Strix + Strix Halo): CNN INT8 and BF16, NLP BF16; XINT8, A8W8, A16W8 quantisation; bfp16 activations | DOCUMENTED | AMD Ryzen AI software release notes |
| Any data type actually executed on this NPU | NOT OBSERVED | no kernel has run; execution proof is A-092 |

## 4. Supported ops

Kernel level (what a tile can be programmed to do):

| Claim | Mark | Source |
|---|---|---|
| Each compute tile is a VLIW/SIMD processor with a vector unit and a scalar unit; matrix multiplication via aie::mmul with XDNA2 modes including 8b x 8b, 8b x 4b, 16b x 16b, 32b x 32b, bfloat16 x bfloat16 and bfp16 x bfp16 | DOCUMENTED | AMD UG1529, Matrix Multiplication; AMD XDNA technology page |
| Spatial dataflow architecture: the array is programmed as a dataflow graph (kernels + explicit DMA movement), configured at run time; up to 8 concurrent isolated streams / hardware contexts is the architectural claim | DOCUMENTED | AMD XDNA architecture briefings as reported at the Zen 5 / XDNA 2 deep dive; IRON programming guide |
| Fixed-function Softmax / LayerNorm / RoPE / attention units | NOT DOCUMENTED as hardware primitives in sources fetched | such ops are kernels compiled onto tiles (IRON / Ryzen AI software), not fixed-function blocks; do not census them as hardware ops |

Framework level (what the installed software can dispatch):

| Claim | Mark | Source |
|---|---|---|
| Ryzen AI 1.2-era Vitis AI EP ONNX op list (convolution, Gemm, MatMul, pooling, elementwise, Softmax, etc., with CPU fallback for unsupported subgraphs) | DOCUMENTED (older, generic-NPU, not Halo-specific) | AMD Ryzen AI model-compatibility documentation v1.2 |
| A current, Strix-Halo-specific ONNX op list | NOT OBSERVED | no current Halo-specific list was found in AMD sources fetched |
| Any framework dispatching to the NPU on THIS machine | NOT OBSERVED | see section 6: no Vitis AI EP, no Python onnxruntime, no MLIR-AIE/IRON toolchain is installed |

## 5. Memory model

| Claim | Mark | Source |
|---|---|---|
| Compute-tile local (L1) data memory: 64 KB per tile; program memory 16 KB per tile | DOCUMENTED | AMD AIE-ML documentation (AM020/UG1603 lineage figures, confirmed for both XDNA generations by Taka et al.) |
| Memory-tile (L2) memory: 512 KB per tile | DOCUMENTED | same sources as above |
| On-chip total 6 MB (32 x 64 KB + 8 x 512 KB) | DERIVED | arithmetic from the documented per-tile figures and the derived 8 memory tiles; AMD does not state this total for Strix Halo in sources fetched |
| Movement is explicit and compiler-scheduled: per-tile DMA engines, buffer descriptors / ObjectFifos; no hardware cache coherence for tile scratchpads is documented | DOCUMENTED | MLIR-AIE / IRON programming guide; AIE-ML memory documentation |
| Host side: one unified LPDDR5X pool shared by CPU, GPU and NPU (UMA); this machine has 128 GB (MemTotal 127,396,532 kB) | DOCUMENTED (UMA, AMD workstation whitepaper) + OBSERVED (pool size, /proc/meminfo, a091_probe2.log) |
| XRT buffer objects live in host memory and round-trip through the device API on the real NPU handle: 4096-byte BO, byte-exact, 0 mismatches, BO types 1+2 (A-016, banked) | OBSERVED (earlier slice, this machine) | hidden_files/A016_LEDGER.md |
| NPU bandwidth to LPDDR5X, any NPU-specific memory carve-out, direct tile load/store reach across the full 128 GB | NOT OBSERVED / not documented in sources fetched | the documented up-to-96 GB Variable Graphics Memory figure is a GPU allocation, not an NPU one |
| Buffer sharing between NPU and CPU/GPU (dma-buf/BO sharing) | NOT OBSERVED in this census | that probe is A-093's acceptance, not this slice's |

## 6. Software stacks on this machine (all OBSERVED, this census)

| Stack | State | Evidence |
|---|---|---|
| XRT 2.25.00 userland + xrt-smi + xclbinutil | PRESENT | dpkg; which xrt-smi xclbinutil, a091_probe1.log |
| amdxdna kernel driver + firmware 1.1.2.65 | PRESENT, healthy | lsmod; xrt-smi examine |
| MLIR-AIE / IRON toolchain (aiecc, aie-opt) | ABSENT | which: not found, a091_probe2.log |
| Python XRT bindings (pyxrt / import xrt) | ABSENT | import fails, a091_probe3.log |
| Python onnxruntime module | ABSENT (C libraries libonnxruntime 1.23.2 are installed, but no Python module and no Vitis AI EP was found) | a091_probe2.log, a091_probe3.log |
| Ryzen AI software stack / Vitis AI EP | ABSENT | dpkg / pip survey, a091_probe2.log |
| xclbin files on the filesystem | PRESENT but third-party: /opt/fastflowlm/share/flm/xclbins/ ships prebuilt NPU2 xclbins (mm, attn, vision variants per model tier) belonging to the FastFlowLM install, not to XRT or to this project | ls, a091_probe2.log / a091_probe3.log; this corrects A-016's then-true record that no xclbin existed anywhere - they arrived with FastFlowLM after A-016 banked. Their presence proves nothing ran: no Aesir code has loaded one |
| Xilinx VTD validate archive (xrt_smi_strx.a) | ABSENT | xrt-smi validate error, a091_probe2.log |

## 7. What this census does NOT claim

- No compute executed on the NPU. No kernel, no matmul, no
  TOPS figure was measured. Every performance number above
  is DOCUMENTED, none is OBSERVED.
- No tile row was individually probed: xrt-smi reports the
  6x8 topology and the column count; the row composition
  (shim / memory / compute) is DOCUMENTED, not observed.
- Versal AIE-ML and AIE-ML v2 figures were used only where
  an XDNA2 source confirms them; where the generations
  differ (fp16, MX formats) the XDNA2 row governs.

## 8. Consequences for Wave 11

- A-092 (hello-compute) inherits two hard first steps, both
  already on the roadmap: fetch the Xilinx VTD archive so
  xrt-smi validate can run, and stand up a kernel toolchain
  (IRON/MLIR-AIE or the Ryzen AI stack) - neither exists on
  this machine today (OBSERVED, section 6).
- The FastFlowLM xclbins (OBSERVED present) are a possible
  existence proof that prebuilt NPU2 kernels ship for this
  silicon, but they are that product's kernels, not a
  general Aesir kernel path; A-092's stack choice must not
  silently inherit them.
- Every NPU run until Volmarr rules on the memlock limit
  goes through sudo (OBSERVED wall, section 1).
- The types A-094's op-fit analysis should target first are
  the documented native set: int8/int16/bf16 matmul and
  bfp16 block matmul (DOCUMENTED, sections 3-4). fp16 NPU
  matmul is not in the documented native set.

## Sources

Observed: hidden_files/a091_probe1.log, a091_probe2.log,
a091_probe3.log, a091_probe4.log, a091_xrtsmi.log (this
census, purpleraider, 2026-11-13); hidden_files/A007_LEDGER.md
and hidden_files/A016_LEDGER.md (banked slices, same machine).

Documented: AMD Ryzen AI Max+ 395 product specifications
(amd.com); AMD FOSDEM 2025 MLIR/IREE slide deck; Taka et al.,
Striking the Balance: GEMM Performance Optimization Across
Generations of Ryzen AI NPUs (arXiv 2512.13282, AMD
co-authors); AMD UG1529 AI Engine API User Guide (Basic
Types; Matrix Multiplication); AMD AM020 / UG1603 AIE-ML
memory documentation; MLIR-AIE / IRON programming guide
(xilinx.github.io/mlir-aie); AMD Ryzen AI software release
notes and model-compatibility documentation; AMD Ryzen AI
Max PRO workstation whitepaper (UMA).
