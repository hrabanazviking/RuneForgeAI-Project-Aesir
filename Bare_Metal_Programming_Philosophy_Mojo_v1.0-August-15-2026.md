# The Bare Metal Programming Philosophy in Mojo 1.0

(Bare_Metal_Programming_Philosophy_Mojo_v1.0-August-15-2026.md)

## A Comprehensive Technical Guide to Systems-Level Development Without an Operating System

---

# Table of Contents

**Part I: Foundations of Bare Metal Programming**

1. Introduction to Bare Metal Philosophy
2. The Mojo Language: Architecture and Design Principles
3. Understanding the Compilation Pipeline: From Mojo to Machine Code
4. Memory Model and Ownership Semantics

**Part II: Low-Level Primitives**

5. Pointer Types and Memory Manipulation
6. Memory Allocation Strategies in Freestanding Environments
7. The Foreign Function Interface (FFI) and C Interoperability
8. Inline Assembly and Compiler Intrinsics
9. Compile-Time Metaprogramming for Hardware Abstraction

**Part III: Practical Bare Metal Development**

10. Freestanding Environment Setup and Toolchain Configuration
11. Startup Code, Linker Scripts, and the C Runtime
12. Interrupt Handling and Exception Management
13. Peripheral Access and Memory-Mapped I/O
14. Building a Minimal Hardware Abstraction Layer

**Part IV: Case Studies and Advanced Topics**

15. Case Study: RP2040 Bare Metal Firmware in Pure Mojo
16. GPU and Accelerator Bare Metal Programming
17. Real-Time Constraints and Deterministic Execution
18. Debugging Bare Metal Mojo Programs
19. Performance Optimization at the Metal Level

**Part V: The Future of Bare Metal Mojo**

20. The Freestanding Standard Library Initiative
21. Emerging Hardware Targets and Cross-Compilation
22. Conclusion: The Unification of High-Level Ergonomics and Metal-Level Control

**Appendices**

A. Mojo 1.0 Language Reference Summary
B. Standard Library Modules for Systems Programming
C. Target Architecture Reference
D. Glossary of Terms

---

# Part I: Foundations of Bare Metal Programming

---

## Chapter 1: Introduction to Bare Metal Philosophy

### 1.1 Defining Bare Metal Programming

Bare metal programming represents the most fundamental layer of software development—the creation of programs that execute directly on hardware without the mediation of an operating system. In this paradigm, the programmer assumes complete responsibility for every aspect of system initialization, memory management, peripheral control, and resource coordination. There is no kernel to schedule threads, no filesystem to organize data, no standard library to provide convenience functions, and no runtime environment to manage exceptions or perform garbage collection.

The term "bare metal" derives from the notion that the software runs directly on the physical silicon, with no software abstraction layers interposed between the program logic and the hardware registers. This is the realm of firmware, bootloaders, operating system kernels, embedded systems, and high-performance computing kernels that demand deterministic, predictable execution with minimal overhead.

### 1.2 The Philosophical Imperative

The bare metal programming philosophy rests on several foundational principles that distinguish it from application-level development:

**Principle of Direct Control**: The programmer must have the ability to access any hardware resource directly, without abstractions that obscure or impede low-level operations. This includes memory-mapped I/O registers, interrupt controllers, cache management facilities, and specialized processor instructions.

**Principle of Zero-Cost Abstraction**: Any abstraction introduced by the programming language or its standard library must compile to machine code that is semantically equivalent to hand-written assembly, with no runtime overhead that would not exist in an equivalent C or assembly implementation.

**Principle of Predictable Execution**: Bare metal systems often operate in environments where timing guarantees are critical. The programming model must support deterministic execution with known worst-case latencies, without unpredictable pauses from garbage collection, dynamic dispatch, or runtime compilation.

**Principle of Explicit Resource Management**: All resources—memory, peripherals, interrupt vectors, DMA channels—must be managed explicitly by the programmer. The language should provide mechanisms for precise control over resource acquisition, utilization, and release, but should not impose automatic management strategies that might conflict with the requirements of the target environment.

**Principle of Minimal Runtime**: The executable should include only the code necessary to perform its intended function. There should be no mandatory runtime components, no hidden initialization routines, no implicit library dependencies that cannot be controlled or eliminated.

### 1.3 Why Mojo for Bare Metal?

Mojo emerges as a compelling choice for bare metal programming because it uniquely synthesizes three traditionally incompatible attributes:

First, **Pythonic expressiveness** provides a syntax that is clean, readable, and conducive to rapid development. The language borrows Python's familiar control flow, type annotations, and module system, lowering the barrier to entry for developers who might otherwise be intimidated by the syntactic density of C++ or Rust.

Second, **systems-level performance** places Mojo in the same performance class as C and Rust. The compiler leverages the MLIR (Multi-Level Intermediate Representation) framework and LLVM backend to generate highly optimized machine code. Benchmarks demonstrate that Mojo achieves performance parity with clang-compiled C code across a wide range of workloads, landing within ±13% and often matching C to the microsecond.

Third, **low-level hardware control** is baked into the language design from the ground up. Mojo provides direct access to pointers, inline assembly, compiler intrinsics, and memory-mapped I/O. The `sys` package exposes low-level system functionality, hardware capabilities, and compiler intrinsics. The `memory` package offers comprehensive pointer types and memory manipulation primitives.

This combination makes Mojo unique among modern programming languages: it is the first language that reads like Python but can generate code that runs on bare metal with no operating system, no runtime, and no performance penalty.

### 1.4 The Historical Context

The journey to bare metal Mojo has been rapid but significant. The language was announced in 2023 and has evolved through multiple pre-release versions. Mojo 1.0 was officially released on August 11, 2026, as part of the Modular 26.5 update, marking the first stable, production-ready release. This release represents the culmination of three years of development, with substantial work on language stabilization, type system refinement, and memory safety diagnostics.

The bare metal capabilities of Mojo have been demonstrated through community-driven projects, most notably a pure-Mojo firmware and peripheral SDK for the Raspberry Pi Pico (RP2040) microcontroller. This project showed that Mojo can generate bare metal binaries that are byte-for-byte identical in size to equivalent C code compiled with clang -O2—a complete blink program fitting in just 780 bytes.

### 1.5 Scope of This Guide

This guide is written for experienced systems programmers who understand the fundamentals of computer architecture, memory management, and low-level programming. Familiarity with C, C++, or Rust is assumed, as is basic knowledge of assembly language concepts. The guide assumes the reader has access to the Mojo 1.0 toolchain and is comfortable working with command-line tools, linker scripts, and hardware documentation.

---

## Chapter 2: The Mojo Language: Architecture and Design Principles

### 2.1 The MLIR Foundation

Mojo is built on the MLIR (Multi-Level Intermediate Representation) compiler framework, which is part of the LLVM ecosystem. MLIR provides a infrastructure for representing and transforming programs at multiple levels of abstraction, from high-level language constructs down to target-specific machine code.

The Mojo compilation pipeline follows this trajectory:

```
Mojo Source → MLIR Dialects → LLVM IR → Target Machine Code
```

This multi-level architecture is fundamental to Mojo's bare metal capabilities. Unlike languages that compile directly to LLVM IR, Mojo's MLIR foundation allows it to perform high-level optimizations that are aware of the semantics of the source language, while still leveraging LLVM's mature code generation infrastructure for the final lowering to machine code.

The MLIR framework also enables Mojo to target diverse hardware architectures—CPUs, GPUs, and specialized accelerators—using a unified compiler infrastructure. This is particularly relevant for bare metal programming, where the target may be an embedded microcontroller, a graphics processor, or a custom AI accelerator.

### 2.2 Type System Fundamentals

Mojo employs a static, strong type system that operates at compile time. Every variable, function parameter, and return value has a type that is known and checked at compilation time. This is in contrast to Python's dynamic typing, though Mojo does support optional dynamic typing for interoperability.

The fundamental types in Mojo include:

- **Integer types**: `Int8`, `Int16`, `Int32`, `Int64`, `UInt8`, `UInt16`, `UInt32`, `UInt64`
- **Floating-point types**: `Float16`, `Float32`, `Float64`
- **Boolean type**: `Bool`
- **SIMD types**: `SIMD[dtype, width]` for vectorized operations
- **Pointer types**: `Pointer`, `UnsafePointer`, `OwnedPointer`, `ArcPointer`
- **Reference types**: `Reference[T]` for borrowing
- **Struct types**: User-defined data structures
- **Trait types**: For defining shared behavior

The type system supports parametric polymorphism through compile-time parameters, which are similar to C++ template parameters or Rust generic parameters. This enables zero-cost abstractions where generic code is specialized at compile time for each concrete instantiation.

### 2.3 Ownership and Memory Safety

Mojo implements an ownership-based memory management model inspired by Rust, but with important differences that reflect Mojo's unique design goals.

The ownership model operates on these principles:

- **Each value has a single owner** at any given time. When the owner goes out of scope, the value is destroyed.
- **Values can be moved** from one owner to another, transferring ownership without copying.
- **Values can be borrowed** (via references) for temporary access without transferring ownership.
- **The compiler performs static analysis** to determine the last use of each value and inserts destructor calls at the appropriate points.

Unlike Rust, Mojo does not enforce strict borrowing rules at compile time. Instead, Mojo uses a more flexible approach where the compiler tracks "origins"—special values that represent the provenance of variables and references—to determine validity. This allows Mojo to maintain memory safety while providing more flexibility for systems programming.

For bare metal programming, this ownership model provides several critical advantages:

- **No garbage collector** means predictable execution with no pauses.
- **No reference counting overhead** for most operations (though `ArcPointer` provides reference counting when needed).
- **Explicit control over lifetimes** allows the programmer to manage memory in ways that align with hardware constraints.
- **Zero-cost abstractions** mean that ownership tracking is performed at compile time, with no runtime overhead.

### 2.4 Functions and Calling Conventions

Mojo supports two primary function declaration styles:

**`def` functions** are the default, providing flexibility similar to Python functions. They can raise exceptions, support keyword arguments, and have a more permissive type system.

