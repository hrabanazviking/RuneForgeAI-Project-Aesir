# Mojo Ownership and Memory

*Study notes reflecting the Mojo Manual and standard library reference as documented for Mojo 1.1.0 (latest stable release, 17 September 2026, per the releases page). Nightly at time of writing was 1.2.0.dev2026101405. Everything below is version-sensitive: Mojo renamed its ownership vocabulary more than once on the road to 1.0, and §9 collects the rename history so old code and old blog posts can be translated.*

## 1. The problem ownership solves

Mojo has no garbage collector and, in safe code, no manual `free`. Instead it borrows the ownership discipline familiar from Rust and modern C++ and states it as three rules (Manual, *Ownership*):

- Every value has only one owner at a time.
- When the lifetime of the owner ends, Mojo destroys the value.
- If there are existing references to a value, Mojo extends the lifetime of the owner.

A variable *owns* its value; a struct owns its fields. A *reference* is access to a value owned by someone else, and it is either mutable or immutable. When the owner dies, the compiler calls the value's deinitializer — promptly, not at some later collection cycle — and that deinitializer is responsible for releasing whatever the value holds (heap buffers, file handles, and so on). The type author writes the deinitializer; the ownership system guarantees it is called exactly once, at the right time. That is how Mojo claims freedom from use-after-free, double-free, and leaks without a GC and, in safe code, without the programmer tracking frees by hand.

Underneath, values live where values always live: fixed-size locals on the stack (or in registers), dynamically-sized data on the heap behind a fixed-size handle. A `String` variable, for example, is a small stack struct containing a pointer to a heap buffer. Ownership is about who is responsible for that buffer, not about where the bytes sit.

## 2. Value semantics first

Mojo's default posture is *value semantics*: each variable has unique access to its value, and code outside that variable's scope cannot change it. Assignment of a value-semantic type makes an independent value:

```mojo
def main():
    var x = 1
    var y = x   # copy: y is its own value
    y += 1
    print("x:", x)  # x: 1
    print("y:", y)  # y: 2
```

The Manual is careful to say Mojo does not *enforce* value semantics for every type: each type defines how it is created, copied, and moved (if at all), and a type may implement reference semantics or a mixture. What Mojo does enforce is the ownership scaffolding around whatever semantics a type chooses — one owner, tracked references, deterministic destruction — so that reference semantics can be introduced "in a way that does not disturb the predictability and safety of value semantics."

Two consequences follow for everyday code:

1. **Function arguments look value-semantic by default.** A callee receives an immutable reference (see §3), so it cannot change the caller's variable. If it wants a local mutable value, it copies explicitly: `var z = y`.
2. **Copies are explicit for expensive types.** `List` and `Dict` are value-semantic, but `Dict` is not implicitly copyable: `var dict2 = dict1` is an error, and you must write `dict1.copy()`. `List` spells the deep copy the same way. Move-only types cannot be copied at all.

## 3. Argument conventions: the current spellings

An *argument convention* is a keyword before an argument name that says whether the argument is mutable, and whether the function owns it. This table is the current (1.1.0) Manual, *Ownership*, verbatim in substance:

| Spelling | Meaning |
|---|---|
| *(default — no keyword)* | Immutable reference. The function can read the original value; it is *not* a copy, and it cannot be mutated. |
| `mut` | Mutable reference. The function can read and mutate the original value; not a copy. |
| `var` | The function takes **ownership** of a value. The callee has exclusive ownership; exactly how the value arrives (transfer, copy, or fresh temporary) is §5. |
| `ref` | A reference with *parametric mutability*: it follows the mutability of the referenced value. Advanced; tied to origins, §6. |
| `out` | Uninitialized on entry, must be initialized before return. Used for `self` in initializers and for named results; never passed by the caller. |
| `deinit` | Initialized on entry, uninitialized on return. Used for the deinitializer and consuming lifecycle methods; the argument is tagged for destruction. |

```mojo
def add(mut x: Int, y: Int):
    x += y          # x is a mutable reference; y is read-only

def main():
    var a = 1
    var b = 2
    add(a, b)
    print(a)  # 3
```

