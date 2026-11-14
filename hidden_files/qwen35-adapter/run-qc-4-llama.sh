#!/usr/bin/env bash
cd /home/volmarr/aesir-qc-4
H=hidden_files/qwen35-adapter
STORIES=/home/volmarr/aesir-team-01/hidden_files/fixtures/stories260K.F16.gguf
LC=/home/volmarr/llama.cpp-build/build/bin/llama-cli
$LC --version > $H/qc-4-llama-version.log 2>&1; echo VERSION_EXIT=$?
$LC -m $H/stories260K.Q8_0.gguf -p "One day, Timmy went to" -n 16 --temp 0 -t 4 > $H/qc-4-llama-load-q8.log 2>&1; echo LLAMA_Q8_EXIT=$?
$LC -m $STORIES -p "One day, Timmy went to" -n 16 --temp 0 -t 4 > $H/qc-4-llama-load-f16.log 2>&1; echo LLAMA_F16_EXIT=$?
$H/qc4grade $STORIES $H/qc-4-streams.txt $H/qc-4-prompts.txt $H/qc-4-rows-llama-f16.bin $H/qc-4-gen-llama-f16.txt 4 > $H/qc-4-qc4grade-f16.log 2>&1; echo GRADE_F16_EXIT=$?
$H/qc4grade $H/stories260K.Q8_0.gguf $H/qc-4-streams.txt $H/qc-4-prompts.txt $H/qc-4-rows-llama-q8.bin $H/qc-4-gen-llama-q8.txt 4 > $H/qc-4-qc4grade-q8.log 2>&1; echo GRADE_Q8_EXIT=$?
echo LLAMA_RUNS_DONE
