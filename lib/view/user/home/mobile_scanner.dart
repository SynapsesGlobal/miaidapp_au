import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/consts.dart';

import '../../../component/nav_bar_icons.dart';
import '../../../config/app_colors.dart';
import '../../../generated/l10n.dart';

class ScanCheckIn extends StatefulWidget {
  const ScanCheckIn({super.key});

  @override
  State<ScanCheckIn> createState() => _ScanCheckInState();
}

class _ScanCheckInState extends State<ScanCheckIn> {
  bool _hasScanned = false;

  void _onScan(Code result) {
    if (_hasScanned) return;

    if (result.isValid && result.text != null && _validateQRFormat(result.text!)) {
      final data = jsonDecode(result.text!);
      _hasScanned = true;
      Navigator.pop(context, data['hospital_name'].toString());
    } else {
      Navigator.pop(context, '');
    }
  }

  bool _validateQRFormat(String qrContent) {
    final data = jsonDecode(qrContent);
    var hospital_name = data['hospital_name'].toString() ?? '';
    var timestamp = data['timestamp'].toString() ?? '';
    var signature = data['signature'].toString() ?? '';
    if (hospital_name.isEmpty || timestamp.isEmpty || signature.isEmpty) {
      return false;
    }
    var token = data['token'].toString() ?? '';
    if (token.isEmpty || token != Consts.QrCodeToken) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: AppColors.kffffff,
        centerTitle: true,
        title: Text(S.of(context).check_in, style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),),
        leading: Builder(
          builder: (BuildContext context) => InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            child: navBarIcon(iconAssetName: 'ic_nb_back.png'),
          ),
        ),
      ),
      body: ReaderWidget(
        codeFormat: Format.qrCode,
        onScan: _onScan,
        onScanFailure: (Code result) {
          debugPrint('扫码失败');
        },
        showScannerOverlay: true,
        showFlashlight: true,
        showGallery: true,
        scanDelay: const Duration(milliseconds: 500),
      ),
    );
  }
}
