import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:image/image.dart' as imglib;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  tfl.Interpreter? _interpreter;

  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  bool _startRecognition = true; // True: nhận diện, False: thêm mặt

  List<Face> _faces = [];
  String _statusMessage = 'Đang khởi tạo...';
  Color _statusColor = Colors.blue;

  Map<String, List<double>> _registeredFaces = {};
  double _threshold = 1.0;

  final int _inputSize = 112;
  final int _outputSize = 192;

  @override
  void initState() {
    super.initState();
    _loadSavedFaces();
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

  Future<void> _loadSavedFaces() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('registered_faces') ?? '{}';
    final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
    setState(() {
      _registeredFaces = jsonMap.map((key, value) => MapEntry(key, List<double>.from(value)));
    });
  }

  Future<void> _saveFaces() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonMap = _registeredFaces.map((key, value) => MapEntry(key, value));
    final jsonString = jsonEncode(jsonMap);
    await prefs.setString('registered_faces', jsonString);
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await tfl.Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      print('Model loaded');
    } catch (e) {
      _showError('Lỗi load model: $e');
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _cameraController!.initialize();
    setState(() {
      _isCameraInitialized = true;
      _statusMessage = 'Camera sẵn sàng';
      _statusColor = Colors.green;
    });

    _cameraController!.startImageStream(_processImage);
  }

void _initializeFaceDetector() {
  final options = FaceDetectorOptions(
    performanceMode: FaceDetectorMode.fast,
    minFaceSize: 0.1,
  );
  _faceDetector = FaceDetector(options: options);
}

  // === CHUẨN NV21 CHO ANDROID ===
  imglib.Image _convertYUV420ToImage(CameraImage image) {
    final width = image.width;
    final height = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 2;

    final img = imglib.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yRowStride + x;
        final uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

        final yp = yBytes[yIndex] & 0xFF;
        final up = uBytes[uvIndex] & 0xFF;
        final vp = vBytes[uvIndex] & 0xFF;

        int r = (yp + 1.402 * (vp - 128)).round().clamp(0, 255);
        int g = (yp - 0.34414 * (up - 128) - 0.71414 * (vp - 128)).round().clamp(0, 255);
        int b = (yp + 1.772 * (up - 128)).round().clamp(0, 255);

        img.setPixelRgb(x, y, r, g, b);
      }
    }
    return img;
  }

imglib.Image _cropAndResizeFace(CameraImage cameraImage, Face face) {
  final img = _convertYUV420ToImage(cameraImage);
  final box = face.boundingBox;

  int x = box.left.toInt().clamp(0, cameraImage.width - 1);
  int y = box.top.toInt().clamp(0, cameraImage.height - 1);
  int w = box.width.toInt().clamp(1, cameraImage.width - x);
  int h = box.height.toInt().clamp(1, cameraImage.height - y);

  var cropped = imglib.copyCrop(img, x: x, y: y, width: w, height: h);
  return imglib.copyResize(cropped, width: _inputSize, height: _inputSize);
}

