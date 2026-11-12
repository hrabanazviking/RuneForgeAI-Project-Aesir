# A-018 Ledger — Thermal & power sensing (team-04, 2026-11-12)

## Deliverable
- NEW aesir_engine/core/thermal_power.mojo: ThermalPower struct +
  observe_thermal_power() (never raises) + thermal_power_lines() +
  parsers/formatters/plausibility/tolerance helpers.
- Doctor integration (aesir_engine/cli/doctor.mojo): text section
  'Thermal & power (runtime-observed)' + JSON "thermal" object
  (unknowns as null via doctor_json_bytes, never fabricated zeros).
- NEW aesir_engine/tests/test_thermal_power.mojo (4 groups);
  run_all.mojo +4 cases, pin 319 -> 323 with house-style comment.

## Sysfs paths used (live on purpleraider)
- /sys/class/hwmon/hwmon13 name=amdgpu: temp1_input (label edge),
  power1_average (label PPT), fallback power1_input.
- /sys/class/hwmon/hwmon8 name=k10temp: temp1_input (label Tctl).
  (zenpower accepted identically if present; it is not here.)
- Fans: first readable fan1_input — hwmon1 acpi_fan (0 RPM);
  asus hwmon9 cpu_fan/gpu_fan also 0 RPM in `sensors`.
- RAPL: /sys/class/powercap/intel-rapl:0 name=package-0;
  energy_uj is mode r-------- root-owned -> Permission denied for
  the test user. Reported present-but-unreadable with reason,
  energy -1/null. NEVER fabricated. Package power is carried by
  the amdgpu PPT reading until a readable RAPL road exists.

## Live values + tolerance tracking (READ FROM LOG FILES)
Baseline capture hidden_files/a018_sensors_baseline.log
(2026-11-12T02:13:18-05:00, sha256 e500040445a34485d0e7ef910a8942fdad0309b158c1f24dac93c4b6e6a37417):
- sensors edge +30.0 C vs sysfs temp1_input 30000 (=30.0 C) — exact
- sensors PPT 7.12 W vs sysfs power1_average 7236000 uW (=7.236 W)
  — diff 0.116 W, inside tolerance (5 W or 30%)
- sensors Tctl +31.0 C vs sysfs 31000 (=31.0 C) — exact
- fans 0 RPM in both sensors and sysfs.
Tolerances: temp +/-3 C; power within 5 W or 30% (PPT moves fast:
first probe sysfs 8.936 W vs sensors 10.74 W moments apart).
Under load the readings move and stay plausible — standalone run
(hidden_files/a018_thermal_standalone.log sha256 7033486a36c51dca81b9847a8fa7cd7e14e976273665e6c0b52a4af07010b163):
GPU edge 32.0 C / PPT 34.0 W, Tctl 47.9 C; in-suite: edge 40.0 C /
PPT 26.5 W, Tctl 51.5 C — the self-throttling slices (later road)
can consume ThermalPower directly.

## Suite (READ FROM LOG)
hidden_files/a018_run_all_canonical.log sha256
e9632e498160fe2d217f3b37c2d9ae080d7a9cadfd376a1b4c3dae8bbc6281ba:
320 passed / 1 failed / 2 skipped / 323 total = seat baseline
316/1/2/319 + exactly the 4 new thermal.* cases, all PASS.
Sole failure = pre-existing gguf.tensor_directory_interface
J-022 drift (roads A-165/A-121), unchanged. Skips = 2 pre-declared.

## Bugs
No new bug discovered in slice scope. Known: RAPL energy_uj
unreadable as non-root on this host (honest-absent handled);
recorded in CAMPAIGN_STATE.md as next-work note, not a code bug.
