/// Square 支付前后端协议
/// ─────────────────────────────────────────────────────────────────────────
///
/// 涉及两个接口：
///
/// 1) POST /api/v1/square/pre-order
///    用途：用户点"订阅"时调用，后端预生成订单。
///    Request body:
///      {
///        "userId":     "<string>",
///        "packageId":  "<string>",
///        "type":       "<string>"   // 业务类型：travel_care(默认) / call
///      }
///    Response (200):
///      {
///        "amount":     <int, 单位：分>,
///        "orderId":    "<string>"   // 前端会把它作为 state 传给 Square POS
///      }
///
/// 2) POST /api/v1/square/confirm-payment
///    用途：Square POS 回调到达后，前端把交易结果上报，后端把订单状态
///         置为 paid 并激活订阅。
///    Request body:
///      {
///        "order_id":                     "<string>",  // 对应 pre-order 的 orderId
///        "square_transaction_id":        "<string?>", // Square 服务端事务 id（联网刷卡时有）
///        "square_client_transaction_id": "<string?>", // 客户端事务 id（离线刷卡时有）
///        "raw":              h            { ... }      // Square 回调 data 原文（审计 / 排查用）
///      }
///    Response:
///      200  视为对账成功；前端会从未对账队列移除该订单。
///      408 / 425 / 429 / 5xx  视为"可重试"，前端按指数退避重试，本地保留记录。
///      其他 4xx  视为"业务终止"，前端不再重试，但本地记录仍会保留到 7 天后过期。
///
/// 关键要求（后端必须做的）
/// ─────────────────────────────────────────────────────────────────────────
///
/// A. **幂等性**
///    同一个 (order_id, square_transaction_id) 重复调用必须返回 200，且只
///    入账一次。前端在以下场景会重复 POST：
///      - 用户点支付成功弹框前网络抖动 → 接口内置 3 次重试
///      - app 被系统杀掉冷启动后 → 启动恢复阶段 reconcile
///      - 回到前台 → AppLifecycleObserver 触发 reconcile
///    建议用 square_transaction_id 做唯一约束；离线刷卡可用 client_transaction_id。
///
/// B. **从 order_id 自行解析 user_id / package_id**
///    confirm-payment body 故意不带 user_id / package_id，避免前端伪造或字段
///    漂移。后端用 pre-order 时落库的 orderId → (user_id, package_id, amount)
///    关系即可还原。
///
/// C. **错误码语义稳定**
///    凡是希望前端不再重试的业务错误（例如订单已取消、订单不存在、套餐已下架），
///    应返回 4xx（非 408/425/429）。需要前端重试的瞬时故障，应返回 5xx 或 429。
///
/// D. **超时建议 < 15s**
///    前端单次请求 timeout 是 15 秒。如果后端处理 Square 服务端校验耗时较长，
///    应改为异步落账 + 立即返回 200，避免前端超时引发重复重试。
///
/// 前端的容错（已实现）
/// ─────────────────────────────────────────────────────────────────────────
///
///  - charge() 启动 Square POS 前先把订单写本地 SharedPreferences 队列
///  - _onUri 收到回调时，无论 app 是冷启动还是热恢复，都会先广播给 queue
///  - confirmPayment 内置 3 次指数退避重试（1s / 3s / 6s）
///  - 启动时 / 回到前台时 reconcilePendingPayments 扫描队列重试未对账
///  - 队列记录 7 天过期，避免脏数据无限堆积

import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../api_utils/api_provider.dart';
import '../api_utils/http_exception.dart';
import '../dialogs/square_payment.dart';
import '../generated/l10n.dart';
import '../store/home/home_screen_store.dart';
import '../utils/configure_dependencies.dart';
import 'square_payment_queue.dart';
import 'square_payment_service.dart';

class PaymentBackend {
  PaymentBackend._();

  // ────────────────────────────────────────────────────────────────────────
  // 对账（确认订单状态）
  // ────────────────────────────────────────────────────────────────────────

