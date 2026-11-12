# A-055 — SPIR-V build pipeline

Wave 7 opener (Part III — GPU Compute via Vulkan). All Vulkan compute
kernels are now compiled at build time from GLSL sources versioned in
this repository, embedded as SPIR-V words in a generated header, and
recorded with SHA-256 hashes in a manifest. Nothing is fetched at
runtime or at build time.

## Pipeline

`scripts/build_shaders.py` (Python 3, stdlib only):

1. Fail-closed tool check: `glslangValidator` and `spirv-val` must be
   present on the host; otherwise the build stops before any compile.
2. For every `aesir_engine/shaders/*.comp` (sorted, auto-discovered):
   compile twice with `glslangValidator -V --target-env vulkan1.0`,
   validate each output with `spirv-val --target-env vulkan1.0`, and
   byte-compare the two outputs — a kernel's hash is recorded only
   after determinism is proven for that kernel.
3. Emit the versioned artefacts:
   - `aesir_engine/shaders/generated/<name>.spv` per kernel,
   - `aesir_engine/shaders/generated/aesir_shaders_spv.h` — embedded
     `uint32_t` arrays (`k<Name>Spv` / `k<Name>SpvBytes`) plus the
     `kAesirShaders` registry table (name, words, bytes, sha256),
   - `aesir_engine/shaders/SHADER_MANIFEST.json` — per-kernel source
     SHA-256, SPIR-V SHA-256, byte/word counts, SPIR-V version word,
     and the recorded toolchain versions.

`scripts/build_shaders.py --check` regenerates into a temp directory
and verifies the in-repo artefacts match a fresh build byte-for-byte
(clean-checkout verification). `scripts/build_matrix.sh` runs the
pipeline inside `stage_shims()`, so every suite build recompiles the
shaders first and fails if the pipeline fails.

## Kernels built (8)

| Kernel | Home slice | SPIR-V bytes | SPIR-V SHA-256 |
|---|---|---:|---|
| vec_add | A-015 (existing) | 1608 | b228710b1f464b3aa810a4d4cb73e67f2325fdf1eabaa2ceb6b2cf73309ce15b |
| gemv_f32 | A-055 foundation | 2224 | 658061666ecb1c85a9b8d2d5d7a4804ad0c47eb2c6648b92d251fad26c6e907b |
| rmsnorm | A-060 foundation | 3984 | b23cb30bc450a41d97e447c608063a7498b5df218ac95c4702a54c1187d3c7ae |
| rope | A-060 foundation | 2880 | 5de79760b84c0ca6bbe0ce773241b5fc6a5e260c1a98e86f560e10665da50768 |
| elementwise | A-061 foundation | 2868 | 804583081f7299d73d96d78ce565a276f51f64db815e6756d8512860d33170ca |
| softmax | A-061 foundation | 4552 | 706162baf9e9194a8ea5f3e558bd6bbe00acbce026bd7cd1487b6a95e482c1cc |
| attention_decode | A-062 foundation | 5348 | 53e44cae0bbf15d5381c2866b28b6493b266fb75c9a77e2a6bb47cd145c16981 |
| sampling_greedy | A-063 foundation | 3788 | a381ed5a989591d9854a8384c7d80ce33a9c3f04a075cd5c33cf77d71f1486db |

The quant GEMV kernels (A-056 Q8_0, A-057 Q4_K, A-058 Q6_K/Q5_K,
A-059 IQ) land as new `.comp` files in their own slices and are
picked up by this pipeline automatically; each of those slices
re-records the manifest. The foundation kernels carry the generic
float interfaces those slices are judged against (push-constant
shapes, max-subtraction softmax, lowest-index greedy tie-break
matching the CPU sampler policy).

## Consumer change

`aesir_engine/vulkan_buffer_shim.c` no longer hand-pastes the
vec_add SPIR-V words: it includes
`shaders/generated/aesir_shaders_spv.h` and uses the generated
`kVecAddSpv` / `kVecAddSpvBytes`. The generated module is
byte-identical to the A-015 hand-embedded array (same SHA-256,
above), so the A-015 dispatch behaviour is unchanged — and the
suite's `gpu.vulkan_dispatch_*` cases now execute pipeline-built
SPIR-V on the RADV device (device-execution evidence per law 6:
RADV STRIX_HALO identity asserted, llvmpipe rejected, in
`test_vulkan_dispatch.mojo`, unchanged from A-015).

## Toolchain recorded

- glslangValidator: Glslang Version: 11:16.4.0 (GLSL 4.60, SPIR-V 1.0 target env vulkan1.0)
- spirv-val: SPIRV-Tools v2026.3
- Host: purpleraider (ASUS ROG Flow Z13, Radeon 8060S / RADV STRIX_HALO)

## Acceptance

- Pipeline builds all wave kernels from a clean checkout: proven by
  `--check` against a fresh regeneration and by the build-matrix
  wiring (see the A-055 ledger for the clean-copy run).
- Shader hashes recorded: `SHADER_MANIFEST.json` (table above mirrors
  it; values read from the manifest, not memory).
- Suite: five new `gpu.spirv_pipeline_*` cases pin the manifest, the
  recorded hashes, the embedded header, the no-fetch discipline, and
  the toolchain record.
