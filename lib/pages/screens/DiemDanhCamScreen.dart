import 'dart:async';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:mobile_erp/controller/APIRequest.dart';

class DiemDanhCamScreen extends StatefulWidget {
  const DiemDanhCamScreen({Key? key}) : super(key: key);

  @override
  State<DiemDanhCamScreen> createState() => _DiemDanhCamScreenState();
}

class _DiemDanhCamScreenState extends State<DiemDanhCamScreen> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  
  bool _isDetecting = false;
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  
  List<Face> _faces = [];
  String _statusMessage = 'Đang khởi tạo camera...';
  Color _statusColor = Colors.blue;
  
  // Cooldown để tránh detect liên tục
  DateTime? _lastDetectionTime;
  final int _detectionCooldownSeconds = 3;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeFaceDetector();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector?.close();
    super.dispose();
  }

  // Khởi tạo camera
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _statusMessage = 'Không tìm thấy camera';
          _statusColor = Colors.red;
        });
        _showErrorDialog('Lỗi Camera', 'Không tìm thấy camera trên thiết bị');
        return;
      }

      // Chọn camera trước (front camera)
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21, // Use NV21 for ML Kit compatibility
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
        _statusMessage = 'Camera đã sẵn sàng. Đưa mặt vào khung hình';
        _statusColor = Colors.green;
      });

      // Bắt đầu stream xử lý ảnh
      _cameraController!.startImageStream(_processCameraImage);
      
      print('✓ Camera initialized successfully');
      print('✓ Face detector ready');
      print('✓ Image stream started');
    } catch (e, stackTrace) {
      print('Error initializing camera: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _statusMessage = 'Lỗi khởi tạo camera: $e';
        _statusColor = Colors.red;
      });
      _showErrorDialog('Lỗi Khởi tạo Camera', 'Chi tiết: $e');
    }
  }

  // Khởi tạo face detector
  void _initializeFaceDetector() {
    final options = FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.15,
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);
  }

  // Extract face features từ ML Kit (thay thế TFLite)
  // ML Kit cung cấp landmarks, contours, và bounding box
  // Có thể dùng để tạo "feature vector" đơn giản

  // Show error dialog
  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 32),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  // Xử lý camera image stream
  Future<void> _processCameraImage(CameraImage cameraImage) async {
    if (_isDetecting || _isProcessing) return;
    
    // Kiểm tra cooldown
    if (_lastDetectionTime != null) {
      final timeSinceLastDetection = DateTime.now().difference(_lastDetectionTime!);
      if (timeSinceLastDetection.inSeconds < _detectionCooldownSeconds) {
        return;
      }
    }

    _isDetecting = true;

    try {
      // Convert CameraImage to InputImage
      final inputImage = _convertCameraImage(cameraImage);
      if (inputImage == null) {
        _isDetecting = false;
        _showErrorDialog('Lỗi Camera', 'Không thể convert camera image');
        return;
      }

      // Detect faces
      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isNotEmpty && !_isProcessing) {
        setState(() {
          _faces = faces;
          _statusMessage = '✓ Phát hiện ${faces.length} khuôn mặt. Đang xử lý...';
          _statusColor = Colors.orange;
        });

        // Xử lý khuôn mặt đầu tiên
        await _processFaceRecognition(cameraImage, faces.first);
      } else if (faces.isNotEmpty) {
        // Đang processing nhưng vẫn detect được face
        setState(() {
          _faces = faces;
        });
      } else {
        setState(() {
          _faces = faces;
          if (faces.isEmpty && !_isProcessing) {
            _statusMessage = 'Đưa khuôn mặt vào khung hình để điểm danh';
            _statusColor = Colors.green;
          }
        });
      }
    } catch (e, stackTrace) {
      print('Error processing image: $e');
      print('Stack trace: $stackTrace');
      _showErrorDialog('Lỗi Face Detection', 'Chi tiết: $e');
    }

    _isDetecting = false;
  }

  // Convert CameraImage to InputImage - FIX for yuv_420_888
  InputImage? _convertCameraImage(CameraImage cameraImage) {
    try {
      print('=== Converting CameraImage ===');
      print('Image size: ${cameraImage.width}x${cameraImage.height}');
      print('Format raw: ${cameraImage.format.raw}');
      
      final camera = _cameraController!.description;
      
      // Determine rotation
      InputImageRotation rotation;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotation = InputImageRotation.rotation270deg;
      } else {
        rotation = InputImageRotation.rotation90deg;
      }

      // CRITICAL: Force NV21 format instead of yuv_420_888
      // yuv_420_888 causes IllegalArgumentException in ML Kit
      final format = InputImageFormat.nv21;
      print('Using format: $format (forced), Rotation: $rotation');

      // CRITICAL: Only use Y plane, not all planes
      // Concatenating all planes causes IllegalArgumentException
      final bytes = cameraImage.planes[0].bytes;
      print('Y plane bytes: ${bytes.length}');

      final metadata = InputImageMetadata(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: cameraImage.planes[0].bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
      print('✓ InputImage created successfully');
      return inputImage;
      
    } catch (e, stackTrace) {
      print('ERROR: $e');
      print('Stack: $stackTrace');
      
      // Fallback: Try alternative method
      try {
        print('Trying alternative conversion method...');
        return _convertCameraImageAlternative(cameraImage);
      } catch (e2) {
        print('Alternative method also failed: $e2');
        _showErrorDialog('Lỗi Convert', 'Không thể convert camera image.\n\nLỗi: $e');
        return null;
      }
    }
  }
  
  // Alternative conversion method
  InputImage? _convertCameraImageAlternative(CameraImage cameraImage) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in cameraImage.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
    
    final metadata = InputImageMetadata(
      size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
      rotation: InputImageRotation.rotation0deg, // Try no rotation
      format: InputImageFormat.yuv420,
      bytesPerRow: cameraImage.width,
    );
    
    return InputImage.fromBytes(bytes: bytes, metadata: metadata);
  }

  // Xử lý face recognition và điểm danh
  Future<void> _processFaceRecognition(CameraImage cameraImage, Face face) async {
    if (_isProcessing) return;
    
    _isProcessing = true;
    _lastDetectionTime = DateTime.now();

    try {
      // Extract face embedding
      final embedding = await _extractFaceEmbedding(cameraImage, face);
      
      if (embedding == null) {
        setState(() {
          _statusMessage = 'Không thể trích xuất đặc trưng khuôn mặt';
          _statusColor = Colors.red;
        });
        _isProcessing = false;
        return;
      }
       AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.rightSlide,
          title: 'Thông báo',
          desc: 'Embedding: ${embedding.join(", ")}',
          btnOkOnPress: () {},
        ).show();

      // Gọi API để check và điểm danh
      setState(() {
        _statusMessage = 'Đang kiểm tra với database...';
        _statusColor = Colors.blue;
      });

      final result = await _checkAttendanceWithAPI(embedding);

      if (result['tk_status'] == 'OK') {
        setState(() {
          _statusMessage = 'Điểm danh thành công! ${result['message'] ?? ''}';
          _statusColor = Colors.green;
        });
        
        // Hiển thị dialog thành công
        _showSuccessDialog(result);
      } else {
        setState(() {
          _statusMessage = 'Không nhận diện được: ${result['message'] ?? 'Không tìm thấy trong database'}';
          _statusColor = Colors.red;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Lỗi xử lý: $e';
        _statusColor = Colors.red;
      });
    }

    // Reset sau 3 giây
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _statusMessage = 'Đưa khuôn mặt vào khung hình để điểm danh';
          _statusColor = Colors.green;
        });
      }
      _isProcessing = false;
    });
  }

  // Extract face features từ ML Kit Face Detection
  // Tạo feature vector từ landmarks và bounding box
  Future<List<double>?> _extractFaceEmbedding(CameraImage cameraImage, Face face) async {
    try {
      List<double> features = [];
      
      // 1. Bounding box features (4 values: normalized)
      final bbox = face.boundingBox;
      features.addAll([
        bbox.left / cameraImage.width,
        bbox.top / cameraImage.height,
        bbox.width / cameraImage.width,
        bbox.height / cameraImage.height,
      ]);
      
      // 2. Face landmarks (nếu có)
      final landmarks = face.landmarks;
      for (var landmark in landmarks.values) {
        if (landmark != null) {
          features.addAll([
            landmark.position.x / cameraImage.width,
            landmark.position.y / cameraImage.height,
          ]);
        }
      }
      
      // 3. Head rotation angles (nếu có)
      if (face.headEulerAngleX != null) features.add(face.headEulerAngleX!);
      if (face.headEulerAngleY != null) features.add(face.headEulerAngleY!);
      if (face.headEulerAngleZ != null) features.add(face.headEulerAngleZ!);
      
      // 4. Smile probability
      if (face.smilingProbability != null) features.add(face.smilingProbability!);
      
      // 5. Eye open probabilities
      if (face.leftEyeOpenProbability != null) features.add(face.leftEyeOpenProbability!);
      if (face.rightEyeOpenProbability != null) features.add(face.rightEyeOpenProbability!);
      
      // Pad to fixed length (e.g., 50 features)
      while (features.length < 50) {
        features.add(0.0);
      }
      
      // Truncate if too long
      if (features.length > 50) {
        features = features.sublist(0, 50);
      }
      
      return features;
    } catch (e) {
      print('Error extracting face features: $e');
      return null;
    }
  }

  // Không cần convert image nữa vì dùng ML Kit features trực tiếp

  // Gọi API để check và điểm danh
  Future<Map<String, dynamic>> _checkAttendanceWithAPI(List<double> embedding) async {
    try {
      final response = await API_Request.api_query('recognizeface', {
        'FACE_ID': embedding,
        'timestamp': DateTime.now().toIso8601String(),
      });

      return response;
    } catch (e) {
      return {
        'tk_status': 'NG',
        'message': 'Lỗi kết nối API: $e',
      };
    }
  }

  // Hiển thị dialog thành công
  void _showSuccessDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 10),
            Text('Điểm danh thành công'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhân viên: ${result['employee_name'] ?? 'N/A'}'),
            Text('Mã NV: ${result['employee_code'] ?? 'N/A'}'),
            Text('Thời gian: ${result['attendance_time'] ?? DateTime.now().toString()}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Điểm danh bằng khuôn mặt'),
        backgroundColor: Colors.blue,
      ),
      body: _isCameraInitialized
          ? Stack(
              fit: StackFit.expand,
              children: [
                // Camera preview full screen không méo
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize!.height,
                    height: _cameraController!.value.previewSize!.width,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
                
                // Face detection overlay
                if (_faces.isNotEmpty)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: FacePainter(
                        faces: _faces,
                        imageSize: Size(
                          _cameraController!.value.previewSize!.height,
                          _cameraController!.value.previewSize!.width,
                        ),
                      ),
                    ),
                  ),
                
                // Status bar với debug info
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.9),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'DEBUG: Detecting=${_isDetecting} | Processing=${_isProcessing} | Faces=${_faces.length}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // DEBUG: Khung hình đổi màu - BLUE = có face, RED = không có face
                Center(
                  child: Container(
                    width: 250,
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _faces.isNotEmpty ? Colors.blue : Colors.red,
                        width: 5,
                      ),
                      borderRadius: BorderRadius.circular(150),
                      boxShadow: [
                        BoxShadow(
                          color: (_faces.isNotEmpty ? Colors.blue : Colors.red).withOpacity(0.6),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // DEBUG: Hiển thị trạng thái lớn ở giữa màn hình
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: (_faces.isNotEmpty ? Colors.blue : Colors.red).withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _faces.isNotEmpty ? Icons.check_circle : Icons.cancel,
                          color: Colors.white,
                          size: 60,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _faces.isNotEmpty ? 'PHÁT HIỆN KHUÔN MẶT' : 'KHÔNG CÓ KHUÔN MẶT',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Số lượng: ${_faces.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    _statusMessage,
                    style: TextStyle(color: _statusColor, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}

// Custom painter để vẽ face bounding box và landmarks
class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;

  FacePainter({required this.faces, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    for (final face in faces) {
      final scaleX = size.width / imageSize.width;
      final scaleY = size.height / imageSize.height;

      // Vẽ bounding box với màu xanh neon
      final Paint boxPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..color = Colors.greenAccent
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromLTRB(
        face.boundingBox.left * scaleX,
        face.boundingBox.top * scaleY,
        face.boundingBox.right * scaleX,
        face.boundingBox.bottom * scaleY,
      );

      // Vẽ rounded rectangle
      final RRect roundedRect = RRect.fromRectAndRadius(
        rect,
        const Radius.circular(20),
      );
      canvas.drawRRect(roundedRect, boxPaint);

      // Vẽ góc của bounding box (decorative corners)
      final Paint cornerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..color = Colors.green
        ..strokeCap = StrokeCap.round;

      final double cornerLength = 30;

      // Top-left corner
      canvas.drawLine(
        Offset(rect.left, rect.top + cornerLength),
        Offset(rect.left, rect.top),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(rect.left, rect.top),
        Offset(rect.left + cornerLength, rect.top),
        cornerPaint,
      );

      // Top-right corner
      canvas.drawLine(
        Offset(rect.right - cornerLength, rect.top),
        Offset(rect.right, rect.top),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(rect.right, rect.top),
        Offset(rect.right, rect.top + cornerLength),
        cornerPaint,
      );

      // Bottom-left corner
      canvas.drawLine(
        Offset(rect.left, rect.bottom - cornerLength),
        Offset(rect.left, rect.bottom),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(rect.left, rect.bottom),
        Offset(rect.left + cornerLength, rect.bottom),
        cornerPaint,
      );

      // Bottom-right corner
      canvas.drawLine(
        Offset(rect.right - cornerLength, rect.bottom),
        Offset(rect.right, rect.bottom),
        cornerPaint,
      );
      canvas.drawLine(
        Offset(rect.right, rect.bottom - cornerLength),
        Offset(rect.right, rect.bottom),
        cornerPaint,
      );

      // Vẽ landmarks (eyes, nose, mouth)
      final Paint landmarkPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.yellowAccent;

      for (var landmark in face.landmarks.values) {
        if (landmark != null) {
          canvas.drawCircle(
            Offset(
              landmark.position.x * scaleX,
              landmark.position.y * scaleY,
            ),
            5,
            landmarkPaint,
          );
        }
      }

      // Vẽ label "FACE DETECTED"
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'FACE DETECTED',
          style: TextStyle(
            color: Colors.greenAccent,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.black.withOpacity(0.7),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(rect.left, rect.top - 25),
      );
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}
