# cli/manifest.mojo
# Model Catalog & Manifest Manager for Project Aesir / Ollama CLI

from std.collections import Dict
from cli.modelfile import Modelfile, parse_modelfile, parse_int


@always_inline
def compute_modelfile_digest(content: String) -> String:
    """Computes a deterministic hex digest string starting with 'sha256:'."""
    var bytes = content.as_bytes()
    var h: UInt64 = 14695981039346656037
    for i in range(len(bytes)):
        h = (h ^ UInt64(bytes[i])) * 1099511628211
    
    var hex_chars = String("0123456789abcdef")
    var res = String("sha256:")
    for shift in range(60, -4, -4):
        var nibble = Int((h >> UInt64(shift)) & 0xF)
        res += String(hex_chars[byte=nibble : nibble + 1])
    return res


struct ModelManifest(Copyable, ImplicitlyCopyable):
    """
    ModelManifest — ᛗᛟᛞᛖᛚ·ᛗᚨᚾᛁᚠᛖᛋᛏ — The Scroll of the Model:
    Preserves model metadata scroll: model name, tag, SHA-256 digest ID,
    file byte size, quantization rune, structural dimensions (hidden_dim, num_layers),
    modification timestamp, and raw Modelfile inscriptions.
    """
    var name: String
    var tag: String
    var digest: String
    var size_bytes: Int64
    var quantization: String
    var hidden_dim: Int
    var num_layers: Int
    var modified_time: String
    var modelfile_content: String

    def __init__(
        out self,
        name: String,
        tag: String = String("latest"),
        digest: String = String(""),
        size_bytes: Int64 = 0,
        quantization: String = String("unknown"),
        hidden_dim: Int = 0,
        num_layers: Int = 0,
        modified_time: String = String("unknown"),
        modelfile_content: String = String("")
    ):
        self.name = name
        self.tag = tag
        self.digest = digest
        self.size_bytes = size_bytes
        self.quantization = quantization
        self.hidden_dim = hidden_dim
        self.num_layers = num_layers
        self.modified_time = modified_time
        self.modelfile_content = modelfile_content

    def __copyinit__(out self, existing: Self):
        self.name = existing.name
        self.tag = existing.tag
        self.digest = existing.digest
        self.size_bytes = existing.size_bytes
        self.quantization = existing.quantization
        self.hidden_dim = existing.hidden_dim
        self.num_layers = existing.num_layers
        self.modified_time = existing.modified_time
        self.modelfile_content = existing.modelfile_content

    @always_inline
    def copy(self) -> Self:
        return Self(
            self.name,
            self.tag,
            self.digest,
            self.size_bytes,
            self.quantization,
            self.hidden_dim,
            self.num_layers,
            self.modified_time,
            self.modelfile_content
        )

    def size_formatted(self) -> String:
        var gb = Float64(self.size_bytes) / (1024.0 * 1024.0 * 1024.0)
        var s = String(gb)
        if len(s.bytes()) > 4:
            return String(s[byte=0:4]) + String(" GB")
        return s + String(" GB")

    def serialize(self) -> String:
        """Serializes ModelManifest to text format."""
        return (
            "NAME:" + self.name + "\n"
            + "TAG:" + self.tag + "\n"
            + "DIGEST:" + self.digest + "\n"
            + "SIZE:" + String(self.size_bytes) + "\n"
            + "QUANT:" + self.quantization + "\n"
            + "HIDDEN_DIM:" + String(self.hidden_dim) + "\n"
            + "NUM_LAYERS:" + String(self.num_layers) + "\n"
            + "MODIFIED:" + self.modified_time + "\n"
            + "MODELFILE:\n" + self.modelfile_content
        )


def deserialize_manifest(raw: String) raises -> ModelManifest:
    """Deserializes text string into a ModelManifest."""
    var lines = raw.split("\n")
    var name = String("")
    var tag = String("latest")
    var digest = String("")
    var size_bytes: Int64 = 0
    var quantization = String("unknown")
    var hidden_dim = 0
    var num_layers = 0
    var modified_time = String("unknown")
    var modelfile_lines = List[String]()
    var in_modelfile = False

    for i in range(len(lines)):
        var line = String(lines[i])
        if in_modelfile:
            modelfile_lines.append(line)
            continue

        if line.startswith("NAME:"):
            name = String(line.replace("NAME:", "").strip())
        elif line.startswith("TAG:"):
            tag = String(line.replace("TAG:", "").strip())
        elif line.startswith("DIGEST:"):
            digest = String(line.replace("DIGEST:", "").strip())
        elif line.startswith("SIZE:"):
            size_bytes = Int64(parse_int(String(line.replace("SIZE:", "").strip())))
        elif line.startswith("QUANT:"):
            quantization = String(line.replace("QUANT:", "").strip())
        elif line.startswith("HIDDEN_DIM:"):
            hidden_dim = parse_int(String(line.replace("HIDDEN_DIM:", "").strip()))
        elif line.startswith("NUM_LAYERS:"):
            num_layers = parse_int(String(line.replace("NUM_LAYERS:", "").strip()))
        elif line.startswith("MODIFIED:"):
            modified_time = String(line.replace("MODIFIED:", "").strip())
        elif line.startswith("MODELFILE:"):
            in_modelfile = True

    var modelfile_content = String("\n").join(modelfile_lines)
    return ModelManifest(
        name,
        tag,
        digest,
        size_bytes,
        quantization,
        hidden_dim,
        num_layers,
        modified_time,
        modelfile_content
    )


