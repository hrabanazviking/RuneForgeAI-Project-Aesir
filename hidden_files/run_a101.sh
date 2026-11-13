#!/bin/bash
# A-101 pipeline probe build + run recipe (team-25).
cd /home/volmarr/aesir-team-25/spikes/a101_pipeline || exit 99
g++ -O2 -std=c++17 -I/home/volmarr/aesir-team-22/scratch/a092/overlay -I/home/volmarr/aesir-team-22/scratch/a092 pipeline_probe.cpp -o pipeline_probe /usr/lib/x86_64-linux-gnu/libxrt_coreutil.so.2 -luuid -lpthread -lvulkan || exit 98
glslc gemv.comp -o gemv.spv || exit 97
sudo -n ./pipeline_probe final_p128.xclbin insts_p128.bin gemv.spv 64