Notes that matter:

- **The default is a reference, not a copy** — but it behaves value-semantically because it is immutable. For large values this avoids invoking the copy initializer and deinitializer entirely. Small register-passable values such as `Int`, `Float`, and `SIMD` are passed in machine registers regardless.
- **`self` takes conventions too.** Read-only methods use plain `self`, mutating methods use `mut self`, initializers use `out self`, deinitializers and consuming methods use `deinit self`.
- **The reference "How to read the API docs" cheat sheet names the default convention `read`** and lists the three common conventions as `read` (default), `mut`, and `owned`. Treat that page with care: in the Manual's normative text the default has *no keyword at all*, ownership is spelled `var`, and `owned` survives as descriptive prose ("the callee receives ownership") rather than as the current keyword. When you see `read`/`owned` in signatures, translate: `read` = default, `owned` = `var`. See §9.

### 3.1 Argument exclusivity

A mutable reference must be *exclusive*: if a function receives a value as `mut`, it may not receive any other reference — mutable or immutable — to the same value in the same call.

```mojo
def append_twice(mut s: String, other: String):
    s += other
    s += other

def invalid_access():
    var my_string = "o"
    # error: my_string passed both mut and as an immutable reference
    append_twice(my_string, my_string)
```

The Manual's motivation is partly correctness (with aliasing, the example above would produce `oooo`, not the `ooo` a reader expects) and partly optimization: exclusivity is a no-alias guarantee the compiler can exploit. The documented workaround is to copy: `var other_string = my_string` and pass the copy as the second argument. Exclusivity is *not* enforced for register-passable trivial types such as `Int` and `Bool`, which are always passed by copy — passing the same `Int` twice simply gives the callee two copies.


## 4. Copies vs moves: the lifecycle initializers

Whether assignment copies or moves is a property of the *type*, expressed through traits and two special initializers documented in *Creating values*:

```mojo
# Copy initializer — required by the Copyable trait
def __init__(out self, *, copy: Self):
    ...

# Move initializer — deinit move: the source is consumed
def __init__(out self, *, deinit move: Self):
    ...
```

- `Copyable` provides the `copy()` method; `value.copy()` is `ValueType(copy=value)`. Where possible Mojo synthesizes the copy initializer for you. All `Copyable` types are also `Movable`.
- `ImplicitlyCopyable` refines `Copyable` and lets the compiler insert copies silently. The Manual warns that implicit copying can hide expensive work and advises preferring an explicit `.copy()` when a copy may allocate.
- `Movable` provides the move initializer; `value^` is `ValueType(move=value^)`. Mojo synthesizes a move initializer for ordinary structs even when you declare nothing.
- A type that is `Movable` but not `Copyable` is **move-only** — e.g. `OwnedPointer` and `Atomic`. A type conforming to neither (declare `Movable where False`, or hold a non-movable field) is **immovable/pinned**, for values whose address is their identity.

At the expression level the distinction is visible in one character:

```mojo
var the_copy = value.copy()  # value still usable afterwards
var the_move = value^        # value's lifetime ends here
```

## 5. Ownership transfer: `var` and the `^` sigil

Declaring an argument `var` guarantees the callee *unique, mutable, owned* access — but not that it receives the caller's original object. The Manual lists exactly three ways a `var` argument gets its value:

1. **Value transfer.** The caller writes the postfix transfer sigil: `take_text(message^)`. Ownership moves; the caller's variable is left *uninitialized*, and using it is a compile error (`error: use of uninitialized value 'message'`) until it is assigned a fresh value.
2. **Copying.** Without `^`, Mojo copies the value into the argument. If the type is not `Copyable`, this is a compile-time error.
3. **Newly created value.** A temporary (a literal, a function result) has no owner yet, so ownership passes straight to the callee: `take("A brand-new String!")`.

```mojo
def take_text(var text: String):
    text += "!"
    print(text)

def main():
    var message = "Hello"
    take_text(message)     # copies: prints Hello! …
    print(message)         # … and message still prints Hello
    take_text(message^)    # transfers: message is now uninitialized
    # print(message)       # error: use of uninitialized value
```

