# loader/chat_template.mojo
# GGUF Chat Template & Multi-Turn Message Formatting Engine for Project Aesir


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
        """Validates that the role is system, user, assistant, or tool."""
        if self.role != "system" and self.role != "user" and self.role != "assistant" and self.role != "tool":
            raise Error("ChatMessage role must be 'system', 'user', 'assistant', or 'tool', got '" + self.role + "'")


struct RuneChatTemplate(Copyable):
    """Formats structured multi-turn ChatMessage lists into canonical prompts."""

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
        """Auto-detects template family ('chatml', 'llama3', 'llama2') from Jinja2 metadata string."""
        if "<|im_start|>" in jinja_template or "im_start" in jinja_template:
            return "chatml"
        elif "<|start_header_id|>" in jinja_template or "start_header_id" in jinja_template:
            return "llama3"
        elif "[INST]" in jinja_template or "INST" in jinja_template or "<<SYS>>" in jinja_template:
            return "llama2"
        else:
            return "chatml"

    @staticmethod
    def escape_control_tokens(content: String) -> String:
        """Sanitizes raw prompt control tokens from message content payloads using UTF-8 safe byte scanning."""
        var raw_b = content.as_bytes()
        var n_bytes = len(raw_b)
        if n_bytes == 0:
            return String("")
        
        var clean_b = List[Int8]()
        var i = 0
        while i < n_bytes:
            if i + 12 <= n_bytes and content[byte=i : i + 12] == "<|im_start|>":
                for b_c in "[im_start]".as_bytes():
                    clean_b.append(Int8(b_c))
                i += 12
                continue
            if i + 10 <= n_bytes and content[byte=i : i + 10] == "<|im_end|>":
                for b_c in "[im_end]".as_bytes():
                    clean_b.append(Int8(b_c))
                i += 10
                continue
            clean_b.append(Int8(raw_b[i]))
            i += 1
            
        clean_b.append(0)
        return String(unsafe_from_utf8_ptr=clean_b.unsafe_ptr())

    def format_chatml(self, messages: List[ChatMessage]) raises -> String:
        """Formats messages in ChatML standard (<|im_start|>role\ncontent<|im_end|>\n)."""
        if len(messages) == 0:
            raise Error("cannot format empty ChatMessage list")
        var prompt = String("")
        for i in range(len(messages)):
            messages[i].validate()
            var safe_content = Self.escape_control_tokens(messages[i].content)
            prompt += "<|im_start|>" + messages[i].role + "\n" + safe_content + "<|im_end|>\n"
        prompt += "<|im_start|>assistant\n"
        return prompt

    def format_llama3(self, messages: List[ChatMessage]) raises -> String:
        """Formats messages in Llama-3 standard (<|start_header_id|>role<|end_header_id|>\n\ncontent<|eot_id|>)."""
        if len(messages) == 0:
            raise Error("cannot format empty ChatMessage list")
        var prompt = String("<|begin_of_text|>")
        for i in range(len(messages)):
            messages[i].validate()
            var safe_content = Self.escape_control_tokens(messages[i].content)
            prompt += "<|start_header_id|>" + messages[i].role + "<|end_header_id|>\n\n" + safe_content + "<|eot_id|>"
        prompt += "<|start_header_id|>assistant<|end_header_id|>\n\n"
        return prompt

    def format_llama2(self, messages: List[ChatMessage]) raises -> String:
        """Formats messages in Llama-2 standard ([INST] <<SYS>>\nsystem\n<</SYS>>\n\nuser [/INST])."""
        if len(messages) == 0:
            raise Error("cannot format empty ChatMessage list")
        var prompt = String("")
        var system_prompt = String("")
        var in_inst = False

        for i in range(len(messages)):
            messages[i].validate()
            var safe_content = Self.escape_control_tokens(messages[i].content)
            if messages[i].role == "system":
                system_prompt = safe_content
            elif messages[i].role == "user":
                prompt += "[INST] "
                if system_prompt != "":
                    prompt += "<<SYS>>\n" + system_prompt + "\n<</SYS>>\n\n"
                    system_prompt = ""
                prompt += safe_content + " [/INST]"
            elif messages[i].role == "assistant":
                prompt += " " + safe_content + " "
            elif messages[i].role == "tool":
                prompt += "[INST] Tool Response:\n" + safe_content + " [/INST]"

        _ = in_inst
        return prompt

    def format_chat(self, messages: List[ChatMessage]) raises -> String:
        """Formats a list of ChatMessages according to self.format_style."""
        if len(messages) == 0:
            raise Error("cannot format empty ChatMessage list")
        if self.format_style == "llama3":
            return self.format_llama3(messages)
        elif self.format_style == "llama2":
            return self.format_llama2(messages)
        else:
            return self.format_chatml(messages)
