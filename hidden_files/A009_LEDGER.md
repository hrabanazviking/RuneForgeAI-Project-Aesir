# A-009 Ledger — Backend registry skeleton (team-09)

- Worktree: /home/volmarr/aesir-team-09, branch yrsa/aesir-team-09, base ba0cf0662d5fbc6a4531645cb435bc17b6916443
- Deliverable: aesir_engine/core/backend_registry.mojo (typed BackendCapability/BackendRegistry: HIP/Vulkan/XRT/CPU, present/absent/degraded, version + device identity, injectable RawBackendProbe, pure parsers for HIP header / rocminfo / vulkaninfo summary / XRT dpkg version; live probes via AMDGate, vulkaninfo, sysfs /dev/accel/accel0 + dpkg-query, /proc/cpuinfo). Surfaced in aesir_engine/cli/doctor.mojo text (Backend registry section) and JSON ("backends" object).
- Tests: aesir_engine/tests/test_backend_registry.mojo, 4 cases registered in run_all.mojo (cli.backend_registry_all_present, _absent_combinations [all 16 subsets], _degraded_and_software_vulkan [llvmpipe refused], _parsers); finish pin re-pinned 280 -> 284 with note.
- Bugs found/fixed in-slice: Mojo aliasing error in parse_xrt_package_version (String(epoch[1]) on a split of the assigned variable) — fixed with copy-temporaries; no other bugs. Doctor invocation needed both -I . and -I aesir_engine (hailbru module resolution) — recorded in the doctor runner script, not a code bug.

## Real doctor output (purpleraider, text)
Backend registry

  HIP present - version 7.15.0, device AMD Radeon 8060S Graphics (libamdhip64 loadable via AMDGate)
  Vulkan present - version 1.4.354, device AMD Radeon 8060S Graphics (RADV STRIX_HALO) (Vulkan GPU device reported by vulkaninfo)
  XRT present - version 2.25.0, device NPU via /dev/accel/accel0 (XDNA, amdxdna) (device present via sysfs /dev/accel/accel0; unprivileged xrt-smi examine is blocked (RLIMIT_MEMLOCK), so this is presence only -- no NPU execution is claimed)
  CPU present, device AMD RYZEN AI MAX+ 395 w/ Radeon 8060S (host CPU reported by /proc/cpuinfo)

JSON "backends" object: all four present — hip 7.15.0 / AMD Radeon 8060S Graphics; vulkan 1.4.354 / AMD Radeon 8060S Graphics (RADV STRIX_HALO); xrt 2.25.0 / NPU via /dev/accel/accel0 (XDNA, amdxdna), presence only, no NPU execution claimed; cpu / AMD RYZEN AI MAX+ 395 w/ Radeon 8060S. (Full JSON in a009_doctor_json.log.)

## Exact commands
- Registry probe: pixi run --frozen mojo run -I aesir_engine /tmp/probe_a009.mojo (probe imports observe_backend_registry and prints lines)
- Doctor text/json: bash hidden_files/run_a009_doctor.sh [--format json] (stages hailo stub + thread_par, pixi run --frozen mojo run -I . -I aesir_engine --target-accelerator sm_89 -Xlinker -L<staging> -laesir_hailo10h -laesir_par aesir_engine/main.mojo doctor)
- Full suite: bash hidden_files/run_a009.sh (canonical E-MASTER shape: staging cc stubs, pixi run --frozen mojo run -I . --target-accelerator sm_89 -Xlinker ... aesir_engine/tests/run_all.mojo)

## Results (read from logs)
- Suite: 281 passed / 1 failed / 2 skipped / 284 total. Sole failure = pre-existing tolerated gguf.tensor_directory_interface (J-022 drift). Skips = 2 pre-declared. Baseline was 277/1/2 of 280; +4 new A-009 cases, all PASS, no regressions.
- Log sha256:
  - a009_run_all.log 8c5263851b354e07487838cbc9b893146b804fff7a038e39d83ecd6f17cd2383
  - a009_doctor_text.log 4954c4aa3a08750771eb0b4e8950d4f5bb0aebc6e0368677ab88abbf4488161e
  - a009_doctor_json.log 93e85fe19fc2048e2237b4635c0aded0eb4ff652048a28eddada48e6798d61b4
  - a009_probe.log b3048a6a194bd1280bf2a680b2064c7de0033ce79605a95664afc620ee77d27a
