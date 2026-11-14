#!/usr/bin/env bash
# Q35-6 fixture HIP serve proof on side port 18435.
cd /home/volmarr/aesir-q35-6
H=hidden_files/qwen35-adapter
F=aesir_engine/tests/fixtures/qwen35_forward.gguf
printf 'q356-proof-key-0123456789abcdef0123456789' > /tmp/q356-key.txt
chmod 600 /tmp/q356-key.txt
export XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims"
grep MemAvailable /proc/meminfo
ss -ltn | grep 18435 && echo PORT_BUSY || echo PORT_18435_FREE
systemd-run --user --unit=q356-serve2 -p MemoryMax=32G --working-directory=/home/volmarr/aesir-q35-6 bash -c "export HOME=/home/volmarr; export LD_LIBRARY_PATH=/home/volmarr/aesir-q35-6/hidden_files/hip-serve/shims; /home/volmarr/aesir-q35-6/.aesir/aesir serve aesir_engine/tests/fixtures/qwen35_forward.gguf --accel hip --profile qwen35 --experimental-qwen35 --port 18435 --context 512 --max-tokens 16 --model-store .aesir/q356-store --api-key-file /tmp/q356-key.txt > /home/volmarr/aesir-q35-6/hidden_files/qwen35-adapter/q35-6-serve.log 2>&1"
for i in $(seq 1 60); do
  code=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer q356-proof-key-0123456789abcdef0123456789" http://127.0.0.1:18435/health 2>/dev/null)
  if [ "$code" = "200" ]; then echo SERVE_HEALTHY; break; fi
  sleep 2
done
curl -s -H "Authorization: Bearer q356-proof-key-0123456789abcdef0123456789" http://127.0.0.1:18435/health; echo
./.aesir/aesir serve $F --accel hip --profile qwen35 --port 18435 --context 512 --max-tokens 16 --model-store .aesir/q356-store --api-key-file /tmp/q356-key.txt > $H/q35-6-refusal-noexperimental.log 2>&1
echo REFUSAL_NOEXPERIMENTAL_EXIT=$?
python3 $H/q35_6_bench.py > $H/q35-6-bench.log 2>&1; echo BENCH_EXIT=$?
cat $H/q35-6-bench.log
systemctl --user stop q356-serve2; sleep 2
ss -ltn | grep 18435 || echo PORT_18435_FREE_AFTER
grep MemAvailable /proc/meminfo
echo SERVE_PROOF_DONE
