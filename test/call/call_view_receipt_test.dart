
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
import 'package:shared_preferences/shared_preferences.dart';

void main() async{
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(dev.name);
    getIt.registerSingleton<NotificationHandler>(FirebaseNotificationHandler());
    var params = CallViewReceiptParams(
          call: Call(id: 1,
          requestsDoctor: false,
          channelName: "testC",
          customer: null,
          $Operator:null,
          doctor: null,
          translator: null,
          customerJoinedAt: null,
          doctorJoinedAt: null,
          doctorLeftAt: null,
          translatorJoinedAt:null,
          translatorLeftAt:null,
          customerCountryCode:null,
          endedAt:'2012-02-27 13:27:00',
          createdAt:null,
          payment:null,
          channelToken:null,
          operatorChannelToken:null,
          chatChannelToken:null,
          operatorChatChannelToken:null
        ));
      getIt.registerSingleton<CallViewReceiptParams>(params);
  });

  testWidgets('test view receipt ', (WidgetTester tester) async{
    CallViewReceipt mainWidget = CallViewReceipt(params: getIt.get<CallViewReceiptParams>(), services: GetIt.instance.get<CallViewReceiptServices>());
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
    expect(find.byType(CallViewReceipt), findsOneWidget);
  });
}