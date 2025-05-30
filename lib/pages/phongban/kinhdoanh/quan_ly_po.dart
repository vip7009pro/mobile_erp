import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:mobile_erp/controller/APIRequest.dart';
import 'package:mobile_erp/controller/GlobalFunction.dart';
import 'package:mobile_erp/model/DataInterfaceClass.dart';
import 'package:mobile_erp/pages/phongban/kinhdoanh/po_detail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:marquee_text/marquee_direction.dart';
import 'package:marquee_text/marquee_text.dart';

class QuanLyPo extends StatefulWidget {
  const QuanLyPo({super.key});
  @override
  _QuanLyPoState createState() => _QuanLyPoState();
}

class _QuanLyPoState extends State<QuanLyPo> {
  DateTime _fromDate = DateTime.now();
  final DateTime _toDate = DateTime.now();
  String _gName = "";
  String _gCode = "";
  String _emplName = "";
  String _custName = "";
  String _prodType = "";
  String _id = "";
  String _poNo = "";
  String _mainMaterial = "";
  String _overDue = "";
  String _invoiceNo = "";
  bool _allTime = true;
  bool _justPOBalance = true;
  final TextEditingController _fromDateController = TextEditingController();
  final TextEditingController _toDateController = TextEditingController();
  final TextEditingController _gNameController = TextEditingController();
  final TextEditingController _gCodeController = TextEditingController();
  final TextEditingController _emplNameController = TextEditingController();
  final TextEditingController _custNameController = TextEditingController();
  final TextEditingController _prodTypeController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _poNoController = TextEditingController();
  final TextEditingController _mainMaterialController = TextEditingController();
  final TextEditingController _overDueController = TextEditingController();
  final TextEditingController _invoiceNoController = TextEditingController();
  List<PODATA> _poDataTable = List.empty();
  Future<void> _loadPOData() async {
    await API_Request.api_query('traPODataFull', {
      'alltime': _allTime,
      'justPoBalance': _justPOBalance,
      'start_date': GlobalFunction.MyDate('yyyy-MM-dd', _fromDate.toString()),
      'end_date': GlobalFunction.MyDate('yyyy-MM-dd', _toDate.toString()),
      'cust_name': _custName,
      'codeCMS': _gCode,
      'codeKD': _gName,
      'prod_type': _prodType,
      'empl_name': _emplName,
      'po_no': _poNo,
      'over': _overDue,
      'id': _id,
      'material': _mainMaterial,
    }).then((value) {
      if (value['tk_status'] == 'OK') {
        List<dynamic> dynamicList = value['data'];
        AwesomeDialog(
          context: context,
          dialogType: DialogType.success,
          animType: AnimType.rightSlide,
          title: 'Thông báo',
          desc: 'Đã load ${dynamicList.length} dòng',
          btnOkOnPress: () {},
        ).show();
        setState(() {
          _poDataTable = dynamicList.map((dynamic item) {
            return PODATA.fromJson(item);
          }).toList();
        });
      } else {}
    });
  }

  Color getColor(Set<WidgetState> states) {
    const Set<WidgetState> interactiveStates = <WidgetState>{
      WidgetState.pressed,
      WidgetState.hovered,
      WidgetState.focused,
    };
    if (states.any(interactiveStates.contains)) {
      return Colors.blue;
    }
    return Colors.red;
  }

