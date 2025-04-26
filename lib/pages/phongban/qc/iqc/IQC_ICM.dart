import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_erp/controller/APIRequest.dart';
import 'package:collection/collection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class IncomingListPage extends StatefulWidget {
  const IncomingListPage({Key? key}) : super(key: key);

  @override
  State<IncomingListPage> createState() => _IncomingListPageState();
}

class _IncomingListPageState extends State<IncomingListPage> {
  List<Map<String, dynamic>> incomingList = [];
  List<Map<String, dynamic>> filteredList = [];
  bool isLoading = false;
  TextEditingController filterController = TextEditingController();
  MobileScannerController cameraController = MobileScannerController();
  bool isScannerOpen = false;

  @override
  void initState() {
    super.initState();
    _loadIncomingList();
    filterController.addListener(_filterList);
  }

  Future<void> _loadIncomingList() async {
    setState(() => isLoading = true);
    final res = await API_Request.api_query('loadIQC1table', {
      'FROM_DATE': '2020-01-01',
      'TO_DATE': '2100-01-01',
      'M_CODE': '',
      'LOTNCC': '',
      'M_NAME':'',
      'VENDOR_NAME':''
    });
    if (res['tk_status'] == 'OK' && res['data'] != null) {
      setState(() {
        incomingList = List<Map<String, dynamic>>.from(res['data']);
        filteredList = incomingList;
        isLoading = false;
      });
    } else {
      setState(() {
        incomingList = [];
        filteredList = [];
        isLoading = false;
      });
    }
  }

