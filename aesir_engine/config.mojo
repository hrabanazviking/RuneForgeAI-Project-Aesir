# config.mojo
# Line-oriented JSON configuration-intent parser for Project A.E.S.I.R.

from std.math import isinf, isnan
from std.ffi import external_call
from std.memory import Pointer
from std.memory.alloc import alloc, Layout
from std.collections import Dict


comptime MAX_CONFIG_BYTES = 1024 * 1024


def validate_model_store_path(path: String) raises -> String:
    """Validates a relative POSIX model-store path from caller configuration."""
    var clean = String(path.strip())
    if len(clean.bytes()) == 0:
        raise Error("model_store_path must not be empty")
    if clean.startswith("/") or "\\" in clean:
        raise Error("model_store_path must be a relative POSIX path")
    var segments = clean.split("/")
    for index in range(len(segments)):
        var segment = String(segments[index])
        if len(segment.bytes()) == 0 or segment == "." or segment == "..":
            raise Error("model_store_path contains an unsafe path segment")
        var source = segment.as_bytes()
        for byte_index in range(len(source)):
            var code = Int(source[byte_index])
            var allowed = (
                (code >= 48 and code <= 57)
                or (code >= 65 and code <= 90)
                or (code >= 97 and code <= 122)
                or code == 45
                or code == 46
                or code == 95
            )
            if not allowed:
                raise Error("model_store_path contains an unsafe character")
    return clean


struct AesirConfig:
    """
    AesirConfig — Central configuration container for Project A.E.S.I.R.
    Stores parsed intent. Most fields are not yet connected to runtime behavior;
    in particular, hardware and experimental values do not activate execution.
    """

    var acceleration_backend: String  # "auto", "cuda", "metal", "intel", "amd", "npu", "cpu", "max"
    var target_npu: String  # "auto", "hailo10", "hailo8", "hexagon", "ane", "intel_npu", "arm_neon"
    var skaldbrodir_enabled: Bool  # Doom Loop Annihilation Protocol
    var thinking_enabled: Bool  # Thought token generation & suppression toggle
    var cia_enabled: Bool  # Cognitive Inference Architecture (Episodic Computation Memory)
    var wic_enabled: Bool  # Wave Inference Computing (Holographic standing waves)
    var nsfi_enabled: Bool  # Neural Spectral Fractal Inference
    var mqari_enabled: Bool  # MÍMIR-VØLVA Quantum-Acoustic Resonance Inference
    var tui_enabled: Bool  # Terminal UI monitoring dashboard
    var max_threads: Int  # Thread pool limit (0 = auto-detect CPU cores)
    var num_gpu_layers: Int  # Number of model layers offloaded to GPU/NPU (-1 = all)
    var temperature: Float64  # Default sampling temperature
    var top_p: Float64  # Default top-p nucleus sampling cutoff
    var model_store_path: String  # Relative root for durable catalog/blob state
    var config_path: String  # Source path of loaded configuration file

    def __init__(out self):
        self.acceleration_backend = String("auto")
        self.target_npu = String("auto")
        self.skaldbrodir_enabled = False
        self.thinking_enabled = False
        self.cia_enabled = False
        self.wic_enabled = False
        self.nsfi_enabled = False
        self.mqari_enabled = False
        self.tui_enabled = False
        self.max_threads = 0
        self.num_gpu_layers = 0
        self.temperature = 0.0
        self.top_p = 1.0
        self.model_store_path = String(".aesir/models")
        self.config_path = String("aesir.config.json")

    def to_json_string(self) -> String:
        """Serializes current configuration into human-readable JSON string."""
        var out_str = String("{\n")
        out_str += '  "hardware": {\n'
        out_str += (
            '    "acceleration_backend": "' + self.acceleration_backend + '",\n'
        )
        out_str += '    "target_npu": "' + self.target_npu + '",\n'
        out_str += (
            '    "num_gpu_layers": ' + String(self.num_gpu_layers) + ",\n"
        )
        out_str += '    "max_threads": ' + String(self.max_threads) + "\n"
        out_str += "  },\n"

        out_str += '  "safety": {\n'
        out_str += (
            '    "skaldbrodir_enabled": '
            + (String("true") if self.skaldbrodir_enabled else String("false"))
            + ",\n"
        )
        out_str += (
            '    "thinking_enabled": '
            + (String("true") if self.thinking_enabled else String("false"))
            + "\n"
        )
        out_str += "  },\n"

        out_str += '  "experimental_paradigms": {\n'
        out_str += (
            '    "cia_enabled": '
            + (String("true") if self.cia_enabled else String("false"))
            + ",\n"
        )
        out_str += (
            '    "wic_enabled": '
            + (String("true") if self.wic_enabled else String("false"))
            + ",\n"
        )
        out_str += (
            '    "nsfi_enabled": '
            + (String("true") if self.nsfi_enabled else String("false"))
            + ",\n"
        )
        out_str += (
            '    "mqari_enabled": '
            + (String("true") if self.mqari_enabled else String("false"))
            + "\n"
        )
        out_str += "  },\n"

        out_str += '  "interface": {\n'
        out_str += (
            '    "tui_enabled": '
            + (String("true") if self.tui_enabled else String("false"))
            + "\n"
        )
        out_str += "  },\n"

        out_str += '  "storage": {\n'
        out_str += (
            '    "model_store_path": "' + self.model_store_path + '"\n'
        )
        out_str += "  },\n"

        out_str += '  "sampling": {\n'
        out_str += '    "temperature": ' + String(self.temperature) + ",\n"
        out_str += '    "top_p": ' + String(self.top_p) + "\n"
        out_str += "  }\n"
        out_str += "}\n"

        return out_str


