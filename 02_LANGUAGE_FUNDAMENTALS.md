# Mojo Language Fundamentals

*Study corpus — commissioned by Volmarr, 2026-10-19. This file describes Mojo as documented in the current official documentation and release notes at the time of writing: **Mojo 1.1.0** (with the 1.0.0 and 1.0.0b1 notes used to pin down version-sensitive changes). Where older Mojo syntax differs, the change is flagged explicitly. Do not trust pre-1.0 tutorials for the points flagged here.*

Mojo is a statically typed, compiled systems language with Python-like surface syntax: indentation-delimited blocks, `def` functions, and no semicolons or braces for control flow. Every value has a fixed type known at compile time, variables own their values, and the compiler — not a runtime interpreter — checks ownership, trait conformance, and error propagation before the program runs. Built-in types such as `Int`, `String`, and `List`, and the `print` function, live in the automatically imported *prelude*, so a first program needs no imports at all.

```mojo
def main():
    print("Hello, Mojo!")
```

Run it with `mojo hello.mojo`. Every Mojo executable starts at `main()` (see §11).

---

## 1. Variables: `var`, `ref`, and `comptime` — and the death of `let`

### 1.1 Declaring with `var`

All runtime variables are declared with `var`. A declaration can carry a value, a type annotation, or both; the type is then fixed for the life of the variable.

```mojo
var a = 5                # type inferred: Int
var b: Float64 = 3.14    # explicit type annotation
var c: String            # declared, not yet initialized
c = "later"              # must be initialized before first use

var count = 8            # count is Int
# count = "Nine?"        # Error: can't implicitly convert 'StringLiteral' to 'Int'
```

The Manual's Variables page states the model directly: a `var` declaration allocates a logical storage location tied to a type, binds a name to it, and initializes it with a value *owned by* the variable. No other variable owns that value unless ownership is transferred (see §1.3).

> **VERSION-SENSITIVE — implicit declarations are gone.** Older Mojo (like Python) allowed a first assignment to declare a variable implicitly: `x = 0`. Mojo 1.0 deprecated that form with a fix-it that inserts `var`, and 1.1 made it a hard error: “Implicit variable declaration now produces an error instead of a warning.” The walrus operator likewise no longer declares — it only updates an already-declared variable. Always write `var`.

> **VERSION-SENSITIVE — there is no `let`.** Early Mojo had a `let` keyword for immutable declarations. It does **not** appear in the current keyword reference at all. The current declaration keywords are `var` (scoped mutable variable), `ref` (scoped reference binding), and `comptime` (compile-time constant). For an immutable value today, use `comptime` for a true compile-time constant, or simply receive the value as a default-convention (immutable-reference) function argument. Any tutorial showing `let x = ...` is describing pre-1.0 Mojo.

### 1.2 Lexical (block) scope and shadowing

`var` variables have block-level, lexical scope. Inner blocks can read and write outer variables; a `var` inside a block creates a *new* variable that shadows the outer name and dies at the end of the block:

```mojo
def lexical_scopes():
    var num = 1
    var dig = 1
    if num == 1:
        print("num:", num)  # Reads the outer-scope "num"  -> 1
        var num = 2         # Creates new inner-scope "num"
        print("num:", num)  # Reads the inner-scope "num"  -> 2
        dig = 2             # Updates the outer-scope "dig"
    print("num:", num)      # Reads the outer-scope "num"  -> 1
    print("dig:", dig)      # Reads the outer-scope "dig"  -> 2
```

### 1.3 Copying, moving, and the transfer sigil `^`

Assignment copies or moves depending on the type's traits (covered in depth in `03_TYPE_SYSTEM_AND_GENERICS.md`):

```mojo
var source = String("Hello")
var copied = source    # a copy — source stays valid
var moved = source^    # a transfer — source is left uninitialized
# print(source)        # Error until source is assigned a new value
```

- A type conforming to `ImplicitlyCopyable` (e.g. `Int`, `Float64`, `Bool`) copies silently on assignment.
- A type conforming only to `Copyable` needs an explicit copy: `var second = first.copy()`.
- Appending `^` transfers ownership; the value must be `Movable`, and the source becomes uninitialized.

The canonical trap, straight from the Manual:

