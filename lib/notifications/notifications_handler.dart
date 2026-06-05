import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/store/user/calling/ongoing_call_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';

abstract class NotificationHandler {

  final store = getIt<OngoingCallStore>();
  final user = getIt<UserProvider>();

  BuildContext? context;
  bool isSetup = false;

  Future<void> setup(BuildContext contextParam);
}
