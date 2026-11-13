#!/bin/bash
# A-098 power profile driver (team-25). Phases sequential, solo.
set -u
cd /home/volmarr/aesir-team-25 || exit 99
L=hidden_files/a098
SHAPES=/home/volmarr/aesir-team-24/hidden_files/a094/shapes
mkdir -p $L
# PPT sampler (A-018 sensors) for the whole run
( while true; do printf '%s %s %s\n' "$(date +%s.%N)" "$(cat /sys/class/hwmon/hwmon13/power1_average 2>/dev/null)" "$(cat /sys/class/hwmon/hwmon13/temp1_input 2>/dev/null)" >> $L/ppt_samples.log; sleep 0.2; done ) &
SAMP=$!
mark(){ echo "PHASE $1 $(date +%s.%N)" >> $L/phases.log; echo "=== $1 $(date -Is)"; }
mark idle1_start
sudo -n python3 -c "
import time
f='/sys/class/powercap/intel-rapl:0/energy_uj'
e0=int(open(f).read()); t0=time.time(); time.sleep(10); e1=int(open(f).read()); t1=time.time()
print('IDLE energy_uj_delta=%d wall_s=%.3f avg_w=%.3f' % (e1-e0, t1-t0, (e1-e0)/1e6/(t1-t0)))" 
mark idle1_end
for r in 1 2 3; do
  mark cpu_r${r}_start
  sudo -n spikes/a098_power/power_runner 128 1024 1024 off 16000 > $L/cpu_r${r}.log 2>&1; grep -E 'POWER|E2E|RESULT' $L/cpu_r${r}.log
  mark cpu_r${r}_end; sleep 3
done
for r in 1 2 3; do
  mark gpu_r${r}_start
  sudo -n spikes/a098_power/gpu_power spikes/a098_power/gemm.spv 30000 > $L/gpu_r${r}.log 2>&1; grep -E 'POWER|RESULT|gpu_device' $L/gpu_r${r}.log
  mark gpu_r${r}_end; sleep 3
done
for r in 1 2 3; do
  mark npu_r${r}_start
  sudo -n spikes/a098_power/power_runner 128 1024 1024 on 4096 $SHAPES/final_p128.xclbin $SHAPES/insts_p128.bin > $L/npu_r${r}.log 2>&1; grep -E 'POWER|E2E|RESULT|device_name|ert_cmd' $L/npu_r${r}.log
  mark npu_r${r}_end; sleep 3
done
mark idle2_start
sudo -n python3 -c "
import time
f='/sys/class/powercap/intel-rapl:0/energy_uj'
e0=int(open(f).read()); t0=time.time(); time.sleep(10); e1=int(open(f).read()); t1=time.time()
print('IDLE energy_uj_delta=%d wall_s=%.3f avg_w=%.3f' % (e1-e0, t1-t0, (e1-e0)/1e6/(t1-t0)))"
mark idle2_end
kill $SAMP 2>/dev/null
echo A098_PHASES_DONE
