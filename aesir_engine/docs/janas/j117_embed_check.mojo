"""J-117 verification companion — the embeddable surface, executed.

Tier 2 of the embedding example's verification (the J-117 doc,
protocol section 0.2): this driver imports the library modules
the AesirEngine facade itself delegates to and RUNS their
answering behaviour with no model and no inference:

  - core/state_vault.StateVault — the machinery behind the
    facade's save_checkpoint / load_checkpoint: a save -> load
    round-trip against a staging file, values compared exactly,
    and a negative position refused;
  - loader/chat_template.RuneChatTemplate + ChatMessage — the
    machinery behind the facade's generate_chat: a two-turn
    conversation formatted in the chatml style, asserted
    byte-for-byte against the formatter's own contract, and an
    invalid role refused;
  - core/session.SessionContext — the context the facade's
    generate_session validates and binds to: constructed,
    validated, cancelled cooperatively, and an empty id refused.

This proves, by execution, that the in-process embeddable
surface a Mojo host links today answers on this machine. It
does NOT claim the facade tier ran: AesirEngine construction
needs a validated GGUF model, and model-bound generation is
deferred-with-reason in the J-117 doc (section 7). The facade
example itself is j117_example_embed.mojo.

Run (the road's staging shape, from the repo root):
  mojo build -I aesir_engine -I . \\
      aesir_engine/docs/janas/j117_embed_check.mojo -o embed_check
  ./embed_check <staging-dir>
"""

from std.sys import argv

from core.session import SessionContext
from core.state_vault import StateVault
from loader.chat_template import ChatMessage, RuneChatTemplate


def expect(cond: Bool, what: String) raises:
    if not cond:
        raise Error("embed check failed: " + what)


def check_state_vault(staging: String) raises:
    var path = staging + String("/j117_checkpoint.txt")
    var vault = StateVault()
    var saved = vault.save_checkpoint_to_disk(path, 41, 7)
    expect(saved.is_valid, "saved checkpoint is valid")
    expect(saved.token_pos == 41, "saved token_pos is 41")
    expect(saved.prompt_tokens_count == 7, "saved prompt count is 7")
    expect(saved.checksum != 0, "saved checksum is nonzero")

    var fresh = StateVault()
    var loaded = fresh.load_checkpoint_from_disk(path)
    expect(loaded.is_valid, "loaded checkpoint is valid")
    expect(loaded.token_pos == 41, "loaded token_pos survives the round trip")
    expect(
        loaded.prompt_tokens_count == 7,
        "loaded prompt count survives the round trip",
    )
    expect(
        loaded.checksum == saved.checksum,
        "loaded checksum equals the saved checksum",
    )

    var refused = False
    try:
        var bad = StateVault()
        _ = bad.save_checkpoint_to_disk(path, -1, 7)
    except:
        refused = True
    expect(refused, "a negative position is refused, not saved")
    print("PASS: state vault round trip (the save/load_checkpoint machinery)")


def check_chat_template() raises:
    var messages = List[ChatMessage]()
    messages.append(ChatMessage(String("system"), String("Be brief.")))
    messages.append(ChatMessage(String("user"), String("Hello, forge.")))
    var template = RuneChatTemplate(String("chatml"))
    var prompt = template.format_chat(messages)
    var nl = String("\n")
    var expected = (
        String("<|im_start|>system") + nl + String("Be brief.")
        + String("<|im_end|>") + nl
        + String("<|im_start|>user") + nl + String("Hello, forge.")
        + String("<|im_end|>") + nl
        + String("<|im_start|>assistant") + nl
    )
    expect(
        prompt == expected,
        "chatml formatting matches the formatter's own contract",
    )

    var refused = False
    try:
        var bad = List[ChatMessage]()
        bad.append(ChatMessage(String("narrator"), String("Once...")))
        _ = template.format_chat(bad)
    except:
        refused = True
    expect(refused, "an unlisted role is refused by message validation")
    print("PASS: chat template formatting (the generate_chat machinery)")


def check_session() raises:
    var session = SessionContext(String("j117-example"), 1024, UInt64(100))
    session.validate()
    expect(not session.is_cancelled, "a fresh session is not cancelled")
    expect(session.active_tokens == 0, "a fresh session has no active tokens")
    session.touch(UInt64(160))
    expect(
        session.is_expired(UInt64(200), UInt64(30)),
        "expiry honours the ttl against the touched timestamp",
    )
    session.cancel()
    expect(session.is_cancelled, "cooperative cancellation lands")

    var refused = False
    try:
        var bad = SessionContext(String(""), 1024, UInt64(0))
        bad.validate()
    except:
        refused = True
    expect(refused, "an empty session id is refused by validation")
    print("PASS: session context (the generate_session machinery)")


def main() raises:
    var args = argv()
    if len(args) < 2:
        raise Error("usage: embed_check <staging-dir>")
    var staging = String(args[1])
    check_state_vault(staging)
    check_chat_template()
    check_session()
    print("ALL PASS: embeddable library surface (3 groups)")
