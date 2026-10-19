# 10 — Yrsa's Mojo Skill Notes

> **Operational cheat-sheet. Imperative. Current as of Mojo 1.1.0.**
> If a spelling is not in this file, do not invent it. Check the Manual.
> File 09 explains *why*; this file is for *before and while* writing.

---

## ⚠ VERSION-SENSITIVITY WARNINGS — READ FIRST

Mojo changed more between 0.26 and 1.1 than most languages change in a
decade. **Most Mojo code in blogs, videos, and notebooks is syntactically
dead.** Never copy a spelling from pre-1.0 material without this table.

| Dead / changed spelling | When | Current form |
|---|---|---|
| `fn` for functions | Deprecated in the v0.26.2 unification; warned in v1.0.0b1; **removed in v1.1.0** | `def` for **all** functions, with the old `fn` non-raising semantics (v1.0.0b1, v1.1.0 notes) |
| `alias` | Replaced in the 1.0 cycle; **removed in v1.1.0** | `comptime`, e.g. `comptime PI = 3.14159` |
| `__comptime_assert` | Replaced in 1.0 cycle; **removed in v1.1.0** | `comptime assert cond, t"msg {x}"` |
| `@parameter if` / `@parameter for` | **Removed in v1.1.0** | `comptime if` / `comptime for` |
| `@parameter` on parametric closures | **Renamed in v1.1.0** | `@__parameter` — legacy closures only |
| `unified` keyword (closures) | Removed in v1.0.0b1 | Capture list `{...}` after the signature; `{}` = unified, no captures; no list = legacy |
| `read` argument convention | Hard error in v1.1.0 | `imm` |
| `let` | Absent from the current Variables manual | `var` for variables; `comptime` for constants; immutable argument for read-only input |
| `inout`, `owned`, `borrowed` (pre-1.0 tutorials) | Superseded | `mut`, `var`, `out`, `imm` (default), `ref`, `deinit` — §3 |
| Implicit variable declaration | Error in v1.1.0; walrus no longer declares | Always `var x = ...` |
| Negative indexing `x[-1]` | Removed in the 1.0 cycle | `x[len(x) - 1]`; bounds checking on by default on CPU (v1.0.0b1) |
| `NDBuffer` | Fully removed in v1.0.0b1 | `TileTensor` |
| `UnsafePointer` family | Deprecated in v1.0 for the `Pointer` family (`Pointer`, `MutPointer`, `ImmPointer`, `OptionalPointer`); pre-`unsafe_` spellings removed in v1.1.0 | Current `Pointer` names + `unsafe_*` spellings from the pointer manual — never port old pointer code by eye |
| `.mojopkg`; public async task API | Removed in v1.1.0 | Current packaging guide |
| `from pkg import ...` also binding `pkg` | Changed in v1.0.0b1 | Import the module explicitly if you need its name |
| Comparing tuples of differing length/type | Removed in v1.0.0b1 | Rejected statically |
| f-strings `f"..."` (Python habit) | Never Mojo's form | t-strings `t"Hi, {name}!"`; `String(t"...")` when a `String` is required |

**Rule:** code containing `fn`, `let`, `alias`, `inout`, or
`@parameter if` is old. Stop. Translate with this table or rewrite from
the current Manual. Never mix eras in one file.

---

## 1. Before writing Mojo, check these

- [ ] **Version:** writing 1.1, not a remembered 0.x? (Table above.)
- [ ] **Entry point:** all runtime code inside `def main():` or a function it calls? Nothing executable at file scope.
- [ ] **Keyword:** `def` everywhere — zero `fn`?
- [ ] **Declarations:** every variable `var`, every constant `comptime`? No `let`, no bare-assignment declares.
- [ ] **Types:** every argument typed? Every return typed or deliberately `None`? Every struct field `var` + type?
- [ ] **Effects:** every raising function says `raises`? Every non-raising caller of one has `try`?
- [ ] **Mutation:** every mutated argument / `self` says `mut`? Owned-and-consumed says `var`? Initializers `out self`?
- [ ] **Ownership:** each assignment — copy, `.copy()`, or move (`^`) — is the one I meant? No moved-from name reused?
- [ ] **Indexing:** no negative indexes? Last element is `xs[len(xs) - 1]`?
- [ ] **Division:** integer `/` (towards zero) vs `//` (floor) chosen on purpose, especially with negatives?
- [ ] **Conversions:** explicit — `Float64(n)`, `Int(x)` — never assumed?
- [ ] **Strings:** t-strings, not f-strings? `String(...)` where a real `String` is needed?
- [ ] **Imports:** every non-prelude name imported explicitly, in the exact form used?
- [ ] **Comptime honesty:** everything in a `comptime` context known at compile time — no runtime input, no raising calls?

---

## 2. Compact syntax tables

### 2.1 Declarations

