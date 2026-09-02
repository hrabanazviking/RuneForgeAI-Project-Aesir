# cli/manifest.mojo
# Model Catalog & Manifest Manager for Project Aesir / Ollama CLI

from std.collections import Dict
from cli.modelfile import parse_modelfile


def validate_model_component(component: String, label: String) raises:
    """Rejects empty, oversized, or path-shaped model identity components."""
    var value = String(component)
    var raw = value.as_bytes()
    if len(raw) == 0:
        raise Error("model " + label + " must not be empty")
    if len(raw) > 128:
        raise Error("model " + label + " exceeds 128 bytes")
    for index in range(len(raw)):
        var code = Int(raw[index])
        var allowed = (
            (code >= 48 and code <= 57)
            or (code >= 65 and code <= 90)
            or (code >= 97 and code <= 122)
            or code == 45
            or code == 46
            or code == 95
        )
        if not allowed:
            raise Error(
                "model " + label
                + " may contain only letters, digits, '.', '-', and '_'"
            )
    if value == "." or value == "..":
        raise Error("model " + label + " must not be a path segment")


def normalize_model_reference(reference: String) raises -> String:
    """Returns a validated `name:tag` reference, defaulting to `latest`."""
    var parts = reference.split(":")
    if len(parts) > 2:
        raise Error("model reference must contain at most one ':' separator")
    var name = String(parts[0])
    var tag = String("latest")
    if len(parts) == 2:
        tag = String(parts[1])
    validate_model_component(name, "name")
    validate_model_component(tag, "tag")
    return name + ":" + tag


def _parse_nonnegative_manifest_int(value: String, label: String) raises -> Int:
    var clean = String(value.strip())
    var source = clean.as_bytes()
    if len(source) == 0:
        raise Error("manifest " + label + " field must not be empty")
    for index in range(len(source)):
        if source[index] < 48 or source[index] > 57:
            raise Error("manifest " + label + " field must be decimal")
    var parsed: Int
    try:
        parsed = atol(clean)
    except:
        raise Error("manifest " + label + " field is outside the supported range")
    if parsed < 0:
        raise Error("manifest " + label + " field must not be negative")
    return parsed


@always_inline
def compute_modelfile_fingerprint(content: String) -> String:
    """Computes a deterministic non-cryptographic FNV-1a 64-bit fingerprint."""
    var bytes = content.as_bytes()
    var h: UInt64 = 14695981039346656037
    for i in range(len(bytes)):
        h = (h ^ UInt64(bytes[i])) * 1099511628211
    
    var hex_chars = String("0123456789abcdef")
    var res = String("fnv1a64:")
    for shift in range(60, -4, -4):
        var nibble = Int((h >> UInt64(shift)) & 0xF)
        res += String(hex_chars[byte=nibble : nibble + 1])
    return res


def validate_manifest_storage_identity(
    digest: String, size_bytes: Int64
) raises:
    """Couples each supported manifest identity scheme to its byte semantics."""
    if size_bytes < 0:
        raise Error("manifest size must not be negative")
    var prefix_bytes: Int
    var expected_digits: Int
    if digest.startswith("fnv1a64:"):
        prefix_bytes = 8
        expected_digits = 16
        if size_bytes != 0:
            raise Error("recipe fingerprint requires an unknown zero byte size")
    elif digest.startswith("sha256:"):
        prefix_bytes = 7
        expected_digits = 64
        if size_bytes <= 0:
            raise Error("SHA-256 blob identity requires a positive byte size")
    else:
        raise Error("manifest digest uses an unsupported identity scheme")
    var digits = String(digest[byte=prefix_bytes:])
    if len(digits.bytes()) != expected_digits:
        raise Error("manifest digest has the wrong hexadecimal width")
    for byte in digits.as_bytes():
        if not (
            (byte >= 48 and byte <= 57) or (byte >= 97 and byte <= 102)
        ):
            raise Error("manifest digest must use lowercase hexadecimal")


