# 🔧 SỬA LỖI BACKEND - FACE RECOGNITION

## ❌ Vấn đề hiện tại

### Đăng ký (updatefaceid):
- Nhận: `FACE_ID` là **byte array** (768 bytes)
- Chuyển thành hex string và lưu VARBINARY

### Nhận diện (recognizeface):
- Nhận: `FACE_ID` là **Float32Array** (192 floats)
- So sánh trực tiếp

### Kết quả:
- **Byte order (endianness) không khớp**
- **Score rất thấp** do dữ liệu bị sai

---

## ✅ GIẢI PHÁP: Thống nhất dùng Float32Array

### 1. Sửa `updatefaceid` - Nhận Float32Array thay vì byte array

```javascript
exports.updatefaceid = async (req, res, DATA) => {
  let EMPL_NO = req.payload_data["EMPL_NO"];
  let checkkq = "OK";
  
  // FACE_ID bây giờ là Array<number> (192 floats)
  let face_id_array = DATA.FACE_ID;
  console.log('face_id_array length:', face_id_array.length); // Phải là 192
  console.log('face_id_array sample:', face_id_array.slice(0, 5)); // [0.123, -0.456, ...]

  // Validate độ dài (192 floats)
  if (face_id_array.length !== 192) {
    return res.status(400).json({ 
      tk_status: 'NG',
      error: `Độ dài face_id_array không đúng: ${face_id_array.length}, cần 192 floats` 
    });
  }

  // Chuyển Float32Array thành Buffer (192 floats × 4 bytes = 768 bytes)
  const buffer = Buffer.allocUnsafe(192 * 4);
  for (let i = 0; i < 192; i++) {
    buffer.writeFloatLE(face_id_array[i], i * 4); // Little Endian
  }
  
  const hexString = buffer.toString('hex');
  console.log('Buffer length:', buffer.length); // 768 bytes
  console.log('Hex string length:', hexString.length); // 1536 chars

  // Validate CTR_CD và EMPL_NO
  if (!/^[a-zA-Z0-9]+$/.test(DATA.CTR_CD) || !/^[a-zA-Z0-9]+$/.test(DATA.EMPL_NO)) {
    return res.status(400).json({ 
      tk_status: 'NG',
      error: 'CTR_CD hoặc EMPL_NO không hợp lệ' 
    });
  }

  // Chuỗi SQL với CONVERT
  const setpdQuery = `
    UPDATE ZTBEMPLINFO
    SET FACE_ID = CONVERT(VARBINARY(MAX), '${hexString}', 2)
    WHERE CTR_CD = '${DATA.CTR_CD.replace(/'/g, "''")}' 
      AND EMPL_NO = '${DATA.EMPL_NO.replace(/'/g, "''")}'
  `;
  
  console.log('Updating FACE_ID for:', DATA.CTR_CD, DATA.EMPL_NO);
  checkkq = await queryDB(setpdQuery);
  
  res.send({
    tk_status: 'OK',
    message: 'Đăng ký khuôn mặt thành công',
    data: {
      EMPL_NO: DATA.EMPL_NO,
      embedding_length: face_id_array.length,
    }
  });
};
```

### 2. Sửa `recognizeface` - Đọc Buffer đúng cách

