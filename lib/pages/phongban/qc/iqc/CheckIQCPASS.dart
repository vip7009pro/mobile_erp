import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:mobile_erp/controller/GetXController.dart';
import 'package:mobile_erp/controller/GlobalFunction.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile_erp/model/DataInterfaceClass.dart';
import 'package:mobile_erp/controller/APIRequest.dart';
import 'package:collection/collection.dart';

class CheckIQCPASS extends StatefulWidget {
  const CheckIQCPASS({Key? key}) : super(key: key);

  @override
  State<CheckIQCPASS> createState() => _CheckIQCPASSState();
}

class _CheckIQCPASSState extends State<CheckIQCPASS> {
  final _formKey = GlobalKey<FormState>();
  final GlobalController c = Get.put(GlobalController());

  // Controllers
  final TextEditingController lotNvlController = TextEditingController();
  final TextEditingController emplNoController = TextEditingController();

  // Checkbox group sample (now loaded from API)
  List<TestItemData> testItems = [];
  List<String> selectedTestItems = [];

  // Checkbox states
  bool isChangeToMaterial = false;
  bool isLoadingTestItems = false;

  // Biến lưu thông tin vật liệu/sản phẩm
  String? materialName,
      materialSize,
      gCode = "7A07540A",
      mCode = "B0000035",
      cUST_CD = "6969",
      qcPASS = null,
      qcPASSDate = "",
      qcPASSEMPL = "";

  @override
  void initState() {
    emplNoController.text = c.userData.eMPLNO!;
    isChangeToMaterial = (c.userData.sUBDEPTNAME?.contains('IQC') ?? false);
    super.initState();
  }
  // Kiểm tra thông tin vật liệu theo LOT NVL
  Future<void> _checkMaterialInfo(String lotNvl) async {
    if (lotNvl.length == 10) {
      final res = await API_Request.api_query('checkMNAMEfromLotI222', {
        'M_LOT_NO': lotNvl,
      });
      if (res['tk_status'] == 'OK' &&
          res['data'] != null &&
          res['data'].isNotEmpty) {
        setState(() {
          materialName = res['data'][0]['M_NAME'];
          materialSize = res['data'][0]['WIDTH_CD'].toString();
          mCode = res['data'][0]['M_CODE'];
          cUST_CD = res['data'][0]['CUST_CD'];
          qcPASS = res['data'][0]['QC_PASS'];
          qcPASSDate =  (res['data'][0]['QC_PASS_DATE'] != null) ? GlobalFunction.MyDate('yyyy-MM-dd', res['data'][0]['QC_PASS_DATE'].toString()) : "";
          qcPASSEMPL = res['data'][0]['QC_PASS_EMPL'] ?? "";
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

  @override
  void dispose() {
    lotNvlController.dispose();
    emplNoController.dispose();
    super.dispose();
  }

  void _showScannerDialog({required String type}) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            content: SizedBox(
              width: 300,
              height: 400,
              child: MobileScanner(
                onDetect: (capture) {
                  final barcode = capture.barcodes.first.rawValue ?? '';
                  setState(() {
                    _checkMaterialInfo(barcode);
                  });
                  Navigator.pop(context);
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
              validator:
                  (val) =>
                      (isChangeToMaterial && (val == null || val.isEmpty))
                          ? 'Nhập LOT NVL'
                          : null,
              onChanged: (val) {
                _checkMaterialInfo(val);
                //_loadTestedItemsByM_CODE(val);
              },
            ),
            const SizedBox(height: 16),
            // Thông tin vật liệu/sản phẩm
            if (materialName != null && materialSize != null)
              Row(
              children: [
                Text(
                'NAME: ',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color.fromARGB(255, 27, 90, 141),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                materialName ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color.fromARGB(255, 0, 122, 255),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SIZE: ',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color.fromARGB(255, 27, 90, 141),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                materialSize ?? '',
                style: const TextStyle(
                  fontSize: 16,
                  color: Color.fromARGB(255, 218, 12, 183),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            ),
            const SizedBox(height: 16),
            // Thông tin QC PASS
            Row(
              children: [
                Expanded(
                  child: qcPASS == 'Y'
                      ? Image.asset('assets/images/qcpass.png', fit: BoxFit.fitWidth)
                      : qcPASS == 'N'
                          ? Image.asset('assets/images/qcfail.png', fit: BoxFit.fitWidth)
                          : const SizedBox(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                
                const SizedBox(width: 8),
                Text(
                  'IQC PASS: ',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  qcPASS == null ? 'PENDING' : qcPASS == 'Y' ? 'PASS' : 'FAIL',
                  style: TextStyle(
                    fontSize: 16,
                    color: qcPASS == null
                        ? Colors.orange
                        : qcPASS == 'Y'
                            ? Color.fromARGB(255, 141, 221, 143)
                            : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (qcPASS == 'Y')
                const Icon(
                  Icons.check_circle,
                  color: Color.fromARGB(255, 141, 221, 143),
                ),
                if (qcPASS == 'N')
                const Icon(
                  Icons.error,
                  color: Colors.red,
                ),
                if (qcPASS == null)
                const Icon(
                  Icons.pending,
                  color: Colors.orange,
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 8),
                Text(
                  'IQC PASS DATE: ',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  qcPASSDate ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color.fromARGB(255, 1, 4, 197),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 8),
                Text(
                  'IQC PASS EMPL: ',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  qcPASSEMPL ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color.fromARGB(255, 1, 4, 197),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
