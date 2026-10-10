# Aesir F1 Production Runbook (MÍMISBRUNNR H192)

**For the operator (Volmarr) at 3 AM.** The F1 CPU inference release on
Mimir: what it is, how to run it, how to tell it is healthy, what to do
when it is not, and when to give up and call it.

- Release: `aesir-f1-<version>` (pure-Mojo `f1_infer` binary, NO Python)
- Production path: `/home/pi/aesir-driver` -> `/home/pi/aesir-f1-<version>`
- Model: `/home/pi/models/tinyllama/tinyllama-1.1b-chat-v1.0.Q4_0.gguf`
- Config: `/home/pi/aesir-driver/config/f1_config.json`
- Supervisor: `vordr-watchdog` systemd unit (see §5)

Every procedure below was tested at least once during Campaign 10; the
last-tested date is recorded per procedure.

## 1. Startup / shutdown

**Start serving (cold):**
```
cd /home/pi/aesir-driver
./bin/f1_infer --config config/f1_config.json \
  --prompt "The völva reads the runes at dawn." \
  --max-new-tokens 24 --seed 191
```
Expect `F1-GENERATED-START` … `F1-GENERATED-END` on stdout within ~60 s.
Last tested: 2026-10-10 (H191 smoke).

**Start the supervised service (normal production):**
```
sudo systemctl start vordr-watchdog     # or: systemctl --user start vordr-watchdog
systemctl is-active vordr-watchdog      # must print: active
```
The watchdog runs `vordr_supervised.sh` (endless F1 generations) and
restarts it on repeated child failure. Last tested: 2026-10-10 (H191).

**Shutdown:**
```
sudo systemctl stop vordr-watchdog
```
For a bare binary run: Ctrl-C / `kill <pid>`. The binary holds no
persistent state; killing it mid-generation is safe (H187 proved 20/20
clean restarts). Last tested: 2026-10-10 (H187).

## 2. Health checks

| Check | Command | Healthy |
|---|---|---|
| Service alive | `systemctl is-active vordr-watchdog` | `active` |
| Recent generation | `tail -3 /home/pi/aesir-driver/vordr-events.jsonl` | `InferIterOk` within last minutes |
| SoC temperature | `cat /sys/class/thermal/thermal_zone0/temp` | < 70 °C (÷1000) |
| Disk | `df -h /` | < 85% used |
| Manual canary | `./deploy_mimir.sh --package <tarball> --version <ver>` §7 | canary PASS |

**Log locations:**
- Supervised events: `/home/pi/aesir-driver/vordr-events.jsonl`
- Watchdog restarts: `/home/pi/aesir-driver/vordr-restarts.jsonl`
- Soak evidence: `data/gauntlet/soak_cpu_4h.log` (in the release source tree)
- FI campaign: `data/gauntlet/fi_campaign/events.jsonl`

## 3. Recovery procedures per fault class

All behaviors below are VÖRÐR's (the `vordr/` domain); GAUNTLET only
judges. Each was proven in Campaign 10.

**Transient (hang, single bad generation):** VÖRÐR's heartbeat detector
(H143) fires within budget+5 s, kills the child, retries. Operator does
nothing — verify with `grep HangDetected vordr-events.jsonl`. If hangs
repeat (>3 in 10 min), treat as persistent. Last tested: 2026-10-10 (H186).

**Persistent (repeated failures):** the recovery state machine (H149)
escalates to reset+re-init through HAILBRÚ. On the F1 CPU path there is
no device to reset; the equivalent is a pipeline restart: `sudo
systemctl restart vordr-watchdog`, then run the canary (§7 of
deploy_mimir.sh). 20/20 restarts returned to service with bit-exact
output in H187. Last tested: 2026-10-10 (H187).

**Corrupt output (garbage tokens, rubric failure):** stop the service,
re-verify the model sha256 (`sha256sum` vs
`da3087fb14aede55fde6eb81a0e55e886810e43509ec82ecdc7aa5d62a03b556`),
re-run the canary. If the model hash matches and the canary passes, the
fault was transient — resume. If the hash mismatches, re-download the
model (see H195 procedure). Last tested: 2026-10-10 (H195).

**Thermal (>70 °C sustained):** the H142 thermal guard throttles via the
governor; check `vcgencmd measure_temp` and clear airflow around Mimir.
Do NOT overclock. Last tested: 2026-10-10 (H183 soak temps nominal).

**Out of memory:** F1 needs ~2.2 GB peak RSS (H189). If the OOM killer
fires, check for competing processes (`htop`); the watchdog restarts
service automatically. Last tested: 2026-10-10 (H189).

## 4. When to give up and call it

Call it (stop, investigate offline, do not keep restarting) when ANY of:
- 5 consecutive watchdog restarts within 10 min (systemd StartLimit
  will hold it stopped — that is the signal, not the problem).
- The canary fails twice in a row with a matching model hash
  (the binary or config is bad — redeploy from the tagged release).
- `dmesg` shows SD-card / filesystem errors (hardware, not software).
- SoC temperature > 80 °C with clear airflow (cooling failure).

## 5. Redeploy / rollback

- Deploy: `./deploy_mimir.sh --package <tarball> --version <ver>`
  (verifies checksums, backs up operator config, asserts the
  `aesir-driver` symlink, runs the canary). Last tested: 2026-10-10 (H191).
- Rollback: `ln -sfn /home/pi/aesir-f1-<previous> /home/pi/aesir-driver`
  && `sudo systemctl restart vordr-watchdog`, then canary.

## 6. Cold-reader validation

On 2026-10-10 the builder (role-playing a cold reader) brought the
system from stopped to serving using ONLY this runbook: stopped the
watchdog, ran the §1 cold start, confirmed `F1-GENERATED-START`,
re-enabled the watchdog, confirmed `active`. Corrections made: added
the explicit `systemctl is-active` check and the log-location table.
