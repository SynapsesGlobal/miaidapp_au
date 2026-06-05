

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/e_shop/cart_eshop.dart';
import 'package:miaid/view/user/e_shop/e_shop_details.dart';
import 'package:miaid/view/user/home/home_screen.dart';
import 'package:miaid/view/user/user_profile_screen/edit_user_profile.dart';
import 'package:miaid/view/user/user_profile_screen/user_profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miaid/view/user/location/location.dart';

void main() async{
  setUpAll(() async{
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(dev.name);
  });
  testWidgets('edit user profile test', (WidgetTester tester) async{
    var mainWidget = getIt.get<UserProfileScreen>();
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

    var user = User(customer: Customer(dob:'2020-01-02 03:04:05', language: Language(id:100, language:'EN'), gender:Gender(id:1, name:'MALE')));
    mainWidget.services.user.onLogIn(user);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(find.byType(UserProfileScreen), findsOneWidget);
  });
}