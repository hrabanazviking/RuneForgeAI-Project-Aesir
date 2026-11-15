#!/usr/bin/env bash
# QS-1 fenced serve bench: my build on :18436, gate untouched.
# Caller must hold HEAVY.lock. Serve unit qs1-serve is stopped
# at the end no matter what.
set -x
cd /home/volmarr/aesir-qs-cpu
QS=hidden_files/qwen35-speed
GGUF=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
if [ ! -f $QS/qs1.key ]; then tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32 > $QS/qs1.key; echo >> $QS/qs1.key; chmod 600 $QS/qs1.key; fi
grep MemAvailable /proc/meminfo; uptime
sudo systemd-run --unit=qs1-serve -p User=volmarr -p WorkingDirectory=/home/volmarr/aesir-qs-cpu -p MemoryHigh=48G -p MemoryMax=64G --setenv=LD_LIBRARY_PATH=/home/volmarr/aesir-qs-cpu/hidden_files/hip-serve/shims ./.aesir/aesir serve $GGUF --accel cpu --profile qwen35 --qwen35-resident --api-key-file /home/volmarr/aesir-qs-cpu/$QS/qs1.key --context 4096 --max-tokens 512 --timeout-ms 900000 --port 18436
for i in $(seq 1 40); do
  sleep 5
  if curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $(cat $QS/qs1.key)" http://127.0.0.1:18436/health | grep -q 200; then echo SERVE_READY after ${i}x5s; break; fi
done
python3 $QS/qs1_bench.py > $QS/qs1-bench.log 2>&1; echo BENCH_EXIT=$?
sudo systemctl stop qs1-serve; echo SERVE_STOPPED
grep MemAvailable /proc/meminfo
echo QS1_SERVE_BENCH_DONE