```mojo
var first: List[Int] = [1, 2, 3]
# var second = first   # Error: 'List[Int]' is not implicitly copyable
var second = first.copy()  # OK: explicit copy
var third = first^         # OK: transfer; first is now uninitialized
```

### 1.4 Reference bindings with `ref`

Indexing a collection returns a *reference*, not a copy. Assigning that reference to a `var` copies the element (if implicitly copyable) — to alias the element itself, bind with `ref`:

```mojo
var items: List[Int] = [99, 77, 33, 12]
var item = items[1]   # item is a copy of items[1]
item += 1
print(items[1])       # prints 77 — the list is unchanged

ref item_ref = items[1]  # item_ref aliases items[1]
item_ref += 1
print(items[1])          # prints 78
```

Reference bindings cannot be rebound to a different value.

### 1.5 Multiple and destructuring assignment

```mojo
var x = var y = var z = "Hello"   # chained declaration, right-associative
var a, b = 1, 2                   # destructuring
var (c, d) = (1, 2)               # equivalent
a, b = b, a                       # swap without a temporary

var total = 0
total += 5                        # augmented assignment: += -= *= /= //= %= **= etc.
```

A bare `var x` with neither a type nor an initializer is an error; `var x: Int` (typed, uninitialized) and `var x = 42` (inferred) are both fine.

---

## 2. Functions: `def` only — the `fn` story

### 2.1 The current rule

**Every function in current Mojo starts with `def`.** The language reference's function-declarations page opens with exactly that sentence. The simplest forms:

```mojo
def do_nothing():
    pass

def greet(name: String) -> String:
    return "Hello, " + name

def add(a: Int, b: Int) -> Int:
    return a + b

def main():
    print(greet("Amit"))   # Hello, Amit
    print(add(5, 7))       # 12
```

Rules that differ from Python and matter immediately:

- **Every argument must have a type annotation.** `name: String` is not decoration; Mojo needs it.
- **Parentheses are always required**, even with no arguments.
- **Omitting `-> Type` means the function returns `None`** — `def greet(): ...` and `def greet() -> None: ...` are equivalent.
- **A `def` function does not raise by default.** Raising must be declared with the `raises` effect (§9).

### 2.2 VERSION-SENSITIVE — `fn` is deprecated, then removed

This is the single most important version fact in modern Mojo, and secondary coverage frequently gets it wrong:

- Historically Mojo had two keywords: `def` (Python-like, dynamically flavored) and `fn` (strict: typed, non-raising by default, explicit argument conventions).
- The unification began in **v0.26.2**, giving `def` the strict semantics `fn` had.
- **v1.0.0b1 release notes:** “`fn` is deprecated; use `def`. Mojo now emits a compiler warning on uses of `fn`; this will become a compilation error in the next release. This completes the def/fn unification… `def` is now Mojo's standard function declaration keyword, with the same non-raising semantics `fn` had.”
- **v1.1.0 release notes, “Removed”:** “The legacy `fn`, `alias`, and `__comptime_assert` keywords… are gone.”

So in 1.1, `fn` is not merely discouraged — it no longer exists. A widely circulated secondary claim that “the `fn` keyword has not been removed” and remains “the path to fully explicit, maximally optimized code” is **false against the official 1.1 notes**; per this corpus's accuracy law, the official notes win. All pre-1.0 examples written with `fn` — including older Modular blog posts — must be mechanically translated: replace `fn` with `def`, and replace the old argument conventions `borrowed`/`inout`/`owned` with the current set in §3.2.

### 2.3 Full signature anatomy

A signature can contain, in order: a name, a compile-time *parameter* list in `[...]`, a runtime *argument* list in `(...)`, effects (`raises`, …), a return type, and a trailing `where` constraint:

```mojo
def name[parameter-list](argument-list) raises -> ReturnType where constraint:
    ...
```

Mojo deliberately distinguishes **parameters** (compile-time values, square brackets) from **arguments** (runtime values, parentheses) — see `03_TYPE_SYSTEM_AND_GENERICS.md` for parameters in depth. A minimal parameterized example from the reference:

```mojo
def clamp[T: Comparable & ImplicitlyCopyable](
    val: T, lo: T, hi: T,
) -> T:
    if val < lo:
        return lo
    if val > hi:
        return hi
    return val
```

### 2.4 Default values and overloads

Once a positional argument has a default, every following positional argument must have one too. Keyword-only arguments are exempt and may mix freely.

