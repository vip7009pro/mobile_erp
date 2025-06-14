import 'dart:convert';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:mobile_erp/model/DataInterfaceClass.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/oaep.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/block/aes_fast.dart' show AESFastEngine;
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/export.dart';
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

 static Future<Map<String, String>> encryptData(String publicKeyPem, Map<String, dynamic> sendingData) async {
  try {
    // Chuyển sendingData thành chuỗi JSON
    final dataString = jsonEncode(sendingData);
    final dataBytes = Uint8List.fromList(utf8.encode(dataString));
    print('Data bytes length: ${dataBytes.length}');

    // Tạo khóa AES ngẫu nhiên
    final secureRandom = FortunaRandom();
    secureRandom.seed(KeyParameter(Uint8List.fromList(List.generate(32, (i) => DateTime.now().microsecondsSinceEpoch % 256))));
    final aesKey = secureRandom.nextBytes(32); // 256-bit key
    print('AES key: ${base64Encode(aesKey)}');

    // Tạo IV cho AES-GCM
    final iv = secureRandom.nextBytes(12); // 12 bytes IV for GCM
    print('IV: ${base64Encode(iv)}');

    // Mã hóa dữ liệu bằng AES-GCM
    final gcm = GCMBlockCipher(AESEngine());
    final params = AEADParameters(
      KeyParameter(aesKey),
      128, // Tag length (128 bits = 16 bytes)
      iv,
      Uint8List(0), // Additional data (không dùng)
    );
    gcm.init(true, params);
    final encryptedData = gcm.process(dataBytes);
    print('Encrypted data: ${base64Encode(encryptedData)}');

    // Parse publicKey từ PEM
    final publicKey = parsePemPublicKey(publicKeyPem);

    // Mã hóa khóa AES bằng RSA-OAEP với SHA-256
    final rsaEngine = OAEPEncoding.withCustomDigest(() => SHA256Digest(), RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    final encryptedKey = rsaEngine.process(aesKey);
    print('Encrypted key: ${base64Encode(encryptedKey)}');

    // Chuyển thành base64
    return {
      'encryptedData': base64Encode(encryptedData),
      'encryptedKey': base64Encode(encryptedKey),
      'iv': base64Encode(iv),
    };
  } catch (e) {
    print('Encryption error: $e');
    throw Exception('Failed to encrypt data: $e');
  }
}

// Hàm parse publicKey từ PEM
static RSAPublicKey parsePemPublicKey(String pem) {
  try {
    final pemClean = pem
        .replaceAll('-----BEGIN PUBLIC KEY-----', '')
        .replaceAll('-----END PUBLIC KEY-----', '')
        .replaceAll(RegExp(r'\s+'), '');
    print('Cleaned PEM: $pemClean');

    final keyBytes = base64Decode(pemClean);
    print('Key bytes length: ${keyBytes.length}');

    final parser = ASN1Parser(keyBytes);
    final topLevelSeq = parser.nextObject();
    if (topLevelSeq is! ASN1Sequence) {
      throw Exception('Invalid PEM: Expected ASN1Sequence');
    }

    // SPKI: topLevelSeq[0] là algorithm (ASN1Sequence), topLevelSeq[1] là subjectPublicKey (ASN1BitString)
    final algorithmSeq = topLevelSeq.elements[0];
    if (algorithmSeq is! ASN1Sequence) {
      throw Exception('Invalid PEM: Expected algorithm ASN1Sequence');
    }

    final bitString = topLevelSeq.elements[1];
    if (bitString is! ASN1BitString) {
      throw Exception('Invalid PEM: Expected ASN1BitString');
    }

    final rsaKeyParser = ASN1Parser(bitString.contentBytes());
    final rsaKeySeq = rsaKeyParser.nextObject();
    if (rsaKeySeq is! ASN1Sequence) {
      throw Exception('Invalid PEM: Expected RSA key ASN1Sequence');
    }

    // Lấy modulus và exponent
    final modulus = (rsaKeySeq.elements[0] as ASN1Integer).valueAsBigInteger;
    final exponent = (rsaKeySeq.elements[1] as ASN1Integer).valueAsBigInteger;
    if (modulus == null || exponent == null) {
      throw Exception('Invalid PEM: Missing modulus or exponent');
    }

    return RSAPublicKey(modulus, exponent);
  } catch (e) {
    print('Public key parsing error: $e');
    throw Exception('Invalid public key format: $e');
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
