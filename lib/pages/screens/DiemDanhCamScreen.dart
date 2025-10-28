import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:mobile_erp/controller/APIRequest.dart';
import 'package:mobile_erp/utils/FaceRegistrationUtil.dart';
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
    print('=== Initializing DiemDanhCamScreen ===');
    // Không gọi _showDebugDialog trong initState vì context chưa sẵn sàng
    _initializeCamera();
    _initializeFaceDetector();
    _loadModel();
  }

  @override
  void dispose() {
    print('=== Disposing DiemDanhCamScreen ===');
    // Không gọi _showDebugDialog trong dispose
    _cameraController?.dispose();
    _faceDetector?.close();
    _interpreter?.close();
    super.dispose();
  }

  // Show debug dialog
  void _showDebugDialog(String title, String message) {
    if (!mounted) {
      print('Cannot show debug dialog: Widget not mounted');
      return;
    }
    AwesomeDialog(
      context: context,
      dialogType: DialogType.info,
      animType: AnimType.scale,
      title: 'Debug: $title',
      desc: message,
      autoHide: const Duration(seconds: 2), // Auto dismiss after 2 seconds
      btnOkOnPress: () {},
      btnOkText: 'OK',
    ).show();
  }

  // Load MobileFaceNet model
  Future<void> _loadModel() async {
    try {
      print('Loading MobileFaceNet model...');
      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      print('✓ MobileFaceNet model loaded successfully');
    } catch (e) {
      print('Error loading model: $e');
      // Không gọi _showErrorDialog trong initState context
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
      print('✓ Face detector ready');
      print('✓ Image stream started');
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
      print('=== Converting CameraImage ===');
      print('Image size: ${cameraImage.width}x${cameraImage.height}');
      print('Format raw: ${cameraImage.format.raw}');
      //_showDebugDialog('Convert Image', 'Converting CameraImage: ${cameraImage.width}x${cameraImage.height}, Format: ${cameraImage.format.raw}');
      
      final camera = _cameraController!.description;
      print('Camera lens direction: ${camera.lensDirection}');
      //_showDebugDialog('Convert Image', 'Camera lens direction: ${camera.lensDirection}');
      
      InputImageRotation rotation;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotation = InputImageRotation.rotation270deg;
      } else {
        rotation = InputImageRotation.rotation90deg;
      }

      final format = InputImageFormat.nv21;
      print('Using format: $format, Rotation: $rotation');
      //_showDebugDialog('Convert Image', 'Format: $format, Rotation: $rotation');

      final bytes = cameraImage.planes[0].bytes;
      print('Y plane bytes length: ${bytes.length}');
      //_showDebugDialog('Convert Image', 'Y plane bytes length: ${bytes.length}');

      final metadata = InputImageMetadata(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: cameraImage.planes[0].bytesPerRow,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);
      print('✓ InputImage created successfully');
      //_showDebugDialog('Convert Image', 'InputImage created successfully');
      return inputImage;
    } catch (e, stackTrace) {
      print('ERROR converting CameraImage: $e');
      print('Stack trace: $stackTrace');
      _showErrorDialog('Lỗi Convert', 'Không thể convert camera image: $e');
      return null;
    }
  }

  // Convert CameraImage to imglib.Image for MobileFaceNet
  imglib.Image _convertYUV420ToImage(CameraImage image) {
    print('=== Converting CameraImage to imglib.Image ===');
    print('Input image size: ${image.width}x${image.height}');
    print('Number of planes: ${image.planes.length}');
    print('Format: ${image.format.group}');
    
    final int width = image.width;
    final int height = image.height;
    
    // Create image with correct constructor
    var img = imglib.Image(width: width, height: height);
    print('Created imglib.Image with size: ${width}x${height}');

    // Xử lý theo số lượng planes
    if (image.planes.length == 1) {
      // Grayscale hoặc single plane format
      print('Processing single plane image (grayscale)');
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
      // YUV420 format
      print('Processing YUV420 format');
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
      
      print('Y plane: ${image.planes[0].bytes.length} bytes');
      print('U plane: ${image.planes[1].bytes.length} bytes, stride: $uvRowStride, pixel stride: $uvPixelStride');
      print('V plane: ${image.planes[2].bytes.length} bytes');

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int yIndex = y * width + x;
          final int uvX = (x / 2).floor();
          final int uvY = (y / 2).floor();
          final int uvIndex = uvY * uvRowStride + uvX * uvPixelStride;

          // Kiểm tra bounds trước khi truy cập
          if (yIndex >= image.planes[0].bytes.length) {
            continue;
          }
          if (uvIndex >= image.planes[1].bytes.length || uvIndex >= image.planes[2].bytes.length) {
            continue;
          }

          final yp = image.planes[0].bytes[yIndex];
          final up = image.planes[1].bytes[uvIndex];
          final vp = image.planes[2].bytes[uvIndex];

          // YUV to RGB conversion
          final int Y = yp;
          final int U = up - 128;
          final int V = vp - 128;
          int r = (Y + 1.402 * V).round().clamp(0, 255);
          int g = (Y - 0.34414 * U - 0.71414 * V).round().clamp(0, 255);
          int b = (Y + 1.772 * U).round().clamp(0, 255);
          img.setPixelRgba(x, y, r, g, b, 255);

         
        }
      }
    } else {
      print('ERROR: Unsupported number of planes: ${image.planes.length}');
      throw Exception('Unsupported image format: ${image.planes.length} planes');
    }
    
    print('✓ Converted CameraImage to imglib.Image successfully');
    return img;
  }

  // Crop face from CameraImage
  Future<imglib.Image?> _cropFace(CameraImage image, Face face) async {
    try {
      print('=== Cropping face ===');
      print('Input image size: ${image.width}x${image.height}');

      //_showDebugDialog('Crop Face', 'Cropping face, image size: ${image.width}x${image.height}');
      final srcImg = _convertYUV420ToImage(image);
      final box = face.boundingBox;
      int x = box.left.toInt();
      int y = box.top.toInt();
      int w = box.width.toInt();
      int h = box.height.toInt();

      print('Original bounding box: x=$x, y=$y, w=$w, h=$h');
      //_showDebugDialog('Crop Face', 'Original bounding box: x=$x, y=$y, w=$w, h=$h');

      // Add some padding to the face box
      final padding = 0.2; // 20% padding
      x = (x - w * padding).toInt();
      y = (y - h * padding).toInt();
      w = (w * (1 + 2 * padding)).toInt();
      h = (h * (1 + 2 * padding)).toInt();

      print('Padded bounding box: x=$x, y=$y, w=$w, h=$h');
      //_showDebugDialog('Crop Face', 'Padded bounding box: x=$x, y=$y, w=$w, h=$h');

      // Ensure coordinates are within image bounds
      x = x.clamp(0, image.width - 1);
      y = y.clamp(0, image.height - 1);
      w = w.clamp(1, image.width - x);
      h = h.clamp(1, image.height - y);

      print('Clamped bounding box: x=$x, y=$y, w=$w, h=$h');
      //_showDebugDialog('Crop Face', 'Clamped bounding box: x=$x, y=$y, w=$w, h=$h');

      if (w <= 0 || h <= 0) {
        print('Invalid crop dimensions: w=$w, h=$h');
        _showErrorDialog('Lỗi', 'Kích thước khuôn mặt không hợp lệ: $w x $h');
        return null;
      }

      // Use copyCrop to crop the image
      print('Cropping image with copyCrop...');
      //_showDebugDialog('Crop Face', 'Cropping image with copyCrop...');
      final cropped = imglib.copyCrop(srcImg, x: x, y: y, width: w, height: h);
      print('✓ Cropped image successfully, size: ${cropped.width}x${cropped.height}');
      //_showDebugDialog('Crop Face', 'Cropped image successfully, size: ${cropped.width}x${cropped.height}');
      return cropped;
    } catch (e, stackTrace) {
      print('Error cropping face: $e');
      print('Stack trace: $stackTrace');
      _showErrorDialog('Lỗi', 'Không thể cắt ảnh khuôn mặt: $e');
      return null;
    }
  }

  // Extract face embedding using MobileFaceNet (192D)
  Future<List<double>?> _extractFaceEmbedding(CameraImage cameraImage, Face face) async {
    try {
      print('=== Extracting face embedding ===');
      //_showDebugDialog('Embedding', 'Extracting face embedding...');
      if (_interpreter == null) {
        print('Model not loaded');
        _showErrorDialog('Lỗi', 'Model chưa được tải');
        return null;
      }

      // Crop face
      print('Cropping face...');
      //_showDebugDialog('Embedding', 'Cropping face...');
      final croppedImage = await _cropFace(cameraImage, face);
      if (croppedImage == null) {
        print('Failed to crop face');
        _showErrorDialog('Lỗi', 'Không thể cắt khuôn mặt');
        return null;
      }
      print('Cropped image size: ${croppedImage.width}x${croppedImage.height}');
      //_showDebugDialog('Embedding', 'Cropped image size: ${croppedImage.width}x${croppedImage.height}');

      // Resize to 112x112 (MobileFaceNet input)
      print('Resizing image to 112x112...');
      //_showDebugDialog('Embedding', 'Resizing image to 112x112...');
      final resizedImage = imglib.copyResize(croppedImage, width: 112, height: 112);
      print('✓ Resized image successfully, size: ${resizedImage.width}x${resizedImage.height}');
      //_showDebugDialog('Embedding', 'Resized image successfully, size: ${resizedImage.width}x${resizedImage.height}');

      // Normalize pixel values to [-1, 1]
      print('Normalizing pixel values...');
      //_showDebugDialog('Embedding', 'Normalizing pixel values...');
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
      print('✓ Normalized input shape: [1, 112, 112, 3]');
      //_showDebugDialog('Embedding', 'Normalized input shape: [1, 112, 112, 3]');

      // Run MobileFaceNet
      print('Running MobileFaceNet inference...');
      
      // Kiểm tra output shape của model
      print('=== MODEL INFO ===');
      print('Model output shape: ${_interpreter!.getOutputTensor(0).shape}');
      print('Model output type: ${_interpreter!.getOutputTensor(0).type}');
      
      // Model trả về 192 chiều
      var output = List.generate(1, (index) => List.filled(192, 0.0));
      _interpreter!.run(input, output);
      
      print('=== EMBEDDING INFO ===');
      print('✓ Inference completed successfully');
      print('Số chiều embedding: ${output[0].length}D');
      print('Sample embedding values: ${output[0].sublist(0, math.min(5, output[0].length))}...');
      print('==================');

      return output[0];
    } catch (e) {
      print('Error extracting embedding: $e');
      _showErrorDialog('Lỗi', 'Không thể trích xuất đặc trưng khuôn mặt: $e');
      return null;
    }
  }

  // Xử lý face recognition và điểm danh
  Future<void> _processFaceRecognition(CameraImage cameraImage, Face face) async {
    if (_isProcessing) {
      print('Processing already in progress, skipping...');
      return;
    }
    
    print('=== Starting face recognition ===');
    //_showDebugDialog('Face Recognition', 'Starting face recognition...');
    _isProcessing = true;
    _lastDetectionTime = DateTime.now();
    print('Last detection time: $_lastDetectionTime');
    //_showDebugDialog('Face Recognition', 'Last detection time: $_lastDetectionTime');

    try {
      // Extract face embedding
      print('Extracting face embedding...');
      //_showDebugDialog('Face Recognition', 'Extracting face embedding...');
      final embedding = await _extractFaceEmbedding(cameraImage, face);
      
      if (embedding == null) {
        print('Failed to extract embedding');
        _showErrorDialog('Lỗi', 'Không thể trích xuất đặc trưng khuôn mặt');
        setState(() {
          _statusMessage = 'Không thể trích xuất đặc trưng khuôn mặt';
          _statusColor = Colors.red;
        });
        _isProcessing = false;
        return;
      }
      print('✓ Face embedding extracted successfully');
      //_showDebugDialog('Face Recognition', 'Face embedding extracted successfully');

      // Gọi API để check và điểm danh
      print('Calling API for attendance check...');
      //_showDebugDialog('Face Recognition', 'Calling API for attendance check...');
      setState(() {
        _statusMessage = 'Đang kiểm tra với database...';
        _statusColor = Colors.blue;
      });

      final result = await _checkAttendanceWithAPI(embedding);
      print('API response: $result');
      //_showDebugDialog('Face Recognition', 'API response: ${result['tk_status']}');

      if (result['tk_status'] == 'OK') {
        print('Attendance successful: ${result['message']}');
        //_showDebugDialog('Face Recognition', 'Attendance successful: ${result['message']}');
        setState(() {
          _statusMessage = 'Điểm danh thành công! ${result['data']['EMPL_NO'] ?? ''}';
          _statusColor = Colors.green;
        });
        
        // Hiển thị dialog thành công
        //_showSuccessDialog(result);
      } else {
        print('Recognition failed: ${result['message']}');
        //_showDebugDialog('Face Recognition', 'Recognition failed: ${result['message']}');
        setState(() {
          _statusMessage = 'Không nhận diện được: ${result['message'] ?? 'Không tìm thấy trong database'}';
          _statusColor = Colors.red;
        });
      }
    } catch (e) {
      print('Error processing face recognition: $e');
      _showErrorDialog('Lỗi', 'Lỗi xử lý: $e');
      setState(() {
        _statusMessage = 'Lỗi xử lý: $e';
        _statusColor = Colors.red;
      });
    }

    // Reset sau 3 giây
    print('Scheduling reset after 3 seconds...');
    //_showDebugDialog('Face Recognition', 'Scheduling reset after 3 seconds...');
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _statusMessage = ('Đưa khuôn mặt request to API...');
          _statusColor = Colors.green;
        });
      }
      _isProcessing = false;
      print('✓ Reset completed, ready for next detection');
      //_showDebugDialog('Face Recognition', 'Reset completed, ready for next detection');
    });
  }

  // Gọi API để check và điểm danh
  Future<Map<String, dynamic>> _checkAttendanceWithAPI(List<double> embedding) async {
    try {
      print('Sending API request for face recognition...');
      //_showDebugDialog('API', 'Sending API request for face recognition...');
      embedding = FaceRegistrationUtil.normalizeEmbedding(embedding);

      final response = await API_Request.api_query('recognizeface', {
        'FACE_ID': embedding,
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('API response received: ${response['tk_status']}');
      //_showDebugDialog('API', 'API response received: ${response['tk_status']}');
      return response;
    } catch (e) {
      print('Error connecting to API: $e');
      _showErrorDialog('Lỗi', 'Lỗi kết nối API: $e');
      return {
        'tk_status': 'NG',
        'message': 'Lỗi kết nối API: $e',
      };
    }
  }

  // Hiển thị dialog thành công
  void _showSuccessDialog(Map<String, dynamic> result) {
    print('Showing success dialog...');
    print('Dialog content: Employee=${result['employee_name']}, Code=${result['employee_code']}, Time=${result['data']['EMPL_NO']}');
    _showDebugDialog('Success Dialog', 'Employee: ${result['data']['EMPL_NO'] ?? 'N/A'}, Code: ${result['data']['EMPL_NO'] ?? 'N/A'}}');
    AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      animType: AnimType.rightSlide,
      title: 'Điểm danh thành công',
      desc: 'Nhân viên: ${result['data']['EMPL_NO'] ?? 'N/A'}\n'
          'Mã NV: ${result['data']['EMPL_NO'] ?? 'N/A'}\n'
          'Thời gian: ${result['data']['EMPL_NO'] ?? DateTime.now().toString()}',
      btnOkOnPress: () {},
    ).show();
  }

  // Xử lý camera image stream
  Future<void> _processCameraImage(CameraImage cameraImage) async {
    if (_isDetecting || _isProcessing) {
      print('Skipping image processing: Detecting=$_isDetecting, Processing=$_isProcessing');
      //_showDebugDialog('Process Image', 'Skipping: Detecting=$_isDetecting, Processing=$_isProcessing');
      return;
    }
    
    if (_lastDetectionTime != null) {
      final timeSinceLastDetection = DateTime.now().difference(_lastDetectionTime!);
      if (timeSinceLastDetection.inSeconds < _detectionCooldownSeconds) {
        print('Cooldown active: ${timeSinceLastDetection.inSeconds}s since last detection');
        //_showDebugDialog('Process Image', 'Cooldown active: ${timeSinceLastDetection.inSeconds}s');
        return;
      }
    }

    _isDetecting = true;
    print('=== Processing camera image ===');
    //_showDebugDialog('Process Image', 'Processing camera image...');

    try {
      print('Converting camera image to InputImage...');
      //_showDebugDialog('Process Image', 'Converting camera image to InputImage...');
      final inputImage = _convertCameraImage(cameraImage);
      if (inputImage == null) {
        print('Failed to convert camera image');
        _showErrorDialog('Lỗi Camera', 'Không thể convert camera image');
        _isDetecting = false;
        return;
      }

      print('Detecting faces...');
      //_showDebugDialog('Process Image', 'Detecting faces...');
      final faces = await _faceDetector!.processImage(inputImage);
      print('Detected ${faces.length} faces');
      //_showDebugDialog('Process Image', 'Detected ${faces.length} faces');

      if (faces.isNotEmpty && !_isProcessing) {
        setState(() {
          _faces = faces;
          _statusMessage = '✓ Phát hiện ${faces.length} khuôn mặt. Đang xử lý...';
          _statusColor = Colors.orange;
        });
        print('Processing first detected face...');
        //_showDebugDialog('Process Image', 'Processing first detected face...');
        await _processFaceRecognition(cameraImage, faces.first);
      } else if (faces.isNotEmpty) {
        setState(() {
          _faces = faces;
        });
        print('Faces detected but processing skipped due to _isProcessing=true');
        //_showDebugDialog('Process Image', 'Faces detected but processing skipped');
      } else {
        setState(() {
          _faces = faces;
          if (faces.isEmpty && !_isProcessing) {
            _statusMessage = 'Đưa khuôn mặt vào khung hình để điểm danh';
            _statusColor = Colors.green;
          }
        });
        print('No faces detected');
        //_showDebugDialog('Process Image', 'No faces detected');
      }
    } catch (e, stackTrace) {
      print('Error processing image: $e');
      print('Stack trace: $stackTrace');
      _showErrorDialog('Lỗi Face Detection', 'Chi tiết: $e');
    }

    _isDetecting = false;
    print('✓ Image processing completed');
    //_showDebugDialog('Process Image', 'Image processing completed');
  }

  // Show error dialog
  void _showErrorDialog(String title, String message) {
    if (!mounted) {
      print('Cannot show error dialog: Widget not mounted');
      return;
    }
    print('Showing error dialog: $title - $message');
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
    print('Building UI, camera initialized: $_isCameraInitialized');
    //_showDebugDialog('UI Build', 'Building UI, camera initialized: $_isCameraInitialized');
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
    print('=== Painting faces ===');
    print('Number of faces to paint: ${faces.length}');
    if (faces.isNotEmpty) {
      // Use a simple context check to show dialog (context not directly available in CustomPainter)
      print('Showing debug dialog for face painting');
      // Note: CustomPainter cannot directly show dialogs, so we log instead
      // If needed, move dialog to widget's build method or another stateful context
    }
    for (final face in faces) {
      final scaleX = size.width / imageSize.width;
      final scaleY = size.height / imageSize.height;

      print('Painting face with bounding box: ${face.boundingBox}');
      print('Scaled factors: x=$scaleX, y=$scaleY');

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

      print('Painting landmarks...');
      for (var landmark in face.landmarks.values) {
        if (landmark != null) {
          print('Landmark position: (${landmark.position.x}, ${landmark.position.y})');
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
    print('✓ Painting completed');
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.faces != faces;
  }
}