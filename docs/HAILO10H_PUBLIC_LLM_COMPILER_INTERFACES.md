# Public source-model compiler interface leads

Date: 2026-10-20. Contract: `TASK_hailo10h_llm_compile_interfaces.md`.

## Provenance and interpretation

Primary author repository `l-nmch/hailo-10h-llm-compiler` is frozen at
`c870419f7d6315e1277e06a9fa5eadd955b8e1af`. Its MIT license was read before
documentation/interface study. Hashes and the separately pinned official
HailoRT cross-checks are in
`docs/evidence/llm-compiler-interface-study-2026-10-20/`. External documentation
stays outside Git. No external implementation was copied/translated or run,
no compiled artifact inspected, no model downloaded and no device opened.

The author's initial forum post described incomplete KV generation; the pinned
repository now reports coherent generation on a small 25M checkpoint and
remaining numerical failures on larger checkpoints. These are author reports,
not independently reproduced Aesir evidence. Its status document separates
compilation/serving success from numerical fidelity. A successful compile or
response therefore cannot certify the owner's model-execution objective.
[Pinned status](https://github.com/l-nmch/hailo-10h-llm-compiler/blob/c870419f7d6315e1277e06a9fa5eadd955b8e1af/docs/status.md).

## Interface fact matrix

| Interface / requirement | Evidence class | Consequence / missing acceptance |
|---|---|---|
| DFC 5.3.0 LLM entry point named `set_kv_cache_global_params(prefill_size, cache_size)`; groups named `__prefill` and `__tbt` | Author-published interface report | Useful source-compiler lead; not an installed/officially verified API or numerical CCW specification. |
| Pipeline needs separately obtained proprietary compiler; documented wheel targets linux_x86_64 | Author dependency documentation | Root project MIT does not license the compiler. No DFC wheel is present/installed/accepted by this study, and ARM execution is unestablished. |
| Pipeline runs PyTorch export/reference checks, SDK emulation and numerical calibration/bias correction | Author documentation | Cannot run that pipeline under Aesir's no CPU/CUDA/cloud LLM-forward rule. Host compilation permission does not admit full-model calibration/reference execution. Static source/constant conversion remains allowed. |
| Reported explicit token-major conversion on both prefill/decode cache edges | Author hypothesis/fix and hardware report | Treat as a layout requirement lead, not copied conversion code or a hardware proof. Independently establish writer/reader agreement and source-head ordering. |
| Cache buffers are associated by cache ID across core operations; size mismatch rejects | Official public HailoRT declaration/receiver study | Compiler must preserve common cache identity/extent, not merely two equal-shaped graph tensors. |
| Cache I/O metadata derives entry information from features and a padded entry stride; backing volume includes spatial dimensions | Official public HailoRT metadata handling | Logical shape bytes do not establish actual stride. Preserve explicit key/value widths, stride, alignment and quantized representation provenance. |
| Ring offsets are entry-based; output region starts after the input-length window; server updates offset before generation | Official public HailoRT cache/server handling | Host control must distinguish read window, write slots, initialized data and absolute token/RoPE positions. No device data is read here. |
| Exact preprocessing key is `prefill_input_tokens_count`; cache size, query/KV head counts are separately named | Author report cross-checked with official LLM server | `_size` cannot substitute for `_count`. This is a particular receiver's resource schema, not a requirement to adopt its server or preprocessing. |
| RoPE K/Q widths may differ under GQA; source input declarations must match the chosen consumer | Author published observation, not independently established hardware layout | Existing semantic graph already keeps query/KV heads distinct. Do not adopt artifact-derived widths/permutations without a public or independently earned numerical contract. |

Author interface/dependency sources:
[pipeline](https://github.com/l-nmch/hailo-10h-llm-compiler/blob/c870419f7d6315e1277e06a9fa5eadd955b8e1af/pipeline/README.md),
[compiler availability](https://github.com/l-nmch/hailo-10h-llm-compiler/blob/c870419f7d6315e1277e06a9fa5eadd955b8e1af/docker/README.md),
[cache layout report](https://github.com/l-nmch/hailo-10h-llm-compiler/blob/c870419f7d6315e1277e06a9fa5eadd955b8e1af/docs/findings/tbt-cache-read.md),
[config key](https://github.com/l-nmch/hailo-10h-llm-compiler/blob/c870419f7d6315e1277e06a9fa5eadd955b8e1af/docs/findings/kv-cache-config-key.md),
[RoPE widths](https://github.com/l-nmch/hailo-10h-llm-compiler/blob/c870419f7d6315e1277e06a9fa5eadd955b8e1af/docs/findings/rope-input-widths.md),
[quantization scope](https://github.com/l-nmch/hailo-10h-llm-compiler/blob/c870419f7d6315e1277e06a9fa5eadd955b8e1af/docs/findings/quantization-recipe.md).

Official cross-checks use the already-read HailoRT MIT license at
`d503417f2a0db186a838390fb08690c4ea0f415e`:
[cache manager](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/src/core_op/resource_manager/cache_manager.cpp),
[cache declarations](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/libhailort/src/core_op/resource_manager/cache_manager.hpp),
[LLM server resource/offset interface](https://github.com/hailo-ai/hailort/blob/d503417f2a0db186a838390fb08690c4ea0f415e/hailort/hailort_server/genai/llm/llm_server.cpp).

## Independent next implementation

Build an original explicit token-major cache-address scenario from the dense
semantic graph under `TASK_hailo10h_cache_layout.md`. Preserve separate key and
value head widths, source graph/cache identity, row stride/alignment/pool
assumptions and provenance; prove relative slot/head/component mapping with
independent exhaustive small fixtures. This is compiler metadata/address
arithmetic, never host attention/model evaluation or actual physical layout
qualification. Ring mutation/masks and first numerical hardware operation are
separate subsequent work. The public reports identify a real integration gap;
they do not establish a numerical backend or authorize a catalog-only route.

The source-model target remains fixed. Continue actual numerical CCW/register
and placement discovery, original compiled output, owned upload/configure,
cache lifecycle and hardware result/cleanup. Any future compiler backend must
meet the Mojo ownership, licensing and no host LLM-forward requirements; the
external project's pipeline/server cannot simply be adopted as production.
