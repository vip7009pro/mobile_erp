# Hướng dẫn Setup Điểm danh bằng Nhận diện Khuôn mặt

## Tổng quan

Hệ thống điểm danh sử dụng:
- **Camera**: Tự động bật khi vào màn hình
- **Face Detection**: Google ML Kit
- **Face Recognition**: TFLite model (MobileFaceNet)
- **API**: Gọi `checkFaceAttendance` để verify và lưu điểm danh

## Các bước cài đặt

### 1. Cài đặt Model (BẮT BUỘC)

Model TFLite chưa được include trong source code. Bạn cần:

**Tải model:**
```bash
# Option 1: Tải từ GitHub
cd assets/models
# Tải file mobilefacenet.tflite từ một trong các nguồn:
# - https://github.com/sirius-ai/MobileFaceNet_TF
# - https://github.com/deepinsight/insightface
```

**Hoặc sử dụng model tự train:**
- Đặt file `.tflite` vào `assets/models/`
- Đổi tên thành `mobilefacenet.tflite` hoặc update code ở dòng 112 trong `DiemDanhCamScreen.dart`

### 2. Cấu hình Backend API

Tạo endpoint `checkFaceAttendance` trong backend API của bạn.

**Input:**
```json
{
  "face_embedding": [0.123, -0.456, ...], // 192 hoặc 512 số float
  "timestamp": "2024-10-26T12:00:00.000Z"
}
```

**Output khi thành công:**
```json
{
  "tk_status": "OK",
  "message": "Điểm danh thành công",
  "employee_name": "Nguyễn Văn A",
  "employee_code": "NV001",
  "attendance_time": "2024-10-26T12:00:00.000Z"
}
```

**Output khi thất bại:**
```json
{
  "tk_status": "NG",
  "message": "Không tìm thấy khuôn mặt trong database"
}
```

### 3. Database Setup

Tạo bảng lưu face embeddings:

```sql
CREATE TABLE employee_faces (
    id INT PRIMARY KEY AUTO_INCREMENT,
    employee_code VARCHAR(50) NOT NULL,
    employee_name VARCHAR(255) NOT NULL,
    face_embedding TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);
```

### 4. Enrollment (Đăng ký khuôn mặt)

Trước khi nhân viên có thể điểm danh, cần đăng ký khuôn mặt:

1. Chụp 5-10 ảnh khuôn mặt nhân viên
2. Extract face embedding từ mỗi ảnh
3. Tính embedding trung bình hoặc lưu tất cả
4. Lưu vào database

**Ví dụ Python backend:**
```python
import numpy as np

def compare_faces(embedding1, embedding2, threshold=0.6):
    """So sánh 2 face embeddings bằng cosine similarity"""
    similarity = np.dot(embedding1, embedding2) / (
        np.linalg.norm(embedding1) * np.linalg.norm(embedding2)
    )
    return similarity >= threshold, similarity

def find_matching_employee(face_embedding, employee_faces):
    """Tìm nhân viên matching với face embedding"""
    best_match = None
    best_score = 0
    
    for employee in employee_faces:
        db_embedding = json.loads(employee['face_embedding'])
        is_match, score = compare_faces(face_embedding, db_embedding)
        
        if is_match and score > best_score:
            best_match = employee
            best_score = score
    
    return best_match, best_score
```

### 5. Build và Test

```bash
# Clean và rebuild
flutter clean
flutter pub get
flutter build apk --debug

# Hoặc run trực tiếp
flutter run
```

## Cách sử dụng

1. Mở app và navigate đến màn hình điểm danh
2. Camera sẽ tự động bật
3. Đưa khuôn mặt vào khung hình oval màu trắng
4. Hệ thống tự động:
   - Detect khuôn mặt (khung xanh hiện ra)
   - Extract face embedding
   - Gọi API check database
   - Hiển thị kết quả

## Tùy chỉnh

### Thay đổi cooldown time
```dart
// File: DiemDanhCamScreen.dart, dòng 34
final int _detectionCooldownSeconds = 3; // Đổi thành 5 hoặc 10
```

### Thay đổi camera resolution
```dart
// File: DiemDanhCamScreen.dart, dòng 72
ResolutionPreset.medium, // Đổi thành .high hoặc .low
```

### Thay đổi threshold similarity
Điều chỉnh trong backend API (khuyến nghị: 0.6 - 0.7)

## Xử lý lỗi thường gặp

### 1. "Lỗi load model"
- Kiểm tra file `mobilefacenet.tflite` có trong `assets/models/`
- Chạy `flutter clean && flutter pub get`
- Rebuild app

### 2. "Không phát hiện khuôn mặt"
- Đảm bảo ánh sáng đủ
- Khuôn mặt nhìn thẳng vào camera
- Khoảng cách 30-50cm

### 3. "Không nhận diện được"
- Kiểm tra nhân viên đã đăng ký khuôn mặt chưa
- Thử điều chỉnh threshold trong backend
- Cập nhật lại face embedding (có thể đã thay đổi ngoại hình)

### 4. "Lỗi kết nối API"
- Kiểm tra network
- Verify API endpoint trong `APIRequest.dart`
- Check backend logs

## Cấu trúc File

```
mobile_erp/
├── lib/
│   ├── pages/
│   │   └── screens/
│   │       └── DiemDanhCamScreen.dart  # Màn hình điểm danh
│   └── controller/
│       └── APIRequest.dart              # API calls
├── assets/
│   └── models/
│       ├── mobilefacenet.tflite        # Model file (cần tải)
│       └── README.md                    # Chi tiết về model
└── android/
    └── app/
        └── src/
            └── main/
                └── AndroidManifest.xml  # Đã có camera permissions

```

## Performance Tips

1. **Ánh sáng tốt**: Tăng accuracy lên 20-30%
2. **Camera quality**: Tối thiểu 2MP
3. **Enrollment**: Chụp nhiều góc độ khác nhau
4. **Update định kỳ**: Cập nhật embedding mỗi 3-6 tháng
5. **Database indexing**: Index trên employee_code

## Security Best Practices

1. ✅ Sử dụng HTTPS cho tất cả API calls
2. ✅ Validate token trên server
3. ✅ Rate limiting để tránh abuse
4. ✅ Encrypt face embeddings trong database
5. ✅ Log tất cả attendance attempts
6. ✅ Implement timeout cho camera session

## Liên hệ Support

Nếu gặp vấn đề, cung cấp thông tin sau:
- Flutter version: `flutter --version`
- Device model và Android version
- Error logs từ `flutter logs`
- Screenshots nếu có

## Changelog

### Version 1.0.0 (2024-10-26)
- ✅ Tích hợp camera với auto-start
- ✅ Face detection với ML Kit
- ✅ Face recognition với TFLite
- ✅ API integration
- ✅ Real-time feedback UI
- ✅ Success/failure dialogs
- ✅ Cooldown mechanism
