import 'package:flutter_test/flutter_test.dart';
import 'package:miaid/generated_api_code/api_client.swagger.dart';
import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/foundation.dart';
import 'package:miaid/widget/image_widget.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClientMock extends Mock implements ApiClient {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('test image widget', (WidgetTester tester) async {
    var imageWidget = ImageWidget(
      imageUrl:
          'https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png',
    );
    await tester.pumpWidget(imageWidget);
    //debugDumpApp();
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
