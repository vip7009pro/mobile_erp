# Face Recognition Model Setup

## Yêu cầu

Để sử dụng tính năng điểm danh bằng nhận diện khuôn mặt, bạn cần đặt file model TFLite vào thư mục này.

## Model được khuyến nghị

### MobileFaceNet
- **File name**: `mobilefacenet.tflite`
- **Input shape**: `[1, 112, 112, 3]` (batch_size, height, width, channels)
- **Output shape**: `[1, 192]` hoặc `[1, 128]` (face embedding vector)
- **Download**: 
  - GitHub: https://github.com/sirius-ai/MobileFaceNet_TF
  - Pre-trained: https://github.com/deepinsight/insightface/tree/master/recognition/arcface_torch

### Các model thay thế
1. **FaceNet** (512-dimensional embeddings)
2. **ArcFace** (512-dimensional embeddings)
3. **CosFace** (512-dimensional embeddings)

## Cách tải và cài đặt model

### Bước 1: Tải model
```bash
# Ví dụ tải MobileFaceNet
wget https://github.com/sirius-ai/MobileFaceNet_TF/releases/download/v1.0/mobilefacenet.tflite
```

### Bước 2: Đặt file vào thư mục này
```
mobile_erp/
└── assets/
    └── models/
        └── mobilefacenet.tflite
```

### Bước 3: Cập nhật code nếu dùng model khác
Nếu bạn sử dụng model khác với output shape khác, cần cập nhật file `DiemDanhCamScreen.dart`:

```dart
// Dòng 312: Thay đổi output shape
final output = List.filled(1 * 192, 0.0).reshape([1, 192]);
// Thành
final output = List.filled(1 * 512, 0.0).reshape([1, 512]); // Cho FaceNet/ArcFace
```

## Cấu trúc API Backend

API endpoint `checkFaceAttendance` cần nhận và xử lý:

### Request
```json
{
  "command": "checkFaceAttendance",
  "DATA": {
    "face_embedding": [0.123, -0.456, ...], // Array of 192 or 512 floats
    "timestamp": "2024-10-26T12:00:00.000Z",
    "token_string": "...",
    "CTR_CD": "002",
    "COMPANY": "CMS"
  }
}
```

### Response - Thành công
```json
{
  "tk_status": "OK",
  "message": "Điểm danh thành công",
  "employee_name": "Nguyễn Văn A",
  "employee_code": "NV001",
  "attendance_time": "2024-10-26T12:00:00.000Z",
  "similarity_score": 0.95
}
```

### Response - Thất bại
```json
{
  "tk_status": "NG",
  "message": "Không tìm thấy khuôn mặt trong database"
}
```

## Thuật toán so sánh Face Embedding

Backend cần implement thuật toán so sánh embedding, thường dùng:

### 1. Cosine Similarity (Khuyến nghị)
```python
import numpy as np

def cosine_similarity(embedding1, embedding2):
    return np.dot(embedding1, embedding2) / (
        np.linalg.norm(embedding1) * np.linalg.norm(embedding2)
    )

# Threshold: >= 0.6 là match (có thể điều chỉnh)
```

### 2. Euclidean Distance
```python
def euclidean_distance(embedding1, embedding2):
    return np.linalg.norm(embedding1 - embedding2)

# Threshold: <= 1.0 là match (có thể điều chỉnh)
```

## Database Schema

Bảng lưu trữ face embeddings:

```sql
CREATE TABLE employee_faces (
    id INT PRIMARY KEY AUTO_INCREMENT,
    employee_code VARCHAR(50) NOT NULL,
    employee_name VARCHAR(255) NOT NULL,
    face_embedding TEXT NOT NULL, -- JSON array of floats
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    INDEX idx_employee_code (employee_code)
);
```

## Training/Enrollment Process

Để đăng ký khuôn mặt nhân viên mới:

1. Chụp 5-10 ảnh khuôn mặt từ các góc độ khác nhau
2. Extract embedding cho mỗi ảnh
3. Tính trung bình các embedding hoặc lưu tất cả
4. Lưu vào database

## Lưu ý quan trọng

1. **Lighting**: Đảm bảo ánh sáng tốt khi chụp và điểm danh
2. **Distance**: Khoảng cách 30-50cm từ camera
3. **Angle**: Nhìn thẳng vào camera, tránh góc nghiêng quá 30 độ
4. **Quality**: Camera ít nhất 2MP, độ phân giải 720p trở lên
5. **Update**: Nên cập nhật embedding định kỳ (3-6 tháng) do thay đổi ngoại hình

## Troubleshooting

### Model không load được
- Kiểm tra file `mobilefacenet.tflite` có tồn tại trong `assets/models/`
- Chạy `flutter clean` và `flutter pub get`
- Rebuild app

### Không detect được khuôn mặt
- Kiểm tra quyền camera trong Settings
- Đảm bảo ánh sáng đủ
- Khuôn mặt nằm trong khung hình oval

### API trả về lỗi
- Kiểm tra kết nối mạng
- Verify API endpoint trong `APIRequest.dart`
- Check logs backend để xem request có đến không

## Performance Optimization

1. **Cooldown**: Hiện tại set 3 giây giữa các lần detect (có thể điều chỉnh)
2. **Resolution**: Dùng `ResolutionPreset.medium` để cân bằng tốc độ và chất lượng
3. **Model**: MobileFaceNet đã được tối ưu cho mobile, nhanh và nhẹ

## Security Considerations

1. **HTTPS**: Luôn dùng HTTPS cho API calls
2. **Token**: Validate token trên server
3. **Rate Limiting**: Giới hạn số lần điểm danh/phút
4. **Encryption**: Encrypt face embeddings trong database
5. **Privacy**: Tuân thủ GDPR/CCPA nếu áp dụng
