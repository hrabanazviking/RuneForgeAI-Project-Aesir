# J-123 refusal driver: a defective synthetic qwen3next GGUF must
# be refused by the tree's own loader, by name.
# Usage: j123_refuse <file.gguf> <expected_error_substring>
# Exit 0 iff mmap_and_load raises an error containing the
# substring; the refusal text is printed verbatim. No inference.

from std.sys import argv

from core.mimir_well import MimirWell
from loader.gguf import GGUFSeer


def main() raises:
    var args = argv()
    if len(args) != 3:
        raise Error("usage: j123_refuse <file.gguf> <expected_error_substring>")
    var seer = GGUFSeer(args[1])
    var well = MimirWell(4 * 1024 * 1024)
    var refused = False
    try:
        seer.mmap_and_load(well)
    except e:
        refused = True
        print("REFUSAL:", e)
        if args[2] not in String(e):
            raise Error(
                "refusal did not name the expected tensor: " + args[2]
            )
    if not refused:
        raise Error("loader admitted a defective qwen3next fixture")
    print("REFUSAL DRIVER: ALL PASS")
