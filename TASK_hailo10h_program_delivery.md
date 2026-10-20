# Original program delivery and activation boundary

Date: 2026-10-20. Contract before continued study/implementation.
Parent: `TASK_hailo10h_source_compiler_plan.md`.

Consumer: the original SMIÐR program builder and HAILBRÚ device owner, toward
the fixed source-model-to-Hailo-10H objective. Source constant readers and
mathematical IR now have independent host evidence; actual numerical program
encoding and delivery remain open. Investigate these backend dependencies
directly without treating constant-format coverage as device execution.

Read existing public-context/server/driver receipts first. Under the existing
license-first, pinned-source, interface-facts-only discipline, trace the host
driver, integrated-device path and server dispatch to determine which endpoint
can accept an Aesir-generated program and how activation/lifecycle work. Name
every missing program structure, topology/register/CCW fact and privilege or
device-environment distinction. Seek public hardware/configuration facts as
needed, checking licenses before source bodies. Do not copy/translate external
implementations or extract vendor compiled-model contents.

Acceptance for each research slice: pinned provenance, explicit caller → wire
or ioctl → receiver → operation mapping, exact supported/unsupported facts,
and a concrete next original implementation or narrower evidence experiment.
Implement bounded host codecs only after real field definitions are published;
test with independent public-header/byte oracles. No invented register/opcode,
arbitrary device write, guessed request, reset/rebind/firmware/kernel change,
model download or CPU/CUDA/cloud/proxy inference is authorized by this study.
Physical requests require a separately established safe typed endpoint and
bounded cleanup contract. Preserve historical and concurrent work.

The goal remains Mojo-owned compilation/execution for source models fitting
Hailo-10H, with all LLM execution on that hardware. A compiled container format
may be a required output of our compiler; that fact would not authorize a
vendor-catalog-only product or replacing original program generation with
borrowed numerical programs. Report unsolved gaps honestly, publish verified
slices, and advance automatically toward the unchanged owner objective.
