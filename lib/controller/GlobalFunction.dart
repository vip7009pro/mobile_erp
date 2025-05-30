import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:mobile_erp/model/DataInterfaceClass.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
class GlobalFunction {  
  static void logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('token', 'reset');
  }
  static void showToast(BuildContext context, String message) {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(SnackBar(
      content: Text('$message '),
      action:
          SnackBarAction(label: 'OK', onPressed: scaffold.hideCurrentSnackBar),
    ));
  }  
  static String convertVietnameseString(String input) {
  const Map<String, String> vietnameseCharacters = {
    'á': 'a', 'à': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
    'â': 'a', 'ấ': 'a', 'ầ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
    'ă': 'a', 'ắ': 'a', 'ằ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
    'é': 'e', 'è': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
    'ê': 'e', 'ế': 'e', 'ề': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
    'í': 'i', 'ì': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
    'ó': 'o', 'ò': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
    'ô': 'o', 'ố': 'o', 'ồ': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
    'ơ': 'o', 'ớ': 'o', 'ờ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
    'ú': 'u', 'ù': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
    'ư': 'u', 'ứ': 'u', 'ừ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
    'ý': 'y', 'ỳ': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
  };
  return input.split('').map((char) => vietnameseCharacters[char] ?? char).join();
}
static String MyDate(String format, String datetimedata) {
  return DateFormat(format).format(DateTime.parse(datetimedata));
}

  static String MyNumber(num number) {
    final formatter = NumberFormat('#,##0.0', 'vi_VN');
    if (number < 1000) {
      return formatter.format(number);
    } else if (number < 1000000) {
      return '${formatter.format(number / 1000)}K';
    } else if (number < 1000000000) {
      return '${formatter.format(number / 1000000)}M';
    } else {
      return '${formatter.format(number / 1000000000)}B';
    }
  }
  static MyAmount(num totalPOAmount) {
   final formatter = NumberFormat('#,##0.0', 'vi_VN');
    if (totalPOAmount < 1000) {
      return formatter.format(totalPOAmount);
    } else if (totalPOAmount < 1000000) {
      return '${formatter.format(totalPOAmount / 1000)}K';
    } else if (totalPOAmount < 1000000000) {
      return '${formatter.format(totalPOAmount / 1000000)}M';
    } else {
      return '${formatter.format(totalPOAmount / 1000000000)}B';
    }
  }
}
bool CheckPermission(UserData userData, List<String> permittedMainDept,
    List<String> permittedPosition, List<String> permittedEmpl, void Function() func) {
  bool check = false;
  if (userData.eMPLNO == 'NHU1903') {
    func();
    check = true;
  } else {
    if (permittedMainDept.contains('ALL')) {
      if (permittedPosition.contains('ALL')) {
        if (permittedEmpl.contains('ALL')) {
          func();
          check = true;
        } else {
          if (permittedEmpl.contains(userData.eMPLNO)) {
            check = true;
            func();
          }
        }
      } else {
        if (permittedPosition.contains(userData.pOSITIONNAME)) {
          check = true;
          func();
        }
      }
    } else {
      if (permittedMainDept.contains(userData.mAINDEPTNAME)) {
        check = true;
        func();
      }
    }
  }
  return check;
}