Inside the callee, a `var` value lives and dies like any local: it is destroyed when the function exits *unless* the function transfers it onward. The Manual's pair of examples makes the point — `add_to_list(var name: String, mut list: List[String])` does `list.append(name^)`, so nothing remains to destroy; `consume_string(var s: String)` merely prints, so `s` is destroyed at the closing brace.

**Transfer ≠ move operation.** The Manual explicitly warns not to conflate ownership transfer with a move: if the type has a move initializer (`__init__(*, deinit move:)` in current spelling), Mojo *may* invoke it when a value transfers into a `var` argument at the end of the source variable's lifetime — but it may also optimize the move away entirely, leaving the value in place and just reassigning ownership on paper. And the no-sigil path only works because the type is copyable via `__init__(out self, *, copy: Self)`.

## 6. Lifetimes, origins, and reference safety

The **lifetime checker** is a compiler pass that analyzes dataflow, decides when each variable is valid, and inserts deinitializer calls where lifetimes end. Its bookkeeping device is the **origin**: a compile-time value answering two questions about a reference — *what variable owns this value?* and *can it be mutated through this reference?* Origins are symbolic (they track variables, not addresses) and are normally inferred; you meet them directly only with `ref` arguments/returns and with origin-parameterized types such as `Pointer` and `Span`.

Origin vocabulary in the current Manual:

- `ImmOrigin` / `MutOrigin` — immutable / mutable origin types; `Origin[mut=is_mutable]` for parametric mutability.
- `origin_of(x)` — a compile-time operator returning the origin of a value (or, with several arguments, the *union* of their origins). Its argument expressions are never evaluated. `ref[origin_of(self)]` and the shorthand `ref[self]` are equivalent.
- `ImmStaticOrigin` — the origin of values that live for the whole program; string literals have it.
- `MutUntrackedOrigin` / `ImmUntrackedOrigin` — memory no variable owns and the checker does not track, e.g. fresh `alloc()` memory. Using it means managing the lifetime yourself.
- `ImmUnsafeAnyOrigin` / `MutUnsafeAnyOrigin` — wildcard origins: "may access any live value." A live wildcard pointer disables ASAP destruction and argument-exclusivity enforcement in its scope; the Manual says use them only as a last resort.

### 6.1 `ref` arguments and `ref` returns

`ref` is how a function works with a reference whose mutability is decided by the caller:

```mojo
def add_ref(ref a: Int, b: Int) -> Int:
    return a + b
```

With an explicit origin you can bind a result's lifetime to an argument's — the pattern behind non-owning views like `Span`:

```mojo
from std.collections import List, Span

def to_byte_span[
    is_mutable: Bool,
    //,
    origin: Origin[mut=is_mutable],
](ref[origin] list: List[Byte]) -> Span[Byte, origin]:
    return Span(list)
```

A `ref` *return* value must name its origin: `-> ref[origin_specifiers] Type`. This is how `__getitem__` returns a true reference into a collection instead of a copy, with parametric mutability doing the work of two overloads:

```mojo
def __getitem__(ref self, index: Int) raises -> ref[self] String:
    ...
```

If two inputs could be the source, the origin is their union — `def pick_one(cond: Bool, ref a: String, ref b: String) -> ref[a, b] String:` — which extends *both* lifetimes for as long as the result is live, and is mutable only if both inputs are.

Finally, capturing a returned reference requires a **reference binding**; plain assignment copies:

```mojo
var name_copy = list[2]   # owned copy of the element
ref name_ref = list[2]    # reference: name_ref += "?" changes list[2]
```

## 7. Destruction: `__deinit__`, ASAP, and explicit destruction

The current documented destructor spelling is **`__deinit__`**, taking `deinit self`:

```mojo
def __deinit__(deinit self):
    # value and fields are still valid here; on return the
    # instance is logically deinitialized
    ...
```

Mojo generates a `__deinit__` for every struct with deinitializable fields; you write one when cleanup is more than "destroy my fields" — freeing manual allocations, closing files. Inside a deinitializer (and only there) you may move values *out of* fields without reinitializing them, e.g. `var name = self.name^`, because the compiler knows the instance is finished. Don't call `__deinit__` directly in ordinary code.

