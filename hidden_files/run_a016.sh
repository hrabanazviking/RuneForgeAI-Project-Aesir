#!/bin/bash
# A-016 standalone runner (team-02): XRT BO probe + E-MASTER baseline gate.
# The BO probe REQUIRES sudo (RLIMIT_MEMLOCK 8192 kB vs XRT 64 MiB map;
# A-007 caveat) so it is NOT wired into run_all.mojo's gate.
set -u
cd /home/volmarr/aesir-team-02 || exit 99
export PATH=$HOME/.pixi/bin:$PATH
D=hidden_files/a016
cc -std=c11 -O2 -Wall $PWD/aesir_engine/xrt_bo_probe.c -o $D/xrt_bo_probe /usr/lib/x86_64-linux-gnu/libxrt_coreutil.so.2 > $D/compile.log 2>&1
echo "probe_cc_exit=$?"
sudo -n $D/xrt_bo_probe 16777216 2>&1 | tee $D/run_final.log
echo "probe_exit=${PIPESTATUS[0]}"
