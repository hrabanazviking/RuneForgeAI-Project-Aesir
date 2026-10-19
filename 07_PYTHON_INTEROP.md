# Mojo Python Interoperability

> Corpus slice 07 — Mojo study corpus commissioned by Volmarr, 2026-10-19.
> Version reflected: **Mojo 1.1.0** (latest stable, released 2026-09-17, per
> https://mojolang.org/releases/). The Python interoperability pages in the
> Mojo Manual are themselves labelled "Version: 1.1.0".
> Primary source: the Mojo Manual, "Python interoperability" section on
> docs.modular.com / mojolang.org. Every API, import path, and code sample
> below is taken from a page read in full during this research session.
> See "## Sources" at the end for the exact URLs read.

Mojo does not merely *look* like Python. The Manual frames interoperability
as a two-way bridge, and it is explicit that there are two distinct
directions, with two distinct mechanisms:

1. **Calling Python from Mojo** — import existing Python modules into a
   Mojo program and use them there.
2. **Calling Mojo from Python** — declare Mojo functions and types as a
   Python extension module, then `import` them from Python like any other
   module.

The Manual's overview page states the compatibility claim plainly:

> "Not only does Mojo use a Pythonic syntax, our plan is to provide full
> compatibility with the Python ecosystem… You can import existing Python
> modules and use them in a Mojo program. This is 100% compatible because
> we use the CPython runtime without modification for full compatibility
> with existing Python libraries. You can construct Python objects and
> call Python functions directly from Mojo, using the CPython interpreter
> as a dynamic library."

And for the reverse direction:

> "You can extend your Python code with high-performance Mojo code (or
> incrementally migrate Python code to Mojo). Because Mojo is a compiled
> language, we can't directly 'evaluate' Mojo code from Python. Instead,
> you must declare which Mojo functions and types are available to be
> called from Python (declare the 'bindings'), and then you can import
> them in your Python code … just like any other module — there's no
> extra compilation step."

A hard requirement is stated on the same page, and it is easy to miss:

> "Mojo itself doesn't require Python. To use the Mojo ↔ Python
> interoperability features described in this section, you need
> Python 3.10–3.14."

Everything else in this file is the mechanics of those two directions.

---

## 1. Calling Python from Mojo

### 1.1 Which Python, and where it comes from

Mojo does **not** bundle a CPython interpreter. The "Calling Python from
Mojo" page says:

> "Mojo doesn't include a CPython interpreter — it uses the CPython
> interpreter provided by your environment's default Python version."

Consequences documented on that page:

- You must know which Python version each environment will use.
- Modular recommends **Pixi** to pin the version and manage the
  environment, e.g.:

```bash
pixi add "python==3.11"
pixi run python --version
# Python 3.11.0
```

- `mojo build` does **not** include the Python packages your project
  uses. Quoting the page's caution verbatim in substance: Mojo loads the
  Python interpreter and Python packages **at runtime**, so they must be
  provided in the environment where you run the Mojo program — for
  example inside the same Pixi environment where you built the
  executable. A Mojo binary is therefore not a self-contained bundle of
  its Python dependencies.

### 1.2 Importing a Python module: `Python.import_module()`

The documented entry point is the `Python` type from the standard
library package `std.python`:

```mojo
from std.python import Python

def main() raises:
    # This is equivalent to Python's `import numpy as np`
    var np = Python.import_module("numpy")

    # Now use numpy as if writing in Python
    var array = np.array(Python.list(1, 2, 3))
    print(array)  # [1 2 3]
```

Notes the Manual makes about this exact pattern — all of them matter in
practice:

- `import_module()` **returns a `PythonObject` wrapper** referencing the
  module. You must store it in a variable and access functions, classes,
  and other objects through that variable.
- **You cannot import individual members.** There is no equivalent of
  Python's `from numpy import array`. You import the whole module and
  reach members through the module object.
- **The call must be inside a function or method.** Mojo does not yet
  support top-level code, so there is no module-level
  `var np = Python.import_module("numpy")` at file scope. You either
  import inside each function that needs it, or pass the module
  reference around.
- **Re-importing is cheap in the Python sense.** Importing the same
  module multiple times does not re-run its initialization logic, just
  as in Python.
- **`import_module()` may raise.** The enclosing Mojo function therefore
  needs `raises` — note `def main() raises:` in every documented
  example. The Manual contrasts this with the Mojo standard library,
  which limits exception use for performance reasons; Python code raises
  much more freely.

