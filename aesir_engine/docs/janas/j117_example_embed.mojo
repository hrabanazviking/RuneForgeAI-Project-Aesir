"""J-117 worked example 2 — a program embedding the engine.

A host program embedding Aesir through the Mojo-native door (the
door J-115's library audit graded PROVEN as an in-tree, unversioned
Mojo API): it imports the AesirEngine facade from the `aesir`
module, constructs it over a GGUF model path given as its first
argument, and drives the answering entries a small chat host needs:

  - generate_chat(messages, config) — multi-turn chat over
    ChatMessage turns (the facade formats them through
    loader/chat_template and runs generation);
  - generate(prompt) — the raw-prompt compatibility facade
    (a verified 32-token greedy request);
  - save_checkpoint / load_checkpoint — the session's position
    marker, persisted through core/state_vault (a marker only:
    it does not capture model, KV, or sampler state, and this
    example says so where it uses it).

THE RESERVED FIVE — named here because an honest example must not
pretend to use them. On the facade's own face (J-115 section 2.4)
these entries RAISE not-implemented / unavailable, and this
example calls NONE of them:

  - ingest_document            (no validated embedding model)
  - join_swarm_cluster         (no secure transport)
  - dispatch_swarm_inference   (no remote execution transport)
  - speculative_generate       (facade-level speculation
                                unimplemented; Part V's draft
                                machinery lives in its own modules)
  - generate_tokens_with_grammar (grammar-held generation
                                unimplemented at the facade)

FAIL-CLOSED MANNERS. With no argument the program prints its
usage and stops. Over a path that does not load, the facade's
construction raises; the program catches the raise, reports it
as the refusal it is, and exits without inventing any text.
Nothing in this example generates unless a real model loaded.

Build and run (from the repo root, the road's staging shape):
  mojo build -I aesir_engine -I . \\
      aesir_engine/docs/janas/j117_example_embed.mojo -o embed_example
  ./embed_example <model.gguf> [checkpoint-path]

Verification in J-117: this file's compilation was attempted on
the VM at the lightest target and its outcome filed in
j117_test_output.txt exactly as it landed; the model-bound run
is deferred-with-reason (VM inference gate) with its recipe in
the J-117 doc section 7. The embeddable library surface the
facade delegates to is executed separately by
j117_embed_check.mojo — the two tiers are never conflated.
"""

from std.sys import argv

from aesir import AesirEngine, GenerationConfig
from loader.chat_template import ChatMessage


def _usage() -> None:
    print("usage: embed_example <model.gguf> [checkpoint-path]")
    print("Reserved facade entries this example does not use:")
    print("  ingest_document, join_swarm_cluster,")
    print("  dispatch_swarm_inference, speculative_generate,")
    print("  generate_tokens_with_grammar")


def main() raises:
    var args = argv()
    if len(args) < 2:
        _usage()
        return
    var model_path = String(args[1])
    var checkpoint_path = String("j117_example_checkpoint.txt")
    if len(args) >= 3:
        checkpoint_path = String(args[2])

    var loaded = False
    try:
        var engine = AesirEngine(model_path)
        loaded = True

        var config = GenerationConfig(
            max_new_tokens=32, temperature=0.0, repetition_penalty=1.0
        )

        var messages = List[ChatMessage]()
        messages.append(
            ChatMessage(
                String("system"),
                String("You are a concise assistant."),
            )
        )
        messages.append(
            ChatMessage(
                String("user"),
                String("Name the hall where the servers live."),
            )
        )
        var chat_result = engine.generate_chat(messages, config)
        print("chat reply:", chat_result.text)
        print(
            "chat stop reason:", chat_result.stop_reason,
            "| generated tokens:", chat_result.generated_token_count(),
        )

        var raw_reply = engine.generate(
            String("The forge was lit at dawn, and")
        )
        print("raw completion:", raw_reply)

        var saved = engine.save_checkpoint(checkpoint_path, 0, 2)
        print(
            "checkpoint saved: valid =", saved.is_valid,
            "| checksum =", saved.checksum,
        )
        var restored = engine.load_checkpoint(checkpoint_path)
        print(
            "checkpoint loaded: valid =", restored.is_valid,
            "| token_pos =", restored.token_pos,
            "| prompt_count =", restored.prompt_tokens_count,
        )
    except:
        print(
            "AesirEngine refused the model path (fail-closed):",
            model_path,
        )
        print("No generation was attempted or invented.")
    if not loaded:
        return