```mojo
def connect(
    host: String = "www.modular.com", port: Int = 80,
):
    print(t"Connecting to {host}:{port}")

def main():
    connect()             # Connecting to www.modular.com:80
    connect(port=8080)    # Connecting to www.modular.com:8080
```

Functions overload by name: multiple declarations sharing a name form an *overload set*, resolved statically at each call site by argument count, types, keywords, and conventions — never by return type.

```mojo
def add(x: Int, y: Int) -> Int:
    return x + y

def add(x: String, y: String) -> String:
    return x + y
```

Nested functions are supported and act as closures over the enclosing scope, with explicit capture lists in the current unified-closure syntax, e.g. `def inner() {mut count}: ...` captures `count` by mutable reference. Anonymous single-expression functions use `lambda` with typed, parenthesized arguments: `var inc = lambda (x: Int) {} -> Int: x + 1`.

---

## 3. Calling conventions: positional, keyword, variadic, and argument conventions

### 3.1 Positional, keyword, positional-only, keyword-only

Callers may pass arguments positionally or by keyword (`name=value`); positional arguments may not follow keyword arguments, and a keyword may not repeat. Two markers, borrowed from Python's PEP 570 / PEP 3102, restrict call sites:

```mojo
def div(a: Int, b: Int, /):        # / : everything before it is positional-only
    return a // b

div(10, 3)        # OK
# div(a=10, b=3)  # Error

def configure(*, verbose: Bool, retries: Int):   # * : everything after is keyword-only
    pass

configure(verbose=True, retries=3)  # OK
# configure(True, 3)                # Error
```

In parameter lists the markers are `//` (infer-only parameters, §03), `/` (positional-only), and `*` (keyword-only), in that order.

### 3.2 Argument conventions — how values are passed

A convention keyword precedes the argument name and controls ownership and mutability. The current set, per the keyword/conventions reference and the function reference:

| Convention | Meaning |
|---|---|
| *(none)* — `imm` | **Default.** Immutable reference; caller keeps ownership. (Spelled `imm` where a convention must be named.) |
| `mut` | Mutable reference; changes are visible to the caller. `mut` arguments cannot have defaults. |
| `var` | Owned value: copied in, or moved in if the caller writes `value^`. |
| `out` | The function's return slot; replaces `-> Type`. Exactly one allowed. |
| `deinit` | Takes ownership in order to destroy the value; used by `__deinit__` and move initializers. |
| `ref` | Reference with an explicit origin specifier. |

```mojo
def double_it(mut x: Int):
    x *= 2

def consume(var s: String):
    s += "!"
    print(s)

def make_int(out result: Int):
    result = 42

def main():
    var n = 21
    double_it(n)
    print(n)              # 42

    var greeting = "Hello"
    consume(greeting)     # Hello! (copied — greeting still valid)
    print(greeting)       # Hello
    consume(greeting^)    # Hello! (moved — greeting now uninitialized)
    print(make_int())     # 42
```

> **VERSION-SENSITIVE — convention renames.** Three renames bite anyone reading older material: (1) the old `borrowed` / `inout` / `owned` conventions were replaced long before 1.0 by the read/mut/owned family; (2) `read` was then renamed to **`imm`** — 1.0 lists “`read` becomes `imm`” among its consolidations, and 1.1 makes use of `read` as a convention a hard error (“use `imm` instead”); (3) in signatures, owned arguments are now spelled with **`var`**, and a bare `**kwargs` must likewise be spelled `var **kwargs` (1.0). Code showing `fn f(borrowed x)`, `inout x`, or `read x` will not compile today.

The same conventions govern `self` in methods: bare `self` is an immutable reference, `mut self` may modify the instance, `out self` builds it in `__init__`, and `deinit self` consumes it in `__deinit__`.

### 3.3 Variadic arguments

```mojo
# Homogeneous variadic: any number of Int values
def sum_all(*values: Int) -> Int:
    var total = 0
    for v in values:
        total += v
    return total

# Heterogeneous variadic pack: * before BOTH name and type
def print_all[*Ts: Writable](*args: *Ts):
    comptime for idx in range(args.__len__()):
        print(args[idx], end=" ")
    print()

def main():
    print(sum_all(1, 2, 3, 4))        # 10
    print_all("Hello", 42, 3.14)      # Hello 42 3.14
```

