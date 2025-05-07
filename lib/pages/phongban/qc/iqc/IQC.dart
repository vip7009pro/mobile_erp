import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_erp/controller/GlobalFunction.dart';
import 'package:mobile_erp/pages/LoginPage.dart';
import 'package:mobile_erp/pages/phongban/qc/dtc/DangKyDTC.dart';
import 'package:mobile_erp/pages/phongban/qc/iqc/IQC_ICM.dart';
import 'package:mobile_erp/pages/phongban/qc/iqc/CheckIQCPASS.dart';

class IQCPage extends StatelessWidget {
  const IQCPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6, // Số lượng tab, chỉnh lại theo nhu cầu
      child: Scaffold(
        appBar: AppBar(
          title: const Text('IQC'),
          bottom: const TabBar(
            labelColor: Colors.blue,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 2.0,
            labelPadding: EdgeInsets.symmetric(horizontal: 16.0),
            isScrollable: true,
            indicatorColor: Colors.greenAccent,
            tabs: [
              Tab(text: 'Đăng ký độ tin cậy'),
              Tab(text: 'Nhập data Incoming'),
              Tab(text: 'Check IQC PASS'),
              Tab(text: 'Failing'),
              Tab(text: 'Holding'),
              Tab(text: 'Logout'),
            ],
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.fromARGB(255, 241, 241, 241),
                  Color.fromARGB(255, 76, 142, 230),
                ],
                begin: FractionalOffset(0.0, 1.0),
                end: FractionalOffset(0.0, 0.0),
                stops: [0.0, 1.0],
                tileMode: TileMode.clamp,
              ),
            ),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [
              Color.fromARGB(255, 241, 241, 241),
              Color.fromARGB(255, 76, 142, 230),
            ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ),
          width: double.infinity,
          height: double.infinity,
          child: TabBarView(
            children: [
              const Center(child: const ReliabilityTestRegistrationForm()),
              const Center(child: const IncomingListPage()),
              const CheckIQCPASS(),
              const Center(child: Text('Nội dung Tab 4')),
              const Center(child: Text('Nội dung Tab 5')),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    GlobalFunction.logout();
                    Get.off(() => const LoginPage());
                  },
                  child: const Text('Logout'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}