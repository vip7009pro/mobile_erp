// ============================================
// CÁCH SỬ DỤNG FaceRegistrationUtil
// ============================================

import 'dart:typed_data';
import 'package:mobile_erp/utils/FaceRegistrationUtil.dart';
import 'package:flutter/material.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

// ============================================
// 1. ĐĂNG KÝ KHUÔN MẶT TỪ URL ẢNH
// ============================================
void exampleRegisterFromUrl(BuildContext context) async {
  final result = await FaceRegistrationUtil.registerFaceFromUrl(
    emplNo: 'NV001',
    imageUrl: 'https://example.com/path/to/face-image.jpg',
  );

  if (result['success']) {
    // Thành công
    AwesomeDialog(
      context: context,
      dialogType: DialogType.success,
      title: 'Thành công',
      desc: result['message'],
      btnOkOnPress: () {},
    ).show();
  } else {
    // Thất bại
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      title: 'Lỗi',
      desc: result['message'],
      btnOkOnPress: () {},
    ).show();
  }
}

// ============================================
// 2. ĐĂNG KÝ KHUÔN MẶT TỪ FILE BYTES
// ============================================
void exampleRegisterFromBytes(BuildContext context, Uint8List imageBytes) async {
  final result = await FaceRegistrationUtil.registerFaceFromBytes(
    emplNo: 'NV002',
    imageBytes: imageBytes,
  );

  if (result['success']) {
    print('Đăng ký thành công: ${result['message']}');
  } else {
    print('Đăng ký thất bại: ${result['message']}');
  }
}

// ============================================
// 3. ĐĂNG KÝ NHIỀU NHÂN VIÊN TỪ DANH SÁCH
// ============================================
void exampleBatchRegister(BuildContext context) async {
  final employees = [
    {'emplNo': 'NV001', 'imageUrl': 'https://example.com/nv001.jpg'},
    {'emplNo': 'NV002', 'imageUrl': 'https://example.com/nv002.jpg'},
    {'emplNo': 'NV003', 'imageUrl': 'https://example.com/nv003.jpg'},
  ];

  int successCount = 0;
  int failCount = 0;

  for (var employee in employees) {
    print('Processing ${employee['emplNo']}...');
    
    final result = await FaceRegistrationUtil.registerFaceFromUrl(
      emplNo: employee['emplNo']!,
      imageUrl: employee['imageUrl']!,
    );

    if (result['success']) {
      successCount++;
      print('✓ ${employee['emplNo']}: Success');
    } else {
      failCount++;
      print('✗ ${employee['emplNo']}: ${result['message']}');
    }
  }

  print('=== BATCH REGISTRATION COMPLETE ===');
  print('Success: $successCount');
  print('Failed: $failCount');
}

// ============================================
// 4. SỬ DỤNG TRONG WIDGET
// ============================================
class FaceRegistrationExample extends StatefulWidget {
  const FaceRegistrationExample({Key? key}) : super(key: key);

  @override
  State<FaceRegistrationExample> createState() => _FaceRegistrationExampleState();
}

class _FaceRegistrationExampleState extends State<FaceRegistrationExample> {
  bool _isLoading = false;
  String _statusMessage = '';

  Future<void> _registerFace() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang xử lý...';
    });

    final result = await FaceRegistrationUtil.registerFaceFromUrl(
      emplNo: 'NV001',
      imageUrl: 'https://example.com/face.jpg',
    );

    setState(() {
      _isLoading = false;
      _statusMessage = result['message'];
    });

    if (result['success']) {
      // Hiển thị dialog thành công
      if (mounted) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          title: 'Thành công',
          desc: result['message'],
          btnOkOnPress: () {},
        ).show();
      }
    } else {
      // Hiển thị dialog lỗi
      if (mounted) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'Lỗi',
          desc: result['message'],
          btnOkOnPress: () {},
        ).show();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Registration Example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _registerFace,
                child: const Text('Đăng ký khuôn mặt'),
              ),
            const SizedBox(height: 20),
            Text(_statusMessage),
          ],
        ),
      ),
    );
  }
}

// ============================================
// 5. SỬ DỤNG VỚI IMAGE PICKER
// ============================================
/*
import 'package:image_picker/image_picker.dart';
import 'dart:io';

Future<void> exampleWithImagePicker(BuildContext context) async {
  final ImagePicker picker = ImagePicker();
  
  // Chọn ảnh từ gallery
  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
  
  if (image != null) {
    // Đọc bytes từ file
    final bytes = await File(image.path).readAsBytes();
    
    // Đăng ký khuôn mặt
    final result = await FaceRegistrationUtil.registerFaceFromBytes(
      emplNo: 'NV001',
      imageBytes: bytes,
    );
    
    if (result['success']) {
      print('Đăng ký thành công!');
    } else {
      print('Đăng ký thất bại: ${result['message']}');
    }
  }
}
*/

// ============================================
// 6. CLEAN UP KHI KHÔNG DÙNG NỮA
// ============================================
void exampleDispose() {
  // Gọi khi app dispose hoặc không cần dùng model nữa
  FaceRegistrationUtil.dispose();
}
