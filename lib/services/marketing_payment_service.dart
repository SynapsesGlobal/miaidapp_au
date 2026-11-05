import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/payment/marketing_payment_bottom_sheet.dart';
import 'package:miaid/services/alipay_service.dart';
import 'package:miaid/services/marketing_api.dart';

import '../api_utils/api_provider.dart';
import '../api_utils/http_exception.dart';
import '../generated/l10n.dart';
import '../utils/configure_dependencies.dart';
import '../view/marketing/orders.dart';

/// marketing（miaid_mispace）商品的支付方式。[apiValue] 是后端 `orders.payment_method`
/// 的取值，建 intent 时通过 `paymentMethod` 参数告诉后端；Apple Pay 在 Stripe 侧仍是
/// card 类型的 PaymentIntent，只是用 Platform Pay 确认。支付宝不经过 Stripe，
/// 走 mispace 自己的 `/order/alipay/payload`（境内商户号，仅人民币商品）。
enum MarketingPaymentMethod {
  card('stripe'),
  applePay('apple_pay'),
  alipay('alipay');

  const MarketingPaymentMethod(this.apiValue);
  final String apiValue;
}

/// 下单/建 intent 阶段的业务错误（库存不足、积分不够、后端不可用等），
/// [message] 可直接展示给用户。
class MarketingPaymentException implements Exception {
  MarketingPaymentException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 后端 `POST /order/payment/intent` 的返回。除 Stripe 三件套外还带订单号和
/// 实际应付金额（已扣积分），Apple Pay 面板展示金额用的就是它。
class MarketingPaymentIntent {
  MarketingPaymentIntent({
    required this.clientSecret,
    required this.method,
    this.ephemeralKeySecret,
    this.customerId,
    this.paymentIntentId,
    this.orderId,
    this.orderNbr,
    this.amount,
    this.currency,
  });

  final String clientSecret;
  final MarketingPaymentMethod method;
  final String? ephemeralKeySecret;
  final String? customerId;
  final String? paymentIntentId;
  final int? orderId;
  final String? orderNbr;
  /// 应付金额（元，字符串），由后端按两位小数格式化
  final String? amount;
  /// 订单币种，如 AUD / CNY / RMB
  final String? currency;

  /// 解析后端返回；缺少 client secret 时抛 [FormatException]，调用方按失败处理，
  /// 不能让空 secret 一路传到 Stripe 再报一个看不懂的错。
  factory MarketingPaymentIntent.fromJson(Map<String, dynamic> json, MarketingPaymentMethod method) {
    final secret = json['payment_intent_client_secret']?.toString() ?? '';
    if (secret.isEmpty) {
      throw const FormatException('payment_intent_client_secret missing');
    }
    return MarketingPaymentIntent(
      clientSecret: secret,
      method: method,
      ephemeralKeySecret: json['ephemeral_key_secret']?.toString(),
      customerId: json['stripe_customer_id']?.toString(),
      paymentIntentId: json['paymentIntentId']?.toString(),
      orderId: int.tryParse(json['orderId']?.toString() ?? ''),
      orderNbr: json['orderNbr']?.toString(),
      amount: json['amount']?.toString(),
      currency: json['currency']?.toString(),
    );
  }

  /// Apple Pay 面板用的 ISO 币种码：后端人民币记作 RMB，Apple/Stripe 只认 CNY
  String get applePayCurrencyCode {
    final code = (currency ?? '').trim().toUpperCase();
    if (code.isEmpty) return 'AUD';
    return code == 'RMB' ? 'CNY' : code;
  }

  /// Apple Pay 面板展示金额（两位小数）；解析不了时给 0.00，实际扣款以后端 intent 为准
  String get displayAmount {
    final value = num.tryParse(amount ?? '');
    return (value ?? 0).toStringAsFixed(2);
  }
}

/// 后端 `POST /order/alipay/payload` 的返回：已签名的支付宝 orderString、支付宝侧商户单号
/// 以及订单信息。orderString 交给 tobias 唤起支付宝，outTradeNo 用来向后端确认支付结果。
class MarketingAlipayPayload {
  MarketingAlipayPayload({
    required this.orderString,
    required this.outTradeNo,
    this.orderId,
    this.orderNbr,
    this.amount,
    this.currency,
  });

  final String orderString;
  final String outTradeNo;
  final int? orderId;
  final String? orderNbr;
  /// 支付宝实际收取的人民币金额（元，两位小数）
  final String? amount;
  /// 订单币种（AU 只允许 CNY / RMB）
  final String? currency;

