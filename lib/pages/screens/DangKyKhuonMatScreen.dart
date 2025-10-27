import 'dart:async';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:mobile_erp/controller/APIRequest.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as imglib;
import 'dart:math' as math;

class DangKyKhuonMatScreen extends StatefulWidget {
  final String emplNo; // Mã nhân viên cần đăng ký

  const DangKyKhuonMatScreen({Key? key, required this.emplNo}) : super(key: key);

  @override
  State<DangKyKhuonMatScreen> createState() => _DangKyKhuonMatScreenState();
}

class _DangKyKhuonMatScreenState extends State<DangKyKhuonMatScreen> {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  Interpreter? _interpreter;
  
  bool _isDetecting = false;
  bool _isProcessing = false;
  bool _isCameraInitialized = false;
  
  List<Face> _faces = [];
  String _statusMessage = 'Đang khởi tạo camera...';
  Color _statusColor = Colors.blue;
  
  List<double>? _capturedEmbedding;
  bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    print('=== Initializing DangKyKhuonMatScreen for EMPL_NO: ${widget.emplNo} ===');
    _initializeCamera();
    _initializeFaceDetector();
    _loadModel();
  }

  @override
  void dispose() {
    print('=== Disposing DangKyKhuonMatScreen ===');
    _cameraController?.dispose();
    _faceDetector?.close();
    _interpreter?.close();
    super.dispose();
  }

  // Load MobileFaceNet model
  Future<void> _loadModel() async {
    try {
      print('Loading MobileFaceNet model...');
      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      print('✓ MobileFaceNet model loaded successfully');
    } catch (e) {
      print('Error loading model: $e');
      if (mounted) {
        Future.microtask(() => _showErrorDialog('Lỗi Model', 'Không thể tải MobileFaceNet: $e'));
      }
    }
  }

  // Khởi tạo camera
  Future<void> _initializeCamera() async {
    try {
      print('Initializing camera...');
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print('No cameras found');
        if (mounted) {
          setState(() {
            _statusMessage = 'Không tìm thấy camera';
            _statusColor = Colors.red;
          });
          Future.microtask(() => _showErrorDialog('Lỗi Camera', 'Không tìm thấy camera trên thiết bị'));
        }
        return;
      }

      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      print('Selected camera: ${frontCamera.name}, Lens: ${frontCamera.lensDirection}');

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      print('Initializing camera controller...');
      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() {
        _isCameraInitialized = true;
        _statusMessage = 'Camera đã sẵn sàng. Đưa mặt vào khung hình';
        _statusColor = Colors.green;
      });

      print('Starting image stream...');
      _cameraController!.startImageStream(_processCameraImage);
      
      print('✓ Camera initialized successfully');
    } catch (e, stackTrace) {
      print('Error initializing camera: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _statusMessage = 'Lỗi khởi tạo camera: $e';
          _statusColor = Colors.red;
        });
        Future.microtask(() => _showErrorDialog('Lỗi Khởi tạo Camera', 'Chi tiết: $e'));
      }
    }
  }

  // Khởi tạo face detector
  void _initializeFaceDetector() {
    print('Initializing face detector...');
    final options = FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.15,
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);
    print('✓ Face detector initialized');
  }

  // Convert CameraImage to InputImage
  InputImage? _convertCameraImage(CameraImage cameraImage) {
    try {
      final camera = _cameraController!.description;
      
      InputImageRotation rotation;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotation = InputImageRotation.rotation270deg;
      } else {
        rotation = InputImageRotation.rotation90deg;
      }

      final format = InputImageFormat.nv21;
      final bytes = cameraImage.planes[0].bytes;

      final metadata = InputImageMetadata(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: cameraImage.planes[0].bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
      return inputImage;
    } catch (e, stackTrace) {
      print('ERROR converting CameraImage: $e');
      print('Stack trace: $stackTrace');
      _showErrorDialog('Lỗi Convert', 'Không thể convert camera image: $e');
      return null;
    }
  }

  // Convert CameraImage to imglib.Image
  imglib.Image _convertYUV420ToImage(CameraImage image) {
    print('=== Converting CameraImage to imglib.Image ===');
    
    final int width = image.width;
    final int height = image.height;
    
    var img = imglib.Image(width: width, height: height);

    // Xử lý theo số lượng planes
    if (image.planes.length == 1) {
      // Grayscale
      final bytes = image.planes[0].bytes;
      final bytesPerRow = image.planes[0].bytesPerRow;
      
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int index = y * bytesPerRow + x;
          if (index < bytes.length) {
            final gray = bytes[index];
            img.setPixelRgba(x, y, gray, gray, gray, 255);
          }
        }
      }
    } else if (image.planes.length >= 3) {
      // YUV420
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int yIndex = y * width + x;
          final int uvX = (x / 2).floor();
          final int uvY = (y / 2).floor();
          final int uvIndex = uvY * uvRowStride + uvX * uvPixelStride;

          if (yIndex >= image.planes[0].bytes.length) continue;
          if (uvIndex >= image.planes[1].bytes.length || uvIndex >= image.planes[2].bytes.length) continue;

          final yp = image.planes[0].bytes[yIndex];
          final up = image.planes[1].bytes[uvIndex];
          final vp = image.planes[2].bytes[uvIndex];

          int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
          int g = (yp - up * 465 / 1024 - vp * 813 / 1024 + 135).round().clamp(0, 255);
          int b = (yp + up * 1814 / 1024 - 44).round().clamp(0, 255);

          img.setPixelRgba(x, y, r, g, b, 255);
        }
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

      // Add padding
      final padding = 0.2;
      x = (x - w * padding).toInt();
      y = (y - h * padding).toInt();
      w = (w * (1 + 2 * padding)).toInt();
      h = (h * (1 + 2 * padding)).toInt();

      // Clamp to bounds
      x = x.clamp(0, image.width - 1);
      y = y.clamp(0, image.height - 1);
      w = w.clamp(1, image.width - x);
      h = h.clamp(1, image.height - y);

      if (w <= 0 || h <= 0) return null;

      final cropped = imglib.copyCrop(srcImg, x: x, y: y, width: w, height: h);
      return cropped;
    } catch (e) {
      print('Error cropping face: $e');
      return null;
    }
  }

  // Extract face embedding
  Future<List<double>?> _extractFaceEmbedding(CameraImage cameraImage, Face face) async {
    try {
      if (_interpreter == null) return null;

      final croppedImage = await _cropFace(cameraImage, face);
      if (croppedImage == null) return null;

      final resizedImage = imglib.copyResize(croppedImage, width: 112, height: 112);

      var input = List.generate(
        1,
        (index) => List.generate(
          112,
          (y) => List.generate(
            112,
            (x) {
              final pixel = resizedImage.getPixel(x, y);
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

      var output = List.generate(1, (index) => List.filled(192, 0.0));
      _interpreter!.run(input, output);

      print('✓ Extracted embedding: ${output[0].length}D');
      return output[0];
    } catch (e) {
      print('Error extracting embedding: $e');
      return null;
    }
  }

  // Đăng ký khuôn mặt lên server
  Future<void> _registerFaceEmbedding(List<double> embedding) async {
    try {
      setState(() {
        _statusMessage = 'Đang đăng ký khuôn mặt...';
        _statusColor = Colors.blue;
      });

      print('=== REGISTERING FACE EMBEDDING ===');
      print('Embedding length: ${embedding.length}D');
      print('Embedding sample: ${embedding.sublist(0, math.min(5, embedding.length))}...');

      // Gọi API để lưu FACE_ID - GỬI TRỰC TIẾP List<double>
      final response = await API_Request.api_query('updatefaceid', {
        'EMPL_NO': widget.emplNo,
        'FACE_ID': embedding, // Gửi List<double> trực tiếp, giống recognizeface
      });

      print('API response: $response');

      if (response['tk_status'] == 'OK') {
        setState(() {
          _isRegistered = true;
          _statusMessage = 'Đăng ký khuôn mặt thành công!';
          _statusColor = Colors.green;
        });

        _showSuccessDialog();
      } else {
        setState(() {
          _statusMessage = 'Đăng ký thất bại: ${response['message']}';
          _statusColor = Colors.red;
        });
        _showErrorDialog('Lỗi', response['message'] ?? 'Không thể đăng ký');
      }
    } catch (e) {
      print('Error registering face: $e');
      setState(() {
        _statusMessage = 'Lỗi đăng ký: $e';
        _statusColor = Colors.red;
      });
      _showErrorDialog('Lỗi', 'Không thể đăng ký khuôn mặt: $e');
    }
  }

  // Xử lý camera image stream
  Future<void> _processCameraImage(CameraImage cameraImage) async {
    if (_isDetecting || _isProcessing || _isRegistered) return;

    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(cameraImage);
      if (inputImage == null) {
        _isDetecting = false;
        return;
      }

      final faces = await _faceDetector!.processImage(inputImage);

      if (faces.isNotEmpty) {
        setState(() {
          _faces = faces;
          _statusMessage = '✓ Phát hiện khuôn mặt. Nhấn "Chụp" để đăng ký';
          _statusColor = Colors.green;
        });

        // Tự động extract embedding khi phát hiện face
        if (_capturedEmbedding == null && !_isProcessing) {
          final embedding = await _extractFaceEmbedding(cameraImage, faces.first);
          if (embedding != null) {
            setState(() {
              _capturedEmbedding = embedding;
            });
          }
        }
      } else {
        setState(() {
          _faces = faces;
          _capturedEmbedding = null;
          _statusMessage = 'Đưa khuôn mặt vào khung hình';
          _statusColor = Colors.orange;
        });
      }
    } catch (e) {
      print('Error processing image: $e');
    }

    _isDetecting = false;
  }

  // Xử lý nút chụp
  void _onCapturePressed() async {
    if (_capturedEmbedding == null) {
      _showErrorDialog('Lỗi', 'Chưa phát hiện khuôn mặt');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    await _registerFaceEmbedding(_capturedEmbedding!);

    setState(() {
      _isProcessing = false;
    });
  }

  // Show success dialog
  void _showSuccessDialog() {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      animType: AnimType.rightSlide,
      title: 'Thành công',
      desc: 'Đăng ký khuôn mặt thành công cho nhân viên ${widget.emplNo}',
      btnOkOnPress: () {
        Navigator.pop(context, true); // Trả về true khi thành công
      },
    ).show();
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
        title: Text('Đăng ký khuôn mặt - ${widget.emplNo}'),
        backgroundColor: Colors.blue,
      ),
      body: _isCameraInitialized
          ? Stack(
              fit: StackFit.expand,
              children: [
                // Camera preview
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize!.height,
                    height: _cameraController!.value.previewSize!.width,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
                
                // Status bar
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
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                
                // Face frame
                Center(
                  child: Container(
                    width: 250,
                    height: 300,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _faces.isNotEmpty ? Colors.green : Colors.red,
                        width: 5,
                      ),
                      borderRadius: BorderRadius.circular(150),
                      boxShadow: [
                        BoxShadow(
                          color: (_faces.isNotEmpty ? Colors.green : Colors.red).withOpacity(0.6),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Capture button
                if (!_isRegistered)
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ElevatedButton(
                        onPressed: _capturedEmbedding != null && !_isProcessing
                            ? _onCapturePressed
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'CHỤP & ĐĂNG KÝ',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
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
