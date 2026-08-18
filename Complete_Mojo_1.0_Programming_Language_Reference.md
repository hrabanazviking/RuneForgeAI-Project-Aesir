# 🔥 The Complete Mojo 1.0 Programming Language Reference

(Complete_Mojo_1.0_Programming_Language_Reference.md)

## Version Information

**Current Stable Release:** Mojo 1.0.0 (Released May 7, 2026)  
**Stability Status:** Production-ready with API stability guarantees  
**Package Version:** 25.7.0+ (Modular Platform 26.5)  
**Open Source Status:** Standard library open source (Apache 2.0), Compiler open sourcing Fall 2026

---

## Table of Contents

1. [Language Keywords](#1-language-keywords)
2. [Operators](#2-operators)
3. [Types and Type System](#3-types-and-type-system)
4. [Variables and Bindings](#4-variables-and-bindings)
5. [Functions](#5-functions)
6. [Structs](#6-structs)
7. [Traits](#7-traits)
8. [Standard Library APIs](#8-standard-library-apis)
9. [Memory Management](#9-memory-management)
10. [Control Flow](#10-control-flow)
11. [Error Handling](#11-error-handling)
12. [Decorators](#12-decorators)
13. [Metaprogramming](#13-metaprogramming)
14. [Python Interoperability](#14-python-interoperability)
15. [GPU Programming](#15-gpu-programming)
16. [C FFI](#16-c-ffi)
17. [Command Line Interface](#17-command-line-interface)
18. [Special Methods](#18-special-methods)
19. [Conventions and Sigils](#19-conventions-and-sigils)
20. [Literals](#20-literals)

---

## 1. Language Keywords

### 1.1 Control Flow Keywords

| Keyword | Description | Example |
|---------|-------------|---------|
| `if` | Conditional execution | `if x > 0:` |
| `elif` | Additional condition in if chain | `elif x == 0:` |
| `else` | Default branch | `else:` |
| `for` | Iteration loop | `for i in range(10):` |
| `while` | Conditional loop | `while condition:` |
| `break` | Exit innermost loop | `break` |
| `continue` | Skip to next iteration | `continue` |
| `pass` | No-op placeholder | `pass` |
| `return` | Return from function | `return value` |
| `with` | Context manager | `with open("file") as f:` |

### 1.2 Error Handling Keywords

| Keyword | Description | Example |
|---------|-------------|---------|
| `try` | Begin error-handling block | `try:` |
| `except` | Error handler clause | `except Error as e:` |
| `finally` | Always-execute clause | `finally:` |
| `raise` | Raise an error | `raise Error("message")` |
| `assert` | Debug assertion | `assert condition, "message"` |

### 1.3 Declaration Keywords

| Keyword | Description | Example |
|---------|-------------|---------|
| `def` | Function declaration | `def func():` |
| `lambda` | Anonymous function (v1.0+) | `lambda (x: Int): x + 1` |
| `struct` | Struct type declaration | `struct Point:` |
| `trait` | Trait declaration | `trait Drawable:` |
| `var` | Mutable variable binding | `var x = 5` |
| `ref` | Reference binding | `ref view = data` |
| `let` | Immutable binding (deprecated, use `var` + explicit immutability) |

### 1.4 Import Keywords

| Keyword | Description | Example |
|---------|-------------|---------|
| `import` | Import module | `import collections` |
| `from` | Selective import | `from collections import List` |
| `as` | Alias import | `import numpy as np` |

### 1.5 Compile-Time Keywords

| Keyword | Description | Example |
|---------|-------------|---------|
| `comptime` | Force compile-time evaluation | `comptime alias N = 10` |
| `alias` | Compile-time constant/type alias | `alias MyInt = Int64` |

### 1.6 Literal Keywords

| Keyword | Value | Type |
|---------|-------|------|
| `True` | Boolean true | `Bool` |
| `False` | Boolean false | `Bool` |
| `None` | Absence of value | `NoneType` |
| `Self` | Reference to enclosing type | Type |

### 1.7 Keyword Operators

| Keyword | Purpose | Example |
|---------|---------|---------|
| `and` | Logical AND | `if a and b:` |
| `or` | Logical OR | `if a or b:` |
| `not` | Logical NOT | `if not condition:` |
| `in` | Membership test | `if x in container:` |
| `is` | Identity test | `if a is b:` |

---

## 2. Operators

### 2.1 Arithmetic Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `+` | Addition | `a + b` |
| `-` | Subtraction/Negation | `a - b` or `-a` |
| `*` | Multiplication | `a * b` |
| `/` | Division | `a / b` |
| `//` | Floor division | `a // b` |
| `%` | Modulo | `a % b` |
| `**` | Exponentiation | `a ** b` |
| `@` | Matrix multiplication | `a @ b` |

### 2.2 Bitwise Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `&` | Bitwise AND | `a & b` |
| `\|` | Bitwise OR | `a \| b` |
| `^` | Bitwise XOR | `a ^ b` |
| `~` | Bitwise NOT | `~a` |
| `<<` | Left shift | `a << n` |
| `>>` | Right shift | `a >> n` |

### 2.3 Comparison Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `==` | Equal to | `a == b` |
| `!=` | Not equal to | `a != b` |
| `<` | Less than | `a < b` |
| `>` | Greater than | `a > b` |
| `<=` | Less than or equal | `a <= b` |
| `>=` | Greater than or equal | `a >= b` |

### 2.4 Assignment Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `=` | Assignment | `var x = 5` |
| `:=` | Walrus operator (assignment expression) | `if (n := len(data)) > 0:` |
| `+=` | Add and assign | `x += 1` |
| `-=` | Subtract and assign | `x -= 1` |
| `*=` | Multiply and assign | `x *= 2` |
| `/=` | Divide and assign | `x /= 2` |
| `//=` | Floor divide and assign | `x //= 2` |
| `%=` | Modulo and assign | `x %= 2` |
| `**=` | Exponentiate and assign | `x **= 2` |
| `&=` | AND and assign | `x &= mask` |
| `\|=` | OR and assign | `x \|= flags` |
| `^=` | XOR and assign | `x ^= mask` |
| `<<=` | Left shift and assign | `x <<= 1` |
| `>>=` | Right shift and assign | `x >>= 1` |

### 2.5 Special Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `^` | Transfer ownership (postfix) | `func(value ^)` |
| `->` | Return type annotation | `def f() -> Int:` |
| `=>` | Arrow for lambdas (not used in Mojo 1.0, uses `:`) | N/A |
| `...` | Variadic pack/Ellipsis | `*args: *Ts` |
| `*` | Unpacking operator | `func(*args)` |
| `**` | Keyword unpacking | `func(**kwargs^)` |
| `@` | Decorator prefix | `@decorator` |
| `:` | Type annotation separator | `x: Int` |
| `;` | Statement separator | `x = 1; y = 2` |
| `->` | Method return type | `fn method() -> Type:` |

---

## 3. Types and Type System

### 3.1 Scalar Numeric Types

#### Integer Types

| Type | Description | Range |
|------|-------------|-------|
| `Int` | Platform-sized signed integer (alias for `Scalar[DType.int]`) | Platform dependent |
| `Int8` | 8-bit signed integer | -128 to 127 |
| `Int16` | 16-bit signed integer | -32,768 to 32,767 |
| `Int32` | 32-bit signed integer | -2^31 to 2^31-1 |
| `Int64` | 64-bit signed integer | -2^63 to 2^63-1 |
| `UInt8` | 8-bit unsigned integer | 0 to 255 |
| `UInt16` | 16-bit unsigned integer | 0 to 65,535 |
| `UInt32` | 32-bit unsigned integer | 0 to 2^32-1 |
| `UInt64` | 64-bit unsigned integer | 0 to 2^64-1 |
| `UInt` | Platform-sized unsigned integer | Platform dependent |

#### Floating Point Types

| Type | Description | Precision |
|------|-------------|-----------|
| `Float16` | Half-precision float | 16-bit |
| `Float32` | Single-precision float | 32-bit |
| `Float64` | Double-precision float | 64-bit |
| `BFloat16` | Brain floating point | 16-bit (different layout) |

#### Other Scalar Types

| Type | Description |
|------|-------------|
| `Bool` | Boolean (True/False) |
| `Byte` | Single byte value |
| `DType` | Data type descriptor for SIMD |
| `NoneType` | Type of `None` |

### 3.2 SIMD Types

```mojo
# SIMD vector type
SIMD[type: DType, length: Int]

# Examples
var vec4f = SIMD[DType.float32, 4]      # 4-element float32 vector
var vec8i = SIMD[DType.int32, 8]        # 8-element int32 vector

# Complex SIMD
ComplexSIMD[type: DType, length: Int]
```

### 3.3 Collection Types

| Type | Description | Module |
|------|-------------|--------|
| `Array[T, length]` | Fixed-size array (formerly `InlineArray`) | `std.collections` |
| `List[T]` | Dynamic array/list | `std.collections` |
| `Dict[K, V]` | Hash map/dictionary | `std.collections` |
| `Set[T]` | Hash set | `std.collections` |
| `Optional[T]` | Optional value (Some/None) | `std.collections` |
| `Variant[Ts...]` | Sum type/variant | `std.utils` |
| `Tuple[Ts...]` | Fixed-size heterogeneous tuple | `std.builtin` |
| `Span[T]` | Non-owning view into contiguous memory | `std.collections` |
| `String` | UTF-8 string | `std.collections` |
| `StringSpan` | String view (formerly `StringSlice`) | `std.collections` |

### 3.4 Pointer Types

| Type | Description |
|------|-------------|
| `Pointer[T, origin]` | Safe pointer with origin tracking |
| `MutPointer[T]` | Mutable pointer shorthand |
| `ImmPointer[T]` | Immutable pointer shorthand |
| `OptionalPointer[T]` | Optional pointer |
| `OwnedPointer[T]` | Unique owning pointer |
| `ArcPointer[T]` | Reference-counted pointer |

### 3.5 Special Types

| Type | Description |
|------|-------------|
| `Self` | Type of the current struct/trait |
| `AnyType` | Top type (all types conform) |
| `Never` | Bottom type (no values) |
| `Origin` | Lifetime/origin parameter |

---

## 4. Variables and Bindings

### 4.1 Variable Declaration

```mojo
# Mutable variable (v1.0: var is now required)
var x: Int = 10           # Explicitly typed
var y = 20                 # Type inferred
var z: Float64            # Uninitialized (must be assigned before use)

# Reference binding
ref view = data           # Immutable reference to existing value
ref mut_view = mut data   # Mutable reference

# Compile-time constants
alias MAX_SIZE = 100      # Compile-time constant
alias MyType = Int64       # Type alias
```

### 4.2 Conventions in Variable Declarations

| Convention | Syntax | Meaning |
|------------|--------|---------|
| `var` | `var x = value` | Owned mutable copy |
| `ref` | `ref x = value` | Reference (borrows) |
| `mut` | `mut x` | Mutable reference |
| `imm` | `imm x` | Immutable reference (default) |
| `out` | `out x` | Output parameter |
| `deinit` | `deinit x` | Destructive transfer |

---

## 5. Functions

### 5.1 Function Declaration Syntax

```mojo
# Basic function
def function_name(arg1: Type1, arg2: Type2) -> ReturnType:
    """Docstring"""
    return result

# Function with effects
def raising_function() raises:
    raise Error("message")

# Function with constraints
def constrained[T: Trait](value: T) where conforms_to(T, Sized):
    pass

# Lambda expression (v1.0+)
var add = lambda (x: Int, y: Int) -> Int: x + y
var noop = lambda: None
```

### 5.2 Argument Conventions

```mojo
# Immutable borrow (default)
fn func(value: Int):           # imm is implicit

# Mutable borrow
fn func(mut value: Int):
    value += 1

# Take ownership
fn func(owned value: Int):
    # value is destroyed when func returns

# Output parameter
fn make_value(out result: Int):
    result = 42

# Variadic arguments
def func(*args: Int):
    for arg in args:
        print(arg)

# Keyword variadic arguments (v1.0: must use var)
def func(var **kwargs: Int):
    for key, value in kwargs.items():
        print(key, value)

# Forwarding variadics (v1.0)
def wrapper(var **kwargs: Int):
    inner_function(**kwargs^)
```

### 5.3 Function Effects

| Effect | Syntax | Description |
|--------|--------|-------------|
| `raises` | `def f() raises:` | Function may raise errors |
| `capturing` | `def f() capturing:` | Closure captures environment |
| `async` | `async def f():` | Async function |

### 5.4 Generic Functions

```mojo
# Simple generic
fn identity[T: AnyType](value: T) -> T:
    return value

# Constrained generic
fn process[T: Movable & Copyable](value: T) -> T:
    return value

# Multiple type parameters
fn pair[T: AnyType, U: AnyType](a: T, b: U) -> Tuple[T, U]:
    return (a, b)

# Variadic generics
fn process_all[*Ts: Movable](*args: *Ts):
    pass

# Where clause with message (v1.0+)
fn scale[sc: Int]() where (sc > 1, "scaling factor must be > 1"):
    pass
```

---

## 6. Structs

### 6.1 Struct Declaration

```mojo
struct Point:
    """A 2D point."""
    
    # Fields
    var x: Float64
    var y: Float64
    
    # Constructor
    fn __init__(out self, x: Float64, y: Float64):
        self.x = x
        self.y = y
    
    # Method
    fn distance(self, other: Point) -> Float64:
        var dx = self.x - other.x
        var dy = self.y - other.y
        return (dx**2 + dy**2)**0.5
    
    # Mutable method
    fn translate(mut self, dx: Float64, dy: Float64):
        self.x += dx
        self.y += dy
    
    # Destructor (v1.0: __deinit__)
    fn __deinit__(deinit self):
        # Cleanup code
        pass
```

### 6.2 Struct Inheritance and Traits

```mojo
# Implementing traits
struct Circle(Equatable, Stringable):
    var radius: Float64
    
    # Required by Equatable
    fn __eq__(self, other: Circle) -> Bool:
        return self.radius == other.radius
    
    # Required by Stringable
    fn __str__(self) -> String:
        return "Circle(r=" + String(self.radius) + ")"

# Conditional conformance (v1.0)
struct Container[T: AnyType](Movable where conforms_to(T, Movable)):
    var data: T
```

### 6.3 Fieldwise Initialization

```mojo
@fieldwise_init
struct Vector3:
    var x: Float64
    var y: Float64
    var z: Float64

# Automatic constructor generated
var v = Vector3(1.0, 2.0, 3.0)
```

### 6.4 Static and Class Methods

```mojo
struct Math:
    @staticmethod
    fn pi() -> Float64:
        return 3.14159265359
    
    @staticmethod
    fn max[T: Comparable](a: T, b: T) -> T:
        return a if a > b else b
```

---

## 7. Traits

### 7.1 Trait Declaration

```mojo
trait Drawable:
    """Objects that can be drawn."""
    
    # Required method (no implementation)
    fn draw(self):
        ...
    
    # Optional method (with default implementation)
    fn area(self) -> Float64:
        return 0.0

trait Movable:
    fn __moveinit__(out self, owned existing: Self):
        ...

trait Copyable:
    fn __copyinit__(out self, existing: Self):
        ...

trait Deinitable:  # v1.0: renamed from ImplicitlyDestructible
    fn __deinit__(deinit self):
        ...
```

### 7.2 Built-in Traits

| Trait | Description | Methods |
|-------|-------------|---------|
| `AnyType` | Top trait (all types) | None |
| `Movable` | Can be moved | `__moveinit__` |
| `Copyable` | Can be copied | `__copyinit__` |
| `ImplicitlyCopyable` | Can be implicitly copied | `__copyinit__` |
| `Deinitable` | Has destructor (v1.0) | `__deinit__` |
| `Equatable` | Can be compared for equality | `__eq__` |
| `Comparable` | Can be ordered | `__lt__`, `__le__`, `__gt__`, `__ge__` |
| `Hashable` | Can be hashed | `__hash__` |
| `Stringable` | Can be converted to string | `__str__` |
| `Writable` | Can be written to writer | `write_to` |
| `Sized` | Has size/length | `__len__` |
| `Iterable` | Can be iterated | `__iter__` |
| `Iterator` | Is an iterator | `__next__`, `__has_next__` |
| `CollectionElement` | Can be in collections | Various |
| `KeyElement` | Can be dict key | `__hash__`, `__eq__` |
| `Intable` | Can convert to Int | `__int__` |
| `Floatable` | Can convert to Float | `__float__` |
| `Indexable` | Supports indexing | `__getitem__` |

---

## 8. Standard Library APIs

### 8.1 Core Collections

#### Array (Fixed-size)

```mojo
from std.collections import Array

# Construction
var arr = Array[Int, 5]()                    # Default constructed
var arr2 = Array[Int, 3](1, 2, 3)             # With initial values
var arr3: Array[Int, _] = [1, 2, 3]           # Type inference

# Properties
arr.length                                    # Number of elements (v1.0: size -> length)

# Indexing
arr[0]                                       # Get element
arr[0] = 10                                  # Set element

# Methods
arr.copy()                                   # Copy array
arr.unsafe_ptr()                             # Get raw pointer
```

#### List (Dynamic)

```mojo
from std.collections import List

# Construction
var lst = List[Int]()                        # Empty list
var lst2 = List[Int](capacity=100)           # With capacity
var lst3: List = [1, 2, 3]                   # From literal (v1.0: now constructs Array, use explicit type)

# Properties
len(lst)                                     # Number of elements
lst.capacity()                               # Current capacity (v1.0: now method)

# Methods
lst.append(value)                            # Add element
lst.extend(other)                            # Extend with iterable
lst.insert(index, value)                     # Insert at index
lst.pop()                                    # Remove and return last
lst.pop(index)                               # Remove at index
lst.remove(value)                            # Remove first occurrence
lst.clear()                                  # Remove all elements
lst.clear_with(destroy_func)                 # Clear with custom destructor (v1.0)
lst.find(value)                              # Find index (raises if not found)
lst.try_index(value)                         # Find index (returns Optional)
lst.resize(new_length)                       # Resize (v1.0: new_size -> new_length)
lst.shrink(new_length)                         # Shrink capacity
lst.copy()                                   # Shallow copy
lst.reverse()                                # Reverse in place
lst.sort()                                   # Sort in place
lst.deinit_with(func)                        # Destroy with function (v1.0)

# Iteration
for item in lst:                             # By reference
for item in lst^:                            # Consuming (takes ownership)
```

#### Dict (Hash Map)

```mojo
from std.collections import Dict

# Construction
var d = Dict[String, Int]()                  # Empty dict
var d2 = Dict[String, Int]({"a": 1})         # With initial values

# Properties
len(d)                                       # Number of entries

# Access
d["key"]                                     # Get (raises if missing)
d.get("key", default=0)                      # Get with default
d.setdefault("key", default=0)               # Set if missing

# Methods
d.insert(key, value)                         # Insert, returns displaced (v1.0)
d.update(other)                              # Update with other dict
d.pop(key)                                   # Remove and return
d.pop(key, default)                          # Remove with default
d.clear()                                    # Remove all
d.clear_with(destroy_func)                   # Clear with destructor (v1.0)
d.keys()                                     # Iterator over keys
d.values()                                   # Iterator over values
d.items()                                    # Iterator over (key, value)
d.take_items()                               # Consuming iterator (v1.0: renamed from take)

# Membership
"key" in d                                   # Check key exists
```

#### Set

```mojo
from std.collections import Set

# Construction
var s = Set[Int]()                           # Empty set
var s2 = Set[Int]([1, 2, 3])                 # From iterable

# Methods
s.add(element)                               # Add element
s.remove(element)                            # Remove (raises if missing)
s.discard(element)                           # Remove (no error)
s.pop()                                      # Remove and return arbitrary
s.clear()                                    # Remove all
s.clear_with(destroy_func)                   # Clear with destructor (v1.0)
s.union(other)                               # Union
s.intersection(other)                        # Intersection
s.difference(other)                          # Difference
s.symmetric_difference(other)                  # Symmetric difference

# Operators
s1 | s2                                      # Union
s1 & s2                                      # Intersection
s1 - s2                                      # Difference
s1 ^ s2                                      # Symmetric difference

# Membership
element in s                                 # Check membership
```

#### Optional

```mojo
from std.collections import Optional

# Construction
var opt: Optional[Int] = None                # Empty
var opt2 = Optional(42)                      # With value
var opt3: Optional[Int] = 42                 # Implicit conversion

# Methods
opt.is_none()                                # Check if None
opt.is_some()                                # Check if has value
opt.value()                                  # Get value (raises if None)
opt.take()                                   # Take value (consuming)
opt.unwrap[T]()                              # Unwrap as T (v1.0: renamed from take[T])
opt.map(func)                                # Transform if Some
opt.and_then(func)                           # Chain operations
opt.or_else(default)                         # Provide default
opt.deinit_with(func)                        # Destroy with function (v1.0)
opt.deinit_assert_empty()                    # Assert empty and destroy (v1.0)

# Pattern matching
if opt:
    print(opt.value())                       # Safe inside if
```

#### Span (View)

```mojo
from std.collections import Span, MutSpan, ImmSpan

# Construction
var span = Span(lst)                         # From list
var span2 = Span(unsafe_ptr=ptr, length=n)   # From pointer (v1.0: ptr -> unsafe_ptr)
var span3 = arr.as_span()                    # From array

# Properties
span.length                                  # Number of elements
span.is_empty()                              # Check if empty

# Indexing
span[i]                                      # Get element
span[start:end]                              # Slice (v1.0: stricter bounds checking)

# Methods
span.first()                                 # First element
span.last()                                  # Last element
span.as_imm()                                # Convert to immutable (v1.0: renamed from as_immutable)
span.unsafe_ptr()                            # Get raw pointer
span.fill(value)                             # Fill with value
span.copy_from(other)                        # Copy from other span
span.find(value)                             # Find element
span.reverse()                               # Reverse view
```

### 8.2 String APIs

```mojo
from std.collections import String, StringSpan

# Construction
var s = String("hello")                      # From literal
var s2 = String(42)                          # From number
var s3 = String.format("{}", value)          # Formatted

# Properties
s.length                                     # Number of bytes (UTF-8)
s.byte_length()                            # Same as length
s.count_codepoints()                         # Number of Unicode scalars
s.count_graphemes()                          # Number of user-perceived characters (v1.0: default iteration)
s.is_empty()                                 # Check if empty

# Indexing (v1.0: stricter bounds)
s[byte=i]                                    # Byte at offset
s[codepoint=i]                               # Unicode scalar
s[grapheme=i]                                # User-perceived character
s[i:j]                                       # Byte slice

# Iteration (v1.0: yields graphemes by default)
for char in s:                               # Grapheme clusters
for cp in s.codepoints():                    # Unicode scalars
for byte in s.bytes():                       # Raw bytes

# Methods
s.append(other)                              # Append string
s.extend(other)                              # Extend with chars
s.insert(index, char)                        # Insert character
s.find(substring)                            # Find substring
s.rfind(substring)                           # Find from right
s.startswith(prefix)                         # Check prefix
s.endswith(suffix)                           # Check suffix
s.strip()                                    # Remove whitespace
s.lstrip()                                   # Remove leading whitespace
s.rstrip()                                   # Remove trailing whitespace
s.split(sep)                                 # Split into list
s.join(iterable)                             # Join with separator
s.replace(old, new)                          # Replace substring
s.lower()                                    # To lowercase
s.upper()                                    # To uppercase
s.is_digit()                                 # Check if all digits
s.is_alpha()                                 # Check if all letters
s.is_alnum()                                 # Check if alphanumeric
s.to_int()                                   # Parse as integer
s.to_float()                                 # Parse as float
s.as_span()                                  # As StringSpan
s.copy()                                     # Copy string
```

### 8.3 Numeric APIs

```mojo
from math import sqrt, sin, cos, tan, exp, log, pow
from math import pi, e, inf, nan

# Constants
pi                                           # 3.14159...
e                                            # 2.71828...
inf                                          # Infinity
nan                                          # Not a number

# Functions
sqrt(x)                                      # Square root
sin(x), cos(x), tan(x)                       # Trigonometric
asin(x), acos(x), atan(x)                    # Inverse trig
sinh(x), cosh(x), tanh(x)                    # Hyperbolic
exp(x)                                       # Exponential
log(x)                                       # Natural log
log2(x), log10(x)                            # Log base 2, 10
pow(x, y)                                    # Power
abs(x)                                       # Absolute value
min(a, b), max(a, b)                         # Min/max
floor(x), ceil(x), trunc(x), round(x)        # Rounding
hypot(x, y)                                  # Hypotenuse
expm1(x)                                     # exp(x) - 1
```

### 8.4 SIMD Operations

```mojo
from std.builtin import SIMD

# Construction
var vec = SIMD[DType.float32, 4](1.0, 2.0, 3.0, 4.0)
var zeros = SIMD[DType.int32, 8].splat(0)     # Broadcast value

# Arithmetic (element-wise)
vec + other                                  # Addition
vec - other                                  # Subtraction
vec * other                                  # Multiplication
vec / other                                  # Division
vec // other                                 # Floor division
vec % other                                  # Modulo

# Comparison (element-wise, returns mask)
vec == other
vec != other
vec < other
vec <= other
vec > other
vec >= other

# Bitwise
vec & other                                  # AND
vec | other                                  # OR
vec ^ other                                  # XOR
~vec                                         # NOT

# Reductions
vec.reduce_add()                             # Sum all elements
vec.reduce_mul()                             # Product
vec.reduce_min()                             # Minimum
vec.reduce_max()                             # Maximum
vec.reduce_and()                             # AND reduction
vec.reduce_or()                              # OR reduction
vec.reduce_xor()                             # XOR reduction

# Shuffles and swizzles
vec.shuffle[indices...]()                    # Reorder elements
vec.interleave(other)                        # Interleave elements
vec.deinterleave()                           # Deinterleave

# Conversions
vec.cast[DType.int32]()                      # Cast to different dtype
vec.to_bits()                                # Bit representation
```

### 8.5 Range

```mojo
from std.builtin import range

# Construction (v1.0: unified dtype-parameterized)
range(stop)                                  # 0 to stop-1
range(start, stop)                           # start to stop-1
range(start, stop, step)                     # With step

# Properties
r.start                                      # Start value
r.stop                                       # Stop value
r.step                                       # Step value
len(r)                                       # Number of elements (always Int)

# Reversal
reversed(r)                                  # Reverse range

# Iteration
for i in range(10):                          # Standard iteration
for i in reversed(range(10)):                # Reverse iteration
```

### 8.6 I/O Operations

```mojo
from std.io import open, FileHandle, stdout, stderr, stdin

# File operations
var f = open("file.txt", "r")                # Open for reading
var f2 = open("file.txt", "w")               # Open for writing
var f3 = open("file.txt", "a")               # Open for append
var f4 = open("file.txt", "rw")              # Open for read/write

# Context manager
with open("file.txt", "r") as f:
    data = f.read()

# FileHandle methods
f.read()                                     # Read entire file
f.read(size)                                 # Read n bytes
f.readline()                                 # Read one line
f.readlines()                                # Read all lines
f.write(data)                                # Write string
f.writelines(lines)                          # Write multiple lines
f.seek(offset, whence)                       # Seek position (v1.0: Int offset)
f.tell()                                     # Current position
f.flush()                                    # Flush buffer
f.close()                                    # Close file
f.__enter__(), f.__exit__()                  # Context manager protocol

# Standard streams
print("hello")                               # Print to stdout
print("hello", file=stderr)                  # Print to stderr
print("hello", end="")                       # No newline
print("hello", sep=", ")                     # Custom separator

# Formatting
from std.format import format, StringWriter

var s = format("{}", value)                  # Format to string
var writer = StringWriter()
writer.write("{}", value)
var result = writer.get_string()
```

### 8.7 OS Operations

```mojo
from std.os import getenv, setenv, chdir, getcwd, listdir, mkdir, remove, rename

getenv("PATH")                               # Get environment variable
setenv("KEY", "value")                       # Set environment variable
chdir("/path")                               # Change directory (v1.0)
getcwd()                                     # Current directory
listdir("/path")                             # List directory contents
mkdir("/path")                               # Create directory
remove("/path")                              # Remove file
rename("/old", "/new")                       # Rename file
```

### 8.8 Time

```mojo
from time import now, sleep

var start = now()                            # Current time (nanoseconds)
sleep(1.0)                                   # Sleep for seconds
sleep(1000)                                  # Sleep for milliseconds
```

---

## 9. Memory Management

### 9.1 Pointer Operations

```mojo
from std.memory import Pointer, OwnedPointer, ArcPointer

# Pointer construction
var ptr = Pointer[Int].alloc(10)             # Allocate memory
var ptr2 = Pointer[Int].address_of(value)    # Get address of variable

# Safe operations
ptr[0]                                       # Index (bounds checked in debug)
ptr.length                                   # Get length if known

# Unsafe operations (v1.0: prefixed with unsafe_)
ptr.unsafe_load()                            # Load value
ptr.unsafe_store(value)                      # Store value
ptr.unsafe_offset(n)                         # Pointer arithmetic (v1.0: + -> unsafe_offset)
ptr.unsafe_gather(indices)                   # Gather elements
ptr.unsafe_scatter(values, indices)          # Scatter elements
ptr.unsafe_as_noalias()                      # Mark as no-alias
ptr.unsafe_memcpy(dest, src, count)          # Copy memory
ptr.unsafe_free()                            # Free memory

# Allocation (v1.0: new alloc package)
from std.memory.alloc import alloc, free, Allocation

var alloc_result = alloc[Int](10)            # Allocate
var data = alloc_result.unsafe_ptr()         # Get pointer
free(alloc_result)                           # Free allocation

# Owned pointer
var owned = OwnedPointer[Int](42)            # Owns memory
var val = owned.into_inner()                 # Take ownership (v1.0: renamed from take)
var alloc = owned.unsafe_take_allocation()     # Get allocation (v1.0: renamed from steal_data)

# Reference counted
var shared = ArcPointer[Int](42)             # Reference counted
var ref = shared.copy()                      # Increment count
```

### 9.2 Memory Traits and Types

| Type/Trait | Description |
|------------|-------------|
| `AddressSpace` | Memory address space (GENERIC, SHARED, etc.) |
| `Origin` | Lifetime tracking |
| `ImmOrigin` | Immutable origin |
| `MutOrigin` | Mutable origin |
| `UntrackedOrigin` | No lifetime tracking |
| `UnsafeAnyOrigin` | Unsafe escape hatch |

---

## 10. Control Flow

### 10.1 If Statements

```mojo
if condition:
    pass
elif other_condition:
    pass
else:
    pass

# Ternary conditional
var result = value if condition else default

# Inline if (ternary expression)
var x = a if a > b else b
```

### 10.2 Loops

```mojo
# For loop
for i in range(10):
    pass

for item in iterable:
    pass

for i, item in enumerate(iterable):
    pass

# While loop
while condition:
    pass

# Loop with else (executes if no break)
for i in range(10):
    if condition:
        break
else:
    print("No break")

# Continue and break
for i in range(100):
    if i < 10:
        continue
    if i > 20:
        break
    print(i)
```

### 10.3 Context Managers

```mojo
with resource as r:
    use(r)
# r is cleaned up

# Multiple context managers
with open("a") as f1, open("b") as f2:
    pass

# Custom context manager
struct ManagedResource:
    fn __enter__(self) -> Self:
        return self
    
    fn __exit__(self):
        self.cleanup()
```

---

## 11. Error Handling

### 11.1 Raising Errors

```mojo
def risky() raises:
    raise Error("Something went wrong")

def risky_with_trace() raises:
    raise Error("Message").with_stack_trace()
```

### 11.2 Handling Errors

```mojo
try:
    risky()
except Error as e:
    print("Error:", e)
except OtherError:
    print("Other error")
except:
    print("Any error")
else:
    print("No error occurred")
finally:
    print("Always runs")

# Re-raising
try:
    risky()
except Error as e:
    raise  # Re-raise same error
    raise Error("Wrapped") from e  # Chain errors
```

### 11.3 Error Type

```mojo
from std.builtin import Error

# Construction
var e = Error("message")
var e2 = Error("message").with_stack_trace()

# Properties
e.message()                                  # Error message
e.has_stack_trace()                          # Has trace?
e.get_stack_trace()                          # Get trace
```

---

## 12. Decorators

### 12.1 Built-in Decorators

| Decorator | Purpose | Applies To |
|-----------|---------|------------|
| `@staticmethod` | Static method | struct methods |
| `@fieldwise_init` | Generate field-based constructor | struct |
| `@value` | Generate value semantics | struct |
| `@register_passable` | Pass in register | struct |
| `@align(N)` | Set alignment | struct, field |
| `@deprecated` | Mark as deprecated | any |
| `@always_inline` | Force inline | function |
| `@never_inline` | Prevent inline | function |
| `@export` | Export symbol | function |
| `@no_inline` | Prevent inline | function |
| `@parameter` | Compile-time parameter | function |
| `@__copy_constructor` | Copy constructor | struct |
| `@__move_constructor` | Move constructor | struct |
| `@explicit_destroy` | Explicit destruction (v1.0: deprecated) | struct |

### 12.2 Usage Examples

```mojo
@fieldwise_init
struct Point:
    var x: Float64
    var y: Float64

@value
struct CopyablePoint:
    var x: Float64
    var y: Float64

@staticmethod
fn utility():
    pass

@always_inline
fn hot_function():
    pass

@deprecated("Use new_function instead")
fn old_function():
    pass
```

---

## 13. Metaprogramming

### 13.1 Compile-Time Execution

```mojo
# Compile-time constant
alias ARRAY_SIZE = 100

# Compile-time function
comptime alias SQUARED = compute_square(10)

fn compute_square(n: Int) -> Int:
    return n * n

# Compile-time if
comptime if is_gpu_target():
    # GPU-specific code
else:
    # CPU-specific code

# Compile-time assert
comptime assert ARRAY_SIZE > 0
```

### 13.2 Reflection

```mojo
from std.reflection import reflect

# Type reflection
comptime info = reflect[MyStruct]
info.name                                     # Type name
info.field["x"].T                             # Field type (v1.0: renamed from field_type)
info.field_at[0].T                            # Field by index

# Trait checking
conforms_to(T, Movable)
is_trivially_deletable[T]()                   # Check destructor (v1.0: renamed)

# Type functions
TypeList.of[Int, Bool, Float64]               # Create type list (v1.0: infers Trait)
TL.all_conforms_to[Movable]()                   # Check all conform
```

### 13.3 Parameters

```mojo
# Compile-time parameter
fn process[size: Int](data: SIMD[DType.float32, size]):
    pass

# Type parameter with constraint
fn sort[T: Comparable](mut list: List[T]):
    pass

# Variadic parameters
fn tuple_of[*Ts: AnyType](*args: *Ts) -> Tuple[*Ts]:
    return args

# Where clause
fn scale[sc: Int]() where sc > 0:
    pass

# Where with message (v1.0)
fn scale[sc: Int]() where (sc > 1, "must be > 1"):
    pass
```

---

## 14. Python Interoperability

### 14.1 Importing Python

```mojo
from python import Python

# Import module
var np = Python.import_module("numpy")
var pd = Python.import_module("pandas")

# Use Python objects
var arr = np.array([1, 2, 3])
var result = np.sum(arr)

# PythonObject operations (v1.0: 12x faster via protocols)
var a = PythonObject(5)
var b = PythonObject(10)
var c = a + b            # Uses PyNumber_Add
var d = a < b            # Uses PyObject_RichCompare
var e = a in arr         # Uses PySequence_Contains

# Call Python functions
result = py_func.call(arg1, arg2)
result = py_func(arg1, arg2)  # Same
```

### 14.2 NumPy Interop (v1.0+)

```mojo
from std.python.numpy import copy_to_numpy_array, from_numpy_array

# Mojo to NumPy
var mojo_list = List[Float64](1.0, 2.0, 3.0)
var np_array = copy_to_numpy_array(mojo_list)

# NumPy to Mojo (zero-copy borrow)
var np_arr = numpy_array  # Python numpy array
var mojo_span = from_numpy_array(np_arr)
```

### 14.3 Creating Python Modules

```mojo
from std.python.bindings import PythonModuleBuilder, PythonTypeBuilder

# Create module
var module = PythonModuleBuilder("my_module")

# Add function
module.def_py_c_function["my_func", func](
    doc="Documentation"
)

# Add type
var type_builder = PythonTypeBuilder[MyStruct]("MyType")
type_builder.def_method["method_name", MyStruct.method]()
```

---

## 15. GPU Programming

### 15.1 MAX Engine (Moved to max package in v1.0)

```mojo
from max.gpu.host import DeviceContext, Device
from max.gpu.memory import shared_memory
from max.gpu.sync import barrier

# Device management
var device = Device(0)                         # Get GPU 0
var ctx = device.create_context()              # Create context

# Memory allocation
var gpu_buffer = ctx.allocate[DType.float32](1024)

# Kernel launch (moved to max package)
ctx.enqueue_function[kernel](
    gpu_buffer, size,
    grid_dim=(blocks,),
    block_dim=(threads,)
)

# Synchronization
ctx.synchronize()
```

### 15.2 GPU Types (in max package)

```mojo
from max.gpu import thread_idx, block_idx, block_dim, grid_dim

# Thread indexing
var global_id = block_idx.x * block_dim.x + thread_idx.x

# Shared memory
var shared = shared_memory[DType.float32, 256]()

# Barriers
barrier()                                     # Block-level sync
```

---

## 16. C FFI

### 16.1 External Calls

```mojo
from std.ffi import external_call, OwnedDLHandle, c_char, c_int, c_float

# Direct external call
var result = external_call["function_name", ReturnType](arg1, arg2)

# Variadic external call (v1.0)
var fd = external_call["open", c_int, num_fixed_args=2](
    path.as_c_string_slice().unsafe_ptr(),
    c_int(flags),
    c_int(0o666)
)

# Load shared library
var lib = OwnedDLHandle("libm.so")

# Get function (v1.0: simplified)
var sqrt_func = lib.get_function[Float64]("sqrt")
var result = sqrt_func(2.0)

# Get symbol
var symbol = lib.get_symbol("symbol_name")
```

### 16.2 C Types

| Mojo Type | C Type |
|-----------|--------|
| `c_char` | `char` |
| `c_short` | `short` |
| `c_int` | `int` |
| `c_long` | `long` |
| `c_longlong` | `long long` |
| `c_float` | `float` |
| `c_double` | `double` |
| `c_void` | `void` |
| `c_size_t` | `size_t` |
| `c_ssize_t` | `ssize_t` |
| `CStringSlice` | `const char*` |
| `Pointer[C]` | `C*` |

---

## 17. Command Line Interface

### 17.1 mojo Command

```bash
# Run a file
mojo run file.mojo
mojo file.mojo                    # Shorthand

# Build executable
mojo build file.mojo              # Creates file
mojo build file.mojo -o output    # Named output
mojo build --emit shared-lib file.mojo  # Shared library

# REPL
mojo                              # Interactive mode

# Package management
mojo package dir/                 # Create package
mojo test                         # Run tests

# Documentation
mojo doc file.mojo                # Generate docs

# Formatting
mojo format file.mojo             # Format code

# LSP server
mojo-lsp-server                   # Start LSP
mojo-lsp-server -check-docstrings # With docstring checking (opt-in)
```

### 17.2 Compiler Flags

| Flag | Description |
|------|-------------|
| `-o <file>` | Output file |
| `-I <path>` | Include path |
| `-D <name>` | Define macro |
| `-D ASSERT=all` | Enable all assertions |
| `-O0`, `-O1`, `-O2`, `-O3` | Optimization level |
| `--emit <format>` | Output format (shared-lib, etc.) |
| `--fp-mode <mode>` | Floating point mode (v1.0: contract=fast/off) |
| `--lld-path <path>` | LLD linker path (v1.0) |
| `--version` | Show version |

### 17.3 Environment Variables

| Variable | Description |
|----------|-------------|
| `MODULAR_HOME` | Installation directory |
| `MODULAR_DEBUG` | Debug options (stack-trace-on-error) |
| `MODULAR_CRASH_REPORTING_ENABLED` | Crash reporting |
| `MODULAR_TELEMETRY_ENABLED` | Telemetry |

---

## 18. Special Methods

### 18.1 Lifecycle Methods

| Method | Convention | Description |
|--------|------------|-------------|
| `__init__` | `out self` | Constructor |
| `__copyinit__` | `out self, existing` | Copy constructor |
| `__moveinit__` | `out self, owned existing` | Move constructor |
| `__deinit__` | `deinit self` | Destructor (v1.0: renamed from `__del__`) |

### 18.2 Operator Methods

| Method | Operator | Description |
|--------|----------|-------------|
| `__add__` | `+` | Addition |
| `__sub__` | `-` | Subtraction |
| `__mul__` | `*` | Multiplication |
| `__truediv__` | `/` | True division |
| `__floordiv__` | `//` | Floor division |
| `__mod__` | `%` | Modulo |
| `__pow__` | `**` | Power |
| `__and__` | `&` | Bitwise AND |
| `__or__` | `\|` | Bitwise OR |
| `__xor__` | `^` | Bitwise XOR |
| `__lshift__` | `<<` | Left shift |
| `__rshift__` | `>>` | Right shift |
| `__eq__` | `==` | Equality |
| `__ne__` | `!=` | Inequality |
| `__lt__` | `<` | Less than |
| `__le__` | `<=` | Less or equal |
| `__gt__` | `>` | Greater than |
| `__ge__` | `>=` | Greater or equal |
| `__neg__` | `-a` | Negation |
| `__invert__` | `~a` | Bitwise NOT |
| `__iadd__` | `+=` | In-place add |
| `__isub__` | `-=` | In-place subtract |
| `__imul__` | `*=` | In-place multiply |
| `__itruediv__` | `/=` | In-place divide |
| `__ifloordiv__` | `//=` | In-place floor divide |
| `__imod__` | `%=` | In-place modulo |
| `__ipow__` | `**=` | In-place power |
| `__iand__` | `&=` | In-place AND |
| `__ior__` | `\|=` | In-place OR |
| `__ixor__` | `^=` | In-place XOR |
| `__ilshift__` | `<<=` | In-place left shift |
| `__irshift__` | `>>=` | In-place right shift |

### 18.3 Container Methods

| Method | Description |
|--------|-------------|
| `__len__` | Length (`len()`) |
| `__getitem__` | Indexing (`[]`) |
| `__setitem__` | Index assignment |
| `__contains__` | Membership (`in`) |
| `__iter__` | Iterator |
| `__next__` | Next item |
| `__has_next__` | Has more items |
| `__reversed__` | Reverse iteration |
| `__hash__` | Hash value |

### 18.4 Conversion Methods

| Method | Description |
|--------|-------------|
| `__str__` | String conversion |
| `__repr__` | Representation |
| `__int__` | Integer conversion |
| `__float__` | Float conversion |
| `__bool__` | Boolean conversion |
| `__index__` | Index conversion |

### 18.5 Context Manager Methods

| Method | Description |
|--------|-------------|
| `__enter__` | Enter context |
| `__exit__` | Exit context |

---

## 19. Conventions and Sigils

### 19.1 Argument Conventions

| Convention | Syntax | Meaning |
|------------|--------|---------|
| `imm` | `value: T` (default) | Immutable borrow |
| `mut` | `mut value: T` | Mutable borrow |
| `owned` | `owned value: T` | Take ownership |
| `out` | `out value: T` | Output parameter |
| `deinit` | `deinit value: T` | Destructive transfer |
| `var` | `var value: T` | Independent owned copy |

### 19.2 Special Sigils

| Sigil | Meaning | Example |
|-------|---------|---------|
| `^` | Transfer ownership | `func(value ^)` |
| `*` | Unpack iterables | `func(*args)` |
| `**` | Unpack mappings | `func(**kwargs^)` |
| `...` | Ellipsis/variadic | `*args: *Ts...` |
| `->` | Return type | `def f() -> T:` |
| `=>` | Not used in Mojo | N/A |
| `:` | Type annotation | `x: Int` |
| `;` | Statement separator | `x = 1; y = 2` |
| `@` | Decorator | `@decorator` |
| `` ` `` | Escape identifier | `` `struct` `` |

### 19.3 Self Parameter Conventions

```mojo
fn method(self):                    # Immutable borrow (default)
fn method(imm self):                # Explicit immutable
fn method(mut self):                 # Mutable borrow
fn method(out self):                # Constructor pattern
fn method(deinit self):              # Destructor
```

---

## 20. Literals

### 20.1 Integer Literals

```mojo
42              # Decimal
0b101010        # Binary (prefix 0b)
0o52            # Octal (prefix 0o)
0x2A            # Hexadecimal (prefix 0x)

42_000_000      # Underscores for readability
```

### 20.2 Float Literals

```mojo
3.14            # Standard notation
3.14e10         # Scientific notation
3.14E-10        # Negative exponent
.5              # Leading decimal
5.              # Trailing decimal
```

### 20.3 String Literals

```mojo
"hello"         # Double-quoted
'hello'         # Single-quoted (same)
"hello\nworld"  # Escape sequences
"hello" "world" # Implicit concatenation

# Escape sequences
\n              # Newline
\t              # Tab
\\              # Backslash
\"              # Double quote
\'              # Single quote
\0              # Null
\xHH            # Hex byte
\u{HHHH}        # Unicode scalar

# Raw strings (no escapes)
r"hello\nworld" # Literal \n characters
```

### 20.4 T-Strings (Template Strings)

```mojo
t"value is {x}"                 # Interpolated
t"value is {x:.2f}"             # With format spec
t"1 + 1 = {1 + 1}"             # Expression interpolation

# Custom formatting
t"{value}"                      # Default format
t"{value!r}"                    # Representation
t"{value!s}"                    # String conversion
```

### 20.5 Boolean Literals

```mojo
True            # Boolean true
False           # Boolean false
```

### 20.6 None Literal

```mojo
None            # Absence of value
```

### 20.7 Self Literal

```mojo
Self            # Reference to current type
```

### 20.8 List Literals

```mojo
[1, 2, 3]       # Array literal (v1.0: constructs Array, not List)
[1, 2.0, 3]     # Mixed types (inferred as common type)
```

### 20.9 Tuple Literals

```mojo
(1, 2, 3)       # Tuple of 3 elements
(1,)            # Single-element tuple (comma required)
()              # Empty tuple
1, 2, 3         # Bare tuple (no parentheses)
```

### 20.10 Dictionary Literals

```mojo
{"a": 1, "b": 2}               # Dict literal
{key: value for key, value in pairs}  # Dict comprehension
```

### 20.11 Set Literals

```mojo
{1, 2, 3}                       # Set literal
{1, 2, 3, 3, 3}                 # Duplicates removed
```

---

## Appendix A: Stability Status (v1.0)

### Fully Stable APIs

These APIs are guaranteed not to change in backward-incompatible ways:

- **Traits:** `Deinitable`, `Movable`, `Copyable`, `ImplicitlyCopyable`
- **Types:** `Array`, `List`, `Span`, `String`, `Bool`, `Optional` (partial)

### Stability Guarantees

- Source compatibility guaranteed for stable APIs
- ABI not yet stable
- Deprecated APIs remain available with warnings

---

## Appendix B: Breaking Changes in 1.0

### Major Changes from Pre-1.0

1. **`fn` keyword deprecated** - Use `def` for all functions
2. **Variable declarations require `var`** - Implicit declarations deprecated
3. **`__del__` renamed to `__deinit__`** - Destructor method
4. **`size` renamed to `length`** - Throughout standard library
5. **`InlineArray` renamed to `Array`** - Fixed-size array type
6. **`StringSlice` renamed to `StringSpan`** - String view type
7. **`read` renamed to `imm`** - Immutable convention
8. **Pointer types unified** - `UnsafePointer` merged into `Pointer`
9. **`imm` is default convention** - Not `mut`
10. **List literals construct `Array`** - Not `List`
11. **Negative indexing removed** - Explicit bounds required
12. **Import system overhauled** - More explicit resolution
13. **GPU APIs moved to `max` package** - No longer in `std`
14. **`Self` type required for methods** - Not custom types
15. **Lambda expressions added** - Anonymous functions

---

## Appendix C: Quick Reference Card

### Common Patterns

```mojo
# Variable declaration (v1.0: var required)
var x: Int = 5

# Function
def add(a: Int, b: Int) -> Int:
    return a + b

# Struct with fieldwise init
@fieldwise_init
struct Point:
    var x: Float64
    var y: Float64

# Trait
trait Drawable:
    fn draw(self):
        ...

# Generic function
fn process[T: Movable](value: T):
    pass

# Error handling
def risky() raises:
    raise Error("oops")

try:
    risky()
except Error as e:
    print(e)

# List operations
var lst = List[Int]()
lst.append(1)
for item in lst:
    print(item)

# String operations
var s = String("hello")
for grapheme in s:              # v1.0: graphemes by default
    print(grapheme)

# SIMD
var vec = SIMD[DType.float32, 4](1.0, 2.0, 3.0, 4.0)
var sum = vec.reduce_add()

# Pointer (v1.0: unified)
var ptr = Pointer[Int].alloc(10)
ptr.unsafe_store(42)
ptr.unsafe_free()

# Python interop
var np = Python.import_module("numpy")
```

---

*This reference guide is based on Mojo 1.0.0 released May 7, 2026. For the latest updates, consult the official documentation at https://mojolang.org/docs/*

---
