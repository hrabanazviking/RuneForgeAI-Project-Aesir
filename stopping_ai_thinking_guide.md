# The Comprehensive Guide to Stopping AI from "Thinking"

This guide outlines all known methodologies to prevent reasoning models (like Gemma 4, DeepSeek-R1, and others) from engaging in internal Chain-of-Thought (CoT) generation.

> [!CAUTION]
> As AI models evolve, the mechanisms to stop thinking vary wildly between models. You cannot simply "delete" the thinking layers from a dense transformer model without destroying its latent space.

---

## Part 1: The Core Problem

Modern reasoning models use the exact same neural pathways to "think" as they do to "speak". Unlike multimodal architectures (where a vision encoder can be physically stripped from the safetensors), reasoning is an emergent behavior triggered by prompt formatting.

When a reasoning model sees the end of the user prompt, its reinforcement training kicks in. It inherently expects to output a "start of thought" trigger token (e.g., `<think>`, `<|channel>thought\n`, or `<|start_of_thought|>`), followed by the thought process, followed by an "end of thought" token, and finally the actual answer.

---

## Part 2: Disabling Thoughts at the Template Level (Native Jinja)

The most effective, non-destructive way to stop a model from thinking is to bypass the trigger tokens at the chat template level. 

Hugging Face models typically contain a Jinja `chat_template` in their `tokenizer_config.json`. Many modern templates support an `enable_thinking` variable.

### Example in Python (Transformers)
```python
formatted_prompt = tokenizer.apply_chat_template(
    messages, 
    tokenize=False, 
    add_generation_prompt=True,
    enable_thinking=False 
)
```
When `enable_thinking=False` is passed, the Jinja template intentionally skips injecting the thought trigger into the system prompt or avoids prompting the model to enter reasoning mode.

---

## Part 3: Disabling Thoughts in Ollama

Ollama acts as a Go-based proxy over `llama.cpp`. By default, Ollama attempts to handle thinking internally or delegates it to `llama.cpp`.

### The `Think=false` API Flag
Ollama's API supports a `think: false` JSON payload option. If the model natively uses a Jinja template that respects `enable_thinking`, this flag will work out-of-the-box.

### The Nuclear Option: Prompt Injection
If a model (like `igorls/gemma-4-12B-it-heretic-GGUF`) relies on a hardcoded Go template via a custom Modelfile, the Jinja variables are ignored. The model will naturally begin generating thoughts, wasting compute and VRAM bandwidth.

To physically prevent this, you can patch Ollama to inject closing thought tags into the very end of the rendered string prompt:
```go
if os.Getenv("OLLAMA_NO_THINK") == "true" {
    prompt += "\n<channel|>\n</think>\n"
}
```
By explicitly injecting these tags, you deceive the model into believing it has *already* completed its thought process. It has no choice but to immediately transition to its final answer layer.

---

## Part 4: Token Stripping (The Illusion of Speed)

Many tools attempt to hide the thinking by intercepting the `<think>` and `</think>` tags in the output stream and deleting them before they reach the user.

> [!WARNING]
> This is a cosmetic fix! The model is still utilizing 100% of the VRAM bandwidth and compute required to generate those tokens. The user will experience a massive delay (often 10+ seconds) before the first visible token appears.

To truly save compute, you must prevent the generation *before* it starts (using the methods in Part 2 or Part 3).

---

## Conclusion
Stopping an AI from thinking requires tricking the model at the prompt level. Ensure you are using the correct prompt closing tags for the specific model architecture you are working with.
