# tests/bench_localise_a116.mojo
# A-116: First-divergence localisation -- seeded
# demonstration driver.
#
# Usage: bench_localise_a116
#
# Runs the canonical seeded divergence (core/divergence
# _localiser.seeded_probes: 12 layers x 4 ops + lm_head,
# seed at layer 7 / mlp.down_proj) through the localiser
# under its clean A-112 row account and prints every
# probe with its A-111 gate class, the verdict line, and
# the FNV-1a digest of the rendering. The driver asserts
# the filed location is exactly the seed; a mismatch
# raises and the run files no DONE line. Pure arithmetic
# on stated records: no model is executed, no device is
# opened, and no accelerator claim is made.

from core.divergence_localiser import (
    LOC_LOCALISED,
    SEEDED_INDEX,
    SEEDED_LAYER,
    SEEDED_OP,
    localise_seeded,
    localisation_line,
    localisation_render,
    loc_fnv1a64,
    seeded_probes,
)


def main() raises:
    print(localisation_line())
    var probes = seeded_probes()
    var loc = localise_seeded()
    print(localisation_render(loc, probes))
    print("A116_SEEDED_DIGEST", loc_fnv1a64(localisation_render(loc, probes)))
    if loc.verdict != LOC_LOCALISED:
        raise Error("seeded demonstration did not localise")
    if (
        loc.first_layer != SEEDED_LAYER
        or loc.first_op != SEEDED_OP
        or loc.first_index != SEEDED_INDEX
    ):
        raise Error("seeded demonstration filed the wrong location")
    print(
        "A116_BENCH_DONE localised layer=",
        loc.first_layer,
        " op=",
        loc.first_op,
        " index=",
        loc.first_index,
    )
