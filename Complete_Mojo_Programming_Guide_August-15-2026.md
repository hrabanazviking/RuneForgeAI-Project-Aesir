# The Complete Mojo Programming Guide

(Complete_Mojo_Programming_Guide_August-15-2026.md)

## Version 1.0 — August 2026 Release

---

# Table of Contents

1. [Introduction to Mojo](#1-introduction-to-mojo)
2. [Getting Started](#2-getting-started)
3. [Language Fundamentals](#3-language-fundamentals)
4. [The Type System](#4-the-type-system)
5. [Value Ownership and Lifecycle Management](#5-value-ownership-and-lifecycle-management)
6. [Structs: Building Custom Types](#6-structs-building-custom-types)
7. [Traits and Generic Programming](#7-traits-and-generic-programming)
8. [Compile-Time Metaprogramming](#8-compile-time-metaprogramming)
9. [Error Handling](#9-error-handling)
10. [Modules and Packages](#10-modules-and-packages)
11. [Concurrency and Parallelism](#11-concurrency-and-parallelism)
12. [GPU Programming](#12-gpu-programming)
13. [Foreign Function Interface (FFI)](#13-foreign-function-interface-ffi)
14. [Python Interoperability](#14-python-interoperability)
15. [Memory Management and Unsafe Code](#15-memory-management-and-unsafe-code)
16. [Performance Optimization](#16-performance-optimization)
17. [Debugging and Testing](#17-debugging-and-testing)
18. [The Standard Library](#18-the-standard-library)
19. [Best Practices and Design Patterns](#19-best-practices-and-design-patterns)
20. [Roadmap and Future Directions](#20-roadmap-and-future-directions)

---

# 1. Introduction to Mojo

## 1.1 What is Mojo?

Mojo is a systems programming language specifically designed for high-performance AI infrastructure and heterogeneous hardware. First announced in May 2023 and reaching version 1.0 on August 11, 2026, Mojo represents a paradigm shift in how developers approach performance-critical computing.

Mojo is the first programming language built from the ground up using MLIR (Multi-Level Intermediate Representation)—a modern compiler infrastructure for heterogeneous hardware ranging from CPUs to GPUs and AI ASICs. This architectural foundation enables Mojo to deliver Python-like ergonomics with C++ and Rust-level performance across diverse hardware platforms.

### 1.1.1 Design Philosophy

Mojo was created to solve the "two-language problem" that has long plagued the AI and scientific computing communities—the need to prototype in Python and then rewrite performance-critical components in C++ or CUDA. Mojo allows developers to write all their code in a single language, from high-level AI applications down to low-level GPU kernels, without using hardware-specific libraries such as CUDA and ROCm.

The language brings together ideas from Rust (ownership and safety), Python (syntax and ecosystem), and C++ (performance and systems control), unified under a single coherent design.

### 1.1.2 Key Features

**Python Syntax and Interoperability**: Mojo adopts and extends Python's syntax, making it immediately familiar to Python programmers. Interoperability works in both directions—you can import Python libraries into Mojo and create Mojo bindings to call from Python.

**Struct-Based Types**: All data types—including basic types like `String` and `Int`—are defined as structs. No types are built into the language itself, meaning you can define your own types with all the same capabilities as standard library types.

**Zero-Cost Traits**: Mojo's trait system provides compile-time type checking with no runtime performance cost. Traits define shared sets of behaviors that types can implement, similar to interfaces in Java or protocols in Swift.

**Value Semantics**: Mojo generally defaults to value semantics, where each copy is independent. This prevents multiple variables from unexpectedly sharing the same data.

**Value Ownership**: Mojo's ownership system ensures that only one variable "owns" a specific value at a given time. This provides safety from use-after-free, double-free, and memory leaks without garbage collector overhead.

**Compile-Time Metaprogramming**: Mojo's parameterization system enables powerful metaprogramming. The same language used for runtime programs is used for compile-time computation.

## 1.2 Mojo 1.0: Production Readiness

The August 2026 release of Mojo 1.0 marks the language's transition to production-ready status. Key aspects of this release include:

- **Backward Compatibility**: Mojo 1.0 provides stability guarantees through semantic versioning
- **API Stabilization**: Core APIs have been stabilized for production use
- **Performance Maturity**: The compiler and runtime have been battle-tested in production environments
- **Open Source Roadmap**: The compiler toolchain is scheduled for open-sourcing following the 1.0 release

## 1.3 Target Audience

Mojo is designed for developers working at the intersection of systems programming and AI/ML infrastructure. The language benefits:

- AI engineers building and optimizing model inference and training pipelines
- Systems programmers developing high-performance infrastructure
- Scientific computing researchers implementing computational kernels
- Python developers seeking to eliminate the two-language problem
- Developers targeting heterogeneous hardware (CPUs, GPUs, AI accelerators)

---

# 2. Getting Started

## 2.1 Installation

Mojo is distributed through the Modular MAX platform. The current stable version is Mojo 1.0.0, released as part of the Modular 26.5 update.

### 2.1.1 System Requirements

- **Operating Systems**: Linux (x86_64) and macOS (Apple Silicon and x86_64)
- **Python**: Python 3.10–3.14 for interoperability features
- **Memory**: Minimum 8GB RAM recommended for compilation

### 2.1.2 Installation Methods

**Method 1: Modular MAX Installation**

```bash
# Install the Modular MAX platform
curl -fsSL https://get.modular.com | sh
# Install Mojo
modular install mojo
```

**Method 2: Conda/Pixi Installation**

Mojo packages are available through the modular-community conda channel:

```toml
# In pixi.toml
[project]
channels = ["modular-community", "conda-forge"]
dependencies = { mojo = ">=1.0.0" }
```

**Method 3: Mojo Playground**

For quick experimentation, the Mojo Playground provides a browser-based environment.

### 2.1.3 Verifying Installation

```bash
mojo --version
# Should output: mojo 1.0.0
```

## 2.2 Your First Mojo Program

Every Mojo program must include a function named `main()` as the entry point:

```mojo
def main():
    print("Hello, world!")
```

Save this as `hello.mojo` and compile it:

```bash
mojo build hello.mojo
./hello
```

## 2.3 Development Environment

### 2.3.1 Visual Studio Code

The Mojo extension for VS Code provides language support including:

- Syntax highlighting
- Code completion (via the Mojo Language Server Protocol)
- Integrated debugging via LLDB
- Inline error reporting

### 2.3.2 Command-Line Tools

**`mojo build`**: Compiles a Mojo file into an executable

```bash
mojo build program.mojo -o program
```

**`mojo package`**: Bundles a package into a `.mojopkg` file for distribution

```bash
mojo package src/ -o mypackage.mojopkg
```

**`mojo doc`**: Generates API reference documentation from docstrings

```bash
mojo doc mylib.mojo --output docs.json
```

**`mojo debug`**: Launches a debugging session using LLDB

---

# 3. Language Fundamentals

## 3.1 Variables and Types

Mojo variables are statically typed—the type is determined at compile time and cannot change at runtime.

### 3.1.1 Variable Declaration

Variables are declared using the `var` keyword:

```mojo
def main():
    var x = 10              # Type inferred as Int
    var y: Int = 20         # Explicit type annotation
    var z: Int              # Declaration without initialization
    z = 30                  # Assignment
```

If you don't specify a type, Mojo uses the type of the first value assigned:

```mojo
var x = 10
x = "Foo"  # Error: cannot implicitly convert 'StringLiteral["Foo"]' value to 'Int'
```

### 3.1.2 Constants

Compile-time constants are declared with `comptime`:

```mojo
comptime MAX_SIZE = 1024
comptime PI: Float64 = 3.141592653589793
```

### 3.1.3 References

References provide aliases to existing values:

```mojo
var value = 42
ref alias = value    # 'alias' refers to the same memory as 'value'
alias = 100          # Now value == 100
```

## 3.2 Control Flow

### 3.2.1 Conditional Statements

```mojo
def main():
    var x = 10
    if x > 0:
        print("Positive")
    elif x == 0:
        print("Zero")
    else:
        print("Negative")
```

### 3.2.2 Loops

**`for` loops** iterate over ranges or iterables:

```mojo
for i in range(5):
    print(i)  # Prints 0, 1, 2, 3, 4

for x in range(0, 10, 2):
    print(x)  # Prints 0, 2, 4, 6, 8
```

**`while` loops**:

```mojo
var i = 0
while i < 5:
    print(i)
    i += 1
```

### 3.2.3 Pattern Matching

Mojo 1.0 includes pattern matching capabilities, with more extensive features planned for future releases.

## 3.3 Functions

Mojo supports two function declaration styles: `def` (Python-compatible) and `fn` (performance-oriented).

### 3.3.1 Def Functions

`def` functions resemble Python functions and support raising exceptions:

```mojo
def greet(name: String) -> String:
    return "Hello, " + name

def divide(a: Int, b: Int) -> Int raises:
    if b == 0:
        raise Error("Division by zero")
    return a // b
```

### 3.3.2 Fn Functions

`fn` functions are more performance-oriented with stricter type checking:

```mojo
fn add(x: Int, y: Int) -> Int:
    return x + y

fn compute(data: List[Int]) -> Int:
    var sum: Int = 0
    for value in data:
        sum += value
    return sum
```

### 3.3.3 Function Overloading

Functions can be overloaded on their parameter signatures:

```mojo
def process(value: Int):
    print("Processing integer:", value)

def process(value: String):
    print("Processing string:", value)
```

### 3.3.4 Default and Named Arguments

```mojo
def configure(host: String = "localhost", port: Int = 8080):
    print("Connecting to", host, "on port", port)

# Called with defaults
configure()
# Called with named arguments
configure(port = 9090)
```

## 3.4 Operators

Mojo supports standard arithmetic, comparison, and logical operators with Python-compatible syntax.

### 3.4.1 Arithmetic Operators

| Operator | Description |
|----------|-------------|
| `+` | Addition |
| `-` | Subtraction |
| `*` | Multiplication |
| `/` | Division (returns Float64) |
| `//` | Integer division |
| `%` | Modulo |
| `**` | Exponentiation |

### 3.4.2 Bitwise Operators

| Operator | Description |
|----------|-------------|
| `&` | Bitwise AND |
| `\|` | Bitwise OR |
| `^` | Bitwise XOR |
| `~` | Bitwise NOT |
| `<<` | Left shift |
| `>>` | Right shift |

### 3.4.3 Comparison Operators

| Operator | Description |
|----------|-------------|
| `==` | Equal |
| `!=` | Not equal |
| `<` | Less than |
| `>` | Greater than |
| `<=` | Less than or equal |
| `>=` | Greater than or equal |

---

# 4. The Type System

## 4.1 Primitive Types

### 4.1.1 Integer Types

Mojo provides both arbitrary-precision and fixed-width integers:

```mojo
var big: Int = 42                    # Native word size integer
var i8: Int8 = 127                   # Signed 8-bit
var u16: UInt16 = 65535              # Unsigned 16-bit
var i32: Int32 = 2147483647          # Signed 32-bit
var u64: UInt64 = 18446744073709551615  # Unsigned 64-bit
```

All fixed-precision integer types are aliases to the `SIMD` type.

### 4.1.2 Floating-Point Types

```mojo
var f32: Float32 = 3.14159           # 32-bit floating point
var f64: Float64 = 3.141592653589793 # 64-bit floating point
```

### 4.1.3 Boolean Type

```mojo
var flag: Bool = True
var is_valid = False
```

### 4.1.4 String Type

```mojo
var greeting: String = "Hello, world!"
var name = "Alice"
var combined = greeting + " My name is " + name
```

## 4.2 The SIMD Type

The `SIMD` (Single Instruction, Multiple Data) type is a first-class citizen in Mojo. It maps directly to hardware vector registers and instructions, enabling automatic generation of optimal SIMD code leveraging CPU-specific instruction sets such as AVX and NEON.

### 4.2.1 SIMD Declaration

```mojo
from builtin import SIMD
from builtin import DType

# SIMD vector of 4 Float32 elements
var vec = SIMD[DType.float32, 4](1.0, 2.0, 3.0, 4.0)

# SIMD vector with default width (architectural SIMD width)
var default_vec = SIMD[DType.float32](1.0, 2.0, 3.0, 4.0)

# SIMD vector of 8 Int16 elements
var int_vec = SIMD[DType.int16, 8](1, 2, 3, 4, 5, 6, 7, 8)
```

### 4.2.2 SIMD Operations

```mojo
var a = SIMD[DType.float32, 4](1.0, 2.0, 3.0, 4.0)
var b = SIMD[DType.float32, 4](5.0, 6.0, 7.0, 8.0)

var c = a + b              # Element-wise addition
var d = a * b              # Element-wise multiplication
var e = a.reduce_add()     # Horizontal reduction (sum of all elements)
var max_val = a.reduce_max()  # Maximum element
```

### 4.2.3 DType Constants

The `DType` enum provides compile-time constants for specifying data types:

| Constant | Description |
|----------|-------------|
| `DType.bool` | Boolean |
| `DType.int8` | Signed 8-bit integer |
| `DType.int16` | Signed 16-bit integer |
| `DType.int32` | Signed 32-bit integer |
| `DType.int64` | Signed 64-bit integer |
| `DType.uint8` | Unsigned 8-bit integer |
| `DType.uint16` | Unsigned 16-bit integer |
| `DType.uint32` | Unsigned 32-bit integer |
| `DType.uint64` | Unsigned 64-bit integer |
| `DType.float16` | 16-bit floating point |
| `DType.float32` | 32-bit floating point |
| `DType.float64` | 64-bit floating point |

## 4.3 Collection Types

### 4.3.1 List

```mojo
from collections import List

var numbers = List[Int](1, 2, 3, 4, 5)
numbers.append(6)
var first = numbers[0]
var length = numbers.size()
```

### 4.3.2 Dict

```mojo
from collections import Dict

var scores = Dict[String, Int]()
scores["Alice"] = 95
scores["Bob"] = 87
var alice_score = scores.get("Alice", 0)
```

### 4.3.3 String

```mojo
from collections import String

var s = String("Hello")
s += " world"
var len = s.length()
var substr = s.slice(0, 5)
```

### 4.3.4 Optional

```mojo
from collections import Optional

var maybe_value: Optional[Int] = Optional.some(42)
if maybe_value.is_some():
    var value = maybe_value.unsafe_get()
```

---

# 5. Value Ownership and Lifecycle Management

## 5.1 Memory Management Strategies

Mojo uses a unique approach called "ownership" that relies on a collection of rules programmers must follow when passing values. The rules ensure there is only one "owner" for a given value at a time. When a value's lifetime ends, Mojo calls its destructor, which deallocates any heap memory that needs to be deallocated.

Mojo has no reference counter and no garbage collector. All data types in the standard library are implemented as structs.

## 5.2 Stack and Heap

Modern programming languages divide a running program's memory into four segments:

1. **Text**: The compiled program
2. **Data**: Global data (initialized or uninitialized)
3. **Stack**: Local data, automatically managed during runtime
4. **Heap**: Dynamically-allocated data, managed by the programmer

The stack stores data local to the current function. When a function is called, a stack frame of exactly the size required to store the function's data is allocated. When the function returns, its stack frame is popped.

Dynamically-sized values that can change in size at runtime are stored in the heap. A local variable for such a value stores a fixed-size pointer to the real value on the heap.

## 5.3 Ownership Rules

Mojo's ownership system ensures:

1. Every value has only one owner at a time
2. When the lifetime of the owner ends, Mojo destroys the value
3. If there are existing references to a value, Mojo extends the lifetime of the owner

### 5.3.1 Move Semantics

When a value is moved, ownership transfers to the new location:

```mojo
struct MyData:
    var value: Int
    def __init__(out self, value: Int):
        self.value = value

def main():
    var a = MyData(42)
    var b = a^   # Move: ownership transfers from a to b
    # a is no longer valid
```

### 5.3.2 Copy Semantics

Types that implement copy semantics can be duplicated:

```mojo
struct MyData:
    var value: Int
    def __init__(out self, value: Int):
        self.value = value
    def __init__(out self, copy: MyData):
        self.value = copy.value

def main():
    var a = MyData(42)
    var b = a    # Copy: b gets a copy of a's data
    # Both a and b are valid
```

### 5.3.3 Argument Conventions

Mojo supports several argument conventions for functions:

- **`in`**: Read-only reference (borrowed)
- **`out`**: Uninitialized reference that must be initialized
- **`ref`**: Mutable reference
- **`owned`**: Takes ownership of the value

## 5.4 Value Lifecycle

The lifecycle of a value is defined by special "dunder" methods in a struct:

| Method | Purpose |
|--------|---------|
| `__init__()` | Constructor |
| `__del__()` | Destructor |
| `__init__(copy=)` | Copy constructor |
| `__init__(take=)` | Move constructor |

Each lifecycle event is handled by a different method. The "lifetime" of a variable is the span of time during program execution in which the variable is considered valid.

### 5.4.1 Origin Type

The concept of lifetimes is related to the `origin` type, a Mojo primitive used to track ownership. For most Mojo programming, you won't need to work with origin values directly.

## 5.5 Explicitly-Destroyed Types

Mojo has first-class support for explicitly-destroyed types (sometimes referred to as "linear types"). These types must be explicitly destroyed, enabling precise resource management.

---

# 6. Structs: Building Custom Types

A struct is Mojo's primary way to define your own type. Structs bundle data together with operations that act on that data.

## 6.1 Struct Definition

All struct fields must be declared using `var` and include a type annotation:

```mojo
struct MyPair:
    var first: Int
    var second: Int

    def __init__(out self, first: Int, second: Int):
        self.first = first
        self.second = second
```

### 6.1.1 Field-Wise Initialization

Mojo provides the `@fieldwise_init` decorator to generate a field-wise constructor automatically:

```mojo
@fieldwise_init
struct MyPair:
    var first: Int
    var second: Int

# Usage:
var pair = MyPair(10, 20)
```

## 6.2 Methods

Methods are functions defined within a struct that act upon the field data:

```mojo
struct Counter:
    var count: Int

    def __init__(out self, initial: Int = 0):
        self.count = initial

    def increment(ref self):
        self.count += 1

    def value(self) -> Int:
        return self.count
```

### 6.2.1 Static Methods

Static methods are functions provided by the type:

```mojo
struct Math:
    @staticmethod
    def square(x: Int) -> Int:
        return x * x

    @staticmethod
    def pi() -> Float64:
        return 3.141592653589793
```

## 6.3 Special (Dunder) Methods

Special methods have double underscores on both sides and define behaviors like initialization and trait conformance:

### 6.3.1 Constructor: `__init__`

```mojo
struct Point:
    var x: Float64
    var y: Float64

    def __init__(out self, x: Float64, y: Float64):
        self.x = x
        self.y = y
```

### 6.3.2 Copy Constructor: `__init__(copy=)`

```mojo
def __init__(out self, copy: Point):
    self.x = copy.x
    self.y = copy.y
```

### 6.3.3 Move Constructor: `__init__(take=)`

```mojo
def __init__(out self, take: Point):
    self.x = take.x
    self.y = take.y
```

### 6.3.4 Destructor: `__del__`

```mojo
def __del__(owned self):
    # Clean up resources
    pass
```

### 6.3.5 Operator Overloading

```mojo
struct Vector3:
    var x: Float64
    var y: Float64
    var z: Float64

    def __add__(self, other: Vector3) -> Vector3:
        return Vector3(self.x + other.x, self.y + other.y, self.z + other.z)

    def __mul__(self, scalar: Float64) -> Vector3:
        return Vector3(self.x * scalar, self.y * scalar, self.z * scalar)
```

## 6.4 Decorators for Structs

### 6.4.1 `@register_passable`

The `@register_passable` decorator declares that a struct can be passed through registers. Register-passable types must be trivially copyable and movable:

```mojo
@register_passable("trivial")
struct SmallType:
    var value: Int32
```

### 6.4.2 `@value`

The `@value` decorator automatically generates lifecycle methods:

```mojo
@value
struct Point:
    var x: Float64
    var y: Float64
```

---

# 7. Traits and Generic Programming

## 7.1 Traits

A trait defines a set of shared behaviors that types (structs) can implement. Traits enable writing functions that depend on behaviors rather than specific types, similar to interfaces in Java or protocols in Swift.

### 7.1.1 Defining Traits

```mojo
trait Printable:
    def format(self) -> String

trait Comparable:
    def compare(self, other: Self) -> Int
```

### 7.1.2 Implementing Traits

```mojo
struct Person:
    var name: String
    var age: Int

    # Implement Printable
    def format(self) -> String:
        return self.name + " (" + String(self.age) + " years old)"
```

### 7.1.3 Built-in Traits

Mojo ships with built-in traits for common behaviors:

- **`Copyable`**: Types that can be copied
- **`Movable`**: Types that can be moved
- **`Destructible`**: Types that can be destroyed
- **`CollectionElement`**: Types that can be stored in collections
- **`Comparable`**: Types that support comparison
- **`Writable`**: Types that can be written to output

## 7.2 Generics

Type generics let you write code once and use it across many types without duplicating logic. Generics use compile-time parameters—a function parameterized on a type is type-generic.

### 7.2.1 Generic Functions

```mojo
def identity[T: AnyType](value: T) -> T:
    return value

def swap[T: AnyType](ref a: T, ref b: T):
    var temp = a^
    a = b^
    b = temp^
```

### 7.2.2 Generic Structs

```mojo
struct Box[T: AnyType]:
    var value: T

    def __init__(out self, value: T):
        self.value = value

    def get(self) -> T:
        return self.value
```

### 7.2.3 Trait Bounds

Generics use traits to constrain which types work with the code:

```mojo
def max[T: Comparable](a: T, b: T) -> T:
    if a.compare(b) > 0:
        return a
    return b

def sort[T: Comparable](ref list: List[T]):
    # Sort implementation
    pass
```

### 7.2.4 Conditional Conformance

Types can conditionally conform to traits based on their parameters:

```mojo
struct Pair[A: AnyType, B: AnyType]:
    var first: A
    var second: B

# Pair conforms to Comparable if both A and B are Comparable
trait Comparable for Pair[A, B] where A: Comparable, B: Comparable:
    def compare(self, other: Pair[A, B]) -> Int:
        var first_cmp = self.first.compare(other.first)
        if first_cmp != 0:
            return first_cmp
        return self.second.compare(other.second)
```

---

# 8. Compile-Time Metaprogramming

Mojo's compile-time metaprogramming system uses the same language as runtime programs—you don't have to learn a new language, just a few new features.

## 8.1 Compile-Time Parameters

Parameters are compile-time inputs to structs or functions, appearing in square brackets after the name:

```mojo
def multiplier[factor: Int](x: Int):
    return x * factor

def main():
    comptime times_ten = multiplier[10]
    var result = times_ten(3)  # Returns 30
```

Parameters accept both types and values at compile time:

```mojo
struct MyList[T: AnyType]:
    # ... type-generic struct

struct FixedBuffer[size: Int]:
    # ... value-generic struct
```

### 8.1.1 Parameterized Functions

```mojo
def repeat[count: Int](msg: String):
    comptime for i in range(count):
        print(msg)
```

The `comptime` keyword causes the for loop to be fully unrolled at compile time. Calling the function:

```mojo
repeat[3]("Hello")
# Output:
# Hello
# Hello
# Hello
```

### 8.1.2 Parameter Overloading

Functions and methods can be overloaded on their parameter signatures.

## 8.2 Compile-Time Evaluation

The `comptime` keyword identifies statements or expressions that need to be evaluated at compile time:

```mojo
comptime MAX_VALUE = 1000

comptime if DEBUG:
    print("Debug mode enabled")
else:
    print("Release mode")

comptime for i in range(4):
    var array[i] = i * i
```

## 8.3 Compile-Time Materialization

Mojo can materialize compile-time values for use at runtime:

```mojo
comptime FACTOR = 42

def compute(x: Int) -> Int:
    return x * FACTOR  # FACTOR is materialized as a runtime constant
```

## 8.4 Reflection

Mojo provides compile-time introspection through the reflection module:

```mojo
from reflection import get_type_name, has_trait

comptime if has_trait[T, Comparable]:
    print("T is Comparable")
```

---

# 9. Error Handling

## 9.1 Typed Errors

Mojo 1.0 supports typed errors, where functions can specify what type they raise instead of defaulting to a generic error type. Typed errors compile to alternate return values without stack unwinding.

### 9.1.1 Defining Custom Error Types

```mojo
struct MyError:
    var code: Int
    var message: String

    def __init__(out self, code: Int, message: String):
        self.code = code
        self.message = message
```

### 9.1.2 Raising Typed Errors

```mojo
def validate(value: Int) -> Int raises -> MyError:
    if value < 0:
        raise MyError(-1, "Value must be non-negative")
    if value > 100:
        raise MyError(-2, "Value must be <= 100")
    return value
```

### 9.1.3 Handling Errors

```mojo
def main():
    try:
        var result = validate(150)
        print("Valid:", result)
    except e: MyError:
        print("Error", e.code, ":", e.message)
```

## 9.2 The `raises` Keyword

Functions that can raise exceptions must be marked with the `raises` keyword:

```mojo
def divide(a: Int, b: Int) -> Int raises:
    if b == 0:
        raise Error("Division by zero")
    return a // b
```

You cannot call raising functions from non-raising functions without wrapping the call in try/except.

## 9.3 Context Managers

Mojo supports context managers for resource management:

```mojo
with open("file.txt", "r") as file:
    var content = file.read()
# File is automatically closed
```

## 9.4 Assertions

```mojo
from sys.debug import assert_true

def compute(x: Int) -> Int:
    assert_true(x >= 0, "x must be non-negative")
    return x * 2
```

Assertions can be controlled at compile time:

- **`ASSERT=1`**: Turn on "safe" assertions only
- **`ASSERT=0`**: Turn off all assertions for performance
- **`ASSERT=warn`**: Turn on all assertions but print errors instead of exiting

---

# 10. Modules and Packages

## 10.1 Modules

A Mojo module is a single `.mojo` file containing code that can be imported into other Mojo programs.

### 10.1.1 Defining a Module

```mojo
# math_utils.mojo
def add(a: Int, b: Int) -> Int:
    return a + b

def multiply(a: Int, b: Int) -> Int:
    return a * b
```

### 10.1.2 Importing Modules

```mojo
from math_utils import add, multiply
from math_utils import *  # Import all public symbols
import math_utils
```

## 10.2 Packages

A Mojo package is a collection of Mojo modules in a directory that contains an `__init__.mojo` file.

### 10.2.1 Package Structure

```
mypackage/
    __init__.mojo
    core.mojo
    utils.mojo
    algorithms/
        __init__.mojo
        sorting.mojo
        search.mojo
```

### 10.2.2 Package Initialization

```mojo
# __init__.mojo
from .core import *
from .utils import *
from .algorithms import *
```

### 10.2.3 Importing from Packages

```mojo
import mypackage
from mypackage.core import Process
from mypackage.algorithms.sorting import quicksort
```

## 10.3 Package Distribution

Mojo packages can be distributed as `.mojopkg` files, which are pre-compiled libraries:

```bash
# Build a package
mojo package src/ -o mypackage.mojopkg

# Use the package
# Place it in the library path and import normally
```

The `.mojopkg` file is tied to the exact version of the Mojo compiler that produced it.

## 10.4 Visibility and Exports

```mojo
# Public: visible outside the module
pub def public_function():
    pass

# Private: only visible within the module
def _private_function():
    pass

# Export for Python interop
@export
def exported_to_c():
    pass
```

---

# 11. Concurrency and Parallelism

Mojo is built for modern hardware and can handle multiple tasks simultaneously, making it efficient for AI and machine learning workloads.

## 11.1 Parallelization

The `algorithm` package provides high-performance primitives for data-parallel operations including parallelization (distributing work across multiple cores).

### 11.1.1 Parallel Work Distribution

```mojo
from algorithm import parallelize

def process_item(index: Int):
    # Process item at index
    pass

def main():
    # Execute func(0) through func(num_work_items-1) in parallel
    parallelize(process_item, 1000)
```

### 11.1.2 Parallel Reduction

```mojo
from algorithm import reduction

def sum_array(data: List[Int]) -> Int:
    return reduction.sum(data)
```

### 11.1.3 Vectorization

```mojo
from algorithm import vectorize

# Apply SIMD operations to contiguous data
var result = vectorize.map(square_function, data_array)
```

## 11.2 CPU Backend Utilities

The `cpu` package implements CPU algorithm backend utilities including reduction, tiling, and parallelization:

```mojo
from backend.cpu import parallelize_over_rows

def process_rows(shape: Tuple[Int, Int]):
    parallelize_over_rows(process_row, shape)
```

## 11.3 Atomic Operations

Mojo provides atomic operations for safe concurrent access:

```mojo
from atomic import Atomic, MemoryOrder

var counter = Atomic[Int](0)

# Increment atomically
counter.fetch_add(1, MemoryOrder.relaxed)

# Load atomically
var value = counter.load(MemoryOrder.acquire)
```

## 11.4 Synchronization Primitives

```mojo
from sync import Mutex, Condvar

var mutex = Mutex()
var condition = Condvar()

with mutex.lock():
    # Critical section
    condition.signal()
```

---

# 12. GPU Programming

Mojo provides first-class support for GPU programming through the `gpu` package. GPU programming primitives include thread blocks, async memory operations, barriers, and synchronization.

## 12.1 GPU Execution Model

GPU code in Mojo follows a traditional programming style—partitioning work across threads that are mapped onto 1-, 2-, or 3-dimensional blocks.

### 12.1.1 Thread Hierarchy

- **Grid**: The entire collection of threads executing a kernel
- **Block**: A group of threads that can communicate and synchronize
- **Thread**: The individual execution unit

## 12.2 DeviceContext

The `DeviceContext` represents a single stream of execution on a particular accelerator (GPU):

```mojo
from std.gpu.host import DeviceContext
from std.gpu import thread_idx

with DeviceContext() as ctx:
    # GPU operations within this context
    var idx = thread_idx.x
    # Process element at index
```

## 12.3 Writing GPU Kernels

```mojo
from gpu import DeviceContext, thread_idx, block_dim, grid_dim

def vector_add_kernel(a: UnsafePointer[Float32], 
                      b: UnsafePointer[Float32], 
                      c: UnsafePointer[Float32], 
                      n: Int):
    var idx = thread_idx.x + block_dim.x * block_idx.x
    if idx < n:
        c[idx] = a[idx] + b[idx]

def main():
    with DeviceContext() as ctx:
        # Allocate device memory
        var d_a = ctx.allocate(n * sizeof(Float32))
        var d_b = ctx.allocate(n * sizeof(Float32))
        var d_c = ctx.allocate(n * sizeof(Float32))
        
        # Copy data to device
        ctx.copy_to_device(d_a, h_a)
        ctx.copy_to_device(d_b, h_b)
        
        # Launch kernel
        var block_size = 256
        var grid_size = (n + block_size - 1) // block_size
        ctx.launch(vector_add_kernel, grid_size, block_size, d_a, d_b, d_c, n)
        
        # Copy result back
        ctx.copy_to_host(h_c, d_c)
```

## 12.4 GPU Synchronization

Mojo provides synchronization primitives for coordinating parallel work on the GPU:

```mojo
from gpu import sync_threads, sync_block

def kernel_with_sync():
    # Do work
    sync_threads()  # Synchronize all threads in the block
    # Continue with synchronized state
```

## 12.5 GPU Performance Considerations

Performance optimization for GPU kernels in Mojo includes:

- Using smaller accumulator tiles to reduce register footprint
- Tuning block sizes for better warp utilization
- Implementing double buffering to overlap memory and compute
- Using software pipelining
- Exploring async execution patterns

---

# 13. Foreign Function Interface (FFI)

The `ffi` module provides tools for interfacing Mojo with C libraries and other foreign code.

## 13.1 C Type Aliases

Mojo provides portable type definitions that match C's type sizes on each platform:

| Mojo Type | C Equivalent |
|-----------|--------------|
| `c_char` | `char` |
| `c_int` | `int` |
| `c_long` | `long` |
| `c_long_long` | `long long` |
| `c_short` | `short` |
| `c_size_t` | `size_t` |
| `c_ssize_t` | `ssize_t` |
| `c_uchar` | `unsigned char` |
| `c_uint` | `unsigned int` |
| `c_ulong` | `unsigned long` |
| `c_ulong_long` | `unsigned long long` |
| `c_ushort` | `unsigned short` |
| `c_float` | `float` |
| `c_double` | `double` |

## 13.2 Calling C Functions

```mojo
from std.ffi import c_int, external_call

def get_random() -> c_int:
    return external_call["rand", c_int]()
```

## 13.3 Dynamic Library Loading

```mojo
from std.ffi import OwnedDLHandle

def main() raises:
    var lib = OwnedDLHandle("libm.so")
    var sqrt = lib.get_function[def(Float64) thin abi("C") -> Float64]("sqrt")
    print(sqrt(4.0))  # 2.0
```

## 13.4 C String Interoperability

```mojo
from std.ffi import CStringSlice

def process_c_string(c_str: CStringSlice):
    var mojo_str = String(c_str)
    # Work with mojo_str
```

## 13.5 Untagged Unions

`UnsafeUnion` provides a C-style untagged union type for FFI interoperability:

```mojo
from std.ffi import UnsafeUnion

@register_passable("trivial")
struct MyUnion:
    var int_val: Int32
    var float_val: Float32
```

## 13.6 Exporting Mojo to C

The `@export` decorator makes Mojo functions callable from C:

```mojo
@export
fn add(a: Int32, b: Int32) -> Int32:
    return a + b
```

---

# 14. Python Interoperability

Mojo provides bidirectional interoperability with Python. You can import existing Python modules and use them in Mojo programs, and you can extend your Python code with high-performance Mojo code.

## 14.1 Importing Python Modules

```mojo
from python import Python

def main():
    var np = Python.import_module("numpy")
    var arr = np.array([1.0, 2.0, 3.0])
    var result = np.mean(arr)
    print(result)
```

## 14.2 Python Object Manipulation

```mojo
from python import PythonObject

def process_python_data(data: PythonObject):
    # Work with Python objects in Mojo
    var length = data.__len__()
    for i in range(length):
        var item = data.__getitem__(i)
        # Process item
```

## 14.3 Calling Mojo from Python

```mojo
# mojo_module.mojo
@export
fn calculate(x: Float64, y: Float64) -> Float64:
    return x * x + y * y
```

In Python:

```python
import mojo_module
result = mojo_module.calculate(3.0, 4.0)  # Returns 25.0
```

## 14.4 Type Conversion

Mojo automatically converts between Mojo and Python types where possible:

| Mojo Type | Python Type |
|-----------|-------------|
| `Bool` | `bool` |
| `Int` | `int` |
| `Float64` | `float` |
| `String` | `str` |
| `List[T]` | `list` |
| `Dict[K, V]` | `dict` |

## 14.5 Python Version Compatibility

Mojo's Python interoperability requires Python 3.10–3.14. Mojo doesn't include a CPython interpreter—it uses the CPython interpreter provided by your environment's default Python version.

---

# 15. Memory Management and Unsafe Code

## 15.1 UnsafePointer

`UnsafePointer` represents an indirect reference to one or more values of type `T` consecutively in memory:

```mojo
from memory import UnsafePointer

def main():
    # Allocate memory for 10 integers
    var ptr = UnsafePointer[Int].alloc(10)
    
    # Initialize values
    for i in range(10):
        ptr[i] = i * i
    
    # Read values
    for i in range(10):
        print(ptr[i])
    
    # Free memory
    ptr.free()
```

### 15.1.1 Pointer Operations

```mojo
# Address of an existing value
var value: Int = 42
var ptr = UnsafePointer.address_of(value)

# Dereference
var loaded = ptr[]

# Pointer arithmetic
var next = ptr + 1
```

### 15.1.2 Unsafe Initialization

```mojo
from memory.unsafe_pointer import initialize_pointee_copy

# Initialize uninitialized memory
var ptr = UnsafePointer[MyStruct].alloc(1)
initialize_pointee_copy(ptr, MyStruct(10, 20))
```

## 15.2 OwnedPointer

`OwnedPointer` provides safe, single-owner, non-nullable smart pointer functionality:

```mojo
from memory import OwnedPointer

def main():
    var ptr = OwnedPointer[MyStruct](MyStruct(10, 20))
    var value = ptr.get()
    # ptr automatically frees memory when it goes out of scope
```

## 15.3 ArcPointer

`ArcPointer` provides reference-counted smart pointers for shared ownership:

```mojo
from memory import ArcPointer

def main():
    var shared = ArcPointer[MyStruct](MyStruct(10, 20))
    var clone = shared.clone()  # Increments reference count
    # Memory freed when all references are dropped
```

## 15.4 Memory Utilities

The `memory` package provides functions for memory manipulation:

```mojo
from memory import memcpy, memset, memcmp

var src = UnsafePointer[UInt8].alloc(100)
var dst = UnsafePointer[UInt8].alloc(100)

# Copy memory
memcpy(dst, src, 100)

# Set memory to zero
memset(dst, 0, 100)

# Compare memory
var equal = memcmp(src, dst, 100) == 0
```

## 15.5 Safety Considerations

Unsafe code in Mojo should be used with caution:

1. Always ensure pointers are valid before dereferencing
2. Never use memory after it has been freed
3. Be careful with pointer arithmetic
4. Initialize memory before reading from it
5. Free memory when no longer needed

---

# 16. Performance Optimization

## 16.1 Inlining

The `@always_inline` decorator forces the compiler to inline a function's body directly into the calling function:

```mojo
@always_inline
fn hot_function(x: Float64) -> Float64:
    return x * x + 2.0 * x + 1.0
```

Use `@always_inline("nodebug")` to inline without debug information.

## 16.2 SIMD Vectorization

Mojo automatically generates optimal SIMD code, but you can also explicitly vectorize loops:

```mojo
from algorithm import vectorize

def compute(data: List[Float64]) -> List[Float64]:
    return vectorize.map(square, data)
```

## 16.3 Struct of Arrays (SoA) Layout

For optimal performance with SIMD, use Struct of Arrays (SoA) memory layout instead of Array of Structs (AoS):

```mojo
# AoS (less SIMD-friendly)
struct PointsAoS:
    var x: Float64
    var y: Float64
    var z: Float64

# SoA (SIMD-friendly)
struct PointsSoA:
    var x: SIMD[DType.float64, 8]
    var y: SIMD[DType.float64, 8]
    var z: SIMD[DType.float64, 8]
```

## 16.4 Compile-Time Evaluation

Leverage compile-time evaluation for constant expressions:

```mojo
comptime FACTOR = 42
comptime BUFFER_SIZE = 1024

struct Buffer:
    var data: SIMD[DType.float32, BUFFER_SIZE]
```

## 16.5 Avoiding Materialization

Be aware of when compile-time values are materialized to runtime:

```mojo
# Materialized (creates runtime constant)
comptime SIZE = 1000
var array = SIMD[DType.float32, SIZE]()

# Not materialized (fully compile-time)
comptime var size = 1000
# size is evaluated at compile time
```

## 16.6 Benchmarking

Mojo includes a benchmarking framework:

```mojo
from benchmark import Benchmark

@benchmark
fn my_benchmark():
    # Code to benchmark
    pass
```

---

# 17. Debugging and Testing

## 17.1 Debugging with LLDB

Mojo integrates with LLDB for debugging:

```bash
# Start debugging session
mojo debug program.mojo

# Or debug an executable
mojo debug ./program
```

### 17.1.1 VS Code Debugging

The Mojo extension for VS Code enables using VS Code's built-in debugger:

1. Install the Mojo extension
2. Set breakpoints by clicking to the left of a line
3. Press F5 to start debugging

### 17.1.2 GPU Debugging

For GPU code, use `mojo-cuda-gdb`.

## 17.2 Testing

Mojo includes a unit testing framework.

### 17.2.1 TestSuite

```mojo
from testing import TestSuite, assert_true, assert_equal

def test_addition():
    assert_equal(2 + 2, 4)

def test_subtraction():
    assert_true(5 - 3 == 2)

def main():
    var suite = TestSuite()
    suite.discover_tests()  # Auto-discovers test_* functions
    suite.run()
```

### 17.2.2 Assertions

```mojo
from testing import assert_true, assert_equal, assert_raises

assert_true(condition, "Optional message")
assert_equal(expected, actual, "Values should be equal")

with assert_raises(MyError):
    # Code that should raise MyError
    raise MyError("Expected error")
```

### 17.2.3 Manual Test Registration

```mojo
var suite = TestSuite()
suite.test("my test", fn():
    assert_true(True)
)
```

## 17.3 Debugging Utilities

```mojo
from sys.debug import debug_assert, print_debug

debug_assert(condition, "Debug assertion failed")
print_debug("Debug message")
```

---

# 18. The Standard Library

The Mojo standard library provides nearly everything you'll need for writing Mojo programs.

## 18.1 Package Overview

| Package | Description |
|---------|-------------|
| `algorithm` | High-performance data operations: vectorization, parallelization, reduction, memory |
| `atomic` | Atomic operations and memory orderings |
| `base64` | Binary data encoding: base64 and base16 encode/decode |
| `benchmark` | Performance benchmarking with statistical analysis |
| `bit` | Bitwise operations: manipulation, counting, rotation |
| `builtin` | Built-in types, traits, and fundamental operations |
| `collections` | Core data types: List, Dict, Set, Optional, String |
| `compile` | Runtime function compilation and introspection |
| `complex` | Complex numbers: SIMD types, scalar types, operations |
| `documentation` | Documentation decorators and utilities |
| `ffi` | Foreign function interface for calling C code |
| `format` | Formatting traits for converting types to text |
| `gpu` | GPU programming primitives |
| `hashlib` | Cryptographic and non-cryptographic hashing |
| `io` | Core I/O operations: console, file handling |
| `iter` | Iteration traits and utilities |
| `itertools` | Iterator tools |
| `memory` | Memory management and pointer types |
| `os` | Operating system functionality |
| `python` | Python interoperability |
| `sys` | System runtime: I/O, hardware info, intrinsics |
| `testing` | Unit testing framework |

## 18.2 Key Types

### 18.2.1 Int

The `Int` type is a general-purpose integer that matches the hardware's native word size.

### 18.2.2 Float32 and Float64

Floating-point types built on SIMD.

### 18.2.3 SIMD

The `SIMD` type leverages hardware acceleration to process multiple data elements with a single operation.

### 18.2.4 String

The `String` type provides UTF-8 string handling with heap allocation.

### 18.2.5 List

A dynamic array type supporting O(1) random access and amortized O(1) append.

### 18.2.6 Dict

A hash map type with O(1) average-case lookup.

### 18.2.7 Optional

A type representing an optional value that may or may not be present.

---

# 19. Best Practices and Design Patterns

## 19.1 Type Design

### 19.1.1 Value Types vs. Reference Types

- Use value semantics for small, independent data
- Use reference semantics for large, shared data
- Default to value semantics for predictability

### 19.1.2 Implementing Lifecycle Methods

```mojo
struct Resource:
    var handle: UnsafePointer[UInt8]
    
    # Constructor
    def __init__(out self, size: Int):
        self.handle = UnsafePointer[UInt8].alloc(size)
    
    # Copy constructor (if copyable)
    def __init__(out self, copy: Resource):
        self.handle = UnsafePointer[UInt8].alloc(copy.size)
        memcpy(self.handle, copy.handle, copy.size)
    
    # Move constructor
    def __init__(out self, take: Resource):
        self.handle = take.handle
        take.handle = UnsafePointer[UInt8]()  # Null
    
    # Destructor
    def __del__(owned self):
        if self.handle:
            self.handle.free()
```

## 19.2 Performance Patterns

### 19.2.1 Use SIMD for Data-Parallel Operations

```mojo
# Instead of:
for i in range(n):
    c[i] = a[i] + b[i]

# Use SIMD:
var vec_a = SIMD[DType.float32, 8].load(a_ptr)
var vec_b = SIMD[DType.float32, 8].load(b_ptr)
var vec_c = vec_a + vec_b
vec_c.store(c_ptr)
```

### 19.2.2 Avoid Unnecessary Copies

Use references and move semantics:

```mojo
# Avoid copying large values
def process(ref data: List[Int]):  # Pass by reference
    # Process data in-place

# Use move for ownership transfer
var large_data = create_large_data()
var processed = process(large_data^)  # Move ownership
```

### 19.2.3 Compile-Time Computation

```mojo
comptime BUFFER_SIZE = 1024 * 1024  # Computed at compile time

struct Buffer:
    var data: SIMD[DType.uint8, BUFFER_SIZE]
```

## 19.3 Error Handling Patterns

### 19.3.1 Use Typed Errors

```mojo
struct FileError:
    var code: Int
    var path: String

def read_file(path: String) -> String raises -> FileError:
    if not file_exists(path):
        raise FileError(1, path)
    # Read file
```

### 19.3.2 Propagate Errors Appropriately

```mojo
def high_level_operation() raises:
    try:
        var result = low_level_operation()
        return result
    except e: LowLevelError:
        # Convert to higher-level error
        raise HighLevelError.from_low_level(e)
```

## 19.4 Module Organization

```
src/
    __init__.mojo         # Package exports
    core/
        __init__.mojo
        types.mojo
        utils.mojo
    algorithms/
        __init__.mojo
        sorting.mojo
        search.mojo
    io/
        __init__.mojo
        file.mojo
        network.mojo
tests/
    test_core.mojo
    test_algorithms.mojo
```

## 19.5 Documentation

Use docstrings for API documentation:

```mojo
"""
Compute the Fibonacci sequence.

Args:
    n: The number of terms to compute.
    start: The starting value (default: 0).

Returns:
    A List containing the first n Fibonacci numbers.

Raises:
    ValueError: If n is negative.
"""
def fibonacci(n: Int, start: Int = 0) -> List[Int]:
    # Implementation
```

Generate documentation:

```bash
mojo doc src/ --output docs.json
# Use Modo to convert to Markdown or HTML
modo --input docs.json --output docs/
```

---

# 20. Roadmap and Future Directions

## 20.1 Mojo 1.0 Status

Mojo 1.0 was released on August 11, 2026, marking the language's transition to production-ready status. Key achievements:

- Backward compatibility guarantees
- API stabilization
- Production-ready compiler and runtime
- Semantic versioning

## 20.2 Future Features

Planned features for future releases include:

- **Async programming**: Native async/await support
- **Pattern matching**: Enhanced pattern matching capabilities
- **Tagged unions**: Discriminated union types
- **Compiler open-sourcing**: The compiler toolchain will be open-sourced following the 1.0 release

## 20.3 Phase 2: Systems Application Programming

Following Phase 1 (High-performance CPU + GPU coding), Phase 2 focuses on systems application programming. This phase will expand Mojo's capabilities for building complete applications.

## 20.4 Ecosystem Growth

The Mojo ecosystem continues to grow with:

- 25,000+ GitHub stars
- 21,000+ collaborators
- Active community on Discord and GitHub
- Community-contributed packages
- Educational resources and courses

---

# Appendix A: Quick Reference

## A.1 Keywords

| Keyword | Description |
|---------|-------------|
| `var` | Variable declaration |
| `def` | Function definition (Python-compatible) |
| `fn` | Function definition (performance-oriented) |
| `struct` | Type definition |
| `trait` | Trait definition |
| `comptime` | Compile-time evaluation |
| `pub` | Public visibility |
| `ref` | Reference parameter |
| `out` | Output parameter |
| `owned` | Owned parameter |
| `raises` | Function may raise an error |
| `try`/`except` | Error handling |
| `with` | Context manager |
| `import` | Module import |
| `from` | Selective import |

## A.2 Common Decorators

| Decorator | Purpose |
|-----------|---------|
| `@fieldwise_init` | Generate field-wise constructor |
| `@register_passable` | Register-passable type |
| `@value` | Auto-generate lifecycle methods |
| `@always_inline` | Force function inlining |
| `@export` | Export for C/Python interop |
| `@staticmethod` | Static method |
| `@benchmark` | Benchmark function |

## A.3 Common Imports

```mojo
from builtin import Int, Float32, Float64, Bool, SIMD, DType
from collections import List, Dict, Set, String, Optional
from algorithm import parallelize, vectorize, reduction
from memory import UnsafePointer, OwnedPointer, ArcPointer
from ffi import c_int, c_float, external_call, OwnedDLHandle
from gpu import DeviceContext, thread_idx, block_dim
from testing import TestSuite, assert_true, assert_equal
from python import Python, PythonObject
from io import print, open
from os import getenv, chdir
from sys import exit, args
```

---

# Appendix B: Compiler Options

## B.1 Build Commands

| Command | Description |
|---------|-------------|
| `mojo build file.mojo` | Build executable |
| `mojo build -o output file.mojo` | Build with custom output name |
| `mojo package src/ -o pkg.mojopkg` | Build package |
| `mojo doc file.mojo --output docs.json` | Generate documentation |
| `mojo debug file.mojo` | Start debugging |
| `mojo run file.mojo` | Run without building executable |

## B.2 Compilation Targets

Mojo can compile for various targets:

```bash
# Native target
mojo build file.mojo

# Target specific CPU
mojo build --target x86_64-unknown-linux-gnu file.mojo

# Target GPU
mojo build --target gpu file.mojo
```

## B.3 Environment Variables

| Variable | Purpose |
|----------|---------|
| `ASSERT` | Control assertions: 1=safe, 0=off, warn=warn-only |
| `MOJO_DEBUG` | Enable debug output |
| `MOJO_OPT_LEVEL` | Optimization level (0-3) |

---

# Appendix C: Resources

## C.1 Official Documentation

- **Mojo Manual**: [docs.modular.com/mojo/manual/](https://docs.modular.com/mojo/manual/)
- **API Reference**: [docs.modular.com/mojo/lib/](https://docs.modular.com/mojo/lib/)
- **GitHub**: [github.com/modular/modular](https://github.com/modular/modular)

## C.2 Community

- **Discord**: Active community for discussion and support
- **GitHub Discussions**: Feature requests and design discussions
- **Modular Blog**: [www.modular.com/blog](https://www.modular.com/blog)

## C.3 Learning Resources

- **Mojo GPU Puzzles**: Interactive GPU programming exercises
- **Mojo Playground**: Browser-based environment for experimentation
- **Community Books**: Multiple books available on Mojo programming

---

*This guide covers Mojo version 1.0.0, released August 2026. The language continues to evolve, and readers are encouraged to consult the official documentation for the most up-to-date information.*
