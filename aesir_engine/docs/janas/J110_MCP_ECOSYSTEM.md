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

---

## 1. What was built

**`aesir_engine/docs/janas/j110_runmal_consumer.py`** (new, the consumer) — exactly §0.2's wiring: a Python-3-stdlib-only prober in Rúnmál's S211 shape (`probe_aesir_mcp(host_argv, profile_id)` returning the `HealthResult`-shaped dict, latency measured around the probe as Rúnmál's own contract does). It spawns the compiled Aesir MCP host, speaks newline-delimited JSON-RPC (`initialize` → `notifications/initialized` → `tools/list` → three `tools/call`s), and **uses** the results: the `aesir_model_info` listing becomes the report's `models` list; the first model's record is verified (64-hex sha256 pin, 40-hex revision, positive size, honest `live_session_bound:false`) before its pin is carried into the report `detail`; a real `aesir_generate` call decides the advertised capabilities — in this host build it returned the honest no-engine tool error, so `generate` is recorded in the annex as not advertised, with the tool's own reason text quoted verbatim. No engine code was changed in this slice; no Rúnmál file was changed (§0.3).

**Artefacts filed beside it:** `j110_consumer_session.txt` (the full run transcript), `j110_consumer_report.json` (the health report the consumer wrote from the tool results), `j110_test_output.txt` (build/gate record), `j110_inspect.py` + `j110_inspect_output.txt` (§4).

## 2. The consumer proof (the §0.4(a) evidence)

The consumer ran against the compiled host and **every assertion passed: CONSUMER PROOF: ALL PASS (14 OK, 0 FAIL)**, exit code 0, host exiting cleanly at EOF. The exchange, from the filed transcript: initialize answered (protocol `2024-11-05`, serverInfo `aesir`/`1.0.0`) → discovery found exactly the three J-109 tools → the listing call returned the real catalogue (5 entries) → the record call for `olmoe-1b-7b:q4_k_m` returned its record with sha256 pin `8c310f1435a1…f3f` — byte-identical to the J-015/J-030 measured pin — revision `02ab6ea6…8080`, size 4,213,512,672 bytes → the generate call returned the no-engine tool error in plain words. The report the consumer produced from those results (`j110_consumer_report.json`): `ok: true`, `capabilities: ["local-models", "model-info"]`, `models:` all five catalogue references (`olmoe-1b-7b:q4_k_m`, `granite-3.1-3b-a800m:q4_k_m`, `qwen1.5-moe-a2.7b-chat:q2_k`, `olmoe-1b-7b:q2_k`, `qwen3-next-80b-a3b:q4_k_m`), `detail` carrying the verified pin prefix, and the annex holding the full first record plus the generate verdict with its quoted reason.

**Host binary provenance (stated plainly, per §0.4(a)):** no fresh Mojo build was attempted — VM MemAvailable stayed ~0.30–0.56 GB, below what the toolchain build safely needs, and this slice changes no engine code (the base-to-branch diff for `aesir_engine/core` and `aesir_engine/cli` is empty; `cli/mcp_serve.mojo` and `core/mcp_tools.mojo` are sha256-identical in the J-109 and J-110 worktrees). The consumer therefore drove J-109's compiled staging binary of the identical source at the identical commit — the fallback the protocol pre-registered for exactly this gate. A one-line smoke test preceded the run (initialize answered correctly, exit 0).

## 3. The integration, written up (what a real wiring takes from here)

- **Rúnmál registration step (roaded, not done here — §0.3):** in Rúnmál's own tree, add `"aesir-mcp"` to `VALID_BACKENDS` and `BACKEND_CAPABILITIES` in `src/runmal/connections/service.py` (advertising only what a session proves — this slice's run supports `["local-models", "model-info"]` today, `generate` joining only when an engine-bound host answers a generate call in the same probe), and register this prober as the injectable `Prober` for profiles of that backend kind, with the profile's model field validated against the probe's `models` list. The prober's argv is the host launch command (`aesir mcp` once the engine-bound build is the deployment, or the compiled host path as here). That is a small, mechanical change in Rúnmál's repo under Rúnmál's own road and tests; the Aesir side needs nothing further.
- **Hermes direction:** the wiring is transport-identical — any MCP host command can be substituted as the prober's argv — so when a Hermes harness grows a backend-probe seam, this consumer is its Aesir prober unchanged. No Hermes code exists on disk today with such a seam (§0.1); nothing is claimed for it.
- **What changes when the engine-bound host lands (J-118 recipe, J-109 §5):** the same probe, unchanged, would find `generate` answering with engine text and would advertise it; the capability set is session-earned by construction, so no consumer change is needed and no capability is ever advertised ahead of proof.

