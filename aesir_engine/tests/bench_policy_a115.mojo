# tests/bench_policy_a115.mojo
# A-115: one-command driver -- emits the encoded
# token-exactness policy table with its digest, plus
# one filed gate verdict per obligation class, on the
# Z13. Pure policy arithmetic over banked records; the
# driver executes no model and opens no device.

from core.exactness_policy import (
    policy_digest,
    policy_gate,
    policy_line,
    policy_render,
    policy_verdict_name,
)


def main() raises:
    print(policy_render())
    print("A115_POLICY_DIGEST " + String(policy_digest()))
    print(policy_line())
    var exact_ranks = List[Int]()
    exact_ranks.append(0)
    exact_ranks.append(2)
    var exact_gaps = List[Int]()
    exact_gaps.append(0)
    exact_gaps.append(500)
    var exact = policy_gate(
        "Q4_K_M", exact_ranks, exact_gaps, True, False, False
    )
    print(
        "A115_GATE quant=Q4_K_M verdict="
        + policy_verdict_name(exact.verdict)
    )
    var iq_ranks = List[Int]()
    iq_ranks.append(5)
    var iq_gaps = List[Int]()
    iq_gaps.append(2000)
    var iq = policy_gate("IQ2_XS", iq_ranks, iq_gaps, True, True, True)
    print(
        "A115_GATE quant=IQ2_XS verdict="
        + policy_verdict_name(iq.verdict)
    )
    var unstated = policy_gate(
        "IQ2_XS", iq_ranks, iq_gaps, True, False, False
    )
    print(
        "A115_GATE quant=IQ2_XS_unstated verdict="
        + policy_verdict_name(unstated.verdict)
    )
    print("A115_BENCH_DONE rows=19")
