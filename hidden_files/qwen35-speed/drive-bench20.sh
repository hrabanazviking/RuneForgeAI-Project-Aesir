#!/usr/bin/env bash
exec > /home/volmarr/aesir-qs-hip/hidden_files/qwen35-speed/qs2-gemv-bench20.log 2>&1
cd /home/volmarr/aesir-qs-hip
export PATH="$HOME/.pixi/bin:$PATH"
SH=hidden_files/hip-serve/shims
export LD_LIBRARY_PATH="$PWD/$SH"
grep MemAvailable /proc/meminfo; cat /proc/loadavg
hidden_files/qwen35-speed/bench_qwen35_gemv_qs2 20
echo BENCH20_EXIT=$?
