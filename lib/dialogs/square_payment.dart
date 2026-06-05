import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_colors.dart';
import '../generated/l10n.dart';
import '../main.dart';

class SquarePaymentDialog {
  static Future<void> showError(String message) => _show(message);

  static Future<void> showSuccess(String message) => _show(message);

  static Future<void> _show(String message) async {
    // App is resuming from Square POS via deeplink. Wait until the navigator
    // is attached and a frame has been built, otherwise the dialog can be
    // dropped silently before the UI is ready.
    final context = await _waitForNavigatorContext();
    if (context == null) return;

    // Clear any lingering loading overlay that may sit on top of the dialog.
    if (EasyLoading.isShow) {
      await EasyLoading.dismiss();
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Column(children: [
          Text(S.of(dialogContext).system_info, style: GoogleFonts.rubik(
            color: AppColors.k0cbcc5,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),),
          const Divider(),
        ],),
        content: Text(
          message,
          style: GoogleFonts.rubik(
            color: AppColors.k010101,
            fontSize: 15,
            fontWeight: FontWeight.normal,
          ),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(child: MaterialButton(
                color: AppColors.k0cbcc5,
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: Text(S.of(dialogContext).confirm, style: GoogleFonts.rubik(
                  color: AppColors.kffffff,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),),
              ),),
            ],
          ),
        ],
      ),
    );
  }

  /// Poll briefly for the root navigator's overlay context. When returning
  /// from an external app via deeplink the engine may deliver the URI before
  /// the first frame has been scheduled, which leaves [navigatorKey] in a
  /// transient state. Waiting for a post-frame callback (and retrying a few
  /// times) gives the framework a chance to settle.
  static Future<BuildContext?> _waitForNavigatorContext() async {
    for (var i = 0; i < 20; i++) {
      final completer = Completer<void>();
      SchedulerBinding.instance.addPostFrameCallback((_) => completer.complete());
      await completer.future;

      final state = navigatorKey.currentState;
      final ctx = state?.overlay?.context;
      if (ctx != null && ctx.mounted) return ctx;

      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    return null;
  }
}