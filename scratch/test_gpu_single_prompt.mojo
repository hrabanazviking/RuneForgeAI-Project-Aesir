from aesir import AesirEngine, GenerationConfig

def main() raises:
    var engine = AesirEngine("qwen2.5-0.5b-instruct-q4_0.gguf", enable_gpu_realm=True)
    var config = GenerationConfig()
    config.max_new_tokens = 30
    config.temperature = 0.7
    config.top_k = 40
    
    var prompt = "<|im_start|>system\nYou are a helpful AI assistant.<|im_end|>\n<|im_start|>user\nHello! Who are you?<|im_end|>\n<|im_start|>assistant\n"
    var res = engine.generate_tokens_config(prompt, config)
    print("PROMPT OUTPUT:")
    print(res.text)

