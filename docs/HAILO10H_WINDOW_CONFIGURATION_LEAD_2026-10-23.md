# Bounded memory-window configuration publication check

Date:2026-10-23. Contract:`TASK_hailo10h_numerical_encoding_sources.md`.
Research only;no software license,implementation or device authority is inferred
from a published patent disclosure. Source-model support is unchanged.

The primary [US11354563B2 publication](https://patents.google.com/patent/US11354563B2/en)
describes configurable limited memory/compute windows,including noncontiguous
access. Its layer-control discussion distinguishes static configuration from
dynamic instruction signals. Figure17 labels splitter/multiplexer selection;
Figure18 depicts contention alerts and layer halt signaling. Those labels are
diagram references,not register addresses. The inspected passages and diagrams
do not establish H10H bit positions,window-register addresses,microcode encoding
or a target resource map. Example element counts cannot qualify actual H10H fit.

The concrete missing evidence remains a matched H10H mapping from logical source
tensor placement to physical window selectors and their exact configuration
fields. No new serializer or device write is justified by these passages.
A separate search hit,US20210303358A1,identifies Micron as original assignee;
it was rejected as Hailo programming authority. No code or algorithm was adopted.
Raw primary PDF/extraction/provenance and actual unchanged691 Mojo/81 Python
input copies are pinned under`evidence/session-finalization-contract-2026-10-23/`.

Independent transport continuation addresses a concrete original close-error
lifetime gap under`TASK_hailo10h_session_finalization.md`. This report establishes
no compiler or numerical capability. Continue exact numerical/placement/program
interfaces and original Mojo implementation toward broad ordinary unmodified
model support100%,with all eventual LLM execution on Hailo-10H.
