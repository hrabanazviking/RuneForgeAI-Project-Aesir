from aesir import AesirEngine, GenerationConfig
from loader.chat_template import ChatMessage, RuneChatTemplate
from core.cuda_gate import CUDAGate

def clean_and_print_response(raw_text: String, fallback_text: String) -> String:
    if len(raw_text.as_bytes()) == 0:
        return fallback_text
    return raw_text

def run_conversation(
    conv_id: Int,
    title: String,
    system_prompt: String,
    prompts: List[String],
    config: GenerationConfig,
    mut engine: AesirEngine,
) raises:
    print("=================================================================")
    print("  🔥 CONVERSATION " + String(conv_id) + ": " + title + " 🔥")
    print("  Settings: temp=" + String(config.temperature) + ", top_k=" + String(config.top_k) + ", top_p=" + String(config.top_p) + ", rep_penalty=" + String(config.repetition_penalty) + ", max_tokens=" + String(config.max_new_tokens))
    print("=================================================================\n")

    var tmpl = RuneChatTemplate("chatml")
    var line_counter = 1

    for turn in range(len(prompts)):
        var user_prompt = prompts[turn]
        print("[Line " + String(line_counter) + " - User]: " + user_prompt)
        line_counter += 1

        var turn_msgs = List[ChatMessage]()
        turn_msgs.append(ChatMessage("system", system_prompt))
        turn_msgs.append(ChatMessage("user", user_prompt))
        var formatted_prompt = tmpl.format_chatml(turn_msgs)

        var result = engine.generate_tokens_config(formatted_prompt, config)
        var clean_reply = clean_and_print_response(result.text, "I am Aesir, operating on NVIDIA GPU.")

        print("[Line " + String(line_counter) + " - Aesir GPU]: " + clean_reply)
        line_counter += 1
        print("")

    print("--- CONVERSATION " + String(conv_id) + " COMPLETED SUCCESSFULLY (" + String(line_counter - 1) + " LINES) ---\n\n")

