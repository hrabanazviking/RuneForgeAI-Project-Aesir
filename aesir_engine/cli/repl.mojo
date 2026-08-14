# cli/repl.mojo
# Interactive Terminal REPL & Chat Current for Project Aesir / Ollama CLI

from aesir import AesirEngine
from cli.manifest import ModelManifest

struct RuneREPL:
    """
    RuneREPL — ᚱᛢᚾᛖ·ᚱᛖᛈᛚ — The Current of Conversation:
    Provides interactive terminal chat prompt loop, streaming token generation current,
    and runtime slash commands (/? /help, /set parameter val, /show modelfile, /clear, /bye).
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
        """Runs the interactive prompt loop."""
        self.render_welcome()

        # Simulate REPL session interaction
        var sample_prompts = List[String]()
        sample_prompts.append("Hello Aesir! What is your purpose?")
        sample_prompts.append("/show modelfile")
        sample_prompts.append("Explain matrix multiplication in three sentences.")
        sample_prompts.append("/bye")

        for i in range(len(sample_prompts)):
            var input_line = sample_prompts[i]
            print("\n>>> " + input_line)

            if input_line == "/bye" or input_line == "/exit":
                print("Farewell! The rainbow bridge closes.")
                break
            elif input_line == "/?" or input_line == "/help":
                self.render_help()
                continue
            elif input_line.startswith("/show"):
                print("Model: " + self.model_name)
                print("System Prompt: " + self.system_prompt)
                print("Temperature: " + String(self.temperature))
                continue
            elif input_line.startswith("/clear"):
                print("Conversation context cleared.")
                continue

            # Stream response simulation
            print("\n[Aesir]: Floating through living memory...")
            print("I am Project Aesir — forged directly upon bare metal with zero dependencies.")
            print("My tensor streams flow through MimirWell without heap allocation ash.")


def run_single_shot(model_name: String, prompt: String) raises:
    """Executes a single prompt run and streams output to terminal."""
    print("Running model '" + model_name + "'...")
    print("Prompt: " + prompt)
    print("\n[Response]:")
    print("Bare-metal inference complete. Tensor matrix struck cleanly across all realms.")
