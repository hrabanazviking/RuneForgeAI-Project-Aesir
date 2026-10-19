# Mojo Type System and Generics

*Study corpus — commissioned by Volmarr, 2026-10-19. Describes Mojo as documented in the current official documentation and release notes at the time of writing: **Mojo 1.1.0** (1.0.0 / 1.0.0b1 notes used for version-sensitive history). Assumes `02_LANGUAGE_FUNDAMENTALS.md`: `def`-only functions, `var` variables, and the current argument conventions (`imm` default, `mut`, `var`, `out`, `deinit`, `ref`).*

Mojo's type system is built from three pieces that interlock: **structs** define concrete value types; **traits** define the contracts those types can promise; and **parameters** — compile-time values written in `[...]` — make both generic. Almost everything a Mojo programmer calls “generics” or “metaprogramming” is the parameter system plus the `comptime` keyword. There is no class inheritance: behavior is shared through traits and composition, never through a base class.

---

## 1. Structs

### 1.1 Declaring a struct, its fields, and its methods

A struct is a value type: each variable holds its own independent copy of the data, laid out as declared fields. Names use `PascalCase` by convention. Every field is declared with `var` and **must** have a type annotation; fields cannot have default values, and every field must be initialized by the initializer.

```mojo
from std.math import sqrt

struct Point:
    var x: Int
    var y: Int

    def __init__(out self, x: Int, y: Int):
        self.x = x
        self.y = y

    def distance(self) -> Float64:
        return sqrt(Float64(self.x * self.x + self.y * self.y))

def main():
    var p = Point(3, 4)
    print(p.distance())   # 5.0
    print(p.x, p.y)       # 3 4 — fields are accessed with dot notation
```

A struct body may contain fields (`var name: Type`), instance methods, `@staticmethod` methods, `comptime` members (§4), an initializer, and a deinitializer. An empty struct uses `pass`. Structs cannot be nested inside other structs, traits, or functions, and a struct cannot store an instance of itself — even wrapped in `Optional` — so recursive structures (linked lists, trees) must go through pointers.

Field types must be concrete types, not traits. “Store something `Writable`” is expressed by parameterizing the struct so the trait becomes a concrete type at compile time (§5):

```mojo
@fieldwise_init
struct Sound[T: Writable & Copyable & Deinitable]:
    var item: Self.T    # OK: T is concrete for each instantiation

def main():
    var g = Sound[Int](item=42)
    print(g.item)       # 42
```

### 1.2 `@fieldwise_init`: synthesized initializers

When an initializer would only assign arguments to fields in order, don't write it — ask the compiler to synthesize it:

```mojo
@fieldwise_init
struct Color:
    var r: UInt8
    var g: UInt8
    var b: UInt8

def main():
    var color = Color(255, 0, 0)
    print(color.r, color.g, color.b)   # 255 0 0
```

`@fieldwise_init` generates exactly `def __init__(out self, var name: String, age: Int)`-style code (moving `var`-convention fields with `^`, copying the rest). Synthesis fails if a field is neither copyable nor movable. `@fieldwise_init("implicit")`, or `@implicit` on a hand-written single-argument initializer, additionally enables implicit conversion: a function expecting the struct will accept a bare value the struct can be built from.

### 1.3 Methods and `self`

Instance methods take `self` first; its convention is the method's access contract:

- `self` — immutable reference (read-only method).
- `mut self` — may modify the instance.
- `out self` — initializers only; builds the instance.
- `deinit self` — deinitializer / consuming methods only.
- `ref self` — reference with parametric mutability.

A method without `self` is an error unless marked `@staticmethod`. Static methods belong to the type, see parameters and `comptime` members, but touch no instance state — the factory/utility pattern:

```mojo
struct MathUtils:
    comptime pi: Float64 = 3.141592653589793

    @staticmethod
    def square(x: Int) -> Int:
        return x * x

def main():
    print(MathUtils.square(5))   # 25
    print(MathUtils.pi)          # 3.141592653589793
```

`Self` (capital) inside a struct or trait denotes the enclosing type itself — in return types (`def create() -> Self`), in field types (`Self.T`), and to reach parameters (`Self.num_cols`). `self` (lowercase) is merely the conventional name of the instance argument. Since 1.0, a method's `self` must have type `Self`; constrain it with a trailing `where` clause instead of annotating a specialized type.

