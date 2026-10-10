from tests.test_inference import test_sampler_stack
from std.memory.alloc import alloc, Layout
from std.memory import Pointer
from core.mimir_well import f16
from core.sampler import RuneRNG, sample_token_from_logits
from core.compute import MutUntrackedOrigin


def main() raises:
    test_sampler_stack()
    var ptr = alloc(Layout[Scalar[f16]](count=5)).unsafe_leak()
    ptr.unsafe_store(0, Scalar[f16](1.0))
    ptr.unsafe_store(1, Scalar[f16](5.0))
    ptr.unsafe_store(2, Scalar[f16](5.0))
    ptr.unsafe_store(3, Scalar[f16](0.0))
    ptr.unsafe_store(4, Scalar[f16](5.0))
    var rng = RuneRNG(42)
    var selected = sample_token_from_logits(ptr, 5, 0.0, 40, 1.0, 1.0, List[Int](), rng)
    print("cpu_tie_selected=", selected)
