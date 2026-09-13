#!/usr/bin/env python3
"""Export (never install) a Linux terminal desktop entry for this checkout."""
import argparse
import base64
from pathlib import Path
import sys

# Constant ASCII code, not a shell command. The checkout path is encoded data so
# Unicode, percent field codes and reserved desktop Exec characters stay literal.
BOOTSTRAP = "import base64,os,sys; p=base64.b64decode(sys.argv[1]).decode('utf-8'); os.execv(sys.executable,[sys.executable,p,'--','home'])"


def desktop_entry(launcher):
    payload = base64.b64encode(str(launcher.resolve()).encode("utf-8")).decode("ascii")
    return ("[Desktop Entry]\nType=Application\nName=Aesir Home\n"
            "Comment=Open the prepared local AI terminal\nTerminal=true\n"
            "Icon=utilities-terminal\nCategories=Utility;\n"
            f'Exec=/usr/bin/python3 -c "{BOOTSTRAP}" {payload}\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, help="new .desktop file; omitted prints a preview")
    options = parser.parse_args()
    try:
        if not Path("/usr/bin/python3").is_file():
            raise ValueError("This desktop entry requires /usr/bin/python3 in Linux/WSL")
        if options.output and options.output.suffix != ".desktop":
            raise ValueError("Output must end in .desktop")
        content = desktop_entry(Path(__file__).with_name("launch.py"))
        if options.output:
            with options.output.open("x", encoding="utf-8", newline="\n") as stream:
                stream.write(content)
            print(f"Exported {options.output}; no desktop settings were changed.")
        else:
            print(content, end="")
        return 0
    except (OSError, ValueError) as error:
        print(f"Aesir desktop export: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
