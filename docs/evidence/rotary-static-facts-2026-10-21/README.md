# Static rotary facts,2026-10-21

Five synthetic vector primitives and18 static frequency tables were observed
through qualified Transformers4.57.1 public callables and installed Torch2.11CPU.
The test process registered a global Module.forward prehook that raises; no
forward hook fired, no model was instantiated and no source weights loaded.
No model/layer/attention forward, inference proxy or device program was used.
No external implementation was copied or translated into production.

Previously reviewed licenses: Transformers Apache2 SHA77fd4710def9ec3c0f6225800e0235f15a425abd4a8b03559127fcd782612049;
Torch primary BSD/bundled notices SHAa0d7abc10248a062a2f309bf12981524973f2a61aadccf4c5099d96d8c388cf4.
The global package directory is exposed only during Torch import, then removed.
A scratch directory exposes just Torch and its metadata plus sympy/mpmath to
the pinned configuration environment. No global installation/config was changed.
The original no-Torch configuration-only oracle remains separate and unchanged.

The five rotate_half/apply_rotary_pos_emb cases identify split-half pairs:
(j,j+R/2), with positive rotation first'=first*cos-second*sin and
second'=first*sin+second*cos. This qualifies these callables/version, not every
source architecture or GGUF convention. Numerical default-frequency observations
are consistent with ideal theta**(-2*j/R) but not exact real arithmetic: maximum
relative discrepancy2.919510495560376e-7. An initial2e-7 comparison assertion
failed; it is explicitly retained in the checks report. No finite-precision
backend qualification follows from this measurement.

Initial import failed on an optional sklearn/scipy dependency. Narrowing visible
packages then exposed missing sympy; both failures remain. The final run passed.
Full8MB traces remain in the task work archive, with exact identities here.
The final trace has zero connect calls and no Hailo device opens. Torch libraries
were intentionally loaded only for the isolated static primitive oracle.

Primary mathematical concept reference:
https://arxiv.org/html/2104.09864v5 (RoFormer, CC BY-NC-ND distribution notice).
Only mathematical facts were consulted; no paper prose/figure/code is copied.
Qualified configuration interface:
https://huggingface.co/docs/transformers/v4.57.1/en/model_doc/smollm3
This is a test oracle, never an Aesir runtime or user dependency.