  void showBTSheet() {
    showModalBottomSheet<void>(
      isScrollControlled: true,
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                height: 500,
                child: Column(
                  children: [
                    Flexible(
                      child: ListView(
                        children: <Widget>[
                          const Text('Search Filter'),
                          TextFormField(
                            readOnly: true,
                            controller: _fromDateController,
                            decoration:
                                const InputDecoration(labelText: 'From Date'),
                            onTap: () async {
                              DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: _fromDate,
                                firstDate: DateTime(1900),
                                lastDate: DateTime(2101),
                              );
                              if (pickedDate != null &&
                                  pickedDate != _fromDate) {
                                setState(() {
                                  _fromDate = pickedDate;
                                  _fromDateController.text =
                                      GlobalFunction.MyDate(
                                          'yyyy-MM-dd', _fromDate.toString());
                                });
                              }
                            },
                          ),
                          TextFormField(
                            readOnly: true,
                            controller: _fromDateController,
                            decoration:
                                const InputDecoration(labelText: 'From Date'),
                            onTap: () async {
                              DateTime? pickedDate = await showDatePicker(
                                context: context,
                                initialDate: _fromDate,
                                firstDate: DateTime(1900),
                                lastDate: DateTime(2101),
                              );
                              if (pickedDate != null &&
                                  pickedDate != _fromDate) {
                                setState(() {
                                  _fromDate = pickedDate;
                                  _fromDateController.text =
                                      GlobalFunction.MyDate(
                                          'yyyy-MM-dd', _fromDate.toString());
                                });
                              }
                            },
                          ),
                          TextFormField(
                            controller: _gNameController,
                            decoration:
                                const InputDecoration(labelText: 'CodeKD'),
                            onChanged: (value) {
                              setState(() {
                                _gName = value;
                              });
                            },
                          ),
                          TextFormField(
                            controller: _gCodeController,
                            decoration:
                                const InputDecoration(labelText: 'Code ERP'),
                            onChanged: (value) {
                              setState(() {
                                _gCode = value;
                              });
                            },
                          ),
                          TextFormField(
                            controller: _emplNameController,
                            decoration: const InputDecoration(
                                labelText: 'Tên nhân viên'),
                            onChanged: (value) {
                              setState(() {
                                _emplName = value;
                              });
                            },
                          ),
                          TextFormField(
                            controller: _custNameController,
                            decoration:
                                const InputDecoration(labelText: 'Khách hàng'),
                            onChanged: (value) {
                              setState(() {
                                _custName = value;
                              });
                            },
                          ),
                          TextFormField(
                            controller: _prodTypeController,
                            decoration: const InputDecoration(
                                labelText: 'Loại sản phẩm'),
                            onChanged: (value) {
                              setState(() {
                                _prodType = value;
                              });
                            },
                          ),
                          TextFormField(
                            controller: _idController,
                            decoration: const InputDecoration(labelText: 'ID'),
                            onChanged: (value) {
                              setState(() {
                                _id = value;
                              });
                            },
                          ),
                          TextFormField(
                            controller: _poNoController,
                            decoration:
                                const InputDecoration(labelText: 'PO NO'),
                            onChanged: (value) {
                              setState(() {
                                _poNo = value;
                              });
                            },
                          ),
                          TextFormField(
                            controller: _mainMaterialController,
                            decoration: const InputDecoration(
                                labelText: 'Main Material'),
                            onChanged: (value) {
                              setState(() {
                                _mainMaterial = value;
                              });
                            },
                          ),
                          TextFormField(
                            controller: _overDueController,
                            decoration:
                                const InputDecoration(labelText: 'OverDue'),
                            onChanged: (value) {
                              setState(() {
                                _overDue = value;
                              });
                            },
                          ),
                          TextFormField(
                            controller: _invoiceNoController,
                            decoration:
                                const InputDecoration(labelText: 'Invoice No'),
                            onChanged: (value) {
                              setState(() {
                                _invoiceNo = value;
                              });
                            },
                          ),
                          Row(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Checkbox(
                                    checkColor: const Color.fromARGB(
                                        255, 255, 255, 255),
                                    fillColor:
                                        WidgetStateProperty.resolveWith(
                                            getColor),
                                    value: _allTime,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        _allTime = value!;
                                      });
                                    },
                                  ),
                                  const Text('All Time')
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Checkbox(
                                    checkColor: const Color.fromARGB(
                                        255, 255, 255, 255),
                                    fillColor:
                                        WidgetStateProperty.resolveWith(
                                            getColor),
                                    value: _justPOBalance,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        _justPOBalance = value!;
                                      });
                                    },
                                  ),
                                  const Text('Chỉ PO Tồn')
                                ],
                              ),
                            ],
                          ),
                          ElevatedButton(
                            child: const Text('Search'),
                            onPressed: () {
                              _loadPOData();
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _showPOInfo() {
    double screenWidth = MediaQuery.of(context).size.width;
    num totalPOQty = 0;
    num totalDeliveredQty = 0;
    num totalPOBalanceQty = 0;
    double totalPOAmount = 0;
    double totalDeliveredAmount = 0;
    double totalPOBalanceAmount = 0;
    for (var item in _poDataTable) {
      totalPOQty += item.pOQTY!;
      totalDeliveredQty += item.tOTALDELIVERED!;
      totalPOBalanceQty += item.pOBALANCE!;
      totalPOAmount += item.pOAMOUNT!;
      totalDeliveredAmount += item.dELIVEREDAMOUNT!;
      totalPOBalanceAmount += item.bALANCEAMOUNT!;
    }
    return Container(
      width: screenWidth,
      child: Table(
        border: TableBorder.all(color: Colors.grey),
        children: [
          TableRow(children: [
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: Text(
                  'PO QTY',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: Text(
                  'DELI QTY',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: Text(
                  'BL QTY',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ]),
          TableRow(children: [
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: Text(
                  '${GlobalFunction.MyNumber(totalPOQty)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 90, 226)),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: Text(
                  '${GlobalFunction.MyNumber(totalDeliveredQty)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 33, 196, 0)),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: Text(
                  '${GlobalFunction.MyNumber(totalPOBalanceQty)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 236, 2, 2)),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ]),
          TableRow(children: [
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: Text(
                  'PO AMOUNT',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: Text(
                  'DELI AMOUNT',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: Text(
                  'BL AMOUNT',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ]),
          TableRow(children: [
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: Text(
                  '${GlobalFunction.MyAmount(totalPOAmount)}\$',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 0, 90, 226)),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: Text(
                  '${GlobalFunction.MyAmount(totalDeliveredAmount)}\$',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 33, 196, 0)),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: Text(
                  '${GlobalFunction.MyAmount(totalPOBalanceAmount)}\$',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: Color.fromARGB(255, 236, 2, 2)),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ]),
        ])
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    _fromDateController.text =
        GlobalFunction.MyDate('yyyy-MM-dd', _fromDate.toString());
    _toDateController.text =
        GlobalFunction.MyDate('yyyy-MM-dd', _toDate.toString());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              PODATA newpo = PODATA(
                pOID: 0,
                cUSTNAMEKD: '',
                pONO: '',
                gNAME: '',
                gNAMEKD: '',
                gCODE: '7A09455A',
                pODATE:DateTime.now().toString(),
                rDDATE: DateTime.now().toString(),
                bEP: 0,
                pRODPRICE: 0,
                pOQTY: 0,
                tOTALDELIVERED: 0,
                pOBALANCE: 0,
                pOAMOUNT: 0,
                dELIVEREDAMOUNT: 0,
                bALANCEAMOUNT: 0,
                dELIVEREDBEPAMOUNT: 0,
                eMPLNAME: '',
                pRODTYPE: '',
                mNAMEFULLBOM: '',
                pRODMAINMATERIAL: '',
                cUSTCD: '',
                eMPLNO: '',
                pOMONTH: 0,
                pOWEEKNUM: 0,
                oVERDUE: '',
                rEMARK: '',
                fINAL: '',

              );              
              Get.to(() => PoDetail(currentPO: newpo));
            },
          ),
        ],
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
                tileMode: TileMode.clamp),
          ),
        ),
        title: const Text(
          'Quản lý PO',
          style: TextStyle(color: Colors.blueAccent),
        ),
      ),
      body: Column(
        children: [
          _showPOInfo(),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemBuilder: ((BuildContext context, int index) {
                final child = Container(
                  alignment: Alignment.topLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_poDataTable[index].cUSTNAMEKD}',
                        style: const TextStyle(
                            color: Color.fromARGB(255, 59, 132, 228), fontSize: 12),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.justify,
                            maxLines: 1,
                            "${index+1}.${(_poDataTable[index].gNAME ?? "").length > 30? (_poDataTable[index].gNAME ?? "").substring(0,30) : (_poDataTable[index].gNAME ?? "")}",
                            style: const TextStyle(
                                color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            GlobalFunction.MyDate(
                                'yyyy-MM-dd', _poDataTable[index].pODATE ?? ""),
                            style: const TextStyle(
                                color: Color.fromARGB(255, 104, 122, 3),
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Text(
                            GlobalFunction.MyDate(
                                'yyyy-MM-dd', _poDataTable[index].rDDATE ?? ""),
                            style: const TextStyle(
                                color: Color.fromARGB(255, 204, 1, 153),
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            NumberFormat.decimalPattern('en_US')
                                .format(_poDataTable[index].pOQTY),
                            style: const TextStyle(
                                color: Color.fromARGB(255, 80, 44, 236),
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(
                            width: 8.0,
                          ),
                          Text(
                            NumberFormat.decimalPattern('en_US')
                                .format(_poDataTable[index].tOTALDELIVERED),
                            style: const TextStyle(
                                color: Color.fromARGB(255, 9, 177, 18),
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(
                            width: 8.0,
                          ),
                          Text(
                            NumberFormat.decimalPattern('en_US')
                                .format(_poDataTable[index].pOBALANCE),
                            style: const TextStyle(
                                color: Color.fromARGB(255, 197, 1, 1),
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
                final leading = Container(
                  width: 60,
                  height: 60,
                  padding: const EdgeInsets.all(8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color.fromARGB(255, 243, 242, 245),
                        Color.fromARGB(255, 153, 209, 247)
                      ], // Your gradient colors
                    ),
                    borderRadius:
                        BorderRadius.circular(25), // Optional: for rounded corners
                  ),
                  child: Text(
                    '${((_poDataTable[index].cUSTNAMEKD ?? "").length > 4 ? _poDataTable[index].cUSTNAMEKD!.substring(0, 4) : _poDataTable[index].cUSTNAMEKD)}',
                    style: const TextStyle(
                        color: Color.fromARGB(255, 59, 132, 228),
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                );
                final trailing = GestureDetector(
                  onTapDown: (TapDownDetails details) {
                    showMenu(
                      context: context,
                      position: RelativeRect.fromLTRB(
                        details.globalPosition.dx,
                        details.globalPosition.dy,
                        details.globalPosition.dx + 1,
                        details.globalPosition.dy + 1,
                      ),
                      items: <PopupMenuEntry>[
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ).then((value) {
                      if (value != null) {
                        if (value == 'edit') {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              TextEditingController maindeptnamevnctrl =
                                  TextEditingController();
                              TextEditingController maindeptnamekrctrl =
                                  TextEditingController();
                              maindeptnamevnctrl.text =
                                  _poDataTable[index].eMPLNAME ?? "";
                              maindeptnamekrctrl.text =
                                  _poDataTable[index].gNAME ?? "";
                              return AlertDialog(
                                title: const Text('Edit PO'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    TextField(
                                      decoration: const InputDecoration(
                                        hintText: 'Main Dept Name VN',
                                      ),
                                      controller: maindeptnamevnctrl,
                                    ),
                                    TextField(
                                      decoration: const InputDecoration(
                                        hintText: 'Main Dept Name KR',
                                      ),
                                      controller: maindeptnamekrctrl,
                                    ),
                                    const SizedBox(height: 20),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: const Text('Save'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        } else if (value == 'delete') {
                          AwesomeDialog(
                            context: context,
                            dialogType: DialogType.question,
                            animType: AnimType.rightSlide,
                            title: 'Cảnh báo',
                            desc:
                                'Bạn muốn xóa maindept: ${_poDataTable[index].cUSTNAMEKD ?? ""}',
                            btnCancelOnPress: () {},
                            btnOkOnPress: () {},
                          ).show();
                        }
                      }
                    });
                  },
                  child: const Icon(Icons.more_vert),
                );
                return GestureDetector(
                  onTap: () {
                    Get.to(() => PoDetail(currentPO: _poDataTable[index]));
                  },
                  child: Container(
                      margin: const EdgeInsets.all(2.0),
                      padding: const EdgeInsets.all(2.0),
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            spreadRadius: 2.0,
                            blurRadius: 5.0,
                            offset: const Offset(
                                0, 3), // Changes the position of the shadow
                          )
                        ],
                        borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                        gradient: const LinearGradient(
                            colors: [
                              Color.fromARGB(255, 255, 255, 254),
                              Color.fromARGB(255, 245, 235, 248),
                            ],
                            begin: FractionalOffset(0.0, 0.0),
                            end: FractionalOffset(1.0, 0.0),
                            stops: [0.0, 1.0],
                            tileMode: TileMode.clamp),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              leading,
                              const SizedBox(
                                width: 8,
                              ),
                              child
                            ],
                          ),
                          trailing
                        ],
                      )),
                );
              }),
              itemCount: _poDataTable.length,
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Builder(builder: (context) {
        return FloatingActionButton(
            backgroundColor: const Color.fromARGB(255, 125, 231, 76),
            child: const Icon(
              Icons.search,
            ),
            onPressed: () {
              showBTSheet();
            });
      }),
    );
  }
}
