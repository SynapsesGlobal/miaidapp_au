

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/payment/additional_services.dart';
import 'package:miaid/payment/card_details.dart';
import 'package:miaid/payment/e_shop_payment_bottom_sheet.dart';
import 'package:miaid/payment/payment_interface.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/e_shop/cart_eshop.dart';
import 'package:miaid/view/user/e_shop/e_shop_details.dart';
import 'package:miaid/view/user/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miaid/view/user/location/location.dart';

void main() async{
  setUpAll(() async{
    SharedPreferences.setMockInitialValues({});
    //await configureDependencies(dev.name);
    GetIt.I.registerSingleton<PaymentInterface>(PaymentInterface());
  });
  testWidgets('payment interface test', (WidgetTester tester) async{
    PaymentInterface mainWidget = getIt.get<PaymentInterface>();
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

    expect(find.byType(PaymentInterface), findsOneWidget);
  });
}