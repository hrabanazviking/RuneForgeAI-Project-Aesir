#!/bin/bash
# A-041 C-008 re-profile: exact A-037 method on the FIXED code.
cd /home/volmarr/aesir-team-09 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
LOG=hidden_files/a041_perf.log
{
date -Is; hostname; uname -a; git rev-parse HEAD; git branch --show-current; git diff --stat
uptime; sha256sum hidden_files/fixtures/stories260K.F16.gguf aesir_engine/tests/bench_decode_census_a037.mojo
perf --version; cat /proc/sys/kernel/perf_event_paranoid
} > $LOG 2>&1
staging=$(mktemp -d); echo staging=$staging >> $LOG
cc -std=c11 -fPIC -shared aesir_engine/hailo10h_stub.c -o "$staging/libaesir_hailo10h.so" >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/thread_par.c -o "$staging/libaesir_par.so" -lpthread >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/hip_memory_shim.c -o "$staging/libaesir_hip.so" -ldl >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/vulkan_context_shim.c aesir_engine/vulkan_buffer_shim.c -o "$staging/libaesir_vulkan.so" -ldl >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/zero_copy_shim.c -o "$staging/libaesir_zc.so" -ldl >> $LOG 2>&1
cc -std=c11 -O2 -fPIC -shared aesir_engine/affinity_shim.c -o "$staging/libaesir_aff.so" >> $LOG 2>&1
echo shims_done >> $LOG
pixi run --frozen mojo build -I . --target-accelerator gfx1151 -Xlinker "-L$staging" -Xlinker -laesir_hailo10h -Xlinker -laesir_par -Xlinker -laesir_hip -Xlinker -laesir_vulkan -Xlinker -laesir_zc -Xlinker -laesir_aff -o /tmp/a041_census aesir_engine/tests/bench_decode_census_a037.mojo >> $LOG 2>&1
echo BUILD_EXIT=$? >> $LOG
sudo -n env LD_LIBRARY_PATH=$staging perf record -F 997 -g -o hidden_files/a041_perf.data /tmp/a041_census hidden_files/fixtures/stories260K.F16.gguf > hidden_files/a041_bench_record.log 2>&1
echo RECORD_EXIT=$? >> $LOG; cat hidden_files/a041_bench_record.log >> $LOG
sudo -n perf report -i hidden_files/a041_perf.data --stdio --no-children --sort=symbol > hidden_files/a041_perf_report_nochildren.txt 2>&1; echo REPORT_EXIT=$? >> $LOG
sudo -n chown volmarr:volmarr hidden_files/a041_perf.data; sha256sum hidden_files/a041_perf.data hidden_files/a041_perf_report_nochildren.txt >> $LOG
uptime >> $LOG
echo A041_PERF_DONE >> $LOG
