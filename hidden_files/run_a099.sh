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
#!/bin/bash
# A-099 NPU-side evidence (team-26): happy path + fault injection, sudo -n.
set -u
cd /home/volmarr/aesir-team-26 || exit 99
B=/home/volmarr/aesir-team-22/scratch/a092/build
R=./hidden_files/a099/npu_prefill_offload
sudo -n $R 64 64 64 on 8 $B/final.xclbin $B/insts.bin > hidden_files/a099/npu_happy_64.log 2>&1; echo happy_exit=$?
sudo -n $R 64 64 64 on 2 /nonexistent/bad.xclbin $B/insts.bin > hidden_files/a099/fb_xclbin_missing_sudo.log 2>&1; echo xm_exit=$?
sudo -n $R 64 64 64 on 2 /tmp/a099_garbage.xclbin $B/insts.bin > hidden_files/a099/fb_xclbin_garbage_sudo.log 2>&1; echo xg_exit=$?
sudo -n env AESIR_A099_FAULT=device_absent $R 64 64 64 on 2 $B/final.xclbin $B/insts.bin > hidden_files/a099/fb_device_absent.log 2>&1; echo da_exit=$?
sudo -n env AESIR_A099_FAULT=xclbin $R 64 64 64 on 2 $B/final.xclbin $B/insts.bin > hidden_files/a099/fb_xclbin_fault.log 2>&1; echo xf_exit=$?
sudo -n env AESIR_A099_FAULT=run $R 64 64 64 on 2 $B/final.xclbin $B/insts.bin > hidden_files/a099/fb_run_fault.log 2>&1; echo rf_exit=$?
sudo -n env AESIR_A099_FAULT=timeout $R 64 64 64 on 2 $B/final.xclbin $B/insts.bin > hidden_files/a099/fb_timeout_fault.log 2>&1; echo tf_exit=$?
sudo -n env AESIR_A099_FAULT=mismatch $R 64 64 64 on 2 $B/final.xclbin $B/insts.bin > hidden_files/a099/fb_mismatch_fault.log 2>&1; echo mf_exit=$?
echo A099_NPU_SIDE_DONE
