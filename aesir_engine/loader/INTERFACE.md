# Loader Domain Interface Specification

> **Current execution boundary — 2026-08-30:** `gguf.mojo`/`tokenizer.mojo`
> retain the CPU Llama slice. `packed_gguf.mojo` and `gemma4_tokenizer.mojo`
> provide the bounded GGUF and BPE contract for the native Gemma CUDA profile;
> `llama3_tokenizer.mojo` supplies the separate Stheno byte-BPE/chat contract.
> `huggingface.mojo` implements the public pinned `pull` workflow. These do not
> make arbitrary GGUF formats, model architectures, or Hub operations supported.

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
    comptime IQ2_XXS = 16
    comptime IQ1_S = 19
    comptime TQ1_0 = 34

    @staticmethod
    def to_compressed_format(ggml_type: UInt32) raises -> CompressedFormatType: ...
```

`to_compressed_format()` maps only implemented GGML tensor layouts, including
IQ2_XXS, IQ1_S, and TQ1_0, and raises for non-quantized, unknown, and
reserved-but-unimplemented types. It never substitutes Q4_K_M for an
unsupported value.

### `GGUFModelConfig`
Validated Llama architecture and tokenizer-special-token metadata derived from
the GGUF key/value table. `head_dim()` and `kv_dim()` keep query width and
grouped-query KV width distinct.

```mojo
struct GGUFModelConfig(Copyable):
    var architecture: String
    var context_length: Int
    var embedding_length: Int
    var feed_forward_length: Int
    var block_count: Int
    var head_count: Int
    var head_count_kv: Int
    var rope_dimension_count: Int
    var rms_epsilon: Float32
    var unknown_token_id: Int
    var bos_token_id: Int
    var eos_token_id: Int

    def head_dim(self) -> Int: ...
    def kv_dim(self) -> Int: ...
    def validate(self) raises: ...
```

### `GGUFSeer`
Bounds-checked GGUF v3 Llama loader. Supported F16 matrices alias the immutable
mapped file directly; required F32 normalization vectors are converted once
into `MimirWell`. Unsupported types, shapes, offsets, truncation, architectures,
or missing tensors raise before `is_loaded` becomes true.

```mojo
struct GGUFSeer:
    var file_path: String
    var tensors: Dict[String, RuneTensor[f16]]
    var tensor_file_offsets: Dict[String, Int]
    var tensor_types: Dict[String, UInt32]
    var config: GGUFModelConfig
    var fd: Int32
    var file_size: Int64
    var mmap_ptr: Pointer[Int8, MutUntrackedOrigin]
    var is_mapped: Bool
    var is_loaded: Bool
    var version: UInt32
    var tensor_count: Int
    var kv_count: Int
    var alignment: Int
    var data_offset: Int

    def __init__(out self, file_path: String): ...
    def inspect_metadata(mut self, mut weaver: RuneWeaver) raises: ...
    def mmap_and_load(mut self, mut pool: MimirWell) raises: ...
    def mmap_and_load(mut self, mut pool: MimirWell, mut weaver: RuneWeaver) raises: ...
    def __deinit__(deinit self): ...
```

### `ONNXModelSeer` (metadata parser; execution unavailable)

`parse_onnx_header()` safely opens and read-only maps `model_path` on Linux;
`parse_onnx_header_bytes()` decodes bounded protobuf `ModelProto`, default-domain
opset and graph node metadata transactionally. Strings are length-capped and
UTF-8 checked, unknown wire fields are skipped safely, and malformed input is
rejected. Recognized operator names describe the accepted metadata subset only.
`map_to_well()` raises unsupported because TensorProto initializer mapping and
ONNX execution are not implemented.

```mojo
struct ONNXModelSeer:
    var model_path: String
    var ir_version: Int64
    var producer_name: String
    var opset_version: Int64
    var num_nodes: Int
    var nodes: List[ONNXNodeDescriptor]

    def parse_onnx_header(mut self) raises -> Bool: ...
    def parse_onnx_header_bytes(mut self, bytes: Pointer[Scalar[DType.uint8], MutUntrackedOrigin], size: Int) raises -> Bool: ...
    def map_to_well(mut self, mut well: MimirWell) raises -> Bool: ...
