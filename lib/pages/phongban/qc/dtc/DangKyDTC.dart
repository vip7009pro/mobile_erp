import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:mobile_erp/controller/GetXController.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile_erp/model/DataInterfaceClass.dart';
import 'package:mobile_erp/controller/APIRequest.dart';
import 'package:collection/collection.dart';

class ReliabilityTestRegistrationForm extends StatefulWidget {
  const ReliabilityTestRegistrationForm({Key? key}) : super(key: key);

  @override
  State<ReliabilityTestRegistrationForm> createState() => _ReliabilityTestRegistrationFormState();
}

class _ReliabilityTestRegistrationFormState extends State<ReliabilityTestRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final GlobalController c = Get.put(GlobalController());

  // MobileScanner controller cho nút focus camera
  final MobileScannerController cameraController = MobileScannerController();

  // Dropdown options
  final List<Map<String, dynamic>> testTypes = [
    {'value': 1, 'text': 'FIRST_LOT'},
    {'value': 2, 'text': 'ECN'},
    {'value': 3, 'text': 'MASS PRODUCTION'},
    {'value': 4, 'text': 'SAMPLE'},
  ];
  int? selectedTestType = 3;

  // Controllers
  final TextEditingController ycsxController = TextEditingController();
  final TextEditingController lotNvlController = TextEditingController();
  final TextEditingController emplNoController = TextEditingController();
  final TextEditingController remarkController = TextEditingController();
  final TextEditingController idTestController = TextEditingController();
  final TextEditingController lotVendorController = TextEditingController();

  // Checkbox group sample (now loaded from API)
  List<TestItemData> testItems = [];
  List<String> selectedTestItems = [];

  // Checkbox states
  bool isSupplement = false;
  bool isChangeToMaterial = false;
  bool isLoadingTestItems = false;
  bool isNoTestDTC = false; // Thêm biến trạng thái cho checkbox "Không test ĐTC"

  // Biến lưu thông tin vật liệu/sản phẩm
  String? materialName, materialSize, productName, prodRequestDate="", gCode = "7A07540A", mCode = "B0000035", cUST_CD="6969";

  @override
  void initState() {
    emplNoController.text = c.userData.eMPLNO!;
    isChangeToMaterial = (c.userData.sUBDEPTNAME?.contains('IQC') ?? false);
    super.initState();
    _loadTestItems();
  }

  Future<void> _loadTestItems() async {
    setState(() {
      isLoadingTestItems = true;
    });
    try {
      final res = await API_Request.api_query('loadDtcTestList', {});
      if (res['tk_status'] == 'OK' && res['data'] != null) {
        final List<dynamic> data = res['data'];
        setState(() {
          testItems = data.map((e) => TestItemData.fromJson(e)).toList();
          isLoadingTestItems = false;
        });
      } else {
        setState(() {
          testItems = [];
          isLoadingTestItems = false;
        });
      }
    } catch (e) {
      setState(() {
        testItems = [];
        isLoadingTestItems = false;
      });
    }
  }

  // Hàm lấy DTC_ID cho LOT NVL: nếu đã từng đăng ký thì lấy DTC_ID cũ, nếu chưa thì lấy DTC_ID tự tăng
  Future<int> _getDtcIdForLotNvl(String lotNvl) async {
    final res = await API_Request.api_query('checkDTC_ID_FROM_M_LOT_NO', {
      'M_LOT_NO': lotNvl,
    });
    if (res['tk_status'] == 'OK' && res['data'] != null && res['data'].isNotEmpty) {
      final dtcId = res['data'][0]['DTC_ID'];
      if (dtcId != null && int.tryParse(dtcId.toString()) != null) {
        return int.parse(dtcId.toString());
      }
    }
    // Nếu không có DTC_ID cũ thì trả về -1 để xử lý tiếp
    return -1;
  }

  // Hàm lấy DTC_ID kế tiếp
  Future<int> _loadNextDtcId() async {
    try {
      final res = await API_Request.api_query('getLastDTCID', {});
      if (res['tk_status'] == 'OK' && res['data'] != null && res['data'].isNotEmpty) {
        final lastId = res['data'][0]['LAST_DCT_ID'];
        if (lastId != null && lastId is int) {
          return lastId + 1;
        } else if (lastId != null && lastId is String) {
          return int.tryParse(lastId) != null ? int.parse(lastId) + 1 : 1;
        }
      }
      return 1;
    } catch (e) {
      return 1;
    }
  }

  // Hàm đăng ký 1 test item với DTC_ID
  Future<bool> _registerDtcTestItem({
    required int dtcId,
    required String testItemCode,
    required int testType,
    required String prodRequestNo,
    required String prodRequestDate,     
    required String lotNvl,
    required String gCode,
    required String mCode,
    required String emplNo,
    required String remark,
  }) async {
    final res = await API_Request.api_query('registerDTCTest', {   
      'DTC_ID': dtcId,
      'TEST_CODE': testItemCode,
      'TEST_TYPE_CODE': testType,
      'REQUEST_DEPT_CODE': c.userData.wORKPOSITIONCODE!,
      'PROD_REQUEST_NO': prodRequestNo,
      'PROD_REQUEST_DATE': prodRequestDate,
      'G_CODE': gCode,
      'M_CODE': mCode,
      'M_LOT_NO': lotNvl,
      'REQUEST_EMPL_NO': emplNo,
      'REMARK': remark,
      'IS_SUPPLEMENT': isSupplement,     
    });
    return (res['tk_status'] == 'OK');
  }

  // Hàm đăng ký incoming data (tạm thởi)
  Future<void> _registerIncomingData({
    required int nqCheckRoll,
    required int dtcId,
  }) async {
    final res = await API_Request.api_query('insertIQC1table', {     
      'M_CODE': mCode,
      'M_LOT_NO': lotNvlController.text,
      'LOT_CMS': lotNvlController.text.substring(0,6),
      'LOT_VENDOR': lotVendorController.text,
      'CUST_CD': cUST_CD,
      'EXP_DATE': '',
      'INPUT_LENGTH': 0,
      'TOTAL_ROLL': 0,
      'NQ_CHECK_ROLL': nqCheckRoll,
      'DTC_ID': dtcId,
      'TEST_EMPL': emplNoController.text,      
      'REMARK': remarkController.text,
    }).then((value) {
      if (value['tk_status'] == 'OK') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đăng ký incoming data thành công!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đăng ký incoming data thất bại!' + value['message'])),
        );
      }
    });
  }

  void _showIncomingDataDialog(int dtcId) {
    final nqCheckRollController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng ký incoming data'),
        content: TextField(
          controller: nqCheckRollController,
          decoration: const InputDecoration(labelText: 'Số Roll check ngoại quan'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _registerIncomingData(
                nqCheckRoll: 0, //qCheckRollController.text,
                dtcId: dtcId,
              );
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã đăng ký incoming data!')),
              );

              /* AwesomeDialog(
                context: context,
                dialogType: DialogType.success,
                title: 'Thành công',
                desc: 'Đã đăng ký incoming data!',
                btnOkOnPress: () {
                  Navigator.of(context).pop(); // Đóng dialog khi bấm OK
                },
              ).show(); */
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  // Hàm kiểm tra đã đăng ký test với LOT NVL và TEST_CODE chưa
  Future<bool> _isTestAlreadyRegistered(String lotNvl, String testCode) async {
    final res = await API_Request.api_query('checkDTC_M_LOT_NO_TEST_CODE_REG', {
      'M_LOT_NO': lotNvl,
      'TEST_CODE': testCode,
    });
    //print(res.toString());
    if (res['tk_status'] == 'OK' && res['data'] != null && res['data'].isNotEmpty) {
      print('ton tai rooi');
      return true;
    }
    return false;
  }

  // Kiểm tra thông tin vật liệu theo LOT NVL
  Future<void> _checkMaterialInfo(String lotNvl) async {    
    if (lotNvl.length == 10) {      
      final res = await API_Request.api_query('checkMNAMEfromLotI222', {'M_LOT_NO': lotNvl});
      if (res['tk_status'] == 'OK' && res['data'] != null && res['data'].isNotEmpty) {
        setState(() {
          materialName = res['data'][0]['M_NAME'];
          materialSize = res['data'][0]['WIDTH_CD'].toString();
          mCode = res['data'][0]['M_CODE'];
          cUST_CD = res['data'][0]['CUST_CD'];
          _loadTestedItemsByM_CODE(mCode!);
          //print('materialName' + materialName!);
          //print('materialSize' + materialSize!);
        });
      } else {
        setState(() {
          materialName = null;
          materialSize = null;
        });
      }
    } else {
      setState(() {
        materialName = null;
        materialSize = null;
      });
    }
  }

  // Kiểm tra thông tin sản phẩm theo YCSX/LABEL_ID
  Future<void> _checkProductInfo(String ycsx) async {
    if (ycsx.length == 7) {
      final res = await API_Request.api_query('ycsx_fullinfo', {'PROD_REQUEST_NO': ycsx});
      if (res['tk_status'] == 'OK' && res['data'] != null && res['data'].isNotEmpty) {
        setState(() {
          productName = res['data'][0]['G_NAME'];
          prodRequestDate = res['data'][0]['PROD_REQUEST_DATE'];
          gCode = res['data'][0]['G_CODE'];
          _loadTestedItemsByG_CODE(gCode!);

        });
      } else {
        setState(() {
          productName = null;
        });
      }
    } else {
      setState(() {
        productName = null;
      });
    }
  }

  // Hàm kiểm tra các test item đã từng test theo LOT NVL
  Future<void> _loadTestedItemsByM_CODE(String M_CODE) async {
    //print('M_CODE: '+ M_CODE);
    if (M_CODE.length >=7 && M_CODE.length <=8) {
      final res = await API_Request.api_query('lichSuTestM_CODE', {'M_CODE': M_CODE});
      if (res['tk_status'] == 'OK' && res['data'] != null) {
        final List<String> testedCodes = res['data'].map<String>((e) => e['TEST_CODE'].toString()).toList();
        print('testedCodes: '+ testedCodes.toString());
        setState(() {
          selectedTestItems = testedCodes;
        });
      } else {
        print('res: '+ res.toString());
        setState(() {
          selectedTestItems = [];
        });
      }
    } else {
      setState(() {
        selectedTestItems = [];
      });
    }
  }

  // Hàm kiểm tra các test item đã từng test theo YCSX/LABEL_ID
  Future<void> _loadTestedItemsByG_CODE(String G_CODE) async {
    if (G_CODE.length == 8) {
      final res = await API_Request.api_query('lichSuTestG_CODE', {'G_CODE': G_CODE});
      if (res['tk_status'] == 'OK' && res['data'] != null) {
        final List<String> testedCodes = res['data'].map<String>((e) => e['TEST_CODE'].toString()).toList();
        setState(() {
          selectedTestItems = testedCodes;
        });
      } else {
        setState(() {
          selectedTestItems = [];
        });
      }
    } else {
      setState(() {
        selectedTestItems = [];
      });
    }
  }

  // Không cần initState cho cameraController vì đã khai báo final ở trên
  @override
  void dispose() {
    cameraController.dispose();
    ycsxController.dispose();
    lotNvlController.dispose();
    emplNoController.dispose();
    remarkController.dispose();
    idTestController.dispose();
    lotVendorController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      int dtcId;
      if (isNoTestDTC) {
        dtcId = -1;
      } else {
        dtcId = isChangeToMaterial ? await _getDtcIdForLotNvl(lotNvlController.text) : await _loadNextDtcId();
        print('dtc_id $dtcId');
        if (dtcId == -1) {
          dtcId = await _loadNextDtcId();
        }
      }
      bool allSuccess = true;
      final List<String> skippedTestItems = [];
      for (final itemCode in selectedTestItems) {
        // Kiểm tra nếu đã tồn tại thì bỏ qua
        bool exists = await _isTestAlreadyRegistered(lotNvlController.text, itemCode);
        if (exists) {
          skippedTestItems.add(itemCode);
          continue;
        }

        final success = isNoTestDTC ? true : await _registerDtcTestItem(
          dtcId: dtcId, // dùng chung DTC_ID cho tất cả test item
          testItemCode: itemCode,
          testType: selectedTestType!,
          prodRequestNo: isChangeToMaterial ? '1IG0008' : ycsxController.text,
          prodRequestDate: isChangeToMaterial? '20210916' : prodRequestDate!,
          lotNvl: isChangeToMaterial ?  lotNvlController.text : '2101011325',
          emplNo: emplNoController.text,
          remark: remarkController.text,
          gCode: gCode!,
          mCode: mCode!,
        );
        if (!success) allSuccess = false;
      }
      // Thông báo các hạng mục đã đăng ký trước đó
      String? getTestNameByCode(String code) {
        final item = testItems.firstWhereOrNull((e) => e.tESTCODE?.toString() == code);
        return item?.tEST_NAME ?? code;
      }
      if (skippedTestItems.length == selectedTestItems.length && !isNoTestDTC) {
        final skippedTestNames = skippedTestItems.map((code) => getTestNameByCode(code)).toList();
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'Lỗi',
          desc: 'Tất cả các hạng mục đã được đăng ký trước đó:\n${skippedTestNames.join(', ')}',
          btnOkOnPress: () {},
        ).show();
        return;
      }
      if (skippedTestItems.isNotEmpty) {
        final skippedTestNames = skippedTestItems.map((code) => getTestNameByCode(code)).toList();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Các hạng mục đã đăng ký trước đó: \n${skippedTestNames.join(', ')}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      if(allSuccess && isChangeToMaterial) {
        await _registerIncomingData(
                nqCheckRoll: 0,
                dtcId: dtcId,
              );
      }
        AwesomeDialog(
        context: context,
        dialogType: allSuccess ? DialogType.success : DialogType.error,
        animType: AnimType.rightSlide,
        title: 'Thông báo',
        desc: allSuccess
            ? 'Đăng ký thành công!, ID: $dtcId'
            : 'Có lỗi khi đăng ký một số test!',
        btnOkText: allSuccess ? 'OK' : null,
        btnCancelText: allSuccess ? 'Cancel' : null,
        btnOkOnPress: () {},
    
        ).show();

     
    }
  }

  void _showScannerDialog({required String type}) {
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
                  final barcode = capture.barcodes.first.rawValue ?? '';
                  setState(() {
                    if (type == 'YCSX') {
                      ycsxController.text = barcode;
                      _checkProductInfo(barcode);                  
                    } else if (type == 'LOTNVL') {
                      lotNvlController.text = barcode;
                      _checkMaterialInfo(barcode);                  
                    } else if (type == 'LOT_VENDOR') {
                      lotVendorController.text = barcode;
                    }
                  });
                  Navigator.pop(context);
                },
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  heroTag: 'focus_button_dtc',
                  backgroundColor: Colors.white,
                  child: const Icon(Icons.center_focus_strong, color: Colors.blue),
                  tooltip: 'Làm nét lại (Focus)',
                  onPressed: () async {
                    try {
                      await cameraController.start();
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingTestItems) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dropdown
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Phân loại test'),
                value: selectedTestType,
                items: testTypes.map((item) {
                  return DropdownMenuItem<int>(
                    value: item['value'],
                    child: Text(item['text']),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => selectedTestType = val);
                },
                validator: (val) => val == null ? 'Chọn phân loại test' : null,
              ),
              const SizedBox(height: 16),

              // Checkbox đổi sản phẩm/NGVL
              CheckboxListTile(
                title: const Text('Thay đổi sản phẩm vào nguyên vật liệu'),
                value: isChangeToMaterial,
                onChanged: (val) {
                  setState(() => isChangeToMaterial = val ?? false);
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),

              // YCSX/LABEL_ID hoặc LOT NVL với nút scan barcode
              if (!isChangeToMaterial)
                TextFormField(
                  controller: ycsxController,
                  decoration: InputDecoration(
                    labelText: 'YCSX/LABEL_ID',
                    hintText: 'YCSX/LABEL_ID',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () => _showScannerDialog(type: 'YCSX'),
                    ),
                  ),
                  validator: (val) => (!isChangeToMaterial && (val == null || val.isEmpty)) ? 'Nhập YCSX/LABEL_ID' : null,
                  onChanged: (val) {
                    _checkProductInfo(val);
                    
                  },
                ),
              if (isChangeToMaterial)
                TextFormField(
                  controller: lotNvlController,
                  decoration: InputDecoration(
                    labelText: 'LOT NVL',
                    hintText: 'LOT NVL',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () => _showScannerDialog(type: 'LOTNVL'),
                    ),
                  ),
                  validator: (val) => (isChangeToMaterial && (val == null || val.isEmpty)) ? 'Nhập LOT NVL' : null,
                  onChanged: (val) {
                    _checkMaterialInfo(val);
                    //_loadTestedItemsByM_CODE(val);
                  },
                ),
              const SizedBox(height: 16),
               // Thông tin vật liệu/sản phẩm
              if (isChangeToMaterial && materialName != null && materialSize != null)
                Text('Tên vật liệu: $materialName, Kích thước: $materialSize',
                  style: const TextStyle(fontSize: 16, color: Color.fromARGB(255, 1, 4, 197), fontWeight: FontWeight.bold),),
              if (!isChangeToMaterial && productName != null)
                Text('Tên sản phẩm: $productName',
                  style: const TextStyle(fontSize: 16, color: Color.fromARGB(255, 1, 4, 197), fontWeight: FontWeight.bold),),
              const SizedBox(height: 16),
              // LOT_VENDOR input with scan button
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: lotVendorController,
                      decoration: const InputDecoration(
                        labelText: 'LOT_VENDOR',
                        hintText: 'Nhập LOT_VENDOR',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: 'Scan LOT_VENDOR',
                    onPressed: () {
                      _showScannerDialog(type: 'LOT_VENDOR');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // EMPL_NO
              TextFormField(
                readOnly: true,
                controller: emplNoController,
                decoration: const InputDecoration(
                  labelText: 'EMPL_NO',
                  hintText: 'EMPL_NO',
                ),
                validator: (val) => val == null || val.isEmpty ? 'Nhập EMPL_NO' : null,
              ),
              const SizedBox(height: 16),



             

              // Checkbox "Không test ĐTC"
              CheckboxListTile(
                title: const Text('Không test ĐTC'),
                value: isNoTestDTC,
                onChanged: (val) {
                  setState(() {
                    isNoTestDTC = val ?? false;
                    if (isNoTestDTC) {
                      selectedTestItems.clear();
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const Text('Chọn các hạng mục test:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...testItems.map((item) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,                    
                    value: selectedTestItems.contains(item.tESTCODE?.toString()),
                    title: Text(item.tEST_NAME ?? ''),
                    onChanged: isNoTestDTC ? null : (checked) {
                      setState(() {
                        final codeStr = item.tESTCODE?.toString();
                        if (checked == true) {
                          if (codeStr != null && !selectedTestItems.contains(codeStr)) {
                            selectedTestItems.add(codeStr);
                          }
                        } else {
                          selectedTestItems.remove(codeStr);
                        }
                      });
                    },
                  )),
              const SizedBox(height: 16),

              // Remark
              TextFormField(
                controller: remarkController,
                decoration: const InputDecoration(
                  labelText: 'Remark',
                  hintText: 'Remark',
                ),
              ),
              const SizedBox(height: 16),

              // Checkbox đăng ký bổ sung
              CheckboxListTile(
                title: const Text('Đăng ký bổ sung cho ID test đã có'),
                value: isSupplement,
                onChanged: (val) {
                  setState(() => isSupplement = val ?? false);
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
              // Nếu check thì hiện textfield nhập ID test
              if (isSupplement)
                TextFormField(
                  controller: idTestController,
                  decoration: const InputDecoration(
                    labelText: 'ID test độ tin cậy',
                    hintText: 'Nhập ID test độ tin cậy',
                  ),
                  validator: (val) => (isSupplement && (val == null || val.isEmpty)) ? 'Nhập ID test độ tin cậy' : null,
                ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitForm,
                  child: const Text('Đăng ký test'),
                ),
              ),
            ],
          ),
        )
      );
    }
  }
