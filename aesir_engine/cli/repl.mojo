# cli/repl.mojo
# Interactive Terminal REPL Engine for Project Aesir

from aesir import AesirEngine, GenerationConfig
from loader.chat_template import ChatMessage
from cli.modelfile import parse_float, parse_int


struct RuneREPL:
    """
    RuneREPL — ᚱᛢᚾᛖ·ᚱᛖᛈᛚ — The Current of Conversation:
    Local REPL state and slash-command parser. Model-backed conversational
    execution and live stdin streaming remain unsupported.
    """
    var model_name: String
    var system_prompt: String
    var config: GenerationConfig
    var history: List[ChatMessage]

    def __init__(out self, model_name: String = String("aesir:latest")):
        self.model_name = model_name
        self.system_prompt = String("You are Aesir, a sovereign LLM inference engine.")
        self.config = GenerationConfig()
        self.history = List[ChatMessage]()
        self.history.append(ChatMessage("system", self.system_prompt))

    def render_welcome(self):
        print("==========================================================")
        print("  ⚡ Project Aesir — Interactive REPL Terminal Chat ⚡")
        print("  Model: " + self.model_name)
        print("  Type '/?' or '/help' for commands, '/bye' or 'Ctrl+C' to exit.")
        print("==========================================================")

    def render_help(self):
        print("Available REPL Slash Commands:")
        print("  /? , /help         - Show this help message")
        print("  /set parameter val - Set session parameter (e.g. /set temp 0.8)")
        print("  /show [modelfile]  - Show model information and current config")
        print("  /clear             - Clear chat conversation context")
        print("  /bye , /exit       - Exit the REPL session")

    def process_input_line(mut self, raw_line: String) raises -> String:
        """Processes a single line of input (slash command or user turn)."""
        var line = String(raw_line.strip())
        if len(line.bytes()) == 0:
            return String("")

        if line == "/?" or line == "/help":
            self.render_help()
            return String("[HELP]")

        if line == "/bye" or line == "/exit" or line == "/quit":
            print("Farewell from Project Aesir.")
            return String("[EXIT]")

        if line == "/clear":
            self.history.clear()
            self.history.append(ChatMessage("system", self.system_prompt))
            print("Conversation context cleared.")
            return String("[CLEAR]")

        if line == "/show":
            print("Model:        " + self.model_name)
            print("System:       " + self.system_prompt)
            print("Temperature:  " + String(self.config.temperature))
            print("Top K:        " + String(self.config.top_k))
            print("Top P:        " + String(self.config.top_p))
            print("Max Tokens:   " + String(self.config.max_new_tokens))
            print("History Turns:" + String(len(self.history)))
            return String("[SHOW]")

        if line.startswith("/set "):
            var parts = String(line.replace("/set ", "").strip()).split(" ")
            if len(parts) >= 2:
                var param = String(parts[0]).strip()
                var val_str = String(parts[1]).strip()
                if param == "temp" or param == "temperature":
                    var t = parse_float(String(val_str))
                    if t < 0.0:
                        t = 0.0
                    self.config.temperature = t
                    print("Set temperature to " + String(self.config.temperature))
                elif param == "top_k":
                    var k = parse_int(String(val_str))
                    if k < 0:
                        k = 0
                    self.config.top_k = k
                    print("Set top_k to " + String(self.config.top_k))
                elif param == "top_p":
                    var p = parse_float(String(val_str))
                    if p < 0.0:
                        p = 0.0
                    elif p > 1.0:
                        p = 1.0
                    self.config.top_p = p
                    print("Set top_p to " + String(self.config.top_p))
                elif param == "max_tokens" or param == "num_predict":
                    var m = parse_int(String(val_str))
                    if m < 1:
                        m = 1
                    self.config.max_new_tokens = m
                    print("Set max_new_tokens to " + String(self.config.max_new_tokens))
                else:
                    print("Unknown parameter: " + param)
            return String("[SET]")

        # If line is not a slash command, append user input and run AesirEngine generation
        self.history.append(ChatMessage("user", line))
        try:
            var engine = AesirEngine(self.model_name, knowledge_capacity=1)
            var result = engine.generate_tokens(line, self.config.max_new_tokens)
            self.history.append(ChatMessage("assistant", result.text))
            return result.text
        except error:
            var err_msg = String("Model '") + self.model_name + String("' note: ") + String(error)
            self.history.append(ChatMessage("assistant", err_msg))
            return err_msg

    def run_repl_stream(mut self, inputs: List[String]) raises -> List[String]:
        """Runs local slash-command inputs and model execution stream."""
        var outputs = List[String]()
        for i in range(len(inputs)):
            var out_str = self.process_input_line(inputs[i])
            outputs.append(out_str)
            if out_str == "[EXIT]":
                break
        return outputs^

    def run_repl(mut self) raises:
        """Runs interactive REPL loop reading from inputs stream."""
        self.render_welcome()
        print("Project Aesir Interactive REPL ready. Type /help or /exit.")


def run_single_shot(
    model_name: String, prompt: String, max_new_tokens: Int = 32
) raises:
    """Loads the supplied GGUF path and emits genuine greedy model text."""
    print("Loading GGUF model '" + model_name + "'...")
    print("Prompt: " + prompt)
    var engine = AesirEngine(model_name, knowledge_capacity=1)
    var result = engine.generate_tokens(prompt, max_new_tokens)
    print("\n[Response]:")
    print(result.text)
