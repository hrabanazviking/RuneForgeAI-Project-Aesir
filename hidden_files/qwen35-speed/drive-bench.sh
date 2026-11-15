#!/usr/bin/env bash
exec >> /home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed/qs2-gemv-bench.log 2>&1
cd /home/volmarr/aesir-qs-hip
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims"
grep MemAvailable /proc/meminfo
./hidden_files/qwen35-speed/bench_qwen35_gemv_qs2 5
echo BENCH_EXIT=$?
grep MemAvailable /proc/meminfo
