# Integrated RPC DMA observation and bounded completion

Date: 2026-10-19. Contract published before observation implementation.
Parent: `TASK_hailo10h_soc_session.md`, under the fixed Mojo source-model target.

## Established starting point

The native Mojo descriptor/assigned-connection lifecycle is physically verified
at `1327492`. Typed device messages and frame codecs already pass independent
wire oracles. Actual transfer sizing, cache visibility, completion and bounded
wait/cancellation remain separate dependencies before owned RPC exchange.

The owner uploaded nine compiler-strategy documents at `4a0cc74`. Their
weights-as-inputs, primitive-library, synthesis and independent-compiler ideas
are experiment candidates toward broad source-model support. Their pseudocode
and historical capability descriptions are not new hardware proof. Keep the
owner's Hailo/Mojo target and existing ledger authoritative.

## Acceptance slices

1. Build an independently authored test-only ioctl observer against the
   operator's installed 5.3.0 UAPI. Observe only a bounded private instance of
   supported `hailortcli fw-control identify`; no model/inference request.
   Record relevant request sizes, returned channel/descriptor facts, transfer
   buffer lengths/types, host-pointer alignment, outgoing RPC header bytes,
   and completion status. Do not dump weights, arbitrary memory or identities.
2. Verify paired calls, successful read-only query and subsequent normal
   identification. Fingerprint the observer, CLI/library and installed UAPI.
   Publish raw facts separately from hypotheses. The observer is not a
   production runtime bridge and cannot count as independent Mojo exchange.
3. Resolve nominal message-buffer versus actual transfer size using observation
   and pinned interfaces. No guessed padding, fragment pattern or opcode.
4. Implement bounded completion and cancellation inside HAILBRÚ, proving host
   control flow first and then an assigned channel with no user transfer.
   An owned blocking waiter must finish or be stopped/reaped before session
   or buffer destruction. Preserve real timeout/error evidence.
5. Add owned DMA storage and the typed physical create/identify/destroy client.
   Admit only established cache/completion/lifetime behavior, correlated replies
   and full cleanup. Publish each verified acceptance slice, then continue
   actual source-model program generation/lowering under the same target.

## Scope and evidence

The observation uses the already installed runtime as a reference instrument,
not as a serving substitute. No catalog/model selection, precompiled-only
policy, CPU/CUDA/cloud inference, kernel/module/firmware changes, driver unbind
or device reset. Source copies remain outside the repo; read licenses first,
extract interface facts into prose, implement independently. No vendor
implementation is copied or translated. Test helpers must not become a
production dependency.

Every physical experiment has a process deadline and recorded cleanup outcome.
Process-level containment alone does not certify a reusable client's timeout
API; that claim needs its own tested owner. Unknown compiler operation encoding
stays named work, never a reason to alter the owner target.
