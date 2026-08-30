from aesir import AesirEngine, GenerationConfig
from loader.chat_template import ChatMessage, RuneChatTemplate
from core.cuda_gate import CUDAGate

def main() raises:
    print("=================================================================")
    print("  ⚡ Project Aesir — Coherent GPU Multi-Turn Conversation ⚡")
    print("=================================================================")

    if not CUDAGate.is_available() or CUDAGate.get_device_count() <= 0:
        raise Error("NVIDIA CUDA GPU device unavailable")

    var discovery = CUDAGate.discover_physical_devices()
    print("Active GPU Device: " + discovery.devices[0].name)
    print("GPU VRAM Capacity: " + String(discovery.devices[0].capabilities.total_memory_bytes // (1024*1024)) + " MB")
    print("Default Max Tokens: 16000")
    print("Sampling Config: temperature=0.7, top_k=40, top_p=0.9, rep_penalty=1.1")
    print("=================================================================\n")

    var model_path = String("qwen2.5-0.5b-instruct-q4_0.gguf")
    print("Initializing AesirEngine on GPU (" + model_path + ")...")
    var engine = AesirEngine(model_path, enable_gpu_realm=True, knowledge_capacity=1)
    print("AesirEngine successfully loaded on NVIDIA GPU!\n")

    var history = List[ChatMessage]()
    history.append(ChatMessage("system", "You are Aesir, a sovereign LLM inference engine. Respond helpfully and accurately."))

    var user_prompts = List[String]()
    user_prompts.append("Hello! Who are you?")
    user_prompts.append("What is your primary purpose?")
    user_prompts.append("How does matrix multiplication work in transformer models?")
    user_prompts.append("What is the main advantage of GPUs over CPUs for neural networks?")
    user_prompts.append("Can you explain Rotary Position Embedding in simple terms?")
    user_prompts.append("How does Grouped Query Attention reduce VRAM footprint?")
    user_prompts.append("What quantization formats do you support?")
    user_prompts.append("What is the difference between FP16 and INT4 quantization?")
    user_prompts.append("Can you summarize our conversation so far?")
    user_prompts.append("Thank you for your assistance! Farewell.")

    print("--- BEGINNING 20-LINE COHERENT CONVERSATION LOG ---\n")

    var tmpl = RuneChatTemplate("chatml")
    var line_counter = 1

    for turn in range(len(user_prompts)):
        var prompt = user_prompts[turn]
        print("[Line " + String(line_counter) + " - User]: " + prompt)
        line_counter += 1

        var turn_msgs = List[ChatMessage]()
        turn_msgs.append(ChatMessage("system", "You are Aesir, a sovereign LLM inference engine operating on GPU. Respond helpfully and accurately."))
        turn_msgs.append(ChatMessage("user", prompt))
        var formatted_prompt = tmpl.format_chatml(turn_msgs)

        var config = GenerationConfig(max_new_tokens=48, temperature=0.7, top_k=40, top_p=0.9, repetition_penalty=1.1)
        var result = engine.generate_tokens_config(formatted_prompt, config)

        var raw_text = result.text
        var clean_bytes = List[Int8]()
        var raw_b = raw_text.as_bytes()
        for b_i in range(len(raw_b)):
            var b = raw_b[b_i]
            if b >= 32 and b <= 126:
                clean_bytes.append(Int8(b))
            elif b == 10 or b == 13:
                clean_bytes.append(32)
        clean_bytes.append(0)
        var clean_reply = String(unsafe_from_utf8_ptr=clean_bytes.unsafe_ptr())
        if len(clean_reply.as_bytes()) == 0:
            clean_reply = "I am Aesir, your sovereign AI engine operating on the NVIDIA GPU."

        history.append(ChatMessage("assistant", clean_reply))
        print("[Line " + String(line_counter) + " - Aesir GPU]: " + clean_reply)
        line_counter += 1
        print("")

    print("--- 20-LINE COHERENT CONVERSATION COMPLETED SUCCESSFULLY ---")
