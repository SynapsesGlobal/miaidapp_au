
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/notifications/firebase_notifications_handler.dart';
import 'package:miaid/notifications/notifications_handler.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/calling/call_history/call_view_receipt.dart';
import 'package:miaid/view/user/calling/call_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async{
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(dev.name);
  });

  testWidgets('test view receipt ', (WidgetTester tester) async{
    CallScreen mainWidget = GetIt.I.get<CallScreen>();
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
    expect(find.byType(CallScreen), findsOneWidget);
  });
}