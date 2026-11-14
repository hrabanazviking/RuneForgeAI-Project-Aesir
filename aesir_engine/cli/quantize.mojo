# cli/quantize.mojo
# QC-3: whole-model Q8_0 quantization -- the `aesir quantize` command.
#
# Wires the compression workstream end to end (QC-0-PLAN section 6,
# QC-3): a source GGUF is read through QC-1's metadata-copy path
# (loader/gguf_writer.read_gguf_header_copy) plus GGUFSeer tensor
# access, each tensor is quantized or kept under the per-role policy
# below, general.file_type is set for the tier (Q8_0 = 7, per QC-0
# section 2 -- the caller-owned duty QC-1 and QC-2 both named), and
# the result is emitted through QC-1's writer (write_gguf_file).
#
# Per-tensor policy (QC-0 section 3 + QC-2-NOTES handoff):
# - Weight matrices (rank >= 2, dense float source: F16/F32/BF16)
#   whose dim0 is a multiple of the 32-value Q8_0 block are quantized
#   with QC-2's quantize_q8_0. F16 values are widened to F32 exactly
#   first (f16 -> f32 is exact); F32 values pass through; BF16 values
#   widen exactly (zero-extension of the low mantissa bits).
# - Everything else stays at its source type, byte for byte, and is
#   LISTED BY NAME in the run report -- no silent skips, no padding:
#   * one-dimensional tensors (norms, scales, biases),
#   * tensors named as norms or biases at any rank,
#   * tensors whose source type is not a dense float,
#   * tensors whose dim0 is not a multiple of 32 (GGUF has no
#     padding semantics; the readers refuse/misprice such rows).
#
# The conversion is payload-faithful at fixture scale: payloads ride
# in the QC-1 model description, exactly as copy_gguf_model does.
# The streaming writer/converter QC-6 needs at 27B scale is named
# future work in QC-1/QC-2 notes and is NOT built here.

from std.memory import bitcast

from core.mimir_well import f16, f32
from core.dequantize_input import (
    dequant_input_keep_reason,
    dequant_input_supported,
    dequantize_range_f32,
)
from core.quantize import (
    Q4_K_GGML_TYPE,
    Q6_K_GGML_TYPE,
    Q8_0_GGML_TYPE,
    q4_k_payload_bytes,
    q6_k_payload_bytes,
    q8_0_payload_bytes,
    quantize_q4_k,
    quantize_q6_k,
    quantize_q8_0,
)
from loader.gguf import GGMLType, GGUFSeer
from loader.gguf_writer import (
    GGUFDirectoryEntry,
    GGUFKV,
    GGUFWriterTensorMeta,
    GGUFModelDesc,
    GGUFWriterTensor,
    gguf_kv_u32,
    open_gguf_stream,
    read_gguf_header_copy,
    write_gguf_file,
)


comptime QUANTIZE_TIER_Q8_0 = "q8_0"
comptime Q8_0_FILE_TYPE = 7
comptime QUANTIZE_TIER_Q4_K_M = "q4_k_m"
comptime Q4_K_M_FILE_TYPE = 15


struct QuantizeReport(Copyable, Movable):
    """The conversion account: every tensor is named exactly once,
    as quantized or as kept-with-a-reason, with byte counts per
    class. Printed by the CLI and asserted by the QC-3 test."""

    var quantized_names: List[String]
    var quantized_source_bytes: List[Int]
    var quantized_output_bytes: List[Int]
    var kept_names: List[String]
    var kept_types: List[UInt32]
    var kept_bytes: List[Int]
    var kept_reasons: List[String]
    var quantized_types: List[UInt32]
    var file_type: Int
    var output_bytes: Int

    def __init__(out self):
        self.quantized_names = List[String]()
        self.quantized_source_bytes = List[Int]()
        self.quantized_output_bytes = List[Int]()
        self.kept_names = List[String]()
        self.kept_types = List[UInt32]()
        self.kept_bytes = List[Int]()
        self.kept_reasons = List[String]()
        self.quantized_types = List[UInt32]()
        self.file_type = 0
        self.output_bytes = 0

    def quantized_count(self) -> Int:
        return len(self.quantized_names)

    def kept_count(self) -> Int:
        return len(self.kept_names)

    def quantized_source_total(self) -> Int:
        var total = 0
        for value in self.quantized_source_bytes:
            total += value
        return total

    def quantized_output_total(self) -> Int:
        var total = 0
        for value in self.quantized_output_bytes:
            total += value
        return total

    def kept_total(self) -> Int:
        var total = 0
        for value in self.kept_bytes:
            total += value
        return total