Future<List<double>?> _extractEmbedding(imglib.Image image) async {
  if (_interpreter == null) return null;

  final input = Float32List(1 * _inputSize * _inputSize * 3);
  int idx = 0;

  for (int y = 0; y < _inputSize; y++) {
    for (int x = 0; x < _inputSize; x++) {
      final pixel = image.getPixel(x, y);

      // CÁCH 1: Dùng .r, .g, .b (NHANH & CHUẨN)
      final r = pixel.r / 127.5 - 1.0;
      final g = pixel.g / 127.5 - 1.0;
      final b = pixel.b / 127.5 - 1.0;

      input[idx++] = r;
      input[idx++] = g;
      input[idx++] = b;

      // HOẶC CÁCH 2: Dùng toInt() + bitshift
      // final int p = pixel.toInt();
      // input[idx++] = ((p >> 16) & 0xFF) / 127.5 - 1.0;
      // input[idx++] = ((p >> 8) & 0xFF) / 127.5 - 1.0;
      // input[idx++] = (p & 0xFF) / 127.5 - 1.0;
    }
  }

  final output = List.filled(1, List.filled(_outputSize, 0.0));
  _interpreter!.run(input, output);
  return output[0];
}

  double _l2Distance(List<double> a, List<double> b) {
    double sum = 0;
    for (int i = 0; i < a.length; i++) {
      final diff = a[i] - b[i];
      sum += diff * diff;
    }
    return math.sqrt(sum);
  }

  // === NHẬN DIỆN ===
  void _recognizeFace(List<double> embedding) {
    String bestMatch = 'Unknown';
    double minDist = double.infinity;

    for (final entry in _registeredFaces.entries) {
      final dist = _l2Distance(embedding, entry.value);
      if (dist < minDist && dist < _threshold) {
        minDist = dist;
        bestMatch = entry.key;
      }
    }

    setState(() {
      _statusMessage = bestMatch;
      _statusColor = minDist < _threshold ? Colors.green : Colors.red;
    });
  }

  // === THÊM MẶT ===
  void _addFace(List<double> embedding) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập tên'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _registeredFaces[name] = embedding;
                });
                _saveFaces();
                _showSuccess('Đã thêm: $name');
              }
              Navigator.pop(ctx);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

Future<void> _processImage(CameraImage image) async {
  if (_isProcessing) return;
  _isProcessing = true;

  // === TẠO NV21 BYTE ARRAY (Y + V + U) ===
  final yBytes = image.planes[0].bytes;
  final uBytes = image.planes[1].bytes;
  final vBytes = image.planes[2].bytes;

  final nv21 = Uint8List(yBytes.length + uBytes.length + vBytes.length);
  nv21.setAll(0, yBytes); // Y
  nv21.setAll(yBytes.length, vBytes); // V
  nv21.setAll(yBytes.length + vBytes.length, uBytes); // U

  final inputImage = InputImage.fromBytes(
    bytes: nv21,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: _getInputImageRotation(),
      format: InputImageFormat.nv21,
      bytesPerRow: image.planes[0].bytesPerRow,
    ),
  );

  try {
    final faces = await _faceDetector!.processImage(inputImage);

    if (faces.isNotEmpty) {
      print('✅ ĐÃ PHÁT HIỆN: ${faces.length} khuôn mặt');
      final cropped = _cropAndResizeFace(image, faces[0]);
      final embedding = await _extractEmbedding(cropped);
      if (embedding != null) {
        _startRecognition ? _recognizeFace(embedding) : _addFace(embedding);
      }
    } else {
      setState(() {
        _statusMessage = 'Không thấy khuôn mặt';
        _statusColor = Colors.orange;
      });
    }
  } catch (e) {
    print('ML Kit Error: $e');
    setState(() {
      _statusMessage = 'Lỗi phát hiện';
      _statusColor = Colors.red;
    });
  }

  _isProcessing = false;
}

InputImageRotation _getInputImageRotation() {
  if (!Platform.isAndroid) return InputImageRotation.rotation0deg;

  final camera = _cameraController!.description;
  final rotation = camera.sensorOrientation;

  if (camera.lensDirection == CameraLensDirection.front) {
    return InputImageRotation.values[(rotation + 270) ~/ 90 % 4];
  } else {
    return InputImageRotation.values[rotation ~/ 90 % 4];
  }
}



  void _toggleMode() {
    setState(() {
      _startRecognition = !_startRecognition;
      _statusMessage = _startRecognition ? 'Chế độ nhận diện' : 'Chế độ thêm mặt';
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Face Recognition')),
      body: _isCameraInitialized
          ? Stack(
              children: [
                CameraPreview(_cameraController!),
                Positioned(
                  top: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _statusMessage,
                      style: TextStyle(color: _statusColor, fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: ElevatedButton(
                    onPressed: _toggleMode,
                    child: Text(_startRecognition ? 'Chuyển sang Thêm Mặt' : 'Chuyển sang Nhận Diện'),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}