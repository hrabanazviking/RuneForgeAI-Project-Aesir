#!/bin/bash
# A-099 evidence (team-26): Mojo fallback check + runner fault injection.
set -u
cd /home/volmarr/aesir-team-26 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
S=/home/volmarr/aesir-team-22/scratch/a092
B=$S/build
mkdir -p hidden_files/a099
g++ -O3 -march=native -std=c++17 -I$S -I$S/overlay aesir_engine/npu_prefill_offload.cpp -o hidden_files/a099/npu_prefill_offload /usr/lib/x86_64-linux-gnu/libxrt_coreutil.so.2 -luuid -lpthread || exit 1
pixi run --frozen mojo run -I aesir_engine spikes/a099_measure/fallback_check.mojo > hidden_files/a099/fallback_check.log 2>&1
echo mojo_check_exit=$?
R=./hidden_files/a099/npu_prefill_offload
$R 128 1024 1024 off 4 > hidden_files/a099/fb_flagoff.log 2>&1; echo flagoff_exit=$?
$R 64 64 64 on 2 > hidden_files/a099/fb_noargs.log 2>&1; echo noargs_exit=$?
$R 64 64 64 on 2 /nonexistent/bad.xclbin /nonexistent/instrs.bin > hidden_files/a099/fb_instr_missing.log 2>&1; echo instr_missing_exit=$?
$R 64 64 64 on 2 /nonexistent/bad.xclbin $B/insts.bin > hidden_files/a099/fb_xclbin_missing.log 2>&1; echo xclbin_missing_exit=$?
head -c 64 /dev/urandom > /tmp/a099_garbage.xclbin
$R 64 64 64 on 2 /tmp/a099_garbage.xclbin $B/insts.bin > hidden_files/a099/fb_xclbin_garbage.log 2>&1; echo xclbin_garbage_exit=$?
echo A099_CPU_SIDE_DONE
