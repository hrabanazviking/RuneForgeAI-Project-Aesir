"""Stable-order memory injection for the native serve (HS-7).

Callers attach memory blocks (key, text, order) to a request. The serve
renders the admitted blocks into the system position of the composed
prompt, so the injected text becomes part of the cached prefix.

Contract:
- Deterministic order: blocks render sorted by (order, key), regardless
  of the order they arrived in.
- Token budget: a block is admitted whole or not at all. The admission
  estimate is ceil(bytes/4) of the rendered line plus one token of
  newline allowance -- a documented estimate, not an exact tokenizer
  count. An oversize block is skipped; later, smaller blocks are still
  considered.
- Append-stability: when blocks are only appended (a new block sorts
  after the existing ones), the render for turn N is a byte-for-byte
  prefix of the render for turn N+1, so the cached prefix never churns.
"""


struct MemoryBlock(Copyable, ImplicitlyCopyable):
    var key: String
    var text: String
    var order: Int

    def __init__(out self, key: String, text: String, order: Int):
        self.key = key
        self.text = text
        self.order = order


def estimate_tokens(text: String) -> Int:
    """Admission estimate: one token per four bytes, rounded up."""
    return (text.byte_length() + 3) // 4


def render_memory(blocks: List[MemoryBlock], budget_tokens: Int) -> String:
    """Renders admitted blocks as '[key] text' lines in stable order."""
    var ordered = blocks.copy()
    for i in range(1, len(ordered)):
        var j = i
        while j > 0 and (
            ordered[j - 1].order > ordered[j].order
            or (ordered[j - 1].order == ordered[j].order
                and ordered[j - 1].key > ordered[j].key)
        ):
            var tmp = ordered[j - 1].copy()
            ordered[j - 1] = ordered[j].copy()
            ordered[j] = tmp^
            j -= 1
    var out = String("")
    var used = 0
    for block in ordered:
        var line = "[" + block.key + "] " + block.text
        var cost = estimate_tokens(line) + 1
        if used + cost > budget_tokens:
            continue
        if out != "":
            out += "\n"
        out += line
        used += cost
    return out
