"""Hardening tests for loader/chat_template.mojo (R010-R013)."""
from loader.chat_template import ChatMessage, RuneChatTemplate


def count_occurrences(haystack: String, needle: String) -> Int:
    if needle == "":
        return 0
    return len(haystack.split(needle)) - 1


def raw_control_spellings() -> List[String]:
    var spellings = List[String]()
    spellings.append("<|im_start|>")
    spellings.append("<|im_end|>")
    spellings.append("<start_of_turn>")
    spellings.append("<end_of_turn>")
    spellings.append("<|start_header_id|>")
    spellings.append("<|end_header_id|>")
    spellings.append("<|eot_id|>")
    spellings.append("<|begin_of_text|>")
    spellings.append("[INST]")
    spellings.append("[/INST]")
    spellings.append("<<SYS>>")
    spellings.append("<</SYS>>")
    return spellings^


def neutralized_control_spellings() -> List[String]:
    var neutralized = List[String]()
    neutralized.append("[im_start]")
    neutralized.append("[im_end]")
    neutralized.append("[start_of_turn]")
    neutralized.append("[end_of_turn]")
    neutralized.append("[start_header_id]")
    neutralized.append("[end_header_id]")
    neutralized.append("[eot_id]")
    neutralized.append("[begin_of_text]")
    neutralized.append("[[INST]]")
    neutralized.append("[[/INST]]")
    neutralized.append("[SYS]")
    neutralized.append("[/SYS]")
    return neutralized^


def framing_tokens_for(style: String) -> List[String]:
    var tokens = List[String]()
    if style == "gemma":
        tokens.append("<start_of_turn>")
        tokens.append("<end_of_turn>")
    elif style == "chatml":
        tokens.append("<|im_start|>")
        tokens.append("<|im_end|>")
    elif style == "llama3":
        tokens.append("<|begin_of_text|>")
        tokens.append("<|start_header_id|>")
        tokens.append("<|end_header_id|>")
        tokens.append("<|eot_id|>")
    elif style == "llama2":
        tokens.append("[INST]")
        tokens.append("[/INST]")
        tokens.append("<<SYS>>")
        tokens.append("<</SYS>>")
    return tokens^


def injection_messages(dirty_content: String) -> List[ChatMessage]:
    var messages = List[ChatMessage]()
    messages.append(ChatMessage("system", "You are a helpful assistant."))
    messages.append(ChatMessage("user", dirty_content))
    return messages^


def format_by_style(style: String, messages: List[ChatMessage]) raises -> String:
    var tpl = RuneChatTemplate(style)
    return tpl.format_chat(messages)


def test_escape_control_tokens_all_families() raises:
    print("--- Testing escape_control_tokens neutralizes all family control spellings ---")
    var raws = raw_control_spellings()
    var neus = neutralized_control_spellings()

    # One user payload containing EVERY control spelling from all families.
    var dirty = String("")
    for i in range(len(raws)):
        if i > 0:
            dirty += " "
        dirty += raws[i]

    var styles = List[String]()
    styles.append("gemma")
    styles.append("chatml")
    styles.append("llama3")
    styles.append("llama2")

    for s in range(len(styles)):
        var style = styles[s]
        var out_dirty = format_by_style(style, injection_messages(dirty))
        var out_clean = format_by_style(style, injection_messages("clean content here"))

        # 1. Every control spelling must appear only in its neutralized form.
        for k in range(len(raws)):
            if neus[k] not in out_dirty:
                raise Error("style " + style + ": control spelling " + raws[k]
                            + " was not neutralized to " + neus[k])

        # 2. Scrub neutralized forms and framing tokens: no raw spelling may survive.
        var scrubbed = out_dirty
        for k in range(len(neus)):
            scrubbed = scrubbed.replace(neus[k], "")
        var framing = framing_tokens_for(style)
        for f in range(len(framing)):
            scrubbed = scrubbed.replace(framing[f], "")
        for k in range(len(raws)):
            if raws[k] in scrubbed:
                raise Error("style " + style + ": raw control spelling " + raws[k]
                            + " survived escaping")

        # 3. Framing token counts must be identical to the clean-content baseline.
        var scrubbed_dirty = out_dirty
        for k in range(len(neus)):
            scrubbed_dirty = scrubbed_dirty.replace(neus[k], "")
        for f in range(len(framing)):
            var token = framing[f]
            var dirty_count = count_occurrences(scrubbed_dirty, token)
            var clean_count = count_occurrences(out_clean, token)
            if dirty_count != clean_count:
                raise Error("style " + style + ": framing token " + token
                            + " count changed (" + String(dirty_count)
                            + " vs " + String(clean_count) + ")")

    print("escape_control_tokens all families: PASS")


