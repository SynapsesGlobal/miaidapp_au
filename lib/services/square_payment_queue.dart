/// 未对账 Square 支付的本地队列。
///
/// 用于覆盖以下场景：
/// 1. app 在 Square POS 支付期间被系统杀掉（iPad 内存压力下常见），冷启动
///    回来时 [SquarePaymentService] 的 `_pending` 是 null，URI 会被丢弃，
///    需要持久化等待启动恢复。
/// 2. confirmPayment 接口抖动或瞬时失败，需要保留记录稍后重试。
///
/// 状态机：
///   launched (charge 发起)
///     → callbackReceived (Square POS 回调到达，可能成功也可能失败)
///       → confirming (正在调后端对账)
///         → 成功后从队列移除 / 失败保留，等下次 reconcile
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SquarePaymentStage { launched, callbackReceived }

class PendingSquarePayment {
  PendingSquarePayment({
    required this.orderId,
    required this.packageId,
    required this.amountCents,
    required this.createdAt,
    this.stage = SquarePaymentStage.launched,
    this.transactionId,
    this.clientTransactionId,
    this.rawCallback,
    this.callbackSuccess,
    this.callbackErrorCode,
    this.callbackErrorMessage,
  });

  final String orderId;
  final String packageId;
  final int amountCents;
  final int createdAt;

  SquarePaymentStage stage;
  String? transactionId;
  String? clientTransactionId;
  Map<String, dynamic>? rawCallback;
  bool? callbackSuccess;
  String? callbackErrorCode;
  String? callbackErrorMessage;

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'packageId': packageId,
        'amountCents': amountCents,
        'createdAt': createdAt,
        'stage': stage.name,
        'transactionId': transactionId,
        'clientTransactionId': clientTransactionId,
        'rawCallback': rawCallback,
        'callbackSuccess': callbackSuccess,
        'callbackErrorCode': callbackErrorCode,
        'callbackErrorMessage': callbackErrorMessage,
      };

  static PendingSquarePayment fromJson(Map<String, dynamic> json) {
    final stageName = json['stage'] as String? ?? SquarePaymentStage.launched.name;
    final stage = SquarePaymentStage.values.firstWhere(
      (s) => s.name == stageName,
      orElse: () => SquarePaymentStage.launched,
    );
    return PendingSquarePayment(
      orderId: json['orderId'] as String,
      packageId: json['packageId'] as String,
      amountCents: (json['amountCents'] as num).toInt(),
      createdAt: (json['createdAt'] as num).toInt(),
      stage: stage,
      transactionId: json['transactionId'] as String?,
      clientTransactionId: json['clientTransactionId'] as String?,
      rawCallback: (json['rawCallback'] as Map?)?.cast<String, dynamic>(),
      callbackSuccess: json['callbackSuccess'] as bool?,
      callbackErrorCode: json['callbackErrorCode'] as String?,
      callbackErrorMessage: json['callbackErrorMessage'] as String?,
    );
  }
}

class SquarePaymentQueue {
  SquarePaymentQueue._();
  static final instance = SquarePaymentQueue._();

  static const _prefsKey = 'square_pending_payments_v1';
  // 超过 7 天的记录在恢复时直接丢弃 —— 用户已经放弃，再对账也意义不大
  static const _maxAgeMillis = 7 * 24 * 60 * 60 * 1000;

  final _lock = _AsyncLock();

  Future<List<PendingSquarePayment>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PendingSquarePayment.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } catch (e) {
      debugPrint('[SquareQueue] decode error, resetting: $e');
      await prefs.remove(_prefsKey);
      return [];
    }
  }

  Future<PendingSquarePayment?> findByOrderId(String orderId) async {
    final all = await getAll();
    for (final p in all) {
      if (p.orderId == orderId) return p;
    }
    return null;
  }

  Future<void> upsert(PendingSquarePayment payment) async {
    await _lock.run(() async {
      final all = await getAll();
      final idx = all.indexWhere((p) => p.orderId == payment.orderId);
      if (idx >= 0) {
        all[idx] = payment;
      } else {
        all.add(payment);
      }
      await _persist(all);
    });
  }

  Future<void> remove(String orderId) async {
    await _lock.run(() async {
      final all = await getAll();
      all.removeWhere((p) => p.orderId == orderId);
      await _persist(all);
    });
  }

  /// 丢弃过期记录，返回剩余的（按创建时间正序）。启动恢复时调用。
  Future<List<PendingSquarePayment>> pruneAndList() async {
    return _lock.run(() async {
      final all = await getAll();
      final now = DateTime.now().millisecondsSinceEpoch;
      all.removeWhere((p) => now - p.createdAt > _maxAgeMillis);
      all.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      await _persist(all);
      return all;
    });
  }

  Future<void> _persist(List<PendingSquarePayment> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }
}

/// 串行化所有写操作，避免 read-modify-write 竞态（_onUri 可能和 reconcile
/// 同时触发写）。
class _AsyncLock {
  Future<void> _last = Future.value();

  Future<T> run<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _last = _last.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }
}