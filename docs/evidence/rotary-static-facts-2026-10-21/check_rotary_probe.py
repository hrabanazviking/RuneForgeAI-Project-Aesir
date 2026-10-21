from pathlib import Path
import json,math,re
root=Path(__file__).resolve().parent
d=json.loads((root / "rotary-final.json").read_text())
for case in d["cases"]:
    width=case["width"];x=case["input"];half=width//2
    expected=[-x[i+half] for i in range(half)]+x[:half]
    assert case["rotated"]==expected and case["query"]==expected
    assert case["key"]==[2*v for v in expected]
errors=[]
for case in d["frequencies"]:
    expected=[case["theta"]**(-2*j/case["width"]) for j in range(case["width"]//2)]
    assert len(expected)==len(case["inverse_frequencies"])
    errors.append(max(abs(a-b)/b for a,b in zip(case["inverse_frequencies"],expected)))
    assert case["attention_factor"]==1
trace=(root / "rotary-final.strace").read_text()
summary=dict(static_cases=len(d["cases"]),frequency_cases=len(d["frequencies"]),
    max_frequency_relative_error=max(errors),split_half_pairing_observed=True,
    module_forward_calls=d["module_forward_calls"],network_connect_calls=len(re.findall(r"\bconnect\(",trace)),
    hailo_device_open=bool(re.search(r"/dev/(?:hailo|h1x)",trace)),torch_loaded=True,
    model_instantiated=False,weights_loaded=False,frequency_errors=errors,
    initial_comparison=dict(threshold=2e-7,passed=False,reason="F32 frequency oracle differs from ideal real exponent, maximum measured2.9196e-7. No hardware precision acceptance claimed."),
    notes=["Only static vector/frequency primitives; no model/layer/attention forward.",
    "Initial sklearn/scipy import failure and missing sympy failure are preserved.",
    "Final process uses pinned Transformers4.57.1 plus selected installed Torch/sympy/mpmath imports; no global package changes."])
assert not summary["module_forward_calls"] and summary["network_connect_calls"]==0 and not summary["hailo_device_open"]
(root / "rotary-oracle-checks.json").write_text(json.dumps(summary,indent=2)+"\n")
print({k:v for k,v in summary.items() if k not in ("notes","frequency_errors")})
