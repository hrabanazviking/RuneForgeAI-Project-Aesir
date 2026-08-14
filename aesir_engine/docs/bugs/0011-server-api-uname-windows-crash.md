# Bug Report: Server API `uname` Invocation on Non-POSIX / Windows Systems

**Bug ID**: 0011
**Title**: `os_is_windows` invokes `external_call["uname"]`, causing runtime symbol lookup failure on Windows
**Component**: `server/api.mojo`
**Status**: Resolved

## Description
In `server/api.mojo`, `os_is_windows()` called `not (os_is_linux() or os_is_macos())`. Both `os_is_linux()` and `os_is_macos()` invoke `external_call["uname", Int32](buf)` to read OS system info. On Windows operating systems, `uname` does not exist in standard C runtimes, causing dynamic symbol resolution failure or crash on Windows platforms.

## Fix Applied
Safely handled platform detection without calling POSIX `uname` unconditionally on Windows, preserving cross-platform capability.

## Mythic Engineering Rite Completed
Additive fix applied to guarantee cross-platform portability across Windows, Linux, and macOS.
