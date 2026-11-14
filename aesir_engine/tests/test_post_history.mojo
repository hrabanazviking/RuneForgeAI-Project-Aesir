"""Pure post-history anchor composition (HS-5); no model or device evidence."""
from core.post_history import resolve_post_history, apply_post_history


def test_post_history_resolution() raises:
    if resolve_post_history("req", True, "cfg") != "req":
        raise Error("present request value must win")
    if resolve_post_history("", True, "cfg") != "":
        raise Error("explicitly empty request value must disable the anchor")
    if resolve_post_history("req", False, "cfg") != "cfg":
        raise Error("absent request value must fall back to the configured anchor")
    if resolve_post_history("", False, "") != "":
        raise Error("no anchor anywhere must stay empty")


def test_post_history_application() raises:
    var history = "User: hello\nAssistant: hi\nUser: again\n"
    var composed = apply_post_history(history, "Stay in character.")
    if composed != history + "Stay in character.":
        raise Error("anchor must land in final position after the history")
    if history != "User: hello\nAssistant: hi\nUser: again\n":
        raise Error("composition must not mutate the stored history")
    if "Stay in character." in history:
        raise Error("stored history must never contain the anchor")
    var bare = apply_post_history("User: hi", "Anchor.")
    if bare != "User: hi\nAnchor.":
        raise Error("anchor must be separated from a prompt without a trailing newline")
    if apply_post_history(history, "") != history:
        raise Error("empty anchor must leave the prompt unchanged")


def main() raises:
    test_post_history_resolution()
    test_post_history_application()
    print("PASS post-history anchor resolution and composition")
