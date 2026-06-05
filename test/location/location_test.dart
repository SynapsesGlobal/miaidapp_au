

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/e_shop/cart_eshop.dart';
import 'package:miaid/view/user/e_shop/e_shop_details.dart';
import 'package:miaid/view/user/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miaid/view/user/location/location.dart';

void main() async{
  setUpAll(() async{
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(dev.name);
  });
  testWidgets('location test', (WidgetTester tester) async{
    Locations mainWidget = getIt.get<Locations>();
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

    expect(find.byType(Locations), findsOneWidget);
  });
}