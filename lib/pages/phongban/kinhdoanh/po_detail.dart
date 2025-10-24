import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:mobile_erp/controller/APIRequest.dart';
import 'package:mobile_erp/controller/GlobalFunction.dart';
import 'package:mobile_erp/model/DataInterfaceClass.dart';
import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';

class PoDetail extends StatefulWidget {
  final PODATA currentPO;
  final List<CodeListData> allCodes;
  const PoDetail({super.key, required this.currentPO, required this.allCodes});
  @override
  _PoDetailState createState() => _PoDetailState();
}

class _PoDetailState extends State<PoDetail> {
  late PODATA _thisPO;
  final _formKey = GlobalKey<FormState>();
  // Dropdown search controllers
  final TextEditingController _codeSearchCtrl = TextEditingController();
  final TextEditingController _custSearchCtrl = TextEditingController();
  final TextEditingController _poG_NAME = TextEditingController();
  final TextEditingController _poG_CODE = TextEditingController();
  final TextEditingController _poCUST_NAME_KD = TextEditingController();
  final TextEditingController _poCUST_CD = TextEditingController();
  final TextEditingController _poPO_NO = TextEditingController();
  final TextEditingController _poPO_QTY = TextEditingController();
  final TextEditingController _poEMPL_NO = TextEditingController();
  final TextEditingController _poPO_DATE = TextEditingController();
  final TextEditingController _poRD_DATE = TextEditingController();
  final TextEditingController _poPROD_PRICE = TextEditingController();
  final TextEditingController _poBEP = TextEditingController();
  final TextEditingController _poREMARK = TextEditingController();
  List<CustomerListData> _customerList = List.empty();
  List<CodeListData> _codeList = List.empty();
  CodeListData? _selectedCode;
  CustomerListData? _selectedCustomer;
  // No remote search; using provided list with local filtering.

  Future<void> _loadCustomerList() async {
    await API_Request.api_query('selectcustomerList', {}).then((value) {
      if (value['tk_status'] == 'OK') {
        List<dynamic> dynamicList = value['data'];
        setState(() {
          _customerList = dynamicList.map((dynamic item) {
            return CustomerListData.fromJson(item);
          }).toList();
          // Auto select based on existing value
          if (_poCUST_CD.text.isNotEmpty) {
            _selectedCustomer = _customerList.firstWhere(
              (e) => (e.cUSTCD ?? '') == _poCUST_CD.text,
              orElse: () => _selectedCustomer ?? (CustomerListData()),
            );
          }
        });
      } else {}
    });
  }

  Future<void> _updatePO() async {
    // TODO: implement update logic
  }

  void _khoiTao() {
    _poG_NAME.text = widget.currentPO.gNAME!;
    _poCUST_NAME_KD.text = widget.currentPO.cUSTNAMEKD!;
    _poG_CODE.text = widget.currentPO.gCODE!;
    _poCUST_CD.text = widget.currentPO.cUSTCD!;
    _poPO_NO.text = widget.currentPO.pONO!;
    _poPO_QTY.text = widget.currentPO.pOQTY.toString();
    _poPROD_PRICE.text = widget.currentPO.pRODPRICE.toString();
    _poBEP.text = widget.currentPO.bEP.toString();
    _poEMPL_NO.text = widget.currentPO.eMPLNO!;
    _poREMARK.text = widget.currentPO.rEMARK!;
    _poPO_DATE.text = GlobalFunction.MyDate(
      'yyyy-MM-dd',
      widget.currentPO.pODATE!,
    );
    _poRD_DATE.text = GlobalFunction.MyDate(
      'yyyy-MM-dd',
      widget.currentPO.rDDATE!,
    );
    _loadCustomerList();
    // Use provided full code list for local search
    _codeList = widget.allCodes;
    // Auto select current PO code if present in list
    if ((widget.currentPO.gCODE ?? '').isNotEmpty) {
      try {
        _selectedCode = _codeList.firstWhere(
          (e) => (e.gCODE ?? '') == (widget.currentPO.gCODE ?? ''),
        );
      } catch (_) {
        // Keep null to avoid assertion when the item is not in provided list
        _selectedCode = null;
      }
    }
  }

