import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:miaid/store/app/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

void main() async {
  setUpAll(() async{
    SharedPreferences.setMockInitialValues({});
  });
  test('test app settings', () async {
    var pref = await SharedPreferences.getInstance();
    bool working = false;
    String name = 'john';
    pref.setBool('working', working);
    pref.setString('name', name);

    expect(pref.getBool('working'), false);
    expect(pref.getString('name'), 'john');

    await AppSettings.create(pref).then((value) {
      var locale = Locale('fr', 'CH');
      value.setLocale(locale);
      expect(value.locale.languageCode, 'fr');
    });
  });
}
