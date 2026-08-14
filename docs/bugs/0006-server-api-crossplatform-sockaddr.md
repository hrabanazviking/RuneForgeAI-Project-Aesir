# Bug Report: Hardcoded Linux Socket Constants and Structural Layout

**Bug ID**: 0006
**Title**: `BifrostGate` uses Linux-specific socket constants and `sockaddr_in` memory layout
**Component**: `server/api.mojo`
**Status**: Resolved

## Description
In `server/api.mojo`, socket initialization hardcodes Linux `sockaddr_in` layout:
- `self.addr_ptr` stores `Int16(2)` (AF_INET) at index 0. On BSD / macOS / iOS, `sockaddr_in` starts with `uint8_t sin_len` followed by `uint8_t sin_family`, causing byte order misalignment and `bind()` failures.
- `setsockopt` hardcodes `SOL_SOCKET=1, SO_REUSEADDR=2`, which are Linux values (on macOS, `SOL_SOCKET` is `0xFFFF` and `SO_REUSEADDR` is `0x0004`).
- Windows requires Winsock initialization (`WSAStartup`) and `closesocket()` instead of standard POSIX `close()`.

This violates rule 16 of `RULES.AI.md`: "Make sure all codebases are designed to be highly cross platform, including working on Windows, Linux, Mac, iOS, Android, and Raspberry PI devices."

## Recommendation for the Forge Worker
Introduce OS-conditional compilation flags (`@parameter if sys.is_apple():` / `@parameter if sys.is_windows():`) or a cross-platform POSIX socket abstraction wrapper.

## Mythic Engineering Rite Completed
Resolved by Forge Worker: Introduced platform helper functions (`os_is_linux()`, `os_is_macos()`, `os_is_windows()`, `os_is_apple()`) in `server/api.mojo`. Socket options `SOL_SOCKET` and `SO_REUSEADDR` are set dynamically based on OS platform. `sockaddr_in` memory initialization adjusts byte layout for BSD/macOS (`sin_len` + `sin_family`), and socket closing branches on OS (`closesocket` vs `close`).
