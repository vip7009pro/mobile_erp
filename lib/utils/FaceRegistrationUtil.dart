import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as imglib;
import 'package:http/http.dart' as http;
import 'package:mobile_erp/controller/APIRequest.dart';
import 'dart:math' as math;

class FaceRegistrationUtil {
  static Interpreter? _interpreter;

  // Load MobileFaceNet model
  static Future<void> loadModel() async {
    if (_interpreter != null) return; // Đã load rồi
    
    try {
      print('Loading MobileFaceNet model...');
      _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
      print('✓ MobileFaceNet model loaded successfully');
    } catch (e) {
      print('Error loading model: $e');
      throw Exception('Không thể tải model: $e');
    }
  }

  // Tải ảnh từ URL
  static Future<imglib.Image?> loadImageFromUrl(String imageUrl) async {
    try {
      print('Loading image from URL: $imageUrl');
      final response = await http.get(Uri.parse(imageUrl));
      
      if (response.statusCode != 200) {
        print('Failed to load image: ${response.statusCode}');
        return null;
      }

      final bytes = response.bodyBytes;
      print('Image loaded: ${bytes.length} bytes');

      // Decode image
      final image = imglib.decodeImage(bytes);
      if (image == null) {
        print('Failed to decode image');
        return null;
      }

      print('✓ Image decoded: ${image.width}x${image.height}');
      return image;
    } catch (e) {
      print('Error loading image from URL: $e');
      return null;
    }
  }

  // Extract face embedding từ ảnh
  static Future<List<double>?> extractEmbeddingFromImage(imglib.Image image) async {
    try {
      // Đảm bảo model đã load
      await loadModel();
      if (_interpreter == null) {
        throw Exception('Model chưa được load');
      }

      print('=== Extracting face embedding from image ===');
      print('Input image size: ${image.width}x${image.height}');

      // Resize to 112x112 (MobileFaceNet input)
      print('Resizing image to 112x112...');
      final resizedImage = imglib.copyResize(image, width: 112, height: 112);
      print('✓ Resized image successfully');

      // Normalize pixel values to [-1, 1]
      print('Normalizing pixel values...');
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
      print('✓ Normalized input shape: [1, 112, 112, 3]');

      // Run MobileFaceNet
      print('Running MobileFaceNet inference...');
      
      // Kiểm tra output shape của model
      print('Model output shape: ${_interpreter!.getOutputTensor(0).shape}');
      
      var output = List.generate(1, (index) => List.filled(192, 0.0));
      _interpreter!.run(input, output);
      
      print('✓ Inference completed successfully');
      print('Embedding dimension: ${output[0].length}D');
      print('Sample values: ${output[0].sublist(0, math.min(5, output[0].length))}...');

      return output[0];
    } catch (e) {
      print('Error extracting embedding: $e');
      return null;
    }
  }

  // Đăng ký khuôn mặt từ URL ảnh
  static Future<Map<String, dynamic>> registerFaceFromUrl({
    required String emplNo,
    required String imageUrl,
  }) async {
    try {
      print('=== Starting face registration from URL ===');
      print('EMPL_NO: $emplNo');
      print('Image URL: $imageUrl');

      // 1. Tải ảnh từ URL
      final image = await loadImageFromUrl(imageUrl);
      if (image == null) {
        return {
          'success': false,
          'message': 'Không thể tải ảnh từ URL',
        };
      }

      // 2. Extract embedding
      final embedding = await extractEmbeddingFromImage(image);
      if (embedding == null) {
        return {
          'success': false,
          'message': 'Không thể trích xuất đặc trưng khuôn mặt',
        };
      }

      // 3. Gọi API để lưu FACE_ID - GỬI TRỰC TIẾP List<double>
      print('Calling API to save FACE_ID...');
      print('Embedding length: ${embedding.length}D');
      print('Embedding sample: ${embedding.sublist(0, math.min(5, embedding.length))}...');
      
      final response = await API_Request.api_query('updatefaceid', {
        'EMPL_NO': emplNo,
        'FACE_ID': embedding, // Gửi List<double> trực tiếp
      });

      print('API response: $response');

      if (response['tk_status'] == 'OK') {
        print('✓ Face registration successful');
        return {
          'success': true,
          'message': 'Đăng ký khuôn mặt thành công',
          'data': response,
        };
      } else {
        print('✗ Face registration failed: ${response['message']}');
        return {
          'success': false,
          'message': response['message'] ?? 'Đăng ký thất bại',
          'data': response,
        };
      }
    } catch (e) {
      print('Error in registerFaceFromUrl: $e');
      return {
        'success': false,
        'message': 'Lỗi: $e',
      };
    }
  }

  // Đăng ký khuôn mặt từ file bytes
  static Future<Map<String, dynamic>> registerFaceFromBytes({
    required String emplNo,
    required Uint8List imageBytes,
  }) async {
    try {
      print('=== Starting face registration from bytes ===');
      print('EMPL_NO: $emplNo');
      print('Image bytes length: ${imageBytes.length}');

      // 1. Decode image từ bytes
      final image = imglib.decodeImage(imageBytes);
      if (image == null) {
        return {
          'success': false,
          'message': 'Không thể decode ảnh',
        };
      }

      print('Image decoded: ${image.width}x${image.height}');

      // 2. Extract embedding
      final embedding = await extractEmbeddingFromImage(image);
      if (embedding == null) {
        return {
          'success': false,
          'message': 'Không thể trích xuất đặc trưng khuôn mặt',
        };
      }

      // 3. Gọi API để lưu FACE_ID - GỬI TRỰC TIẾP List<double>
      final response = await API_Request.api_query('updatefaceid', {
        'EMPL_NO': emplNo,
        'FACE_ID': embedding, // Gửi List<double> trực tiếp
      });

      if (response['tk_status'] == 'OK') {
        return {
          'success': true,
          'message': 'Đăng ký khuôn mặt thành công',
          'data': response,
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Đăng ký thất bại',
          'data': response,
        };
      }
    } catch (e) {
      print('Error in registerFaceFromBytes: $e');
      return {
        'success': false,
        'message': 'Lỗi: $e',
      };
    }
  }

  // Đăng ký khuôn mặt từ imglib.Image trực tiếp
  static Future<Map<String, dynamic>> registerFaceFromImage({
    required String emplNo,
    required imglib.Image image,
  }) async {
    try {
      print('=== Starting face registration from Image ===');
      print('EMPL_NO: $emplNo');
      print('Image size: ${image.width}x${image.height}');

      // 1. Extract embedding
      final embedding = await extractEmbeddingFromImage(image);
      if (embedding == null) {
        return {
          'success': false,
          'message': 'Không thể trích xuất đặc trưng khuôn mặt',
        };
      }

      // 2. Gọi API để lưu FACE_ID - GỬI TRỰC TIẾP List<double>
      final response = await API_Request.api_query('updatefaceid', {
        'EMPL_NO': emplNo,
        'FACE_ID': embedding, // Gửi List<double> trực tiếp
      });

      if (response['tk_status'] == 'OK') {
        return {
          'success': true,
          'message': 'Đăng ký khuôn mặt thành công',
          'data': response,
        };
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Đăng ký thất bại',
          'data': response,
        };
      }
    } catch (e) {
      print('Error in registerFaceFromImage: $e');
      return {
        'success': false,
        'message': 'Lỗi: $e',
      };
    }
  }

  // Dispose model khi không dùng nữa
  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    print('✓ Model disposed');
  }
}
