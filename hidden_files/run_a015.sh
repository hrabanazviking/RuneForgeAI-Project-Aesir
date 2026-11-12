#!/bin/bash
cd /home/volmarr/aesir-team-01 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
{
echo "=== A-015 E-MASTER run (team-01, Vulkan compute dispatch smoke) ==="
date -Is; hostname; uname -a
nproc; free -g | head -n 2
git rev-parse HEAD; git branch --show-current
mojo --version 2>&1 || .pixi/envs/default/bin/mojo --version
glslangValidator -V aesir_engine/shaders/vec_add.comp -o /tmp/a015_vec_add.spv && sha256sum /tmp/a015_vec_add.spv
/tmp/a015_probe
} > hidden_files/a015_run_all.log 2>&1
staging=$(mktemp -d)
echo "staging=$staging" >> hidden_files/a015_run_all.log
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> hidden_files/a015_run_all.log 2>&1; echo "stub_cc_exit=$?" >> hidden_files/a015_run_all.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> hidden_files/a015_run_all.log 2>&1; echo "par_cc_exit=$?" >> hidden_files/a015_run_all.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$staging/libaesir_hip.so" -ldl >> hidden_files/a015_run_all.log 2>&1; echo "hip_cc_exit=$?" >> hidden_files/a015_run_all.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl >> hidden_files/a015_run_all.log 2>&1; echo "vk_cc_exit=$?" >> hidden_files/a015_run_all.log
echo "=== mojo run start $(date -Is) ===" >> hidden_files/a015_run_all.log
pixi run --frozen mojo run -I . --target-accelerator sm_89 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan aesir_engine/tests/run_all.mojo >> hidden_files/a015_run_all.log 2>&1
echo "MOJO_EXIT=$?" >> hidden_files/a015_run_all.log
echo "=== end $(date -Is) ===" >> hidden_files/a015_run_all.log
