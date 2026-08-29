# config.mojo
# Line-oriented JSON configuration-intent parser for Project A.E.S.I.R.

struct AesirConfig:
    """
    AesirConfig — Central configuration container for Project A.E.S.I.R.
    Stores parsed intent. Most fields are not yet connected to runtime behavior;
    in particular, hardware and experimental values do not activate execution.
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
        self.skaldbrodir_enabled = True
        self.thinking_enabled = True
        self.cia_enabled = False
        self.wic_enabled = False
        self.nsfi_enabled = False
        self.mqari_enabled = False
        self.tui_enabled = False
        self.max_threads = 0
        self.num_gpu_layers = -1
        self.temperature = 0.7
        self.top_p = 0.9
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
    """Parses the tracked line-oriented JSON schema and rejects invalid values."""
    var config = AesirConfig()
    var lines = json_content.split("\n")
    for i in range(len(lines)):
        var line = lines[i].strip()
        if len(line.as_bytes()) == 0 or line.startswith("{") or line.startswith("}"):
            continue
        var parts = line.split(":")
        if len(parts) != 2:
            continue
        var key = String(parts[0].strip().strip("\""))
        var val = String(parts[1].strip().strip(",").strip("\""))

        if key == "acceleration_backend":
            if (
                val != "auto" and val != "cpu" and val != "cuda"
                and val != "metal" and val != "intel" and val != "amd"
                and val != "npu" and val != "max"
            ):
                raise Error("invalid acceleration_backend: " + val)
            config.acceleration_backend = val
        elif key == "target_npu":
            if (
                val != "auto" and val != "hailo10" and val != "hailo8"
                and val != "hexagon" and val != "ane"
                and val != "intel_npu" and val != "arm_neon"
            ):
                raise Error("invalid target_npu: " + val)
            config.target_npu = val
        elif key == "skaldbrodir_enabled":
            if val != "true" and val != "false":
                raise Error("skaldbrodir_enabled must be true or false")
            config.skaldbrodir_enabled = (val.lower() == "true")
        elif key == "thinking_enabled":
            if val != "true" and val != "false":
                raise Error("thinking_enabled must be true or false")
            config.thinking_enabled = (val.lower() == "true")
        elif key == "cia_enabled":
            if val != "true" and val != "false":
                raise Error("cia_enabled must be true or false")
            config.cia_enabled = (val.lower() == "true")
        elif key == "wic_enabled":
            if val != "true" and val != "false":
                raise Error("wic_enabled must be true or false")
            config.wic_enabled = (val.lower() == "true")
        elif key == "nsfi_enabled":
            if val != "true" and val != "false":
                raise Error("nsfi_enabled must be true or false")
            config.nsfi_enabled = (val.lower() == "true")
        elif key == "mqari_enabled":
            if val != "true" and val != "false":
                raise Error("mqari_enabled must be true or false")
            config.mqari_enabled = (val.lower() == "true")
        elif key == "tui_enabled":
            if val != "true" and val != "false":
                raise Error("tui_enabled must be true or false")
            config.tui_enabled = (val.lower() == "true")
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
            key != "hardware" and key != "safety"
            and key != "experimental_paradigms" and key != "interface"
            and key != "sampling"
        ):
            raise Error("unknown configuration key: " + key)

    if config.max_threads < 0:
        raise Error("max_threads cannot be negative")
    if config.num_gpu_layers < -1:
        raise Error("num_gpu_layers cannot be less than -1")
    if config.temperature < 0.0:
        raise Error("temperature cannot be negative")
    if config.top_p < 0.0 or config.top_p > 1.0:
        raise Error("top_p must be between 0.0 and 1.0")

    return config^
