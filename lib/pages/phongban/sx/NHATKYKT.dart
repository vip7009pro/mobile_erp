import 'dart:async';
import 'dart:convert';
import 'package:mobile_erp/controller/APIRequest.dart';
import 'package:mobile_erp/controller/GetXController.dart';
import 'package:mobile_erp/controller/GlobalFunction.dart';
import 'package:mobile_erp/controller/LocalDataAccess.dart';
import 'package:mobile_erp/pages/LoginPage.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class NhatKyKT extends StatefulWidget {
  const NhatKyKT({super.key});

  @override
  _NhatKyKTState createState() => _NhatKyKTState();
}

class _NhatKyKTState extends State<NhatKyKT> {
  bool _useScanner = true;
  String _token = "reset", _PLAN_ID = '', _EMPL_NO = '', _M_LOT_NO = '', _MACHINE_NO = '',
      _G_NAME = '', _M_NAME = '', _M_CODE = '', _M_SIZE = '', _PLAN_EQ = '', _EMPL_NAME = '',
      _checkEmplOK = 'NG', _checkPlanIdOK = 'NG', _checkMLotNoOK = 'NG', _processLotNo = '',
      _inspectStart = '', _inspectStop = '', _inspectQty = '', _inspectOk = '', _inspectNg = '';
  var _plan_info, _user_info, _processlotinfo;

  final c = Get.put(GlobalController());
  final _formKey = GlobalKey<FormState>();
  final _controllerPlanId = TextEditingController();
  final _controllerEmplNo = TextEditingController();
  final _controllerMLotNo = TextEditingController();
  final _controllerProcessLotNo = TextEditingController();
  final _controllerMachineNo = TextEditingController();
  final _controllerInspectStart = TextEditingController();
  final _controllerInspectStop = TextEditingController();
  final _controllerInspectQty = TextEditingController();
  final _controllerInspectOK = TextEditingController();
  final _controllerInspectNG = TextEditingController();
  final MobileScannerController cameraController = MobileScannerController();
  String? currentScanType;

  @override
  void initState() {
    super.initState();
    _initLocalData();
    _getToken().then((value) => setState(() => _token = value));
  }

  Future<void> _initLocalData() async {
    final userData = await LocalDataAccess.getVariable('userData');
    final useCamera = await LocalDataAccess.getVariable('useCamera');
    setState(() {
      if (userData.isNotEmpty) {
        _user_info = jsonDecode(userData);
        _EMPL_NO = _controllerEmplNo.text = _user_info['EMPL_NO'];
        _EMPL_NAME = '${_user_info['MIDLAST_NAME']} ${_user_info['FIRST_NAME']}';
      }
      _useScanner = useCamera.isNotEmpty;
    });
  }

  Future<String> _getToken() async => (await SharedPreferences.getInstance()).getString('token') ?? 'reset';

  Future<void> _apiQuery(String query, Map<String, dynamic> params, Function(dynamic) onSuccess, {String? errorMsg}) async {
    final value = await API_Request.api_query(query, params);
    if (value['tk_status'] == 'OK') {
      onSuccess(value['data'][0]);
    } else {
      _showErrorDialog(errorMsg ?? value['message']);
    }
  }

  Future<void> checkPlanIdInfo(String planId) async => _apiQuery(
      'checkPLAN_ID', {'token_string': _token, 'PLAN_ID': planId},
      (response) => setState(() {
        _G_NAME = response['G_NAME'];
        _PLAN_EQ = _MACHINE_NO = _controllerMachineNo.text = response['PLAN_EQ'];
        _plan_info = response;
        _checkPlanIdOK = 'OK';
      }), errorMsg: 'Không có số chỉ thị này');

  Future<void> checkProcessLotNo(String processLotNo) async => _apiQuery(
      'mobile_checkProcessLotNo', {
        'token_string': _token,
        'PROCESS_LOT_NO': processLotNo.length > 8 ? processLotNo.substring(11, 19) : processLotNo
      },
      (response) => setState(() {
        _processlotinfo = response;
        _controllerInspectQty.text = '1331';
        _controllerInspectStart.text = response['INSPECT_START'] ?? '';
        _controllerInspectStop.text = response['INSPECT_STOP'] ?? '';
      }), errorMsg: 'Không có lot sản xuất này');