### 1.4 Special methods (dunders) and the value lifecycle

Double-underscore methods hook operators, built-ins, and the value lifecycle. The compiler enforces their signatures — argument counts, conventions, and return types are checked. The lifecycle core:

| Method | Signature shape | Role |
|---|---|---|
| `__init__` | `def __init__(out self, ...)` | Construct; **every** field must be assigned before return. Multiple overloads allowed. |
| Copy initializer | `def __init__(out self, *, copy: Self)` | Build from an immutable reference to an existing value. Cannot raise. Prefer calling `value.copy()`. |
| Move initializer | `def __init__(out self, *, deinit move: Self)` | Build by consuming an existing value. Cannot raise. |
| `__deinit__` | `def __deinit__(deinit self)` | Cleanup at the value's last use (ASAP destruction). Cannot raise, cannot be overloaded. |
| `__len__` | `def __len__(self) -> Int` | Backs `len(x)`; required by the `Sized` trait. |
| `__iter__` / `__next__` | — | Back `for` loops (a `for` desugars to `while` + these). |
| `__enter__` / `__exit__` | — | Back `with` context managers; `__exit__` runs even on error. |
| `__getitem__`, `__eq__`, `__add__`, … | operator-shaped | Back subscripts, comparisons, and arithmetic for the type. |

> **VERSION-SENSITIVE — destructor renamed.** The destructor was historically `__del__(owned self)`. In 1.0 it was renamed to **`__deinit__(deinit self)`** for parity with `__init__`; the old `__del__` spelling still works in 1.0 but emits a deprecation warning with a fix-it. Write `__deinit__` in new code. Likewise the trait `ImplicitlyDestructible` was renamed to `Deinitable` in 1.0, and its alias was removed in 1.1 (see §6).

Initializers in full:

```mojo
struct Point:
    var x: Float64
    var y: Float64

    def __init__(out self, x: Float64, y: Float64):
        (self.x, self.y) = (x, y)          # tuple assignment is fine

    def __init__(out self, *, copy: Self):  # copy initializer
        self.x = copy.x
        self.y = copy.y

    def __deinit__(deinit self):
        pass                                # nothing to release here
```

Omitting `out self` in `__init__` is a compile error — the initializer's job is to *produce* `Self` through the `out` slot, not to receive an instance. Most structs never write copy/move initializers or a deinitializer by hand: conformance to `Copyable` / `Movable` makes the compiler synthesize field-wise versions, and implicitly deinitable structs get a default `__deinit__` that destroys each field. Synthesis fails loudly when a field cannot support the operation.

Structs may also declare `comptime` members — type-level constants and aliases evaluated at compile time, reachable through the type or any instance:

```mojo
@fieldwise_init
struct Matrix2D[dtype: DType, w: Int, h: Int]:
    pass

struct Test[dtype: DType]:
    comptime default_size = 1024
    comptime DefaultMatrixType = Matrix2D[Self.dtype, Self.default_size, Self.default_size]

def main():
    print(Test[.int32].default_size)   # 1024
```

---

## 2. Traits

### 2.1 Defining a trait

A trait is a contract: a named set of required methods, provided (default) methods, associated types, and compile-time values. Declare one at top level with the `trait` keyword. A body of `...` marks a method **required**; a real body makes it **provided** — inherited by conforming types, overridable, and allowed to call the trait's other requirements:

```mojo
trait DeflectionSensing:
    def fetch_reading(self) -> Float64:
        ...

    comptime absolute_tolerance: Float64 = 0.05

    def within_tolerance(self) -> Bool:
        return abs(self.fetch_reading()) <= Self.absolute_tolerance
```

Two distinctions that are easy to get wrong: `...` (requirement) is **not** interchangeable with `pass` (a provided no-op body, valid only for `None`-returning methods); and a trait with no requirements at all is a *marker trait* — it certifies a property (`AnyType`, `RegisterPassable`, `ImplicitlyCopyable` are stdlib examples) without demanding any code. Traits cannot declare fields, cannot take parameter lists (`trait T[X]:` is an error), and their methods cannot carry `where` clauses.

### 2.2 The full trait contract

Beyond methods, a trait contract has three kinds of `comptime` members:

```mojo
trait Container:
    associatedtype Element: Movable        # (manual spelling; see note below)

trait Pausable:
    comptime max_pause_seconds: Float64    # required value: each type supplies its own
    def pause(self):
        pass                               # provided no-op

trait DeflectionSensing:
    comptime absolute_tolerance: Float64 = 0.05   # shared constant: one value for all
```

