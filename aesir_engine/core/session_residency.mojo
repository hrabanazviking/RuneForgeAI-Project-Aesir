"""Session residency continuation predicate for the native serve (HS-6).

A resident session keeps its committed token stream -- prompt and generated
tokens alike -- in the engine session's KV across requests. A follow-up
request is a continuation only when it carries the resident conversation
verbatim, extended by exactly the assistant reply the serve generated and
one new user message. Anything else (edited history, a different assistant
text, extra or missing messages) is not a continuation: the serve falls
back to the stateless path and re-evaluates the full resent prompt, where
the exact-prefix cache still applies. The seam loss of the stateless path
-- re-tokenizing a resent string drops a few tokens where the new text
joins the old -- cannot occur here, because the prior tokens are never
re-tokenized: only the new user message is tokenized, at the position the
conversation already reached.
"""


def resident_delta(resident_roles: List[String], resident_contents: List[String],
                   resident_reply: String,
                   roles: List[String], contents: List[String]) -> String:
    """Returns the new user message content when roles/contents extend the
    resident conversation by exactly the generated reply plus one user
    message; returns "" for every other shape."""
    var stored = len(resident_roles)
    if len(resident_contents) != stored:
        return ""
    if len(roles) != stored + 2 or len(contents) != stored + 2:
        return ""
    for i in range(stored):
        if roles[i] != resident_roles[i] or contents[i] != resident_contents[i]:
            return ""
    if roles[stored] != "assistant" or contents[stored] != resident_reply:
        return ""
    if roles[stored + 1] != "user":
        return ""
    return contents[stored + 1]
