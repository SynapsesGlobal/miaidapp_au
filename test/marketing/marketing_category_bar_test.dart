import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/widget/marketing_category_bar.dart';

/// /category/products 返回的 categories：全部 + 两个有货的系统子分类
const List<Map<String, dynamic>> _categories = [
  {'cateId': 0, 'cateName': 'All Products', 'cateImg': ''},
  {'cateId': 5, 'cateName': 'Hair', 'cateImg': ''},
  {'cateId': '6', 'cateName': 'Skin', 'cateImg': ''},
];

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: Column(children: [child])),
    );

void main() {
  testWidgets('bar lists every category with the local "all" label and reports taps by id', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(_host(MarketingCategoryBar(
      categories: _categories,
      selectedCateId: 5,
      onSelected: taps.add,
    )));
    await tester.pumpAndSettle();

    expect(find.text(S.current.allProducts), findsOneWidget);
    expect(find.text('Hair'), findsOneWidget);
    expect(find.text('Skin'), findsOneWidget);

    await tester.tap(find.text('Skin'));
    await tester.tap(find.text(S.current.allProducts));
    expect(taps, [6, 0], reason: 'string ids from JSON are normalised to int');
  });
}
