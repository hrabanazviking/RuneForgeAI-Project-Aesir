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
