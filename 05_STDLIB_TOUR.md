# A Tour of the Mojo Standard Library

*Signatures and examples below are taken from the standard library API reference as published for Mojo 1.1.0 (the reference pages themselves carry "Version: 1.1.0"). Import paths use the current `std.` prefix — e.g. `from std.collections import List` — exactly as the 1.1.0 reference shows. Where a signature is long, the essential form is given and the full text is on the linked reference page (see Sources).*

## 1. Shape of the library

The standard library is organized into packages. The ones a newcomer touches first:

- `prelude` — fundamental types, traits, and operations, auto-imported into every file. `Int`, `String`, `List`, `print`, and friends need no import.
- `builtin` — the language foundation: built-in types and traits.
- `collections` — `List`, `Dict`, `Set`, `Optional`, `String`, plus `Deque`, `Counter`, `InlineArray`, `LinkedList`, bitsets, and more.
- `math` — functions and constants: trig, exponential, logarithmic, special functions.
- `io` — console input/output, file handling, and the `Writer`/`Writable` traits.
- `memory` — pointers and allocation (covered in the companion file, *Ownership and Memory*).
- `testing` — assertions and test suites.
- Beyond those: `algorithm`, `os`, `pathlib`, `sys`, `iter`, `time`, `random`, `ffi`, `python` (Python interoperability), and GPU-oriented packages.

A recurring theme: the "built-in" types are ordinary structs defined in the library with the same tools available to users. Nothing about `Int` or `String` is compiler magic beyond the prelude import.

## 2. Core scalar types

### 2.1 `SIMD`, `Scalar`, and the numeric aliases

Almost every numeric type is a vector in disguise. The reference documents the core type as:

```mojo
SIMD[dtype, width]        # e.g. SIMD[DType.float32, 4]
Scalar[dtype]             # = SIMD[dtype, 1]
```

`DType` is a compile-time specification — `@register_passable(trivial) struct DType` — used as `DType.float32`, `DType.int64`, `DType.bool`, and so on; it also answers introspection queries such as `dtype.is_floating_point()` and `dtype.is_signed()`. The familiar names are aliases over one-lane SIMD values:

- `Float64 = Scalar[DType.float64]`, `Float32 = Scalar[DType.float32]` — likewise `Float16`, `BFloat16`, and the fixed-width integers `Int8/16/32/64`, `UInt8/16/32/64`.
- Arithmetic on a multi-lane value is elementwise:

```mojo
var a = SIMD[DType.float32, 4](1.0, 2.0, 3.0, 4.0)
var b = a * a + 1.0
print(b)   # [2.0, 5.0, 10.0, 17.0]
print(a[0], len(a))   # lane access; len is the width
```

Newer reference examples also use the shorthand `SIMD[.float32, 4](…)`, where `.float32` is the inferred `DType` member.

### 2.2 `Int`, `UInt`, `Bool`

- `Int` is the signed, machine-word integer — the index type, and the one numeric type that is *not* SIMD-based. `UInt` is its unsigned machine-word counterpart. Use plain `Int` unless a width is semantically required.
- `Bool` holds `True`/`False`, is the result of comparisons, and is what `if`/`while` consume; most containers define `__bool__` so they can be tested directly (`if my_list:`, `if opt:`).

There is no implicit numeric conversion: write `Float64(n)` or `Int(x)` explicitly.

### 2.3 `String`, `StringSlice`/`StringSpan`, `StringLiteral`

`struct String` is the owning text type: mutable, UTF-8, value-semantic with copy-on-write (assignment may share storage until one side mutates). Documented constructors include:

```mojo
def __init__(out self)                                   # empty
def __init__(out self, *, capacity_bytes: Int)
@implicit def __init__(out self, data: StringLiteral, /)
def __init__(out self, *, from_utf8: Span[UInt8])         # raises on invalid UTF-8
def __init__(out self, *, from_utf8_lossy: Span[UInt8])   # replaces invalid bytes with U+FFFD
def __init__[*Ts: Writable](out self, *args: *Ts.values, *, sep: StringSpan = "", end: StringSpan = "")
def __init__(out self, *, copy: Self)
def __deinit__(deinit self)
```

