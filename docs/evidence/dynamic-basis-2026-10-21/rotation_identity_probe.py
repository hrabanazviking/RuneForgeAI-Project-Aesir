"""Original fixed-number planar rotation identities, no model or attention."""
import cmath
import json
import math

def rotate(pair, angle):
    x, y = pair
    c, s = math.cos(angle), math.sin(angle)
    return (c*x-s*y, s*x+c*y)

rows = []
worst = 0.0
changed = 0
for width in (4, 6, 8):
    for theta in (10000.0, 2000000.0):
        for factor in (1.0, 2.0):
            for position in (0, 1, 7, 15):
                for old_context, new_context in ((16, 17), (17, 32), (32, 16)):
                    def frequency(context, j):
                        gain = factor*max(context,16)/16-(factor-1)
                        return theta**(-2*j/width)*gain**(-2*j/(width-2))
                    pair_results = []
                    for j in range(width//2):
                        pair = (0.25*(j+1), -0.5*(j+2))
                        old_angle = position*frequency(old_context,j)
                        new_angle = position*frequency(new_context,j)
                        old = rotate(pair, old_angle)
                        new = rotate(pair, new_angle)
                        rebased = rotate(old, new_angle-old_angle)
                        complex_target = complex(*pair)*cmath.exp(1j*new_angle)
                        reference = (complex_target.real, complex_target.imag)
                        error = max(abs(x-y) for x,y in zip(rebased,reference))
                        norm_error = abs(sum(x*x for x in pair)-sum(x*x for x in rebased))
                        inverse = rotate(old, -old_angle)
                        inverse_error = max(abs(x-y) for x,y in zip(pair,inverse))
                        error = max(error, norm_error, inverse_error)
                        worst = max(worst,error)
                        assert error < 1e-12
                        unchanged_wrong_basis_delta = max(abs(x-y) for x,y in zip(old,new))
                        changed += unchanged_wrong_basis_delta > 1e-12
                        pair_results.append(dict(pair_index=j, original_pair=pair, old=old, target=new, rebased=rebased, max_identity_error=error, unrephased_difference=unchanged_wrong_basis_delta))
                    rows.append(dict(width=width, theta=theta, factor=factor, position=position, old_context=old_context, new_context=new_context, pairs=pair_results))
assert len(rows) == 144
print(json.dumps(dict(cases=rows, case_count=len(rows), pair_identities=sum(len(row["pairs"]) for row in rows), changed_pairs=changed, worst_absolute_error=worst, fixed_input_pairs_only=True, model_or_layer_or_attention_forward=False, attention_scores=False, model_cache_equivalence_claimed=False),indent=2,allow_nan=False))
