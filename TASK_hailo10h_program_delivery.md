> **Controlling owner clarification — 2026-10-20:** broad model support,
> ordinary model files, Aesir-owned internal Mojo translation, no outside model
> compiler or specially compiled artifact prerequisite. See
> `docs/HAILO10H_OWNER_NATIVE_SCOPE_2026-10-20.md`.

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

2026-10-23 separate payload qualification:
`docs/HAILO10H_PROGRAM_PAYLOAD_BOUNDARY_2026-10-23.md` distinguishes full2068-byte
metadata from the exact separate program buffer and the grouped request/read
boundary. Original owned staging follows `TASK_hailo10h_program_payload_staging.md`;
no arbitrary chunking,live payload transfer or numerical execution follows.

Original owned payload staging is now verified under
`docs/HAILO10H_MOJO_PROGRAM_PAYLOAD.md`:43 selected methods and2495 complete
frozen comparisons. This supplies copied byte preparation,not DMA submission or
immutable/executable identity. Continue grouped-buffer driver constraints,sealed
output,in-flight ownership/deadlines/cleanup and actual numerical program work.
