# Self-contained commands for AESIR's direct Hailo-10H backend.

from std.ffi import external_call
from hailo10h_direct import Hailo10HSession


def json_escape(value: String) -> String:
    """Escape JSON controls while retaining complete UTF-8 sequences."""
    var bytes = value.as_bytes()
    var digits = String("0123456789abcdef")
    var result = String("")
    var start = 0
    for index in range(len(bytes)):
        var byte = bytes[index]
        if byte >= 0x20 and byte != 0x22 and byte != 0x5c:
            continue
        if index > start:
            result += String(value[byte=start:index])
        if byte == 0x22:
            result += "\\\""
        elif byte == 0x5c:
            result += "\\\\"
        elif byte == 0x0a:
            result += "\\n"
        elif byte == 0x0d:
            result += "\\r"
        elif byte == 0x09:
            result += "\\t"
        else:
            var high = Int((byte >> 4) & 0xf)
            var low = Int(byte & 0xf)
            result += "\\u00" + String(digits[byte=high:high + 1]) + String(digits[byte=low:low + 1])
        start = index + 1
    if start < len(bytes):
        result += String(value[byte=start:len(bytes)])
    return result


def _validate_string(value: String, name: String) raises:
    for byte in value.as_bytes():
        if byte == 0:
            raise Error(name + " contains an embedded NUL")


def _positive_uint32(value: String, option: String) raises -> Int:
    var bytes = value.as_bytes()
    if len(bytes) == 0:
        raise Error(option + " requires an integer between 1 and 4294967295")
    var result = 0
    for byte in bytes:
        if byte < 48 or byte > 57:
            raise Error(option + " requires an integer between 1 and 4294967295")
        var digit = Int(byte - 48)
        if result > (4294967295 - digit) // 10:
            raise Error(option + " must not exceed 4294967295")
        result = result * 10 + digit
    if result == 0:
        raise Error(option + " must be greater than zero")
    return result


struct HailoOptions(Movable):
    var model_path: String
    var prompt: String
    var max_tokens: Int
    var timeout_ms: Int
    var format: String

    def __init__(out self):
        self.model_path = String("")
        self.prompt = String("")
        self.max_tokens = 128
        self.timeout_ms = 60000
        self.format = String("text")


def _parse_options(args: List[String], command: String) raises -> HailoOptions:
    """Finish parsing and validating the request before opening any device."""
    var options = HailoOptions()
    var seen = List[String]()
    var has_prompt = False
    var positional = False
    var index = 1
    while index < len(args):
        var option = args[index]
        _validate_string(option, "argument")
        if option == "--":
            if command != "run" or index + 1 >= len(args):
                raise Error("-- requires a positional prompt for run")
            if has_prompt:
                raise Error("Specify the prompt once using --prompt or positional text")
            for word_index in range(index + 1, len(args)):
                _validate_string(args[word_index], "prompt")
                if word_index > index + 1:
                    options.prompt += " "
                options.prompt += args[word_index]
            has_prompt = True
            break
        if not option.startswith("-"):
            if command != "run":
                raise Error(command + " does not accept positional arguments")
            if has_prompt and not positional:
                raise Error("Specify the prompt once using --prompt or positional text")
            if positional:
                options.prompt += " "
            options.prompt += option
            has_prompt = True
            positional = True
            index += 1
            continue
        if option != "--model-path" and option != "--accel" and option != "--format" and option != "--max-tokens" and option != "--timeout-ms" and option != "--prompt":
            raise Error("Unknown " + command + " option: " + option + "; use aesir help " + command)
        if command == "hardware" and (option == "--max-tokens" or option == "--timeout-ms" or option == "--prompt"):
            raise Error(option + " is not a hardware option")
        if command == "chat" and option == "--prompt":
            raise Error("chat reads prompts from standard input; use run for --prompt")
        for previous in seen:
            if previous == option:
                raise Error("Duplicate option: " + option)
        seen.append(option)
        if index + 1 >= len(args):
            raise Error(option + " requires a value")
        var value = args[index + 1]
        _validate_string(value, option)
        if option != "--prompt" and value.startswith("--"):
            raise Error(option + " requires a value before " + value)
        if option == "--model-path":
            options.model_path = value
        elif option == "--accel":
            if value != "hailo10h":
                raise Error("--accel must be hailo10h for this AESIR build")
        elif option == "--format":
            if value != "text" and value != "json":
                raise Error("--format must be text or json")
            options.format = value
        elif option == "--max-tokens":
            options.max_tokens = _positive_uint32(value, option)
        elif option == "--timeout-ms":
            options.timeout_ms = _positive_uint32(value, option)
        elif option == "--prompt":
            if has_prompt:
                raise Error("Specify the prompt once using --prompt or positional text")
            options.prompt = value
            has_prompt = True
        index += 2
    if len(options.model_path.strip().as_bytes()) == 0:
        raise Error(command + " requires --model-path with an explicit Hailo model artifact")
    if command == "run" and (not has_prompt or len(options.prompt.strip().as_bytes()) == 0):
        raise Error("run requires nonempty --prompt text or a positional prompt")
    if command == "run" and options.prompt.byte_length() > 1048576:
        raise Error("run prompt must not exceed 1048576 UTF-8 bytes")
    return options^


def print_general_help():
    print("Project AESIR — direct Hailo-10H LLM inference")
    print("Usage: aesir <command> [options]")
    print("  run       Generate a response from an explicit prompt")
    print("  chat      Keep one Hailo model session across input lines")
    print("  hardware  Show live Hailo device, runtime, firmware and model information")
    print("  help [command], --help, --version")
    print("Run 'aesir help run' or 'aesir help chat' for options.")


