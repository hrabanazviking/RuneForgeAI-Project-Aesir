## Slice 119 — Identify a minimum model only from proven Hailo operations (complete; no candidate selectable)

A model can be selected only after a measured Hailo operation set covers every required layer operation, tensor format, memory movement, and control step. The current verified Æsir-on-Hailo operation set is empty. Consequently no “smallest” LLM architecture can be responsibly selected or sized for this target under the present evidence: reducing parameter count does not remove the need for projections, normalization, attention, nonlinearity, output logits, and a legal chip configuration path.

Result: candidate selection is deferred; the existing TinyLlama source is only the repository’s model-operation reference and is not nominated as Hailo-compatible. Revisit after the first real Hailo operation and a complete model-op coverage matrix exist. No CPU LLM work was performed.

Evidence: Slices 107–118; docs/smidr/PHASE_D_GATE.md; CAPABILITY_LEDGER.md.
