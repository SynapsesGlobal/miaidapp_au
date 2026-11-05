import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/services/marketing_api.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:tobias/tobias.dart';

/// 支付宝 App 支付（境内商户号）。药房订单走 createPharmacyOrder，旅行套餐 / 加购问诊走 createPackageOrder，
/// MiSpace 商品订单由 marketing_payment_service 向 miaid_mispace 下单后交给 [payMarketingOrder]。
///
/// 流程：后端生成签名后的
/// orderString → tobias 唤起支付宝 App → 拿到 resultStatus →
/// `GET /api/v1/alipay/query`（MiSpace 为 mispace 的 `POST /order/alipay/query`）向后端
/// （后端再向支付宝 trade.query）确认是否已支付。
/// 后端另有 notify 异步回调兜底落库，客户端查询只用来决定当下的 UI 反馈。
///
/// 不走 swagger 生成的客户端：这三个接口不在 swagger 里，而且 build_runner 会覆盖
/// 手工补丁（见 docs/apple-pay.md 里的说明），这里用 http 直连。
class AlipayService {
  AlipayService({Tobias? tobias, http.Client? client, ApiProvider? api})
      : _tobias = tobias ?? Tobias(),
        _client = client ?? http.Client(),
        _api = api ?? getIt<ApiProvider>();

  final Tobias _tobias;
  final http.Client _client;
  final ApiProvider _api;

  static const _timeout = Duration(seconds: 30);