  /// 把 Square 交易上报给后端进行对账，带指数退避重试。
  /// 返回 true 表示对账成功；false 表示已耗尽重试仍然失败。
  ///
  /// 注意：transactionId 作为天然的幂等键，后端应做去重。前端这边只要本地
  /// 队列还存在记录，启动恢复时会再次重试。
  static Future<bool> confirmPayment({
    required String orderId,
    required SquarePaymentResult result,
    int maxAttempts = 3,
  }) async {
    final api = getIt<ApiProvider>();

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final resp = await http.post(
          Uri.parse('${api.baseUrl}/api/v1/square/confirm-payment'),
          headers: {
            'Content-Type': 'application/json',
            'x-user-id': api.userProvider.user!.id.toString(),
            'x-access-token': api.userProvider.user!.accessToken!,
            'x-api-key': api.apiKey,
          },
          body: jsonEncode({
            'order_id': orderId,
            'square_transaction_id': result.transactionId,
            'square_client_transaction_id': result.clientTransactionId,
            'raw': result.raw,
          }),
        ).timeout(const Duration(seconds: 15));

        if (resp.statusCode == 200) return true;

        // 4xx（除 408/429）一般是业务错误，重试也没意义。
        final code = resp.statusCode;
        final isRetriable =
            code == 408 || code == 425 || code == 429 || code >= 500;
        debugPrint('[SquarePay] confirmPayment attempt=$attempt '
            'status=$code body=${resp.body} retriable=$isRetriable');
        if (!isRetriable) return false;
      } catch (e) {
        debugPrint('[SquarePay] confirmPayment attempt=$attempt error: $e');
      }