struct ModelManifest(Copyable, ImplicitlyCopyable):
    """
    ModelManifest — ᛗᛟᛞᛖᛚ·ᛗᚨᚾᛁᚠᛖᛋᛏ — The Scroll of the Model:
    Preserves model metadata scroll: model name, tag, content fingerprint,
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
    """Strictly deserializes the complete ModelManifest text schema."""
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
    var seen_name = False
    var seen_tag = False
    var seen_digest = False
    var seen_size = False
    var seen_quantization = False
    var seen_hidden_dim = False
    var seen_num_layers = False
    var seen_modified = False
    var seen_modelfile = False

    for i in range(len(lines)):
        var line = String(lines[i])
        if in_modelfile:
            modelfile_lines.append(line)
            continue

        if line.startswith("NAME:"):
            if seen_name:
                raise Error("manifest contains duplicate NAME field")
            seen_name = True
            name = String(line.replace("NAME:", "").strip())
        elif line.startswith("TAG:"):
            if seen_tag:
                raise Error("manifest contains duplicate TAG field")
            seen_tag = True
            tag = String(line.replace("TAG:", "").strip())
        elif line.startswith("DIGEST:"):
            if seen_digest:
                raise Error("manifest contains duplicate DIGEST field")
            seen_digest = True
            digest = String(line.replace("DIGEST:", "").strip())
        elif line.startswith("SIZE:"):
            if seen_size:
                raise Error("manifest contains duplicate SIZE field")
            seen_size = True
            size_bytes = Int64(
                _parse_nonnegative_manifest_int(
                    String(line[byte=5:]), "SIZE"
                )
            )
        elif line.startswith("QUANT:"):
            if seen_quantization:
                raise Error("manifest contains duplicate QUANT field")
            seen_quantization = True
            quantization = String(line.replace("QUANT:", "").strip())
        elif line.startswith("HIDDEN_DIM:"):
            if seen_hidden_dim:
                raise Error("manifest contains duplicate HIDDEN_DIM field")
            seen_hidden_dim = True
            hidden_dim = _parse_nonnegative_manifest_int(
                String(line[byte=11:]), "HIDDEN_DIM"
            )
        elif line.startswith("NUM_LAYERS:"):
            if seen_num_layers:
                raise Error("manifest contains duplicate NUM_LAYERS field")
            seen_num_layers = True
            num_layers = _parse_nonnegative_manifest_int(
                String(line[byte=11:]), "NUM_LAYERS"
            )
        elif line.startswith("MODIFIED:"):
            if seen_modified:
                raise Error("manifest contains duplicate MODIFIED field")
            seen_modified = True
            modified_time = String(line.replace("MODIFIED:", "").strip())
        elif line == "MODELFILE:":
            if seen_modelfile:
                raise Error("manifest contains duplicate MODELFILE field")
            seen_modelfile = True
            in_modelfile = True
        else:
            raise Error("manifest contains an unknown or malformed field")

    if not (
        seen_name
        and seen_tag
        and seen_digest
        and seen_size
        and seen_quantization
        and seen_hidden_dim
        and seen_num_layers
        and seen_modified
        and seen_modelfile
    ):
        raise Error("manifest is missing one or more required fields")
    validate_model_component(name, "name")
    validate_model_component(tag, "tag")
    if len(digest.bytes()) == 0:
        raise Error("manifest digest must not be empty")
    validate_manifest_storage_identity(digest, size_bytes)

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
    Model catalog supporting in-memory operations and text serialization.
    It performs no durable file I/O.
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
        var search_name = normalize_model_reference(name)
        
        if search_name in self.catalog:
            return self.catalog[search_name].copy()
        
        raise Error("model manifest not found: " + name)

    def create_model(mut self, name: String, modelfile_content: String) raises:
        """Creates an in-memory manifest without inventing unobserved model metadata."""
        var search_name = normalize_model_reference(name)
        
        _ = parse_modelfile(modelfile_content)
        var parts = search_name.split(":")
        var tag = String(parts[1])
        
        var fingerprint = compute_modelfile_fingerprint(modelfile_content)
        var name_base = String(parts[0])
        var new_manifest = ModelManifest(
            name_base,
            tag,
            fingerprint,
            0,
            String("unknown"),
            0,
            0,
            String("unknown"),
            modelfile_content
        )
        self.catalog[search_name] = new_manifest
        if search_name not in self.model_keys:
            self.model_keys.append(search_name)

    def create_model_from_blob(
        mut self,
        name: String,
        modelfile_content: String,
        digest: String,
        size_bytes: Int64,
    ) raises:
        """Creates a manifest from measured immutable model bytes."""
        if not digest.startswith("sha256:") or len(digest.bytes()) != 71:
            raise Error("model blob digest must use sha256:<64 lowercase hex>")
        for byte in String(digest[byte=7:]).as_bytes():
            if not (
                (byte >= 48 and byte <= 57)
                or (byte >= 97 and byte <= 102)
            ):
                raise Error("model blob digest must be lowercase hexadecimal")
        if size_bytes <= 0:
            raise Error("model blob size must be positive")
        var search_name = normalize_model_reference(name)
        self.create_model(search_name, modelfile_content)
        var manifest = self.catalog[search_name].copy()
        manifest.digest = digest
        manifest.size_bytes = size_bytes
        self.catalog[search_name] = manifest

    def copy_model(mut self, source: String, target: String) raises:
        """Copies an existing model manifest to a new name/tag."""
        var source_name = normalize_model_reference(source)
        var target_name = normalize_model_reference(target)
        var src_manifest = self.get_model(source_name)
        
        var copied = src_manifest.copy()
        var parts = target_name.split(":")
        copied.name = String(parts[0])
        copied.tag = String(parts[1])
        self.catalog[target_name] = copied.copy()
        if target_name not in self.model_keys:
            self.model_keys.append(target_name)

    def remove_model(mut self, name: String) raises -> Bool:
        """Removes a model manifest from the store."""
        var search_name = normalize_model_reference(name)
        
        if search_name in self.catalog:
            _ = self.catalog.pop(search_name)
            var new_keys = List[String]()
            for i in range(len(self.model_keys)):
                if self.model_keys[i] != search_name:
                    new_keys.append(self.model_keys[i])
            self.model_keys = new_keys^
            return True
        return False

    def remove_model_checked(mut self, name: String, active_model: String = String("")) raises:
        """Removes model manifest with model-in-use and not-found exception guards."""
        var search_name = name
        if ":" not in search_name:
            search_name += String(":latest")

        var active_search = active_model
        if len(active_search.bytes()) > 0 and ":" not in active_search:
            active_search += String(":latest")

        if len(active_search.bytes()) > 0 and search_name == active_search:
            raise Error("cannot remove model currently in use: " + name)

        if search_name not in self.catalog:
            raise Error("model manifest not found: " + name)

        _ = self.remove_model(search_name)

    def serialize_store(self) raises -> String:
        """Serializes the in-memory model store to caller-owned text."""
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
                if key not in self.model_keys:
                    self.model_keys.append(key)

    def get_active_ps(self) raises -> List[ModelManifest]:
        """Returns no processes until runtime process tracking is implemented."""
        var active = List[ModelManifest]()
        return active^
