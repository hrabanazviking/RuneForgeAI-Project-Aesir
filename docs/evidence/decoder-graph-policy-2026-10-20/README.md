# Explicit decoder graph policy evidence

See ../../HAILO10H_MOJO_DECODER_GRAPH_POLICY.md for scope and interpretation.
Five new methods/152 native calls pass,81 accepted/71 expected refusals,
40 complete independently transformed semantic graphs. Fourteen rebuilt
regression suites pass94 methods/2559 calls, including108 complete frozen
consumer comparisons. Final total99 methods/2711 native calls.

Initial compile failures and initial passing145-call policy/2559-call regression
runs remain preserved. Cache hardening was followed by fresh clean tool/API
builds and final152/2559 runs. Builds include26 affected regression binaries
and the new inspector/API. Final source manifests identify the tested versions;
only cache_layout changed after the initial26-build snapshot and both cache
binaries were rebuilt explicitly. New inspector/API sources were added after
that snapshot. Final-source and slice manifests include them.

Native commands, binary identities, raw outcome counters/hashes and syscall
traces retain observed machine paths. The fixture programs only inspect source
metadata/compile structures and isolated source constants. No model/layer/
attention forward, device access, numerical program upload or execution occurs.
Whole-repository consistency and hosted CI are separate gates.
