

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/user/e_shop/cart_eshop.dart';
import 'package:miaid/view/user/e_shop/e_shop_details.dart';
import 'package:miaid/view/user/home/home_screen.dart';
import 'package:miaid/view/user/user_profile_screen/edit_user_profile.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miaid/view/user/location/location.dart';

class MockUserProvider extends Mock implements UserProvider{ }
void main() async{
  setUpAll(() async{
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(dev.name);
    if(GetIt.I.isRegistered<UserProvider>()){
      GetIt.I.unregister<UserProvider>();
    }
    GetIt.I.registerSingleton<UserProvider>(MockUserProvider());
  });
  testWidgets('edit user profile test', (WidgetTester tester) async{
    var user = User(customer: Customer(dob:'2020-01-02 03:04:05', language: Language(id:100, language:'EN'), gender:Gender(id:1, name:'MALE')));
    when(()=> GetIt.I.get<UserProvider>().user).thenReturn(user);
    var mainWidget = GetIt.I.get<EditUserProfile>();
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

    expect(find.byType(EditUserProfile), findsOneWidget);
  });
}