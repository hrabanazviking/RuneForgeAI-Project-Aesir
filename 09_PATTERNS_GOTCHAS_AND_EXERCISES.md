# 09 — Mojo Patterns, Gotchas, and Exercises

> **Version reflected:** Mojo **1.1.0** (the newest release notes read for this
> corpus), incorporating the 1.0 / 1.0.0b1 unification. Read this file as
> current-1.x Mojo, *not* as the Mojo of 2023–2025 tutorials. The single most
> important fact in it is this: **`def` is now the only function keyword.
> `fn` is gone.** See §2.3 and file 10 for the full version warnings.
>
> Every code sample below uses only constructs verified in the official
> Mojo Manual, get-started tutorial, language reference material, cheat
> sheet, or 1.x release notes listed in Sources. Where a familiar construct
> could not be verified in the current docs, it is left out — not guessed.

---

## 1. Idioms: writing Mojo well

### 1.1 Declare everything with `var`; make constants `comptime`

All variables in current Mojo are declared with `var` and are mutable by
default. There is no `let` in the current Variables manual: a value that
must not change at runtime is either a `comptime` value or a non-mutable
function argument.

```mojo
var greeting: String = "Hello World"   # owned, mutable, typed
var count = 8                          # type inferred as Int
comptime num_cols: Int = 8             # evaluated at compile time
```

Idiom: annotate types at boundaries (function signatures, struct fields,
public constants) and let inference work inside a function body, where the
initializer makes the type obvious.

### 1.2 Put the entry point in `main()` — and nothing at file scope

Every runnable Mojo program starts in `main()`. Mojo does not allow
runtime statements at global scope (the get-started tutorial makes this
point about calling `seed()`), so setup code belongs in `main()` or in a
function it calls.

```mojo
def main():
    print("Hello, world!")
```

Run it with `mojo hello.mojo`; build a native binary with `mojo build`.

### 1.3 Prefer small typed functions with explicit effects

A function signature should say three things plainly: what it takes
(typed), what it returns (`-> Type`, or nothing), and whether it can raise
(`raises`). Non-raising is the default — and it is a promise the compiler
enforces.

```mojo
def my_pow(base: Int, exp: Int = 2) -> Int:
    return base ** exp

def raises_error() raises:
    raise Error("There was an error.")
```

### 1.4 Use structs + traits for abstraction, not dynamic tricks

Define data as a `struct` with declared fields. Use `@fieldwise_init`
when the initializer just assigns arguments to fields; write
`__init__(out self, ...)` by hand when you need defaults, computation, or
validation. Express shared behaviour as a *trait* and name the conformance
on the struct — conformance is explicit and checked, never duck-typed.

```mojo
@fieldwise_init
struct Point(Copyable):
    var x: Int
    var y: Int

    def magnitude_squared(self) -> Int:
        return self.x * self.x + self.y * self.y
```

### 1.5 Respect ownership in the small: copy cheap, move big, borrow to read

- `Int`, `Float64`, `Bool` and other `ImplicitlyCopyable` values copy
  silently on assignment. That is cheap and idiomatic.
- A `List` is *not* implicitly copyable. Copy it explicitly with
  `.copy()` when you really want a second owned list.
- Transfer a value you will not use again with the transfer sigil `^`.
  After the transfer the source is uninitialized until reassigned.
- Use a `ref` binding when you mean “a name for that element”, not a copy:

```mojo
var items: List[Int] = [99, 77, 33, 12]
ref item_ref = items[1]   # a reference, not a copy
item_ref += 1             # writes through: items[1] is now 78
```

### 1.6 Let the compiler specialize: parameters in `[]`, arguments in `()`

Square brackets carry compile-time *parameters*; parentheses carry
runtime *arguments*. Reach for a parameter when the value shapes the
code itself — a size, a type, a rank, a width — and for an argument when
the value is ordinary data known only at runtime.

```mojo
struct Grid[num_cols: Int, num_rows: Int]:
    var cells: List[Int]
    var count: Int

    def __init__(out self):
        self.count = Self.num_cols * Self.num_rows
        self.cells = List[Int](length=self.count, fill=0)
```

