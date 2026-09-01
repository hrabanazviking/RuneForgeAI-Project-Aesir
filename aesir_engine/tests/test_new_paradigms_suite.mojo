# tests/test_new_paradigms_suite.mojo
# Proving suite for Config, SKÁLDBRØÐIR, Thinking, Tool Use, Smart Crash, MAX, CIA, WIC, and NSFI

from config import AesirConfig, parse_config_json
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
from core.mqari import MQARIEngine
from core.mimir_well import MimirWell, RuneTensor, f16, NPUBackendType
from core.npu_gate import NPUGate

def test_config_and_json() raises:
    var cfg = AesirConfig()
    cfg.acceleration_backend = String("npu")
    cfg.target_npu = String("hailo10")
    cfg.skaldbrodir_enabled = True
    cfg.cia_enabled = True
    var json_out = cfg.to_json_string()

    if "\"acceleration_backend\": \"npu\"" not in json_out:
        raise Error("test_config_and_json: Failed to serialize config to JSON")

    var parsed = parse_config_json(json_out)
    if parsed.acceleration_backend != "npu":
        raise Error("test_config_and_json: Failed to parse acceleration_backend")
    if parsed.target_npu != "hailo10":
        raise Error("test_config_and_json: Failed to parse target_npu")
    if not parsed.skaldbrodir_enabled:
        raise Error("test_config_and_json: Failed to parse skaldbrodir_enabled")
    
    # Prove Hailo-10 /dev/hailo0 Pi 5 device detection method executes cleanly
    _ = NPUGate.is_hailo_pi5_device_present()
    print("test_config_and_json: PASS")

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
    var empty_frame = dash.render_frame()
    if "observation: unavailable" not in empty_frame:
        raise Error("test_help_and_tui: empty dashboard fabricated telemetry")
    dash.update_observation(
        "Llama-3-8B-Q4_K_M.gguf", "CUDA GPU", 4096.0, 12.5, 1,
        "native-session", 1788210000000,
    )
    var frame = dash.render_frame()
    if "OBSERVATION DASHBOARD" not in frame or "native-session" not in frame:
        raise Error("test_help_and_tui: TUI frame rendering failed")

    var rejected = False
    try:
        dash.update_observation("model", "CUDA", -1.0, 1.0, 1, "probe", 1)
    except:
        rejected = True
    if not rejected or dash.memory_used_mb != 4096.0:
        raise Error("test_help_and_tui: invalid observation was accepted or partially committed")
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

    var varied = SkaldbrodirDetector()
    for token in range(12):
        if varied.evaluate_and_intercept(token) != 0:
            raise Error("test_skaldbrodir_doom_loop: varied prefix raised a repetition signal")
    if varied.last_repetition_index != 0.0:
        raise Error("test_skaldbrodir_doom_loop: varied prefix produced a false periodicity score")

    var invalid = SkaldbrodirDetector()
    invalid.window_size = 0
    var invalid_rejected = False
    try:
        _ = invalid.evaluate_and_intercept(1)
    except:
        invalid_rejected = True
    if not invalid_rejected or len(invalid.token_history) != 0:
        raise Error("test_skaldbrodir_doom_loop: invalid policy mutated detector history")

    detector.reset()
    if detector.is_annihilated or len(detector.token_history) != 0:
        raise Error("test_skaldbrodir_doom_loop: reset did not clear session state")
    print("test_skaldbrodir_doom_loop: PASS")

def test_thinking_redaction() raises:
    var raw = String("Let me think... <think>Solving equation 2+2</think> The answer is 4.")
    var sanitized = sanitize_thinking_transcript(raw, False)
    if "<think>" in sanitized or "Solving" in sanitized:
        raise Error("test_thinking_redaction: failed to suppress thought block")

    var controller = ThinkingController(False)
    var streamed = controller.process_token_text("Visible <thi")
    streamed += controller.process_token_text("nk>hidden</thi")
    streamed += controller.process_token_text("nk> tail")
    streamed += controller.finish()
    if streamed != "Visible  tail":
        raise Error("test_thinking_redaction: split-tag redaction failed")

    var malformed_rejected = False
    try:
        _ = sanitize_thinking_transcript("visible<think>hidden", False)
    except:
        malformed_rejected = True
    if not malformed_rejected:
        raise Error("test_thinking_redaction: unterminated thought block was accepted")
    print("test_thinking_redaction: PASS")