**ASAP destruction.** Mojo destroys each value *as soon as possible* — immediately after its last use, mid-expression if necessary, not at end of block or end of statement. In `a + (b - c) * d`, temporaries die in evaluation order as their last uses complete. Every value is initialized once and deinitialized once.

**Lifetime extension.** Where something outside ordinary uses must keep a value alive (an RAII guard, a pointer whose origin was erased), assign it to the discard pattern at the point where it may die: `_ = t`. That statement *is* the last use, and the deinitializer runs right after it.

**Explicit destruction.** A type can opt out of automatic destruction with an unsatisfiable conformance, `Deinitable where False` (optionally with a message: `Deinitable where (False, "call 'cleanup()'")`). Its values must then be consumed by a named deinitializer — any method taking `deinit self`, invoked as `value^.cleanup()` — or transferred out; otherwise the compiler errors. Unlike `__deinit__` (which can never raise — the compiler rejects `raises` on it), a named deinitializer *can* raise, which is the point: use explicit destruction when cleanup can fail, has several paths (`commit()` / `rollback()`), is order-sensitive, or is expensive enough to demand deliberation. `Allocation` (§8) is the standard library's working example.


## 8. Pointers

All pointer types are parameterized on the pointee type. Dereferencing any of them is `ptr[]`.

### 8.1 `Pointer` — the primary pointer

```mojo
struct Pointer[
    mut: Bool,
    //,
    T: AnyType,
    origin: Origin[mut=mut],
    *,
    address_space: AddressSpace = .GENERIC,
]
```

`Pointer` refers to one or more contiguous values and may refer to uninitialized memory. Its split personality is the whole design:

- **Safe when pointing at an existing value.** `var ptr = Pointer(to=count)` keeps the ownership linkage to `count`, so the checker tracks it; `ptr[] = 100` just mutates `count`. Creating such a pointer and dereferencing it are safe operations.
- **Unsafe for dynamic memory.** Everything involving allocated or uninitialized memory is named `unsafe_…` (or takes an `unsafe_…` keyword), and *you* track allocation, initialization state, and pointee destruction.

`Pointer` is non-nullable by design — model null with `Optional[Pointer[...]]`, which reuses the null address as its `None` niche at zero overhead — and it does not own the memory it points to. It is implicitly copyable, and copying a pointer copies the address, not the pointee.

The heap workflow goes through `Allocation`, an explicitly-destroyed handle:

```mojo
from std.memory import Pointer
from std.memory.alloc import alloc, dealloc, Layout

var allocation = alloc(Layout[Int](count=4))
var ptr = allocation.unsafe_ptr()

for i in range(4):
    ptr.unsafe_offset(i).unsafe_write(i)   # initialize each slot

ptr[unsafe_offset=2] = 30                  # now initialized: dereference is fine
print(ptr[unsafe_offset=2])                # 30

dealloc(allocation^)                       # frees memory; ptr is now dangling
```

Key `Pointer` APIs as documented:

- `unsafe_write(value^)` moves a value into uninitialized memory; `unsafe_write(copy=value)` copies instead. Never initialize via `ptr[] = …` — assignment runs lifecycle methods on whatever garbage is already there, which is undefined behavior.
- `unsafe_offset(i)` returns a new pointer `i` elements away (negative allowed), no bounds checking; `ptr[unsafe_offset=i]` is the fused dereference form.
- `unsafe_take_pointee()` moves the pointee out, leaving the slot uninitialized; `unsafe_deinit_pointee()` runs its deinitializer, likewise leaving it uninitialized. Both are undefined behavior on uninitialized or null memory.
- `unsafe_load()` / `unsafe_store()` move `SIMD[dtype, width]` values through `Pointer[Scalar[dtype]]`, with optional `alignment`, `volatile`, and `non_temporal` parameters.
- `dealloc(allocation^)` frees the block but does **not** deinitialize pointees — do that first. Consuming the `Allocation` makes double-free a compile-time non-issue; the escape is `Allocation.unsafe_leak()`, which hands you the raw pointer and the responsibility. Allocation failure aborts the program; it cannot be caught.
- `ThinAllocation` is the layout-free variant for struct fields: convert with `alloc(...).into_thin()`, rebuild with `unsafe_with_layout(...)` to deallocate. `Pointer.unsafe_dangling()` gives an aligned non-null placeholder for lazy initialization; `OpaquePointer` is an alias for `Pointer[NoneType]`, the `void*` of FFI, castable with `unsafe_bitcast`.

