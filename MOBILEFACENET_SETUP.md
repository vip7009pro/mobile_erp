# MobileFaceNet Model Setup Guide

## 📥 Download Model

### Option 1: Pre-trained TFLite Model
```bash
# Download từ GitHub
wget https://github.com/sirius-ai/MobileFaceNet_TF/raw/master/output/MobileFaceNet.tflite

# Hoặc
curl -L -o mobilefacenet.tflite https://github.com/sirius-ai/MobileFaceNet_TF/raw/master/output/MobileFaceNet.tflite
```

### Option 2: Convert từ PyTorch
```python
import torch
import torch.onnx
from onnx_tf.backend import prepare
import tensorflow as tf

# Load PyTorch model
model = torch.load('mobilefacenet.pth')
model.eval()

# Export to ONNX
dummy_input = torch.randn(1, 3, 112, 112)
torch.onnx.export(model, dummy_input, "mobilefacenet.onnx")

# Convert ONNX to TF
onnx_model = onnx.load("mobilefacenet.onnx")
tf_rep = prepare(onnx_model)
tf_rep.export_graph("mobilefacenet_tf")

# Convert TF to TFLite
converter = tf.lite.TFLiteConverter.from_saved_model("mobilefacenet_tf")
tflite_model = converter.convert()

with open('mobilefacenet.tflite', 'wb') as f:
    f.write(tflite_model)
```

---

## 📁 Setup trong Flutter Project

### 1. Tạo thư mục assets
```bash
cd d:\Apps\mobile_erp
mkdir -p assets\models
```

### 2. Copy model file
```bash
# Copy file vào thư mục
copy mobilefacenet.tflite assets\models\

# Hoặc download trực tiếp
curl -L -o assets\models\mobilefacenet.tflite [URL]
```

### 3. Verify file tồn tại
```bash
dir assets\models\mobilefacenet.tflite
```

Expected output:
```
mobilefacenet.tflite
```

---

## ✅ Verify Model trong Code

### Test Model Loading
Thêm vào `_loadModel()`:
```dart
Future<void> _loadModel() async {
  try {
    _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
    
    // Verify input/output shapes
    print('✓ Model loaded successfully');
    print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
    print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
    print('Input type: ${_interpreter!.getInputTensor(0).type}');
    print('Output type: ${_interpreter!.getOutputTensor(0).type}');
  } catch (e) {
    print('Error loading model: $e');
    _showErrorDialog('Lỗi Model', 'Không thể tải MobileFaceNet: $e');
  }
}
```

Expected logs:
```
✓ Model loaded successfully
Input shape: [1, 112, 112, 3]
Output shape: [1, 128]
Input type: TfLiteType.float32
Output type: TfLiteType.float32
```

---

## 🧪 Test Model Inference

### Test với dummy data
```dart
Future<void> _testModel() async {
  if (_interpreter == null) {
    print('Model not loaded');
    return;
  }
  
  // Create dummy input [1, 112, 112, 3]
  var input = List.generate(
    1,
    (_) => List.generate(
      112,
      (_) => List.generate(
        112,
        (_) => [0.5, 0.5, 0.5], // Dummy RGB values
      ),
    ),
  );
  
  // Create output buffer [1, 128]
  var output = List.generate(1, (_) => List.filled(128, 0.0));
  
  // Run inference
  final stopwatch = Stopwatch()..start();
  _interpreter!.run(input, output);
  stopwatch.stop();
  
  print('Inference time: ${stopwatch.elapsedMilliseconds}ms');
  print('Output embedding (first 10): ${output[0].sublist(0, 10)}');
  print('Embedding length: ${output[0].length}');
}
```

Expected output:
```
Inference time: 50-200ms (depends on device)
Output embedding (first 10): [0.123, -0.456, 0.789, ...]
Embedding length: 128
```

---

## 📊 Model Specifications

### MobileFaceNet Architecture
```
Input: [1, 112, 112, 3] RGB image, normalized to [-1, 1]
├── Conv2D (3x3, 64)
├── Depthwise Separable Blocks (x5)
├── Conv2D (1x1, 128)
├── Global Average Pooling
├── FC (128)
└── Output: [1, 128] embedding vector
```