def q8_0_keep_reason(name: String, entry: GGUFDirectoryEntry) -> String:
    """Empty string means QUANTIZE. Any other return is the named
    reason the tensor stays at its source type (QC-0 section 3)."""
    if len(entry.dims) < 2:
        return String(
            "one-dimensional tensor (norm/scale/bias class) stays at source type"
        )
    if "norm" in name:
        return String("norm tensor stays at source type")
    if name.endswith(".bias"):
        return String("bias tensor stays at source type")
    if (
        entry.tensor_type != UInt32(GGMLType.F16)
        and entry.tensor_type != UInt32(GGMLType.F32)
        and entry.tensor_type != UInt32(GGMLType.BF16)
    ):
        return String(
            "source type "
            + String(entry.tensor_type)
            + " is not a dense float; stays at source type"
        )
    if Int(entry.dims[0]) % 32 != 0:
        return String(
            "dim0 "
            + String(entry.dims[0])
            + " is not a multiple of the 32-value Q8_0 block; stays at"
            + " source type (no padding -- GGUF has no padding semantics)"
        )
    return String("")


def _element_count(entry: GGUFDirectoryEntry) -> Int:
    var total = 1
    for dim in entry.dims:
        total *= Int(dim)
    return total


def _read_dense_f32(
    seer: GGUFSeer, base: Int, entry: GGUFDirectoryEntry
) raises -> List[Float32]:
    """Exact widening of one dense-float tensor's values to F32:
    F16 -> F32 is exact, F32 passes through, BF16 -> F32 is exact
    (the BF16 bit pattern is the high half of the F32 pattern)."""
    var count = _element_count(entry)
    var values = List[Float32]()
    values.reserve(count)
    if entry.tensor_type == UInt32(GGMLType.F16):
        var ptr = seer.mmap_ptr.unsafe_offset(base).unsafe_bitcast[Scalar[f16]]()
        for i in range(count):
            values.append(ptr.unsafe_load(i).cast[f32]())
        return values^
    if entry.tensor_type == UInt32(GGMLType.F32):
        var ptr = seer.mmap_ptr.unsafe_offset(base).unsafe_bitcast[Float32]()
        for i in range(count):
            values.append(ptr.unsafe_load(i))
        return values^
    if entry.tensor_type == UInt32(GGMLType.BF16):
        var ptr = seer.mmap_ptr.unsafe_offset(base).unsafe_bitcast[UInt16]()
        for i in range(count):
            var bits = UInt32(ptr.unsafe_load(i)) << 16
            values.append(bitcast[DType.float32](bits))
        return values^
    raise Error("quantize: tensor is not a dense float: " + entry.name)


def quantize_gguf_q8_0(
    source_path: String, output_path: String
) raises -> QuantizeReport:
    """Converts a whole GGUF to Q8_0 under the policy above and
    writes it through the QC-1 writer with general.file_type = 7.
    Metadata is copied wholesale (raw KV carriage) except the one
    key quantization owns; tensor names, shapes, and directory
    order are preserved exactly."""
    var head = read_gguf_header_copy(source_path)
    var seer = GGUFSeer(source_path)
    seer._open_and_map()
    seer._parse_header()
    var desc = GGUFModelDesc()
    desc.alignment = head.alignment
    var saw_file_type = False
    for kv in head.kvs:
        if kv.key == "general.file_type":
            desc.add_kv(gguf_kv_u32("general.file_type", UInt32(Q8_0_FILE_TYPE)))
            saw_file_type = True
        else:
            desc.add_kv(kv)
    if not saw_file_type:
        raise Error(
            "quantize: source carries no general.file_type key to set;"
            + " refusing to invent metadata layout"
        )
    var report = QuantizeReport()
    for entry in head.directory:
        var base = head.data_offset + entry.relative_offset
        seer._require_range(base, entry.byte_size)
        var reason = q8_0_keep_reason(entry.name, entry.copy())
        if reason.byte_length() == 0:
            var values = _read_dense_f32(seer, base, entry.copy())
            var payload = quantize_q8_0(values)
            report.quantized_names.append(String(entry.name))
            report.quantized_source_bytes.append(entry.byte_size)
            report.quantized_output_bytes.append(len(payload))
            report.quantized_types.append(UInt32(Q8_0_GGML_TYPE))
            desc.add_tensor(
                GGUFWriterTensor(
                    entry.name, entry.dims, UInt32(Q8_0_GGML_TYPE), payload
                )
            )
        else:
            var payload = List[UInt8]()
            payload.reserve(entry.byte_size)
            for index in range(entry.byte_size):
                payload.append(
                    UInt8(seer.mmap_ptr.unsafe_offset(base + index).unsafe_load())
                )
            report.kept_names.append(String(entry.name))
            report.kept_types.append(entry.tensor_type)
            report.kept_bytes.append(entry.byte_size)
            report.kept_reasons.append(reason)
            desc.add_tensor(
                GGUFWriterTensor(entry.name, entry.dims, entry.tensor_type, payload)
            )
    report.file_type = Q8_0_FILE_TYPE
    report.output_bytes = write_gguf_file(output_path, desc)
    return report^


