# Quick Test Checklist

## ✅ Pre-flight Checks

### 1. Model File
```bash
# Check model exists
dir assets\models\mobilefacenet.tflite
```
- [ ] File exists
- [ ] Size: ~4-5 MB

### 2. Dependencies
```bash
flutter pub get
```
- [ ] No errors
- [ ] tflite_flutter installed
- [ ] image package installed

### 3. Build
```bash
flutter clean
flutter build apk --release
```
- [ ] Build successful
- [ ] No compile errors

---

## 🧪 Runtime Tests

### Test 1: App Launch
- [ ] App opens without crash
- [ ] Camera permission requested
- [ ] Camera initializes

**Expected logs:**
```
✓ Camera initialized successfully
✓ Face detector ready
✓ MobileFaceNet model loaded successfully
```

### Test 2: Model Loading
- [ ] Model loads successfully
- [ ] No error dialog

**Expected logs:**
```
✓ MobileFaceNet model loaded successfully
Input shape: [1, 112, 112, 3]
Output shape: [1, 128]
```

### Test 3: Face Detection
- [ ] Camera shows preview
- [ ] Khung ĐỎ khi không có face
- [ ] Khung XANH khi có face
- [ ] Bounding box hiển thị
- [ ] Landmarks hiển thị

**Expected logs:**
```
=== Converting CameraImage ===
Image size: 320x240
Format raw: 17
Using format: InputImageFormat.nv21
✓ InputImage created successfully
```

### Test 4: Face Recognition
- [ ] "Đang xử lý..." message
- [ ] No crash during processing
- [ ] Embedding extracted

**Expected logs:**
```
Embedding length: 128
```

### Test 5: API Call
- [ ] "Đang kiểm tra database..." message
- [ ] API call completes
- [ ] Response handled

**Expected response:**
```json
{
  "matchId": "EMP001",
  "name": "Employee Name",
  "message": "Success"
}
```

### Test 6: Success Flow
- [ ] Success dialog shows
- [ ] Employee info displayed
- [ ] Can close dialog
- [ ] Returns to ready state

### Test 7: Error Handling
- [ ] Network error → Error dialog
- [ ] No match → Error message
- [ ] Model error → Error dialog

---

## 🐛 Debug Checklist

### If Model Fails to Load
```
Error loading model: Unable to load asset
```
- [ ] Check file exists: `assets/models/mobilefacenet.tflite`
- [ ] Check pubspec.yaml has `assets/models/`
- [ ] Run `flutter clean`
- [ ] Rebuild app

### If Face Detection Fails
```
Error processing image: PlatformException
```
- [ ] Check camera format (should be NV21)
- [ ] Check logs for format details
- [ ] Try different camera resolution

### If Embedding Extraction Fails
```
Error extracting embedding: [error]
```
- [ ] Check model loaded (`_interpreter != null`)
- [ ] Check input shape [1, 112, 112, 3]
- [ ] Check image cropping succeeded
- [ ] Check resize succeeded

### If API Call Fails
```
Lỗi kết nối API: Connection refused
```
- [ ] Backend is running
- [ ] Correct URL (localhost vs IP)
- [ ] Network connectivity
- [ ] CORS enabled on backend

---

## 📊 Performance Checks

### Timing
- [ ] Face detection: < 100ms
- [ ] Embedding extraction: < 200ms
- [ ] API call: < 1000ms
- [ ] Total: < 1500ms

### Memory
- [ ] No memory leaks
- [ ] App doesn't crash after multiple uses
- [ ] Camera stream stable

### Battery
- [ ] Reasonable battery usage
- [ ] Camera stops when leaving screen
- [ ] No background processing

---

## 🎯 Acceptance Criteria

### Must Have
- [x] Camera works
- [x] Face detection works
- [x] Embedding extraction works (128D)
- [x] API integration works
- [x] Success/error dialogs work
- [x] No crashes

### Nice to Have
- [ ] Fast performance (< 1s total)
- [ ] Good UI/UX
- [ ] Helpful error messages
- [ ] Smooth animations

---

## 📝 Test Results Template

```
Date: ___________
Device: ___________
Android Version: ___________

✅ PASSED / ❌ FAILED

[ ] Model loads
[ ] Face detection works
[ ] Embedding extraction works
[ ] API call works
[ ] Success dialog shows
[ ] Error handling works

Performance:
- Face detection: _____ms
- Embedding: _____ms
- API call: _____ms
- Total: _____ms

Issues found:
1. ___________
2. ___________
3. ___________

Notes:
___________
___________
```

---

## 🚀 Quick Start Commands

```bash
# Clean build
flutter clean
flutter pub get

# Run on device
flutter run

# Build APK
flutter build apk --release

# Install APK
adb install build/app/outputs/flutter-apk/app-release.apk

# View logs
adb logcat | findstr flutter
```

---

**Version:** 1.0  
**Last Updated:** 2024-10-26