In practice:

```mojo
var hello = "Hello"            # String inferred from a literal
var world = String("World")
var n = String(42)             # any Writable converts: "42"
var text = "café"
print(text.byte_length())      # 5 — é is two UTF-8 bytes
print(text.count_codepoints()) # 4
text += " World"               # in-place concatenation
print(text.find("World"))      # byte position, or -1
var replaced = text.replace("Hello", "Hi")
var formatted = "{} is {} years old".format("Alice", 30)
```

Two traps are documented on the `String` page: `len(s)` / `byte_length()` count **bytes**, not characters (use `count_codepoints()`), and indexing is byte-based — `text[byte=1]` returns the codepoint at byte 1 and aborts if the index is not on a codepoint boundary.

- **`StringSlice` / `StringSpan`** is the non-owning view: a slice of someone else's string data, parameterized by an origin (`StringSpan[origin]`), so the checker knows whose storage it borrows and how long it may live. `String.as_string_slice()` and `String.as_bytes()` (`-> Span[UInt8, …]`) produce views; `StaticString` is the alias for an immutable constant span. In 1.1.0 signatures the name `StringSpan` predominates (older text says `StringSlice`); they are the same view concept.
- **`StringLiteral`** is the compile-time type of `"…"` literals, with static origin (`ImmStaticOrigin`): literals live for the whole program and are never destroyed. It supports the usual comparisons against slices and conversions such as `__int__(self) -> Int` and `__float__(self) -> Float64` (both raising on unparseable input) and `__mul__(self, n: Int) -> String`.

Template strings are the 1.x interpolation form: `t"Hi, {name}!"` produces a `TString`, which `print` accepts directly and `String(t"…")` materializes.

## 3. `List[T]`

```mojo
struct List[T: AnyType, /]   # from std.collections import List
```

A dynamically-allocated, resizable, homogeneous array. Constructors documented in the reference:

```mojo
def __init__(out self)
def __init__(out self, *, capacity: Int)
def __init__(out self, *, length: Int, fill: T)        # T: Copyable
def __init__(out self, var *values: T, *, __list_literal__: NoneType)
def __init__(out self, *, copy: Self)                  # the deep copy
```

Key methods, with signatures as documented (trait `where` clauses abbreviated):

```mojo
def append(mut self, var value: T, /)                       # amortized; doubles capacity
def insert(mut self, i: Int, var value: T, /)
def extend(mut self, var other: Self)                       # consumes other
def extend(mut self, elements: Span[T])                     # copies from a span
def pop(mut self) -> T
def pop(mut self, i: Int) -> T
def reserve(mut self, capacity: Int)
def resize(mut self, length: Int, fill: T)
def shrink(mut self, new_length: Int)
def reverse(mut self)
def clear(mut self)
def capacity(self) -> Int
def __len__(self) -> Int
def __getitem__(ref self, idx: Int, /) -> ref[…] T          # aborts out of bounds
def __contains__(self, value: T, /) -> Bool
def index(ref self, value: T, start: Int = 0, stop: Optional[Int] = None) -> Int   # raises ValueError
def try_index(ref self, value: T, start: Int = 0, stop: Optional[Int] = None) -> Optional[Int]
def __bool__(self) -> Bool
```

Usage, adapted from the reference page:

```mojo
var my_list: List = [10, 20, 30]     # annotation needed: bare [..] can be a fixed Array
my_list.append(40)                   # [10, 20, 30, 40]
my_list.insert(1, 15)                # [10, 15, 20, 30, 40]
my_list.extend([50, 60])
print(my_list.pop())                 # 60; pop(2) removes by index
print(len(my_list), my_list.capacity())

var list2 = my_list.copy()           # deep copy — List is value-semantic
for ref num in my_list:              # ref = mutable references to the elements
    num += 1
for x in my_list^:                   # owned iteration consumes the list
    print(x)
```

