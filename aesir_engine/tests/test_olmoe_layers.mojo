"""B1 bisection vehicle (J-022): steps a token-id sequence through
MoEStreamSession and, for ONE chosen token index, dumps the session's
per-layer hidden states and router choices (the moe_session debug_dump
hook) so they can be compared layer by layer against a reference
forward. Hidden values are printed as integers (value * 1e6, rounded)
to keep full precision through text.

Usage: test_olmoe_layers <model.gguf> <context> <cache_bytes>
       <tokens_csv> <dump_index>
Prints: NEXT (the dumped step's greedy pick), DUMP lines (checkpoint
index, then hidden-dimension integers; checkpoint 0 = embedding,
1/2 = layer 0 attention/MoE residuals, ..., 33 = final hidden), and
ROUTE lines (layer, then expert,weight*1e6 pairs).
"""
from std.sys import argv
from core.moe_session import MoEStreamSession
from cli.modelfile import parse_int


def parse_tokens(text: String) raises -> List[Int]:
    var tokens = List[Int]()
    var current = String("")
    var bytes = text.as_bytes()
    for i in range(len(bytes)):
        var b = bytes[i]
        if b == 44:  # ','
            if len(current.as_bytes()) > 0:
                tokens.append(parse_int(current))
                current = String("")
        else:
            current += chr(Int(b))
    if len(current.as_bytes()) > 0:
        tokens.append(parse_int(current))
    return tokens^


def main() raises:
    var args = argv()
    if len(args) != 6:
        raise Error(
            "usage: test_olmoe_layers <model.gguf> <context> <cache_bytes>"
            " <tokens_csv> <dump_index>"
        )
    var session = MoEStreamSession(
        args[1], parse_int(args[2]), parse_int(args[3])
    )
    var tokens = parse_tokens(args[4])
    var dump_index = parse_int(args[5])
    var next_token = 0
    for i in range(len(tokens)):
        if i == dump_index:
            session.debug_dump = True
        next_token = session.step(tokens[i])
        if i == dump_index:
            session.debug_dump = False
    print("NEXT", next_token)
    var hidden = session.hidden
    var n_chk = len(session.dump_hidden) // hidden
    for c in range(n_chk):
        var line = String("DUMP ") + String(c)
        for i in range(hidden):
            var v = session.dump_hidden[c * hidden + i]
            line += "," + String(Int(v * 1000000.0 + (0.5 if v >= 0 else -0.5)))
        print(line)
    var per_layer = session.expert_used * 2
    for layer in range(session.layer_count):
        var line = String("ROUTE ") + String(layer)
        for i in range(per_layer):
            var v = session.dump_route[layer * per_layer + i]
            if i % 2 == 0:
                line += "," + String(Int(v))
            else:
                line += "," + String(Int(v * 1000000.0 + (0.5 if v >= 0 else -0.5)))
        print(line)