- **Associated types** — a subordinate type each conforming type must name, e.g. a container's element type. In the current trait-declarations reference these are written as `comptime` members without an initializer: `comptime Associated: Writable & Copyable & Deinitable`, and the conforming struct answers with `comptime Associated = String`, thereafter usable as `Self.Associated`. (The Manual's traits page still shows the `associatedtype Element: Movable` spelling in one example; the reference's `comptime` form is the one used throughout its worked examples — treat the area as recently reshaped and prefer the `comptime` form in new code.)
- **Required compile-time values** — `comptime name: Type` with no value; every conforming type defines its own.
- **Shared compile-time constants** — `comptime name = value` in the trait; one definition serves all conformers.

### 2.3 Conforming to a trait

Conformance is **explicit and declared at the definition site** — list the traits in parentheses after the struct name (after the parameter list, if any) and implement every requirement. Duck typing does not exist here: a struct that happens to have a matching `fetch_reading()` does **not** conform until it says so, and conformance can never be added retroactively to a type you don't own.

```mojo
@fieldwise_init
struct CapacitiveSensor(Copyable, DeflectionSensing):
    def fetch_reading(self) -> Float64:
        return Float64(21.5)

@fieldwise_init
struct Timer(Copyable, Pausable):
    comptime max_pause_seconds: Float64 = 30.0   # satisfies the required value
    def pause(self):
        print("Paused")
```

If any requirement is missing — a method, an associated type, a required value — compilation fails with a note naming the missing item. Conformance is all-or-nothing; default implementations count toward satisfying it.

### 2.4 Refinement (trait inheritance)

A trait can *refine* another by listing it in parentheses; conforming types must then satisfy both, transitively. Every trait implicitly refines `AnyType`.

```mojo
trait CalibratableDeflectionSensing(DeflectionSensing):
    def calibrate(mut self):
        ...

struct EddyCurrentSensor(CalibratableDeflectionSensing):
    def fetch_reading(self) -> Float64:
        ...  # implementation
    def calibrate(mut self):
        ...  # implementation
```

A refining trait may override a parent's method by redeclaring the same signature. Refinement says “always goes together”; for independent capabilities used together only sometimes, use composition instead (§2.5).

### 2.5 Composition with `&`, and naming a composition

A parameter or conformance can demand several traits at once with `&`. All of them must hold:

```mojo
trait Loggable:
    def log(self, message: String):
        ...

def poll_and_log[T: DeflectionSensing & Loggable](sensor: T):
    print(sensor.fetch_reading())
    sensor.log("Polling sensor")
```

A reused composition can be named with a `comptime` declaration. The name is shorthand, not a new trait — conforming to both traits automatically satisfies it, with nothing extra to declare:

```mojo
comptime SensorLike = DeflectionSensing & Loggable

struct SmartSensor(Copyable, SensorLike):
    def fetch_reading(self) -> Float64:
        return 18.2
    def log(self, message: String):
        print("reading logged")
```

When two composed traits provide conflicting defaults for the same method, the compiler refuses to choose; the struct (or the composed use) must implement the method itself, overriding both.

### 2.6 Conditional conformance

A conformance can be gated on a compile-time condition with a `where` clause in the conformance list — the standard way to say “`Pair[T]` is `Equatable` exactly when `T` is”:

```mojo
@fieldwise_init
struct Pair[T: Copyable & Deinitable](
    Equatable where conforms_to(T, Equatable),
    Writable where conforms_to(T, Writable),
    Copyable
):
    var first: Self.T
    var second: Self.T

def main():
    var pair1 = Pair(first=1, second=2)
    var pair2 = Pair(first=1, second=2)
    print(pair1 == pair2)        # True — because Int is Equatable
    var pair4 = pair1.copy()     # OK — Copyable conformance is unconditional
```

Conditions may be any consistent compile-time fact — trait tests via `conforms_to(...)`, parameter comparisons (`Iterable where N > 0`), `dtype.is_floating_point()`, platform predicates — but never a computed `comptime` member of the struct itself (the signature is needed to resolve members; that would be circular). A struct opts *out* of the otherwise-automatic movability (§6) the same way: `Movable where False`.

---

## 3. Using traits to bound parameters