Python's builtins are not special-cased. You import them as a module
named `"builtins"`:

```mojo
from std.python import Python

def main() raises:
    var np = Python.import_module("numpy")
    var array = np.array(Python.list(1, 2, 3))

    var builtins = Python.import_module("builtins")
    print(builtins.type(array))  # <class 'numpy.ndarray'>
```

### 1.3 Importing a local Python module: `Python.add_to_path()`

For your own `.py` files, the documented mechanism is to add their
directory to the Python path first, then import by module name:

```python
# mypython.py
import numpy as np

def gen_random_values(size, base):
    # generate a size x size array of random numbers between base and base+1
    random_array = np.random.rand(size, size)
    return random_array + base
```

```mojo
# main.mojo
from std.python import Python

def main() raises:
    Python.add_to_path("path/to/module")
    var mypython = Python.import_module("mypython")
    var values = mypython.gen_random_values(2, 3)
    print(values)
```

Both absolute and relative paths work with `add_to_path()`, including
the local directory:

```mojo
Python.add_to_path(".")
```

### 1.4 Working with NumPy and other libraries

The NumPy example above is the Manual's canonical "call a real Python
library" example, and its shape generalises: import the module once,
keep the returned `PythonObject`, then use attribute access, indexing,
and calls on it **as if writing Python**. Attribute access, method
calls, and `[]` indexing are forwarded to the underlying CPython object
by `PythonObject` (see §2).

That forwarding is also why keyword arguments to Python functions work
from Mojo in the form Python programmers expect. A Modular blog post on
Mojo 24.2 (an older release, cited here only for the historical note
that keyword-argument support was *added* then, not as the current API
reference) illustrated the change with Matplotlib:

```mojo
# Before keyword-argument support, you had to do it in two steps:
# fig = plt.figure()
# fig.set_size_inches(10, 6)

# With keyword arguments:
plt.figure(figsize=(10, 6))
```

In current (1.1.0) code you should treat that call style as the normal
one: Python functions are called through `PythonObject`, and the call
convention is Python's.

> **Version-sensitive flag:** the 24.2 blog example used the old import
> spelling `from python import Python`. The 1.1.0 Manual uniformly uses
> `from std.python import Python` and `from std.python import PythonObject`.
> Use the `std.`-prefixed form for current code. The unprefixed form is
> pre-1.0 history.


---

## 2. `PythonObject`: the wrapper every Python value wears in Mojo

### 2.1 What it is

The "Python types" page of the Manual defines the model:

> "When you use Python objects in your Mojo code, Mojo adds the
> `PythonObject` wrapper around the Python object. This object exposes a
> number of common double underscore methods (dunder methods) like
> `__getitem__()` and `__getattr__()`, passing them through to the
> underlying Python object. Most of the time, you can treat the wrapped
> object just like you'd treat it in Python. You can use dot-notation to
> access attributes and call methods, and use the `[]` operator to
> access an item in a sequence."

`PythonObject` also implements the `Writable` trait, so the built-in
`print()` works on Python values directly. The Manual warns, however,
that **most other Mojo APIs do not accept `PythonObject` values
directly** — for those you must explicitly convert to a native Mojo
value (see §3.2).

### 2.2 Creating Python values from Mojo

You can construct a `PythonObject` directly from a Mojo integer, float,
boolean, or string:

```mojo
from std.python import Python
from std.python import PythonObject

def main() raises:
    var py_string = PythonObject("Hello, Mojo!")
    var py_bool = PythonObject(True)
    var py_int = PythonObject(123)
    var py_float = PythonObject(3.14)
```

For collections, the Manual documents three static constructors on
`Python`:

```mojo
from std.python import Python

def main() raises:
    var py_dict = Python.dict()
    py_dict["item_name"] = "whizbang"
    py_dict["price"] = 11.75
    py_dict["inventory"] = 100
    print(py_dict)
    # {'item_name': 'whizbang', 'price': 11.75, 'inventory': 100}
```

```mojo
from std.python import Python

def main() raises:
    var py_list = Python.list("cat", 2, 3.14159, 4)
    var n = py_list[2]
    print("n =", n)          # n = 3.14159
    py_list.append(5)
    py_list[0] = "aardvark"
    print(py_list)           # ['aardvark', 2, 3.14159, 4, 5]
```

