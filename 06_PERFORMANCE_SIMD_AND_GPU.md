# Mojo Performance: SIMD, Parallelism, Compile-Time Parameterization, and GPUs

> Corpus slice 06 — Mojo study corpus commissioned by Volmarr, 2026-10-19.
> Version reflected: **Mojo 1.1.0** (latest stable, released 2026-09-17, per
> https://mojolang.org/releases/; nightly at research time was
> 1.2.0.dev2026101405, 2026-10-14).
> Primary sources: the Mojo Manual and standard-library reference on
> docs.modular.com / mojolang.org, read in full during this session.
> See "## Sources" at the end for the exact URLs read, and §8 for the
> version-sensitive spellings this research found — there are several,
> and they matter.

Mojo's performance story is not one feature. It is a stack, and the
official documentation presents it as one:

1. **SIMD values** — every numeric scalar is a 1-lane SIMD vector; wider
   vectors are the same type with a larger compile-time `size`.
2. **Higher-order algorithm helpers** — `vectorize`, `parallelize`, and
   friends in `std.algorithm` turn a per-chunk or per-item function into
   a whole-buffer operation without hand-written intrinsics or thread
   management.
3. **Compile-time parameterization** — `comptime` values, parameters in
   `[]`, `comptime if` / `comptime for`, and target queries such as
   `simd_width_of` let one source file specialize itself for the exact
   hardware it is compiled for.
4. **The GPU model** — the same language, plus the MAX accelerator
   library (`max.gpu`, `max.gpu.host`), compiles kernel functions for
   NVIDIA, AMD, and Apple silicon GPUs from a single source.
5. **Measurement** — the `std.benchmark` package and the compiler's
   target/optimization flags close the loop.

Each layer is covered below, in that order.

---

## 1. The SIMD type

### 1.1 Definition, from the standard-library reference

The reference page for `SIMD` states its definition and contract
verbatim:

```mojo
@register_passable(trivial)
struct SIMD[dtype: DType, size: Int]
```

> "Represents a small vector that is backed by a hardware vector
> element. SIMD allows a single instruction to be executed across the
> multiple data elements of the vector."
>
> **Constraints:** "The size of the SIMD vector to be positive and a
> power of 2."
>
> - `dtype` (`DType`): The data type of SIMD vector elements.
> - `size` (`Int`): The size of the SIMD vector.

Both parameters are **compile-time** parameters. There is no runtime-sized
Mojo vector type in this design: the lane count is part of the type, so
the compiler always knows exactly which hardware register shape it is
emitting.

`DType` itself is documented as:

> "a set of compile-time constants that specify the precise numeric
> representation of data in order to prevent runtime errors by catching
> type mismatches at compile time. It directly maps to CPU/GPU
> instruction sets, allowing the compiler to generate optimal SIMD and
> vector operations."

You do not instantiate `DType`; you use its constants — `DType.float32`,
`DType.float64`, `DType.int32`, `DType.uint8`, `DType.bfloat16`, the
8-bit float family (`float8_e4m3fn`, `float8_e5m2`, …), `DType.bool`, and
so on — and you can interrogate them at compile time with methods such
as `.is_floating_point()`, `.is_signed()`, `.is_integral()`,
`.is_numeric()`. One documented portability trap: **not all dtypes are
supported on all platforms — the reference gives
`DType.bfloat16` on Apple Silicon as the example of an unsupported
combination.**

The reference's own introductory example:

```mojo
var data = SIMD[DType.float16, 4](1.5, 2.5, 3.5, 4.5)
var dtype = data.dtype
print("Is float:", dtype.is_floating_point())  # True
print("Is signed:", dtype.is_signed())         # True
```

### 1.2 Scalars are SIMD values of size 1

This is the single most important structural fact about Mojo numerics,
and it is visible directly in the `SIMD` reference:

- The default initializer creates an all-zeros vector.
- Initializing from a single scalar **splats** it: the reference states,
  for the `Int`, `UInt`, `Bool`, float-literal, and `SIMD[dtype, 1]`
  initializers alike, "The … value is splatted across all the elements
  of the SIMD vector." Hence `SIMD[DType.uint64, 4](UInt8(42))` is
  `[42, 42, 42, 42]`.
- A variadic initializer `__init__(*elems: SIMD[dtype, 1])` builds a
  vector lane by lane, with the constraint that the number of values
  equals `size`.
