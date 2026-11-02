# cli/mcp_serve.mojo
# MCP stdio host (Janas road J-109): serves Aesir as MCP
# tools on stdin/stdout, JSON-RPC 2.0, one object per
# line -- the `aesir mcp` door.
#
# Every protocol and dispatch decision lives in the pure
# layer (core/mcp_tools.mojo); this host only:
#   * converts the J-103 known-models catalogue
#     (cli/known_models.mojo) to layer facts once at start,
#   * carries one McpSession between lines,
#   * prints each reply payload as exactly one stdout
#     line, and nothing else, ever -- the protocol
#     channel is the product and any stray print would
#     corrupt its framing,
#   * exits cleanly at EOF.
#
# No engine is bound in this build (engine_bound = false):
# generation requests are answered by the layer with the
# honest no-engine tool error, never with invented text.
# J-112: the same holds for tokenize (no tokenizer is
# bound without an engine); the bench report form IS
# executed here, because observing the device inventory
# and rendering filed evidence need no model.
# The engine binding -- constructing an AesirEngine over
# a locally present model file and completing
# needs_generate replies through the facade -- is the
# deferred live leg filed in the J-109 doc section 5,
# re-cited at the J-118 gate. The host writes nothing to
# disk and never modifies a model file (J-105's manners).
#
# The stdin reader is host-local on purpose: it is the
# same POSIX getchar shape as cli/repl.mojo's proven
# read_line, duplicated so this host's import graph stays
# free of the engine facade that cli/repl.mojo carries.

from std.ffi import external_call

from core.mcp_tools import (
    McpModelFact,
    McpSession,
    mcp_bench_completion,
    mcp_generate_failure,
    mcp_handle_line,
    mcp_tokenize_failure,
)
from core.device_inventory import observe_device_inventory
from core.machine_report import filed_model_rows, model_table
from core.services_surface import svc_bench_text
from cli.known_models import known_models_dataset


struct _McpLine(Copyable, ImplicitlyCopyable):
    var text: String
    var eof: Bool

    def __init__(out self, text: String, eof: Bool):
        self.text = text
        self.eof = eof

    def __copyinit__(out self, existing: Self):
        self.text = existing.text
        self.eof = existing.eof


def _buffer_text(buffer: List[Byte]) -> String:
    """Bytes -> String via the tree's proven idiom (a
    NUL terminator + unsafe_from_utf8_ptr); String(List)
    in this toolchain yields the debug representation,
    not the characters (J-109 doc section 7)."""
    var terminated = List[Byte]()
    for b in buffer:
        terminated.append(b)
    terminated.append(Byte(0))
    return String(unsafe_from_utf8_ptr=terminated.unsafe_ptr())


def _read_mcp_line() -> _McpLine:
    """Reads one line from stdin via POSIX getchar;
    eof is true when the stream ended (with any partial
    line still returned in text)."""
    var buffer = List[Byte]()
    while True:
        var ch = external_call["getchar", Int32]()
        if ch == -1:
            return _McpLine(_buffer_text(buffer), True)
        if ch == 10:
            return _McpLine(_buffer_text(buffer), False)
        if ch != 13:
            buffer.append(Byte(ch))
    return _McpLine(_buffer_text(buffer), True)


def _catalogue_facts() -> List[McpModelFact]:
    var facts = List[McpModelFact]()
    for entry in known_models_dataset():
        facts.append(
            McpModelFact(
                entry.name,
                entry.tag,
                entry.repository,
                entry.filename,
                entry.revision,
                entry.sha256,
                Int(entry.size_bytes),
                entry.quantization,
            )
        )
    return facts^


def run_mcp_stdio() raises:
    """The MCP stdio session loop: layer decisions in,
    one reply line out per answered request, silence for
    notifications, clean exit at EOF."""
    var facts = _catalogue_facts()
    var session = McpSession()
    while True:
        var line = _read_mcp_line()
        if line.text.byte_length() > 0:
            var reply = mcp_handle_line(
                line.text, session, facts, False, String("")
            )
            if reply.now_initialized:
                session.initialized = True
            if reply.needs_generate:
                # Unreachable in this build (engine_bound is
                # false, so the layer answers generate calls
                # itself); kept as the bound build's seam:
                # a bound host executes the facade here and
                # prints mcp_generate_completion instead.
                print(
                    mcp_generate_failure(
                        reply.gen_id_raw,
                        String(
                            "internal: generate dispatched with"
                            " no engine bound in this host build"
                        ),
                    )
                )
            elif reply.needs_tokenize:
                # Unreachable in this build for the same
                # reason (no tokenizer is bound without an
                # engine); the bound build's seam: it encodes
                # reply.tok_text through the bound tokenizer
                # and prints mcp_tokenize_completion with
                # svc_format_tokenize's text instead.
                print(
                    mcp_tokenize_failure(
                        reply.gen_id_raw,
                        String(
                            "internal: tokenize dispatched with"
                            " no tokenizer bound in this host"
                            " build"
                        ),
                    )
                )
            elif reply.needs_bench:
                # Executed in this build (J-112): the bench
                # report form needs no model -- observe the
                # device inventory, render the filed
                # per-model evidence table, compose through
                # the services layer, complete through the
                # MCP layer's builder. One stdout line, like
                # every reply: the report's newlines ride
                # inside the JSON string.
                print(
                    mcp_bench_completion(
                        reply.gen_id_raw,
                        svc_bench_text(
                            observe_device_inventory().describe(),
                            model_table(filed_model_rows()),
                        ),
                    )
                )
            elif reply.respond:
                print(reply.payload)
        if line.eof:
            break
