import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/device_id_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/component/miaid_drawer.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/store/map/map_screen_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/map/map_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:flutter/rendering.dart';
import 'package:mocktail/mocktail.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:injectable/injectable.dart';

/*
class MockUser extends Mock implements User {
  @override
  bool operator ==(Object? other) => identical(this, other);
}
*/

class MockUserProvider extends Mock implements UserProvider {}

void main() async {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(dev.name);
  });
  testWidgets('test map screen test', (WidgetTester tester) async {
    var pref = await SharedPreferences.getInstance();
    //var userProvider = UserProvider(pref, DeviceIdProvider(pref));
    var userProvider = MockUserProvider();

    //userProvider.onLogIn(MockUser());
    when(() => userProvider.isCustomer).thenReturn(true);

    var apiProvider =
        ApiProvider(apiSettings: DevApiSettings(), userProvider: userProvider);
    var mainWidget = MapScreen(
        services: MapScreenServices(
            apiProvider, MapScreenStore(userProvider, apiProvider)));

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

    expect(find.byType(MapScreen), findsOneWidget);
  });
}
