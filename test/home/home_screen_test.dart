

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/notifications/firebase_notifications_handler.dart';
import 'package:miaid/notifications/notifications_handler.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/e_shop/cart_eshop.dart';
import 'package:miaid/view/user/e_shop/e_shop_details.dart';
import 'package:miaid/view/user/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miaid/store/user/calling/ongoing_call_store.dart';

void main() async{
  setUpAll(() async{
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(dev.name);
    GetIt.instance.registerSingleton<NotificationHandler>(FirebaseNotificationHandler());
  });
  testWidgets('home screen test', (WidgetTester tester) async{
    HomeScreen mainWidget = getIt.get<HomeScreen>();
    var app = MaterialApp(
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: mainWidget
      ),
    );

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}