import 'package:flutter_test/flutter_test.dart';
import 'package:injectable/injectable.dart' show dev;
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/main.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/calling/call_history/call_history.dart';
import 'package:miaid/view/user/home/home_screen.dart';
import 'package:miaid/view/user/sign_in/sign_in.dart';
import 'package:miaid/view/user/sign_up/otp_screen.dart';
import 'package:miaid/view/user/sign_up/sign_up_2.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 所有页面都要求先登录：未登录时首页就是登录页；已登录按用户状态分流。
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(dev.name);
  });

  test('not logged in lands on the sign-in page', () {
    expect(getHomeFromUser(null), isA<SignIn>());
  });

  test('logged-in users are routed by their account state', () {
    const verified = '2026-01-01 00:00:00';

    expect(getHomeFromUser(User(emailVerifiedAt: null)), isA<OtpScreen>(),
        reason: 'email not verified yet → OTP');
    expect(getHomeFromUser(User(emailVerifiedAt: verified)), isA<SignUp2>(),
        reason: 'verified but no customer profile → complete profile');
    expect(getHomeFromUser(User(emailVerifiedAt: verified, customer: Customer())), isA<HomeScreen>());
    expect(getHomeFromUser(User(emailVerifiedAt: verified, doctor: Doctor())), isA<CallHistory>());
  });
}
