# Q8_0 source conversion acceptance

This receipt records completed native verification under the published pre-code
contract 9b69894. summary.json and suite-census.json contain the primary census;
frozen-pair-summary.json covers all 74 unchanged native controls. The separately
repeated context transcript is excluded from the primary total. See
context-report-collision-review.json for the preserved runner collision.

The 76 builds are Mojo builds. Existing C++ control oracles and the isolated
static constant reference remain unchanged test-only inputs; their exact hashes
are included in audit-review-input-hashes.json. runtime.json records the compiler.
No model, layer, attention, inference backend or numerical Hailo program runs.

Source hashes cover 640 actual archived Mojo sources, not 640 rebuilt programs.
The source-snapshot tree, binaries, original journals, raw syscall traces and
failed/intermediate artifacts remain in the retained outside archives. Their
identities are in archive-identities.json. The source byte payload is genuinely
read/decoded, and whole read-only GGUF mappings include that payload. No
header-only or immutable external model/cache identity claim is made.

Exhaustive coverage uses an independently computed integer digest of 2,097,152
component records; 1,321 additional records have complete component comparisons.
The 256-value external comparison calls only the pinned static Q8_0 constant
decoder. Its CPU backend is disabled, and it is not a production dependency.

Exact original runners are preserved, including the original trace auditor.
Use audit-q8-traces-reviewed.py for PID-scoped unfinished/resumed syscall records;
the original preliminary audit failure and its raw trace remain in the outside
archive. The reviewed full verifier was prepared but not needed: the original
full verification passed, followed by the corrected audit postcheck. Neither
native sources nor original frozen test inputs changed during review.

Published JSON copies replace the task's absolute work prefix with portable
../ paths. Original and published document hashes are in portable-paths.json;
source, binary and payload identities remain hashes of the original bytes.
No raw binary, vendor implementation or syscall trace is shipped here.
