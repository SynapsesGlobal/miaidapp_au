import 'dart:core';

import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/home/home_screen_store.dart';
import 'package:mobx/mobx.dart';

part 'payment_store.g.dart';

enum PurchaseType { travelPackages, services, calls }

String purchaseTypeToString(PurchaseType purchaseType) {
  switch (purchaseType) {
    case PurchaseType.travelPackages:
      return 'travel-packages';
    case PurchaseType.services:
      return 'calls';
    case PurchaseType.calls:
      return 'calls';
  }
}

String paymentMethodTypeToString(PaymentMethodType paymentMethodType) {
  switch (paymentMethodType) {
    case PaymentMethodType.Card:
      return 'card';
    case PaymentMethodType.Alipay:
      return 'alipay';
    // case PaymentMethodType.WeChatPay:
    //   return 'wechat_pay';
    default:
      throw Exception('Unsupported payment type: $paymentMethodType');
  }
}

class PurchaseRequest {
  PurchaseRequest(
    this.purchaseType,
    this.itemId,
    this.amount,
    this.currency,
  );

  final PurchaseType purchaseType;
  final int itemId;
  final int amount;
  final Currency currency;

  String get amountStringFormat => (amount / 100.0).toStringAsFixed(2);
}

@injectable
class PaymentStore = _PaymentStore with _$PaymentStore;

abstract class _PaymentStore with Store {
  _PaymentStore(this.user, this.api);

  final UserProvider user;
  final ApiProvider api;

  @action
  Future<StripePaymentIntent> createStripePaymentIntent(
      PurchaseRequest purchaseRequest,
      PaymentMethodType paymentMethodType) async {
    final countryCode = await getCountryCode();

    final response =
        await api.apiClient.subscriptionsPostStripePaymentIntentCreate(
      item_id: purchaseRequest.itemId,
      purchase_type: purchaseTypeToString(purchaseRequest.purchaseType),
      payment_method_type: paymentMethodTypeToString(paymentMethodType),
      country_code: countryCode,
    );
    return await ApiSuccessParser.payloadOrThrowWithMessage(response);
  }

  // Apple Pay 在 Stripe 侧仍是 card 类型的 PaymentIntent，后端用 apple_pay
  // 标记 payment_type。不加 @action（无 observable 变更），避免必须跑
  // build_runner（会抹掉 generated_api_code 里的手工补丁）。
  Future<StripePaymentIntent> createApplePayPaymentIntent(
      PurchaseRequest purchaseRequest) async {
    final countryCode = await getCountryCode();

    final response =
        await api.apiClient.subscriptionsPostStripePaymentIntentCreate(
      item_id: purchaseRequest.itemId,
      purchase_type: purchaseTypeToString(purchaseRequest.purchaseType),
      payment_method_type: 'apple_pay',
      country_code: countryCode,
    );
    return await ApiSuccessParser.payloadOrThrowWithMessage(response);
  }

  @action
  Future<BraintreePayment> createBraintreePayment(
    PurchaseRequest purchaseRequest,
    String paymentNonce,
  ) async {
    final countryCode = await getCountryCode();

    final response =
        await api.apiClient.subscriptionsPostBraintreePaymentServiceCreate(
      item_id: purchaseRequest.itemId,
      purchase_type: purchaseTypeToString(purchaseRequest.purchaseType),
      payment_method_nonce: paymentNonce,
      country_code: countryCode,
    );
    return await ApiSuccessParser.payloadOrThrowWithMessage(response);
  }
}
