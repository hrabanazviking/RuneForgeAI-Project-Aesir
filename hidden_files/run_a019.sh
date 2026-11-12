#!/bin/bash
# A-019 runner (team-05): canonical E-MASTER shape per run_a011.sh /
# run_seat_gate_a017.sh, plus the A-019 zero-copy shim staged as
# libaesir_zc.so and the A-019 C probe run in the header.
cd /home/volmarr/aesir-team-05 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
{
echo "=== A-019 E-MASTER run (zero-copy allocator) ==="
date -Is; hostname; uname -a
git rev-parse HEAD; git branch --show-current
mojo --version 2>&1 || .pixi/envs/default/bin/mojo --version
} > hidden_files/a019_run_all.log 2>&1
staging=$(mktemp -d)
echo "staging=$staging" >> hidden_files/a019_run_all.log
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> hidden_files/a019_run_all.log 2>&1
echo "stub_cc_exit=$?" >> hidden_files/a019_run_all.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> hidden_files/a019_run_all.log 2>&1
echo "par_cc_exit=$?" >> hidden_files/a019_run_all.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$staging/libaesir_hip.so" -ldl >> hidden_files/a019_run_all.log 2>&1
echo "hip_cc_exit=$?" >> hidden_files/a019_run_all.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl >> hidden_files/a019_run_all.log 2>&1
echo "vulkan_cc_exit=$?" >> hidden_files/a019_run_all.log
cc -std=c11 -O2 -fPIC -shared aesir_engine/zero_copy_shim.c -o "$staging/libaesir_zc.so" -ldl >> hidden_files/a019_run_all.log 2>&1
echo "zc_cc_exit=$?" >> hidden_files/a019_run_all.log
cc -std=c11 -O2 hidden_files/a019_probe.c -o "$staging/a019_probe" -L"$staging" -laesir_zc -laesir_vulkan -Wl,-rpath,"$staging" >> hidden_files/a019_run_all.log 2>&1
echo "probe_cc_exit=$?" >> hidden_files/a019_run_all.log
"$staging/a019_probe" >> hidden_files/a019_run_all.log 2>&1
echo "PROBE_EXIT=$?" >> hidden_files/a019_run_all.log
/usr/bin/time -v pixi run --frozen mojo run -I . --target-accelerator sm_89 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc aesir_engine/tests/run_all.mojo >> hidden_files/a019_run_all.log 2>&1
echo "MOJO_EXIT=$?" >> hidden_files/a019_run_all.log
echo "=== end $(date -Is) ===" >> hidden_files/a019_run_all.log
