import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:vector_math/vector_math_64.dart' as vector;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

class FaceRegistrationScreen extends StatefulWidget {
  const FaceRegistrationScreen({super.key});

  @override
  State<FaceRegistrationScreen> createState() => _FaceRegistrationScreenState();
}

class _FaceRegistrationScreenState extends State<FaceRegistrationScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isModelLoaded = false;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  tfl.Interpreter? _interpreter;
  bool _isDetecting = false;
  bool _hasValidFace = false;
  Rect? _faceBoundingBox;

  String _status = 'Đang khởi động...';
  Color _indicatorColor = Colors.orange;

  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await _loadModel();
    await _initializeCamera();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await tfl.Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      if (mounted) setState(() => _isModelLoaded = true);
    } catch (e) {
      debugPrint('Lỗi load model: $e');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(frontCamera, ResolutionPreset.high, enableAudio: false);
      await _cameraController!.initialize();

      if (!mounted) return;

      await _cameraController!.startImageStream(_processCameraImage);

      setState(() {
        _isCameraInitialized = true;
        _status = 'Không thấy mặt';
        _indicatorColor = Colors.red;
      });
    } catch (e) {
      debugPrint('Lỗi camera: $e');
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || !mounted || !_isCameraInitialized) return;
    _isDetecting = true;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      _isDetecting = false;
      return;
    }

    final faces = await _faceDetector.processImage(inputImage);

    setState(() {
      _hasValidFace = false;
      _faceBoundingBox = null;
      _status = 'Không thấy mặt';
      _indicatorColor = Colors.red;
    });

    if (faces.isNotEmpty) {
      final face = faces.first;
      final screenSize = MediaQuery.of(context).size;
      final previewSize = _cameraController!.value.previewSize!;
      final previewAspectRatio = previewSize.width / previewSize.height;
      final previewRect = _getPreviewRect(screenSize, previewAspectRatio);
      
      // Calculate the actual preview scale factors
      final scaleX = previewRect.width / previewSize.width;
      final scaleY = previewRect.height / previewSize.height;
      
      // Calculate frame size and position
      final frameSize = min(screenSize.width, screenSize.height) * 0.7; // Smaller frame for better accuracy
      final frameRect = Rect.fromCenter(
        center: Offset(screenSize.width / 2, screenSize.height / 2 - 50), // Slightly higher than center
        width: frameSize,
        height: frameSize * 1.3, // Make it taller than wide
      );
      
      // Transform face rectangle to screen coordinates
      final faceRect = _transformFaceRect(face, image, screenSize);
      
      // Check if face is within the frame with some tolerance
      final faceCenter = faceRect.center;
      final frameCenter = frameRect.center;
      final isHorizontallyCentered = (faceCenter.dx - frameCenter.dx).abs() < (frameSize * 0.3);
      final isVerticallyCentered = (faceCenter.dy - frameCenter.dy).abs() < (frameSize * 0.3);
      
      // Face orientation checks
      final isFacingFront = face.headEulerAngleY!.abs() < 30 && 
                          face.headEulerAngleZ!.abs() < 30;
                          
      // Face size check (relative to frame)
      final faceSize = faceRect.width;
      final isGoodSize = faceSize > frameSize * 0.4 && 
                        faceSize < frameSize * 0.8;
      
      // Face is considered in center if it's within the frame bounds
      final isInCenter = isHorizontallyCentered && isVerticallyCentered;
      
      if (isInCenter && isFacingFront && isGoodSize) {
        setState(() {
          _hasValidFace = true;
          _faceBoundingBox = faceRect;
          _status = 'Sẵn sàng đăng ký';
          _indicatorColor = Colors.green;
        });
      }
    }

    _isDetecting = false;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _cameraController!.description;
    final rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final inputImageMetadata = InputImageMetadata(
      size: imageSize,
      rotation: rotation,
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
  }

  Rect _transformFaceRect(Face face, CameraImage image, Size screenSize) {
    try {
      // Get the camera's preview size
      final previewSize = _cameraController!.value.previewSize!;
      final isFrontCamera = _cameraController!.description.lensDirection == CameraLensDirection.front;
      
      // Calculate the preview rectangle on screen
      final previewAspectRatio = previewSize.width / previewSize.height;
      final previewRect = _getPreviewRect(screenSize, previewAspectRatio);
      
      // Calculate scale factors (accounting for any cropping)
      final scaleX = previewRect.width / previewSize.width;
      final scaleY = previewRect.height / previewSize.height;
      
      // Get the face bounding box in camera coordinates
      final rect = face.boundingBox;
      
      // Convert to screen coordinates
      double left, right, top, bottom;
      
      if (isFrontCamera) {
        // For front camera, mirror the X coordinates
        left = previewRect.right - (rect.right * scaleX);
        right = previewRect.right - (rect.left * scaleX);
      } else {
        left = previewRect.left + (rect.left * scaleX);
        right = previewRect.left + (rect.right * scaleX);
      }
      
      // Y coordinates (no mirroring needed)
      top = previewRect.top + (rect.top * scaleY);
      bottom = previewRect.top + (rect.bottom * scaleY);
      
      // Add some padding (percentage of face size)
      final width = right - left;
      final height = bottom - top;
      final padding = width * 0.15; // 15% padding
      
      left = (left - padding).clamp(0.0, screenSize.width);
      top = (top - padding).clamp(0.0, screenSize.height);
      right = (right + padding).clamp(0.0, screenSize.width);
      bottom = (bottom + padding).clamp(0.0, screenSize.height);
      
      return Rect.fromLTRB(left, top, right, bottom);
    } catch (e) {
      debugPrint('Error transforming face rect: $e');
      return Rect.zero;
    }
  }

  // Helper method to transform a point using Matrix4
  Offset _transformPoint(Matrix4 matrix, Offset point) {
    final vector3 = vector.Vector3(
      point.dx,
      point.dy,
      0.0,
    );
    final transformedVector = matrix.perspectiveTransform(vector3);
    return Offset(transformedVector.x, transformedVector.y);
  }

  Matrix4 _getTransformationMatrix({
    required Size inputSize,
    required Size outputSize,
    required int rotation,
    required bool mirror,
  }) {
    final matrix = Matrix4.identity();

    // Scale
    matrix.scale(outputSize.width / inputSize.width, outputSize.height / inputSize.height);

    // Rotate
    final rad = rotation * (pi / 180);
    matrix.rotateZ(rad);

    // Mirror (front camera)
    if (mirror) {
      matrix.scale(-1.0, 1.0);
      matrix.translate(-outputSize.width, 0);
    }

    return matrix;
  }

  Future<void> _registerFace() async {
    if (!_hasValidFace || _nameController.text.isEmpty || _cameraController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên và đưa mặt vào khung!')),
      );
      return;
    }

    try {
      final xFile = await _cameraController!.takePicture();
      final bytes = await xFile.readAsBytes();
      final originalImage = imglib.decodeImage(bytes);
      if (originalImage == null) return;

      if (_faceBoundingBox == null) return;

      final screenSize = MediaQuery.of(context).size;
      final cropX = (_faceBoundingBox!.left * originalImage.width / screenSize.width).toInt();
      final cropY = (_faceBoundingBox!.top * originalImage.height / screenSize.height).toInt();
      final cropW = (_faceBoundingBox!.width * originalImage.width / screenSize.width).toInt();
      final cropH = (_faceBoundingBox!.height * originalImage.height / screenSize.height).toInt();

      final cropped = imglib.copyCrop(
        originalImage,
        x: cropX.clamp(0, originalImage.width - 1),
        y: cropY.clamp(0, originalImage.height - 1),
        width: cropW.clamp(1, originalImage.width - cropX),
        height: cropH.clamp(1, originalImage.height - cropY),
      );

      final resized = imglib.copyResize(cropped, width: 112, height: 112);

      final input = Float32List(1 * 112 * 112 * 3);
      final buffer = Float32List.view(input.buffer);
      int pixelIndex = 0;

      for (int y = 0; y < 112; y++) {
        for (int x = 0; x < 112; x++) {
          final pixel = resized.getPixel(x, y);
          buffer[pixelIndex++] = (pixel.r - 127.5) / 127.5;
          buffer[pixelIndex++] = (pixel.g - 127.5) / 127.5;
          buffer[pixelIndex++] = (pixel.b - 127.5) / 127.5;
        }
      }

      final output = List.filled(1 * 128, 0.0).reshape([1, 128]);
      _interpreter!.run(input.reshape([1, 112, 112, 3]), output);

      final embedding = (output[0] as List).cast<double>();

      final prefs = await SharedPreferences.getInstance();
      final userId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString(
        'face_$userId',
        jsonEncode({'name': _nameController.text.trim(), 'embedding': embedding}),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng ký thành công: ${_nameController.text}')),
      );

      _nameController.clear();
      setState(() => _hasValidFace = false);
    } catch (e) {
      debugPrint('Lỗi đăng ký: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lỗi khi đăng ký.')),
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    _interpreter?.close();
    _nameController.dispose();
    super.dispose();
  }

  // Helper method to get the actual preview size and position
  Rect _getPreviewRect(Size screenSize, double previewAspectRatio) {
    // For better face detection, we'll make the preview fill the screen width
    // and adjust height to maintain aspect ratio
    double width = screenSize.width;
    double height = width / previewAspectRatio;
    
    // Calculate vertical position to center the preview
    double posY = (screenSize.height - height) / 2;
    
    // If preview is taller than screen, adjust to fill height
    if (height > screenSize.height) {
      height = screenSize.height;
      width = height * previewAspectRatio;
      posY = 0;
    }
    
    // Center horizontally
    double posX = (screenSize.width - width) / 2;
    
    // Ensure the preview stays within screen bounds
    return Rect.fromLTWH(
      posX.clamp(0.0, screenSize.width - 1),
      posY.clamp(0.0, screenSize.height - 1),
      width.clamp(0.0, screenSize.width),
      height.clamp(0.0, screenSize.height),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || !_isModelLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Đăng ký khuôn mặt')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final screenSize = MediaQuery.of(context).size;
    final previewAspectRatio = _cameraController!.value.aspectRatio;
    final previewRect = _getPreviewRect(screenSize, previewAspectRatio);
    
    // Make the frame larger - use 90% of the screen width
    final frameSize = min(screenSize.width, screenSize.height) * 0.9;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Đăng ký khuôn mặt'), 
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Full screen camera preview
          if (_cameraController != null)
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize!.height,
                  height: _cameraController!.value.previewSize!.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),

          // Overlay with guidance
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.black54,
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: frameSize,
                      height: frameSize,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            spreadRadius: 5,
                            blurRadius: 7,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Instruction text
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'Đưa khuôn mặt vào khung',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Đảm bảo khuôn mặt nằm trong khung và đủ sáng',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Bounding box
          if (_faceBoundingBox != null)
            Positioned.fromRect(
              rect: _faceBoundingBox!,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _hasValidFace ? Colors.green : Colors.red, width: 3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

          // Status indicator
          Positioned(
            top: 40,
            left: 20,
            child: Row(
              children: [
                CircleAvatar(radius: 12, backgroundColor: _indicatorColor),
                const SizedBox(width: 10),
                Text(_status, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Name input and register button
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Nhập tên của bạn',
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: Colors.black54,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_hasValidFace && _nameController.text.isNotEmpty) ? _registerFace : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.blue,
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: const Text('ĐĂNG KÝ', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}