  /// 9000 之后向后端确认支付状态的轮询次数与间隔：
  /// 支付宝返回 9000 时 trade.query 通常已经是 TRADE_SUCCESS，偶尔有几秒延迟
  static const _verifyAttempts = 3;
  static const _verifyInterval = Duration(seconds: 2);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'x-access-token': _api.userProvider.user?.accessToken ?? '',
        'x-api-key': _api.apiKey,
      };

  /// 设备是否安装了支付宝 App。tobias.pay 依赖支付宝 App，未安装时不展示入口
  Future<bool> get isInstalled async {
    try {
      return await _tobias.isAliPayInstalled;
    } catch (_) {
      return false;
    }
  }

  /// 为药房订单发起支付宝支付。
  /// [currency] 传订单币种（AU 为 AUD），后端按配置汇率换算成人民币金额下单。
  /// [subject] 支付宝收银台展示的商品标题。
  Future<AlipayPayOutcome> payPharmacyOrder({
    required String orderId,
    required String currency,
    required String subject,
  }) async {
    if (!await isInstalled) {
      return const AlipayPayOutcome(AlipayPayStatus.notInstalled);
    }

    final createResp = await _client
        .post(
          Uri.parse('${_api.baseUrl}/api/v1/alipay/createPharmacyOrder'),
          headers: _headers,
          body: jsonEncode({'orderId': orderId, 'currency': currency, 'subject': subject}),
        )
        .timeout(_timeout);
    if (createResp.statusCode != 200) {
      throw AlipayException('create order failed: ${createResp.statusCode} ${createResp.body}');
    }
    final data = jsonDecode(createResp.body) as Map<String, dynamic>;
    final orderString = data['orderString'] as String?;
    final outTradeNo = data['outTradeNo'] as String?;
    if (orderString == null || orderString.isEmpty || outTradeNo == null || outTradeNo.isEmpty) {
      throw AlipayException('create order failed: invalid response ${createResp.body}');
    }

    return _payAndVerify(orderString, outTradeNo);
  }

  /// 为旅行套餐 / 加购问诊发起支付宝支付。
  /// [packageType] 与 Stripe 路径一致：travel-packages / calls；[currency] 必须是人民币，后端会再校验。
  /// 成功时 [AlipayPayOutcome.paymentId] 为后端 payments.id，可交给 recheckActiveSubscription 轮询。
  Future<AlipayPayOutcome> payPackage({
    required String packageId,
    required String packageType,
    required String currency,
    required String countryCode,
  }) async {
    if (!await isInstalled) {
      return const AlipayPayOutcome(AlipayPayStatus.notInstalled);
    }

    final createResp = await _client
        .post(
          Uri.parse('${_api.baseUrl}/api/v1/alipay/createPackageOrder'),
          headers: _headers,
          body: jsonEncode({
            'packageId': packageId,
            'packageType': packageType,
            'currency': currency,
            'countryCode': countryCode,
          }),
        )
        .timeout(_timeout);
    if (createResp.statusCode != 200) {
      throw AlipayException('create package order failed: ${createResp.statusCode} ${createResp.body}');
    }
    final data = jsonDecode(createResp.body) as Map<String, dynamic>;
    final orderString = data['orderString'] as String?;
    final outTradeNo = data['outTradeNo'] as String?;
    final paymentId = (data['paymentId'] as num?)?.toInt();
    if (orderString == null || orderString.isEmpty || outTradeNo == null || outTradeNo.isEmpty) {
      throw AlipayException('create package order failed: invalid response ${createResp.body}');
    }

    final outcome = await _payAndVerify(orderString, outTradeNo);
    return outcome.copyWith(paymentId: paymentId);
  }

  /// 为 MiSpace（miaid_mispace）商品订单发起支付宝支付。
  /// 预订单和签名串由 MarketingPaymentService 调 mispace `POST /order/alipay/payload` 取得（那里会先校验
  /// 商品以人民币计价），这里只负责唤起支付宝并向 mispace `POST /order/alipay/query` 确认支付状态：
  /// mispace 与 miaid.com 是两套后端、两套鉴权头，不能复用上面的 query。
  Future<AlipayPayOutcome> payMarketingOrder({
    required String orderString,
    required String outTradeNo,
  }) async {
    if (!await isInstalled) {
      return const AlipayPayOutcome(AlipayPayStatus.notInstalled);
    }
    return _payAndVerify(orderString, outTradeNo, verify: _verifyMarketingPaidOnServer);
  }

  /// 唤起支付宝并把 SDK 结果映射为统一状态；9000/8000/6004 都向后端确认一次实际支付状态。
  /// [verify] 为向哪个后端确认，默认 miaid.com 的 /alipay/query。
  Future<AlipayPayOutcome> _payAndVerify(
    String orderString,
    String outTradeNo, {
    Future<bool> Function(String outTradeNo)? verify,
  }) async {
    final payResult = await _tobias.pay(orderString);
    final resultStatus = payResult['resultStatus']?.toString() ?? '';
    final memo = payResult['memo']?.toString() ?? '';

    switch (resultStatus) {
      case '9000': // 支付成功
      case '8000': // 正在处理中（支付结果以服务端异步通知为准）
      case '6004': // 处理结果未知（可能已成功）
        final paid = await (verify ?? _verifyPaidOnServer)(outTradeNo);
        return AlipayPayOutcome(
          paid ? AlipayPayStatus.success : AlipayPayStatus.pending,
          resultStatus: resultStatus,
          memo: memo,
          outTradeNo: outTradeNo,
        );
      case '6001': // 用户中途取消
        return AlipayPayOutcome(AlipayPayStatus.cancelled, resultStatus: resultStatus, memo: memo, outTradeNo: outTradeNo);
      default: // 4000 失败 / 5000 重复请求 / 6002 网络错误 / 其它
        return AlipayPayOutcome(AlipayPayStatus.failed, resultStatus: resultStatus, memo: memo, outTradeNo: outTradeNo);
    }
  }

  /// miaid.com：药房 / 套餐订单
  Future<bool> _verifyPaidOnServer(String outTradeNo) => _pollPaid(() async {
        final uri = Uri.parse('${_api.baseUrl}/api/v1/alipay/query').replace(queryParameters: {'outTradeNo': outTradeNo});
        final resp = await _client.get(uri, headers: _headers).timeout(_timeout);
        return _isPaidResponse(resp);
      });

  /// miaid_mispace：MiSpace 商品订单
  Future<bool> _verifyMarketingPaidOnServer(String outTradeNo) => _pollPaid(() async {
        final uri = Uri.parse('${getIt<ApiSettings>().marketingApiHost}/order/alipay/query');
        final resp = await _client
            .post(uri, headers: MarketingApi.headers(), body: jsonEncode({'outTradeNo': outTradeNo}))
            .timeout(_timeout);
        return _isPaidResponse(resp);
      });

  static bool _isPaidResponse(http.Response resp) {
    if (resp.statusCode != 200) return false;
    final data = jsonDecode(resp.body);
    return data is Map && data['paid'] == true;
  }

  /// 最多查 [_verifyAttempts] 次，任一次确认已支付即返回 true
  Future<bool> _pollPaid(Future<bool> Function() once) async {
    for (var attempt = 0; attempt < _verifyAttempts; attempt++) {
      if (attempt > 0) await Future<void>.delayed(_verifyInterval);
      try {
        if (await once()) return true;
      } catch (_) {
        // 网络抖动继续重试；用尽次数后按 pending 处理，由后端 notify 兜底
      }
    }
    return false;
  }
}

enum AlipayPayStatus {
  /// 支付宝返回成功且后端已确认已支付
  success,

  /// 支付宝已受理或结果未知，后端暂未确认；以后端异步通知为准
  pending,

  /// 用户主动取消
  cancelled,

  /// 支付失败
  failed,

  /// 设备未安装支付宝 App
  notInstalled,
}

class AlipayPayOutcome {
  const AlipayPayOutcome(this.status, {this.resultStatus = '', this.memo = '', this.outTradeNo = '', this.paymentId});

  final AlipayPayStatus status;

  /// 后端 payments.id（套餐 / 服务支付时由 createPackageOrder 返回），用于轮询支付状态；药房订单为 null
  final int? paymentId;

  /// 支付宝 SDK 原始 resultStatus（9000/8000/4000/5000/6001/6002/6004）
  final String resultStatus;
  final String memo;
  final String outTradeNo;

  bool get success => status == AlipayPayStatus.success;

  AlipayPayOutcome copyWith({int? paymentId}) => AlipayPayOutcome(
        status,
        resultStatus: resultStatus,
        memo: memo,
        outTradeNo: outTradeNo,
        paymentId: paymentId ?? this.paymentId,
      );
}

class AlipayException implements Exception {
  AlipayException(this.message);

  final String message;

  @override
  String toString() => 'AlipayException: $message';
}
