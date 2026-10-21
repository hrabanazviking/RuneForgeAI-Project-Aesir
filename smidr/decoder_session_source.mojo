# Project a selected session preference without erasing the complete source owner.
from smidr.decoder_architecture import SourceDecoderArchitecture, validate_decoder_architecture
from smidr.session_policy import DecoderSessionPolicy, session_policy_charge


def source_decoder_session(architecture: SourceDecoderArchitecture, mode: String,
                           return_override: Int, provenance: String,
                           work: Int) raises -> DecoderSessionPolicy:
    if return_override < -1 or return_override > 1:
        raise Error("DecoderSession: override must be -1, zero or one")
    validate_decoder_architecture(architecture, architecture.policy)
    var source_flag = Int(architecture.flags["use_cache"])
    var returned = source_flag if return_override == -1 else return_override
    var origin = String("source") if return_override == -1 else String("invocation")
    _ = session_policy_charge(mode, returned, source_flag, origin, provenance,
        architecture.layers.layer_count, work, architecture.policy.work)
    return DecoderSessionPolicy(mode, returned, source_flag, origin, provenance, work)