| Intent | Write |
|---|---|
| Mutable variable, inferred | `var count = 0` |
| Mutable variable, explicit | `var name: String = "Mojo"` |
| Declared, uninitialized | `var c: String` |
| Compile-time constant | `comptime num_cols: Int = 8` |
| Compile-time type choice | `comptime Choice = Int if cond else String` |
| Reference binding (no copy) | `ref item_ref = items[1]` |
| Move / transfer | `var moved = source^` |
| Explicit copy | `var second = first.copy()` |
| Parameter (compile-time) | `def f[rank: Int](...)` · `struct Grid[cols: Int, rows: Int]:` |
| Argument (runtime) | `def f(x: Int)` |

Prelude, no import: `Int`, `Float64`, `Bool`, `String`, `List`,
`print`, `len`, `range`. Types `PascalCase`; names `lower_snake_case`.

### 2.2 Function forms — only `def`

| Form | Signature |
|---|---|
| No return | `def greet(name: String):` |
| Explicit `None` (equivalent) | `def greet(name: String) -> None:` |
| Returning | `def add(a: Int, b: Int) -> Int:` |
| Default argument | `def my_pow(base: Int, exp: Int = 2) -> Int:` |
| Raising | `def risky() raises:` |
| Typed error | `def validate(v: Int) raises ValidationError -> Int:` |
| Positional-only | `def min(a: Int, b: Int, /) -> Int:` |
| Keyword-only | `def kw(a1: Int, *, double: Bool) -> Int:` |
| Homogeneous variadic | `def sum(*values: Int) -> Int:` |
| Variadic keywords | `def print_nicely(var **kwargs: Int):` |
| Named result | `def get_tag(var name: String, out tag: NameTag):` |
| Parameterized | `def greet_repeat[count: Int](msg: String):` |
| Empty body | `def do_nothing():` + indented `pass` |
| Lambda | `var to_index = lambda (x: Int, y: Int) -> Int: y * 8 + x` |
| Static method | `@staticmethod` above a `def` in a struct |

Parentheses always required; `[]` only for parameters; a body always
required (`pass` counts). Overloads may differ in argument types or
conventions — **never only in return type or `raises`**.

### 2.3 Argument conventions

| Convention | Meaning | Use when |
|---|---|---|
| *(none)* — `imm` | Immutable borrow | Default: reading an argument. (`imm` replaces dead `read`.) |
| `mut` | Mutable reference | Function must change the argument; `mut self`; `mut *strs` |
| `var` | Owned value, may mutate/consume | Taking ownership; `var **kwargs` |
| `out` | Uninitialized; must initialize | `__init__(out self, ...)`; named results |
| `ref` | Names a reference | `ref x = xs[0]`; `for ref i in strs:` |
| `deinit` | Consuming destructor receiver | `def __deinit__(deinit self):` |

`self`: plain = read-only; `mut self` = mutating method; `out self` =
initializer. `Self` (capital) = the type, its parameters, its
`comptime` members.

### 2.4 Control flow

| Construct | Form |
|---|---|
| Conditional | `if cond:` / `elif cond:` / `else:` |
| Ternary | `a if cond else b` |
| Loops | `for i in range(5):` · `for item in xs:` · `for index, value in enumerate(xs):` · `while n > 0:` |
| Skip / stop | `continue` / `break` |
| Compile-time | `comptime if cond:` · `comptime for i in range(5):` |
| Errors | `try:` / `except e:` / `else:` / `finally:` · `raise Error("msg")` (only in a `raises` function) |
| Operators | `+ - * / // % **` · `== != < <= > >=` (chainable) · `and or not` · `+= -= *= /=` |
| Comprehension | `[x * 2 for x in values]` |

Integer `/` truncates towards zero; `//` floors. Memorize it.

### 2.5 Structs and traits — minimum kit

```mojo
@fieldwise_init
struct Point(Copyable):
    var x: Int
    var y: Int
    def magnitude_squared(self) -> Int:
        return self.x * self.x + self.y * self.y

struct Counter:
    var n: Int
    def __init__(out self):
        self.n = 0
    def bump(mut self):
        self.n += 1
```

- `@fieldwise_init` only for pure field assignment. Custom `__init__`
  must initialize **every** field.
- Conformance is declared — `struct Duck(Copyable, Quackable):` —
  explicit, all-or-nothing, never retroactive for others' types.
- Generic over a trait: `def f[T: Quackable](v: T):` or
  `def f(v: Some[Quackable]):`.

---

## 3. Decision rules

**Function form:** always `def`. Pure and total → typed return, no
`raises`. Can fail → `raises` (`Error`, or a typed error when callers
must distinguish). Small and hot → `@inline(.always)`; cold path →
`@inline(.never)` (1.1 forms; never combine disagreeing inline
decorators — that is now an error).