def print_quantize_report(
    report: QuantizeReport, source_path: String, output_path: String
):
    for i in range(len(report.quantized_names)):
        print(
            "QUANTIZED",
            report.quantized_names[i],
            "-> " + _ggml_type_name(report.quantized_types[i]),
            report.quantized_source_bytes[i],
            "->",
            report.quantized_output_bytes[i],
            "bytes",
        )
    for i in range(len(report.kept_names)):
        print(
            "KEPT",
            report.kept_names[i],
            "type=" + String(report.kept_types[i]),
            "bytes=" + String(report.kept_bytes[i]),
            "reason: " + report.kept_reasons[i],
        )
    print(
        "SUMMARY quantized=" + String(report.quantized_count())
        + " kept=" + String(report.kept_count())
        + " quantized_source_bytes=" + String(report.quantized_source_total())
        + " quantized_output_bytes=" + String(report.quantized_output_total())
        + " kept_bytes=" + String(report.kept_total())
    )
    print(
        "FILE_TYPE general.file_type="
        + String(report.file_type)
        + " ("
        + _file_type_name(report.file_type)
        + ")"
    )
    print("WROTE " + output_path + " " + String(report.output_bytes) + " bytes (source: " + source_path + ")")


def dispatch_quantize(args: List[String]) raises:
    """Parses and executes `aesir quantize <source.gguf> <output.gguf>
    [--to q8_0|q4_k_m]`. Q8_0 is the only tier this slice wires (QC-5 owns
    Q4_K_M); any other tier is refused by name, never approximated."""
    var source = String("")
    var output = String("")
    var tier = String(QUANTIZE_TIER_Q8_0)
    var seen_to = False
    var streaming = False
    var index = 1
    while index < len(args):
        var token = args[index]
        if token == "--to":
            if seen_to or index + 1 >= len(args):
                raise Error("quantize requires one value for --to")
            seen_to = True
            tier = args[index + 1]
            index += 2
            continue
        if token == "--streaming":
            streaming = True
            index += 1
            continue
        if token.startswith("--"):
            raise Error("quantize: unknown option " + token)
        if source.byte_length() == 0:
            source = token
        elif output.byte_length() == 0:
            output = token
        else:
            raise Error(
                "Usage: aesir quantize <source.gguf> <output.gguf> [--to q8_0|q4_k_m]"
            )
        index += 1
    if source.byte_length() == 0 or output.byte_length() == 0:
        raise Error("Usage: aesir quantize <source.gguf> <output.gguf> [--to q8_0|q4_k_m]")
    if tier != QUANTIZE_TIER_Q8_0 and tier != QUANTIZE_TIER_Q4_K_M:
        raise Error(
            "quantize: tier '"
            + tier
            + "' is not implemented; the wired tiers are q8_0 (QC-3)"
            + " and q4_k_m (QC-5)"
        )
    if source == output:
        raise Error("quantize: source and output paths must differ")
    var report = QuantizeReport()
    if tier == QUANTIZE_TIER_Q4_K_M:
        if streaming:
            report = quantize_gguf_q4_k_m_streaming_qc6(source, output)
        else:
            report = quantize_gguf_q4_k_m(source, output)
    elif streaming:
        report = quantize_gguf_q8_0_streaming(source, output)
    else:
        report = quantize_gguf_q8_0(source, output)
    print_quantize_report(report, source, output)


