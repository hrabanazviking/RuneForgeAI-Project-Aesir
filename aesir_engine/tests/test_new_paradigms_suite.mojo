# tests/test_new_paradigms_suite.mojo
# Proving suite for Config, SKÁLDBRØÐIR, Thinking, Tool Use, Smart Crash, MAX, CIA, WIC, and NSFI

from config import AesirConfig, parse_config_toml
from cli.options import parse_cli_options
from cli.help import get_help_overview, get_command_help
from cli.tui import AesirTUIDashboard
from core.skaldbrodir import SkaldbrodirDetector
from core.thinking import ThinkingController, sanitize_thinking_transcript
from core.tool_use import ToolDefinition, ToolCall, format_tool_system_prompt, parse_tool_call
from core.smart_crash import SmartCrashReporter
from core.max_gate import MAXGate
from core.cia import EpisodicComputationMemory
from core.wic import WaveInferenceEngine
from core.nsfi import NSFIEngine
from core.mimir_well import MimirWell, RuneTensor, f16

def test_config_and_toml() raises:
    var cfg = AesirConfig()
    cfg.acceleration_backend = String("cuda")
    cfg.skaldbrodir_enabled = True
    cfg.cia_enabled = True
    var toml_out = cfg.to_toml_string()

    if "acceleration_backend = \"cuda\"" not in toml_out:
        raise Error("test_config_and_toml: Failed to serialize config to TOML")

    var parsed = parse_config_toml(toml_out)
    if parsed.acceleration_backend != "cuda":
        raise Error("test_config_and_toml: Failed to parse acceleration_backend")
    if not parsed.skaldbrodir_enabled:
        raise Error("test_config_and_toml: Failed to parse skaldbrodir_enabled")
    print("test_config_and_toml: PASS")

def test_cli_flags() raises:
    var args = List[String]()
    args.append("--accel")
    args.append("npu")
    args.append("--skaldbrodir")
    args.append("on")
    args.append("--tui")

    var opts = parse_cli_options(args)
    if opts.accel_backend != "npu":
        raise Error("test_cli_flags: Failed to parse --accel flag")
    if opts.skaldbrodir != "on":
        raise Error("test_cli_flags: Failed to parse --skaldbrodir flag")
    if not opts.tui:
        raise Error("test_cli_flags: Failed to parse --tui flag")
    print("test_cli_flags: PASS")

def test_help_and_tui() raises:
    var overview = get_help_overview()
    if "Cyber-Viking AI Engine" not in overview:
        raise Error("test_help_and_tui: Help overview text missing header")

    var run_help = get_command_help(String("run"))
    if "aesir run" not in run_help:
        raise Error("test_help_and_tui: Run help text missing")

    var dash = AesirTUIDashboard()
    dash.model_name = String("Llama-3-8B-Q4_K_M.gguf")
    dash.active_backend = String("CUDA GPU")
    var frame = dash.render_frame()
    if "TELEMETRY DASHBOARD" not in frame:
        raise Error("test_help_and_tui: TUI frame rendering failed")
    print("test_help_and_tui: PASS")

def test_skaldbrodir_doom_loop() raises:
    var detector = SkaldbrodirDetector()

    # Feed repeated token pattern: 42, 42, 42, 42, 42...
    var caught = False
    for _ in range(12):
        try:
            _ = detector.evaluate_and_intercept(42)
        except e:
            if "INF-016" in String(e):
                caught = True
                break

    if not caught:
        raise Error("test_skaldbrodir_doom_loop: Failed to annihilate runaway generation loop with INF-016")
    print("test_skaldbrodir_doom_loop: PASS")

def test_thinking_and_tool_use() raises:
    var raw = String("Let me think... <think>Solving equation 2+2</think> The answer is 4.")
    var sanitized = sanitize_thinking_transcript(raw, False)
    if "<think>" in sanitized or "Solving" in sanitized:
        raise Error("test_thinking_and_tool_use: Failed to suppress thought tokens when thinking mode disabled")

    var tool = ToolDefinition(String("get_weather"), String("Gets current weather"), String("{\"location\": \"string\"}"))
    var tools = List[ToolDefinition]()
    tools.append(tool)
    var prompt = format_tool_system_prompt(tools)
    if "[AVAILABLE_TOOLS]" not in prompt:
        raise Error("test_thinking_and_tool_use: Tool prompt formatting failed")

    var call_json = String("Sure! Calling tool: {\"tool\": \"get_weather\", \"arguments\": {\"location\": \"Oslo\"}}")
    var parsed_call = parse_tool_call(call_json)
    if parsed_call.name != "get_weather":
        raise Error("test_thinking_and_tool_use: Failed to parse tool call name")
    print("test_thinking_and_tool_use: PASS")

def test_smart_crash_and_max() raises:
    var reporter = SmartCrashReporter()
    var r1 = reporter.handle_crash(String("CUDA out of memory error"), String("CUDAGate"))
    var r2 = reporter.handle_crash(String("CUDA out of memory error"), String("CUDAGate"))
    var r3 = reporter.handle_crash(String("CUDA out of memory error"), String("CUDAGate"))
    if not reporter.failsafe_mode_active:
        raise Error("test_smart_crash_and_max: Failsafe mode not activated after 3 crashes")
    if "FAILSAFE MODE" not in r3:
        raise Error("test_smart_crash_and_max: Crash report missing failsafe alert")

    var max_gate = MAXGate()
    if not max_gate.is_available():
        raise Error("test_smart_crash_and_max: MAXGate is_available returned false")
    print("test_smart_crash_and_max: PASS")

def test_experimental_paradigms() raises:
    var well = MimirWell(1024 * 1024)
    var ecm = EpisodicComputationMemory()
    ecm.enabled = True
    var hash1 = ecm.compute_semantic_hash(String("Explain quantum computing"))
    ecm.store_episodic_state(hash1)
    if not ecm.lookup_episodic_state(hash1):
        raise Error("test_experimental_paradigms: Episodic state lookup failed")

    var wic = WaveInferenceEngine()
    wic.enabled = True
    var in_ptr = well.allocate(4)
    var in_sig = RuneTensor[f16](1, 4, in_ptr)
    var out_ptr = well.allocate(4)
    var out_wave = RuneTensor[f16](1, 4, out_ptr)
    for i in range(4):
        in_sig.set(0, i, Scalar[f16](1.0))
    wic.propagate_holographic_wavefront(in_sig, out_wave)

    var nsfi = NSFIEngine()
    nsfi.enabled = True
    var w_ptr = well.allocate(16)
    var target_w = RuneTensor[f16](4, 4, w_ptr)
    nsfi.reconstruct_fractal_weights(1.5, 2.5, target_w)
    print("test_experimental_paradigms: PASS")

def main() raises:
    print("=== Testing New Paradigms & System Extensions ===")
    test_config_and_toml()
    test_cli_flags()
    test_help_and_tui()
    test_skaldbrodir_doom_loop()
    test_thinking_and_tool_use()
    test_smart_crash_and_max()
    test_experimental_paradigms()
    print("=== ALL NEW PARADIGMS PROVED CLEAN PASS ===")