Inside the type, `Self.num_cols` names the parameter; `self.count` names
one instance's field. Confusing `Self` with `self` is a beginner error
worth drilling out early.

### 1.7 Handle errors where they happen, or declare `raises`

Do not let a raising call sit unhandled in a non-raising function — it
will not compile. Either wrap it in `try` / `except`, or add `raises` to
your own signature and let the caller decide. Both are idiomatic; hiding
the error is not an option the language offers.

### 1.8 Use comprehensions, `enumerate`, and joining for output

The get-started tutorial's own performance advice is to build one string
and print once per frame rather than printing cell by cell. List
comprehensions plus `"".join(...)` are the documented way to do that:

```mojo
def render(cells: List[Int]) -> String:
    var parts = [("X" if value else ".") for value in cells]
    return "".join(parts)
```

Note the comprehension iterates values directly. When you also need the
position, iterate `for index, value in enumerate(cells)`.

### 1.9 Keep compile-time work at compile time

Use `comptime` declarations, `comptime if`, and `comptime for` for work
whose inputs are known before the program runs: constants, table
building, unrolling, and selecting an implementation. Do not re-implement
that selection with runtime `if` statements over values that never change.

### 1.10 Name things the Mojo way

Types are `PascalCase` (`List`, `String`, `Float64`); values and
functions are `lower_snake_case`. Prelude types — `Int`, `String`,
`List`, `Bool`, `print`, `len`, `range` — need no import. Everything else
is imported explicitly (see §2.11).

---
## 2. Gotchas for Python programmers

Each gotcha follows the same form: **the Python habit → what Mojo does
instead → correct Mojo.**

### 2.1 “I'll define a class”

**Python habit →** `class Point:` with attributes assigned in `__init__`,
methods added freely, attributes added later, monkey-patching at runtime.

**Mojo instead →** There are no Python-style classes in the code this
corpus teaches. Use a `struct`: fields are declared up front with `var`,
the layout is fixed at compile time, and you cannot add fields or methods
at runtime. Behaviour shared between types comes from *traits*, declared
on the struct, not from class inheritance and not from duck typing.

**Correct Mojo →**

```mojo
@fieldwise_init
struct MyPair(Copyable):
    var first: Int
    var second: Int

    def dump(self):
        print(self.first, self.second)

def main():
    var mine = MyPair(2, 4)
    mine.dump()          # prints: 2 4
```

If `@fieldwise_init` does not fit, write the initializer explicitly —
and every field must be initialized before it returns:

```mojo
struct MyPair:
    var first: Int
    var second: Int

    def __init__(out self, first: Int, second: Int):
        self.first = first
        self.second = second
```

### 2.2 “Variables don't need declarations or types”

**Python habit →** `x = 5`, then later `x = "nine"` in the same scope.

**Mojo instead →** Declare with `var`. A variable's type is fixed at
creation and never changes; assigning an incompatible value is a compile
error. Implicit declaration is also gone: in 1.1, relying on a bare
assignment (or the walrus operator) to create a new variable is an error,
not a warning.

**Correct Mojo →**

```mojo
def main():
    var count = 8            # count is Int, forever
    count = 9                # fine: same type
    # count = "Nine?"       # error: can't convert StringLiteral to Int
    var ratio: Float64 = 0.5 # annotate when inference is not what you want
    print(count, ratio)
```

Scope is block-level and lexical. A `var` inside an `if` block shadows an
outer variable of the same name instead of modifying it — a classic
silent-bug source for Python programmers, who expect assignment in a
block to reach the outer name.

### 2.3 “`fn` is the strict one, `def` is the Python one” — OBSOLETE

**Python habit →** (Really a habit from *old Mojo tutorials*.) Reach for
`fn` for serious code and `def` for loose, Python-like, implicitly
raising code, and expect different argument and mutability rules for each.

