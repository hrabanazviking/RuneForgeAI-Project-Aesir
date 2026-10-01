"""Checked D2D transfer owned by the opt-in bandwidth probe.

Uses the locked runtime copy API; it is not a native model kernel.
"""
from max.gpu.host import DeviceContext, DeviceBuffer


def copy_words(ctx: DeviceContext, source: DeviceBuffer[DType.uint32],
               target: DeviceBuffer[DType.uint32]) raises:
    if len(source) < 1 or len(source) != len(target):
        raise Error("Measurement copy requires equal nonempty spans")
    ctx.enqueue_copy(target, source)
