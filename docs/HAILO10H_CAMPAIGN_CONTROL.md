## Slice 123 — Specify bounded staging memory (complete; size remains unknown)

A future Hailo data path must account for a fixed, configurable ceiling covering input, output, descriptor, and any in-flight staging buffers. Admission must reject a request before allocation if its verified byte requirements exceed that ceiling. Buffer lifetime and reuse must be tied to correlated device completion; backpressure must stop new submissions rather than grow memory without bound. The numerical ceiling must come from documented module/driver limits and measured Æsir operation shapes, not the Pi’s RAM total or product-level onboard-memory headline.

Because no compliant Hailo operation/transfer path or tensor format is established, no staging size can yet be calculated or implemented. This is a design requirement only; it does not move LLM work to the CPU.

Evidence: Slices 114–116 and 121–122; H019 elements 2–4; Raspberry Pi AI HAT+ 2 public memory specification.
