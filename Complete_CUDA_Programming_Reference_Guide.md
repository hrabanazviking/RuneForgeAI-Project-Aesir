# 🚀 The Complete CUDA Programming Reference Guide

(Complete_CUDA_Programming_Reference_Guide.md)

## Version Information

**Current Stable Release:** CUDA Toolkit 13.3 Update 1 (June 27, 2026)  
**Developer Preview:** CUDA Toolkit 13.4 (July 2026)  
**Supported Architectures:** Turing (sm_75), Ampere (sm_80, sm_86), Ada (sm_89), Hopper (sm_90), Blackwell (sm_100, sm_101, sm_110, sm_120)  
**Dropped Support:** Maxwell and older (pre-Turing offline compilation removed in CUDA 13.0)  
**Minimum Driver:** Linux 610.43.02, Windows 13.3.31

---

## Table of Contents

1. [CUDA C++ Language Extensions](#1-cuda-c-language-extensions)
2. [Execution Model](#2-execution-model)
3. [Built-in Variables](#3-built-in-variables)
4. [Kernel Launch Configuration](#4-kernel-launch-configuration)
5. [Memory Management (Runtime API)](#5-memory-management-runtime-api)
6. [Stream Management](#6-stream-management)
7. [Event Management](#7-event-management)
8. [Texture and Surface APIs](#8-texture-and-surface-apis)
9. [Unified Memory](#9-unified-memory)
10. [Warp-Level Primitives](#10-warp-level-primitives)
11. [Atomic Operations](#11-atomic-operations)
12. [Synchronization](#12-synchronization)
13. [Math Library](#13-math-library)
14. [CUDA Libraries](#14-cuda-libraries)
15. [Graph APIs](#15-graph-apis)
16. [Driver API](#16-driver-api)
17. [NVCC Compiler](#17-nvcc-compiler)
18. [Error Handling](#18-error-handling)
19. [CUDA 13.x New Features](#19-cuda-13x-new-features)

---

## 1. CUDA C++ Language Extensions

### 1.1 Function Type Qualifiers

| Qualifier | Syntax | Description |
|-----------|--------|-------------|
| `__global__` | `__global__ void kernel()` | Executed on device, callable from host |
| `__device__` | `__device__ float func()` | Executed on device, callable from device only |
| `__host__` | `__host__ void func()` | Executed on host, callable from host only |
| `__host__ __device__` | `__host__ __device__ void func()` | Compiled for both host and device |

```cuda
// Kernel definition - called from host, runs on device
__global__ void vectorAdd(const float *A, const float *B, float *C, int numElements) {
    int i = blockDim.x * blockIdx.x + threadIdx.x;
    if (i < numElements) {
        C[i] = A[i] + B[i];
    }
}

// Device function - called from device code only
__device__ float clamp(float x, float min, float max) {
    return fminf(fmaxf(x, min), max);
}

// Host-device function - works on both
__host__ __device__ int add(int a, int b) {
    return a + b;
}
```

### 1.2 Variable Type Qualifiers

| Qualifier | Memory Space | Scope | Lifetime | Access |
|-----------|--------------|-------|----------|--------|
| `__device__` | Global memory | Grid | Application | Read/write by all threads |
| `__constant__` | Constant memory | Grid | Application | Read-only by device, write by host |
| `__shared__` | Shared memory | Block | Block | Read/write by block threads |
| `__managed__` | Unified memory | Grid | Application | Automatic migration |
| `__restrict__` | N/A (pointer qualifier) | - | - | No aliasing hint |

```cuda
// Global variable (device memory)
__device__ float devData;

// Constant memory (cached read-only)
__constant__ float constData[256];

// Kernel with shared memory
__global__ void sharedMemKernel(float *input) {
    __shared__ float sharedData[256];  // Per-block shared memory
    int tid = threadIdx.x;
    sharedData[tid] = input[tid];
    __syncthreads();
    // Use sharedData...
}

// Managed memory (Unified Memory)
__managed__ float managedData[1024];
```

### 1.3 Execution Space Qualifiers (New in CUDA 13)

| Qualifier | Description |
|-----------|-------------|
| `__forceinline__` | Force inline expansion |
| `__noinline__` | Prevent inline expansion |
| `__launch_bounds__(maxThreadsPerBlock, minBlocksPerMultiprocessor)` | Register pressure hint |

```cuda
// Launch bounds for occupancy optimization
__launch_bounds__(256, 4)
__global__ void optimizedKernel() {
    // Compiler optimizes for 256 threads/block, 4 blocks/SM
}
```

---

## 2. Execution Model

### 2.1 Thread Hierarchy

```
Grid (1D, 2D, or 3D)
├── Block (0,0,0) ────┬── Thread (0,0,0)
│                      ├── Thread (1,0,0)
│                      └── ...
├── Block (1,0,0) ────┬── Thread (0,0,0)
│                     └── ...
└── ...

Maximum Dimensions (Compute Capability 9.0+):
- Grid: (2^31-1, 65535, 65535)
- Block: (1024, 1024, 64), max 1024 threads total
- Warp: 32 threads (always)
```

### 2.2 Scheduling

| Concept | Description |
|---------|-------------|
| **Warp** | 32 threads executing in SIMT fashion |
| **Warp Scheduler** | Dispatches instructions to warps |
| **Occupancy** | Ratio of active warps to maximum warps per SM |
| **Cooperative Groups** | Thread collaboration beyond warp level |

---

## 3. Built-in Variables

### 3.1 Grid and Block Dimensions

| Variable | Type | Description | Range |
|----------|------|-------------|-------|
| `gridDim` | `dim3` | Grid dimensions in blocks | 1 to 2^31-1 (x), 65535 (y,z) |
| `blockDim` | `dim3` | Block dimensions in threads | 1 to 1024 |
| `blockIdx` | `dim3` | Block index within grid | 0 to gridDim-1 |
| `threadIdx` | `dim3` | Thread index within block | 0 to blockDim-1 |
| `warpSize` | `int` | Warp size (threads per warp) | 32 |

```cuda
// 1D indexing
int globalIdx = blockIdx.x * blockDim.x + threadIdx.x;

// 2D indexing
int row = blockIdx.y * blockDim.y + threadIdx.y;
int col = blockIdx.x * blockDim.x + threadIdx.x;
int idx = row * width + col;

// 3D indexing
int x = blockIdx.x * blockDim.x + threadIdx.x;
int y = blockIdx.y * blockDim.y + threadIdx.y;
int z = blockIdx.z * blockDim.z + threadIdx.z;
```

### 3.2 Clock and Performance Counters

| Variable/Function | Description |
|-------------------|-------------|
| `clock()` | Returns cycle counter (per-SM, wraps) |
| `clock64()` | 64-bit cycle counter |
| `__pm0()` to `__pm3()` | Performance monitor counters |

---

## 4. Kernel Launch Configuration

### 4.1 Execution Configuration Syntax

```cuda
// Basic syntax
kernel<<<numBlocks, threadsPerBlock>>>(args);

// With shared memory bytes
kernel<<<numBlocks, threadsPerBlock, sharedMemBytes>>>(args);

// With stream
kernel<<<numBlocks, threadsPerBlock, sharedMemBytes, stream>>>(args);

// dim3 for multi-dimensional
dim3 blocks(16, 16);
dim3 threads(32, 32);
kernel<<<blocks, threads>>>(args);
```

### 4.2 Dynamic Parallelism (Device-side Launch)

```cuda
__global__ void parentKernel() {
    // Launch child kernel from device
    childKernel<<<gridDim, blockDim>>>(args);
    
    // Synchronize with child
    cudaDeviceSynchronize();
}
```

### 4.3 Cooperative Groups Launch

```cuda
// Multi-device cooperative launch
cudaLaunchCooperativeKernel(
    (void*)kernel,
    gridDim,
    blockDim,
    kernelArgs,
    sharedMemBytes,
    stream
);

// Get max active blocks per multiprocessor
cudaOccupancyMaxActiveBlocksPerMultiprocessor(
    &numBlocks,
    kernel,
    blockSize,
    dynamicSmemSize
);
```

---

## 5. Memory Management (Runtime API)

### 5.1 Device Memory Allocation

```cuda
// Basic allocation
cudaError_t cudaMalloc(void** devPtr, size_t size);

// Pitched allocation (for 2D/3D arrays)
cudaError_t cudaMallocPitch(void** devPtr, size_t* pitch, size_t width, size_t height);

// 3D allocation
cudaError_t cudaMalloc3D(cudaPitchedPtr* pitchedDevPtr, cudaExtent extent);

// Array allocation (for textures)
cudaError_t cudaMallocArray(cudaArray_t* array, const cudaChannelFormatDesc* desc, size_t width, size_t height);

// 3D array
cudaError_t cudaMalloc3DArray(cudaArray_t* array, const cudaChannelFormatDesc* desc, cudaExtent extent);

// Free
cudaError_t cudaFree(void* devPtr);
cudaError_t cudaFreeArray(cudaArray_t array);
```

### 5.2 Host Memory Allocation

```cuda
// Pageable host memory (default)
cudaError_t cudaMallocHost(void** ptr, size_t size);  // Pinned/page-locked
cudaError_t cudaFreeHost(void* ptr);

// Portable, mapped, or write-combined
cudaError_t cudaHostAlloc(void** pHost, size_t size, unsigned int flags);

// Flags for cudaHostAlloc
cudaHostAllocDefault       = 0x00;  // Default
cudaHostAllocPortable      = 0x01;  // Portable across contexts
cudaHostAllocMapped        = 0x02;  // Mapped into device space
cudaHostAllocWriteCombined = 0x04;  // Write-combined (fast for GPU reads)

// Register existing host memory
cudaError_t cudaHostRegister(void* ptr, size_t size, unsigned int flags);
cudaError_t cudaHostUnregister(void* ptr);

// Flags for cudaHostRegister
cudaHostRegisterDefault    = 0x00;
cudaHostRegisterPortable   = 0x01;
cudaHostRegisterMapped     = 0x02;
cudaHostRegisterIoMemory   = 0x04;  // I/O memory (PCIe BAR)
```

### 5.3 Memory Copy Operations

```cuda
// Basic copy
cudaError_t cudaMemcpy(void* dst, const void* src, size_t count, cudaMemcpyKind kind);

// Copy kinds
cudaMemcpyHostToHost     = 0;  // Host to host
cudaMemcpyHostToDevice   = 1;  // Host to device
cudaMemcpyDeviceToHost   = 2;  // Device to host
cudaMemcpyDeviceToDevice = 3;  // Device to device
cudaMemcpyDefault        = 4;  // Automatic (unified virtual addressing)

// Pitched copy (2D)
cudaError_t cudaMemcpy2D(void* dst, size_t dpitch, const void* src, size_t spitch, size_t width, size_t height, cudaMemcpyKind kind);

// 3D copy
cudaError_t cudaMemcpy3D(const cudaMemcpy3DParms* p);

// Async copy
cudaError_t cudaMemcpyAsync(void* dst, const void* src, size_t count, cudaMemcpyKind kind, cudaStream_t stream);

// Peer copy (P2P)
cudaError_t cudaMemcpyPeer(void* dst, int dstDevice, const void* src, int srcDevice, size_t count);
```

### 5.4 Memory Set Operations

```cuda
// Set memory to value
cudaError_t cudaMemset(void* devPtr, int value, size_t count);
cudaError_t cudaMemsetAsync(void* devPtr, int value, size_t count, cudaStream_t stream);

// 2D memset
cudaError_t cudaMemset2D(void* devPtr, size_t pitch, int value, size_t width, size_t height);

// 3D memset
cudaError_t cudaMemset3D(cudaPitchedPtr pitchedDevPtr, int value, cudaExtent extent);
```

### 5.5 Memory Information

```cuda
// Get free and total memory
cudaError_t cudaMemGetInfo(size_t* free, size_t* total);

// Get pointer attributes
cudaError_t cudaPointerGetAttributes(cudaPointerAttributes* attributes, const void* ptr);

// Attributes structure
struct cudaPointerAttributes {
    cudaMemoryType memoryType;      // cudaMemoryTypeHost or cudaMemoryTypeDevice
    int device;                      // Device ID
    void* devicePointer;            // Device pointer (for mapped host memory)
    void* hostPointer;              // Host pointer (for managed/device memory)
    int isManaged;                  // Managed memory flag
};
```

### 5.6 Stream-Ordered Memory Allocator (CUDA 11.2+)

```cuda
// Allocate async
cudaError_t cudaMallocAsync(void** devPtr, size_t size, cudaStream_t stream);

// Free async
cudaError_t cudaFreeAsync(void* devPtr, cudaStream_t stream);

// Memory pool
cudaError_t cudaMemPoolCreate(cudaMemPool_t* memPool, const cudaMemPoolProps* props);
cudaError_t cudaMemPoolDestroy(cudaMemPool_t memPool);
cudaError_t cudaMemPoolTrimTo(cudaMemPool_t memPool, size_t minBytesToKeep);

// Set/get attributes
cudaError_t cudaMemPoolSetAttribute(cudaMemPool_t memPool, cudaMemPoolAttr attr, void* value);
cudaError_t cudaMemPoolGetAttribute(cudaMemPool_t memPool, cudaMemPoolAttr attr, void* value);
```

---

## 6. Stream Management

### 6.1 Stream Creation and Destruction

```cuda
// Default stream (NULL stream, synchronous with all blocking)
cudaStream_t stream0 = 0;

// Create stream
cudaError_t cudaStreamCreate(cudaStream_t* pStream);

// Create with priority
cudaError_t cudaStreamCreateWithPriority(cudaStream_t* pStream, unsigned int flags, int priority);

// Flags
cudaStreamDefault   = 0x00;  // Default stream
cudaStreamNonBlocking = 0x01;  // Non-blocking (doesn't sync with NULL stream)

// Priority range (lower number = higher priority)
// Query with: cudaDeviceGetStreamPriorityRange(&least, &greatest);

// Destroy
cudaError_t cudaStreamDestroy(cudaStream_t stream);
```

### 6.2 Stream Synchronization

```cuda
// Synchronize stream (block until all operations complete)
cudaError_t cudaStreamSynchronize(cudaStream_t stream);

// Query if stream is idle
cudaError_t cudaStreamQuery(cudaStream_t stream);  // Returns cudaSuccess or cudaErrorNotReady

// Wait for event
cudaError_t cudaStreamWaitEvent(cudaStream_t stream, cudaEvent_t event, unsigned int flags);

// Callback (deprecated in favor of graphs)
cudaError_t cudaStreamAddCallback(cudaStream_t stream, cudaStreamCallback_t callback, void* userData, unsigned int flags);
```

### 6.3 Stream Attributes (CUDA 13)

```cuda
// Get/Set stream attributes
cudaError_t cudaStreamGetAttribute(cudaStream_t stream, cudaStreamAttrID attr, cudaStreamAttrValue* value);
cudaError_t cudaStreamSetAttribute(cudaStream_t stream, cudaStreamAttrID attr, const cudaStreamAttrValue* value);

// Access policy
cudaStreamAttrAccessPolicyWindow = 1;
```

---

## 7. Event Management

### 7.1 Event Creation and Destruction

```cuda
// Create event
cudaError_t cudaEventCreate(cudaEvent_t* event);
cudaError_t cudaEventCreateWithFlags(cudaEvent_t* event, unsigned int flags);

// Flags
cudaEventDefault        = 0x00;
cudaEventBlockingSync   = 0x01;  // Uses blocking synchronization
cudaEventDisableTiming  = 0x02;  // No timing (faster)
cudaEventInterprocess   = 0x04;  // Inter-process event

// Destroy
cudaError_t cudaEventDestroy(cudaEvent_t event);
```

### 7.2 Event Recording and Timing

```cuda
// Record event
cudaError_t cudaEventRecord(cudaEvent_t event, cudaStream_t stream);
cudaError_t cudaEventRecordWithFlags(cudaEvent_t event, cudaStream_t stream, unsigned int flags);

// Synchronize on event
cudaError_t cudaEventSynchronize(cudaEvent_t event);

// Query event
cudaError_t cudaEventQuery(cudaEvent_t event);

// Elapsed time
cudaError_t cudaEventElapsedTime(float* ms, cudaEvent_t start, cudaEvent_t end);
```

---

## 8. Texture and Surface APIs

### 8.1 Texture Reference (Legacy)

```cuda
// Texture reference declaration
texture<float, cudaTextureType2D, cudaReadModeElementType> texRef;

// Bind to array
cudaBindTextureToArray(texRef, cuArray, desc);

// Fetch in kernel
float value = tex2D(texRef, x, y);
```

### 8.2 Texture Object (Modern)

```cuda
// Create texture object
cudaTextureObject_t texObj;
cudaResourceDesc resDesc;
memset(&resDesc, 0, sizeof(resDesc));
resDesc.resType = cudaResourceTypeArray;
resDesc.res.array.array = cuArray;

cudaTextureDesc texDesc;
memset(&texDesc, 0, sizeof(texDesc));
texDesc.filterMode = cudaFilterModeLinear;
texDesc.readMode = cudaReadModeElementType;

cudaCreateTextureObject(&texObj, &resDesc, &texDesc, NULL);

// Use in kernel
float value = tex2D<float>(texObj, x, y);

// Destroy
cudaDestroyTextureObject(texObj);
```

### 8.3 Surface Objects

```cuda
// Create surface object
cudaSurfaceObject_t surfObj;
cudaResourceDesc resDesc;
resDesc.resType = cudaResourceTypeArray;
resDesc.res.array.array = cuArray;
cudaCreateSurfaceObject(&surfObj, &resDesc);

// Write in kernel
surf2Dwrite(value, surfObj, x * sizeof(float), y);

// Destroy
cudaDestroySurfaceObject(surfObj);
```

---

## 9. Unified Memory

### 9.1 Managed Memory Allocation

```cuda
// Allocate managed memory
cudaError_t cudaMallocManaged(void** devPtr, size_t size, unsigned int flags);

// Flags
cudaMemAttachGlobal = 0x00;  // Accessible from all streams
cudaMemAttachHost   = 0x01;  // Hint: mostly accessed by host

// Prefetch
cudaError_t cudaMemPrefetchAsync(const void* devPtr, size_t count, int dstDevice, cudaStream_t stream);

// Advise
cudaError_t cudaMemAdvise(const void* devPtr, size_t count, cudaMemoryAdvise advice, int device);

// Advices
cudaMemAdviseSetReadMostly          = 0x00;
cudaMemAdviseUnsetReadMostly        = 0x01;
cudaMemAdviseSetPreferredLocation   = 0x02;
cudaMemAdviseUnsetPreferredLocation = 0x03;
cudaMemAdviseSetAccessedBy          = 0x04;
cudaMemAdviseUnsetAccessedBy        = 0x05;

// Query
cudaError_t cudaMemRangeGetAttribute(void* data, size_t dataSize, cudaMemRangeAttribute attribute, const void* devPtr, size_t count);
```

---

## 10. Warp-Level Primitives

### 10.1 Shuffle Operations

```cuda
// Shuffle within warp (deprecated, use sync versions)
int __shfl(int var, int srcLane, int width);
int __shfl_up(int var, unsigned int delta, int width);
int __shfl_down(int var, unsigned int delta, int width);
int __shfl_xor(int var, int laneMask, int width);

// Synchronized versions (CUDA 9.0+)
int __shfl_sync(unsigned mask, int var, int srcLane, int width);
int __shfl_up_sync(unsigned mask, int var, unsigned int delta, int width);
int __shfl_down_sync(unsigned mask, int var, unsigned int delta, int width);
int __shfl_xor_sync(unsigned mask, int var, int laneMask, int width);

// Mask: 0xFFFFFFFF for all threads in warp
// Width: 32 (warpSize), 16, 8, 4, 2 (sub-warp)
```

### 10.2 Vote Operations

```cuda
// Warp vote (deprecated)
int __all(int predicate);      // All predicate non-zero?
int __any(int predicate);      // Any predicate non-zero?
unsigned __ballot(int predicate);  // Ballot of predicates

// Synchronized versions
int __all_sync(unsigned mask, int predicate);
int __any_sync(unsigned mask, int predicate);
unsigned __ballot_sync(unsigned mask, int predicate);

// Match operations (CUDA 9.0+)
unsigned __match_any_sync(unsigned mask, int value);
unsigned __match_all_sync(unsigned mask, int value);
```

### 10.3 Warp Reduction (CUDA 13)

```cuda
// Warp-level reductions
int __reduce_add_sync(unsigned mask, int value);
int __reduce_min_sync(unsigned mask, int value);
int __reduce_max_sync(unsigned mask, int value);
unsigned int __reduce_and_sync(unsigned mask, unsigned int value);
unsigned int __reduce_or_sync(unsigned mask, unsigned int value);
unsigned int __reduce_xor_sync(unsigned mask, unsigned int value);
```

### 10.4 Active Mask and Lane ID

```cuda
// Get active mask
unsigned __activemask();

// Lane ID
int laneId = threadIdx.x % warpSize;  // Or use threadIdx.x & 31

// Lane index functions
unsigned __lane_id();  // Returns lane ID (0-31)
```

---

## 11. Atomic Operations

### 11.1 Atomic Functions

```cuda
// Arithmetic
int atomicAdd(int* address, int val);
int atomicSub(int* address, int val);
int atomicExch(int* address, int val);
int atomicMin(int* address, int val);
int atomicMax(int* address, int val);
unsigned int atomicInc(unsigned int* address, unsigned int val);
unsigned int atomicDec(unsigned int* address, unsigned int val);

// Bitwise
int atomicAnd(int* address, int val);
int atomicOr(int* address, int val);
int atomicXor(int* address, int val);

// Compare and swap
int atomicCAS(int* address, int compare, int val);

// 64-bit versions
unsigned long long int atomicAdd(unsigned long long int* address, unsigned long long int val);
// ... etc for other 64-bit operations

// System-scope atomics (visible to CPU and all GPUs)
int atomicAdd_system(int* address, int val);
int atomicAdd_block(int* address, int val);  // Block scope

// Floating point (CUDA 13)
float atomicAdd(float* address, float val);
double atomicAdd(double* address, double val);
__half atomicAdd(__half* address, __half val);
__half2 atomicAdd(__half2* address, __half2 val);
```

### 11.2 CUDA C++ Atomic Library

```cuda
#include <cuda/atomic>

// C++11-style atomics
__shared__ cuda::atomic<int, cuda::thread_scope_block> counter;

// Operations
counter.store(0, cuda::memory_order_relaxed);
int old = counter.fetch_add(1, cuda::memory_order_relaxed);

// Memory orders
cuda::memory_order_relaxed
cuda::memory_order_consume
cuda::memory_order_acquire
cuda::memory_order_release
cuda::memory_order_acq_rel
cuda::memory_order_seq_cst

// Scopes
cuda::thread_scope_thread    // Single thread
cuda::thread_scope_block     // Thread block
cuda::thread_scope_device    // Device (GPU)
cuda::thread_scope_system    // System (CPU + all GPUs)
```

---

## 12. Synchronization

### 12.1 Block-Level Synchronization

```cuda
// Synchronize all threads in block
__syncthreads();

// Counting barrier
__syncthreads_count(int predicate);

// AND barrier
__syncthreads_and(int predicate);

// OR barrier
__syncthreads_or(int predicate);
```

### 12.2 Warp-Level Synchronization

```cuda
// Synchronize threads in warp (implicit in shuffle/vote)
__syncwarp();

// With mask
__syncwarp(unsigned mask);
```

### 12.3 Device-Level Synchronization

```cuda
// Synchronize entire device (expensive!)
cudaDeviceSynchronize();

// From device code (dynamic parallelism)
cudaError_t cudaDeviceSynchronize(void);
```

### 12.4 Memory Fences

```cuda
// Thread fence
__threadfence();        // All memory operations visible to device
__threadfence_block();  // Visible to block
__threadfence_system(); // Visible to system (CPU + all GPUs)
```

---

## 13. Math Library

### 13.1 Standard Math Functions

```cuda
// Trigonometric
float sinf(float x);
float cosf(float x);
float tanf(float x);
float asinf(float x);
float acosf(float x);
float atanf(float x);
float atan2f(float y, float x);

// Hyperbolic
float sinhf(float x);
float coshf(float x);
float tanhf(float x);

// Exponential and Logarithmic
float expf(float x);
float exp2f(float x);
float exp10f(float x);
float expm1f(float x);  // e^x - 1
float logf(float x);
float log2f(float x);
float log10f(float x);
float log1pf(float x);  // log(1 + x)

// Power
float powf(float x, float y);
float sqrtf(float x);
float rsqrtf(float x);  // 1/sqrt(x)
float cbrtf(float x);
float rcbrtf(float x);  // 1/cbrt(x)

// Integer/Floating point
float fabsf(float x);
float fmodf(float x, float y);
float remainderf(float x, float y);
float fmaf(float x, float y, float z);  // Fused multiply-add

// Classification
int isnan(float x);
int isinf(float x);
int isfinite(float x);
int signbit(float x);

// Rounding
float ceilf(float x);
float floorf(float x);
float truncf(float x);
float roundf(float x);
float nearbyintf(float x);

// Double precision versions (replace 'f' suffix with nothing)
double sin(double x);
// ... etc
```

### 13.2 Intrinsic Functions (Faster, Less Precision)

```cuda
// Trigonometric
float __sinf(float x);    // Faster sine
float __cosf(float x);    // Faster cosine
float __sincosf(float x, float* sptr, float* cptr);  // Both

// Exponential
float __expf(float x);    // Faster exp
float __logf(float x);    // Faster log

// Other
float __frsqrt_rn(float x);  // Reciprocal sqrt
float __fdividef(float x, float y);  // Faster division
float __fmaf_rn(float x, float y, float z);  // Rounded FMA
float __fmaf_rz(float x, float y, float z);  // Truncated FMA
```

### 13.3 SIMD Math (CUDA Math API)

```cuda
// float2 operations
float2 a = make_float2(1.0f, 2.0f);
float2 b = make_float2(3.0f, 4.0f);
float2 c = a + b;  // Component-wise

// float3, float4 similarly
float4 d = make_float4(1.0f, 2.0f, 3.0f, 4.0f);
```

### 13.4 Half-Precision (FP16)

```cuda
#include <cuda_fp16.h>

// Types
__half h;
__half2 h2;  // Vector of 2 halfs

// Conversions
__half __float2half(float f);
float __half2float(__half h);
__half2 __floats2half2_rn(float f1, float f2);
float __low2float(__half2 h2);
float __high2float(__half2 h2);

// Operations
__half2 __hadd2(__half2 a, __half2 b);
__half2 __hmul2(__half2 a, __half2 b);
__half2 __hfma2(__half2 a, __half2 b, __half2 c);
```

### 13.5 BFloat16 (CUDA 13)

```cuda
#include <cuda_bf16.h>

// Type
__nv_bfloat16 bf;
__nv_bfloat162 bf2;

// Similar operations to FP16
```

### 13.6 Tensor Core Math (WMMA)

```cuda
#include <mma.h>

namespace mma = nvcuda::wmma;

// Fragment types
mma::fragment<mma::matrix_a, M, N, K, half, mma::row_major> a_frag;
mma::fragment<mma::matrix_b, M, N, K, half, mma::col_major> b_frag;
mma::fragment<mma::accumulator, M, N, K, float> c_frag;

// Load, multiply, store
mma::load_matrix_sync(a_frag, A, lda);
mma::load_matrix_sync(b_frag, B, ldb);
mma::mma_sync(c_frag, a_frag, b_frag, c_frag);
mma::store_matrix_sync(C, c_frag, ldc, mma::mem_row_major);
```

---

## 14. CUDA Libraries

### 14.1 cuBLAS (Linear Algebra)

```cuda
#include <cublas_v2.h>

// Handle
cublasHandle_t handle;
cublasCreate(&handle);

// Level 1: Vector operations
cublasSaxpy(handle, n, &alpha, x, incx, y, incy);  // y = alpha*x + y
cublasSdot(handle, n, x, incx, y, incy, result);   // dot product
cublasSnrm2(handle, n, x, incx, result);          // norm
cublasSscal(handle, n, &alpha, x, incx);          // x = alpha*x

// Level 2: Matrix-vector
cublasSgemv(handle, trans, m, n, &alpha, A, lda, x, incx, &beta, y, incy);

// Level 3: Matrix-matrix
cublasSgemm(handle, transa, transb, m, n, k, &alpha, A, lda, B, ldb, &beta, C, ldc);

// Strided batch
cublasSgemmStridedBatched(handle, transa, transb, m, n, k, &alpha, A, lda, strideA, B, ldb, strideB, &beta, C, ldc, strideC, batchCount);

// Destroy
cublasDestroy(handle);
```

### 14.2 cuFFT (Fast Fourier Transform)

```cuda
#include <cufft.h>

// Plan
cufftHandle plan;
cufftPlan1d(&plan, nx, CUFFT_C2C, batch);
cufftPlan2d(&plan, nx, ny, CUFFT_C2C);
cufftPlan3d(&plan, nx, ny, nz, CUFFT_C2C);

// Execute
cufftExecC2C(plan, idata, odata, CUFFT_FORWARD);
cufftExecC2C(plan, idata, odata, CUFFT_INVERSE);

// Types
CUFFT_R2C  // Real to complex
CUFFT_C2R  // Complex to real
CUFFT_C2C  // Complex to complex
CUFFT_D2Z  // Double to double-complex
CUFFT_Z2D  // Double-complex to double
CUFFT_Z2Z  // Double-complex to double-complex

// Destroy
cufftDestroy(plan);
```

### 14.3 cuRAND (Random Number Generation)

```cuda
#include <curand.h>

// Generator
curandGenerator_t gen;
curandCreateGenerator(&gen, CURAND_RNG_PSEUDO_DEFAULT);
curandSetPseudoRandomGeneratorSeed(gen, 1234ULL);

// Generate
curandGenerateUniform(gen, outputPtr, n);
curandGenerateNormal(gen, outputPtr, n, mean, stddev);
curandGenerateLogNormal(gen, outputPtr, n, mean, stddev);

// Types
CURAND_RNG_PSEUDO_DEFAULT
CURAND_RNG_PSEUDO_XORWOW
CURAND_RNG_PSEUDO_MRG32K3A
CURAND_RNG_PSEUDO_MTGP32
CURAND_RNG_PSEUDO_MT19937
CURAND_RNG_PSEUDO_PHILOX4_32_10
CURAND_RNG_QUASI_DEFAULT
CURAND_RNG_QUASI_SOBOL32
CURAND_RNG_QUASI_SCRAMBLED_SOBOL32

// Destroy
curandDestroyGenerator(gen);
```

### 14.4 cuDNN (Deep Neural Networks)

```cuda
#include <cudnn.h>

// Handle
cudnnHandle_t handle;
cudnnCreate(&handle);

// Tensor descriptor
cudnnTensorDescriptor_t desc;
cudnnCreateTensorDescriptor(&desc);
cudnnSetTensor4dDescriptor(desc, format, dataType, n, c, h, w);

// Convolution
cudnnConvolutionDescriptor_t convDesc;
cudnnCreateConvolutionDescriptor(&convDesc);
cudnnSetConvolution2dDescriptor(convDesc, pad_h, pad_w, stride_h, stride_w, dilation_h, dilation_w, mode, computeType);

// Forward convolution
cudnnConvolutionForward(handle, &alpha, xDesc, x, wDesc, w, convDesc, algo, workSpace, workSpaceSize, &beta, yDesc, y);

// Destroy
cudnnDestroyTensorDescriptor(desc);
cudnnDestroyConvolutionDescriptor(convDesc);
cudnnDestroy(handle);
```

### 14.5 NCCL (Multi-GPU Communication)

```cuda
#include <nccl.h>

// Initialize
ncclComm_t comm;
ncclUniqueId id;
ncclGetUniqueId(&id);
ncclCommInitRank(&comm, nranks, id, rank);

// Collective operations
ncclAllSend(sendbuff, sendcount, datatype, dest, comm, stream);
ncclAllRecv(recvbuff, recvcount, datatype, src, comm, stream);
ncclBroadcast(sendbuff, recvbuff, count, datatype, root, comm, stream);
ncclAllReduce(sendbuff, recvbuff, count, datatype, op, comm, stream);
ncclReduce(sendbuff, recvbuff, count, datatype, op, root, comm, stream);
ncclAllGather(sendbuff, recvbuff, sendcount, datatype, comm, stream);
ncclReduceScatter(sendbuff, recvbuff, recvcount, datatype, op, comm, stream);

// Operations
ncclSum, ncclProd, ncclMax, ncclMin, ncclAvg

// Finalize
ncclCommDestroy(comm);
```

---

## 15. Graph APIs

### 15.1 Graph Creation

```cuda
// Create graph
cudaGraph_t graph;
cudaGraphCreate(&graph, 0);

// Add kernel node
cudaGraphNode_t kernelNode;
cudaKernelNodeParams kernelParams = {0};
kernelParams.func = (void*)kernel;
kernelParams.gridDim = dim3(blocks);
kernelParams.blockDim = dim3(threads);
kernelParams.sharedMemBytes = 0;
kernelParams.kernelParams = args;
kernelParams.extra = NULL;
cudaGraphAddKernelNode(&kernelNode, graph, NULL, 0, &kernelParams);

// Add memcpy node
cudaGraphNode_t memcpyNode;
cudaMemcpy3DParms memcpyParams = {0};
// ... set memcpy params ...
cudaGraphAddMemcpyNode(&memcpyNode, graph, NULL, 0, &memcpyParams);

// Add memset node
cudaGraphAddMemsetNode(&memsetNode, graph, NULL, 0, &memsetParams);

// Add host node
cudaGraphAddHostNode(&hostNode, graph, NULL, 0, &hostParams);

// Add child graph node
cudaGraphAddChildGraphNode(&childNode, graph, NULL, 0, childGraph);

// Add empty node
cudaGraphAddEmptyNode(&emptyNode, graph, NULL, 0);

// Add dependencies
cudaGraphAddDependencies(graph, &nodeA, &nodeB, 1);  // A must execute before B
```

### 15.2 Graph Execution

```cuda
// Instantiate graph
cudaGraphExec_t graphExec;
cudaGraphInstantiate(&graphExec, graph, NULL, NULL, 0);

// Launch
cudaGraphLaunch(graphExec, stream);

// Launch with flags (CUDA 13)
cudaGraphLaunch(graphExec, stream, flags);

// Synchronize
cudaStreamSynchronize(stream);

// Update (CUDA 13)
cudaGraphExecKernelNodeSetParams(graphExec, node, &params);

// Destroy
cudaGraphExecDestroy(graphExec);
cudaGraphDestroy(graph);
```

### 15.3 Stream Capture

```cuda
// Begin capture
cudaStreamBeginCapture(stream, cudaStreamCaptureModeGlobal);

// Or thread-local capture
cudaStreamBeginCapture(stream, cudaStreamCaptureModeThreadLocal);

// Or relaxed capture
cudaStreamBeginCapture(stream, cudaStreamCaptureModeRelaxed);

// ... issue work to stream ...

// End capture
cudaGraph_t graph;
cudaStreamEndCapture(stream, &graph);

// Query capture status
cudaStreamIsCapturing(stream, &captureStatus);
```

---

## 16. Driver API

### 16.1 Initialization

```cuda
// Initialize
cuInit(0);

// Get device
CUdevice device;
cuDeviceGet(&device, 0);

// Create context
CUcontext context;
cuCtxCreate(&context, 0, device);

// Primary context (recommended)
cuDevicePrimaryCtxRetain(&context, device);
```

### 16.2 Module Loading

```cuda
// Load module from file
CUmodule module;
cuModuleLoad(&module, "kernel.ptx");

// Load from string
cuModuleLoadData(&module, ptxString);

// Get function
CUfunction function;
cuModuleGetFunction(&function, module, "kernel_name");

// Get global
CUdeviceptr globalPtr;
size_t globalSize;
cuModuleGetGlobal(&globalPtr, &globalSize, module, "global_name");
```

### 16.3 Memory (Driver API)

```cuda
// Allocate
CUdeviceptr dptr;
cuMemAlloc(&dptr, size);

// Allocate pitched
cuMemAllocPitch(&dptr, &pitch, width, height, elementSize);

// Free
cuMemFree(dptr);

// Copy
cuMemcpyHtoD(dstDevice, srcHost, byteCount);
cuMemcpyDtoH(dstHost, srcDevice, byteCount);
cuMemcpyDtoD(dstDevice, srcDevice, byteCount);

// Async copy
cuMemcpyHtoDAsync(dstDevice, srcHost, byteCount, hStream);
```

### 16.4 Launch Kernel (Driver API)

```cuda
// Set up args
void* args[] = { &d_a, &d_b, &d_c, &n };

// Launch
cuLaunchKernel(function,
    gridDimX, gridDimY, gridDimZ,
    blockDimX, blockDimY, blockDimZ,
    sharedMemBytes,
    hStream,
    args,
    NULL  // extra
);
```

---

## 17. NVCC Compiler

### 17.1 Basic Usage

```bash
# Compile to executable
nvcc program.cu -o program

# Compile with optimization
nvcc -O3 program.cu -o program

# Generate PTX only
nvcc -ptx program.cu -o program.ptx

# Generate cubin only
nvcc -cubin program.cu -o program.cubin
```

### 17.2 Architecture Options

```bash
# Specify architecture (sm = binary, compute = PTX)
nvcc -arch=sm_80 program.cu              # Ampere
nvcc -arch=sm_90 program.cu              # Hopper
nvcc -arch=sm_100 program.cu             # Blackwell

# Multiple architectures (fatbinary)
nvcc -gencode arch=compute_80,code=sm_80 \
     -gencode arch=compute_90,code=sm_90 program.cu

# Forward compatibility (PTX)
nvcc -gencode arch=compute_90,code=compute_90 program.cu

# All supported (CUDA 13)
nvcc -arch=all program.cu
nvcc -arch=all-major program.cu

# Blackwell (sm_100, sm_101, sm_110, sm_120) - CUDA 13.0+
nvcc -arch=sm_100 program.cu
nvcc -arch=sm_110 program.cu             # Jetson Thor
nvcc -arch=sm_120 program.cu
```

### 17.3 Compilation Flags

| Flag | Description |
|------|-------------|
| `-c` | Compile to object file |
| `-dc` | Generate relocatable device code |
| `-dw` | Generate whole program device code |
| `-rdc=true` | Relocatable device code |
| `-shared` | Generate shared library |
| `-Xcompiler` | Pass option to host compiler |
| `-Xlinker` | Pass option to linker |
| `-Xptxas` | Pass option to PTX assembler |
| `-Xnvlink` | Pass option to device linker |
| `-I<path>` | Include path |
| `-L<path>` | Library path |
| `-l<lib>` | Link library |
| `-D<macro>` | Define macro |
| `-U<macro>` | Undefine macro |
| `-E` | Preprocess only |
| `-std=c++17` | C++ standard |
| `--expt-relaxed-constexpr` | Relax constexpr restrictions |
| `--expt-extended-lambda` | Extended lambda support |
| `-lineinfo` | Generate line number info |
| `-G` | Generate debug info |
| `-pg` | Generate profiling info |
| `--use_fast_math` | Use fast math intrinsics |
| `--ftz=true` | Flush denormals to zero |
| `--prec-div=true` | Precise division |
| `--prec-sqrt=true` | Precise sqrt |
| `--fmad=true` | Enable FMA contraction |
| `--maxrregcount=<N>` | Maximum registers per thread |
| `--Ofast-compile=<level>` | Fast compilation over optimization (CUDA 13) |

### 17.4 NVCC Phases

```bash
# Complete compilation flow:
# .cu -> preprocessor -> cudafe -> nvcc frontend
#   -> host compiler (gcc/clang/msvc)
#   -> device compilation -> nvcc -> ptxas (PTX assembler)
#   -> fatbinary -> linker -> executable
```

### 17.5 Separate Compilation

```bash
# Compile with relocatable device code
nvcc -dc -arch=sm_80 file1.cu -o file1.o
nvcc -dc -arch=sm_80 file2.cu -o file2.o

# Link device code
nvcc -arch=sm_80 file1.o file2.o -o program

# Or use nvlink directly
nvcc -arch=sm_80 -dlink file1.o file2.o -o device_link.o
nvcc file1.o file2.o device_link.o -o program
```

---

## 18. Error Handling

### 18.1 Error Codes

```cuda
// Common error codes
cudaSuccess                    = 0
cudaErrorInvalidValue          = 1
cudaErrorMemoryAllocation      = 2
cudaErrorInitializationError   = 3
cudaErrorCudartUnloading       = 4
cudaErrorProfilerDisabled      = 5
cudaErrorProfilerNotInitialized = 6
cudaErrorProfilerAlreadyStarted  = 7
cudaErrorProfilerAlreadyStopped  = 8
cudaErrorInvalidConfiguration  = 9
cudaErrorInvalidPitchValue     = 12
cudaErrorInvalidSymbol         = 13
cudaErrorInvalidDevicePointer  = 17
cudaErrorInvalidMemcpyDirection = 21
cudaErrorInsufficientDriver    = 35
cudaErrorMissingConfiguration   = 52
cudaErrorPriorLaunchFailure     = 53
cudaErrorLaunchMaxDepthExceeded = 65
cudaErrorLaunchFileScopedTex    = 66
cudaErrorLaunchFileScopedSurf   = 67
cudaErrorSyncDepthExceeded      = 68
cudaErrorLaunchPendingCountExceeded = 69
cudaErrorInvalidDevice          = 101
cudaErrorDeviceNotLicensed      = 102
cudaErrorNotReady               = 600
cudaErrorIllegalAddress         = 700
cudaErrorLaunchOutOfResources   = 701
cudaErrorLaunchTimeout          = 702
cudaErrorPeerAccessAlreadyEnabled = 704
cudaErrorPeerAccessNotEnabled   = 705
cudaErrorAlreadyMapped          = 208
cudaErrorNotMapped              = 211
cudaErrorAlreadyAcquired        = 210
cudaErrorNotAcquired            = 212
cudaErrorECCUncorrectable       = 214
cudaErrorUnsupportedLimit       = 215
cudaErrorContextAlreadyInUse    = 216
cudaErrorStreamCaptureUnsupported = 900
cudaErrorStreamCaptureInvalidated = 901
cudaErrorStreamCaptureMerge       = 902
cudaErrorStreamCaptureUnmatched   = 903
cudaErrorStreamCaptureUnjoined    = 904
cudaErrorStreamCaptureIsolation   = 905
cudaErrorStreamCaptureImplicit    = 906
cudaErrorCapturedEvent            = 907
cudaErrorStreamCaptureWrongThread = 908
cudaErrorTimeout                = 909
cudaErrorGraphExecUpdateFailure   = 910
cudaErrorExternalDevice           = 911
cudaErrorInvalidClusterSize       = 912
cudaErrorFunctionNotLoaded        = 913
cudaErrorInvalidResourceType      = 914
cudaErrorInvalidResourceConfiguration = 915
cudaErrorKeyRotation              = 916
cudaErrorUnknown                  = 999
```

### 18.2 Error Checking Macros

```cuda
// Basic error checking
#define cudaCheck(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char *file, int line, bool abort=true) {
   if (code != cudaSuccess) {
      fprintf(stderr,"GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
      if (abort) exit(code);
   }
}

// Usage
cudaCheck(cudaMalloc(&d_data, size));
cudaCheck(cudaMemcpy(d_data, h_data, size, cudaMemcpyHostToDevice));
kernel<<<blocks, threads>>>(d_data);
cudaCheck(cudaGetLastError());  // Check kernel launch
cudaCheck(cudaDeviceSynchronize());  // Check execution

// Get error string
const char* cudaGetErrorString(cudaError_t error);
cudaError_t cudaGetLastError(void);
cudaError_t cudaPeekAtLastError(void);
```

---

## 19. CUDA 13.x New Features

### 19.1 CUDA 13.0 (August 2025)

- **Blackwell Architecture Support**: sm_100, sm_101, sm_110, sm_120
- **Zstandard Compression**: Default fatbinary compression
- **Dropped Legacy Support**: Maxwell and older architectures (pre-Turing)
- **cuTile Python DSL**: Tile-level kernel programming

### 19.2 CUDA 13.1 (December 2025)

- **CUDA Tile**: Tile-based programming model
- **Group GEMM**: FP8/BF16 on Blackwell
- **MPS Static SM Partitioning**: Multi-Process Service improvements
- **Compute Sanitizer**: Compile-time patching via NVCC

### 19.3 CUDA 13.2 (March 2026)

- **Enhanced cuTile**: Performance improvements
- **cuSPARSE Updates**: Sparse matrix optimizations
- **CUB Multi-phase Determinism**: CCCL 3.1

### 19.4 CUDA 13.3 (June 2026) - Current Stable

- **Performance Optimizations**: Library improvements
- **Bug Fixes**: Stability enhancements
- **--Ofast-compile**: Fast compilation option at levels 1-4

### 19.5 CUDA 13.4 (July 2026) - Developer Preview

- **Experimental Features**: Next-generation capabilities
- **Unbundled Linux Driver**: Driver no longer bundled with toolkit

### 19.6 Architecture Support Matrix

| Architecture | Compute Capability | CUDA Support |
|--------------|------------------|--------------|
| Maxwell | sm_50, sm_52, sm_53 | Up to 12.x |
| Pascal | sm_60, sm_61, sm_62 | Up to 12.x |
| Volta | sm_70, sm_72 | 9.0+ |
| Turing | sm_75 | 10.0+ |
| Ampere | sm_80, sm_86 | 11.0+ |
| Ada | sm_89 | 11.8+ |
| Hopper | sm_90, sm_90a | 12.0+ |
| Blackwell | sm_100, sm_101, sm_110, sm_120 | 13.0+ |

---

## Appendix A: Quick Reference

### Common Kernel Pattern

```cuda
__global__ void vectorAdd(const float *A, const float *B, float *C, int numElements) {
    int i = blockDim.x * blockIdx.x + threadIdx.x;
    if (i < numElements) {
        C[i] = A[i] + B[i];
    }
}

// Launch
int threadsPerBlock = 256;
int blocksPerGrid = (numElements + threadsPerBlock - 1) / threadsPerBlock;
vectorAdd<<<blocksPerGrid, threadsPerBlock>>>(d_A, d_B, d_C, numElements);
```

### Memory Copy Pattern

```cuda
// Allocate
float *d_data;
cudaMalloc(&d_data, size);

// Copy H2D
cudaMemcpy(d_data, h_data, size, cudaMemcpyHostToDevice);

// Launch kernel
kernel<<<blocks, threads>>>(d_data);

// Copy D2H
cudaMemcpy(h_data, d_data, size, cudaMemcpyDeviceToHost);

// Free
cudaFree(d_data);
```

### Stream Pattern

```cuda
cudaStream_t stream;
cudaStreamCreate(&stream);

// Async operations
cudaMemcpyAsync(d_data, h_data, size, cudaMemcpyHostToDevice, stream);
kernel<<<blocks, threads, 0, stream>>>(d_data);
cudaMemcpyAsync(h_data, d_data, size, cudaMemcpyDeviceToHost, stream);

cudaStreamSynchronize(stream);
cudaStreamDestroy(stream);
```

### Error Checking Pattern

```cuda
cudaError_t err = cudaGetLastError();
if (err != cudaSuccess) {
    printf("Error: %s\n", cudaGetErrorString(err));
}
cudaDeviceSynchronize();
```

---

## Appendix B: Performance Guidelines

### Occupancy

| Compute Capability | Max Threads/SM | Max Blocks/SM | Max Warps/SM |
|-------------------|----------------|---------------|--------------|
| 7.x (Volta) | 2048 | 32 | 64 |
| 8.x (Ampere) | 2048 | 32 | 64 |
| 9.0 (Hopper) | 2048 | 32 | 64 |
| 10.x (Blackwell) | 2048 | 32 | 64 |

### Memory Bandwidth

| Memory Type | Bandwidth | Latency |
|-------------|-----------|---------|
| Registers | ~20 TB/s | 1 cycle |
| Shared | ~10 TB/s | ~20 cycles |
| L2 Cache | ~2-4 TB/s | ~200 cycles |
| Global | ~1-2 TB/s | ~400 cycles |
| Constant | ~10 TB/s (cached) | ~20 cycles |

### Coalesced Access Pattern

```cuda
// Coalesced (good)
int idx = blockIdx.x * blockDim.x + threadIdx.x;
data[idx] = value;

// Strided (bad)
int idx = threadIdx.x * stride;
data[idx] = value;

// Bank conflict example (shared memory)
__shared__ float shared[256];
float x = shared[threadIdx.x];      // No conflict
float y = shared[threadIdx.x * 2];  // 2-way conflict
```

---

*This reference guide is based on CUDA Toolkit 13.3 Update 1 (June 2026). For the latest updates, consult the official NVIDIA documentation at https://docs.nvidia.com/cuda/*

---