**`fn` functions** are the performance-oriented variant, providing stricter type checking and enabling more aggressive compiler optimizations. `fn` functions cannot raise exceptions (unless explicitly annotated) and support the `@always_inline` decorator for forcing inlining.

For bare metal programming, `fn` functions are generally preferred because they:
- Eliminate exception handling overhead
- Enable more predictable code generation
- Support inlining for performance-critical code paths
- Provide stronger type guarantees

Mojo also supports the `abi` attribute for specifying calling conventions. The `abi("C")` attribute is particularly important for bare metal programming because it enables interoperability with C code and ensures compatibility with the C runtime's calling conventions. This is essential for:
- Calling into assembly startup code
- Interfacing with hardware initialization routines
- Maintaining ABI compatibility with system firmware

### 2.5 Structs and Data Layout

Structs are Mojo's primary mechanism for defining custom data types. A Mojo struct bundles data fields together with the methods that operate on that data.

Key features of Mojo structs for bare metal programming:

**Memory layout control**: Struct fields are laid out in memory in declaration order, with alignment determined by the platform's ABI. This predictable layout is essential for:
- Mapping structs to hardware register layouts
- Defining data structures that will be shared with assembly code
- Controlling cache line alignment for performance optimization

**Zero-cost abstraction**: Methods on structs are statically dispatched, with no virtual table overhead unless explicitly requested. This means that calling a method on a struct compiles to the same machine code as calling a free function with the struct as an argument.

**Compile-time parameters**: Structs can be parameterized with compile-time values, enabling:
- Type-safe hardware register definitions (e.g., `Pin[99]` is a compile-time error for invalid pin numbers)
- Size-optimized data structures based on compile-time constants
- Hardware-specific specializations without runtime overhead

**Destructors**: Structs can define `__del__()` methods that are called when the value is destroyed. This enables RAII (Resource Acquisition Is Initialization) patterns where resources are automatically released when the struct goes out of scope.

### 2.6 Traits and Generic Programming

Traits in Mojo define shared behavior that can be implemented by multiple types. They are similar to Rust traits or Haskell type classes.

For bare metal programming, traits enable:
- Generic hardware abstraction layers that work across different peripherals
- Compile-time polymorphism without runtime overhead
- Interface definitions for hardware drivers

The `@register_passable("trivial")` decorator can be applied to structs to indicate that they can be passed by value in registers rather than memory, which is critical for performance in bare metal contexts.

---

## Chapter 3: Understanding the Compilation Pipeline: From Mojo to Machine Code

### 3.1 The Mojo Compiler Architecture

The Mojo compiler is built on the MLIR framework and consists of several distinct stages:

**Frontend**: Parses Mojo source code, performs syntactic and semantic analysis, and generates an Abstract Syntax Tree (AST). This stage handles type checking, name resolution, and basic validation.

**MLIR Generation**: The AST is lowered to MLIR, specifically to a dialect that represents Mojo's high-level semantics. This includes representations of functions, structs, control flow, and ownership semantics.

**Optimization Passes**: The MLIR representation is transformed through a series of optimization passes. These passes are aware of Mojo's semantics and can perform high-level optimizations that would be difficult or impossible to express in LLVM IR alone.

**LLVM IR Lowering**: The optimized MLIR is lowered to LLVM IR, which is then processed by LLVM's optimization pipeline.

**Code Generation**: LLVM generates target-specific machine code, which is then assembled and linked into the final executable.

### 3.2 Emitting Intermediate Representations

Mojo provides several command-line options for inspecting the compilation pipeline, which is invaluable for bare metal development:

**`--emit=mlir`**: Emits the MLIR representation of the compiled code. This shows the high-level transformations performed by the Mojo compiler.

**`--emit=llvm`**: Emits LLVM IR. This is particularly useful for understanding how Mojo constructs map to LLVM primitives and for debugging code generation issues.

**`--emit=asm`**: Emits assembly code. This shows the final machine code that will be executed on the target.

The `compile_info` function provides programmatic access to compilation artifacts, including assembly code, LLVM IR, and object code. This can be used for:
- Runtime inspection of generated code
- Self-modifying code patterns
- Performance analysis and optimization

### 3.3 Target Specification and Cross-Compilation

Mojo supports cross-compilation through the `--target` option, which specifies the target triple for code generation. The target triple follows the standard LLVM format: `architecture-vendor-operating_system-environment`.

For bare metal programming, common target triples include:
- `thumbv6m-none-eabi`: ARM Cortex-M0/M0+ (used for RP2040)
- `riscv32-unknown-elf`: RISC-V 32-bit
- `aarch64-none-elf`: ARMv8-A
- `x86_64-none-elf`: x86-64

### 3.4 The RP2040 Retarget Pipeline

The RP2040 bare metal Mojo project demonstrates an ingenious approach to targeting architectures that are not directly supported by Mojo's bundled LLVM. The pipeline works as follows:

1. **Compile to RISC-V**: Mojo compiles the source to RISC-V 32-bit LLVM IR using `mojo build --emit=llvm --target=riscv32`. RISC-V is chosen because it shares the exact ILP32 little-endian data model of ARMv6-M.

2. **Retarget the IR**: The emitted LLVM IR is transformed by rewriting the target triple and data layout from `riscv32` to `thumbv6m-none-eabi`.

3. **IR Cleanup**: The retargeted IR is cleaned up by removing or transforming IR constructs that the system LLVM (version 18) does not understand, such as certain capture annotations, debug records, and float literals.

4. **Optimization and Code Generation**: The cleaned IR is processed by `opt -O2` and `llc -O2` to generate Cortex-M0+ object code.

5. **Linking**: The object code is linked with the startup code (`crt0`), linker script, bootloader (`boot2`), and `libgcc` using `arm-none-eabi-gcc`.

The entire retarget pipeline is itself implemented as a Mojo program, not a shell script, demonstrating the language's suitability for tooling and build automation.

### 3.5 Optimization Levels and Flags

Mojo supports optimization levels from 0 to 3 through the `--optimization-level` option (or `-O`, `--no-optimization` for level 0).

For bare metal programming, optimization level 2 (`-O2`) is typically the sweet spot, providing good performance while keeping compilation times reasonable and avoiding the code size increases that can occur at `-O3`.

The `-D KEY=VALUE` flag defines compile-time constants that can be accessed from code using the `sys` package. This is useful for:
- Configuring hardware parameters at compile time
- Enabling or disabling features for different builds
- Setting memory layout parameters

---

## Chapter 4: Memory Model and Ownership Semantics

### 4.1 The Mojo Memory Model

Mojo's memory model defines how programs interact with memory, including:
- The memory hierarchy (registers, cache, main memory)
- Memory ordering and synchronization
- The behavior of concurrent memory accesses

For bare metal programming, understanding the memory model is essential because:
- Memory-mapped I/O requires precise control over memory accesses
- Interrupt handlers must be aware of memory ordering constraints
- DMA operations require careful coordination with the memory subsystem

Mojo inherits the LLVM memory model, which provides:
- **Sequential consistency** for default operations
- **Acquire/release semantics** for atomic operations
- **Relaxed semantics** for performance-critical code

### 4.2 Origins and Lifetime Tracking

Mojo uses a concept called "origins" to track the validity of variables and references. An origin is a compile-time construct that represents the provenance of a value, indicating where it came from and when it becomes invalid.

The origin system enables Mojo to:
- Detect use-after-free errors at compile time
- Track the lifetime of references
- Ensure that moved values are not accessed after being moved
- Insert destructor calls at the correct points

For bare metal programming, origins are particularly important because:
- They enable safe manipulation of raw memory without requiring runtime checks
- They support zero-cost abstractions for resource management
- They provide compile-time guarantees about memory safety

### 4.3 Value Categories

Mojo distinguishes between several value categories:

**L-values**: Values that have a memory location and can appear on the left side of an assignment. Variables and dereferenced pointers are l-values.

**R-values**: Values that do not have a persistent memory location and can only appear on the right side of an assignment. Temporary values and the results of expressions are r-values.

**X-values**: Values that are about to expire and can be moved from. This is used for implementing move semantics.

Understanding value categories is essential for:
- Implementing efficient move operations
- Avoiding unnecessary copies
- Correctly managing resource lifetimes

### 4.4 Move Semantics

Mojo implements move semantics to enable efficient transfer of ownership without copying. When a value is moved:
- The source value becomes invalid (it can no longer be accessed)
- The destination value takes ownership of the resources
- No deep copy of the data occurs

Move semantics are particularly important for bare metal programming because:
- They enable efficient passing of large data structures
- They avoid unnecessary memory allocations
- They support zero-copy data transfer patterns

The `movable` trait indicates that a type supports move semantics. Most types in Mojo are implicitly movable, with the compiler synthesizing trivial move constructors when possible.

### 4.5 Destruction and Resource Release

Mojo uses static analysis to determine when values are no longer needed and inserts destructor calls at the point of last use. This is similar to Rust's drop semantics but with Mojo's unique ownership model.

The destruction process:
1. The compiler determines the last use of each value
2. At the point of last use, the destructor (`__del__`) is called
3. The memory occupied by the value is released

For bare metal programming, explicit control over destruction is essential for:
- Releasing hardware resources (e.g., DMA channels, interrupt vectors)
- Flushing caches before memory is deallocated
- Ensuring deterministic cleanup in interrupt handlers

### 4.6 Reference Types

Mojo provides reference types for borrowing values without taking ownership:

**`Reference[T]`**: A non-owning reference to a value of type `T`. References can be mutable or immutable and are subject to Mojo's origin tracking.

**`Pointer[T]`**: A safe pointer that points to a single value that it doesn't own. It provides bounds checking and other safety guarantees.

**`UnsafePointer[T]`**: An unsafe pointer that provides direct memory access with no safety guarantees. It is the primary pointer type for bare metal programming.

---

# Part II: Low-Level Primitives

---

## Chapter 5: Pointer Types and Memory Manipulation

### 5.1 Overview of Mojo Pointer Types

Mojo provides a hierarchy of pointer types with different safety guarantees and use cases:

