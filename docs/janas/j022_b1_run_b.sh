#!/bin/bash
# J-022 B1 experiment B driver (purplelongship): regression re-run of the
# standard vehicle built from the hook-carrying tree, Aesir layer dumps
# at positions 0 / 7 / 71, numpy reference dumps for the same sequences,
# and the per-layer comparisons. Run inside tmux; logs to ~/j022/b1/.
set -x
export PATH=/home/volmarr/.pixi/bin:$PATH
export LD_LIBRARY_PATH=/home/volmarr/j022/stage
export CUDA_VISIBLE_DEVICES=
export PYTHONPATH=/home/volmarr/.cache/uv/archive-v0/VLgX3neNztjkLwdz
M=/home/volmarr/aesir-gpu/.aesir/models/olmoe-1b-7b-0924-instruct-q4_k_m.gguf
B=/home/volmarr/j022/b1
TREE=/home/volmarr/aesir-j022-tree
IDS67=$(cat /home/volmarr/j022/prompt_prose_ids.csv)
IDS8="510,1708,5967,43775,21863,253,6891,16303"
IDS72="$IDS67,187,187,510,1708,5967"

cd $TREE
pixi run mojo build --mcpu znver2 --target-accelerator sm_75 -I . -I aesir_engine \
  aesir_engine/tests/test_olmoe_stream.mojo -o /home/volmarr/j022/test_olmoe_stream_b1 \
  -Xlinker -L/home/volmarr/j022/stage -Xlinker -laesir_hailo10h -Xlinker -laesir_par \
  > $B/build_stream_b1.log 2>&1
echo "STREAM_BUILD_EXIT=$?"

nice -n 10 /home/volmarr/j022/test_olmoe_stream_b1 $M 512 536870912 "$IDS67" 24 > $B/regress67.log 2>&1
echo "REGRESS_EXIT=$?"
grep "Generated IDs" $B/regress67.log

nice -n 10 /home/volmarr/j022/test_olmoe_layers $M 512 536870912 "510" 0 > $B/dump_pos0.txt 2>&1
echo "DUMP0_EXIT=$?"
nice -n 10 /home/volmarr/j022/test_olmoe_layers $M 512 536870912 "$IDS8" 7 > $B/dump_pos7.txt 2>&1
echo "DUMP7_EXIT=$?"
nice -n 10 /home/volmarr/j022/test_olmoe_layers $M 512 536870912 "$IDS72" 71 > $B/dump_pos71.txt 2>&1
echo "DUMP71_EXIT=$?"

cd $TREE/docs/janas
nice -n 10 python3 j022_b1_layer_dump.py $M "510" $B/ref_pos0.npz > $B/ref_pos0.log 2>&1
echo "REF0_EXIT=$?"
nice -n 10 python3 j022_b1_layer_dump.py $M "$IDS8" $B/ref_pos7.npz > $B/ref_pos7.log 2>&1
echo "REF7_EXIT=$?"
nice -n 10 python3 j022_b1_layer_dump.py $M "$IDS72" $B/ref_pos71.npz > $B/ref_pos71.log 2>&1
echo "REF71_EXIT=$?"

python3 j022_b1_compare.py $B/ref_pos0.npz $B/dump_pos0.txt 0 > $B/cmp_pos0.txt 2>&1
python3 j022_b1_compare.py $B/ref_pos7.npz $B/dump_pos7.txt 7 > $B/cmp_pos7.txt 2>&1
python3 j022_b1_compare.py $B/ref_pos71.npz $B/dump_pos71.txt 71 > $B/cmp_pos71.txt 2>&1
echo "B_ALLDONE"