**Mojo instead →** **This distinction no longer exists.** The def/fn
unification began in v0.26.2. In v1.0.0b1, `fn` was deprecated with a
compiler warning and `def` took on `fn`'s non-raising semantics. In
**v1.1.0, `fn` was removed entirely**. Current Mojo has one function
keyword, `def`, and *every* function — including one that looks exactly
like Python — must declare argument types and must declare `raises` if
it can raise.

**Correct Mojo →**

```mojo
def add(x: Int, y: Int) -> Int:   # not fn; there is no fn any more
    return x + y

def main():
    print(add(3, 5))              # 8
```

Any tutorial, notebook, or blog post that teaches `fn`, or that presents
untyped `def` arguments as valid Mojo, is describing a pre-1.0 language.
Treat it as historical material.

### 2.4 “I can mutate any argument I like”

**Python habit →** Assume every argument is a mutable reference to the
caller's object, and reassign or mutate parameters freely.

**Mojo instead →** Arguments are immutable by default. To mutate, say so
in the signature: `mut` for a mutable reference (including `mut self` in
a method), `var` to take an owned value the function may mutate and
consume, `out` for a value the function must initialize (initializers
and named results), and `ref` where a reference type is being named.
The old spellings in pre-1.0 material — `inout`, `owned`, `borrowed`,
and `read` — are not the current forms; 1.1 made use of the `read`
argument convention a hard error, directing you to `imm` (immutable)
instead.

**Correct Mojo →**

```mojo
struct Counter:
    var n: Int

    def __init__(out self):
        self.n = 0

    def bump(mut self):       # mut self: this method may change the instance
        self.n += 1

    def value(self) -> Int:   # plain self: read-only
        return self.n

def double_in_place(mut xs: List[Int]):
    for i in range(len(xs)):
        xs[i] = xs[i] * 2

def main():
    var c = Counter()
    c.bump()
    c.bump()
    print(c.value())          # 2
    var nums: List[Int] = [1, 2, 3]
    double_in_place(nums)
    print(nums[2])            # 6
```

For variadic arguments the same rule appears in miniature: iterate a
`mut` variadic list with a `for ref i in ...` binding if you intend to
write through to the elements.

### 2.5 “Types are whatever the value happens to be at runtime”

**Python habit →** Pass an `int` where a `float` was expected, store
mixed types in one list, add attributes dynamically, rely on duck typing.

**Mojo instead →** Typed code is statically typed, full stop. Every
function argument and parameter must declare its type; a `List[T]` holds
only `T`; there is no implicit numeric conversion in the cheat sheet's
blunt phrasing — write the conversion, as in `Float64(n)` or `Int(x)`.
If a function must accept several types, write overloads or parameterize
it and constrain the parameter with a trait — do not look for a dynamic
escape hatch inside typed code.

**Correct Mojo →**

```mojo
def add(x: Int, y: Int) -> Int:
    return x + y

def add(x: String, y: String) -> String:   # an overload, not duck typing
    return x + y

def describe[T: Writable](value: T):       # a trait-constrained parameter
    print(value)

def main():
    print(add(2, 3))          # Int overload
    print(add("a", "b"))      # String overload
    var n = 3
    print(Float64(n) / 2.0)   # explicit conversion: 1.5
```

Two overloads that differ *only* in return type or only in `raises` are
duplicate definitions and are rejected — overload resolution does not
consider either.

### 2.6 “`/` is always true division, `//` is a niche extra”

**Python habit →** Expect `7 / 2 == 3.5` and `-7 / 2 == -3.5`, and reach
for `//` only occasionally.

**Mojo instead →** The get-started tutorial states the rule directly:
for integer types, `/` returns an integer, **rounding towards zero**;
`//` is flooring divide, **rounding towards negative infinity**. The two
differ exactly where Python programmers least expect it — on negatives.

**Correct Mojo →**

```mojo
def main():
    print(7 / 2)    # 3   (Int / Int -> Int, towards zero)
    print(7 // 2)   # 3
    print(-7 / 2)   # -3  (towards zero)
    print(-7 // 2)  # -4  (towards negative infinity)
    print(7.0 / 2.0)  # 3.5: use Float64 when you want true division
```

Coordinate/index arithmetic in the official tutorial depends on this:
`(i % num_cols, i // num_cols)` converts an index to coordinates.