  Future<void> checkMLotNoInfo(String mLotNo, String planId) async {
    bool mLotNoExistOutKhoAo = false, mLotNoExistInP500 = false;
    String mName = '', mSize = '', mCode = '';

    final khoAo = await API_Request.api_query('check_xuat_kho_ao_mobile', {'token_string': _token, 'PLAN_ID': planId, 'M_LOT_NO': mLotNo});
    if (khoAo['tk_status'] == 'OK') {
      final response = khoAo['data'][0];
      mName = response['M_NAME'];
      mSize = response['WIDTH_CD'];
      mCode = response['M_CODE'];
      mLotNoExistOutKhoAo = true;
    }

    final p500 = await API_Request.api_query('checkM_LOT_NO_p500_mobile', {'token_string': _token, 'PLAN_ID': planId, 'M_LOT_NO': mLotNo});
    mLotNoExistInP500 = p500['tk_status'] == 'OK';

    setState(() {
      _M_SIZE = mSize;
      _M_NAME = mName;
      _M_CODE = mCode;
      _M_LOT_NO = mLotNo;
      if (!mLotNoExistOutKhoAo) {
        _controllerMLotNo.text = '-1';
        _showErrorDialog('Lot liệu không đúng hoặc chưa được xuất');
      } else if (mLotNoExistInP500) {
        _controllerMLotNo.text = '-1';
        _showErrorDialog('Lot liệu đã bắn lot cho chỉ thị này');
      } else {
        _checkMLotNoOK = 'OK';
      }
    });
  }

  Future<void> checkEmplNo(String emplNo) async => _apiQuery(
      'checkEMPL_NO_mobile', {'token_string': _token, 'EMPL_NO': emplNo},
      (response) => setState(() {
        _EMPL_NO = response['EMPL_NO'];
        _EMPL_NAME = '${response['MIDLAST_NAME']} ${response['FIRST_NAME']}';
        _user_info = response;
        _checkEmplOK = 'OK';
      }), errorMsg: 'Không có nhân viên này');

  Future<void> insertP500(String mLotNo, String planId) async {
    String nextP500InNo = '001', totalOutQty = '', planIdInput = '', inKhoId = '';
    bool checkPlanIdInput = false;

    await _apiQuery('checkProcessInNoP500', {'token_string': _token},
        (response) => nextP500InNo = (int.parse(response['PROCESS_IN_NO']) + 1).toString().padLeft(3, '0'));

    await _apiQuery('checkOutKhoSX_mobile', {'token_string': _token, 'PLAN_ID_OUTPUT': _PLAN_ID, 'M_CODE': _M_CODE, 'M_LOT_NO': mLotNo},
        (response) {
      totalOutQty = response['TOTAL_OUT_QTY'];
      planIdInput = response['PLAN_ID_INPUT'];
      inKhoId = response['IN_KHO_ID'];
      checkPlanIdInput = true;
    });

    final insertResult = await API_Request.api_query('insert_p500_mobile', {
      'token_string': _token,
      'in_date': DateTime.now().toIso8601String().substring(0, 10).replaceAll('-', ''),
      'next_process_in_no': nextP500InNo,
      'PROD_REQUEST_DATE': _plan_info['PROD_REQUEST_DATE'],
      'PROD_REQUEST_NO': _plan_info['PROD_REQUEST_NO'],
      'G_CODE': _plan_info['G_CODE'],
      'EMPL_NO': _EMPL_NO,
      'phanloai': _MACHINE_NO,
      'PLAN_ID': _PLAN_ID,
      'M_CODE': _M_CODE,
      'M_LOT_NO': mLotNo,
      'INPUT_QTY': totalOutQty,
      'IN_KHO_ID': inKhoId
    });

    if (insertResult['tk_status'] == 'OK') {
      _showSuccessDialog('Input liệu thành công');
      setState(() => _checkEmplOK = _checkMLotNoOK = _checkPlanIdOK = 'NG');
      if (checkPlanIdInput) {
        await Future.wait([
          API_Request.api_query('setUSE_YN_KHO_AO_INPUT_mobile', {
            'token_string': _token,
            'PLAN_ID_INPUT': planIdInput,
            'PLAN_ID_SUDUNG': _PLAN_ID,
            'M_CODE': _M_CODE,
            'M_LOT_NO': mLotNo,
            'TOTAL_IN_QTY': totalOutQty,
            'USE_YN': 'X',
          }),
          API_Request.api_query('setUSE_YN_KHO_AO_OUTPUT_mobile', {
            'token_string': _token,
            'PLAN_ID_OUTPUT': _PLAN_ID,
            'M_CODE': _M_CODE,
            'M_LOT_NO': mLotNo,
            'TOTAL_OUT_QTY': totalOutQty,
            'USE_YN': 'X',
          }),
        ]);
      }
    }
  }

  void _handleBarcodeScan(BarcodeCapture capture, String type) {
    final barcode = capture.barcodes.first.rawValue ?? '';
    setState(() {
      if (type == 'PLAN_ID') {
        _PLAN_ID = _controllerPlanId.text = barcode;
        checkPlanIdInfo(barcode);
      } else if (type == 'EMPL_NO') {
        _EMPL_NO = _controllerEmplNo.text = barcode;
        checkEmplNo(barcode);
      } else if (type == 'M_LOT_NO') {
        _M_LOT_NO = _controllerMLotNo.text = barcode;
        checkMLotNoInfo(barcode, _PLAN_ID);
      } else if (type == 'PROCESS_LOT_NO') {
        _processLotNo = _controllerProcessLotNo.text = barcode;
        checkProcessLotNo(barcode);
      } else if (type == 'MACHINE_NO') {
        _MACHINE_NO = _controllerMachineNo.text = barcode;
        if (barcode != _plan_info?['PLAN_EQ']) _showWarningDialog('Máy input khác so với chỉ thị');
      }
    });
    Navigator.pop(context);
  }

