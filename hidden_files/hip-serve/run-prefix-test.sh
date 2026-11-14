#!/usr/bin/env bash
cd /home/volmarr/aesir-hipserve
export LD_LIBRARY_PATH="hidden_files/hip-serve/shims:.pixi/envs/default/lib"
./hidden_files/hip-serve/test_hip_prompt_prefix .aesir/models/Llama-3.2-3B-Instruct-Q4_K_M.gguf > hidden_files/hip-serve/hip-prefix-test.log 2>&1
echo RUN_EXIT=$? >> hidden_files/hip-serve/hip-prefix-test.log