### 2.7 “Strings are immutable, so build them with `+` in a loop”

**Python habit →** Treat a string as an immutable value, slice and
reassign freely, and assume any variable holding a string can be mutated
through any reference.

**Mojo instead →** Be precise about *which* string thing you hold.
A string literal is compile-time text; a `String` is an owned, heap-backed
value held by a variable. A `var` holding a `String` can be reassigned
and accumulated into — the official tutorial builds output exactly this
way, with `grid_str += ...` — but that mutability belongs to the *owner*
under a mutable binding. A plain (immutable) function argument cannot be
mutated by the callee; a method that changes a string field needs
`mut self`; and taking a slice/view is a borrowing operation, not an
invitation to write through it. Interpolation also differs: Mojo uses
**t-strings**, `t"..."`, where Python uses f-strings; a t-string prints
directly, but elsewhere convert it explicitly with `String(...)`.

**Correct Mojo →**

```mojo
def greet(name: String):
    print(t"Hi, {name}!")          # t-string, not f-string

def main():
    var s = String("Mojo")
    s += "!"                        # the owning var may accumulate
    print(s)                        # Mojo!
    print(s[0:4])                   # slicing for reading: Mojo
    greet("Volmarr")
```

Do not port Python code that “edits” a string through a borrowed
parameter and expect it to compile; restructure it to return a new
`String` or to take the argument under a mutable convention.

### 2.8 “Any function can raise; exceptions are invisible”

**Python habit →** Raise anywhere; callers find out at runtime; a bare
`except:` catches whatever arrives.

**Mojo instead →** Functions are **non-raising by default**. A function
that can propagate an error must declare `raises`; a non-raising caller
of a raising function must handle the error with `try` / `except` or it
does not compile. Raise with `raise Error("...")` (typed errors —
`raises SomeErrorType` — also exist). `try` also supports the familiar
`except` / `else` / `finally` shape covered in the revised quickstart.

**Correct Mojo →**

```mojo
def safe_divide(a: Int, b: Int) raises -> Float64:
    if b == 0:
        raise Error("division by zero")
    return Float64(a) / Float64(b)

def main():
    try:
        print(safe_divide(7, 2))    # 3.5
        print(safe_divide(1, 0))    # raises
    except e:
        print("Handled an error:", e)
```

Corollary gotcha: because `main()` above has no `raises`, it *had* to
handle the error. Writing `def main() raises:` and letting the error
propagate is also correct — but it is a choice you must spell out.

### 2.9 “Comprehensions? Probably not in a systems language”

**Python habit →** Either assume comprehensions are unavailable and
write verbose loops everywhere, or assume every Python comprehension
form (dict/set comprehensions, conditions, nested loops) ports verbatim.

**Mojo instead →** List comprehensions **are** supported and are used
in the official tutorial, including with the conditional expression
form and with `enumerate`. They build a collection value; they are not
a licence to assume the entire Python comprehension grammar is present.
When a comprehension starts to strain, an explicit loop with
`append` is clear, documented, and fast.

**Correct Mojo →**

```mojo
def main():
    var values: List[Int] = [1, 2, 3, 4]
    var doubled = [x * 2 for x in values]
    print(len(doubled), doubled[3])        # 4 8
    var labels = [("even" if v % 2 == 0 else "odd") for v in values]
    print(labels[0], labels[1])            # odd even
```

### 2.10 “Truthiness: 0, empty string, and empty list all just work”

**Python habit →** Drop any value into an `if` and rely on Python's
truth-value testing rules.

**Mojo instead →** Conditions are `Bool` values, and types opt into
truth testing by being `Boolable` — it is a trait, not a universal
runtime rule. In practice you will see documented code use an `Int`
cell directly as a condition (`"X" if grid[index] else "."` in the
official tutorial), because that type supports it; do not generalize
that to arbitrary values of your own types. For your own structs, write
an explicit comparison, or implement the trait the condition needs.
Likewise `Optional` values are tested as conditions in the pointer
documentation (`if ptr:`) — again, because that type provides it.

