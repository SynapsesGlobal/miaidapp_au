import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/api_utils/api_provider.dart';
import 'package:miaid/api_utils/device_id_provider.dart';
import 'package:miaid/api_utils/user_provider.dart';
import 'package:miaid/config/api_settings.dart';
import 'package:miaid/store/static_pages/static_pages_store.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/view/drawer/about.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:flutter/rendering.dart';

void main() async {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies(dev.name);
  });
  testWidgets('test about miaid test', (WidgetTester tester) async {
    var pref = await SharedPreferences.getInstance();
    var aboutMiAidWidget = AboutMiAid(
        services: AboutMiAidServices(StaticPageStore(ApiProvider(
            apiSettings: DevApiSettings(),
            userProvider: UserProvider(pref, DeviceIdProvider(pref))))));
    var app = MaterialApp(
      localizationsDelegates: [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: aboutMiAidWidget,
    );

    await tester.pumpWidget(app);
    await tester.pump();
    //debugDumpApp();
    //await tester.pumpAndSettle();

    expect(find.byType(AboutMiAid), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    Widget backInkWellButton = find.byType(InkWell).evaluate().first.widget;
    expect(backInkWellButton != null, true);
    (backInkWellButton as InkWell).onTap!();
    await tester.pumpAndSettle();
  });
}
