// ignore_for_file: library_private_types_in_public_api
import 'dart:convert';
import 'package:mobile_erp/controller/GetXController.dart';
import 'package:mobile_erp/controller/LocalDataAccess.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HomeDrawerHeader extends StatefulWidget {
  const HomeDrawerHeader({super.key});
  @override
  _HomeDrawerHeaderState createState() => _HomeDrawerHeaderState();
}

class _HomeDrawerHeaderState extends State<HomeDrawerHeader> {
  final GlobalController c = Get.put(GlobalController());
  String emplNo = 'NHU1903';
  String mainDeptName = 'QC';
  String emplName = '';
  String position = '';
  @override
  void initState() {
    super.initState();
    LocalDataAccess.getVariable('userData').then(
      (value) {
        setState(() {
          Map<String, dynamic> rawJson = jsonDecode(value);
          emplNo = rawJson['EMPL_NO'];
          mainDeptName = rawJson['MAINDEPTNAME'];
          position = rawJson['JOB_NAME'];
          emplName = rawJson['MIDLAST_NAME'] + ' ' + rawJson['FIRST_NAME'];
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final logo =
        Image.asset('assets/images/cmslogo.jpg', width: 120, fit: BoxFit.cover);
    final emplImage = CircleAvatar(      
      radius: 60,
      backgroundImage:
          NetworkImage('http://14.160.33.94/Picture_NS/NS_$emplNo.jpg'),          
    );
    final thongtinnhanvien = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        logo,
        Text(
          emplName,
          style: const TextStyle(
              color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
        ),
        Text(
          'Bộ phận: $mainDeptName',
          style: const TextStyle(
              color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
        ),
        Text(
          'Chức vụ: $position',
          style: const TextStyle(
              color: Color.fromARGB(255, 231, 37, 189),
              fontWeight: FontWeight.bold,
              fontSize: 12),
        ),
        Text(
          'Mã NV: $emplNo',
          style: const TextStyle(
              color: Color.fromARGB(255, 53, 160, 4),
              fontWeight: FontWeight.bold,
              fontSize: 12),
        ),
      ],
    );
    return Container(
      alignment: Alignment.center, 
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,        
        children: <Widget>[emplImage, thongtinnhanvien],
      ),
    );
  }
}