def test_tool_use_json() raises:
    var tool = ToolDefinition(String("get_weather"), String("Gets current weather"), String("{\"location\": \"string\"}"))
    var tools = List[ToolDefinition]()
    tools.append(tool)
    var prompt = format_tool_system_prompt(tools)
    if "[AVAILABLE_TOOLS_JSON]" not in prompt:
        raise Error("test_tool_use_json: tool prompt formatting failed")

    var call_json = String("{\"tool\":\"get_weather\",\"arguments\":{\"location\":\"Oslo\",\"units\":\"metric\"}}")
    var parsed_call = parse_tool_call(call_json)
    if parsed_call.name != "get_weather" or parsed_call.arguments_json != "{\"location\":\"Oslo\",\"units\":\"metric\"}":
        raise Error("test_tool_use_json: strict tool call parsing failed")

    var prose_rejected = False
    try:
        _ = parse_tool_call("Calling tool: " + call_json)
    except:
        prose_rejected = True
    if not prose_rejected:
        raise Error("test_tool_use_json: prose-wrapped JSON was accepted")

    var duplicate_rejected = False
    try:
        _ = parse_tool_call("{\"tool\":\"a\",\"tool\":\"b\",\"arguments\":{}}")
    except:
        duplicate_rejected = True
    if not duplicate_rejected:
        raise Error("test_tool_use_json: duplicate field was accepted")

    var malformed_rejected = False
    try:
        _ = parse_tool_call("{\"tool\":\"a\",\"arguments\":{\"x\":[1,]}}")
    except:
        malformed_rejected = True
    if not malformed_rejected:
        raise Error("test_tool_use_json: malformed nested JSON was accepted")
    print("test_tool_use_json: PASS")

def test_smart_failure_diagnostics() raises:
    var reporter = SmartCrashReporter()
    _ = reporter.record_failure(String("CUDA out of memory error"), String("CUDAGate"))
    _ = reporter.record_failure(String("CUDA out of memory error"), String("CUDAGate"))
    var r3 = reporter.record_failure(String("CUDA out of memory error"), String("CUDAGate"))
    if not reporter.threshold_reached:
        raise Error("test_smart_failure_diagnostics: failure threshold was not recorded")
    if "Category: resource_exhaustion" not in r3 or "Recovery action: none performed" not in r3:
        raise Error("test_smart_failure_diagnostics: bounded diagnostic report is incorrect")

    var count_before_rejection = reporter.consecutive_failures
    var rejected = False
    try:
        _ = reporter.record_failure("", "CUDAGate")
    except:
        rejected = True
    if not rejected or reporter.consecutive_failures != count_before_rejection:
        raise Error("test_smart_failure_diagnostics: invalid failure mutated reporter state")

    print("test_smart_failure_diagnostics: PASS")

def test_max_gate_boundary() raises:
    var max_gate = MAXGate()
    if max_gate.is_available() or max_gate.is_initialized or max_gate.num_devices != 0:
        raise Error("test_max_gate_boundary: legacy gateway fabricated availability")

    var well = MimirWell(1024)
    var A = RuneTensor[f16](2, 2, well.allocate(4), False)
    var B = RuneTensor[f16](2, 2, well.allocate(4), False)
    var C = RuneTensor[f16](2, 2, well.allocate(4), False)
    for i in range(4):
        A.data.unsafe_store(i, Scalar[f16](1.0))
        B.data.unsafe_store(i, Scalar[f16](1.0))
        C.data.unsafe_store(i, Scalar[f16](7.0))
    var rejected = False
    try:
        max_gate.launch_gemm_max(A, B, C)
    except error:
        rejected = "not implemented" in String(error)
    if not rejected:
        raise Error("test_max_gate_boundary: legacy gateway substituted host GEMM")
    for i in range(4):
        if C.data.unsafe_load(i) != Scalar[f16](7.0):
            raise Error("test_max_gate_boundary: rejected gateway mutated output")
    print("test_max_gate_boundary: PASS")

