# Project AESIR's Hailo-10H command line entry point.

from std.sys import argv
from cli.hailo_commands import dispatch_command


def main() raises:
    var raw_args = argv()
    var cli_args = List[String]()

    for index in range(1, len(raw_args)):
        cli_args.append(raw_args[index])
    dispatch_command(cli_args)
