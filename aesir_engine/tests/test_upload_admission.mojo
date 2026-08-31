"""Host-only upload sizing/admission checks, not physical transfer proof."""
from core.cuda_upload import upload_staging_bytes
from core.inference_memory import InferenceMemoryPlan


def test_upload_staging_bounds() raises:
    if upload_staging_bytes(1) != 1 or upload_staging_bytes(67108865) != 67108864:
        raise Error("Upload staging boundary mismatch")
    if upload_staging_bytes(65539, 31) != 31:
        raise Error("Custom small staging limit ignored")
    for choice in range(4):
        var rejected = False
        try:
            if choice == 0:
                _ = upload_staging_bytes(0)
            elif choice == 1:
                _ = upload_staging_bytes(-1)
            elif choice == 2:
                _ = upload_staging_bytes(100, 0)
            else:
                _ = upload_staging_bytes(100, 67108865)
        except:
            rejected = True
        if not rejected:
            raise Error("Invalid upload chunk or extent accepted")


def test_upload_host_admission() raises:
    var plan = InferenceMemoryPlan(4692668960, 1024, 1024)
    # Accept a host budget that cannot hold the former full pinned copy.
    plan.admit(5000000000, 4759777828, 0)
    var rejected = False
    try:
        plan.admit(5000000000, 4759777827, 0)
    except:
        rejected = True
    if not rejected:
        raise Error("Mapped model plus staging boundary ignored")
