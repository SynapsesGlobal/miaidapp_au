

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/e_shop/cart_eshop.dart';
import 'package:miaid/view/user/e_shop/e_shop_details.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miaid/generated/l10n.dart';

void main() async{
  setUpAll(() async{
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(dev.name);
    var location = PharmacyLocation(
      pharmacyId: null,
      address: null,
      unit: null,
      street: null,
      city: null,
      state: null,
      country: null,
      zip: null,
      latitude: null,
      longitude: null,
      cities: null,
      pharmacy: null,
      id: null,
    );

    GetIt.instance.registerSingleton<EShopDetailsParams>(EShopDetailsParams(1, location));
  });
  testWidgets('eshop detail test', (WidgetTester tester) async{
    var mainWidget = EShopDetails(params: GetIt.instance.get<EShopDetailsParams>(), services:GetIt.instance.get<EShopDetailsServices>());
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

    expect(find.byType(EShopDetails), findsOneWidget);
  });
}