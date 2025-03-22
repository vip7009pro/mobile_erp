import 'dart:async';
import 'dart:convert';
import 'package:mobile_erp/controller/APIRequest.dart';
import 'package:mobile_erp/controller/GetXController.dart';
import 'package:mobile_erp/controller/GlobalFunction.dart';
import 'package:mobile_erp/controller/LocalDataAccess.dart';
import 'package:mobile_erp/pages/LoginPage.dart';
import 'package:mobile_erp/pages/phongban/sx/InputMaterialList.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:get/get.dart';
import 'package:moment_dart/moment_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:awesome_dialog/awesome_dialog.dart';

class InputLieu extends StatefulWidget {
  const InputLieu({super.key});

  @override
  _InputLieuState createState() => _InputLieuState();
}

class _InputLieuState extends State<InputLieu> {
  bool _useScanner = true;
  String _token = "reset", _planId = '', _emplNo = '', _mLotNo = '', _mLotNo2 = '', _machineNo = '',
      _mName = '', _mCode = '', _mSize = '', _checkEmplOK = 'NG', _checkPlanIdOK = 'NG', _checkMLotNoOK = 'NG';
  dynamic _planInfo, _userInfo;

  final c = Get.put(GlobalController());
  final _controllerPlanId = TextEditingController();
  final _controllerEmplNo = TextEditingController();
  final _controllerMLotNo = TextEditingController();
  final _controllerMachineNo = TextEditingController();
  final _formKey = GlobalKey<FormState>();
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
        _userInfo = jsonDecode(userData);
        _emplNo = _userInfo['EMPL_NO'];
        _controllerEmplNo.text = _emplNo;
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
      (response) {
        setState(() {
          _machineNo = _controllerMachineNo.text = response['PLAN_EQ'];
          _planInfo = response;
          _checkPlanIdOK = 'OK';
        });
      }, errorMsg: 'Không có số chỉ thị này');

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
      _mSize = mSize;
      _mName = mName;
      _mCode = mCode;
      _mLotNo = mLotNo;
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
        _emplNo = response['EMPL_NO'];
        _userInfo = response;
        _checkEmplOK = 'OK';
      }), errorMsg: 'Không có nhân viên này');

  Future<void> insertP500(String mLotNo, String planId) async {
    String nextP500InNo = '001', totalOutQty = '', planIdInput = '', inKhoId = '';
    bool checkPlanIdInput = false;

    await _apiQuery('checkProcessInNoP500', {'token_string': _token}, (response) {
      nextP500InNo = (int.parse(response['PROCESS_IN_NO']) + 1).toString().padLeft(3, '0');
    });

    await _apiQuery('checkOutKhoSX_mobile', {'token_string': _token, 'PLAN_ID_OUTPUT': _planId, 'M_CODE': _mCode, 'M_LOT_NO': mLotNo},
        (response) {
      totalOutQty = response['TOTAL_OUT_QTY'];
      planIdInput = response['PLAN_ID_INPUT'];
      inKhoId = response['IN_KHO_ID'];
      checkPlanIdInput = true;
    });

    final insertResult = await API_Request.api_query('insert_p500_mobile', {
      'token_string': _token,
      'in_date': Moment.now().format('YYYYMMDD'),
      'next_process_in_no': nextP500InNo,
      'PROD_REQUEST_DATE': _planInfo['PROD_REQUEST_DATE'],
      'PROD_REQUEST_NO': _planInfo['PROD_REQUEST_NO'],
      'G_CODE': _planInfo['G_CODE'],
      'EMPL_NO': _emplNo,
      'phanloai': _machineNo,
      'PLAN_ID': _planId,
      'M_CODE': _mCode,
      'M_LOT_NO': mLotNo,
      'INPUT_QTY': totalOutQty,
      'IN_KHO_ID': inKhoId
    });

    if (insertResult['tk_status'] == 'OK') {
      _showSuccessDialog('Input liệu thành công');
      setState(() {
        _checkEmplOK = _checkMLotNoOK = _checkPlanIdOK = 'NG';
      });

      if (checkPlanIdInput) {
        await API_Request.api_query('setUSE_YN_KHO_AO_INPUT_mobile', {
          'token_string': _token,
          'PLAN_ID_INPUT': planIdInput,
          'PLAN_ID_SUDUNG': _planId,
          'M_CODE': _mCode,
          'M_LOT_NO': mLotNo,
          'TOTAL_IN_QTY': totalOutQty,
          'USE_YN': 'X',
        });
        await API_Request.api_query('setUSE_YN_KHO_AO_OUTPUT_mobile', {
          'token_string': _token,
          'PLAN_ID_OUTPUT': _planId,
          'M_CODE': _mCode,
          'M_LOT_NO': mLotNo,
          'TOTAL_OUT_QTY': totalOutQty,
          'USE_YN': 'X',
        });
      }
    }
  }

  Future<void> insertP500NoCamera() async {
    await Future.wait([checkEmplNo(_emplNo), checkPlanIdInfo(_planId), checkMLotNoInfo(_mLotNo2, _planId)]);
    if (_checkEmplOK == 'OK' && _checkMLotNoOK == 'OK' && _checkPlanIdOK == 'OK') {
      await insertP500(_mLotNo, _planId);
    }
  }

  void _handleBarcodeScan(BarcodeCapture capture, String type) {
    final barcode = capture.barcodes.first.rawValue ?? '';
    setState(() {
      if (type == 'PLAN_ID') {
        _planId = _controllerPlanId.text = barcode;
        checkPlanIdInfo(barcode);
      } else if (type == 'EMPL_NO') {
        _emplNo = _controllerEmplNo.text = barcode;
        checkEmplNo(barcode);
      } else if (type == 'M_LOT_NO') {
        _mLotNo = _controllerMLotNo.text = barcode;
        checkMLotNoInfo(barcode, _planId);
      } else if (type == 'MACHINE_NO') {
        _machineNo = barcode;
        _controllerMachineNo.text = barcode;
        if (barcode != _planInfo?['PLAN_EQ']) {
          _showWarningDialog('Máy input khác so với chỉ thị');
        }
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
      appBar: AppBar(backgroundColor: Colors.green, title: const Text('CMS VINA: Scan Input Material')),
      body: Container(
        margin: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField("EMPL_NO/사원ID:", "Quét EMPL_NO", _controllerEmplNo, 'EMPL_NO', 7, checkEmplNo),
              Text('PIC: ${_userInfo?['MIDLAST_NAME'] ?? ''} ${_userInfo?['FIRST_NAME'] ?? ''}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 30, 7, 233))),
              _buildTextField("PLAN_ID/지시 번호:", "Quét PLAN_ID", _controllerPlanId, 'PLAN_ID', 8, checkPlanIdInfo),
              _buildTextField("MACHINE/호기:", "Quét MACHINE", _controllerMachineNo, 'MACHINE_NO', null, null),
              Text('CODE: ${_planInfo?['G_NAME'] ?? ''} | ${_planInfo?['PLAN_EQ'] ?? ''}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
              _buildTextField("M_LOT_NO:", "Quét M_LOT_NO", _controllerMLotNo, 'M_LOT_NO', 10, (value) => checkMLotNoInfo(value, _planId)),
              Text('LIỆU: $_mName | SIZE: $_mSize',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 243, 8, 192))),
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
                      _useScanner ? null : insertP500NoCamera();
                      setState(() {
                        _controllerMLotNo.text = _mLotNo = _mName = _mSize = '';
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
              InputMaterialList(planID: _planId, key: ValueKey(_planId)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller, String type, int? checkLength, Function(String)? onCheck) {
    return TextFormField(
      decoration: InputDecoration(labelText: label, hintText: hint),
      controller: controller,
      onTap: () => _useScanner ? _showScannerDialog(type) : null,
      validator: (value) => (value == null || value.isEmpty || value == '-1') ? 'Phải quét mã vạch' : null,
      onChanged: (value) {
        setState(() {
          if (type == 'PLAN_ID') _planId = value;
          else if (type == 'EMPL_NO') _emplNo = value;
          else if (type == 'M_LOT_NO') _mLotNo = _mLotNo2 = value;
          else if (type == 'MACHINE_NO') _machineNo = value;
          if (checkLength != null && value.length == checkLength && onCheck != null) onCheck(value);
        });
      },
    );
  }
}