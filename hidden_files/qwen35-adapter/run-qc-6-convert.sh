#!/usr/bin/env bash
cd /home/volmarr/aesir-qc-6
H=hidden_files/qwen35-adapter
SRC=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q8_0.gguf
OUT=/mnt/vault/models/gguf/Qwen3.8-27B-Ultimate-Heretic-Uncn-Turbo-Brilli-50x-AGI-NEO-Q4_K_M.gguf
export LD_LIBRARY_PATH="$PWD/hidden_files/hip-serve/shims:$LD_LIBRARY_PATH"
grep MemAvailable /proc/meminfo > $H/qc-6-convert-mem.log
date >> $H/qc-6-convert-mem.log
/usr/bin/time -v .aesir/aesir quantize $SRC $OUT --to q4_k_m --streaming > $H/qc-6-convert.log 2> $H/qc-6-convert-time.log; echo CONVERT_EXIT=$?
ls -la $OUT > $H/qc-6-product-ls.log 2>&1
sha256sum $OUT > $H/qc-6-product-sha.log 2>&1; cat $H/qc-6-product-sha.log
date >> $H/qc-6-convert-mem.log
grep MemAvailable /proc/meminfo >> $H/qc-6-convert-mem.log
echo QC6_CONVERT_DONE
