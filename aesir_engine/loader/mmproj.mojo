"""Vision projector (mmproj) discovery, structure parsing, and validation.

An mmproj GGUF is the separate vision/audio tower file that ships beside a
multimodal language model (llama.cpp convention). Its architecture string is
``clip``, its tensors run to rank 4, and it carries no tokenizer vocabulary,
so neither ``GGUFSeer.mmap_and_load`` (LLM tensor validation, tokenizer
validation, rank <= 2) nor ``PackedGGUF`` (rank <= 2) can read one. This
module is the dedicated inventory parser for that format: it reuses
``GGUFSeer``'s bounds-checked byte readers, walks the full metadata and
tensor tables at ranks 1-4, range-checks every tensor against the file, and
extracts a validated ``VisionTowerSpec``.

Scope boundary (docs/VISION_MMPROJ_DEVELOPMENT.md): this module proves
structure only. It does not decode images, run the vision encoder, or inject
embeddings. Audio towers present in the same file are inventoried as
present, never interpreted.
"""
from std.collections import Dict
from std.ffi import external_call
from loader.gguf import GGUFSeer
from hailbru.syscall import list_dir, os_host_architecture


# ---------------------------------------------------------------------------
# GGML tensor byte geometry over total element counts (rank 1-4 safe).
# ---------------------------------------------------------------------------

def _block_geometry(kind: Int) raises -> Tuple[Int, Int]:
    """Returns (elements per block, bytes per block) for a GGML type id."""
    if kind == 0:  # F32
        return (1, 4)
    if kind == 1 or kind == 30:  # F16 / BF16
        return (1, 2)
    if kind == 2:  # Q4_0
        return (32, 18)
    if kind == 3:  # Q4_1
        return (32, 20)
    if kind == 6:  # Q5_0
        return (32, 22)
    if kind == 7:  # Q5_1
        return (32, 24)
    if kind == 8:  # Q8_0
        return (32, 34)
    if kind == 9:  # Q8_1
        return (32, 36)
    if kind == 10:  # Q2_K
        return (256, 84)
    if kind == 11:  # Q3_K
        return (256, 110)
    if kind == 12:  # Q4_K
        return (256, 144)
    if kind == 13:  # Q5_K
        return (256, 176)
    if kind == 14:  # Q6_K
        return (256, 210)
    if kind == 16:  # IQ2_XXS
        return (256, 66)
    if kind == 17:  # IQ2_XS
        return (256, 74)
    if kind == 18:  # IQ3_XXS
        return (256, 50)
    if kind == 19:  # IQ1_S
        return (256, 52)
    if kind == 20:  # IQ4_NL
        return (32, 18)
    if kind == 21:  # IQ3_S
        return (256, 110)
    if kind == 22:  # IQ2_S
        return (256, 82)
    if kind == 23:  # IQ4_XS
        return (256, 136)
    raise Error("mmproj: unsupported GGML tensor type " + String(kind))


def mmproj_tensor_byte_count(kind: Int, dims: List[Int]) raises -> Int:
    """Exact on-disk byte count of a tensor with the given GGUF dims.

    ``dims`` are in GGUF order (innermost first). Quantized block types tile
    the innermost dimension, which must be block aligned.
    """
    if len(dims) < 1 or len(dims) > 4:
        raise Error("mmproj: tensor rank must be 1..4")
    var elements = 1
    for i in range(len(dims)):
        if dims[i] <= 0:
            raise Error("mmproj: tensor dimension must be positive")
        if dims[i] > 9223372036854775807 // elements:
            raise Error("mmproj: tensor element count overflows host index")
        elements *= dims[i]
    var geometry = _block_geometry(kind)
    var block_elements = geometry[0]
    var block_bytes = geometry[1]
    if block_elements == 1:
        return elements * block_bytes
    if dims[0] % block_elements != 0:
        raise Error("mmproj: innermost dimension is not block aligned")
    return elements // block_elements * block_bytes


