import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

class FaceRecognitionScreen extends StatefulWidget {
  const FaceRecognitionScreen({super.key});

  @override
  State<FaceRecognitionScreen> createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen> {
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

  String _recognizedName = '';
  double _score = 0.0;
  String _status = 'Đang khởi động...';
  Color _indicatorColor = Colors.orange;

  List<Map<String, dynamic>> _registeredFaces = [];

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await _loadModel();
    await _initializeCamera();
    await _loadRegisteredFaces();
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

  Future<void> _loadRegisteredFaces() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('face_')).toList();

    final List<Map<String, dynamic>> faces = [];
    for (String key in keys) {
      final data = prefs.getString(key);
      if (data != null) {
        final json = jsonDecode(data) as Map<String, dynamic>;
        faces.add({
          'name': json['name'] as String,
          'embedding': (json['embedding'] as List).cast<double>(),
        });
      }
    }

    setState(() {
      _registeredFaces = faces;
    });
  }

  void _processCameraImage(CameraImage image) async {
    if (_isDetecting || !mounted || !_isCameraInitialized || _registeredFaces.isEmpty) return;
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
      _recognizedName = '';
      _score = 0.0;
    });

    if (faces.isNotEmpty) {
      final face = faces.first;
      final screenSize = MediaQuery.of(context).size;
      final faceRect = _transformFaceRect(face, image, screenSize);

      final centerFrame = Rect.fromCenter(
        center: Offset(screenSize.width / 2, screenSize.height / 2),
        width: screenSize.width * 0.6,
        height: screenSize.height * 0.6,
      );

      final isInCenter = centerFrame.contains(faceRect.center);
      final isFacingFront = face.headEulerAngleY!.abs() < 20 && face.headEulerAngleZ!.abs() < 20;

      if (isInCenter && isFacingFront) {
        setState(() {
          _hasValidFace = true;
          _faceBoundingBox = faceRect;
          _status = 'Đang nhận diện...';
          _indicatorColor = Colors.orange;
        });

        final currentEmbedding = await _extractEmbedding(image, face);
        if (currentEmbedding != null) {
          final result = _findBestMatch(currentEmbedding);
          if (result != null && result['score'] > 0.6) {
            setState(() {
              _recognizedName = result['name'];
              _score = result['score'];
              _status = 'Đã nhận diện';
              _indicatorColor = Colors.green;
            });
          } else {
            setState(() {
              _recognizedName = 'Không nhận diện';
              _score = 0.0;
              _status = 'Có mặt';
              _indicatorColor = Colors.green;
            });
          }
        }
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

  Offset _transformPoint(Matrix4 matrix, Offset point) {
    final vector3 = vector.Vector3(
      point.dx,
      point.dy,
      0.0,
    );
    final transformedVector = matrix.perspectiveTransform(vector3);
    return Offset(transformedVector.x, transformedVector.y);
  }

  Rect _transformFaceRect(Face face, CameraImage image, Size screenSize) {
    final matrix = _getTransformationMatrix(
      inputSize: Size(image.width.toDouble(), image.height.toDouble()),
      outputSize: screenSize,
      rotation: _cameraController!.description.sensorOrientation,
      mirror: _cameraController!.description.lensDirection == CameraLensDirection.front,
    );

    final rect = face.boundingBox;
    final p1 = Offset(rect.left, rect.top);
    final p2 = Offset(rect.right, rect.bottom);

    final tp1 = _transformPoint(matrix, p1);
    final tp2 = _transformPoint(matrix, p2);

    return Rect.fromPoints(tp1, tp2);
  }

  Matrix4 _getTransformationMatrix({
    required Size inputSize,
    required Size outputSize,
    required int rotation,
    required bool mirror,
  }) {
    final matrix = Matrix4.identity();

    matrix.scale(outputSize.width / inputSize.width, outputSize.height / inputSize.height);
    final rad = rotation * (pi / 180);
    matrix.rotateZ(rad);

    if (mirror) {
      matrix.scale(-1.0, 1.0);
      matrix.translate(-outputSize.width, 0);
    }

    return matrix;
  }

  Future<List<double>?> _extractEmbedding(CameraImage image, Face face) async {
    try {
      final imglib.Image? rgbImage = _convertYUV420ToImage(image);
      if (rgbImage == null) return null;

      final faceRect = face.boundingBox;
      final cropX = (faceRect.left * rgbImage.width / image.width).toInt();
      final cropY = (faceRect.top * rgbImage.height / image.height).toInt();
      final cropW = (faceRect.width * rgbImage.width / image.width).toInt();
      final cropH = (faceRect.height * rgbImage.height / image.height).toInt();

      final cropped = imglib.copyCrop(
        rgbImage,
        x: cropX.clamp(0, rgbImage.width - 1),
        y: cropY.clamp(0, rgbImage.height - 1),
        width: cropW.clamp(1, rgbImage.width - cropX),
        height: cropH.clamp(1, rgbImage.height - cropY),
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

      return (output[0] as List).cast<double>();
    } catch (e) {
      debugPrint('Lỗi extract embedding: $e');
      return null;
    }
  }

  imglib.Image? _convertYUV420ToImage(CameraImage image) {
    try {
      final width = image.width;
      final height = image.height;
      final yuv420p = image.planes;

      final img = imglib.Image(width: width, height: height);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);
          final yValue = yuv420p[0].bytes[y * width + x] & 0xFF;
          final uValue = yuv420p[1].bytes[uvIndex] & 0xFF;
          final vValue = yuv420p[2].bytes[uvIndex] & 0xFF;

          final r = (yValue + 1.402 * (vValue - 128)).round().clamp(0, 255);
          final g = (yValue - 0.34414 * (uValue - 128) - 0.71414 * (vValue - 128)).round().clamp(0, 255);
          final b = (yValue + 1.772 * (uValue - 128)).round().clamp(0, 255);

          img.setPixel(x, y, imglib.ColorRgb8(r, g, b));
        }
      }
      return img;
    } catch (e) {
      debugPrint('Lỗi convert YUV: $e');
      return null;
    }
  }

  Map<String, dynamic>? _findBestMatch(List<double> currentEmbedding) {
    double bestScore = 0.0;
    String bestName = '';

    for (final face in _registeredFaces) {
      final savedEmbedding = face['embedding'] as List<double>;
      final similarity = _cosineSimilarity(currentEmbedding, savedEmbedding);
      if (similarity > bestScore) {
        bestScore = similarity;
        bestName = face['name'] as String;
      }
    }

    if (bestScore > 0.6) {
      return {'name': bestName, 'score': bestScore};
    }
    return null;
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return dot / (sqrt(normA) * sqrt(normB) + 1e-10);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || !_isModelLoaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nhận diện khuôn mặt')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nhận diện khuôn mặt'), backgroundColor: Colors.blue),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),

              Center(
                child: Container(
                  width: constraints.maxWidth * 0.6,
                  height: constraints.maxHeight * 0.6,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),

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

              if (_recognizedName.isNotEmpty)
                Positioned(
                  bottom: 120,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      '$_recognizedName\nScore: ${_score.toStringAsFixed(3)}',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}