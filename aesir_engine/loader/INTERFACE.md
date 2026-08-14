# Loader Domain Interface Specification

## Public Structs & Enums

### `GGMLType`
Enumeration of supported GGML tensor data types and compressed format translation.

```mojo
struct GGMLType:
    comptime F32 = 0
    comptime F16 = 1
    comptime Q4_0 = 2
    comptime Q4_1 = 3
    comptime Q5_0 = 6
    comptime Q5_1 = 7
    comptime Q8_0 = 8
    comptime Q8_1 = 9
    comptime Q2_K = 10
    comptime Q3_K = 11
    comptime Q4_K = 12
    comptime Q5_K = 13
    comptime Q6_K = 14
    comptime Q8_K = 15
    comptime GPTQ_4BIT = 20
    comptime AWQ_4BIT = 21
    comptime EXL2 = 22
    comptime HQQ = 23
    comptime SMOOTHQUANT = 24

    @staticmethod
    def to_compressed_format(ggml_type: UInt32) -> CompressedFormatType: ...
```

### `GGUFSeer`
GGUF binary model loader.

```mojo
struct GGUFSeer:
    var file_path: String
    var tensors: Dict[String, RuneTensor[f16]]
    var fd: Int32
    var file_size: Int64
    var mmap_ptr: Pointer[Int8, MutUntrackedOrigin]

    def __init__(out self, file_path: String): ...
    def skip_value(self, val_type: UInt32, offset: Int) -> Int: ...
    def mmap_and_load(mut self, mut pool: MimirWell): ...
    def mmap_and_load(mut self, mut pool: MimirWell, mut weaver: RuneWeaver): ...
    def __deinit__(deinit self): ...
```

### `ONNXModelSeer` (Slice 11)
ONNX binary protocol buffer and node graph seer.

```mojo
struct ONNXModelSeer:
    var model_path: String
    var ir_version: Int64
    var producer_name: String
    var num_nodes: Int

    def __init__(out self, model_path: String): ...
    def parse_onnx_header(mut self) -> Bool: ...
    def map_to_well(self, mut well: MimirWell) -> Bool: ...
```


### `RuneWeaver` (Slice 4)
Pure Mojo BPE tokenizer interface.

```mojo
struct RuneWeaver:
    var vocab: List[String]
    var token_to_id: Dict[String, Int]
    var vocab_size: Int

    def __init__(out self): ...
    def add_token(mut self, token: String, id: Int): ...
    def byte_to_hex_token(self, b: UInt8) -> String: ...
    def encode(self, prompt: String) -> List[Int]: ...
    def decode(self, token: Int) -> String: ...
```

### `HuggingFaceSeer` (`loader/huggingface.mojo`) (Slice 13)
Sovereign repository scout, URI tag normalizer, CDN stream URL builder, and weight stream downloader for HuggingFace Hub.

```mojo
struct HuggingFaceSeer:
    var default_cdn: String

    def __init__(out self): ...
    @staticmethod
    def parse_hf_repo(model_tag: String) -> String: ...
    @staticmethod
    def is_hf_tag(model_tag: String) -> Bool: ...
    @staticmethod
    def build_download_url(repo_id: String, filename: String = "model.gguf") -> String: ...
    def download_hf_model(self, repo_id: String, filename: String) raises -> Bool: ...
```
