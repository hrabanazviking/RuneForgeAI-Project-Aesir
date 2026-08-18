# ⚡ The Complete Modular MAX Reference Guide

(Complete_Modular_MAX_Reference_Guide.md)

## Version Information

**Current Stable Release:** Modular Platform 26.5 (August 2026)  
**Previous Stable:** MAX 26.4  
**Package Version:** 26.5.x  
**Installation:** `pip install modular` or `pixi add modular`  
**Supported Platforms:** Linux (x86_64, ARM64), macOS (Apple Silicon), Windows (WSL2)  
**Python Support:** 3.10 - 3.12

---

## Table of Contents

1. [Installation and Setup](#1-installation-and-setup)
2. [MAX CLI](#2-max-cli)
3. [Python API Overview](#3-python-api-overview)
4. [MAX Engine (Inference)](#4-max-engine-inference)
5. [MAX Graph API](#5-max-graph-api)
6. [Tensor Operations](#6-tensor-operations)
7. [Graph Operations (ops)](#7-graph-operations-ops)
8. [GPU Programming (Mojo)](#8-gpu-programming-mojo)
9. [MAX Accelerator Library](#9-max-accelerator-library)
10. [Model Development](#10-model-development)
11. [Custom Operations](#11-custom-operations)
12. [PyTorch Integration](#12-pytorch-integration)
13. [Serving and Deployment](#13-serving-and-deployment)
14. [C API](#14-c-api)
15. [Configuration and Environment](#15-configuration-and-environment)
16. [Performance Optimization](#16-performance-optimization)

---

## 1. Installation and Setup

### 1.1 Installation Methods

```bash
# Method 1: Using pip (recommended)
pip install modular

# Method 2: Using pixi (recommended for projects)
pixi init my-project
cd my-project
pixi add modular

# Method 3: Using uv
uv pip install modular

# Method 4: Using conda
conda install -c conda-forge modular
```

### 1.2 Verify Installation

```bash
# Check version
max --version

# List available commands
max --help

# Check devices
max device list
```

### 1.3 Environment Setup

```bash
# Add to PATH (if needed)
export PATH="$HOME/.modular/bin:$PATH"

# Set environment variables
export MODULAR_HOME="$HOME/.modular"
export MAX_CACHE_DIR="$HOME/.max/cache"

# For GPU support
export CUDA_VISIBLE_DEVICES=0,1,2,3
```

---

## 2. MAX CLI

### 2.1 Core Commands

| Command | Description | Example |
|---------|-------------|---------|
| `max serve` | Start model server | `max serve --model llama-3.1-8b` |
| `max run` | Run inference | `max run --model bert --input "text"` |
| `max compile` | Compile model | `max compile model.onnx --output model.max` |
| `max benchmark` | Benchmark model | `max benchmark --model model.max` |
| `max generate` | Generate text | `max generate --model gpt2 "Hello"` |
| `max encode` | Encode embeddings | `max encode --model clip image.jpg` |
| `max warm-cache` | Precompile model | `max warm-cache model.onnx` |
| `max list` | List available models | `max list` |
| `max device` | Device management | `max device list` |

### 2.2 max serve

```bash
# Basic usage
max serve --model meta-llama/Llama-3.1-8B-Instruct

# With specific device
max serve --model llama-3.1-8b --device gpu

# Multi-GPU
max serve --model llama-3.1-70b --tensor-parallel-size 4

# With custom port
max serve --model llama-3.1-8b --port 8080

# With API key
max serve --model llama-3.1-8b --api-key your-key

# Precompiled model
max serve --model-path ./model.max

# With continuous batching
max serve --model llama-3.1-8b --enable-chunked-prefill

# With specific dtype
max serve --model llama-3.1-8b --dtype float16

# With quantization
max serve --model llama-3.1-8b --quantization int8

# Save compiled graph
max serve --model llama-3.1-8b --save-compiled-graph ./compiled.max
```

**Options:**

| Flag | Description | Default |
|------|-------------|---------|
| `--model` | Model name or path | Required |
| `--model-path` | Path to local model | - |
| `--device` | Device (cpu/gpu) | auto |
| `--port` | Server port | 8000 |
| `--host` | Server host | 0.0.0.0 |
| `--tensor-parallel-size` | GPUs for tensor parallelism | 1 |
| `--pipeline-parallel-size` | GPUs for pipeline parallelism | 1 |
| `--dtype` | Data type (float32/float16/bfloat16) | auto |
| `--quantization` | Quantization mode | none |
| `--max-model-len` | Maximum sequence length | model default |
| `--gpu-memory-utilization` | GPU memory fraction | 0.9 |
| `--enable-chunked-prefill` | Enable chunked prefill | false |
| `--enable-prefix-caching` | Enable prefix caching | false |
| `--api-key` | API key for authentication | - |
| `--trust-remote-code` | Trust remote code | false |
| `--save-compiled-graph` | Save compiled graph path | - |
| `--precompiled-mefs` | Load precompiled MEFs | - |
| `--scheduling-policy` | Scheduling policy | fcfs |

### 2.3 max compile

```bash
# Compile ONNX model
max compile model.onnx --output model.max

# Compile with optimization
max compile model.onnx --output model.max --opt-level 3

# Compile for specific target
max compile model.onnx --target gpu --output model.max

# With custom batch size
max compile model.onnx --batch-size 32 --output model.max
```

### 2.4 max benchmark

```bash
# Benchmark local endpoint
max benchmark --url http://localhost:8000

# With specific concurrency
max benchmark --url http://localhost:8000 --concurrency 10

# With specific number of requests
max benchmark --url http://localhost:8000 --num-requests 1000

# With specific input length
max benchmark --url http://localhost:8000 --input-len 512 --output-len 128
```

**Options:**

| Flag | Description | Default |
|------|-------------|---------|
| `--url` | Endpoint URL | http://localhost:8000 |
| `--concurrency` | Concurrent requests | 1 |
| `--num-requests` | Total requests | 100 |
| `--input-len` | Input token length | 128 |
| `--output-len` | Output token length | 128 |
| `--model` | Model name | - |
| `--timeout` | Request timeout | 60 |

### 2.5 max device

```bash
# List available devices
max device list

# Get device info
max device info

# Check device status
max device status
```

### 2.6 max warm-cache

```bash
# Precompile and cache model
max warm-cache model.onnx

# With specific target
max warm-cache model.onnx --target gpu

# Output compiled graph
max warm-cache model.onnx --output compiled.max
```

---

## 3. Python API Overview

### 3.1 Module Structure

```python
import max

# Core modules
from max import engine      # Inference engine
from max import graph       # Graph construction
from max import tensor      # Tensor operations
from max import dtype       # Data types
from max import driver      # Low-level device management
from max import nn          # Neural network layers
from max import optimizer   # Optimizers

# Submodules
from max.graph import ops   # Graph operations
from max.experimental import functional as F  # Functional ops
from max.torch import torch_custom_op  # PyTorch integration
```

### 3.2 Import Patterns

```python
# Common imports
import numpy as np
from max import engine
from max.graph import Graph, TensorType, TensorValue, ops
from max.dtype import DType
from max.device import DeviceRef, CPU, GPU

# For model development
from max.nn import Linear, Conv2d, BatchNorm, ReLU
from max.optimizer import Adam, SGD
```

---

## 4. MAX Engine (Inference)

### 4.1 InferenceSession

```python
from max import engine

# Create session
session = engine.InferenceSession()

# With specific devices
session = engine.InferenceSession(devices=[engine.GPU(0), engine.GPU(1)])

# With CPU only
session = engine.InferenceSession(devices=[engine.CPU()])

# Load model
model = session.load("model.onnx")
model = session.load("model.max")  # Compiled MAX model
model = session.load("model.pt")   # PyTorch model

# Execute model
outputs = model.execute(input_data)

# With specific inputs
outputs = model.execute({"input": input_tensor})

# Get model info
print(model.input_names)   # ['input']
print(model.output_names)  # ['output']
print(model.input_shapes)  # [(1, 3, 224, 224)]
```

### 4.2 Model Execution

```python
import numpy as np

# Prepare input
input_data = np.random.randn(1, 3, 224, 224).astype(np.float32)

# Execute
outputs = model.execute(input_data)

# Get output
output = outputs[0]  # NumPy array

# With multiple inputs
outputs = model.execute({
    "input_ids": input_ids,
    "attention_mask": attention_mask
})

# Access by name
logits = outputs["logits"]
```

### 4.3 Async Execution

```python
# Async execution
future = model.execute_async(input_data)

# Get result
output = future.result()

# With timeout
output = future.result(timeout=30.0)

# Check if ready
if future.done():
    output = future.result()
```

### 4.4 Session Configuration

```python
from max import engine

# Create session with config
config = engine.InferenceSessionConfig()
config.enable_profiling = True
config.enable_memory_optimization = True
config.graph_optimization_level = 3

session = engine.InferenceSession(config=config)

# Set cache directory
session = engine.InferenceSession(
    devices=[engine.GPU()],
    cache_dir="/path/to/cache"
)
```

---

## 5. MAX Graph API

### 5.1 Graph Construction

```python
from max.graph import Graph, TensorType, TensorValue, ops
from max.dtype import DType

# Define a simple graph
class LinearLayer:
    def __init__(self, weight, bias):
        self.weight = weight
        self.bias = bias
    
    def __call__(self, x: TensorValue) -> TensorValue:
        # Create constant tensors
        w = ops.constant(self.weight, dtype=DType.float32)
        b = ops.constant(self.bias, dtype=DType.float32)
        
        # Matmul and add
        return ops.matmul(x, w) + b

# Create graph
linear = LinearLayer(np.ones((784, 10)), np.zeros(10))
graph = Graph(
    "linear_graph",
    linear,
    input_types=[TensorType(DType.float32, (1, 784))]
)

# Compile graph
compiled = graph.compile()
```

### 5.2 TensorType and TensorValue

```python
from max.graph import TensorType, TensorValue
from max.dtype import DType

# Create tensor type
input_type = TensorType(DType.float32, (1, 3, 224, 224))
input_type = TensorType(DType.float32, "batch", 3, 224, 224)  # Dynamic batch

# Create tensor value
value = TensorValue(data)  # From numpy array
value = ops.constant(data, dtype=DType.float32)

# Get shape and dtype
shape = value.shape
dtype = value.dtype
```

### 5.3 Device References

```python
from max.device import DeviceRef, CPU, GPU

# CPU device
cpu = CPU()

# GPU device
gpu = GPU()      # Default GPU
gpu = GPU(0)     # Specific GPU
gpu = GPU("cuda:0")

# Device reference
device = DeviceRef.CPU()
device = DeviceRef.GPU(0)
```

### 5.4 Graph Compilation

```python
# Compile graph
compiled = graph.compile(
    target="gpu",           # Target device
    optimization_level=3,  # Optimization level (0-3)
    enable_profiling=True   # Enable profiling
)

# Execute compiled graph
output = compiled.execute(input_data)

# Save compiled graph
compiled.save("compiled_graph.max")

# Load compiled graph
loaded = engine.InferenceSession().load("compiled_graph.max")
```

---

## 6. Tensor Operations

### 6.1 Creating Tensors

```python
from max import tensor
import numpy as np

# From numpy array
data = np.random.randn(1, 3, 224, 224).astype(np.float32)
t = tensor.from_numpy(data)

# Create empty tensor
t = tensor.empty((1, 3, 224, 224), dtype=tensor.float32)

# Create zeros/ones
t = tensor.zeros((1, 3, 224, 224), dtype=tensor.float32)
t = tensor.ones((1, 3, 224, 224), dtype=tensor.float32)

# Create random
t = tensor.randn(1, 3, 224, 224)  # Normal distribution
t = tensor.rand(1, 3, 224, 224)     # Uniform [0, 1)

# Create arange
t = tensor.arange(0, 10, 1)  # [0, 1, 2, ..., 9]

# Create linspace
t = tensor.linspace(0, 1, 100)
```

### 6.2 Tensor Properties

```python
# Shape and dimensions
shape = t.shape          # (1, 3, 224, 224)
ndim = t.ndim            # 4
size = t.size            # 1 * 3 * 224 * 224 = 150528
dtype = t.dtype          # float32

# Device
device = t.device        # CPU or GPU

# Convert to numpy
arr = t.numpy()          # NumPy array (copies if needed)
```

### 6.3 Tensor Operations

```python
# Reshape
t2 = t.reshape(1, 3, -1)      # (1, 3, 50176)
t2 = t.view(1, 3, 224, 224)   # View with same data

# Transpose
t2 = t.transpose(0, 2)          # Swap dims 0 and 2
t2 = t.permute(0, 2, 3, 1)      # Reorder dimensions

# Squeeze/Unsqueeze
t2 = t.squeeze(0)               # Remove dim 0 if size 1
t2 = t.unsqueeze(0)             # Add dim at position 0

# Concatenate
t3 = tensor.cat([t1, t2], dim=0)  # Concatenate along dim 0

# Stack
t3 = tensor.stack([t1, t2], dim=0)  # Stack along new dim 0

# Split
splits = t.split(3, dim=1)      # Split into chunks of size 3

# Slice
t2 = t[:, :, 0:112, 0:112]      # Slice
```

### 6.4 Mathematical Operations

```python
# Element-wise operations
c = a + b
c = a - b
c = a * b
c = a / b
c = a ** b

# In-place operations
a += b
a *= b

# Reductions
sum_val = t.sum()
sum_dim = t.sum(dim=1, keepdim=True)
mean_val = t.mean()
max_val = t.max()
min_val = t.min()
argmax = t.argmax()

# Broadcasting
c = a + 1.0  # Scalar broadcast
c = a + b    # Shape broadcast
```

---

## 7. Graph Operations (ops)

### 7.1 Core Operations

```python
from max.graph import ops

# Constants
c = ops.constant(value, dtype=DType.float32)
c = ops.constant(np.array([1, 2, 3]))

# Placeholder (for inputs)
x = ops.placeholder(TensorType(DType.float32, (1, 784)), name="input")

# Variable (trainable)
v = ops.variable(initial_value, name="weight", trainable=True)
```

### 7.2 Linear Algebra

```python
# Matrix multiplication
c = ops.matmul(a, b)
c = ops.matmul(a, b, transpose_a=True)
c = ops.matmul(a, b, transpose_b=True)

# Batch matrix multiplication
c = ops.batch_matmul(a, b)

# Dot product
d = ops.dot(a, b)

# Outer product
o = ops.outer(a, b)
```

### 7.3 Convolution Operations

```python
# 2D Convolution
out = ops.conv2d(
    input, weight,
    stride=(1, 1),
    padding=(0, 0),
    dilation=(1, 1),
    groups=1
)

# Transposed convolution
out = ops.conv_transpose2d(input, weight, stride=2)

# Depthwise convolution
out = ops.depthwise_conv2d(input, weight)
```

### 7.4 Activation Functions

```python
from max.experimental import functional as F

# ReLU
out = F.relu(x)
out = F.leaky_relu(x, negative_slope=0.01)
out = F.relu6(x)

# Sigmoid/Softmax
out = F.sigmoid(x)
out = F.softmax(x, dim=-1)
out = F.log_softmax(x, dim=-1)

# Tanh
out = F.tanh(x)

# GELU
out = F.gelu(x)

# Swish/SiLU
out = F.silu(x)
out = F.swish(x)  # Alias

# ELU
out = F.elu(x, alpha=1.0)

# SELU
out = F.selu(x)

# Hard variants
out = F.hard_sigmoid(x)
out = F.hard_swish(x)
out = F.hard_tanh(x)
```

### 7.5 Normalization

```python
# Batch normalization
out = F.batch_norm(x, running_mean, running_var, weight, bias, training=True)

# Layer normalization
out = F.layer_norm(x, normalized_shape, weight, bias, eps=1e-5)

# Group normalization
out = F.group_norm(x, num_groups, weight, bias, eps=1e-5)

# Instance normalization
out = F.instance_norm(x, running_mean, running_var, weight, bias)

# RMS normalization
out = F.rms_norm(x, weight, eps=1e-6)
```

### 7.6 Pooling Operations

```python
# Max pooling
out = F.max_pool2d(x, kernel_size=2, stride=2)
out = F.max_pool2d(x, kernel_size=(2, 2), stride=(2, 2), padding=(0, 0))

# Average pooling
out = F.avg_pool2d(x, kernel_size=2, stride=2)

# Adaptive pooling
out = F.adaptive_avg_pool2d(x, output_size=(1, 1))
out = F.adaptive_max_pool2d(x, output_size=(1, 1))

# Global pooling
out = F.global_avg_pool2d(x)
out = F.global_max_pool2d(x)
```

### 7.7 Shape Manipulation

```python
# Reshape
out = ops.reshape(x, new_shape)
out = ops.reshape(x, (1, -1))

# Transpose
out = ops.transpose(x, dim0=0, dim1=1)

# Permute (reorder all dims)
out = ops.permute(x, (0, 2, 3, 1))

# Squeeze/Unsqueeze
out = ops.squeeze(x, dim=0)
out = ops.unsqueeze(x, dim=0)

# Flatten
out = ops.flatten(x, start_dim=1)

# Expand
out = ops.expand(x, new_shape)

# Broadcast to
out = ops.broadcast_to(x, target_shape)
```

### 7.8 Indexing and Gathering

```python
# Index select
out = ops.index_select(x, dim=0, index=indices)

# Gather
out = ops.gather(x, dim=1, index=indices)

# Scatter
out = ops.scatter(input, dim=1, index=indices, src=source)

# Embedding lookup
out = ops.embedding(weight, indices)

# One-hot
out = ops.one_hot(indices, num_classes=10)
```

### 7.9 Reduction Operations

```python
# Sum
out = ops.sum(x)
out = ops.sum(x, dim=1, keepdim=True)

# Mean
out = ops.mean(x)
out = ops.mean(x, dim=1)

# Product
out = ops.prod(x)

# Min/Max
min_val = ops.min(x)
max_val = ops.max(x)
min_val, min_idx = ops.min(x, dim=1, keepdim=True)

# Argmin/Argmax
min_idx = ops.argmin(x, dim=1)
max_idx = ops.argmax(x, dim=1)

# Cumulative
out = ops.cumsum(x, dim=0)
out = ops.cumprod(x, dim=0)
```

### 7.10 Comparison Operations

```python
# Element-wise comparison
mask = ops.eq(x, y)   # x == y
mask = ops.ne(x, y)   # x != y
mask = ops.gt(x, y)   # x > y
mask = ops.ge(x, y)   # x >= y
mask = ops.lt(x, y)   # x < y
mask = ops.le(x, y)   # x <= y

# Where (conditional)
out = ops.where(condition, x, y)

# Clip
out = ops.clip(x, min_val, max_val)
```

### 7.11 Mathematical Functions

```python
# Exponential and logarithmic
out = ops.exp(x)
out = ops.log(x)
out = ops.log1p(x)      # log(1 + x)
out = ops.exp2(x)       # 2^x
out = ops.log2(x)
out = ops.log10(x)

# Power
out = ops.pow(x, exponent)
out = ops.sqrt(x)
out = ops.rsqrt(x)      # 1/sqrt(x)
out = ops.cbrt(x)       # Cube root

# Trigonometric
out = ops.sin(x)
out = ops.cos(x)
out = ops.tan(x)
out = ops.asin(x)
out = ops.acos(x)
out = ops.atan(x)
out = ops.atan2(y, x)

# Hyperbolic
out = ops.sinh(x)
out = ops.cosh(x)
out = ops.tanh(x)
```

### 7.12 Random Operations

```python
# Random number generation
out = ops.random.uniform(shape=(3, 3), minval=0.0, maxval=1.0)
out = ops.random.normal(shape=(3, 3), mean=0.0, stddev=1.0)
out = ops.random.randint(shape=(3, 3), minval=0, maxval=10)

# Dropout (training)
out = ops.dropout(x, p=0.5, training=True)
```

### 7.13 Attention Operations

```python
# Scaled dot-product attention
out = ops.scaled_dot_product_attention(
    query, key, value,
    attn_mask=None,
    dropout_p=0.0,
    is_causal=False
)

# Multi-head attention
out = ops.multi_head_attention(
    query, key, value,
    num_heads,
    in_proj_weight,
    out_proj_weight,
    in_proj_bias,
    out_proj_bias,
    dropout_p=0.0
)
```

---

## 8. GPU Programming (Mojo)

### 8.1 Device Context

```mojo
from max.gpu.host import DeviceContext, Device
from max.gpu import thread_idx, block_idx, block_dim

# Get device
var device = Device(0)
var ctx = device.create_context()

# Or create context directly
var ctx = DeviceContext()
```

### 8.2 Kernel Definition

```mojo
from max.gpu import thread_idx, block_idx, block_dim

# Define kernel
fn my_kernel(data: DTypePointer[DType.float32], size: Int):
    var idx = block_idx.x * block_dim.x + thread_idx.x
    if idx < size:
        data[idx] = data[idx] * 2.0

# Launch kernel
ctx.enqueue_function[my_kernel](
    data,
    size,
    grid_dim=(blocks,),
    block_dim=(threads,)
)
```

### 8.3 Memory Allocation

```mojo
from max.gpu.host import DeviceContext

# Allocate GPU memory
var buffer = ctx.allocate[DType.float32](1024)

# Allocate with specific flags
var buffer = ctx.allocate[DType.float32](
    size,
    host_accessible=True,
    cached=False
)

# Copy data
ctx.copy_from_host(buffer, host_ptr, size)
ctx.copy_to_host(host_ptr, buffer, size)

# Memset
ctx.memset(buffer, 0, size)
```

### 8.4 Kernel Launch

```mojo
# Simple 1D launch
var threads = 256
var blocks = (size + threads - 1) // threads

ctx.enqueue_function[kernel](
    buffer,
    size,
    grid_dim=(blocks,),
    block_dim=(threads,)
)

# 2D launch
ctx.enqueue_function[kernel2d](
    buffer,
    width,
    height,
    grid_dim=(blocks_x, blocks_y),
    block_dim=(16, 16)
)

# 3D launch
ctx.enqueue_function[kernel3d](
    buffer,
    grid_dim=(blocks_x, blocks_y, blocks_z),
    block_dim=(8, 8, 8)
)

# With shared memory
ctx.enqueue_function[kernel](
    args...,
    grid_dim=(blocks,),
    block_dim=(threads,),
    shared_mem_bytes=1024
)
```

### 8.5 Synchronization

```mojo
# Synchronize context
ctx.synchronize()

# Synchronize stream
ctx.synchronize_stream(stream)

# Event
var event = ctx.create_event()
ctx.record_event(event)
ctx.wait_event(event)
```

### 8.6 Shared Memory

```mojo
from max.gpu.memory import shared_memory
from max.gpu.sync import barrier

fn kernel_with_shared():
    # Allocate shared memory
    var shared = shared_memory[DType.float32, 256]()
    
    # Load to shared memory
    var tid = thread_idx.x
    shared[tid] = global_data[tid]
    
    # Synchronize
    barrier()
    
    # Use shared data
    var val = shared[(tid + 1) % 256]
```

### 8.7 Warp Operations

```mojo
from max.gpu.warp import reduce, shuffle

# Warp-level reduction
var sum = reduce.add(val)
var min_val = reduce.min(val)
var max_val = reduce.max(val)

# Shuffle
var broadcast = shuffle.broadcast(val, lane=0)
var shifted = shuffle.shift_up(val, delta=1)
var shifted_down = shuffle.shift_down(val, delta=1)
var xor_val = shuffle.xor(val, mask=1)
```

### 8.8 Tensor Cores (WMMA)

```mojo
from max.gpu.tensor_core import wmma

# Define fragments
var a_frag = wmma.Fragment[wmma.matrix_a, M, N, K, DType.float16]()
var b_frag = wmma.Fragment[wmma.matrix_b, M, N, K, DType.float16]()
var c_frag = wmma.Fragment[wmma.accumulator, M, N, K, DType.float32]()

# Load data
wmma.load_matrix_sync(a_frag, a_ptr, lda)
wmma.load_matrix_sync(b_frag, b_ptr, ldb)

// Matrix multiply
wmma.mma_sync(c_frag, a_frag, b_frag, c_frag)

// Store result
wmma.store_matrix_sync(c_ptr, c_frag, ldc, wmma.mem_row_major)
```

---

## 9. MAX Accelerator Library

### 9.1 Module Structure (Moved in 26.5)

```mojo
# Old (pre-26.5)
from std.algorithm import parallelize
from std.benchmark import Bencher

# New (26.5+)
from max.algorithm import parallelize
from max.benchmark import Bencher
from max.gpu.compute import *
from max.gpu.host import *
from max.gpu.memory import *
from max.gpu.sync import *
```

### 9.2 GPU Compute Operations

```mojo
from max.gpu.compute import reduce, scan, sort

# Parallel reduction
var result = reduce.add(data, size)
var result = reduce.min(data, size)
var result = reduce.max(data, size)

# Parallel scan (prefix sum)
var output = scan.inclusive_sum(input, size)
var output = scan.exclusive_sum(input, size)

# Parallel sort
sort.keys(keys, values, size)
```

### 9.3 Benchmarking

```mojo
from max.benchmark import Bencher

fn benchmark(mut b: Bencher):
    @always_inline
    def call_fn():
        run_computation()
    
    b.iter(call_fn)

# Run benchmark
var bencher = Bencher()
benchmark(bencher)
bencher.print_report()
```

### 9.4 Multi-Context

```mojo
from max.gpu.host import DeviceContextList

# Multiple contexts
var contexts = DeviceContextArray[length=4](
    Device(0),
    Device(1),
    Device(2),
    Device(3)
)

# Use contexts
for ctx in contexts:
    ctx.enqueue_function[kernel](...)
```

---

## 10. Model Development

### 10.1 Defining Modules

```python
from max.nn import Module, Linear, Conv2d, BatchNorm2d, ReLU
from max.graph import TensorValue

class MyModel(Module):
    def __init__(self):
        super().__init__()
        self.conv1 = Conv2d(3, 64, kernel_size=3, padding=1)
        self.bn1 = BatchNorm2d(64)
        self.relu = ReLU()
        self.fc = Linear(64 * 56 * 56, 10)
    
    def forward(self, x: TensorValue) -> TensorValue:
        x = self.conv1(x)
        x = self.bn1(x)
        x = self.relu(x)
        x = ops.flatten(x, start_dim=1)
        x = self.fc(x)
        return x

# Create and compile
model = MyModel()
compiled = model.compile()
```

### 10.2 Training Loop

```python
from max.optimizer import Adam
from max.nn import CrossEntropyLoss

# Setup
model = MyModel()
optimizer = Adam(model.parameters(), lr=0.001)
criterion = CrossEntropyLoss()

# Training
for epoch in range(num_epochs):
    for batch in dataloader:
        inputs, labels = batch
        
        # Forward
        outputs = model(inputs)
        loss = criterion(outputs, labels)
        
        # Backward
        loss.backward()
        
        # Update
        optimizer.step()
        optimizer.zero_grad()
```

### 10.3 Saving and Loading

```python
# Save model
model.save("model.max")

# Load model
loaded_model = engine.InferenceSession().load("model.max")

# Save weights only
model.save_weights("weights.npz")

# Load weights
model.load_weights("weights.npz")
```

---

## 11. Custom Operations

### 11.1 Registering Custom Ops

```python
from max.graph import compiler

@compiler.register
def my_custom_op(x, weight, bias):
    # Custom computation
    return x @ weight + bias
```

### 11.2 Custom GPU Kernels

```mojo
from max.gpu.host import DeviceContext

fn custom_kernel[data_type: DType](
    output: DTypePointer[data_type],
    input: DTypePointer[data_type],
    size: Int
):
    var idx = block_idx.x * block_dim.x + thread_idx.x
    if idx < size:
        output[idx] = compute(input[idx])

# Compile and register
ctx.compile_function[custom_kernel]()
```

---

## 12. PyTorch Integration

### 12.1 Using PyTorch Models

```python
import torch
from max import engine

# Load PyTorch model
model = torch.load("model.pt")

# Convert to MAX
session = engine.InferenceSession()
max_model = session.load(model)

# Or trace and convert
traced = torch.jit.trace(model, example_input)
max_model = session.load(traced)
```

### 12.2 Custom PyTorch Ops

```python
from max.torch import torch_custom_op
from max.graph import ops

@torch_custom_op
def max_custom_op(x, y):
    # Use MAX operations
    return ops.matmul(x, y) + ops.relu(x)

# Use in PyTorch
import torch.nn as nn

class MyModule(nn.Module):
    def forward(self, x, y):
        return max_custom_op(x, y)
```

---

## 13. Serving and Deployment

### 13.1 OpenAI-Compatible API

```python
from max.serve import Server, OpenAIConfig

# Configure server
config = OpenAIConfig(
    model="llama-3.1-8b",
    device="gpu",
    tensor_parallel_size=1
)

# Start server
server = Server(config)
server.start(port=8000)
```

### 13.2 Batch Processing

```python
from max.serve import BatchProcessor

processor = BatchProcessor(
    model="model.max",
    max_batch_size=32,
    max_latency_ms=100
)

# Process requests
results = processor.process_batch(requests)
```

### 13.3 Docker Deployment

```dockerfile
FROM modular/max:latest

COPY model.max /app/model.max

EXPOSE 8000

CMD ["max", "serve", "--model-path", "/app/model.max", "--port", "8000"]
```

---

## 14. C API

### 14.1 Basic Usage

```c
#include <max/max.h>

// Initialize
M_Status status = M_Init();

// Create session
M_InferenceSession session;
status = M_CreateInferenceSession(&session, NULL);

// Load model
M_Model model;
status = M_LoadModel(session, "model.max", &model);

// Prepare input
M_Tensor input;
float data[784] = {...};
status = M_CreateTensor(&input, data, sizeof(data), 
                        (int64_t[]){1, 784}, 2, M_FLOAT32);

// Execute
M_Tensor output;
status = M_Execute(model, &input, 1, &output, 1);

// Cleanup
M_DestroyTensor(input);
M_DestroyModel(model);
M_DestroySession(session);
M_Shutdown();
```

---

## 15. Configuration and Environment

### 15.1 Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MAX_CACHE_DIR` | Cache directory | `~/.max/cache` |
| `MAX_LOG_LEVEL` | Logging level | `INFO` |
| `CUDA_VISIBLE_DEVICES` | Visible GPUs | all |
| `MAX_DEVICE` | Default device | auto |
| `MAX_COMPILE_CACHE` | Compile cache | `~/.max/compile` |
| `MODULAR_HOME` | Modular installation | `~/.modular` |

### 15.2 Configuration Files

```json
// max.json
{
  "device": {
    "default": "gpu",
    "gpu_memory_fraction": 0.9
  },
  "compilation": {
    "optimization_level": 3,
    "cache_dir": "~/.max/cache"
  },
  "serving": {
    "port": 8000,
    "host": "0.0.0.0",
    "max_batch_size": 32
  }
}
```

---

## 16. Performance Optimization

### 16.1 Graph Optimization

```python
# Enable all optimizations
config = engine.InferenceSessionConfig()
config.graph_optimization_level = 3  # 0=off, 1=basic, 2=extended, 3=all
config.enable_memory_optimization = True

session = engine.InferenceSession(config=config)
```

### 16.2 Quantization

```python
# INT8 quantization
model = session.load(
    "model.onnx",
    quantization="int8",
    calibration_dataset=calib_data
)

# INT4 quantization (for LLMs)
model = session.load(
    "model.onnx",
    quantization="int4",
    group_size=128
)
```

### 16.3 Profiling

```python
# Enable profiling
config = engine.InferenceSessionConfig()
config.enable_profiling = True

session = engine.InferenceSession(config=config)
model = session.load("model.max")

# Run inference
output = model.execute(input_data)

# Get profile
profile = model.get_profile()
print(profile.summary())
```

---

## Appendix A: Quick Reference

### Minimal Python Example

```python
from max import engine

# Load and run model
session = engine.InferenceSession()
model = session.load("model.onnx")
output = model.execute(input_data)
print(output)
```

### Minimal Mojo GPU Example

```mojo
from max.gpu.host import DeviceContext

var ctx = DeviceContext()

fn kernel(data: DTypePointer[DType.float32]):
    var idx = block_idx.x * block_dim.x + thread_idx.x
    data[idx] *= 2.0

var buffer = ctx.allocate[DType.float32](1024)
ctx.enqueue_function[kernel](buffer, grid_dim=(4,), block_dim=(256,))
ctx.synchronize()
```

### CLI Quick Start

```bash
# Serve LLM
max serve --model llama-3.1-8b

# Run inference
max run --model bert --input "Hello world"

# Benchmark
max benchmark --url http://localhost:8000
```

---

*This reference guide is based on Modular MAX Platform 26.5 (August 2026). For the latest updates, consult the official documentation at https://docs.modular.com/*

---
