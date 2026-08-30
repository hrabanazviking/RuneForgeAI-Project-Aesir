# main.mojo
# Entry point for Project Aesir / Ollama CLI Engine

from std.sys import argv
from cli.commands import dispatch_command, print_general_help


def main() raises:
    var raw_args = argv()
    var cli_args = List[String]()

    # argv()[0] is binary name; collect rest of command line args
    if len(raw_args) > 1:
        for i in range(1, len(raw_args)):
            cli_args.append(raw_args[i])

    # An empty invocation is a discovery request, not an implicit request to
    # start an unsupported daemon. The dispatcher renders actionable help.
    dispatch_command(cli_args)