**`Pointer[T]`**: A safe, non-nullable pointer that points to a single value. It provides bounds checking and other safety guarantees, making it suitable for application-level code where safety is paramount.

**`OwnedPointer[T]`**: A smart pointer that points to a single value and maintains exclusive ownership of that value. When the `OwnedPointer` goes out of scope, the owned value is destroyed. This provides RAII semantics for dynamically allocated values.

**`ArcPointer[T]`**: A reference-counted smart pointer that points to an owned value with ownership potentially shared with other instances. This is useful when multiple parts of the program need to share ownership of a value.

**`UnsafePointer[T, mut, origin, address_space]`**: An unsafe pointer that provides direct memory access with no safety guarantees. This is the primary pointer type for bare metal programming because it offers the maximum control with minimum overhead.

### 5.2 The UnsafePointer Type in Depth

`UnsafePointer` is the workhorse of bare metal Mojo programming. It represents an indirect reference to one or more values of type `T` consecutively in memory and can refer to uninitialized memory.

**Key characteristics**:

- **Unsafe and nullable**: No bounds checks are performed; reading before writing is undefined behavior.
- **Non-owning**: It does not own the memory it points to. When memory is heap-allocated with `alloc()`, you must call `.free()` explicitly.
- **Generic**: Parameterized by the pointee type `T`, mutability `mut`, origin, and address space.

**Basic operations**:

```mojo
// Allocate memory for 4 Float32 values
var ptr = alloc[Float32](4)

// Store values element-wise
for i in range(4):
    ptr.store(i, Float32(i))

// Load a single value
var v = ptr.load(2)  // Returns a SIMD vector of width 1
print(v[0])  // => 2.0

// Vectorized store and load
var vec = SIMD[DType.int32, 4](1, 2, 3, 4)
ptr.store(0, vec)
var out = ptr.load[width=4](0)
print(out)  // => [1, 2, 3, 4]

// Pointer arithmetic and dereference
(ptr + 0)[] = 10   // offset by 0 elements, then dereference
(ptr + 1)[] = 20   // offset +1 element
ptr[2] = 30        // equivalent offset/dereference with brackets
var second = ptr[1]  // reads the element at index 1

// Free the memory
ptr.free()
```

**Key APIs**:

- `free()`: Frees memory previously allocated by `alloc()`. Do not call on pointers that were not allocated by `alloc()`.
- `+ i` / `- i`: Pointer arithmetic. Returns a new pointer shifted by `i` elements. No bounds checking.
- `[]` or `[i]`: Dereference to a reference of the pointee (or at offset `i`). Only valid if the memory at that location is initialized.
- `load()`: Loads `width` elements starting at offset (default 0) as `SIMD[dtype, width]` from `UnsafePointer[Scalar[dtype]]`.
- `store()`: Stores `val: SIMD[dtype, width]` at offset into `UnsafePointer[Scalar[dtype]]`. Requires a mutable pointer.
- `destroy_pointee()` / `take_pointee()`: Explicitly end the lifetime of the current pointee, or move it out, taking ownership.
- `init_pointee_move()` / `init_pointee_move_from()` / `init_pointee_copy()`: Initialize a pointee that is currently uninitialized by moving an existing value, moving from another pointee, or copying an existing value.

### 5.3 Pointing to Stack Memory

`UnsafePointer` can point to memory on the stack as well as the heap:

```mojo
var x: Int32 = 42
var ptr = UnsafePointer[Int32].address_of(x)  // Point to stack variable
var value = ptr[]  // Read the value
ptr[] = 100        // Write the value
```

This is useful for:
- Passing stack-allocated buffers to functions that expect pointers
- Implementing efficient temporary buffers
- Interfacing with assembly code that expects pointer arguments

### 5.4 Address Spaces

`UnsafePointer` supports an `address_space` parameter that specifies which address space the pointer refers to. This is critical for bare metal programming on architectures with multiple address spaces, such as:
- **Generic** (`AddressSpace.GENERIC`): The default address space
- **Global** (`AddressSpace.GLOBAL`): Global memory
- **Shared** (`AddressSpace.SHARED`): Shared memory (e.g., GPU shared memory)
- **Constant** (`AddressSpace.CONSTANT`): Constant memory

Address spaces enable:
- Type-safe access to different memory regions
- Compiler optimizations based on address space semantics
- Portability across architectures with different memory hierarchies

### 5.5 Pointer Bitcasting and Type Punning

`UnsafePointer` supports `bitcast()` for reinterpreting the type of the pointee:

```mojo
var float_ptr = alloc[Float32](1)
float_ptr[] = 3.14
var int_ptr = float_ptr.bitcast[Int32]()
var int_value = int_ptr[]  // Reinterpret the bits as an integer
```

Bitcasting is useful for:
- Implementing type-punning operations
- Accessing hardware registers that can be interpreted in different ways
- Performing low-level data transformations

### 5.6 Span for Safe Bounded Access

The `Span` type provides a bounded view into a contiguous sequence of values:

```mojo
var data = alloc[Int32](100)
var span = Span[Int32](data, 100)  // Create a span over the allocated memory
for i in range(span.length):
    span[i] = i * 2
```

`Span` provides:
- Bounds checking in debug builds
- Length information
- Safe iteration
- Slicing operations

### 5.7 Stack Allocation

The `stack_allocation` function enables allocation of memory on the stack:

```mojo
var buffer = stack_allocation[Int32](64)  // Allocate 64 Int32 values on the stack
```

Stack allocation is useful for:
- Temporary buffers that don't need to outlive the current function
- Performance-critical code where heap allocation would be too slow
- Bare metal environments where heap allocation may not be available

---

## Chapter 6: Memory Allocation Strategies in Freestanding Environments

### 6.1 The Challenge of Freestanding Allocation

In a hosted environment (one with an operating system), memory allocation is typically handled by the standard library's `malloc` and `free` functions, which interact with the operating system's virtual memory manager. In a freestanding (bare metal) environment, no such operating system exists, so the programmer must implement their own memory allocation strategy.

Mojo's standard library currently assumes a full hosted POSIX environment with libc, making it unsuitable for bare metal allocation without modification. The standard library components that depend on POSIX functions include:
- String handling (depends on `dup`, `fdopen`, `fclose`)
- File I/O
- Dynamic library loading
- Process control

For bare metal programming, you must either:
1. Implement your own memory allocator using the primitives provided by Mojo
2. Use a minimal subset of the standard library that doesn't require POSIX
3. Contribute to the freestanding standard library initiative

### 6.2 Implementing a Simple Bump Allocator

A bump allocator is the simplest possible memory allocator:

```mojo
struct BumpAllocator:
    var start: UnsafePointer[UInt8]
    var current: UnsafePointer[UInt8]
    var end: UnsafePointer[UInt8]
    
    fn __init__(inout self, start: UnsafePointer[UInt8], size: Int):
        self.start = start
        self.current = start
        self.end = start + size
    
    fn allocate(inout self, size: Int, alignment: Int = 1) -> UnsafePointer[UInt8]:
        # Align the current pointer
        var aligned = (self.current.address + alignment - 1) & ~(alignment - 1)
        var ptr = UnsafePointer[UInt8](aligned)
        
        # Check if we have enough space
        if ptr + size > self.end:
            return UnsafePointer[UInt8]()  # Return null pointer
        
        self.current = ptr + size
        return ptr
    
    fn reset(inout self):
        self.current = self.start
```

A bump allocator is appropriate for:
- Early boot phases before a more sophisticated allocator is available
- Real-time systems where allocation latency must be predictable
- Single-use allocations that are never freed

### 6.3 Implementing a Simple Free List Allocator

For more flexible allocation, a free list allocator can be implemented:

```mojo
struct Block:
    var size: Int
    var next: UnsafePointer[Block]
    
struct FreeListAllocator:
    var head: UnsafePointer[Block]
    var heap_start: UnsafePointer[UInt8]
    var heap_end: UnsafePointer[UInt8]
    
    fn __init__(inout self, start: UnsafePointer[UInt8], size: Int):
        self.heap_start = start
        self.heap_end = start + size
        # Initialize the free list with a single large block
        var first = start.bitcast[Block]()
        first.size = size - sizeof[Block]()
        first.next = UnsafePointer[Block]()
        self.head = first
    
    fn allocate(inout self, size: Int) -> UnsafePointer[UInt8]:
        var prev = UnsafePointer[Block]()
        var current = self.head
        
        while current.is_not_null():
            if current.size >= size:
                # Found a suitable block
                if current.size > size + sizeof[Block]():
                    # Split the block
                    var remaining = (current.bitcast[UInt8]() + sizeof[Block]() + size).bitcast[Block]()
                    remaining.size = current.size - size - sizeof[Block]()
                    remaining.next = current.next
                    
                    if prev.is_not_null():
                        prev.next = remaining
                    else:
                        self.head = remaining
                    
                    current.size = size
                else:
                    # Remove the block from the free list
                    if prev.is_not_null():
                        prev.next = current.next
                    else:
                        self.head = current.next
                
                # Return the memory after the block header
                return (current.bitcast[UInt8]() + sizeof[Block]()).bitcast[UInt8]()
            
            prev = current
            current = current.next
        
        return UnsafePointer[UInt8]()  # Out of memory
    
    fn free(inout self, ptr: UnsafePointer[UInt8]):
        var block = (ptr - sizeof[Block]()).bitcast[Block]()
        # TODO: Coalesce adjacent free blocks
        block.next = self.head
        self.head = block
```

### 6.4 Static Allocation

For many bare metal applications, static allocation is the simplest and most reliable strategy:

```mojo
var global_buffer: StaticArray[UInt8, 1024]  # 1KB static buffer
```

Static allocation offers:
- Predictable memory usage
- No allocation failures
- No fragmentation
- No initialization overhead

The trade-off is that memory usage is fixed at compile time, which may be inefficient for workloads with variable memory requirements.

### 6.5 Custom Allocators with the Alloc Module

Mojo's `alloc` module provides layout-aware memory allocation and deallocation. It includes:
- `alloc`: Allocates memory with a specified layout
- `dealloc`: Deallocates memory
- `Layout`: Describes the size and alignment of an allocation

