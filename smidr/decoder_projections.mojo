# Original ordinary projection role/shape binding. Metadata only, never math.
from std.collections import Dict
from smidr.decoder_architecture import SourceDecoderArchitecture, source_decoder_architecture, validate_decoder_architecture
from smidr.decoder_layers import _same_ints, _same_strings
from smidr.source_storage import SourceStorageInventory, validate_source_storage
from smidr.source_inventory import SourceSemanticPolicy, SourceTensorInventory, append_source_storage, validate_source_inventory, validate_source_weight
from smidr.semantic_plan import checked_product


@fieldwise_init
struct DecoderProjectionPolicy(Copyable, Movable):
    var source: SourceSemanticPolicy
    var work: Int
    var provenance: String


@fieldwise_init
struct SourceProjectionIntent(Movable):
    var architecture: SourceDecoderArchitecture
    var files: List[SourceStorageInventory]
    var source: SourceTensorInventory
    var key_dim: Int
    var value_dim: Int
    var output_weight: String
    var unresolved: List[String]
    var policy: DecoderProjectionPolicy
    var work_units: Int


def _charge(used: Int, amount: Int, bound: Int) raises -> Int:
    if used < 0 or amount < 0 or used > bound or amount > bound - used:
        raise Error("DecoderProjections: projection work/count bound exceeded")
    return used + amount


def _same_policy(a: DecoderProjectionPolicy, b: DecoderProjectionPolicy) raises:
    if a.work != b.work or a.provenance != b.provenance or a.source.files != b.source.files or a.source.tensors != b.source.tensors or a.source.rank != b.source.rank or a.source.work != b.source.work:
        raise Error("DecoderProjections: supplied and owned policies differ")


def _work(architecture: SourceDecoderArchitecture, files: List[SourceStorageInventory],
          policy: DecoderProjectionPolicy) raises -> Int:
    if policy.source.files <= 0 or policy.source.tensors <= 0 or policy.source.rank <= 0 or policy.source.work <= 0 or policy.work <= 0 or policy.provenance.byte_length() == 0 or len(files) == 0 or len(files) > policy.source.files:
        raise Error("DecoderProjections: explicit positive source/work/provenance required")
    var count = 0
    for i in range(len(files)):
        count = _charge(count, len(files[i].tensors), policy.source.tensors)
    var layers = architecture.layers.layer_count
    if count < 2 or layers <= 0 or layers > (count - 2) // 9 or layers > (9223372036854775807 - 3) // 9:
        raise Error("DecoderProjections: layer roles exceed actual source evidence")
    var slots = 9 * layers + 3
    if slots > policy.work // 128 or count > policy.work // 8:
        raise Error("DecoderProjections: alias slot work bound exceeded")
    var work = _charge(slots * 128, count * 8, policy.work)
    work = _charge(work, len(files), policy.work)
    if policy.provenance.byte_length() > (policy.work - work) // len(files):
        raise Error("DecoderProjections: provenance work bound exceeded")
    work += policy.provenance.byte_length() * len(files)
    for i in range(len(files)):
        ref file = files[i]
        work = _charge(work, file.source_path.byte_length(), policy.work)
        work = _charge(work, len(file.metadata), policy.work)
        for key in file.metadata:
            work = _charge(work, key.byte_length(), policy.work)
            work = _charge(work, file.metadata[key].byte_length(), policy.work)
        for j in range(len(file.tensors)):
            work = _charge(work, file.tensors[j].original_name.byte_length(), policy.work)
            work = _charge(work, file.tensors[j].source_path.byte_length(), policy.work)
    return work