```javascript
exports.recognizeface = async (req, res, DATA) => {
  let EMPL_NO = req.payload_data["EMPL_NO"];
  let checkkq = "OK";
  
  const setpdQuery = `
    SELECT CTR_CD, EMPL_NO, FIRST_NAME, MIDLAST_NAME, FACE_ID 
    FROM ZTBEMPLINFO 
    WHERE CTR_CD='${DATA.CTR_CD}' AND FACE_ID IS NOT NULL
  `;
  
  let result = await queryDB(setpdQuery);
  let bestMatch = null;
  let bestScore = -1;
  
  console.log('Input FACE_ID length:', DATA.FACE_ID.length); // 192
  console.log('Input FACE_ID sample:', DATA.FACE_ID.slice(0, 5));

  for (const row of result.data) {
    // Đọc Buffer từ DB và chuyển thành Float32Array
    const buffer = row.FACE_ID; // Buffer từ SQL Server
    
    if (buffer.length !== 768) {
      console.log(`Skipping ${row.EMPL_NO}: Invalid buffer length ${buffer.length}`);
      continue;
    }
    
    // Chuyển Buffer thành Float32Array (Little Endian)
    const storedEmbedding = new Float32Array(192);
    for (let i = 0; i < 192; i++) {
      storedEmbedding[i] = buffer.readFloatLE(i * 4);
    }
    
    // So sánh
    const score = cosineSimilarity(DATA.FACE_ID, storedEmbedding);
    console.log('EMPL:', row.EMPL_NO, 'Score:', score.toFixed(4));
    
    if (score > bestScore && score > 0.6) { // Ngưỡng 0.6
      bestScore = score;
      bestMatch = {
        matchId: row.CTR_CD + '-' + row.EMPL_NO,
        CTR_CD: row.CTR_CD,
        EMPL_NO: row.EMPL_NO,
        name: row.FIRST_NAME + ' ' + row.MIDLAST_NAME,
        score,
      };
    }
  }
  
  if (!bestMatch) {
    return res.status(404).json({
      tk_status: 'NG', 
      message: 'Không tìm thấy khuôn mặt phù hợp (score < 0.6)' 
    });
  }
  
  console.log('Best match:', bestMatch);
  res.send({
    tk_status: "OK", 
    data: bestMatch
  });
};
```

### 3. Hàm cosineSimilarity (nếu chưa có)

```javascript
function cosineSimilarity(vecA, vecB) {
  if (vecA.length !== vecB.length) {
    throw new Error('Vectors must have same length');
  }
  
  let dotProduct = 0;
  let normA = 0;
  let normB = 0;
  
  for (let i = 0; i < vecA.length; i++) {
    dotProduct += vecA[i] * vecB[i];
    normA += vecA[i] * vecA[i];
    normB += vecB[i] * vecB[i];
  }
  
  normA = Math.sqrt(normA);
  normB = Math.sqrt(normB);
  
  if (normA === 0 || normB === 0) {
    return 0;
  }
  
  return dotProduct / (normA * normB);
}
```

---

## 📊 Kiểm tra sau khi sửa

### Test đăng ký:
```bash
# Log phải hiển thị:
face_id_array length: 192
face_id_array sample: [0.123, -0.456, 0.789, ...]
Buffer length: 768
Hex string length: 1536
```

### Test nhận diện:
```bash
# Log phải hiển thị:
Input FACE_ID length: 192
Input FACE_ID sample: [0.123, -0.456, ...]
EMPL: NV001 Score: 0.9876  # Score cao (>0.9) cho cùng người
EMPL: NV002 Score: 0.3421  # Score thấp cho người khác
```

---

## 🎯 Kết quả mong đợi

- ✅ Score **> 0.9** cho cùng một người
- ✅ Score **< 0.5** cho người khác
- ✅ Không còn vấn đề endianness
- ✅ Dữ liệu nhất quán giữa đăng ký và nhận diện

---

## 🔍 Debug nếu vẫn lỗi

### 1. Kiểm tra dữ liệu trong DB:
```sql
SELECT EMPL_NO, DATALENGTH(FACE_ID) as byte_length 
FROM ZTBEMPLINFO 
WHERE FACE_ID IS NOT NULL;
-- Phải trả về 768 bytes
```

### 2. So sánh embedding trước và sau khi lưu:
```javascript
// Trong updatefaceid, sau khi lưu:
const testQuery = `SELECT FACE_ID FROM ZTBEMPLINFO WHERE EMPL_NO='${DATA.EMPL_NO}'`;
const testResult = await queryDB(testQuery);
const savedBuffer = testResult.data[0].FACE_ID;

// Đọc lại và so sánh
const savedEmbedding = new Float32Array(192);
for (let i = 0; i < 192; i++) {
  savedEmbedding[i] = savedBuffer.readFloatLE(i * 4);
}

console.log('Original:', face_id_array.slice(0, 5));
console.log('Saved:', Array.from(savedEmbedding.slice(0, 5)));
// Phải giống nhau!
```

### 3. Test cosine similarity:
```javascript
// Test với chính nó
const score = cosineSimilarity(face_id_array, face_id_array);
console.log('Self similarity:', score); // Phải = 1.0
```