**Copy vs move vs borrow:**
1. Small `ImplicitlyCopyable` (`Int`, `Float64`, `Bool`): copy.
2. Reading a big value: borrow — default `imm` argument, or `ref`.
3. Mutating the caller's value: `mut`. Never copy-modify-forget.
4. Last use, or callee should own it: move with `^` / take a `var` argument.
5. Second independent owner of a `List`-like value: explicit `.copy()`.
   Cannot justify it in one sentence? Borrow instead.

**Comptime vs runtime:** known from source alone, shapes the code
(sizes, types, tables, switches) → parameter `[]` / `comptime`. From
the user, the data, or the clock → runtime argument `()`. Never pay
runtime cost for a compile-time fact; never force a runtime fact into
`comptime`.

**`List` vs fixed array vs `SIMD`:**
- Growable, runtime size, one element type → `List[T]` (default).
  Pre-fill: `List[T](length=n, fill=v)`.
- Fixed count known at compile time → the fixed-size array type in the
  current collections docs. **Caution:** the 1.1 notes name it `Array`
  (`Array[T, N]`; `concat()`, `repeat()`, `fill_with=` constructor).
  `InlineArray` was **not** verified in current docs read for this
  corpus — do not write it in new code without re-checking first.
- Same numeric op across lanes, dtype + width are compile-time facts →
  `SIMD[dtype, size]`, e.g. `SIMD[DType.float64, 4]` (1.1 also allows
  `SIMD[.float64, 4]`). Only when vectorization is the point.
- Text keys → `Dict` / `StringDict`. Absence as a value →
  `Optional[T]`. Borrowed view, not an owner → `Span`.

**Struct vs trait vs overload:** one data shape → `struct`. Several
shapes, one behaviour → `trait` + generic function. Same name,
different argument types → overloads. No runtime type-check simulations.

**Raise vs `Optional`:** failure is exceptional and must not be
ignored → `raises`. “No result” is a normal outcome → `Optional[T]`.

---

## 4. Quick-lookup: most-used stdlib signatures

Only signatures verified in docs/release notes read for this corpus.

| Call | Signature / form | Notes |
|---|---|---|
| Print | `print(...)`, `print(value, end="")` | Prelude; takes a t-string directly |
| Length | `len(xs)` | Prelude |
| Range | `range(stop)`, `range(start, stop)` | Prelude |
| List literal | `var xs: List[Int] = [1, 2, 3]` | Prelude type |
| List pre-fill | `List[Int](length=count, fill=0)` | Get-started |
| List append | `def append(mut self, var value: Self.T, /)` | Stabilized 1.1 |
| List grow | `extend()`, `resize()`, `reserve()` | 1.1: extend/resize grow geometrically; `reserve()` is exact |
| String init | `def __init__(out self)`; `def __init__(out self, *, capacity_bytes: Int)` | Stabilized 1.1 |
| String reserve | `def reserve_bytes(mut self, new_capacity_bytes: Int, /)` | Stabilized 1.1 |
| String join | `"".join(list_of_strings)` | Get-started |
| SIMD | `def __init__(out self)`; `def __eq__(self, rhs: Self) -> Bool`; `def __len__(self) -> Int` | Stabilized 1.1 |
| Sort closure | `sort()` takes its closure as a runtime (unified) argument | Migrated 1.1; parameter form gone |
| Seed RNG | `from std.random import seed` → `seed()` | Inside `main()`, never file scope |
| Random int | `from std.random import random_si64` | Get-started import |
| Square root | `from std.math import sqrt` (`as root` to alias) | Cheat-sheet form |
| Error | `Error("message")`, thrown with `raise` | Functions manual |
| Counter | `Counter(["a", "a", "b"])` | 1.1: any iterable, not only `List` |

Not in this table = not verified this session. Look it up in the
stdlib reference first; never reconstruct a signature from Python,
Rust, or an old Mojo post.

---

## 5. House rules

1. Write 1.1 or write nothing. Dead spellings are bugs, not style.
2. One file, one era.
3. Type the boundaries, infer the interiors.
4. Default to borrow; justify every copy; move on last use.
5. `raises` is contract: state it, handle it, or propagate it.
6. Construct not in file 09, file 10, or a Manual page opened this
   session? Open the Manual first, *then* write the line.

---

## Sources

Exact URLs read during the research for this file:

- https://docs.modular.com/mojo/manual/
- https://docs.modular.com/mojo/manual/variables/
- https://docs.modular.com/mojo/manual/traits/
- https://docs.modular.com/mojo/manual/packages/
- https://docs.modular.com/mojo/manual/pointers/unsafe-pointers/
- https://mojolang.org/docs/manual/functions/
- https://mojolang.org/docs/manual/get-started/
- https://mojolang.org/docs/manual/basics/
- https://mojolang.org/docs/manual/lifecycle/life/
- https://mojolang.org/releases/v1.0.0b1/
- https://mojolang.org/releases/v1.0.0/
- https://mojolang.org/releases/v1.1.0/
- https://mojolang.org/assets/files/mojo-cheat-sheet-basics-light-1d88e2110a8da4e026a7e13464d45b7e.pdf