Out-of-bounds indexing **aborts** with an assert error; check bounds or use `try_index`/`index` under `try`. Note the documented asymmetry with Python: iteration yields immutable references by default — mutation requires `for ref x in …`.


## 4. `Dict[K, V]`

```mojo
struct Dict[K: KeyElement, V: Movable, H: Hasher = AHasher[…]]
```

The primary associative collection: unique keys, fast lookup/insert/delete, and — as documented — iteration in **insertion order**, matching Python's `dict` guarantee. Keys must satisfy `KeyElement` (hashable + equatable); both key and value types are fixed at compile time.

```mojo
def __init__(out self)
def __init__(out self, *, capacity: Int)
def __init__(out self, *, copy: Self)
def __getitem__(ref self, ref key: K) -> ref[…] V        # raises DictKeyError if absent
def __setitem__(mut self, var key: K, var value: V)
def __contains__(self, key: K) -> Bool
def __len__(self) -> Int
def __bool__(self) -> Bool
def get(self, key: K) -> Optional[V]
def get(self, key: K, var default: V) -> V
def find(self, key: K) -> Optional[V]
def pop(mut self, ref key: K) -> V                        # raises DictKeyError if absent
def pop(mut self, key: K, var default: V) -> V
def popitem(mut self) -> SwissTableEntry[K, V, H]         # LIFO; EmptyDictError if empty
def setdefault(mut self, var key: K, var default: V) -> ref[…] V
def update(mut self, other: Self, /)
def clear(mut self)
def keys(ref self)   -> _DictKeyIter[…]                   # immutable refs by default
def values(ref self) -> _DictValueIter[…]
def items(ref self)  -> _DictEntryIter[…]                 # item.key / item.value
static def fromkeys(keys, value: V) -> Self
```

```mojo
var phonebook = {"Alice": "555-0101", "Bob": "555-0102"}
phonebook["Charlie"] = "555-0103"          # add
phonebook["Alice"] = "555-0199"             # update
print(phonebook["Alice"])                   # 555-0199 (raises DictKeyError if missing)
var phone = phonebook.get("David")          # Optional[String]
print(phone.or_else("phone not found!"))
print(phonebook.get("David", "555-0000"))   # default form returns V directly
if "Bob" in phonebook:
    print("Found Bob")
print(phonebook.pop("Charlie"))             # remove and return
for item in phonebook.items():
    print(item.key, "=>", item.value)
var backup = phonebook.copy()               # Dict is NOT implicitly copyable
backup.update({"David": "555-0104"})
var combined = backup | {"Eve": "555-0105"} # __or__ merges into a new dict
```

Iteration yields immutable references; `for ref value in d.values():` mutates in place, `for var key in d:` takes owned copies of keys — the reference page warns that indexing a dict with a reference to one of its own keys trips argument exclusivity, and the `var key` copy is the documented fix.

## 5. `Set[T]`

```mojo
struct Set[T: KeyElement, H: Hasher = AHasher[…]]   # from std.collections import Set
```

A set with O(1) average-case amortized add, remove, and membership. Documented surface:

```mojo
def __init__(out self)
def __init__(out self, *ts: T, *, __set_literal__: NoneType = None)
def __init__(out self, elements: List[T])
def add(mut self, var t: T)
def insert(mut self, var t: T) -> Optional[T]     # returns displaced equal element, if any
def remove(mut self, t: T)                        # raises if absent
def pop(mut self) -> T                            # removes (last by insertion order); raises if empty
def __contains__(self, t: T) -> Bool
def __len__(self) -> Int
def union(self, other: Self) -> Self
def intersection(self, other: Self) -> Self
def difference(self, other: Self) -> Self
def update(mut self, other: Self)
def intersection_update(mut self, other: Self)
def difference_update(mut self, other: Self)
def issubset(self, other: Self) -> Bool           # also __le__ / __lt__
def issuperset(self, other: Self) -> Bool         # also __ge__ / __gt__
# operators: | union, & intersection, - difference, ^ symmetric difference,
#            |=, &=, -=, ^= in place
```

