#!/usr/bin/env bash
# Q35-3r serve proofs on side port 18435 (gate on 18434 untouched).
cd /home/volmarr/aesir-q35-3r
H=hidden_files/qwen35-adapter
F=aesir_engine/tests/fixtures/qwen35_forward.gguf
printf 'q353r-proof-key-0123456789abcdef0123456789' > /tmp/q353r-key.txt
chmod 600 /tmp/q353r-key.txt
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
wait_health() {
  for i in $(seq 1 60); do
    if curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer q353r-proof-key" http://127.0.0.1:18435/health 2>/dev/null | grep -q 200; then return 0; fi
    sleep 2
  done
  return 1
}
# 1) resident serve
sudo systemd-run --unit=q353r-serve1 -p User=volmarr -p WorkingDirectory=/home/volmarr/aesir-q35-3r -p MemoryHigh=24G -p MemoryMax=32G bash -c "export HOME=/home/volmarr; export LD_LIBRARY_PATH=/home/volmarr/aesir-q35-3r/hidden_files/hip-serve/shims; /home/volmarr/aesir-q35-3r/.aesir/aesir serve $F --accel cpu --profile qwen35 --experimental-qwen35 --qwen35-resident --port 18435 --context 512 --max-tokens 16 --model-store .aesir/q353r-store --api-key-file /tmp/q353r-key.txt > /home/volmarr/aesir-q35-3r/$H/q35-3r-serve-resident.log 2>&1"
wait_health && echo SERVE1_HEALTHY || echo SERVE1_NO_HEALTH
python3 $H/q35_3r_bench.py resident > $H/q35-3r-bench-resident.log 2>&1; echo BENCH_RESIDENT_EXIT=$?
sudo systemctl stop q353r-serve1; sleep 2
# 2) default serve (no resident flag)
sudo systemd-run --unit=q353r-serve2 -p User=volmarr -p WorkingDirectory=/home/volmarr/aesir-q35-3r -p MemoryHigh=24G -p MemoryMax=32G bash -c "export HOME=/home/volmarr; export LD_LIBRARY_PATH=/home/volmarr/aesir-q35-3r/hidden_files/hip-serve/shims; /home/volmarr/aesir-q35-3r/.aesir/aesir serve $F --accel cpu --profile qwen35 --experimental-qwen35 --port 18435 --context 512 --max-tokens 16 --model-store .aesir/q353r-store --api-key-file /tmp/q353r-key.txt > /home/volmarr/aesir-q35-3r/$H/q35-3r-serve-default.log 2>&1"
wait_health && echo SERVE2_HEALTHY || echo SERVE2_NO_HEALTH
python3 $H/q35_3r_bench.py default > $H/q35-3r-bench-default.log 2>&1; echo BENCH_DEFAULT_EXIT=$?
sudo systemctl stop q353r-serve2; sleep 2
# 3) refusals
.aesir/aesir serve aesir_engine/tests/fixtures/qwen35_forward_f16probe.gguf --accel cpu --profile qwen35 --experimental-qwen35 --qwen35-resident --port 18435 --context 512 --max-tokens 16 --model-store .aesir/q353r-store --api-key-file /tmp/q353r-key.txt > $H/q35-3r-refusal-f16probe.log 2>&1; echo REFUSAL_F16PROBE_EXIT=$?
.aesir/aesir serve $F --accel cpu --profile llama3 --qwen35-resident --port 18435 --context 512 --max-tokens 16 --model-store .aesir/q353r-store --api-key-file /tmp/q353r-key.txt > $H/q35-3r-refusal-profile.log 2>&1; echo REFUSAL_PROFILE_EXIT=$?
ss -ltn | grep 18435 || echo PORT_18435_FREE
systemctl is-active aesir-gate || true
echo SERVE_PROOFS_DONE