# ---------------------------------------------------------------------
# QC-3b: dequantizing policy + streaming whole-model conversion.
#
# quantize_gguf_q8_0 above widens DENSE floats only and keeps every
# quantized tensor at source type; at gemma-4-E2B scale (3.1 GB,
# 601 tensors, mostly Q4_K/Q5_K/Q6_K) it also cannot ride the
# in-memory writer. The streaming conversion below is the QC-3b
# extension: the per-role policy gains the dequantizing input path
# (core/dequantize_input.mojo -- Q4_K/Q5_K/Q6_K through the engine's
# own packed_value, F32 out), values are produced ROW BY ROW
# (dim0 values at a time), quantized per row with QC-2's
# quantize_q8_0, and emitted through QC-1's streaming writer
# (loader/gguf_writer.open_gguf_stream), so peak memory stays
# O(largest row + header), never O(file). Kept tensors are copied
# from the source mmap in 64 KiB chunks. Metadata handling is
# identical to the in-memory path (raw KV copy, general.file_type
# set to 7); tensor names/shapes/directory order are preserved.


def q8_0_keep_reason_dequant(name: String, entry: GGUFDirectoryEntry) -> String:
    # QC-3b per-role policy: identical to q8_0_keep_reason except
    # that a quantized source type WITH a wired F32 dequantizer
    # (Q4_K / Q5_K / Q6_K, the E2B census) quantizes instead of
    # being kept; a quantized type without one is kept with the
    # dequant path's named reason.
    if len(entry.dims) < 2:
        return String(
            "one-dimensional tensor (norm/scale/bias class) stays at source type"
        )
    if "norm" in name:
        return String("norm tensor stays at source type")
    if name.endswith(".bias"):
        return String("bias tensor stays at source type")
    var dense = (
        entry.tensor_type == UInt32(GGMLType.F16)
        or entry.tensor_type == UInt32(GGMLType.F32)
        or entry.tensor_type == UInt32(GGMLType.BF16)
    )
    if not dense and not dequant_input_supported(Int(entry.tensor_type)):
        return dequant_input_keep_reason(Int(entry.tensor_type))
    if Int(entry.dims[0]) % 32 != 0:
        return String(
            "dim0 "
            + String(entry.dims[0])
            + " is not a multiple of the 32-value Q8_0 block; stays at"
            + " source type (no padding -- GGUF has no padding semantics)"
        )
    return String("")


def _read_row_f32(
    seer: GGUFSeer, base: Int, entry: GGUFDirectoryEntry, row: Int
) raises -> List[Float32]:
    # One row (dim0 values) of a tensor as F32: exact widening for
    # dense floats (the _read_dense_f32 rules, row-sliced), the
    # dequantizing input path for quantized types.
    var dim0 = Int(entry.dims[0])
    var start = row * dim0
    if entry.tensor_type == UInt32(GGMLType.F16):
        var values = List[Float32]()
        values.reserve(dim0)
        var ptr = seer.mmap_ptr.unsafe_offset(base + start * 2).unsafe_bitcast[Scalar[f16]]()
        for i in range(dim0):
            values.append(ptr.unsafe_load(i).cast[f32]())
        return values^
    if entry.tensor_type == UInt32(GGMLType.F32):
        var values = List[Float32]()
        values.reserve(dim0)
        var ptr = seer.mmap_ptr.unsafe_offset(base + start * 4).unsafe_bitcast[Float32]()
        for i in range(dim0):
            values.append(ptr.unsafe_load(i))
        return values^
    if entry.tensor_type == UInt32(GGMLType.BF16):
        var values = List[Float32]()
        values.reserve(dim0)
        var ptr = seer.mmap_ptr.unsafe_offset(base + start * 2).unsafe_bitcast[UInt16]()
        for i in range(dim0):
            var bits = UInt32(ptr.unsafe_load(i)) << 16
            values.append(bitcast[DType.float32](bits))
        return values^
    return dequantize_range_f32(
        seer.mmap_ptr.unsafe_bitcast[UInt8](),
        base,
        Int(entry.tensor_type),
        start,
        dim0,
    )