def _roles(layers: Int) raises -> Dict[String, String]:
    # Each original/canonical pair was prepaid with a128-unit slot reserve.
    var result = Dict[String, String]()
    result["model.embed_tokens.weight"] = "token_embd.weight"
    result["model.norm.weight"] = "output_norm.weight"
    result["lm_head.weight"] = "output.weight"
    var originals: List[String] = ["input_layernorm.weight", "post_attention_layernorm.weight", "self_attn.q_proj.weight", "self_attn.k_proj.weight", "self_attn.v_proj.weight", "self_attn.o_proj.weight", "mlp.gate_proj.weight", "mlp.up_proj.weight", "mlp.down_proj.weight"]
    var canonical: List[String] = ["attn_norm.weight", "ffn_norm.weight", "attn_q.weight", "attn_k.weight", "attn_v.weight", "attn_output.weight", "ffn_gate.weight", "ffn_up.weight", "ffn_down.weight"]
    for layer in range(layers):
        var prefix = String("model.layers.") + String(layer) + "."
        var target = String("blk.") + String(layer) + "."
        for i in range(len(originals)):
            result[prefix + originals[i]] = target + canonical[i]
    return result^


def bind_decoder_projections(architecture: SourceDecoderArchitecture,
                             files: List[SourceStorageInventory],
                             policy: DecoderProjectionPolicy) raises -> SourceProjectionIntent:
    var work = _work(architecture, files, policy)
    validate_decoder_architecture(architecture, architecture.policy)
    if "num_key_value_heads" not in architecture.dimensions:
        raise Error("DecoderProjections: explicit KV-head source semantics unresolved")
    var roles = _roles(architecture.layers.layer_count)
    var source = SourceTensorInventory()
    source.architecture = architecture.layers.model_type
    source.policy = policy.source.copy()
    var seen = Dict[String, Bool]()
    for i in range(len(files)):
        ref file = files[i]
        if file.source_format != "safetensors":
            raise Error("DecoderProjections: source role format implementation unresolved")
        validate_source_storage(file, policy.source.tensors, policy.source.rank, policy.source.work)
        var aliases = Dict[String, String]()
        for j in range(len(file.tensors)):
            var name = file.tensors[j].original_name
            if name not in roles:
                raise Error("DecoderProjections: source tensor role implementation unresolved: " + name)
            if name in seen:
                raise Error("DecoderProjections: duplicate global source name")
            seen[name] = True
            aliases[roles[name]] = name
        append_source_storage(source, file, aliases, policy.provenance)
    validate_source_inventory(source)
    var hidden = architecture.dimensions["hidden_size"]
    var ff = architecture.dimensions["intermediate_size"]
    var heads = architecture.dimensions["num_attention_heads"]
    var kv = architecture.dimensions["num_key_value_heads"]
    var vocab = architecture.dimensions["vocab_size"]
    validate_source_weight(source, "token_embd.weight", hidden, vocab, False)
    validate_source_weight(source, "output_norm.weight", hidden, 1, True)
    var key_dim = 0
    var value_dim = 0
    for layer in range(architecture.layers.layer_count):
        var p = String("blk.") + String(layer) + "."
        if p + "attn_q.weight" not in source.bindings or p + "attn_v.weight" not in source.bindings:
            raise Error("DecoderProjections: missing Q/V projection source")
        var query = source.bindings[p + "attn_q.weight"]
        var value = source.bindings[p + "attn_v.weight"]
        if query.rows <= 0 or value.rows <= 0 or query.rows % heads != 0 or value.rows % kv != 0:
            raise Error("DecoderProjections: nonintegral actual projection head dimensions")
        var key_width = query.rows // heads
        var value_width = value.rows // kv
        if layer == 0:
            key_dim = key_width
            value_dim = value_width
        elif key_dim != key_width or value_dim != value_width:
            raise Error("DecoderProjections: heterogeneous head recipe implementation unresolved")
        validate_source_weight(source, p + "attn_q.weight", hidden, checked_product(heads, key_width), False)
        validate_source_weight(source, p + "attn_k.weight", hidden, checked_product(kv, key_width), False)
        validate_source_weight(source, p + "attn_v.weight", hidden, checked_product(kv, value_width), False)
        validate_source_weight(source, p + "attn_output.weight", checked_product(heads, value_width), hidden, False)
        validate_source_weight(source, p + "attn_norm.weight", hidden, 1, True)
        validate_source_weight(source, p + "ffn_norm.weight", hidden, 1, True)
        validate_source_weight(source, p + "ffn_gate.weight", hidden, ff, False)
        validate_source_weight(source, p + "ffn_up.weight", hidden, ff, False)
        validate_source_weight(source, p + "ffn_down.weight", ff, hidden, False)
    var has_output = "output.weight" in source.bindings
    if has_output:
        validate_source_weight(source, "output.weight", hidden, vocab, False)
    var output = String("")
    var notes = architecture.unresolved.copy()
    for note in architecture.layers.unresolved:
        notes.append("layer:" + note)
    if "tie_word_embeddings" in architecture.flags:
        if architecture.flags["tie_word_embeddings"]:
            output = "token_embd.weight"
            if has_output:
                notes.append("duplicate_tied_output_requires_source_identity")
        else:
            if not has_output:
                raise Error("DecoderProjections: explicit untied output source missing")
            output = "output.weight"
    else:
        notes.append("explicit_output_tie_semantics_unresolved")
    notes.append("initial_projection_schema_not_complete_architecture")
    notes.append("source_file_identity_not_verified")
    var snapshots = List[SourceStorageInventory]()
    for i in range(len(files)):
        ref file = files[i]
        snapshots.append(SourceStorageInventory(file.source_format, file.source_path,
            file.source_bytes, file.data_offset, file.tensors.copy(), file.metadata.copy()))
    var owned_architecture = source_decoder_architecture(architecture.layers, architecture.policy)
    return SourceProjectionIntent(owned_architecture^, snapshots^, source^, key_dim,
        value_dim, output^, notes^, policy.copy(), work)


