# Quick Start - Điểm danh Khuôn mặt

## 🚀 Bắt đầu nhanh trong 5 bước

### Bước 1: Tải Model (2 phút)

```bash
# Tải model MobileFaceNet
cd assets/models

# Option A: Từ GitHub
# Truy cập: https://github.com/sirius-ai/MobileFaceNet_TF/releases
# Download file: mobilefacenet.tflite

# Option B: Từ Google Drive (nếu có)
# Download và đặt vào thư mục này

# Kiểm tra file đã có
ls mobilefacenet.tflite
```

### Bước 2: Build App (3 phút)

```bash
# Clean project
flutter clean

# Get dependencies
flutter pub get

# Build APK
flutter build apk --debug

# Hoặc run trực tiếp
flutter run
```

### Bước 3: Setup Backend API (10 phút)

Tạo file `face_attendance_api.py`:

```python
from flask import Flask, request, jsonify
import numpy as np
import json

app = Flask(__name__)

# Mock database (thay bằng DB thật)
EMPLOYEES = {
    'NV001': {
        'name': 'Nguyễn Văn A',
        'embedding': [0.1] * 192  # Thay bằng embedding thật
    }
}

def cosine_similarity(emb1, emb2):
    emb1 = np.array(emb1)
    emb2 = np.array(emb2)
    return np.dot(emb1, emb2) / (np.linalg.norm(emb1) * np.linalg.norm(emb2))

@app.route('/api', methods=['POST'])
def api():
    data = request.json
    if data['command'] == 'checkFaceAttendance':
        embedding = data['DATA']['face_embedding']
        
        # Tìm match
        best_match = None
        best_score = 0
        
        for code, emp in EMPLOYEES.items():
            score = cosine_similarity(embedding, emp['embedding'])
            if score > best_score and score >= 0.6:
                best_match = (code, emp['name'], score)
                best_score = score
        
        if best_match:
            return jsonify({
                'tk_status': 'OK',
                'message': 'Điểm danh thành công',
                'employee_code': best_match[0],
                'employee_name': best_match[1],
                'attendance_time': data['DATA']['timestamp']
            })
        else:
            return jsonify({
                'tk_status': 'NG',
                'message': 'Không tìm thấy trong database'
            })
    
    return jsonify({'tk_status': 'NG', 'message': 'Unknown command'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=3007)
```

Chạy server:
```bash
pip install flask numpy
python face_attendance_api.py
```

### Bước 4: Cấu hình Server IP (1 phút)

Trong app, set server IP:
- Mở Settings
- Chọn TEST_SERVER hoặc nhập IP: `http://YOUR_IP:3007/api`

### Bước 5: Test (2 phút)

1. Mở app
2. Navigate đến màn hình "Điểm danh bằng khuôn mặt"
3. Đưa mặt vào khung hình
4. Xem kết quả

## 📝 Enrollment - Đăng ký khuôn mặt

### Script Python để extract embedding từ ảnh

```python
import cv2
import numpy as np
from mtcnn import MTCNN
import tensorflow as tf

# Load model
interpreter = tf.lite.Interpreter(model_path='mobilefacenet.tflite')
interpreter.allocate_tensors()

# Load face detector
detector = MTCNN()

def extract_face_embedding(image_path):
    # Load image
    img = cv2.imread(image_path)
    img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    
    # Detect face
    faces = detector.detect_faces(img_rgb)
    if not faces:
        return None
    
    # Get first face
    x, y, w, h = faces[0]['box']
    face = img_rgb[y:y+h, x:x+w]
    
    # Resize to 112x112
    face = cv2.resize(face, (112, 112))
    
    # Normalize
    face = (face - 127.5) / 127.5
    face = np.expand_dims(face, axis=0).astype(np.float32)
    
    # Run inference
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    interpreter.set_tensor(input_details[0]['index'], face)
    interpreter.invoke()
    
    embedding = interpreter.get_tensor(output_details[0]['index'])
    return embedding[0].tolist()

# Extract embedding
embedding = extract_face_embedding('employee_photo.jpg')
print(json.dumps(embedding))

# Save to database
# INSERT INTO employee_faces (employee_code, employee_name, face_embedding)
# VALUES ('NV001', 'Nguyễn Văn A', '[...]')
```

