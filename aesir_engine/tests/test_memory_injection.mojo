"""Pure stable-order memory injection contract (HS-7); no device evidence."""
from core.memory_injection import MemoryBlock, render_memory


def test_memory_injection_render() raises:
    var blocks = List[MemoryBlock]()
    blocks.append(MemoryBlock("home", "The user lives in Indiana.", 2))
    blocks.append(MemoryBlock("user-name", "The user is Volmarr.", 1))
    blocks.append(MemoryBlock("aardvark", "Same order, earlier key.", 1))
    # Deterministic (order, key) order regardless of arrival order.
    var rendered = render_memory(blocks, 100000)
    var expected = (
        "[aardvark] Same order, earlier key.\n"
        + "[user-name] The user is Volmarr.\n"
        + "[home] The user lives in Indiana."
    )
    if rendered != expected:
        raise Error("render must sort by (order, key): " + rendered)
    # Budget admits whole blocks only: the first line costs
    # ceil(35/4)+1 = 10 tokens; a budget of 10 admits exactly it.
    var tight = render_memory(blocks, 10)
    if tight != "[aardvark] Same order, earlier key.":
        raise Error("budget must admit whole blocks only: " + tight)
    # Zero budget admits nothing; no blocks render empty.
    if render_memory(blocks, 0) != "":
        raise Error("zero budget must render empty")
    var none = List[MemoryBlock]()
    if render_memory(none, 100) != "":
        raise Error("no blocks must render empty")


def test_memory_injection_append_stability() raises:
    var turn_n = List[MemoryBlock]()
    turn_n.append(MemoryBlock("user-name", "The user is Volmarr.", 1))
    turn_n.append(MemoryBlock("home", "The user lives in Indiana.", 2))
    var turn_n1 = turn_n.copy()
    turn_n1.append(MemoryBlock("project", "Current project: Aesir.", 3))
    var render_n = render_memory(turn_n, 100000)
    var render_n1 = render_memory(turn_n1, 100000)
    # A pure append must leave turn N's render a byte-for-byte prefix.
    if not render_n1.startswith(render_n):
        raise Error("appended render must extend the prior render byte-for-byte")
    if render_n1.byte_length() <= render_n.byte_length():
        raise Error("appended render must grow")


def main() raises:
    test_memory_injection_render()
    test_memory_injection_append_stability()
    print("PASS memory injection render + append stability")
