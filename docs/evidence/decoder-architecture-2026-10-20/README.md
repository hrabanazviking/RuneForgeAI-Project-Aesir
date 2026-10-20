# Owned ordinary parameter intent evidence

Read ../../HAILO10H_MOJO_DECODER_ARCHITECTURE.md for exact claims/bounds.
Final7 methods/200 native calls pass (69 accepted/131 expected refusals).
Four unchanged-source regressions pass24 methods/853 calls. Total31/1053.
Original194-call success and regressions are retained. The extra edge run failed
because the trace omitted openat2 and one executable was being relinked; both
harness errors are retained. Fresh final tests use completed warning-free
binaries and an openat/openat2/close trace. No production implementation failure
was observed by the final acceptance suite.

Manifests identify every new source/binary and prove old implementation source
files unchanged. Raw logs/traces retain actual machine paths. These are metadata
and compiler-structure checks; no model/layer/attention forward, source payload
mmap, inference library/device access or hardware numerical execution occurs.