Traits earn their keep as bounds on compile-time parameters. The named-parameter form declares the bound once and lets the body use the trait's whole interface; the compiler infers the parameter from the call arguments when it can:

```mojo
def averaged_poll[
    SensorType: DeflectionSensing, //   # // marks infer-only parameters
](sensor: SensorType, samples: Int) -> Float64:
    var total: Float64 = 0.0
    for _ in range(samples):
        total += sensor.fetch_reading()
    return total / Float64(samples)

def main():
    var sensor = CapacitiveSensor()
    print(averaged_poll(sensor, 10))   # SensorType inferred — no [...] at the call
```

When the type never needs naming inside the body, the `Some[...]` sugar puts the constraint on the argument itself. It is pure shorthand for a hidden infer-only parameter:

```mojo
def averaged_poll_2(sensor: Some[DeflectionSensing], samples: Int) -> Float64:
    ...
```

Use the named form when the same type must appear twice (`def compare_readings[SensorType: DeflectionSensing](a: SensorType, b: SensorType)`) — `Some` used twice would infer two independent types. `Some` cannot type a struct field, since a field has no call site to infer from; give the struct an explicit parameter instead.

---

## 4. Parameters and `comptime`: Mojo's generics and metaprogramming engine

### 4.1 Parameters vs. arguments

Mojo splits what other languages lump together:

- **Arguments** — runtime values, in `(...)`, typed normally: `(x: Int)`.
- **Parameters** — compile-time values, in `[...]`, declared as `name: TypeOrTrait` and bound at each call site: `[T: Copyable, n: Int]`. The compiler generates a specialized copy of the function or struct for each distinct parameter set — the same model as C++ templates or Rust generics, with traits playing the role of concepts/bounds.

```mojo
def pow_exp[exp: Int](base: Int) -> Int:
    var res = 1
    comptime for _ in range(exp):   # unrolled at compile time (see §4.3)
        res *= base
    return res

struct Matrix[dtype: DType, rows: Int, cols: Int]:
    ...

comptime F32Matrix = Matrix[DType.float32, 4, 4]   # a named specialization
```

Callers write parameters in brackets — `pow_exp[3](2)`, `SIMD[DType.float32, 4](...)`, `Grid[8, 8]()` — positionally or by keyword (`MyStruct[cond=True, T=Float32](...)`), and may omit them entirely when inference can recover them from the arguments. Parameters support defaults, and the `//` marker (§3) makes parameters infer-only. Inside a parameterized struct, parameters are reached through `Self` (`Self.T`, `Self.num_rows`); bare `T` is not valid in the struct body.

### 4.2 `comptime` declarations — the current spelling of “alias”

> **VERSION-SENSITIVE — `alias` is gone; `@parameter` control flow is gone.** Pre-1.0 Mojo spelled compile-time constants with the `alias` keyword (`alias Float32 = SIMD[...]`) and compile-time branching with `@parameter if` / `@parameter for`. Both were replaced by the unified **`comptime`** keyword during the 1.0 cycle, and the 1.1 release notes list the `alias` and `__comptime_assert` keywords and the `@parameter if` / `@parameter for` syntax under **Removed**. The `@parameter` decorator itself survives only in mutated form: in 1.1 it was renamed to `@__parameter` and is used solely for declaring *legacy* (parameter-passed) closures. Any code sample containing `alias`, `@parameter if`, or `@parameter for` is pre-current Mojo.

The `comptime` keyword now does all of this work, in several grammatical positions:

```mojo
comptime SIZE = 256
comptime MAX = SIZE * 2                       # compile-time arithmetic

comptime MyInt = Int                          # type alias
comptime Vec3 = List[Float64]                 # alias for a parameterized type
comptime SensorLike = DeflectionSensing & Loggable   # trait-composition alias

def add(a: Int, b: Int) -> Int:
    return a + b

comptime MY_VALUE = add(2, 3)                 # an ordinary function, run at compile time
```

Key facts:

- A `comptime` value must be computable at compile time; ordinary functions can be evaluated there (the compile-time interpreter runs them), which is what makes Mojo metaprogramming “just write Mojo.”
- `comptime` also declares struct/trait members (§1.4, §2.2) and associated types.
- As an expression operator, `comptime(expr)` — parentheses required — forces one expression to compile time: `var x = comptime(heavy_calculation())`.
- Parametric `comptime` declarations can carry constraints: `comptime AscendingMidpoint[lo: Int, hi: Int]: Int where lo < hi = (lo + hi) / 2` — each use is checked, and a violating instantiation is an error.
- Inside a function body, `comptime name = ...` creates a local compile-time constant; it cannot be reassigned at runtime.

