import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:mobile_erp/controller/APIRequest.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as imglib;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

class DiemDanhCamScreen extends StatefulWidget {
  const DiemDanhCamScreen({Key? key}) : super(key: key);

  @override
  State<DiemDanhCamScreen> createState() => _DiemDanhCamScreenState();
}

class _DiemDanhCamScreenState extends State<DiemDanhCamScreen> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  Interpreter? _interpreter;
  
  bool _isDetecting = false;
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  
  List<Face> _faces = [];
  String _statusMessage = 'Đang khởi tạo camera...';
  Color _statusColor = Colors.blue;
  
  DateTime? _lastDetectionTime;
  final int _detectionCooldownSeconds = 3;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeFaceDetector();
    _loadModel();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector?.close();
    _interpreter?.close();
    super.dispose();
  }

  // Load MobileFaceNet model
  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      print('✓ MobileFaceNet model loaded successfully');
    } catch (e) {
      print('Error loading model: $e');
      _showErrorDialog('Lỗi Model', 'Không thể tải MobileFaceNet: $e');
    }
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

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
        _statusMessage = 'Camera đã sẵn sàng. Đưa mặt vào khung hình';
        _statusColor = Colors.green;
      });

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

  // Convert CameraImage to InputImage
  InputImage? _convertCameraImage(CameraImage cameraImage) {
    try {
      print('=== Converting CameraImage ===');
      print('Image size: ${cameraImage.width}x${cameraImage.height}');
      print('Format raw: ${cameraImage.format.raw}');
      
      final camera = _cameraController!.description;
      
      InputImageRotation rotation;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotation = InputImageRotation.rotation270deg;
      } else {
        rotation = InputImageRotation.rotation90deg;
      }

      final format = InputImageFormat.nv21;
      print('Using format: $format, Rotation: $rotation');

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
      _showErrorDialog('Lỗi Convert', 'Không thể convert camera image: $e');
      return null;
    }
  }

  // Convert CameraImage to imglib.Image for MobileFaceNet
  imglib.Image _convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;
    final int uvRowStride = image.planes[1].bytesPerRow;
    final int uvPixelStride = image.planes[1].bytesPerPixel!;

    // Create image with correct constructor
    var img = imglib.Image(width: width, height: height);

    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;

        final yp = image.planes[0].bytes[index];
        final up = image.planes[1].bytes[uvIndex];
        final vp = image.planes[2].bytes[uvIndex];

        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 465 / 1024 - vp * 813 / 1024 + 135).round().clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 44).round().clamp(0, 255);

        img.setPixelRgba(x, y, r, g, b, 255);
      }
    }
    return img;
  }

  // Crop face from CameraImage
  Future<imglib.Image?> _cropFace(CameraImage image, Face face) async {
    try {
      final srcImg = _convertYUV420ToImage(image);
      final box = face.boundingBox;
      int x = box.left.toInt();
      int y = box.top.toInt();
      int w = box.width.toInt();
      int h = box.height.toInt();

      // Add some padding to the face box
      final padding = 0.2; // 20% padding
      x = (x - w * padding).toInt();
      y = (y - h * padding).toInt();
      w = (w * (1 + 2 * padding)).toInt();
      h = (h * (1 + 2 * padding)).toInt();

      // Ensure coordinates are within image bounds
      x = x.clamp(0, image.width - 1);
      y = y.clamp(0, image.height - 1);
      w = w.clamp(1, image.width - x);
      h = h.clamp(1, image.height - y);

      if (w <= 0 || h <= 0) {
        print('Invalid crop dimensions: w=$w, h=$h');
        _showErrorDialog('Lỗi', 'Kích thước khuôn mặt không hợp lệ: $w x $h');
        return null;
      }

      // Use copyCrop to crop the image
      final cropped = imglib.copyCrop(srcImg, x: x, y: y, width: w, height: h);
      return cropped;
    } catch (e, stackTrace) {
      print('Error cropping face: $e');
      print('Stack trace: $stackTrace');
      _showErrorDialog('Lỗi', 'Không thể cắt ảnh khuôn mặt: $e');
      return null;
    }
  }

  // Extract face embedding using MobileFaceNet (128D)
  Future<List<double>?> _extractFaceEmbedding(CameraImage cameraImage, Face face) async {
    try {
      if (_interpreter == null) {
        print('Model not loaded');
        _showErrorDialog('Lỗi', 'Model chưa được tải');
        return null;
      }

      // Crop face
      final croppedImage = await _cropFace(cameraImage, face);
      if (croppedImage == null) {
        print('Failed to crop face');
        _showErrorDialog('Lỗi', 'Không thể cắt khuôn mặt');
        return null;
      }

      // Resize to 112x112 (MobileFaceNet input)
      final resizedImage = imglib.copyResize(croppedImage, width: 112, height: 112);

      // Normalize pixel values to [-1, 1]
      var input = List.generate(
        1,
        (index) => List.generate(
          112,
          (y) => List.generate(
            112,
            (x) {
              final pixel = resizedImage.getPixel(x, y);
              // Extract R, G, B from Pixel object
              final r = pixel.r.toDouble();
              final g = pixel.g.toDouble();
              final b = pixel.b.toDouble();
              return [
                (r / 127.5 - 1.0),
                (g / 127.5 - 1.0),
                (b / 127.5 - 1.0),
              ];
            },
          ),
        ),
      );

      // Run MobileFaceNet
      var output = List.generate(1, (index) => List.filled(128, 0.0));
      _interpreter!.run(input, output);

      print('Embedding length: ${output[0].length}'); // Should be 128
      return output[0];
    } catch (e) {
      print('Error extracting embedding: $e');
      _showErrorDialog('Lỗi', 'Không thể trích xuất đặc trưng khuôn mặt');
      return null;
    }
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
    AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      animType: AnimType.rightSlide,
      title: 'Điểm danh thành công',
      desc: 'Nhân viên: ${result['employee_name'] ?? 'N/A'}\n'
          'Mã NV: ${result['employee_code'] ?? 'N/A'}\n'
          'Thời gian: ${result['attendance_time'] ?? DateTime.now().toString()}',
      btnOkOnPress: () {},
    ).show();
  }

  // Xử lý camera image stream
  Future<void> _processCameraImage(CameraImage cameraImage) async {
    if (_isDetecting || _isProcessing) return;
    
    if (_lastDetectionTime != null) {
      final timeSinceLastDetection = DateTime.now().difference(_lastDetectionTime!);
      if (timeSinceLastDetection.inSeconds < _detectionCooldownSeconds) {
        return;
      }
    }

    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(cameraImage);
      if (inputImage == null) {
        _isDetecting = false;
        _showErrorDialog('Lỗi Camera', 'Không thể convert camera image');
        return;
      }

      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isNotEmpty && !_isProcessing) {
        setState(() {
          _faces = faces;
          _statusMessage = '✓ Phát hiện ${faces.length} khuôn mặt. Đang xử lý...';
          _statusColor = Colors.orange;
        });

        await _processFaceRecognition(cameraImage, faces.first);
      } else if (faces.isNotEmpty) {
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

  // Show error dialog
  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.rightSlide,
      title: title,
      desc: message,
      btnOkOnPress: () {},
    ).show();
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
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize!.height,
                    height: _cameraController!.value.previewSize!.width,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
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

      final RRect roundedRect = RRect.fromRectAndRadius(
        rect,
        const Radius.circular(20),
      );
      canvas.drawRRect(roundedRect, boxPaint);

      final Paint cornerPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..color = Colors.green
        ..strokeCap = StrokeCap.round;

      final double cornerLength = 30;

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