```mojo
from std.collections import Set

var set = {1, 2, 3}
print(len(set))                    # 3
set.add(4)
set -= Set[Int](3, 4, 5)
print(set == Set[Int](1, 2))       # True
print(set | Set[Int](0, 1))        # {0, 1, 2}
var element = set.pop()
```

## 6. `Optional[T]`

```mojo
struct Optional[T: AnyType]   # std.collections
```

A type-safe nullable: either a value or `None`, with the absence made explicit. Layout is *not* guaranteed — the reference warns the implementation may use niche optimization (as it does for `Optional[Pointer]`), so never depend on `size_of[Optional[T]]()`.

```mojo
def __init__(out self)                              # empty
@implicit def __init__(out self, var value: T)       # holds a value
@implicit def __init__(out self, value: NoneType)   # empty, from None
def __bool__(self) -> Bool
def value(ref self) -> ref[…] T                     # ABORTS on empty
def unsafe_value(ref self) -> ref[…] T              # no abort — caller guarantees
def take(mut self) -> T                             # moves out, leaves None; aborts on empty
def or_else(deinit self, var default: T) -> T       # consuming unwrap-with-default
def map(deinit self, mapper) -> Optional[To]
def and_then(deinit self, mapper) -> Optional[To]   # flat-map
def __is__(self, other: NoneType) -> Bool           # enables `is None` / `is not None`
```

```mojo
var a = Optional(1)
var b = Optional[Int](None)
if a:
    print(a.value())     # 1
print(a.or_else(2))      # 1 — note or_else consumes the Optional
print(b.or_else(2))      # 2
var parsed = Optional("42").and_then(try_parse_int)   # Optional[Int]
```

The discipline: test first (`if opt:`, `opt is None`), then extract. `value()` and `take()` abort on empty by design; the `unsafe_` variants exist for code that has already established presence.

## 7. Math: `std.math`

Import selectively — `from std.math import sqrt` is the reference's own example style. Most functions are elementwise over `SIMD[dtype, width]`, so one call serves scalars and vectors alike:

```mojo
def sqrt[dtype: DType, width: SIMDLength, //](x: SIMD[dtype, width]) -> SIMD[dtype, width]
def log(x)    # natural log, elementwise — likewise log2, log10, log1p, logb
def exp(x)    # likewise exp2, expm1
def sin(x) / cos(x) / tan(x)          # plus asin/acos/atan/atan2 and hyperbolics
def pow(base, exp)
def abs(x) / ceil(x) / floor(x) / round(x) / trunc(x)
def clamp(x, ...)                     # SIMD values clamped to a range
def max(x, y) / min(x, y)             # elementwise
def gcd(a, b) / lcm(a, b)             # integers
def factorial(n) / comb(n, k) / perm(n, k)
def hypot(x, y) / cbrt(x) / erf(x) / gamma(x) / lgamma(x)
def fma(a, b, c)                      # fused multiply-add
def isclose(a, b)                     # equality within tolerance, as a SIMD bool vector
def ceildiv(numerator, denominator)   # rounded-up division
```

```mojo
from std.math import sqrt, sin, pi

print(sqrt(Float64(16.0)))        # 4.0
print(sqrt(SIMD[DType.float32, 4](1.0, 4.0, 9.0, 16.0)))  # [1.0, 2.0, 3.0, 4.0]
print(sin(pi / 2))                # 1.0 (approximately)
```

Constants live in the same package (`from std.math import pi`): `pi = 3.1415926535897931`, `tau = 6.2831853071795862` (2π), `e = 2.7182818284590451`, `log2e = 1.4426950408889634` — all `comptime` values. A `std.math.fast` module provides faster approximate variants when precision can be traded for speed, and `std.math.polynomial` evaluates polynomials.


## 8. I/O: `print`, `input`, and files