def test_experimental_paradigms() raises:
    var well = MimirWell(1024 * 1024)
    var ecm = EpisodicComputationMemory()
    ecm.enabled = True
    var rejected = False
    try:
        _ = ecm.compute_semantic_hash(String("Explain quantum computing"))
    except error:
        rejected = "not implemented" in String(error)
    if not rejected:
        raise Error("test_experimental_paradigms: CIA fabricated a semantic hash")
    rejected = False
    try:
        ecm.store_episodic_state("invented")
    except error:
        rejected = "not implemented" in String(error)
    if not rejected or len(ecm.cached_hashes) != 0:
        raise Error("test_experimental_paradigms: CIA fabricated stored state")
    rejected = False
    try:
        _ = ecm.lookup_episodic_state("invented")
    except error:
        rejected = "not implemented" in String(error)
    if not rejected or ecm.cache_hits != 0 or ecm.cache_misses != 0:
        raise Error("test_experimental_paradigms: CIA fabricated lookup telemetry")

    var wic = WaveInferenceEngine()
    wic.enabled = True
    var in_ptr = well.allocate(4)
    var in_sig = RuneTensor[f16](1, 4, in_ptr)
    var out_ptr = well.allocate(4)
    var out_wave = RuneTensor[f16](1, 4, out_ptr)
    for i in range(4):
        in_sig.set(0, i, Scalar[f16](1.0))
        out_wave.set(0, i, Scalar[f16](7.0))
    rejected = False
    try:
        wic.propagate_holographic_wavefront(in_sig, out_wave)
    except error:
        rejected = "not implemented" in String(error)
    if not rejected:
        raise Error("test_experimental_paradigms: WIC fabricated execution")
    for i in range(4):
        if out_wave.get(0, i) != Scalar[f16](7.0):
            raise Error("test_experimental_paradigms: rejected WIC mutated output")

    var nsfi = NSFIEngine()
    nsfi.enabled = True
    var w_ptr = well.allocate(16)
    var target_w = RuneTensor[f16](4, 4, w_ptr)
    for r in range(4):
        for c in range(4):
            target_w.set(r, c, Scalar[f16](3.0))
    rejected = False
    try:
        nsfi.reconstruct_fractal_weights(1.5, 2.5, target_w)
    except error:
        rejected = "not implemented" in String(error)
    if not rejected:
        raise Error("test_experimental_paradigms: NSFI fabricated weights")
    for r in range(4):
        for c in range(4):
            if target_w.get(r, c) != Scalar[f16](3.0):
                raise Error("test_experimental_paradigms: rejected NSFI mutated weights")

    var mqari = MQARIEngine()
    mqari.enabled = True
    rejected = False
    try:
        mqari.solve_harmonic_resonance(in_sig, out_wave)
    except error:
        rejected = "not implemented" in String(error)
    if not rejected:
        raise Error("test_experimental_paradigms: MQARI fabricated execution")
    for i in range(4):
        if out_wave.get(0, i) != Scalar[f16](7.0):
            raise Error("test_experimental_paradigms: rejected MQARI mutated output")
    print("test_experimental_paradigms: PASS")

def main() raises:
    print("=== Testing New Paradigms & System Extensions ===")
    test_config_and_json()
    test_cli_flags()
    test_help_and_tui()
    test_skaldbrodir_doom_loop()
    test_thinking_redaction()
    test_tool_use_json()
    test_smart_failure_diagnostics()
    test_max_gate_boundary()
    test_experimental_paradigms()
    print("=== ALL NEW PARADIGMS PROVED CLEAN PASS ===")
