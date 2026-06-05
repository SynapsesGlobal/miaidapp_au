// TODO Temporarily Disable no-sound-null-safety

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:logging/logging.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/services/square_payment_backend_service.dart';
import 'package:miaid/services/square_payment_service.dart';
import 'package:miaid/utils/configure_dependencies.dart';

import 'main.dart';

void setLoggingLevelAll() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies(prod.name);

  await initFirebase();

  /// square payment: 监听器必须在 init 之前挂上，否则 getInitialAppLink()
  /// 触发的 _onUri 会广播到没有订阅者的 stream，冷启动场景丢失结果。
  PaymentBackend.attachQueueListener();
  await SquarePaymentService.instance.init();
  unawaited(PaymentBackend.reconcilePendingPayments());

  await runAppFromEnvironment();

  setupFlutterLocalNotifications();

  setLoggingLevelAll();

  incomingLinkHandler();
}