### Model Size
- **File size:** ~4-5 MB
- **Parameters:** ~1M
- **FLOPs:** ~200M

### Performance
- **Inference time:** 
  - High-end phone: 20-50ms
  - Mid-range phone: 50-100ms
  - Low-end phone: 100-200ms

---

## 🔧 Troubleshooting

### Error: "Unable to load asset"
```
Error loading model: Unable to load asset: assets/models/mobilefacenet.tflite
```

**Fixes:**
1. Check file exists:
   ```bash
   dir assets\models\mobilefacenet.tflite
   ```

2. Check pubspec.yaml:
   ```yaml
   flutter:
     assets:
       - assets/models/
   ```

3. Run flutter clean:
   ```bash
   flutter clean
   flutter pub get
   ```

### Error: "Input tensor shape mismatch"
```
Error extracting embedding: Input tensor shape mismatch
```

**Fix:** Verify input shape
```dart
print('Expected: [1, 112, 112, 3]');
print('Actual: ${input.length}, ${input[0].length}, ${input[0][0].length}, ${input[0][0][0].length}');
```

### Error: "Interpreter is null"
```
Error extracting embedding: Null check operator used on a null value
```

**Fix:** Wait for model to load
```dart
if (_interpreter == null) {
  print('Model not loaded yet');
  return null;
}
```

---

## 🎯 Alternative Models

### 1. FaceNet (512D)
```
Input: [1, 160, 160, 3]
Output: [1, 512]
Size: ~90MB
Accuracy: Higher
Speed: Slower
```

### 2. ArcFace (512D)
```
Input: [1, 112, 112, 3]
Output: [1, 512]
Size: ~30MB
Accuracy: Highest
Speed: Moderate
```

### 3. MobileFaceNet (128D) ✅ RECOMMENDED
```
Input: [1, 112, 112, 3]
Output: [1, 128]
Size: ~4MB
Accuracy: Good
Speed: Fastest
```

**Why MobileFaceNet?**
- ✅ Small size (4MB)
- ✅ Fast inference (50-100ms)
- ✅ Good accuracy for mobile
- ✅ Compatible với face-api.js (128D)

---

## 📝 Model Conversion Notes

### From PyTorch to TFLite
```python
# 1. PyTorch → ONNX
torch.onnx.export(model, dummy_input, "model.onnx")

# 2. ONNX → TensorFlow
from onnx_tf.backend import prepare
tf_rep = prepare(onnx.load("model.onnx"))
tf_rep.export_graph("model_tf")

# 3. TensorFlow → TFLite
converter = tf.lite.TFLiteConverter.from_saved_model("model_tf")
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()
```

### Optimization Options
```python
# Quantization (giảm size, tăng speed)
converter.optimizations = [tf.lite.Optimize.DEFAULT]

# Float16 quantization
converter.target_spec.supported_types = [tf.float16]

# INT8 quantization (cần representative dataset)
def representative_dataset():
    for _ in range(100):
        yield [np.random.rand(1, 112, 112, 3).astype(np.float32)]

converter.representative_dataset = representative_dataset
converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
```

---

## 🔗 Useful Links

### Pre-trained Models
- MobileFaceNet TF: https://github.com/sirius-ai/MobileFaceNet_TF
- FaceNet: https://github.com/davidsandberg/facenet
- ArcFace: https://github.com/deepinsight/insightface

### Tools
- TFLite Converter: https://www.tensorflow.org/lite/convert
- ONNX: https://onnx.ai/
- Netron (model visualizer): https://netron.app/

### Documentation
- TFLite Flutter: https://pub.dev/packages/tflite_flutter
- ML Kit: https://developers.google.com/ml-kit
- Face-api.js: https://github.com/justadudewhohacks/face-api.js

---

**Updated:** 2024-10-26  
**Version:** 1.0  
**Status:** Ready for deployment
