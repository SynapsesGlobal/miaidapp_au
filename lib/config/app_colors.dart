import 'package:flutter/material.dart';

class AppColors {
  static Color k0cbcc5 = Color(0xFF0CBCC5);
  static Color k010101 = Color(0xFF010101);
  static Color ke63030 = Color(0xFFE63030);
  static Color kffffff = Color(0xffFFFFFF);
  static Color k696969 = Color(0xFF696969);
  static Color kb1b1b1 = Color(0xFFB1B1B1);
  static Color ke68c30 = Color(0xFFE68C30);
  static Color k5251f7 = Color(0xFF5251F7);
  static Color k5e5e5e = Color(0xFF5E5E5E);
  static Color kf4f4f4 = Color(0xffF4F4F4);
  static Color kfa0020 = Color(0xFFFA0020);
  static Color k003f51 = Color(0xff003f51);
  static Color k747474 = Color(0xFF747474);
  static Color k8f8e94 = Color(0xFF8F8E94);
  static Color keefeff = Color(0xFFEEFEFF);
  static Color k2e2e2e = Color(0xFF2E2E2E);
  static Color k000000 = Color(0xFF000000);
  static Color k30bee6 = Color(0xFF30BEE6);
  static Color k808080 = Color(0xFF808080);
  static Color k25d000 = Color(0xFF25D000);
  static Color kff3b30 = Color(0xFFFF3B30);
  static Color k0CC58F = Color(0xff0CC58F);

  /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color? fromHex(String? hexString) {
    if (hexString == null) {
      return null;
    }
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));

    final colourNumber = int.tryParse(buffer.toString(), radix: 16);
    if (colourNumber == null) {
      return null;
    }
    return Color(colourNumber);
  }
}