def _print_command_help(command: String) raises:
    if command == "run":
        print("Usage: aesir run --model-path <artifact> [options] --prompt <text>")
        print("       aesir run --model-path <artifact> [options] <prompt words>")
    elif command == "chat":
        print("Usage: aesir chat --model-path <artifact> [options]")
        print("Input commands: /clear, /info, /help, /bye. EOF closes the session.")
    elif command == "hardware":
        print("Usage: aesir hardware --model-path <artifact> [--accel hailo10h] [--format text|json]")
        print("Opens the model and prints live device and model information as JSON.")
        return
    else:
        raise Error("Unknown command: " + command)
    print("Options: --accel hailo10h, --max-tokens <1..4294967295>,")
    print("         --timeout-ms <1..4294967295>, --format text|json")
    print("Defaults: max-tokens 128, timeout-ms 60000, format text.")
    print("The model artifact must be compatible with the installed Hailo runtime.")


def _print_response(response: String, provenance: String, format: String):
    if format == "json":
        print('{"response":"' + json_escape(response) + '","provenance":' + provenance + "}")
    else:
        print(response)


def _print_completed_response(response: String, session: Hailo10HSession, format: String):
    """Deliver the completed answer even if optional diagnostics fail."""
    if format != "json":
        print(response)
        return
    var provenance: String
    try:
        provenance = session.describe()
    except error:
        provenance = '{"diagnostics_error":"' + json_escape(String(error)) + '"}'
    _print_response(response, provenance, format)


def _read_line() raises -> Tuple[Bool, String]:
    var bytes = List[Byte]()
    var too_long = False
    while True:
        var character = external_call["getchar", Int32]()
        if character == -1:
            if len(bytes) == 0 and not too_long:
                return (False, String(""))
            break
        if character == 10:
            break
        if len(bytes) < 1048576:
            bytes.append(Byte(character))
        else:
            # Drain the rejected input line so the next turn starts cleanly.
            too_long = True
    if too_long:
        raise Error("Chat input exceeds 1048576 UTF-8 bytes; shorten the prompt and retry")
    if len(bytes) > 0 and bytes[len(bytes) - 1] == 13:
        _ = bytes.pop()
    if len(bytes) == 0:
        return (True, String(""))
    return (True, String(from_utf8=bytes))


def _print_chat_error(message: String, format: String):
    if format == "json":
        print('{"error":"' + json_escape(message) + '","action":"Retry or use /clear when reset is required; restart chat when reopen is required"}')
    else:
        print("Request failed: " + message)
        print("Retry or use /clear when reset is required; restart chat when reopen is required.")


def _chat(options: HailoOptions) raises:
    var session = Hailo10HSession(options.model_path)
    var interactive = options.format == "text" and external_call["isatty", Int32](Int32(0)) == 1 and external_call["isatty", Int32](Int32(1)) == 1
    if interactive:
        print("AESIR Hailo-10H chat. Use /clear, /info, /help or /bye.")
    while True:
        if interactive:
            print("You> ", end="")
            _ = external_call["fflush", Int32](Int(0))
        try:
            var line = _read_line()
            if not line[0]:
                break
            var prompt = line[1]
            var command = String(prompt.strip())
            if command == "/bye" or command == "/exit":
                break
            if len(command.as_bytes()) == 0:
                continue
            _validate_string(prompt, "prompt")
            if command == "/clear":
                session.clear_context()
                if options.format == "json":
                    print('{"event":"context_cleared","provenance":' + session.describe() + "}")
                else:
                    print("Hailo model context cleared.")
            elif command == "/info":
                print(session.describe())
            elif command == "/help":
                if options.format == "json":
                    print('{"commands":["/clear","/info","/help","/bye"]}')
                else:
                    print("/clear resets the model context; /info shows live hardware and context; /bye exits.")
            elif command.startswith("/"):
                raise Error("Unknown chat command: " + command + "; use /help")
            else:
                var response = session.generate(prompt, options.max_tokens, options.timeout_ms)
                _print_completed_response(response, session, options.format)
        except error:
            _print_chat_error(String(error), options.format)
    session.close()


def dispatch_command(args: List[String]) raises:
    if len(args) == 0:
        print_general_help()
        return
    var command = args[0]
    if command == "--version" or command == "-v" or command == "version":
        if len(args) != 1:
            raise Error("version does not accept arguments")
        print("aesir 0.1.0 (direct Hailo-10H backend)")
        return
    if command == "help" or command == "--help" or command == "-h":
        if len(args) == 1:
            print_general_help()
        elif command == "help" and len(args) == 2:
            _print_command_help(args[1])
        else:
            raise Error("Usage: aesir help [run|chat|hardware]")
        return
    if command != "run" and command != "chat" and command != "hardware":
        raise Error("Unknown command: " + command + "; use aesir help")
    if len(args) == 2 and (args[1] == "--help" or args[1] == "-h"):
        _print_command_help(command)
        return
    var options = _parse_options(args, command)
    if command == "chat":
        _chat(options^)
        return
    var session = Hailo10HSession(options.model_path)
    if command == "hardware":
        print(session.describe())
    else:
        var response = session.generate(options.prompt, options.max_tokens, options.timeout_ms)
        _print_completed_response(response, session, options.format)
    session.close()
