import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../api_utils/api_provider.dart';
import '../config/app_colors.dart';
import '../generated/l10n.dart';
import '../main.dart';
import '../store/home/home_screen_store.dart';
import '../utils/configure_dependencies.dart';
import 'package:http/http.dart' as http;

class AppointCheckInDialog {
  static Future<void> show(String hospitalName) async {
    final context = navigatorKey.currentState!.overlay!.context;

    final result = await _performCheckIn(hospitalName);
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AppointCheckIn(
        hospitalName: hospitalName,
        checkInTime: result.checkInTime,
        errorMessage: result.errorMessage,
      ),
    );
  }

  // 签到逻辑移到这里，与 UI 解耦
  static Future<_CheckInResult> _performCheckIn(String hospitalName) async {
    final api = getIt<ApiProvider>();
    try {
      final position = await determinePosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      final countryCode = await getCountryCodeFromLocation(position);

      await EasyLoading.show(
        status: 'Checking in...',
        maskType: EasyLoadingMaskType.black,
      );

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'x-access-token': api.userProvider.user!.accessToken!,
        'x-user-id': api.userProvider.user!.id.toString(),
        'x-api-key': api.apiKey,
      };

      final body = jsonEncode({
        'userId': api.userProvider.user!.id.toString(),
        'country_code': countryCode,
        'hospital_name': hospitalName,
      });

      final url = Uri.parse('${api.baseUrl}/api/v1/scan/checkin');
      final response = await http.post(url, headers: headers, body: body);
      await EasyLoading.dismiss();
      if (response.statusCode == 200) {
        return _CheckInResult(checkInTime: DateTime.now());
      } else {
        return _CheckInResult(
          checkInTime: DateTime.now(),
          errorMessage: "签到失败",
        );
      }
    } catch (e) {
      await EasyLoading.dismiss();
      return _CheckInResult(
        checkInTime: DateTime.now(),
        errorMessage: e.toString(),
      );
    }
  }
}

class _CheckInResult {
  final DateTime checkInTime;
  final String? errorMessage;

  _CheckInResult({required this.checkInTime, this.errorMessage});
  bool get isSuccess => errorMessage == null;
}

class AppointCheckIn extends StatelessWidget {
  final String hospitalName;
  final DateTime checkInTime;
  final String? errorMessage;

  const AppointCheckIn({
    super.key,
    required this.hospitalName,
    required this.checkInTime,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = errorMessage == null;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Column(children: [
        Text(S.of(context).system_info, style: GoogleFonts.rubik(
          color: AppColors.k0cbcc5,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),),
        const Divider(),
      ],),
      content: Text(
        isSuccess ? S.of(context).check_in_success(hospitalName, DateFormat('yyyy-MM-dd HH:mm:ss').format(checkInTime),) : S.of(context).check_in_failed, // 失败文案
        style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 15,
          fontWeight: FontWeight.normal,
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: MaterialButton(
              color: AppColors.k0cbcc5,
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(S.of(context).confirm, style: GoogleFonts.rubik(
                color: AppColors.kffffff,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),),
            ),),
          ],
        ),
      ],
    );
  }
}
