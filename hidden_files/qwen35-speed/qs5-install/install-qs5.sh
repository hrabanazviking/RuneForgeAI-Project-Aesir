#!/usr/bin/env bash
# QS-5.2 installer: installs the permanent aesir-gate unit +
# watchdog from this folder's sources. Run with sudo.
# Installs and enables; does NOT start aesir-gate.service
# (the QS-5.3 swap starts it, once, as a single restart).
set -e
SRC=/home/volmarr/aesir-qs-stable/hidden_files/qwen35-speed/qs5-install
install -m 644 "$SRC/aesir-gate.service" /etc/systemd/system/aesir-gate.service
install -m 644 "$SRC/aesir-gate-watchdog.service" /etc/systemd/system/aesir-gate-watchdog.service
install -m 644 "$SRC/aesir-gate-watchdog.timer" /etc/systemd/system/aesir-gate-watchdog.timer
install -m 755 "$SRC/aesir-gate-health.sh" /usr/local/sbin/aesir-gate-health.sh
systemctl daemon-reload
# While the Q35-7 transient unit of the same name is loaded,
# it shadows this file and enable is refused ("transient or
# generated"). That is expected pre-swap: the QS-5.3 swap
# stops the transient, daemon-reloads, then enables.
if systemctl enable aesir-gate.service 2>/dev/null; then
  echo "aesir-gate.service enabled"
else
  echo "NOTE: aesir-gate.service enable deferred to the swap (transient unit of the same name is still loaded)"
fi
systemctl enable aesir-gate-watchdog.timer
echo QS5_INSTALL_DONE
systemctl is-enabled aesir-gate-watchdog.timer
