# API Backend Reference - Face Recognition Attendance

## Quick Start cho Backend Developer

### Endpoint cần implement

```
POST /api
Content-Type: application/json
```

### Request Structure

```json
{
  "command": "checkFaceAttendance",
  "DATA": {
    "face_embedding": [0.123, -0.456, 0.789, ...],  // 192 floats
    "timestamp": "2024-10-26T12:00:00.000Z",
    "token_string": "user_token_here",
    "CTR_CD": "002",
    "COMPANY": "CMS"
  },
  "secureContext": true
}
```

### Response Structure

**Success:**
```json
{
  "tk_status": "OK",
  "message": "Điểm danh thành công",
  "employee_name": "Nguyễn Văn A",
  "employee_code": "NV001",
  "attendance_time": "2024-10-26T12:00:15.123Z",
  "similarity_score": 0.87
}
```

**Failure:**
```json
{
  "tk_status": "NG",
  "message": "Không tìm thấy khuôn mặt trong database"
}
```

## Python Implementation Example

### 1. Basic Structure

```python
from flask import Flask, request, jsonify
import numpy as np
import json
from datetime import datetime

app = Flask(__name__)

@app.route('/api', methods=['POST'])
def api_handler():
    data = request.json
    command = data.get('command')
    
    if command == 'checkFaceAttendance':
        return handle_face_attendance(data['DATA'])
    
    return jsonify({'tk_status': 'NG', 'message': 'Unknown command'})

def handle_face_attendance(data):
    # Extract data
    face_embedding = np.array(data['face_embedding'])
    timestamp = data['timestamp']
    token = data['token_string']
    
    # Validate token
    if not validate_token(token):
        return jsonify({'tk_status': 'NG', 'message': 'Invalid token'})
    
    # Find matching employee
    employee = find_matching_employee(face_embedding)
    
    if employee:
        # Save attendance
        save_attendance(employee['code'], timestamp, employee['similarity'])
        
        return jsonify({
            'tk_status': 'OK',
            'message': 'Điểm danh thành công',
            'employee_name': employee['name'],
            'employee_code': employee['code'],
            'attendance_time': timestamp,
            'similarity_score': employee['similarity']
        })
    else:
        return jsonify({
            'tk_status': 'NG',
            'message': 'Không tìm thấy khuôn mặt trong database'
        })
```

### 2. Face Comparison Logic

```python
def cosine_similarity(embedding1, embedding2):
    """Calculate cosine similarity between two embeddings"""
    embedding1 = np.array(embedding1)
    embedding2 = np.array(embedding2)
    
    dot_product = np.dot(embedding1, embedding2)
    norm1 = np.linalg.norm(embedding1)
    norm2 = np.linalg.norm(embedding2)
    
    return dot_product / (norm1 * norm2)

def find_matching_employee(face_embedding, threshold=0.6):
    """Find employee with matching face embedding"""
    # Query all active employees from database
    employees = db.query("""
        SELECT employee_code, employee_name, face_embedding 
        FROM employee_faces 
        WHERE is_active = TRUE
    """)
    
    best_match = None
    best_score = 0
    
    for employee in employees:
        # Parse stored embedding
        db_embedding = json.loads(employee['face_embedding'])
        
        # Calculate similarity
        similarity = cosine_similarity(face_embedding, db_embedding)
        
        # Check if better match
        if similarity >= threshold and similarity > best_score:
            best_match = {
                'code': employee['employee_code'],
                'name': employee['employee_name'],
                'similarity': float(similarity)
            }
            best_score = similarity
    
    return best_match
```

### 3. Database Operations

```python
def save_attendance(employee_code, timestamp, similarity_score):
    """Save attendance record to database"""
    db.execute("""
        INSERT INTO attendance_records 
        (employee_code, attendance_time, method, similarity_score)
        VALUES (%s, %s, 'face_recognition', %s)
    """, (employee_code, timestamp, similarity_score))
    
    db.commit()

def check_duplicate_attendance(employee_code, timestamp):
    """Check if employee already checked in today"""
    today = datetime.fromisoformat(timestamp).date()
    
    result = db.query("""
        SELECT COUNT(*) as count
        FROM attendance_records
        WHERE employee_code = %s 
        AND DATE(attendance_time) = %s
    """, (employee_code, today))
    
    return result[0]['count'] > 0
```

### 4. Rate Limiting

```python
from functools import wraps
from time import time

# Simple in-memory rate limiter
rate_limit_store = {}

def rate_limit(max_requests=10, window=60):
    """Rate limit decorator: max_requests per window seconds"""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            # Get client identifier (IP or token)
            client_id = request.remote_addr
            current_time = time()
            
            # Initialize or clean old entries
            if client_id not in rate_limit_store:
                rate_limit_store[client_id] = []
            
            # Remove old requests outside window
            rate_limit_store[client_id] = [
                req_time for req_time in rate_limit_store[client_id]
                if current_time - req_time < window
            ]
            
            # Check limit
            if len(rate_limit_store[client_id]) >= max_requests:
                return jsonify({
                    'tk_status': 'NG',
                    'message': 'Too many requests. Please try again later.'
                }), 429
            
            # Add current request
            rate_limit_store[client_id].append(current_time)
            
            return func(*args, **kwargs)
        return wrapper
    return decorator

# Apply to endpoint
@app.route('/api', methods=['POST'])
@rate_limit(max_requests=10, window=60)
def api_handler():
    # ... existing code
```

