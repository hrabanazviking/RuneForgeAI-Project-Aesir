#!/bin/bash
set -x
export PATH=/home/volmarr/.pixi/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/home/volmarr/j022/stage
export CUDA_VISIBLE_DEVICES=
M=/home/volmarr/aesir-gpu/.aesir/models/olmoe-1b-7b-0924-instruct-q4_k_m.gguf
B=/home/volmarr/j022/b1
TREE=/home/volmarr/aesir-j022-tree
IDS67=$(cat /home/volmarr/j022/prompt_prose_ids.csv)
cd $TREE
pixi run mojo build --mcpu znver2 --target-accelerator sm_75 -I . -I aesir_engine aesir_engine/tests/test_olmoe_stream.mojo -o /home/volmarr/j022/test_olmoe_stream_fix -Xlinker -L/home/volmarr/j022/stage -Xlinker -laesir_hailo10h -Xlinker -laesir_par
echo BUILD_EXIT=$?
nice -n 10 /home/volmarr/j022/test_olmoe_stream_fix $M 512 536870912 $IDS67 24 > $B/run_fix.log 2>&1
echo RUN_EXIT=$?
grep 'Generated IDs' $B/run_fix.log
GEN=$(grep 'Generated IDs' $B/run_fix.log | sed 's/.*\[//; s/\].*//; s/ //g')
echo GEN=$GEN
nice -n 10 /home/volmarr/s026l/tf_oracle $M /home/volmarr/j022/prompt_prose.txt $GEN > $B/tf_grade_fix.log 2>$B/tf_grade_fix.err
echo GRADE_EXIT=$?
cat $B/tf_grade_fix.log
grep prompt_tokens $B/tf_grade_fix.err
nice -n 10 /home/volmarr/s026l/fr_oracle $M /home/volmarr/j022/prompt_prose.txt 24 > $B/fr_fix.log 2>$B/fr_fix.err
echo FR_EXIT=$?
cat $B/fr_fix.log
echo VERIFY_DONE
