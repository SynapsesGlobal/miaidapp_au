import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_it/get_it.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/component/nav_bar_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:miaid/notifications/firebase_notifications_handler.dart';
import 'package:miaid/notifications/notifications_handler.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async{
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets("nav bar icon test", (WidgetTester tester) async {
    Widget mainWidget = navBarIcon(iconAssetName: 'ic_nb_back.png');
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
    await tester.pumpAndSettle();
    expect(find.byType(Container), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
