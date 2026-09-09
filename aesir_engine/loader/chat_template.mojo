"""GGUF chat-template detection and metadata-driven tokenizer selection."""


struct NativeTokenizerSelection(Copyable):
    var tokenizer_family: String
    var format_style: String

    def __init__(out self, tokenizer_family: String, format_style: String):
        self.tokenizer_family = tokenizer_family
        self.format_style = format_style

    @staticmethod
    def from_metadata(architecture: String, tokenizer_model: String,
                      tokenizer_pre: String,
                      jinja_template: String) raises -> Self:
        var family = tokenizer_model if tokenizer_model != "" else "unknown"
        var expected = String("unknown")
        if architecture == "gemma4":
            family = "Gemma BPE"
            expected = "gemma"
            if tokenizer_model != "gemma4":
                raise Error("Gemma 4 requires tokenizer.ggml.model=gemma4")
        elif architecture == "llama":
            family = "Llama 3 BPE"
            expected = "llama3"
            if tokenizer_model != "gpt2" or tokenizer_pre != "llama-bpe":
                raise Error("Llama 3 requires gpt2/llama-bpe tokenizer metadata")
        elif architecture == "qwen2" or architecture == "qwen3":
            family = "Qwen BPE"
            expected = "chatml"
            if tokenizer_model != "gpt2" or tokenizer_pre != "qwen2":
                raise Error("Qwen requires gpt2/qwen2 tokenizer metadata")

        var detected = RuneChatTemplate.detect_template_family(jinja_template)
        if jinja_template == "":
            detected = expected
        elif detected == "unknown" and expected != "unknown":
            raise Error("unrecognized tokenizer.chat_template for " + architecture)
        elif expected != "unknown" and detected != expected:
            raise Error(
                "tokenizer.chat_template selects " + detected
                + " but architecture requires " + expected
            )
        return Self(family, detected)

struct ChatMessage(Copyable):
    """A single conversation turn with a role and content payload."""
    var role: String
    var content: String

    def __init__(out self, role: String, content: String):
        self.role = role
        self.content = content

    def __copyinit__(out self, existing: Self):
        self.role = existing.role
        self.content = existing.content

    @always_inline
    def copy(self) -> Self:
        return Self(self.role, self.content)

    def validate(self) raises:
        if self.role != "system" and self.role != "user" and self.role != "assistant" and self.role != "tool":
            raise Error("ChatMessage role must be system, user, assistant, or tool")

struct RuneChatTemplate(Copyable):
    var format_style: String

    def __init__(out self, format_style: String = "chatml"):
        self.format_style = format_style

    def __copyinit__(out self, existing: Self):
        self.format_style = existing.format_style

    @always_inline
    def copy(self) -> Self:
        return Self(self.format_style)

    @staticmethod
    def detect_template_family(jinja_template: String) -> String:
        if ("start_of_turn" in jinja_template or "gemma" in jinja_template
                or "<|turn>" in jinja_template or "<turn|>" in jinja_template):
            return "gemma"
        elif "<|im_start|>" in jinja_template or "im_start" in jinja_template:
            return "chatml"
        elif "<|start_header_id|>" in jinja_template or "start_header_id" in jinja_template:
            return "llama3"
        elif "[INST]" in jinja_template or "INST" in jinja_template or "<<SYS>>" in jinja_template:
            return "llama2"
        return "unknown"

    @staticmethod
    def escape_control_tokens(content: String) -> String:
        if "<|im_start|>" not in content and "<|im_end|>" not in content:
            return content
        var res = content.replace("<|im_start|>", "[im_start]")
        res = res.replace("<|im_end|>", "[im_end]")
        return res

    def format_gemma(self, messages: List[ChatMessage]) raises -> String:
        if len(messages) == 0:
            raise Error("cannot format empty ChatMessage list")
        var prompt = String("")
        var nl = String("\n")
        for i in range(len(messages)):
            messages[i].validate()
            var role = messages[i].role
            if role == "assistant":
                role = "model"
            elif role == "system":
                role = "user"
            var safe_content = Self.escape_control_tokens(messages[i].content)
            prompt += String("<start_of_turn>") + role + nl + safe_content + String("<end_of_turn>") + nl
        prompt += String("<start_of_turn>model") + nl
        return prompt

    def format_chatml(self, messages: List[ChatMessage]) raises -> String:
        if len(messages) == 0:
            raise Error("cannot format empty ChatMessage list")
        var prompt = String("")
        var nl = String("\n")
        for i in range(len(messages)):
            messages[i].validate()
            var safe_content = Self.escape_control_tokens(messages[i].content)
            prompt += String("<|im_start|>") + messages[i].role + nl + safe_content + String("<|im_end|>") + nl
        prompt += String("<|im_start|>assistant") + nl
        return prompt

    def format_llama3(self, messages: List[ChatMessage]) raises -> String:
        if len(messages) == 0:
            raise Error("cannot format empty ChatMessage list")
        var prompt = String("<|begin_of_text|>")
        var nl = String("\n")
        for i in range(len(messages)):
            messages[i].validate()
            var safe_content = Self.escape_control_tokens(messages[i].content)
            prompt += String("<|start_header_id|>") + messages[i].role + String("<|end_header_id|>") + nl + nl + safe_content + String("<|eot_id|>")
        prompt += String("<|start_header_id|>assistant<|end_header_id|>") + nl + nl
        return prompt

    def format_llama2(self, messages: List[ChatMessage]) raises -> String:
        if len(messages) == 0:
            raise Error("cannot format empty ChatMessage list")
        var prompt = String("")
        var system_prompt = String("")
        var nl = String("\n")
        for i in range(len(messages)):
            messages[i].validate()
            var safe_content = Self.escape_control_tokens(messages[i].content)
            if messages[i].role == "system":
                system_prompt = safe_content
            elif messages[i].role == "user":
                prompt += String("[INST] ")
                if system_prompt != "":
                    prompt += String("<<SYS>>") + nl + system_prompt + nl + String("<</SYS>>") + nl + nl
                    system_prompt = ""
                prompt += safe_content + String(" [/INST]")
            elif messages[i].role == "assistant":
                prompt += String(" ") + safe_content + String(" ")
            elif messages[i].role == "tool":
                prompt += String("[INST] Tool Response:") + nl + safe_content + String(" [/INST]")
        return prompt

    def format_chat(self, messages: List[ChatMessage]) raises -> String:
        if len(messages) == 0:
            raise Error("cannot format empty ChatMessage list")
        if self.format_style == "gemma" or self.format_style == "gemma3":
            return self.format_gemma(messages)
        elif self.format_style == "llama3":
            return self.format_llama3(messages)
        elif self.format_style == "llama2":
            return self.format_llama2(messages)
        else:
            return self.format_chatml(messages)
