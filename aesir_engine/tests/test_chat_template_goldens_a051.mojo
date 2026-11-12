"""A-051: Chat-template goldens.

Per-family template rendering vs golden files under
aesir_engine/tests/goldens/chat_template/. The fixed RAW conversation
(system / user / assistant / user, plain contents with no surrounding
whitespace and no control-token spellings) is rendered through
RuneChatTemplate for each family style and compared BYTE-EXACT against
the committed golden.

Golden provenance (see hidden_files/A051_LEDGER.md): each golden was
derived from the family's canonical published template form and
cross-checked against the byte-exact expectations already pinned in
tests/test_inference.mojo for the shared two-message prefix (ChatML,
Llama-3, Llama-2) -- NOT snapshotted blind from current code output.
Documented divergences between the engine's string renderers and the
published canonical forms (all filed in the A-051 ledger):
- BOS is a tokenizer-level concern in this engine
  (loader/tokenizer.mojo encode(add_bos=...)); the string renderers
  emit no <s>/<bos> token, except Llama-3 whose canonical string form
  itself begins with <|begin_of_text|>.
- Llama-2: the canonical form appends </s> after an assistant turn;
  the engine renderer leaves generation/EOS to the sampler and pads
  the assistant turn with spaces instead.
- Gemma: the canonical template trims message content and has no
  system role; the engine maps system -> user and does not trim.
  The fixed conversation is trim-invariant, so the golden is exact
  for it; the system mapping is pinned deliberately by the golden.
- Gemma 4 is NOT string-rendered here: its prompt construction is
  token-level in loader/gemma4_tokenizer.mojo (<|turn>/<turn|>) and
  is covered by the Gemma 4 tokenizer parity fixtures. The A-051
  routing case pins only its metadata selection.
- Mistral has no dedicated renderer in RuneChatTemplate (its [INST]
  templates detect as llama2); no Mistral golden is claimed.

ORACLE RULE (roadmap A-051): these goldens are RAW renderings kept
for template tests only -- never as inference-grading inputs.
"""

from loader.chat_template import (
    ChatMessage,
    NativeTokenizerSelection,
    RuneChatTemplate,
)


def _fixed_conversation() -> List[ChatMessage]:
    var messages = List[ChatMessage]()
    messages.append(ChatMessage("system", "You are a helpful assistant."))
    messages.append(ChatMessage("user", "Hello!"))
    messages.append(ChatMessage("assistant", "Hi there."))
    messages.append(ChatMessage("user", "What is 2+2?"))
    return messages^


def _read_golden(name: String) raises -> String:
    # The E-MASTER suite runs from the repository root; the fallback
    # covers running with aesir_engine/ as the working directory.
    try:
        with open("aesir_engine/tests/goldens/chat_template/" + name, "r") as f:
            return f.read()
    except read_error:
        try:
            with open("tests/goldens/chat_template/" + name, "r") as f:
                return f.read()
        except fallback_error:
            raise Error(
                "A051: golden file unreadable: " + name + " ("
                + String(read_error) + " / " + String(fallback_error) + ")"
            )


def _assert_golden(style: String, golden_name: String) raises:
    var tpl = RuneChatTemplate(style)
    var rendered = tpl.format_chat(_fixed_conversation())
    var golden = _read_golden(golden_name)
    if rendered != golden:
        raise Error(
            "A051: golden mismatch for style " + style
            + " (rendered " + String(rendered.byte_length())
            + " bytes, golden " + String(golden.byte_length()) + " bytes)"
        )
    print("A051 golden " + style + ": PASS (" + String(golden.byte_length()) + " bytes)")


def test_chat_template_golden_chatml() raises:
    """Qwen family (qwen2/qwen3, ChatML): byte-exact vs golden."""
    _assert_golden("chatml", "chatml.txt")


def test_chat_template_golden_llama3() raises:
    """Llama family (llama arch, Llama-3 headers): byte-exact vs golden."""
    _assert_golden("llama3", "llama3.txt")


def test_chat_template_golden_llama2() raises:
    """Llama-2 [INST] form: byte-exact vs golden."""
    _assert_golden("llama2", "llama2.txt")


def test_chat_template_golden_gemma() raises:
    """Gemma family (gemma/gemma2 text form; style gemma3 routes to the
    same renderer): byte-exact vs golden under both style names."""
    _assert_golden("gemma", "gemma.txt")
    _assert_golden("gemma3", "gemma.txt")


def test_chat_template_golden_family_routing() raises:
    """Metadata routing per A-048 architecture string: each family's
    canonical Jinja snippet detects to its style, and
    NativeTokenizerSelection binds the architectures the engine
    supports. Gemma 4 routing is metadata-level only (its rendering
    is token-level, loader/gemma4_tokenizer.mojo); qwen35 binds
    ChatML through the detected-template path (no arch-specific
    branch in the selection code -- filed in the A-051 ledger)."""
    if RuneChatTemplate.detect_template_family(
        "{{ '<|im_start|>' + role + '\n' + content + '<|im_end|>' }}"
    ) != "chatml":
        raise Error("A051: ChatML canonical snippet misdetected")
    if RuneChatTemplate.detect_template_family(
        "{{ '<|start_header_id|>' + role + '<|end_header_id|>' }}"
    ) != "llama3":
        raise Error("A051: Llama-3 canonical snippet misdetected")
    if RuneChatTemplate.detect_template_family(
        "{{ bos_token + '[INST] ' + content + ' [/INST]' }}"
    ) != "llama2":
        raise Error("A051: Llama-2 canonical snippet misdetected")
    if RuneChatTemplate.detect_template_family(
        "{{ '<start_of_turn>' + role + '\n' + content + '<end_of_turn>' }}"
    ) != "gemma":
        raise Error("A051: Gemma canonical snippet misdetected")
    if RuneChatTemplate.detect_template_family(
        "{{ '<|turn>' + role + '\n' + content + '<turn|>' }}"
    ) != "gemma":
        raise Error("A051: Gemma 4 canonical snippet must detect as gemma family")

    var llama = NativeTokenizerSelection.from_metadata(
        "llama", "gpt2", "llama-bpe", "{{ '<|start_header_id|>' + role }}"
    )
    if llama.format_style != "llama3":
        raise Error("A051: llama arch did not select llama3 style")
    var qwen2 = NativeTokenizerSelection.from_metadata(
        "qwen2", "gpt2", "qwen2", "{{ '<|im_start|>' + role }}"
    )
    if qwen2.format_style != "chatml":
        raise Error("A051: qwen2 arch did not select chatml style")
    var qwen3 = NativeTokenizerSelection.from_metadata(
        "qwen3", "gpt2", "qwen2", "{{ '<|im_start|>' + role }}"
    )
    if qwen3.format_style != "chatml":
        raise Error("A051: qwen3 arch did not select chatml style")
    var qwen35 = NativeTokenizerSelection.from_metadata(
        "qwen35", "gpt2", "qwen2", "{{ '<|im_start|>' + role }}"
    )
    if qwen35.format_style != "chatml":
        raise Error("A051: qwen35 arch did not bind chatml via detection")
    var gemma4 = NativeTokenizerSelection.from_metadata(
        "gemma4", "gemma4", "", "{{ '<|turn>' + role + '<turn|>' }}"
    )
    if gemma4.format_style != "gemma" or gemma4.tokenizer_family != "Gemma BPE":
        raise Error("A051: gemma4 metadata selection mismatch")
    print("A051 golden family routing: PASS")