  /// 缺 orderString 或 outTradeNo 时抛 [FormatException]：没有签名串唤不起支付宝，
  /// 没有单号则无法确认结果，两者都按下单失败处理。
  factory MarketingAlipayPayload.fromJson(Map<String, dynamic> json) {
    final orderString = json['orderString']?.toString() ?? '';
    final outTradeNo = json['outTradeNo']?.toString() ?? '';
    if (orderString.isEmpty || outTradeNo.isEmpty) {
      throw const FormatException('orderString / outTradeNo missing');
    }
    return MarketingAlipayPayload(
      orderString: orderString,
      outTradeNo: outTradeNo,
      orderId: int.tryParse(json['orderId']?.toString() ?? ''),
      orderNbr: json['orderNbr']?.toString(),
      amount: json['amount']?.toString(),
      currency: json['currency']?.toString(),
    );
  }
}

/// marketing 商品购买：先弹支付方式（刷卡 / Apple Pay / 人民币商品另有支付宝），选定后才向
/// 后端下预订单，避免用户关掉弹窗也留下一张未支付订单。几种方式的返回约定一致：
/// true 表示支付渠道已确认支付成功并跳到了订单页；取消、失败都返回 false，
/// 取消不提示，失败给出可读原因。
class MarketingPaymentService {
  MarketingPaymentService._();
  static final MarketingPaymentService instance = MarketingPaymentService._();

  static const String _merchantDisplayName = 'Synapses Global Assist Pty Ltd';
  static const String _merchantCountryCode = 'AU';

  /// 商品是否以人民币计价。后端商品币种有 CNY 也有 RMB 两种写法，都算；
  /// 支付宝（境内商户号）只对这类商品开放，后端下单时同样校验。
  static bool isRmb(String? currency) {
    final code = (currency ?? '').trim().toUpperCase();
    return code == 'CNY' || code == 'RMB';
  }

  /// [currency] 传商品币种，决定是否展示支付宝入口。
  Future<void> handlePurchase({
    required BuildContext context,
    required dynamic products,
    required String companyId,
    String? points,
    String? currency,
  }) async {
    final api = getIt<ApiProvider>();
    if (api.userProvider.user == null) {
      await HttpExceptionNotifyUser.showInfo(S.of(context).relogin);
      return;
    }

    await showModalBottomSheet<void>(
      backgroundColor: Colors.white,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => MarketingPaymentBottomSheet(
        parentContext: context,
        products: products,
        companyId: companyId,
        points: points,
        currency: currency,
      ),
    );
  }

  /// 向后端下预订单并创建 Stripe PaymentIntent。
  /// 非 200 抛 [MarketingPaymentException]（带后端 message），返回体不完整抛 [FormatException]。
  Future<MarketingPaymentIntent> createPaymentIntent({
    required MarketingPaymentMethod method,
    required dynamic products,
    required String companyId,
    String? points,
  }) async {
    final decoded = await _postOrder('/order/payment/intent', method, products, companyId, points);
    return MarketingPaymentIntent.fromJson(decoded, method);
  }

  /// 向后端下预订单并取支付宝签名串（`POST /order/alipay/payload`）。
  /// 非 200 抛 [MarketingPaymentException]（带后端 message，如非人民币商品被拒），
  /// 返回体不完整抛 [FormatException]。
  Future<MarketingAlipayPayload> createAlipayPayload({
    required dynamic products,
    required String companyId,
    String? points,
  }) async {
    final decoded = await _postOrder('/order/alipay/payload', MarketingPaymentMethod.alipay, products, companyId, points);
    return MarketingAlipayPayload.fromJson(decoded);
  }

  /// 下单类接口共用的请求体与错误处理；返回解析后的 JSON 对象
  Future<Map<String, dynamic>> _postOrder(
    String path,
    MarketingPaymentMethod method,
    dynamic products,
    String companyId,
    String? points,
  ) async {
    final user = getIt<ApiProvider>().userProvider.user;
    if (user == null) {
      throw MarketingPaymentException(S.current.relogin);
    }

    final url = Uri.parse('${getIt<ApiSettings>().marketingApiHost}$path');
    final body = jsonEncode({
      'companyId': companyId,
      'userId': user.id,
      'username': user.firstName,
      'email': user.email,
      'phone': user.phone,
      'products': products,
      'source': 'au',
      'points': points,
      'paymentMethod': method.apiValue,
    });

    final response = await http
        .post(url, headers: MarketingApi.headers(), body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw MarketingPaymentException(_errorMessage(response));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('unexpected response body');
    }
    return decoded;
  }

