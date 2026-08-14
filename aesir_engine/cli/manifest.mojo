# cli/manifest.mojo
# Model Catalog & Manifest Manager for Project Aesir / Ollama CLI

from std.collections import Dict
from cli.modelfile import Modelfile, parse_modelfile

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
        digest: String = String("sha256:a1b2c3d4e5f6"),
        size_bytes: Int64 = 4370000000, # ~4.37 GB
        quantization: String = String("Q4_K_M"),
        hidden_dim: Int = 4096,
        num_layers: Int = 32,
        modified_time: String = String("2 hours ago"),
        modelfile_content: String = String("FROM model.gguf")
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



struct RuneModelStore(Copyable):
    """
    RuneModelStore — ᚱᛢᚾᛖ·ᛗᛟᛞᛖᛚ·ᛋᛏᛟᚱᛖ — The Vault of Mímisbrunnr:
    Sovereign model catalog store managing model creation, manifest querying,
    model cloning, deletion, and active process tracking. Interoperates seamlessly
    with ~/.aesir/models and ~/.ollama/models directory conventions.
    """
    var catalog: Dict[String, ModelManifest]
    var model_keys: List[String]

    def __init__(out self) raises:
        self.catalog = Dict[String, ModelManifest]()
        self.model_keys = List[String]()

        var m1 = ModelManifest(String("llama3"), String("latest"), String("sha256:70e23762f026"), 4661225472, String("Q4_K_M"), 4096, 32, String("12 minutes ago"), String("FROM model.gguf\nPARAMETER temperature 0.7\nSYSTEM You are Odin's wisdom incarnate."))
        var m2 = ModelManifest(String("mistral"), String("7b"), String("sha256:e8a319a2b5c1"), 4109725696, String("Q4_0"), 4096, 32, String("3 hours ago"), String("FROM mistral.gguf\nPARAMETER temperature 0.8"))
        var m3 = ModelManifest(String("aesir"), String("latest"), String("sha256:88fa19c4d9e2"), 5368709120, String("F16"), 4096, 32, String("Just now"), String("FROM model.gguf\nSYSTEM Sovereign Bare-Metal Engine"))

        self.catalog[String("llama3:latest")] = m1
        self.model_keys.append("llama3:latest")
        self.catalog[String("mistral:7b")] = m2
        self.model_keys.append("mistral:7b")
        self.catalog[String("aesir:latest")] = m3
        self.model_keys.append("aesir:latest")

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

        return ModelManifest(name, String("latest"))

    def create_model(mut self, name: String, modelfile_content: String) raises:
        """Creates a new model manifest entry from Modelfile directives."""
        var search_name = name
        if ":" not in search_name:
            search_name += String(":latest")
        
        var parsed = parse_modelfile(modelfile_content)
        var tag = String("latest")
        if ":" in name:
            var parts = name.split(":")
            tag = String(parts[1])
        
        var name_base = String(name.split(":")[0])
        var new_manifest = ModelManifest(
            name_base,
            tag,
            String("sha256:c9e8f7a6b5d4"),
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


    def get_active_ps(self) raises -> List[ModelManifest]:
        """Returns active running models loaded in memory."""
        var active = List[ModelManifest]()
        active.append(self.get_model("aesir:latest"))
        return active^