The `alloc` module is designed to work with `UnsafePointer` and provides:
- Alignment-aware allocation
- Type-safe allocation
- Integration with the ownership system

### 6.6 The Freestanding Standard Library Initiative

The Mojo community has recognized the need for a freestanding standard library that works without an operating system. Key considerations for this initiative include:

**Which stdlib components are most critical for bare-metal?**
- Basic types and operations
- Memory management
- String handling (without POSIX dependencies)
- Interrupt handling
- Atomic operations

**Should freestanding be a compile flag or separate modules?**
A compile flag (`--freestanding`) would be simpler but would require a significant rework of the standard library. Separate modules would allow incremental adoption but might lead to fragmentation.

**How should memory allocation work without a heap?**
The freestanding standard library should support both heap-based allocation (when a heap is available) and static allocation (when it is not).

**What other use cases need this beyond OS development?**
- Embedded systems
- GPU/accelerator programming
- Non-POSIX targets such as Windows
- Custom hardware platforms

---

## Chapter 7: The Foreign Function Interface (FFI) and C Interoperability

### 7.1 Overview of Mojo's FFI

Mojo's FFI (Foreign Function Interface) provides tools for calling C code and loading libraries. This is essential for bare metal programming because:
- Many bare metal environments provide a minimal C library interface
- Hardware initialization code is often written in C or assembly
- Existing bare metal libraries (e.g., CMSIS for ARM) are written in C

The FFI module provides:
- **C type aliases**: Portable type definitions that match C's type sizes on each platform
- **Dynamic library loading**: `OwnedDLHandle` for loading shared libraries at runtime (not applicable to most bare metal environments)
- **External function calls**: `external_call()` for calling C functions by name with compile-time resolution
- **String interop**: `CStringSlice` for working with null-terminated C strings

### 7.2 C Type Aliases

Mojo provides type aliases that match the sizes of C types on each platform:

| Mojo Type | C Type | Typical Size |
|-----------|--------|--------------|
| `c_char` | `char` | 1 byte |
| `c_short` | `short` | 2 bytes |
| `c_int` | `int` | 4 bytes |
| `c_long` | `long` | 4 or 8 bytes |
| `c_long_long` | `long long` | 8 bytes |
| `c_float` | `float` | 4 bytes |
| `c_double` | `double` | 8 bytes |
| `c_size_t` | `size_t` | 4 or 8 bytes |
| `c_void` | `void` | N/A |

These aliases are comptime values that resolve to the appropriate Mojo types for the target platform. They ensure that Mojo code can correctly interface with C code regardless of the target architecture.

### 7.3 External Function Calls

The `external_call` function enables calling C functions by name with compile-time resolution:

```mojo
from std.ffi import c_int, external_call

fn get_random() -> c_int:
    return external_call["rand", c_int]()
```

The `external_call` function:
- Resolves the function name at compile time
- Generates a direct call to the function
- No runtime lookup overhead
- Type-safe: the return type is checked at compile time

For bare metal programming, `external_call` is used to call:
- C runtime initialization functions (`_start`, `main`)
- Hardware abstraction layer functions
- Assembly functions exposed with C calling conventions

### 7.4 Calling Convention Specification

For FFI, Mojo supports explicit ABI specification:

```mojo
fn call_c_function(ptr: UnsafePointer[UInt8]) abi("C"):
    # This function uses the C calling convention
```

The `abi("C")` attribute specifies that the function uses the C calling convention, which is essential for:
- Calling C functions from Mojo
- Being called from C code
- Maintaining ABI compatibility with system firmware

### 7.5 Working with C Strings

The `CStringSlice` type provides interoperability with null-terminated C strings:

```mojo
from std.ffi.cstring import CStringSlice

fn print_c_string(cstr: CStringSlice):
    # Iterate over the C string
    for i in range(cstr.length):
        print(cstr[i])
```

`CStringSlice` provides:
- Safe access to C strings
- Length calculation (by scanning for the null terminator)
- Indexing operations
- Conversion to and from Mojo strings

### 7.6 Dynamic Library Loading

`OwnedDLHandle` provides RAII semantics for dynamically loaded libraries:

```mojo
from std.ffi import OwnedDLHandle, def

fn main() raises:
    var lib = OwnedDLHandle("libm.so")
    var sqrt = lib.get_function[def(Float64) abi("C") -> Float64]("sqrt")
    print(sqrt(4.0))  # 2.0
```

While dynamic library loading is not typically used in bare metal environments, it can be useful for:
- Loading firmware updates
- Implementing plugin architectures in systems with storage
- Testing and development

### 7.7 Unsafe Unions for C Interoperability

The `unsafe_union` module defines an untagged union type for C FFI interoperability:

```mojo
from std.ffi.unsafe_union import UnsafeUnion

struct MyUnion(UnsafeUnion[Int32, Float32]):
    # This union can hold either an Int32 or a Float32
```

Unsafe unions are useful for:
- Interfacing with C code that uses unions
- Implementing type-punning operations
- Accessing hardware registers that can be interpreted in different ways

---

## Chapter 8: Inline Assembly and Compiler Intrinsics

### 8.1 The Need for Inline Assembly

Inline assembly enables the programmer to embed processor-specific instructions directly in Mojo code. This is essential for bare metal programming because:
- Certain processor features are not accessible from high-level languages
- Performance-critical code may need to be hand-optimized
- Some hardware operations require specific instruction sequences

Mojo provides inline assembly through the `sys._assembly` module, which exports the `inlined_assembly` function.

### 8.2 Inline Assembly Syntax

The basic syntax for inline assembly in Mojo is:

```mojo
from sys._assembly import inlined_assembly

fn my_asm_function():
    inlined_assembly("""
        // Assembly code here
        nop
        ret
    """)
```

More complex inline assembly can specify input and output operands:

```mojo
fn add_asm(a: Int32, b: Int32) -> Int32:
    var result: Int32 = 0
    inlined_assembly("""
        add {0}, {1}, {2}
    """, outputs=[&result], inputs=[a, b])
    return result
```

### 8.3 LLVM Intrinsics

As an alternative to inline assembly, Mojo provides access to LLVM intrinsics through the `llvm_intrinsic` function:

```mojo
from sys.intrinsics import llvm_intrinsic

fn use_avx512_instruction(data: SIMD[DType.int8, 64]) -> SIMD[DType.int8, 64]:
    return llvm_intrinsic["llvm.x86.avx512.vpermi2var.qi.512"](
        data, data, data
    )
```

LLVM intrinsics offer several advantages over inline assembly:
- **Stability**: Intrinsics are less likely to be affected by compiler changes
- **Portability**: The same intrinsic works across different LLVM targets
- **Optimization**: The compiler can optimize around intrinsics
- **Type safety**: Intrinsics have defined type signatures

### 8.4 CPUID and Hardware Detection

For x86 and x86-64 targets, CPUID instructions can be used to detect hardware capabilities:

```mojo
fn cpuid(eax: Int32, ecx: Int32) -> (Int32, Int32, Int32, Int32):
    var a: Int32 = eax
    var b: Int32 = 0
    var c: Int32 = ecx
    var d: Int32 = 0
    inlined_assembly("""
        cpuid
    """, outputs=[a, b, c, d], inputs=[a, c])
    return (a, b, c, d)
```

This is useful for:
- Detecting available instruction set extensions (AVX, AVX-512, etc.)
- Determining cache sizes and topology
- Identifying the processor model and stepping

### 8.5 Compile-Time Assembly Inspection

Mojo provides the `compile_info` function for inspecting generated assembly code at compile time:

```mojo
from sys.compile import compile_info

fn my_function():
    # ... function body ...

fn main():
    var info = compile_info[my_function]()
    print(info.asm)  # Print the generated assembly
```

This is useful for:
- Verifying that the compiler generated the expected instructions
- Performance analysis
- Debugging code generation issues

### 8.6 Inlining Control

The `@always_inline` decorator forces the compiler to inline the body of a function directly into the calling function:

```mojo
@always_inline
fn critical_path():
    # This function will always be inlined
```

This is useful for:
- Performance-critical code where function call overhead is significant
- Wrapper functions around primitive operations
- Functions that are only used in a single context

### 8.7 The `compile` Package

The `compile` package provides functionality for compiling individual Mojo functions and examining their low-level implementation details:

- **`compile_info`**: Returns compilation information including assembly, LLVM IR, or object code
- **Linkage information**: Getting linkage names and module information

This enables:
- Runtime code generation
- JIT compilation
- Self-modifying code patterns

---

## Chapter 9: Compile-Time Metaprogramming for Hardware Abstraction

### 9.1 The Compile-Time Parameter System

Mojo's compile-time parameter system is one of its most powerful features for bare metal programming. Parameters are compile-time inputs to structs or functions that appear in square brackets after the name:

```mojo
struct MyStruct[param: Int]:
    var data: StaticArray[Int32, param]
    
fn my_function[param: Int]():
    # param is known at compile time
```

Parameters are similar to C++ template parameters or Rust generic parameters, but with Mojo's unique syntax where `[]` is used for parameters and `()` for arguments.

### 9.2 Compile-Time Evaluation

Mojo uses the `comptime` declaration for compile-time evaluation:

```mojo
fn compute_buffer_size(size: Int) -> Int:
    comptime:
        # This code runs at compile time
        return size * sizeof[Int32]()
```

`comptime` blocks can be used for:
- Computing constant values at compile time
- Generating code based on compile-time conditions
- Performing compile-time assertions

### 9.3 Type-Level Programming

Mojo's compile-time parameter system enables type-level programming where types are computed at compile time:

```mojo
struct Register[addr: Int, size: Int]:
    # A hardware register at address `addr` of size `size` bytes
    fn read(self) -> UInt32:
        var ptr = UnsafePointer[UInt8](addr)
        return ptr.load[width=size]()
    
    fn write(inout self, value: UInt32):
        var ptr = UnsafePointer[UInt8](addr)
        ptr.store[width=size](value)
```

This enables:
- Type-safe hardware register access
- Compile-time checking of register addresses
- Zero-cost hardware abstraction

### 9.4 Compile-Time Conditionals

