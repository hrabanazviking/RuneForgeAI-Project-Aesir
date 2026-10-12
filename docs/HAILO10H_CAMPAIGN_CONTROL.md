## Slice 115 — Assess tensor precision and quantization evidence (complete; model contract unknown)

The selected TinyLlama source uses FP16 weights and FP16 intermediate buffers in its host implementation, with FP32 accumulation in several kernels and FP32 attention scores/softmax before conversion to FP16. That describes Æsir’s existing ARMVEGR code, not a verified Hailo-10H tensor contract. Official Raspberry Pi AI HAT+ 2 material reports 40 TOPS INT4, but a performance specification does not establish accepted external tensor dtypes, per-layer quantization scales, accumulator precision, or a no-HEF execution route. H019 requires exact tensor descriptors and quantization fields; those remain unknown.

Result: no precision or quantization mapping is approved for Hailo. Do not infer INT4 model compatibility from TOPS claims; require public technical documentation and a Hailo proof before defining a chip contract. No model was executed.

Sources: armvegr/infer.mojo; armvegr/gemv.mojo; armvegr/gemm_tuned.mojo; docs/plunder/HAILO_CONFIG_SURFACE.md; https://www.raspberrypi.com/documentation/accessories/ai-hat-plus.html.