### 4.3 Compile-time control flow: `comptime if` and `comptime for`

```mojo
from std.sys import size_of

comptime if size_of[Int]() == 8:
    print("64-bit")
else:
    print("Probably 32-bit")

comptime for i in range(3):
    print(i)   # compiled as: print(0); print(1); print(2)
```

`comptime if` prunes the dead branch entirely — only the selected branch exists in the compiled program — and `comptime for` fully unrolls its loop, trading binary size for zero loop overhead and further optimization. Both require compile-time-known conditions/sequences; a runtime value in either is a compile error. `comptime if` supports `elif`/`else` exactly like runtime `if`. These forms are the workhorse of generic code: iterating a variadic pack, for instance, is `comptime for idx in range(args.__len__()): ...` because the pack length exists only at compile time.

Compile-time assertions follow the same pattern: `comptime assert i > 5, t"expected i > 5, got {i}"` (the legacy `__comptime_assert` keyword was removed in 1.1).

### 4.4 `where` clauses: prove it, then gate on it

A trailing `where` clause states compile-time preconditions the compiler must *prove* before an instantiation compiles — trait facts via `conforms_to`, numeric truths, parameter predicates. Since 1.0 a clause may carry a diagnostic message, written `where (condition, "message")`, which the compiler shows when the constraint fails:

```mojo
def process[n: Int](data: SIMD[.float32, n]) -> Float32 where (
    n == 1 or n == 2 or n == 4 or n == 8 or n == 16 or n == 32
):
    ...

def foo[sc: Int]() where (sc > 1, "scaling factor must be greater than 1"):
    ...

def compare[T: AnyType](x: T, y: T) -> Int32 where conforms_to(T, Comparable):
    ...
```

`where` belongs at the *end* of a declaration — inside a `[...]` parameter list it is an error as of 1.0 (use the trailing form), and it constrains compile-time parameters only, never runtime arguments. The same clause form gates conditional conformances (§2.6), `comptime` declarations (§4.2), and constrained `thin` function types (`comptime Kernel = def[w: Int](Int) thin -> None where (w > 0, "width must be positive")`).

### 4.5 Reflection and compile-time introspection

Mojo exposes type structure to ordinary compile-time code — no macro system, no compiler plugins. Three keyword-expressions form the base layer (from the expressions reference):

- `type_of(x)` — the type of an expression.
- `conforms_to(T, Trait)` — a compile-time trait-conformance test, usable in `where` clauses, `comptime if`, and `comptime assert`.
- `origin_of(x)` — the origin of a reference.

> **VERSION-SENSITIVE — unified reflection API.** In 1.0.0b1 the standard library gained a unified reflection entry point: `reflect[T]()` in `std.reflection` returns a `Reflected[T]` handle, replacing the older family of `struct_field_*` free functions and `get_type_name` / `get_base_type_name`, which are now `@deprecated` (the `ReflectedType[T]` wrapper went with them). `reflect` is auto-imported through the prelude.

With it, generic code reads a type's shape — its name and its fields — and adapts:

```mojo
def inferred_type[T: Writable, //](value: T):
    print(t"Value is {value}. Type is {reflect[T].name()}.")
```

The compile-time cheat sheet summarizes the reflected surface as `reflect[T].name()`, `.field_count()`, `.field_names()`, and field-type access — enough for a trait to synthesize behavior from a struct's fields. That is precisely how modern Mojo implements “derived” conformances without compiler magic: the `Writable` trait's default implementation uses reflection to write a struct's fields automatically, so declaring `(Writable)` on a struct whose fields are all `Writable` just works — and any user trait can offer the same kind of default. Type refinement ties in: inside a scope guarded by `where`, `comptime if`, or `comptime assert` on a `conforms_to(...)` fact, the compiler *narrows* the type, so trait methods become callable directly (the 1.0.0b1 notes show this eliminating manual `trait_downcast` calls).

Finally, “run code at compile time” needs no marker at all: any function whose inputs are compile-time-known can be invoked in a `comptime` context and its result baked in —

