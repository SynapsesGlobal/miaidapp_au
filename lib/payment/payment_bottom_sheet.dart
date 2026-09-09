import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/config/braintree_settings.dart';
import 'package:miaid/config/stripe_settings.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/payment/payment_paypal.dart';
import 'package:miaid/services/alipay_service.dart';
import 'package:miaid/services/facebook_service.dart';
import 'package:miaid/store/home/active_subscription_store.dart';
import 'package:miaid/store/home/home_screen_store.dart';
import 'package:miaid/store/payment/payment_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/travel_care_packages/travel_care_packages.dart';
import 'package:tap_debouncer/tap_debouncer.dart';

class PaymentBottomSheetParams {
  const PaymentBottomSheetParams({
    this.key,
    required this.purchaseRequest,
    required this.context,
    this.onSuccess,
  });

  final Key? key;
  final PurchaseRequest purchaseRequest;
  final BuildContext context;
  final Future<void> Function()? onSuccess;
}

@injectable
class PaymentBottomSheetServices {
  PaymentBottomSheetServices(
    this.store,
    this.activeSubscriptionStore,
    this.stripeSettings,
    this.braintreeSettings,
    this.apiProvider,
  );

  final ApiProvider apiProvider;
  final PaymentStore store;
  final ActiveSubscriptionStore activeSubscriptionStore;
  final StripeSettings stripeSettings;
  final BraintreeSettings braintreeSettings;
}

@injectable
class PaymentBottomSheet extends StatelessWidget {
  PaymentBottomSheet({
    @factoryParam this.params,
    required this.services,
  }) : super(key: params?.key);

  final PaymentBottomSheetParams? params;
  final PaymentBottomSheetServices services;