```mojo
from std.python import Python

def main() raises:
    var py_tuple = Python.tuple("cat", 2, 3.1415, "cat")
    var n = py_tuple[2]
    print("n =", n)                          # n = 3.1415
    print("Number of cats:", py_tuple.count("cat"))  # Number of cats: 2
```

For Python types with no Mojo literal equivalent, the documented escape
hatch is `Python.evaluate()`, which evaluates a Python expression
string in CPython:

```mojo
from std.python import Python

def main() raises:
    var py_set = Python.evaluate('{2, 3, 2, 7, 11, 3}')
    var num_items = len(py_set)
    print(num_items, "items in the set.")    # 4 items in the set.
    var contained = 7 in py_set
    print("Is 7 in the set:", contained)     # Is 7 in the set: True
```

`Python.evaluate()` is also the documented way to create an *in-memory
Python module* from a string — used in the Manual's conversion example
in §3.1 below, with `file=True` and a `name=` argument:

```mojo
var py_utils = Python.evaluate(py_module, file=True, name="py_utils")
```

### 2.3 Comparisons, identity, and type tests

The Manual documents three distinct operations, and keeping them apart
matters:

- **Value comparison** uses the ordinary operators, forwarded to
  Python: `value1 > 3`, `value1 > value2`.
- **Identity** uses Mojo's `is` operator on the wrappers.
- **Type inspection** uses `Python.type(obj)`, the equivalent of
  Python's `type()` builtin, and type tests are identity comparisons
  against the type object.

Python's `False` and `None` also evaluate as false in Mojo boolean
expressions. The full documented example:

```mojo
from std.python import Python

def main() raises:
    var value1 = PythonObject(3.7)
    var value2 = Python.evaluate("10/3")

    # Compare values
    print("Is value1 greater than 3:", value1 > 3)          # True
    print("Is value1 greater than value2:", value1 > value2)  # True

    # Compare identities
    var value3 = value2
    print("value1 is value2:", value1 is value2)  # False
    print("value2 is value3:", value2 is value3)  # True

    # Compare types
    var py_float_type = Python.evaluate("float")
    print("Python float type:", py_float_type)    # <class 'float'>
    print("value1 type:", Python.type(value1))    # <class 'float'>
    print("Is value1 a Python float:", Python.type(value1) is py_float_type)  # True
```

(One line above also needs `from std.python import PythonObject` in a
real file when `PythonObject(...)` is constructed explicitly, as in
§2.2; the Manual's types page imports both names in its conversion
example.)

---

## 3. Type conversions, both ways

The "Python types" page opens with the governing sentence:

> "When calling Python methods, Mojo needs to convert back and forth
> between native Python objects and native Mojo objects. Most of these
> conversions happen automatically, but there are a number of cases that
> Mojo doesn't handle yet. In these cases you may need to do an explicit
> conversion, or call an extra method."

### 3.1 Mojo → Python: implicit for primitives

> "Mojo primitive types implicitly convert into Python objects. Today
> we support integers, floats, booleans, and strings."

The Manual proves it by defining a Python function that prints the type
of whatever it receives, then passing Mojo values to it:

```mojo
from std.python import Python

def main() raises:
    var py_module = """
def type_printer(value):
    print(type(value))
"""
    var py_utils = Python.evaluate(py_module, file=True, name="py_utils")
    py_utils.type_printer(4)       # <class 'int'>
    py_utils.type_printer(3.14)    # <class 'float'>
    py_utils.type_printer(True)    # <class 'bool'>
    py_utils.type_printer("Mojo")  # <class 'str'>
```

So a Mojo `Int`-like value becomes a Python `int`, a floating value a
Python `float`, `True`/`False` a Python `bool`, and a Mojo string a
Python `str` — with no wrapping code on the Mojo side.

### 3.2 Python → Mojo: explicit, via `py=` initializers

The reverse direction is explicit. The documented conversions from a
`PythonObject` to native Mojo values use initializers with a `py=`
argument:

```mojo
from std.python import Python
from std.python import PythonObject

def main() raises:
    var py_string = PythonObject("Hello, Mojo!")
    var py_bool = PythonObject(True)
    var py_int = PythonObject(123)
    var py_float = PythonObject(3.14)

    var mojo_string = String(py=py_string)
    var mojo_bool = Bool(py=py_bool)
    var mojo_int = Int(py=py_int)
    var mojo_float = Float64(py=py_float)
```

