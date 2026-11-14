"""Q35-3r: the Q8_0-resident weight contract for Qwen 3.5 (qwen35).

Why this module exists: the gate that keeps the real 27B / 40B files
out of the forward path is memory. Priced as materialized F16, the
27B's large weights cost ~57 GB (the 40B's ~83 GB); priced in their
stored Q8_0 form they cost ~28.6 GB / ~41.5 GB -- the file sizes
themselves. The engine-core CPU path never needed the F16 price:
GGUFSeer maps Q8_0 tensors as zero-copy packed views into the mmap
(loader/gguf.mojo _map_tensor), and the qwen35 forward consumes
every large weight ONLY through gemm_f16, which dispatches a packed
Q8_0 operand to gemm_q8_0 (dequantize-on-the-fly: the single-row
decode shape fuses dequant into the GEMV; the batched shape decodes
ONE weight row at a time into a bounded F32 scratch), plus the
per-row embedding dequant in _embed_token_into. Small tensors
(norms, ssm_a, ssm_dt.bias, ssm_conv1d, ssm_norm -- F32 in the real
files) keep their load-time conversion into the F16 pool; that is
megabytes, not gigabytes (27B census: 2,645,504 F32 elements).

What was missing, and what this slice adds, is the CONTRACT: until
now nothing verified that a given file's large weights actually
are Q8_0, nothing refused a file whose large weights are stored
F16 (the loader records types without enforcing them -- Q35-1 U2),
and nothing reported the load mode. Resident mode is opt-in:

- validate_qwen35_resident(seer) checks EVERY large weight (the
  exact set the Q35-1 validator records as Q8_0: token_embd,
  output, per-layer ffn gate/up/down, full-attention q/k/v/output,
  SSM qkv/gate/alpha/beta/out) against the file's recorded tensor
  types. Any large weight not stored Q8_0, not carrying the packed
  view, or not 32-aligned in its input width is REFUSED BY NAME.
  There is no silent fallback to F16 materialization: this path
  contains no whole-tensor dequantization at all.
- The returned report counts the large tensors and prices them
  both ways (stored Q8_0 bytes vs the F16-materialized bytes the
  resident path avoids), so the fit arithmetic for the real files
  is formula-priced from the file's own directory, not estimated.
- The mode string is "q8_0_resident"; the serve health surface
  reports it for qwen35 sessions loaded under the opt-in (Q35-3r).

The default (non-resident) load is unchanged in every way.
"""
from loader.gguf import GGMLType, GGUFSeer


struct Qwen35ResidentReport(Copyable):
    """Census of the large weights admitted under the resident contract."""

    var large_count: Int
    var large_elements: Int
    var q8_bytes: Int
    var f16_bytes: Int

    def __init__(out self, large_count: Int = 0, large_elements: Int = 0,
                 q8_bytes: Int = 0, f16_bytes: Int = 0):
        self.large_count = large_count
        self.large_elements = large_elements
        self.q8_bytes = q8_bytes
        self.f16_bytes = f16_bytes

    def load_mode(self) -> String:
        return String("q8_0_resident")


def qwen35_large_weight_names(block_count: Int, full_attention_interval: Int) -> List[String]:
    """The exact large-weight set of the qwen35 tensor contract:
    2 globals + per full-attention layer 7 + per SSM layer 8
    (27B: 2 + 16*7 + 48*8 = 498, the Q35-1 census Q8_0 count)."""
    var names = List[String]()
    names.append(String("token_embd.weight"))
    names.append(String("output.weight"))
    var interval = full_attention_interval
    if interval <= 0:
        interval = 4
    for layer in range(block_count):
        var prefix = String("blk.") + String(layer) + String(".")
        names.append(prefix + "ffn_gate.weight")
        names.append(prefix + "ffn_up.weight")
        names.append(prefix + "ffn_down.weight")
        if (layer + 1) % interval == 0:
            names.append(prefix + "attn_q.weight")
            names.append(prefix + "attn_k.weight")
            names.append(prefix + "attn_v.weight")
            names.append(prefix + "attn_output.weight")
        else:
            names.append(prefix + "attn_qkv.weight")
            names.append(prefix + "attn_gate.weight")
            names.append(prefix + "ssm_alpha.weight")
            names.append(prefix + "ssm_beta.weight")
            names.append(prefix + "ssm_out.weight")
    return names^


def _require_q8_resident(seer: GGUFSeer, name: String, mut report: Qwen35ResidentReport) raises:
    if name not in seer.tensors:
        raise Error("Qwen35 resident Q8_0 load refused: missing large tensor '" + name + "'")
    var stored = seer.tensor_types.get(name, UInt32(99))
    if stored != UInt32(GGMLType.Q8_0):
        raise Error(
            "Qwen35 resident Q8_0 load refused tensor '" + name
            + "': stored GGML type " + String(stored)
            + " is not Q8_0 (8); the resident path holds large weights in native Q8_0 form and never materializes F16 weights -- convert the file to Q8_0 or load without the resident option"
        )
    ref tensor = seer.tensors[name]
    if not tensor.is_quantized:
        raise Error("Qwen35 resident Q8_0 load refused tensor '" + name + "': view is not a packed quantized view")
    if tensor.cols % 32 != 0:
        raise Error(
            "Qwen35 resident Q8_0 load refused tensor '" + name
            + "': input width " + String(tensor.cols) + " is not a multiple of 32 (Q8_0 block width)"
        )
    report.large_count += 1
    report.large_elements += tensor.rows * tensor.cols
    report.q8_bytes += (tensor.rows * tensor.cols // 32) * 34
    report.f16_bytes += tensor.rows * tensor.cols * 2


def validate_qwen35_resident(seer: GGUFSeer) raises -> Qwen35ResidentReport:
    """Enforce the resident contract over a loaded seer and price it.

    Raises, naming the first offending tensor, when any large weight
    is not stored Q8_0. Small tensors are not inspected here: they
    keep the loader's F32 -> F16 pool conversion on both paths.
    """
    if seer.config.architecture != "qwen35":
        raise Error("Qwen35 resident Q8_0 load requires a qwen35 model")
    var report = Qwen35ResidentReport()
    var names = qwen35_large_weight_names(seer.config.block_count, seer.config.full_attention_interval)
    for i in range(len(names)):
        _require_q8_resident(seer, names[i], report)
    return report^
