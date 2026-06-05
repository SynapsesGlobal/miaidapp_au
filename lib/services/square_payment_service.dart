import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/square_config.dart';
import 'square_payment_queue.dart';

/// 支付结果
class SquarePaymentResult {
  final bool success;
  final String? transactionId;
  final String? clientTransactionId;
  final String? orderId;
  final String? errorCode;
  final String? errorMessage;
  final Map<String, dynamic> raw;

  SquarePaymentResult({
    required this.success,
    this.transactionId,
    this.clientTransactionId,
    this.orderId,
    this.errorCode,
    this.errorMessage,
    required this.raw,
  });

  factory SquarePaymentResult.fromCallback(Uri uri) {
    final dataParam = uri.queryParameters['data'];
    if (dataParam == null) {
      return SquarePaymentResult(
        success: false,
        errorCode: 'no_data',
        errorMessage: '回调缺少 data 参数',
        raw: {},
      );
    }

    try {
      final data = jsonDecode(dataParam) as Map<String, dynamic>;
      final errorCode = data['error_code'] as String?;
      final hasError = errorCode != null && errorCode.isNotEmpty;
      return SquarePaymentResult(
        success: !hasError,
        transactionId: data['transaction_id'] as String?,
        clientTransactionId: data['client_transaction_id'] as String?,
        orderId: data['state'] as String?,
        errorCode: errorCode,
        errorMessage: _humanMessage(errorCode),
        raw: data,
      );
    } catch (e) {
      return SquarePaymentResult(
        success: false,
        errorCode: 'parse_error',
        errorMessage: '回调数据解析失败：$e',
        raw: {},
      );
    }
  }

  static String? _humanMessage(String? code) {
    const map = {
      'payment_canceled': 'Customer canceled the payment.',
      'unsupported_tender_type': 'Unsupported payment method.',
      'invalid_request': 'Invalid request parameters.',
      'no_network_connection': 'No network connection.',
      'not_logged_in': 'Square POS app not logged in.',
      'app_not_installed': 'Square POS app not installed.',
      'amount_invalid_format': 'Invalid amount format.',
      'invalid_currency': 'Unsupported currency.',
    };
    return code == null ? null : (map[code] ?? code);
  }
}

/// 单例
class SquarePaymentService {
  SquarePaymentService._();
  static final instance = SquarePaymentService._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  Completer<SquarePaymentResult>? _pending;

  /// 当收到 Square 回调 URI 时触发的旁路。无论 [_pending] 是否存在都会广播。
  /// 持久化层订阅它，把回调结果写入本地，供冷启动 / 重启场景使用。
  final _onResultCtrl = StreamController<SquarePaymentResult>.broadcast();
  Stream<SquarePaymentResult> get onResult => _onResultCtrl.stream;

  /// app 启动时调用
  Future<void> init() async {
    await _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
      _onUri,
      onError: (Object e) {
        debugPrint('[SquarePay] uriLinkStream error: $e');
        _pending?.complete(SquarePaymentResult(
          success: false,
          errorCode: 'link_error',
          errorMessage: e.toString(),
          raw: {},
        ));
        _pending = null;
      },
    );

    // 冷启动场景：app 被系统杀掉后由 Square POS 通过 deeplink 重新唤起 ——
    // 这种情况下 URI 不会通过 uriLinkStream 触发，需要主动取一次。
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        debugPrint('[SquarePay] cold-start URI: $initial');
        _onUri(initial);
      }
    } catch (e) {
      debugPrint('[SquarePay] getInitialAppLink error: $e');
    }
  }

  void dispose() {
    _sub?.cancel();
    _onResultCtrl.close();
  }

  void _onUri(Uri uri) {
    debugPrint('[SquarePay] received URI: $uri');
    if (uri.scheme != SquareConfig.callbackScheme) return;
    final result = SquarePaymentResult.fromCallback(uri);
    debugPrint('[SquarePay] parsed result: success=${result.success} '
        'errorCode=${result.errorCode} txn=${result.transactionId}');

    // 先广播给持久化层，无论 _pending 是否存在都要落地，避免冷启动 / 进程
    // 被杀 / 重复触发时丢失对账线索。
    if (!_onResultCtrl.isClosed) {
      _onResultCtrl.add(result);
    }

    if (_pending == null) {
      debugPrint('[SquarePay] no pending completer; result handed off to queue');
      return;
    }
    _pending!.complete(result);
    _pending = null;
  }

  /// 发起一笔刷卡支付
  ///
  /// [amountCents] 金额（分），$1.00 = 100
  /// [orderId] 你的订单号（通过 state 字段原样回传，用于对账）
  /// [packageId] 业务侧用于关联订阅套餐
  /// [note] 收据备注
  Future<SquarePaymentResult> charge({
    required int amountCents,
    required String orderId,
    required String packageId,
    String? note,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    if (_pending != null) {
      debugPrint('[SquarePay] stale pending completer detected; resetting');
      _pending = null;
    }

    // 在外部 app 接管前先入队，确保 charge 后即使 Flutter 被杀也能恢复。
    await SquarePaymentQueue.instance.upsert(PendingSquarePayment(
      orderId: orderId,
      packageId: packageId,
      amountCents: amountCents,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      stage: SquarePaymentStage.launched,
    ));

    final data = {
      'amount_money': {
        'amount': amountCents,
        'currency_code': SquareConfig.currencyCode,
      },
      'callback_url': SquareConfig.callbackUrl,
      'client_id': SquareConfig.applicationId,
      'version': '1.3',
      'notes': note ?? 'Order $orderId',
      'options': {
        'supported_tender_types': ['CREDIT_CARD'],
        'skip_receipt': false,
        'auto_return': true,
      },
      'state': orderId,
      'reference_id': orderId
    };

    final encoded = Uri.encodeComponent(jsonEncode(data));
    final uri = Uri.parse('square-commerce-v1://payment/create?data=$encoded');

    if (!await canLaunchUrl(uri)) {
      await SquarePaymentQueue.instance.remove(orderId);
      return SquarePaymentResult(
        success: false,
        errorCode: 'app_not_installed',
        errorMessage: 'Square POS app not installed or unauthorized.',
        raw: {},
      );
    }

    _pending = Completer<SquarePaymentResult>();

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _pending = null;
      await SquarePaymentQueue.instance.remove(orderId);
      return SquarePaymentResult(
        success: false,
        errorCode: 'launch_failed',
        errorMessage: 'Cannot initiate Square POS app',
        raw: {},
      );
    }

    try {
      return await _pending!.future.timeout(timeout);
    } on TimeoutException {
      _pending = null;
      return SquarePaymentResult(
        success: false,
        errorCode: 'timeout',
        errorMessage: 'Overtime',
        raw: {},
      );
    }
  }
}