def test_detect_template_family_strong_first() raises:
    print("--- Testing detect_template_family strong-marker ordering ---")
    # ChatML framing plus a mere mention of the word "gemma" must stay chatml.
    if RuneChatTemplate.detect_template_family(
            "{{ '<|im_start|>' + role }} gemma model chat template") != "chatml":
        raise Error("detect_template_family misdetected chatml template mentioning gemma")
    # Bare word "gemma" alone is the documented weak heuristic.
    if RuneChatTemplate.detect_template_family("a gemma model chat template") != "gemma":
        raise Error("detect_template_family lost bare-word gemma heuristic")
    # Strong markers per family.
    if RuneChatTemplate.detect_template_family("{{ '<|start_header_id|>' + role }}") != "llama3":
        raise Error("detect_template_family failed on <|start_header_id|>")
    if RuneChatTemplate.detect_template_family("[INST] do the thing [/INST]") != "llama2":
        raise Error("detect_template_family failed on [INST]")
    if RuneChatTemplate.detect_template_family("{{ '<|turn>' + role + '<turn|>' }}") != "gemma":
        raise Error("detect_template_family failed on <|turn>/<turn|>")
    if RuneChatTemplate.detect_template_family("{{ '<start_of_turn>' + role }}") != "gemma":
        raise Error("detect_template_family failed on <start_of_turn>")
    # Weak bare "INST" fallback still routes to llama2.
    if RuneChatTemplate.detect_template_family("template with INST mentioned") != "llama2":
        raise Error("detect_template_family lost bare-word INST heuristic")
    # Empty and garbage templates stay unknown.
    if RuneChatTemplate.detect_template_family("") != "unknown":
        raise Error("detect_template_family misdetected empty template")
    if RuneChatTemplate.detect_template_family("{{ messages | join }}") != "unknown":
        raise Error("detect_template_family misdetected garbage template")
    print("detect_template_family strong-marker ordering: PASS")


def test_format_llama2_multiple_system_messages() raises:
    print("--- Testing format_llama2 multiple system message concatenation ---")
    var tpl = RuneChatTemplate("llama2")

    # Two system messages: both must appear, joined by "\n\n", merged into the
    # first [INST] turn.
    var two_system = List[ChatMessage]()
    two_system.append(ChatMessage("system", "SYS_ONE"))
    two_system.append(ChatMessage("system", "SYS_TWO"))
    two_system.append(ChatMessage("user", "hi"))
    var out_two = tpl.format_llama2(two_system)
    if "SYS_ONE" not in out_two or "SYS_TWO" not in out_two:
        raise Error("format_llama2 dropped a system message: got '" + out_two + "'")
    if "<<SYS>>\nSYS_ONE\n\nSYS_TWO\n<</SYS>>" not in out_two:
        raise Error("format_llama2 did not concatenate system blocks with \\n\\n: got '"
                    + out_two + "'")
    if "hi [/INST]" not in out_two:
        raise Error("format_llama2 combined system block did not merge into first [INST] turn")

    # Single system message: byte-identical to the historical output.
    var one_system = List[ChatMessage]()
    one_system.append(ChatMessage("system", "You are a helpful assistant."))
    one_system.append(ChatMessage("user", "Hello!"))
    var out_one = tpl.format_llama2(one_system)
    var expected = "[INST] <<SYS>>\nYou are a helpful assistant.\n<</SYS>>\n\nHello! [/INST]"
    if out_one != expected:
        raise Error("format_llama2 single-system output changed: got '" + out_one + "'")
    print("format_llama2 multiple system messages: PASS")


def test_format_chat_unknown_style_raises() raises:
    print("--- Testing format_chat rejects unknown styles ---")
    var messages = List[ChatMessage]()
    messages.append(ChatMessage("user", "hi"))

    var tpl = RuneChatTemplate("bogus")
    var raised = False
    var message = String("")
    try:
        _ = tpl.format_chat(messages)
    except e:
        raised = True
        message = String(e)
    if not raised:
        raise Error("format_chat silently formatted unknown style 'bogus'")
    if "bogus" not in message:
        raise Error("format_chat error did not name the style: got '" + message + "'")

    # Every known style must still format without raising.
    var known = List[String]()
    known.append("gemma")
    known.append("gemma3")
    known.append("llama3")
    known.append("llama2")
    known.append("chatml")
    for i in range(len(known)):
        var out = format_by_style(known[i], messages)
        if out.byte_length() == 0:
            raise Error("format_chat produced empty output for known style " + known[i])
    print("format_chat unknown style rejection: PASS")


def main() raises:
    test_escape_control_tokens_all_families()
    test_detect_template_family_strong_first()
    test_format_llama2_multiple_system_messages()
    test_format_chat_unknown_style_raises()