def parse_config_json(json_content: String) raises -> AesirConfig:
    """Parses the tracked line-oriented JSON schema and rejects invalid values.
    """
    var config = AesirConfig()
    var seen_keys = Dict[String, Bool]()
    var lines = json_content.split("\n")
    for i in range(len(lines)):
        var line = lines[i].strip()
        if (
            len(line.as_bytes()) == 0
            or line.startswith("{")
            or line.startswith("}")
        ):
            continue
        var parts = line.split(":")
        if len(parts) != 2:
            raise Error("malformed configuration line")
        var key = String(parts[0].strip().strip('"'))
        var val = String(parts[1].strip().strip(",").strip('"'))

        if key in seen_keys:
            raise Error("duplicate configuration key: " + key)
        seen_keys[key] = True

        if key == "acceleration_backend":
            if (
                val != "auto"
                and val != "cpu"
                and val != "cuda"
                and val != "metal"
                and val != "intel"
                and val != "amd"
                and val != "npu"
                and val != "max"
            ):
                raise Error("invalid acceleration_backend: " + val)
            config.acceleration_backend = val
        elif key == "target_npu":
            if (
                val != "auto"
                and val != "hailo10"
                and val != "hailo8"
                and val != "hexagon"
                and val != "ane"
                and val != "intel_npu"
                and val != "arm_neon"
            ):
                raise Error("invalid target_npu: " + val)
            config.target_npu = val
        elif key == "skaldbrodir_enabled":
            if val != "true" and val != "false":
                raise Error("skaldbrodir_enabled must be true or false")
            config.skaldbrodir_enabled = val.lower() == "true"
        elif key == "thinking_enabled":
            if val != "true" and val != "false":
                raise Error("thinking_enabled must be true or false")
            config.thinking_enabled = val.lower() == "true"
        elif key == "cia_enabled":
            if val != "true" and val != "false":
                raise Error("cia_enabled must be true or false")
            config.cia_enabled = val.lower() == "true"
        elif key == "wic_enabled":
            if val != "true" and val != "false":
                raise Error("wic_enabled must be true or false")
            config.wic_enabled = val.lower() == "true"
        elif key == "nsfi_enabled":
            if val != "true" and val != "false":
                raise Error("nsfi_enabled must be true or false")
            config.nsfi_enabled = val.lower() == "true"
        elif key == "mqari_enabled":
            if val != "true" and val != "false":
                raise Error("mqari_enabled must be true or false")
            config.mqari_enabled = val.lower() == "true"
        elif key == "tui_enabled":
            if val != "true" and val != "false":
                raise Error("tui_enabled must be true or false")
            config.tui_enabled = val.lower() == "true"
        elif key == "model_store_path":
            config.model_store_path = validate_model_store_path(val)
        elif key == "max_threads":
            try:
                config.max_threads = atol(val)
            except:
                raise Error("max_threads must be an integer")
        elif key == "num_gpu_layers":
            try:
                config.num_gpu_layers = atol(val)
            except:
                raise Error("num_gpu_layers must be an integer")
        elif key == "temperature":
            try:
                config.temperature = atof(val)
            except:
                raise Error("temperature must be numeric")
        elif key == "top_p":
            try:
                config.top_p = atof(val)
            except:
                raise Error("top_p must be numeric")
        elif (
            key != "hardware"
            and key != "safety"
            and key != "experimental_paradigms"
            and key != "interface"
            and key != "storage"
            and key != "sampling"
        ):
            raise Error("unknown configuration key: " + key)

    if config.max_threads < 0:
        raise Error("max_threads cannot be negative")
    if config.num_gpu_layers < -1:
        raise Error("num_gpu_layers cannot be less than -1")
    if config.temperature < 0.0:
        raise Error("temperature cannot be negative")
    if isnan(config.temperature) or isinf(config.temperature):
        raise Error("temperature must be finite")
    if config.top_p < 0.0 or config.top_p > 1.0:
        raise Error("top_p must be between 0.0 and 1.0")
    if isnan(config.top_p) or isinf(config.top_p):
        raise Error("top_p must be finite")
    config.model_store_path = validate_model_store_path(
        config.model_store_path
    )

    return config^


