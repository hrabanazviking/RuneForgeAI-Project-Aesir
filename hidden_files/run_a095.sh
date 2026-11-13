#!/bin/bash
# A-095 evidence reproduction (team-25): registry dispatch check,
# offload runner build + CPU/NPU measurement runs. The E-MASTER suite
# runs separately in seat-gate form (see hidden_files/A095_LEDGER.md).
set -u
cd /home/volmarr/aesir-team-25 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
S=/home/volmarr/aesir-team-22/scratch/a092
SHAPES=/home/volmarr/aesir-team-24/hidden_files/a094/shapes
B=$S/build
mkdir -p hidden_files/a095
g++ -O3 -march=native -std=c++17 -I$S -I$S/overlay aesir_engine/npu_prefill_offload.cpp -o hidden_files/a095/npu_prefill_offload /usr/lib/x86_64-linux-gnu/libxrt_coreutil.so.2 -luuid -lpthread || exit 1
g++ -O3 -march=native -std=c++17 spikes/a095_measure/cpu_compare.cpp -o hidden_files/a095/cpu_compare_fresh -lpthread || exit 1
pixi run --frozen mojo run -I aesir_engine spikes/a095_measure/dispatch_check.mojo > hidden_files/a095/dispatch_check.log 2>&1
./hidden_files/a095/cpu_compare_fresh > hidden_files/a095/cpu_compare_fresh.log 2>&1
./hidden_files/a095/npu_prefill_offload 128 1024 1024 off 128 > hidden_files/a095/offload_flagoff_p128.log 2>&1
./hidden_files/a095/npu_prefill_offload 32 1024 1024 on 8 > hidden_files/a095/offload_belowband_p32.log 2>&1
sudo -n ./hidden_files/a095/npu_prefill_offload 64 64 64 on 8 $B/final.xclbin $B/insts.bin > hidden_files/a095/offload_xdna_64.log 2>&1
sudo -n ./hidden_files/a095/npu_prefill_offload 128 1024 1024 on 128 $SHAPES/final_p128.xclbin $SHAPES/insts_p128.bin > hidden_files/a095/offload_xdna_p128.log 2>&1
echo A095_EVIDENCE_DONE