In the Mojo-from-Python documentation the same conversions appear in
their raising form — `Int(py=py_obj)`, `String(args[0])`,
`Int(args[1])` — with the explicit note that a conversion **raises an
exception if the source value is not convertible**. That raising
behaviour is what lets binding code (see §4) validate Python arguments
at the boundary instead of silently coercing them.

The trait behind the supported conversions is named in the
Mojo-from-Python page: **`ConvertibleFromPython`**. A Mojo type that
implements it can be constructed directly from an equivalent Python
builtin object. The same page's "Known limitations" section is blunt
about coverage: only "a handful of Mojo standard library types" do this
today, and "many Mojo standard library types do not yet implement this
trait, so may require manual conversion logic if needed."

### 3.3 The practical pattern

Putting §§3.1–3.2 together, the documented working style is:

1. Keep Python values as `PythonObject` while you are talking to
   Python — attribute access, calls, and indexing all forward.
2. Convert **once, at the boundary**, with `Int(py=…)`, `Float64(py=…)`,
   `String(py=…)`, `Bool(py=…)` when a native Mojo API or a hot Mojo
   loop needs a native value.
3. Pass Mojo primitives back to Python freely; they convert implicitly.
4. Expect a raise on a failed conversion, and let `raises` propagate it
   (in Mojo-from-Mojo code) or let the binding layer turn it into a
   Python exception (in Mojo-from-Python code, §4.2).

There is no documented zero-copy NumPy-array conversion in the pages
read for this slice. NumPy arrays cross as `PythonObject`s and are
manipulated through Python operations; any claim of direct buffer
sharing would need a source this research did not verify, so none is
made here. See the report-back note on unverifiable items.


---

## 4. Calling Mojo from Python

> **Status warning, from the Manual itself:** "Calling Mojo code from
> Python is in early development. You should expect a lot of changes to
> the API and ergonomics. Likewise, this documentation is still a work
> in progress." Treat every API in this section as **beta and
> version-sensitive**.

### 4.1 The minimal round-trip

Project layout:

```text
project
├── main.py
└── mojo_module.mojo
```

The Mojo side must declare an exported initialiser function named
`PyInit_<module>` — for `mojo_module.mojo`, that is
`PyInit_mojo_module()` — because that is the function Python looks for
when it loads the module. Inside it, `PythonModuleBuilder` declares
("binds") everything Python may call:

```mojo
from std.python import PythonObject
from std.python.bindings import PythonModuleBuilder
from std import math
from std.os import abort

@export
def PyInit_mojo_module() abi("C") -> PythonObject:
    try:
        var m = PythonModuleBuilder("mojo_module")
        m.def_function[factorial]("factorial", docstring="Compute n!")
        return m.finalize()
    except e:
        abort(String("error creating Python Mojo module:", e))

def factorial(py_obj: PythonObject) raises -> PythonObject:
    # Raises an exception if `py_obj` is not convertible to a Mojo `Int`.
    var n = Int(py=py_obj)
    return math.factorial(n)
```

The Python side needs one extra import — `mojo.importer` — before the
normal import:

```python
import mojo.importer
import mojo_module

print(mojo_module.factorial(5))  # 120
```

### 4.2 How it works underneath

The Manual explains the mechanism in full:

- Python extension modules are the standard CPython mechanism by which
  compiled languages (C, C++, Rust — and Mojo) expose callables to
  Python. An extension module is a dynamic library defining a suitable
  `PyInit_*()` function.
- Importing `mojo.importer` installs a Python **import hook**. When
  Python then imports a name, the hook looks for a matching `.mojo`
  file, compiles it with the equivalent of
  `mojo build --emit shared-lib`, and caches the resulting `.so` in a
  `__mojocache__` directory next to the source:

```text
project
├── main.py
├── mojo_module.mojo
└── __mojocache__
    └── mojo_module.hash-ABC123.so
```

- The cached library is rebuilt only when it becomes stale, typically
  when the Mojo source changes. Deleting `__mojocache__` is always
  safe; artifacts are rebuilt on next import.
- **The `abi` rule:** an `@export` function must declare its calling
  convention with an explicit `abi` effect. `PyInit_<module>` must use
  `abi("C")` because CPython locates and calls it directly across the C
  boundary. An `abi("C")` function cannot be marked `raises` — which is
  why the examples wrap the body in `try`/`except` and call `abort()`
  on error.
