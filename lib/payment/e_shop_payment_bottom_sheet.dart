import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/config/braintree_settings.dart';
import 'package:miaid/config/stripe_settings.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/payment/payment_paypal.dart';
import 'package:miaid/services/facebook_service.dart';
import 'package:miaid/store/e_shop/cart_store.dart';
import 'package:miaid/store/e_shop/e_shop_payment_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:tap_debouncer/tap_debouncer.dart';

class EShopPaymentBottomSheetParams {
  const EShopPaymentBottomSheetParams({
    this.key,
    required this.order,
    this.cartStore,
  });

  final Key? key;
  final Order order;
  final CartEShopStore? cartStore;
}

@injectable
class EShopPaymentBottomSheetServices {
  EShopPaymentBottomSheetServices(
    this.store,
    this.stripeSettings,
    this.braintreeSettings,
    this.cartStore,
  );

  final EShopPaymentStore store;
  final StripeSettings stripeSettings;
  final BraintreeSettings braintreeSettings;
  final CartEShopStore cartStore;
}

@injectable
class EShopPaymentBottomSheet extends StatelessWidget {
  EShopPaymentBottomSheet({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final EShopPaymentBottomSheetParams? params;
  final EShopPaymentBottomSheetServices services;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 15),
          child: Container(
            child: Text(S.of(context).chooseAPayment, style: GoogleFonts.rubik(
              color: AppColors.k010101,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            )),
          ),
        ),
        Divider(
          color: Colors.black12,
          height: 0,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: TapDebouncer(
            onTap: () async => await _startCardPaymentProcess(context),
            builder: (context, onTap) => ListTile(
              leading: Image(
                image: AssetImage('assets/images/ic_payment_card.png'),
              ),
              title: Text(S.of(context).creditOrDebit, style: GoogleFonts.rubik(
                color: AppColors.k010101,
                fontSize: 14,
              )),
              // contentPadding: EdgeInsets.zero,
              dense: true,
              onTap: onTap,
            ),
          ),
        ),
        Divider(
          color: Colors.black12,
          height: 0,
        ),
      ],
    );
  }

  Future<void> _startCardPaymentProcess(BuildContext context) async {
    final paymentIntent = await services.store.createStripePaymentIntent(params!.order, PaymentMethodType.Card);
    Navigator.pop(context);
    try {
      await Stripe.instance.initPaymentSheet(paymentSheetParameters: SetupPaymentSheetParameters(
        /*applePay: PaymentSheetApplePay(
          merchantCountryCode: 'AU',
        ),
        googlePay: PaymentSheetGooglePay(
          merchantCountryCode: 'AU',
        ),*/
        applePay: null,
        googlePay: null,
        style: ThemeMode.light,
        merchantDisplayName: 'Synapses Global Assist Pty Ltd',
        customerId: paymentIntent.stripeCustomerId,
        paymentIntentClientSecret: paymentIntent.paymentIntentClientSecret!,
        customerEphemeralKeySecret: paymentIntent.ephemeralKeySecret,
      ));
      await Stripe.instance.presentPaymentSheet();

      await LogEventService.purchase(
        orderItems: params!.order.products ?? <Product>[],
        currency: params!.order.pharmacyCurrency ?? '',
        total: params!.order.subTotal ?? 0,
        orderId: params!.order.id?.toString() ?? '',
      );

      params?.cartStore?.closeCart();
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) {
        await HttpExceptionNotifyUser.showError('Could not complete payment [10]: ' + e.toString());
        rethrow;
      }
    } catch (e) {
      await HttpExceptionNotifyUser.showError('Could not complete payment [11]: ' + e.toString());
      rethrow;
    }
  }

  String amountStringFormat(double amount) {
    return (amount / 100.0).toStringAsFixed(2);
  }
}