def quantize_gguf_q8_0_streaming(
    source_path: String, output_path: String
) raises -> QuantizeReport:
    # Whole-model Q8_0 conversion through the streaming writer and
    # the dequantizing input path (QC-3b). Same report contract as
    # quantize_gguf_q8_0: every tensor named exactly once, as
    # quantized or as kept-with-a-reason.
    var head = read_gguf_header_copy(source_path)
    var seer = GGUFSeer(source_path)
    seer._open_and_map()
    seer._parse_header()
    var kvs = List[GGUFKV]()
    var saw_file_type = False
    for kv in head.kvs:
        if kv.key == "general.file_type":
            kvs.append(gguf_kv_u32("general.file_type", UInt32(Q8_0_FILE_TYPE)))
            saw_file_type = True
        else:
            kvs.append(kv.copy())
    if not saw_file_type:
        raise Error(
            "quantize: source carries no general.file_type key to set;"
            + " refusing to invent metadata layout"
        )
    var metas = List[GGUFWriterTensorMeta]()
    var reasons = List[String]()
    for entry in head.directory:
        var reason = q8_0_keep_reason_dequant(entry.name, entry.copy())
        reasons.append(reason)
        if reason.byte_length() == 0:
            metas.append(
                GGUFWriterTensorMeta(entry.name, entry.dims, UInt32(Q8_0_GGML_TYPE))
            )
        else:
            metas.append(
                GGUFWriterTensorMeta(entry.name, entry.dims, entry.tensor_type)
            )
    var writer = open_gguf_stream(output_path, kvs, metas, head.alignment)
    var report = QuantizeReport()
    for i in range(len(head.directory)):
        ref entry = head.directory[i]
        var base = head.data_offset + entry.relative_offset
        seer._require_range(base, entry.byte_size)
        writer.begin_tensor(i)
        if reasons[i].byte_length() == 0:
            var count = _element_count(entry.copy())
            var dim0 = Int(entry.dims[0])
            var rows = count // dim0
            for row in range(rows):
                var values = _read_row_f32(seer, base, entry.copy(), row)
                var payload = quantize_q8_0(values)
                writer.write_chunk(payload)
            report.quantized_names.append(String(entry.name))
            report.quantized_source_bytes.append(entry.byte_size)
            report.quantized_output_bytes.append(q8_0_payload_bytes(count))
            report.quantized_types.append(UInt32(Q8_0_GGML_TYPE))
        else:
            var done = 0
            while done < entry.byte_size:
                var n = entry.byte_size - done
                if n > 65536:
                    n = 65536
                var chunk = List[UInt8]()
                chunk.resize(n, UInt8(0))
                for k in range(n):
                    chunk[k] = UInt8(seer.mmap_ptr.unsafe_offset(base + done + k).unsafe_load())
                writer.write_chunk(chunk)
                done += n
            report.kept_names.append(String(entry.name))
            report.kept_types.append(entry.tensor_type)
            report.kept_bytes.append(entry.byte_size)
            report.kept_reasons.append(reasons[i])
        writer.end_tensor()
    report.file_type = Q8_0_FILE_TYPE
    report.output_bytes = writer.finish()
    return report^


# ---------------------------------------------------------------------------
# QC-5: the Q4_K_M tier (file_type 15) -- llama.cpp's rule set, flat tiling.
#
# POLICY (QC-5-NOTES): the tensor-role rules are llama.cpp's Q4_K_M rules as
# read from llama-quant.cpp at a956a85, WITHOUT imatrix (none exists; the
# honest comparator, llama-quantize without imatrix, does not use one
# either):
#   - output.weight                       -> Q6_K
#   - blk.<i>.attn_v.weight               -> Q6_K when use_more_bits(i, n)
#   - blk.<i>.ffn_down.weight             -> Q6_K when use_more_bits(i, n)
#   - every other dense matrix            -> Q4_K
#   - norms / biases / 1-D / non-floats   -> kept at source type, named
# with use_more_bits(i, n) = i < n/8 || i >= 7n/8 || (i - n/8) % 3 == 2.
#
# TILING FINDING (named divergence from QC-0-PLAN section 3's per-row
# wording): llama.cpp tiles K-quants per ROW (ne[0] must divide 256, else
# it falls back Q4_K -> Q5_0, Q6_K -> Q8_0, then F16). The Aesir engine
# prices and reads K tensors FLAT -- loader/gguf _tensor_byte_size is
# (element_count // 256) * block_bytes, packed_value indexes blocks flat
# over the tensor, and dequantize_range_f32 is flat -- so this converter
# quantizes a matrix iff its TOTAL element count is a multiple of 256.
# For stories260K every matrix qualifies flat (37/37) while NO matrix has
# dim0 divisible by 256; the two tilings are compared head-on in the
# stage-3 arbitration (llama-quantize's own product is the per-row one).


def _ggml_type_name(t: UInt32) -> String:
    if t == UInt32(Q8_0_GGML_TYPE):
        return String("Q8_0")
    if t == UInt32(Q4_K_GGML_TYPE):
        return String("Q4_K")
    if t == UInt32(Q6_K_GGML_TYPE):
        return String("Q6_K")
    return String("type ") + String(t)


def _file_type_name(file_type: Int) -> String:
    if file_type == Q8_0_FILE_TYPE:
        return String("Q8_0")
    if file_type == Q4_K_M_FILE_TYPE:
        return String("Q4_K_M")
    return String("unknown")