- Functions you *register* with the builder (`def_function`,
  `def_method`, `def_py_init`, …) do **not** need `@export`. You pass
  them by reference; Mojo generates the C wrapper CPython calls, and
  that wrapper invokes your function with the Mojo calling convention
  and **translates any raised error into a Python exception**. Registered
  functions may therefore freely use `raises`.

### 4.3 Binding Mojo types

Any Mojo type can be bound with `PythonModuleBuilder.add_type()`, which
returns a `PythonTypeBuilder`:

```mojo
@fieldwise_init
struct Person(Movable, Writable):
    var name: String
    var age: Int

@export
def PyInit_person_module() abi("C") -> PythonObject:
    try:
        var mb = PythonModuleBuilder("person_module")
        var person_type = mb.add_type[Person]("Person")
        # ... bind constructor / methods on person_type ...
        return mb.finalize()
    except e:
        abort(String("error creating Python Mojo module:", e))
```

Documented requirements and consequences:

- A bound type **must implement `Writable`**. `Movable` is additionally
  required for custom initializers (`def_py_init`); both `Defaultable`
  and `Movable` are required for `def_init_defaultable`.
- Registering a type with `add_type()` registers the resulting Python
  type object **globally**. That enables two things: constructing a
  Python object wrapping a Mojo value with
  `PythonObject(alloc=Person(..))`, and downcasting (see §4.5).

### 4.4 Constructing Mojo objects from Python

Custom construction is declared with `def_py_init`, pointing at a
static initializer that receives the raw Python `args`/`kwargs`:

```mojo
@export
def PyInit_person_module() abi("C") -> PythonObject:
    try:
        var mb = PythonModuleBuilder("person_module")
        _ = mb.add_type[Person]("Person").def_py_init[Person.py_init]()
        return mb.finalize()
    except e:
        abort(String("error creating Python Mojo module:", e))

@fieldwise_init
struct Person(Movable, Writable):
    var name: String
    var age: Int

    @staticmethod
    def py_init(
        out self: Person, args: PythonObject, kwargs: PythonObject
    ) raises:
        # Validate argument count
        if len(args) != 2:
            raise Error("Person() takes exactly 2 arguments")
        # Convert Python arguments to Mojo types
        var name = String(args[0])
        var age = Int(args[1])
        self = Self(name, age)
```

From Python, construction then looks native:

```python
person = person_module.Person("Sarah", 32)
print(person)  # Person(name=Sarah, age=32)
```

For default-constructible types there is a shortcut,
`def_init_defaultable`:

```mojo
var counter_type = m.add_type[Counter]("Counter")
counter_type.def_init_defaultable[Counter]()
```

```python
counter = counter_module.Counter()  # Creates Counter()
```

Terminology note from the Manual: Python splits construction across
`__new__()` and `__init__()`; a Mojo struct has no `__new__()`, so Mojo
documentation always calls `__init__()` the *initializer*.

### 4.5 Returning Mojo values, and getting them back: `alloc=` and downcasting

A Mojo function returning a native Mojo value to Python wraps it with
the `alloc=` constructor:

```mojo
def create_person() -> PythonObject:
    var person = Person("Sarah", 32)
    return PythonObject(alloc=person^)
```

> Caution (Manual): "`PythonObject(alloc=...)` will raise an exception
> if the provided Mojo object type had not previously been registered
> using `PythonModuleBuilder.add_type()`."

Inside Mojo, there are **two different** ways to recover a Mojo value
from a `PythonObject`, and the Manual distinguishes them carefully:

1. **Conversion** — build a *new* Mojo value with the same logical
   value, via `ConvertibleFromPython` (e.g. `String(name_obj)`,
   `Int(age_obj)`). This is for genuine Python objects (a Python `str`,
   a Python `int`).
2. **Downcasting** — recover a *pointer to the inner Mojo value* that a
   Python object is wrapping, via `downcast_value_ptr[T]()`:

```mojo
def print_age(person_obj: PythonObject) raises:
    # Raises if `obj` does not contain an instance of the Mojo `Person` type.
    var person = person_obj.downcast_value_ptr[Person]()
    print("Person is", person[].age, "years old")
```

Downcasting also permits mutation through the pointer:

