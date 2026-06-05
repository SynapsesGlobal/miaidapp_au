import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/device_id_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/store/user/password/forgot_password/forgot_password_store.dart';
import 'package:miaid/view/user/password/forgot_password.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miaid/generated/l10n.dart';

class ApiClientMock extends Mock implements ApiClient {}

void debugDumpApp() {
  assert(WidgetsBinding.instance != null);
  String mode = 'RELEASE MODE';
  assert(() {
    mode = 'CHECKED MODE';
    return true;
  }());
  debugPrint('${WidgetsBinding.instance.runtimeType} - $mode');
  if (WidgetsBinding.instance!.renderViewElement != null) {
    debugPrint(WidgetsBinding.instance!.renderViewElement!.toStringDeep());
  } else {
    debugPrint('<no tree currently mounted>');
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('test forget password', (WidgetTester tester) async {
    SharedPreferences pref = await SharedPreferences.getInstance();

    var forgotPasswordWidget = ForgotPassword(
        services: ForgotPasswordServices(
      ApiProvider(
          apiSettings: DevApiSettings(),
          userProvider: UserProvider(pref, DeviceIdProvider(pref))),
      ForgotPasswordStore(),
    ));

    var app = MaterialApp(
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: forgotPasswordWidget,
      ),
    );

    await tester.pumpWidget(app);

    await tester.pumpAndSettle();
    expect(find.byType(TextButton), findsWidgets);
    expect(find.byType(Image), findsWidgets);
    expect(find.byType(TextFormField), findsWidgets);

    expect(find.text(S.current.entEmail), findsNothing);

    TextButton tb = tester.widget<TextButton>(find.byType(TextButton));
    await tester.tap(find.byType(TextButton));
    await tester.pump();

    expect(tb != null, true);
    print((tb.child as Text).data);

    expect(find.text(S.current.entEmail), findsOneWidget);
  });
}
