import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

import '../api_utils/api_provider.dart';
import '../api_utils/http_exception.dart';
import '../config/app_colors.dart';
import '../utils/configure_dependencies.dart';
import '../generated/l10n.dart';
import '../view/marketing/orders.dart';
import 'package:miaid/config/api_settings.dart';

class MarketingPaymentService {
  MarketingPaymentService._();
  static final MarketingPaymentService instance = MarketingPaymentService._();

  Future<void> handlePurchase({
    required BuildContext context,
    required dynamic products,
    required String companyId,
    String? points
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      'x-api-key': getIt<ApiSettings>().marketingApiKey,
    };

    try {
      await EasyLoading.show(status: 'Loading');

      final api = getIt<ApiProvider>();
      final url = Uri.parse('${getIt<ApiSettings>().marketingApiHost}/order/payment/intent');

      final body = jsonEncode({
        'companyId': companyId,
        'userId': api.userProvider.user!.id,
        'username': api.userProvider.user!.firstName,
        'email': api.userProvider.user!.email,
        'phone': api.userProvider.user!.phone,
        'products': products,
        'source': 'au',
        'points': points
      });

      final response = await http.post(url, headers: headers, body: body);
      await EasyLoading.dismiss();

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return _showPaymentSheet(
          context: context,
          responseData: responseData,
        );
      } else {
        final responseData = jsonDecode(response.body);
        await HttpExceptionNotifyUser.showInfo(responseData['message']);
      }
    } catch (e) {
      await EasyLoading.dismiss();
      await HttpExceptionNotifyUser.showInfo(
        S.of(context).somethingWentWrong,
      );
    }
  }

  Future<void> _showPaymentSheet({
    required BuildContext context,
    required Map<String, dynamic> responseData,
  }) async {
    await showModalBottomSheet<void>(
      backgroundColor: Colors.white,
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SizedBox(
        height: 200,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 15),
            child: Text(S.of(context).chooseAPayment, style: GoogleFonts.rubik(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: AppColors.k010101,
            ),),
          ),
          Divider(height: 0),
          ListTile(
            leading: Image.asset('assets/images/ic_payment_card.png'),
            title: Text(
              S.of(context).creditOrDebit,
              style: GoogleFonts.rubik(fontSize: 14),
            ),
            onTap: () async {
              Navigator.pop(context);
              await _payWithCard(context, responseData);
            },
          ),
          Divider(height: 0),
        ],),
      ),
    );
  }

  Future<void> _payWithCard(BuildContext context, Map<String, dynamic> res) async {
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'Synapses Global Assist Pty Ltd',
          customerId: res['stripe_customer_id'],
          paymentIntentClientSecret: res['payment_intent_client_secret'],
          customerEphemeralKeySecret: res['ephemeral_key_secret'],
          applePay: PaymentSheetApplePay(merchantCountryCode: 'AU'),
          googlePay: PaymentSheetGooglePay(merchantCountryCode: 'AU'),
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      await Navigator.push(context, MaterialPageRoute<void>(
        builder: (context) => Orders(),
      ),);
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) {
        await HttpExceptionNotifyUser.showError(
          'Payment failed: ${e.toString()}',
        );
      }
    } catch (e) {
      await HttpExceptionNotifyUser.showError(
        'Payment failed: $e',
      );
    }
  }
}