  /// 后端错误 message（422 时取第一条字段错误），拿不到时用通用文案
  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        final message = decoded['message']?.toString();
        if (message != null && message.isNotEmpty) return message;
        final errors = decoded['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return first.first.toString();
        }
      }
    } catch (_) {
      // body 不是 JSON（如网关 502 页面），落到通用文案
    }
    return S.current.somethingWentWrong;
  }

  /// 刷卡：Stripe PaymentSheet
  Future<bool> payWithCard({
    required BuildContext context,
    required dynamic products,
    required String companyId,
    String? points,
  }) async {
    return _pay(
      context: context,
      method: MarketingPaymentMethod.card,
      products: products,
      companyId: companyId,
      points: points,
      confirm: (intent) async {
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            merchantDisplayName: _merchantDisplayName,
            customerId: intent.customerId,
            paymentIntentClientSecret: intent.clientSecret,
            customerEphemeralKeySecret: intent.ephemeralKeySecret,
            applePay: const PaymentSheetApplePay(merchantCountryCode: _merchantCountryCode),
            googlePay: const PaymentSheetGooglePay(merchantCountryCode: _merchantCountryCode),
          ),
        );
        await Stripe.instance.presentPaymentSheet();
      },
    );
  }

  /// Apple Pay：Stripe Platform Pay，与 payment_bottom_sheet.dart 的做法一致。
  /// 调用方须先确认 iOS 且 `Stripe.instance.isPlatformPaySupported()`。
  Future<bool> payWithApplePay({
    required BuildContext context,
    required dynamic products,
    required String companyId,
    String? points,
  }) async {
    return _pay(
      context: context,
      method: MarketingPaymentMethod.applePay,
      products: products,
      companyId: companyId,
      points: points,
      confirm: (intent) async {
        await Stripe.instance.confirmPlatformPayPaymentIntent(
          clientSecret: intent.clientSecret,
          confirmParams: PlatformPayConfirmParams.applePay(
            applePay: ApplePayParams(
              merchantCountryCode: _merchantCountryCode,
              currencyCode: intent.applePayCurrencyCode,
              cartItems: [
                // 实际扣款金额以后端创建的 PaymentIntent（分）为准，这里仅为 Apple Pay 面板展示
                ApplePayCartSummaryItem.immediate(
                  label: _merchantDisplayName,
                  amount: intent.displayAmount,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 支付宝 App 支付（境内商户号、人民币结算），只对人民币计价的商品开放（见 [isRmb]，
  /// 后端下单时同样校验）。调用方须先确认设备已安装支付宝。
  /// 流程：loading → 后端下预订单并签名 → 关 loading → tobias 唤起支付宝 → 向后端确认 → 跳订单页。
  /// 返回约定与刷卡 / Apple Pay 相同；支付宝"处理中 / 结果未知"时也进订单页但提示稍后查看，
  /// 返回 false（后端 notify 会兜底把订单置为已支付）。
  Future<bool> payWithAlipay({
    required BuildContext context,
    required dynamic products,
    required String companyId,
    String? points,
  }) async {
    final payload = await _createWithLoading(
      context,
      MarketingPaymentMethod.alipay,
      () => createAlipayPayload(products: products, companyId: companyId, points: points),
    );
    if (payload == null) return false;

    final AlipayPayOutcome outcome;
    try {
      outcome = await AlipayService().payMarketingOrder(
        orderString: payload.orderString,
        outTradeNo: payload.outTradeNo,
      );
    } catch (e, stacktrace) {
      debugPrint('[MarketingPayment] alipay error: $e\n$stacktrace');
      await HttpExceptionNotifyUser.showError('Could not complete payment [23]: $e');
      return false;
    }

    switch (outcome.status) {
      case AlipayPayStatus.success:
        await _openOrders(context);
        return true;
      case AlipayPayStatus.pending:
        await HttpExceptionNotifyUser.showInfo(S.current.alipayPaymentPending);
        await _openOrders(context);
        return false;
      case AlipayPayStatus.cancelled:
        return false;
      case AlipayPayStatus.notInstalled:
        await HttpExceptionNotifyUser.showInfo(S.current.alipayNotInstalled);
        return false;
      case AlipayPayStatus.failed:
        debugPrint('[MarketingPayment] alipay failed: ${outcome.resultStatus} ${outcome.memo}');
        await HttpExceptionNotifyUser.showError(
          'Could not complete payment [24]: Alipay ${outcome.resultStatus} ${outcome.memo}'.trim(),
        );
        return false;
    }
  }

  /// 公共流程：loading → 建 intent → 关 loading → Stripe 确认 → 跳订单页。
  /// 建 intent 阶段的任何异常都不会唤起 Stripe；Stripe 取消静默返回 false。
  Future<bool> _pay({
    required BuildContext context,
    required MarketingPaymentMethod method,
    required dynamic products,
    required String companyId,
    required Future<void> Function(MarketingPaymentIntent intent) confirm,
    String? points,
  }) async {
    final intent = await _createWithLoading(
      context,
      method,
      () => createPaymentIntent(method: method, products: products, companyId: companyId, points: points),
    );
    if (intent == null) return false;

    try {
      await confirm(intent);
    } on StripeException catch (e, stacktrace) {
      if (e.error.code == FailureCode.Canceled) return false;
      // 给用户看 Stripe 的可读文案（如 Your card was declined），完整异常只打日志
      debugPrint('[MarketingPayment] ${method.apiValue} failed: $e\n$stacktrace');
      final reason = e.error.localizedMessage ?? e.error.message ?? e.error.code.name;
      await HttpExceptionNotifyUser.showError('Could not complete payment [21]: $reason');
      return false;
    } catch (e, stacktrace) {
      debugPrint('[MarketingPayment] ${method.apiValue} error: $e\n$stacktrace');
      await HttpExceptionNotifyUser.showError('Could not complete payment [22]: $e');
      return false;
    }

    // Stripe 已确认扣款。订单列表只显示已支付订单，而后端 webhook 可能延迟或收不到，
    // 所以这里主动让后端向 Stripe 核实并置为已支付；确认不了也照样进订单页，只是提示稍后查看
    final confirmed = await _confirmOrderPaid(context, intent);
    if (!confirmed) {
      await HttpExceptionNotifyUser.showInfo(S.current.alipayPaymentPending);
    }

    await _openOrders(context);
    return true;
  }

  /// 下单阶段的公共包装：带遮罩调 [create]，业务错误 / 网络异常都提示并返回 null，
  /// 不会唤起任何支付面板。返回前遮罩一定已关闭，否则会盖住随后弹出的支付面板。
  Future<T?> _createWithLoading<T>(
    BuildContext context,
    MarketingPaymentMethod method,
    Future<T> Function() create,
  ) async {
    await EasyLoading.show(status: S.of(context).loading, maskType: EasyLoadingMaskType.clear);
    try {
      return await create();
    } on MarketingPaymentException catch (e) {
      await HttpExceptionNotifyUser.showInfo(e.message);
      return null;
    } catch (e, stacktrace) {
      // 网络超时、JSON 解析、返回体缺字段等
      debugPrint('[MarketingPayment] create order (${method.apiValue}) failed: $e\n$stacktrace');
      await HttpExceptionNotifyUser.showInfo(S.current.somethingWentWrong);
      return null;
    } finally {
      await EasyLoading.dismiss();
    }
  }

  Future<void> _openOrders(BuildContext context) async {
    if (!context.mounted) return;
    await Navigator.push(context, MaterialPageRoute<void>(
      builder: (context) => Orders(),
    ),);
  }

  /// 让后端核实 Stripe intent 并把订单置为已支付（`POST /order/paid`，幂等）。
  /// 返回 false 表示后端暂时没能确认（网络、Stripe 不可达、还没结算），不代表扣款失败。
  Future<bool> _confirmOrderPaid(BuildContext context, MarketingPaymentIntent intent) async {
    final paymentIntentId = intent.paymentIntentId;
    if (paymentIntentId == null || paymentIntentId.isEmpty) {
      // 旧版后端不返回 intent id，只能等 webhook
      return false;
    }

    await EasyLoading.show(status: S.current.processing, maskType: EasyLoadingMaskType.clear);
    try {
      return await confirmOrderPaid(paymentIntentId);
    } catch (e, stacktrace) {
      debugPrint('[MarketingPayment] confirm order paid failed: $e\n$stacktrace');
      return false;
    } finally {
      await EasyLoading.dismiss();
    }
  }

  /// 单次确认请求：200 即已支付（含已被 webhook 先处理的情况），其它状态返回 false。
  /// 网络异常向上抛，由调用方决定提示。
  Future<bool> confirmOrderPaid(String paymentIntentId) async {
    final url = Uri.parse('${getIt<ApiSettings>().marketingApiHost}/order/paid');
    final response = await http
        .post(url, headers: MarketingApi.headers(), body: jsonEncode({'paymentIntentId': paymentIntentId}))
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 200) return true;
    debugPrint('[MarketingPayment] /order/paid ${response.statusCode}: ${response.body}');
    return false;
  }
}
