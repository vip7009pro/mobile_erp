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
    final res = await API_Request.api_query('loadIQC1Table_Mobile', {
      'FROM_DATE': '2020-01-01',
      'TO_DATE': '2100-01-01',
      'M_CODE': '',
      'LOTNCC': '',
      'M_NAME': '',
      'VENDOR_NAME': '',
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
        filteredList =
            incomingList.where((item) {
              return (item['M_NAME'] ?? '').toString().toLowerCase().contains(
                    query,
                  ) ||
                  (item['M_LOT_NO'] ?? '').toString().toLowerCase().contains(
                    query,
                  );
            }).toList();
      });
    }
  }
  void _showScannerDialog() {
    if (isScannerOpen) return;
    setState(() {
      isScannerOpen = true;
    });
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: SizedBox(
          width: 300,
          height: 400,
          child: Stack(
            children: [
              MobileScanner(
                controller: cameraController,
                onDetect: (capture) {
                  final barcode = capture.barcodes.first.rawValue;
                  if (barcode != null && barcode.isNotEmpty) {
                    filterController.text = barcode;
                    _filterList();
                    Navigator.pop(context);
                    setState(() {
                      isScannerOpen = false;
                    });
                  }
                },
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  heroTag: 'focus_button',
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.center_focus_strong, color: Colors.blue),
                  tooltip: 'Làm nét lại (Focus)',
                  onPressed: () async {
                    try {
                      await cameraController.start(); // Gọi lại start để trigger lại focus
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Không thể focus lại: $e')),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [                
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                isScannerOpen = false;
              });
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
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                      itemCount: filteredList.length,
                      itemBuilder: (context, idx) {
                        final item = filteredList[idx];
                        return Card(
                          child: ListTile(
                            title: Text(
                              '${item['M_LOT_NO'] ?? ''} - ${item['M_NAME'] ?? ''}',
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lot Vendor: ${item['LOT_VENDOR_IQC'] ?? ''}',
                                ),
                                Text('Size: ${item['WIDTH_CD'] ?? ''}'),
                                Text(
                                  'Tổng kết quả: ${item['TOTAL_RESULT'] ?? ''}',
                                  style: TextStyle(
                                    color:
                                        item['TOTAL_RESULT'] == 'OK'
                                            ? Colors.green
                                            : item['TOTAL_RESULT'] == 'PD'
                                            ? Colors.orange
                                            : Colors.red,
                                  ),
                                ),
                                Text(
                                  'KQ IQC: ${item['IQC_TEST_RESULT'] ?? ''}',
                                  style: TextStyle(
                                    color:
                                        item['IQC_TEST_RESULT'] == 'OK'
                                            ? Colors.green
                                            : item['IQC_TEST_RESULT'] == 'PD'
                                            ? Colors.orange
                                            : Colors.red,
                                  ),
                                ),
                                Text(
                                  'DTC RESULT: ${item['DTC_RESULT'] ?? ''}',
                                  style: TextStyle(
                                    color:
                                        item['DTC_RESULT'] == 'OK'
                                            ? Colors.green
                                            : item['DTC_RESULT'] == 'PD'
                                            ? Colors.orange
                                            : Colors.red,
                                  ),
                                ),
                                Text(
                                  'Roll ngoại quan: ${item['NQ_CHECK_ROLL'] ?? ''}',
                                ),
                                Text('Remark: ${item['REMARK'] ?? ''}'),
                              ],
                            ),
                            onTap: () async {
                              final updated = await Get.to(
                                () => IncomingDetailPage(data: item),
                              );
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
  String? dtcResult;
  late TextEditingController remarkController;
  bool isUpdating = false;
  File? pickedImage;
  final String serverUrl =
      'http://cms.ddns.net'; // <-- sửa lại đúng domain của bạn
  @override
  void initState() {
    super.initState();
    nqCheckRollController = TextEditingController(
      text: widget.data['NQ_CHECK_ROLL']?.toString() ?? '',
    );
    totalResult = widget.data['TOTAL_RESULT']?.toString() ?? 'OK';
    iqcTestResult = widget.data['IQC_TEST_RESULT']?.toString() ?? 'OK';
    dtcResult = widget.data['DTC_RESULT']?.toString() ?? 'OK';
    remarkController = TextEditingController(
      text: widget.data['REMARK']?.toString() ?? '',
    );
  }
  @override
  void dispose() {
    nqCheckRollController.dispose();
    remarkController.dispose();
    super.dispose();
  }
  // Hàm chọn/chụp ảnh
  Future<void> _pickImage({required ImageSource source}) async {
    final picked = await ImagePicker().pickImage(source: source);
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
          SnackBar(
            content: Text('An error occurred while uploading the image'),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please choose an image first')));
      uploadResult = false;
    }
    return uploadResult;
  }
  //Future get next ID
  Future<num> _getNextID() async {
    num nextID = 0;
    final res = await API_Request.api_query('getMaxHoldingID', {});
    if (res['tk_status'] == 'OK') {
      if (res['data'] != null && res['data'].isNotEmpty) {       
        nextID = res['data'][0]['MAX_ID'] + 1;
      }
    } else {
      nextID = 1;
    }
    return nextID;
  }
  Future<void> _insertHoldingData(
    String REASON,
    String M_CODE,
    String M_LOT_NO,
  ) async {
    num nextID = await _getNextID();
    final res = await API_Request.api_query('insertHoldingFromI222', {
      'ID': nextID,
      'REASON': REASON,
      'M_CODE': M_CODE,
      'M_LOT_NO': M_LOT_NO,
    });
    setState(() => isUpdating = false);
    if (res['tk_status'] == 'OK') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật QC PASS kho VL thành công!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cập nhật QC PASS kho VL thất bại!')),
      );
    }
  }
  Future<void> _updateQCPASS_IQC(
    String M_CODE,
    String LOT_CMS,
    String VALUE,
  ) async {
    setState(() => isUpdating = true);
    final res = await API_Request.api_query('updateQCPASSI222', {
      'M_CODE': M_CODE,
      'LOT_CMS': LOT_CMS,
      'VALUE': VALUE,
    });
    setState(() => isUpdating = false);
    if (res['tk_status'] == 'OK') {
      if (VALUE == 'N') {
        await _insertHoldingData(
          widget.data['REMARK'],
          M_CODE,
          LOT_CMS,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật QC PASS kho VL thành công!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cập nhật QC PASS kho VL thất bại!')),
      );
    }
  }
  Future<void> _updateIncomingData(String IQC1_ID) async {
    setState(() => isUpdating = true);
    final res = await API_Request.api_query('updateIncomingData', {
      'M_LOT_NO': widget.data['M_LOT_NO'],
      'NQ_CHECK_ROLL': nqCheckRollController.text,
      'TOTAL_RESULT': totalResult,
      'IQC_TEST_RESULT': iqcTestResult,
      'DTC_RESULT': dtcResult,
      'IQC1_ID': IQC1_ID,
      'REMARK': remarkController.text,
    });
    setState(() => isUpdating = false);
    if (res['tk_status'] == 'OK') {
      _updateQCPASS_IQC(
        widget.data['M_CODE'],
        widget.data['LOT_CMS'],
        totalResult == 'OK' ? 'Y' : 'N',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!')));
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cập nhật thất bại!')));
    }
  }
  Future<void> _updateChecksheetFlag(String iqc1Id) async {
    final res = await API_Request.api_query('updateIncomingChecksheet', {
      'IQC1_ID': iqc1Id,
      'CHECKSHEET': 'Y',
    });
    if (res['tk_status'] == 'OK') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật trạng thái checksheet!')),
      );
      setState(() {
        widget.data['CHECKSHEET'] = 'Y';
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cập nhật trạng thái checksheet thất bại!')),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final hasChecksheet =
        widget.data['CHECKSHEET'] == 'Y' && pickedImage == null;
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
            Text(
              'M_LOT_NO: $lotNo',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('M_NAME: ${widget.data['M_NAME'] ?? ''}'),
            Text('Size: ${widget.data['WIDTH_CD'] ?? ''}'),
            const SizedBox(height: 16),
            // Ảnh checksheet hoặc nút chọn ảnh
            if (widget.data['CHECKSHEET'] == 'Y')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ảnh checksheet kiểm tra đầu vào:'),
                  const SizedBox(height: 8),
                  Image.network(
                    'http://14.160.33.94/iqcincoming/${widget.data['IQC1_ID']}.jpg',
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ],
              )
            else ...[
              pickedImage != null
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ảnh đã chọn:'),
                      const SizedBox(height: 8),
                      Image.file(
                        pickedImage!,
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed:
                                () => _pickImage(source: ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Chụp ảnh'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed:
                                () => _pickImage(source: ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Chọn từ bộ nhớ'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Checksheet'),
                        onPressed: () async {
                          final IQC1_ID = widget.data['IQC1_ID']?.toString();
                          if (IQC1_ID == null || IQC1_ID.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Không tìm thấy IQC1_ID!'),
                              ),
                            );
                            return;
                          }
                          final success = await _uploadImage(IQC1_ID);
                          if (success) {
                            await _updateChecksheetFlag(IQC1_ID);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Upload checksheet thành công!'),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Upload checksheet thất bại!'),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Chưa có ảnh checksheet!'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed:
                                () => _pickImage(source: ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Chụp ảnh'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed:
                                () => _pickImage(source: ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Chọn từ bộ nhớ'),
                          ),
                        ],
                      ),
                    ],
                  ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: nqCheckRollController,
              decoration: const InputDecoration(
                labelText: 'NQ_CHECK_ROLL (Roll ngoại quan)',
              ),
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
                Radio<String>(
                  value: 'PD',
                  groupValue: totalResult,
                  onChanged: (val) => setState(() => totalResult = val),
                ),
                const Text('PD'),
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
                Radio<String>(
                  value: 'PD',
                  groupValue: iqcTestResult,
                  onChanged: (val) => setState(() => iqcTestResult = val),
                ),
                const Text('PD'),
              ],
            ),
            const SizedBox(height: 8),
            const Text('DTC_RESULT:'),
            Row(
              children: [
                Radio<String>(
                  value: 'OK',
                  groupValue: dtcResult,
                  onChanged: (val) => setState(() => dtcResult = val),
                ),
                const Text('OK'),
                Radio<String>(
                  value: 'NG',
                  groupValue: dtcResult,
                  onChanged: (val) => setState(() => dtcResult = val),
                ),
                const Text('NG'),
                Radio<String>(
                  value: 'PD',
                  groupValue: dtcResult,
                  onChanged: (val) => setState(() => dtcResult = val),
                ),
                const Text('PD'),
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
                onPressed:
                    isUpdating
                        ? null
                        : () => _updateIncomingData(
                          widget.data['IQC1_ID'].toString(),
                        ),
                child:
                    isUpdating
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
