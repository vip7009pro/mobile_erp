# Debug Mode Guide - Face Recognition

## 🔍 Cách kiểm tra hệ thống hoạt động

### Visual Indicators

#### 1. Khung hình tròn (Oval Frame)
- **🔴 ĐỎ** = KHÔNG có khuôn mặt trong camera
- **🔵 XANH** = CÓ khuôn mặt được phát hiện

#### 2. Box ở giữa màn hình
Hiển thị trạng thái real-time:

**Khi KHÔNG có face:**
```
❌ (icon cancel màu đỏ)
KHÔNG CÓ KHUÔN MẶT
Số lượng: 0
```

**Khi CÓ face:**
```
✓ (icon check màu xanh)
PHÁT HIỆN KHUÔN MẶT
Số lượng: 1
```

#### 3. Status Bar (phía trên)
Hiển thị 2 dòng:
- **Dòng 1:** Status message
- **Dòng 2:** Debug info
  ```
  DEBUG: Detecting=false | Processing=false | Faces=0
  ```

### Debug Info Giải thích

```
Detecting = true/false
```
- `true`: Đang chạy face detection
- `false`: Không detect (idle hoặc cooldown)

```
Processing = true/false
```
- `true`: Đang xử lý face recognition + API call
- `false`: Không xử lý

```
Faces = số
```
- `0`: Không detect được face
- `1+`: Số lượng face được detect

---

## 🐛 Error Handling

### Popup Errors
Mọi lỗi runtime sẽ hiển thị popup với:
- Icon lỗi đỏ
- Tiêu đề lỗi
- Chi tiết lỗi
- Button "Đóng"

### Các loại lỗi có thể gặp:

#### 1. "Lỗi Camera"
```
Không tìm thấy camera trên thiết bị
```
**Nguyên nhân:** Thiết bị không có camera hoặc permission bị từ chối

#### 2. "Lỗi Khởi tạo Camera"
```
Chi tiết: [error message]
```
**Nguyên nhân:** Camera đang được sử dụng bởi app khác hoặc lỗi hệ thống

#### 3. "Lỗi Camera"
```
Không thể convert camera image
```
**Nguyên nhân:** Format ảnh không đúng hoặc camera stream bị lỗi

#### 4. "Lỗi Face Detection"
```
Chi tiết: [error message]
```
**Nguyên nhân:** ML Kit face detector gặp lỗi

---

## 📊 Testing Workflow

### Bước 1: Khởi động app
```
Status: "Đang khởi tạo camera..."
Khung: Không hiển thị
```

### Bước 2: Camera sẵn sàng
```
Status: "Camera đã sẵn sàng. Đưa mặt vào khung hình"
Khung: ĐỎ (không có face)
Debug: Detecting=false | Processing=false | Faces=0
```

### Bước 3: Đưa mặt vào camera
**Nếu hoạt động đúng:**
```
Khung: XANH (có face)
Box giữa: "PHÁT HIỆN KHUÔN MẶT"
Debug: Detecting=true | Processing=false | Faces=1
Bounding box: Xuất hiện quanh khuôn mặt
```

**Nếu KHÔNG hoạt động:**
```
Khung: VẪN ĐỎ
Box giữa: "KHÔNG CÓ KHUÔN MẶT"
Debug: Faces=0
→ Face detection KHÔNG hoạt động!
```

### Bước 4: Processing
```
Status: "✓ Phát hiện 1 khuôn mặt. Đang xử lý..."
Debug: Detecting=false | Processing=true | Faces=1
```

### Bước 5: Cooldown
```
Debug: Detecting=false | Processing=false | Faces=0/1
Khung: ĐỎ hoặc XANH tùy có face hay không
```

---

## 🔧 Troubleshooting

### Vấn đề: Khung luôn ĐỎ, không bao giờ XANH

**Kiểm tra:**
1. Debug info có `Detecting=true` không?
   - Nếu KHÔNG → Face detection không chạy
   - Check console logs

2. Có popup error không?
   - Nếu CÓ → Đọc error message
   - Fix theo hướng dẫn

3. Camera có hoạt động không?
   - Nhìn thấy hình ảnh camera?
   - Nếu KHÔNG → Lỗi camera initialization

### Vấn đề: Khung đổi XANH nhưng không có bounding box

**Nguyên nhân:**
- Face được detect nhưng painter không vẽ được
- Check console logs cho errors

### Vấn đề: Camera bị méo

**Đã fix:**
```dart
FittedBox(
  fit: BoxFit.cover,
  child: SizedBox(
    width: _cameraController!.value.previewSize!.height,
    height: _cameraController!.value.previewSize!.width,
    child: CameraPreview(_cameraController!),
  ),
)
```

Nếu vẫn méo → Check orientation của camera

---

## 📝 Console Logs

### Logs khi khởi tạo thành công:
```
✓ Camera initialized successfully
✓ Face detector ready
✓ Image stream started
```

### Logs khi có lỗi:
```
Error initializing camera: [error]
Stack trace: [stack trace]
```

```
Error processing image: [error]
Stack trace: [stack trace]
```

---

## 🎯 Expected Behavior

### Normal Flow:
1. App start → Camera init → Status "sẵn sàng"
2. Không có face → Khung ĐỎ, Faces=0
3. Đưa mặt vào → Khung XANH, Faces=1, Bounding box xuất hiện
4. Processing → Status "Đang xử lý"
5. API call → Status "Đang kiểm tra database"
6. Result → Dialog hoặc error message
7. Cooldown 3s → Quay lại bước 2

### Abnormal Flow:
- Lỗi camera → Popup error
- Lỗi face detection → Popup error
- Lỗi API → Status message màu đỏ

---

## 🔍 Debug Checklist

Kiểm tra từng bước:

- [ ] App khởi động không crash
- [ ] Camera hiển thị hình ảnh
- [ ] Camera không bị méo
- [ ] Khung hình hiển thị (đỏ ban đầu)
- [ ] Status bar hiển thị
- [ ] Debug info hiển thị
- [ ] Đưa mặt vào → Khung đổi XANH
- [ ] Debug info: Faces=1
- [ ] Bounding box xuất hiện
- [ ] Landmarks hiển thị (nếu có)
- [ ] Box giữa: "PHÁT HIỆN KHUÔN MẶT"
- [ ] Processing bắt đầu
- [ ] Không có popup error

Nếu TẤT CẢ đều ✓ → Hệ thống hoạt động HOÀN HẢO!

---

## 💡 Tips

1. **Test trong điều kiện ánh sáng tốt** - Face detection chính xác hơn
2. **Nhìn thẳng vào camera** - Góc nghiêng giảm accuracy
3. **Khoảng cách 30-50cm** - Tối ưu cho detection
4. **Check console logs** - Mọi lỗi đều được log
5. **Popup sẽ hiện** - Không cần check logs nếu có lỗi runtime

---

**Version:** 2.0 (Debug Mode)  
**Updated:** 2024-10-26  
**Status:** Ready for testing