      if (attempt < maxAttempts) {
        // 指数退避：1s → 3s → 6s
        final backoff = Duration(seconds: attempt * attempt + 1);
        await Future<void>.delayed(backoff);
      }
    }
    return false;
  }

  // ────────────────────────────────────────────────────────────────────────
  // 订阅流程入口
  // ────────────────────────────────────────────────────────────────────────

  /// 返回 true 表示用户完成支付，调用方应据此刷新页面。
  ///
  /// [type] 区分预下单的业务类型：travel_care_packages 页面用默认值
  /// `travel_care`；additional_services 页面传 `call`。后端据此决定
  /// 用哪张表把 orderId 还原成 (user_id, package_id, amount)。
  static Future<bool> subscribeWithSquare(
    BuildContext context, {
    required String packageId,
    String type = 'travel_care',
  }) async {
    final api = getIt<ApiProvider>();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'x-user-id': api.userProvider.user!.id.toString(),
      'x-access-token': api.userProvider.user!.accessToken!,
      'x-api-key': api.apiKey,
    };

    final position = await determinePosition(desiredAccuracy: LocationAccuracy.medium);
    final countryCode = await getCountryCodeFromLocation(position);

    final data = <String, dynamic>{
      'userId': api.userProvider.user!.id.toString(),
      'packageId': packageId,
      'type': type,
      'countryCode': countryCode
    };

    await EasyLoading.show(
      status: 'Loading...',
      maskType: EasyLoadingMaskType.black,
    );

    try {
      final url = Uri.parse(api.baseUrl + '/api/v1/square/pre-order');
      final response = await http.post(url, headers: headers, body: jsonEncode(data));
      await EasyLoading.dismiss();

      if (response.statusCode != 200) {
        await HttpExceptionNotifyUser.showInfo(S.of(context).somethingWentWrong);
        return false;
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final amount = (responseData['amount'] as num).toInt();
      final orderId = responseData['orderId'].toString();

      final result = await SquarePaymentService.instance.charge(
        amountCents: amount,
        orderId: orderId,
        packageId: packageId,
        note: 'Order $orderId',
      );

      if (!result.success) {
        // 用户取消 / Square POS 报错：队列里这条无需重试，直接清掉。
        await SquarePaymentQueue.instance.remove(orderId);
        await SquarePaymentDialog.showError(result.errorMessage ?? 'unknown error');
        return false;
      }

      // 1. 先弹框提示支付成功（等用户点确认）
      await SquarePaymentDialog.showSuccess('Pay successfully.');

      // 2. 再调用后端接口更新订单状态（内置重试）
      final confirmed = await confirmPayment(orderId: orderId, result: result);

      if (confirmed) {
        // 对账成功，从未对账队列移除
        await SquarePaymentQueue.instance.remove(orderId);
      } else {
        // 保留队列记录 —— 启动 / 回到前台时会自动 reconcile
        await SquarePaymentQueue.instance.upsert(PendingSquarePayment(
          orderId: orderId,
          packageId: packageId,
          amountCents: amount,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          stage: SquarePaymentStage.callbackReceived,
          transactionId: result.transactionId,
          clientTransactionId: result.clientTransactionId,
          rawCallback: result.raw,
          callbackSuccess: true,
        ));
        await SquarePaymentDialog.showError(
          '支付已成功（交易号 ${result.transactionId}），订单状态同步稍后会自动重试。',
        );
      }

      // 3. 返回 true，由调用方刷新页面
      return true;
    } catch (e, st) {
      debugPrint('[SquarePay] subscribeWithSquare error: $e\n$st');
      await EasyLoading.dismiss();
      await SquarePaymentDialog.showError(S.of(context).somethingWentWrong);
      return false;
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // 启动恢复 / 重试
  // ────────────────────────────────────────────────────────────────────────

  static bool _reconciling = false;

  /// 扫描本地未对账队列，逐条尝试 confirmPayment。
  /// 由 main.dart 在 app 启动 / 回到前台时调用。
  /// 用 [_reconciling] 串行化，避免并发重复对账。
  static Future<void> reconcilePendingPayments() async {
    if (_reconciling) return;
    _reconciling = true;
    try {
      // 用户未登录时不动 —— 没有 access token 没法调对账接口。
      final api = getIt<ApiProvider>();
      if (api.userProvider.user?.accessToken == null) return;

      final pendings = await SquarePaymentQueue.instance.pruneAndList();
      for (final p in pendings) {
        // 只有真正收到 Square 回调且支付成功的才需要对账
        if (p.stage != SquarePaymentStage.callbackReceived) continue;
        if (p.callbackSuccess != true) {
          // 收到回调但 Square 报失败（用户在 POS 取消等）—— 不需要对账，直接清掉
          await SquarePaymentQueue.instance.remove(p.orderId);
          continue;
        }
        if (p.transactionId == null) {
          await SquarePaymentQueue.instance.remove(p.orderId);
          continue;
        }

        debugPrint('[SquarePay] reconciling orderId=${p.orderId}');
        final confirmed = await confirmPayment(
          orderId: p.orderId,
          result: SquarePaymentResult(
            success: true,
            transactionId: p.transactionId,
            clientTransactionId: p.clientTransactionId,
            raw: p.rawCallback ?? {},
          ),
        );
        if (confirmed) {
          await SquarePaymentQueue.instance.remove(p.orderId);
        }
        // 失败就保留，下次启动 / 回前台再重试，pruneAndList 会兜底清理过期
      }
    } finally {
      _reconciling = false;
    }
  }

  /// 监听 SquarePaymentService 的回调广播，把结果落到本地队列。
  /// 这样即使 _pending 是 null（冷启动 / 进程被杀），结果也不会丢。
  ///
  /// 由 main.dart 在 init 时启动一次即可。
  static StreamSubscription<SquarePaymentResult>? _resultSub;

  static void attachQueueListener() {
    _resultSub?.cancel();
    _resultSub = SquarePaymentService.instance.onResult.listen((result) async {
      final orderId = result.orderId;
      if (orderId == null || orderId.isEmpty) return;

      final existing = await SquarePaymentQueue.instance.findByOrderId(orderId);
      // charge() 时已经入队过；如果 existing 是 null 说明是冷启动后队列被
      // 清了或顺序异常，这种情况下我们也尽量保留信息。
      final updated = PendingSquarePayment(
        orderId: orderId,
        packageId: existing?.packageId ?? '',
        amountCents: existing?.amountCents ?? 0,
        createdAt: existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
        stage: SquarePaymentStage.callbackReceived,
        transactionId: result.transactionId,
        clientTransactionId: result.clientTransactionId,
        rawCallback: result.raw,
        callbackSuccess: result.success,
        callbackErrorCode: result.errorCode,
        callbackErrorMessage: result.errorMessage,
      );
      await SquarePaymentQueue.instance.upsert(updated);

      // 写入完成后主动触发一次 reconcile —— 覆盖"冷启动 URI 在监听器订阅
      // 之后才落库，比首次启动调用的 reconcile 跑得晚"这种时序竞态。
      // reconcile 内部有 _reconciling 锁，重复触发是安全的。
      if (result.success) {
        unawaited(reconcilePendingPayments());
      }
    });
  }
}