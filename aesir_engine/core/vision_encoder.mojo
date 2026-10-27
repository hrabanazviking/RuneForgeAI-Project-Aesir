"""Vision encoder forward stages for the mmproj tower (built stage by stage).

Stage 3a (this file's proven scope): the patch-embedding projection —
each patch vector (patch_size * patch_size * 3 values, in the layout
loader/image_prep produces) is linearly mapped to the vision hidden size
by ``v.patch_embd.weight`` (F32, dims [patch, patch, 3, hidden], GGUF
innermost-first). No bias tensor exists for this layer in the file.

Position-embedding addition and the transformer blocks are later stages;
their absence is explicit in docs/VISION_MMPROJ_DEVELOPMENT.md. The exact
semantics of ``v.position_embd.weight`` ([768, 10240, 2]) are NOT yet
established and nothing here guesses them.
"""


def patch_embed(
    patch_vectors: List[Float32],
    weights: List[Float32],
    patch_count: Int,
    patch_size: Int,
    hidden: Int,
) raises -> List[Float32]:
    """Projects patch vectors to hidden-size embeddings.

    ``weights`` is the raw F32 patch-embedding tensor in file order:
    element ((oc * 3 + c) * patch_size + h) * patch_size + w belongs to
    output channel oc, input position (h, w, c). ``patch_vectors`` uses
    the matching input order (h, then w, then c) per patch.
    """
    var patch_values = patch_size * patch_size * 3
    if len(patch_vectors) != patch_count * patch_values:
        raise Error("vision: patch vector buffer does not match geometry")
    if len(weights) != patch_values * hidden:
        raise Error("vision: patch embedding weight count does not match geometry")
    var out = List[Float32]()
    out.reserve(patch_count * hidden)
    for p in range(patch_count):
        var base = p * patch_values
        for oc in range(hidden):
            var acc = Float32(0.0)
            for h in range(patch_size):
                for w in range(patch_size):
                    for c in range(3):
                        var input_index = (h * patch_size + w) * 3 + c
                        var weight_index = ((oc * 3 + c) * patch_size + h) * patch_size + w
                        acc += patch_vectors[base + input_index] * weights[weight_index]
            out.append(acc)
    return out^