**Correct Mojo →**

```mojo
def classify(x: Int) -> String:
    if x > 0:
        return "positive"
    elif x == 0:
        return "zero"
    else:
        return "negative"

def main():
    var kind = "even" if 4 % 2 == 0 else "odd"   # ternary on a Bool
    print(kind, classify(-3))
    var maybe: Optional[String] = None
    if maybe:
        print("has a value")
    else:
        print("empty")                            # this branch prints
```

### 2.11 “Imports are loose; the module name comes along for free”

**Python habit →** `import os.path` and start using `os`; `from pkg
import thing` and still refer to `pkg.thing`; add directories to a path
and expect them to behave like packages automatically.

**Mojo instead →** Import exactly what you use, in one of the documented
forms. Note the 1.0.0b1 change: `from pkg import ...` **no longer makes
`pkg` itself available** in your module. A single `.mojo` file is a
module; a directory treated as a package is imported differently (see
the Modules and packages manual page). You also cannot execute runtime
statements at module scope to “set things up”.

**Correct Mojo →**

```mojo
from std.random import seed          # one name from a stdlib module
from std.math import sqrt as root    # aliased import (cheat-sheet form)

import mymodule                      # the whole module

from mymodule import MyPair          # one member (see §2.1)

def main():
    seed()
    print(root(9.0))                 # 3.0
    var mine = mymodule.MyPair(2, 4)
    mine.dump()
```

Builtins in the prelude — `Int`, `String`, `List`, `print` — need no
import. When in doubt, import; a missing import is a compile error, not
a runtime surprise.

### 2.12 Bonus traps in one breath

- **Negative indexing is gone.** In 1.0, `x[-1]` became a compile-time
  error for standard collections. Write `x[len(x) - 1]`.
- **Assignment is not aliasing.** Assigning a value copies or transfers
  it; two variables do not silently share one mutable object the way
  Python names do. If you wanted a shared view, you wanted a `ref`.
- **`let`, `alias`, `inout`, `owned`, `borrowed` in old code are tells.**
  Current spellings are `var`, `comptime`, `mut` / `var` / `out` /
  `imm` / `ref` (see file 10). Do not “fix” old code by mixing eras.

---
## 3. Complete example programs

Each program is self-contained: save it as a `.mojo` file and run it
with `mojo file.mojo`. Expected output is shown in comments.

### Example 1 — Hello, plus: greeting, defaults, and a t-string

```mojo
def greet(name: String = "world"):
    print(t"Hello, {name}!")

def main():
    greet()
    greet("Mojo")
    var who = String("Volmarr")
    print(t"Hi, {who}")
```

Output:

```text
Hello, world!
Hello, Mojo!
Hi, Volmarr
```

