import 'package:chopper/chopper.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/main.dart';
import 'package:miaid/utils/auth_gate.dart';

class ApiSuccessParser {
  static bool isSuccessfulWithPayload(Response<dynamic> response) {
    return response.isSuccessful && response.body != null && response.body.payload != null;
  }

  static T payloadOrThrow<T>(Response<dynamic> response) {
    if (isSuccessfulWithPayload(response)) {
      return response.body.payload;
    }
    throw HttpException(response.statusCode, ApiErrorParser.message(response.error));
  }

  static Future<T> payloadOrThrowWithMessage<T>(Response<dynamic> response) async {
    try {
      return payloadOrThrow(response);
    } on HttpException catch (e) {
      // App 还没 runApp（启动时更新推送 token）时没有 context，只处理登录态不弹提示
      final context = navigatorKey.currentContext;
      if (context != null) {
        await HttpExceptionNotifyUser.showInfo(
            e.statusCode == 401 ? S.of(context).relogin : S.of(context).somethingWentWrong);
      }
      if (e.statusCode == 401) {
        // 已登录用户令牌失效：清登录态并回登录页；登录页自身的 401（密码错误）不受影响
        await AuthGate.onUnauthorized();
      }
      rethrow;
    }
  }

  static Future<void> isSuccessfulOrThrowWithMessage(Response<dynamic> response) async {
    if (!response.isSuccessful) {
      final message = S.current.apiError(response.statusCode, ApiErrorParser.message(response.error) ?? '');
      throw HttpException(response.statusCode, message);
    }
  }
}

class ApiErrorParser {
  /// Returns the error message from the API
  /// Returns null if the error could not the parsed
  static String? message(dynamic apiError) {
    if (apiError is String) {
      return apiError;
    } else if (apiError is Map<String, dynamic>) {
      return apiError['message'];
    }
    return null;
  }
}