The `io` package docs state that `print` and `input`, and the `open`/`FileHandle` file APIs, are built-ins: no import needed.

### 8.1 Console

```mojo
def print[*Ts: Writable](*values: *Ts.values, *, sep: StringSpan = " ",
                         end: StringSpan = "\n", flush: Bool = False,
                         var file: FileDescriptor = stdout)
def input(prompt: String = "") -> String    # raises on failure
```

`print` accepts any number of `Writable` values — most built-in types conform — separated by `sep`, terminated by `end`, and optionally redirected to a file descriptor:

```mojo
print("Hello, World!")
print("The answer is", 42)
print(1, 2, 3, sep=", ", end="!\n")
var name = "Mojo"
print(t"{name} is 🔥")                    # template-string interpolation
print("{} is {}".format("Mojo", "🔥"))    # or String.format

def main() raises:
    var who = input("Enter your name: ")  # prompt has no trailing newline
    print("Hello", who)
```

### 8.2 Files

```mojo
def open[PathLike: PathLike](path: PathLike, mode: StringSpan) -> FileHandle
    # modes: {"r", "w", "rw", "a"}; raises on bad mode or open failure

struct FileHandle:   # Writer + Deinitable + Movable
    def read(self, size: Int = -1) -> String                 # -1 = to EOF
    def read_bytes(self, size: Int = -1) -> List[UInt8]
    def seek(self, offset: Int, whence: UInt8 = 0) -> UInt64 # os.SEEK_SET/CUR/END
    def write[*Ts: Writable](mut self, *args: *Ts.values)
    def write_bytes(mut self, bytes: Span[UInt8])            # Writer trait; aborts on failure
    def write_all(mut self, bytes: Span[UInt8])              # loops over partial writes; raises
    def write_string(mut self, string: StringSpan)
    def close(mut self)
    def __deinit__(deinit self)                              # closes the handle
    def __enter__(var self) -> Self                          # with-statement support
```

```mojo
def main() raises:
    var f = open("my_file.txt", "r")
    print(f.read())
    f.close()

    with open("my_file.txt", "r") as fh:   # closed automatically
        print(fh.read())

    with open("out.txt", "w") as out:
        out.write("Hello, file!")
        out.write_all(String("raw bytes").as_bytes())
```

Because `FileHandle.__deinit__` closes the file, even the non-`with` form cannot leak the descriptor if you forget `close()` — destruction closes it at last use. Prefer `write_all` over `write_bytes` when you need errors rather than an abort.

## 9. Testing: `std.testing`

The `testing` package is documented as "Unit testing: Assertions (equal, true, raises) and test suites." Assertions raise an `Error` on failure, so test functions are typically declared `raises`:

```mojo
def assert_equal[T: Equatable & Writable, //](lhs: T, rhs: T, msg: String = "",
                                              *, location: Optional[SourceLocation] = None)
def assert_not_equal(lhs, rhs, msg: String = "", *, location: … = None)
def assert_true(value, msg: String = "", *, location: … = None)
def assert_false(value, msg: String = "", *, location: … = None)
def assert_almost_equal(a, b, *, msg: String = "", location: … = None)  # tolerance-based
def assert_is(a, b, …) / assert_is_not(a, b, …)                          # identity
# assert_raises: a context manager asserting the block raises
```

(The `assert_true`/`assert_false`/`assert_not_equal`/`assert_almost_equal` entries follow the same parameter pattern as the fully-documented `assert_equal` above: compared value(s), an optional `msg: String = ""`, and a keyword-only `location`. `assert_equal` additionally has overloads for `List[StringSpan]` and `StringSpan` pairs.)

```mojo
from std.testing import assert_true, assert_equal, assert_raises

def test_arithmetic() raises:
    assert_equal(2 + 2, 4)
    assert_true(len("mojo") == 4)
    with assert_raises():
        _ = Int("not a number")

def main() raises:
    test_arithmetic()
    print("tests passed")
```

(The stdlib index describes the package as providing "Assertions (equal, true, raises) and test suites"; only the assertion APIs above were verified signature-by-signature for this tour.)

