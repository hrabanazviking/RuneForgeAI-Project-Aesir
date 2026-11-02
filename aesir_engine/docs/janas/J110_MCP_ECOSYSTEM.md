# J-110 — MCP: Aesir Inside the Ecosystem

**Slice:** J-110 (Part VII — The Tool Family, J-099–J-118), Project Aesir Janas clean-room road.
**Roadmap text:** "The MCP surface bound where Aesir is actually consumed (the Hermes/Rúnmál direction): one real consumer wired and proven, the integration written up."
**Builds on:** J-109 (banked `yrsa/janas-j109` @ `52258cd8` — this slice's base, ls-remote verified at slice start): the pure MCP layer `core/mcp_tools.mojo`, the stdio host `cli/mcp_serve.mojo` behind the `aesir mcp` door, exactly three tools (`aesir_generate`, `aesir_model_info`, `aesir_embed` — embed honestly refusing), and a stdlib MCP client session proven end-to-end against the compiled host. J-109 §5 named this slice as the natural place to earn the second witness: a real ecosystem consumer bound to that surface.
**Clean-room record:** no Janas material is consulted in this slice beyond the road's own already-filed records (the roadmap text, the J-099 census, the J-109 doc). MCP is a public open protocol; every decision below is taken from Aesir's own architecture and from the consumer's own on-disk code, and is recorded as answered-locally in the doc's final section. No Janas source code was opened, in this slice or any other.

---

## 0. Protocol (committed first, before any consumer code was built)

This section was committed before the consumer, its proof run, or the inspect existed. It states the consumer choice with its on-disk evidence, the wiring, the verdict rules, and what is deferred and why; everything after §0 is filed under these rules and no others.

### 0.1 The consumer, chosen on evidence from disk

Two candidate consumers were inspected first-hand on this machine:

- **Rúnmál — CHOSEN.** `~/workspace/runmal` is a real, runnable program outside the engine: a Python (FastAPI) chat application, package `src/runmal/`, with its own test suite (`tests/`, incl. `test_s211_connections.py`, `test_s213_tools.py`). Its connections layer, `src/runmal/connections/service.py` (S211), is exactly a consumption point for a model backend: a *connection profile* names a backend (`VALID_BACKENDS = ("fake", "ollama", "openai")`), and `probe_profile` health-probes a backend and reports a `ProbeOutcome` / `HealthResult` of the shape `{ok, latency_ms, capabilities, detail, models}` — reachability, latency, advertised capabilities, and **the list of models the backend offers** (`_probe_models`). That model list is a real thing Rúnmál consumes to let a user pick what a profile talks to. An Aesir backend behind MCP slots into that shape without inventing anything: the prober spawns the MCP host instead of HTTP-probing a base URL, and the model list comes from `aesir_model_info` instead of an ollama `/api/tags`-style call.
- **Hermes — inspected, not chosen.** The Hermes-side material on disk (`~/workspace/heimdall-sl-hermes-agent`, `~/workspace/hermes-hack-build`) is a documentation-heavy workspace and a Second-Life hack build, not a light runnable agent harness with a backend-probe seam this slice could wire honestly in one slice. Wiring there would mean building the harness first and calling it a consumer — a fake fit. Recorded as answered-locally; the Rúnmál wiring below is transport-identical (any MCP host command), so a Hermes-side prober is the same code with a different argv when a Hermes harness with such a seam exists.

### 0.2 The wiring (the consumer)

**`aesir_engine/docs/janas/j110_runmal_consumer.py`** — Python 3 standard library only, living on the consumer side of the boundary (it calls no Aesir internal; its only contact with Aesir is spawning the host process and speaking MCP on its stdio, exactly as J-109's client did and as any ecosystem consumer would):

- `probe_aesir_mcp(host_argv, profile_id)` — a prober in Rúnmál's S211 shape: it measures latency around the whole probe (Rúnmál's own pattern: "latency is measured around it"), spawns the compiled Aesir MCP host, and speaks newline-delimited JSON-RPC: `initialize` → `notifications/initialized` → `tools/list` → `tools/call aesir_model_info` (absent argument → the catalogue listing) → `tools/call aesir_model_info` for the listing's first reference (the full record) → `tools/call aesir_generate` (to learn, from the tool itself, whether generation may be advertised) → EOF.
- **The tool results are used, not merely received** — that is what makes this a consumer and not a second test client:
  1. The listing becomes the probe's `models` list — the model names a Rúnmál profile backed by Aesir would offer its user.
  2. The first model's record is verified before it is trusted (64-hex sha256 pin, 40-hex revision, positive size) and its pin is carried into the probe `detail` — the consumer checks the catalogue's integrity facts the way a careful consumer must, because the pin is what a later download would be verified against (J-103's contract).
  3. The generate call's honest answer decides the advertised `capabilities`: only what the tools actually did is advertised. In this host build (no engine bound, per J-109 §5) the truthful capability set is `["local-models", "model-info"]` and generation is recorded in the report as unavailable-with-reason — the consumer never advertises a capability the backend refused in the same session.
  4. The probe result is emitted as a Rúnmál `HealthResult`-shaped JSON report (`{profile_id, ok, latency_ms, capabilities, detail, models}` plus the per-tool honesty annex) written to a file the run names — the artefact a Rúnmál health check stores — and printed as a transcript.
- The consumer asserts each step as it goes (handshake shape, exactly the three J-109 tools discovered, listing non-empty, record fields well-formed, generate's answer honestly an error in this build, clean server exit) and exits non-zero on any failed assertion. Its verdict line is `CONSUMER PROOF: ALL PASS`.

### 0.3 What this slice does not build

- **No change to Rúnmál's own tree.** The wiring is proven consumer-side, in the shape Rúnmál's prober contract defines (injectable prober callable — `connections/service.py`: "The probe callable is injectable"). Registering `"aesir-mcp"` in Rúnmál's `VALID_BACKENDS` inside Rúnmál's own repo is Rúnmál-road work, not Aesir-road work; this slice proves the prober against the real host and files the exact registration step in the write-up. Claiming Rúnmál itself was modified would be false, and is not claimed.
- **No engine code changes.** J-109's surface is consumed as banked. If the consumer run finds a defect in the J-109 surface, it is fixed in scope or recorded as a named next item — never silently left.
- **No live generation.** The generate leg stays exactly where J-109 §5 put it: DEFERRED-WITH-REASON to the J-118 Part VII gate (VM MemAvailable far below the 5,500 MB inference gate at dispatch — ~0.3–0.6 GB — and no CUDA device on the VM; purplelongship yielded to the 204 road's live S-104). The consumer therefore wires to the proven `aesir_model_info`/catalogue tool, as the slice brief directs, and defers only the generate leg.

### 0.4 Verdict rule for this slice (pre-registered)

The slice **passes** iff all of the following hold, each filed:

(a) **Consumer proof:** `j110_runmal_consumer.py` runs against the compiled J-109-shape host binary (built fresh in this worktree at the lightest target, or the J-109 staging binary of the identical source at the identical base commit — whichever the machine gate allows, stated plainly in the doc) end-to-end and every assertion PASSes; the filed transcript shows the full exchange and the HealthResult-shaped report the consumer produced from the tool results (models list from the real catalogue, first record's pin verified, capabilities honest to the session).
(b) **Inspect:** `docs/janas/j110_inspect.py` re-derives the load-bearing claims and PASSes: the consumer is stdlib-only and speaks real MCP framing; the transcript's tallies against the filed session; the report artefact's fields against the catalogue facts in the transcript; the doc's tallies against the filed outputs; repo hygiene (no README, no `.gguf` in the slice diff, diff == the expected file set). Every FAIL is disposed in the doc, never hidden.
(c) **The deferred legs are named, not hidden:** live generate-through-MCP (J-109 §5's leg, unchanged) and the in-Rúnmál registration step (§0.3) are recorded DEFERRED-WITH-REASON / roaded, re-cited at the **J-118 Part VII gate**.

**Honesty classes.** The consumer wiring and its probe report are **PROVEN** where the run passes. Interoperability with a third-party MCP client implementation remains as J-109 left it — this slice adds a second, independent consumer program (different purpose, different code path: a backend prober, not a protocol test client), which is a stronger witness than a re-run of J-109's client, but it is still this road's own code on both ends of the stdio pipe; a vendor editor's bundled client is **NOT PROVEN** and is not claimed. Any engine-generated text through MCP is **NOT PROVEN** by this slice.

**No README is touched. Hailo stays parked (no finish-line branch contact, no chip run or probe). No Docker. Nothing is deleted to free disk; staging lives under `~/workspace/.verify-tmp/`.**

*(The sections after §0 are filed from the build, under this protocol.)*