Mojo supports `comptime if` and `comptime for` statements for compile-time conditional compilation:

```mojo
fn optimized_add(a: Int32, b: Int32) -> Int32:
    comptime if has_avx2():
        # Use AVX2 instructions
        return avx2_add(a, b)
    else:
        # Use scalar instructions
        return scalar_add(a, b)
```

This enables:
- Architecture-specific optimizations
- Feature detection at compile time
- Zero-cost abstraction over hardware capabilities

### 9.5 Compile-Time Defines

The `-D` flag passes key-value pairs from the command line into Mojo code:

```bash
mojo build -D TARGET=rp2040 -D HEAP_SIZE=4096 my_program.mojo
```

These defines can be accessed at compile time:

```mojo
from sys.defines import get_defined_string

fn main():
    comptime:
        var target = get_defined_string("TARGET")
        var heap_size = get_defined_int("HEAP_SIZE")
```

### 9.6 Compile-Time Reflection

Mojo provides compile-time reflection capabilities for inspecting types and values at compile time:

```mojo
from sys.reflection import type_name, type_size

fn print_type_info[T: AnyType]():
    comptime:
        print("Type:", type_name[T]())
        print("Size:", type_size[T]())
```

Reflection enables:
- Generic code that adapts to type properties
- Debugging and logging of type information
- Code generation based on type characteristics

### 9.7 Parameterized Structs for Hardware Abstraction

Parameterized structs are the cornerstone of zero-cost hardware abstraction in Mojo:

```mojo
trait Peripheral:
    fn init(inout self)
    fn enable(inout self)
    fn disable(inout self)

struct UART[base_addr: Int, baud_rate: Int]:
    # UART peripheral at base address `base_addr` with baud rate `baud_rate`
    
    fn init(inout self):
        # Initialize the UART
        self.set_baud_rate()
        self.enable()
    
    fn send_byte(inout self, byte: UInt8):
        var data_reg = UnsafePointer[UInt8](base_addr + 0x00)
        var status_reg = UnsafePointer[UInt8](base_addr + 0x04)
        
        # Wait for TX buffer to be empty
        while (status_reg[] & 0x01) == 0:
            pass
        
        data_reg[] = byte
    
    fn receive_byte(inout self) -> UInt8:
        var data_reg = UnsafePointer[UInt8](base_addr + 0x00)
        var status_reg = UnsafePointer[UInt8](base_addr + 0x04)
        
        # Wait for RX buffer to have data
        while (status_reg[] & 0x02) == 0:
            pass
        
        return data_reg[]
```

This pattern provides:
- Type-safe peripheral access
- Compile-time configuration
- Zero runtime overhead
- Reusable hardware abstractions

---

# Part III: Practical Bare Metal Development

---

## Chapter 10: Freestanding Environment Setup and Toolchain Configuration

### 10.1 Understanding Freestanding vs. Hosted Environments

In the context of C and Mojo compilers, "freestanding" refers to a program compiled to run in a bare-metal environment or an embedded system, where there might not be full support for all standard libraries and functionalities expected in a "hosted" environment.

Key differences:

| Aspect | Hosted Environment | Freestanding Environment |
|--------|-------------------|--------------------------|
| Operating System | Present | Absent |
| Standard Library | Full implementation | Minimal implementation |
| Startup Code | Provided by OS | Must be provided by programmer |
| Memory Management | OS-provided heap | Programmer-managed |
| I/O | OS-provided services | Programmer-implemented |
| Exception Handling | OS-provided | Programmer-implemented |
| Dynamic Linking | Supported | Typically not supported |

### 10.2 Toolchain Requirements

A bare metal Mojo development environment requires:

**Mojo 1.0 Toolchain**: The compiler itself, including:
- `mojo` command-line driver
- MLIR and LLVM libraries
- Standard library (or a subset thereof)

**Target-Specific Toolchain**:
- Assembler (`as`)
- Linker (`ld`)
- Object manipulation tools (`objcopy`, `objdump`)
- Debugger (`gdb`)

For ARM targets, the GNU ARM Embedded Toolchain provides these components.
For RISC-V targets, the RISC-V GNU Toolchain serves the same purpose.

**Hardware-Specific Files**:
- Linker script (defines memory layout)
- Startup code (initializes the system)
- Hardware header files (register definitions)

### 10.3 Memory Layout and Linker Scripts

The linker script defines the memory layout of the final executable. A typical bare metal linker script includes:

```
MEMORY
{
    FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 256K
    RAM (rwx)  : ORIGIN = 0x20000000, LENGTH = 64K
}

SECTIONS
{
    .text : {
        *(.vectors)
        *(.text*)
        *(.rodata*)
    } > FLASH
    
    .data : {
        *(.data*)
    } > RAM AT > FLASH
    
    .bss : {
        *(.bss*)
        *(COMMON)
    } > RAM
    
    .heap : {
        . = ALIGN(8);
        _heap_start = .;
        . = . + 4096;
        _heap_end = .;
    } > RAM
    
    .stack : {
        . = ALIGN(8);
        _stack_end = .;
        . = . + 2048;
        _stack_start = .;
    } > RAM
}
```

### 10.4 Startup Code

Startup code (often called `crt0`) initializes the system before calling the main program:

```assembly
.section .vectors
.word _stack_start
.word _start
.word handler_reset
.word handler_nmi
.word handler_hard_fault

.section .text
.global _start
_start:
    # Disable interrupts
    cpsid i
    
    # Initialize data section (copy from FLASH to RAM)
    ldr r0, =_data_start
    ldr r1, =_data_end
    ldr r2, =_data_load
    cmp r0, r1
    beq data_init_done
data_init_loop:
    ldr r3, [r2], #4
    str r3, [r0], #4
    cmp r0, r1
    bne data_init_loop
data_init_done:
    
    # Initialize BSS section (zero out)
    ldr r0, =_bss_start
    ldr r1, =_bss_end
    mov r2, #0
    cmp r0, r1
    beq bss_init_done
bss_init_loop:
    str r2, [r0], #4
    cmp r0, r1
    bne bss_init_loop
bss_init_done:
    
    # Enable interrupts
    cpsie i
    
    # Call the Mojo main function
    bl mojo_main
    
    # Loop forever if main returns
    b .
```

### 10.5 The `@export` Decorator

The `@export` decorator makes a function visible to the linker:

```mojo
@export("mojo_main")
fn start() abi("C"):
    # This is the entry point
```

`@export` ensures that the function:
- Is not stripped from the final binary
- Is visible to the linker for use in the startup code
- Has the specified symbol name

### 10.6 Cross-Compilation with Mojo

Cross-compilation with Mojo uses the `--target` option:

```bash
mojo build --target=thumbv6m-none-eabi -O2 my_program.mojo
```

For targets not directly supported by Mojo's LLVM, the retarget pipeline described in Chapter 3 can be used.

### 10.7 The `mojo build` Command

The `mojo build` command is the primary tool for building Mojo programs:

```bash
mojo build [options] source.mojo
```

Key options for bare metal development:
- `--target <TRIPLE>`: Specify the target triple
- `--optimization-level <LEVEL>`: Set optimization level (0-3)
- `--emit-llvm`: Emit LLVM IR
- `--emit-asm`: Emit assembly code
- `-D KEY=VALUE`: Define compile-time constants
- `--linker-script <FILE>`: Specify a linker script

---

## Chapter 11: Startup Code, Linker Scripts, and the C Runtime

### 11.1 The Boot Sequence

The boot sequence for a bare metal Mojo program follows these stages:

1. **Reset Vector**: The processor starts executing at the reset vector, which points to the startup code.

2. **Startup Code**: The startup code (crt0) initializes the system:
   - Disables interrupts
   - Copies the data section from FLASH to RAM
   - Zeroes the BSS section
   - Sets up the stack pointer
   - Enables interrupts
   - Calls the main function

3. **Main Function**: The Mojo main function executes the application logic.

4. **Infinite Loop**: If the main function returns, the program enters an infinite loop.

### 11.2 The Vector Table

The vector table is a table of function pointers that the processor uses to handle exceptions and interrupts:

```mojo
struct VectorTable:
    var stack_pointer: UInt32
    var reset: UInt32
    var nmi: UInt32
    var hard_fault: UInt32
    var memory_manage_fault: UInt32
    var bus_fault: UInt32
    var usage_fault: UInt32
    # ... more vectors
```

The vector table must be placed at a specific address in memory (typically the start of FLASH) and aligned to a specific boundary.

### 11.3 Implementing Interrupt Handlers

Interrupt handlers in Mojo are functions with the `abi("C")` attribute:

```mojo
@export("IRQ_Handler")
fn irq_handler() abi("C"):
    # Handle the interrupt
    # Clear the interrupt source
    # Return from interrupt
```

The handler must:
- Save the processor state (automatically handled by the hardware)
- Service the interrupt
- Clear the interrupt source
- Restore the processor state (automatically handled by the hardware)

### 11.4 The C Runtime (libgcc)

For bare metal programming on ARM, the C runtime (`libgcc`) provides:
- Software floating-point operations (if hardware FPU is not available)
- Division operations (if not implemented in hardware)
- Memory operations (memcpy, memset, memcmp)

The `libgcc` library is typically linked with the final executable.

### 11.5 Customizing the Runtime

For minimal bare metal programs, you may want to customize the runtime:
- Provide your own implementations of `memcpy`, `memset`, etc.
- Avoid using the full `libgcc` to reduce code size
- Implement only the runtime functions that are actually used

### 11.6 The `no_std` Pattern

While Mojo doesn't have an explicit "no_std" mode like Rust, the same pattern applies: avoid using standard library features that depend on the operating system.

Functions to avoid in bare metal Mojo:
- File I/O (`open`, `read`, `write`, `close`)
- Dynamic memory allocation (`malloc`, `free`)
- Process control (`fork`, `exec`, `exit`)
- Signal handling
- Threading (unless implemented by the programmer)

---

## Chapter 12: Interrupt Handling and Exception Management

### 12.1 The Interrupt System

