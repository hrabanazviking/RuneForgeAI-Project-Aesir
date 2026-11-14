#!/usr/bin/env bash
# Q35-7 stage-1 serve proof: this tree's binary, REAL 27B resident, side port 18435.
cd /home/volmarr/aesir-q35-7
H=hidden_files/qwen35-adapter
REAL=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
grep MemAvailable /proc/meminfo
sudo systemd-run --unit=q35-7-serve1 -p User=volmarr -p WorkingDirectory=/home/volmarr/aesir-q35-7 -p MemoryHigh=48G -p MemoryMax=64G bash -c "export HOME=/home/volmarr; export LD_LIBRARY_PATH=/home/volmarr/aesir-q35-7/hidden_files/hip-serve/shims; /home/volmarr/aesir-q35-7/.aesir/aesir serve $REAL --accel cpu --profile qwen35 --qwen35-resident --port 18435 --context 4096 --max-tokens 48 --timeout-ms 900000 --api-key-file /home/volmarr/.config/aesir/service.key > /home/volmarr/aesir-q35-7/$H/q35-7-serve-stage1.log 2>&1"
for i in $(seq 1 90); do
  code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $(cat /home/volmarr/.config/aesir/service.key)" http://127.0.0.1:18435/health 2>/dev/null)
  if [ "$code" = "200" ]; then echo SERVE_HEALTHY after ${i}x2s; break; fi
  sleep 2
done
python3 $H/q35_7_bench.py 18435 /home/volmarr/.config/aesir/service.key > $H/q35-7-bench-stage1.log 2>&1; echo BENCH_EXIT=$?
grep VmHWM /proc/$(pgrep -f 'aesir serve' | head -1)/status || true
grep MemAvailable /proc/meminfo
sudo systemctl stop q35-7-serve1; sleep 2
ss -ltn | grep 18435 || echo PORT_18435_FREE
