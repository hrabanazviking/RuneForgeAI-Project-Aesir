# Metadata-only adapter over the existing project reader; no tensor conversion.
from std.collections import Dict
from armvegr.safetensors import SafetensorsLoader


@fieldwise_init
struct SafetensorsTensor(Copyable, Movable):
    var name: String
    var dtype: UInt8  # Existing reader: 0 F16, 1 BF16, 2 F32; not GGUF type IDs.
    var shape: List[Int]
    var elements: Int64
    var file_offset: Int
    var byte_count: Int


@fieldwise_init
struct SafetensorsInventory(Movable):
    var source_bytes: Int64
    var data_offset: Int64
    var tensors: List[SafetensorsTensor]
    var metadata: Dict[String, String]


def read_safetensors_inventory(path: String, header_bound: Int, tensor_bound: Int,
                                rank_bound: Int, work_bound: Int,
                                depth_bound: Int) raises -> SafetensorsInventory:
    var source = SafetensorsLoader()
    source.open(path, header_bound, tensor_bound, rank_bound, work_bound, depth_bound)
    try:
        var tensors = List[SafetensorsTensor]()
        for tensor in source.descs:
            tensors.append(SafetensorsTensor(tensor.name, tensor.dtype, tensor.shape.copy(),
                tensor.element_count(), tensor.data_start, tensor.data_end - tensor.data_start))
        var result = SafetensorsInventory(source.file_size, source.header_size + 8,
                                          tensors^, source.metadata.copy())
        source.close()
        return result^
    except e:
        source.close()
        raise e