```mojo
def birthday(person_obj: PythonObject):
    var person = person_obj.downcast_value_ptr[Person]()
    person[].age += 1
```

The Manual warns that with a mutable downcast pointer, aliasing safety
is the user's responsibility. And it documents an unchecked variant,
`unchecked_downcast_value_ptr[T]()`, which performs no type checking —
justified, in the Manual's words, only when you are "optimizing a tight
inner loop" and have "benchmarked and measured that type checking
downcasts is a significant bottleneck."

### 4.6 Methods and static methods

Methods are exposed with `PythonTypeBuilder.def_method()`. The
documented catch: **a method exposed to Python cannot take a normal
`self`.** It must be a `@staticmethod` taking either
`py_self: PythonObject` or `self_ptr: Pointer[Self]`:

```mojo
struct Person(Writable):
    var name: String
    var age: Int

    @staticmethod
    def get_name(py_self: PythonObject) raises -> PythonObject:
        var self_ptr = py_self.downcast_value_ptr[Self]()
        return self_ptr[].name

    @staticmethod
    def set_age(
        self_ptr: Pointer[mut=True, Self],
        new_age: PythonObject,
    ) raises:
        self_ptr[].age = Int(new_age)

    def write_to(self, mut writer: Some[Writer]):
        t"Person({self.name}, {self.age})".write_to(writer)
```

```mojo
# Binding site:
_ = mb.add_type[Person]("Person")
    .def_method[Person.get_name]("get_name")
    .def_method[Person.set_age]("set_age")
```

The Manual says taking `py_self` gives access to the full
`PythonObject` allocation, while taking `self_ptr: Pointer[Self]`
"will minimize boilerplate in the common case that a method merely
needs to access the fields of an object." It also states plainly that
the non-standard `self` types are a current limitation "that will be
lifted in future versions of Python Mojo bindings."

Static methods use `def_staticmethod`:

```mojo
mb.add_type[Person]("Person")
    .def_staticmethod[Person.is_valid_age]("is_valid_age")
```

```mojo
@staticmethod
def is_valid_age(age_obj: PythonObject) raises -> PythonObject:
    var age = Int(age_obj)
    return 0 <= age <= 130
```

```python
from mojo_module import Person
print(Person.is_valid_age(45))  # Prints 'True'
print(Person.is_valid_age(-1))  # Prints 'False'
```

### 4.7 Keyword and variadic arguments: the current, limited story

- **Keyword-only arguments** (`def foo(*, x: Int)`) are **not**
  currently supported in Python/Mojo bindings.
- **Variadic keyword arguments** *are* supported, but only in the
  unsugared form: the last parameter is a
  `StringDict[PythonObject]` (imported as
  `from std.collections import StringDict`), not `**kwargs`. The
  Manual notes the `**kwargs` syntax limitation "will be removed in
  the future."

```python
import mojo_module
result = mojo_module.sum_kwargs_ints(a=10, b=20, c=30)  # returns 60
```

```mojo
from std.collections import StringDict

def sum_kwargs_ints(kwargs: StringDict[PythonObject]) raises -> PythonObject:
    var total = 0
    for entry in kwargs.items():
        total += Int(entry.value)
    return PythonObject(total)
```