def mmproj_type_name(kind: Int) -> String:
    if kind == 0:
        return "F32"
    if kind == 1:
        return "F16"
    if kind == 2:
        return "Q4_0"
    if kind == 3:
        return "Q4_1"
    if kind == 6:
        return "Q5_0"
    if kind == 7:
        return "Q5_1"
    if kind == 8:
        return "Q8_0"
    if kind == 9:
        return "Q8_1"
    if kind == 10:
        return "Q2_K"
    if kind == 11:
        return "Q3_K"
    if kind == 12:
        return "Q4_K"
    if kind == 13:
        return "Q5_K"
    if kind == 14:
        return "Q6_K"
    if kind == 30:
        return "BF16"
    return "type-" + String(kind)


# ---------------------------------------------------------------------------
# Discovery: which file beside a model is its mmproj?
# ---------------------------------------------------------------------------

def _path_exists(path: String) -> Bool:
    var encoded = List[Int8]()
    for byte in path.as_bytes():
        encoded.append(Int8(byte))
    encoded.append(0)
    return external_call["access", Int32](encoded.unsafe_ptr(), 0) == 0


def split_model_path(model_path: String) -> Tuple[String, String]:
    """Splits a model path into (directory with trailing slash, stem).

    The stem is the file name without a trailing ``.gguf`` suffix.
    """
    var bytes = model_path.as_bytes()
    var slash = -1
    for i in range(len(bytes)):
        if bytes[i] == 47:  # '/'
            slash = i
    var directory = String("")
    var filename = model_path
    if slash >= 0:
        directory = String(model_path[byte=:slash + 1])
        filename = String(model_path[byte=slash + 1:])
    var stem = filename
    if filename.endswith(".gguf"):
        stem = String(filename[byte=:filename.byte_length() - 5])
    return (directory, stem)


def mmproj_candidate_paths(model_path: String) -> List[String]:
    """Ordered explicit mmproj spellings to probe beside a model file."""
    var parts = split_model_path(model_path)
    var directory = parts[0]
    var stem = parts[1]
    var candidates = List[String]()
    candidates.append(directory + "mmproj-" + stem + ".gguf")
    candidates.append(directory + "mmproj_" + stem + ".gguf")
    candidates.append(directory + "mmproj.gguf")
    candidates.append(directory + stem + ".mmproj.gguf")
    candidates.append(directory + stem + ".mmproj-Q8_0.gguf")
    candidates.append(directory + stem + ".mmproj-f16.gguf")
    candidates.append(directory + stem + ".mmproj-BF16.gguf")
    return candidates^


def pick_mmproj_sibling(names: List[String], stem: String) -> String:
    """Deterministically picks the mmproj file name from a directory listing.

    Only names containing ``mmproj`` and ending ``.gguf`` qualify. Preference:
    names that also contain the model stem first, then lexicographic order
    (so a Q8_0 projector wins over its f16 sibling). Returns "" when nothing
    qualifies.
    """
    var best = String("")
    for i in range(len(names)):
        var name = names[i]
        if "mmproj" not in name or not name.endswith(".gguf"):
            continue
        if best == "":
            best = name
            continue
        var best_has_stem = stem in best
        var name_has_stem = stem in name
        if name_has_stem and not best_has_stem:
            best = name
        elif name_has_stem == best_has_stem and name < best:
            best = name
    return best


def find_mmproj_beside(model_path: String) -> String:
    """Returns the mmproj path beside a model, or "" when there is none.

    Probes the explicit candidate spellings first, then falls back to a
    directory listing pick. Any filesystem failure reads as "no mmproj":
    a model without a projector is an ordinary text model, not an error.
    """
    var candidates = mmproj_candidate_paths(model_path)
    for i in range(len(candidates)):
        if _path_exists(candidates[i]):
            return candidates[i]
    var parts = split_model_path(model_path)
    var directory = parts[0]
    if directory == "":
        directory = "./"
    try:
        var names = list_dir(os_host_architecture(), directory)
        var pick = pick_mmproj_sibling(names, parts[1])
        if pick != "":
            return directory + pick
    except:
        pass
    return ""


# ---------------------------------------------------------------------------
# Parsed inventory
# ---------------------------------------------------------------------------