A function may have at most one `*args`; variadics cannot have defaults and cannot be `out`. Keyword variadics use `var **kwargs`, and can be forwarded with Python-style syntax: `takes_them(**kwargs^)`. Arguments declared after a `*values` variadic are effectively keyword-only at the call site.

---

## 4. Type annotations and the built-in types

Annotations appear after a colon in declarations, arguments, and return positions: `var temps: List[Float64]`, `def f(x: Int) -> Bool`. Inference fills in the rest — `var a = 5` needs no annotation — but function *arguments* always require one.

The everyday built-in types, all in the prelude:

- `Int` — machine-word signed integer (in 1.0, `Int` became an alias for `Scalar[DType.int]`); `UInt` is its unsigned counterpart.
- Sized integers and floats: `Int8`…`Int64`, `UInt8`…, `Float16`, `Float32`, `Float64`. A bare decimal literal defaults to `Float64`; a bare integer literal defaults to `Int`.
- `Bool` — `True` / `False` (capitalized; lowercase `true` is not a keyword).
- `String` — owned Unicode text; iterating a string yields grapheme clusters by default (1.0).
- `NoneType` — the type of `None`, and the implicit return type of functions without `->`.
- `SIMD[dtype, width]` — the vector type underneath the scalar types; `Scalar[DType.float32]` *is* `Float32`. New in 1.1, members can be written with a leading dot where context supplies the type: `SIMD[.float64, 4]`.

