import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/view/user/password/change_password.dart';
import 'package:miaid/store/user/user_profile_screen/change_password/change_password_store.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miaid/api_utils/device_id_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

  testWidgets('', (WidgetTester tester) async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    const fakeBody =
        '[{"id":1,"name":"Leanne Graham","username":"Bret","email":"Sincere@april.biz","address":{"street":"Kulas Light","suite":"Apt. 556","city":"Gwenborough","zipcode":"92998-3874","geo":{"lat":"-37.3159","lng":"81.1496"}},"phone":"1-770-736-8031 x56442","website":"hildegard.org","company":{"name":"Romaguera-Crona","catchPhrase":"Multi-layered client-server neural-net","bs":"harness real-time e-markets"}},{"id":2,"name":"Ervin Howell","username":"Antonette","email":"Shanna@melissa.tv","address":{"street":"Victor Plains","suite":"Suite 879","city":"Wisokyburgh","zipcode":"90566-7771","geo":{"lat":"-43.9509","lng":"-34.4618"}},"phone":"010-692-6593 x09125","website":"anastasia.net","company":{"name":"Deckow-Crist","catchPhrase":"Proactive didactic contingency","bs":"synergize scalable supply-chains"}}]';
    var changePassword = ChangePassword(
        services: ChangePasswordServices(
            ChangePasswordStore(),
            ApiProvider(
                apiSettings: DevApiSettings(),
                userProvider: UserProvider(pref, DeviceIdProvider(pref)))));

    var app = MaterialApp(
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: changePassword,
      ),
    );
    await tester.pumpWidget(
      app,
    );

    //debugDumpApp();
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsWidgets);
    expect(find.byType(ChangePassword), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(TextFormField), findsWidgets);

    expect(find.text(S.current.savePass), findsOneWidget);
    expect(find.text(S.current.password), findsOneWidget);
    expect(find.text(S.current.confirmPass), findsOneWidget);
    //debugDumpApp();

    //expect(tester.widget<TextFormField>(find.text(S.current.currPass)).val);
    //await tester.enterText(find.text(S.current.currPass), 'testcurrPass');
    //await tester.enterText(find.text(S.current.password), 'testnewpassword');
    //await tester.enterText(find.text(S.current.confirmPass), 'testnewpassword');
    //await tester.testTextInput.receiveAction(TextInputAction.done);
    //await tester.pump();
    //expect(find.text('testcurrPass'), findsOneWidget);
    //expect(find.text('testnewpassword'), findsWidgets);

    expect(changePassword, isNot(null));
    expect(changePassword.services, isNot(null));
    expect(changePassword.params, null);

    expect(find.text(S.current.entCurrPass), findsNothing);
    expect(find.text(S.current.entPass), findsNothing);
    expect(find.text(S.current.entConfrmPass), findsNothing);
    await tester.tap(find.text(S.current.savePass));
    await tester.pump();
    expect(find.text(S.current.entCurrPass), findsOneWidget);
    expect(find.text(S.current.entPass), findsOneWidget);
    expect(find.text(S.current.entConfrmPass), findsOneWidget);
  });
}
