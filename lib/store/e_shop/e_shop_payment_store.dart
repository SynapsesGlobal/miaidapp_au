import 'dart:core';

import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_parser.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:mobx/mobx.dart';

part 'e_shop_payment_store.g.dart';

@injectable
class EShopPaymentStore = _EShopPaymentStore with _$EShopPaymentStore;

abstract class _EShopPaymentStore with Store {
  _EShopPaymentStore(this.user, this.api);

  final UserProvider user;
  final ApiProvider api;

  @action
  Future<StripePaymentIntent> createStripePaymentIntent(
      Order order, PaymentMethodType paymentMethodType) async {
    final response = await api.apiClient.eShopPaymentPostGetStripeIntent(
      currency: order.pharmacyCurrency,
      order_id: order.id,
      payment_method_type: paymentMethodTypeToString(paymentMethodType),
    );
    return await ApiSuccessParser.payloadOrThrowWithMessage(response);
  }

  @action
  Future<BraintreePayment> createBraintreePayment(
    String paymentNonce,
    Order order,
  ) async {
    final response =
        await api.apiClient.eShopPaymentPostBraintreePaymentServiceCreate(
      currency: order.pharmacyCurrency,
      order_id: order.id,
      payment_method_nonce: paymentNonce,
    );
    return await ApiSuccessParser.payloadOrThrowWithMessage(response);
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
}