## 4. Inspect

`docs/janas/j110_inspect.py` re-derives the load-bearing claims from the tree and the filed outputs — the consumer's stdlib-only imports and real MCP framing strings; the absence of any Aesir-internal contact (no engine import, the host reached only as a spawned argv); the session transcript's tallies (14 OK, 0 FAIL, the verdict line, the real OLMoE pin, clean exit); the report artefact's shape against Rúnmál's `HealthResult` fields, its models list against the transcript's listing, its capabilities against the session's generate verdict; the doc's tallies against the filed outputs; and repo hygiene (diff == the expected file set; no README, no `.gguf`). Result filed in `docs/janas/j110_inspect_output.txt`.

## 5. Defects found and dispositioned

None in the J-109 surface: the consumer's first run passed whole — handshake, discovery, listing, record, and the honest generate refusal all behaved exactly as J-109 filed them, now witnessed from a second, independent program with a different purpose. No defect was found in Rúnmál's prober contract either (the consumer follows its documented shape without adaptation). The one environmental constraint — VM memory far below even a safe toolchain build — is a gate observation, not a defect, and is handled in §2's provenance statement rather than hidden.

## 6. Deferred legs (DEFERRED-WITH-REASON — re-cite at the J-118 Part VII gate)

1. **Live generate-through-MCP (the engine-bound host)** — unchanged from J-109 §5, with its exact recipe filed there: VM below the 5,500 MB inference gate with no CUDA device; purplelongship yielded to the 204 road's S-104. This slice's consumer is built so the leg closes by re-running the same probe against the bound host (§3).
2. **In-Rúnmál registration** (`VALID_BACKENDS` + capability table + prober registration in Rúnmál's own repo, §3): roaded to Rúnmál's own road — it is a change to a different project's tree with its own tests, and this slice's bound (§0.3) was to prove the consumer against the real host, which is done. NOT PROVEN inside Rúnmál itself; proven at its contract boundary.
3. **Hermes-side wiring:** no harness with a probe seam exists on disk (§0.1); the transport-identical prober is ready when one does. NOT PROVEN, not claimed.

## 7. Answered-locally (clean-room)

- **Consumer choice (Rúnmál over Hermes):** decided on on-disk evidence (§0.1) — a runnable app with a documented, injectable backend-probe contract versus a documentation workspace with no such seam. Wiring to the seam that exists is the honest reading of "bound where Aesir is actually consumed."
- **Capabilities are session-earned:** the consumer advertises only what the same session's tool calls actually did. This follows Rúnmál's own probe semantics (capabilities come from the probe outcome, and a failed probe advertises none) and Aesir's honesty law; it is also what keeps the J-109 no-engine truth visible to the ecosystem instead of papered over.
- **The consumer lives in Aesir's docs tree, not Rúnmál's:** the slice's deliverable is the wiring proven at the contract boundary; modifying another project's tree from this road would mix two campaigns' banking. The registration step is written up exactly (§3) instead.
- No Janas document beyond the already-filed road records and no Janas code was consulted; MCP decisions follow the protocol's public shape as proven in J-109.

## 8. Honesty ledger

- **PROVEN:** one real consumer wired and proven — a Rúnmál-shaped backend prober, an independent program outside the engine, speaking real MCP over stdio to the compiled Aesir host, using the tool results to produce a real artefact (the health report: verified model list, verified pin, session-earned capabilities), every assertion passing (14 OK, 0 FAIL) with the full transcript filed; the integration written up (§3) including the exact Rúnmál registration step.
- **NOT PROVEN:** engine-generated text through MCP (deferred leg 1); the registration inside Rúnmál's own tree (deferred leg 2 — proven at its contract boundary only); Hermes-side wiring (deferred leg 3); interoperability with a vendor editor's bundled MCP client (this slice adds a second independent consumer witness, but both ends of the pipe are still this road's own code).
- **SIMULATED / MEASURED-INDICATIVE:** none. The report's `latency_ms` is a real measurement of the filed run, printed in the artefact itself; no number in this doc is simulated.

## 9. Banking

Per-slice commits on `yrsa/janas-j110` from the §0 base (`e51b32cf` protocol + the build/evidence commit), pushed by explicit refspec and verified with `git ls-remote` (remote == local HEAD; `yrsa/janas-j109` and origin/main unchanged); campaign copies of this doc, the consumer script, the session transcript, the report artefact, the inspect script + output, and the test output filed sha-identical in `~/workspace/model-tests/janas/`. No README touched. Hailo untouched/parked. Nothing was deleted to free disk; staging lived under `~/workspace/.verify-tmp/j110stage`.
