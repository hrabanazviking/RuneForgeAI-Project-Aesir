# config.mojo
# Strict bounded JSON configuration-intent parser for Project A.E.S.I.R.

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


def _valid_config_utf8(text: String) -> Bool:
    var source = text.as_bytes()
    var index = 0
    while index < len(source):
        var first = Int(source[index])
        if first < 128:
            index += 1
            continue
        var count: Int
        var codepoint: Int
        var minimum: Int
        if first >= 194 and first <= 223:
            count = 1
            codepoint = first & 31
            minimum = 128
        elif first >= 224 and first <= 239:
            count = 2
            codepoint = first & 15
            minimum = 2048
        elif first >= 240 and first <= 244:
            count = 3
            codepoint = first & 7
            minimum = 65536
        else:
            return False
        if index + count >= len(source):
            return False
        for offset in range(1, count + 1):
            var next = Int(source[index + offset])
            if next < 128 or next > 191:
                return False
            codepoint = (codepoint << 6) | (next & 63)
        if (
            codepoint < minimum
            or codepoint > 1114111
            or (codepoint >= 55296 and codepoint <= 57343)
        ):
            return False
        index += count + 1
    return True


struct ConfigJSONParser:
    """Strict JSON parser for the bounded Project Aesir configuration schema."""

    var source: String
    var position: Int
    var config: AesirConfig

    def __init__(out self, source: String) raises:
        if (
            source.byte_length() == 0
            or source.byte_length() > MAX_CONFIG_BYTES
            or not _valid_config_utf8(source)
        ):
            raise Error("configuration must be 1..1048576 bytes of valid UTF-8")
        self.source = source
        self.position = 0
        self.config = AesirConfig()

    def _peek(self) -> Int:
        if self.position >= self.source.byte_length():
            return -1
        return Int(self.source.as_bytes()[self.position])

    def _space(mut self):
        while (
            self._peek() == 32
            or self._peek() == 9
            or self._peek() == 10
            or self._peek() == 13
        ):
            self.position += 1

    def _take(mut self, expected: Int) raises:
        self._space()
        if self._peek() != expected:
            raise Error("malformed configuration JSON")
        self.position += 1

    def _hex4(mut self) raises -> Int:
        var value = 0
        for _ in range(4):
            var digit = self._peek()
            if digit < 0:
                raise Error("truncated configuration Unicode escape")
            self.position += 1
            if digit >= 48 and digit <= 57:
                digit -= 48
            elif digit >= 65 and digit <= 70:
                digit -= 55
            elif digit >= 97 and digit <= 102:
                digit -= 87
            else:
                raise Error("invalid configuration Unicode escape")
            value = value * 16 + digit
        return value

    def _string(mut self) raises -> String:
        self._take(34)
        var output = List[Int8]()
        while True:
            var byte = self._peek()
            if byte < 0:
                raise Error("unterminated configuration string")
            self.position += 1
            if byte == 34:
                break
            if byte < 32:
                raise Error("configuration string contains an unescaped control")
            if byte != 92:
                output.append(Int8(byte))
                continue
            byte = self._peek()
            if byte < 0:
                raise Error("unterminated configuration escape")
            self.position += 1
            if byte == 34 or byte == 92 or byte == 47:
                output.append(Int8(byte))
            elif byte == 98:
                output.append(8)
            elif byte == 102:
                output.append(12)
            elif byte == 110:
                output.append(10)
            elif byte == 114:
                output.append(13)
            elif byte == 116:
                output.append(9)
            elif byte == 117:
                var codepoint = self._hex4()
                if codepoint >= 55296 and codepoint <= 56319:
                    if self._peek() != 92:
                        raise Error("configuration Unicode high surrogate lacks pair")
                    self.position += 1
                    if self._peek() != 117:
                        raise Error("configuration Unicode surrogate pair is malformed")
                    self.position += 1
                    var low = self._hex4()
                    if low < 56320 or low > 57343:
                        raise Error("configuration Unicode low surrogate is invalid")
                    codepoint = 65536 + ((codepoint - 55296) << 10) + low - 56320
                elif codepoint >= 56320 and codepoint <= 57343:
                    raise Error("configuration contains an unpaired low surrogate")
                if codepoint == 0:
                    raise Error("configuration strings must not contain NUL")
                if codepoint < 128:
                    output.append(Int8(codepoint))
                elif codepoint < 2048:
                    output.append(Int8(192 | (codepoint >> 6)))
                    output.append(Int8(128 | (codepoint & 63)))
                elif codepoint < 65536:
                    output.append(Int8(224 | (codepoint >> 12)))
                    output.append(Int8(128 | ((codepoint >> 6) & 63)))
                    output.append(Int8(128 | (codepoint & 63)))
                else:
                    output.append(Int8(240 | (codepoint >> 18)))
                    output.append(Int8(128 | ((codepoint >> 12) & 63)))
                    output.append(Int8(128 | ((codepoint >> 6) & 63)))
                    output.append(Int8(128 | (codepoint & 63)))
            else:
                raise Error("invalid configuration string escape")
        output.append(0)
        var result = String(unsafe_from_utf8_ptr=output.unsafe_ptr())
        _ = output
        return result

    def _boolean(mut self) raises -> Bool:
        self._space()
        if (
            self.position + 4 <= self.source.byte_length()
            and String(self.source[byte=self.position : self.position + 4])
            == "true"
        ):
            self.position += 4
            return True
        if (
            self.position + 5 <= self.source.byte_length()
            and String(self.source[byte=self.position : self.position + 5])
            == "false"
        ):
            self.position += 5
            return False
        raise Error("configuration boolean must be true or false")

    def _number(mut self) raises -> String:
        self._space()
        var start = self.position
        if self._peek() == 45:
            self.position += 1
        if self._peek() == 48:
            self.position += 1
            if self._peek() >= 48 and self._peek() <= 57:
                raise Error("configuration number has a leading zero")
        elif self._peek() >= 49 and self._peek() <= 57:
            while self._peek() >= 48 and self._peek() <= 57:
                self.position += 1
        else:
            raise Error("configuration value must be a JSON number")
        if self._peek() == 46:
            self.position += 1
            var fraction_start = self.position
            while self._peek() >= 48 and self._peek() <= 57:
                self.position += 1
            if self.position == fraction_start:
                raise Error("configuration fraction requires digits")
        if self._peek() == 101 or self._peek() == 69:
            self.position += 1
            if self._peek() == 43 or self._peek() == 45:
                self.position += 1
            var exponent_start = self.position
            while self._peek() >= 48 and self._peek() <= 57:
                self.position += 1
            if self.position == exponent_start:
                raise Error("configuration exponent requires digits")
        if self.position - start > 64:
            raise Error("configuration number exceeds 64 bytes")
        return String(self.source[byte=start : self.position])

    def _integer(mut self, label: String) raises -> Int:
        var value = self._number()
        if "." in value or "e" in value or "E" in value:
            raise Error(label + " must be an integer")
        try:
            return atol(value)
        except:
            raise Error(label + " is outside the supported integer range")

    def _float(mut self, label: String) raises -> Float64:
        var value = self._number()
        try:
            var parsed = atof(value)
            if isnan(parsed) or isinf(parsed):
                raise Error(label + " must be finite")
            return parsed
        except:
            raise Error(label + " must be a finite JSON number")

    def _field(mut self, section: String, key: String) raises:
        if section == "hardware" and key == "acceleration_backend":
            var value = self._string()
            if (
                value != "auto" and value != "cpu" and value != "cuda"
                and value != "metal" and value != "intel" and value != "amd"
                and value != "npu" and value != "max"
            ):
                raise Error("invalid acceleration_backend: " + value)
            self.config.acceleration_backend = value
        elif section == "hardware" and key == "target_npu":
            var value = self._string()
            if (
                value != "auto" and value != "hailo10" and value != "hailo8"
                and value != "hexagon" and value != "ane"
                and value != "intel_npu" and value != "arm_neon"
            ):
                raise Error("invalid target_npu: " + value)
            self.config.target_npu = value
        elif section == "hardware" and key == "max_threads":
            self.config.max_threads = self._integer(key)
        elif section == "hardware" and key == "num_gpu_layers":
            self.config.num_gpu_layers = self._integer(key)
        elif section == "safety" and key == "skaldbrodir_enabled":
            self.config.skaldbrodir_enabled = self._boolean()
        elif section == "safety" and key == "thinking_enabled":
            self.config.thinking_enabled = self._boolean()
        elif section == "experimental_paradigms" and key == "cia_enabled":
            self.config.cia_enabled = self._boolean()
        elif section == "experimental_paradigms" and key == "wic_enabled":
            self.config.wic_enabled = self._boolean()
        elif section == "experimental_paradigms" and key == "nsfi_enabled":
            self.config.nsfi_enabled = self._boolean()
        elif section == "experimental_paradigms" and key == "mqari_enabled":
            self.config.mqari_enabled = self._boolean()
        elif section == "interface" and key == "tui_enabled":
            self.config.tui_enabled = self._boolean()
        elif section == "storage" and key == "model_store_path":
            self.config.model_store_path = validate_model_store_path(self._string())
        elif section == "sampling" and key == "temperature":
            self.config.temperature = self._float(key)
        elif section == "sampling" and key == "top_p":
            self.config.top_p = self._float(key)
        else:
            raise Error("unknown configuration field " + section + "." + key)

    def _object(mut self, section: String) raises:
        self._take(123)
        self._space()
        var seen = Dict[String, Bool]()
        var field_count = 0
        if self._peek() != 125:
            while True:
                var key = self._string()
                field_count += 1
                if key.byte_length() > 64 or field_count > 32:
                    raise Error("configuration object has too many or oversized fields")
                if key in seen:
                    raise Error("duplicate configuration field: " + section + "." + key)
                seen[key] = True
                self._take(58)
                self._field(section, key)
                self._space()
                if self._peek() == 125:
                    break
                if self._peek() != 44:
                    raise Error("configuration object requires a comma")
                self.position += 1
                self._space()
                if self._peek() == 125:
                    raise Error("configuration object has a trailing comma")
        self._take(125)

    def parse(mut self) raises -> AesirConfig:
        self._take(123)
        self._space()
        var sections = Dict[String, Bool]()
        var section_count = 0
        if self._peek() != 125:
            while True:
                var section = self._string()
                section_count += 1
                if section.byte_length() > 64 or section_count > 16:
                    raise Error("configuration has too many or oversized sections")
                if section in sections:
                    raise Error("duplicate configuration section: " + section)
                if (
                    section != "hardware" and section != "safety"
                    and section != "experimental_paradigms"
                    and section != "interface" and section != "storage"
                    and section != "sampling"
                ):
                    raise Error("unknown configuration section: " + section)
                sections[section] = True
                self._take(58)
                self._object(section)
                self._space()
                if self._peek() == 125:
                    break
                if self._peek() != 44:
                    raise Error("configuration root requires a comma")
                self.position += 1
                self._space()
                if self._peek() == 125:
                    raise Error("configuration root has a trailing comma")
        self._take(125)
        self._space()
        if self._peek() != -1:
            raise Error("configuration has trailing content")
        if self.config.max_threads < 0:
            raise Error("max_threads cannot be negative")
        if self.config.num_gpu_layers < -1:
            raise Error("num_gpu_layers cannot be less than -1")
        if self.config.temperature < 0.0:
            raise Error("temperature cannot be negative")
        if self.config.top_p < 0.0 or self.config.top_p > 1.0:
            raise Error("top_p must be between 0.0 and 1.0")
        self.config.model_store_path = validate_model_store_path(
            self.config.model_store_path
        )
        var result = AesirConfig()
        result.acceleration_backend = self.config.acceleration_backend
        result.target_npu = self.config.target_npu
        result.skaldbrodir_enabled = self.config.skaldbrodir_enabled
        result.thinking_enabled = self.config.thinking_enabled
        result.cia_enabled = self.config.cia_enabled
        result.wic_enabled = self.config.wic_enabled
        result.nsfi_enabled = self.config.nsfi_enabled
        result.mqari_enabled = self.config.mqari_enabled
        result.tui_enabled = self.config.tui_enabled
        result.max_threads = self.config.max_threads
        result.num_gpu_layers = self.config.num_gpu_layers
        result.temperature = self.config.temperature
        result.top_p = self.config.top_p
        result.model_store_path = self.config.model_store_path
        result.config_path = self.config.config_path
        return result^


def parse_config_json(json_content: String) raises -> AesirConfig:
    """Parses the strict bounded nested JSON configuration schema."""
    var parser = ConfigJSONParser(json_content)
    return parser.parse()


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
