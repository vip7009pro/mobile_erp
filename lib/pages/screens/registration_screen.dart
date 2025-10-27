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

class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
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
  TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
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

  Future<void> _registerFace() async {
    if (_nameController.text.isEmpty || _cameraController == null || !_isFaceDetected) {
      print('Register button disabled: name empty or no face detected');
      return;
    }
    setState(() => _isLoading = true);

    try {
      final image = await _cameraController!.takePicture();
      final cropped = await _detectAndCropFace(image);
      if (cropped == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No face detected')));
        setState(() => _isLoading = false);
        return;
      }

      final embedding = await _getEmbedding(cropped);
      if (embedding == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Embedding failed')));
        setState(() => _isLoading = false);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      List<String> embeddingsJson = prefs.getStringList('face_embeddings') ?? [];
      embeddingsJson.add(jsonEncode({'name': _nameController.text, 'embedding': embedding}));
      await prefs.setStringList('face_embeddings', embeddingsJson);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registered successfully')));
      setState(() => _isLoading = false);
    } catch (e) {
      print('Error registering face: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error registering face')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register Face')),
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
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: 'Enter your name'),
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
                  onPressed: _isFaceDetected && _nameController.text.isNotEmpty ? _registerFace : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFaceDetected && _nameController.text.isNotEmpty ? Colors.green : Colors.grey,
                  ),
                  child: Text('Register'),
                ),
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