Interrupts are events that cause the processor to suspend normal execution and jump to an interrupt handler. In bare metal systems, interrupts are used for:
- Peripheral events (UART receive, timer overflow, etc.)
- External events (button presses, sensor readings)
- System events (watchdog timeout, power failure)

The interrupt system consists of:
- **Interrupt sources**: Peripherals or external signals that can generate interrupts
- **Interrupt controller**: Hardware that prioritizes and dispatches interrupts
- **Interrupt vectors**: Table of function pointers for each interrupt source
- **Interrupt handlers**: Functions that service the interrupts

### 12.2 Enabling and Disabling Interrupts

Interrupts must be managed carefully in bare metal systems:

```mojo
fn disable_interrupts():
    inlined_assembly("cpsid i")

fn enable_interrupts():
    inlined_assembly("cpsie i")
```

Critical sections should disable interrupts to prevent reentrancy:

```mojo
fn critical_section():
    disable_interrupts()
    # Critical code here
    enable_interrupts()
```

### 12.3 Interrupt Priority

Most interrupt controllers support multiple priority levels:

```mojo
fn set_irq_priority(irq: Int, priority: Int):
    var nvic = UnsafePointer[UInt32](0xE000E400)  # NVIC priority registers
    nvic[irq / 4] = (nvic[irq / 4] & ~(0xFF << (8 * (irq % 4)))) | (priority << (8 * (irq % 4)))
```

Higher priority interrupts can preempt lower priority interrupts.

### 12.4 Nested Interrupts

Nested interrupts occur when a higher-priority interrupt preempts a lower-priority interrupt handler. To support nested interrupts:
- Interrupt handlers must be reentrant
- Critical sections must disable interrupts
- The interrupt controller must support nesting

### 12.5 Interrupt Latency

Interrupt latency is the time from the interrupt event to the start of the interrupt handler. Factors affecting latency:
- **Hardware latency**: Time for the processor to recognize the interrupt
- **Vector fetch**: Time to read the interrupt vector
- **Context save**: Time to save the processor state
- **Handler execution**: Time to execute the handler

For real-time systems, interrupt latency must be bounded and predictable.

### 12.6 Software Interrupts

Software interrupts (SWI) are generated by software to request operating system services. In bare metal systems, they can be used for:
- System calls in a minimal operating system
- Inter-processor communication
- Debugging and breakpoints

```mojo
fn swi(number: Int):
    inlined_assembly("""
        mov r0, {0}
        swi {0}
    """, inputs=[number])
```

### 12.7 Exception Handling

Exceptions in bare metal systems include:
- Hard faults (memory access violations, illegal instructions)
- Bus faults (bus errors)
- Usage faults (divide by zero, alignment errors)

Exception handlers should:
- Save the processor state
- Determine the cause of the exception
- Take appropriate action (reset, log, ignore)
- Return from the exception

---

## Chapter 13: Peripheral Access and Memory-Mapped I/O

### 13.1 Memory-Mapped I/O

Memory-mapped I/O (MMIO) is the dominant method for accessing peripherals in embedded systems. Peripherals are mapped to specific addresses in the processor's memory space, and reading or writing to these addresses controls the peripheral.

In Mojo, MMIO is accessed using `UnsafePointer`:

```mojo
var uart_data_reg = UnsafePointer[UInt8](0x40004000)  # UART data register
uart_data_reg[] = 0x41  # Send 'A' character
```

### 13.2 Register Bit Fields

Hardware registers often contain multiple fields packed into a single word. Bit fields can be accessed using bit manipulation:

```mojo
struct UARTStatus:
    var raw: UInt32
    
    fn tx_empty(self) -> Bool:
        return (self.raw & 0x01) != 0
    
    fn rx_full(self) -> Bool:
        return (self.raw & 0x02) != 0
```

Alternatively, the `bitfield` module can be used for type-safe bit field access.

### 13.3 Peripheral Initialization

Peripherals must be initialized before use:

```mojo
fn init_uart(base_addr: Int, baud_rate: Int):
    var ctrl_reg = UnsafePointer[UInt32](base_addr + 0x00)
    var baud_reg = UnsafePointer[UInt32](base_addr + 0x04)
    
    # Disable the UART
    ctrl_reg[] = 0
    
    # Set the baud rate
    baud_reg[] = baud_rate
    
    # Enable the UART with 8-bit data, no parity, 1 stop bit
    ctrl_reg[] = 0x03  # Enable TX and RX
```

### 13.4 Polling vs. Interrupt-Driven I/O

Polling is the simplest method for peripheral I/O:

```mojo
fn uart_send_byte(base_addr: Int, byte: UInt8):
    var status_reg = UnsafePointer[UInt8](base_addr + 0x04)
    while (status_reg[] & 0x01) == 0:
        pass  # Wait for TX buffer to be empty
    var data_reg = UnsafePointer[UInt8](base_addr + 0x00)
    data_reg[] = byte
```

Interrupt-driven I/O is more efficient for high-speed or low-latency operations:

```mojo
fn uart_isr() abi("C"):
    # Read the received byte
    var data_reg = UnsafePointer[UInt8](UART_BASE + 0x00)
    var byte = data_reg[]
    # Process the byte
    process_byte(byte)
```

### 13.5 DMA Transfers

DMA (Direct Memory Access) allows peripherals to transfer data directly to and from memory without CPU intervention:

```mojo
fn configure_dma(source: UnsafePointer[UInt8], dest: UnsafePointer[UInt8], size: Int):
    var dma_ctrl = UnsafePointer[UInt32](DMA_BASE + 0x00)
    var dma_source = UnsafePointer[UInt32](DMA_BASE + 0x04)
    var dma_dest = UnsafePointer[UInt32](DMA_BASE + 0x08)
    var dma_size = UnsafePointer[UInt32](DMA_BASE + 0x0C)
    
    dma_source[] = source.address
    dma_dest[] = dest.address
    dma_size[] = size
    dma_ctrl[] = 0x01  # Start the transfer
```

### 13.6 Peripheral Abstraction Patterns

For maintainable bare metal code, peripherals should be abstracted:

```mojo
trait UARTPeripheral:
    fn init(inout self)
    fn send(inout self, byte: UInt8)
    fn receive(inout self) -> UInt8
    
struct UART[base_addr: Int]:
    var initialized: Bool
    
    fn init(inout self):
        # Initialize the UART
        self.initialized = True
    
    fn send(inout self, byte: UInt8):
        # Send a byte
        pass
    
    fn receive(inout self) -> UInt8:
        # Receive a byte
        return 0
```

---

## Chapter 14: Building a Minimal Hardware Abstraction Layer

### 14.1 The Purpose of a HAL

A Hardware Abstraction Layer (HAL) provides a uniform interface to hardware peripherals, making code more portable and maintainable. A minimal HAL for bare metal Mojo includes:

- **Register definitions**: Type-safe definitions for hardware registers
- **Peripheral drivers**: Functions for initializing and using peripherals
- **Interrupt handlers**: Functions for servicing interrupts
- **Clock management**: Functions for configuring system clocks
- **Power management**: Functions for controlling power states

### 14.2 Register Definition Patterns

Registers can be defined using structs with bitfield methods:

```mojo
struct Reg32:
    var raw: UInt32
    
    fn read(self) -> UInt32:
        return self.raw
    
    fn write(inout self, value: UInt32):
        self.raw = value
    
    fn set_bits(inout self, mask: UInt32):
        self.raw = self.raw | mask
    
    fn clear_bits(inout self, mask: UInt32):
        self.raw = self.raw & ~mask
```

### 14.3 A Minimal GPIO Driver

```mojo
struct GPIO:
    var base: Int
    
    fn set_mode(inout self, pin: Int, mode: UInt32):
        var mode_reg = UnsafePointer[UInt32](self.base + 0x00)
        var shift = (pin % 8) * 4
        var mask = 0xF << shift
        mode_reg[] = (mode_reg[] & ~mask) | (mode << shift)
    
    fn write(inout self, pin: Int, value: Bool):
        var output_reg = UnsafePointer[UInt32](self.base + 0x04)
        if value:
            output_reg[] = output_reg[] | (1 << pin)
        else:
            output_reg[] = output_reg[] & ~(1 << pin)
    
    fn read(self, pin: Int) -> Bool:
        var input_reg = UnsafePointer[UInt32](self.base + 0x08)
        return (input_reg[] & (1 << pin)) != 0
```

### 14.4 A Minimal UART Driver

```mojo
struct UART:
    var base: Int
    
    fn init(inout self, baud: Int):
        var ctrl_reg = UnsafePointer[UInt32](self.base + 0x00)
        var baud_reg = UnsafePointer[UInt32](self.base + 0x04)
        
        ctrl_reg[] = 0
        baud_reg[] = baud
        ctrl_reg[] = 0x03  # Enable TX and RX
    
    fn send(inout self, byte: UInt8):
        var status_reg = UnsafePointer[UInt8](self.base + 0x04)
        while (status_reg[] & 0x01) == 0:
            pass
        var data_reg = UnsafePointer[UInt8](self.base + 0x00)
        data_reg[] = byte
    
    fn receive(inout self) -> UInt8:
        var status_reg = UnsafePointer[UInt8](self.base + 0x04)
        while (status_reg[] & 0x02) == 0:
            pass
        var data_reg = UnsafePointer[UInt8](self.base + 0x00)
        return data_reg[]
```

### 14.5 HAL Design Principles

When designing a HAL for bare metal Mojo:

1. **Type Safety**: Use Mojo's type system to prevent invalid operations
2. **Zero-Cost Abstraction**: Use compile-time parameters to eliminate runtime overhead
3. **Modularity**: Separate concerns into distinct modules
4. **Portability**: Abstract hardware-specific details behind interfaces
5. **Testability**: Design for testability through dependency injection

---

# Part IV: Case Studies and Advanced Topics

---

## Chapter 15: Case Study: RP2040 Bare Metal Firmware in Pure Mojo

### 15.1 Overview of the Project

The RP2040 bare metal Mojo project is a landmark achievement in Mojo's bare metal capabilities. It demonstrates:
- A pure-Mojo firmware for the Raspberry Pi Pico (RP2040)
- No operating system, no C application layer
- Startup code in ~60 lines of assembly and one linker script
- A complete peripheral SDK written in Mojo
- Performance parity with C and Rust