```mojo
def meters(ft: Float64) -> Float64:
    return ft * 0.3048

comptime track = meters(100.0)   # computed while compiling; free at runtime
```

---

## 5. Parameterized types in practice

Putting §§1–4 together, a generic container follows a fixed recipe: parameters in `[...]`, trait bounds on those parameters, fields typed through `Self`, conformances possibly conditional:

```mojo
@fieldwise_init
struct Pair[T: Copyable & Deinitable](
    Equatable where conforms_to(T, Equatable)
):
    var first: Self.T
    var second: Self.T

struct Grid[num_cols: Int, num_rows: Int]:
    var cells: List[Int]
    var count: Int

    def __init__(out self):
        self.count = Self.num_cols * Self.num_rows
        self.cells = List[Int](length=self.count, fill=0)

def main():
    var glider_grid = Grid[8, 8]()
    var p = Pair(first=1, second=2)   # T inferred as Int from the fields
```

The standard library's own types are the reference examples: `SIMD[dtype: DType, size: Int]`, `List[T]`, `Dict[K: KeyElement, V: ...]`, `Optional[T]`, `Array[T, N]` — each a struct whose parameters are types, values, or both, bounded by the traits of §6.

---

## 6. Value-semantics traits: the lifecycle vocabulary

Mojo has no garbage collector and no implicit reference semantics for user types. What a value *can do* — be copied, be moved, be destroyed implicitly, be compared — is spelled out as trait conformances, and generic code bounds its parameters with exactly these traits. The core set, as documented in the current stdlib reference and release notes:

| Trait | What conformance promises | How you get / use it |
|---|---|---|
| `AnyType` | The root: a type with a (possibly trivial) deinitializer story. Every trait refines it; every struct conforms when its members do. | Automatic. The default bound when nothing else is known. |
| `Movable` | Values can be transferred with `^` / move-initialized. | **Structs are `Movable` by default since 1.0** (opt out or narrow with `Movable where <cond>` / `Movable where False`); declaring it synthesizes a field-wise move initializer. |
| `Copyable` | Values can be copied explicitly via `value.copy()` / the `copy:` initializer. | Declare it; the compiler synthesizes a field-wise copy initializer if all fields are copyable. |
| `ImplicitlyCopyable` | Copying is cheap/trivial enough to happen silently on assignment (refines `Copyable`). | Marker-style conformance for simple value types: `Int`, `Float64`, `Bool`. `List` deliberately lacks it — hence `.copy()` / `^`. |
| `Deinitable` | The value can be destroyed implicitly at last use via `__deinit__`. | Automatic for structs whose members are deinitable; custom `__deinit__(deinit self)` overrides the default. Opt out (explicit-destruction types) with `Deinitable where False`. **Renamed from `ImplicitlyDestructible` in 1.0; the old alias was removed in 1.1.** |
| `Defaultable` | A no-argument `__init__(out self)` exists. | Implement the default initializer. (E.g. `Array` conforms when its element type does — conditional conformance.) |
| `Equatable` | `__eq__` / `__ne__` are defined. | Implement, or gain it conditionally in generic wrappers via `where conforms_to(T, Equatable)`. |
| `Comparable` | The full ordering set (`<`, `<=`, `>`, `>=`) on top of equality. | Implement the comparisons; required by generic code like `clamp[T: Comparable & ImplicitlyCopyable]`. |
| `Hashable` | `__hash__` is defined; usable as a `Dict` key / `Set` element (with `KeyElement`). | Implement `__hash__` taking a `Hasher`. |
| `Boolable` | The value can be tested for truthiness (`if value:`). | Implement `__bool__`. |
| `Sized` | `__len__` is defined; `len(x)` works. | Implement `__len__(self) -> Int`. |
| `Writable` | The value can be written to a `Writer` — this is what makes `print(x)` work. Its default implementation uses reflection over the struct's fields. | Declare it (fields must be `Writable` for the default), or implement `write_to[W: Writer](self, mut writer: W)`. |
| `Stringable` / `Representable` | `__str__` / `__repr__` conversions to `String`. | Appear together in stdlib “Implemented traits” lists (e.g. on `DType`). |
| `RegisterPassable` / `TrivialRegisterPassable` | The value is passed in a register rather than in memory; the trivial variant is memcpy-like with no custom lifecycle. Marker traits. | Declared for small scalar-like types; `RegisterPassable` types cannot define move initializers (they move by register copy). Conditional `RegisterPassable` conformance for `Tuple`/`Optional`/`Variant` arrived in the 1.0 cycle. |
| `Intable`, `Floatable`, … | Conversion traits (`Int(x)`, `Float64(x)`). | Seen in bounds such as `[T: Intable]`. |

