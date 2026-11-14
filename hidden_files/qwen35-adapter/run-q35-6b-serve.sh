#!/usr/bin/env bash
# Q35-6b real-file HIP serve proof on side port 18435.
cd /home/volmarr/aesir-q35-6
H=hidden_files/qwen35-adapter
REAL=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
printf 'q356b-proof-key-0123456789abcdef0123456789' > /tmp/q356b-key.txt
chmod 600 /tmp/q356b-key.txt
export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims"
grep MemAvailable /proc/meminfo
ps aux | grep -E 'mojo|cc1|clang|aesir' | grep -v grep | head -5
ss -ltn | grep 18435 && echo PORT_BUSY || echo PORT_18435_FREE
systemd-run --user --unit=q356b-serve -p MemoryMax=96G --working-directory=/home/volmarr/aesir-q35-6 bash -c "export HOME=/home/volmarr; export LD_LIBRARY_PATH=/home/volmarr/aesir-q35-6/hidden_files/hip-serve/shims; /home/volmarr/aesir-q35-6/.aesir/aesir serve /mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf --accel hip --profile qwen35 --experimental-qwen35 --port 18435 --context 4096 --max-tokens 48 --timeout-ms 1800000 --model-store .aesir/q356b-store --api-key-file /tmp/q356b-key.txt > /home/volmarr/aesir-q35-6/hidden_files/qwen35-adapter/q35-6b-serve.log 2>&1"
( peak=0; while true; do pid=$(pgrep -f '^/home/volmarr/aesir-q35-6/.aesir/aesir serve' | head -1); if [ -n "$pid" ]; then h=$(awk '/VmHWM/{print $2}' /proc/$pid/status 2>/dev/null); if [ -n "$h" ] && [ "$h" -gt "$peak" ]; then peak=$h; fi; fi; echo $peak > /tmp/q356b-peak-kb.txt; sleep 5; done ) &
SAMPLER=$!
for i in $(seq 1 90); do
  code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer q356b-proof-key-0123456789abcdef0123456789" http://127.0.0.1:18435/health 2>/dev/null)
  if [ "$code" = "200" ]; then echo SERVE_HEALTHY; break; fi
  sleep 2
done
curl -s -H "Authorization: Bearer q356b-proof-key-0123456789abcdef0123456789" http://127.0.0.1:18435/health; echo
python3 $H/q35_6b_bench.py > $H/q35-6b-bench.log 2>&1; echo BENCH_EXIT=$?
cat $H/q35-6b-bench.log
kill $SAMPLER; echo SERVE_VMHWM_PEAK_KB=$(cat /tmp/q356b-peak-kb.txt)
systemctl --user stop q356b-serve; sleep 2
ss -ltn | grep 18435 || echo PORT_18435_FREE_AFTER
grep MemAvailable /proc/meminfo
echo SERVE_6B_DONE
