# AESIR speed-lead roadmap — 2026-10-01

## Authorization and scope

Volmarr asks for a Markdown roadmap to make AESIR substantially faster than
Ollama and explicitly authorizes pushing the roadmap. This task publishes a
plan and its measured baseline; it does not implement planned kernels, change
service policy, install dependencies or promote runtime capability status.
Mythic Engineering roles operate sequentially: Cartographer, Architect, Auditor
and Scribe. The existing capability ledger and reality-first rules govern truth.

## Current truth

Start from clean main 59094de. Native strict Llama 3.2 3B Q4_K_M on RTX 2060 Max-Q
uses four-token prefill and F16 KV. Actual paired requests show cached 32-token
passages near Ollama, but new long input 13.559s versus 3.325s and repeated 128-token
output 3.314s versus 2.719s. Templates and KV precision differ; these wall times
are an installed-service baseline, not isolated prefill/decode or full parity.
Existing long-token, sampling, recovery and API evidence remains authoritative.

## Ownership and files

Root ROADMAP_AESIR_SPEED_LEAD.md owns this focused speed program. TODO.md and
README_AI.md expose its next work; README.md and PERFORMANCE_BUDGETS.md link it.
Existing BEST_IN_CLASS_GAMEPLAN.md remains the wider application program.
Public baseline JSON/Markdown files go in docs/evidence/provider-speed-2026-10-01/
without local machine paths, keys, private data or generated binary artifacts.
No executable/source/API/lock/model/service files change.

## Required content

Define ambitious measurable lead/stretch targets, fair benchmark modes, a
hardware bandwidth/compute feasibility gate, separate prefill and decode work,
owner/dependency/exit gates for each slice, Turing/locked-Mojo constraints,
precision and quality contracts, memory/buffer budgets, recovery/release gates,
reproducible baseline commands and an exact next implementation work order.
Distinguish proposed targets, primary-source research and observed evidence.
Publish this task contract before the substantive roadmap slice.

## Verification and completion

Verify every local baseline number from raw samples and selected runtime flags.
Use primary NVIDIA/Modular/research sources for architectural mechanisms;
current online APIs do not prove support in the locked runtime. Validate local
Markdown links, document drift, whitespace and absence of local paths/secrets.
Push to main, verify the remote revision and exact CI separately. Provide a
user-facing roadmap copy and publication receipt. Preserve existing reference
code and corpus, and leave all planned capabilities unimplemented/unverified.
