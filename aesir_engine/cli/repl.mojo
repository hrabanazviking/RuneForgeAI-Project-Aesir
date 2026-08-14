# cli/repl.mojo
# Reserved interactive terminal REPL surface for Project Aesir

from aesir import AesirEngine
from cli.manifest import ModelManifest

struct RuneREPL:
    """
    RuneREPL — ᚱᛢᚾᛖ·ᚱᛖᛈᛚ — The Current of Conversation:
    Preserves the planned REPL configuration surface. Interactive stdin,
    conversation state, and real inference integration are not implemented.
    """
    var model_name: String
    var system_prompt: String
    var temperature: Float64
    var stream_enabled: Bool

    def __init__(out self, model_name: String = String("aesir:latest")):
        self.model_name = model_name
        self.system_prompt = String("You are Aesir, a bare-metal high-performance intelligence.")
        self.temperature = 0.7
        self.stream_enabled = True

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
        print("  /show [modelfile]  - Show model information")
        print("  /clear             - Clear chat conversation context")
        print("  /bye               - Exit the REPL session")

    def run_repl(mut self) raises:
        """Rejects the reserved REPL until stdin and engine sessions exist."""
        raise Error("interactive REPL is not implemented")


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
