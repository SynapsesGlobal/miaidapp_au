import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/device_id_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/notifications/firebase_notifications_handler.dart';
import 'package:miaid/notifications/notifications_handler.dart';
import 'package:miaid/store/user/calling/call_history/call_history_store.dart';
import 'package:miaid/store/user/calling/ongoing_call_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/calling/call_history/call_history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(dev.name);
    //getIt.registerSingleton<OngoingCallStore>(OngoingCallStore(GetIt.I.get<ApiProvider>(), GetIt.I.get<UserProvider>()));
    getIt.registerSingleton<NotificationHandler>(FirebaseNotificationHandler());
  });
  testWidgets('test call history', (WidgetTester tester) async {
    var pref = await SharedPreferences.getInstance();
    CallHistory mainWidget = GetIt.instance.get<CallHistory>();
    var app = MaterialApp(
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: mainWidget,
    );

    await tester.pumpWidget(app);
    await tester.pump();
    //debugDumpApp();
    //await tester.pumpAndSettle();

    expect(find.byType(CallHistory), findsOneWidget);
  });
}
