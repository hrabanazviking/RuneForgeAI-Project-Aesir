"""Pure session-residency continuation predicate (HS-6); no device evidence."""
from core.session_residency import resident_delta


def test_session_residency_delta() raises:
    # Resident store: the full seed request (one user message) plus the
    # reply the serve generated for it.
    var stored_roles = List[String]()
    stored_roles.append("user")
    var stored_contents = List[String]()
    stored_contents.append("hello")
    var reply = "hi there"
    # Continuation: seed messages + [assistant: the generated reply] +
    # [user: the new message].
    var next_roles = List[String]()
    next_roles.append("user")
    next_roles.append("assistant")
    next_roles.append("user")
    var next_contents = List[String]()
    next_contents.append("hello")
    next_contents.append("hi there")
    next_contents.append("how are you")
    if resident_delta(stored_roles, stored_contents, reply, next_roles, next_contents) != "how are you":
        raise Error("exact continuation must yield the new user message")
    # Edited history: an earlier message differs.
    var edited = next_contents.copy()
    edited[0] = "hello!"
    if resident_delta(stored_roles, stored_contents, reply, next_roles, edited) != "":
        raise Error("edited history must not continue")
    # The assistant echo is not the reply the serve generated.
    var wrong_reply = next_contents.copy()
    wrong_reply[1] = "hi there!"
    if resident_delta(stored_roles, stored_contents, reply, next_roles, wrong_reply) != "":
        raise Error("a foreign assistant text must not continue")
    # Missing the assistant echo entirely.
    var short_roles = List[String]()
    short_roles.append("user")
    short_roles.append("user")
    var short_contents = List[String]()
    short_contents.append("hello")
    short_contents.append("how are you")
    if resident_delta(stored_roles, stored_contents, reply, short_roles, short_contents) != "":
        raise Error("a request without the reply echo must not continue")
    # No resident state: nothing can continue.
    var empty_roles = List[String]()
    var empty_contents = List[String]()
    if resident_delta(empty_roles, empty_contents, "", next_roles, next_contents) != "":
        raise Error("an empty resident store must not continue")


def main() raises:
    test_session_residency_delta()
    print("PASS session residency continuation predicate")