## 🔧 Troubleshooting nhanh

### Lỗi: "Lỗi load model"
```bash
# Kiểm tra file model
ls assets/models/mobilefacenet.tflite

# Nếu không có, tải lại
cd assets/models
# Download model vào đây

# Clean và rebuild
flutter clean && flutter pub get && flutter run
```

### Lỗi: "Không phát hiện khuôn mặt"
- Bật đèn, đảm bảo ánh sáng đủ
- Nhìn thẳng vào camera
- Khoảng cách 30-50cm
- Không đeo khẩu trang/kính râm

### Lỗi: "Lỗi kết nối API"
```bash
# Kiểm tra server đang chạy
curl http://YOUR_IP:3007/api

# Kiểm tra firewall
# Windows: Allow port 3007
# Linux: sudo ufw allow 3007

# Test với Postman
POST http://YOUR_IP:3007/api
Body: {"command": "checkFaceAttendance", "DATA": {...}}
```

### Lỗi: "Không nhận diện được"
- Kiểm tra đã enrollment chưa
- Thử giảm threshold xuống 0.5
- Verify embedding trong database
- Re-enroll với ảnh chất lượng tốt hơn

## 📊 Test Checklist

- [ ] Model file tồn tại: `assets/models/mobilefacenet.tflite`
- [ ] App build thành công
- [ ] Camera permissions granted
- [ ] Camera khởi tạo OK
- [ ] Face detection hoạt động (khung xanh hiện ra)
- [ ] Backend API running
- [ ] Server IP configured đúng
- [ ] Test employee đã enrollment
- [ ] API response OK
- [ ] Dialog hiển thị kết quả

## 🎯 Demo Flow

```
1. User mở app
   ↓
2. Navigate to "Điểm danh bằng khuôn mặt"
   ↓
3. Camera tự động bật
   Status: "Đưa khuôn mặt vào khung hình để điểm danh"
   ↓
4. User đưa mặt vào khung oval
   ↓
5. Face detected (khung xanh hiện ra)
   Status: "Phát hiện 1 khuôn mặt. Đang xử lý..."
   ↓
6. Extract embedding (~100ms)
   Status: "Đang kiểm tra với database..."
   ↓
7. Call API (~300ms)
   ↓
8. Show result:
   - Success: Dialog "Điểm danh thành công"
   - Failure: "Không nhận diện được"
   ↓
9. Cooldown 3 giây
   ↓
10. Quay lại bước 3
```

## 📚 Tài liệu chi tiết

- `FACE_RECOGNITION_SETUP.md` - Setup đầy đủ
- `API_BACKEND_REFERENCE.md` - API implementation
- `IMPLEMENTATION_SUMMARY.md` - Technical details
- `assets/models/README.md` - Model info

## 💡 Tips

1. **Enrollment tốt = Recognition tốt**
   - Chụp 5-10 ảnh từ các góc
   - Ánh sáng tốt, không bóng mặt
   - Nhiều biểu cảm khác nhau

2. **Tối ưu threshold**
   - Bắt đầu với 0.6
   - Nếu nhiều false reject → giảm xuống 0.5
   - Nếu nhiều false accept → tăng lên 0.7

3. **Performance**
   - Medium resolution = cân bằng tốt
   - High resolution = chậm hơn nhưng chính xác hơn
   - Low resolution = nhanh nhưng kém chính xác

4. **Security**
   - Luôn dùng HTTPS
   - Validate token
   - Rate limiting
   - Log tất cả attempts

## 🆘 Support

Nếu cần help:
1. Check logs: `flutter logs`
2. Review documentation files
3. Test API với Postman
4. Verify model file
5. Check permissions

---

**Thời gian setup tổng**: ~20 phút  
**Độ khó**: Trung bình  
**Prerequisites**: Flutter, Python, Basic ML knowledge
