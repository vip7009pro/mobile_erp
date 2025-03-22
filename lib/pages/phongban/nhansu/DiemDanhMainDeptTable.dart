// ignore_for_file: library_private_types_in_public_api
import 'package:mobile_erp/model/DataInterfaceClass.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

class DiemDanhMainDeptTable extends StatefulWidget {
  final List<DIEMDANHMAINDEPT> diemdanhmaindeptdata;
  const DiemDanhMainDeptTable({super.key, required this.diemdanhmaindeptdata});

  @override
  _DiemDanhMainDeptTableState createState() => _DiemDanhMainDeptTableState();
}

class _DiemDanhMainDeptTableState extends State<DiemDanhMainDeptTable> {
  late DiemDanhMainDeptDataSource _diemDanhMainDeptDataSource;
  late Map<String, double> columnWidths = {
    'MAINDEPTNAME': double.nan,
    'COUNT_TOTAL': double.nan,
    'COUT_ON': double.nan,
    'COUT_OFF': double.nan,
    'COUNT_CDD': double.nan,
    'ON_RATE': double.nan,
  };

  @override
  void initState() {
    super.initState();
    print('Dữ liệu đầu vào: ${widget.diemdanhmaindeptdata.length} phần tử');
    widget.diemdanhmaindeptdata.forEach((e) {
      print('MAINDEPTNAME: ${e.mAINDEPTNAME}, COUNT_TOTAL: ${e.cOUNTTOTAL}');
    });
    _diemDanhMainDeptDataSource = DiemDanhMainDeptDataSource(
        diemdanhmaindeptdata: widget.diemdanhmaindeptdata);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.5,
      width: MediaQuery.of(context).size.width,
      child: SfDataGrid(
        allowColumnsResizing: true,
        onColumnResizeUpdate: (ColumnResizeUpdateDetails details) {
          setState(() {
            columnWidths[details.column.columnName] = details.width;
          });
          return true;
        },
        rowHeight: 40,
        source: _diemDanhMainDeptDataSource,
        columnWidthMode: ColumnWidthMode.auto,
        columns: <GridColumn>[
          GridColumn(
              width: columnWidths['MAINDEPTNAME'] ?? 100,
              columnName: 'MAINDEPTNAME',
              label: Container(
                  alignment: Alignment.center,
                  child: const Text(
                    'DEPTNAME',
                    style: TextStyle(fontSize: 12),
                  ))),
          GridColumn(
              width: columnWidths['COUNT_TOTAL'] ?? 80,
              columnName: 'COUNT_TOTAL',
              label: Container(
                  padding: const EdgeInsets.all(8.0),
                  alignment: Alignment.center,
                  child: const Text('TOTAL', style: TextStyle(fontSize: 12)))),
          GridColumn(
              width: columnWidths['COUT_ON'] ?? 80,
              columnName: 'COUT_ON',
              label: Container(
                  padding: const EdgeInsets.all(8.0),
                  alignment: Alignment.center,
                  child: const Text('COUT_ON', style: TextStyle(fontSize: 12)))),
          GridColumn(
              width: columnWidths['COUT_OFF'] ?? 80,
              columnName: 'COUT_OFF',
              label: Container(
                  padding: const EdgeInsets.all(8.0),
                  alignment: Alignment.center,
                  child: const Text('COUT_OFF', style: TextStyle(fontSize: 12)))),
          GridColumn(
              width: columnWidths['COUNT_CDD'] ?? 80,
              columnName: 'COUNT_CDD',
              label: Container(
                  padding: const EdgeInsets.all(8.0),
                  alignment: Alignment.center,
                  child: const Text('COUNT_CDD',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12)))),
          GridColumn(
              width: columnWidths['ON_RATE'] ?? 80,
              columnName: 'ON_RATE',
              label: Container(
                  padding: const EdgeInsets.all(8.0),
                  alignment: Alignment.center,
                  child: const Text('ON_RATE',
                      style: TextStyle(fontSize: 12)))),
        ],
      ),
    );
  }
}

class DiemDanhMainDeptDataSource extends DataGridSource {
  DiemDanhMainDeptDataSource(
      {required List<DIEMDANHMAINDEPT> diemdanhmaindeptdata}) {
    _dataGridRow = diemdanhmaindeptdata.map<DataGridRow>((e) {
      return DataGridRow(cells: [
        DataGridCell<String>(
            columnName: 'MAINDEPTNAME', value: e.mAINDEPTNAME ?? 'N/A'),
        DataGridCell<int>(
            columnName: 'COUNT_TOTAL', value: e.cOUNTTOTAL ?? 0),
        DataGridCell<int>(columnName: 'COUT_ON', value: e.cOUTON ?? 0),
        DataGridCell<int>(columnName: 'COUT_OFF', value: e.cOUTOFF ?? 0),
        DataGridCell<int>(columnName: 'COUNT_CDD', value: e.cOUNTCDD ?? 0),
        DataGridCell<String>(
            columnName: 'ON_RATE',
            value: NumberFormat.percentPattern()
                .format((e.oNRATE ?? 100) / 100)),
      ]);
    }).toList();
  }

  List<DataGridRow> _dataGridRow = [];

  @override
  List<DataGridRow> get rows => _dataGridRow;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((e) {
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(1.0),
          child: Text(
            e.value?.toString() ?? '',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }
}