def _same_source(a: SourceTensorInventory, b: SourceTensorInventory) raises:
    if a.architecture != b.architecture or a.source_bytes != b.source_bytes or a.data_offset != b.data_offset or a.weight_bytes != b.weight_bytes or a.alias_provenance != b.alias_provenance or len(a.bindings) != len(b.bindings) or len(a.storage) != len(b.storage) or len(a.files) != len(b.files) or a.policy.files != b.policy.files or a.policy.tensors != b.policy.tensors or a.policy.rank != b.policy.rank or a.policy.work != b.policy.work:
        raise Error("DecoderProjections: derived source summary/policy changed")
    for path in b.files:
        if path not in a.files or a.files[path].source_format != b.files[path].source_format or a.files[path].source_bytes != b.files[path].source_bytes or a.files[path].data_offset != b.files[path].data_offset:
            raise Error("DecoderProjections: derived backing extent changed")
    for name in b.bindings:
        if name not in a.bindings or name not in a.storage:
            raise Error("DecoderProjections: derived source alias missing")
        var left = a.bindings[name]
        var right = b.bindings[name]
        if left.file_offset != right.file_offset or left.columns != right.columns or left.rows != right.rows or left.source_kind != right.source_kind or left.byte_count != right.byte_count:
            raise Error("DecoderProjections: derived source binding changed")
        ref x = a.storage[name]
        ref y = b.storage[name]
        if x.source_format != y.source_format or x.source_kind != y.source_kind or x.original_name != y.original_name or x.source_path != y.source_path or x.axis_order != y.axis_order or x.elements != y.elements or x.file_offset != y.file_offset or x.byte_count != y.byte_count:
            raise Error("DecoderProjections: derived tagged source changed")
        _same_ints(x.source_shape, y.source_shape)
    # Compare against the bounded rederived fields before hashing/sorting mutable
    # caller metadata in the generic validator.
    validate_source_inventory(a)


def validate_decoder_projections(intent: SourceProjectionIntent,
                                 policy: DecoderProjectionPolicy) raises:
    _same_policy(intent.policy, policy)
    var expected = bind_decoder_projections(intent.architecture, intent.files, policy)
    if intent.key_dim != expected.key_dim or intent.value_dim != expected.value_dim or intent.output_weight != expected.output_weight or intent.work_units != expected.work_units:
        raise Error("DecoderProjections: derived projection decision/accounting changed")
    _same_strings(intent.unresolved, expected.unresolved)
    _same_source(intent.source, expected.source)
