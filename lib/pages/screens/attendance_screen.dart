import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imglib;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;

class AttendanceScreen extends StatefulWidget {
  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  CameraController? _cameraController;
  late List<CameraDescription> _cameras;
  tfl.Interpreter? _interpreter;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: true, // Bật landmarks để tăng độ chính xác
      enableClassification: true, // Bật classification để kiểm tra face presence
      performanceMode: FaceDetectorMode.accurate,
    ),
  );
  bool _isLoading = false;
  String _result = '';
  List<Face> _faces = [];
  bool _isFaceDetected = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _loadModel();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      _cameraController = CameraController(_cameras[1], ResolutionPreset.high); // Front camera
      await _cameraController!.initialize();
      if (!mounted) return;
      _cameraController!.startImageStream(_processCameraImage);
      setState(() {});
      print('Camera initialized successfully');
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await tfl.Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      print('Model loaded successfully');
    } catch (e) {
      print('Error loading model: $e');
    }
  }

  void _processCameraImage(CameraImage image) async {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final camera = _cameras[1];
      final imageRotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation) ?? InputImageRotation.rotation0deg;
      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      final faces = await _faceDetector.processImage(inputImage);
      print('Faces detected: ${faces.length}'); // Debug log
      setState(() {
        _faces = faces;
        _isFaceDetected = faces.isNotEmpty;
      });
    } catch (e) {
      print('Error processing camera image: $e');
    }
  }

  Future<List<double>?> _getEmbedding(imglib.Image image) async {
    if (_interpreter == null) {
      print('Interpreter is null');
      return null;
    }
    var input = _preprocessImage(image);
    var output = List.filled(1 * 512, 0.0).reshape([1, 512]);
    _interpreter!.run(input, output);
    return output[0].cast<double>();
  }

  dynamic _preprocessImage(imglib.Image image) {
    image = imglib.copyResize(image, width: 112, height: 112);
    var input = Float32List(1 * 112 * 112 * 3);
    int i = 0;
    for (int y = 0; y < 112; y++) {
      for (int x = 0; x < 112; x++) {
        var pixel = image.getPixel(x, y) as int;
        int r = (pixel >> 16) & 0xFF;
        int g = (pixel >> 8) & 0xFF;
        int b = pixel & 0xFF;
        input[i++] = (r - 127.5) / 127.5;
        input[i++] = (g - 127.5) / 127.5;
        input[i++] = (b - 127.5) / 127.5;
      }
    }
    return input.reshape([1, 112, 112, 3]);
  }

  Future<imglib.Image?> _detectAndCropFace(XFile imageFile) async {
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final faces = await _faceDetector.processImage(inputImage);
      if (faces.isEmpty) {
        print('No face detected in captured image');
        return null;
      }

      final face = faces.first;
      final bytes = await File(imageFile.path).readAsBytes();
      final img = imglib.decodeImage(bytes)!;

      int x = face.boundingBox.left.toInt();
      int y = face.boundingBox.top.toInt();
      int w = face.boundingBox.width.toInt();
      int h = face.boundingBox.height.toInt();

      return imglib.copyCrop(img, x: x, y: y, width: w, height: h);
    } catch (e) {
      print('Error detecting and cropping face: $e');
      return null;
    }
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0.0, magA = 0.0, magB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      magA += a[i] * a[i];
      magB += b[i] * b[i];
    }
    return dot / (sqrt(magA) * sqrt(magB));
  }

  Future<void> _markAttendance() async {
    if (_cameraController == null || !_isFaceDetected) {
      print('Attendance button disabled: no face detected');
      return;
    }
    setState(() => _isLoading = true);

    try {
      final image = await _cameraController!.takePicture();
      final cropped = await _detectAndCropFace(image);
      if (cropped == null) {
        setState(() {
          _result = 'No face detected';
          _isLoading = false;
        });
        return;
      }

      final newEmbedding = await _getEmbedding(cropped);
      if (newEmbedding == null) {
        setState(() {
          _result = 'Embedding failed';
          _isLoading = false;
        });
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      List<String> embeddingsJson = prefs.getStringList('face_embeddings') ?? [];
      String name = 'Unknown';
      double maxSim = 0.0;

      for (var jsonStr in embeddingsJson) {
        var data = jsonDecode(jsonStr);
        List<double> storedEmbedding = List<double>.from(data['embedding']);
        double sim = _cosineSimilarity(newEmbedding, storedEmbedding);
        if (sim > maxSim && sim > 0.8) {
          maxSim = sim;
          name = data['name'];
        }
      }

      setState(() {
        _result = name != 'Unknown' ? 'Attendance marked for $name' : 'No match found';
        _isLoading = false;
      });
    } catch (e) {
      print('Error marking attendance: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error marking attendance')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Attendance')),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          if (_cameraController != null && _cameraController!.value.isInitialized)
            Stack(
              children: [
                CameraPreview(_cameraController!),
                CustomPaint(
                  painter: FacePainter(_faces, _cameraController!.description, MediaQuery.of(context).size),
                ),
              ],
            ),
          SizedBox(height: 16),
          Text(
            _isFaceDetected ? 'Face detected! Ready to proceed.' : 'No face detected. Please align your face.',
            style: TextStyle(color: _isFaceDetected ? Colors.green : Colors.red),
          ),
          SizedBox(height: 16),
          _isLoading
              ? CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: _isFaceDetected ? _markAttendance : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFaceDetected ? Colors.green : Colors.grey,
                  ),
                  child: Text('Scan Face'),
                ),
          SizedBox(height: 16),
          Text(_result),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _interpreter?.close();
    _faceDetector.close();
    super.dispose();
  }
}

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final CameraDescription camera;
  final Size screenSize;

  FacePainter(this.faces, this.camera, this.screenSize);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.green;

    for (var face in faces) {
      final left = face.boundingBox.left * size.width / screenSize.width;
      final top = face.boundingBox.top * size.height / screenSize.height;
      final right = face.boundingBox.right * size.width / screenSize.width;
      final bottom = face.boundingBox.bottom * size.height / screenSize.height;

      canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) => true;
}