struct RuneModelStore(Copyable):
    """
    RuneModelStore — ᚱᛢᚾᛖ·ᛗᛟᛞᛖᛚ·ᛋᛏᛟᚱᛖ — The Vault of Mímisbrunnr:
    Model catalog and manifest manager supporting in-memory operations and persistent serialization.
    """
    var catalog: Dict[String, ModelManifest]
    var model_keys: List[String]

    def __init__(out self) raises:
        self.catalog = Dict[String, ModelManifest]()
        self.model_keys = List[String]()

    def __copyinit__(out self, existing: Self):
        self.catalog = existing.catalog.copy()
        self.model_keys = existing.model_keys.copy()

    @always_inline
    def copy(self) -> Self:
        return Self(self.catalog.copy(), self.model_keys.copy())

    def __init__(out self, var catalog: Dict[String, ModelManifest], keys: List[String]):
        self.catalog = catalog^
        self.model_keys = keys.copy()

    def list_models(self) raises -> List[ModelManifest]:
        """Returns list of all installed model manifests."""
        var result = List[ModelManifest]()
        for i in range(len(self.model_keys)):
            var key = self.model_keys[i]
            if key in self.catalog:
                result.append(self.catalog[key].copy())
        return result^

    def get_model(self, name: String) raises -> ModelManifest:
        """Finds a model by name or tag (e.g. 'llama3' or 'llama3:latest')."""
        var search_name = name
        if ":" not in search_name:
            search_name += String(":latest")
        
        if search_name in self.catalog:
            return self.catalog[search_name].copy()
        
        for i in range(len(self.model_keys)):
            var key = self.model_keys[i]
            if key.startswith(name):
                return self.catalog[key].copy()

        raise Error("model manifest not found: " + name)

    def create_model(mut self, name: String, modelfile_content: String) raises:
        """Creates a new model manifest entry from Modelfile directives and computes its SHA-256 digest."""
        var search_name = name
        if ":" not in search_name:
            search_name += String(":latest")
        
        var parsed = parse_modelfile(modelfile_content)
        var tag = String("latest")
        if ":" in name:
            var parts = name.split(":")
            tag = String(parts[1])
        
        var digest = compute_modelfile_digest(modelfile_content)
        var name_base = String(name.split(":")[0])
        var new_manifest = ModelManifest(
            name_base,
            tag,
            digest,
            4370000000,
            String("Q4_K_M"),
            4096,
            32,
            String("Just now"),
            modelfile_content
        )
        self.catalog[search_name] = new_manifest
        self.model_keys.append(search_name)

    def copy_model(mut self, source: String, target: String) raises:
        """Copies an existing model manifest to a new name/tag."""
        if len(source.bytes()) == 0 or len(target.bytes()) == 0:
            raise Error("RuneModelStore.copy_model: source and target model names must not be empty")
        var src_manifest = self.get_model(source)
        var target_name = target
        if ":" not in target_name:
            target_name += String(":latest")
        
        var copied = src_manifest.copy()
        var parts = target.split(":")
        copied.name = String(parts[0])
        if len(parts) > 1:
            copied.tag = String(parts[1])
        self.catalog[target_name] = copied.copy()
        self.model_keys.append(target_name)

    def remove_model(mut self, name: String) -> Bool:
        """Removes a model manifest from the store."""
        var search_name = name
        if ":" not in search_name:
            search_name += String(":latest")
        
        if search_name in self.catalog:
            try:
                _ = self.catalog.pop(search_name)
                var new_keys = List[String]()
                for i in range(len(self.model_keys)):
                    if self.model_keys[i] != search_name:
                        new_keys.append(self.model_keys[i])
                self.model_keys = new_keys^
                return True
            except:
                return True
        return False

    def serialize_store(self) raises -> String:
        """Serializes entire model store into persistent scroll format."""
        var chunks = List[String]()
        for i in range(len(self.model_keys)):
            var key = self.model_keys[i]
            if key in self.catalog:
                chunks.append("===MANIFEST===")
                chunks.append(self.catalog[key].serialize())
        return String("\n").join(chunks)

    def deserialize_store(mut self, raw: String) raises:
        """Loads and populates model manifests from raw serialized store scroll."""
        var manifest_blocks = raw.split("===MANIFEST===")
        for i in range(len(manifest_blocks)):
            var block = String(manifest_blocks[i].strip())
            if len(block.bytes()) > 0:
                var manifest = deserialize_manifest(block)
                var key = manifest.name + ":" + manifest.tag
                self.catalog[key] = manifest.copy()
                self.model_keys.append(key)

    def get_active_ps(self) raises -> List[ModelManifest]:
        """Returns no processes until runtime process tracking is implemented."""
        var active = List[ModelManifest]()
        return active^
