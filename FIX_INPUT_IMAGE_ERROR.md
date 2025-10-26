# Fix InputImage Conversion Error

## ❌ Lỗi gặp phải

```
Error processing image: PlatformException(InputImageConverterError, java.lang.IllegalArgumentException, null, null)
```

## 🔍 Nguyên nhân

Lỗi xảy ra khi convert `CameraImage` sang `InputImage` cho Google ML Kit Face Detection trên Android.

### Vấn đề:
1. **Sai API structure** - Dùng `InputImageData` và `InputImagePlaneMetadata` (không tồn tại)
2. **Sai cách lấy bytes** - Chỉ lấy plane[0] thay vì tất cả planes
3. **Rotation không đúng** - Không xử lý đúng cho front/back camera

## ✅ Giải pháp

### Trước (SAI):
```dart
// SAI: Dùng InputImageData (không tồn tại)
final inputImageData = InputImageData(
  size: imageSize,
  imageRotation: rotation,
  inputImageFormat: format,
  planeData: planeData,
);

// SAI: Chỉ lấy plane đầu
final bytes = cameraImage.planes[0].bytes;

return InputImage.fromBytes(
  bytes: bytes,
  inputImageData: inputImageData, // SAI: parameter không tồn tại
);
```

### Sau (ĐÚNG):
```dart
// ĐÚNG: Dùng InputImageMetadata
final metadata = InputImageMetadata(
  size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
  rotation: rotation,
  format: format,
  bytesPerRow: cameraImage.planes[0].bytesPerRow,
);

// ĐÚNG: Lấy tất cả planes
final WriteBuffer allBytes = WriteBuffer();
for (final Plane plane in cameraImage.planes) {
  allBytes.putUint8List(plane.bytes);
}
final bytes = allBytes.done().buffer.asUint8List();

return InputImage.fromBytes(
  bytes: bytes,
  metadata: metadata, // ĐÚNG: parameter đúng
);
```

## 📝 Chi tiết thay đổi

### 1. Rotation handling
```dart
// Xác định rotation dựa trên camera direction
InputImageRotation rotation;
if (camera.lensDirection == CameraLensDirection.front) {
  rotation = InputImageRotation.rotation270deg;
} else {
  rotation = InputImageRotation.rotation90deg;
}
```

### 2. Format validation
```dart
final format = InputImageFormatValue.fromRawValue(cameraImage.format.raw);
if (format == null || 
    (format != InputImageFormat.nv21 && format != InputImageFormat.yuv420)) {
  print('Unsupported format: ${cameraImage.format.raw}');
  return null;
}
```

### 3. Metadata creation
```dart
final metadata = InputImageMetadata(
  size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
  rotation: rotation,
  format: format,
  bytesPerRow: cameraImage.planes[0].bytesPerRow,
);
```

### 4. Bytes concatenation
```dart
// Ghép tất cả planes (Y, U, V cho YUV420)
final WriteBuffer allBytes = WriteBuffer();
for (final Plane plane in cameraImage.planes) {
  allBytes.putUint8List(plane.bytes);
}
final bytes = allBytes.done().buffer.asUint8List();
```

## 🎯 Kết quả

### Trước fix:
- ❌ Popup error: "InputImageConverterError"
- ❌ Face detection không hoạt động
- ❌ Khung luôn đỏ

### Sau fix:
- ✅ Không có error
- ✅ Face detection hoạt động
- ✅ Khung đổi xanh khi có face

## 🔧 Testing

Sau khi fix, test lại:

```bash
flutter clean
flutter run
```

### Expected behavior:
1. App khởi động → Camera bật
2. Không có popup error
3. Đưa mặt vào → Khung đổi XANH
4. Debug info: `Faces=1`
5. Bounding box xuất hiện

## 📚 Reference

### Google ML Kit InputImage API:
```dart
InputImage.fromBytes({
  required Uint8List bytes,
  required InputImageMetadata metadata,
})
```

### InputImageMetadata structure:
```dart
InputImageMetadata({
  required Size size,
  required InputImageRotation rotation,
  required InputImageFormat format,
  required int bytesPerRow,
})
```

## ⚠️ Common Mistakes

### ❌ Mistake 1: Wrong parameter name
```dart
// SAI
InputImage.fromBytes(
  bytes: bytes,
  inputImageData: metadata, // Sai tên parameter
)

// ĐÚNG
InputImage.fromBytes(
  bytes: bytes,
  metadata: metadata,
)
```

### ❌ Mistake 2: Only using first plane
```dart
// SAI - Chỉ Y plane
final bytes = cameraImage.planes[0].bytes;

// ĐÚNG - Tất cả planes (Y + U + V)
final WriteBuffer allBytes = WriteBuffer();
for (final Plane plane in cameraImage.planes) {
  allBytes.putUint8List(plane.bytes);
}
final bytes = allBytes.done().buffer.asUint8List();
```

### ❌ Mistake 3: Wrong rotation
```dart
// SAI - Dùng sensor orientation trực tiếp
final rotation = InputImageRotationValue.fromRawValue(
  camera.sensorOrientation,
);

// ĐÚNG - Xử lý theo camera direction
InputImageRotation rotation;
if (camera.lensDirection == CameraLensDirection.front) {
  rotation = InputImageRotation.rotation270deg;
} else {
  rotation = InputImageRotation.rotation90deg;
}
```

## 💡 Tips

1. **Luôn validate format** - Chỉ hỗ trợ NV21 và YUV420
2. **Concatenate all planes** - Không chỉ plane đầu
3. **Handle rotation properly** - Front vs back camera khác nhau
4. **Use correct API** - InputImageMetadata, không phải InputImageData
5. **Check logs** - Print format và size để debug

## 🐛 Troubleshooting

### Nếu vẫn lỗi:

1. **Check format:**
   ```dart
   print('Format: ${cameraImage.format.raw}');
   print('Format enum: $format');
   ```

2. **Check size:**
   ```dart
   print('Width: ${cameraImage.width}');
   print('Height: ${cameraImage.height}');
   print('Planes: ${cameraImage.planes.length}');
   ```

3. **Check bytes:**
   ```dart
   print('Total bytes: ${bytes.length}');
   print('Expected: ${cameraImage.width * cameraImage.height * 1.5}');
   ```

4. **Try different rotation:**
   ```dart
   // Test các rotation khác nhau
   rotation = InputImageRotation.rotation0deg;
   rotation = InputImageRotation.rotation90deg;
   rotation = InputImageRotation.rotation180deg;
   rotation = InputImageRotation.rotation270deg;
   ```

---

**Fixed:** 2024-10-26  
**Version:** 2.1  
**Status:** Working ✅
