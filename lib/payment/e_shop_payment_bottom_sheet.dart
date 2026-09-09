import 'dart:io';

import 'package:flutter/foundation.dart';
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
import 'package:miaid/services/alipay_service.dart';
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
        // Apple Pay 走 Stripe Platform Pay，仅 iOS 且设备支持时展示，
        // 不影响原有刷卡（PaymentSheet）流程
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
                  // 与上方 Credit or Debit 行保持一致的列表项样式（支付方式列表中
                  // 苹果允许用 Apple Pay 标识的列表项代替官方 PKPaymentButton）
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 10),
                    child: TapDebouncer(
                      onTap: () async => await _startApplePayProcess(context),
                      builder: (context, onTap) => ListTile(
                        leading: const Icon(Icons.apple, color: Colors.black, size: 30),
                        title: Text('Apple Pay', style: GoogleFonts.rubik(
                          color: AppColors.k010101,
                          fontSize: 14,
                        )),
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
            },
          ),
        // 支付宝 App 支付：走后端 /alipay/createPharmacyOrder（境内商户号，人民币结算）+ tobias 唤起支付宝，
        // 不经过 Stripe，不影响上方刷卡与 Apple Pay。只在设备已安装支付宝时展示，
        // 各平台一致（Android 通过插件 manifest 的 <queries> 检测，iOS 通过 LSApplicationQueriesSchemes）
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
                    onTap: () async => await _startAlipayProcess(context),
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
                  color: Colors.black12,
                  height: 0,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _startAlipayProcess(BuildContext context) async {
    final order = params!.order;
    // pop 之后当前 context 失效，文案对象要先取
    final l10n = S.of(context);
    Navigator.pop(context);
    try {
      final outcome = await AlipayService().payPharmacyOrder(
        orderId: '${order.id}',
        currency: order.pharmacyCurrency ?? 'AUD',
        subject: _alipaySubject(order),
      );
      switch (outcome.status) {
        case AlipayPayStatus.success:
          // 此时已扣款成功，埋点失败不能再走 Could not complete payment 提示
          try {
            await LogEventService.purchase(
              orderItems: order.products ?? <Product>[],
              currency: order.pharmacyCurrency ?? '',
              total: order.subTotal ?? 0,
              orderId: order.id?.toString() ?? '',
            );
          } catch (e) {
            debugPrint('LogPurchase failed: $e');
          }
          await HttpExceptionNotifyUser.showInfo(l10n.alipayPaymentSuccessful);
          params?.cartStore?.closeCart();
          break;
        case AlipayPayStatus.pending:
          // 支付宝已受理但后端还没确认（8000/6004，或 9000 后查询暂未返回已支付）。
          // 后端 notify 回调最终会把订单标记为已支付，这里不关购物车，只提示稍后查看订单
          await HttpExceptionNotifyUser.showInfo(l10n.alipayPaymentPending);
          break;
        case AlipayPayStatus.cancelled:
          // 与刷卡取消（FailureCode.Canceled）一致：用户主动取消不提示
          break;
        case AlipayPayStatus.notInstalled:
          await HttpExceptionNotifyUser.showInfo(l10n.alipayNotInstalled);
          break;
        case AlipayPayStatus.failed:
          await HttpExceptionNotifyUser.showError(
            'Could not complete payment [14]: Alipay ${outcome.resultStatus} ${outcome.memo}'.trim(),
          );
          break;
      }
    } catch (e) {
      await HttpExceptionNotifyUser.showError('Could not complete payment [15]: ' + e.toString());
    }
  }

  /// 支付宝收银台展示的商品标题：药房名 + 商品名。支付宝 subject 上限 256 字节，这里保守截断。
  /// 目前后端 createAlipayPharmacyOrder 仍写死为"测试商品"、未读取该字段，后端修正后即生效。
  String _alipaySubject(Order order) {
    final names = (order.products ?? <Product>[])
        .map((p) => p.name ?? '')
        .where((n) => n.isNotEmpty)
        .join(', ');
    final subject = [order.pharmacy?.name ?? '', names].where((s) => s.isNotEmpty).join(' - ');
    if (subject.isEmpty) return 'MiAid order ${order.id}';
    return subject.length > 60 ? '${subject.substring(0, 60)}…' : subject;
  }

  Future<void> _startApplePayProcess(BuildContext context) async {
    try {
      final order = params!.order;
      final paymentIntent = await services.store.createApplePayPaymentIntent(order);
      Navigator.pop(context);
      await Stripe.instance.confirmPlatformPayPaymentIntent(
        clientSecret: paymentIntent.paymentIntentClientSecret!,
        confirmParams: PlatformPayConfirmParams.applePay(
          applePay: ApplePayParams(
            merchantCountryCode: 'AU',
            currencyCode: order.pharmacyCurrency ?? 'AUD',
            cartItems: [
              // 实际扣款金额以后端创建的 PaymentIntent（分）为准，这里仅为 Apple Pay 面板展示
              ApplePayCartSummaryItem.immediate(
                label: 'Synapses Global Assist Pty Ltd',
                amount: (order.orderTotal ?? 0).toStringAsFixed(2),
              ),
            ],
          ),
        ),
      );

      // 此时已扣款成功，埋点失败不能再走 Could not complete payment 提示
      try {
        await LogEventService.purchase(
          orderItems: order.products ?? <Product>[],
          currency: order.pharmacyCurrency ?? '',
          total: order.subTotal ?? 0,
          orderId: order.id?.toString() ?? '',
        );
      } catch (e) {
        debugPrint('LogPurchase failed: $e');
      }

      params?.cartStore?.closeCart();
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) {
        await HttpExceptionNotifyUser.showError('Could not complete payment [12]: ' + e.toString());
        rethrow;
      }
    } catch (e) {
      await HttpExceptionNotifyUser.showError('Could not complete payment [13]: ' + e.toString());
      rethrow;
    }
  }

  Future<void> _startCardPaymentProcess(BuildContext context) async {
    final paymentIntent = await services.store.createStripePaymentIntent(params!.order, PaymentMethodType.Card);
    Navigator.pop(context);
    try {
      await Stripe.instance.initPaymentSheet(paymentSheetParameters: SetupPaymentSheetParameters(
        applePay: null,
        googlePay: null,
        style: ThemeMode.light,
        merchantDisplayName: 'Synapses Global Assist Pty Ltd',
        customerId: paymentIntent.stripeCustomerId,
        paymentIntentClientSecret: paymentIntent.paymentIntentClientSecret!,
        customerEphemeralKeySecret: paymentIntent.ephemeralKeySecret,
      ));
      await Stripe.instance.presentPaymentSheet();

      // 此时已扣款成功，埋点失败不能再走 Could not complete payment 提示
      try {
        await LogEventService.purchase(
          orderItems: params!.order.products ?? <Product>[],
          currency: params!.order.pharmacyCurrency ?? '',
          total: params!.order.subTotal ?? 0,
          orderId: params!.order.id?.toString() ?? '',
        );
      } catch (e) {
        debugPrint('LogPurchase failed: $e');
      }

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