  void _filterList() {
    final query = filterController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => filteredList = incomingList);
    } else {
      setState(() {
        filteredList = incomingList.where((item) {
          return (item['M_NAME'] ?? '').toString().toLowerCase().contains(query) ||
                 (item['M_LOT_NO'] ?? '').toString().toLowerCase().contains(query);
        }).toList();
      });
    }
  }

  void _showScannerDialog() {
    if (isScannerOpen) return;
    setState(() { isScannerOpen = true; });
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: SizedBox(
          width: 300,
          height: 400,
          child: MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final barcode = capture.barcodes.first.rawValue;
              if (barcode != null && barcode.isNotEmpty) {
                filterController.text = barcode;
                _filterList();
                Navigator.pop(context);
                setState(() { isScannerOpen = false; });
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() { isScannerOpen = false; });
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    filterController.dispose();
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: filterController,
            decoration: InputDecoration(
              labelText: 'Lọc theo tên liệu hoặc M_LOT_NO',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _showScannerDialog,
                tooltip: 'Quét barcode',
              ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadIncomingList,
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: filteredList.length,
                    itemBuilder: (context, idx) {
                      final item = filteredList[idx];
                      return Card(
                        child: ListTile(
                          title: Text('${item['M_LOT_NO'] ?? ''} - ${item['M_NAME'] ?? ''}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Size: ${item['WIDTH_CD'] ?? ''}'),
                              Text(
                                'Tổng kết quả: ${item['TOTAL_RESULT'] ?? ''}',
                                style: TextStyle(
                                  color: item['TOTAL_RESULT'] == 'OK' ? Colors.green : Colors.red,
                                ),
                              ),
                              Text(
                                'KQ IQC: ${item['IQC_TEST_RESULT'] ?? ''}',
                                style: TextStyle(
                                  color: item['IQC_TEST_RESULT'] == 'OK' ? Colors.green : Colors.red,
                                ),
                              ),
                              Text('Roll ngoại quan: ${item['NQ_CHECK_ROLL'] ?? ''}'),
                              Text('Remark: ${item['REMARK'] ?? ''}'),
                            ],
                          ),
                          onTap: () async {
                            final updated = await Get.to(() => IncomingDetailPage(data: item));
                            if (updated == true) {
                              _loadIncomingList();
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class IncomingDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;
  const IncomingDetailPage({Key? key, required this.data}) : super(key: key);

  @override
  State<IncomingDetailPage> createState() => _IncomingDetailPageState();
}

class _IncomingDetailPageState extends State<IncomingDetailPage> {
  late TextEditingController nqCheckRollController;
  String? totalResult;
  String? iqcTestResult;
  late TextEditingController remarkController;
  bool isUpdating = false;
  File? pickedImage;

  final String serverUrl = 'http://cms.ddns.net'; // <-- sửa lại đúng domain của bạn

  @override
  void initState() {
    super.initState();
    nqCheckRollController = TextEditingController(text: widget.data['NQ_CHECK_ROLL']?.toString() ?? '');
    totalResult = widget.data['TOTAL_RESULT']?.toString() ?? 'OK';
    iqcTestResult = widget.data['IQC_TEST_RESULT']?.toString() ?? 'OK';
    remarkController = TextEditingController(text: widget.data['REMARK']?.toString() ?? '');
  }

  @override
  void dispose() {
    nqCheckRollController.dispose();
    remarkController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        pickedImage = File(picked.path);
      });
    }
  }

  Future<bool> _uploadImage(String IQC1_ID) async {    
    bool uploadResult = false;
    if (pickedImage != null) {      
      try {
        final result = await API_Request.uploadQuery(
          file: pickedImage!,
          filename: '$IQC1_ID.jpg',
          uploadfoldername: 'iqcincoming',
        );
        if (result['tk_status'] == 'OK') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image uploaded successfully')),
          );
          // Update the shopAvatarController with the new URL if provided in the result          
          uploadResult = true;          
        } else {
          uploadResult = false;
        }
      } catch (e) {        
        print('Error uploading image: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred while uploading the image')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please choose an image first')),
      );
      uploadResult = false;
    }
    return uploadResult;
  } 


  Future<void> _updateIncomingData(String IQC1_ID) async {
    setState(() => isUpdating = true);
    final res = await API_Request.api_query('updateIncomingData', {
      'M_LOT_NO': widget.data['M_LOT_NO'],
      'NQ_CHECK_ROLL': nqCheckRollController.text,
      'TOTAL_RESULT': totalResult,
      'IQC_TEST_RESULT': iqcTestResult,
      'IQC1_ID': IQC1_ID,
      'REMARK': remarkController.text,
      'CHECKSHEET': 'Y',
    });
    bool uploadSuccess = true;
    if (pickedImage != null) {
      uploadSuccess = await _uploadImage(IQC1_ID);
    }
    setState(() => isUpdating = false);
    if (res['tk_status'] == 'OK' && uploadSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật thành công!')),
      );
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cập nhật thất bại!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasChecksheet = widget.data['CHECKSHEET'] == 'Y' && pickedImage == null;
    final lotNo = widget.data['M_LOT_NO']?.toString() ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết Incoming Data')),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('M_LOT_NO: $lotNo', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('M_NAME: ${widget.data['M_NAME'] ?? ''}'),
            Text('Size: ${widget.data['WIDTH_CD'] ?? ''}'),
            const SizedBox(height: 16),
            // Ảnh checksheet hoặc nút chọn ảnh
            if (hasChecksheet)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ảnh checksheet kiểm tra đầu vào:'),
                  const SizedBox(height: 8),
                  Image.network('http://14.160.33.94/iqcincoming/${widget.data['IQC1_ID']}.jpg', height: 200, fit: BoxFit.contain),
                ],
              )
            else ...[
              pickedImage != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ảnh đã chọn:'),
                        const SizedBox(height: 8),
                        Image.file(pickedImage!, height: 200, fit: BoxFit.contain),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Chọn lại ảnh'),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Chưa có ảnh checksheet!'),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Chọn ảnh checksheet'),
                        ),
                      ],
                    ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: nqCheckRollController,
              decoration: const InputDecoration(labelText: 'NQ_CHECK_ROLL (Roll ngoại quan)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const Text('TOTAL_RESULT:'),
            Row(
              children: [
                Radio<String>(
                  value: 'OK',
                  groupValue: totalResult,
                  onChanged: (val) => setState(() => totalResult = val),
                ),
                const Text('OK'),
                Radio<String>(
                  value: 'NG',
                  groupValue: totalResult,
                  onChanged: (val) => setState(() => totalResult = val),
                ),
                const Text('NG'),
              ],
            ),
            const SizedBox(height: 8),
            const Text('IQC_TEST_RESULT:'),
            Row(
              children: [
                Radio<String>(
                  value: 'OK',
                  groupValue: iqcTestResult,
                  onChanged: (val) => setState(() => iqcTestResult = val),
                ),
                const Text('OK'),
                Radio<String>(
                  value: 'NG',
                  groupValue: iqcTestResult,
                  onChanged: (val) => setState(() => iqcTestResult = val),
                ),
                const Text('NG'),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: remarkController,
              decoration: const InputDecoration(labelText: 'Remark'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isUpdating || (widget.data['CHECKSHEET'] == 'N' && pickedImage == null)
                    ? null
                    : () => _updateIncomingData(widget.data['IQC1_ID'].toString()),
                child: isUpdating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Cập nhật'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}