Reading a specific keyword is a dictionary lookup, and a missing
required keyword raises at runtime (a Python `KeyError` in the
Manual's example). Keyword arguments work for bound top-level
functions, methods, and static methods.

- **Variadic positional arguments** (`*args`) are **not** supported
  through `def_function()`, which only supports fixed-arity functions.
  The documented workaround is the lower-level `def_py_function()`
  interface, whose handlers receive `(py_self, args_tuple)` and must
  validate the argument count themselves:

```mojo
b.def_py_function[count_args]("count_args")
b.def_py_function[sum_args]("sum_args")
```

```mojo
def count_args(py_self: PythonObject, args_tuple: PythonObject) raises:
    return len(args_tuple)

def sum_args(py_self: PythonObject, args_tuple: PythonObject) raises:
    var total = args_tuple[0]
    for i in range(1, len(args_tuple)):
        total += args_tuple[i]
    return total
```

### 4.8 Porting Python code to Mojo "Pythonically"

The Manual offers a deliberate strategy section: instead of converting
every `PythonObject` argument into strongly typed Mojo values, write
the Mojo function *in Python style* over `PythonObject`s and let it
raise at runtime if something is wrong. Its rule of thumb:

> "Any Python builtin function should be accessible in Mojo using
> `Python.<builtin>()`."

```python
# Python original
def foo(x, y, z):
    x[y] = int(z)
    x = y + z
```

```mojo
def foo(x: PythonObject, y: PythonObject, z: PythonObject) -> PythonObject:
    x[y] = Python.int(z)
    x = y + z
```

This is a documented, legitimate migration pattern — incremental
porting first, strict typing later where profiling says it pays.

### 4.9 Distributing Mojo extension modules

Two documented routes:

1. **As source**, compiled on demand by the `mojo.importer` hook.
   Simple, always up to date after an edit.
2. **As a pre-built shared library**:

```bash
mojo build mojo_module.mojo --emit shared-lib -o mojo_module.so
```

   The Manual calls this the "escape hatch" for advanced users: it lets
   you specify build options manually — optimization or debug flags,
   import paths, etc.

---

## 5. Documented limits and pitfalls — consolidated

From the overview, types, from-Mojo, and from-Python pages combined:

**Calling Python from Mojo**

- Python 3.10–3.14 is required for interop; Mojo ships no interpreter
  and uses the environment's CPython.
- Python packages are loaded at runtime and are **not** bundled by
  `mojo build`; the runtime environment must provide them.
- No member-level imports (`from module import name` has no equivalent);
  import the whole module.
- No top-level code: `import_module()` must run inside a function.
- `import_module()` and Python calls in general may raise; Mojo callers
  need `raises`.
- Most Mojo APIs do not accept `PythonObject` directly; convert
  explicitly with the `py=` initializers.
- Only integers, floats, booleans, and strings convert implicitly from
  Mojo to Python today (per the types page).

**Calling Mojo from Python (beta — expect API changes)**

- Keyword arguments: only via a trailing
  `kwargs: StringDict[PythonObject]` parameter; no keyword-only
  parameters, no native `**kwargs` syntax yet.
- Variadic positional arguments: not via `def_function()`; use
  `def_py_function()` and validate counts manually.
- Mojo package dependencies beyond the standard library are **not**
  supported through the import hook (it has no way to specify import
  paths for them); build the extension module manually instead.
- Computed properties (getters/setters) are not currently supported.
- `ConvertibleFromPython` coverage is partial — "a handful" of standard
  library types; others need manual conversion logic.
- Exposed methods must use the non-standard `py_self` / `self_ptr`
  static-method form for now.
- `PythonObject(alloc=...)` raises unless the type was registered with
  `add_type()` first.
- `PyInit_<module>` must be `@export … abi("C")`, cannot `raise`, and
  must handle errors internally (the examples `abort()`).

**Performance guidance that follows from the documented model**

- Every Mojo→Python call crosses into CPython through `PythonObject`
  forwarding. The docs do not publish a per-call cost figure in the
  pages read, so no number is quoted here — but the architecture (a
  dynamic CPython call per operation on a `PythonObject`) is the reason
  the Manual's own examples convert to native Mojo values before doing
  Mojo-side work, and the reason the "porting" strategy in §4.8 is
  presented as a *starting* point rather than the performance end state.
- Keep module references: re-importing is safe and cheap, but holding
  the `PythonObject` from a single `import_module()` call is the
  documented idiom.

---

## Sources

Exact URLs read in full during this research session:

- https://docs.modular.com/mojo/manual/python/ — "Python interoperability" overview (Version: 1.1.0); also served at https://mojolang.org/docs/manual/python/
- https://mojolang.org/docs/manual/python/python-from-mojo/ — "Calling Python from Mojo"
- https://mojolang.org/docs/manual/python/mojo-from-python/ — "Calling Mojo from Python"
- https://docs.modular.com/mojo/manual/python/types — "Python types" (conversions, `PythonObject`, `Python.dict/list/tuple`, `Python.evaluate`, `Python.type`)
- https://mojolang.org/releases/ — Mojo releases; latest stable 1.1.0 (2026-09-17), nightly 1.2.0.dev2026101405 (2026-10-14)

Consulted as a secondary, historical source only (old-release import
spelling and the origin of keyword-argument support; **not** used as
the current API reference):

- https://www.modular.com/blog/whats-new-in-mojo-24-2-mojo-nightly-enhanced-python-interop-oss-stdlib-and-more