Reading a stdlib “Implemented traits” list is now mechanical. `DType`, for example, is documented as implementing `AnyType`, `Copyable`, `Equatable`, `Hashable`, `ImplicitlyCopyable`, `Movable`, `RegisterPassable`, `Representable`, `Stringable`, `Writable`, and friends — i.e. it is a trivially copyable, movable, printable scalar descriptor, exactly the profile §6's table predicts.

Three interactions matter most in day-to-day generic code:

1. **Bounds compose with `&`.** Real signatures stack these traits: `struct Sound[T: Writable & Copyable & Deinitable]`, `def write_all[*Ts: Movable](mut writer: Some[Writer], *args: *Ts)`. As of 1.0 the compiler even warns when a composition is redundant (`Copyable` already implies `AnyType`).
2. **Conformance is conditional in the library itself.** `Optional`, `Tuple`, `Variant`, `Span`, and `Array` conform to `Copyable`, `Hashable`, `Defaultable`, `Writable`, etc. *exactly when their element types do* — the §2.6 mechanism, not special-casing.
3. **Destruction is part of the contract.** A parameterized struct whose parameter lacks `Deinitable` cannot itself be implicitly destroyed: the reference's `Box[T: Copyable]` example fails with “the 'box' being abandoned without being destroyed” until the bound becomes `T: Copyable & Deinitable`. When a bound feels oddly insistent about `Deinitable`, this is why.

---

## Version-sensitive summary

| Older form | Current form (1.1.0) | Changed in |
|---|---|---|
| `fn` (all methods) | `def` | deprecated 1.0.0b1, **removed 1.1** |
| `alias X = ...` | `comptime X = ...` | replaced in 1.0 cycle, `alias` **removed 1.1** |
| `@parameter if` / `@parameter for` | `comptime if` / `comptime for` | **removed 1.1** |
| `@parameter` decorator (closures) | `@__parameter`, legacy closures only | renamed 1.1 |
| `__del__(owned self)` | `__deinit__(deinit self)` | renamed 1.0 (old spelling deprecated) |
| `ImplicitlyDestructible` | `Deinitable` | renamed 1.0, alias **removed 1.1** |
| `read` argument convention | `imm` | renamed 1.0, error 1.1 |
| `struct_field_*()`, `get_type_name()` reflection functions | `reflect[T]` unified API in `std.reflection` | 1.0.0b1; old functions `@deprecated` |
| Structs movable only on request | Structs `Movable` by default (`Movable where …` to narrow) | 1.0 |
| `where` inside `[...]` | trailing `where` clause only | removed 1.0 |
| `size` naming (`SIMD.size`, …) | `length` naming | renamed 1.0, aliases removed 1.1 |
| `InlineArray` / `StringSlice` | `Array` / `StringSpan` | renamed 1.0, aliases removed 1.1 |

## Sources

All URLs below were read during the research session for this file (official Modular / Mojo documentation and release notes).

- https://docs.modular.com/mojo/manual/traits
- https://mojolang.org/docs/reference/struct-declarations/
- https://mojolang.org/docs/reference/trait-declarations/
- https://mojolang.org/docs/reference/function-declarations/
- https://mojolang.org/docs/reference/simple-statements/
- https://mojolang.org/docs/reference/compound-statements/
- https://mojolang.org/docs/reference/expressions/
- https://mojolang.org/docs/reference/keywords/
- https://mojolang.org/docs/reference/literals/
- https://mojolang.org/docs/manual/quickstart/
- https://mojolang.org/releases/v1.0.0/
- https://mojolang.org/releases/v1.0.0b1/
- https://mojolang.org/releases/v1.1.0/
- https://docs.modular.com/mojo/manual/decorators/fieldwise-init/ (via official search excerpt)
- https://mojolang.org/docs/manual/get-started/ (via official search excerpt)
- https://mojolang.org/docs/manual/lifecycle/life/ (via official search excerpt)
- https://docs.modular.com/mojo/stdlib/builtin/dtype/DType/ (via official search excerpt — “Implemented traits” list)