  void _showScannerDialog(String type) {
    currentScanType = type;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: SizedBox(
          width: 300,
          height: 400,
          child: MobileScanner(
            controller: cameraController,
            onDetect: (capture) => _handleBarcodeScan(capture, type),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on), onPressed: () => cameraController.toggleTorch()),
          IconButton(icon: const Icon(Icons.flip_camera_android), onPressed: () => cameraController.switchCamera()),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _showErrorDialog(String desc) => AwesomeDialog(
        context: context,
        dialogType: DialogType.error,
        animType: AnimType.rightSlide,
        title: 'Lỗi',
        desc: desc,
        btnCancelOnPress: () {},
      ).show();

  void _showSuccessDialog(String desc) => AwesomeDialog(
        context: context,
        dialogType: DialogType.success,
        animType: AnimType.rightSlide,
        title: 'Thông báo',
        desc: desc,
        btnOkOnPress: () {},
      ).show();

  void _showWarningDialog(String desc) => AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        animType: AnimType.rightSlide,
        title: 'Cảnh báo',
        desc: desc,
        btnCancelOnPress: () {},
      ).show();

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 91, 255),
        title: const Text('CMS VINA: Scan Input Nhật Ký Sản Xuất'),
      ),
      body: Container(
        margin: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField("Mã nhân viên kiểm tra:", "Quét mã người kiểm", _controllerEmplNo, 'EMPL_NO', null, null),
              Text('PIC: $_EMPL_NAME', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 30, 7, 233))),
              _buildTextField("LOT SX:", "Quét LOTSX", _controllerProcessLotNo, 'PROCESS_LOT_NO', null, null),
              Text('CODE: ${_processlotinfo?['G_NAME'] ?? ''} | ${_processlotinfo?['PLAN_EQ'] ?? ''}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
              _buildTextField("Giờ bắt đầu kiểm:", "Nhập giờ BĐ kiểm", _controllerInspectStart, null, null, null, enabled: false),
              _buildTextField("Giờ kết thúc kiểm:", "Nhập giờ KT kiểm", _controllerInspectStop, null, null, null, enabled: false),
              _buildTextField("Số lượng kiểm tra:", "Nhập số lượng kiểm tra", _controllerInspectQty, null, null, null),
              _buildTextField("Số lượng OK:", "Nhập số lượng OK", _controllerInspectOK, null, null, null),
              _buildTextField("Số lượng NG:", "Nhập số lượng NG", _controllerInspectNG, null, null, null),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Checkbox(
                  value: _useScanner,
                  onChanged: (value) => setState(() {
                    _useScanner = value!;
                    LocalDataAccess.saveVariable('useCamera', value ? 'OK' : '');
                  }),
                ),
                const Text('Dùng camera'),
              ]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _showSuccessDialog('Nhập nhật ký thành công');
                      setState(() {
                        _controllerProcessLotNo.text = _processLotNo = _EMPL_NO = '';
                      });
                    }
                  },
                  child: const Text('Input'),
                ),
                ElevatedButton(
                  onPressed: () => AwesomeDialog(
                    context: context,
                    dialogType: DialogType.question,
                    title: 'Cảnh báo',
                    desc: 'Bạn muốn logout?',
                    btnCancelOnPress: () {},
                    btnOkOnPress: () {
                      GlobalFunction.logout();
                      Get.off(() => const LoginPage());
                    },
                  ).show(),
                  child: const Text('Back'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller, String? type, int? checkLength, Function(String)? onCheck, {bool enabled = true}) {
    return TextFormField(
      enabled: enabled,
      decoration: InputDecoration(labelText: label, hintText: hint),
      controller: controller,
      onTap: () => _useScanner && type != null ? _showScannerDialog(type) : null,
      validator: (value) => (value == null || value.isEmpty || value == '-1') ? (enabled ? 'Phải quét mã vạch' : 'Giá trị không hợp lệ') : null,
      onChanged: (value) => setState(() {
        if (type == 'PLAN_ID') _PLAN_ID = value;
        else if (type == 'EMPL_NO') _EMPL_NO = value;
        else if (type == 'M_LOT_NO') _M_LOT_NO = value;
        else if (type == 'PROCESS_LOT_NO') _processLotNo = value;
        else if (type == 'MACHINE_NO') _MACHINE_NO = value;
        else if (label.contains('kiểm tra')) _inspectQty = value;
        else if (label.contains('OK')) _inspectOk = value;
        else if (label.contains('NG')) _inspectNg = value;
        if (checkLength != null && value.length == checkLength && onCheck != null) onCheck(value);
      }),
    );
  }
}