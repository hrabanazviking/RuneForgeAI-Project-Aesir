# core/tool_use.mojo
# Structured Tool Use & Function Calling Support for Project A.E.S.I.R.

struct ToolDefinition(Copyable, ImplicitlyCopyable):
    """
    ToolDefinition — Function schema definition provided to the model.
    """
    var name: String
    var description: String
    var parameters_json_schema: String

    def __init__(out self, name: String, description: String, schema: String):
        self.name = name
        self.description = description
        self.parameters_json_schema = schema

    def __copyinit__(out self, existing: Self):
        self.name = existing.name
        self.description = existing.description
        self.parameters_json_schema = existing.parameters_json_schema


struct ToolCall(Copyable, ImplicitlyCopyable):
    """
    ToolCall — Model-generated tool call request.
    """
    var name: String
    var arguments_json: String

    def __init__(out self, name: String, arguments_json: String):
        self.name = name
        self.arguments_json = arguments_json

    def __copyinit__(out self, existing: Self):
        self.name = existing.name
        self.arguments_json = existing.arguments_json

def format_tool_system_prompt(tools: List[ToolDefinition]) -> String:
    """Formats system prompt header injecting tool definitions into context."""
    if len(tools) == 0:
        return String("")

    var prompt = String("\n\n[AVAILABLE_TOOLS]\n")
    for i in range(len(tools)):
        prompt += "Tool: " + tools[i].name + "\n"
        prompt += "Description: " + tools[i].description + "\n"
        prompt += "Parameters: " + tools[i].parameters_json_schema + "\n\n"
    prompt += "[END_AVAILABLE_TOOLS]\n"
    prompt += "To invoke a tool, respond with JSON in format: {\"tool\": \"tool_name\", \"arguments\": {...}}\n"
    return prompt

def parse_tool_call(output_text: String) -> ToolCall:
    """Parses JSON-formatted tool calls from model generation output."""
    var raw = output_text.strip()
    var name = String("")
    var args = String("{}")

    if "\"tool\":" in raw:
        var idx = raw.find("\"tool\":")
        var start_quote = raw.find("\"", idx + 7)
        if start_quote != -1:
            var end_quote = raw.find("\"", start_quote + 1)
            if end_quote != -1:
                name = String(raw[byte=start_quote+1:end_quote])

    if "\"arguments\":" in raw:
        var idx = raw.find("\"arguments\":")
        var start_brace = raw.find("{", idx + 12)
        if start_brace != -1:
            var end_brace = raw.rfind("}")
            if end_brace != -1 and end_brace > start_brace:
                args = String(raw[byte=start_brace:end_brace+1])

    return ToolCall(name, args)