@fieldwise_init
struct MmprojTensor(ImplicitlyCopyable, Movable):
    var offset: Int  # absolute file offset of the tensor data
    var kind: Int  # GGML type id
    var byte_count: Int
    var elements: Int
    var rank: Int
    var d0: Int
    var d1: Int
    var d2: Int
    var d3: Int

    def dims(self) -> List[Int]:
        var out = List[Int]()
        out.append(self.d0)
        if self.rank >= 2:
            out.append(self.d1)
        if self.rank >= 3:
            out.append(self.d2)
        if self.rank >= 4:
            out.append(self.d3)
        return out^


struct VisionTowerSpec(Copyable):
    """Validated vision-tower geometry read from an mmproj's clip metadata."""

    var present: Bool
    var projector_type: String
    var projection_dim: Int
    var image_size: Int
    var patch_size: Int
    var embedding_length: Int
    var feed_forward_length: Int
    var block_count: Int
    var head_count: Int
    var layer_norm_epsilon: Float32
    var image_mean: List[Float32]
    var image_std: List[Float32]
    var audio_present: Bool

    def __init__(out self):
        self.present = False
        self.projector_type = ""
        self.projection_dim = 0
        self.image_size = 0
        self.patch_size = 0
        self.embedding_length = 0
        self.feed_forward_length = 0
        self.block_count = 0
        self.head_count = 0
        self.layer_norm_epsilon = Float32(1e-6)
        self.image_mean = List[Float32]()
        self.image_std = List[Float32]()
        self.audio_present = False

    def __copyinit__(out self, existing: Self):
        self.present = existing.present
        self.projector_type = String(existing.projector_type)
        self.projection_dim = existing.projection_dim
        self.image_size = existing.image_size
        self.patch_size = existing.patch_size
        self.embedding_length = existing.embedding_length
        self.feed_forward_length = existing.feed_forward_length
        self.block_count = existing.block_count
        self.head_count = existing.head_count
        self.layer_norm_epsilon = existing.layer_norm_epsilon
        self.image_mean = existing.image_mean.copy()
        self.image_std = existing.image_std.copy()
        self.audio_present = existing.audio_present

    def patch_grid(self) -> Int:
        """Patches along one image edge (image_size / patch_size)."""
        if self.patch_size <= 0:
            return 0
        return self.image_size // self.patch_size

    def patch_count(self) -> Int:
        var grid = self.patch_grid()
        return grid * grid

    def head_dim(self) -> Int:
        if self.head_count <= 0:
            return 0
        return self.embedding_length // self.head_count

    def check_language_match(self, language_embedding_length: Int) raises:
        """The projector output must land exactly on the LM hidden size."""
        if not self.present:
            raise Error("mmproj: no vision tower to match against a language model")
        if self.projection_dim != language_embedding_length:
            raise Error(
                "mmproj: projection_dim " + String(self.projection_dim)
                + " does not match language embedding_length "
                + String(language_embedding_length)
            )


