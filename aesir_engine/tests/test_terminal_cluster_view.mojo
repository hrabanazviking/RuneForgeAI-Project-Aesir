"""Bounded cluster atoms and sanitized terminal-cell estimates."""

from cli.terminal_view import terminal_preview_atom
from cli.chat_history import safe_turn_preview


def check_atom(text: String, cells: Int) raises:
    var atom = terminal_preview_atom(text, 0)
    if (atom.fragment != text or atom.byte_count != text.byte_length()
            or atom.cells != cells):
        raise Error("terminal atom split or mischarged a bounded cluster")


def main() raises:
    check_atom("e\u0301", 1)
    check_atom("界\u0301", 2)
    check_atom("🛡️", 2)
    check_atom("👩🏽‍💻", 2)
    check_atom("👩‍👩‍👧‍👦", 2)
    check_atom("🇺🇸", 2)
    check_atom("1️⃣", 2)
    var flags = String("🇺🇸🇨🇦")
    var first = terminal_preview_atom(flags, 0)
    var second = terminal_preview_atom(flags, first.byte_count)
    if first.fragment != "🇺🇸" or second.fragment != "🇨🇦":
        raise Error("adjacent flags merged into one atom")
    var odd = String("🇺🇸🇨")
    var tail = terminal_preview_atom(odd, first.byte_count)
    if tail.fragment != "🇨" or tail.cells != 2:
        raise Error("odd regional-indicator tail was lost")
    var unsafe = String("A\u200dB\u202eC\x1bD")
    if (terminal_preview_atom(unsafe, 1).fragment != " "
            or terminal_preview_atom(unsafe, 5).fragment != " "
            or terminal_preview_atom(unsafe, 9).fragment != " "):
        raise Error("standalone joiner, bidi or escape leaked")
    if safe_turn_preview("abc👩‍👩‍👧‍👦uvwxyz", 8) != "abc👩‍👩‍👧‍👦...":
        raise Error("preview split a joined emoji at its budget")
    print("cluster preview atoms, width and control safety: PASS")
