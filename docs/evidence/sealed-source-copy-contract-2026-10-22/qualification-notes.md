# Retained qualification attempts

The original C oracle's first build failed -Werror=misleading-indentation on
its output loop. Its source and diagnostics remain as attempt1; adding braces
produced a clean build. No kernel effects occurred in the failed build.

The first descriptor-lifetime audit expected the final parenthesis directly
after the fd path decoration. Actual strace prints `(deleted)` for anonymous
memfds. That assertion failed; the additive corrected audit accepts this exact
suffix and compares all three open/close tuples with multiplicity. The original
native trace and C oracle result are unchanged. No native qualification rerun.
