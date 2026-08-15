# Mojo Programming Language — Complete Command and Function Reference Guide
## Version 0.26.2 (Stable Release)

(Mojo_Command_and_Function_Reference_Guide-Aug-15-2026.md)

---

# Table of Contents

1. [Introduction](#1-introduction)
2. [Mojo CLI Commands](#2-mojo-cli-commands)
3. [Language Fundamentals](#3-language-fundamentals)
4. [Type System](#4-type-system)
5. [Functions](#5-functions)
6. [Structs](#6-structs)
7. [Traits](#7-traits)
8. [Standard Library Overview](#8-standard-library-overview)
9. [Memory Management](#9-memory-management)
10. [Compile-Time Metaprogramming](#10-compile-time-metaprogramming)
11. [Concurrency and Parallelism](#11-concurrency-and-parallelism)
12. [GPU Programming](#12-gpu-programming)
13. [Python Interoperability](#13-python-interoperability)
14. [Foreign Function Interface (FFI)](#14-foreign-function-interface-ffi)
15. [Built-in Functions](#15-built-in-functions)
16. [Keywords Reference](#16-keywords-reference)
17. [Operators Reference](#17-operators-reference)
18. [Error Handling](#18-error-handling)
19. [Modules and Packages](#19-modules-and-packages)
20. [Decorators and Attributes](#20-decorators-and-attributes)
21. [Compilation Targets](#21-compilation-targets)
22. [Debugging and Profiling](#22-debugging-and-profiling)
23. [Performance Optimization](#23-performance-optimization)
24. [Version History and Migration](#24-version-history-and-migration)
25. [Glossary](#25-glossary)

---

# 1. Introduction

Mojo is a systems programming language specifically designed for high-performance AI infrastructure and heterogeneous hardware. It combines Python's syntactic simplicity with the performance characteristics of systems languages like C++ and Rust. Mojo is built from the ground up using MLIR (Multi-Level Intermediate Representation)—a modern compiler infrastructure for heterogeneous hardware, spanning CPUs, GPUs, and AI ASICs.

## 1.1 Key Design Principles

- **Pythonic Syntax**: Mojo adopts and extends Python's syntax, making it accessible to Python programmers
- **Struct-Based Types**: All data types—including basic types such as `String` and `Int`—are defined as structs. No types are built into the language itself
- **Zero-Cost Traits**: Mojo's trait system provides compile-time type checking with no runtime performance cost
- **Value Semantics**: Mojo defaults to value semantics, preventing unexpected data sharing
- **Ownership System**: Ensures only one variable "owns" a specific value at any given time, providing memory safety without garbage collection overhead
- **Compile-Time Metaprogramming**: Powerful parameterization system enables metaprogramming

## 1.2 Version Information

The current stable release is **Mojo v0.26.2**, published on March 19, 2026. To check your installed version, run:

```bash
mojo --version
```

---

# 2. Mojo CLI Commands

The Mojo CLI provides all the tools necessary for Mojo development, including commands to run, compile, precompile, and debug Mojo code.

## 2.1 Core Commands

### `mojo run`

Builds and executes a Mojo file.

**Syntax:**
```bash
mojo run [options] <file.mojo> [arguments...]
```

**Options:**
| Option | Description |
|--------|-------------|
| `--target` | Specify compilation target |
| `--debug` | Include debug information |
| `--release` | Build with optimizations |
| `--O0` through `--O3` | Optimization level |

**Example:**
```bash
mojo run hello.mojo
mojo run --release --target=host benchmark.mojo
```

### `mojo build`

Builds an executable from a Mojo file.

**Syntax:**
```bash
mojo build [options] <file.mojo> [-o <output>]
```

**Options:**
| Option | Description |
|--------|-------------|
| `-o, --output` | Output file name |
| `--target` | Specify compilation target |
| `--debug` | Include debug symbols |
| `--release` | Optimized build |
| `--print-effective-target` | Display the effective target configuration |
| `--experimental-fixit` | Assist with code migration (e.g., deprecated implicit conversions) |

**Example:**
```bash
mojo build program.mojo -o program
mojo build --release --target=cpu program.mojo
```

### `mojo repl`

Launches the Mojo REPL (Read-Eval-Print Loop).

**Syntax:**
```bash
mojo repl [options]
```

**Options:**
| Option | Description |
|--------|-------------|
| `--quiet` | Suppress banner information |
| `--no-histfile` | Disable history file |

**Example:**
```bash
mojo repl
>>> print("Hello, Mojo!")
Hello, Mojo!
>>> 2 + 2
4
```

### `mojo debug`

Launches the Mojo debugger using the command-line interface or an external editor.

**Syntax:**
```bash
mojo debug [options] <file.mojo>
```

**Options:**
| Option | Description |
|--------|-------------|
| `--editor` | Specify external editor |
| `--breakpoint` | Set initial breakpoint |

### `mojo precompile`

Precompiles a Mojo package.

**Syntax:**
```bash
mojo precompile [options] <package>
```

### `mojo format`

Formats Mojo source files according to the standard style.

**Syntax:**
```bash
mojo format [options] <files...>
```

**Options:**
| Option | Description |
|--------|-------------|
| `--check` | Check formatting without modifying |
| `--in-place` | Modify files in place |

### `mojo package`

Compiles a Mojo package.

**Syntax:**
```bash
mojo package [options] <package>
```

## 2.2 Package Management Commands

### `mojo init`

Creates a new Mojo project with default configuration.

**Syntax:**
```bash
mojo init [project-name]
```

Creates `.mojo/config.json` and `.mojo/memory.md` defaults without overwriting existing files.

## 2.3 Global Options

| Option | Description |
|--------|-------------|
| `--version` | Print version information |
| `--help` | Display help information |
| `--verbose` | Enable verbose output |

## 2.4 Environment Variables

| Variable | Description |
|----------|-------------|
| `MOJO_PATH` | Additional search paths for Mojo modules |
| `MOJO_TARGET` | Default compilation target |
| `MOJO_DEBUG` | Enable debug mode |

---

# 3. Language Fundamentals

## 3.1 Lexical Elements

### Identifiers

Identifiers must be valid Python-style names: starting with a letter or underscore, followed by letters, digits, or underscores. Mojo identifiers follow Python's PEP 570 conventions.

```mojo
valid_name
_valid_name
name123
_name_with_underscores
```

### Comments

```mojo
# Single-line comment

"""
Multi-line comment
or docstring
"""
```

### Indentation

Mojo uses indentation to define code blocks, following Python's conventions. Consistent indentation (spaces or tabs, but not mixed) is required.

## 3.2 Variables and Mutability

Mojo variables are declared using the `let` or `var` keywords:

- `let` — Declares an **immutable** variable (value cannot be reassigned)
- `var` — Declares a **mutable** variable (value can be reassigned)

```mojo
let x: Int = 10      # Immutable - cannot be reassigned
var y: Int = 20      # Mutable - can be reassigned
y = 30               # Valid

# Type inference
let a = 42           # Inferred as Int
var b = "hello"      # Inferred as String

# Explicit type annotation
let c: Float64 = 3.14
```

## 3.3 Control Flow

### `if`/`elif`/`else` Statements

```mojo
if condition:
    # code
elif other_condition:
    # code
else:
    # code
```

### `for` Loops

```mojo
for i in range(10):
    print(i)

for item in collection:
    process(item)
```

### `while` Loops

```mojo
while condition:
    # code
    if exit_condition:
        break
```

### `break` and `continue`

- `break` — Exits the innermost loop
- `continue` — Skips to the next iteration

### `pass` Statement

The `pass` statement is a no-operation placeholder:

```mojo
def placeholder_function():
    pass
```

### `assert` Statement

Mojo supports a standalone `assert` statement, similar to Python's `assert`. It checks a condition at runtime and aborts if the condition is false, with an optional message:

```mojo
assert x > 0
assert x > 0, "x must be positive"
```

Under the hood, `assert` desugars to `debug_assert()` and respects the `-D ASSERT` flag.

## 3.4 Ternary Conditional Expression

Mojo supports the ternary conditional expression:

```mojo
result = value if condition else other_value
```

The ternary if/else expression coerces each element to its contextual type when it is obvious.

## 3.5 Template Strings (T-strings)

Mojo supports template strings with the `t"..."` prefix. T-strings produce a `TString` value that captures both the static format string and runtime arguments, enabling structured string processing without immediate allocation:

```mojo
let name = "World"
let greeting = t"Hello, {name}!"
```

---

# 4. Type System

Mojo is statically typed. Every value has a type that is known at compile time. Built-in types come from the standard library prelude, which the compiler imports into every program.

## 4.1 Numeric Types

Mojo provides built-in numeric types representing signed integers, unsigned integers, and floating-point values.

### Integer Types

| Type | Description | Bit Width |
|------|-------------|-----------|
| `Int` | Signed integer (platform-dependent) | Variable |
| `Int8` | Signed 8-bit integer | 8 |
| `Int16` | Signed 16-bit integer | 16 |
| `Int32` | Signed 32-bit integer | 32 |
| `Int64` | Signed 64-bit integer | 64 |
| `UInt8` | Unsigned 8-bit integer | 8 |
| `UInt16` | Unsigned 16-bit integer | 16 |
| `UInt32` | Unsigned 32-bit integer | 32 |
| `UInt64` | Unsigned 64-bit integer | 64 |

### Floating-Point Types

| Type | Description | Precision |
|------|-------------|-----------|
| `Float16` | 16-bit floating-point | Half |
| `Float32` | 32-bit floating-point | Single |
| `Float64` | 64-bit floating-point | Double |

### `DType`

The `DType` specifies the kind of values stored in a SIMD vector, such as `int`, `uint`, `float32`, `int64`, or `uint8`.

### `Byte`

Mojo provides `Byte` for raw byte data.

### `SIMD` Type

The `SIMD` type represents vector data for SIMD operations:

```mojo
let v: SIMD[Float32, 4] = SIMD[Float32, 4](1.0, 2.0, 3.0, 4.0)
```

### Implicit Conversions (Deprecated)

Implicit conversions from `Int` to `SIMD` scalar types like `Int8` or `Float32` are now deprecated. Code relying on these conversions should use explicit constructors instead.

## 4.2 String Types

| Type | Description |
|------|-------------|
| `String` | Mutable string type |
| `StringRef` | String reference |
| `StringSlice` | String slice |
| `TString` | Template string (captures format string and arguments) |
| `InlineString` | String with small-string optimization, avoids heap allocations for short strings |

## 4.3 Boolean Type

| Type | Description |
|------|-------------|
| `Bool` | Boolean type (true/false) |

## 4.4 Collection Types

Mojo includes a flexible set of collection types:

| Type | Description |
|------|-------------|
| `List` | Dynamic array |
| `Dict` | Dictionary (key-value pairs) |
| `Set` | Set collection |
| `Optional` | Optional value (Some/None) |
| `Deque` | Double-ended queue |
| `InlineArray` | Fixed-size array with inline storage |
| `InlineList` | Inline list |
| `ListLiteral` | List literal type |

## 4.5 Memory Types

| Type | Description |
|------|-------------|
| `Pointer` | Generic pointer type |
| `UnsafePointer` | Unsafe pointer |
| `LegacyPointer` | Legacy pointer type |
| `DTypePointer` | DType-specific pointer |
| `Span` | View over a contiguous sequence |

## 4.6 Other Built-in Types

| Type | Description |
|------|-------------|
| `NoneType` | Type of `None` (replaces empty tuple for constructors using literals) |
| `slice` | Slice type |
| `range` | Range type |

---

# 5. Functions

Mojo uses the `def` keyword to define functions. Functions declared inside a struct are called "methods".

**Important**: The `fn` keyword is deprecated as of Mojo v0.26.2. Use `def` for all function declarations.

## 5.1 Function Declaration Syntax

```mojo
def function_name[parameters](arguments) -> return_type:
    function_body
```

### Anatomy of a Function

1. **Parameters** (optional): Compile-time parameter values used for metaprogramming
2. **Arguments** (optional): Run-time arguments
3. **Return value** (optional): Return type annotation
4. **Function body**: Executed statements

### Minimal Function

```mojo
def do_nothing():
    pass
```

If a function takes no parameters, you can omit the square brackets, but parentheses are always required.

## 5.2 Arguments and Parameters

In Mojo, "parameter" and "parameter expression" refer to compile-time values, while "argument" and "expression" refer to run-time values.

### Arguments (Run-time)

```mojo
def add(a: Int, b: Int) -> Int:
    return a + b
```

### Parameters (Compile-time)

```mojo
def add_tensors[rank: Int](a: MyTensor[rank], b: MyTensor[rank]) -> MyTensor[rank]:
    # rank is a compile-time constant
```

The `rank` value must be determinable at compilation time. The compiler produces a unique version of the function for each unique `rank` value used.

### Positional and Keyword Arguments

Both arguments and parameters can be specified either by position or by keyword:

```mojo
# Positional
x = add(5, 7)

# Keyword
y = add(b=3, a=9)

# Mixed
z = add(5, b=7)    # Positional for a, keyword for b
```

### Return Type

If a function does not return a value, you can either omit the return type or declare `None` as the return type:

```mojo
# Equivalent definitions
def greet(name: String):
    print("Hello,", name)

def greet(name: String) -> None:
    print("Hello,", name)
```

## 5.3 Function Requirements

- You must declare the type of each function parameter and argument
- Function definitions must include a body

## 5.4 Special Methods (Dunder Methods)

Mojo supports special methods (dunder methods) for operator overloading and type behavior:

| Method | Purpose |
|--------|---------|
| `__init__()` | Constructor (unified initialization) |
| `__copyinit__()` | Copy constructor (now keyword-only `copy` argument) |
| `__moveinit__()` | Move constructor (now keyword-only `take` argument) |
| `__del__()` | Destructor |
| `__add__()` | Addition operator |
| `__sub__()` | Subtraction operator |
| `__mul__()` | Multiplication operator |
| `__eq__()` | Equality operator |
| `__contains__()` | Membership test |

**Note**: `__moveinit__()` and `__copyinit__()` are renamed to `__init__()` with keyword-only `take` and `copy` arguments, respectively. Legacy names are still accepted but should be migrated.

## 5.5 Function Effects

### `abi("C")` Effect

Functions can be marked with `abi("C")` to use the platform C ABI (System V x86-64 / ARM64 AAPCS) for struct arguments and return values, enabling safe interop with C libraries:

```mojo
# C-ABI function definition (safe as a callback into C code)
def add(a: Int32, b: Int32) abi("C") -> Int32:
    return a + b

# C-ABI function pointer type
var f = handle.get_function[def(Float64) abi("C") -> Float64]("sqrt")
```

`DLHandle.get_function[]` enforces that the type parameter carries `abi("C")`, preventing silent ABI mismatches.

## 5.6 Closures

Mojo supports closures with unified capturing conventions:

```mojo
def captures_with_default_convention():
    var a, b, c, d = ("a", "b", "c", "d")
    def my_fn() unified {mut a, b, c^, read}:
        # `a` by mutable reference
        # `b` by immutable reference
        # `c` by moving
        # `d` by immutable reference (default 'read' convention)
        use(a, b, c, d)
```

---

# 6. Structs

Structs are Mojo's mechanism for creating custom data types. All data types—including basic types such as `String` and `Int`—are defined as structs.

## 6.1 Struct Declaration

```mojo
struct MyStruct[parameters](fields):
    # struct body
```

## 6.2 Struct Fields

```mojo
struct Point:
    var x: Int
    var y: Int

    def __init__(inout self, x: Int, y: Int):
        self.x = x
        self.y = y
```

## 6.3 Methods

Methods are functions declared inside a struct:

```mojo
struct Rectangle:
    var width: Int
    var height: Int

    def area(self) -> Int:
        return self.width * self.height

    def scale(inout self, factor: Int):
        self.width *= factor
        self.height *= factor
```

## 6.4 Field Alignment

Structs can specify minimum alignment with `@align(N)`, similar to C++ `alignas` and Rust `#[repr(align(N))]`:

```mojo
@align(64)
struct CacheAlignedType:
    var data: SIMD[Float32, 16]
```

The alignment value can be a struct parameter, enabling generic cache-aligned and hardware-aligned types.

## 6.5 Conditional Trait Conformances

Structs can declare trait conformances that apply only when type parameters satisfy certain conditions, using `where` clauses in the conformance list:

```mojo
struct MyContainer[T]:
    # Methods and fields

    # Conditional conformance: only applies when T is Equatable
    where conforms_to(T, Equatable):
        def __eq__(self, other: Self) -> Bool:
            # Implementation
```

Nine standard library types—including `List`, `Dict`, `Set`, and `Optional`—now use this feature to enforce trait requirements at compile time.

---

# 7. Traits

A trait defines requirements that a conforming type must satisfy, including methods, associated types, and constants. Traits are similar to protocols in Swift or interfaces in Java, except with compile-time type checking and no runtime performance cost.

## 7.1 Trait Declaration

Traits are declared with the `trait` keyword followed by the trait name and an optional refinement list:

```mojo
trait MyTrait:
    def required_method(self) -> Int

trait RefinedTrait: MyTrait:
    def additional_method(self) -> String
```

## 7.2 Marker Traits

Mojo marker traits include:

| Trait | Description |
|-------|-------------|
| `AnyType` | The most basic trait that all types extend by default |
| `TrivialRegisterPassable` | Marker for trivial register-passable types |
| `RegisterPassable` | Marker for register-passable types |
| `ImplicitlyCopyable` | Marker for implicitly copyable types |

### `AnyType`

`AnyType` is the foundational trait that defines how objects are created, managed, and destroyed in Mojo.

## 7.3 Core Traits

| Trait | Description |
|-------|-------------|
| `Copyable` | Types that can be copied |
| `Movable` | Types that can be moved |
| `Equatable` | Types that support equality comparison |
| `Sized` | Types that have an integer length (string, array) |
| `SizedRaising` | Types that can raise when computing size |
| `Comparable` | Types that support comparison operations |
| `Hashable` | Types that can be hashed |
| `ImplicitlyDeletable` | Types that can be implicitly deleted |

## 7.4 Using Traits

Traits enable writing functions that depend on a trait rather than individual types:

```mojo
def sort[T: Movable & Comparable](collection: List[T]):
    # Implementation requires T to be Movable and Comparable
```

## 7.5 Generics and Traits

In Mojo, generic functions and structs are parameterized on types. A trait defines a set of shared behaviors for structs. Generic code uses traits to identify the behaviors it requires:

```mojo
def process[T: Copyable](value: T) -> T:
    return value
```

---

# 8. Standard Library Overview

The Mojo standard library provides nearly everything needed for writing Mojo programs, including basic data types, collection types, reusable algorithms, and modules to support GPU programming.

## 8.1 Package List

| Package | Description |
|---------|-------------|
| `algorithm` | High-performance data operations: vectorization, parallelization, reduction, memory |
| `anytype` | Defines the `AnyType` trait |
| `arc` | Reference-counted smart pointers |
| `arg` | Functions and variables for interacting with execution and system environment |
| `atomic` | Atomic operations and memory orderings |
| `base64` | Binary data encoding: base64 and base16 encode/decode functions |
| `benchmark` | Performance benchmarking with statistical analysis and detailed reports |
| `bit` | Bitwise operations: manipulation, counting, rotation, and power-of-two utilities |
| `bool` | Implements the `Bool` class |
| `breakpoint` | Built-in breakpoint function |
| `buffer` | Implements the `Buffer` class |
| `builtin` | Language foundation: built-in types, traits, and fundamental operations |
| `collections` | Core data types: List, Dict, Set, Optional, String, and other collections |
| `compile` | Runtime function compilation and introspection: assembly, IR, linkage, metadata |
| `complex` | Complex numbers: SIMD types, scalar types, and operations |
| `constrained` | Compile-time constraints |
| `coroutine` | Coroutine classes and methods |
| `debug` | Debug hook functions |
| `debug_assert` | Debug assertion implementation |
| `deque` | Double-ended queue type |
| `dict` | Dictionary collection (key-value pairs) |
| `documentation` | Documentation built-ins: decorators and utilities for doc generation |
| `dtype` | Implements the `DType` class |
| `env` | OS environment routines |
| `error` | Implements the `Error` class |
| `ffi` | Foreign function interface for calling C code and loading libraries |
| `file` | File-based methods |
| `format` | Formatting traits for converting types to text |
| `functional` | Higher-order functions |
| `gpu` | GPU programming primitives: thread blocks, async memory, barriers, and sync |
| `hashlib` | Cryptographic and non-cryptographic hashing |
| `io` | Core I/O operations: console input/output, file handling |
| `iter` | Iteration traits and utilities: Iterable, IterableOwned, Iterator |
| `itertools` | Iterator tools |
| `math` | Mathematical utilities and functions |
| `memory` | Memory manipulation functions |
| `os` | Operating system interfaces |

## 8.2 Prelude

The `prelude` package contains the core types, traits, and functions that are automatically imported into every Mojo program. It provides:

- Basic types: `Int`, `String`, `Bool`
- Essential traits: `Copyable`, `Movable`, `Equatable`
- Memory primitives: `Pointer`

---

# 9. Memory Management

Mojo's ownership system ensures that only one variable "owns" a specific value at a given time—such that Mojo can safely deallocate the value when the owner's lifetime ends—while still allowing you to share references to the value.

## 9.1 Ownership and Borrowing

```mojo
let x = create_value()  # x owns the value
let y = x               # Move: x no longer owns the value
# x is no longer valid

let a = create_value()
let b = a^              # Explicit transfer: a no longer owns the value
```

## 9.2 Memory Functions

The `memory` module provides functions for memory manipulations:

| Function | Description |
|----------|-------------|
| `destroy_n` | Destroy `count` initialized values at pointer |
| `forget_deinit` | Forget and deinitialize |
| `memcmp` | Compares two buffers |
| `memcpy` | Copies memory |
| `memmove` | Moves memory |
| `memset` | Fills memory with the given value |
| `is_trivially_copyable` | Checks if a type is trivially copyable |
| `uninit_copy_n` | Copy `count` values from `src` into memory at `dest` |

### `destroy_n`

```mojo
destroy_n(pointer: Pointer[T], count: Int)
```

### `memcmp`

```mojo
memcmp(lhs: Pointer[Byte], rhs: Pointer[Byte], count: Int) -> Int
```

### `memcpy`

```mojo
memcpy(dest: Pointer[Byte], src: Pointer[Byte], count: Int)
```

### `memset`

```mojo
memset(dest: Pointer[Byte], value: UInt8, count: Int)
```

## 9.3 Reference-Counted Smart Pointers (ARC)

The `arc` module provides reference-counted smart pointers:

```mojo
from arc import Arc

let shared = Arc[MyType](my_value)
```

---

# 10. Compile-Time Metaprogramming

Mojo's parameterization system enables powerful metaprogramming.

## 10.1 `comptime` Keyword

The `comptime` keyword identifies a statement or expression that needs to be evaluated at compile time. It is used to declare compile-time constant values and to introduce compile-time conditionals and loops.

## 10.2 `comptime if` and `comptime for`

The new `comptime if` and `comptime for` syntax replaces the legacy `@parameter if` and `@parameter for` decorator forms for compile-time conditionals and loops:

```mojo
comptime if condition:
    # Compile-time conditional code
comptime else:
    # Compile-time else code

comptime for i in range(10):
    # Compile-time loop
```

Both syntaxes are accepted in this release; the `@parameter` forms will be deprecated soon.

## 10.3 Parameterization

```mojo
struct MyGenericType[T: Copyable, size: Int]:
    var data: SIMD[T, size]
```

## 10.4 Type Refinement

Type refinement is based on compile-time assumptions, enabling Mojo to narrow types from `where` clauses, `comptime if` statements, and `comptime assert` statements:

```mojo
def __contains__(self, value: Self.T) -> Bool where conforms_to(Self.T, Equatable):
    for item in self:
        if item == value:  # Type refinement makes this safe
            return True
    return False
```

Refinements in a scope are driven by `conforms_to()` expressions.

## 10.5 `@parameter` Forms (Deprecating)

The legacy `@parameter if` and `@parameter for` decorator forms are being deprecated in favor of `comptime if` and `comptime for`.

---

# 11. Concurrency and Parallelism

## 11.1 Atomic Operations

The `atomic` module implements atomic operations and memory orderings:

```mojo
from atomic import Atomic

var counter = Atomic[Int](0)
counter.fetch_add(1)
```

## 11.2 Coroutines

The `coroutine` module implements classes and methods for coroutines.

## 11.3 Parallel Algorithms

The `algorithm` package provides parallel data operations.

---

# 12. GPU Programming

Mojo includes modules to support GPU programming.

## 12.1 GPU Module

The `gpu` module provides GPU programming primitives:

- Thread blocks
- Asynchronous memory operations
- Barriers
- Synchronization

## 12.2 GPU Kernel Writing

Mojo enables writing high-performance kernels for CPUs and GPUs without using hardware-specific libraries such as CUDA and ROCm.

---

# 13. Python Interoperability

Mojo adopts and extends Python's syntax and integrates with existing Python code. Mojo's interoperability works in both directions: you can import Python libraries into Mojo and create Mojo bindings to call from Python.

## 13.1 Importing Python Modules

```mojo
from python import Python

let np = Python.import_module("numpy")
let arr = np.array([1, 2, 3])
```

## 13.2 Type Conversion

Mojo primitive types implicitly convert into Python objects:

| Mojo Type | Python Type |
|-----------|-------------|
| `Int` | `int` |
| `Float` | `float` |
| `Bool` | `bool` |
| `String` | `str` |

You can explicitly create a wrapped Python object by initializing a `PythonObject` with a Mojo integer, float, boolean, or string.

---

# 14. Foreign Function Interface (FFI)

The `ffi` module implements a foreign function interface for calling C code and loading libraries.

## 14.1 Loading Libraries

```mojo
from ffi import DLHandle

let handle = DLHandle("libm.so")
let sqrt = handle.get_function[def(Float64) abi("C") -> Float64]("sqrt")
let result = sqrt(2.0)
```

## 14.2 C ABI Functions

Functions marked with `abi("C")` use the platform C ABI for safe interop with C libraries.

---

# 15. Built-in Functions

Built-in functions are available in every Mojo program without an import.

## 15.1 Type and Conversion Functions

| Function | Description |
|----------|-------------|
| `int()` | Convert to `Int` |
| `str()` | Convert to `String` |
| `float()` | Convert to floating-point |
| `bool()` | Convert to `Bool` |

## 15.2 String Representation Functions

| Function | Description |
|----------|-------------|
| `bin()` | Return the binary string representation of an integral value |
| `hex()` | Return the hex string representation of an integer |

## 15.3 Length Function

| Function | Description |
|----------|-------------|
| `len()` | Get the length of a string or collection |

## 15.4 Mathematical Functions

From the `math` module:

| Function | Description |
|----------|-------------|
| `abs()` | Get the absolute value |
| `acos()` | Compute arc cosine |
| `acosh()` | Compute inverse hyperbolic cosine |
| `asin()` | Compute arc sine |
| `asinh()` | Compute inverse hyperbolic sine |
| `atan()` | Compute arc tangent |
| `atanh()` | Compute inverse hyperbolic tangent |
| `cbrt()` | Compute cube root |
| `ceil()` | Get ceiling value |
| `comb()` | Compute combinations |
| `copysign()` | Copy sign |
| `cos()` | Compute cosine |
| `erf()` | Compute error function |
| `factorial()` | Compute factorial |
| `ceil_div()` | Ceiling division |
| `floor_div()` | Floor division |

## 15.5 Operating System Functions

From the `os` module:

| Function | Description |
|----------|-------------|
| `abort()` | Terminate execution |
| `chdir()` | Change current working directory |
| `getuid()` | Retrieve user ID of calling process |
| `isatty()` | Check if file descriptor refers to a terminal |
| `link()` | Create a new hard-link to an existing file |
| `listdir()` | List directory contents |
| `makedirs()` | Create directories recursively |
| `mkdir()` | Create a directory |
| `remove()` | Remove a file |
| `removedirs()` | Remove directories recursively |
| `rmdir()` | Remove a directory |
| `unlink()` | Unlink a file |

## 15.6 Breakpoint

| Function | Description |
|----------|-------------|
| `breakpoint()` | Built-in breakpoint function |

---

# 16. Keywords Reference

## 16.1 Reserved Keywords

| Keyword | Description |
|---------|-------------|
| `if` | Conditional execution |
| `elif` | Additional condition in an if chain |
| `else` | Default branch in conditionals or loops |
| `for` | Iteration loop |
| `while` | Conditional loop |
| `break` | Exits the innermost loop |
| `continue` | Skips to next iteration |
| `try` | Begins an error-handling block |
| `finally` | Always-execute clause in a try block |
| `raise` | Raises an error |
| `assert` | Assertion statement |
| `def` | Function declaration |
| `struct` | Struct declaration |
| `trait` | Trait declaration |
| `var` | Mutable variable declaration |
| `let` | Immutable variable declaration |
| `comptime` | Compile-time evaluation |
| `inout` | Mutable reference parameter |
| `self` | Self reference in methods |
| `return` | Return from function |
| `pass` | No-operation placeholder |
| `where` | Trait constraint clause |
| `from` | Import from module |
| `import` | Import module |

## 16.2 Deprecated Keywords

| Keyword | Status |
|---------|--------|
| `fn` | Deprecated as of v0.26.2; use `def` |

---

# 17. Operators Reference

Mojo's operator syntax mirrors Python.

## 17.1 Operator Precedence Table

| Precedence | Operators | Description |
|------------|-----------|-------------|
| 8 | `^` | Bitwise XOR (not transfers) |
| - | `+x`, `-x`, `~x` | Prefix operators |
| - | `*`, `@`, `/`, `//` | Multiplicative operators |

## 17.2 Arithmetic Operators

| Operator | Description |
|----------|-------------|
| `+` | Addition |
| `-` | Subtraction |
| `*` | Multiplication |
| `/` | Division (rounds toward zero for integers) |
| `//` | Floor/truncating division |
| `%` | Modulo |
| `**` | Exponentiation |
| `@` | Matrix multiplication |

## 17.3 Comparison Operators

| Operator | Description |
|----------|-------------|
| `==` | Equality |
| `!=` | Inequality |
| `<` | Less than |
| `<=` | Less than or equal |
| `>` | Greater than |
| `>=` | Greater than or equal |

## 17.4 Boolean Operators

Mojo uses words for boolean operators instead of symbols like `&&` or `||`:

| Operator | Description |
|----------|-------------|
| `and` | Logical AND |
| `or` | Logical OR |
| `not` | Logical NOT |

## 17.5 Bitwise Operators

| Operator | Description |
|----------|-------------|
| `&` | Bitwise AND |
| `|` | Bitwise OR |
| `^` | Bitwise XOR |
| `~` | Bitwise NOT |
| `<<` | Left shift |
| `>>` | Right shift |

## 17.6 Assignment Operators

| Operator | Description |
|----------|-------------|
| `=` | Assignment |
| `+=` | Add and assign |
| `-=` | Subtract and assign |
| `*=` | Multiply and assign |
| `/=` | Divide and assign |
| `//=` | Floor divide and assign |
| `%=` | Modulo and assign |
| `**=` | Power and assign |
| `&=` | Bitwise AND and assign |
| `|=` | Bitwise OR and assign |
| `^=` | Bitwise XOR and assign |
| `<<=` | Left shift and assign |
| `>>=` | Right shift and assign |

## 17.7 Transfer Operator

Mojo uses the caret (`^`) as the transfer marker or transfer sigil for explicit ownership transfer:

```mojo
let b = a^  # Transfer ownership of a to b
```

## 17.8 Walrus Operator

Mojo supports the walrus operator (`:=`) for assignment expressions:

```mojo
if (n := len(collection)) > 10:
    print(f"Collection has {n} elements")
```

## 17.9 Member Access

The dot operator (`.`) accesses an attribute or method on a value:

```mojo
obj.method()
obj.field
```

## 17.10 Subscript and Slice Operators

```mojo
collection[index]
collection[start:end:step]
```

---

# 18. Error Handling

## 18.1 `try`/`except`/`finally`

Mojo supports Python-style exception handling:

```mojo
try:
    # Code that may raise
    risky_operation()
except ValueError as e:
    # Handle ValueError
    print(f"Value error: {e}")
except Exception as e:
    # Handle other exceptions
    print(f"Error: {e}")
finally:
    # Always executed
    cleanup()
```

## 18.2 `raise` Statement

```mojo
raise ValueError("Invalid value")
```

## 18.3 `assert` Statement

```mojo
assert condition, "Optional error message"
```

## 18.4 `Error` Class

The `error` module implements the `Error` class.

---

# 19. Modules and Packages

## 19.1 Importing Modules

```mojo
import module_name
from module_name import item_name
from module_name import item1, item2
from module_name import *  # Not recommended
```

## 19.2 Creating Modules

Any `.mojo` file is a module. The module name is the filename without the extension.

## 19.3 Packages

A package is a directory containing an `__init__.mojo` file.

---

# 20. Decorators and Attributes

## 20.1 `@align`

Structs can specify minimum alignment with `@align(N)`:

```mojo
@align(64)
struct AlignedType:
    var data: SIMD[Float32, 16]
```

## 20.2 `@doc_hidden`

The `@doc_hidden` decorator hides items from documentation.

## 20.3 `@parameter` (Deprecating)

The `@parameter` forms for compile-time conditionals and loops are being deprecated in favor of `comptime`.

---

# 21. Compilation Targets

Mojo compiles code for a range of targets, from the local machine to other CPUs, operating systems, and GPUs.

## 21.1 Target Inspection

```bash
mojo build --print-effective-target
```

## 21.2 Target Specification

```bash
mojo build --target=<target> program.mojo
```

## 21.3 Target Documentation

The compilation targets documentation instructs how to inspect the current platform, select a target configuration, and generate code for that target.

---

# 22. Debugging and Profiling

## 22.1 Debugger

The `mojo debug` command launches the Mojo debugger:

```bash
mojo debug program.mojo
```

## 22.2 Breakpoint

The built-in `breakpoint()` function sets a breakpoint:

```mojo
breakpoint()  # Pause execution and enter debugger
```

## 22.3 Benchmarking

The `benchmark` module provides runtime benchmarking with statistical analysis and detailed reports:

```mojo
from benchmark import benchmark

benchmark(my_function, iterations=1000)
```

## 22.4 Debug Build

```bash
mojo build --debug program.mojo
```

---

# 23. Performance Optimization

## 23.1 Optimization Levels

| Flag | Description |
|------|-------------|
| `-O0` | No optimization |
| `-O1` | Basic optimizations |
| `-O2` | Standard optimizations |
| `-O3` | Aggressive optimizations |

```bash
mojo build -O3 --release program.mojo
```

## 23.2 Release Build

```bash
mojo build --release program.mojo
```

## 23.3 SIMD Operations

The `SIMD` type provides vectorized operations for high-performance numerical computing:

```mojo
let v1 = SIMD[Float32, 4](1.0, 2.0, 3.0, 4.0)
let v2 = SIMD[Float32, 4](5.0, 6.0, 7.0, 8.0)
let result = v1 + v2  # Vectorized addition
```

## 23.4 Algorithm Package

The `algorithm` package provides high-performance data operations: vectorization, parallelization, reduction, and memory operations.

---

# 24. Version History and Migration

## 24.1 v0.26.2 (March 19, 2026)

- `def`/`fn` unification: `def` is now Mojo's standard function declaration keyword. `def` functions no longer implicitly raise and now have the same semantics as `fn`
- `fn` is deprecated and will be removed in a future release
- T-strings: Support for template strings with the `t"..."` prefix
- `comptime if` and `comptime for`: Replaces legacy `@parameter if` and `@parameter for`
- `assert` statement: Standalone assertion support
- `@align(N)` decorator: Struct alignment specification
- Conditional trait conformances: Structs can declare trait conformances with `where` clauses
- Implicit `Int` to `SIMD` conversions deprecated
- Init unification: `__moveinit__()` and `__copyinit__()` renamed to `__init__()` with keyword-only `take` and `copy` arguments

## 24.2 Migration from `fn` to `def`

The `mojo build --experimental-fixit` command can assist with migration:

```bash
mojo build --experimental-fixit program.mojo
```

## 24.3 Migration from `@parameter` to `comptime`

Replace:
```mojo
@parameter if condition:
    # code
```

With:
```mojo
comptime if condition:
    # code
```

## 24.4 Migration from Implicit `Int` to `SIMD` Conversions

Replace implicit conversions with explicit constructors:

```mojo
# Before (deprecated)
let x: SIMD[Float32, 1] = 42

# After
let x = SIMD[Float32, 1](42)
```

---

# 25. Glossary

| Term | Definition |
|------|------------|
| **Argument** | A run-time value passed to a function |
| **Parameter** | A compile-time value used for metaprogramming |
| **Trait** | A set of requirements that a type must implement |
| **Struct** | A custom data type definition |
| **SIMD** | Single Instruction, Multiple Data - vector processing |
| **MLIR** | Multi-Level Intermediate Representation - compiler infrastructure |
| **FFI** | Foreign Function Interface - for calling C code |
| **ARC** | Automatic Reference Counting - smart pointers |
| **REPL** | Read-Eval-Print Loop - interactive interpreter |
| **T-string** | Template string with structured formatting |
| **DType** | Data type specifier for SIMD vectors |
| **Comptime** | Compile-time evaluation |
| **Ownership** | Memory management system ensuring single ownership |
| **Value Semantics** | Each copy is independent; modifications don't affect other copies |
| **Reference Semantics** | Multiple variables can point to the same instance |

---

# Appendix A: Quick Reference

## A.1 Basic Syntax

```mojo
# Variable declaration
let immutable: Int = 10
var mutable: String = "hello"

# Function definition
def add(a: Int, b: Int) -> Int:
    return a + b

# Struct definition
struct Point:
    var x: Int
    var y: Int

# Trait definition
trait Drawable:
    def draw(self)

# Conditional
if condition:
    # code
elif other:
    # code
else:
    # code

# Loop
for i in range(10):
    print(i)

# Compile-time
comptime if condition:
    # compile-time code
```

## A.2 Command Quick Reference

| Command | Description |
|---------|-------------|
| `mojo --version` | Check version |
| `mojo run file.mojo` | Run Mojo file |
| `mojo build file.mojo` | Build executable |
| `mojo repl` | Launch REPL |
| `mojo debug file.mojo` | Launch debugger |
| `mojo precompile package` | Precompile package |
| `mojo format file.mojo` | Format source |
| `mojo init project` | Initialize project |

---

*This reference guide is current for Mojo v0.26.2 (stable release), published March 19, 2026. For the complete Mojo documentation, refer to the [Mojo Manual](https://docs.modular.com/mojo/manual/) and [Mojo API Reference](https://docs.modular.com/mojo/lib/)*.
