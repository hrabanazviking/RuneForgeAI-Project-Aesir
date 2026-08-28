# 🧠 The Complete Hailo 10 NPU Reference Guide

(Complete_Hailo_10_NPU_Reference_Guide.md)

## Version Information

**Current Stable Release:** HailoRT 4.23 (October 2025)  
**Hailo 10H Specifications:**
- **Performance:** 40 TOPS (INT4) / 20 TOPS (INT8)
- **Memory:** 2GB or 8GB LPDDR4 @ 4266 MT/s
- **Power:** 2.5W (typical), up to 8.25W (max)
- **Interface:** PCIe 3.0 x4 lanes, M.2 2280 Key-M
- **Form Factor:** M.2 2242, M.2 2280
- **Supported OS:** Linux, Windows, Android
- **Host Support:** x86_64, ARM64 (aarch64)

**Hailo Software Suite Components:**
- HailoRT 4.23 (Runtime)
- Dataflow Compiler 3.30+ (Model compilation)
- TAPPAS 3.31+ (Application framework)
- Hailo Model Zoo (Pre-trained models)

---

## Table of Contents

1. [Hardware Specifications](#1-hardware-specifications)
2. [Installation and Setup](#2-installation-and-setup)
3. [HailoRT CLI](#3-hailort-cli)
4. [Python API (pyHailoRT)](#4-python-api-pyhailort)
5. [C/C++ API (libhailort)](#5-cc-api-libhailort)
6. [HEF Format](#6-hef-format)
7. [Dataflow Compiler](#7-dataflow-compiler)
8. [TAPPAS Framework](#8-tappas-framework)
9. [GStreamer Elements](#9-gstreamer-elements)
10. [Model Zoo](#10-model-zoo)
11. [Configuration Parameters](#11-configuration-parameters)
12. [Performance Optimization](#12-performance-optimization)
13. [Monitoring and Debugging](#13-monitoring-and-debugging)
14. [Multi-Device Support](#14-multi-device-support)
15. [Error Handling](#15-error-handling)

---

## 1. Hardware Specifications

### 1.1 Hailo-10H M.2 Module

| Specification | Value |
|-------------|-------|
| AI Accelerator | Hailo-10H |
| Neural Core Architecture | 2nd Generation |
| INT4 Performance | 40 TOPS |
| INT8 Performance | 20 TOPS |
| On-Module Memory | 2GB / 4GB / 8GB LPDDR4 |
| Memory Bandwidth | 4266 MT/s |
| Typical Power | 2.5W |
| Maximum Power | 8.25W |
| Interface | PCIe 3.0 x4 |
| Form Factor | M.2 2280 Key-M (also 2242) |
| Supply Voltage | 3.3V |
| Operating Temperature | -40°C to 85°C (industrial) |

### 1.2 Supported Models

| Category | Examples |
|----------|----------|
| **Vision Models** | ResNet, EfficientNet, YOLO (v5-v12), MobileNet |
| **Object Detection** | YOLO variants, CenterNet, SSD |
| **Segmentation** | DeepLab, U-Net, SAM |
| **Pose Estimation** | OpenPose, MoveNet |
| **Generative AI** | LLMs (Llama, Mistral), VLMs, Whisper |
| **OCR** | PaddleOCR |
| **Stereo Depth** | StereoNet |

---

## 2. Installation and Setup

### 2.1 System Requirements

**Host Requirements:**
- Linux: Ubuntu 20.04/22.04/24.04, Debian 11/12, RHEL 8/9
- Windows: Windows 10/11
- Architecture: x86_64 or ARM64 (aarch64)
- Python: 3.8 - 3.12

**PCIe Requirements:**
- PCIe Gen 3 x4 slot or M.2 Key-M slot
- SR-IOV support recommended for multi-process

### 2.2 Installation Methods

```bash
# Method 1: Using Hailo Software Suite (Recommended)
# Download from https://hailo.ai/developer-zone/software-downloads/
./hailo_ai_sw_suite_<version>_linux_x86_64.run

# Method 2: Using pip (Python only)
pip install hailo-platform

# Method 3: From source (GitHub)
git clone https://github.com/hailo-ai/hailort.git
cd hailort
./install.sh
```

### 2.3 Driver Installation

```bash
# Linux - PCIe driver
cd hailort/hailort/pcie_driver
make
sudo make install
sudo modprobe hailo_pci

# Verify installation
hailortcli scan
lspci | grep Hailo
```

### 2.4 Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `HAILO_MONITOR` | Enable monitoring mode | `export HAILO_MONITOR=1` |
| `HAILO_LOG_LEVEL` | Set logging level | `export HAILO_LOG_LEVEL=DEBUG` |
| `HAILO_BATCH_SIZE` | Default batch size | `export HAILO_BATCH_SIZE=8` |
| `HAILO_MONITOR` | Enable CLI monitoring | `export HAILO_MONITOR=1` |

---

## 3. HailoRT CLI

### 3.1 Device Commands

```bash
# Scan for devices
hailortcli scan

# Detailed device info
hailortcli scan --full

# Monitor device (requires HAILO_MONITOR=1)
hailortcli monitor

# Monitor with specific interval (ms)
hailortcli monitor --interval 1000

# Get device temperature
hailortcli fw-control --temperature

# Get device power consumption
hailortcli fw-control --power
```

### 3.2 Inference Commands

```bash
# Basic inference
hailortcli run model.hef

# With specific input
hailortcli run model.hef --input input_image.jpg

# With batch size
hailortcli run model.hef --batch-size 8

# Measure latency
hailortcli run model.hef --measure-latency

# Measure power
hailortcli run model.hef --measure-power

# With specific mode
hailortcli run model.hef --mode full_sync      # Synchronous
hailortcli run model.hef --mode full_async     # Asynchronous
hailortcli run model.hef --mode raw_sync       # Raw synchronous
hailortcli run model.hef --mode raw_async      # Raw asynchronous

# With timeout
hailortcli run model.hef --timeout 30

# With frame count
hailortcli run model.hef --frames 1000

# Multi-device
hailortcli run model.hef --device-ids 0,1,2
```

### 3.3 HEF Commands

```bash
# Get HEF info
hailortcli hef-info model.hef

# Parse HEF
hailortcli parse-hef model.hef

# Convert HAR to HEF (requires DFC)
hailortcli har-to-hef model.har --output model.hef
```

### 3.4 Firmware Commands

```bash
# Get firmware version
hailortcli fw-control --version

# Update firmware
hailortcli fw-update --file firmware.bin

# Reset device
hailortcli fw-control --reset

# Get sensor values
hailortcli fw-control --sensors
```

### 3.5 Profiling Commands

```bash
# Run with profiling
hailortcli run model.hef --profiling

# Save profiling data
hailortcli run model.hef --profiling --profiling-output profile.json

# Benchmark mode
hailortcli benchmark model.hef --duration 60
```

---

## 4. Python API (pyHailoRT)

### 4.1 Core Classes

#### VDevice (Virtual Device)

```python
from hailo_platform import VDevice, HailoSchedulingAlgorithm, FormatType, HEF

# Create VDevice with default parameters
with VDevice() as vdevice:
    # Use vdevice
    pass

# Create with custom parameters
params = VDevice.create_params()
params.scheduling_algorithm = HailoSchedulingAlgorithm.ROUND_ROBIN
params.device_count = 2  # Multi-device

with VDevice(params) as vdevice:
    infer_model = vdevice.create_infer_model('model.hef')
```

**VDevice Parameters:**

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `scheduling_algorithm` | `HailoSchedulingAlgorithm` | Job scheduling algorithm | `ROUND_ROBIN` |
| `device_count` | `int` | Number of devices to use | 1 |
| `device_ids` | `List[int]` | Specific device IDs | Auto-detect |

**Scheduling Algorithms:**
- `HailoSchedulingAlgorithm.ROUND_ROBIN` - Distribute jobs round-robin
- `HailoSchedulingAlgorithm.PRIORITY` - Priority-based scheduling
- `HailoSchedulingAlgorithm.NONE` - No scheduling (single process)

#### InferModel

```python
# Create InferModel from HEF
infer_model = vdevice.create_infer_model('model.hef')

# Set batch size
infer_model.set_batch_size(8)

# Configure input
infer_model.input().set_format_type(FormatType.AUTO)
infer_model.input().set_frame_size(640, 480)

# Configure output
infer_model.output().set_nms_iou_threshold(0.45)
infer_model.output().set_nms_score_threshold(0.3)

# Configure with dictionary
config = {
    'input': {
        'format_type': FormatType.RGB,
        'shape': (1, 640, 640, 3)
    },
    'output': {
        'nms_iou_threshold': 0.45,
        'nms_score_threshold': 0.3
    }
}
infer_model.configure(config)

# Create configured model for inference
configured_model = infer_model.configure()
```

#### ConfiguredInferModel

```python
# Get configured model
configured_model = infer_model.configure()

# Run inference
input_data = np.random.randn(1, 640, 640, 3).astype(np.float32)
output = configured_model.infer(input_data)

# Async inference with callback
def callback(output):
    print("Inference complete:", output)

configured_model.infer_async(input_data, callback)

# Run with timeout
output = configured_model.infer(input_data, timeout_ms=1000)

# Get input/output stream info
input_info = configured_model.get_input_stream_info()
output_info = configured_model.get_output_stream_info()
```

### 4.2 HEF (Hailo Executable Format)

```python
from hailo_platform import HEF

# Load HEF
hef = HEF('model.hef')

# Get network info
network_info = hef.get_network_info()

# Get input/output info
input_vstream_info = hef.get_input_vstream_info()
output_vstream_info = hef.get_output_vstream_info()

# Get model name
model_name = hef.get_model_name()

# Get expected input shape
input_shape = hef.get_input_shape()

# Get expected output shape
output_shape = hef.get_output_shape()
```

### 4.3 Format Types

```python
from hailo_platform import FormatType

# Input format types
FormatType.AUTO          # Automatic format detection
FormatType.RGB           # RGB image
FormatType.BGR           # BGR image
FormatType.RGBA          # RGBA image
FormatType.GRAYSCALE     # Grayscale image
FormatType.NCHW          # NCHW tensor format
FormatType.NHWC          # NHWC tensor format
FormatType.FLOAT32       # 32-bit float
FormatType.UINT8         # 8-bit unsigned integer
```

### 4.4 Complete Inference Example

```python
import numpy as np
from hailo_platform import VDevice, HEF, FormatType

def run_inference(hef_path, image_path):
    # Load HEF
    hef = HEF(hef_path)
    
    # Create VDevice
    with VDevice() as vdevice:
        # Create inference model
        infer_model = vdevice.create_infer_model(hef)
        
        # Configure
        infer_model.input().set_format_type(FormatType.RGB)
        infer_model.set_batch_size(1)
        
        # Configure NMS if detection model
        try:
            infer_model.output().set_nms_iou_threshold(0.45)
            infer_model.output().set_nms_score_threshold(0.3)
        except:
            pass  # Not a detection model
        
        # Create configured model
        configured = infer_model.configure()
        
        # Load and preprocess image
        input_data = preprocess_image(image_path)
        
        # Run inference
        output = configured.infer(input_data)
        
        return output

def preprocess_image(image_path, target_size=(640, 640)):
    from PIL import Image
    img = Image.open(image_path)
    img = img.resize(target_size)
    img_array = np.array(img) / 255.0  # Normalize
    return img_array.astype(np.float32)
```

### 4.5 Async Inference

```python
import queue

# Create callback with queue
result_queue = queue.Queue()

def inference_callback(output):
    result_queue.put(output)

# Run async
configured_model.infer_async(input_data, inference_callback)

# Get result with timeout
try:
    result = result_queue.get(timeout=5.0)
except queue.Empty:
    print("Inference timeout")
```

### 4.6 Multi-Input/Output Models

```python
# Models with multiple inputs/outputs
infer_model = vdevice.create_infer_model('multi_input.hef')

# Configure specific inputs
infer_model.input('input1').set_format_type(FormatType.RGB)
infer_model.input('input2').set_format_type(FormatType.GRAYSCALE)

# Configure specific outputs
infer_model.output('output1').set_nms_iou_threshold(0.45)
infer_model.output('output2')  # No NMS for this output

# Run with multiple inputs
output = configured_model.infer({
    'input1': input1_data,
    'input2': input2_data
})

# Access outputs
detections = output['output1']
features = output['output2']
```

---

## 5. C/C++ API (libhailort)

### 5.1 Core Headers

```cpp
#include <hailo/hailort.hpp>      // C++ API
#include <hailo/hailort.h>        // C API
```

### 5.2 VDevice Management (C++)

```cpp
#include <hailo/hailort.hpp>
using namespace hailo;

// Create VDevice
auto vdevice_exp = VDevice::create();
if (!vdevice_exp) {
    std::cerr << "Failed to create VDevice: " << vdevice_exp.status() << std::endl;
    return -1;
}
auto vdevice = vdevice_exp.release();

// Create with parameters
VDevice::Params params;
params.scheduling_algorithm = HAILO_SCHEDULING_ALGORITHM_ROUND_ROBIN;
params.device_count = 2;

auto vdevice_exp = VDevice::create(params);
```

### 5.3 InferModel (C++)

```cpp
// Create InferModel from HEF
auto infer_model_exp = vdevice->create_infer_model("model.hef");
if (!infer_model_exp) {
    std::cerr << "Failed to create InferModel" << std::endl;
    return -1;
}
auto infer_model = infer_model_exp.release();

// Set batch size
infer_model->set_batch_size(8);

// Configure input
infer_model->input()->set_format_type(HAILO_FORMAT_TYPE_AUTO);

// Configure output with NMS
infer_model->output()->set_nms_iou_threshold(0.45f);
infer_model->output()->set_nms_score_threshold(0.3f);

// Configure and get ConfiguredInferModel
auto configured_exp = infer_model->configure();
if (!configured_exp) {
    std::cerr << "Failed to configure model" << std::endl;
    return -1;
}
auto configured = configured_exp.release();
```

### 5.4 Synchronous Inference (C++)

```cpp
// Prepare input
std::vector<uint8_t> input_data(input_size);

// Run inference
auto output_exp = configured->infer(input_data);
if (!output_exp) {
    std::cerr << "Inference failed" << std::endl;
    return -1;
}
auto output = output_exp.release();

// Process output
auto output_data = output->get_buffer();
```

### 5.5 Asynchronous Inference (C++)

```cpp
// Define callback
auto callback = [](const AsyncInferCompletionInfo& completion_info) {
    if (completion_info.status == HAILO_SUCCESS) {
        auto output_buffer = completion_info.output_buffer;
        // Process output
    }
};

// Run async
auto status = configured->infer_async(input_buffer, callback);
if (HAILO_SUCCESS != status) {
    std::cerr << "Async inference failed" << std::endl;
}

// Wait for completion
configured->wait_for_async_ready(timeout_ms);
```

### 5.6 C API Example

```c
#include <hailo/hailort.h>

// Create VDevice
hailo_vdevice_t vdevice = NULL;
hailo_vdevice_params_t params = {0};
params.scheduling_algorithm = HAILO_SCHEDULING_ALGORITHM_ROUND_ROBIN;

hailo_status_t status = hailo_create_vdevice(&params, &vdevice);
if (HAILO_SUCCESS != status) {
    fprintf(stderr, "Failed to create VDevice: %d\n", status);
    return -1;
}

// Create InferModel
hailo_infer_model_t infer_model = NULL;
status = hailo_create_infer_model(vdevice, "model.hef", &infer_model);
if (HAILO_SUCCESS != status) {
    fprintf(stderr, "Failed to create InferModel\n");
    hailo_destroy_vdevice(vdevice);
    return -1;
}

// Clean up
hailo_destroy_infer_model(infer_model);
hailo_destroy_vdevice(vdevice);
```

### 5.7 Error Handling (C++)

```cpp
// Using expected pattern
auto result = some_hailo_operation();
if (!result) {
    // Handle error
    hailo_status error_status = result.status();
    std::cerr << "Error: " << hailo_get_status_message(error_status) << std::endl;
    return -1;
}

// Using value
auto value = result.release();

// Or using value()
auto value = result.value();
```

### 5.8 Status Codes

| Status Code | Value | Description |
|-------------|-------|-------------|
| `HAILO_SUCCESS` | 0 | Success |
| `HAILO_TIMEOUT` | 1 | Operation timed out |
| `HAILO_INVALID_ARGUMENT` | 2 | Invalid argument |
| `HAILO_OUT_OF_MEMORY` | 3 | Out of memory |
| `HAILO_DEVICE_NOT_FOUND` | 4 | Device not found |
| `HAILO_INVALID_HEF` | 5 | Invalid HEF file |
| `HAILO_NETWORK_NOT_FOUND` | 6 | Network not found |
| `HAILO_UNSUPPORTED_OPERATION` | 7 | Operation not supported |
| `HAILO_UNINITIALIZED` | 8 | Object not initialized |
| `HAILO_FILE_NOT_FOUND` | 9 | File not found |
| `HAILO_INVALID_CONFIG` | 10 | Invalid configuration |
| `HAILO_BUSY` | 11 | Device/resource busy |
| `HAILO_STREAM_NOT_ACTIVATED` | 12 | Stream not activated |
| `HAILO_INTERNAL_FAILURE` | 13 | Internal error |

---

## 6. HEF Format

### 6.1 HEF Structure

```
HEF (Hailo Executable Format)
├── Header
│   ├── Magic number
│   ├── Version
│   └── Metadata
├── Network Groups
│   ├── Network Group 1
│   │   ├── Layer definitions
│   │   ├── Weights
│   │   └── Dataflow graph
│   └── Network Group 2...
├── Calibration Data (optional)
└── Custom Data
```

### 6.2 HEF Generation

```python
# From Dataflow Compiler
from hailo_dataflow_compiler import DataflowCompiler

compiler = DataflowCompiler()
compiler.load_model('model.onnx')
compiler.optimize()
compiler.compile(output_path='model.hef')
```

### 6.3 HEF Inspection

```bash
# Using CLI
hailortcli hef-info model.hef

# Using Python
from hailo_platform import HEF

hef = HEF('model.hef')
print(f"Model name: {hef.get_model_name()}")
print(f"Input shape: {hef.get_input_shape()}")
print(f"Output shape: {hef.get_output_shape()}")
print(f"Network count: {hef.get_network_count()}")
```

---

## 7. Dataflow Compiler

### 7.1 Installation

```bash
pip install hailo-dataflow-compiler

# Or from Hailo Software Suite
./hailo_ai_sw_suite.run --install-dfc
```

### 7.2 Compilation Workflow

```python
from hailo_dataflow_compiler import DataflowCompiler, Parser

# Step 1: Parse model
parser = Parser()
har = parser.parse('model.onnx')

# Step 2: Optimize
compiler = DataflowCompiler()
compiler.load_har(har)
compiler.optimize(target='hailo10')

# Step 3: Compile to HEF
compiler.compile(output_path='model.hef')
```

### 7.3 Parser Configuration

```python
from hailo_dataflow_compiler import Parser, ParserParams

params = ParserParams()
params.input_shape = (1, 640, 640, 3)
params.output_names = ['output1', 'output2']
params.norm_params = {
    'mean': [0.485, 0.456, 0.406],
    'std': [0.229, 0.224, 0.225]
}

parser = Parser(params)
har = parser.parse('model.onnx')
```

### 7.4 Optimization Parameters

```python
from hailo_dataflow_compiler import OptimizationParams

params = OptimizationParams()
params.target = 'hailo10'           # Target device
params.performance_mode = True       # Maximize performance
params.workload_type = 'vision'      # Workload type
params.quantization = {
    'enabled': True,
    'precision': 'int8',            # or 'int4'
    'calibration_dataset': 'data/'
}

compiler.optimize(params)
```

### 7.5 DFC CLI

```bash
# Parse model
hailo-dfc parse model.onnx --output model.har

# Optimize HAR
hailo-dfc optimize model.har --target hailo10 --output optimized.har

# Compile to HEF
hailo-dfc compile optimized.har --output model.hef

# Full pipeline
hailo-dfc compile model.onnx \
    --target hailo10 \
    --performance \
    --quantization int8 \
    --calibration-data ./calib \
    --output model.hef
```

### 7.6 Advanced Compilation Options

```bash
# With custom allocator script
hailo-dfc compile model.onnx \
    --alls allocator.alls \
    --target hailo10 \
    --output model.hef

# Performance mode (longer compilation)
hailo-dfc compile model.onnx \
    --performance \
    --target hailo10 \
    --output model.hef

# With specific batch size
hailo-dfc compile model.onnx \
    --batch-size 8 \
    --target hailo10 \
    --output model.hef
```

---

## 8. TAPPAS Framework

### 8.1 Installation

```bash
# From Hailo Software Suite
./hailo_ai_sw_suite.run --install-tappas

# Or download separately
wget https://hailo-csdata.s3.eu-west-2.amazonaws.com/tappas/tappas_<version>.tar.gz
tar -xzf tappas_<version>.tar.gz
```

### 8.2 TAPPAS Architecture

```
TAPPAS Pipeline
├── Sources (Camera/File/Network)
│   └── v4l2src, filesrc, rtspsrc, etc.
├── Hailo Elements
│   ├── hailonet (Inference)
│   ├── hailotilecropper (Tiling)
│   ├── hailotileaggregator (Tile aggregation)
│   └── hailofilter (Post-processing)
├── Post-Processing
│   └── Custom callbacks (Python/C++)
└── Sinks
    ├── fakesink
    ├── autovideosink
    └── filesink
```

### 8.3 TAPPAS Applications

| Application | Description | Location |
|-------------|-------------|----------|
| `detection` | Object detection | `apps/h8/gstreamer/general/detection` |
| `classification` | Image classification | `apps/h8/gstreamer/general/classification` |
| `instance_segmentation` | Instance segmentation | `apps/h8/gstreamer/general/instance_segmentation` |
| `depth_estimation` | Depth estimation | `apps/h8/gstreamer/general/depth_estimation` |
| `face_recognition` | Face recognition | `apps/h8/gstreamer/general/face_recognition` |
| `license_plate_recognition` | LPR | `apps/h8/gstreamer/general/license_plate_recognition` |
| `tiling` | High-res tiling | `apps/h8/gstreamer/general/tiling` |
| `multi_person_multi_camera` | Multi-camera tracking | `apps/h8/gstreamer/general/multi_person_multi_camera_tracking` |

### 8.4 Running TAPPAS Applications

```bash
# Detection example
cd $TAPPAS_WORKSPACE/apps/h8/gstreamer/general/detection

# Run with default parameters
./detection.sh

# Run with custom model
./detection.sh --hef-path custom_model.hef --input /dev/video0

# Run on video file
./detection.sh --input video.mp4 --show-fps

# Run with specific post-process
./detection.sh --post-process-type yolo_v5
```

### 8.5 TAPPAS Configuration

```json
// config.json
{
    "hef_path": "model.hef",
    "post_process": {
        "type": "yolo_v5",
        "iou_threshold": 0.45,
        "score_threshold": 0.3,
        "nms_iou_threshold": 0.45
    },
    "input": {
        "format": "rgb",
        "width": 640,
        "height": 640
    },
    "output": {
        "display": true,
        "save": false
    }
}
```

---

## 9. GStreamer Elements

### 9.1 hailonet

```gst
# Basic usage
gst-launch-1.0 v4l2src ! hailonet hef-path=model.hef ! fakesink

# With specific device
gst-launch-1.0 v4l2src ! hailonet hef-path=model.hef device-id=0 ! fakesink

# With batching
gst-launch-1.0 v4l2src ! hailonet hef-path=model.hef batch-size=4 ! fakesink

# With scheduling
gst-launch-1.0 v4l2src ! hailonet hef-path=model.hef scheduling-algorithm=round-robin ! fakesink
```

**Properties:**

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `hef-path` | String | Path to HEF file | Required |
| `device-id` | Int | Device ID | -1 (auto) |
| `batch-size` | Int | Batch size | 1 |
| `scheduling-algorithm` | Enum | Scheduling algorithm | round-robin |
| `multi-process-service` | Boolean | Use MPS | false |
| `pass-through` | Boolean | Pass-through mode | false |

### 9.2 hailotilecropper

```gst
# High-resolution tiling
gst-launch-1.0 \
    filesrc location=4k_video.mp4 ! decodebin ! \
    hailotilecropper tile-width=640 tile-height=640 tile-overlap=0.2 ! \
    hailonet hef-path=model.hef ! \
    hailotileaggregator ! \
    autovideosink
```

**Properties:**

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `tile-width` | Int | Tile width | 640 |
| `tile-height` | Int | Tile height | 640 |
| `tile-overlap` | Float | Overlap ratio | 0.2 |
| `tiles-per-frame` | Int | Max tiles per frame | 0 (unlimited) |

### 9.3 hailotileaggregator

```gst
# Aggregate tiles
gst-launch-1.0 \
    hailotilecropper ! \
    hailonet ! \
    hailotileaggregator iou-threshold=0.5 ! \
    fakesink
```

**Properties:**

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `iou-threshold` | Float | IoU threshold for NMS | 0.5 |

### 9.4 hailofilter

```gst
# Custom post-processing
gst-launch-1.0 \
    hailonet ! \
    hailofilter so-path=libpostprocess.so function-name=my_post_process ! \
    autovideosink
```

**Properties:**

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `so-path` | String | Path to shared library | Required |
| `function-name` | String | Post-process function | Required |
| `config-json` | String | JSON config path | "" |

---

## 10. Model Zoo

### 10.1 Installation

```bash
git clone https://github.com/hailo-ai/hailo_model_zoo.git
cd hailo_model_zoo
pip install -e .
```

### 10.2 Available Models

```bash
# List all models
hailo-model-zoo --list

# List by task
hailo-model-zoo --list --task detection
hailo-model-zoo --list --task classification
hailo-model-zoo --list --task segmentation

# List by network
hailo-model-zoo --list --network yolo
```

### 10.3 Download Models

```bash
# Download pre-compiled HEF
hailo-model-zoo --download yolov5m --target hailo10

# Download with specific precision
hailo-model-zoo --download yolov5m --precision int8
hailo-model-zoo --download yolov5m --precision int4
```

### 10.4 Evaluate Models

```bash
# Evaluate on dataset
hailo-model-zoo --eval yolov5m --dataset coco --target hailo10

# With specific metrics
hailo-model-zoo --eval yolov5m --dataset coco --metric map
```

### 10.5 Compile Models

```bash
# Compile from zoo
hailo-model-zoo --compile yolov5m --target hailo10 --output yolov5m.hef

# With performance optimization
hailo-model-zoo --compile yolov5m --target hailo10 --performance --output yolov5m.hef
```

### 10.6 Model Zoo Python API

```python
from hailo_model_zoo import ModelZoo

# Initialize zoo
zoo = ModelZoo()

# Get model info
model_info = zoo.get_model_info('yolov5m')
print(f"Name: {model_info.name}")
print(f"Task: {model_info.task}")
print(f"Input shape: {model_info.input_shape}")

# Download model
hef_path = zoo.download('yolov5m', target='hailo10')

# Compile model
hef_path = zoo.compile('yolov5m', target='hailo10', performance=True)
```

---

## 11. Configuration Parameters

### 11.1 Input Configuration

| Parameter | Type | Description | Range |
|-----------|------|-------------|-------|
| `format_type` | Enum | Input format | RGB, BGR, GRAYSCALE, etc. |
| `width` | Int | Input width | 1-8192 |
| `height` | Int | Input height | 1-8192 |
| `batch_size` | Int | Batch size | 1-32 |
| `normalization` | Dict | Normalization params | mean, std |

### 11.2 Output Configuration (Detection)

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `nms_iou_threshold` | Float | NMS IoU threshold | 0.45 |
| `nms_score_threshold` | Float | NMS score threshold | 0.3 |
| `max_detections` | Int | Max detections per class | 100 |
| `classes` | List | Class names | Auto |

### 11.3 Device Configuration

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `scheduling_algorithm` | Enum | Scheduling mode | ROUND_ROBIN |
| `device_count` | Int | Number of devices | 1 |
| `power_mode` | Enum | Power mode | NORMAL |
| `clock_frequency` | Int | Clock frequency | Auto |

### 11.4 Power Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| `POWER_MODE_HIGH` | Maximum performance | Low-latency inference |
| `POWER_MODE_NORMAL` | Balanced | General use |
| `POWER_MODE_LOW` | Power saving | Battery-powered |

---

## 12. Performance Optimization

### 12.1 Batch Size Optimization

```python
# Benchmark different batch sizes
for batch_size in [1, 2, 4, 8, 16]:
    infer_model.set_batch_size(batch_size)
    configured = infer_model.configure()
    
    # Warm up
    for _ in range(10):
        configured.infer(input_data)
    
    # Benchmark
    start = time.time()
    for _ in range(100):
        configured.infer(input_data)
    elapsed = time.time() - start
    
    fps = 100 * batch_size / elapsed
    print(f"Batch {batch_size}: {fps:.2f} FPS")
```

### 12.2 Multi-Stream Processing

```python
# Process multiple streams in parallel
import threading

def process_stream(stream_id, vdevice, hef_path):
    infer_model = vdevice.create_infer_model(hef_path)
    configured = infer_model.configure()
    
    while True:
        frame = get_frame(stream_id)
        output = configured.infer(frame)
        process_output(output)

# Create single VDevice for all streams
with VDevice() as vdevice:
    threads = []
    for i in range(num_streams):
        t = threading.Thread(
            target=process_stream,
            args=(i, vdevice, 'model.hef')
        )
        threads.append(t)
        t.start()
    
    for t in threads:
        t.join()
```

### 12.3 Async Pipeline

```python
import asyncio
from hailo_platform import VDevice

async def inference_worker(queue, vdevice):
    infer_model = vdevice.create_infer_model('model.hef')
    configured = infer_model.configure()
    
    while True:
        input_data = await queue.get()
        if input_data is None:
            break
        
        # Async inference
        future = asyncio.Future()
        
        def callback(output):
            future.set_result(output)
        
        configured.infer_async(input_data, callback)
        output = await future
        
        await process_output(output)

# Run async pipeline
async def main():
    queue = asyncio.Queue(maxsize=10)
    
    with VDevice() as vdevice:
        worker = asyncio.create_task(
            inference_worker(queue, vdevice)
        )
        
        # Feed inputs
        for input_data in input_generator():
            await queue.put(input_data)
        
        await queue.put(None)  # Signal done
        await worker

asyncio.run(main())
```

---

## 13. Monitoring and Debugging

### 13.1 CLI Monitoring

```bash
# Enable monitoring
export HAILO_MONITOR=1

# Run inference with monitoring
hailortcli run model.hef

# In another terminal
hailortcli monitor

# Monitor with specific interval
hailortcli monitor --interval 500  # 500ms
```

### 13.2 Python Profiling

```python
from hailo_platform import VDevice, HEF
import time

with VDevice() as vdevice:
    infer_model = vdevice.create_infer_model('model.hef')
    configured = infer_model.configure()
    
    # Warm up
    for _ in range(10):
        configured.infer(input_data)
    
    # Profile
    times = []
    for _ in range(100):
        start = time.perf_counter()
        output = configured.infer(input_data)
        end = time.perf_counter()
        times.append((end - start) * 1000)  # ms
    
    print(f"Mean latency: {sum(times)/len(times):.2f} ms")
    print(f"Min latency: {min(times):.2f} ms")
    print(f"Max latency: {max(times):.2f} ms")
    print(f"Throughput: {1000 / (sum(times)/len(times)):.2f} FPS")
```

### 13.3 Logging

```python
import logging
from hailo_platform import set_log_level

# Set log level
set_log_level(logging.DEBUG)

# Or via environment variable
import os
os.environ['HAILO_LOG_LEVEL'] = 'DEBUG'

# Log levels: DEBUG, INFO, WARNING, ERROR, CRITICAL
```

### 13.4 Firmware Logs

```bash
# Get firmware logs
hailortcli fw-control --logs

# Get device statistics
hailortcli fw-control --stats

# Get temperature
hailortcli fw-control --temperature

# Get power consumption
hailortcli fw-control --power
```

---

## 14. Multi-Device Support

### 14.1 Multi-Device Configuration

```python
from hailo_platform import VDevice

# Use multiple devices
params = VDevice.create_params()
params.device_count = 4  # Use 4 devices

with VDevice(params) as vdevice:
    # Model is distributed across devices
    infer_model = vdevice.create_infer_model('model.hef')
    configured = infer_model.configure()
    
    # Inference uses all devices
    output = configured.infer(input_data)
```

### 14.2 Device Selection

```python
# Use specific devices
params = VDevice.create_params()
params.device_ids = [0, 2]  # Use devices 0 and 2

with VDevice(params) as vdevice:
    infer_model = vdevice.create_infer_model('model.hef')
```

### 14.3 Multi-Process Service (MPS)

```bash
# Start MPS daemon
sudo hailort_mps start

# Run with MPS
hailortcli run model.hef --multi-process-service

# Or in Python
params = VDevice.create_params()
params.multi_process_service = True

with VDevice(params) as vdevice:
    # ...
```

---

## 15. Error Handling

### 15.1 Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `DEVICE_NOT_FOUND` | Device not connected | Check PCIe connection, load driver |
| `INVALID_HEF` | Corrupted HEF | Recompile model |
| `OUT_OF_MEMORY` | Insufficient device memory | Reduce batch size, use smaller model |
| `TIMEOUT` | Inference timeout | Increase timeout, check model |
| `BUSY` | Device in use | Wait for other process, use MPS |
| `INVALID_ARGUMENT` | Wrong input format | Check input shape and type |

### 15.2 Error Handling Pattern

```python
from hailo_platform import VDevice, HailoRTException

try:
    with VDevice() as vdevice:
        infer_model = vdevice.create_infer_model('model.hef')
        configured = infer_model.configure()
        output = configured.infer(input_data)
        
except HailoRTException as e:
    print(f"Hailo error: {e}")
    
    # Handle specific errors
    if 'DEVICE_NOT_FOUND' in str(e):
        print("Please check device connection")
    elif 'OUT_OF_MEMORY' in str(e):
        print("Try reducing batch size")
        
except Exception as e:
    print(f"Unexpected error: {e}")
```

### 15.3 Debugging Tips

1. **Enable debug logging:**
   ```bash
   export HAILO_LOG_LEVEL=DEBUG
   ```

2. **Check device status:**
   ```bash
   hailortcli scan
   lspci | grep Hailo
   dmesg | grep hailo
   ```

3. **Verify HEF:**
   ```bash
   hailortcli hef-info model.hef
   ```

4. **Test with CLI first:**
   ```bash
   hailortcli run model.hef --input test.jpg
   ```

---

## Appendix A: Quick Reference

### Minimal Python Example

```python
from hailo_platform import VDevice, HEF
import numpy as np

# Load model
hef = HEF('model.hef')

# Create VDevice and run inference
with VDevice() as vdevice:
    infer_model = vdevice.create_infer_model(hef)
    configured = infer_model.configure()
    
    # Prepare input
    input_data = np.random.randn(1, 640, 640, 3).astype(np.float32)
    
    # Run inference
    output = configured.infer(input_data)
    print(output)
```

### Minimal C++ Example

```cpp
#include <hailo/hailort.hpp>
#include <iostream>

int main() {
    auto vdevice = hailo::VDevice::create().release();
    auto infer_model = vdevice->create_infer_model("model.hef").release();
    auto configured = infer_model->configure().release();
    
    std::cout << "Model loaded successfully" << std::endl;
    
    return 0;
}
```

### CLI Quick Start

```bash
# Scan devices
hailortcli scan

# Run inference
hailortcli run model.hef --input image.jpg

# Monitor
export HAILO_MONITOR=1
hailortcli run model.hef &
hailortcli monitor
```

---

## Appendix B: Performance Benchmarks (Hailo-10H)

| Model | Task | Precision | Batch=1 FPS | Batch=8 FPS | Latency (ms) |
|-------|------|-----------|-------------|-------------|--------------|
| YOLOv5m | Detection | INT8 | 120 | 180 | 8.3 |
| YOLOv8m | Detection | INT8 | 100 | 150 | 10.0 |
| ResNet-50 | Classification | INT8 | 500 | 800 | 2.0 |
| EfficientNet-B0 | Classification | INT8 | 400 | 600 | 2.5 |
| DeepLabV3 | Segmentation | INT8 | 30 | 45 | 33.3 |
| Llama-2-7B | LLM | INT4 | 10 tokens/s | - | 100 |
| Whisper-Base | ASR | INT8 | 50 | 70 | 20.0 |

*Performance varies based on host CPU, PCIe configuration, and model optimization.*

---

*This reference guide is based on HailoRT 4.23 and Hailo-10H. For the latest updates, consult the official Hailo documentation at https://hailo.ai/developer-zone/documentation/*

---


