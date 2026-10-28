"""Unit tests for the slice 4 embedding-span override (design doc
section 4, proof plan (a)): a synthetic embedding stream plus a span
override must replace exactly the span rows, leave neighbours
bit-untouched, honour chunk offsets when a prefill chunk starts
inside the span, and raise fail-closed on a width mismatch, an
empty buffer, or a negative span start.
"""
from core.inference import apply_embedding_span
from core.mimir_well import MimirWell, RuneTensor, f16


def _fill(mut x: RuneTensor[f16]):
    # NOTE: the stream is created by the caller and filled through this
    # mut reference. A create-and-fill helper returning the tensor by
    # value lost its stores under this toolchain when core.inference is
    # in the import graph (observed 2026-10-27); the engine's own code
    # always fills tensors in the function that consumes them.
    for r in range(x.rows):
        for j in range(x.cols):
            x.data.unsafe_store(r * x.cols + j, Scalar[f16](Float32(100 + r)))


def _span_rows(n: Int, width: Int) -> List[Float32]:
    var rows = List[Float32]()
    for k in range(n):
        for j in range(width):
            rows.append(Float32(1000 + 10 * k + j))
    return rows^


def _expect(x: RuneTensor[f16], r: Int, j: Int, want: Float32, what: String) raises:
    var got = x.data.unsafe_load(r * x.cols + j).cast[DType.float32]()
    if got != want:
        raise Error(
            "embedding span: " + what + " row " + String(r) + " col "
            + String(j) + " = " + String(got) + ", want " + String(want)
        )


def _case_exact_rows() raises:
    var well = MimirWell(4096)
    var x = RuneTensor[f16](6, 4, well.allocate(24), False)
    _fill(x)
    apply_embedding_span(x, _span_rows(3, 4), 2, 0)
    for r in range(6):
        for j in range(4):
            if 2 <= r and r <= 4:
                _expect(x, r, j, Float32(1000 + 10 * (r - 2) + j), "span row")
            else:
                _expect(x, r, j, Float32(100 + r), "neighbour row")
    print("embedding span exact rows: PASS")


def _case_chunk_offset() raises:
    var well = MimirWell(4096)
    var x = RuneTensor[f16](5, 4, well.allocate(20), False)
    _fill(x)
    apply_embedding_span(x, _span_rows(3, 4), 2, 3)
    for r in range(5):
        for j in range(4):
            if r == 0:
                _expect(x, r, j, Float32(1000 + 10 + j), "chunk row from span 1")
            elif r == 1:
                _expect(x, r, j, Float32(1000 + 20 + j), "chunk row from span 2")
            else:
                _expect(x, r, j, Float32(100 + r), "chunk neighbour")
    print("embedding span chunk offset: PASS")


def _case_no_intersection() raises:
    var well = MimirWell(4096)
    var x = RuneTensor[f16](4, 4, well.allocate(16), False)
    _fill(x)
    apply_embedding_span(x, _span_rows(3, 4), 2, 10)
    for r in range(4):
        for j in range(4):
            _expect(x, r, j, Float32(100 + r), "untouched row")
    print("embedding span no intersection: PASS")


def _case_fail_closed() raises:
    var well = MimirWell(4096)
    var x = RuneTensor[f16](4, 4, well.allocate(16), False)
    _fill(x)
    var raised = 0
    try:
        apply_embedding_span(x, List[Float32](), 0, 0)
    except:
        raised += 1
    try:
        apply_embedding_span(x, _span_rows(3, 4), -1, 0)
    except:
        raised += 1
    var bad_width = List[Float32]()
    for i in range(6):
        bad_width.append(Float32(i))
    try:
        apply_embedding_span(x, bad_width, 0, 0)
    except:
        raised += 1
    if raised != 3:
        raise Error(
            "embedding span: fail-closed cases raised " + String(raised) + " of 3"
        )
    print("embedding span fail-closed: PASS")


def test_embedding_span() raises:
    _case_exact_rows()
    _case_chunk_offset()
    _case_no_intersection()
    _case_fail_closed()


def main() raises:
    test_embedding_span()
    print("test_embedding_span: PASS")
