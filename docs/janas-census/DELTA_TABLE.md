# The Delta Table — Janas's Documented Behaviours vs Aesir (J-013)

**Grades:** HAVE (Aesir has it, proof cited in `AESIR_LEDGER_CROSSCHECK.md`) · PARTIAL (Aesir has part; the gap is named) · IN-204 (the 204 road already owns it; the slice is named) · WANTED (this road builds it; the owning part is named) · REFUSED (named refusal with its reason). Frozen as **the Concordance** at the J-014 gate (see `GATE_RECORD.md`).

| # | Census row | Grade | Owner / reason / gap |
|---|---|---|---|
| 1 | Expert streaming from disk (models ≫ RAM) | WANTED | Part II |
| 2 | Expert cache: free-memory-sized + hard cap + reserve | WANTED | Part II (J-018) |
| 3 | O_DIRECT disk discipline, gentle degradation under load | WANTED | Part II (J-019/J-023) |
| 4 | Expert read-ahead prefetch (decode + prefill variants) | WANTED | Part II (J-025) |
| 5 | Cache-conditional dropping of light experts | WANTED | Part II — J-017's design must name it (gate note A1) |
| 6 | Bit-plane expert storage & partial-bit reads | REFUSED | A `.jns`-layout feature; inseparable from the format refused at row 66. GGUF offers no partial-bit expert reads; the pressure lever family lives at row 7 instead. |
| 7 | Quality tiers + measured per-model speed levers (head requant, fast attention) | WANTED | Part III — inside J-036's option surface (gate note A2) |
| 8 | Models larger than RAM (dense) | HAVE | Spill PROVEN token-identical (S-011) |
| 9 | Pass taxonomy (prompt ≥17 / draft-check 2–16 / reply 1) | WANTED | Part III (J-035) |
| 10 | Per-pass placement options (auto/single/co-work/race lists) + env equivalents | WANTED | Part III (J-036) |
| 11 | Device kill switches | PARTIAL | CUDA_VISIBLE_DEVICES discipline + in-code gates exist; no user-facing options. Gap closed by Part III (J-036). |
| 12 | Auto measured choice within tolerance of best | WANTED | Part III (J-038/J-046) |
| 13 | Thread-topology auto-trials + warm re-trials | WANTED | Part III (J-039/J-045) |
| 14 | Learned config persisted (tuning files, /save-config) | PARTIAL | Preferences persist (model_preferences); nothing is *measured*. Completed by Part III (J-044). |
| 15 | Per-model first-run tune measurement (drafts/bits rivals, ≥3% rule) | WANTED | Part III (J-038) |
| 16 | Power modes (auto/eco/max) | WANTED | Part III (J-036 surface) |
| 17 | GPU prompt products per quant type (fast prompt, group-rounded) | WANTED | Part IV (J-054) |
| 18 | Whole-layer dense GPU prompt path | PARTIAL | Gemma-4 CUDA full-path session proven; a prefill-shaped whole-layer path as a general class is Part IV (J-055). |
| 19 | Whole-pass GPU on discrete cards + VRAM expert tier | WANTED | Part IV (J-054 scope; tier meets Part II at J-031) |
| 20 | GPU self-check at open + wrong-shader diagnostics | WANTED | Part IV (J-053/J-060) |
| 21 | Reply-token agreement discipline across compute paths | HAVE | Aesir's standing grading (token-identity/faithfulness per arch; S-011 + wave RESULTS) |
| 22 | Vulkan GPU backend | PARTIAL | CUDA is Aesir's proven GPU road; the Vulkan question is decided by evidence at Part IV (J-066). |
| 23 | NPU prompt reading (dense whole layers, 8-bit copies) | WANTED | Part IV (J-061 design; J-063 conditional on hardware) |
| 24 | NPU split-block co-processing | WANTED | Part IV (J-064, conditional) |
| 25 | NPU resident-products placement (large/MoE) | WANTED | Part IV (J-061/J-065) |
| 26 | NPU preparation pass + progress + compiled-graph cache | WANTED | Part IV (J-061) |
| 27 | NPU memory-contention closure rule | WANTED | Part III/IV (J-048/J-065) |
| 28 | Speculative verification identity (text unchanged with drafts) | PARTIAL | Acceptance arithmetic validated in `core/speculative.mojo`; no integrated loop, no KV ownership. Completed by Part V (J-071–J-073). |
| 29 | MTP-head drafts | WANTED | Part V (J-077) |
| 30 | Assistant-model drafts (drafter reads main KV) | WANTED | Part V (J-078) |
| 31 | Cross-model drafts (same-vocab pair) | WANTED | Part V (J-074) |
| 32 | Conversation (prompt-lookup) drafts | WANTED | Part V — a third proposer inside J-072's loop (gate note A3) |
| 33 | Adaptive draft sizing + periodic re-trial | WANTED | Part V (J-079) |
| 34 | Acceptance measurement by text type | WANTED | Part V (J-075) |
| 35 | 8-bit KV cache | WANTED | Part VI (J-088) — Aesir KV is f16 today |
| 36 | Long-context strength measured to 32k | PARTIAL | Context 4096 proven; no ladder. Part VI (J-091) builds the ladder. |
| 37 | Sliding-window KV economy (Gemma) | WANTED | Part VIII (J-127) |
| 38 | Chat context sliding with recap summary | PARTIAL | History/autosave/recovery exist; recap-summarisation not evidenced. |
| 39 | Per-quant kernel bandwidth near memory speed | PARTIAL | IQ2_M scalar-decode defect found + fixed (S-030); no per-type bandwidth table published for Aesir. Evidence completed by Part IX (J-138). |
| 40 | IQ1/IQ2 quant support | HAVE | IQ2_M proven faithful; IQ1_S coherence-graded — parity NOT PROVEN BY CONSTRUCTION (S-029), an honesty class, not a gap |
| 41 | Terminal chat (editor, history, colours, status line) | HAVE | CLI REPL/TUI surface (44 cli modules) |
| 42 | Slash-command family incl. /save-config, /experts, /image | PARTIAL | Commands exist; /experts meaningless until Part II; /image rides the vision path (204 Part V). |
| 43 | Model picker with download + checksum | PARTIAL | Model selector exists; verified-download catalogue is Part VII (J-102/J-103). |
| 44 | `janas-get` (catalogue, resumable, fingerprint-checked) | WANTED | Part VII (J-103) |
| 45 | `janas-bench` configuration sweep + machine report | PARTIAL | Measurement kernels + campaign battery exist; no sweep/report tool. Part VII (J-100/J-101). |
| 46 | Progress + metrics surfaces (progress lines, JSONL events) | WANTED | Part IV (J-059) + Part VII (J-107) |
| 47 | Tool manners (strict option refusal w/ suggestions, env-typo detection, Ctrl-C semantics) | PARTIAL | Interrupts exist (cli/interrupts.mojo); refusal-with-suggestion manners not evidenced. Part VII (J-105). |
| 48 | OpenAI-shape HTTP API core (chat completions) | HAVE | `server/api.mojo` routes `/v1/chat/completions` |
| 49 | Full OpenAI surface (Responses, Files, Batches, Vector Stores, Evals, Assistants, Uploads) | PARTIAL | Core only. Audited and closed-or-kept by Part VII (J-106; gate note A4). |
| 50 | Embeddings endpoint | PARTIAL | Route exists (`/v1/embeddings`); no graded embedding parity. Part VII (J-106). |
| 51 | Server conversation prefix-reuse + cached_tokens accounting | WANTED | Part VII (J-106/J-107) |
| 52 | Served browser chat/test page | WANTED | Part VII (J-108) |
| 53 | Server security manners (API key, TLS, Origin refusal) | PARTIAL | Keyfiles exist; TLS/Origin discipline not evidenced. Part VII (J-106). |
| 54 | Grammar-held JSON / schema-constrained output | WANTED | Part VII (J-106) |
| 55 | Speech-to-text (Whisper) + VAD + diarization | REFUSED | A second model kind and pipeline; no slice on this road owns it and no Aesir consumer names it. Recorded conscious non-goal: J-106 answers speech routes in the honest 501 class instead. (Converters refused with it, row 71.) |
| 56 | Code completion / FIM serving + sliding-window discipline | WANTED | Part VII (J-111; window discipline meets Part VI J-097) |
| 57 | MCP server (model as tools: generate/embed) | WANTED | Part VII (J-109) — no MCP exists in Aesir today |
| 58 | MCP client in chat (confirm-before-run) | WANTED | Part VII (J-109/J-112) |
| 59 | Janas's domain services (flights/weather/maps/prices/github/git/quakes/system/wiki) | REFUSED | Host-layer domain services, not engine functions; they belong to hosts (Hermes, Samtal), not to Aesir the engine. The transferable core — engine-as-MCP — is rows 57–58. |
| 60 | GGUF→native converter (gguf2jns) | REFUSED | Its output is the `.jns` format (row 66); Aesir reads GGUF natively — there is nothing to convert *to*. |
| 61 | HF→GGUF conversion with LoRA merge at conversion | WANTED | Part VIII (J-120) |
| 62 | MTP-preserving conversion/extraction | WANTED | Part VIII (J-121) |
| 63 | Vision-encoder conversion from HF checkpoints | PARTIAL | mmproj-class path proven via existing files (Gemma CUDA); HF-checkpoint vision conversion not in Aesir's pipeline. Part VIII (J-119 reconciliation). |
| 64 | Model-file checker with per-expert checksums | PARTIAL | Wave store integrity discipline exists (S-059); no user-facing check tool. Part VII (J-112). |
| 65 | C library API (opaque handles, error codes) | PARTIAL | Adapters consume Aesir (Yggdrasil Y-023/Y-024); no stable C ABI in tree. Part VII (J-115/J-116). |
| 66 | The `.jns` format itself | REFUSED | The mirror project's own native format. Aesir's native format is GGUF; adopting `.jns` buys nothing GGUF doesn't give and couples Aesir's layout law to the mirror's. Its transferable cores (expert-slot layout, bit planes as a pressure lever) are graded at rows 1 and 6/7 on their own merits. |
| 67 | Node/TypeScript module | WANTED | Part VII — J-115's audit decides build-or-refuse on evidence (no consumer named today). |
| 68 | FreeBASIC bindings | REFUSED | Exists to serve the mirror author's own BASIC MODERN platform; no Aesir consumer exists in Volmarr's stack. J-115 records the audit trail so the refusal is documented, not silent. |
| 69 | `janas-nsm` (NSM explication tool + scoring) | REFUSED | The NSM dressing: a single-paper research tool whose weights/data are CC BY-NC-SA and which Janas itself does not ship; no Aesir consumer. Its transferable core is row 70. |
| 70 | Constrained generation / vocabulary restriction | WANTED | Part VII (J-114; design at J-113) |
| 71 | Whisper/VAD/WeSpeaker converters | REFUSED | With row 55 — they exist only to feed the speech pipeline this road refuses. |
| 72 | Qwen3 dense family | HAVE | Zen (Qwen3-4B) proven across the rung ladder (S-026) |
| 73 | Qwen2 family (Coder/SmolLM2) | HAVE | Crowns Coder-3B Q8_0 / Coder-7B Q4_K_M |
| 74 | Llama-3 family | HAVE | Spill proof + Stheno grading |
| 75 | Mistral3 family | HAVE | Short-length proven; the at-length gap is IN-204's S-104 — noted, grade stands on the proven half |
| 76 | Gemma-4 dense | IN-204 | CUDA half HAVE; CPU generation owned by 204 S-039/S-040 |
| 77 | Gemma-4 MoE (26B-A4B) | WANTED | Part VIII (J-126) |
| 78 | Gemma-4 E2B/E4B (per-layer embeddings) | WANTED | Part VIII (J-127) |
| 79 | Qwen3 MoE (30B-A3B) | WANTED | Part VIII (J-122 family) |
| 80 | Qwen3.5 dense | WANTED | Part VIII (J-125) |
| 81 | Qwen3.5 MoE / Qwen3.6 MoE | WANTED | Part VIII (J-124/J-125) |
| 82 | Qwen3-Next (+ Coder-Next) | WANTED | Part VIII (J-123) |
| 83 | Nemotron hybrid (Mamba-2/MoE) | WANTED | Part VIII — J-131's gate decides execution or refusal with reasons (gate note A5) |
| 84 | Qwen3.8-Flash-Next experimental arch | WANTED | Part VIII — J-131's gate decides (gate note A5) |
| 85 | UD dynamic quant files (as a class) | PARTIAL | Individual UD files graded in the wave; the class is completed by Part VIII (J-130). |
| 86 | Importance-matrix (imatrix) GGUF files | WANTED | Part VIII (J-129) |
| 87 | MXFP4 weights | WANTED | Part VIII — enters via J-123's files or J-131's refusal (gate note A6) |
| 88 | Vision (encoder beside the model) | PARTIAL | Gemma CUDA convergence proven; encoder CPU-side (ledger `partial`); development owned by 204 Part V, bound by this road's J-119/J-127 |
| 89 | Windows build parity | WANTED | Part III (J-051 decides and records) |
| 90 | Machine reports from other machines (reports culture) | WANTED | Part VII (J-101 machine report is the artefact) |

**Grade counts (grep-tallied from this table, 2026-10-31):** HAVE 9 · PARTIAL 20 · IN-204 1 · WANTED 52 · REFUSED 8 — 90 rows.