### 15.2 Project Structure

The project structure includes:

```
project/
├── src/
│   ├── main.mojo        # Main application
│   ├── pico.mojo        # Pico SDK
│   ├── gpio.mojo        # GPIO driver
│   ├── uart.mojo        # UART driver
│   └── pio.mojo         # PIO driver
├── startup/
│   ├── startup.s        # Startup assembly
│   └── link.ld          # Linker script
├── tools/
│   └── retarget.mojo    # IR retargeting tool
└── build/
    └── output.bin       # Final binary
```

### 15.3 The Blink Example

The classic "blink" program in Mojo demonstrates the simplicity of the approach:

```mojo
import pico
from pico import Pin, pins, sleep_ms

@export("mojo_main")
fn start() abi("C"):
    pico.init()
    var led = Pin[pins.LED]()  # Pin number is a compile-time parameter
    led.make_output()          # Pin[99]() is a compile-time error
    
    while True:
        led.toggle()
        sleep_ms(250)
```

Key features demonstrated:
- **Compile-time checked pin numbers**: `Pin[99]()` is a compile-time error
- **Type-safe peripheral access**: The `Pin` struct provides methods that are type-checked
- **Simple syntax**: The code reads like Python but runs on bare metal

### 15.4 Performance Benchmarks

The project includes comprehensive benchmarks comparing Mojo to C, C++, and Rust:

**Register-loop microbenchmarks**: Mojo matches clang C to the microsecond. The 200k-round xorshift benchmark runs in 102,501 µs across all three of Mojo, clang C, and Rust.

**Larger workloads** (CRC-32, quicksort, 16×16 matrix multiply, recursive Fibonacci): Mojo lands within ±13% of clang C, ahead on some workloads and behind on others—ordinary optimizer variance with no systematic "language tax" or performance cliff as programs grow.

**Binary size**: A complete blink program is 780 bytes, byte-for-byte identical to the same program compiled with clang -O2 on the identical hardware.

### 15.5 The Retarget Pipeline in Practice

The retarget pipeline is the technical innovation that makes this project possible:

1. Mojo compiles to RISC-V 32-bit IR (`--target=riscv32`)
2. The IR is retargeted to `thumbv6m-none-eabi`
3. IR constructs that LLVM 18 doesn't understand are transformed
4. LLVM generates Cortex-M0+ object code
5. `arm-none-eabi-gcc` links with startup code and libraries

The retarget pipeline is guarded by unit tests and verification checks. The whole pipeline is implemented as a Mojo program.

### 15.6 SDK Capabilities

The SDK includes:
- **GPIO**: Pins as compile-time-checked types
- **PIO**: Programmable I/O assembler written as method calls
- Additional peripherals (UART, SPI, I2C, PWM, etc.)

### 15.7 Lessons Learned

Key lessons from the RP2040 project:

1. **Mojo is ready for bare metal**: Despite being a young language, Mojo can generate code that is competitive with mature languages like C and Rust.

2. **Compile-time parameters enable zero-cost abstraction**: The ability to use compile-time parameters for hardware configuration eliminates runtime overhead.

3. **The retarget pipeline is viable**: While not ideal, the IR retargeting approach works for targeting architectures not directly supported by Mojo's LLVM.

4. **Performance is competitive**: Mojo achieves performance parity with C and Rust across a wide range of workloads.

---

## Chapter 16: GPU and Accelerator Bare Metal Programming

### 16.1 Mojo's GPU Programming Model

Mojo is designed for heterogeneous computing, with first-class support for GPU and accelerator programming. The language provides:
- Unified syntax for CPU and GPU code
- Direct access to low-level CPU and GPU intrinsics
- Cross-hardware portability

### 16.2 GPU Memory Model

GPU programming in Mojo follows the GPU memory hierarchy:
- **Global memory**: Accessible by all threads
- **Shared memory**: Accessible by threads in the same block
- **Local memory**: Private to each thread
- **Constant memory**: Read-only, cached

Mojo provides address space annotations for different memory types.

### 16.3 Kernel Definition

GPU kernels in Mojo are defined as functions with specific attributes:

```mojo
@kernel
fn vector_add(a: UnsafePointer[Float32], b: UnsafePointer[Float32], 
              c: UnsafePointer[Float32], n: Int):
    var idx = get_global_id()
    if idx < n:
        c[idx] = a[idx] + b[idx]
```

### 16.4 GPU Memory Allocation

GPU memory is allocated using specialized functions:

```mojo
var device_a = gpu_alloc[Float32](n)
var device_b = gpu_alloc[Float32](n)
var device_c = gpu_alloc[Float32](n)

# Copy data to the GPU
gpu_memcpy(device_a, host_a, n * sizeof[Float32]())
gpu_memcpy(device_b, host_b, n * sizeof[Float32]())

# Launch the kernel
launch_kernel[vector_add](n, device_a, device_b, device_c, n)

# Copy results back
gpu_memcpy(host_c, device_c, n * sizeof[Float32]())
```

### 16.5 GPU Debugging

Debugging GPU code requires specialized techniques:
- Printf from GPU kernels
- GPU debugging tools (NVIDIA Nsight, AMD ROCm)
- Emulation modes for CPU debugging

### 16.6 Accelerator Support

Mojo supports various accelerators beyond GPUs:
- NPUs (Neural Processing Units)
- DSPs (Digital Signal Processors)
- Custom accelerators

The MLIR foundation enables targeting these diverse accelerators through specialized dialects.

---

## Chapter 17: Real-Time Constraints and Deterministic Execution

### 17.1 Real-Time Systems

Real-time systems require deterministic execution with predictable timing. In bare metal Mojo, this means:
- No garbage collection pauses
- No dynamic memory allocation in time-critical paths
- Predictable interrupt latencies
- Worst-case execution time (WCET) analysis

### 17.2 Avoiding Unpredictable Behavior

To maintain deterministic execution:

**Avoid dynamic allocation**: Use static allocation or pre-allocated pools.

**Avoid recursion**: Recursion can lead to stack overflow and unpredictable execution.

**Avoid virtual dispatch**: Use static dispatch (struct methods) rather than dynamic dispatch (traits with dynamic dispatch).

**Avoid exceptions**: Use error codes or return values instead of exceptions.

### 17.3 Timing Analysis

WCET analysis determines the maximum execution time of a piece of code. In Mojo, this requires:
- Understanding the instruction timing of the target processor
- Analyzing loops and branches
- Considering cache behavior
- Accounting for interrupt overhead

### 17.4 Real-Time Scheduling

For systems with multiple tasks, a real-time scheduler is needed:
- **Priority-based scheduling**: Higher priority tasks preempt lower priority tasks
- **Rate-monotonic scheduling**: Fixed priorities based on task periods
- **Earliest-deadline-first**: Dynamic priorities based on deadlines

### 17.5 Watchdog Timers

Watchdog timers detect system failures and reset the system:

```mojo
fn feed_watchdog():
    var wdt_reg = UnsafePointer[UInt32](WDT_BASE + 0x00)
    wdt_reg[] = 0xDEADBEEF  # Feed the watchdog
```

The watchdog must be fed regularly to prevent a reset.

---

## Chapter 18: Debugging Bare Metal Mojo Programs

### 18.1 Debugging Challenges

Bare metal debugging presents unique challenges:
- No operating system to provide debugging services
- Limited or no console output
- No crash dumps or error logs
- JTAG/SWD debugging requires specialized hardware

### 18.2 JTAG/SWD Debugging

JTAG (Joint Test Action Group) and SWD (Serial Wire Debug) provide access to the processor's debug interface:

```
OpenOCD or GDB server → JTAG/SWD adapter → Target processor
```

Using GDB:
```bash
arm-none-eabi-gdb build/output.elf
(gdb) target remote localhost:3333
(gdb) break mojo_main
(gdb) continue
```

### 18.3 Print Debugging

For systems without a debugger, print debugging is the primary method:

```mojo
fn print_hex(value: UInt32):
    var uart = UART[UART_BASE]()
    for i in range(8):
        var nibble = (value >> (28 - i * 4)) & 0xF
        var char = if nibble < 10: '0' + nibble else: 'A' + nibble - 10
        uart.send(char)
```

### 18.4 LED Debugging

Blinking LEDs is a classic debugging technique:

```mojo
fn debug_blink(code: Int):
    var led = Pin[pins.LED]()
    for i in range(code):
        led.toggle()
        sleep_ms(100)
        led.toggle()
        sleep_ms(100)
    sleep_ms(500)  # Pause between codes
```

### 18.5 Crash Analysis

When a crash occurs, the processor's state can be examined:
- Program counter (PC): Address of the faulting instruction
- Link register (LR): Return address
- Stack pointer (SP): Current stack location
- Fault status registers: Cause of the fault

For ARM Cortex-M processors:
```mojo
fn hard_fault_handler() abi("C"):
    var psp = get_psp()
    # Examine the stack frame to determine the cause
    while True:
        pass  # Halt execution
```

### 18.6 The `debug` Module

Mojo's `debug` module provides debug hook functions:

```mojo
from sys.debug import breakpoint

fn debug_break():
    breakpoint()
```

The `breakpoint` function generates a breakpoint instruction, causing the debugger to halt.

---

## Chapter 19: Performance Optimization at the Metal Level

### 19.1 The Performance Mindset

Bare metal programming requires a performance-first mindset:
- Understand the target architecture
- Know the cost of operations
- Profile and measure
- Optimize the hot path

### 19.2 Architecture-Specific Optimizations

Different architectures have different optimization opportunities:
- **ARM**: Use Thumb-2 instructions for code size, SIMD for data parallelism
- **x86**: Use AVX/AVX-512 for vector operations, cache prefetch
- **RISC-V**: Use compressed instructions for code size

### 19.3 Cache Optimization

Cache optimization is critical for performance:
- **Data layout**: Organize data for cache-friendly access
- **Prefetching**: Use prefetch instructions to reduce latency
- **Alignment**: Align data to cache line boundaries
- **Locality**: Maximize spatial and temporal locality

