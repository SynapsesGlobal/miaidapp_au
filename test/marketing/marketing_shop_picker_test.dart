import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/widget/marketing_shop_picker.dart';

/// /category/products 返回的 companies（该大类下有货的商家，按距离排序）
const List<Map<String, dynamic>> _companies = [
  {'companyId': 3, 'name': 'Beisheng Hair', 'image': '', 'distance': 6.7},
  {'companyId': '5', 'name': 'Sunny Clinic', 'image': '', 'distance': 0.35},
];

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: child),
    );

void main() {
  test('companyIdOf accepts int and string ids', () {
    expect(MarketingShopPicker.companyIdOf(_companies[0]), 3);
    expect(MarketingShopPicker.companyIdOf(_companies[1]), 5);
    expect(MarketingShopPicker.companyIdOf({'name': 'x'}), 0);
    expect(MarketingShopPicker.companyIdOf(null), 0);
  });

  testWidgets('picker lists "all shops" first, marks the selected shop and returns the tapped id', (tester) async {
    int? picked;
    await tester.pumpWidget(_host(Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          picked = await MarketingShopPicker.show(context, companies: _companies, selectedCompanyId: 5);
        },
        child: const Text('open'),
      ),
    )));
    // 本地化资源异步加载，首帧无内容
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text(S.current.selectShop), findsOneWidget);
    expect(find.text(S.current.allShops), findsOneWidget);
    expect(find.text('Beisheng Hair'), findsOneWidget);
    expect(find.text('Sunny Clinic'), findsOneWidget);
    expect(find.text('350 m'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget, reason: 'only the selected shop is ticked');
    // Two shops do not need the local search box
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('Beisheng Hair'));
    await tester.pumpAndSettle();
    expect(picked, 3);
  });

  testWidgets('with many shops the picker offers a local name filter and "all shops" returns 0', (tester) async {
    final many = List.generate(8, (i) => {'companyId': i + 1, 'name': 'Shop ${i + 1}', 'image': ''});
    int? picked;
    await tester.pumpWidget(_host(Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          picked = await MarketingShopPicker.show(context, companies: many, selectedCompanyId: 0);
        },
        child: const Text('open'),
      ),
    )));
    // 本地化资源异步加载，首帧无内容
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'shop 7');
    await tester.pumpAndSettle();
    expect(find.text('Shop 7'), findsOneWidget);
    expect(find.text('Shop 1'), findsNothing);
    expect(find.text(S.current.allShops), findsNothing, reason: 'hidden while filtering');

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.current.allShops));
    await tester.pumpAndSettle();
    expect(picked, 0);
  });
}
