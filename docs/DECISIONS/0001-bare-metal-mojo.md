# ADR 0001: Bare-Metal Implementation in Mojo

## Status
Accepted

## Context
Traditional LLM inference engines (e.g., Python wrappers around C++ libraries) introduce complex multi-layer runtime dependencies, foreign function interface (FFI) overheads, unpredictable garbage collection pauses, and heavy memory footprints.

## Decision
We choose to implement Project Aesir entirely in **Mojo** as a single bare-metal codebase. We bypass all high-level framework dependencies and communicate directly with the Linux operating system kernel using POSIX standard C library syscalls (`mmap`, `open`, `socket`, `bind`, `listen`, `send`, `close`).

## Consequences
- **Positive:** Zero third-party dependency clutter. Ultra-fast cold boot times. Sub-millisecond execution. SIMD hardware vectorization directly in native code.
- **Negative:** Requires writing low-level pointer management, manual memory safety protocols, and custom SIMD kernels.
