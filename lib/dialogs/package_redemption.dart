import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api_utils/api_provider.dart';
import '../config/app_colors.dart';
import '../generated/l10n.dart';
import '../main.dart';
import '../payment/additional_services.dart';
import '../utils/configure_dependencies.dart';
import 'package:http/http.dart' as http;

class PackageRedemptionDialog {
  static Future<void> show(String hospitalId, String hospitalName) async {
    final context = navigatorKey.currentState!.overlay!.context;

    final redemptionResult = await _performRedemption(hospitalId, hospitalName);
    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => redemptionResult,
    );
  }

  static Future _performRedemption(String hospitalId, String hospitalName) async {
    final api = getIt<ApiProvider>();
    try {
      await EasyLoading.show(
        status: 'Being redeemed',
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
        'companyId': hospitalId,
      });

      final url = Uri.parse('${api.baseUrl}/api/v1/company/package/redemption');
      final response = await http.post(url, headers: headers, body: body);
      await EasyLoading.dismiss();
      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        return Redemption(
          hospital: hospitalName,
          code: responseData['code'],
          remainingCount: responseData['remainingCount'].toString(),
        );
      }
    } catch (e) {
      await EasyLoading.dismiss();
      return Redemption(
        hospital: hospitalName,
        code: 'no_remaining_count',
        remainingCount: '0',
      );
    }
  }
}

class Redemption extends StatelessWidget {
  final String code;
  final String hospital;
  final String remainingCount;

  const Redemption({
    super.key,
    required this.code,
    required this.remainingCount,
    required this.hospital,
  });

  @override
  Widget build(BuildContext context) {
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
        code == 'no_remaining_count' ? S.of(context).no_available_service(hospital) : S.of(context).redemption(remainingCount, hospital),
        style: GoogleFonts.rubik(
          color: AppColors.k010101,
          fontSize: 15,
          fontWeight: FontWeight.normal,
        ),
      ),
      actions: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            code == 'no_remaining_count' ? SizedBox(
              width: double.infinity,
              child: MaterialButton(
                color: AppColors.k0cbcc5,
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute<void>(
                    builder: (context) => getIt<AdditionalServices>(),
                  ),);
                },
                child: Text(S.of(context).buyNow, style: GoogleFonts.rubik(
                  color: AppColors.kffffff,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),),
              ),
            ) : Offstage(),
            SizedBox(
              width: double.infinity,
              child: MaterialButton(
                color: AppColors.ke63030,
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(S.of(context).cancel, style: GoogleFonts.rubik(
                  color: AppColors.kffffff,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),),
              ),
            )
          ],
        )
      ],
    );
  }
}