What it teaches: `def` only; a default argument; string interpolation
with `t"..."` (not Python's `f"..."`); an owned `String` variable.

### Example 2 — Loops, conditionals, and integer division

```mojo
def classify(x: Int) -> String:
    if x > 0:
        return "positive"
    elif x == 0:
        return "zero"
    else:
        return "negative"

def main():
    for n in range(-4, 5):
        var parity = "even" if n % 2 == 0 else "odd"
        print(n, classify(n), parity, n / 2, n // 2)
    var total = 0
    var i = 1
    while i <= 5:
        total += i
        i += 1
    print("sum 1..5 =", total)
```

First and last loop lines:

```text
-4 negative even -2 -2
4 positive even 2 2
sum 1..5 = 15
```

Read the middle lines carefully: for negative odd numbers, `n / 2` and
`n // 2` disagree (`-3 / 2` is `-1`; `-3 // 2` is `-2`). That is §2.6
in action, not a bug.

### Example 3 — Collections: building, transforming, summarizing a `List`

```mojo
def mean(xs: List[Float64]) -> Float64:
    var total: Float64 = 0.0
    for x in xs:
        total += x
    return total / Float64(len(xs))

def main():
    var scores: List[Float64] = [2.0, 4.0, 6.0, 8.0]
    scores.append(10.0)
    var doubled = [x * 2.0 for x in scores]
    print("count:", len(scores))
    print("mean:", mean(scores))
    print("last:", scores[len(scores) - 1])   # no negative indexing
    print("doubled last:", doubled[len(doubled) - 1])
    for index, value in enumerate(doubled):
        print("doubled[", index, "] =", value)
```

Output:

```text
count: 5
mean: 6.0
last: 10.0
doubled last: 20.0
doubled[ 0 ] = 4.0
doubled[ 1 ] = 8.0
doubled[ 2 ] = 12.0
doubled[ 3 ] = 16.0
doubled[ 4 ] = 20.0
```

What it teaches: `List[T]` construction from a literal, `append`,
`len`, iteration, a list comprehension, `enumerate`, explicit
`Float64(len(...))` conversion, and the
`xs[len(xs) - 1]` replacement for Python's `xs[-1]`.

### Example 4 — A struct with state: a tally counter

```mojo
struct Tally:
    var counts: List[Int]
    var total: Int

    def __init__(out self, buckets: Int):
        self.counts = List[Int](length=buckets, fill=0)
        self.total = 0

    def record(mut self, bucket: Int):
        self.counts[bucket] += 1
        self.total += 1

    def report(self):
        for index, count in enumerate(self.counts):
            print("bucket", index, ":", count)
        print("total:", self.total)

def main():
    var tally = Tally(3)
    tally.record(0)
    tally.record(0)
    tally.record(2)
    tally.report()
```

Output:

```text
bucket 0 : 2
bucket 1 : 0
bucket 2 : 1
total: 3
```

What it teaches: a hand-written `__init__(out self, ...)` that must
initialize every field; `List[Int](length=..., fill=...)`; a mutating
method declared `mut self` next to a read-only method declared with
plain `self`; separating the type definition from `main()`.

### Example 5 — Errors as part of the signature

```mojo
def require_positive(value: Int) raises -> Int:
    if value <= 0:
        raise Error("value must be positive")
    return value

def describe(value: Int):
    try:
        var ok = require_positive(value)
        print(value, "->", ok)
    except e:
        print(value, "rejected:", e)

def main() raises:
    describe(42)
    describe(-1)
    var ok = require_positive(7)   # main raises, so no try needed here
    print("direct:", ok)
```

Output:

```text
42 -> 42
-1 rejected: value must be positive
direct: 7
```

What it teaches: one raising function, two caller styles — handle with
`try`/`except` inside a non-raising function (`describe`), or declare
`raises` and propagate (`main`). There is no third style in which the
error is simply ignored by the type system. (This example deliberately
avoids string-to-int parsing: that conversion's exact raising behaviour
was not verified in the docs read for this corpus, so it is not taught
here as fact.)

---

## 4. Graded exercises

Work in order. Each exercise names the trap it is training you out of.
Solution sketches are deliberately brief: write the code first, then
compare shapes, not characters.

### Beginner

**B1. Greet by name.** Write `main()` that prints a greeting for a
`var name: String` using a t-string, then reassigns `name` and greets
again. *Sketch:* `def main():` / `var name = String("...")` /
`print(t"Hello, {name}")` / reassign / print again. Trap: f-strings.

**B2. Squares table.** Print `n` and `n * n` for `n` in `range(6)`,
using a comprehension to build the squares first. *Sketch:* build
`var squares = [n * n for n in range(6)]`, then iterate with
`enumerate`. Trap: printing inside the comprehension.

**B3. Two divisions.** For each `n` in `[-7, -3, 3, 7]`, print
`n / 2` and `n // 2` and write one comment explaining any line where
they differ. *Sketch:* a `List[Int]` literal, a `for` loop, §2.6.
Trap: expecting Python's float result from `/`.

**B4. Last things first.** Given `var xs: List[Int] = [5, 9, 2]`, print
the last element and the length without using negative indexing.
*Sketch:* `xs[len(xs) - 1]`. Trap: `xs[-1]` — a compile-time error in 1.x.

### Intermediate

**I1. Summarize scores.** Write `def summarize(xs: List[Float64])`
that prints count, total, and mean, handling conversion of the count
explicitly. *Sketch:* accumulate a `Float64` total in a `for` loop;
`total / Float64(len(xs))`. Trap: integer division eating the fraction.

**I2. A `Point` struct.** Define `@fieldwise_init struct Point(Copyable)`
with `x`, `y: Int`, a `magnitude_squared(self)` method, and a
`translate(mut self, dx: Int, dy: Int)` method. Demonstrate both in
`main()`. *Sketch:* §2.1 + §2.4; `translate` must be `mut self`.
Trap: forgetting that a plain `self` method cannot assign to fields.

**I3. Move, don't copy.** Hold a `List[Int]` in a variable, transfer it
to a second variable with `^`, and print from the second. Then write —
as a comment — what happens if you try to use the first variable before
reassigning it. *Sketch:* `var second = first^`. Trap: assuming both
names now alias one list, Python-style.

**I4. Guarded divide.** Write `def divide(a: Int, b: Int) raises ->
Float64` that raises `Error` on `b == 0`; call it from a non-raising
helper that catches and prints, and from `main() raises` directly.
*Sketch:* Example 5, renamed. Trap: calling a raising function from a
non-raising function with no `try`.

### Advanced

**A1. Parameterize the grid.** Generalize Example 4's storage idea into
`struct Grid[num_cols: Int, num_rows: Int]` with a `cells: List[Int]`
filled with zeros, plus `__getitem__` / `__setitem__` taking a
`Tuple[Int, Int]` coordinate. *Sketch:* follow the get-started
tutorial's Grid: parameters on the struct, `Self.num_cols` inside,
`List[Int](length=..., fill=0)` in `__init__(out self)`.
Trap: using `self.num_cols` for a parameter, or `Self` for a field.

**A2. Trait, two conformers.** Define a trait requiring one method
(e.g. `def describe(self) -> String`), make two unrelated structs
conform to it, and write one generic function constrained by the trait
that works with both. *Sketch:* declare conformance in each struct's
parentheses; constrain with `def show[T: YourTrait](value: T)` or the
`Some[YourTrait]` argument form (both documented in the Traits page).
Trap: expecting structural duck typing without declared conformance.

**A3. Overload by design.** Write two overloads of one function name —
one for `Int`, one for `String` — then deliberately attempt a third
that differs only in return type and record the compiler's verdict in
a comment. *Sketch:* §2.5; resolution ignores return type and `raises`.
Trap: designing an API that needs return-type overloading.

**A4. Compile-time table.** Build a small lookup table (squares, or
powers of two) as a `comptime` value and use `comptime for` to emit or
check it, then materialize / read it at runtime in `main()`. *Sketch:*
a `comptime` declaration at module scope; a `comptime for i in
range(...)` loop; ordinary runtime reads afterwards. Trap: trying to
make the table depend on runtime input — anything `comptime` must be
fully known at compile time.

**A5. Audit a pre-1.0 tutorial.** Take any old Mojo snippet containing
`fn`, `let`, `alias`, `inout`, or `@parameter if` and rewrite it in
current 1.1 form, listing each substitution you made. *Sketch:* use
the warnings table in file 10 as your checklist; if a construct has no
current equivalent you can verify, redesign around it instead of
guessing a spelling. Trap: mixing eras in one file.

---

## Sources

Exact URLs read during the research for this file (official sources
unless noted):

- https://docs.modular.com/mojo/manual/
- https://docs.modular.com/mojo/manual/variables/
- https://docs.modular.com/mojo/manual/traits/
- https://docs.modular.com/mojo/manual/packages/
- https://mojolang.org/docs/manual/functions/
- https://mojolang.org/docs/manual/get-started/
- https://mojolang.org/docs/manual/basics/
- https://mojolang.org/docs/manual/lifecycle/life/
- https://mojolang.org/releases/v1.0.0b1/
- https://mojolang.org/releases/v1.0.0/
- https://mojolang.org/releases/v1.1.0/
- https://mojolang.org/assets/files/mojo-cheat-sheet-basics-light-1d88e2110a8da4e026a7e13464d45b7e.pdf