def load_config_file(path: String) raises -> AesirConfig:
    """Reads, validates, and records one caller-selected configuration file."""
    var clean_path = String(path.strip())
    if len(clean_path.bytes()) == 0:
        raise Error("configuration path must not be empty")

    # Use the repository's existing POSIX boundary instead of mixing the
    # standard-library FileHandle symbol with GGUF's direct mmap/open FFI.
    var path_bytes = List[Int8]()
    var source = clean_path.as_bytes()
    for index in range(len(source)):
        path_bytes.append(Int8(source[index]))
    path_bytes.append(0)

    # Linux O_RDONLY | O_NOFOLLOW | O_CLOEXEC. A configuration path must name
    # a file rather than an attacker-substituted final symlink.
    var fd = external_call["open64", Int32](
        path_bytes.unsafe_ptr(), Int32(655360), Int32(0)
    )
    _ = path_bytes
    if fd < 0:
        raise Error("unable to read configuration '" + clean_path + "'")

    var content_bytes = List[Int8]()
    var buffer_alloc = alloc(Layout[Int8](count=4096))
    var buffer = buffer_alloc^.unsafe_leak()
    while True:
        var read_count = external_call["read", Int](Int(fd), buffer, 4096)
        if read_count < 0:
            var errno_pointer = external_call[
                "__errno_location", Pointer[Int32, MutUntrackedOrigin]
            ]()
            if errno_pointer.unsafe_load() == 4:
                continue
            buffer.unsafe_free()
            _ = external_call["close", Int32](fd)
            raise Error("failed while reading configuration '" + clean_path + "'")
        if read_count == 0:
            break
        if len(content_bytes) + read_count > MAX_CONFIG_BYTES:
            buffer.unsafe_free()
            _ = external_call["close", Int32](fd)
            raise Error("configuration exceeds the 1 MiB limit")
        for index in range(Int(read_count)):
            content_bytes.append(buffer.unsafe_load(index))
    buffer.unsafe_free()
    _ = external_call["close", Int32](fd)

    content_bytes.append(0)
    var content = String(unsafe_from_utf8_ptr=content_bytes.unsafe_ptr())
    _ = content_bytes

    if len(content.bytes()) == 0:
        raise Error("configuration file is empty: " + clean_path)

    var config = parse_config_json(content)
    config.config_path = clean_path
    return config^