```


### `EXL2ModelSeer` (descriptor only; parser/runtime unavailable)

Construction reports zero model metadata. `parse_exl2_header_bytes()`,
`map_to_well()` and the execution contract raise unsupported. `add_sub_block()`
only validates caller-declared 2..8 bpw metadata and computes a weighted average;
it is not evidence that a model was parsed. Real EXL2 requires config and
safetensors handling plus custom kernels, none of which is implemented.


### `RuneWeaver` (Slice 4, real-GGUF vertical slice)
Pure Mojo, model-driven Llama SentencePiece tokenizer. Vocabulary, scores,
token types, and special IDs are loaded together. Encoding applies the visible
SentencePiece space marker, score-prioritized pair merges, UTF-8 symbol
boundaries, byte fallback, and opt-in model-controlled BOS insertion.

```mojo
struct RuneWeaver:
    var vocab: List[String]
    var token_to_id: Dict[String, Int]
    var scores: List[Float32]
    var token_types: List[Int]
    var vocab_size: Int
    var unknown_token_id: Int
    var bos_token_id: Int
    var eos_token_id: Int
    var add_bos_token: Bool

    def __init__(out self): ...
    def add_token(mut self, token: String, id: Int, score: Float32 = 0.0, token_type: Int = 1): ...
    def set_token_score(mut self, token_id: Int, score: Float32): ...
    def set_token_type(mut self, token_id: Int, token_type: Int): ...
    def set_special_tokens(mut self, unknown_token_id: Int, bos_token_id: Int, eos_token_id: Int): ...
    def byte_to_hex_token(self, b: UInt8) -> String: ...
    def encode(self, prompt: String, add_bos: Bool = False) -> List[Int]: ...
    def decode(self, token: Int) -> String: ...
```

### `HuggingFaceSeer` (`loader/huggingface.mojo`)
Public pinned-GGUF downloader and tag/URL builder. Downloads use checked argv
subprocesses, HTTPS-only redirects, bounded time/size, optional parallel ranges,
exact SHA-256/size checks and atomic exclusive publication. Existing files and
symlinks are never overwritten. Authentication, restart/resume and model-store
registration remain unsupported.

```mojo
struct HuggingFaceSeer:
    var default_cdn: String

    def __init__(out self): ...
    @staticmethod
    def parse_hf_repo(model_tag: String) -> String: ...
    @staticmethod
    def is_hf_tag(model_tag: String) -> Bool: ...
    @staticmethod
    def build_download_url(repo_id: String, filename: String = "model.gguf", revision: String = "main") raises -> String: ...
    def download_hf_model(self, repo_id: String, filename: String, destination: String = "", revision: String = "", expected_sha256: String = "", expected_size: Int = 0, connections: Int = 1) raises -> Bool: ...
```

### Packed Gemma 4 and Llama 3 loading

`PackedGGUF` owns its mmap and a bounded metadata/tensor index; `PackedTensor`
describes validated dense storage without pretending packed bytes are F16.
Supported storage is F32, F16, BF16, Q4_K, Q5_K and Q6_K. It rejects overlapping,
misaligned or truncated tensors before core code can upload them.

`Gemma4Tokenizer` loads the embedded vocabulary and merge ranks, implements raw
UTF-8 Gemma BPE with newline boundaries, and constructs text-chat control tokens
explicitly. The generic `RuneWeaver` retains model-driven Llama space-prefix
handling; Llama and Qwen use their own RoPE base/layout metadata in core.

`Llama3Tokenizer(model: PackedGGUF)` admits `gpt2`/`llama-bpe`, the 128,256-token
vocabulary and expected control IDs. `encode(text, add_bos=False)` applies the
Unicode Llama 3 segmentation pattern, GPT-2 byte encoding, whole-segment lookup
and ranked BPE. Plain input cannot inject control IDs. `append_header`,
`append_message` and `decode(token, decoder)` own chat framing and streaming
UTF-8. The Unicode 16 category table is generated at build time.