- `__bool__` is only defined when `size == 1` ("The size of the SIMD
  vector must be 1") — a multi-lane vector has no single truth value.
- Lane access is `__getitem__(idx) -> SIMD[dtype, 1]` and
  `__setitem__(idx, val)`.

Because a scalar is `SIMD[dtype, 1]`, code written generically over
`size` works for both the scalar and vector cases, and the familiar
aliases (`Float32`, `Int64`, `UInt8`, …) are the size-1 instances of
the same machinery. Generic-width programming is therefore the Mojo
norm, not an advanced trick.

`SIMD` also carries a compile-time alias that matters for §5:

```mojo
alias device_type = SIMD[dtype, size]
```

with the note: "SIMD types are remapped to the same type when passed to
accelerator devices." A SIMD value crosses the host/device boundary
unchanged — unlike `Int`/`UInt`, as §5.4 explains.

### 1.3 Operations: arithmetic, shuffling, reductions

Operators work lane-wise: `a + b`, `a * b`, comparisons, and the other
arithmetic/bitwise dunder methods apply the operation independently in
every lane and return a same-shaped vector. On top of that, the
reference documents a rich set of whole-vector operations. The ones a
performance programmer reaches for most:

**Horizontal reductions** — collapse lanes to a smaller vector
(`size_out` defaults to 1):

```mojo
reduce_add[size_out: Int = 1](self) -> SIMD[dtype, size_out]  # sum of all elements
reduce_mul[size_out: Int = 1](self) -> SIMD[dtype, size_out]  # product
reduce_max[size_out: Int = 1](self) -> SIMD[dtype, size_out]  # maximum element
reduce_min[size_out: Int = 1](self) -> SIMD[dtype, size_out]  # minimum element
reduce_and / reduce_or                                        # bitwise, int/bool only
reduce_bit_count(self) -> Int                                 # total set bits
reduce[func](self)                                            # custom binary operator
```

The constraints are stated per method — e.g. `reduce_max`/`reduce_min`
require an integer or floating-point element type and
`size_out` must not exceed the vector width.

**Lane rearrangement:**

- `split()` — split into two half-width vectors,
  `self_0:N/2, self_N/2:N`.
- `deinterleave()` — two vectors of the even lanes and the odd lanes;
  requires `size > 1`.
- `interleave(other)` — `self_0, other_0, …, self_n, other_n`.
- `rotate_left[shift]()` / `rotate_right[shift]()` — lane rotation with
  wrap-around; `shift_left[shift]()` / `shift_right[shift]()` — lane
  shift with zero fill. All take `shift` as a compile-time parameter.
- `reversed()` — reverse lane order:
  `SIMD[DType.uint8, 4](1, 2, 3, 4).reversed()` is `[4, 3, 2, 1]`.

**Masked selection:**

```mojo
select[dtype: DType](self, true_case: SIMD[dtype, size],
                     false_case: SIMD[dtype, size]) -> SIMD[dtype, size]
```

defined on a boolean vector: the result is
`[true_case[i] if elem else false_case[i] for i, elem in enumerate(self)]`.
This is the branch-free conditional — the vector equivalent of a
predicated instruction — and it is how you write data-dependent logic
without diverging lanes.

**Limits as values:** the type also exposes compile-time aliases
`MAX`, `MAX_FINITE`, `MIN`, `MIN_FINITE` (the largest/smallest values
of the dtype, potentially ±inf for the non-`_FINITE` forms), useful as
reduction identities.

### 1.4 Loading and storing SIMD vectors through pointers

Vector values are only useful if you can move them between memory and
registers in width. The Manual's "Using pointers" page documents the
`Pointer` side of that contract:

- `unsafe_load()` / `unsafe_store()` perform aligned loads and stores.
- `unsafe_strided_load[width](stride)` / `unsafe_strided_store[width](value, stride)`
  load/store every *stride*-th element — the tool for pulling one field
  out of an array-of-structs, or one colour channel out of packed
  pixels.
- `unsafe_gather()` / `unsafe_scatter()` take a **SIMD vector of
  offsets**: for `unsafe_gather()`, the *n*th value in the result is
  loaded from `(pointer address) + offset[n]`. This is true
  gather/scatter addressing, not a loop in disguise.

The Manual's worked strided example, verbatim in structure — invert
the red channel of an RGB image, 8 pixels at a time:

```mojo
def invert_red_channel(ptr: Pointer[mut=True, UInt8, _], pixel_count: Int):
    # Number of values loaded or stored at a time
    comptime simd_width = 8
    # Bytes per pixel, which is also the stride size
    comptime bpp = 3
    for i in range(0, pixel_count * bpp, simd_width * bpp):
        var red_values = ptr.unsafe_offset(i).unsafe_strided_load[
            width=simd_width
        ](bpp)
        # Invert values and store them in their original locations
        ptr.unsafe_offset(i).unsafe_strided_store[width=simd_width](
            ~red_values, bpp
        )
```

Note the honesty of the example: it states up front that it "only
handles images where the number of pixels is evenly divisible by
eight." Tail handling is the caller's problem at this level of the
stack — which is exactly the problem `vectorize` (§2.1) exists to
solve. The page's safety section is equally direct: any `unsafe_`
operation puts allocation size, initialization state, and bounds on
**you**, not the compiler.

A related scalar-vector bridge on the same page: `byte_swap()` swaps
the byte order of a SIMD value (big-endian ↔ little-endian), for file
and network formats.

---

## 2. Algorithm helpers: `vectorize`, `parallelize`, and the `std.algorithm` package

The standard-library index describes the package in one line:

> "`algorithm`: High performance data operations including
> vectorization, functional map, and tiling."

And its own package page expands:

> "The `algorithm` package provides high-performance primitives for
> data-parallel operations. It includes tools for vectorization (SIMD
> operations on contiguous data), parallelization (distributing work
> across multiple cores), and reduction operations (aggregating
> values). These building blocks enable efficient computational kernels
> without manual SIMD intrinsics or thread management."

Its modules are `functional` ("Implements higher-order functions"),
`memory` (implements `parallel_memcpy`), and `reduction` (implements
SIMD reductions), plus a `backend` package for tiling/unswitching
utilities. Imports in current (1.1.0) style are from the package, e.g.:

```mojo
from std.algorithm import map
```

### 2.1 `vectorize`: describe one chunk, apply it to a whole buffer

`vectorize` is a higher-order function: you pass it a **parametric
closure** that knows how to process one SIMD-width chunk at a given
starting index, plus the total element count, and it strides that
closure across the buffer at the requested width — handling the
trailing remainder (the elements left over when the count is not a
multiple of the width) for you.

The current documented pattern (function first, width second; see the
version warning in §8):

```mojo
from std.algorithm.functional import vectorize
from std.sys import simd_width_of

def normalize(data: UnsafePointer[Float32], size: Int,
              lo: Float32, hi: Float32):
    comptime width = simd_width_of[DType.float32]()
    var span = hi - lo

    @parameter
    fn chunk[w: Int](i: Int):
        # Load w values, scale them to [0, 1], store them back — one shot.
        var v = data.load[width=w](i)
        data.store[width=w](i, (v - lo) / span)

    # vectorize strides the whole column in SIMD-width steps,
    # and quietly handles the leftover elements at the end.
    vectorize[chunk, width](size)
```

Read the closure signature carefully, because it is the whole design:
the chunk function is parameterized by `w: Int` — the **actual** width
of the chunk it is being asked to process — and takes the chunk's
starting index `i` as a runtime argument. `vectorize` can therefore
call it with the full width for the body of the buffer and with a
smaller width for the tail, and the same source works for both. An
`unroll_factor` parameter is also supported for loop unrolling.

### 2.2 `parallelize`: the same closure shape, across cores

`parallelize` distributes independent work items across the CPU's
cores and waits for all of them. The work item is again a parametric
closure, this time taking just the item index:

```mojo
from std.algorithm.functional import parallelize

def score_batch(features: UnsafePointer[Float32],
                weights: SIMD[DType.float32, 16],
                scores: UnsafePointer[Float32],
                num_rows: Int):
    @parameter
    fn score_row(row: Int):
        # Each row: one SIMD dot product (16 features at once) + ReLU.
        var x = features.load[width=16](row * 16)
        var s = (x * weights).reduce_add()
        scores[row] = max(s, 0.0)  # row OWNS scores[row] — no races

    # Spread the rows across every core, run, and wait for all of them.
    parallelize[score_row](num_rows)
```

The two helpers compose, and that composition is the idiomatic Mojo
performance pattern: **`parallelize` on the outside (task parallelism
across cores), `vectorize`/explicit SIMD on the inside (data
parallelism within a core)**. The safety discipline is also the same
in both examples: each work item writes only to memory it owns
(`scores[row]`), so there is no shared mutable state to race on.
Mojo's ownership model pushes you toward exactly this shape.

Historical note, kept because it shows the pattern is old and stable
even though its spelling moved: Modular's own v0.5 release post
demonstrated a row-mean kernel built as `parallelize` over rows with a
nested `vectorize` + `reduce_add()` inside each row, reporting a ~52×
speedup over the naive nested-loop version on an Apple M2 Pro. The
*structure* of that 2023 example is identical to the current one; the
argument order of `vectorize` and the spelling of `simdwidthof` are
not (see §8).

### 2.3 The rest of the package

- **`map`** — the sequential functional map, imported in the package
  page's own example (`from std.algorithm import map`).
- **`elementwise`** — the multi-dimensional sibling of `vectorize` used
  heavily on the GPU side: it applies a function over every index of a
  (possibly tiled) tensor, with a SIMD width and a target, and is the
  high-level entry point in the Mojo GPU puzzles for "launch an
  element-wise kernel without hand-writing thread indexing."
- **Reductions** — the `reduction` module implements SIMD reductions
  over buffers, complementing the in-register `reduce_*` methods of
  §1.3.
- **`parallel_memcpy`** — the `memory` module's parallel copy.

> **Verification note:** the stdlib reference's per-function listing
> pages are rendered dynamically; their text layer confirms the
> package, module, and import structure quoted above, but does not
> expose every individual function signature. The `vectorize` /
> `parallelize` examples in this section follow the current
> (function-first) calling pattern as published for the 1.x line; if
> you are porting pre-1.0 code, check §8 before trusting any
> `vectorize[...]` call you find in older posts.


---

## 3. Compile-time parameterization for performance

Mojo's parameter system is its metaprogramming system, and most
performance idioms in the language are applications of it. The rules,
as documented across the Manual and Modular's metaprogramming writing:

- **Parameters live in `[]`; arguments live in `()`.** A parameter is a
  type or value known at compile time; an argument is a runtime value.
  The compiler generates a specialized copy of a parameterized function
  or struct for each distinct parameter combination it is used with.
- **`comptime` names a compile-time value.** In current syntax,
  `comptime width = simd_width_of[DType.float32]()` is an immutable,
  compile-time-evaluated binding (the older spelling for the same idea
  was `alias`). Types can also carry `comptime` **members** — values,
  associated types, and parametric aliases reached through `Self`, as
  in `SIMD`'s own `device_type` and `MAX`/`MIN` aliases, or a trait
  requirement like:

```mojo
trait Repeater:
    comptime count: Int

struct Multispeak[verbosity: Int](Repeater):
    comptime count: Int = Self.verbosity * 2 + 1
```

- **`comptime if` selects code at compile time**, and the unchosen
  branch is not compiled into the binary at all — while still being
  type-checked. The GPU detection idiom in §5.1 is exactly this.
- **`comptime for` unrolls a loop at compile time.** The tiled matmul
  kernel in §6 uses `comptime for k_tile in range(...)` and
  `comptime for k in range(TILE_K)` so the tile loop and the inner
  product loop exist in the binary as straight-line code with constant
  bounds, not as runtime loops.
- **Parametric closures** (`@parameter fn …`) are how `vectorize`,
  `parallelize`, kernel launches, and benchmarks all receive user
  code: the closure is a compile-time parameter, so it is inlined and
  specialized rather than called through a function pointer. Captured
  values are baked in.
- **Target queries are compile-time functions.** The compile-time cheat
  sheet published for the 1.x line summarizes this layer directly:
  `simd_width_of[DType.float32]()` gives the lanes that fit a register
  for that dtype on the target being compiled for;
  `size_of[T]()` / `align_of[T]()` give layout facts; and "sys.info
  answers machine questions at compile time, so one source adapts to
  every target." Compile-time code runs on the CPU during compilation,
  cannot depend on runtime input, and cannot do file I/O, foreign
  calls, or raising calls.
- **Materialization is explicit for heap values.** Scalars baked at
  compile time materialize automatically; heap-backed compile-time
  values (`List`, `Dict`) need `materialize[table]()` to become runtime
  values, and `global_constant[POWERS]()` keeps one static copy to
  index instead of copying.
- **Inlining is controllable.** `@always_inline` on a function (the
  Manual's decorators reference: the compiler copies the body to every
  call site, eliminating call overhead at the cost of binary size;
  `@always_inline("nodebug")` additionally strips debug info and is
  intended for low-level library wrappers) — and the 1.x cheat sheet
  also shows the newer `@inline(.always)` / `@inline(.never)` spelling.
  Treat the decorator spelling as version-sensitive; the *capability*
  is stable.

Why this matters for performance, concretely: tile sizes, SIMD widths,
dtypes, grid/block shapes, and algorithm variants all become
**parameters**, so a single generic kernel source specializes into the
exact instruction sequence for each (dtype, width, tile) combination —
with dead branches, runtime bound checks on constant bounds, and
closure-call overhead compiled away before the binary exists. The cost
is equally concrete and worth stating: every distinct specialization
is real code the compiler must generate, so unconstrained parameter
sweeps explode compile time and binary size. Parameterize the axes
that change the instruction stream (dtype, width, tile size), not
every number in sight.

---

## 4. Performance methodology: measure, then compile for the target

### 4.1 `std.benchmark`: the documented measurement tool

The standard-library package page describes it as:

> "Performance benchmarking: statistical analysis and detailed
> reports. The `benchmark` package provides tools for measuring and
> analyzing the performance of Mojo code. It enables statistical
> benchmarking with automatic warmup, batch execution, and
> comprehensive reporting including mean, min, max, and total time
> statistics across multiple runs."

The core API is `run()`: pass any function, get back a `Report`.

```mojo
from std.benchmark import run
from std.time import sleep

def sleeper():
    sleep(.01)

var report = run(sleeper)
print(report.mean())
report.print()
```

```text
---------------------
Benchmark Report (s)
---------------------
Mean: 0.012265747899159664
Total: 1.459624
Iters: 119
Warmup Mean: 0.01251
Warmup Total: 0.025020000000000001
Warmup Iters: 2
Fastest Mean: 0.0121578
Slowest Mean: 0.012321428571428572
```

Points the page documents that define the methodology:

- **Warmup is built in and reported separately** — the report carries
  `Warmup Mean / Warmup Total / Warmup Iters` alongside the measured
  batches, so cold-start cost is visible rather than silently averaged
  in.
- **`report.print_full()`** prints every batch (per-batch iterations,
  mean, duration), not just the summary — use it when you suspect
  variance, throttling, or a bimodal distribution.
- **Units are selectable:** `from std.benchmark import run, Unit`, then
  `report.print(Unit.ms)`; the units are aliases for string constants,
  so `report.mean("ms")` also works and returns e.g. `12.199…`.
- **`run()` takes four behaviour arguments** after the function —
  documented by example as (warmup iterations, max iterations, min
  total time, max total time): `run(sleeper, 5)` sets 5 warmup
  iterations; `run(sleeper, 1, 2, 3, 4)` sets 1 warmup iteration, 2 max
  iterations, 3 s minimum total time, 4 s maximum total time. The page
  notes that **minimum total time takes precedence over max
  iterations** — the harness will keep iterating past your cap rather
  than report a too-short measurement.
- The package's modules are `bencher` (the comprehensive `Bench` /
  `Bencher` infrastructure), `benchmark`, `compiler` ("Provides
  compiler hints to prevent optimization of benchmark code"),
  `memory` ("Provides memory barrier utilities for preventing compiler
  optimizations"), and `quick_bench` (a simplified interface). The
  existence of dedicated compiler-hint and memory-barrier modules is
  itself the methodology lesson: **a benchmark the optimizer can
  delete is not a benchmark** — keep results alive and order memory
  operations deliberately. (The GPU puzzle corpus makes the same point
  from the kernel side, calling `keep(output.unsafe_ptr())` and
  `bench_ctx.synchronize()` inside its benchmark workflows so the
  timed work is neither optimized away nor timed before the GPU
  finishes.)

For quick one-off timings, the stdlib index also lists the `time`
package: "Timing operations: monotonic clocks, performance counters,
sleep, `time_function`."

### 4.2 Compile flags and target selection

The Mojo CLI reference documents a single shared set of compilation
options across `mojo run` / `mojo build` / `mojo test` / `mojo debug`
(the page read in full for this slice is `mojo debug`, which states
that its build-and-debug mode accepts "any compilation options
expected by `mojo run`"). The performance-relevant ones:

**Optimization:**

- `--optimization-level <LEVEL>`, `-O` — "a number between 0 and 3.
  The default is 3." (`--no-optimization` is level 0.) Note the
  debugger's default differs on purpose: `mojo debug` builds with
  `-O0` and full debug info unless you override it — never benchmark a
  debug build.
- `--debug-level <LEVEL>`, `-g` — `none` (default), `line-tables`, or
  `full`.
- `--fp-mode contract=fast|off` — `contract=fast` is the default and
  "is like Clang's `-ffp-contract=fast`: it fuses `a + b*c` into an FMA
  across statements," breaking strict IEEE compliance; `contract=off`
  disables contraction. This flag changes *results*, not just speed —
  record which setting a benchmark used.
- `-D <KEY=VALUE>` — defines a compile-time value readable from the
  program (the CLI pages name the accessor module differently across
  versions — `sys.param_env` in one, `std.defines` in another; see
  §8). This is the documented way to bake benchmark variants,
  sizes, and feature switches into separate binaries.
- `--num-threads <NUM>`, `-j` — compilation parallelism (default 0 =
  all threads). Affects build time, not the produced code.

**Target selection:**

- `--target-triple <TRIPLE>` (default: host), `--target-cpu <CPU>`
  (default: host CPU), `--target-features <FEATURES>` (default: host
  features) — the CPU-side specialization knobs. Compiling on the
  machine you run on gets you its SIMD width for free via
  `simd_width_of`; cross-compiling means choosing these deliberately.
- `--march <ARCHITECTURE>`, `--mcpu <CPU>`, `--mtune <TUNE>` — the
  architecture / codegen-CPU / tuning-CPU trio.
- `--target-accelerator <ACCELERATOR>` — "Sets the GPU or accelerator
  architecture for heterogeneous computing (e.g., sm_90 for NVIDIA
  H100, gfx942 for AMD MI300)." One executable per accelerator
  architecture: pair this with `mojo build` when the build machine has
  no GPU of the target kind.
- Introspection flags that belong in every build script:
  `--print-effective-target`, `--print-supported-targets`,
  `--print-supported-cpus`, `--print-supported-accelerators` — ask the
  compiler what it thinks the target is instead of assuming.
- `--sanitize address|thread` exists for correctness runs (memory and
  threading checkers). Sanitizer builds are for finding bugs, not for
  timing.

**Methodology summary, as the docs imply it:** benchmark with
`std.benchmark` at `-O3` (the default) on the real target; report mean
*and* fastest/slowest with warmup excluded; synchronize before reading
GPU results (§5.2); pin and record `--target-cpu` /
`--target-accelerator` and `--fp-mode`; and re-measure after any
parameter change (width, tile, unroll) rather than assuming wider is
faster — a wider SIMD type than the register file wants, or a tile
bigger than shared memory wants, loses.

---

## 5. The GPU programming model

### 5.1 Where the APIs live — read this first

The GPU programming fundamentals guide is explicit about the split,
and it is the most version-sensitive fact in this whole file:

> "The Mojo language, together with the open source MAX accelerator
> library, allows you to develop GPU-enabled applications. The
> `max.gpu` package of the MAX accelerator library includes several
> subpackages for interacting with GPUs, with the `max.gpu.host`
> package providing most of the commonly used APIs. The APIs that you
> use inside kernel functions — such as the thread and block indices —
> come from the `max.gpu` package itself. The Mojo standard library's
> `sys` package contains a few basic introspection functions for
> determining whether a system has a supported GPU."

So, in the current (1.1.0) documentation:

| Need | Import |
| --- | --- |
| Device management, buffers, launches | `from max.gpu.host import DeviceContext` |
| Thread/block/grid indices (in-kernel) | `from max.gpu import block_dim, block_idx, thread_idx, global_idx` |
| Block synchronization (in-kernel) | `from max.gpu.sync import barrier` |
| GPU presence checks (host) | `from std.sys import has_accelerator, has_nvidia_gpu_accelerator, has_amd_gpu_accelerator, has_apple_gpu_accelerator` |
| Multi-dimensional device data | `from layout import TileTensor, stack_allocation` / `from layout.tile_layout import row_major` |

> ⚠️ **Version-sensitive — flag, do not paper over:** older Mojo/MAX
> code, and even some current Modular blog code, spells these imports
> differently: `from gpu import …`, `from gpu.host import DeviceContext`,
> and `from std.gpu import DeviceContext` / `from std.gpu import global_idx`
> all appear in Modular-published material from different points in the
> 1.x line. The Manual's fundamentals and block/warp guides — the
> canonical learning path — use the **`max.gpu` / `max.gpu.host`** forms
> quoted above. If code you find does not compile, the import block is
> the first place to look, and the fix is to match the Manual of the
> version you have installed, not the blog post you copied from.

Supported targets, per the same guide: NVIDIA, AMD, and Apple silicon
GPUs, from the same Mojo source, assuming no device-specific features
are used. `DeviceContext` can be told which vendor API to use —
`"cuda"` (NVIDIA), `"hip"` (AMD), `"metal"` (Apple).

### 5.2 The host/device pattern and `DeviceContext`

The documented programming model divides work strictly:

- The **CPU (host)** manages program flow and coordinates GPU
  operations.
- The **GPU (device)** executes parallel computations across many
  threads.
- **You explicitly manage data exchange** between host and device
  memory.

And every GPU program follows the same four steps: (1) initialize data
in host memory; (2) allocate device memory and copy host → device;
(3) execute a kernel; (4) copy results device → host. Execution is
**asynchronous**: each `DeviceContext` owns a stream of queued
operations that execute in enqueue order while the CPU continues, and
the CPU must call `ctx.synchronize()` before trusting any result.

`DeviceContext` is "a logical instance of a GPU device" providing
allocation, copies, and kernel compile/launch. Devices are indexed
from 0 (the default); `DeviceContext.number_of_devices()` reports how
many exist; the constructor takes optional `device_id` and `api`
arguments and raises if no matching GPU exists.

The guide's complete canonical example — add a scalar to every element
of a vector on the GPU — is worth reproducing nearly whole, because
every real Mojo GPU program is this shape with a bigger kernel:

```mojo
from std.math import iota
from std.sys import exit, has_accelerator
from max.gpu.host import DeviceContext
from max.gpu import block_dim, block_idx, thread_idx

comptime num_elements = 20

def scalar_add(
    vector: Pointer[Float32, MutAnyOrigin], size: Int32, scalar: Float32
):
    # Calculate the global thread index within the entire grid.
    var idx = block_idx.x * block_dim.x + thread_idx.x
    # Bounds checking: crucial when the number of threads
    # doesn't exactly match vector size.
    if idx < Int(size):
        vector[unsafe_offset=idx] += scalar

def main() raises:
    comptime if not has_accelerator():
        print("No GPUs detected")
        exit(0)
    else:
        # Initialize GPU context for device 0 (default GPU device).
        var ctx = DeviceContext()

        # Create a buffer in host (CPU) memory.
        var host_buffer = ctx.enqueue_create_host_buffer[.float32](num_elements)
        ctx.synchronize()  # Wait for buffer creation to complete.
        iota(host_buffer.as_span())
        print("Original host buffer:", host_buffer)

        # Create a buffer in device (GPU) memory.
        var device_buffer = ctx.enqueue_create_buffer[.float32](num_elements)

        # Copy data from host memory to device memory.
        ctx.enqueue_copy(src_buf=host_buffer, dst_buf=device_buffer)

        # Compile the scalar_add kernel for execution on the GPU.
        var scalar_add_kernel = ctx.compile_function[scalar_add]()

        # Launch: 1 block, num_elements threads (one per element).
        ctx.enqueue_function(
            scalar_add_kernel,
            device_buffer,
            Int32(num_elements),
            Float32(20.0),
            grid_dim=1,
            block_dim=num_elements,
        )

        # Copy results back, wait, and read them on the host.
        ctx.enqueue_copy(src_buf=device_buffer, dst_buf=host_buffer)
        ctx.synchronize()
        print("Modified host buffer:", host_buffer)
```

Output:

```text
Original host buffer: HostBuffer([0.0, 1.0, 2.0, ..., 19.0])
Modified host buffer: HostBuffer([20.0, 21.0, 22.0, ..., 39.0])
```

Details in that example that generalize:

- The GPU-presence guard is a **`comptime if`**: kernel compilation
  requires a compatible GPU development environment, so the
  no-GPU branch must be removed at compile time, not merely skipped at
  runtime.
- Every `enqueue_*` method is asynchronous and returns immediately.
  `synchronize()` is called twice for two different reasons: before
  *writing* the freshly created host buffer, and before *reading* the
  results.
- Compiling once (`compile_function`) and launching the compiled kernel
  repeatedly avoids recompilation overhead; for a one-shot kernel,
  `ctx.enqueue_function[scalar_add](args…, grid_dim=…, block_dim=…)`
  compiles and enqueues in a single step. Both forms type-check kernel
  arguments **at compile time**.

### 5.3 Buffers: `DeviceBuffer` and `HostBuffer`

- `ctx.enqueue_create_buffer[.float32](1024)` creates a `DeviceBuffer`
  in the device's **global memory**, accessible by all threads of all
  kernels on that context. The dtype is a compile-time parameter; the
  size is a runtime argument.
- `ctx.enqueue_create_host_buffer[.float32](1024)` creates the
  host-side analogue. Because creation is enqueued asynchronously, you
  must `synchronize()` before writing to or reading from it.
- `ctx.enqueue_copy(src_buf=…, dst_buf=…)` copies host→device,
  device→host, or device→device (multi-GPU). `enqueue_copy_to()` /
  `enqueue_copy_from()` on the buffers themselves are convenience
  equivalents. A host-memory `Pointer` may also be a copy source or
  destination — a `Pointer` referencing *device* memory here is an
  error.
- `device_buffer.map_to_host()` returns a `HostBuffer` as a **context
  manager** holding a copy of the device data; modifications are
  copied back when the `with` block exits. The guide recommends it
  only for testing/prototyping, because of the bidirectional copies
  and synchronization it hides.
- **No explicit free:** both buffer types are destroyed by Mojo's
  normal ownership/lifecycle analysis — the compiler inserts the
  destructor call at the last use. There is no `free()` to forget.

### 5.4 Kernel functions: the rules

From the fundamentals guide, a kernel is "simply a function that runs
on a GPU," with hard rules:

- **Kernels must be non-raising.** (Functions *called from* kernels
  that need error handling may use typed errors whose types do not
  allocate heap memory.)
- **Kernels have no return value.** Results are written into a buffer
  passed in as an argument.
- **Every argument must conform to `DevicePassable`.** The trait
  declares a `comptime` member `device_type` mapping the host type to
  the type the kernel actually receives:

| Host type | Device type | Description |
| --- | --- | --- |
| `SIMD[dtype, width]` | `SIMD[dtype, width]` | Small vector backed by a hardware vector element |
| `DeviceBuffer[dtype]` | `Pointer[SIMD[dtype, 1]]` | Memory buffer of `dtype` values |
| `TileTensor` | `TileTensor` | Multi-dimensional data abstraction (see §7) |

  This is why the kernel above takes
  `Pointer[Float32, MutAnyOrigin]` while the host passes a
  `DeviceBuffer`: the buffer *becomes* a pointer across the boundary.
  Using `DeviceBuffer` itself inside a kernel is an error.
- **`Int` and `UInt` are NOT device-passable** — the guide calls this
  out as the one exception to the SIMD row. Their width depends on the
  target, so passing one into a kernel is a compile-time error. Pass
  `Int32` / `Int64` (hence `Int32(num_elements)` in the launch above).
  Using `Int` *inside* the kernel body is fine.

### 5.5 Grids, blocks, threads, warps

A kernel launch executes a **grid** of **thread blocks**, each block
containing threads, organized in up to three dimensions. Dimensions
are given as the `grid_dim` / `block_dim` keyword arguments to
`enqueue_function`, as an `Int`, a tuple, or a `Dim`; missing `y`/`z`
default to 1 (`64` means `(64, 1, 1)`; `(2, 2)` means `(2, 2, 1)`).

Inside the kernel, five compile-time values describe where a thread
sits — all `Int`-valued, all from `max.gpu`:

| Value | Meaning |
| --- | --- |
| `grid_dim` | Dimensions of the grid (`.x`, `.y`, `.z`) |
| `block_dim` | Dimensions of the thread block |
| `block_idx` | Index of this block within the grid |
| `thread_idx` | Index of this thread within its block |
| `global_idx` | `block_dim * block_idx + thread_idx`, per dimension |

The canonical index computation is therefore either manual —
`block_idx.x * block_dim.x + thread_idx.x`, as in `scalar_add` — or
the precomputed `global_idx.x`. **Bounds-check it**: grids rarely
divide the data evenly, and the guide's `process_vector` pattern is
simply `if global_idx.x < Int(size): …`.

Hardware executes a block by splitting it into **warps** — subsets of
threads (32 or 64 on most current architectures) scheduled together by
a streaming multiprocessor. A block whose thread count is not a
multiple of the warp size still pays for a full final warp: 100 threads
at warp size 32 means 3 full warps plus a 4-thread warp occupying 32
slots. Choose block sizes as warp multiples unless you have measured a
reason not to.

One documented platform quirk: on Apple silicon GPUs, each `print()`
inside a kernel currently supports at most one string literal argument;
the Manual's examples therefore print numbers from kernels and headers
from the host. This restriction does not apply on NVIDIA or AMD.


---

## 6. Block and warp operations, synchronization

The Manual's second GPU guide covers coordination inside a kernel.
Its framing is worth keeping: **synchronization primitives**
(`barrier()`, `syncwarp()`) only coordinate — they enforce execution
order and memory visibility and compute nothing; **collective
operations** (reductions, broadcasts, prefix sums) coordinate *and*
compute. Use the first when you manage shared memory between phases;
use the second when you need the aggregate itself.

### 6.1 `barrier()`: block-wide synchronization

`barrier()` (from `max.gpu.sync`, documented as `gpu.sync.barrier()`)
is both an **execution barrier** — no thread in the block proceeds
until every thread in the block arrives — and a **memory fence**: all
writes to shared (and, block-visibly, global) memory made before the
barrier are visible to all threads in the block after it. It is
functionally equivalent to CUDA/HIP `__syncthreads()` and Metal
`threadgroup_barrier(mem_flags::mem_threadgroup)`.

The canonical use is the shared-memory producer/consumer cycle:
cooperatively load a tile global → shared, `barrier()`, compute from
shared, `barrier()` again before overwriting the tile. The deadlock
rule is absolute and the guide states it as a caution: **a `barrier()`
must be encountered by all threads in the block** — inside a
conditional, it is only safe if every thread in the block is
guaranteed to evaluate the condition identically.

### 6.2 Block collectives: `gpu.primitives.block`

Higher-level operations that handle their own synchronization and
shared-memory management internally:

- `sum(val)` — sum of `val` across all threads in the block.
- `max(val)` / `min(val)` — block-wide maximum / minimum.
- `broadcast(val, src_thread=0)` — broadcast one thread's value to the
  block.
- `prefix_sum[exclusive=False](val)` — inclusive (default) or
  exclusive scan across the block: inclusive maps
  $[x_0,x_1,x_2,x_3]$ to $[x_0, x_0{+}x_1, x_0{+}x_1{+}x_2, \dots]$;
  exclusive starts from 0.

Guidance from the guide: use block operations to aggregate across a
whole block (possibly several warps), warp operations (§6.3) to
aggregate within a warp (significantly faster), and a hybrid —
warp-reduce first, then combine warp results at block level — for
large reductions.

### 6.3 Warp operations: `syncwarp()`, shuffles, warp collectives

A warp's threads execute simultaneously, so intra-warp communication
through registers is the fastest coordination on the GPU.

**`syncwarp()`** reconverges threads of one warp after divergent
control flow. It takes an optional lane `mask` (default −1 = all
lanes). Its behaviour is deliberately portable-but-different per
vendor, and the guide spells out all three cases:

- **NVIDIA** (Volta and newer, independent thread scheduling): a real
  hardware instruction (`bar.warp.sync`); necessary for correctness
  of warp-synchronous algorithms.
- **AMD**: wavefronts execute in lock-step and cannot diverge the same
  way, so `syncwarp()` is a **no-op** — the compiler emits nothing.
- **Apple silicon**: execution synchronization within a SIMD group
  only, with no memory fence; lane masks are unsupported and the
  `mask` argument is ignored.

**Shuffle operations** (`gpu.primitives.warp`) exchange values
register-to-register between lanes, with an optional participation
`mask` that also provides implicit synchronization:

- `shuffle_up(value, offset)` — receive from lane `current − offset`
  (undefined if that lane is < 0).
- `shuffle_down(value, offset)` — receive from lane `current + offset`
  (undefined if ≥ warp size).
- `shuffle_xor(value, offset)` — exchange with lane `current XOR offset`;
  the butterfly pattern behind FFTs and fast reductions.
- `shuffle_idx(value, offset)` — every lane receives lane `offset`'s
  value (a broadcast from an arbitrary lane).
- `broadcast(value)` — convenience wrapper broadcasting lane 0.

Boundary rule: out-of-range source lanes yield **undefined** values —
sliding-window code must guard its edges explicitly. And with a full
mask in divergent code, every lane must eventually reach the shuffle
or the participating lanes hang.

**Warp collectives** (`gpu.primitives.warp`): `sum(value)`,
`max(value)`, `min(value)`, and `prefix_sum[exclusive=False](value)` —
the same four shapes as the block level, warp-scoped, with results
broadcast to all lanes, using hardware intrinsics where available and
falling back to shuffle-based implementations elsewhere. The guide's
example of that fallback philosophy: a warp `max()` automatically
uses specialized `redux` instructions on the newest NVIDIA hardware
and a shuffle implementation everywhere else — "You get performance
where available and correctness everywhere else."

Two usage rules the guide is firm about:

- **Shuffle and warp-collective operations synchronize implicitly.**
  Calling `syncwarp()` immediately before one is redundant.
- **Do not hardcode warp size 32.** Use the `gpu.WARP_SIZE` constant;
  AMD wavefronts are 64. For genuinely architecture-specific tuning,
  branch at compile time:

```mojo
from std.sys import is_amd_gpu, is_apple_gpu, is_nvidia_gpu

def adaptive_algorithm():
    comptime if is_nvidia_gpu():
        nvidia_optimized_path()
    elif is_amd_gpu():
        amd_optimized_path()
    elif is_apple_gpu():
        apple_optimized_path()
    else:
        # Conservative fallback for future hardware support
        portable_path()
```

### 6.4 Races, atomics, and advanced primitives

The guide's correctness section gives the minimal race example —
`shared_counter[0] += my_value` from many threads loses updates
because the read-modify-write is not atomic — and the fix, an atomic
operation (`Atomic.fetch_add`). Beyond the portable core, it lists
architecture-specific mechanisms (consult the API reference for
current availability): on NVIDIA only — semaphores for inter-CTA
synchronization, named barriers (barrier IDs 0–16) for split-phase and
TMA pipelines, `mbarrier_*` functions for async memory operations,
`threadfence()` for scoped memory ordering, and async bulk-copy group
commit/wait; on AMD only — schedule barriers and `s_waitcnt`
primitives (CDNA only). None of these are portable; all of them are
behind the same "single portable API first" philosophy.

### 6.5 The tiled matmul: everything together

The guide's capstone is a tiled matrix multiplication whose kernel
combines §5 and §6 with §7's tensors. Its skeleton (imports and
layout declarations verbatim in structure):

```mojo
from std.math import ceildiv
from std.sys import exit, has_accelerator
from max.gpu.sync import barrier
from max.gpu.host import DeviceContext
from max.gpu import thread_idx, block_idx
from layout import TileTensor, stack_allocation
from layout.tile_layout import row_major

comptime float_dtype = DType.float32
comptime MATRIX_SIZE = 64
comptime TILE_SIZE = 16
# … M/N/K and tile constants derived from the two above …

comptime matrix_a_layout = row_major[MATRIX_M, MATRIX_K]()  # A: M x K
comptime matrix_b_layout = row_major[MATRIX_K, MATRIX_N]()  # B: K x N
comptime matrix_c_layout = row_major[MATRIX_M, MATRIX_N]()  # C: M x N

def tiled_matmul_kernel(
    matrix_a: TileTensor[float_dtype, type_of(matrix_a_layout), ImmutAnyOrigin],
    matrix_b: TileTensor[float_dtype, type_of(matrix_b_layout), ImmutAnyOrigin],
    matrix_c: TileTensor[float_dtype, type_of(matrix_c_layout), MutAnyOrigin],
):
    var thread_x = thread_idx.x
    var thread_y = thread_idx.y
    var global_row = block_idx.y * TILE_M + thread_y
    var global_col = block_idx.x * TILE_N + thread_x

    # Allocate shared memory tiles for fast on-chip access
    var tile_a_shared = stack_allocation[
        float_dtype, address_space=.SHARED
    ](tile_a_layout)
    var tile_b_shared = stack_allocation[
        float_dtype, address_space=.SHARED
    ](tile_b_layout)

    var accumulator: matrix_c.ElementType = 0.0

    comptime for k_tile in range(0, MATRIX_K, TILE_K):
        # … cooperative, bounds-checked load of both tiles into shared …
        barrier()  # all loads complete before any compute
        comptime for k in range(TILE_K):
            accumulator += tile_a_shared[thread_y, k] * tile_b_shared[k, thread_x]
        barrier()  # all compute complete before tiles are overwritten

    if (global_row < MATRIX_M) and (global_col < MATRIX_N):
        matrix_c[global_row, global_col] = accumulator
```

The guide's analysis stresses: shared memory is fast but small ("a
typical block might have only 48KB"); the two barriers are *both*
essential — the first prevents read-before-write races, the second
prevents write-during-read races — and together they implement a safe
producer–consumer cycle: load → barrier → compute → barrier → repeat.

---

## 7. Layouts and tensors on device: `TileTensor` and `Layout`

### 7.1 What a layout is

A **layout** describes both the logical shape of a tensor and how its
elements map to physical addresses: a shape (e.g. `(1024, 8)`) and a
stride (e.g. `(8, 1)`), written together as `((1024, 8):(8, 1))`. A
stride of 1 in the final dimension is row-major. Layouts can nest —
`((1024, (4, 2)):(8, (2, 1)))` describes a tiled/interleaved physical
arrangement — and they can carry a **swizzle**: a non-linear bit
permutation that spreads simultaneous warp accesses across shared-
memory banks to avoid bank conflicts. A swizzle is not expressible as
shape+stride, which is precisely why layout is a first-class
abstraction rather than index arithmetic.

### 7.2 `TileTensor`: layout as a compile-time property of the type

`TileTensor` is, per the 26.3 release announcement, "the successor to
`LayoutTensor`", built so that "memory layout is a compile-time
property of the tensor itself, so the swizzles, strides, and indexing
that GPU kernels require are checked by the type system rather than
maintained by hand." The fundamentals guide lists it as a
`DevicePassable` type that passes to kernels *as itself* — no pointer
lowering.

Construction (from Modular's TileTensor series; host and device,
static and dynamic shapes):

```mojo
from layout import TileTensor, Idx, row_major

def main() raises:
    a = alloc[Float32](16)
    tensor_8s = TileTensor(a, row_major[8]())              # static shape
    tensor_8s_idx = TileTensor(a, row_major(Idx(8)))       # static via Idx
    row, col = 8, 2
    tensor_8d2 = TileTensor(a, row_major(Idx(row), Idx(col)))  # dynamic

    with DeviceContext() as ctx:
        b = ctx.enqueue_create_buffer[DType.float32](16)
        gmem_8s = TileTensor(b, row_major[8]())            # device, static
        gmem_8d = TileTensor(b, row_major(Idx(col)))       # device, dynamic
```

> ⚠️ **Version-sensitive:** this TileTensor-series snippet imports
> `DeviceContext` as `from std.gpu import DeviceContext`, while the
> Manual's fundamentals guide (§5.1) imports it from
> `max.gpu.host`. Both spellings appear in current Modular material.
> Treat the Manual as canonical for the version you install, and
> expect this import to keep moving in the 1.x line.

Shared-memory tensors use the same layout language through
`stack_allocation` (already seen in §6.5, in both spellings:
`stack_allocation[dtype, address_space=.SHARED](layout)` in the
Manual, and `stack_allocation[DType.float32, AddressSpace.SHARED](col_major(…))`
in the TileTensor series).

Inside kernels, `TileTensor` gives checked, multi-dimensional access —
`matrix_c[global_row, global_col] = accumulator` instead of
`ptr[unsafe_offset=row * width + col]` — plus tiling and distribution:

```mojo
g_tile = src.tile[32, 8](tile_row, tile_col)   # a view, no copy
s_tile = stack_allocation[
    dtype=DType.float32, address_space=AddressSpace.SHARED
](row_major[32, 8]())
# distribute fragments to threads under a thread layout (+ optional swizzle):
g_frag = g_tile.distribute[thread_layout](tid)
s_frag = s_tile.distribute[thread_layout, Swizzle(3, 0, 3)](tid)
```

And constraints are part of function signatures: a kernel can declare
`where tensor.static_shape[0] == 4`, or assert with
`comptime assert t.flat_rank == 2`, or require row-majorness with
`where t.is_row_major` — violations are compile-time errors pointing
at the violated constraint, not wrong numbers at runtime. Element
access is likewise typed by the layout: for a tensor with
`element_size=4`, `t[0, 0]` *is* a `SIMD[_, 4]`; `t.vectorize[4]()`
produces the vectorized view of a scalar-element tensor.

A typed vector-add kernel shows the call-site guarantee:

```mojo
from std.gpu import global_idx
from layout import TileTensor

def vector_add_kernel[dtype: DType](
    a: TileTensor[dtype, element_size=1, ...],
    b: TileTensor[dtype, element_size=1, ...],
    c: TileTensor[mut=True, dtype, element_size=1, ...],
    n: Int,
):
    comptime assert a.flat_rank == 1, "a must be rank 1"
    comptime assert b.flat_rank == 1, "b must be rank 1"
    comptime assert c.flat_rank == 1, "c must be rank 1"
    idx = global_idx.x
    if idx < n:
        c[idx] = a[idx] + b[idx]
```

All three operands are guaranteed by the signature to share one
`dtype` and scalar element size — the class of mismatch that an
unconstrained template kernel would only discover as bad output.

### 7.3 `LayoutTensor`: the predecessor, still present

The `layout` package reference still documents both worlds: modules
for `layout`, `layout_tensor` ("Provides the `LayoutTensor` type for
representing multidimensional data"), `tile_tensor` ("TileTensor type
for structured memory access with compile-time layout information"),
`runtime_layout` / `runtime_tuple` (for shapes and strides not known
at compile time), `swizzle`, `tensor_core`, and TMA support. Existing
code — including much of the GPU puzzle corpus — uses `LayoutTensor`
with `Layout.row_major(...)` and `.tile[...]` views; new code should
follow the Manual's current guides, which teach `TileTensor`. When
reading other people's code, treat `LayoutTensor` vs `TileTensor` as a dating
signal, not a semantic difference in intent: both exist to make
layout explicit, typed, and checkable.

---

## 8. Version-sensitive items found in this research (consolidated)

Mojo moved fast through 0.x and is still moving in 1.x. Every item
below was *observed* in sources read for this slice:

1. **`vectorize` argument order flipped.** Pre-1.0 Modular examples:
   `vectorize[simd_width, fill_val](count)` (width first). Current 1.x
   pattern: `vectorize[chunk_fn, width](size)` (function first).
2. **`simdwidthof` → `simd_width_of`.** The old name
   `simdwidthof[DType.float32]()` (from `sys.info`) is now
   `simd_width_of[DType.float32]()` (from `std.sys` / `sys`).
3. **GPU import homes moved repeatedly.** `gpu` → `gpu.host` →
   `max.gpu` / `max.gpu.host` (Manual, current) — with
   `std.gpu` spellings still appearing in current Modular blog code.
   `barrier` is `max.gpu.sync.barrier` in the Manual's matmul;
   block/warp collectives are documented as `gpu.primitives.block` /
   `gpu.primitives.warp` modules.
4. **`LayoutTensor` → `TileTensor`** as the taught tensor type
   (announced with Mojo 1.0 beta in Modular 26.3); both remain in the
   `layout` package.
5. **`alias` → `comptime`** for compile-time value declarations;
   `@parameter if` / `@parameter fn` in old code correspond to
   `comptime if` and parametric closures in current code (the
   `@parameter` decorator on closures is still the spelling used by
   `vectorize`/`parallelize` examples).
6. **`-D` define accessor renamed:** one CLI page reads the value via
   `sys.param_env`, another via `std.defines`. Check your version's
   CLI reference.
7. **Inlining decorator:** `@always_inline` (Manual decorators
   reference) vs `@inline(.always)` / `@inline(.never)` (1.x compile-
   time cheat sheet).
8. **`Tensor` (old `from tensor import Tensor`) is gone** from the
   current teaching path; pre-1.0 performance examples built on it
   (including the v0.5 row-mean benchmark) do not port mechanically —
   their *patterns* (parallelize ∘ vectorize ∘ reduce) do.
9. **Host/device function distinction:** there is no `__global__` /
   `__device__` keyword split in Mojo. A "kernel" is an ordinary Mojo
   function that is compiled for the device via
   `DeviceContext.compile_function` / `enqueue_function` and obeys the
   kernel rules of §5.4; host code is everything else in the same
   file. Any source showing CUDA-style qualifiers in Mojo code is not
   describing current Mojo.

---

## Sources

Exact URLs read during this research session (official Modular/Mojo
documentation unless marked otherwise):

- https://mojolang.org/releases/ — Mojo releases; latest stable 1.1.0 (2026-09-17)
- https://docs.modular.com/mojo/manual/gpu/fundamentals/ — GPU programming fundamentals (DeviceContext, kernels, buffers, DevicePassable, grid/block/thread indexing)
- https://docs.modular.com/mojo/manual/gpu/block-and-warp/ — GPU block and warp operations and synchronization (barrier, syncwarp, shuffles, block/warp collectives, tiled matmul)
- https://docs.modular.com/mojo/manual/pointers/unsafe-pointers/ — Using pointers (SIMD loads/stores: strided, gather/scatter; byte_swap)
- https://docs.modular.com/mojo/stdlib/builtin/simd/SIMD/ — SIMD struct reference (definition, splat initializers, reductions, shuffles, select, device_type)
- https://docs.modular.com/mojo/stdlib/builtin/dtype/DType/ — DType reference
- https://docs.modular.com/mojo/std/algorithm/ — algorithm package page (vectorization / parallelization / reduction; `from std.algorithm import map`)
- https://mojolang.org/docs/std/algorithm/functional/ — functional module page
- https://mojolang.org/docs/std/benchmark/ — benchmark package page (`run`, `Report`, `Unit`, warmup/batch semantics, module list)
- https://mojolang.org/docs/std/ — standard library index (package descriptions for algorithm, benchmark, time, sys, python, …)
- https://mojolang.org/docs/cli/debug/ — mojo CLI compilation & target options (shared with mojo run/build: -O levels, --target-*, --target-accelerator, --fp-mode, -D)
- https://docs.modular.com/mojo/cli/test/ — mojo test CLI page (same compilation/target option set, via search read)
- https://www.modular.com/blog/tiletensor-part-1-safer-more-efficient-gpu-kernels — TileTensor Part 1 (layouts, swizzles, construction, tile/distribute, constraints) [Modular blog]
- https://www.modular.com/blog/modular-26-3-mojo-1-0-beta-max-video-gen-and-more — Modular 26.3 / Mojo 1.0 beta announcement (TileTensor as LayoutTensor successor) [Modular blog, via search read]
- https://www.modular.com/blog/whats-new-in-mojo-sdk-v0-5 — Mojo SDK v0.5 post (historical vectorize/parallelize/benchmark example; old spellings) [Modular blog, via search read]

Secondary sources read via search for the current `vectorize` /
`parallelize` calling pattern and cross-checked against the official
package pages above (not official documentation; flagged in §2.3):

- https://hackernoon.com/mojo-lets-you-parallelize-ai-code-without-leaving-python-behind
