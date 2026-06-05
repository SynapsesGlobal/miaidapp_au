import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/device_id_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/notifications/firebase_notifications_handler.dart';
import 'package:miaid/notifications/notifications_handler.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:miaid/store/user/sign_in/sign_in_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/sign_in/sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miaid/generated/l10n.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(dev.name);
  });
  testWidgets('test sign in', (WidgetTester tester) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    var signInWidget = SignIn(
        services: SignInServices(
            ApiProvider(
                apiSettings: DevApiSettings(),
                userProvider: UserProvider(pref, DeviceIdProvider(pref))),
            SignInStore(AppSettings(pref))));

    var app = MaterialApp(
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: signInWidget,
      ),
    );

    await tester.pumpWidget(app);

    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsWidgets);
    expect(find.byType(Image), findsWidgets);
    expect(find.byType(SignIn), findsOneWidget);

    expect(find.text(S.current.email), findsOneWidget);
    expect(find.text(S.current.password), findsOneWidget);
    expect(find.text(S.current.signIn), findsWidgets);
    expect(find.text(S.current.signUp), findsOneWidget);

    /*
    await tester.tap(find.text(S.current.signIn));
    await tester.pump();

    expect(find.text(S.current.entEmail), findsOneWidget);
    expect(find.text(S.current.entPass), findsOneWidget);
    */
  });
}
