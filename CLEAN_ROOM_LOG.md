# Clean-Room Log — MÍMISBRUNNR vendor-material studies

Audit trail for all study-only work on vendor sources (Doctrine §7 /
architectural law L5). No studied code is copied, translated, or vendored
anywhere in this repository — understanding only.

## License gate (recorded BEFORE any source file was read)

| Repository | License found | License file | Gate |
|---|---|---|---|
| hailort-drivers | GPL-2.0 (GNU General Public License, Version 2, June 1991) | `LICENSE` at repo root | PASS — study-only, no code taken |
| HailoRT | MIT License, Copyright (c) 2019-2026 Hailo Technologies Ltd. | `hailort/libhailort/LICENSE` | PASS — study-only, no code taken |

The license files were read first (2026-10-10, before any `.c`/`.h`/`.cpp`/
`.proto` source file was opened). Both licenses permit studying; the
GPL-2.0 terms additionally confirm why no driver code may enter this tree
(DEPENDENCY_POLICY Tier 4: no GPL code linked, vendored, or shipped).

## Study entries

### H005 — PCIe transport study (2026-10-10)

- **Who:** MIMISBRUNNR Campaign 1 worker (Yrsa's forge).
- **Repositories:**
  - `https://github.com/hailo-ai/hailort-drivers.git` @ `309eb10`
    ("Update third-party-packages.md for v5.4.0", shallow clone `--depth 1`).
  - `https://github.com/hailo-ai/hailort.git` @ `f519590` ("v5.4.0",
    shallow clone `--depth 1`) — ioctl surface only.
- **Files studied:** `hailort-drivers/linux/pcie/src/pcie.c`,
  `hailort-drivers/linux/pcie/src/pcie.h`,
  `hailort-drivers/linux/pcie/src/fops.c`,
  `hailort-drivers/linux/pcie/src/fops.h`,
  `hailort-drivers/common/pcie_common.h`,
  `hailort-drivers/common/pcie_common.c`,
  `hailort-drivers/common/vdma_common.c`,
  `hailort-drivers/common/hailo_ioctl_common.h`.
- **Clone commands:**
  - `git clone --depth 1 https://github.com/hailo-ai/hailort-drivers.git`
  - `git clone --depth 1 https://github.com/hailo-ai/hailort.git`
  - Cloned to `/tmp/hailo_study/` (outside the repository).
- **Assertions:** No vendor package was installed, built, or executed at any
  point. No kernel module was compiled or loaded from the studied sources.
  The studied clones live outside the repo and are never committed.
- **Output:** `docs/plunder/HAILO_PCIE_TRANSPORT_GUIDE.md` (original prose;
  no code blocks longer than one line, no translated functions).

### H006 — HEF container study (2026-10-10)

- **Who:** MIMISBRUNNR Campaign 1 worker (Yrsa's forge).
- **Repository:** `https://github.com/hailo-ai/hailort.git` @ `f519590`
  ("v5.4.0", shallow clone `--depth 1`; same clone as H005).
- **Files studied:** `hailort/hailort/libhailort/hef.proto` (container
  schema), `hailort/hailort/libhailort/src/hef/hef.cpp` (parser walk order),
  `hailort/hailort/include/hailo/hef.hpp` (public surface, skimmed).
- **Assertions:** No `.hef` file was downloaded, opened, or parsed during
  this study; sources were documentation and parser source code only. A
  repo-wide scan during the slice confirmed zero `.hef` files present in
  the repository. No vendor package was installed, built, or executed.
- **Output:** `docs/plunder/HAILO_HEF_CONTAINER_GUIDE.md` (original prose;
  no format diagrams reproduced verbatim, no parser code copied).

### H101/H102 — Firmware mailbox doorbell + control-protocol study (2026-10-10)

- **Who:** MIMISBRUNNR Campaign 6 worker (Yrsa's forge).
- **Repositories:**
  - `https://github.com/hailo-ai/hailort-drivers.git` @ `309eb10`
    (shallow clone `--depth 1`, fresh clone to `/tmp/hailo_study_c6/`).
  - `https://github.com/hailo-ai/hailort.git` @ `f519590` ("v5.4.0",
    shallow clone `--depth 1`, fresh clone to `/tmp/hailo_study_c6/`).
- **Files studied:** `hailort-drivers/common/pcie_common.c` (mailbox
  write/read path), `hailort-drivers/common/pcie_common.h` (request-size
  offset constant, alignment constant), `hailort-drivers/common/hailo_ioctl_common.h`
  (firmware-control structure, ready-flag bit masks, default timeout),
  `hailort-drivers/linux/pcie/src/nnc.c` + `linux/pcie/src/fops.c`
  (completion signaling via software-IRQ bit), `hailort/common/include/control_protocol.h`
  (control opcode list, packed request/response header layout, IDENTIFY
  response structure, protocol version), `hailort/common/include/status.h`
  (success status value), `hailort/common/include/firmware_version.h`
  (version triple layout),
  `hailort/hailort/libhailort/src/device_common/control_protocol.cpp`
  (request header packing: version field value used on the wire).
- **Assertions:** No vendor package was installed, built, or executed.
  No kernel module was compiled or loaded from the studied sources.
  The studied clones live outside the repo (`/tmp/hailo_study_c6/`,
  ephemeral) and are never committed. No studied code was copied,
  translated, or vendored into this repository — understanding only.
- **Output:** `docs/plunder/HAILO_COMMAND_QUEUE.md` (H101; original
  prose, cited evidence per claim, UNCORROBORATED marking where live
  probing could not confirm). The study names the exact doorbell offset
  and one side-effect-free control command that H102 attempts live.

## 2026-10-19 — Integrated-device source-execution transport research

- Pinned HailoRT v5.3.0 revision:
  `d503417f2a0db186a838390fb08690c4ea0f415e`.
- License gate: `hailort/LICENSE` read and confirmed MIT before implementation
  source study. The historical deeper license path returned 404; the pinned
  tree provided the correct root path.
- Studied: `hailort/hrpc/rpc_connection.hpp`, `.cpp`,
  `hrpc/session_internal/pcie_session_internal.cpp`, `hrpc_protocol/rpc.proto`,
  `libhailort/src/device/device_hrpc_client.cpp`, and
  `libhailort/src/vdma/integrated/integrated_device.cpp`.
- Extracted protocol/interface facts only. No implementation code copied,
  translated or vendored. Original Mojo envelope implementation has a real
  native inspector and independent byte-vector/ownership/refusal evidence.
- Source copies stay outside this repository. No vendor code was built,
  installed or executed for the study, and no device state was changed.
- Independent source-compilation research license was read at project revision
  `c870419f7d6315e1277e06a9fa5eadd955b8e1af` (MIT); its public findings and
  dependency boundary were surveyed. Its DFC/proxy pipeline is not adopted.
- Receipt and source links: `docs/plunder/HAILO10H_SOURCE_EXECUTION_RESEARCH.md`.

### 2026-10-19 — Typed integrated-device requests and session lifecycle

At the same MIT-licensed HailoRT revision `d503417`, studied
`hrpc_protocol/serializer.hpp`, `hrpc/client.cpp`,
`libhailort/src/vdma/pcie_session.cpp`, `.hpp` and
`vdma/driver/hailort_driver.cpp`, `.hpp`. Recorded protocol/interface facts:
create/identify/destroy enum indices, nested proto3 field contracts, descriptor
ownership, assigned channels and close/cancel ordering. Independently authored
Mojo code uses those facts; no vendor implementation was copied or translated.
The external test-only protobuf 6.33.6 runtime is an independent oracle, not a
shipped or newly installed runtime dependency. No device was touched in tests.

### 2026-10-19 — Installed driver session UAPI

Read the installed 5.3.0 common-header SPDX declaration:
`(GPL-2.0 WITH Linux-syscall-note) AND MIT`; the installed driver package
copyright identifies GPLv2. Studied packed declarations, enums and ioctl
macros in `common/hailo_ioctl_common.h`, and connection ownership interface
facts in `linux/pcie/src/soc.c`. Header SHA-256:
`a2731314f4676cb140b970043d53cc06d57da90ea46344ccd44a3c491aede26b`.
No driver implementation or declarations were copied/translated into the
production code. The independently authored Mojo codec uses interface facts.
A test-only C++ oracle includes the operator's installed UAPI header to emit
layout and byte evidence; no vendor header is shipped in this repository.
No kernel code was built, installed, loaded or changed. Host-only evidence:
`docs/HAILO10H_MOJO_SOC_ABI.md`.

### 2026-10-19 — Driver file ownership and system UAPI facts

Continued installed 5.3.0 driver interface study: `linux/pcie/src/soc.c`,
`fops.c` and `linux/vdma/vdma.c` for per-file ownership/finalization order.
Recorded behavior only; no GPL implementation copied or translated. Read
installed Linux/glibc system headers for statx, uname, syscall and ARM open
flag ABI facts; no header declarations are shipped. Test-only C++ oracle
includes system headers for independent layout/constant evidence. The native
Mojo owner performs real read-only queries through libc/syscall; no vendor
runtime/bridge, kernel compilation, module or firmware changes are added.
Evidence: `docs/HAILO10H_MOJO_DRIVER_OWNER.md`.

### 2026-10-19 — Assigned descriptor/connection owner

Continued licensed installed-driver interface study in `common/pcie_common.c`,
`vdma_common.h`, `linux/pcie/src/soc.c`, `fops.c`, and `linux/vdma/ioctl.c`,
`vdma.c`: descriptor/connection ownership, PCIe direction mask, bounded control
wait, and finalization ordering. No implementation copied or translated.
Original Mojo ownership policy and physical syscall/fault evidence are in
`docs/HAILO10H_MOJO_SESSION_LIFECYCLE.md`. Driver code was not built, installed,
loaded or modified. No user DMA buffer, transfer or model was supplied.

### 2026-10-19 — Bounded read-only DMA observation

Under `TASK_hailo10h_dma_observation.md`, the independent test observer
includes the installed dual-licensed UAPI and forwards actual libc ioctl in a
private installed-runtime identify child. No vendor implementation is copied,
translated or shipped. Interface study at the already pinned MIT HailoRT
revision: `hrpc/client.cpp`, `vdma/driver/hailort_driver.cpp`; installed driver
UAPI/behavior facts from `linux/vdma/ioctl.c`, `common/vdma_common.c`, and
installed `hailo/hailort.h` status declaration. Extracted exact sizes, result
semantics, request status and unmap keys into the observation receipt before
the next production implementation. No model/inference or kernel changes.
See `docs/HAILO10H_DMA_OBSERVATION.md`.

### 2026-10-19 — USERPTR map/unmap/cache-sync interface

Continued study under the previously read installed UAPI dual license and
installed driver's recorded license: `common/hailo_ioctl_common.h`,
`linux/vdma/ioctl.c` and `memory.c`. Extracted packed field/enum/ioctl facts,
original-tuple unmap identity, sync handle/range rules and context lifetime.
No implementation copied or translated. Independently authored Mojo codecs
are checked against actual C objects from the installed-header test oracle.
See `docs/HAILO10H_MOJO_DMA_STORAGE_ABI.md`. No physical transfer is claimed.

### 2026-10-19 — Native owned RPC storage

Used the already recorded installed UAPI/driver interface facts for original
USERPTR tuple lifetime, map output, sync selector/ranges and file finalization.
The new Mojo ownership policy is independently authored; no vendor code was
copied or translated. Actual anonymous allocation, driver map/sync/unmap and
post-effect malformed reply evidence use the installed driver and strace.
The discarded preload experiment is test research outside production; raw
syscall observation supplies the qualified fault. No DMA transfer was launched.
Receipt: `docs/HAILO10H_MOJO_DMA_STORAGE_OWNER.md`.

### 2026-10-19 — In-process native worker interface

Read current Mojo 1.1 C ABI and public runtime documentation, GNU pthread join
clock manual and Linux pthread_create API documentation. Installed glibc
pthread/time headers identify LGPL-2.1-or-later; read their notice and only
extracted ABI facts, independently checked with system-header C++ oracle.
No libc/runtime implementation is copied or translated. Original Mojo callback
and ownership policy, actual host deadlines and terminal invariant evidence:
`docs/HAILO10H_MOJO_BOUNDED_WORKER.md`. No device was opened by this proof.

### 2026-10-19 — Assigned interrupt disable/join ownership

Continued previously licensed installed-driver interface study in
`linux/vdma/ioctl.c` and `vdma.c`: per-file enabled/interrupted masks,
interruptible wait, disable wakeup and semaphore release during wait. No
implementation copied or translated. Original Mojo session cancellation uses
only assigned channel masks and the independently owned pthread worker.
Actual empty-channel deadlines, retry, terminal invariant and subsequent fresh
sessions are recorded in `docs/HAILO10H_MOJO_ASSIGNED_WAIT.md`. No DMA launch,
inference, kernel, firmware, binding or reset operation was performed.

### 2026-10-19 — Exact RPC descriptor/directional accounting

Continued already licensed installed 5.3.0 UAPI/driver interface study in
`common/vdma_common.c` and `linux/vdma/ioctl.c` for non-cyclic returned count,
IRQ transfer-count meaning and finalization. Facts recorded in the
source-execution research notes and prior reference observation. Original Mojo single-outstanding pair policy
and pending storage guards contain no copied/translated implementation. Host
IRQ snapshots prove accounting/refusals, not hardware execution.

### 2026-10-19 — Independent native device RPC exchange

Implemented the previously recorded/licensed hRPC frame, typed device messages,
USERPTR launch and completion facts using original Mojo ownership/accounting.
No vendor implementation, source translation or runtime bridge is used. The
actual binary does not link HailoRT; the installed driver/firmware provides the
hardware endpoint. Thirty-six physical native child runs cover normal typed
lifecycles, pre-create submission failures, timeout and post-destroy cleanup.
No model/inference or kernel/firmware/binding/reset change. Private identifiers
and RPC bodies are omitted from published output. Receipt:
`docs/HAILO10H_MOJO_NATIVE_RPC.md`.

### 2026-10-19 — Source tensor inventory and GGUF string boundary

Reused the project's own PackedGGUF/GGUFSeer parsing and ownership APIs without
backend registry or inference calls. Read ggml MIT license at frozen commit
`a05c9922613c6a2230dbb1d0de679519ecafb4f0`; consulted only its GGUF specification
for length-prefixed UTF-8 facts (spec SHA-256 recorded in the receipt). No ggml
implementation/header/runtime is copied, translated or linked. Current public
Mojo String API supplies validating byte construction. Original Mojo projection
and independent Python struct-packed fixtures prove descriptors and string
identity, not inference. Receipt: `docs/HAILO10H_MOJO_SOURCE_INVENTORY.md`.

### 2026-10-19 — Typed source semantic graph

Continued the already MIT-licensed pinned GGUF specification study at
`a05c9922613c6a2230dbb1d0de679519ecafb4f0` for attention key/value defaults,
rotary dimensions and layout metadata facts. The existing project dense-GQA
contracts supplied source tensor shape conventions; no CUDA admission registry
or execution path is used. Original Mojo graph/ownership/lifetime construction
and independent synthetic structural oracles copy or translate no external
implementation. No source-model forward or device program is executed.
Receipt: `docs/HAILO10H_MOJO_SEMANTIC_PLAN.md`.

### 2026-10-19 — Original storage lifetime arithmetic

Original Mojo interval-event accounting consumes the project's typed graph.
Independent Python brute-force interval scans and test-only native graph
mutations verify byte arithmetic without external implementation study, model
forward or device access. Supplied assumptions are labelled hypothetical; no
precision, available hardware memory or executable program is inferred.
Receipt: `docs/HAILO10H_MOJO_STORAGE_ESTIMATE.md`.

### 2026-10-19 — Public context action/configuration boundary

Re-read pinned HailoRT v5.3.0 MIT license before the continued study. Public
context/control header definitions, action-list/config-buffer/resource-manager
interfaces and host/local device boundaries supply prose facts and hashes in
`docs/HAILO10H_PUBLIC_CONTEXT_ACTIONS.md`. This is no vendor program extraction
or implementation translation. The next original codec is contracted in
`TASK_hailo10h_context_actions.md`. No device control/write is performed.

### 2026-10-19 — Original context-action codec verification

Implemented the previously published public field facts independently in Mojo.
The test-only C++ oracle includes operator-supplied pinned public headers outside
Git, without vendor runtime linkage. Ten dependency hashes are recorded. Their
MIT notices and the transitive md5 header's Alexander Peslyak public-domain/
permissive notice were read; no MD5 implementation is used or linked. Exact
byte/layout and independent Python checks pass. No vendor implementation or
model/container content is copied or translated. No device/control/write or
model forward occurs. Receipt: `docs/HAILO10H_MOJO_CONTEXT_ACTIONS.md`.

### 2026-10-19 — Server loading boundary and primitive recipe contract

Continued already MIT-licensed pinned server interface study; original prose
facts/hash appended to `docs/HAILO10H_PUBLIC_CONTEXT_ACTIONS.md`. No server is
run, installed or copied. Read paper abstract definitions and arXiv distribution
license notices for RMSNorm (1910.07467) and SiLU (1702.03118); no paper source,
implementation, figure or text is copied. Mathematical definitions and the
project's own epsilon convention inform the original compiler recipe contract
`TASK_hailo10h_primitive_recipes.md`. No numerical model forward.

### 2026-10-19 — Original RMSNorm/SiLU mathematical IR

Original Mojo source-bound expansion from mathematical identities and the
project's normalization convention; no external implementation or paper
text/figure copied. Exact graph/scalar/lifetime checks and tiny synthetic
primitive-only Decimal oracles pass. No numerical production kernel, source
model/layer forward or device program is executed. Receipt:
`docs/HAILO10H_MOJO_PRIMITIVE_RECIPES.md`.
