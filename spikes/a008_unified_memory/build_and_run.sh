#!/bin/sh
# A-008 unified-memory probe: build + run (purpleraider, no hipcc needed)
set -e; cd "$(dirname "$0")"
gcc -O2 -std=gnu11 -D__HIP_PLATFORM_AMD__ -I/usr/include -o hip_unified_probe hip_unified_probe.c -lamdhip64 -lhiprtc -lm
gcc -O2 -std=gnu11 -D__HIP_PLATFORM_AMD__ -I/usr/include -o reread_probe reread_probe.c -lamdhip64 -lhiprtc -lm
glslc fill.comp -o fill.spv; glslc sum.comp -o sum.spv
gcc -O2 -std=gnu11 -o vk_coherent_probe vk_coherent_probe.c -lvulkan
./hip_unified_probe            # HIP managed / pinned / device, gfx1151 asserted
./reread_probe                 # CPU re-read symmetry check on managed memory
./vk_coherent_probe . 0        # Vulkan host-CACHED coherent type
./vk_coherent_probe . 1        # Vulkan DEVICE_LOCAL coherent (device-uncached) type