The module page's own minimal example imports from `std.testing` and simply lets the assertion error propagate:

```mojo
from std.testing import assert_true

def main() raises:
    try:
        assert_true(1 == 1)
        print("All assertions succeeded")
    except e:
        print("At least one assertion failed:", e)
```

Assertions are also the stdlib's own documentation style — reference pages use `from std.testing import assert_equal` / `assert_true` inside their examples (e.g. verifying `String(from_utf8_lossy=…)` results and `Dict.get` behavior), which makes them the natural first tool for checking your understanding of any API in this tour.

## 10. Also in `collections`: `Span` and the supporting cast

One more type appears inside half the signatures above and deserves a name-check. `Span[T, origin]` is a non-owning, contiguous view over someone else's elements — the list/string analogue of `StringSpan`. It is parameterized by the origin of the data it views, so a `Span` cannot outlive its owner, and its mutability follows the owner's. You have already met it as `List.extend(elements: Span[T])`, as the return of `String.as_bytes()`, and as the buffer type for `FileHandle.read`/`write_all`. Constructing one is ordinary: `Span(list)` or `Span(string)` in the examples on the reference pages.

Beyond the big four, the `collections` package index documents: `Deque` (double-ended queue), `Counter`, `InlineArray` (fixed-size, inline storage — the type a bare `[1, 2, 3]` literal may produce where a `List` annotation is absent), `LinkedList`, `BinaryHeap`, `BitSet`, and an interval tree. Iteration helpers live in `iter`/`itertools`: `zip` (used in the `Dict` construction example in §4), `enumerate`, and `map`. None of these change the ownership story — they are all value types built from the same `List`/`Dict` primitives — but `InlineArray` vs `List` is a distinction worth remembering when a literal does not behave like the dynamic array you expected.

## 11. Reading further

Three habits will keep you accurate as the library evolves toward and beyond 1.1:

1. **Trust the signature, including its conventions.** `mut self` vs `self` vs `deinit self`, `var` parameters, and `ref` returns tell you the ownership story of every call before you read a word of prose (see the companion file).
2. **Check the `where` clauses.** Half the collections API is conditionally available — `List.copy()` needs `T: Copyable`, consuming iteration needs `Deinitable & Movable` — and the clause says exactly what is required.
3. **Prefer the documented safe path.** For every `unsafe_` method in this tour there is a checked sibling (`index`/`try_index`, `value()`/`unsafe_value()`, `write_all`/`write_bytes`); reach for the unsafe one only with a reason you can state.

## Sources

- https://docs.modular.com/mojo/std
- https://mojolang.org/docs/std/
- https://docs.modular.com/mojo/std/collections/
- https://docs.modular.com/mojo/std/collections/list/List
- https://docs.modular.com/mojo/std/collections/dict/Dict
- https://mojolang.org/docs/std/collections/dict/Dict/
- https://docs.modular.com/mojo/std/collections/set/Set
- https://docs.modular.com/mojo/std/collections/optional/Optional
- https://docs.modular.com/mojo/std/collections/string/string/String
- https://docs.modular.com/mojo/std/builtin/string_literal/StringLiteral/
- https://docs.modular.com/mojo/stdlib/builtin/dtype/DType/
- https://docs.modular.com/mojo/std/math
- https://mojolang.org/docs/std/math/math/
- https://mojolang.org/docs/std/math/math/sqrt/
- https://docs.modular.com/mojo/std/math/constants
- https://docs.modular.com/mojo/std/io
- https://mojolang.org/docs/std/io/io/
- https://mojolang.org/docs/std/io/io/print/
- https://mojolang.org/docs/std/io/io/input/
- https://mojolang.org/docs/std/io/file/
- https://mojolang.org/docs/std/io/file/open/
- https://mojolang.org/docs/std/io/file/FileHandle/
- https://docs.modular.com/mojo/std/testing/testing
- https://mojolang.org/docs/std/testing/testing/assert_equal/