A pointer's states, per the Manual, are exactly four: uninitialized variable; pointing to allocated-but-uninitialized memory; pointing to initialized memory; and *dangling* after `dealloc` — dereferencing a dangling pointer is undefined behavior.

### 8.2 `OwnedPointer` — single-owner smart pointer

```mojo
from std.memory import OwnedPointer

var o_ptr = OwnedPointer(some_big_struct^)
```

`OwnedPointer[T]` allocates on construction, moves or copies the value in, and owns it exclusively: the pointer itself is movable but **not copyable** (a separate initializer can build a second `OwnedPointer` by copying the *pointee*). Documented methods include `__deinit__(deinit self)`, `__getitem__(ref self) -> ref[…] T`, `take(deinit self) -> T` (move the value out, consuming the pointer), `steal_data(deinit self) -> UnsafePointer[T, MutUntrackedOrigin]`, and `unsafe_ptr(...) -> UnsafePointer[T, origin]` for the backing pointer.

### 8.3 `ArcPointer` — shared ownership

```mojo
from std.memory import ArcPointer

var attributes = ArcPointer(attributesDict^)
```

`ArcPointer` is the reference-counted smart pointer: freely copyable, every copy bumps the count, every destruction decrements it, and at zero the value is destroyed and freed. The count itself is thread-safe; accesses to the stored value are not — callers synchronize. It is the standard building block for reference-semantic types: a struct holding an `ArcPointer[Dict[String, String]]` can be `ImplicitlyCopyable` while all copies share one dictionary.

### 8.4 `UnsafePointer` — a deprecated alias, not a separate type

This is the single most version-sensitive fact in this file. In 1.1.0, `std.memory.unsafe_pointer` "defines `UnsafePointer` as a backward-compatible name for `Pointer`":

```mojo
comptime UnsafePointer[mut: Bool, //, T: AnyType, origin: Origin[mut=mut], *,
    address_space: AddressSpace = .GENERIC] = Pointer[T, origin, address_space=address_space]
# Deprecated: 'UnsafePointer' is deprecated, use 'Pointer' instead
```

The two historical pointer types were unified; new code should write `Pointer`. `LegacyUnsafePointer` still exists in the reference as a deprecated predecessor of `UnsafePointer`, kept for backwards compatibility with implicit conversions both ways, and slated for removal.

Summary table (Manual, *Intro to pointers*):

|  | `Pointer` | `OwnedPointer` | `ArcPointer` |
|---|---|---|---|
| Safe | Conditionally (`unsafe_` APIs excluded) | Yes | Yes |
| Allocation | Manual via `alloc()` | Implicit | Implicit |
| Owns pointee | No | Yes | Yes |
| Implicitly copyable | Yes | No | Yes |
| Nullable | No | No | No |
| Uninitialized memory | Yes | No | No |
| Multiple values | Yes | No | No |

## 9. Rename history — read old Mojo with this table

Mojo's pre-1.0 vocabulary appears in years of blog posts, forum answers, and the Modular team's own deep-dive articles. The current Manual and lifecycle pages support these translations:

