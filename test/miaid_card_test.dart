import 'dart:math';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:injectable/injectable.dart';
import 'package:miaid/component/miaid_card.dart';
import 'package:flutter/material.dart';
import 'package:miaid/utils/configure_dependencies.dart';
import 'package:miaid/widget/image_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miaid/generated/l10n.dart';

void main() async{
  var testTextVal = 'for test';
  setUpAll(()async{
    //await configureDependencies(dev.name);
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('test miaid card component miAidCard function', (WidgetTester tester) async {
    final mainWidget= miAidCard(Text(testTextVal));
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
    expect(find.byType(Text), findsOneWidget);
    expect(find.text(testTextVal), findsOneWidget);
  });

  testWidgets("test miaid card component activeSubscriptionCard function", (WidgetTester tester) async {
    final mainWidget= activeSubscriptionCard(Text(testTextVal));
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
    expect(find.byType(Text), findsOneWidget);
    expect(find.text(testTextVal), findsOneWidget);
  });

  testWidgets('test miaid card component radiobuttonContainer function', (WidgetTester tester) async{
    final mainWidget= radiobuttonContainer(child: Text(testTextVal));
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
    expect(find.byType(Text), findsOneWidget);
    expect(find.text(testTextVal), findsOneWidget);
  });
  testWidgets('test miaid card component buttonContainer function', (WidgetTester tester) async{
    final mainWidget = buttonContainer(Text(testTextVal));
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
    expect(find.byType(Text), findsOneWidget);
    expect(find.text(testTextVal), findsOneWidget);
  });


}
