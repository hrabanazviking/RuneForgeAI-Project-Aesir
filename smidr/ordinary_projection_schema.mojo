# Original qualified source header schema. No numerical model computation.
from smidr.decoder_architecture import SourceDecoderArchitecture
from smidr.decoder_layers import _positive, _same_strings
from smidr.decoder_projections import (
    DecoderProjectionPolicy, SourceProjectionIntent, _work, _charge,
    _bind_decoder_projections, _same_policy, _same_source,
)
from smidr.source_storage import SourceStorageInventory


@fieldwise_init
struct OrdinaryProjectionSchema(Movable):
    var binding: SourceProjectionIntent
    var head_dim: Int
    var head_dim_origin: String
    var schema_provenance: String
    var work_units: Int


def bind_ordinary_projection_schema(architecture: SourceDecoderArchitecture,
                                    files: List[SourceStorageInventory],
                                    policy: DecoderProjectionPolicy) raises -> OrdinaryProjectionSchema:
    # Pre-admit wrapper work before the common binder allocates role dictionaries.
    var work = _work(architecture, files, policy, True)
    work = _charge(work, 128, policy.work)
    var layers = architecture.layers.layer_count
    if layers > (policy.work - work) // 8:
        raise Error("OrdinaryProjectionSchema: wrapper work bound exceeded")
    work += layers * 8
    var binding = _bind_decoder_projections(architecture, files, policy, True)
    var hidden = binding.architecture.dimensions["hidden_size"]
    var heads = binding.architecture.dimensions["num_attention_heads"]
    var head_dim = hidden // heads
    var origin = String("qualified_constructor:floor(hidden_size/num_attention_heads)")
    if "head_dim" in binding.architecture.layers.source.fields:
        head_dim = _positive(binding.architecture.layers.source.fields["head_dim"])
        origin = "source:head_dim"
    if head_dim <= 0 or binding.key_dim != head_dim or binding.value_dim != head_dim:
        raise Error("OrdinaryProjectionSchema: declared head/source projection mismatch")
    return OrdinaryProjectionSchema(binding^, head_dim, origin^,
        "transformers:4.57.1:smollm3:meta-constructor:2026-10-21", work)


def validate_ordinary_projection_schema(intent: OrdinaryProjectionSchema,
                                        policy: DecoderProjectionPolicy) raises:
    _same_policy(intent.binding.policy, policy)
    var expected = bind_ordinary_projection_schema(intent.binding.architecture,
        intent.binding.files, policy)
    if intent.head_dim != expected.head_dim or intent.head_dim_origin != expected.head_dim_origin or intent.schema_provenance != expected.schema_provenance or intent.work_units != expected.work_units:
        raise Error("OrdinaryProjectionSchema: qualified source decision/accounting changed")
    ref a = intent.binding
    ref b = expected.binding
    if a.key_dim != b.key_dim or a.value_dim != b.value_dim or a.output_weight != b.output_weight or a.work_units != b.work_units:
        raise Error("OrdinaryProjectionSchema: derived projection decision changed")
    _same_strings(a.unresolved, b.unresolved)
    _same_source(a.source, b.source)
