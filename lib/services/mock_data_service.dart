import 'dart:convert';
import 'package:flutter/services.dart';

class MockDataService {
  static Future<List<Employee>> getEmployees() async {
    final jsonString = await rootBundle.loadString('assets/mock_employees.json');
    final jsonData = json.decode(jsonString);
    return (jsonData['employees'] as List).map((e) => Employee.fromJson(e)).toList();
  }

  static Future<void> updateAttendance(int empId, String timeIn) async {
    // Tạm in-memory, sau lưu file local bằng path_provider
    // Logic: Tìm emp, thêm {date: DateTime.now(), timeIn}
  }
}

class Employee {
  final int id;
  final String name;
  final String email;
  final String faceImage; // Base64
  final List<Attendance> attendance;

  Employee({required this.id, required this.name, required this.email, required this.faceImage, required this.attendance});

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      faceImage: json['faceImage'],
      attendance: (json['attendance'] as List).map((a) => Attendance.fromJson(a)).toList(),
    );
  }
}

class Attendance {
  final String date;
  final String? timeIn;
  final String? timeOut;

  Attendance({required this.date, this.timeIn, this.timeOut});

  factory Attendance.fromJson(Map<String, dynamic> json) => Attendance(
    date: json['date'],
    timeIn: json['timeIn'],
    timeOut: json['timeOut'],
  );
}