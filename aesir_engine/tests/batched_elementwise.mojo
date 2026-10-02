"""Test-owned independent rows retain original per-cell arithmetic."""
from std.gpu import block_idx
from core.gemma4_kernels import Floats
from core.llama3_kernels import llama_residual_cell, llama_silu_cell


def batched_residual(a: Floats,src: Int64,other: Int64,dst: Int64,count: Int64,stride: Int64):
    var offset = Int64(block_idx.y)*stride
    llama_residual_cell(a,src+offset,other+offset,dst+offset,count)


def batched_silu(a: Floats,gate: Int64,up: Int64,count: Int64,stride: Int64):
    var offset = Int64(block_idx.y)*stride
    llama_silu_cell(a,gate+offset,up+offset,count)
