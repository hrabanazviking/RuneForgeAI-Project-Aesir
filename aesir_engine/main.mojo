# main.mojo
# Entry point for Project Aesir / Ollama CLI Engine
#
# The canonical command line is the general CLI (cli.commands): catalog,
# single-shot run (CPU GGUF, native CUDA, or Hailo-10H via --model-path),
# chat, serve, and the terminal home. The Hailo-only command module
# (cli.hailo_commands) remains in the tree for Hailo hosts; the direct
# Hailo GenAI session is reached from this CLI through
# `run --accel hailo10h --model-path <model.hef>`.

from std.sys import argv
from cli.commands import dispatch_command, print_general_help
from cli.interrupts import prepare_chat_process
from cli.home import dispatch_home, home_terminal_available


def main() raises:
    var raw_args = argv()
    var cli_args = List[String]()

    # argv()[0] is binary name; collect rest of command line args
    if len(raw_args) > 1:
        for i in range(1, len(raw_args)):
            cli_args.append(raw_args[i])

    # Home owns interactive launch only; redirected invocation keeps CLI help.
    if len(cli_args) == 0 and home_terminal_available():
        dispatch_home(["home"])
        return
    if len(cli_args) > 0 and cli_args[0] == "home":
        dispatch_home(cli_args)
        return
    if len(cli_args) > 0 and cli_args[0] == "chat":
        prepare_chat_process()
    if len(cli_args) > 0 and cli_args[0] == "serve":
        prepare_chat_process(True)
    dispatch_command(cli_args)