| Historical (pre-1.0 / early) | Current (1.1.0 docs) | Notes |
|---|---|---|
| `borrowed x: T` (the old default) | *(no keyword)* `x: T` | Immutable reference. The API-reading cheat sheet also calls this convention `read`. |
| `inout x: T` | `mut x: T` | Mutable reference. |
| `owned x: T` | `var x: T` | Ownership-taking argument. `owned` still appears in prose and in the cheat sheet's convention list. |
| `owned self` in destructors/consumers | `deinit self` | The `deinit` convention replaced `owned` for `__deinit__` and consuming methods; it also generalizes to any argument (`deinit other: Self`). |
| `__del__(owned self)` | `__deinit__(deinit self)` | The destructor itself was renamed. Older reference crawls still show `__del__(deinit self)`; the 1.1.0 lifecycle pages uniformly document `__deinit__`. |
| `__copyinit__(out self, existing: Self)` | `__init__(out self, *, copy: Self)` | Copying is now an ordinary initializer overload keyed by `copy:`. |
| `__moveinit__(out self, owned/deinit existing: Self)` | `__init__(out self, *, deinit move: Self)` | Moving likewise, keyed by `move:` with a `deinit` parameter. |
| `UnsafePointer[T]` with `.alloc()`, `.init_pointee()`, `.destroy_pointee()`, `.free()` | `Pointer[T, origin]` + `alloc(Layout[…])` / `unsafe_write()` / `unsafe_deinit_pointee()` / `dealloc(allocation^)` | `UnsafePointer` is now a deprecated alias of `Pointer` (§8.4); the old `Pointer`/`UnsafePointer` pair was unified, and allocation moved to the `Allocation` API in `std.memory.alloc`. |
| `MutAnyOrigin` / `ImmutAnyOrigin`, `MutExternalOrigin` | `MutUnsafeAnyOrigin` / `ImmUnsafeAnyOrigin`, `MutUntrackedOrigin` / `ImmUntrackedOrigin` | Origin constants were renamed alongside the pointer unification (older lifetime pages show the old names). |
| `^` required when discarding a move-only value | No longer required | Noted in *Automatic destruction*: the compiler does not move a discarded value. |

Anything in the wild using the left-hand column should be read as history, not as current Mojo.

## 10. What is guaranteed, and where the exits are

In safe code — no `unsafe_` calls, no wildcard origins — the documented guarantees are: one owner per value; no destruction while references are live (lifetimes are extended); exclusive mutable references; deterministic, exactly-once destruction at last use; and non-nullable pointers. There is no garbage collector and no runtime borrow checker: all of it is compile-time dataflow analysis.

The escape hatches are equally explicit, and they are all spelled `unsafe`:

- `Pointer`'s `unsafe_` surface (§8.1): raw allocation, uninitialized memory, manual pointee lifetimes, unchecked offsets and loads/stores, bitcasts, and pointers built `unsafe_from_address=…`. Mistakes here are undefined behavior, by documentation, not by accident.
- Untracked and wildcard origins, which remove memory from the checker's view (wildcards additionally suspend ASAP destruction and exclusivity in scope — discouraged, last resort).
- `unsafe_leak()`, `steal_data()`, `unsafe_take_allocation()` and friends, which trade the double-free protection of consuming handles for raw responsibility.
- Explicitly-destroyed types, where forgetting the named deinitializer is at least a *compile* error — the one escape hatch that keeps a guardrail.

The pattern to internalize: Mojo's safety is the default you get for free, and every step away from it is labeled at the call site.

## Sources

- https://docs.modular.com/mojo/manual
- https://docs.modular.com/mojo/manual/values
- https://docs.modular.com/mojo/manual/values/value-semantics
- https://docs.modular.com/mojo/manual/values/ownership
- https://docs.modular.com/mojo/manual/values/lifetimes
- https://docs.modular.com/mojo/manual/lifecycle
- https://mojolang.org/docs/manual/lifecycle/life/
- https://mojolang.org/docs/manual/lifecycle/death/
- https://mojolang.org/docs/manual/lifecycle/explicit-destroy/
- https://docs.modular.com/mojo/manual/pointers
- https://docs.modular.com/mojo/manual/pointers/using-pointers
- https://docs.modular.com/mojo/std/memory
- https://mojolang.org/docs/std/memory/unsafe_pointer/
- https://docs.modular.com/mojo/std/memory/pointer/Pointer
- https://docs.modular.com/mojo/std/memory/owned_pointer/OwnedPointer/
- https://docs.modular.com/mojo/std/memory/legacy_unsafe_pointer/LegacyUnsafePointer/
- https://mojolang.org/releases/