### 19.4 Memory Access Optimization

Memory access optimization:
- **Minimize memory accesses**: Keep data in registers
- **Use SIMD**: Process multiple data elements with a single instruction
- **Avoid unaligned accesses**: Align data for efficient access
- **Use DMA**: Offload memory transfers to DMA controllers

### 19.5 Loop Optimization

Loop optimization techniques:
- **Loop unrolling**: Reduce loop overhead
- **Software pipelining**: Overlap iterations
- **Loop-invariant code motion**: Move invariant code out of loops
- **Strength reduction**: Replace expensive operations with cheaper ones

### 19.6 Compiler Optimization Hints

Mojo provides attributes for guiding the compiler:
- `@always_inline`: Force inlining
- `@noinline`: Prevent inlining
- `@register_passable`: Pass structs in registers

### 19.7 Profiling Bare Metal Code

Profiling bare metal code requires specialized tools:
- **Hardware performance counters**: Count instructions, cache misses, etc.
- **Cycle-accurate simulation**: Simulate the processor
- **Logic analyzers**: Measure timing on real hardware

### 19.8 Benchmarking Methodology

Proper benchmarking is essential:
- Use representative workloads
- Run multiple iterations
- Measure the right thing (execution time, energy, code size)
- Account for measurement overhead

---

# Part V: The Future of Bare Metal Mojo

---

## Chapter 20: The Freestanding Standard Library Initiative

### 20.1 Current Limitations

Mojo's standard library currently assumes a full hosted POSIX environment, making it unsuitable for bare metal programming without modification. The limitations include:
- Dependencies on POSIX functions (`dup`, `fdopen`, `fclose`)
- Dynamic linking requirements
- Assumptions about a heap allocator
- Lack of control over runtime initialization

### 20.2 The Rust Model

Rust provides a model for freestanding programming with three levels of standard library:

**`core`**: Everything that should be able to function on a Turing machine. This includes basic types, operations, and language concepts.

**`alloc`**: Stuff that needs a global, general-purpose allocator to be present.

**`std`**: Things that could be reasonably assumed to require an operating system of some sort.

### 20.3 Proposed Mojo Freestanding Model

The Mojo community has discussed adapting the Rust model:

**Core layer**: Basic types, operations, and language features with no OS dependencies.

**Alloc layer**: Memory allocation with a custom allocator interface.

**OS layer**: Operating system-specific functionality.

### 20.4 Key Design Questions

The freestanding standard library initiative raises several design questions:

**Should freestanding be a compile flag or separate modules?**
A compile flag (`--freestanding`) would be simpler but would require significant rework of the standard library. Separate modules would allow incremental adoption.

**How should memory allocation work without a heap?**
The freestanding standard library should support both heap-based allocation (when a heap is available) and static allocation (when it is not).

**Which stdlib components are most critical for bare-metal?**
Basic types, memory management, string handling (without POSIX dependencies), interrupt handling, and atomic operations.

### 20.5 Capability-Based Abstractions

There has been discussion about using capability-based abstractions for freestanding Mojo:
- Capabilities represent access to resources
- Capabilities are passed explicitly
- The presence of a capability indicates that a resource is available

This approach would allow the same code to work in both hosted and freestanding environments.

### 20.6 Community Efforts

The Mojo community is actively working on freestanding support:
- Feature requests for `--freestanding` command-line option
- Discussions about minimal runtime requirements
- Contributions to the standard library

### 20.7 Timeline

While no official timeline has been announced, freestanding support is a priority for the Mojo team. The release of Mojo 1.0 marks the beginning of a stable platform for further development.

---

## Chapter 21: Emerging Hardware Targets and Cross-Compilation

### 21.1 WebAssembly Support

Mojo's LLVM backend could potentially support WebAssembly (WASM) targets:
- `wasm32` and `wasm64` targets
- Web deployment in browsers
- Edge computing and serverless environments

### 21.2 Custom Accelerators

Mojo's MLIR foundation enables targeting custom accelerators:
- AI accelerators (TPUs, NPUs)
- DSPs
- FPGA-based accelerators

### 21.3 RISC-V Support

RISC-V is becoming increasingly important for embedded systems:
- Mojo's LLVM backend supports RISC-V
- The RP2040 project uses RISC-V as an intermediate representation
- Full RISC-V support is expected

### 21.4 Cross-Compilation Improvements

Future improvements to cross-compilation:
- Better target triple support
- Improved retargeting tools
- Integration with embedded build systems

### 21.5 The Mojo Roadmap

The Mojo roadmap includes:
- Systems application programming
- Generic type system convergence
- Systems programming features stabilization

---

## Chapter 22: Conclusion: The Unification of High-Level Ergonomics and Metal-Level Control

### 22.1 The Mojo Promise

Mojo fulfills a promise that has eluded systems programming languages for decades: the unification of high-level ergonomics with metal-level control. Mojo reads like Python but runs like raw assembly, providing:
- Pythonic syntax that is clean and readable
- Systems-level performance competitive with C and Rust
- Direct access to hardware at the metal level

### 22.2 The Current State

As of Mojo 1.0, the language is production-ready for bare metal programming:
- Stable language features
- Comprehensive standard library
- Mature toolchain
- Proven performance

### 22.3 The Road Ahead

The future of bare metal Mojo is bright:
- Freestanding standard library support
- Expanded hardware targets
- Improved tooling
- Growing ecosystem

### 22.4 The Call to Action

For developers interested in bare metal Mojo:
- Explore the RP2040 project
- Contribute to the freestanding standard library initiative
- Build bare metal applications
- Share your experiences with the community

Mojo represents the next generation of systems programming—a language that combines the best of Python's usability with the performance and control of C. Bare metal programming in Mojo is not just possible; it is practical, performant, and productive.

---

# Appendices

---

## Appendix A: Mojo 1.0 Language Reference Summary

### A.1 Basic Types

| Type | Description |
|------|-------------|
| `Bool` | Boolean (true/false) |
| `Int8`, `Int16`, `Int32`, `Int64` | Signed integers |
| `UInt8`, `UInt16`, `UInt32`, `UInt64` | Unsigned integers |
| `Float16`, `Float32`, `Float64` | Floating-point |
| `SIMD[dtype, width]` | SIMD vector |

### A.2 Function Declarations

```mojo
def function_name(param1: Type1, param2: Type2) -> ReturnType:
    # Runtime function with exceptions
    pass

fn function_name(param1: Type1, param2: Type2) -> ReturnType:
    # Performance function without exceptions
    pass
```

### A.3 Struct Declarations

```mojo
struct StructName:
    var field1: Type1
    var field2: Type2
    
    fn __init__(inout self, ...):
        # Constructor
        pass
    
    fn __del__(inout self):
        # Destructor
        pass
```

### A.4 Trait Declarations

```mojo
trait TraitName:
    fn method(self)
```

### A.5 Parameterized Types

```mojo
struct Generic[T: AnyType, N: Int]:
    var data: StaticArray[T, N]
```

### A.6 Key Attributes

| Attribute | Purpose |
|-----------|---------|
| `@always_inline` | Force function inlining |
| `@noinline` | Prevent function inlining |
| `@register_passable` | Pass struct in registers |
| `@export` | Export symbol |

---

## Appendix B: Standard Library Modules for Systems Programming

### B.1 `sys` Module

| Submodule | Purpose |
|-----------|---------|
| `sys.arg` | Execution environment |
| `sys.compile` | Compile-time information |
| `sys.debug` | Debug hooks |
| `sys.defines` | Compile-time defines |
| `sys.info` | Host target info |
| `sys.intrinsics` | Compiler intrinsics |
| `sys.terminate` | Exit functions |

### B.2 `memory` Module

| Submodule | Purpose |
|-----------|---------|
| `memory.alloc` | Memory allocation |
| `memory.arc_pointer` | Reference-counted pointers |
| `memory.owned_pointer` | Owned pointers |
| `memory.pointer` | Safe pointers |
| `memory.span` | Bounded views |
| `memory.stack_allocation` | Stack allocation |
| `memory.unsafe_pointer` | Unsafe pointers |

### B.3 `ffi` Module

| Submodule | Purpose |
|-----------|---------|
| `ffi.cstring` | C string interop |
| `ffi.unsafe_union` | Untagged unions |

---

## Appendix C: Target Architecture Reference

### C.1 ARM Cortex-M

| Target Triple | Description |
|---------------|-------------|
| `thumbv6m-none-eabi` | Cortex-M0, M0+ |
| `thumbv7m-none-eabi` | Cortex-M3 |
| `thumbv7em-none-eabi` | Cortex-M4, M7 (FPU) |

### C.2 RISC-V

| Target Triple | Description |
|---------------|-------------|
| `riscv32-unknown-elf` | RISC-V 32-bit |
| `riscv64-unknown-elf` | RISC-V 64-bit |

### C.3 x86-64

| Target Triple | Description |
|---------------|-------------|
| `x86_64-none-elf` | x86-64 bare metal |
| `x86_64-unknown-none` | x86-64 bare metal (Rust-style) |

---

## Appendix D: Glossary of Terms

**Bare Metal**: Programming directly on hardware without an operating system.

**FFI**: Foreign Function Interface—mechanism for calling C code from Mojo.

**Freestanding**: A compilation environment without an operating system.

**Hosted**: A compilation environment with an operating system.

**IR**: Intermediate Representation—the representation of code between source and machine code.

**LLVM**: Low-Level Virtual Machine—a compiler infrastructure used by Mojo.

**MLIR**: Multi-Level Intermediate Representation—the compiler framework used by Mojo.

**MMIO**: Memory-Mapped I/O—peripheral access via memory addresses.

**RAII**: Resource Acquisition Is Initialization—automatic resource management.

**SIMD**: Single Instruction, Multiple Data—vectorized processing.

**WCET**: Worst-Case Execution Time—the maximum execution time of a code segment.

---

*This guide is current as of Mojo 1.0 (August 2026). The Mojo language continues to evolve, and readers are encouraged to consult the official Mojo documentation for the most up-to-date information.*
