import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_sms/flutter_sms.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/config/app_colors.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/invitation_service.dart';
import 'package:url_launcher/url_launcher.dart';

const _appLink = 'https://www.mi-aid.com.au/';

enum _InviteChannel { sms, email }

/// 弹出「邀请好友」选择框（短信 / 邮件），选定后拉取邀请码并打开系统短信或邮件。
/// 返回是否已打开分享；用户取消或邀请码拉取失败返回 false。
/// 抽屉和「我的」页共用，所以只依赖传入的 context 取文案，不做任何页面跳转。
Future<bool> showInviteFriendsSheet(BuildContext context) async {
  final l10n = S.of(context);
  final channel = await showCupertinoModalPopup<_InviteChannel>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      message: Text(
        l10n.inviteFriends,
        style: TextStyle(fontSize: 13, color: AppColors.k8f8e94),
      ),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext, _InviteChannel.sms),
          child: Text(l10n.viaMessage, style: _actionStyle(24)),
        ),
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext, _InviteChannel.email),
          child: Text(l10n.viaEmail, style: _actionStyle(24)),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(sheetContext),
        child: Text(l10n.cancel, style: _actionStyle(20)),
      ),
    ),
  );
  if (channel == null) return false;

  await EasyLoading.show(status: 'Loading...', maskType: EasyLoadingMaskType.black);
  final code = await InvitationService.fetchInvitationCode();
  await EasyLoading.dismiss();
  if (code == null) {
    await HttpExceptionNotifyUser.showInfo(l10n.somethingWentWrong);
    return false;
  }

  try {
    switch (channel) {
      case _InviteChannel.sms:
        await _shareBySms(l10n.messageInvitationContent(code, _appLink));
      case _InviteChannel.email:
        await _shareByEmail(
          subject: l10n.emailInvitationTitle,
          body: l10n.emailInvitationContent(code, _appLink),
        );
    }
  } catch (e) {
    debugPrint('invite share failed: $e');
    return false;
  }
  return true;
}

TextStyle _actionStyle(double fontSize) =>
    GoogleFonts.rubik(color: AppColors.k0cbcc5, fontSize: fontSize);

Future<void> _shareBySms(String message) async {
  if (Platform.isIOS) {
    await sendSMS(message: message, recipients: [], sendDirect: false);
  } else {
    await launchUrl(Uri(scheme: 'sms', queryParameters: {'body': message}));
  }
}

Future<void> _shareByEmail({required String subject, required String body}) async {
  // mailto 的参数要用 encodeComponent：Uri 默认把空格编成 +，邮件客户端会原样显示
  String encode(Map<String, String> params) => params.entries
      .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
  await launchUrl(Uri(
    scheme: 'mailto',
    path: '',
    query: encode({'subject': subject, 'body': body}),
  ));
}
