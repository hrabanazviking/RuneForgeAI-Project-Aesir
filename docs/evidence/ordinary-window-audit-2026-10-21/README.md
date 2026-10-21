# Ordinary source window audit

46 public constructor cases:44 accepted metadata/2 expected empty-list refusals.
119 isolated index cases/4760 boolean checks pass. No model, layer or attention
forward, source weights, external compiler, network or Hailo access. Constructor
process excludes Torch/model-module imports; separate integer predicate process
uses Torch only for library availability and blocks module/SDPA forwards. Lazy
source-file discovery is distinct from importing/executing a model module.

Pinned4.57.1 module/license identities, scripts, full oracle output and both
preliminary audit assertion corrections are retained. Complete syscall traces
and full license remain outside Git with hashes and file modes here. Facts only;
no native window implementation, physical cache compaction or device execution
claim. Exact native design/acceptance contract precedes production edits.
