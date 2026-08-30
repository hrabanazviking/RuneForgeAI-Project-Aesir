# config.mojo
# Human-Readable JSON Configuration System for Project A.E.S.I.R.

struct AesirConfig:
    """
    AesirConfig — Central configuration container for Project A.E.S.I.R.
    Governs hardware acceleration (GPUs, NPUs including Hailo-10 / Pi 5), compute paradigms, safety protocols, and defaults.
    """
    var acceleration_backend: String  # "auto", "cuda", "metal", "intel", "amd", "npu", "cpu", "max"
    var target_npu: String            # "auto", "hailo10", "hailo8", "hexagon", "ane", "intel_npu", "arm_neon"
    var skaldbrodir_enabled: Bool      # Doom Loop Annihilation Protocol
    var thinking_enabled: Bool        # Thought token generation & suppression toggle
    var cia_enabled: Bool             # Cognitive Inference Architecture (Episodic Computation Memory)
    var wic_enabled: Bool             # Wave Inference Computing (Holographic standing waves)
    var nsfi_enabled: Bool            # Neural Spectral Fractal Inference
    var mqari_enabled: Bool           # MÍMIR-VØLVA Quantum-Acoustic Resonance Inference
    var tui_enabled: Bool             # Terminal UI monitoring dashboard
    var max_threads: Int              # Thread pool limit (0 = auto-detect CPU cores)
    var num_gpu_layers: Int           # Number of model layers offloaded to GPU/NPU (-1 = all)
    var temperature: Float64          # Default sampling temperature
    var top_p: Float64                # Default top-p nucleus sampling cutoff
    var config_path: String           # Source path of loaded configuration file

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
        self.config_path = String("aesir.config.json")

    def to_json_string(self) -> String:
        """Serializes current configuration into human-readable JSON string."""
        var out_str = String("{\n")
        out_str += "  \"hardware\": {\n"
        out_str += "    \"acceleration_backend\": \"" + self.acceleration_backend + "\",\n"
        out_str += "    \"target_npu\": \"" + self.target_npu + "\",\n"
        out_str += "    \"num_gpu_layers\": " + String(self.num_gpu_layers) + ",\n"
        out_str += "    \"max_threads\": " + String(self.max_threads) + "\n"
        out_str += "  },\n"

        out_str += "  \"safety\": {\n"
        out_str += "    \"skaldbrodir_enabled\": " + (String("true") if self.skaldbrodir_enabled else String("false")) + ",\n"
        out_str += "    \"thinking_enabled\": " + (String("true") if self.thinking_enabled else String("false")) + "\n"
        out_str += "  },\n"

        out_str += "  \"experimental_paradigms\": {\n"
        out_str += "    \"cia_enabled\": " + (String("true") if self.cia_enabled else String("false")) + ",\n"
        out_str += "    \"wic_enabled\": " + (String("true") if self.wic_enabled else String("false")) + ",\n"
        out_str += "    \"nsfi_enabled\": " + (String("true") if self.nsfi_enabled else String("false")) + ",\n"
        out_str += "    \"mqari_enabled\": " + (String("true") if self.mqari_enabled else String("false")) + "\n"
        out_str += "  },\n"

        out_str += "  \"interface\": {\n"
        out_str += "    \"tui_enabled\": " + (String("true") if self.tui_enabled else String("false")) + "\n"
        out_str += "  },\n"

        out_str += "  \"sampling\": {\n"
        out_str += "    \"temperature\": " + String(self.temperature) + ",\n"
        out_str += "    \"top_p\": " + String(self.top_p) + "\n"
        out_str += "  }\n"
        out_str += "}\n"

        return out_str

def parse_config_json(json_content: String) raises -> AesirConfig:
    """Parses a JSON configuration string into an AesirConfig instance."""
    var config = AesirConfig()
    var lines = json_content.split("\n")
    for i in range(len(lines)):
        var line = lines[i].strip()
        if len(line.as_bytes()) == 0 or line.startswith("{") or line.startswith("}"):
            continue
        var parts = line.split(":")
        if len(parts) != 2:
            continue
        var key = String(parts[0].strip().strip('"').strip("'"))
        var val = String(parts[1].strip().strip(",").strip('"').strip("'"))

        if key == "acceleration_backend":
            config.acceleration_backend = val
        elif key == "target_npu":
            config.target_npu = val
        elif key == "skaldbrodir_enabled":
            config.skaldbrodir_enabled = (val.lower() == "true")
        elif key == "thinking_enabled":
            config.thinking_enabled = (val.lower() == "true")
        elif key == "cia_enabled":
            config.cia_enabled = (val.lower() == "true")
        elif key == "wic_enabled":
            config.wic_enabled = (val.lower() == "true")
        elif key == "nsfi_enabled":
            config.nsfi_enabled = (val.lower() == "true")
        elif key == "mqari_enabled":
            config.mqari_enabled = (val.lower() == "true")
        elif key == "tui_enabled":
            config.tui_enabled = (val.lower() == "true")
        elif key == "max_threads":
            try:
                config.max_threads = atol(val)
            except:
                pass
        elif key == "num_gpu_layers":
            try:
                config.num_gpu_layers = atol(val)
            except:
                pass
        elif key == "temperature":
            try:
                config.temperature = atof(val)
            except:
                pass
        elif key == "top_p":
            try:
                config.top_p = atof(val)
            except:
                pass

    return config^

def validate_model_store_path(path: String) raises -> String:
    """Validates a model store root path is non-empty and usable."""
    if len(path.as_bytes()) == 0:
        raise Error("model store path must not be empty")
    return path


def load_config_file(path: String) raises -> AesirConfig:
    """Reads a config file from disk and parses it."""
    try:
        var f = open(path, "r")
        var content = f.read()
        f.close()
        return parse_config_json(content)
    except e:
        raise Error("unable to read configuration: " + String(e))
