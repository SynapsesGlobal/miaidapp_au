import 'package:chopper/chopper.dart';
import 'package:miaid/api_utils/http_exception.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/main.dart';

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
      final message = S.current.apiError(e.statusCode, e.message ?? '');
      if (e.statusCode == 401) {
        await HttpExceptionNotifyUser.showInfo(S.of(navigatorKey.currentContext!).relogin);
      } else {
        await HttpExceptionNotifyUser.showInfo(S.of(navigatorKey.currentContext!).somethingWentWrong);
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