  Widget _customPopupItemBuilderExample2(
    BuildContext context,
    CodeListData item,
    bool isSelected,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration:
          !isSelected
              ? null
              : BoxDecoration(
                border: Border.all(color: Theme.of(context).primaryColor),
                borderRadius: BorderRadius.circular(5),
                color: Colors.white,
              ),
      child: ListTile(
        selected: isSelected,
        title: Text(item.gNAME!),
        subtitle: Text(item.gCODE.toString()),
      ),
    );
  }

  @override
  void initState() {
    _thisPO = widget.currentPO;
    _khoiTao();
    super.initState();
  }

  @override
  void dispose() {
    _codeSearchCtrl.dispose();
    _custSearchCtrl.dispose();
    _poG_NAME.dispose();
    _poG_CODE.dispose();
    _poCUST_NAME_KD.dispose();
    _poCUST_CD.dispose();
    _poPO_NO.dispose();
    _poPO_QTY.dispose();
    _poEMPL_NO.dispose();
    _poPO_DATE.dispose();
    _poRD_DATE.dispose();
    _poPROD_PRICE.dispose();
    _poBEP.dispose();
    _poREMARK.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color.fromARGB(255, 211, 209, 185),
                Color.fromARGB(255, 147, 241, 84),
              ],
              begin: FractionalOffset(0.0, 0.0),
              end: FractionalOffset(1.0, 0.0),
              stops: [0.0, 1.0],
              tileMode: TileMode.clamp,
            ),
          ),
        ),
        title: const Text(
          'Chi tiết PO',
          style: TextStyle(color: Colors.blueAccent),
        ),
      ),
      body: Container(
        padding: const EdgeInsets.all(12.0),
        child: Flex(
          direction: Axis.vertical,
          children: [
            Flexible(
              child: ListView(
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const SizedBox(height: 8),
                            DropdownButtonHideUnderline(
                              child: DropdownButton2<CodeListData>(
                                isExpanded: true,
                                hint: const Text('Chọn Code'),
                                value: _selectedCode != null && _codeList.contains(_selectedCode) ? _selectedCode : null,
                                items: _codeList
                                    .map((e) => DropdownMenuItem<CodeListData>(
                                          value: e,
                                          child: Text('${e.gCODE ?? ''} - ${e.gNAME ?? ''}'),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedCode = val;
                                    _poG_CODE.text = val?.gCODE ?? '';
                                    _poG_NAME.text = val?.gNAME ?? '';
                                    _poPROD_PRICE.text =
                                        (val?.pRODLASTPRICE ?? 0).toString();
                                  });
                                },
                                buttonStyleData: ButtonStyleData(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  height: 48,
                                ),
                                dropdownStyleData: DropdownStyleData(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  maxHeight: 300,
                                ),
                                menuItemStyleData:
                                    const MenuItemStyleData(height: 44),
                                dropdownSearchData: DropdownSearchData(
                                  searchController: _codeSearchCtrl,
                                  searchInnerWidgetHeight: 56,
                                  searchInnerWidget: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: TextFormField(
                                      controller: _codeSearchCtrl,
                                      decoration: InputDecoration(
                                        hintText: 'Tìm theo code hoặc tên...',
                                        prefixIcon: const Icon(Icons.search),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Local filtering of provided list
                                  searchMatchFn: (item, searchValue) {
                                    final data = item.value;
                                    final f = (searchValue).toLowerCase();
                                    return (data?.gCODE ?? '').toLowerCase().contains(f) ||
                                        (data?.gNAME ?? '').toLowerCase().contains(f);
                                  },
                                ),
                                onMenuStateChange: (isOpen) {
                                  if (!isOpen) {
                                    _codeSearchCtrl.clear();
                                  }
                                },
                              ),
                            ),
                            TextFormField(
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'G_CODE',
                                filled: true,
                                fillColor: Color.fromARGB(255, 231, 230, 228),
                              ),
                              controller: _poG_CODE,
                            ),
                            TextFormField(
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'G_NAME',
                                filled: true,
                                fillColor: Color.fromARGB(255, 231, 230, 228),
                              ),
                              controller: _poG_NAME,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonHideUnderline(
                              child: DropdownButton2<CustomerListData>(
                                isExpanded: true,
                                hint: const Text('Chọn Khách hàng'),
                                value: _selectedCustomer,
                                items: _customerList
                                    .map(
                                      (e) => DropdownMenuItem<CustomerListData>(
                                        value: e,
                                        child: Text('${e.cUSTCD ?? ''} - ${e.cUSTNAMEKD ?? ''}'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedCustomer = val;
                                    _poCUST_CD.text = val?.cUSTCD ?? '';
                                    _poCUST_NAME_KD.text = val?.cUSTNAMEKD ?? '';
                                  });
                                },
                                buttonStyleData: ButtonStyleData(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  height: 48,
                                ),
                                dropdownStyleData: DropdownStyleData(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  maxHeight: 300,
                                ),
                                menuItemStyleData:
                                    const MenuItemStyleData(height: 44),
                                dropdownSearchData: DropdownSearchData(
                                  searchController: _custSearchCtrl,
                                  searchInnerWidgetHeight: 56,
                                  searchInnerWidget: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: TextFormField(
                                      controller: _custSearchCtrl,
                                      decoration: InputDecoration(
                                        hintText: 'Tìm khách hàng theo mã hoặc tên...',
                                        prefixIcon: const Icon(Icons.search),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  searchMatchFn: (item, searchValue) {
                                    final data = item.value;
                                    final f = searchValue.toLowerCase();
                                    return (data?.cUSTCD ?? '')
                                            .toLowerCase()
                                            .contains(f) ||
                                        (data?.cUSTNAMEKD ?? '')
                                            .toLowerCase()
                                            .contains(f);
                                  },
                                ),
                                onMenuStateChange: (isOpen) {
                                  if (!isOpen) _custSearchCtrl.clear();
                                },
                              ),
                            ),
                            TextFormField(
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'CUST_CD',
                                filled: true,
                                fillColor: Color.fromARGB(255, 231, 230, 228),
                              ),
                              controller: _poCUST_CD,
                            ),
                            TextFormField(
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'CUST_NAME_KD',
                                filled: true,
                                fillColor: Color.fromARGB(255, 231, 230, 228),
                              ),
                              controller: _poCUST_NAME_KD,
                            ),
                            TextFormField(
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'PO_NO',
                                filled: true,
                                fillColor: Color.fromARGB(255, 231, 230, 228),
                              ),
                              controller: _poPO_NO,
                            ),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'PO_QTY',
                              ),
                              controller: _poPO_QTY,
                            ),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'PROD_PRICE',
                              ),
                              controller: _poPROD_PRICE,
                            ),
                            TextFormField(
                              decoration: const InputDecoration(labelText: 'BEP'),
                              controller: _poBEP,
                            ),
                            TextFormField(
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'EMPL_NO',
                                filled: true,
                                fillColor: Color.fromARGB(255, 231, 230, 228),
                              ),
                              controller: _poEMPL_NO,
                            ),
                            TextFormField(
                              readOnly: true,
                              controller: _poPO_DATE,
                              decoration: const InputDecoration(
                                labelText: 'PO_DATE',
                              ),
                              onTap: () async {
                                DateTime? pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.parse(
                                    widget.currentPO.pODATE ?? "1900-01-01",
                                  ),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime(2101),
                                );
                                if (pickedDate != null &&
                                    pickedDate !=
                                        DateTime.parse(
                                          widget.currentPO.pODATE ?? "1900-01-01",
                                        )) {
                                  setState(() {
                                    _poPO_DATE.text = GlobalFunction.MyDate(
                                      'yyyy-MM-dd',
                                      pickedDate.toString(),
                                    );
                                  });
                                }
                              },
                            ),
                            TextFormField(
                              readOnly: true,
                              controller: _poRD_DATE,
                              decoration: const InputDecoration(
                                labelText: 'RD_DATE',
                              ),
                              onTap: () async {
                                DateTime? pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.parse(
                                    widget.currentPO.rDDATE ?? "1900-01-01",
                                  ),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime(2101),
                                );
                                if (pickedDate != null &&
                                    pickedDate !=
                                        DateTime.parse(
                                          widget.currentPO.rDDATE ?? "1900-01-01",
                                        )) {
                                  setState(() {
                                    _poRD_DATE.text = GlobalFunction.MyDate(
                                      'yyyy-MM-dd',
                                      pickedDate.toString(),
                                    );
                                  });
                                }
                              },
                            ),
                            TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'REMARK',
                              ),
                              controller: _poREMARK,
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    AwesomeDialog(
                      context: context,
                      dialogType: DialogType.question,
                      animType: AnimType.rightSlide,
                      title: 'Cảnh báo',
                      desc: 'Bạn muốn update thông tin nhân viên?',
                      btnCancelOnPress: () {},
                      btnOkOnPress: () {},
                    ).show();
                  },
                  child: const Text('Update'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    AwesomeDialog(
                      context: context,
                      dialogType: DialogType.question,
                      animType: AnimType.rightSlide,
                      title: 'Cảnh báo',
                      desc: 'Bạn muốn add nhân viên?',
                      btnCancelOnPress: () {},
                      btnOkOnPress: () {},
                    ).show();
                  },
                  child: const Text('Add New'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
