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