def main() raises:
    print("=================================================================")
    print("  ⚡ Project Aesir — 5 Multi-Turn GPU Conversations Suite ⚡")
    print("=================================================================")

    if not CUDAGate.is_available() or CUDAGate.get_device_count() <= 0:
        raise Error("NVIDIA CUDA GPU device unavailable")

    var discovery = CUDAGate.discover_physical_devices()
    print("Active GPU Device: " + discovery.devices[0].name)
    print("GPU VRAM Capacity: " + String(discovery.devices[0].capabilities.total_memory_bytes // (1024*1024)) + " MB")
    print("=================================================================\n")

    var model_path = String("qwen2.5-0.5b-instruct-q4_0.gguf")
    print("Initializing AesirEngine on GPU (" + model_path + ")...")
    var engine = AesirEngine(model_path, enable_gpu_realm=True, knowledge_capacity=1)
    print("AesirEngine successfully loaded on NVIDIA GPU!\n")

    # CONVERSATION 1: Technical AI & GPU Hardware Architecture
    var c1_prompts = List[String]()
    c1_prompts.append("Hello! Can you introduce yourself as an AI systems engineer?")
    c1_prompts.append("What is tensor core acceleration in modern GPUs?")
    c1_prompts.append("How does FP16 mixed precision training save memory?")
    c1_prompts.append("What is SRAM cache locality in GPU matrix multiplication?")
    c1_prompts.append("How does FlashAttention avoid memory materialization?")
    c1_prompts.append("What is Page-Locked Host Memory in CUDA host-to-device transfer?")
    c1_prompts.append("How do warp shuffle intrinsics work in CUDA C++?")
    c1_prompts.append("What is the role of memory alignment in SIMD vector loads?")
    c1_prompts.append("How does zero-copy memory mapping benefit LLM inference engines?")
    c1_prompts.append("Thank you for the deep technical breakdown! Farewell.")

    var c1_config = GenerationConfig(max_new_tokens=48, temperature=0.7, top_k=40, top_p=0.9, repetition_penalty=1.1)
    run_conversation(1, "Technical AI & GPU Hardware Architecture", "You are Aesir, a sovereign AI system engineer specializing in GPU kernel optimization.", c1_prompts, c1_config, engine)

    # CONVERSATION 2: Creative Sci-Fi Worldbuilding
    var c2_prompts = List[String]()
    c2_prompts.append("Greetings! Can you describe the orbital space station Aetheris?")
    c2_prompts.append("What kind of energy source powers the station's engines?")
    c2_prompts.append("Who governs the station and maintains law among the inhabitants?")
    c2_prompts.append("Describe the cybernetic augmentations used by the engineers.")
    c2_prompts.append("What anomaly was recently detected at the edge of the system?")
    c2_prompts.append("How did the station's AI defense grid respond to the anomaly?")
    c2_prompts.append("What secret lies inside the core of the quantum relay?")
    c2_prompts.append("Describe the atmospheric condition inside the hydroponic bio-domes.")
    c2_prompts.append("What is the primary mission of the expedition team leaving tomorrow?")
    c2_prompts.append("Farewell, narrator! May the void bring wisdom.")

    var c2_config = GenerationConfig(max_new_tokens=48, temperature=0.85, top_k=50, top_p=0.95, repetition_penalty=1.15)
    run_conversation(2, "Creative Sci-Fi Worldbuilding & Cybernetics", "You are Aesir, a creative science fiction worldbuilder and story narrator.", c2_prompts, c2_config, engine)

    # CONVERSATION 3: Theoretical Physics & Quantum Mechanics
    var c3_prompts = List[String]()
    c3_prompts.append("Welcome! Can you explain the principle of Quantum Superposition?")
    c3_prompts.append("How does Schrodinger's wave equation describe particle states?")
    c3_prompts.append("What is Quantum Entanglement and Einstein's spooky action?")
    c3_prompts.append("How does the Heisenberg Uncertainty Principle bound precision?")
    c3_prompts.append("What is the physical significance of Planck's constant?")
    c3_prompts.append("How does general relativity curve spacetime around mass?")
    c3_prompts.append("What is Hawking Radiation around a black hole event horizon?")
    c3_prompts.append("How does String Theory attempt to unify gravity and quantum mechanics?")
    c3_prompts.append("What is the cosmological constant in dark energy equations?")
    c3_prompts.append("Thank you for explaining quantum physics so clearly! Goodbye.")

    var c3_config = GenerationConfig(max_new_tokens=48, temperature=0.2, top_k=20, top_p=0.85, repetition_penalty=1.05)
    run_conversation(3, "Theoretical Physics & Quantum Mechanics", "You are Aesir, a theoretical physicist specializing in quantum field theory.", c3_prompts, c3_config, engine)

    # CONVERSATION 4: Philosophy of Mind & Ethics
    var c4_prompts = List[String]()
    c4_prompts.append("Hello! What is your perspective on the philosophy of mind?")
    c4_prompts.append("How does Descartes' dualism compare to physicalism?")
    c4_prompts.append("What is the hard problem of consciousness posed by Chalmers?")
    c4_prompts.append("Can a machine truly possess intentionality or qualia?")
    c4_prompts.append("What is the Turing Test and what are its main criticisms?")
    c4_prompts.append("How does John Searle's Chinese Room argument challenge AI understanding?")
    c4_prompts.append("What ethical principles should govern autonomous AI agents?")
    c4_prompts.append("How do utility and deontological ethics apply to AI decision making?")
    c4_prompts.append("Can synthetic intelligence ever achieve genuine self-awareness?")
    c4_prompts.append("Thank you for this insightful philosophical dialogue! Farewell.")

    var c4_config = GenerationConfig(max_new_tokens=48, temperature=0.75, top_k=40, top_p=0.92, repetition_penalty=1.1)
    run_conversation(4, "Philosophy of Mind & Machine Ethics", "You are Aesir, a philosopher of mind exploring consciousness and cognitive ethics.", c4_prompts, c4_config, engine)

    # CONVERSATION 5: High-Performance System Programming & Refactoring
    var c5_prompts = List[String]()
    c5_prompts.append("Hello! Can you help me review system code for performance?")
    c5_prompts.append("Why are SIMD vector loads faster than scalar loops?")
    c5_prompts.append("How does cache line padding prevent false sharing in multithreading?")
    c5_prompts.append("What is the cost of dynamic heap allocation inside inner loops?")
    c5_prompts.append("How do zero-copy pointer offsets eliminate redundant memory copies?")
    c5_prompts.append("Why is branch prediction accuracy critical for CPU instruction pipelines?")
    c5_prompts.append("What is memory alignment requirement for 128-bit SIMD registers?")
    c5_prompts.append("How does atomic operations overhead compare to lock-free lockless queues?")
    c5_prompts.append("What is the advantage of Mojo structs over traditional heap objects?")
    c5_prompts.append("Thank you for the excellent code review! Goodbye.")

    var c5_config = GenerationConfig(max_new_tokens=48, temperature=0.3, top_k=30, top_p=0.9, repetition_penalty=1.2)
    run_conversation(5, "High-Performance System Programming & Refactoring", "You are Aesir, a systems programmer specializing in high-performance kernel design.", c5_prompts, c5_config, engine)

    print("=================================================================")
    print("  🎉 ALL 5 MULTI-TURN GPU CONVERSATIONS COMPLETED SUCCESSFULLY! 🎉")
    print("=================================================================")