## Node.js Implementation Example

```javascript
const express = require('express');
const app = express();

app.use(express.json());

// Cosine similarity function
function cosineSimilarity(embedding1, embedding2) {
    const dotProduct = embedding1.reduce((sum, val, i) => 
        sum + val * embedding2[i], 0);
    
    const norm1 = Math.sqrt(embedding1.reduce((sum, val) => 
        sum + val * val, 0));
    const norm2 = Math.sqrt(embedding2.reduce((sum, val) => 
        sum + val * val, 0));
    
    return dotProduct / (norm1 * norm2);
}

// Main API endpoint
app.post('/api', async (req, res) => {
    const { command, DATA } = req.body;
    
    if (command === 'checkFaceAttendance') {
        try {
            const { face_embedding, timestamp, token_string } = DATA;
            
            // Validate token
            if (!await validateToken(token_string)) {
                return res.json({
                    tk_status: 'NG',
                    message: 'Invalid token'
                });
            }
            
            // Find matching employee
            const employee = await findMatchingEmployee(face_embedding);
            
            if (employee) {
                // Save attendance
                await saveAttendance(employee.code, timestamp, employee.similarity);
                
                return res.json({
                    tk_status: 'OK',
                    message: 'Điểm danh thành công',
                    employee_name: employee.name,
                    employee_code: employee.code,
                    attendance_time: timestamp,
                    similarity_score: employee.similarity
                });
            } else {
                return res.json({
                    tk_status: 'NG',
                    message: 'Không tìm thấy khuôn mặt trong database'
                });
            }
        } catch (error) {
            console.error('Error:', error);
            return res.json({
                tk_status: 'NG',
                message: 'Internal server error'
            });
        }
    }
    
    res.json({ tk_status: 'NG', message: 'Unknown command' });
});

// Find matching employee
async function findMatchingEmployee(faceEmbedding, threshold = 0.6) {
    const employees = await db.query(`
        SELECT employee_code, employee_name, face_embedding 
        FROM employee_faces 
        WHERE is_active = TRUE
    `);
    
    let bestMatch = null;
    let bestScore = 0;
    
    for (const employee of employees) {
        const dbEmbedding = JSON.parse(employee.face_embedding);
        const similarity = cosineSimilarity(faceEmbedding, dbEmbedding);
        
        if (similarity >= threshold && similarity > bestScore) {
            bestMatch = {
                code: employee.employee_code,
                name: employee.employee_name,
                similarity: similarity
            };
            bestScore = similarity;
        }
    }
    
    return bestMatch;
}

app.listen(3007, () => {
    console.log('Server running on port 3007');
});
```

## Database Schema

```sql
-- Employee faces table
CREATE TABLE employee_faces (
    id INT PRIMARY KEY AUTO_INCREMENT,
    employee_code VARCHAR(50) NOT NULL UNIQUE,
    employee_name VARCHAR(255) NOT NULL,
    face_embedding TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    INDEX idx_employee_code (employee_code),
    INDEX idx_is_active (is_active)
);

-- Attendance records table
CREATE TABLE attendance_records (
    id INT PRIMARY KEY AUTO_INCREMENT,
    employee_code VARCHAR(50) NOT NULL,
    attendance_time TIMESTAMP NOT NULL,
    method VARCHAR(20) DEFAULT 'face_recognition',
    similarity_score FLOAT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_employee_code (employee_code),
    INDEX idx_attendance_time (attendance_time),
    INDEX idx_date (DATE(attendance_time))
);
```

## Testing với Postman

### 1. Test Request

```json
POST http://localhost:3007/api

{
  "command": "checkFaceAttendance",
  "DATA": {
    "face_embedding": [0.1, 0.2, 0.3, ..., 0.192],  // 192 numbers
    "timestamp": "2024-10-26T12:00:00.000Z",
    "token_string": "test_token",
    "CTR_CD": "002",
    "COMPANY": "CMS"
  },
  "secureContext": true
}
```

### 2. Insert Test Data

```sql
-- Insert test employee with dummy embedding
INSERT INTO employee_faces (employee_code, employee_name, face_embedding)
VALUES (
    'NV001',
    'Nguyễn Văn A',
    '[0.1, 0.2, 0.3, ..., 0.192]'  -- 192 numbers
);
```

## Performance Tips

1. **Database Indexing**: Index on `employee_code` and `is_active`
2. **Caching**: Cache active employees in Redis
3. **Batch Processing**: Process multiple comparisons in parallel
4. **Vector Database**: Use specialized DB like Milvus for large scale
5. **Connection Pooling**: Reuse database connections

## Security Checklist

- [ ] HTTPS enabled
- [ ] Token validation implemented
- [ ] Rate limiting active
- [ ] SQL injection prevention
- [ ] Input validation
- [ ] Error messages don't leak info
- [ ] Audit logging enabled
- [ ] Face embeddings encrypted at rest

## Monitoring

Log these metrics:
- Total attendance attempts
- Success rate
- Average similarity score
- Response time
- Failed attempts per employee
- API errors

## Troubleshooting

**High false reject rate:**
- Lower threshold (0.5 instead of 0.6)
- Check enrollment quality
- Verify embedding extraction

**High false accept rate:**
- Increase threshold (0.7 instead of 0.6)
- Add liveness detection
- Require multiple frames

**Slow response:**
- Add database indexes
- Implement caching
- Use connection pooling
- Consider vector database
