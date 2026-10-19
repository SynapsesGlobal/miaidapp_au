import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miaid/dialogs/targeted_push_dialog.dart';
import 'package:miaid/generated/l10n.dart';
import 'package:miaid/services/targeted_push_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

TargetedProduct _product(String id, {String? location, String? instruction}) => TargetedProduct(
      pushKey: '$id-1',
      productId: id,
      companyId: '3',
      companyName: 'Beisheng Hair',
      title: 'Product $id',
      currency: 'CNY',
      price: '1000.00',
      discountPrice: '900.00',
      image: '',
      instruction: instruction,
      location: location,
      distance: 6.7,
    );

/// 用一个按钮打开弹框，并把返回值（用户点开的商品）记下来。
Widget _host(List<TargetedProduct> products, TargetedPushHistory history, List<TargetedProduct?> results) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            final selected = await showDialog<TargetedProduct>(
              context: context,
              barrierDismissible: false,
              builder: (_) => TargetedPushCarousel(products: products, history: history),
            );
            results.add(selected);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  // 等本地化资源（S.delegate）异步加载完成，首帧才有内容
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
  // 不用 pumpAndSettle：多商品时有周期性自动轮播 Timer，会让 settle 超时。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('view product returns the current product', (tester) async {
    final history = await TargetedPushHistory.load();
    final results = <TargetedProduct?>[];
    const longInstruction = 'Call 020-38296666 or add WeChat y13725298151 to book. '
        'Surgery takes 3-6 hours, open all year 9:00-20:00. Arrive 15 minutes early.';
    await tester.pumpWidget(_host(
      [_product('7', location: 'Guangzhou', instruction: longInstruction)],
      history,
      results,
    ));
    await _open(tester);

    expect(find.text('Product 7'), findsOneWidget);
    final instruction = tester.widget<Text>(find.text(longInstruction));
    expect(instruction.maxLines, 2);
    expect(instruction.overflow, TextOverflow.ellipsis);
    expect(find.text('Beisheng Hair'), findsOneWidget);
    expect(find.text('Guangzhou · 6.7 km away'), findsOneWidget);
    expect(find.text('RECOMMENDED NEAR YOU'), findsOneWidget);
    expect(find.byType(TargetedPushCarousel), findsOneWidget);

    await tester.tap(find.byKey(const Key('targeted_push_view_product')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TargetedPushCarousel), findsNothing);
    expect(results.single?.productId, '7');
    // 查看商品不做记录
    expect(history.hiddenKeys, isEmpty);
  });

  testWidgets('close returns nothing and records nothing', (tester) async {
    final history = await TargetedPushHistory.load();
    final results = <TargetedProduct?>[];
    await tester.pumpWidget(_host([_product('7')], history, results));
    await _open(tester);

    // 点遮罩不关闭
    await tester.tapAt(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TargetedPushCarousel), findsOneWidget);

    // 系统返回键不关闭
    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TargetedPushCarousel), findsOneWidget);

    await tester.tap(find.byKey(const Key('targeted_push_close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TargetedPushCarousel), findsNothing);
    expect(results, [null]);
    expect(history.hiddenKeys, isEmpty);
  });

  testWidgets('do not show again hides the product and closes when none is left', (tester) async {
    final history = await TargetedPushHistory.load();
    final results = <TargetedProduct?>[];
    await tester.pumpWidget(_host([_product('7'), _product('9')], history, results));
    await _open(tester);

    expect(find.text('Product 7'), findsOneWidget);

    await tester.tap(find.byKey(const Key('targeted_push_hide_product')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 第一个被移走，弹框还在，显示第二个
    expect(find.byType(TargetedPushCarousel), findsOneWidget);
    expect(find.text('Product 7'), findsNothing);
    expect(find.text('Product 9'), findsOneWidget);
    expect(history.hiddenKeys, {'7-1'});

    await tester.tap(find.byKey(const Key('targeted_push_hide_product')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TargetedPushCarousel), findsNothing);
    expect(history.hiddenKeys, {'7-1', '9-1'});
    expect(results, [null]);
  });

  testWidgets('multiple products auto-advance', (tester) async {
    final history = await TargetedPushHistory.load();
    await tester.pumpWidget(_host([_product('7'), _product('9')], history, []));
    await _open(tester);

    expect(find.text('Product 7'), findsOneWidget);
    await tester.pump(TargetedPushDialog.autoPlayInterval);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Product 9'), findsOneWidget);

    // 关闭弹框，停掉自动轮播 Timer
    await tester.tap(find.byKey(const Key('targeted_push_close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  });
}
