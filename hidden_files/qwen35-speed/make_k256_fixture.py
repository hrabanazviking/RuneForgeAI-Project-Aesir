#!/usr/bin/env python3
"""QS-3 fixture: qwen35 forward fixture at a K-admissible geometry.
Every large matrix input width (GGUF dim0) is a multiple of 256:
H=512 (embd/output/ffn_gate/ffn_up/attn_q/k/v/qkv/gate/alpha/beta),
FFN=512 (ffn_down), QW=4*128=512 (attn_output), INNER=4*64=256
(ssm_out). Built with the banked generator (scripts/
make_qwen35_fixtures.build_forward) at a custom geom; the Q8_0
source is then converted by the QS-3 CLI runs in run-qs-3-resident.sh."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path.home() / "aesir-qs-pack" / "scripts"))
from make_qwen35_fixtures import build_forward
out = Path.home() / "aesir-qs-pack" / "hidden_files" / "qwen35-speed" / "fixtures" / "qwen35_k256_q8.gguf"
out.parent.mkdir(parents=True, exist_ok=True)
build_forward(out, geom=(512, 512, 1024, 4, 512, 4, 2, 128, 4, 64, 4, 4), seed=20261116, file_type=7)
print("K256 fixture written:", out)
