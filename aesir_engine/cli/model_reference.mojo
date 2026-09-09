"""One verified route from CLI model references to executable GGUF paths."""
from std.ffi import external_call
from cli.storage import DurableModelStore
from cli.manifest import normalize_model_reference


struct ResolvedModelReference(Copyable):
    var requested: String
    var path: String
    var catalog_name: String
    var digest: String
    var size_bytes: Int64
    var modelfile_content: String
    var from_catalog: Bool

    def __init__(out self, requested: String, path: String,
                 catalog_name: String = "", digest: String = "",
                 size_bytes: Int64 = 0, modelfile_content: String = "",
                 from_catalog: Bool = False):
        self.requested = requested
        self.path = path
        self.catalog_name = catalog_name
        self.digest = digest
        self.size_bytes = size_bytes
        self.modelfile_content = modelfile_content
        self.from_catalog = from_catalog


def _reference_cstring(value: String) -> List[Int8]:
    var output = List[Int8]()
    for byte in value.as_bytes():
        output.append(Int8(byte))
    output.append(0)
    return output^


def _reference_exists(reference: String) -> Bool:
    var encoded = _reference_cstring(reference)
    return external_call["access", Int32](encoded.unsafe_ptr(), 0) == 0


def resolve_model_reference(reference: String,
                            model_store: String = ".aesir/models") raises -> ResolvedModelReference:
    """Keeps path-shaped references intact; otherwise verifies a catalog name."""
    if reference == "":
        raise Error("model reference must not be empty")
    if (_reference_exists(reference) or reference.endswith(".gguf")
            or "/" in reference or "\\" in reference):
        return ResolvedModelReference(reference, reference)

    var durable = DurableModelStore(model_store)
    var catalog_name = normalize_model_reference(reference)
    var manifest = durable.get_model(catalog_name)
    var path = durable.resolve_model_path(catalog_name)
    return ResolvedModelReference(
        reference, path, catalog_name, manifest.digest, manifest.size_bytes,
        manifest.modelfile_content, True,
    )
