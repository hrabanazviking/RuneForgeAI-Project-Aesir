# ADR 0003: Decoupled POSIX Transport Layer (BifrostGate)

## Status
Accepted

## Context
Tightly coupling HTTP network handlers to AI inference engines leads to boundary collapse, making testing difficult and risking networking bugs contaminating core compute logic.

## Decision
The network transport domain (`server/api.mojo` - `BifrostGate`) is strictly decoupled from the core inference engine. `BifrostGate` handles raw socket I/O, HTTP headers, and client lifetimes, communicating with the inference engine ONLY through `AesirEngine.generate()`.

## Consequences
- **Positive:** Network code can be tested, refactored, or replaced independently. The engine core remains completely transport-agnostic.
- **Negative:** String prompts must be passed explicitly across the domain boundary interface.