Unlike Python, there is **no implicit numeric conversion** between distinct types in general code: convert explicitly, as in `Float64(len(temps))` or `Int(some_float)`. Selected implicit conversions exist where a type defines an `@implicit` initializer (the Variables page's example passes an `Int` where a `Float64` is expected, because `Float64` provides such a constructor) — but when in doubt, write the conversion.

---

## 5. Control flow

### 5.1 Conditionals

```mojo
if avg > 25.0:
    print("Status: Hot week")
elif avg > 20.0:
    print("Status: Comfortable week")
else:
    print("Status: Cool week")
```

Conditions are evaluated in order; the first true branch runs. Mojo also has a ternary *expression*, `value_if_true if condition else value_if_false`:

```mojo
var label = "even" if x % 2 == 0 else "odd"
```

Note two Python-isms that fail here, per the reference: `x > 0 and print(...)` errors because `None` isn't truthy, and `pass` is a statement, not an expression, so it cannot appear in a ternary branch.

### 5.2 `while` loops

```mojo
var count = 0
while count < 10:
    print(count)
    count += 1

while True:
    var item = get_next()
    if item is None:
        break        # exit the loop
    if not is_valid(item):
        continue     # skip to the next iteration
    process(item)
```

### 5.3 `for` loops and `range`

A `for` loop iterates anything implementing `__iter__()` / `__next__()`, with destructuring in the target:

```mojo
for temp in temps:
    total += temp

for index in range(len(temps)):   # range is [0, len(temps))
    print(t"  Day {index + 1}: {temps[index]}°C")

for i in range(10):               # 0 .. 9
    print(i)

for key, value in pairs:          # unpack each element as you go
    print(key, value)
```

`range` follows Python's half-open convention and supports the usual `range(stop)`, `range(start, stop)`, and `range(start, stop, step)` forms; in 1.0 the `range()` types were unified into a single `dtype`-parameterized family, and `range()` now rejects non-numeric element types.

Loop-variable conventions mirror argument conventions. By default the loop variable is an immutable reference (`imm`); `for var item in list` iterates over mutable *copies* (the list is unchanged), while `for ref item in list` iterates over references into the list itself (mutations stick):

```mojo
var list: List[String] = ["a", "b", "c", "d"]
for ref item in list:
    item = item + "x"
print(list)   # ['ax', 'bx', 'cx', 'dx']
```

Both `for` and `while` support a Python-style `else` clause that runs only when the loop exits *without* `break` — the classic search idiom:

```mojo
for item in items:
    if item == target:
        found = True
        break
else:
    print("not found")   # only if break was never hit
```

Compile-time loops and branches — `comptime if` and `comptime for` — are covered in `03_TYPE_SYSTEM_AND_GENERICS.md`.

---

## 6. Strings and string literals

### 6.1 Plain literals

Single quotes, double quotes, and triple quotes (for multi-line text) are all supported; adjacent literals concatenate; source files are UTF-8 and literals may contain non-ASCII characters directly.

```mojo
var a = "Hello"
var b = 'world'
var c = """Multi-line
string
"""                       # includes the final newline
var joined = "Hello, " "World"   # "Hello, World" — adjacent literals join
var wave = "👋"                  # literal character, stored as UTF-8
var euro = "\u20AC"       # 4-digit escape form
```

Escapes in non-raw literals include `\\`, `\"`, `\'`, `\n`, `\r`, `\t`, `\0`–`\377` (octal), `\xHH`, `\uHHHH` (BMP only), and `\UHHHHHHHH` (full Unicode range); surrogate code points are rejected. A backslash at the end of a line inside a triple-quoted string suppresses the newline.

### 6.2 Raw strings

Prefix with `r`/`R` to disable escape processing:

```mojo
var raw = r"C:\path\to\file"   # backslashes are literal
```

### 6.3 T-strings: Mojo's interpolation is `t"…"`, not `f"…"`

> **VERSION-SENSITIVE.** Python programmers reach for f-strings. Mojo's interpolating literal is the **t-string** (template string), written `t"..."`. There is no `f"..."` form in current Mojo.

```mojo
var name = "World"
print(t"Hello, {name}!")        # Hello, World!
print(t"1 + 1 = {1 + 1}")        # 1 + 1 = 2
print(t"Use {{braces}} here")    # Use {braces} here — doubled braces escape
```

Expressions inside `{}` are evaluated at runtime. A t-string value has its own template type; `print` accepts it directly, but to use one anywhere a `String` is expected, convert explicitly:

```mojo
var greeting = t"Hello, {name}!"     # a t-string value
var greeting_str = String(greeting)  # convert to a regular String
```

T-strings can be triple-quoted and combined with the raw prefix in either order (`rt"..."`), and interpolations can nest (up to 20 levels deep). They are heavily optimized: 1.1 notes substantially faster compilation and smaller objects for t-string-heavy files.

### 6.4 Working with strings

`String` values concatenate with `+` (as in `return "Hello, " + name`), report their size with `len(...)`, are falsy when empty (`if not name: return`), and iterate by grapheme cluster: `for c in my_string` yields what a user perceives as one character, even for multi-codepoint emoji. Indexing and slicing follow the expression rules in §8.

> **VERSION-SENSITIVE — negative indexing removed.** In 1.0.0b1, negative indexing was removed from all standard-library collections: `x[-1]` is now a compile-time error. Write `x[len(x) - 1]`. Bounds checking is on by default for collections on CPU.

---

## 7. Collections basics

The prelude gives you `List` directly; `Dict`, `Set`, and `Optional` live in `std.collections` (import `Set` explicitly to name the type — set *display* syntax is core, the type is not).

### 7.1 `List[T]` — the growable array

```mojo
var temps: List[Float64] = [20.5, 22.3, 19.8, 25.1]
var xs: List[Int] = [1, 2, 3]
xs.append(4)
print(xs[0])        # 1
print(len(xs))      # 4

var squares = [x * x for x in [0, 1, 2, 3, 4] if x % 2 == 0]  # [0, 4, 16]
```

> **VERSION-SENSITIVE — `[...]` now builds an `Array` by default.** In 1.0, list expressions construct a fixed-size `Array` rather than a `List` when no target type is given, eliminating an implicit heap allocation: `var x = [1, 2, 3]` has type `Array[Int, 3]`. Annotate when you want a `List`: `var y: List[Int] = [1, 2, 3]`. (The pre-1.0 name `InlineArray` was removed in 1.1; use `Array`.)

### 7.2 `Dict[K, V]` — typed key/value maps

Keys and values are homogeneous and fixed at compile time; keys must satisfy the key requirements (`Hashable`/`KeyElement`). Iteration follows insertion order, as in Python.

```mojo
var empty_dict = Dict[String, Int]()
var scores = {"Alice": 95, "Bob": 87, "Charlie": 92}   # Dict[String, Int]
var large_dict = Dict[String, Int](capacity=64)
scores["Alice"] = 96
# var mixed = {"key": 1, 2: "val"}   # Error: keys must be the same type
```

### 7.3 `Set[T]` and displays

```mojo
from std.collections import Set

var primes = {2, 3, 5, 7}        # set display — {1: 2} would be a dict
var empty_set = Set[Int]()
empty_set.add(4)
empty_set.add(4)                 # duplicate: ignored — len stays 1
```

### 7.4 `Optional[T]`

`Optional` (in `std.collections`) models a value that may be absent — Mojo's answer to nullable types, used pervasively where other languages use null pointers; for example, nullable pointers in 1.x are expressed as `Optional[Pointer[...]]`, which shares the pointer's layout so the “none” case costs nothing. Construct it from a value or from `None`, and test presence before use.

### 7.5 Tuples, slices, and comprehensions

Tuples are comma-made, fixed-size, and heterogeneous; slices use `start:stop:stride` with the stop excluded; comprehensions exist for lists, sets, and dicts:

```mojo
var point = (10, 20)
print(point[0])                       # 10
var pair = (1,)                       # trailing comma: one-element tuple

var items = [0, 1, 2, 3, 4, 5]
var first_three = items[0:3]          # [0, 1, 2]
var every_other = items[::2]          # [0, 2, 4]

var lengths: Dict[String, Int] = {k: len(k) for k in ["one", "two", "three"]}
```

---

## 8. Operators and expressions in brief

Operators are Python-shaped: arithmetic `+ - * / // % **`, matrix-multiply `@`, comparisons, bitwise `& | ^ << >>`, and the word-operators `and`, `or`, `not`, `in`, `is`. Augmented forms (`+=`, `//=`, `@=`, …) evaluate the left side once. Member access, calls, and subscripts chain left-to-right: `person.name.upper()`, `matrix[i, j]`. The transfer operator `^` is postfix (`value^`). The walrus operator `:=` assigns into an *already declared* variable and yields the value — `if (n := len(items)) > 10:` — and, per 1.1, always yields its right-hand side.

---

## 9. Error handling: `raises`, `raise`, `try`/`except`/`else`/`finally`

Mojo errors are explicit in signatures. A function that can fail declares the `raises` effect; callers must handle the error or declare `raises` themselves. There are no unchecked exceptions.

```mojo
def calculate_average(temps: List[Float64]) raises -> Float64:
    if len(temps) == 0:
        raise Error("No temperature data")
    var total = 0.0
    for temp in temps:
        total += temp
    return total / Float64(len(temps))
```

`raise` is only legal inside a `raises` function or a `try` block; a bare `raise` inside an `except` block re-raises the current error. An optional error type may follow `raises` — `def fetch() raises NetworkError -> String:` — in which case the type of the variable bound by `except e:` is inferred as that error type, with direct field access.

Handling uses Python-shaped `try` statements. Each `try` requires at least one `except` or `finally`; `else` runs only on success; `finally` always runs:

```mojo
try:
    var avg = calculate_average(temps)
    print(t"Average: {round(avg, 2)}°C")
except e:
    print("Error:", e)        # e is the caught error
else:
    on_success()              # only if no error occurred
finally:
    cleanup()                 # always
```

Catching without a binding (`except:`) is allowed when the details don't matter. One sharp edge, per the reference: **a single `try` block handles one error type** — if code in the block can raise more than one error type, the compiler rejects it. `main()` itself may be declared `raises`, in which case an unhandled error aborts the program (and, since 1.1, uncaught exceptions print to `stderr`).

Resource cleanup pairs naturally with `with` context managers, whose `__exit__` runs even when an error occurs:

```mojo
with open("file.txt") as f:
    var content = f.read()
# file is closed here, even if an error occurred
```

---

## 10. Modules and imports

Imports may appear at module level or inside functions — they do not have to sit at the top of the file. The standard library is rooted at `std`:

```mojo
import std.math                                  # binds std, std.math
from std.collections import Dict, Set            # selective import
from std.collections import Dict as Dictionary   # aliased import
from std.math import sqrt, pi
from std.math import *                           # wildcard import
from std.python import Python                    # Python interop entry point
```

> **VERSION-SENSITIVE — the 1.0 import overhaul.** Name resolution is now explicit and consistent: (1) `import a.b.c` binds `a`, `a.b`, *and* `a.b.c`; (2) relative imports must use `from` (`from . import foo`) — `import .foo` no longer works; (3) a package's submodules are accessible through the package only if its `__init__.mojo` re-exports them, though `import pkg.submodule` always works directly; (4) intra-package access without an explicit `import` was deprecated in 1.0 and is an **error in 1.1**, as is importing same-named functions from different modules into one overload set. Precompiled packages use `.mojoc` files; support for legacy `.mojopkg` files was removed in 1.1.

Your own code organizes the same way: a `.mojo` file is a module, a directory with `__init__.mojo` is a package, and 1.1 adds *namespace* directories — one logical directory name may resolve across several `-I` search paths.

---

## 11. The `main` entry point, files, and docstrings

- Save code as `name.mojo` (or `name.🔥`) and run it with `mojo name.mojo`; `mojo build` produces an executable.
- Execution starts at `def main():`. `main` takes no arguments in the basic form and returns `None`; declare it `def main() raises:` if top-level code can raise.
- Comments start with `#`. Docstrings are triple-quoted strings in the Python position (module, function, struct), e.g. `"""Docstring: what greet does."""` immediately inside `def greet():`.
- Indentation is syntax: a compound statement's body must be indented consistently, and the first body statement sets the block's indentation level.

A complete, current program tying this file together — variables, a raising function, collections, t-strings, and error handling, adapted from the official quickstart:

```mojo
from std.python import Python

def calculate_average(temps: List[Float64]) raises -> Float64:
    if len(temps) == 0:
        raise Error("No temperature data")
    var total = 0.0
    for temp in temps:
        total += temp
    return total / Float64(len(temps))

def main():
    print("Temperature Analyzer")
    var temps: List[Float64] = [20.5, 22.3, 19.8, 25.1]
    print("Recorded", len(temps), "temperatures")
    for index in range(len(temps)):
        print(t"  Day {index + 1}: {temps[index]}°C")
    try:
        var avg = calculate_average(temps)
        print(t"Average: {round(avg, 2)}°C")
        if avg > 25.0:
            print("Status: Hot week")
        elif avg > 20.0:
            print("Status: Comfortable week")
        else:
            print("Status: Cool week")
    except e:
        print("Error:", e)
```

---

## Version-sensitive summary (read before trusting any older tutorial)

| Older form | Current form (1.1.0) | Changed in |
|---|---|---|
| `fn` function keyword | `def` only | deprecated 1.0.0b1, **removed 1.1** |
| `let` declarations | `var` / `comptime` / immutable arguments | removed pre-1.0; absent from current keyword reference |
| `alias X = ...` | `comptime X = ...` | replaced pre-1.0; `alias` keyword **removed 1.1** |
| `x = 0` implicit declaration | `var x = 0` required | deprecated 1.0, **error 1.1** |
| `borrowed` / `inout` / `owned` | default-`imm` / `mut` / `var` | pre-1.0 |
| `read` convention | `imm` | renamed 1.0, **error 1.1** |
| `f"..."` (Python habit) | `t"..."` t-strings | Mojo never used `f"..."` as current syntax |
| `x[-1]` negative indexing | `x[len(x) - 1]` | removed 1.0.0b1 |
| `[1, 2, 3]` → `List` | `[1, 2, 3]` → `Array[Int, 3]` by default | 1.0 |
| `InlineArray`, `StringSlice` | `Array`, `StringSpan` | renamed 1.0; aliases removed 1.1 |
| `@parameter if` / `@parameter for` | `comptime if` / `comptime for` | **removed 1.1** |
| `__del__` | `__deinit__` (old spelling deprecated) | renamed 1.0 |
| `ImplicitlyDestructible` | `Deinitable` | renamed 1.0; alias removed 1.1 |

## Sources

All URLs below were read during the research session for this file (official Modular / Mojo documentation and release notes unless noted).

- https://docs.modular.com/mojo/manual
- https://mojolang.org/docs/manual/quickstart/
- https://docs.modular.com/mojo/manual/variables/
- https://mojolang.org/docs/reference/
- https://mojolang.org/docs/reference/keywords/
- https://mojolang.org/docs/reference/literals/
- https://mojolang.org/docs/reference/function-declarations/
- https://mojolang.org/docs/reference/simple-statements/
- https://mojolang.org/docs/reference/compound-statements/
- https://mojolang.org/docs/reference/expressions/
- https://mojolang.org/releases/v1.0.0/
- https://mojolang.org/releases/v1.0.0b1/
- https://mojolang.org/releases/v1.1.0/