def _use_more_bits(i: Int, n: Int) -> Bool:
    # llama.cpp llama-quant.cpp use_more_bits, transcribed exactly.
    if n <= 0:
        return False
    if i < n // 8:
        return True
    if i >= (7 * n) // 8:
        return True
    return (i - n // 8) % 3 == 2


def _layer_index(name: String) -> Int:
    # Parses the layer number out of a "blk.<i>." tensor name; -1 if the
    # name carries no well-formed blk prefix.
    var bytes = name.as_bytes()
    if len(bytes) < 6:
        return -1
    if bytes[0] != 98 or bytes[1] != 108 or bytes[2] != 107 or bytes[3] != 46:
        return -1
    var value = 0
    var digits = 0
    var j = 4
    while j < len(bytes) and bytes[j] >= 48 and bytes[j] <= 57:
        value = value * 10 + Int(bytes[j]) - 48
        digits += 1
        j += 1
    if digits == 0 or j >= len(bytes) or bytes[j] != 46:
        return -1
    return value


def q4_k_m_plan(
    name: String, entry: GGUFDirectoryEntry, n_layers: Int
) -> Tuple[Int, String]:
    """The Q4_K_M per-tensor decision: (target ggml type, "") to quantize,
    or (-1, reason) to keep the tensor at its source type."""
    if len(entry.dims) < 2:
        return (
            -1,
            String(
                "one-dimensional tensor (norm/scale/bias class) stays at"
                " source type"
            ),
        )
    if "norm" in name:
        return (-1, String("norm tensor stays at source type"))
    if name.endswith(".bias"):
        return (-1, String("bias tensor stays at source type"))
    if (
        entry.tensor_type != UInt32(GGMLType.F16)
        and entry.tensor_type != UInt32(GGMLType.F32)
        and entry.tensor_type != UInt32(GGMLType.BF16)
    ):
        return (
            -1,
            String("source type ")
            + String(entry.tensor_type)
            + " is not a dense float; stays at source type",
        )
    var count = _element_count(entry)
    if count % 256 != 0:
        return (
            -1,
            String("element count ")
            + String(count)
            + " is not a multiple of the 256-value K-quant super-block;"
            + " stays at source type (no padding -- GGUF has no padding"
            + " semantics)",
        )
    if name == "output.weight":
        return (Int(Q6_K_GGML_TYPE), String(""))
    var layer = _layer_index(name)
    if layer >= 0 and _use_more_bits(layer, n_layers):
        if name.endswith(".attn_v.weight"):
            return (Int(Q6_K_GGML_TYPE), String(""))
        if name.endswith(".ffn_down.weight"):
            return (Int(Q6_K_GGML_TYPE), String(""))
    return (Int(Q4_K_GGML_TYPE), String(""))


def quantize_gguf_q4_k_m(
    source_path: String, output_path: String
) raises -> QuantizeReport:
    """Converts a whole GGUF to Q4_K_M under the policy above and writes it
    through the QC-1 writer with general.file_type = 15. Metadata is copied
    wholesale (raw KV carriage) except the one key quantization owns;
    tensor names, shapes, and directory order are preserved exactly."""
    var head = read_gguf_header_copy(source_path)
    var seer = GGUFSeer(source_path)
    seer._open_and_map()
    seer._parse_header()
    var n_layers = 0
    for entry in head.directory:
        var layer = _layer_index(entry.name)
        if layer + 1 > n_layers:
            n_layers = layer + 1
    var desc = GGUFModelDesc()
    desc.alignment = head.alignment
    var saw_file_type = False
    for kv in head.kvs:
        if kv.key == "general.file_type":
            desc.add_kv(
                gguf_kv_u32("general.file_type", UInt32(Q4_K_M_FILE_TYPE))
            )
            saw_file_type = True
        else:
            desc.add_kv(kv)
    if not saw_file_type:
        raise Error(
            "quantize: source carries no general.file_type key to set;"
            " refusing to invent metadata layout"
        )
    var report = QuantizeReport()
    report.file_type = Q4_K_M_FILE_TYPE
    for entry in head.directory:
        var base = head.data_offset + entry.relative_offset
        seer._require_range(base, entry.byte_size)
        var plan = q4_k_m_plan(entry.name, entry.copy(), n_layers)
        if plan[0] >= 0:
            var values = _read_dense_f32(seer, base, entry.copy())
            var payload = List[UInt8]()
            if plan[0] == Int(Q6_K_GGML_TYPE):
                payload = quantize_q6_k(values)
            else:
                payload = quantize_q4_k(values)
            report.quantized_names.append(String(entry.name))
            report.quantized_source_bytes.append(entry.byte_size)
            report.quantized_output_bytes.append(len(payload))
            report.quantized_types.append(UInt32(plan[0]))
            desc.add_tensor(
                GGUFWriterTensor(
                    entry.name, entry.dims, UInt32(plan[0]), payload
                )
            )
        else:
            var payload = List[UInt8]()
            payload.reserve(entry.byte_size)
            for index in range(entry.byte_size):
                payload.append(
                    UInt8(
                        seer.mmap_ptr.unsafe_offset(base + index).unsafe_load()
                    )
                )
            report.kept_names.append(String(entry.name))
            report.kept_types.append(entry.tensor_type)
            report.kept_bytes.append(entry.byte_size)
            report.kept_reasons.append(plan[1])
            desc.add_tensor(
                GGUFWriterTensor(
                    entry.name, entry.dims, entry.tensor_type, payload
                )
            )
    report.output_bytes = write_gguf_file(output_path, desc)
    return report^


# ---------------------------------------------------------------------------
# QC-6: the streaming Q4_K_M converter -- the 27B tier.
#
# QC-5's in-memory converter tiles K-quants FLAT (total element count
# % 256 == 0) and refuses --streaming by name. QC-6 changes the gate
# to the QC-5 risk-1 rule and streams:
#
# TILING RULE (per tensor): a tensor is K-packed ONLY where
# dim0 % 256 == 0. There flat tiling == per-row tiling byte for
# byte, so the flat consumers (GGUFSeer pricing, packed_value,
# dequantize_range_f32) and the per-row consumers (PackedGGUF
# pricing, the fused K GEMM, ggml) read identical bytes.
#
# FALLBACKS (llama-quantize's tensor_type_fallback, llama-quant.cpp
# at a956a85, adapted to the writers this workstream owns):
# - a K designee with dim0 % 256 != 0 but dim0 % 32 == 0 falls back
#   to Q8_0 (llama's exact Q6_K fallback; for Q4_K llama falls to
#   Q5_0, a writer this workstream does not own -- Q8_0 is the
#   named substitute, per-row valid in every reader).
# - a K designee with dim0 % 32 != 0 stays at source type (llama
#   falls to F16; keeping the source never invents data).
# - rank-1 / norm / bias tensors stay at source type (QC-0 s.3).
# - ssm_conv1d.weight stays at source type: QC-0 s.3 verbatim,
#   the SSM conv kernel rows (dim0 = conv_kernel, 4 on the 27B)
#   stay F32, full stop.
#
# INPUT: values come row by row through the engine's own readers --
# dense widening for F16/F32/BF16 sources, the dequantizing input
# path (core/dequantize_input, QC-6 wires its Q8_0 kind) for
# quantized sources. The 27B source is Q8_0 throughout its large
# weights, so the real conversion is dequantize_q8_0 -> F32 row ->
# QC-5 packer -> streamed payload, peak heap O(largest row).
#
# POLICY: file_type 15 exactly as QC-5 (output -> Q6_K; attn_v and
# ffn_down -> Q6_K on use_more_bits layers; everything else Q4_K),
# with the tiling gate and fallbacks above applied per tensor.


def q4_k_m_plan_qc6(
    name: String, entry: GGUFDirectoryEntry, n_layers: Int
) -> Tuple[Int, String]:
    """The QC-6 per-tensor decision: (target ggml type, "") to
    quantize (K tier or the Q8_0 fallback), or (-1, reason) to keep
    the tensor at its source type."""
    if len(entry.dims) < 2:
        return (
            -1,
            String(
                "one-dimensional tensor (norm/scale/bias class) stays at"
                " source type"
            ),
        )
    if "norm" in name:
        return (-1, String("norm tensor stays at source type"))
    if name.endswith(".bias"):
        return (-1, String("bias tensor stays at source type"))
    if name.endswith("ssm_conv1d.weight"):
        return (
            -1,
            String(
                "ssm_conv1d tensor stays at source type (QC-0 section 3:"
                " SSM conv rows are not K-tileable and stay F32)"
            ),
        )
    if not dequant_input_supported(Int(entry.tensor_type)):
        return (-1, dequant_input_keep_reason(Int(entry.tensor_type)))
    var target = Int(Q4_K_GGML_TYPE)
    if name == "output.weight":
        target = Int(Q6_K_GGML_TYPE)
    else:
        var layer = _layer_index(name)
        if layer >= 0 and _use_more_bits(layer, n_layers):
            if name.endswith(".attn_v.weight"):
                target = Int(Q6_K_GGML_TYPE)
            elif name.endswith(".ffn_down.weight"):
                target = Int(Q6_K_GGML_TYPE)
    var dim0 = Int(entry.dims[0])
    if dim0 % 256 == 0:
        return (target, String(""))
    if dim0 % 32 == 0:
        return (Int(Q8_0_GGML_TYPE), String(""))
    return (
        -1,
        String("dim0 ")
        + String(dim0)
        + " is not a multiple of 32; no quant tier tiles it -- stays"
        + " at source type (no padding -- GGUF has no padding semantics)",
    )


def quantize_gguf_q4_k_m_streaming_qc6(
    source_path: String, output_path: String
) raises -> QuantizeReport:
    """Streaming whole-model Q4_K_M conversion under the QC-6 tiling
    rule. Same report contract as the QC-3b streaming converter:
    every tensor named exactly once, quantized (with its emitted
    type) or kept-with-a-reason; metadata copied raw except
    general.file_type = 15."""
    var head = read_gguf_header_copy(source_path)
    var seer = GGUFSeer(source_path)
    seer._open_and_map()
    seer._parse_header()
    var n_layers = 0
    for entry in head.directory:
        var layer = _layer_index(entry.name)
        if layer + 1 > n_layers:
            n_layers = layer + 1
    var kvs = List[GGUFKV]()
    var saw_file_type = False
    for kv in head.kvs:
        if kv.key == "general.file_type":
            kvs.append(
                gguf_kv_u32("general.file_type", UInt32(Q4_K_M_FILE_TYPE))
            )
            saw_file_type = True
        else:
            kvs.append(kv.copy())
    if not saw_file_type:
        raise Error(
            "quantize: source carries no general.file_type key to set;"
            + " refusing to invent metadata layout"
        )
    var metas = List[GGUFWriterTensorMeta]()
    var plans = List[Tuple[Int, String]]()
    for entry in head.directory:
        var plan = q4_k_m_plan_qc6(entry.name, entry.copy(), n_layers)
        plans.append(plan)
        if plan[0] >= 0:
            metas.append(
                GGUFWriterTensorMeta(entry.name, entry.dims, UInt32(plan[0]))
            )
        else:
            metas.append(
                GGUFWriterTensorMeta(entry.name, entry.dims, entry.tensor_type)
            )
    var writer = open_gguf_stream(output_path, kvs, metas, head.alignment)
    var report = QuantizeReport()
    for i in range(len(head.directory)):
        ref entry = head.directory[i]
        var base = head.data_offset + entry.relative_offset
        seer._require_range(base, entry.byte_size)
        writer.begin_tensor(i)
        var plan = plans[i]
        if plan[0] >= 0:
            var count = _element_count(entry.copy())
            var dim0 = Int(entry.dims[0])
            var rows = count // dim0
            for row in range(rows):
                var values = _read_row_f32(seer, base, entry.copy(), row)
                var payload = List[UInt8]()
                if plan[0] == Int(Q6_K_GGML_TYPE):
                    payload = quantize_q6_k(values)
                elif plan[0] == Int(Q8_0_GGML_TYPE):
                    payload = quantize_q8_0(values)
                else:
                    payload = quantize_q4_k(values)
                writer.write_chunk(payload)
            var out_bytes = 0
            if plan[0] == Int(Q6_K_GGML_TYPE):
                out_bytes = q6_k_payload_bytes(count)
            elif plan[0] == Int(Q8_0_GGML_TYPE):
                out_bytes = q8_0_payload_bytes(count)
            else:
                out_bytes = q4_k_payload_bytes(count)
            report.quantized_names.append(String(entry.name))
            report.quantized_source_bytes.append(entry.byte_size)
            report.quantized_output_bytes.append(out_bytes)
            report.quantized_types.append(UInt32(plan[0]))
        else:
            var done = 0
            while done < entry.byte_size:
                var n = entry.byte_size - done
                if n > 65536:
                    n = 65536
                var chunk = List[UInt8]()
                chunk.resize(n, UInt8(0))
                for k in range(n):
                    chunk[k] = UInt8(
                        seer.mmap_ptr.unsafe_offset(base + done + k).unsafe_load()
                    )
                writer.write_chunk(chunk)
                done += n
            report.kept_names.append(String(entry.name))
            report.kept_types.append(entry.tensor_type)
            report.kept_bytes.append(entry.byte_size)
            report.kept_reasons.append(plan[1])
        writer.end_tensor()
    report.file_type = Q4_K_M_FILE_TYPE
    report.output_bytes = writer.finish()
    return report^