  @override
  Widget build(BuildContext context) {
    return Column(
      //mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 15),
          child: Container(
            child: Text(
              S.of(context).chooseAPayment,
              style: GoogleFonts.rubik(
                color: AppColors.k010101,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        Divider(
          color: Colors.grey[300],
          height: 0,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 10),
          child: TapDebouncer(
            onTap: () async {
              var state = await _startCardPaymentProcess(context);
              Navigator.pop(params!.context, state);
            },
            builder: (context, onTap) => ListTile(
              leading: Image(
                image: AssetImage('assets/images/ic_payment_card.png'),
              ),
              title: Text(S.of(context).creditOrDebit, style: GoogleFonts.rubik(
                color: AppColors.k010101,
                fontSize: 14,
              )),
              dense: true,
              onTap: onTap,
            ),
          ),
        ),
        Divider(
          color: Colors.grey[300],
          height: 0,
        ),
        // Apple Pay 走 Stripe Platform Pay，仅 iOS 且 Wallet 已添加受支持的卡时展示，
        // 与 e_shop_payment_bottom_sheet 保持一致；原刷卡/Square 流程不受影响
        if (Platform.isIOS)
          FutureBuilder<bool>(
            future: Stripe.instance.isPlatformPaySupported(),
            builder: (context, snapshot) {
              if (snapshot.data != true) {
                // isPlatformPaySupported 只检查 Wallet 里是否已添加
                // Visa/Mastercard/Amex 等 Stripe 支持的卡（银联不算），
                // debug 构建把原因显示出来方便真机排查
                if (kDebugMode && snapshot.connectionState == ConnectionState.done) {
                  return Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      'Apple Pay 不可用：Wallet 未添加 Visa/Mastercard/Amex 卡'
                      '（isPlatformPaySupported=${snapshot.data}）',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 10),
                    child: TapDebouncer(
                      onTap: () async {
                        var state = await _startApplePayProcess(context);
                        Navigator.pop(params!.context, state);
                      },
                      builder: (context, onTap) => ListTile(
                        leading: const Icon(Icons.apple, color: Colors.black, size: 30),
                        title: Text(S.of(context).applePay, style: GoogleFonts.rubik(
                          color: AppColors.k010101,
                          fontSize: 14,
                        )),
                        dense: true,
                        onTap: onTap,
                      ),
                    ),
                  ),
                  Divider(
                    color: Colors.grey[300],
                    height: 0,
                  ),
                ],
              );
            },
          ),
        // 支付宝 App 支付：走后端 /alipay/createPackageOrder（境内商户号，人民币结算）+ tobias 唤起支付宝，
        // 不经过 Stripe，不影响上方刷卡与 Apple Pay。只在套餐以人民币计价且设备已安装支付宝时展示，
        // 与 e_shop_payment_bottom_sheet 的药房入口规则一致
        if (_isRmbPurchase())
          FutureBuilder<bool>(
            future: AlipayService().isInstalled,
            builder: (context, snapshot) {
              // 未安装支付宝时不显示任何内容（debug 构建也不显示提示）
              if (snapshot.data != true) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 10),
                    child: TapDebouncer(
                      onTap: () async {
                        var state = await _startAlipayProcess(context);
                        Navigator.pop(params!.context, state);
                      },
                      builder: (context, onTap) => ListTile(
                        leading: Image(
                          image: AssetImage('assets/images/ic_payment_alipay.png'),
                        ),
                        title: Text(S.of(context).alipay, style: GoogleFonts.rubik(
                          color: AppColors.k010101,
                          fontSize: 14,
                        )),
                        // 境外卡单笔超 200 元支付宝向用户收 3%，提前告知避免被理解为平台多收费
                        subtitle: Text(S.of(context).alipayOverseasCardFeeNotice, style: GoogleFonts.rubik(
                          color: Colors.grey,
                          fontSize: 11,
                        )),
                        dense: true,
                        onTap: onTap,
                      ),
                    ),
                  ),
                  Divider(
                    color: Colors.grey[300],
                    height: 0,
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  /// 套餐币种是否为人民币。后端 currencies 表里人民币记作 RMB，个别地方也用 CNY，两者都算
  bool _isRmbPurchase() {
    final currency = (params!.purchaseRequest.currency.currency ?? '').toUpperCase();
    return currency == 'RMB' || currency == 'CNY';
  }

  /// 与 _startCardPaymentProcess / _startApplePayProcess 相同的返回约定：true 表示已确认支付成功
  Future<bool> _startAlipayProcess(BuildContext context) async {
    final purchase = params!.purchaseRequest;
    final l10n = S.of(context);
    Navigator.pop(context);

    await EasyLoading.show(
      status: l10n.loading,
      maskType: EasyLoadingMaskType.clear,
    );

    await LogEventService.beginCheckout(
      numItems: 1,
      currency: purchase.currency.currency ?? '',
      total: purchase.amount.toDouble(),
    );

    try {
      final countryCode = await getCountryCode();
      if (countryCode == null || countryCode.isEmpty) {
        throw AlipayException('current country is unknown');
      }
      // 唤起支付宝前先关掉遮罩，否则支付宝回跳后遮罩会盖住页面
      await EasyLoading.dismiss();
      final outcome = await AlipayService().payPackage(
        packageId: purchase.itemId.toString(),
        packageType: purchaseTypeToString(purchase.purchaseType),
        currency: purchase.currency.currency ?? 'RMB',
        countryCode: countryCode,
      );
      switch (outcome.status) {
        case AlipayPayStatus.success:
          // 与刷卡一致：轮询后端确认已支付后刷新订阅、弹成功提示、埋点
          await recheckActiveSubscription(params!.context, outcome.paymentId);
          return true;
        case AlipayPayStatus.pending:
          // 支付宝已受理但后端还没确认，后端 notify 回调最终会落库；提示稍后查看，不按成功处理
          await HttpExceptionNotifyUser.showInfo(l10n.alipayPaymentPending);
          return false;
        case AlipayPayStatus.cancelled:
          // 与刷卡取消（FailureCode.Canceled）一致：用户主动取消不提示
          return false;
        case AlipayPayStatus.notInstalled:
          await HttpExceptionNotifyUser.showInfo(l10n.alipayNotInstalled);
          return false;
        case AlipayPayStatus.failed:
          await HttpExceptionNotifyUser.showError(
            'Could not complete payment [16]: Alipay ${outcome.resultStatus} ${outcome.memo}'.trim(),
          );
          return false;
      }
    } catch (e) {
      await EasyLoading.dismiss();
      await HttpExceptionNotifyUser.showError('Could not complete payment [17]: ' + e.toString());
      return false;
    }
  }

  Future<bool> _startApplePayProcess(BuildContext context) async {
    Navigator.pop(context);

    await EasyLoading.show(
      status: S.of(context).loading,
      maskType: EasyLoadingMaskType.clear,
    );

    await LogEventService.beginCheckout(
      numItems: 1,
      currency: params!.purchaseRequest.currency.currency ?? '',
      total: params!.purchaseRequest.amount.toDouble(),
    );

    try {
      final paymentIntent = await services.store.createApplePayPaymentIntent(params!.purchaseRequest);

      // 与后端建 intent 的映射保持一致：Stripe/Apple Pay 面板不认 RMB，需转 CNY
      final rawCurrency = params!.purchaseRequest.currency.currency ?? 'AUD';
      final currencyCode = rawCurrency.toUpperCase() == 'RMB' ? 'CNY' : rawCurrency;

      await Stripe.instance.confirmPlatformPayPaymentIntent(
        clientSecret: paymentIntent.paymentIntentClientSecret!,
        confirmParams: PlatformPayConfirmParams.applePay(
          applePay: ApplePayParams(
            merchantCountryCode: 'AU',
            currencyCode: currencyCode,
            cartItems: [
              // 实际扣款金额以后端创建的 PaymentIntent（分）为准，这里仅为 Apple Pay 面板展示
              ApplePayCartSummaryItem.immediate(
                label: 'Synapses Global Assist Pty Ltd',
                amount: params!.purchaseRequest.amountStringFormat,
              ),
            ],
          ),
        ),
      );
      await EasyLoading.dismiss();

      // Payment is complete
      await recheckActiveSubscription(context, paymentIntent.paymentId);
      return true;
    } on StripeException catch (e, stacktrace) {
      await EasyLoading.dismiss();
      if (e.error.code != FailureCode.Canceled) {
        await HttpExceptionNotifyUser.showError('Could not complete payment [5]: ' + e.toString() + ' -- ' + stacktrace.toString());
      }
      return false;
    } catch (e, stacktrace) {
      await EasyLoading.dismiss();
      await HttpExceptionNotifyUser.showError('Could not complete payment [6]: ' + e.toString() + ' -- ' + stacktrace.toString());
      return false;
    }
  }

  Future<bool> _startCardPaymentProcess(BuildContext context) async {
    Navigator.pop(context);

    await EasyLoading.show(
      status: S.of(context).loading,
      maskType: EasyLoadingMaskType.clear,
    );

    await LogEventService.beginCheckout(
      numItems: 1,
      currency: params!.purchaseRequest.currency.currency ?? '',
      total: params!.purchaseRequest.amount.toDouble(),
    );

    final paymentIntent = await services.store.createStripePaymentIntent(params!.purchaseRequest, PaymentMethodType.Card);

    try {
      await Stripe.instance.initPaymentSheet(paymentSheetParameters: SetupPaymentSheetParameters(
        applePay: PaymentSheetApplePay(
          merchantCountryCode: 'AU',
        ),
        googlePay: PaymentSheetGooglePay(
          merchantCountryCode: 'AU',
        ),
        style: ThemeMode.system,
        merchantDisplayName: 'Synapses Global Assist Pty Ltd',
        customerId: paymentIntent.stripeCustomerId,
        paymentIntentClientSecret: paymentIntent.paymentIntentClientSecret!,
        customerEphemeralKeySecret: paymentIntent.ephemeralKeySecret,
      ));

      await Stripe.instance.presentPaymentSheet();
      await EasyLoading.dismiss();

      // Payment is complete
      await recheckActiveSubscription(context, paymentIntent.paymentId);
      print('支付成功1');
      return true;
    } on StripeException catch (e, stacktrace) {
      print('支付失败2');
      await EasyLoading.dismiss();
      if (e.error.code != FailureCode.Canceled) {
        await HttpExceptionNotifyUser.showError('Could not complete payment [3]: ' + e.toString() + ' -- ' + stacktrace.toString());
      }
      return false;
    } catch (e, stacktrace) {
      print('支付失败3');
      await EasyLoading.dismiss();
      await HttpExceptionNotifyUser.showError('Could not complete payment [4]: ' + e.toString() + ' -- ' + stacktrace.toString());
      return false;
    }
  }

  Future<void> recheckActiveSubscription(
      BuildContext context, int? paymentId) async {
    if (paymentId == null) {
      return;
    }

    try {
      await EasyLoading.show(
        status: S.of(context).processing,
        maskType: EasyLoadingMaskType.clear,
      );

      // Check if the payment was successful in 1 seconds, then 3 seconds and 5 from now
      var paid = await checkActiveSubscription(paymentId, 1);
      if (!paid) {
        paid = await checkActiveSubscription(paymentId, 2);
        if (!paid) {
          paid = await checkActiveSubscription(paymentId, 3);
        }
      }

      if (paid) {
        if (params!.onSuccess != null) {
          await params!.onSuccess!();
        }
        await EasyLoading.dismiss();

        await showPaymentSuccessful(params!.context);
        await LogEventService.purchaseSubscription(
          currency: params!.purchaseRequest.currency.currency ?? '',
          total: params!.purchaseRequest.amount.toDouble() ?? 0,
          orderId: paymentId.toString(),
        );
      } else {
        // not paid yet, do nothing
        await EasyLoading.dismiss();
      }
    } catch (e) {
      await EasyLoading.dismiss();

      // print('showPaymentSuccessful error: $e');
    }
  }

  /// @ returns true when paid
  Future<bool> checkActiveSubscription(int paymentId, int sleepSeconds) async {
    await Future.delayed(Duration(seconds: sleepSeconds), () {});
    await services.activeSubscriptionStore.fetchActiveSubscription();
    return await services.activeSubscriptionStore.isPaymentPaid(paymentId);
  }
}

Future<void> showPaymentSuccessful(BuildContext context) async {
  Widget okButton = Padding(
    padding: EdgeInsets.only(left: 64.5, right: 63.5, bottom: 24.5),
    child: Center(
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: AppColors.k0cbcc5.withOpacity(0.2),
              blurRadius: 10.0,
              spreadRadius: 0.0, //extend the shadow
              offset: Offset(
                0.0, // Move to right 10  horizontally
                4, // Move to bottom 10 Vertically
              ),
            ),
          ],
        ),
        child: TextButton(
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(AppColors.k0cbcc5),
            shape: MaterialStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
          onPressed: () {
            Navigator.pop(context, true);
          },
          child: Text(
            S.of(context).okay,
            style: GoogleFonts.rubik(
              color: AppColors.kffffff,
              fontSize: 17,
            ),
          ),
        ),
      ),
    ),
  );

  var alert = AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    title: Text(
      S.of(context).success,
      textAlign: TextAlign.center,
      style: GoogleFonts.rubik(
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: AppColors.k010101,
      ),
    ),
    content: Text(
      S.of(context).paymentDone,
      textAlign: TextAlign.center,
      style: GoogleFonts.rubik(
        fontSize: 13,
        color: AppColors.k010101,
      ),
    ),
    actions: [okButton],
  );

  await showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}