struct MmprojFile:
    var path: String
    var source: GGUFSeer
    var fields: Dict[String, Int]
    var field_types: Dict[String, Int]
    var tensors: Dict[String, MmprojTensor]
    var data_offset: Int

    def __init__(out self, path: String) raises:
        self.path = path
        self.source = GGUFSeer(path)
        self.fields = Dict[String, Int]()
        self.field_types = Dict[String, Int]()
        self.tensors = Dict[String, MmprojTensor]()
        self.data_offset = 0
        self.source._open_and_map()
        self.source._parse_header()
        self._interpret_tables()

    def _interpret_tables(mut self) raises:
        if self.source.kv_count > 4096 or self.source.tensor_count > 100000:
            raise Error("mmproj: unreasonable table count")
        var cursor = 24
        for _ in range(self.source.kv_count):
            var key = self.source._read_string(cursor)
            cursor = self.source._string_end(cursor)
            var kind = self.source._read_u32(cursor)
            cursor += 4
            if key in self.fields:
                raise Error("mmproj: duplicate metadata " + key)
            self.fields[key] = cursor
            self.field_types[key] = Int(kind)
            if kind == 9 and self.source._read_u32(cursor) == 9:
                raise Error("mmproj: nested metadata arrays unsupported")
            cursor = self.source.skip_value(kind, cursor)
        var alignment = self.integer("general.alignment", 32)
        if alignment <= 0 or alignment > 4096 or alignment & (alignment - 1) != 0:
            raise Error("mmproj: invalid alignment")
        var names = List[String]()
        for _ in range(self.source.tensor_count):
            var name = self.source._read_string(cursor)
            cursor = self.source._string_end(cursor)
            var rank = Int(self.source._read_u32(cursor))
            cursor += 4
            if rank < 1 or rank > 4:
                raise Error("mmproj: tensor rank must be 1..4: " + name)
            var dims = List[Int]()
            for _ in range(rank):
                var dim = self.source._read_u64(cursor)
                if dim > UInt64(9223372036854775807):
                    raise Error("mmproj: tensor dimension exceeds host index: " + name)
                dims.append(Int(dim))
                cursor += 8
            var kind = Int(self.source._read_u32(cursor))
            var relative = Int(self.source._read_u64(cursor + 4))
            cursor += 12
            if relative < 0 or relative % alignment != 0:
                raise Error("mmproj: invalid tensor extent: " + name)
            var byte_count = mmproj_tensor_byte_count(kind, dims)
            if name in self.tensors:
                raise Error("mmproj: duplicate tensor " + name)
            var elements = 1
            for i in range(len(dims)):
                elements *= dims[i]
            var tensor = MmprojTensor(
                relative, kind, byte_count, elements, rank,
                dims[0],
                dims[1] if rank >= 2 else 1,
                dims[2] if rank >= 3 else 1,
                dims[3] if rank >= 4 else 1,
            )
            self.tensors[name] = tensor
            names.append(name)
        self.data_offset = (cursor + alignment - 1) // alignment * alignment
        for i in range(len(names)):
            var tensor = self.tensors[names[i]]
            self.source._require_range(self.data_offset, tensor.offset)
            tensor.offset += self.data_offset
            self.source._require_range(tensor.offset, tensor.byte_count)
            self.tensors[names[i]] = tensor
        for i in range(len(names)):
            var a = self.tensors[names[i]]
            for j in range(i):
                var b = self.tensors[names[j]]
                if a.offset < b.offset + b.byte_count and b.offset < a.offset + a.byte_count:
                    raise Error("mmproj: overlapping tensors")

    # -- metadata accessors -------------------------------------------------

    def integer(self, key: String, default: Int = -1) raises -> Int:
        if key not in self.fields:
            if default >= 0:
                return default
            raise Error("mmproj: missing metadata " + key)
        var kind = self.field_types[key]
        var offset = self.fields[key]
        if kind == 4:
            return Int(self.source._read_u32(offset))
        if kind == 5:
            var signed32 = self.source._read_i32(offset)
            if signed32 < 0:
                raise Error("mmproj: negative integer " + key)
            return Int(signed32)
        if kind == 7:
            return Int(self.source.mmap_ptr.unsafe_load(offset))
        if kind == 10:
            var unsigned64 = self.source._read_u64(offset)
            if unsigned64 > UInt64(9223372036854775807):
                raise Error("mmproj: integer exceeds native range " + key)
            return Int(unsigned64)
        if kind == 11:
            var signed64 = Int64(self.source._read_u64(offset))
            if signed64 < 0:
                raise Error("mmproj: negative integer " + key)
            return Int(signed64)
        raise Error("mmproj: expected integer/bool " + key + "; type=" + String(kind))

    def floating(self, key: String) raises -> Float32:
        if self.field_types.get(key, -1) != 6:
            raise Error("mmproj: expected float " + key)
        return self.source._read_f32(self.fields[key])

    def text(self, key: String) raises -> String:
        if self.field_types.get(key, -1) != 8:
            raise Error("mmproj: expected string " + key)
        return self.source._read_string(self.fields[key])

    def float_array(self, key: String) raises -> List[Float32]:
        if self.field_types.get(key, -1) != 9:
            raise Error("mmproj: expected array " + key)
        var offset = self.fields[key]
        if Int(self.source._read_u32(offset)) != 6:
            raise Error("mmproj: expected float32 array " + key)
        var count = Int(self.source._read_u64(offset + 4))
        if count < 0 or count > 4096:
            raise Error("mmproj: float array length out of range " + key)
        var values = List[Float32]()
        var cursor = offset + 12
        for _ in range(count):
            values.append(self.source._read_f32(cursor))
            cursor += 4
        return values^

    def tensor_f32(self, name: String) raises -> List[Float32]:
        """Copies an F32 tensor's elements out of the mapping, in file order."""
        if name not in self.tensors:
            raise Error("mmproj: missing tensor " + name)
        var tensor = self.tensors[name]
        if tensor.kind != 0:
            raise Error("mmproj: tensor is not F32: " + name)
        var values = List[Float32]()
        values.reserve(tensor.elements)
        for i in range(tensor.elements):
            values.append(self.source._read_f32(tensor.offset + 4 * i))
        return values^

    def has_tensor(self, name: String) -> Bool:
        return name in self.tensors

    def tensor_count_with_prefix(self, prefix: String) -> Int:
        var count = 0
        for entry in self.tensors.items():
            if entry.key.startswith(prefix):
                count += 1
        return count

    def total_tensor_bytes(self) -> Int:
        var total = 0
        for entry in self.tensors.items():
            total += entry.value.byte_count
        return total

    # -- vision tower validation ---------------------------------------------

    def _require_tensor(
        self, name: String, dims: List[Int]
    ) raises -> MmprojTensor:
        if name not in self.tensors:
            raise Error("mmproj: missing required vision tensor " + name)
        var tensor = self.tensors[name]
        var actual = tensor.dims()
        if len(actual) != len(dims):
            raise Error("mmproj: vision tensor rank mismatch: " + name)
        for i in range(len(dims)):
            if actual[i] != dims[i]:
                raise Error(
                    "mmproj: vision tensor shape mismatch: " + name
                    + " dim " + String(i) + " is " + String(actual[i])
                    + ", expected " + String(dims[i])
                )
        return tensor

    def vision_spec(self) raises -> VisionTowerSpec:
        """Extracts and validates the vision tower spec from this inventory."""
        var architecture = self.text("general.architecture")
        if architecture != "clip":
            raise Error("mmproj: architecture is '" + architecture + "', not 'clip'")
        var spec = VisionTowerSpec()
        spec.audio_present = self.integer("clip.has_audio_encoder", 0) == 1
        if self.integer("clip.has_vision_encoder", 0) != 1:
            return spec^
        spec.present = True
        # The canonical GGUF key is clip.projector_type; the gemma
        # converter additionally writes it under clip.vision.*.
        try:
            spec.projector_type = self.text("clip.projector_type")
        except:
            spec.projector_type = self.text("clip.vision.projector_type")
        spec.projection_dim = self.integer("clip.vision.projection_dim")
        spec.image_size = self.integer("clip.vision.image_size")
        spec.patch_size = self.integer("clip.vision.patch_size")
        spec.embedding_length = self.integer("clip.vision.embedding_length")
        spec.feed_forward_length = self.integer("clip.vision.feed_forward_length")
        spec.block_count = self.integer("clip.vision.block_count")
        spec.head_count = self.integer("clip.vision.attention.head_count")
        spec.layer_norm_epsilon = self.floating(
            "clip.vision.attention.layer_norm_epsilon"
        )
        spec.image_mean = self.float_array("clip.vision.image_mean")
        spec.image_std = self.float_array("clip.vision.image_std")
        if (
            spec.projection_dim <= 0 or spec.image_size <= 0
            or spec.patch_size <= 0 or spec.embedding_length <= 0
            or spec.feed_forward_length <= 0 or spec.block_count <= 0
            or spec.head_count <= 0
        ):
            raise Error("mmproj: vision geometry metadata is incomplete")
        if spec.image_size % spec.patch_size != 0:
            raise Error("mmproj: image_size is not divisible by patch_size")
        if spec.embedding_length % spec.head_count != 0:
            raise Error("mmproj: vision embedding is not divisible by head count")
        if len(spec.image_mean) != 3 or len(spec.image_std) != 3:
            raise Error("mmproj: image mean/std must have exactly 3 channels")

        var hidden = spec.embedding_length
        var ffn = spec.feed_forward_length
        var head_dim = spec.head_dim()
        if "mm.input_projection.weight" in self.tensors:
            # Gemma-family tower: single clippable projection, FPE
            # position table, per-head Q/K norms, block post-norms.
            _ = self._require_tensor(
                "mm.input_projection.weight",
                [hidden, spec.projection_dim],
            )
            _ = self._require_tensor(
                "v.patch_embd.weight",
                [spec.patch_size, spec.patch_size, 3, hidden],
            )
            if "v.position_embd.weight" not in self.tensors:
                raise Error("mmproj: missing required vision tensor v.position_embd.weight")
            if self.tensors["v.position_embd.weight"].rank != 3:
                raise Error("mmproj: v.position_embd.weight must be rank 3")
            for block in range(spec.block_count):
                var prefix = "v.blk." + String(block) + "."
                _ = self._require_tensor(prefix + "ln1.weight", [hidden])
                _ = self._require_tensor(prefix + "ln2.weight", [hidden])
                _ = self._require_tensor(prefix + "attn_q.weight", [hidden, hidden])
                _ = self._require_tensor(prefix + "attn_k.weight", [hidden, hidden])
                _ = self._require_tensor(prefix + "attn_v.weight", [hidden, hidden])
                _ = self._require_tensor(prefix + "attn_out.weight", [hidden, hidden])
                _ = self._require_tensor(prefix + "attn_q_norm.weight", [head_dim])
                _ = self._require_tensor(prefix + "attn_k_norm.weight", [head_dim])
                _ = self._require_tensor(prefix + "attn_post_norm.weight", [hidden])
                _ = self._require_tensor(prefix + "ffn_post_norm.weight", [hidden])
                _ = self._require_tensor(prefix + "ffn_gate.weight", [hidden, ffn])
                _ = self._require_tensor(prefix + "ffn_up.weight", [hidden, ffn])
                _ = self._require_tensor(prefix + "ffn_down.weight", [ffn, hidden])
        elif spec.projector_type == "pixtral":
            # Pixtral tower: 2D-RoPE positions (no table), plain
            # blocks, patch merger + two-layer MLP projector.
            _ = self._require_tensor(
                "v.patch_embd.weight",
                [spec.patch_size, spec.patch_size, 3, hidden],
            )
            _ = self._require_tensor("v.pre_ln.weight", [hidden])
            for block in range(spec.block_count):
                var prefix = "v.blk." + String(block) + "."
                _ = self._require_tensor(prefix + "ln1.weight", [hidden])
                _ = self._require_tensor(prefix + "ln2.weight", [hidden])
                _ = self._require_tensor(prefix + "attn_q.weight", [hidden, hidden])
                _ = self._require_tensor(prefix + "attn_k.weight", [hidden, hidden])
                _ = self._require_tensor(prefix + "attn_v.weight", [hidden, hidden])
                _ = self._require_tensor(prefix + "attn_out.weight", [hidden, hidden])
                _ = self._require_tensor(prefix + "ffn_gate.weight", [hidden, ffn])
                _ = self._require_tensor(prefix + "ffn_up.weight", [hidden, ffn])
                _ = self._require_tensor(prefix + "ffn_down.weight", [ffn, hidden])
            var merge = self.integer("clip.vision.spatial_merge_size", 1)
            _ = self._require_tensor("mm.input_norm.weight", [hidden])
            _ = self._require_tensor(
                "mm.patch_merger.weight", [hidden * merge * merge, hidden]
            )
            _ = self._require_tensor(
                "mm.1.weight", [hidden, spec.projection_dim]
            )
            _ = self._require_tensor(
                "mm.2.weight", [spec.projection_dim, spec.projection_dim]
            )
        else:
            raise Error(
                "mmproj: unsupported projector family '"
                + spec.projector_type + "'"
            )
        return spec^

    # -- reporting ------------------------------------------------------------

    def describe(self, spec: VisionTowerSpec) -> String:
        var out = String("")
        out += "mmproj: " + self.path + "\n"
        out += "file bytes: " + String(Int(self.source.file_size)) + "\n"
        out += "metadata entries: " + String(self.source.kv_count) + "\n"
        out += "tensors: " + String(len(self.tensors)) + " ("
        out += String(self.total_tensor_bytes()) + " tensor bytes)\n"
        out += "vision tensors: " + String(self.tensor_count_with_prefix("v.")) + "\n"
        out += "audio tensors: " + String(self.tensor_count_with_prefix("a.")) + "\n"
        if spec.present:
            out += "vision tower: present (projector " + spec.projector_type + ")\n"
            out += "  image: " + String(spec.image_size) + "x" + String(spec.image_size)
            out += ", patch " + String(spec.patch_size)
            out += " -> " + String(spec.patch_count()) + " patches\n"
            out += "  embedding: " + String(spec.embedding_length)
            out += ", feed-forward: " + String(spec.feed_forward_length)
            out += ", blocks: " + String(spec.block_count)
            out += ", heads: " + String(spec.head_count)
            out += " (head_dim " + String(spec.head_dim()) + ")\n"
            if "mm.input_projection.weight" in self.tensors:
                out += "  projector: mm.input_projection.weight ["
            elif spec.projector_type == "pixtral":
                out += "  projector: mm.patch_merger + mm.1/mm.2 MLP ["
            else:
                out += "  projector: ["
            out += String(spec.embedding_length) + " -> "
            out += String(spec.projection_dim) + "]\n"
        else:
            out += "vision tower: absent\n"
        if spec.audio_present:
            out += "audio tower: present (inventoried, not interpreted)\n"
        return out
    def tensor_q8_0_f32(self, name: String) raises -> List[Float32]:
        """Dequantizes a Q8_0 tensor to F32 values, in file order.

        Q8_0 tiles the element stream in blocks of 32 along the innermost
        dimension: each block is an F16 scale followed by 32 signed int8
        codes, and each value is scale * code. The returned list uses the
        same linear file order as ``tensor_f32``.
        """
        if name not in self.tensors:
            raise Error("mmproj: missing tensor " + name)
        var tensor = self.tensors[name]
        if tensor.kind != 8:
            raise Error("mmproj: tensor is not Q8_0: " + name)
        if tensor.elements % 32 != 0:
            raise Error(
                "mmproj: Q8_0 tensor element count is not block aligned: " + name
            )
        var values = List[Float32]()
        values.reserve(tensor.elements)
        var blocks = tensor.elements // 32
        for b in range(blocks):
            var block_offset = tensor.offset + b * 34
            var scale = _f16_to_f32(self.source._read_u16(block_offset))
            for j in range(32):
                var code = Int(
                    self.source.mmap_ptr.unsafe_load(block_offset + 2 + j)
                )
                if code >= 128:
                    code -= 256
                values.append(scale * Float32(code))
        return values^

    def tensor_scalar_f32(self, name: String) raises -> Float32:
        """Reads a single-element F32 tensor (a calibration scalar)."""
        if name not in self.tensors:
            raise Error("mmproj: missing tensor " + name)
        var tensor = self.tensors[name]
        if tensor.kind != 0 or tensor.elements != 1:
            raise Error("mmproj: tensor is not an F32 scalar: " + name)
        return self.source._read_f32(tensor.offset)


def _f16_to_f32(bits: UInt16) raises -> Float32:
    """Converts IEEE-754 half-precision bits to a Float32 value.

    Exact for every finite half (the conversion is a widening). Non-finite
    halves raise: a Q8_0 scale is a measured calibration value, and an
    infinite or NaN scale in a real file is corruption, not data.
    """
    var sign = Float32(-1.0) if (bits >> 15) != 0 else Float32(1.0)
    var exponent = Int((bits >> 10) & 31)
    var fraction = Int(bits & 1023)
    if exponent == 31:
        raise Error("mmproj: non-finite F16 value in tensor data")
    if exponent == 0:
        # Subnormal (or zero): fraction * 2^-24.
        return sign * Float32(fraction) * Float32(5.960464477539063e-08)
    var mantissa = Float32(1.0) + Float32(fraction) / Float32(1024.0)
    var power = Float32(1.0)
    var e = exponent - 15
    while e > 0:
        power *= Float32(2.0)
        e -= 1
    while e < 0:
        power /= Float32(2.0)
        e += 1
    return sign * mantissa * power
