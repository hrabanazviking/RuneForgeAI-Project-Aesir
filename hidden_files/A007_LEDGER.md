# A-007 Ledger — XRT userland bring-up (team-07)

- Date: 2026-11-11 (EST, purpleraider local)
- Machine: purpleraider — ASUS ROG Flow Z13, AMD RYZEN AI MAX+ 395 w/ Radeon 8060S, XDNA 2 NPU, 32 threads, 121 GiB
- OS: Ubuntu 26.10 (stonking), kernel 7.3.0-10-generic
- Worktree: /home/volmarr/aesir-team-07, branch yrsa/aesir-team-07, base ba0cf066
- Method: native Ubuntu packages only (apt). NO Docker. sudo -n worked non-interactively.
- VERDICT: SUCCESS — the successor tool reports the XDNA 2 device (see Acceptance). No blocker; NPU waves do NOT need to re-plan around a missing userland.

## Hardware / driver state BEFORE install (hidden_files/a007_probe1.log)
- NPU on PCI: c5:00.1 AMD Strix/Krackan/Strix Halo Neural Processing Unit [1022:17f0] rev 11 — the XDNA 2 device.
- Kernel driver amdxdna (in-tree, 7.3.0-10-generic) LOADED; firmware amdnpu/17f0_11/npu_7.sbin loaded at boot (dmesg in a007_xrtsmi_diag.log); firmware files present under /lib/firmware/amdnpu/17f0_11/ (incl. npu.sbin.1.1.2.65.zst).
- Device node /dev/accel/accel0 (root:render, ACL user:volmarr rw); /sys/class/accel/accel0 -> device 0000:c5:00.1, power_state D0.
- xbutil / xrt-smi ABSENT; no XRT packages installed. The kernel side was already complete — only the userland was missing.

## Road taken — Ubuntu 26.10 native XRT packages (a007_probe2.log)
- The roadmap note said a prior crew found no safe 26.10 package. That no longer holds on this machine: Ubuntu 26.10 universe ships XRT 2.25.0 NPU packages. apt-cache policy: libxrt-npu2 / libxrt-utils-npu / libxrt2 / libxrt-utils all candidate 1:2.25.0-4ubuntu1 (500 stonking/universe).
- apt-get install -s dry-run: 4 NEW packages only, 0 upgraded, 0 removed, NO dkms/kernel packages — the in-tree amdxdna driver is reused, no reboot, no kernel surgery. That is why this road is safe where an upstream .deb + DKMS road would not be.
- Neither AMD upstream .debs nor a source build were needed; both remain fallbacks if the distro packages ever lag.

## Install (hidden_files/a007_install.log, APT_EXIT=0)
Command: sudo -n env DEBIAN_FRONTEND=noninteractive apt-get install -y libxrt-npu2 libxrt-utils-npu libxrt-utils
Newly installed (4, Ubuntu XRT 2.25.0 series for stonking): libxrt2, libxrt-npu2, libxrt-utils, libxrt-utils-npu (all 1:2.25.0-4ubuntu1; 5,490 kB, 18.8 MB).
Pre-install baseline: hidden_files/a007_preinstall.log.

## Acceptance — proven from filed logs (hidden_files/a007_xbutil.log)
- xbutil is the Alveo-era tool and is NOT shipped for the NPU stack; its successor xrt-smi (/usr/bin/xrt-smi, XRT 2.25.00) is the tool the roadmap's "or successor tool" clause names.
- sudo xrt-smi examine (exit 0) reports:
  XRT Version 2.25.00; amdxdna Version 7.3.0-10-generic; NPU Firmware Version 1.1.2.65;
  Device(s) Present: [0000:c5:00.1] NPU Strix Halo, Architecture aie2p, Topology 6x8.
- sudo xrt-smi examine --report all adds: AIE Partitions (no hardware contexts running), Platform NPU Strix Halo, Total Columns 8.
- This is device evidence from the vendor tool against the live driver/firmware — not inference from PCI presence.

## Known caveats / next work (honest, not blockers)
1. UNPRIVILEGED xrt-smi examine FAILS for user volmarr: mmap(len=67108864) EAGAIN (Resource temporarily unavailable). Root cause: RLIMIT_MEMLOCK is 8192 kB (ulimit -l) while XRT maps a 64 MiB locked region; root bypasses the limit, which is why the root run succeeds. Device-node access itself is fine (ACL rw for volmarr). FIX (needs Volmarr's word / a re-login, NOT done in this slice): raise memlock for the user (e.g. /etc/security/limits.d entry or systemd user.conf DefaultLimitMEMLOCK) to >= 1 GiB. Until then, NPU tooling runs via sudo. Recorded as immediate next work in CAMPAIGN_STATE.md.
2. xrt-smi validate cannot run yet: it needs the test archive amdxdna/bins/xrt_smi_strx.a (smi_install_archive.sh xrt_smi_strx.a 2.25.00, from github.com/Xilinx/VTD archives) — hidden_files/a007_validate.log, VALIDATE_EXIT=1. Fetching that archive is the first step of the first real NPU-execution slice (A-092), not of this bring-up slice.
3. A transient python holder of /dev/accel/accel0 was observed during probing (fuser, a007_xrtsmi_diag.log); it did not affect the root examine and is not held by this team.

## Full suite (E-MASTER, canonical sm_89 compile-target, CPU execution)
- hidden_files/a007_run_all_canonical.log: see CAMPAIGN_STATE.md for the counts read from that log (must equal baseline 277 passed / 1 failed / 2 skipped / 280; the 1 failure is the pre-existing gguf.tensor_directory_interface J-022 drift).
- Repo code changes: NONE. Install/evidence-only slice (same pattern as A-005). Evidence lives in hidden_files/: a007_probe1.log, a007_probe2.log, a007_probe3.log, a007_preinstall.log, a007_install.log, a007_xbutil.log, a007_xrtsmi_diag.log, a007_validate.log, a007_run_all_canonical.log, run_a007.sh, A007_LEDGER.md.

## Suite result (appended after the confirmation re-run)
- Canonical log hidden_files/a007_run_all_canonical.log: 277 passed / 1 failed / 2 skipped / 280 total — IDENTICAL to baseline; sole failure is the pre-existing gguf.tensor_directory_interface.
- First run (a007_run_all_first.log) read 276/2/2/280: the extra failure was resilience.state_vault_rejects_growth, a timing race test, run while a torch bench (235% CPU) and other teams' suites shared the machine. It passed on the clean re-run; XRT packages touch no code in that path. Filed as a contention flake, not a regression and not an XRT defect.
