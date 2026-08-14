# Bug Report: Missing Socket Cleanup on Stream Completion

**Bug ID**: 0011  
**Title**: Client file descriptor `client_fd` is not closed after streaming autoregressive generation  
**Component**: `server/api.mojo` & `aesir.mojo`  
**Status**: Resolved  

## Description
In `aesir.mojo`, `generate_stream()` emits SSE chunk payloads to `client_fd` via `BifrostGate.send_chunk_static()`. When the token stream finishes, no socket closure function was called on `client_fd`. Over time, active HTTP streaming connections accumulate leaked file descriptors until system FD limits are exhausted (`EMFILE`).

## Fix Applied
Added `close_client_static(client_fd: Int32)` and `close_client(client_fd: Int32)` methods to `BifrostGate` in `server/api.mojo` that invoke OS-specific socket closure (`closesocket` on Windows, `close` on POSIX). Updated `generate_stream()` in `aesir.mojo` to invoke `BifrostGate.close_client_static(client_fd)` upon sending the final stream termination chunk.

## Mythic Engineering Rite Completed
Additive fix applied. Streaming connections now terminate cleanly without file descriptor leaks.
