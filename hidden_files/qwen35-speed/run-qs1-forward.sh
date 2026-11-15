#!/usr/bin/env bash
set -x
cd /home/volmarr/aesir-qs-cpu
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims"
GGUF=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
/usr/bin/time -v ./hidden_files/qwen35-speed/bench_qs1_forward $GGUF hidden_files/qwen35-adapter/q35-3b-tokens.txt
echo FWD_EXIT=$?
